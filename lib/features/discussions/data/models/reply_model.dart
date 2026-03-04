import 'package:equatable/equatable.dart';

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
  final bool isAcceptedAnswer; // Marked as accepted solution
  final int likeCount;
  final List<String> likedBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

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
    this.isAcceptedAnswer = false,
    this.likeCount = 0,
    this.likedBy = const [],
    required this.createdAt,
    this.updatedAt,
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
    isAcceptedAnswer,
    likeCount,
    likedBy,
    createdAt,
    updatedAt,
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
      isAcceptedAnswer: map['isAcceptedAnswer'] as bool? ?? false,
      likeCount: map['likeCount'] as int? ?? 0,
      likedBy: (map['likedBy'] as List<dynamic>?)?.cast<String>() ?? [],
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
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
      'isAcceptedAnswer': isAcceptedAnswer,
      'likeCount': likeCount,
      'likedBy': likedBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
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
    bool? isAcceptedAnswer,
    int? likeCount,
    List<String>? likedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
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
      isAcceptedAnswer: isAcceptedAnswer ?? this.isAcceptedAnswer,
      likeCount: likeCount ?? this.likeCount,
      likedBy: likedBy ?? this.likedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if a user has liked this reply
  bool isLikedBy(String userId) => likedBy.contains(userId);
}
