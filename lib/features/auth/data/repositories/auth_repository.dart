import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/config/environment.dart';
import '../../../../core/constants/app_constants.dart';
import '../models/user_model.dart';

/// Repository handling authentication and user profile operations
class AuthRepository {
  final FirebaseAuth? _firebaseAuth;
  final FirebaseFirestore? _firestore;

  static const String _demoStudentUserId = 'demo-user-1';
  static const String _demoInstructorUserId = 'demo-instructor-1';

  // Demo mode state
  UserModel? _demoUser;
  final _demoAuthController = StreamController<User?>.broadcast();

  AuthRepository({FirebaseAuth? firebaseAuth, FirebaseFirestore? firestore})
    : _firebaseAuth = EnvironmentConfig.isDemoMode
          ? null
          : (firebaseAuth ?? FirebaseAuth.instance),
      _firestore = EnvironmentConfig.isDemoMode
          ? null
          : (firestore ?? FirebaseFirestore.instance);

  /// Stream of authentication state changes
  Stream<User?> get authStateChanges => EnvironmentConfig.isDemoMode
      ? _demoAuthController.stream
      : _firebaseAuth!.authStateChanges();

  /// Get current Firebase user
  User? get currentUser =>
      EnvironmentConfig.isDemoMode ? null : _firebaseAuth!.currentUser;

  /// Get demo user (for demo mode)
  UserModel? get demoUser => _demoUser;

  /// Get current user's profile from Firestore
  Future<UserModel?> getCurrentUserProfile() async {
    if (EnvironmentConfig.isDemoMode) return _demoUser;

    final user = currentUser;
    if (user == null) return null;

    final doc = await _firestore!
        .collection(FirestorePaths.users)
        .doc(user.uid)
        .get();

    if (!doc.exists) return null;

    return UserModel.fromMap(doc.data()!, doc.id);
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
      final credential = await _firebaseAuth!.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw Exception('Sign in failed: No user returned');
      }

      // Fetch user profile from Firestore
      var profile = await getCurrentUserProfile();

      // If profile doesn't exist, create it (user was created via Firebase Console)
      if (profile == null) {
        profile = UserModel.create(
          id: user.uid,
          email: user.email ?? email,
          role: 'student', // Default role for users created outside the app
          displayName: user.displayName,
        );

        await _firestore!
            .collection(FirestorePaths.users)
            .doc(user.uid)
            .set(profile.toMap());
      }

      return profile;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
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
      // Create Firebase Auth user
      final credential = await _firebaseAuth!.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw Exception('Registration failed: No user returned');
      }

      // Create user profile in Firestore
      final userModel = UserModel.create(
        id: user.uid,
        email: email,
        role: role,
        displayName: displayName,
      );

      await _firestore!
          .collection(FirestorePaths.users)
          .doc(user.uid)
          .set(userModel.toMap());

      return userModel;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Sign out
  Future<void> signOut() async {
    if (EnvironmentConfig.isDemoMode) {
      _demoUser = null;
      _demoAuthController.add(null);
      return;
    }
    await _firebaseAuth!.signOut();
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      return; // Simulate success
    }
    try {
      await _firebaseAuth!.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
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
      'updatedAt': DateTime.now().toIso8601String(),
    };

    if (displayName != null) updates['displayName'] = displayName;
    if (bio != null) updates['bio'] = bio;
    if (avatarUrl != null) updates['avatarUrl'] = avatarUrl;

    await _firestore!
        .collection(FirestorePaths.users)
        .doc(user.uid)
        .update(updates);

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

    // Delete user document from Firestore
    await _firestore!.collection(FirestorePaths.users).doc(user.uid).delete();

    // Delete Firebase Auth user
    await user.delete();
  }

  /// Handle Firebase Auth exceptions
  Exception _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return Exception('No account found with this email');
      case 'wrong-password':
        return Exception('Invalid password');
      case 'email-already-in-use':
        return Exception('An account already exists with this email');
      case 'weak-password':
        return Exception('Password is too weak');
      case 'invalid-email':
        return Exception('Invalid email address');
      case 'user-disabled':
        return Exception('This account has been disabled');
      case 'too-many-requests':
        return Exception('Too many attempts. Please try again later');
      default:
        return Exception(e.message ?? 'Authentication failed');
    }
  }
}
