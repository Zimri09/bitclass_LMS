import 'package:bitclass/features/messaging/data/models/message_model.dart';
import 'package:bitclass/features/messaging/data/repositories/messaging_repository.dart';
import 'package:bitclass/features/messaging/presentation/screens/conversation_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  for (final width in [320.0, 1000.0]) {
    testWidgets('own messages expose both unsend options at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _MessagingRepository(ownMessage: true);
      await _pumpConversation(tester, repository);
      await tester.tap(find.byTooltip('Message options'));
      await tester.pumpAndSettle();
      expect(find.text('Unsend for You'), findsOneWidget);
      expect(find.text('Unsend for Everyone'), findsOneWidget);
      expect(find.text('Edit message'), findsNothing); // Old message.
      await tester.tap(find.text('Unsend for Everyone'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(repository.unsentForEveryone, isFalse);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome'), findsOneWidget);
      await tester.tap(find.byTooltip('Message options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unsend for Everyone'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Unsend for Everyone'),
      );
      await tester.pumpAndSettle();
      expect(repository.unsentForEveryone, isTrue);
      expect(find.text('Welcome'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'hide for you needs no global confirmation and survives reopening',
    (tester) async {
      final repository = _MessagingRepository(ownMessage: true);
      await _pumpConversation(tester, repository);
      await tester.tap(find.byTooltip('Message options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unsend for You'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(repository.hiddenForYou, isTrue);
      expect(repository.unsentForEveryone, isFalse);
      expect(find.text('Welcome'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await _pumpConversation(tester, repository);
      expect(find.text('Welcome'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'received messages have no menu and realtime removes unsent messages',
    (tester) async {
      final repository = _MessagingRepository();
      await _pumpConversation(tester, repository);
      expect(find.byTooltip('Message options'), findsNothing);
      await tester.longPress(find.text('Welcome'));
      await tester.pumpAndSettle();
      expect(find.text('Unsend for You'), findsNothing);
      repository.unsentForEveryone = true;
      repository.onChanged!();
      await tester.pumpAndSettle();
      expect(find.text('Welcome'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('failed unsend keeps the message available for retry', (
    tester,
  ) async {
    final repository = _MessagingRepository(ownMessage: true)
      ..failUnsend = true;
    await _pumpConversation(tester, repository);
    await tester.tap(find.byTooltip('Message options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unsend for You'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome'), findsOneWidget);
    expect(find.textContaining('Unable to unsend message:'), findsOneWidget);
    expect(repository.hiddenForYou, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  for (final width in [320.0, 1000.0]) {
    testWidgets('emoji shortcuts insert and send normal messages at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _MessagingRepository();
      await tester.pumpWidget(
        RepositoryProvider<MessagingRepository>.value(
          value: repository,
          child: const MaterialApp(
            home: ConversationScreen(
              courseId: 'course',
              currentUserId: 'student',
              participantId: 'teacher',
              participantName: 'Teacher',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final input = find.byType(TextField);
      final field = tester.widget<TextField>(input);
      for (final label in ['Haha 😂', 'Sad 😢', 'Angry 😡', 'Heart ❤️']) {
        await tester.tap(find.byTooltip(label));
        await tester.pumpAndSettle();
      }
      expect(field.controller!.text, '😂😢😡❤️');
      expect(field.focusNode!.hasFocus, isTrue);
      expect(repository.sentBodies, isEmpty);

      await tester.enterText(input, 'Hello world');
      field.controller!.selection = const TextSelection(
        baseOffset: 6,
        extentOffset: 11,
      );
      await tester.tap(find.byTooltip('Heart ❤️'));
      await tester.pumpAndSettle();
      expect(field.controller!.text, 'Hello ❤️');
      expect(field.controller!.selection.baseOffset, 'Hello ❤️'.length);
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      expect(repository.sentBodies, ['Hello ❤️']);
      expect(field.controller!.text, isEmpty);

      await tester.tap(find.byTooltip('Haha 😂'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      expect(repository.sentBodies, ['Hello ❤️', '😂']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}

Future<void> _pumpConversation(
  WidgetTester tester,
  MessagingRepository repository,
) async {
  await tester.pumpWidget(
    RepositoryProvider<MessagingRepository>.value(
      value: repository,
      child: const MaterialApp(
        home: ConversationScreen(
          courseId: 'course',
          currentUserId: 'student',
          participantId: 'teacher',
          participantName: 'Teacher',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _MessagingRepository implements MessagingRepository {
  _MessagingRepository({bool ownMessage = false})
    : message = MessageModel(
        id: 'message',
        courseId: 'course',
        senderId: ownMessage ? 'student' : 'teacher',
        recipientId: ownMessage ? 'teacher' : 'student',
        body: 'Welcome',
        createdAt: DateTime(2026),
      );
  bool hiddenForYou = false;
  bool unsentForEveryone = false;
  bool failUnsend = false;
  VoidCallback? onChanged;
  final sentBodies = <String>[];
  final MessageModel message;

  @override
  Future<bool> canModifyMessage(String messageId) async => false;

  @override
  Future<void> unsendMessageForYou(String messageId) async {
    if (failUnsend) throw StateError('Offline');
    expect(messageId, message.id);
    hiddenForYou = true;
  }

  @override
  Future<MessageModel> unsendMessage(String messageId) async {
    expect(messageId, message.id);
    unsentForEveryone = true;
    return message;
  }

  @override
  Future<List<MessageModel>> getConversation({
    required String courseId,
    required String participantId,
  }) async => hiddenForYou || unsentForEveryone ? [] : [message];

  @override
  Future<void> markConversationRead({
    required String courseId,
    required String participantId,
  }) async {}

  @override
  RealtimeChannel? subscribeToConversation({
    required String courseId,
    required VoidCallback onChanged,
  }) {
    this.onChanged = onChanged;
    return null;
  }

  @override
  Future<void> removeRealtimeChannel(RealtimeChannel? channel) async {}

  @override
  Future<MessageModel> sendMessage({
    required String courseId,
    required String recipientId,
    required String body,
  }) async {
    expect(courseId, 'course');
    expect(recipientId, 'teacher');
    sentBodies.add(body);
    return message;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
