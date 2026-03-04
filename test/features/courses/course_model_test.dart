import 'package:flutter_test/flutter_test.dart';
import 'package:bitclass/features/courses/data/models/course_model.dart';

void main() {
  group('CourseModel', () {
    test('creates a valid course with all fields', () {
      final course = CourseModel(
        id: 'course-1',
        title: 'Flutter Development',
        description: 'Learn Flutter from scratch',
        instructorId: 'instructor-1',
        instructorName: 'Prof. Smith',
        category: 'Mobile Development',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        lessonCount: 10,
        enrollmentCount: 50,
        isPublished: true,
        createdAt: DateTime(2024, 1, 1),
      );

      expect(course.id, 'course-1');
      expect(course.title, 'Flutter Development');
      expect(course.instructorName, 'Prof. Smith');
      expect(course.category, 'Mobile Development');
      expect(course.lessonCount, 10);
      expect(course.enrollmentCount, 50);
      expect(course.isPublished, true);
    });

    test('toJson creates valid map', () {
      final course = CourseModel(
        id: 'course-1',
        title: 'Flutter Development',
        description: 'Learn Flutter from scratch',
        instructorId: 'instructor-1',
        instructorName: 'Prof. Smith',
        category: 'Mobile Development',
        lessonCount: 5,
        enrollmentCount: 20,
        isPublished: false,
        createdAt: DateTime(2024, 1, 1),
      );

      final json = course.toJson();

      expect(json['id'], 'course-1');
      expect(json['title'], 'Flutter Development');
      expect(json['instructorId'], 'instructor-1');
      expect(json['category'], 'Mobile Development');
      expect(json['isPublished'], false);
    });

    test('fromJson creates valid course', () {
      final json = {
        'id': 'course-1',
        'title': 'Flutter Development',
        'description': 'Learn Flutter from scratch',
        'instructorId': 'instructor-1',
        'instructorName': 'Prof. Smith',
        'category': 'Mobile Development',
        'lessonCount': 15,
        'enrollmentCount': 100,
        'isPublished': true,
        'createdAt': '2024-01-01T00:00:00.000',
      };

      final course = CourseModel.fromJson(json);

      expect(course.id, 'course-1');
      expect(course.title, 'Flutter Development');
      expect(course.category, 'Mobile Development');
      expect(course.lessonCount, 15);
      expect(course.enrollmentCount, 100);
    });

    test('copyWith creates new instance with updated fields', () {
      final course = CourseModel(
        id: 'course-1',
        title: 'Flutter Development',
        description: 'Learn Flutter',
        instructorId: 'instructor-1',
        instructorName: 'Prof. Smith',
        category: 'Mobile Development',
        lessonCount: 5,
        enrollmentCount: 20,
        isPublished: false,
        createdAt: DateTime(2024, 1, 1),
      );

      final updatedCourse = course.copyWith(
        title: 'Advanced Flutter',
        lessonCount: 20,
        isPublished: true,
      );

      expect(updatedCourse.title, 'Advanced Flutter');
      expect(updatedCourse.lessonCount, 20);
      expect(updatedCourse.isPublished, true);
      expect(updatedCourse.id, course.id);
      expect(updatedCourse.instructorId, course.instructorId);
    });
  });

  group('CourseModel categories', () {
    test('mobile development category is valid', () {
      final course = CourseModel(
        id: 'course-1',
        title: 'Mobile Course',
        description: 'Mobile development',
        instructorId: 'instructor-1',
        instructorName: 'Instructor',
        category: 'Mobile Development',
        lessonCount: 1,
        enrollmentCount: 0,
        isPublished: true,
        createdAt: DateTime.now(),
      );

      expect(course.category, 'Mobile Development');
    });

    test('web development category is valid', () {
      final course = CourseModel(
        id: 'course-1',
        title: 'Web Course',
        description: 'Web development',
        instructorId: 'instructor-1',
        instructorName: 'Instructor',
        category: 'Web Development',
        lessonCount: 1,
        enrollmentCount: 0,
        isPublished: true,
        createdAt: DateTime.now(),
      );

      expect(course.category, 'Web Development');
    });

    test('data science category is valid', () {
      final course = CourseModel(
        id: 'course-1',
        title: 'Data Course',
        description: 'Data science',
        instructorId: 'instructor-1',
        instructorName: 'Instructor',
        category: 'Data Science',
        lessonCount: 1,
        enrollmentCount: 0,
        isPublished: true,
        createdAt: DateTime.now(),
      );

      expect(course.category, 'Data Science');
    });
  });
}
