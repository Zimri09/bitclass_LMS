import 'package:equatable/equatable.dart';

enum ReactionType {
  like('like', 'Like', '\u{1F44D}'),
  haha('haha', 'Haha', '\u{1F602}'),
  sad('sad', 'Sad', '\u{1F622}'),
  heart('heart', 'Heart', '\u2764\uFE0F'),
  angry('angry', 'Angry', '\u{1F621}');

  final String value;
  final String label;
  final String emoji;

  const ReactionType(this.value, this.label, this.emoji);

  static ReactionType? fromValue(String? value) {
    for (final reaction in values) {
      if (reaction.value == value) return reaction;
    }
    return null;
  }
}

class ReactionSelection extends Equatable {
  final Map<String, int> counts;
  final int total;
  final String? currentReaction;

  const ReactionSelection({
    required this.counts,
    required this.total,
    required this.currentReaction,
  });

  @override
  List<Object?> get props => [counts, total, currentReaction];
}

ReactionSelection toggleReactionSelection({
  required Map<String, int> counts,
  required String? currentReaction,
  required ReactionType selected,
}) {
  final updatedCounts = <String, int>{
    for (final reaction in ReactionType.values)
      reaction.value: counts[reaction.value] ?? 0,
  };

  String? nextReaction;
  if (currentReaction == selected.value) {
    updatedCounts[selected.value] = (updatedCounts[selected.value]! - 1).clamp(
      0,
      1 << 31,
    );
  } else {
    final previous = ReactionType.fromValue(currentReaction);
    if (previous != null) {
      updatedCounts[previous.value] = (updatedCounts[previous.value]! - 1)
          .clamp(0, 1 << 31);
    }
    updatedCounts[selected.value] = updatedCounts[selected.value]! + 1;
    nextReaction = selected.value;
  }

  return ReactionSelection(
    counts: updatedCounts,
    total: updatedCounts.values.fold(0, (total, count) => total + count),
    currentReaction: nextReaction,
  );
}
