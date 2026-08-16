import 'package:bitclass/core/theme/app_colors.dart';
import 'package:bitclass/features/notifications/data/models/models.dart';
import 'package:bitclass/features/notifications/data/repositories/notification_repository.dart';
import 'package:bitclass/features/notifications/presentation/bloc/notification_bloc.dart';
import 'package:bitclass/features/notifications/presentation/bloc/notification_event.dart';
import 'package:bitclass/features/notifications/presentation/bloc/notification_state.dart';
import 'package:bitclass/features/notifications/presentation/screens/notification_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('unread dot is red and disappears after notification is read', (
    tester,
  ) async {
    final repository = _FakeNotificationRepository();
    final bloc = NotificationBloc(notificationRepository: repository)
      ..add(const LoadNotifications(userId: 'user-1'));

    addTearDown(() async {
      await bloc.close();
      repository.close();
    });

    await tester.pumpWidget(
      BlocProvider<NotificationBloc>.value(
        value: bloc,
        child: const MaterialApp(
          home: NotificationListView(userId: 'user-1', isInstructor: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final indicatorKey = const Key(
      'notification-unread-indicator-notification-1',
    );
    final indicator = tester.widget<Container>(find.byKey(indicatorKey));
    final decoration = indicator.decoration! as BoxDecoration;

    expect(decoration.color, AppColors.error);

    await tester.tap(find.text('New lesson'));
    await tester.pumpAndSettle();

    expect(repository.markAsReadCalls, 1);
    expect(find.byKey(indicatorKey), findsNothing);

    final reloadedBloc = NotificationBloc(notificationRepository: repository)
      ..add(const LoadNotifications(userId: 'user-1'));
    addTearDown(reloadedBloc.close);

    final reloadedState =
        await reloadedBloc.stream.firstWhere(
              (state) => state is NotificationsLoaded,
            )
            as NotificationsLoaded;
    expect(reloadedState.notifications.single.isRead, isTrue);
    expect(reloadedState.unreadCount, 0);
  });
}

class _FakeNotificationRepository extends NotificationRepository {
  final SupabaseClient _client;
  NotificationModel _notification = NotificationModel(
    id: 'notification-1',
    userId: 'user-1',
    type: NotificationType.newLesson,
    title: 'New lesson',
    body: 'A new lesson is ready.',
    createdAt: DateTime.utc(2026, 8, 16),
  );
  int markAsReadCalls = 0;

  factory _FakeNotificationRepository() {
    final client = SupabaseClient('http://localhost:54321', 'test-anon-key');
    client.auth.stopAutoRefresh();
    return _FakeNotificationRepository._(client);
  }

  _FakeNotificationRepository._(this._client) : super(supabase: _client);

  @override
  Future<List<NotificationModel>> getNotifications(String userId) async => [
    _notification,
  ];

  @override
  Future<int> getUnreadCount(String userId) async =>
      _notification.isRead ? 0 : 1;

  @override
  Future<NotificationModel> markAsRead(String notificationId) async {
    markAsReadCalls++;
    _notification = _notification.copyWith(isRead: true);
    return _notification;
  }

  void close() {
    dispose();
    _client.auth.dispose();
  }
}
