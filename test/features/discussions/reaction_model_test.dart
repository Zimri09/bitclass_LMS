import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:bitclass/features/discussions/data/models/models.dart';
import 'package:bitclass/features/discussions/presentation/widgets/reaction_control.dart';

void main() {
  group('ReactionType', () {
    test('contains all supported reactions', () {
      expect(ReactionType.values.map((reaction) => reaction.value), [
        'like',
        'haha',
        'sad',
        'heart',
        'angry',
      ]);
    });

    test('parses stored reaction values', () {
      expect(ReactionType.fromValue('heart'), ReactionType.heart);
      expect(ReactionType.fromValue('unknown'), isNull);
      expect(ReactionType.fromValue(null), isNull);
    });
  });

  group('ThreadModel reactions', () {
    final thread = ThreadModel(
      id: 'thread-1',
      channelId: 'channel-1',
      courseId: 'course-1',
      title: 'Question',
      content: 'Details',
      authorId: 'author-1',
      authorName: 'Author',
      createdAt: DateTime.utc(2026, 7, 29),
    );

    test('adds and removes the same reaction', () {
      final liked = thread.toggleReaction(ReactionType.like);
      expect(liked.currentUserReaction, 'like');
      expect(liked.totalReactionCount, 1);
      expect(liked.effectiveReactionCounts['like'], 1);

      final removed = liked.toggleReaction(ReactionType.like);
      expect(removed.currentUserReaction, isNull);
      expect(removed.totalReactionCount, 0);
      expect(removed.effectiveReactionCounts['like'], 0);
    });

    test('changes reaction without increasing the total', () {
      final liked = thread.toggleReaction(ReactionType.like);
      final laughed = liked.toggleReaction(ReactionType.haha);

      expect(laughed.currentUserReaction, 'haha');
      expect(laughed.totalReactionCount, 1);
      expect(laughed.effectiveReactionCounts['like'], 0);
      expect(laughed.effectiveReactionCounts['haha'], 1);
    });

    test('treats a legacy like as the current user reaction', () {
      final legacyLike = thread.copyWith(
        likeCount: 1,
        likedBy: const ['student-1'],
      );
      final removed = legacyLike.toggleReaction(
        ReactionType.like,
        userId: 'student-1',
      );

      expect(removed.currentUserReaction, isNull);
      expect(removed.totalReactionCount, 0);
    });
  });

  test('ReplyModel applies the same single-choice behavior', () {
    final reply = ReplyModel(
      id: 'reply-1',
      threadId: 'thread-1',
      channelId: 'channel-1',
      courseId: 'course-1',
      content: 'Reply',
      authorId: 'author-2',
      authorName: 'Responder',
      createdAt: DateTime.utc(2026, 7, 29),
    );

    final hearted = reply.toggleReaction(ReactionType.heart);
    final angry = hearted.toggleReaction(ReactionType.angry);

    expect(angry.currentUserReaction, 'angry');
    expect(angry.totalReactionCount, 1);
    expect(angry.effectiveReactionCounts['heart'], 0);
    expect(angry.effectiveReactionCounts['angry'], 1);
  });

  test('ReplyModel preserves an explicit edit marker', () {
    final editedAt = DateTime.utc(2026, 7, 29, 12);
    final reply = ReplyModel(
      id: 'reply-1',
      threadId: 'thread-1',
      channelId: 'channel-1',
      courseId: 'course-1',
      content: 'Updated reply',
      authorId: 'author-2',
      authorName: 'Responder',
      createdAt: DateTime.utc(2026, 7, 29),
      editedAt: editedAt,
    );

    expect(ReplyModel.fromMap(reply.toMap()).editedAt, editedAt);
  });

  testWidgets('reaction control exposes all options and returns a selection', (
    tester,
  ) async {
    ReactionType? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: ReactionControl(
              reactionCounts: const {},
              totalCount: 0,
              selectedReaction: null,
              onReactionSelected: (reaction) => selected = reaction,
            ),
          ),
        ),
      ),
    );

    await tester.longPress(find.text('React'));
    await tester.pumpAndSettle();

    for (final reaction in ReactionType.values) {
      expect(find.text(reaction.label), findsOneWidget);
    }

    await tester.tap(find.text('Haha'));
    await tester.pumpAndSettle();
    expect(selected, ReactionType.haha);
  });

  testWidgets('short tap applies the quick Like reaction', (tester) async {
    ReactionType? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReactionControl(
            reactionCounts: const {},
            totalCount: 0,
            selectedReaction: null,
            onReactionSelected: (reaction) => selected = reaction,
          ),
        ),
      ),
    );

    await tester.tap(find.text('React'));
    await tester.pump();

    expect(selected, ReactionType.like);
  });

  testWidgets('reaction total opens the count breakdown', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReactionControl(
            reactionCounts: const {'like': 2, 'heart': 1},
            totalCount: 3,
            selectedReaction: ReactionType.like,
            onReactionSelected: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('3'));
    await tester.pumpAndSettle();

    expect(find.text('3 reactions'), findsOneWidget);
    expect(find.text('Heart'), findsOneWidget);
  });
}
