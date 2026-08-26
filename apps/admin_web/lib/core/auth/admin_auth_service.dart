import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class AdminAuthService {
  String? get currentUserId;

  Stream<String?> get userChanges;

  Future<void> signIn({required String email, required String password});

  Future<void> signOut();
}

class SupabaseAdminAuthService implements AdminAuthService {
  final SupabaseClient _client;

  const SupabaseAdminAuthService(this._client);

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  Stream<String?> get userChanges =>
      _client.auth.onAuthStateChange.map((event) => event.session?.user.id);

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
  }

  @override
  Future<void> signOut() => _client.auth.signOut();
}
