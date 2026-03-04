import 'package:flutter_test/flutter_test.dart';
import 'package:bitclass/features/auth/data/models/user_model.dart';

void main() {
  group('UserModel', () {
    test('creates a valid user with all fields', () {
      final user = UserModel(
        id: 'user-1',
        email: 'test@example.com',
        displayName: 'Test User',
        role: 'student',
        createdAt: DateTime(2024, 1, 1),
      );

      expect(user.id, 'user-1');
      expect(user.email, 'test@example.com');
      expect(user.displayName, 'Test User');
      expect(user.role, 'student');
      expect(user.isInstructor, false);
    });

    test('instructor role is detected correctly', () {
      final instructor = UserModel(
        id: 'user-2',
        email: 'instructor@example.com',
        displayName: 'Instructor',
        role: 'instructor',
        createdAt: DateTime(2024, 1, 1),
      );

      expect(instructor.isInstructor, true);
    });

    test('displayNameOrEmail returns display name when available', () {
      final user = UserModel(
        id: 'user-1',
        email: 'test@example.com',
        displayName: 'Test User',
        role: 'student',
        createdAt: DateTime(2024, 1, 1),
      );

      expect(user.displayNameOrEmail, 'Test User');
    });

    test('displayNameOrEmail returns email when display name is null', () {
      final user = UserModel(
        id: 'user-1',
        email: 'test@example.com',
        displayName: null,
        role: 'student',
        createdAt: DateTime(2024, 1, 1),
      );

      expect(user.displayNameOrEmail, 'test@example.com');
    });

    test('toJson creates valid map', () {
      final user = UserModel(
        id: 'user-1',
        email: 'test@example.com',
        displayName: 'Test User',
        role: 'student',
        bio: 'A test bio',
        createdAt: DateTime(2024, 1, 1),
      );

      final json = user.toJson();

      expect(json['id'], 'user-1');
      expect(json['email'], 'test@example.com');
      expect(json['displayName'], 'Test User');
      expect(json['role'], 'student');
      expect(json['bio'], 'A test bio');
    });

    test('fromJson creates valid user', () {
      final json = {
        'id': 'user-1',
        'email': 'test@example.com',
        'displayName': 'Test User',
        'role': 'student',
        'bio': 'A test bio',
        'createdAt': '2024-01-01T00:00:00.000',
      };

      final user = UserModel.fromJson(json);

      expect(user.id, 'user-1');
      expect(user.email, 'test@example.com');
      expect(user.displayName, 'Test User');
      expect(user.role, 'student');
      expect(user.bio, 'A test bio');
    });

    test('copyWith creates new instance with updated fields', () {
      final user = UserModel(
        id: 'user-1',
        email: 'test@example.com',
        displayName: 'Test User',
        role: 'student',
        createdAt: DateTime(2024, 1, 1),
      );

      final updatedUser = user.copyWith(displayName: 'Updated Name');

      expect(updatedUser.displayName, 'Updated Name');
      expect(updatedUser.id, user.id);
      expect(updatedUser.email, user.email);
    });
  });
}
