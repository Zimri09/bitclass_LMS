import 'package:equatable/equatable.dart';

/// Types of notifications in the app
enum NotificationType {
  courseUpdate, // New content added to course
  newLesson, // New lesson published
  newAssignment, // New assignment posted
  assignmentDue, // Assignment due soon
  assignmentGraded, // Assignment has been graded
  quizAvailable, // New quiz available
  quizGraded, // Quiz results ready
  discussionReply, // Someone replied to your thread
  discussionMention, // Someone mentioned you
  announcement, // Course announcement
  enrollment, // Someone enrolled in your course
  general, // General notification
}

/// Extension for notification type display
extension NotificationTypeExtension on NotificationType {
  String get displayName {
    switch (this) {
      case NotificationType.courseUpdate:
        return 'Course Update';
      case NotificationType.newLesson:
        return 'New Lesson';
      case NotificationType.newAssignment:
        return 'New Assignment';
      case NotificationType.assignmentDue:
        return 'Assignment Due';
      case NotificationType.assignmentGraded:
        return 'Assignment Graded';
      case NotificationType.quizAvailable:
        return 'Quiz Available';
      case NotificationType.quizGraded:
        return 'Quiz Graded';
      case NotificationType.discussionReply:
        return 'Discussion Reply';
      case NotificationType.discussionMention:
        return 'Mention';
      case NotificationType.announcement:
        return 'Announcement';
      case NotificationType.enrollment:
        return 'Enrollment';
      case NotificationType.general:
        return 'Notification';
    }
  }

  String get icon {
    switch (this) {
      case NotificationType.courseUpdate:
        return 'update';
      case NotificationType.newLesson:
        return 'book';
      case NotificationType.newAssignment:
        return 'assignment';
      case NotificationType.assignmentDue:
        return 'alarm';
      case NotificationType.assignmentGraded:
        return 'grade';
      case NotificationType.quizAvailable:
        return 'quiz';
      case NotificationType.quizGraded:
        return 'check_circle';
      case NotificationType.discussionReply:
        return 'chat';
      case NotificationType.discussionMention:
        return 'alternate_email';
      case NotificationType.announcement:
        return 'campaign';
      case NotificationType.enrollment:
        return 'person_add';
      case NotificationType.general:
        return 'notifications';
    }
  }
}

/// Model representing a notification
class NotificationModel extends Equatable {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String body;
  final String? imageUrl;
  final Map<String, dynamic>? data; // Additional data for navigation
  final bool isRead;
  final DateTime createdAt;
  final String? courseId;
  final String? actionUrl; // Deep link for navigation

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.imageUrl,
    this.data,
    this.isRead = false,
    required this.createdAt,
    this.courseId,
    this.actionUrl,
  });

  NotificationModel copyWith({
    String? id,
    String? userId,
    NotificationType? type,
    String? title,
    String? body,
    String? imageUrl,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? createdAt,
    String? courseId,
    String? actionUrl,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      imageUrl: imageUrl ?? this.imageUrl,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      courseId: courseId ?? this.courseId,
      actionUrl: actionUrl ?? this.actionUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'type': type.name,
      'title': title,
      'body': body,
      'imageUrl': imageUrl,
      'data': data,
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
      'courseId': courseId,
      'actionUrl': actionUrl,
    };
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      type: NotificationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => NotificationType.general,
      ),
      title: json['title'] as String,
      body: json['body'] as String,
      imageUrl: json['imageUrl'] as String?,
      data: json['data'] as Map<String, dynamic>?,
      isRead: json['isRead'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      courseId: json['courseId'] as String?,
      actionUrl: json['actionUrl'] as String?,
    );
  }

  /// Create from Firestore document
  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
    return NotificationModel(
      id: id,
      userId: map['userId'] as String,
      type: NotificationType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => NotificationType.general,
      ),
      title: map['title'] as String,
      body: map['body'] as String,
      imageUrl: map['imageUrl'] as String?,
      data: map['data'] as Map<String, dynamic>?,
      isRead: map['isRead'] as bool? ?? false,
      createdAt: DateTime.parse(map['createdAt'] as String),
      courseId: map['courseId'] as String?,
      actionUrl: map['actionUrl'] as String?,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toMap() => toJson();

  @override
  List<Object?> get props => [
    id,
    userId,
    type,
    title,
    body,
    imageUrl,
    data,
    isRead,
    createdAt,
    courseId,
    actionUrl,
  ];
}
