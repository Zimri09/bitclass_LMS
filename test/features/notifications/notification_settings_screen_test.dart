import 'package:bitclass/features/notifications/data/models/models.dart';
import 'package:bitclass/features/notifications/data/repositories/notification_repository.dart';
import 'package:bitclass/features/notifications/presentation/bloc/notification_bloc.dart';
import 'package:bitclass/features/notifications/presentation/bloc/notification_event.dart';
import 'package:bitclass/features/notifications/presentation/screens/notification_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('a save failure keeps the loaded settings visible', (
    tester,
  ) async {
    final repository = _FailingSettingsRepository();
    final bloc = NotificationBloc(notificationRepository: repository);

    addTearDown(() async {
      await bloc.close();
      repository.close();
    });

    await tester.pumpWidget(
      BlocProvider<NotificationBloc>.value(
        value: bloc,
        child: const MaterialApp(
          home: NotificationSettingsView(
            userId: 'user-1',
            isInstructor: false,
          ),
        ),
      ),
    );
    bloc.add(const LoadNotificationSettings(userId: 'user-1'));
    await tester.pumpAndSettle();

    expect(find.text('Notification Types'), findsOneWidget);
    expect(find.text('Enable Push Notifications'), findsOneWidget);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    expect(find.text('Notification Types'), findsOneWidget);
    expect(find.text('Enable Push Notifications'), findsOneWidget);
    expect(
      find.text('Could not save notification settings. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('PostgrestException'), findsNothing);
  });
}

class _FailingSettingsRepository extends NotificationRepository {
  final SupabaseClient _client;

  factory _FailingSettingsRepository() {
    final client = SupabaseClient('http://localhost:54321', 'test-anon-key');
    client.auth.stopAutoRefresh();
    return _FailingSettingsRepository._(client);
  }

  _FailingSettingsRepository._(this._client) : super(supabase: _client);

  @override
  Future<NotificationSettings> getSettings(String userId) async {
    return NotificationSettings.defaults(userId);
  }

  @override
  Future<NotificationSettings> togglePushEnabled(
    String userId,
    bool enabled,
  ) {
    throw Exception('duplicate key violates notification_settings_user_id_key');
  }

  void close() {
    dispose();
    _client.auth.dispose();
  }
}
