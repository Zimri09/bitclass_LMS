import 'package:bitclass/features/messaging/data/models/message_reaction.dart';
import 'package:bitclass/features/messaging/data/models/message_model.dart';
import 'package:bitclass/features/messaging/data/repositories/messaging_repository.dart';
import 'package:bitclass/features/messaging/presentation/screens/conversation_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('right-click, toggle and remote reaction updates', (
    tester,
  ) async {
    final repository = _MessagingRepository();
    await _pumpConversation(tester, repository);
    await tester.tap(find.text('Welcome'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sad 😢'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('You: Sad'), findsOneWidget);
    await tester.longPress(find.text('Welcome'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sad 😢'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('You: Sad'), findsNothing);
    repository.message = MessageModel(
      id: 'message',
      courseId: 'course',
      senderId: 'teacher',
      recipientId: 'student',
      body: 'Welcome',
      createdAt: DateTime(2026),
      senderReaction: MessageReaction.angry,
    );
    repository.onChanged!();
    await tester.pumpAndSettle();
    expect(find.byTooltip('Participant: Angry'), findsOneWidget);
    repository.failReaction = true;
    await tester.tap(find.byTooltip('Message options'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Heart ❤️'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('You: Heart'), findsNothing);
    expect(find.byTooltip('Participant: Angry'), findsOneWidget);
    expect(
      find.text('Unable to update reaction. Please try again.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

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
    'received messages offer reactions and realtime removes unsent messages',
    (tester) async {
      final repository = _MessagingRepository();
      await _pumpConversation(tester, repository);
      expect(find.byTooltip('Message options'), findsOneWidget);
      await tester.longPress(find.text('Welcome'));
      await tester.pumpAndSettle();
      expect(find.text('Unsend for You'), findsNothing);
      await tester.tap(find.byTooltip('Haha 😂'));
      await tester.pumpAndSettle();
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
    for (final ownMessage in [false, true]) {
      testWidgets(
        'react, change, remove and reopen at $width, sent=$ownMessage',
        (tester) async {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final repository = _MessagingRepository(ownMessage: ownMessage);
          await _pumpConversation(tester, repository);
          expect(find.byTooltip('Haha 😂'), findsNothing);
          await tester.longPress(find.text('Welcome'));
          await tester.pumpAndSettle();
          for (final label in ['Haha 😂', 'Sad 😢', 'Angry 😡', 'Heart ❤️']) {
            expect(find.byTooltip(label), findsOneWidget);
          }
          await tester.tap(find.byTooltip('Haha 😂'));
          await tester.pumpAndSettle();
          expect(find.byTooltip('You: Haha'), findsOneWidget);
          expect(
            tester.getTopLeft(find.text('😂')).dy,
            lessThan(tester.getTopLeft(find.text('Welcome')).dy),
          );
          expect(repository.sentBodies, isEmpty);
          await tester.tap(find.byTooltip('Message options'));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('Heart ❤️'));
          await tester.pumpAndSettle();
          expect(find.byTooltip('You: Heart'), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
          await _pumpConversation(tester, repository);
          expect(find.byTooltip('You: Heart'), findsOneWidget);
          await tester.tap(find.byTooltip('Message options'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Remove reaction'));
          await tester.pumpAndSettle();
          expect(find.byTooltip('You: Heart'), findsNothing);
          await tester.enterText(find.byType(TextField), 'Hello ❤️');
          await tester.pump();
          await tester.tap(find.byTooltip('Send message'));
          await tester.pumpAndSettle();
          expect(repository.sentBodies, ['Hello ❤️']);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
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
  bool failReaction = false;
  VoidCallback? onChanged;
  final sentBodies = <String>[];
  MessageModel message;

  @override
  Future<void> setReaction({
    required String messageId,
    required MessageReaction? reaction,
  }) async {
    if (failReaction) throw StateError('Offline');
    message = MessageModel(
      id: message.id,
      courseId: message.courseId,
      senderId: message.senderId,
      recipientId: message.recipientId,
      body: message.body,
      createdAt: message.createdAt,
      senderReaction: message.senderId == 'student'
          ? reaction
          : message.senderReaction,
      recipientReaction: message.recipientId == 'student'
          ? reaction
          : message.recipientReaction,
    );
  }

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
