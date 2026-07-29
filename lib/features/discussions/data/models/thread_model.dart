import 'package:equatable/equatable.dart';

import 'reaction_type.dart';

/// Thread model representing a discussion thread within a channel
class ThreadModel extends Equatable {
  final String id;
  final String channelId;
  final String courseId;
  final String title;
  final String content; // Markdown content
  final String authorId;
  final String authorName;
  final String? authorAvatarUrl;
  final bool isPinned;
  final bool isLocked; // No new replies allowed
  final bool isResolved; // For Q&A style threads
  final int replyCount;
  final int likeCount;
  final List<String> likedBy;
  final int reactionCount;
  final Map<String, int> reactionCounts;
  final String? currentUserReaction;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? lastReplyAt;

  const ThreadModel({
    required this.id,
    required this.channelId,
    required this.courseId,
    required this.title,
    required this.content,
    required this.authorId,
    required this.authorName,
    this.authorAvatarUrl,
    this.isPinned = false,
    this.isLocked = false,
    this.isResolved = false,
    this.replyCount = 0,
    this.likeCount = 0,
    this.likedBy = const [],
    this.reactionCount = 0,
    this.reactionCounts = const {},
    this.currentUserReaction,
    required this.createdAt,
    this.updatedAt,
    this.lastReplyAt,
  });

  @override
  List<Object?> get props => [
    id,
    channelId,
    courseId,
    title,
    content,
    authorId,
    authorName,
    authorAvatarUrl,
    isPinned,
    isLocked,
    isResolved,
    replyCount,
    likeCount,
    likedBy,
    reactionCount,
    reactionCounts,
    currentUserReaction,
    createdAt,
    updatedAt,
    lastReplyAt,
  ];

  factory ThreadModel.fromMap(Map<String, dynamic> map) {
    return ThreadModel(
      id: map['id'] as String,
      channelId: map['channelId'] as String,
      courseId: map['courseId'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      authorId: map['authorId'] as String,
      authorName: map['authorName'] as String,
      authorAvatarUrl: map['authorAvatarUrl'] as String?,
      isPinned: map['isPinned'] as bool? ?? false,
      isLocked: map['isLocked'] as bool? ?? false,
      isResolved: map['isResolved'] as bool? ?? false,
      replyCount: map['replyCount'] as int? ?? 0,
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
      lastReplyAt: map['lastReplyAt'] != null
          ? DateTime.parse(map['lastReplyAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'channelId': channelId,
      'courseId': courseId,
      'title': title,
      'content': content,
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatarUrl': authorAvatarUrl,
      'isPinned': isPinned,
      'isLocked': isLocked,
      'isResolved': isResolved,
      'replyCount': replyCount,
      'likeCount': likeCount,
      'likedBy': likedBy,
      'reactionCount': reactionCount,
      'reactionCounts': reactionCounts,
      'currentUserReaction': currentUserReaction,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'lastReplyAt': lastReplyAt?.toIso8601String(),
    };
  }

  ThreadModel copyWith({
    String? id,
    String? channelId,
    String? courseId,
    String? title,
    String? content,
    String? authorId,
    String? authorName,
    String? authorAvatarUrl,
    bool? isPinned,
    bool? isLocked,
    bool? isResolved,
    int? replyCount,
    int? likeCount,
    List<String>? likedBy,
    int? reactionCount,
    Map<String, int>? reactionCounts,
    String? currentUserReaction,
    bool clearCurrentUserReaction = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastReplyAt,
  }) {
    return ThreadModel(
      id: id ?? this.id,
      channelId: channelId ?? this.channelId,
      courseId: courseId ?? this.courseId,
      title: title ?? this.title,
      content: content ?? this.content,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      isPinned: isPinned ?? this.isPinned,
      isLocked: isLocked ?? this.isLocked,
      isResolved: isResolved ?? this.isResolved,
      replyCount: replyCount ?? this.replyCount,
      likeCount: likeCount ?? this.likeCount,
      likedBy: likedBy ?? this.likedBy,
      reactionCount: reactionCount ?? this.reactionCount,
      reactionCounts: reactionCounts ?? this.reactionCounts,
      currentUserReaction: clearCurrentUserReaction
          ? null
          : currentUserReaction ?? this.currentUserReaction,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastReplyAt: lastReplyAt ?? this.lastReplyAt,
    );
  }

  /// Check if a user has liked this thread
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

  ThreadModel toggleReaction(ReactionType reaction, {String? userId}) {
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
