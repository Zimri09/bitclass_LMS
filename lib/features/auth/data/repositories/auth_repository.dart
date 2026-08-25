import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/config/environment.dart';
import '../../auth_otp.dart';
import '../models/user_model.dart';

/// Thrown when sign-up succeeds but the user must confirm their email first.
class EmailConfirmationRequiredException implements Exception {
  final String email;

  const EmailConfirmationRequiredException(this.email);

  @override
  String toString() => 'Please confirm your email before signing in.';
}

/// Thrown when Supabase is configured to skip the required OTP challenge.
class EmailOtpConfigurationException implements Exception {
  const EmailOtpConfigurationException();

  @override
  String toString() =>
      'Email OTP verification is not enabled. Please contact support.';
}

/// Thrown when Google authentication uses an account outside BISU.
class GoogleDomainNotAllowedException implements Exception {
  const GoogleDomainNotAllowedException();

  @override
  String toString() =>
      'Use your verified @bisu.edu.ph Google account to continue.';
}

/// Repository handling authentication and user profile operations
class AuthRepository {
  static const String googleStudentEmailDomain = 'bisu.edu.ph';
  static const String _profilesTable = 'profiles';
  static const String _avatarsBucket = 'avatars';
  static const String _authFlowBox = 'auth_flow';
  static const String _pendingRecoveryUserKey = 'pending_recovery_user_id';
  static const String _sessionProfileBox = 'auth_session_profile_v1';

  final SupabaseClient? _supabase;

  static const String _demoStudentUserId = 'demo-user-1';
  static const String _demoInstructorUserId = 'demo-instructor-1';
  static const String _demoOtp = '12345678';

  // Demo mode state
  UserModel? _demoUser;
  UserModel? _demoPendingUser;
  final _demoAuthController = StreamController<User?>.broadcast();

  AuthRepository({SupabaseClient? supabase})
    : _supabase = EnvironmentConfig.isDemoMode
          ? null
          : (supabase ?? Supabase.instance.client);

  /// Stream of authentication state changes
  Stream<User?> get authStateChanges => EnvironmentConfig.isDemoMode
      ? _demoAuthController.stream
      : _supabase!.auth.onAuthStateChange.map((event) => event.session?.user);

  /// Get current authenticated user
  User? get currentUser =>
      EnvironmentConfig.isDemoMode ? null : _supabase!.auth.currentUser;

  /// Whether Supabase restored a persisted session for this device.
  bool get hasCurrentSession =>
      EnvironmentConfig.isDemoMode || _supabase!.auth.currentSession != null;

  /// Get demo user (for demo mode)
  UserModel? get demoUser => _demoUser;

  /// Get current user's profile
  Future<UserModel?> getCurrentUserProfile() async {
    if (EnvironmentConfig.isDemoMode) return _demoUser;

    final user = currentUser;
    if (user == null) return null;
    if (user.emailConfirmedAt == null) return null;

    try {
      final row = await _supabase!
          .from(_profilesTable)
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (row == null) return null;

      return UserModel.fromMap(_rowToUserMap(row), user.id);
    } on PostgrestException catch (e) {
      throw _handlePostgrestException(e);
    }
  }

  /// Sign in with email and password
  Future<UserModel> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      final isInstructor = normalizedEmail.contains('instructor');
      _demoUser = UserModel(
        id: isInstructor ? _demoInstructorUserId : _demoStudentUserId,
        email: normalizedEmail,
        firstName: isInstructor ? 'Demo' : 'Demo',
        lastName: isInstructor ? 'Instructor' : 'Student',
        role: isInstructor ? 'instructor' : 'student',
        createdAt: DateTime.now(),
      );
      _demoAuthController.add(null);
      return _demoUser!;
    }

    try {
      final response = await _supabase!.auth.signInWithPassword(
        email: normalizedEmail,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw Exception('Sign in failed: No user returned');
      }
      if (user.emailConfirmedAt == null) {
        await _supabase.auth.signOut(scope: SignOutScope.local);
        throw EmailConfirmationRequiredException(normalizedEmail);
      }
      await _clearPendingRecovery(user.id);

      return await _resolveProfileForUser(
        user,
        defaultRole: _safeSelfRegisteredRole(user.userMetadata?['role']),
      );
    } on EmailConfirmationRequiredException {
      rethrow;
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('email not confirmed')) {
        throw EmailConfirmationRequiredException(normalizedEmail);
      }
      throw _handleAuthException(e.message);
    } on PostgrestException catch (e) {
      throw _handlePostgrestException(e);
    }
  }

  /// Starts Google OAuth. New Google accounts are always student accounts.
  ///
  /// A real OAuth flow completes through the configured deep link, so this
  /// returns null after opening Google. Demo mode returns a user immediately.
  Future<UserModel?> signInWithGoogle() async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      _demoUser = UserModel(
        id: _demoStudentUserId,
        email: 'student@$googleStudentEmailDomain',
        firstName: 'Demo',
        lastName: 'Student',
        role: 'student',
        createdAt: DateTime.now(),
      );
      return _demoUser;
    }

    try {
      final launched = await _supabase!.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : EnvironmentConfig.authRedirectUrl,
        authScreenLaunchMode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );
      if (!launched) {
        throw Exception(
          'Google sign-in could not be opened. Please try again.',
        );
      }
      return null;
    } on AuthException catch (error) {
      throw _handleAuthException(error.message);
    }
  }

  /// Register a new user with email and password
  Future<UserModel> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String role,
    String? firstName,
    String? lastName,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedFirstName = firstName?.trim() ?? '';
    final normalizedLastName = lastName?.trim() ?? '';
    if (!_isValidEmail(normalizedEmail)) {
      throw const FormatException('Please enter a valid email address.');
    }
    if (normalizedFirstName.isEmpty || normalizedLastName.isEmpty) {
      throw const FormatException('First name and last name are required.');
    }
    if (password.length < 8) {
      throw const FormatException(
        'Password must contain at least 8 characters.',
      );
    }
    if (role != 'student' && role != 'instructor') {
      throw const FormatException('Please select a valid account role.');
    }

    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      _demoPendingUser = UserModel(
        id: 'demo-user-${DateTime.now().millisecondsSinceEpoch}',
        email: normalizedEmail,
        firstName: normalizedFirstName,
        lastName: normalizedLastName,
        role: role,
        createdAt: DateTime.now(),
      );
      _demoAuthController.add(null);
      throw EmailConfirmationRequiredException(normalizedEmail);
    }

    try {
      final response = await _supabase!.auth.signUp(
        email: normalizedEmail,
        password: password,
        data: <String, dynamic>{
          'role': role,
          'first_name': normalizedFirstName,
          'last_name': normalizedLastName,
          'display_name': '$normalizedFirstName $normalizedLastName',
        },
      );

      final user = response.user;
      if (user == null) {
        throw Exception('Registration failed: No user returned');
      }
      if (user.identities?.isEmpty ?? false) {
        throw Exception('An account already exists with this email');
      }

      // A session here means Confirm email/autoconfirm is enabled incorrectly.
      // Sign out rather than allowing a user to bypass the OTP screen.
      if (response.session != null) {
        await _supabase.auth.signOut(scope: SignOutScope.local);
        throw const EmailOtpConfigurationException();
      }

      throw EmailConfirmationRequiredException(user.email ?? normalizedEmail);
    } on EmailConfirmationRequiredException {
      rethrow;
    } on EmailOtpConfigurationException {
      rethrow;
    } on AuthException catch (e) {
      throw _handleAuthException(e.message);
    } on PostgrestException catch (e) {
      throw _handlePostgrestException(e);
    }
  }

  /// Sign out
  Future<void> signOut() async {
    if (EnvironmentConfig.isDemoMode) {
      _demoUser = null;
      _demoAuthController.add(null);
      return;
    }
    final userId = currentUser?.id;
    try {
      // Keep logout device-local so it never waits for a network request.
      await _supabase!.auth.signOut(scope: SignOutScope.local);
    } finally {
      if (userId != null) {
        await _clearPendingRecovery(userId);
        await _clearCachedProfile(userId);
      }
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (!_isValidEmail(normalizedEmail)) {
      throw const FormatException('Please enter a valid email address.');
    }
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      return;
    }
    try {
      await _supabase!.auth.resetPasswordForEmail(normalizedEmail);
    } on AuthException catch (e) {
      throw _handleAuthException(e.message);
    }
  }

  /// Verifies a signup OTP and resolves the profile created by the DB trigger.
  Future<UserModel> verifySignupOtp({
    required String email,
    required String token,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedToken = normalizeAuthEmailOtp(token);
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (normalizedToken != _demoOtp || _demoPendingUser == null) {
        throw Exception('Invalid verification code.');
      }
      _demoUser = _demoPendingUser;
      _demoPendingUser = null;
      _demoAuthController.add(null);
      return _demoUser!;
    }

    try {
      final response = await _supabase!.auth.verifyOTP(
        email: normalizedEmail,
        token: normalizedToken,
        type: OtpType.signup,
      );
      final user = response.user;
      if (response.session == null ||
          user == null ||
          user.emailConfirmedAt == null) {
        throw Exception('Email verification did not create a valid session.');
      }
      return await _resolveProfileForUser(
        user,
        defaultRole: _safeSelfRegisteredRole(user.userMetadata?['role']),
      );
    } on AuthException catch (e) {
      throw _handleOtpException(e.message);
    } on PostgrestException catch (e) {
      throw _handlePostgrestException(e);
    }
  }

  /// Resends the current signup confirmation OTP.
  Future<void> resendSignupOtp(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (_demoPendingUser == null) {
        throw Exception('No pending registration was found.');
      }
      return;
    }

    try {
      await _supabase!.auth.resend(
        email: normalizedEmail,
        type: OtpType.signup,
      );
    } on AuthException catch (e) {
      throw _handleOtpException(e.message);
    }
  }

  /// Verifies a recovery OTP without exposing the application profile.
  Future<void> verifyPasswordRecoveryOtp({
    required String email,
    required String token,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedToken = normalizeAuthEmailOtp(token);
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (normalizedToken != _demoOtp) {
        throw Exception('Invalid verification code.');
      }
      return;
    }

    try {
      final response = await _supabase!.auth.verifyOTP(
        email: normalizedEmail,
        token: normalizedToken,
        type: OtpType.recovery,
      );
      if (response.session == null || response.user == null) {
        throw Exception('Password recovery verification failed.');
      }
      await _markPendingRecovery(response.user!.id);
    } on AuthException catch (e) {
      throw _handleOtpException(e.message);
    }
  }

  /// Updates the password for the verified recovery session, then signs out.
  Future<void> updatePasswordAfterRecovery(String newPassword) async {
    if (newPassword.length < 8) {
      throw const FormatException(
        'Password must contain at least 8 characters.',
      );
    }
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      _demoUser = null;
      _demoAuthController.add(null);
      return;
    }

    try {
      final userId = currentUser?.id;
      await _supabase!.auth.updateUser(UserAttributes(password: newPassword));
      if (userId != null) await _clearPendingRecovery(userId);
      await _supabase.auth.signOut(scope: SignOutScope.local);
    } on AuthException catch (e) {
      throw _handleAuthException(e.message);
    }
  }

  /// Restores a verified user's trigger-created profile after app restart.
  Future<UserModel?> restoreCurrentUserProfile() async {
    if (EnvironmentConfig.isDemoMode) return _demoUser;
    final user = currentUser;
    if (user == null) return null;
    if (user.emailConfirmedAt == null) {
      await _supabase!.auth.signOut(scope: SignOutScope.local);
      return null;
    }
    if (await _hasPendingRecovery(user.id)) {
      await signOut();
      return null;
    }
    return _resolveProfileForUser(
      user,
      defaultRole: _safeSelfRegisteredRole(user.userMetadata?['role']),
    );
  }

  /// Restores only device-local identity data for an existing Supabase
  /// session. This never grants backend access; RLS still protects all remote
  /// operations when connectivity returns.
  Future<UserModel?> restoreSessionSnapshot() async {
    if (EnvironmentConfig.isDemoMode) return _demoUser;

    final user = currentUser;
    if (user == null || user.emailConfirmedAt == null) return null;
    _ensureAllowedGoogleUser(user);
    if (await _hasPendingRecovery(user.id)) return null;

    final cached = await _readCachedProfile(user.id);
    if (cached != null && cached.email == user.email) return cached;

    final email = user.email;
    if (email == null || email.trim().isEmpty) return null;
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    return UserModel(
      id: user.id,
      email: email,
      firstName: _metadataString(metadata, 'first_name', 'firstName'),
      lastName: _metadataString(metadata, 'last_name', 'lastName'),
      role: _safeSelfRegisteredRole(metadata['role']),
      createdAt: DateTime.tryParse(user.createdAt) ?? DateTime.now().toUtc(),
    );
  }

  /// Update user profile
  Future<UserModel> updateProfile({
    String? firstName,
    String? lastName,
    int? age,
    bool clearAge = false,
    String? bio,
    String? avatarUrl,
  }) async {
    if (EnvironmentConfig.isDemoMode) {
      if (_demoUser == null) {
        throw Exception('No authenticated user');
      }
      _demoUser = _demoUser!.copyWith(
        firstName: firstName ?? _demoUser!.firstName,
        lastName: lastName ?? _demoUser!.lastName,
        age: age ?? _demoUser!.age,
        clearAge: clearAge,
        bio: bio ?? _demoUser!.bio,
        avatarUrl: avatarUrl ?? _demoUser!.avatarUrl,
        updatedAt: DateTime.now(),
      );
      return _demoUser!;
    }

    final user = currentUser;
    if (user == null) {
      throw Exception('No authenticated user');
    }

    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (firstName != null) updates['first_name'] = firstName;
    if (lastName != null) updates['last_name'] = lastName;
    if (clearAge) {
      updates['age'] = null;
    } else if (age != null) {
      updates['age'] = age;
    }
    if (bio != null) updates['bio'] = bio;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

    try {
      await _supabase!.from(_profilesTable).update(updates).eq('id', user.id);

      final profile = await getCurrentUserProfile();
      if (profile == null) {
        throw Exception('Failed to fetch updated profile');
      }
      await _cacheProfile(profile);
      return profile;
    } on PostgrestException catch (e) {
      throw _handlePostgrestException(e);
    }
  }

  /// Uploads a JPG avatar to the current user's storage folder.
  Future<UserModel> uploadProfileAvatar(Uint8List imageBytes) async {
    if (!_isJpg(imageBytes)) {
      throw const FormatException('Please select a JPG image file.');
    }
    if (EnvironmentConfig.isDemoMode) {
      throw UnsupportedError('Avatar uploads require a connected account.');
    }

    final user = currentUser;
    if (user == null) {
      throw Exception('No authenticated user');
    }

    // A new path prevents clients from receiving a stale CDN-cached avatar.
    final objectPath = '${user.id}/${const Uuid().v4()}.jpg';

    try {
      await _supabase!.storage
          .from(_avatarsBucket)
          .uploadBinary(
            objectPath,
            imageBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );

      final publicUrl = _supabase.storage
          .from(_avatarsBucket)
          .getPublicUrl(objectPath);

      try {
        return await updateProfile(avatarUrl: publicUrl);
      } catch (_) {
        await _supabase.storage.from(_avatarsBucket).remove([objectPath]);
        rethrow;
      }
    } on StorageException catch (e) {
      throw Exception('Avatar upload failed: ${e.message}');
    }
  }

  static bool _isJpg(Uint8List bytes) {
    return bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff;
  }

  /// Delete user account
  Future<void> deleteAccount() async {
    if (EnvironmentConfig.isDemoMode) {
      _demoUser = null;
      _demoAuthController.add(null);
      return;
    }

    final user = currentUser;
    if (user == null) {
      throw Exception('No authenticated user');
    }

    try {
      await _supabase!.rpc('delete_current_user_account');
    } catch (_) {
      await _supabase!.from(_profilesTable).delete().eq('id', user.id);
      await _supabase.auth.signOut();
    }
  }

  Future<UserModel> _resolveProfileForUser(
    User user, {
    required String defaultRole,
  }) async {
    _ensureAllowedGoogleUser(user);
    for (var attempt = 0; attempt < 5; attempt++) {
      final profile = await getCurrentUserProfile();
      if (profile != null) {
        await _cacheProfile(profile);
        return profile;
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }
    throw Exception(
      'Your verified $defaultRole profile could not be restored. '
      'Please sign out and try again.',
    );
  }

  Map<String, dynamic> _rowToUserMap(Map<String, dynamic> row) {
    return {
      'email': row['email'] as String,
      'firstName': row['first_name'] as String?,
      'lastName': row['last_name'] as String?,
      'age': row['age'] as int?,
      'avatarUrl': row['avatar_url'] as String?,
      'bio': row['bio'] as String?,
      'role': row['role'] as String? ?? 'student',
      'createdAt':
          row['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      'updatedAt': row['updated_at']?.toString(),
    };
  }

  Exception _handleAuthException(String? message) {
    final text = message?.toLowerCase() ?? '';
    if (text.contains('invalid login credentials')) {
      return Exception('Invalid email or password');
    }
    if (text.contains('email not confirmed')) {
      return Exception('Please confirm your email before signing in');
    }
    if (text.contains('email rate limit exceeded')) {
      return Exception('Too many attempts. Please try again later');
    }
    if (text.contains('error sending confirmation email') ||
        text.contains('error sending recovery email') ||
        (text.contains('unexpected_failure') &&
            text.contains('sending') &&
            text.contains('email'))) {
      return Exception(
        'The verification email could not be sent. '
        'Please check the email service configuration and try again.',
      );
    }
    if (text.contains('user already registered')) {
      return Exception('An account already exists with this email');
    }
    if (text.contains('password should be at least')) {
      return Exception('Password is too weak');
    }
    if (text.contains('invalid email')) {
      return Exception('Invalid email address');
    }
    return Exception(message ?? 'Authentication failed');
  }

  Exception _handleOtpException(String? message) {
    final text = message?.toLowerCase() ?? '';
    if (text.contains('expired or is invalid') ||
        text.contains('expired or invalid')) {
      return Exception(
        'This verification code is invalid or has expired. '
        'Use the latest code or request a new one.',
      );
    }
    if (text.contains('expired')) {
      return Exception(
        'This verification code has expired. Request a new one.',
      );
    }
    if (text.contains('invalid') ||
        text.contains('token') ||
        text.contains('otp')) {
      return Exception('Invalid verification code. Please try again.');
    }
    if (text.contains('rate limit') || text.contains('too many')) {
      return Exception('Too many attempts. Please wait before trying again.');
    }
    return Exception(message ?? 'OTP verification failed.');
  }

  static bool _isValidEmail(String email) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);

  /// Uses an exact domain comparison instead of a suffix check.
  static bool isAllowedGoogleStudentEmail(String? email) {
    if (email == null) return false;
    final parts = email.trim().toLowerCase().split('@');
    return parts.length == 2 &&
        parts.first.isNotEmpty &&
        parts.last == googleStudentEmailDomain;
  }

  static bool _hasGoogleIdentity(User user) {
    final provider = user.appMetadata['provider'];
    final providers = user.appMetadata['providers'];
    return provider == 'google' ||
        (providers is List && providers.contains('google')) ||
        (user.identities?.any((identity) => identity.provider == 'google') ??
            false);
  }

  static void _ensureAllowedGoogleUser(User user) {
    if (_hasGoogleIdentity(user) && !isAllowedGoogleStudentEmail(user.email)) {
      throw const GoogleDomainNotAllowedException();
    }
  }

  static String _safeSelfRegisteredRole(Object? role) =>
      role == 'instructor' ? 'instructor' : 'student';

  static String? _metadataString(
    Map<String, dynamic> metadata,
    String snakeCaseKey,
    String camelCaseKey,
  ) {
    final value = metadata[snakeCaseKey] ?? metadata[camelCaseKey];
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }

  Future<Box<dynamic>> _profileCacheBox() =>
      Hive.openBox<dynamic>(_sessionProfileBox);

  Future<void> _cacheProfile(UserModel profile) async {
    final box = await _profileCacheBox();
    await box.put(profile.id, profile.toJson());
  }

  Future<UserModel?> _readCachedProfile(String userId) async {
    final box = await _profileCacheBox();
    final raw = box.get(userId);
    if (raw is! Map) return null;

    try {
      return UserModel.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      await box.delete(userId);
      return null;
    }
  }

  Future<void> _clearCachedProfile(String userId) async {
    final box = await _profileCacheBox();
    await box.delete(userId);
  }

  Future<void> _markPendingRecovery(String userId) async {
    final box = await Hive.openBox<String>(_authFlowBox);
    await box.put(_pendingRecoveryUserKey, userId);
  }

  Future<bool> _hasPendingRecovery(String userId) async {
    final box = await Hive.openBox<String>(_authFlowBox);
    return box.get(_pendingRecoveryUserKey) == userId;
  }

  Future<void> _clearPendingRecovery(String userId) async {
    final box = await Hive.openBox<String>(_authFlowBox);
    if (box.get(_pendingRecoveryUserKey) == userId) {
      await box.delete(_pendingRecoveryUserKey);
    }
  }

  Exception _handlePostgrestException(PostgrestException e) {
    final text = e.message.toLowerCase();
    if (text.contains('row-level security') || e.code == '42501') {
      return Exception(
        'Could not access your profile. Please try signing in again.',
      );
    }
    return Exception(e.message);
  }
}
