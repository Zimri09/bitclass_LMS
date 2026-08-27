import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/environment.dart';
import '../../../../core/errors/app_error.dart';
import '../models/code_execution_language.dart';
import '../models/code_execution_result.dart';

abstract class CodeExecutionRepository {
  static const int maxSourceBytes = 20 * 1024;
  static const int maxStdinBytes = 8 * 1024;

  Future<CodeExecutionResult> execute({
    required CodeExecutionLanguage language,
    required String source,
    required String stdin,
  });
}

class SupabaseCodeExecutionRepository implements CodeExecutionRepository {
  final SupabaseClient? _supabase;

  SupabaseCodeExecutionRepository({SupabaseClient? supabase})
    : _supabase = EnvironmentConfig.isDemoMode
          ? null
          : (supabase ?? Supabase.instance.client);

  @override
  Future<CodeExecutionResult> execute({
    required CodeExecutionLanguage language,
    required String source,
    required String stdin,
  }) async {
    final sourceBytes = utf8.encode(source);
    final stdinBytes = utf8.encode(stdin);
    if (source.trim().isEmpty) {
      throw CodeExecutionException(
        'Enter ${language.displayName} code before running.',
      );
    }
    if (sourceBytes.length > CodeExecutionRepository.maxSourceBytes) {
      throw CodeExecutionException(
        '${language.displayName} source must be 20 KB or less.',
      );
    }
    if (stdinBytes.length > CodeExecutionRepository.maxStdinBytes) {
      throw const CodeExecutionException('Program input must be 8 KB or less.');
    }
    if (EnvironmentConfig.isDemoMode || _supabase == null) {
      throw const CodeExecutionException(
        'Code execution requires the secure runner service.',
      );
    }
    if (_supabase.auth.currentSession == null) {
      throw const CodeExecutionException('Sign in again before running code.');
    }

    try {
      final response = await _supabase.functions
          .invoke(
            'execute-code',
            body: {
              'language': language.name,
              'source': source,
              'stdin': stdin,
            },
          )
          .timeout(const Duration(seconds: 12));

      if (response.status < 200 || response.status >= 300) {
        throw CodeExecutionException(_errorMessage(response.data));
      }
      if (response.data is! Map) {
        throw const CodeExecutionException(
          'The code runner returned an invalid response.',
        );
      }
      return CodeExecutionResult.fromMap(
        Map<String, dynamic>.from(response.data as Map),
      );
    } on TimeoutException {
      throw const CodeExecutionException(
        'The code runner did not respond in time.',
      );
    } on FunctionException catch (error) {
      throw CodeExecutionException(_errorMessage(error.details));
    } on CodeExecutionException {
      rethrow;
    } catch (error) {
      throw CodeExecutionException(
        userFriendlyErrorMessage(
          error,
          fallback: 'Could not run the ${language.displayName} program.',
        ),
      );
    }
  }

  String _errorMessage(Object? details) {
    if (details is Map) {
      final message = details['error'] ?? details['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }
    if (details is String && details.trim().isNotEmpty) return details.trim();
    return 'Could not run the program.';
  }
}

class CodeExecutionException implements Exception {
  final String message;

  const CodeExecutionException(this.message);

  @override
  String toString() => message;
}
