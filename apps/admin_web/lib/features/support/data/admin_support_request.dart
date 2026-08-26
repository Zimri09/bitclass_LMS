enum AdminSupportRequestType { feedback, bug }

enum AdminSupportRequestStatus { open, inReview, resolved, closed }

extension AdminSupportRequestStatusValue on AdminSupportRequestStatus {
  String get databaseValue => switch (this) {
    AdminSupportRequestStatus.open => 'open',
    AdminSupportRequestStatus.inReview => 'in_review',
    AdminSupportRequestStatus.resolved => 'resolved',
    AdminSupportRequestStatus.closed => 'closed',
  };

  String get label => switch (this) {
    AdminSupportRequestStatus.open => 'Open',
    AdminSupportRequestStatus.inReview => 'In review',
    AdminSupportRequestStatus.resolved => 'Resolved',
    AdminSupportRequestStatus.closed => 'Closed',
  };

  static AdminSupportRequestStatus fromDatabase(String value) {
    return AdminSupportRequestStatus.values.firstWhere(
      (status) => status.databaseValue == value,
      orElse: () => AdminSupportRequestStatus.open,
    );
  }
}

class AdminSupportRequest {
  final String id;
  final String userId;
  final AdminSupportRequestType type;
  final String category;
  final String subject;
  final String description;
  final Map<String, dynamic> metadata;
  final AdminSupportRequestStatus status;
  final DateTime? createdAt;
  final String email;
  final String displayName;
  final String role;

  const AdminSupportRequest({
    required this.id,
    required this.userId,
    required this.type,
    required this.category,
    required this.subject,
    required this.description,
    required this.metadata,
    required this.status,
    required this.email,
    required this.displayName,
    required this.role,
    this.createdAt,
  });

  AdminSupportRequest copyWith({AdminSupportRequestStatus? status}) {
    return AdminSupportRequest(
      id: id,
      userId: userId,
      type: type,
      category: category,
      subject: subject,
      description: description,
      metadata: metadata,
      status: status ?? this.status,
      email: email,
      displayName: displayName,
      role: role,
      createdAt: createdAt,
    );
  }

  factory AdminSupportRequest.fromMap(Map<String, dynamic> map) {
    final profile = map['profile'];
    final profileMap = profile is Map
        ? Map<String, dynamic>.from(profile)
        : const <String, dynamic>{};
    final firstName = (profileMap['first_name'] as String? ?? '').trim();
    final lastName = (profileMap['last_name'] as String? ?? '').trim();
    final fullName = '$firstName $lastName'.trim();
    final email = profileMap['email'] as String? ?? '';

    return AdminSupportRequest(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      type: map['request_type'] == 'bug'
          ? AdminSupportRequestType.bug
          : AdminSupportRequestType.feedback,
      category: map['category'] as String? ?? 'General',
      subject: map['subject'] as String? ?? '',
      description: map['description'] as String? ?? '',
      metadata: Map<String, dynamic>.from(
        map['metadata'] as Map? ?? const <String, dynamic>{},
      ),
      status: AdminSupportRequestStatusValue.fromDatabase(
        map['status'] as String? ?? 'open',
      ),
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? ''),
      email: email,
      displayName: fullName.isNotEmpty ? fullName : email,
      role: profileMap['role'] as String? ?? 'unknown',
    );
  }
}
