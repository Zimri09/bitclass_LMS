import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/environment.dart';
import '../models/user_model.dart';

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

  /// Get current user's profile from Firestore
  Future<UserModel?> getCurrentUserProfile() async {
    if (EnvironmentConfig.isDemoMode) return _demoUser;

    final user = currentUser;
    if (user == null) return null;

    final row = await _supabase!
        .from(_profilesTable)
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (row == null) return null;

    return UserModel.fromMap(_rowToUserMap(row), user.id);
  }

  /// Sign in with email and password
  Future<UserModel> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    // Demo mode: simulate login
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      final normalizedEmail = email.trim().toLowerCase();
      final isInstructor = normalizedEmail.contains('instructor');
      _demoUser = UserModel(
        id: isInstructor ? _demoInstructorUserId : _demoStudentUserId,
        email: normalizedEmail,
        displayName: isInstructor ? 'Demo Instructor' : 'Demo Student',
        role: isInstructor ? 'instructor' : 'student',
        createdAt: DateTime.now(),
      );
      _demoAuthController.add(null); // Trigger auth state change
      return _demoUser!;
    }

    try {
      final response = await _supabase!.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw Exception('Sign in failed: No user returned');
      }

      var profile = await getCurrentUserProfile();
      profile ??= await _createOrSyncProfileFromAuth(
        user,
        defaultRole: 'student',
        displayName: user.userMetadata?['display_name'] as String?,
      );

      return profile;
    } on AuthException catch (e) {
      throw _handleAuthException(e.message);
    }
  }

  /// Register a new user with email and password
  Future<UserModel> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String role,
    String? displayName,
  }) async {
    // Demo mode: simulate registration
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      _demoUser = UserModel(
        id: 'demo-user-${DateTime.now().millisecondsSinceEpoch}',
        email: email,
        displayName: displayName ?? email.split('@').first,
        role: role,
        createdAt: DateTime.now(),
      );
      _demoAuthController.add(null); // Trigger auth state change
      return _demoUser!;
    }

    try {
      final response = await _supabase!.auth.signUp(
        email: email,
        password: password,
        data: <String, dynamic>{
          'role': role,
          'display_name': displayName ?? email.split('@').first,
        },
      );

      final user = response.user;
      if (user == null) {
        throw Exception('Registration failed: No user returned');
      }

      final profile = await _createOrSyncProfileFromAuth(
        user,
        defaultRole: role,
        displayName: displayName,
      );

      return profile;
    } on AuthException catch (e) {
      throw _handleAuthException(e.message);
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
      return; // Simulate success
    }
    try {
      await _supabase!.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      throw _handleAuthException(e.message);
    }
  }

  /// Update user profile
  Future<UserModel> updateProfile({
    String? displayName,
    String? bio,
    String? avatarUrl,
  }) async {
    // Demo mode: update local demo user
    if (EnvironmentConfig.isDemoMode) {
      if (_demoUser == null) {
        throw Exception('No authenticated user');
      }
      _demoUser = _demoUser!.copyWith(
        displayName: displayName ?? _demoUser!.displayName,
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

    if (displayName != null) updates['display_name'] = displayName;
    if (bio != null) updates['bio'] = bio;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

    await _supabase!.from(_profilesTable).update(updates).eq('id', user.id);

    final profile = await getCurrentUserProfile();
    if (profile == null) {
      throw Exception('Failed to fetch updated profile');
    }

    return profile;
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

  Future<UserModel> _createOrSyncProfileFromAuth(
    User user, {
    required String defaultRole,
    String? displayName,
  }) async {
    final profile = UserModel(
      id: user.id,
      email: user.email ?? '',
      displayName:
          displayName ??
          (user.userMetadata?['display_name'] as String?) ??
          user.email?.split('@').first,
      avatarUrl: user.userMetadata?['avatar_url'] as String?,
      bio: null,
      role: (user.userMetadata?['role'] as String?) ?? defaultRole,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _supabase!.from(_profilesTable).upsert({
      'id': profile.id,
      'email': profile.email,
      'display_name': profile.displayName,
      'avatar_url': profile.avatarUrl,
      'bio': profile.bio,
      'role': profile.role,
      'updated_at': profile.updatedAt?.toIso8601String(),
    }, onConflict: 'id');

    return (await getCurrentUserProfile()) ?? profile;
  }

  Map<String, dynamic> _rowToUserMap(Map<String, dynamic> row) {
    return {
      'email': row['email'] as String,
      'displayName': row['display_name'] as String?,
      'avatarUrl': row['avatar_url'] as String?,
      'bio': row['bio'] as String?,
      'role': row['role'] as String? ?? 'student',
      'createdAt':
          row['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      'updatedAt': row['updated_at']?.toString(),
    };
  }

  /// Handle Supabase Auth exceptions
  Exception _handleAuthException(String? message) {
    final text = message?.toLowerCase() ?? '';
    if (text.contains('invalid login credentials')) {
      return Exception('Invalid email or password');
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
}
