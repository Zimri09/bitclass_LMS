import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/environment.dart';
import '../../../../core/errors/app_error.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {}

class _AuthSessionChanged extends AuthEvent {
  final bool hasSession;

  const _AuthSessionChanged({required this.hasSession});

  @override
  List<Object?> get props => [hasSession];
}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;

  const AuthLoginRequested({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class AuthRegisterRequested extends AuthEvent {
  final String email;
  final String password;
  final String role;
  final String? firstName;
  final String? lastName;

  const AuthRegisterRequested({
    required this.email,
    required this.password,
    required this.role,
    this.firstName,
    this.lastName,
  });

  @override
  List<Object?> get props => [email, password, role, firstName, lastName];
}

class AuthLogoutRequested extends AuthEvent {}

class AuthForgotPasswordRequested extends AuthEvent {
  final String email;

  const AuthForgotPasswordRequested({required this.email});

  @override
  List<Object?> get props => [email];
}

class AuthOtpVerificationRequested extends AuthEvent {
  final String token;

  const AuthOtpVerificationRequested(this.token);

  @override
  List<Object?> get props => [token];
}

class AuthOtpResendRequested extends AuthEvent {}

class AuthOtpCancelled extends AuthEvent {}

class AuthPasswordUpdateRequested extends AuthEvent {
  final String password;

  const AuthPasswordUpdateRequested(this.password);

  @override
  List<Object?> get props => [password];
}

class AuthUserUpdated extends AuthEvent {
  final UserModel user;

  const AuthUserUpdated(this.user);

  @override
  List<Object?> get props => [user];
}

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

enum AuthOperation {
  checkingSession,
  signingIn,
  signingUp,
  signingOut,
  resettingPassword,
  updatingPassword,
}

class AuthLoading extends AuthState {
  final AuthOperation operation;

  const AuthLoading(this.operation);

  @override
  List<Object?> get props => [operation];
}

class AuthAuthenticated extends AuthState {
  final UserModel user;

  const AuthAuthenticated(this.user);

  @override
  List<Object?> get props => [user];
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String _message;
  String get message => userFriendlyErrorMessage(_message);

  const AuthError(String message) : _message = message;

  @override
  List<Object?> get props => [_message];
}

enum AuthOtpPurpose { signup, passwordRecovery }

class AuthOtpChallenge extends AuthState {
  final String email;
  final AuthOtpPurpose purpose;
  final DateTime expiresAt;
  final DateTime resendAvailableAt;
  final int attemptsRemaining;
  final bool isVerifying;
  final bool isResending;
  final String? errorMessage;
  final String? successMessage;

  const AuthOtpChallenge({
    required this.email,
    required this.purpose,
    required this.expiresAt,
    required this.resendAvailableAt,
    required this.attemptsRemaining,
    this.isVerifying = false,
    this.isResending = false,
    this.errorMessage,
    this.successMessage,
  });

  bool get isExpired => !DateTime.now().isBefore(expiresAt);
  bool get canAttempt => !isExpired && attemptsRemaining > 0;

  AuthOtpChallenge copyWith({
    DateTime? expiresAt,
    DateTime? resendAvailableAt,
    int? attemptsRemaining,
    bool? isVerifying,
    bool? isResending,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return AuthOtpChallenge(
      email: email,
      purpose: purpose,
      expiresAt: expiresAt ?? this.expiresAt,
      resendAvailableAt: resendAvailableAt ?? this.resendAvailableAt,
      attemptsRemaining: attemptsRemaining ?? this.attemptsRemaining,
      isVerifying: isVerifying ?? this.isVerifying,
      isResending: isResending ?? this.isResending,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess
          ? null
          : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [
    email,
    purpose,
    expiresAt,
    resendAvailableAt,
    attemptsRemaining,
    isVerifying,
    isResending,
    errorMessage,
    successMessage,
  ];
}

class AuthPasswordResetRequired extends AuthState {
  final String email;

  const AuthPasswordResetRequired(this.email);

  @override
  List<Object?> get props => [email];
}

class AuthPasswordResetComplete extends AuthState {}

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  static const otpLifetime = Duration(minutes: 10);
  static const otpResendCooldown = Duration(seconds: 60);
  static const otpMaxAttempts = 5;

  final AuthRepository _authRepository;
  StreamSubscription? _authStateSubscription;
  int _requestGeneration = 0;
  AuthOtpChallenge? _activeOtpChallenge;
  String? _passwordRecoveryEmail;

  AuthBloc({required AuthRepository authRepository})
    : _authRepository = authRepository,
      super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<_AuthSessionChanged>(_onAuthSessionChanged);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthForgotPasswordRequested>(_onForgotPasswordRequested);
    on<AuthOtpVerificationRequested>(_onOtpVerificationRequested);
    on<AuthOtpResendRequested>(_onOtpResendRequested);
    on<AuthOtpCancelled>(_onOtpCancelled);
    on<AuthPasswordUpdateRequested>(_onPasswordUpdateRequested);
    on<AuthUserUpdated>(_onUserUpdated);

    _authStateSubscription = _authRepository.authStateChanges.listen((user) {
      add(_AuthSessionChanged(hasSession: user != null));
    });
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    final currentState = state;
    if (currentState is AuthLoading &&
        currentState.operation == AuthOperation.signingOut) {
      return;
    }

    final requestGeneration = _requestGeneration;
    emit(const AuthLoading(AuthOperation.checkingSession));

    try {
      if (EnvironmentConfig.isDemoMode) {
        final demoUser = _authRepository.demoUser;
        if (!_isCurrent(requestGeneration)) return;
        emit(
          demoUser == null
              ? AuthUnauthenticated()
              : AuthAuthenticated(demoUser),
        );
        return;
      }

      final profile = await _authRepository.restoreCurrentUserProfile();
      if (!_isCurrent(requestGeneration)) return;
      emit(
        profile == null ? AuthUnauthenticated() : AuthAuthenticated(profile),
      );
    } catch (_) {
      if (!_isCurrent(requestGeneration)) return;
      emit(AuthUnauthenticated());
    }
  }

  void _onAuthSessionChanged(
    _AuthSessionChanged event,
    Emitter<AuthState> emit,
  ) {
    final currentState = state;
    if (!event.hasSession) {
      final shouldIgnoreSignedOut =
          currentState is AuthLoading &&
          (currentState.operation == AuthOperation.signingIn ||
              currentState.operation == AuthOperation.signingUp ||
              currentState.operation == AuthOperation.resettingPassword ||
              currentState.operation == AuthOperation.updatingPassword);
      if (shouldIgnoreSignedOut) return;

      _requestGeneration++;
      _clearOtpFlow();
      emit(AuthUnauthenticated());
      return;
    }

    final isHandlingOtp =
        (currentState is AuthOtpChallenge && currentState.isVerifying) ||
        currentState is AuthPasswordResetRequired;
    final shouldIgnoreSessionRefresh =
        currentState is AuthLoading &&
        (currentState.operation == AuthOperation.signingIn ||
            currentState.operation == AuthOperation.signingUp ||
            currentState.operation == AuthOperation.signingOut ||
            currentState.operation == AuthOperation.updatingPassword);
    if (currentState is! AuthAuthenticated &&
        !isHandlingOtp &&
        !shouldIgnoreSessionRefresh) {
      add(AuthCheckRequested());
    }
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    final requestGeneration = ++_requestGeneration;
    emit(const AuthLoading(AuthOperation.signingIn));

    try {
      final user = await _authRepository.signInWithEmailAndPassword(
        email: event.email,
        password: event.password,
      );
      if (!_isCurrent(requestGeneration)) return;
      _clearOtpFlow();
      emit(AuthAuthenticated(user));
    } on EmailConfirmationRequiredException catch (error) {
      if (!_isCurrent(requestGeneration)) return;
      emit(_startOtpChallenge(error.email, AuthOtpPurpose.signup));
    } catch (error) {
      if (!_isCurrent(requestGeneration)) return;
      emit(AuthError(_message(error)));
    }
  }

  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    final requestGeneration = ++_requestGeneration;
    emit(const AuthLoading(AuthOperation.signingUp));

    try {
      final user = await _authRepository.registerWithEmailAndPassword(
        email: event.email,
        password: event.password,
        role: event.role,
        firstName: event.firstName,
        lastName: event.lastName,
      );
      if (!_isCurrent(requestGeneration)) return;
      _clearOtpFlow();
      emit(AuthAuthenticated(user));
    } on EmailConfirmationRequiredException catch (error) {
      if (!_isCurrent(requestGeneration)) return;
      emit(_startOtpChallenge(error.email, AuthOtpPurpose.signup));
    } catch (error) {
      if (!_isCurrent(requestGeneration)) return;
      emit(AuthError(_message(error)));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    final requestGeneration = ++_requestGeneration;
    _clearOtpFlow();
    emit(const AuthLoading(AuthOperation.signingOut));

    try {
      await _authRepository.signOut();
      if (!_isCurrent(requestGeneration)) return;
      emit(AuthUnauthenticated());
    } catch (error) {
      if (!_isCurrent(requestGeneration)) return;
      emit(AuthError(_message(error)));
    }
  }

  Future<void> _onForgotPasswordRequested(
    AuthForgotPasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    final requestGeneration = ++_requestGeneration;
    emit(const AuthLoading(AuthOperation.resettingPassword));

    try {
      await _authRepository.sendPasswordResetEmail(event.email);
      if (!_isCurrent(requestGeneration)) return;
      emit(_startOtpChallenge(event.email, AuthOtpPurpose.passwordRecovery));
    } catch (error) {
      if (!_isCurrent(requestGeneration)) return;
      emit(AuthError(_message(error)));
    }
  }

  Future<void> _onOtpVerificationRequested(
    AuthOtpVerificationRequested event,
    Emitter<AuthState> emit,
  ) async {
    final challenge = _activeOtpChallenge;
    if (challenge == null) {
      emit(const AuthError('Your verification session has expired.'));
      return;
    }
    if (challenge.isExpired) {
      _emitChallenge(
        emit,
        challenge.copyWith(
          errorMessage: 'This code has expired. Request a new code.',
          clearSuccess: true,
        ),
      );
      return;
    }
    if (challenge.attemptsRemaining <= 0) {
      _emitChallenge(
        emit,
        challenge.copyWith(
          errorMessage:
              'Too many invalid attempts. Request a new code to continue.',
          clearSuccess: true,
        ),
      );
      return;
    }

    final requestGeneration = ++_requestGeneration;
    _emitChallenge(
      emit,
      challenge.copyWith(
        isVerifying: true,
        clearError: true,
        clearSuccess: true,
      ),
    );

    try {
      if (challenge.purpose == AuthOtpPurpose.signup) {
        final user = await _authRepository.verifySignupOtp(
          email: challenge.email,
          token: event.token,
        );
        if (!_isCurrent(requestGeneration)) return;
        _clearOtpFlow();
        emit(AuthAuthenticated(user));
      } else {
        await _authRepository.verifyPasswordRecoveryOtp(
          email: challenge.email,
          token: event.token,
        );
        if (!_isCurrent(requestGeneration)) return;
        _passwordRecoveryEmail = challenge.email;
        _activeOtpChallenge = null;
        emit(AuthPasswordResetRequired(challenge.email));
      }
    } catch (error) {
      if (!_isCurrent(requestGeneration)) return;
      final attemptsRemaining = challenge.attemptsRemaining - 1;
      _emitChallenge(
        emit,
        challenge.copyWith(
          attemptsRemaining: attemptsRemaining,
          isVerifying: false,
          errorMessage: attemptsRemaining > 0
              ? _message(error)
              : 'Too many invalid attempts. Request a new code to continue.',
          clearSuccess: true,
        ),
      );
    }
  }

  Future<void> _onOtpResendRequested(
    AuthOtpResendRequested event,
    Emitter<AuthState> emit,
  ) async {
    final challenge = _activeOtpChallenge;
    if (challenge == null) {
      emit(const AuthError('Your verification session has expired.'));
      return;
    }

    final now = DateTime.now();
    if (now.isBefore(challenge.resendAvailableAt)) {
      final seconds = challenge.resendAvailableAt.difference(now).inSeconds + 1;
      _emitChallenge(
        emit,
        challenge.copyWith(
          errorMessage: 'You can request another code in ${seconds}s.',
          clearSuccess: true,
        ),
      );
      return;
    }

    final requestGeneration = ++_requestGeneration;
    _emitChallenge(
      emit,
      challenge.copyWith(
        isResending: true,
        clearError: true,
        clearSuccess: true,
      ),
    );

    try {
      if (challenge.purpose == AuthOtpPurpose.signup) {
        await _authRepository.resendSignupOtp(challenge.email);
      } else {
        await _authRepository.sendPasswordResetEmail(challenge.email);
      }
      if (!_isCurrent(requestGeneration)) return;
      final completedAt = DateTime.now();
      _emitChallenge(
        emit,
        AuthOtpChallenge(
          email: challenge.email,
          purpose: challenge.purpose,
          expiresAt: completedAt.add(otpLifetime),
          resendAvailableAt: completedAt.add(otpResendCooldown),
          attemptsRemaining: otpMaxAttempts,
          successMessage: 'A new verification code was sent.',
        ),
      );
    } catch (error) {
      if (!_isCurrent(requestGeneration)) return;
      _emitChallenge(
        emit,
        challenge.copyWith(
          isResending: false,
          errorMessage: _message(error),
          clearSuccess: true,
        ),
      );
    }
  }

  Future<void> _onPasswordUpdateRequested(
    AuthPasswordUpdateRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (_passwordRecoveryEmail == null) {
      emit(const AuthError('Verify your recovery code before continuing.'));
      return;
    }

    final requestGeneration = ++_requestGeneration;
    emit(const AuthLoading(AuthOperation.updatingPassword));
    try {
      await _authRepository.updatePasswordAfterRecovery(event.password);
      if (!_isCurrent(requestGeneration)) return;
      _passwordRecoveryEmail = null;
      emit(AuthPasswordResetComplete());
    } catch (error) {
      if (!_isCurrent(requestGeneration)) return;
      emit(AuthError(_message(error)));
    }
  }

  void _onOtpCancelled(AuthOtpCancelled event, Emitter<AuthState> emit) {
    _requestGeneration++;
    _clearOtpFlow();
    emit(AuthUnauthenticated());
  }

  void _onUserUpdated(AuthUserUpdated event, Emitter<AuthState> emit) {
    _clearOtpFlow();
    emit(AuthAuthenticated(event.user));
  }

  AuthOtpChallenge _startOtpChallenge(String email, AuthOtpPurpose purpose) {
    final now = DateTime.now();
    final challenge = AuthOtpChallenge(
      email: email.trim().toLowerCase(),
      purpose: purpose,
      expiresAt: now.add(otpLifetime),
      resendAvailableAt: now.add(otpResendCooldown),
      attemptsRemaining: otpMaxAttempts,
    );
    _activeOtpChallenge = challenge;
    _passwordRecoveryEmail = null;
    return challenge;
  }

  void _emitChallenge(Emitter<AuthState> emit, AuthOtpChallenge challenge) {
    _activeOtpChallenge = challenge;
    emit(challenge);
  }

  void _clearOtpFlow() {
    _activeOtpChallenge = null;
    _passwordRecoveryEmail = null;
  }

  static String _message(Object error) => userFriendlyErrorMessage(error);

  bool _isCurrent(int requestGeneration) =>
      requestGeneration == _requestGeneration;

  @override
  Future<void> close() {
    _authStateSubscription?.cancel();
    return super.close();
  }
}
