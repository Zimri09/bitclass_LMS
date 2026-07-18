import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/environment.dart';
import '../models/user_model.dart';

/// Thrown when sign-up succeeds but the user must confirm their email first.
class EmailConfirmationRequiredException implements Exception {
  final String email;

  const EmailConfirmationRequiredException(this.email);

  @override
  String toString() => 'Please confirm your email before signing in.';
}

/// Repository handling authentication and user profile operations
class AuthRepository {
  static const String _profilesTable = 'profiles';

  final SupabaseClient? _supabase;

  static const String _demoStudentUserId = 'demo-user-1';
  static const String _demoInstructorUserId = 'demo-instructor-1';

  // Demo mode state
  UserModel? _demoUser;
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

  /// Get demo user (for demo mode)
  UserModel? get demoUser => _demoUser;

  /// Get current user's profile
  Future<UserModel?> getCurrentUserProfile() async {
    if (EnvironmentConfig.isDemoMode) return _demoUser;

    final user = currentUser;
    if (user == null) return null;

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
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      final normalizedEmail = email.trim().toLowerCase();
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
        email: email.trim(),
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw Exception('Sign in failed: No user returned');
      }

      return await _resolveProfileForUser(
        user,
        defaultRole: 'student',
        firstName: user.userMetadata?['first_name'] as String?,
        lastName: user.userMetadata?['last_name'] as String?,
      );
    } on AuthException catch (e) {
      throw _handleAuthException(e.message);
    } on PostgrestException catch (e) {
      throw _handlePostgrestException(e);
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
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      _demoUser = UserModel(
        id: 'demo-user-${DateTime.now().millisecondsSinceEpoch}',
        email: email.trim(),
        firstName: firstName ?? email.split('@').first,
        lastName: lastName,
        role: role,
        createdAt: DateTime.now(),
      );
      _demoAuthController.add(null);
      return _demoUser!;
    }

    final normalizedEmail = email.trim();

    try {
      final response = await _supabase!.auth.signUp(
        email: normalizedEmail,
        password: password,
        data: <String, dynamic>{
          'role': role,
          'first_name': firstName ?? normalizedEmail.split('@').first,
          if (lastName != null) 'last_name': lastName,
        },
      );

      final user = response.user;
      if (user == null) {
        throw Exception('Registration failed: No user returned');
      }

      // Email confirmation enabled: no session yet, profile is created by DB trigger.
      if (response.session == null) {
        throw EmailConfirmationRequiredException(
          user.email ?? normalizedEmail,
        );
      }

      return await _resolveProfileForUser(
        user,
        defaultRole: role,
        firstName: firstName,
        lastName: lastName,
      );
    } on EmailConfirmationRequiredException {
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
    await _supabase!.auth.signOut();
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      return;
    }
    try {
      await _supabase!.auth.resetPasswordForEmail(email.trim());
    } on AuthException catch (e) {
      throw _handleAuthException(e.message);
    }
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

      return profile;
    } on PostgrestException catch (e) {
      throw _handlePostgrestException(e);
    }
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
      await _supabase!.auth.signOut();
    }
  }

  Future<UserModel> _resolveProfileForUser(
    User user, {
    required String defaultRole,
    String? firstName,
    String? lastName,
  }) async {
    var profile = await getCurrentUserProfile();
    if (profile != null) return profile;

    // Brief pause so the handle_new_user trigger can finish on fresh sign-ups.
    await Future.delayed(const Duration(milliseconds: 300));
    profile = await getCurrentUserProfile();
    if (profile != null) return profile;

    return _createOrSyncProfileFromAuth(
      user,
      defaultRole: defaultRole,
      firstName: firstName,
      lastName: lastName,
    );
  }

  Future<UserModel> _createOrSyncProfileFromAuth(
    User user, {
    required String defaultRole,
    String? firstName,
    String? lastName,
  }) async {
    final profile = UserModel(
      id: user.id,
      email: user.email ?? '',
      firstName:
          firstName ??
          (user.userMetadata?['first_name'] as String?) ??
          user.email?.split('@').first,
      lastName:
          lastName ?? (user.userMetadata?['last_name'] as String?),
      avatarUrl: user.userMetadata?['avatar_url'] as String?,
      bio: null,
      role: (user.userMetadata?['role'] as String?) ?? defaultRole,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      await _supabase!.from(_profilesTable).upsert({
        'id': profile.id,
        'email': profile.email,
        'first_name': profile.firstName,
        'last_name': profile.lastName,
        'avatar_url': profile.avatarUrl,
        'bio': profile.bio,
        'role': profile.role,
        'updated_at': profile.updatedAt?.toIso8601String(),
      }, onConflict: 'id');

      return (await getCurrentUserProfile()) ?? profile;
    } on PostgrestException catch (e) {
      throw _handlePostgrestException(e);
    }
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
