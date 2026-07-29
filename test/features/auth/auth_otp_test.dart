import 'dart:async';

import 'package:bitclass/features/auth/data/models/user_model.dart';
import 'package:bitclass/features/auth/data/repositories/auth_repository.dart';
import 'package:bitclass/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('email OTP authentication', () {
    test('registration requires a signup OTP before authentication', () async {
      final repository = _OtpAuthRepository();
      final bloc = AuthBloc(authRepository: repository);
      addTearDown(() async {
        await bloc.close();
        await repository.dispose();
      });

      bloc.add(
        const AuthRegisterRequested(
          email: 'Student@Example.com',
          password: 'password123',
          role: 'student',
          firstName: 'Test',
          lastName: 'Student',
        ),
      );

      final state =
          await bloc.stream.firstWhere((state) => state is AuthOtpChallenge)
              as AuthOtpChallenge;

      expect(state.email, 'student@example.com');
      expect(state.purpose, AuthOtpPurpose.signup);
      expect(state.attemptsRemaining, AuthBloc.otpMaxAttempts);
      expect(bloc.state, isNot(isA<AuthAuthenticated>()));
    });

    test(
      'invalid signup codes consume an attempt and keep access blocked',
      () async {
        final repository = _OtpAuthRepository()
          ..signupVerificationError = Exception('Invalid verification code.');
        final bloc = AuthBloc(authRepository: repository);
        addTearDown(() async {
          await bloc.close();
          await repository.dispose();
        });

        bloc.add(
          const AuthRegisterRequested(
            email: 'student@example.com',
            password: 'password123',
            role: 'student',
            firstName: 'Test',
            lastName: 'Student',
          ),
        );
        await bloc.stream.firstWhere((state) => state is AuthOtpChallenge);

        bloc.add(const AuthOtpVerificationRequested('111111'));
        final failed =
            await bloc.stream.firstWhere(
                  (state) =>
                      state is AuthOtpChallenge &&
                      !state.isVerifying &&
                      state.attemptsRemaining == AuthBloc.otpMaxAttempts - 1,
                )
                as AuthOtpChallenge;

        expect(failed.errorMessage, 'Invalid verification code.');
        expect(bloc.state, isNot(isA<AuthAuthenticated>()));
      },
    );

    test(
      'valid signup OTP restores the trigger-created role profile',
      () async {
        final repository = _OtpAuthRepository();
        final bloc = AuthBloc(authRepository: repository);
        addTearDown(() async {
          await bloc.close();
          await repository.dispose();
        });

        bloc.add(
          const AuthRegisterRequested(
            email: 'instructor@example.com',
            password: 'password123',
            role: 'instructor',
            firstName: 'Course',
            lastName: 'Instructor',
          ),
        );
        await bloc.stream.firstWhere((state) => state is AuthOtpChallenge);

        bloc.add(const AuthOtpVerificationRequested('123456'));
        final authenticated =
            await bloc.stream.firstWhere((state) => state is AuthAuthenticated)
                as AuthAuthenticated;

        expect(authenticated.user.role, 'instructor');
        expect(repository.lastSignupOtp, '123456');
      },
    );

    test('recovery OTP must be verified before password update', () async {
      final repository = _OtpAuthRepository();
      final bloc = AuthBloc(authRepository: repository);
      addTearDown(() async {
        await bloc.close();
        await repository.dispose();
      });

      bloc.add(const AuthForgotPasswordRequested(email: 'student@example.com'));
      final challenge =
          await bloc.stream.firstWhere((state) => state is AuthOtpChallenge)
              as AuthOtpChallenge;
      expect(challenge.purpose, AuthOtpPurpose.passwordRecovery);

      bloc.add(const AuthOtpVerificationRequested('123456'));
      await bloc.stream.firstWhere(
        (state) => state is AuthPasswordResetRequired,
      );

      bloc.add(const AuthPasswordUpdateRequested('newpassword123'));
      await bloc.stream.firstWhere(
        (state) => state is AuthPasswordResetComplete,
      );

      expect(repository.passwordResetRequests, 1);
      expect(repository.lastRecoveryOtp, '123456');
      expect(repository.updatedPassword, 'newpassword123');
    });
  });
}

final _student = UserModel(
  id: 'student-1',
  email: 'student@example.com',
  firstName: 'Test',
  lastName: 'Student',
  role: 'student',
  createdAt: DateTime.utc(2026, 7, 29),
);

final _instructor = UserModel(
  id: 'instructor-1',
  email: 'instructor@example.com',
  firstName: 'Course',
  lastName: 'Instructor',
  role: 'instructor',
  createdAt: DateTime.utc(2026, 7, 29),
);

class _OtpAuthRepository extends AuthRepository {
  final SupabaseClient _client;
  final _authController = StreamController<User?>.broadcast();
  Object? signupVerificationError;
  String? lastSignupOtp;
  String? lastRecoveryOtp;
  String? updatedPassword;
  int passwordResetRequests = 0;

  factory _OtpAuthRepository() {
    return _OtpAuthRepository._(
      SupabaseClient('http://localhost:54321', 'test-anon-key'),
    );
  }

  _OtpAuthRepository._(this._client) : super(supabase: _client) {
    _client.auth.stopAutoRefresh();
  }

  @override
  Stream<User?> get authStateChanges => _authController.stream;

  @override
  Future<UserModel> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String role,
    String? firstName,
    String? lastName,
  }) {
    throw EmailConfirmationRequiredException(email.trim().toLowerCase());
  }

  @override
  Future<UserModel> verifySignupOtp({
    required String email,
    required String token,
  }) async {
    lastSignupOtp = token;
    final error = signupVerificationError;
    if (error != null) throw error;
    return email.startsWith('instructor') ? _instructor : _student;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    passwordResetRequests++;
  }

  @override
  Future<void> verifyPasswordRecoveryOtp({
    required String email,
    required String token,
  }) async {
    lastRecoveryOtp = token;
  }

  @override
  Future<void> updatePasswordAfterRecovery(String newPassword) async {
    updatedPassword = newPassword;
  }

  Future<void> dispose() async {
    _client.auth.dispose();
    await _authController.close();
  }
}
