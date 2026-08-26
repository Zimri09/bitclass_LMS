enum SupportRequestType { feedback, bug }

extension SupportRequestTypeValue on SupportRequestType {
  String get databaseValue => switch (this) {
    SupportRequestType.feedback => 'feedback',
    SupportRequestType.bug => 'bug',
  };
}

enum SupportRequestStatus { open, inReview, resolved, closed }

extension SupportRequestStatusValue on SupportRequestStatus {
  String get databaseValue => switch (this) {
    SupportRequestStatus.open => 'open',
    SupportRequestStatus.inReview => 'in_review',
    SupportRequestStatus.resolved => 'resolved',
    SupportRequestStatus.closed => 'closed',
  };

  String get label => switch (this) {
    SupportRequestStatus.open => 'Open',
    SupportRequestStatus.inReview => 'In Review',
    SupportRequestStatus.resolved => 'Resolved',
    SupportRequestStatus.closed => 'Closed',
  };

  static SupportRequestStatus fromDatabase(String value) {
    return SupportRequestStatus.values.firstWhere(
      (status) => status.databaseValue == value,
      orElse: () => SupportRequestStatus.open,
    );
  }
}

class SupportRequestRecord {
  final String id;
  final String userId;
  final SupportRequestType type;
  final String category;
  final String subject;
  final String description;
  final Map<String, dynamic> metadata;
  final SupportRequestStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? userEmail;
  final String? userFirstName;
  final String? userLastName;
  final String? userRole;

  const SupportRequestRecord({
    required this.id,
    required this.userId,
    required this.type,
    required this.category,
    required this.subject,
    required this.description,
    required this.metadata,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.userEmail,
    this.userFirstName,
    this.userLastName,
    this.userRole,
  });

  String get userDisplayName {
    final name = [
      userFirstName?.trim(),
      userLastName?.trim(),
    ].whereType<String>().where((part) => part.isNotEmpty).join(' ');
    return name.isNotEmpty ? name : (userEmail ?? 'Unknown user');
  }

  SupportRequestRecord copyWith({SupportRequestStatus? status}) {
    return SupportRequestRecord(
      id: id,
      userId: userId,
      type: type,
      category: category,
      subject: subject,
      description: description,
      metadata: metadata,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: DateTime.now().toUtc(),
      userEmail: userEmail,
      userFirstName: userFirstName,
      userLastName: userLastName,
      userRole: userRole,
    );
  }

  factory SupportRequestRecord.fromMap(Map<String, dynamic> map) {
    final profile = map['profile'];
    final profileMap = profile is Map<String, dynamic> ? profile : null;
    final rawType = map['request_type'] as String?;
    return SupportRequestRecord(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      type: rawType == 'bug'
          ? SupportRequestType.bug
          : SupportRequestType.feedback,
      category: map['category'] as String? ?? 'General',
      subject: map['subject'] as String? ?? '',
      description: map['description'] as String? ?? '',
      metadata: Map<String, dynamic>.from(
        map['metadata'] as Map? ?? const <String, dynamic>{},
      ),
      status: SupportRequestStatusValue.fromDatabase(
        map['status'] as String? ?? 'open',
      ),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      userEmail: profileMap?['email'] as String?,
      userFirstName: profileMap?['first_name'] as String?,
      userLastName: profileMap?['last_name'] as String?,
      userRole: profileMap?['role'] as String?,
    );
  }
}
