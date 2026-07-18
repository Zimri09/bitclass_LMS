import 'package:equatable/equatable.dart';

/// User model representing an authenticated user
class UserModel extends Equatable {
  final String id;
  final String email;
  final String? firstName;
  final String? lastName;
  final int? age;
  final String? avatarUrl;
  final String? bio;
  final String role; // 'student', 'instructor', or 'admin'
  final DateTime createdAt;
  final DateTime? updatedAt;

  const UserModel({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.age,
    this.avatarUrl,
    this.bio,
    required this.role,
    required this.createdAt,
    this.updatedAt,
  });

  /// Full display name derived from first + last name
  String? get displayName {
    if (firstName != null && lastName != null) {
      return '${firstName!.trim()} ${lastName!.trim()}'.trim();
    }
    if (firstName != null) return firstName!.trim();
    if (lastName != null) return lastName!.trim();
    return null;
  }

  /// Create a new UserModel with default values for registration
  factory UserModel.create({
    required String id,
    required String email,
    required String role,
    String? firstName,
    String? lastName,
  }) {
    return UserModel(
      id: id,
      email: email,
      firstName: firstName ?? email.split('@').first,
      lastName: lastName,
      role: role,
      createdAt: DateTime.now(),
    );
  }

  /// Create UserModel from Supabase profile row
  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      email: map['email'] as String,
      firstName: map['firstName'] as String?,
      lastName: map['lastName'] as String?,
      age: map['age'] as int?,
      avatarUrl: map['avatarUrl'] as String?,
      bio: map['bio'] as String?,
      role: map['role'] as String? ?? 'student',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : null,
    );
  }

  /// Convert UserModel to map
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'age': age,
      'avatarUrl': avatarUrl,
      'bio': bio,
      'role': role,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Alias for toMap for JSON compatibility
  Map<String, dynamic> toJson() => {'id': id, ...toMap()};

  /// Create UserModel from JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel.fromMap(json, json['id'] as String);
  }

  /// Create a copy with updated fields
  UserModel copyWith({
    String? id,
    String? email,
    String? firstName,
    String? lastName,
    int? age,
    bool clearAge = false,
    String? avatarUrl,
    String? bio,
    String? role,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      age: clearAge ? null : (age ?? this.age),
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if user is an instructor
  bool get isInstructor => role == 'instructor';

  /// Check if user is a student
  bool get isStudent => role == 'student';

  /// Check if user is an admin
  bool get isAdmin => role == 'admin';

  /// Get display name or fallback to email prefix
  String get displayNameOrEmail => displayName ?? email.split('@').first;

  @override
  List<Object?> get props => [
    id,
    email,
    firstName,
    lastName,
    age,
    avatarUrl,
    bio,
    role,
    createdAt,
    updatedAt,
  ];

  @override
  String toString() {
    return 'UserModel(id: $id, email: $email, role: $role)';
  }
}

/// Role enumeration for type safety
enum UserRole {
  student,
  instructor,
  admin;

  String get value {
    switch (this) {
      case UserRole.student:
        return 'student';
      case UserRole.instructor:
        return 'instructor';
      case UserRole.admin:
        return 'admin';
    }
  }

  static UserRole fromString(String value) {
    switch (value) {
      case 'instructor':
        return UserRole.instructor;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.student;
    }
  }
}
