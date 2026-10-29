enum MessageReaction {
  haha('Haha', '😂'),
  sad('Sad', '😢'),
  angry('Angry', '😡'),
  heart('Heart', '❤️');

  const MessageReaction(this.label, this.emoji);
  final String label;
  final String emoji;

  static MessageReaction? fromValue(Object? value) {
    for (final reaction in values) {
      if (reaction.name == value) return reaction;
    }
    return null;
  }
}
