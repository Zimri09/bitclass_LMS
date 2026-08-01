import 'dart:async';
import 'dart:io';

import 'package:bitclass/features/auth/data/models/user_model.dart';
import 'package:bitclass/features/auth/data/repositories/auth_repository.dart';
import 'package:bitclass/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:bitclass/features/auth/presentation/screens/login_screen.dart';
import 'package:bitclass/features/auth/presentation/screens/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('logout reset', () {
    test(
      'cached account remains available when profile refresh is offline',
      () async {
        final repository = _FakeAuthRepository()
          ..sessionSnapshot = _testUser
          ..profileError = const SocketException('Failed host lookup');
        final bloc = AuthBloc(authRepository: repository);
        addTearDown(() async {
          await bloc.close();
          await repository.dispose();
        });

        bloc.add(AuthCheckRequested());
        final restored =
            await bloc.stream.firstWhere(
                  (state) => state is AuthAuthenticated && state.isOffline,
                )
                as AuthAuthenticated;

        expect(restored.user, _testUser);
        expect(restored.isOffline, isTrue);
      },
    );

    test(
      'server profile replaces the offline snapshot after restore',
      () async {
        final updatedUser = _testUser.copyWith(firstName: 'Updated');
        final profileCompleter = Completer<UserModel?>()..complete(updatedUser);
        final repository = _FakeAuthRepository()
          ..sessionSnapshot = _testUser
          ..profileCompleter = profileCompleter;
        final bloc = AuthBloc(authRepository: repository);
        addTearDown(() async {
          await bloc.close();
          await repository.dispose();
        });

        bloc.add(AuthCheckRequested());
        final restored =
            await bloc.stream.firstWhere(
                  (state) => state is AuthAuthenticated && !state.isOffline,
                )
                as AuthAuthenticated;

        expect(restored.user.firstName, 'Updated');
        expect(restored.isOffline, isFalse);
      },
    );

    testWidgets(
      'sign in and sign up remain enabled while logout is finishing',
      (tester) async {
        final repository = _FakeAuthRepository();
        await tester.pump(const Duration(milliseconds: 1));
        final logoutCompleter = Completer<void>();
        repository.logoutCompleter = logoutCompleter;
        final bloc = AuthBloc(authRepository: repository);
        addTearDown(() async {
          if (!logoutCompleter.isCompleted) logoutCompleter.complete();
          await bloc.close();
          await repository.dispose();
        });

        bloc.add(AuthUserUpdated(_testUser));
        await bloc.stream.firstWhere((state) => state is AuthAuthenticated);

        bloc.add(AuthLogoutRequested());
        await bloc.stream.firstWhere(
          (state) =>
              state is AuthLoading &&
              state.operation == AuthOperation.signingOut,
        );

        await tester.pumpWidget(
          MaterialApp(
            builder: _compactTestText,
            home: BlocProvider<AuthBloc>.value(
              value: bloc,
              child: const LoginScreen(),
            ),
          ),
        );
        final signInButton = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Sign In'),
        );
        expect(signInButton.onPressed, isNotNull);

        await tester.pumpWidget(
          MaterialApp(
            builder: _compactTestText,
            home: BlocProvider<AuthBloc>.value(
              value: bloc,
              child: const RegisterScreen(),
            ),
          ),
        );
        final signUpButton = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Create Account'),
        );
        expect(signUpButton.onPressed, isNotNull);

        logoutCompleter.complete();
        await bloc.stream.firstWhere((state) => state is AuthUnauthenticated);
      },
    );

    test(
      'a profile request started before logout cannot restore the session',
      () async {
        final repository = _FakeAuthRepository();
        final profileCompleter = Completer<UserModel?>();
        repository.profileCompleter = profileCompleter;
        final bloc = AuthBloc(authRepository: repository);
        addTearDown(() async {
          await bloc.close();
          await repository.dispose();
        });

        bloc.add(AuthCheckRequested());
        await bloc.stream.firstWhere(
          (state) =>
              state is AuthLoading &&
              state.operation == AuthOperation.checkingSession,
        );

        bloc.add(AuthLogoutRequested());
        await bloc.stream.firstWhere((state) => state is AuthUnauthenticated);

        profileCompleter.complete(_testUser);
        await Future<void>.delayed(Duration.zero);

        expect(bloc.state, isA<AuthUnauthenticated>());
      },
    );
  });
}

Widget _compactTestText(BuildContext context, Widget? child) {
  return MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: const TextScaler.linear(0.8)),
    child: child!,
  );
}

final _testUser = UserModel(
  id: 'user-1',
  email: 'student@example.com',
  firstName: 'Test',
  lastName: 'Student',
  role: 'student',
  createdAt: DateTime.utc(2026, 7, 29),
);

class _FakeAuthRepository extends AuthRepository {
  final SupabaseClient _client;
  final _authController = StreamController<User?>.broadcast();
  Completer<void>? logoutCompleter;
  Completer<UserModel?>? profileCompleter;
  UserModel? sessionSnapshot;
  Object? profileError;
  bool sessionAvailable = true;

  factory _FakeAuthRepository() {
    return _FakeAuthRepository._(
      SupabaseClient('http://localhost:54321', 'test-anon-key'),
    );
  }

  _FakeAuthRepository._(this._client) : super(supabase: _client) {
    _client.auth.stopAutoRefresh();
  }

  @override
  Stream<User?> get authStateChanges => _authController.stream;

  @override
  bool get hasCurrentSession => sessionAvailable;

  @override
  Future<UserModel?> restoreSessionSnapshot() async => sessionSnapshot;

  @override
  Future<UserModel?> getCurrentUserProfile() =>
      profileCompleter?.future ?? Future<UserModel?>.value(null);

  @override
  Future<UserModel?> restoreCurrentUserProfile() {
    final error = profileError;
    if (error != null) return Future<UserModel?>.error(error);
    return profileCompleter?.future ?? Future<UserModel?>.value(null);
  }

  @override
  Future<void> signOut() => logoutCompleter?.future ?? Future<void>.value();

  Future<void> dispose() async {
    _client.auth.dispose();
    await _authController.close();
  }
}
