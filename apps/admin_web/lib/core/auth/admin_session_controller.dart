import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/dashboard/data/admin_models.dart';
import '../../features/dashboard/data/admin_repository.dart';
import 'admin_auth_service.dart';

enum AdminSessionStatus { checking, signedOut, authorized, forbidden, failure }

class AdminSessionController extends ChangeNotifier {
  final AdminAuthService _authService;
  final AdminRepository _repository;

  StreamSubscription<String?>? _authSubscription;
  AdminSessionStatus _status = AdminSessionStatus.checking;
  AdminAccount? _account;
  String? _message;
  bool _isSubmitting = false;
  int _resolveVersion = 0;
  bool _disposed = false;

  AdminSessionController(this._authService, this._repository);

  AdminSessionStatus get status => _status;
  AdminAccount? get account => _account;
  String? get message => _message;
  bool get isSubmitting => _isSubmitting;

  Future<void> initialize() async {
    _authSubscription ??= _authService.userChanges.listen((_) {
      unawaited(resolveSession());
    });
    await resolveSession();
  }

  Future<void> resolveSession() async {
    final version = ++_resolveVersion;
    final userId = _authService.currentUserId;
    if (userId == null) {
      _setState(
        status: AdminSessionStatus.signedOut,
        account: null,
        message: null,
      );
      return;
    }

    _setState(
      status: AdminSessionStatus.checking,
      account: _account,
      message: null,
    );
    try {
      final account = await _repository.findAccount(userId);
      if (version != _resolveVersion || _disposed) return;
      if (account == null) {
        _setState(
          status: AdminSessionStatus.forbidden,
          account: null,
          message: 'This account does not have a BitClass profile.',
        );
      } else if (!account.isAdmin) {
        _setState(
          status: AdminSessionStatus.forbidden,
          account: account,
          message: 'This dashboard is available to administrators only.',
        );
      } else {
        _setState(
          status: AdminSessionStatus.authorized,
          account: account,
          message: null,
        );
      }
    } catch (error) {
      if (version != _resolveVersion || _disposed) return;
      _setState(
        status: AdminSessionStatus.failure,
        account: null,
        message: _friendlyError(error),
      );
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    if (_isSubmitting) return;
    _isSubmitting = true;
    _message = null;
    _notify();
    try {
      await _authService.signIn(email: email, password: password);
      await resolveSession();
    } catch (error) {
      _setState(
        status: AdminSessionStatus.signedOut,
        account: null,
        message: _friendlyError(error),
      );
    } finally {
      _isSubmitting = false;
      _notify();
    }
  }

  Future<void> signOut() async {
    if (_isSubmitting) return;
    _isSubmitting = true;
    _notify();
    try {
      await _authService.signOut();
    } finally {
      _isSubmitting = false;
      _setState(
        status: AdminSessionStatus.signedOut,
        account: null,
        message: null,
      );
    }
  }

  void clearMessage() {
    if (_message == null) return;
    _message = null;
    _notify();
  }

  void _setState({
    required AdminSessionStatus status,
    required AdminAccount? account,
    required String? message,
  }) {
    _status = status;
    _account = account;
    _message = message;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  String _friendlyError(Object error) {
    if (error is AuthException) {
      final message = error.message.toLowerCase();
      if (message.contains('invalid login credentials')) {
        return 'Incorrect email or password.';
      }
      if (message.contains('email not confirmed')) {
        return 'Confirm your email before signing in.';
      }
      return error.message;
    }
    if (error is PostgrestException) {
      return 'Your administrator profile could not be verified.';
    }
    return 'Unable to connect to BitClass. Please try again.';
  }

  @override
  void dispose() {
    _disposed = true;
    _authSubscription?.cancel();
    super.dispose();
  }
}
