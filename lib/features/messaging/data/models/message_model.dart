import 'package:equatable/equatable.dart';

class MessageModel extends Equatable {
  final String id;
  final String courseId;
  final String senderId;
  final String recipientId;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;
  final DateTime? editedAt;
  final bool isUnsent;

  const MessageModel({
    required this.id,
    required this.courseId,
    required this.senderId,
    required this.recipientId,
    required this.body,
    required this.createdAt,
    this.readAt,
    this.editedAt,
    this.isUnsent = false,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'] as String,
      courseId: map['course_id'] as String,
      senderId: map['sender_id'] as String,
      recipientId: map['recipient_id'] as String,
      body: map['body'] as String,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      readAt: map['read_at'] == null
          ? null
          : DateTime.parse(map['read_at'] as String).toLocal(),
      editedAt: map['edited_at'] == null
          ? null
          : DateTime.parse(map['edited_at'] as String).toLocal(),
      isUnsent: map['is_unsent'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
    id,
    courseId,
    senderId,
    recipientId,
    body,
    createdAt,
    readAt,
    editedAt,
    isUnsent,
  ];
}
