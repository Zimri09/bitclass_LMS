import 'package:equatable/equatable.dart';

/// Channel model representing a discussion channel within a course
class ChannelModel extends Equatable {
  final String id;
  final String courseId;
  final String name;
  final String? description;
  final String? icon; // emoji or icon name
  final bool isAnnouncement; // Only instructors can post
  final bool isDefault; // Default channel like "General"
  final int threadCount;
  final DateTime? lastActivityAt;
  final DateTime createdAt;
  final String createdBy;

  const ChannelModel({
    required this.id,
    required this.courseId,
    required this.name,
    this.description,
    this.icon,
    this.isAnnouncement = false,
    this.isDefault = false,
    this.threadCount = 0,
    this.lastActivityAt,
    required this.createdAt,
    required this.createdBy,
  });

  @override
  List<Object?> get props => [
    id,
    courseId,
    name,
    description,
    icon,
    isAnnouncement,
    isDefault,
    threadCount,
    lastActivityAt,
    createdAt,
    createdBy,
  ];

  factory ChannelModel.fromMap(Map<String, dynamic> map) {
    return ChannelModel(
      id: map['id'] as String,
      courseId: map['courseId'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      icon: map['icon'] as String?,
      isAnnouncement: map['isAnnouncement'] as bool? ?? false,
      isDefault: map['isDefault'] as bool? ?? false,
      threadCount: map['threadCount'] as int? ?? 0,
      lastActivityAt: map['lastActivityAt'] != null
          ? DateTime.parse(map['lastActivityAt'] as String)
          : null,
      createdAt: DateTime.parse(map['createdAt'] as String),
      createdBy: map['createdBy'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'courseId': courseId,
      'name': name,
      'description': description,
      'icon': icon,
      'isAnnouncement': isAnnouncement,
      'isDefault': isDefault,
      'threadCount': threadCount,
      'lastActivityAt': lastActivityAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
    };
  }

  ChannelModel copyWith({
    String? id,
    String? courseId,
    String? name,
    String? description,
    String? icon,
    bool? isAnnouncement,
    bool? isDefault,
    int? threadCount,
    DateTime? lastActivityAt,
    DateTime? createdAt,
    String? createdBy,
  }) {
    return ChannelModel(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      isAnnouncement: isAnnouncement ?? this.isAnnouncement,
      isDefault: isDefault ?? this.isDefault,
      threadCount: threadCount ?? this.threadCount,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
