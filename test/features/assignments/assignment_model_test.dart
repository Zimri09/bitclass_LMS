import 'package:flutter_test/flutter_test.dart';
import 'package:bitclass/features/assignments/data/models/assignment_model.dart';

void main() {
  // ====================================================
  // ProgrammingLanguage enum
  // ====================================================
  group('ProgrammingLanguage', () {
    test('fromString parses known languages', () {
      expect(ProgrammingLanguage.fromString('dart'), ProgrammingLanguage.dart);
      expect(
          ProgrammingLanguage.fromString('python'), ProgrammingLanguage.python);
      expect(ProgrammingLanguage.fromString('javascript'),
          ProgrammingLanguage.javascript);
      expect(ProgrammingLanguage.fromString('cpp'), ProgrammingLanguage.cpp);
    });

    test('fromString is case-insensitive (lowercases input)', () {
      expect(ProgrammingLanguage.fromString('Dart'), ProgrammingLanguage.dart);
      expect(ProgrammingLanguage.fromString('PYTHON'),
          ProgrammingLanguage.python);
    });

    test('fromString returns plaintext for unknown values', () {
      expect(ProgrammingLanguage.fromString('unknown'),
          ProgrammingLanguage.plaintext);
      expect(
          ProgrammingLanguage.fromString(''), ProgrammingLanguage.plaintext);
    });

    test('displayName returns human-readable names', () {
      expect(ProgrammingLanguage.dart.displayName, 'Dart');
      expect(ProgrammingLanguage.cpp.displayName, 'C++');
      expect(ProgrammingLanguage.csharp.displayName, 'C#');
      expect(ProgrammingLanguage.javascript.displayName, 'JavaScript');
      expect(ProgrammingLanguage.plaintext.displayName, 'Plain Text');
    });

    test('fileExtension returns correct extensions', () {
      expect(ProgrammingLanguage.dart.fileExtension, '.dart');
      expect(ProgrammingLanguage.python.fileExtension, '.py');
      expect(ProgrammingLanguage.javascript.fileExtension, '.js');
      expect(ProgrammingLanguage.typescript.fileExtension, '.ts');
      expect(ProgrammingLanguage.cpp.fileExtension, '.cpp');
      expect(ProgrammingLanguage.csharp.fileExtension, '.cs');
      expect(ProgrammingLanguage.plaintext.fileExtension, '.txt');
    });
  });

  // ====================================================
  // AssignmentModel
  // ====================================================
  group('AssignmentModel', () {
    final createdAt = DateTime(2024, 3, 1);

    AssignmentModel makeAssignment({
      String id = 'assign-1',
      String courseId = 'course-1',
      ProgrammingLanguage language = ProgrammingLanguage.dart,
    }) =>
        AssignmentModel(
          id: id,
          courseId: courseId,
          title: 'Hello World',
          description: 'Write a hello world program',
          language: language,
          createdAt: createdAt,
        );

    test('creates a valid instance with required fields', () {
      final assignment = makeAssignment();

      expect(assignment.id, 'assign-1');
      expect(assignment.courseId, 'course-1');
      expect(assignment.title, 'Hello World');
      expect(assignment.language, ProgrammingLanguage.dart);
      expect(assignment.maxPoints, 100);
      expect(assignment.allowLateSubmission, true);
      expect(assignment.latePenaltyPercent, 10);
      expect(assignment.isPublished, false);
    });

    test('creates instance with all optional fields', () {
      final dueDate = DateTime(2024, 4, 1);
      final assignment = AssignmentModel(
        id: 'assign-1',
        courseId: 'course-1',
        lessonId: 'lesson-3',
        title: 'Sorting Algorithm',
        description: 'Implement merge sort',
        instructions: '## Instructions\nWrite merge sort in Dart.',
        language: ProgrammingLanguage.dart,
        starterCode: 'void mergeSort(List<int> arr) {}',
        solutionCode: 'void mergeSort(List<int> arr) { /* ... */ }',
        maxPoints: 50,
        dueDate: dueDate,
        allowLateSubmission: false,
        latePenaltyPercent: 20,
        isPublished: true,
        createdAt: createdAt,
        updatedAt: DateTime(2024, 3, 15),
      );

      expect(assignment.lessonId, 'lesson-3');
      expect(assignment.instructions, contains('## Instructions'));
      expect(assignment.starterCode, isNotNull);
      expect(assignment.solutionCode, isNotNull);
      expect(assignment.maxPoints, 50);
      expect(assignment.dueDate, dueDate);
      expect(assignment.allowLateSubmission, false);
      expect(assignment.latePenaltyPercent, 20);
      expect(assignment.isPublished, true);
    });

    test('toMap creates correct map', () {
      final assignment = makeAssignment();
      final map = assignment.toMap();

      expect(map['id'], 'assign-1');
      expect(map['courseId'], 'course-1');
      expect(map['title'], 'Hello World');
      expect(map['language'], 'dart');
      expect(map['maxPoints'], 100);
      expect(map['allowLateSubmission'], true);
      expect(map['isPublished'], false);
      expect(map['createdAt'], createdAt.toIso8601String());
    });

    test('fromMap creates correct instance', () {
      final map = {
        'id': 'assign-2',
        'courseId': 'course-1',
        'title': 'Fibonacci',
        'description': 'Compute Fibonacci numbers',
        'language': 'python',
        'maxPoints': 75,
        'isPublished': true,
        'createdAt': '2024-03-01T00:00:00.000',
      };

      final assignment = AssignmentModel.fromMap(map);

      expect(assignment.id, 'assign-2');
      expect(assignment.language, ProgrammingLanguage.python);
      expect(assignment.maxPoints, 75);
      expect(assignment.isPublished, true);
    });

    test('fromMap uses defaults for missing optional fields', () {
      final map = {
        'id': 'assign-3',
        'courseId': 'course-1',
        'title': 'Test',
        'description': 'Desc',
        'createdAt': '2024-01-01T00:00:00.000',
      };

      final assignment = AssignmentModel.fromMap(map);

      expect(assignment.language, ProgrammingLanguage.plaintext);
      expect(assignment.maxPoints, 100);
      expect(assignment.allowLateSubmission, true);
      expect(assignment.latePenaltyPercent, 10);
      expect(assignment.isPublished, false);
    });

    test('roundtrip toMap -> fromMap preserves all fields', () {
      final original = AssignmentModel(
        id: 'assign-1',
        courseId: 'course-1',
        lessonId: 'lesson-1',
        title: 'Test Assignment',
        description: 'A description',
        instructions: 'Do the thing',
        language: ProgrammingLanguage.rust,
        starterCode: 'fn main() {}',
        solutionCode: 'fn main() { println!("hi"); }',
        maxPoints: 50,
        dueDate: DateTime(2024, 5, 1),
        allowLateSubmission: false,
        latePenaltyPercent: 25,
        isPublished: true,
        createdAt: createdAt,
        updatedAt: DateTime(2024, 3, 10),
      );

      final roundtripped = AssignmentModel.fromMap(original.toMap());

      expect(roundtripped, equals(original));
    });

    test('copyWith updates only specified fields', () {
      final original = makeAssignment();
      final updated = original.copyWith(
        title: 'Updated Title',
        isPublished: true,
      );

      expect(updated.title, 'Updated Title');
      expect(updated.isPublished, true);
      expect(updated.id, 'assign-1'); // unchanged
      expect(updated.language, ProgrammingLanguage.dart); // unchanged
    });

    test('equatable: identical instances are equal', () {
      final a = makeAssignment();
      final b = makeAssignment();
      expect(a, equals(b));
    });

    test('equatable: different instances are not equal', () {
      final a = makeAssignment(id: 'a');
      final b = makeAssignment(id: 'b');
      expect(a, isNot(equals(b)));
    });
  });
}
