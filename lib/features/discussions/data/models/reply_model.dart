import 'package:equatable/equatable.dart';

import 'reaction_type.dart';

/// Reply model representing a reply to a discussion thread
class ReplyModel extends Equatable {
  final String id;
  final String threadId;
  final String channelId;
  final String courseId;
  final String? parentReplyId; // For nested replies
  final String content; // Markdown content
  final String authorId;
  final String authorName;
  final String? authorAvatarUrl;
  final bool isInstructorAnswer; // Marked as instructor's answer
  final int likeCount;
  final List<String> likedBy;
  final int reactionCount;
  final Map<String, int> reactionCounts;
  final String? currentUserReaction;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? editedAt;

  const ReplyModel({
    required this.id,
    required this.threadId,
    required this.channelId,
    required this.courseId,
    this.parentReplyId,
    required this.content,
    required this.authorId,
    required this.authorName,
    this.authorAvatarUrl,
    this.isInstructorAnswer = false,
    this.likeCount = 0,
    this.likedBy = const [],
    this.reactionCount = 0,
    this.reactionCounts = const {},
    this.currentUserReaction,
    required this.createdAt,
    this.updatedAt,
    this.editedAt,
  });

  @override
  List<Object?> get props => [
    id,
    threadId,
    channelId,
    courseId,
    parentReplyId,
    content,
    authorId,
    authorName,
    authorAvatarUrl,
    isInstructorAnswer,
    likeCount,
    likedBy,
    reactionCount,
    reactionCounts,
    currentUserReaction,
    createdAt,
    updatedAt,
    editedAt,
  ];

  factory ReplyModel.fromMap(Map<String, dynamic> map) {
    return ReplyModel(
      id: map['id'] as String,
      threadId: map['threadId'] as String,
      channelId: map['channelId'] as String,
      courseId: map['courseId'] as String,
      parentReplyId: map['parentReplyId'] as String?,
      content: map['content'] as String,
      authorId: map['authorId'] as String,
      authorName: map['authorName'] as String,
      authorAvatarUrl: map['authorAvatarUrl'] as String?,
      isInstructorAnswer: map['isInstructorAnswer'] as bool? ?? false,
      likeCount: map['likeCount'] as int? ?? 0,
      likedBy: (map['likedBy'] as List<dynamic>?)?.cast<String>() ?? [],
      reactionCount: map['reactionCount'] as int? ?? 0,
      reactionCounts:
          (map['reactionCounts'] as Map<dynamic, dynamic>?)?.map(
            (key, value) => MapEntry(key.toString(), value as int),
          ) ??
          const {},
      currentUserReaction: map['currentUserReaction'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : null,
      editedAt: map['editedAt'] != null
          ? DateTime.parse(map['editedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'threadId': threadId,
      'channelId': channelId,
      'courseId': courseId,
      'parentReplyId': parentReplyId,
      'content': content,
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatarUrl': authorAvatarUrl,
      'isInstructorAnswer': isInstructorAnswer,
      'likeCount': likeCount,
      'likedBy': likedBy,
      'reactionCount': reactionCount,
      'reactionCounts': reactionCounts,
      'currentUserReaction': currentUserReaction,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'editedAt': editedAt?.toIso8601String(),
    };
  }

  ReplyModel copyWith({
    String? id,
    String? threadId,
    String? channelId,
    String? courseId,
    String? parentReplyId,
    String? content,
    String? authorId,
    String? authorName,
    String? authorAvatarUrl,
    bool? isInstructorAnswer,
    int? likeCount,
    List<String>? likedBy,
    int? reactionCount,
    Map<String, int>? reactionCounts,
    String? currentUserReaction,
    bool clearCurrentUserReaction = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? editedAt,
  }) {
    return ReplyModel(
      id: id ?? this.id,
      threadId: threadId ?? this.threadId,
      channelId: channelId ?? this.channelId,
      courseId: courseId ?? this.courseId,
      parentReplyId: parentReplyId ?? this.parentReplyId,
      content: content ?? this.content,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      isInstructorAnswer: isInstructorAnswer ?? this.isInstructorAnswer,
      likeCount: likeCount ?? this.likeCount,
      likedBy: likedBy ?? this.likedBy,
      reactionCount: reactionCount ?? this.reactionCount,
      reactionCounts: reactionCounts ?? this.reactionCounts,
      currentUserReaction: clearCurrentUserReaction
          ? null
          : currentUserReaction ?? this.currentUserReaction,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      editedAt: editedAt ?? this.editedAt,
    );
  }

  /// Check if a user has liked this reply
  bool isLikedBy(String userId) => likedBy.contains(userId);

  ReactionType? get selectedReaction =>
      ReactionType.fromValue(currentUserReaction);

  Map<String, int> get effectiveReactionCounts {
    if (reactionCounts.isNotEmpty) return reactionCounts;
    if (likeCount > 0) return {'like': likeCount};
    return const {};
  }

  int get totalReactionCount =>
      reactionCounts.isEmpty ? likeCount : reactionCount;

  ReactionType? reactionForUser(String userId) {
    return selectedReaction ??
        (likedBy.contains(userId) ? ReactionType.like : null);
  }

  ReplyModel toggleReaction(ReactionType reaction, {String? userId}) {
    final effectiveCurrentReaction =
        currentUserReaction ??
        (userId != null && likedBy.contains(userId) ? 'like' : null);
    final selection = toggleReactionSelection(
      counts: effectiveReactionCounts,
      currentReaction: effectiveCurrentReaction,
      selected: reaction,
    );
    return copyWith(
      reactionCount: selection.total,
      reactionCounts: selection.counts,
      currentUserReaction: selection.currentReaction,
      clearCurrentUserReaction: selection.currentReaction == null,
    );
  }
}
