import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/environment.dart';
import '../models/support_request.dart';

class SupportRepository {
  static const String _table = 'support_requests';

  final SupabaseClient? _supabase;

  SupportRepository({SupabaseClient? supabase})
    : _supabase = EnvironmentConfig.isDemoMode
          ? null
          : (supabase ?? Supabase.instance.client);

  Future<void> submitRequest({
    required String userId,
    required SupportRequestType type,
    required String category,
    required String subject,
    required String description,
    Map<String, dynamic> metadata = const {},
  }) async {
    final normalizedCategory = category.trim();
    final normalizedSubject = subject.trim();
    final normalizedDescription = description.trim();

    if (normalizedSubject.length < 3 || normalizedSubject.length > 160) {
      throw const FormatException('Subject must be between 3 and 160 characters.');
    }
    if (normalizedDescription.length < 10 ||
        normalizedDescription.length > 5000) {
      throw const FormatException(
        'Description must be between 10 and 5000 characters.',
      );
    }

    if (EnvironmentConfig.isDemoMode) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      return;
    }

    await _supabase!.from(_table).insert({
      'user_id': userId,
      'request_type': type.databaseValue,
      'category': normalizedCategory,
      'subject': normalizedSubject,
      'description': normalizedDescription,
      'metadata': metadata,
    });
  }
}
