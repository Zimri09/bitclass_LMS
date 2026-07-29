import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/environment.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';

// Events
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

class AuthUserUpdated extends AuthEvent {
  final UserModel user;

  const AuthUserUpdated(this.user);

  @override
  List<Object?> get props => [user];
}

// States
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
  final String message;

  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}

class AuthPasswordResetSent extends AuthState {
  final String email;

  const AuthPasswordResetSent(this.email);

  @override
  List<Object?> get props => [email];
}

class AuthEmailConfirmationPending extends AuthState {
  final String email;

  const AuthEmailConfirmationPending(this.email);

  @override
  List<Object?> get props => [email];
}

// Bloc
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  StreamSubscription? _authStateSubscription;
  int _requestGeneration = 0;

  AuthBloc({required AuthRepository authRepository})
    : _authRepository = authRepository,
      super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<_AuthSessionChanged>(_onAuthSessionChanged);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthForgotPasswordRequested>(_onForgotPasswordRequested);
    on<AuthUserUpdated>(_onUserUpdated);

    // Keep auth state in sync with Supabase session changes.
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
      // In demo mode, check for demo user
      if (EnvironmentConfig.isDemoMode) {
        final demoUser = _authRepository.demoUser;
        if (!_isCurrent(requestGeneration)) return;
        if (demoUser != null) {
          emit(AuthAuthenticated(demoUser));
        } else {
          emit(AuthUnauthenticated());
        }
        return;
      }

      final profile = await _authRepository.getCurrentUserProfile();
      if (!_isCurrent(requestGeneration)) return;
      if (profile != null) {
        emit(AuthAuthenticated(profile));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      if (!_isCurrent(requestGeneration)) return;
      emit(AuthUnauthenticated());
    }
  }

  void _onAuthSessionChanged(
    _AuthSessionChanged event,
    Emitter<AuthState> emit,
  ) {
    if (!event.hasSession) {
      final currentState = state;
      final isSubmittingCredentials =
          currentState is AuthLoading &&
          (currentState.operation == AuthOperation.signingIn ||
              currentState.operation == AuthOperation.signingUp ||
              currentState.operation == AuthOperation.resettingPassword);
      if (isSubmittingCredentials) {
        return;
      }

      _requestGeneration++;
      emit(AuthUnauthenticated());
      return;
    }

    final currentState = state;
    final shouldIgnoreSessionRefresh =
        currentState is AuthLoading &&
        (currentState.operation == AuthOperation.signingIn ||
            currentState.operation == AuthOperation.signingUp ||
            currentState.operation == AuthOperation.signingOut);
    if (currentState is! AuthAuthenticated && !shouldIgnoreSessionRefresh) {
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
      emit(AuthAuthenticated(user));
    } catch (e) {
      if (!_isCurrent(requestGeneration)) return;
      emit(AuthError(e.toString().replaceFirst('Exception: ', '')));
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
      emit(AuthAuthenticated(user));
    } on EmailConfirmationRequiredException catch (e) {
      if (!_isCurrent(requestGeneration)) return;
      emit(AuthEmailConfirmationPending(e.email));
    } catch (e) {
      if (!_isCurrent(requestGeneration)) return;
      emit(AuthError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    final requestGeneration = ++_requestGeneration;
    emit(const AuthLoading(AuthOperation.signingOut));

    try {
      await _authRepository.signOut();
      if (!_isCurrent(requestGeneration)) return;
      emit(AuthUnauthenticated());
    } catch (e) {
      if (!_isCurrent(requestGeneration)) return;
      emit(AuthError(e.toString().replaceFirst('Exception: ', '')));
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
      emit(AuthPasswordResetSent(event.email));
    } catch (e) {
      if (!_isCurrent(requestGeneration)) return;
      emit(AuthError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  void _onUserUpdated(AuthUserUpdated event, Emitter<AuthState> emit) {
    emit(AuthAuthenticated(event.user));
  }

  bool _isCurrent(int requestGeneration) =>
      requestGeneration == _requestGeneration;

  @override
  Future<void> close() {
    _authStateSubscription?.cancel();
    return super.close();
  }
}
