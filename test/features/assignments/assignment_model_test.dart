import 'package:flutter_test/flutter_test.dart';
import 'package:bitclass/features/assignments/data/models/assignment_attachment.dart';
import 'package:bitclass/features/assignments/data/models/assignment_model.dart';
import 'package:bitclass/features/assignments/data/models/criterion_score.dart';
import 'package:bitclass/features/assignments/data/models/grading_criterion.dart';

void main() {
  // ====================================================
  // ProgrammingLanguage enum
  // ====================================================
  group('ProgrammingLanguage', () {
    test('fromString parses known languages', () {
      expect(ProgrammingLanguage.fromString('dart'), ProgrammingLanguage.dart);
      expect(
        ProgrammingLanguage.fromString('python'),
        ProgrammingLanguage.python,
      );
      expect(ProgrammingLanguage.fromString('c'), ProgrammingLanguage.c);
      expect(
        ProgrammingLanguage.fromString('javascript'),
        ProgrammingLanguage.javascript,
      );
      expect(ProgrammingLanguage.fromString('cpp'), ProgrammingLanguage.cpp);
    });

    test('fromString is case-insensitive (lowercases input)', () {
      expect(ProgrammingLanguage.fromString('Dart'), ProgrammingLanguage.dart);
      expect(
        ProgrammingLanguage.fromString('PYTHON'),
        ProgrammingLanguage.python,
      );
    });

    test('fromString returns plaintext for unknown values', () {
      expect(
        ProgrammingLanguage.fromString('unknown'),
        ProgrammingLanguage.plaintext,
      );
      expect(ProgrammingLanguage.fromString(''), ProgrammingLanguage.plaintext);
    });

    test('displayName returns human-readable names', () {
      expect(ProgrammingLanguage.dart.displayName, 'Dart');
      expect(ProgrammingLanguage.c.displayName, 'C');
      expect(ProgrammingLanguage.cpp.displayName, 'C++');
      expect(ProgrammingLanguage.csharp.displayName, 'C#');
      expect(ProgrammingLanguage.javascript.displayName, 'JavaScript');
      expect(ProgrammingLanguage.plaintext.displayName, 'Plain Text');
    });

    test('fileExtension returns correct extensions', () {
      expect(ProgrammingLanguage.dart.fileExtension, '.dart');
      expect(ProgrammingLanguage.python.fileExtension, '.py');
      expect(ProgrammingLanguage.c.fileExtension, '.c');
      expect(ProgrammingLanguage.javascript.fileExtension, '.js');
      expect(ProgrammingLanguage.typescript.fileExtension, '.ts');
      expect(ProgrammingLanguage.cpp.fileExtension, '.cpp');
      expect(ProgrammingLanguage.csharp.fileExtension, '.cs');
      expect(ProgrammingLanguage.plaintext.fileExtension, '.txt');
    });
  });

  test('grading criterion reads the legacy criterionId key', () {
    final criterion = GradingCriterion.fromMap(const {
      'criterionId': 'legacy-creativity',
      'name': 'Creativity',
      'percentage': 100,
    });

    expect(criterion.id, 'legacy-creativity');
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
    }) => AssignmentModel(
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
        gradingCriteria: const [
          GradingCriterion(id: 'accuracy', name: 'Accuracy', percentage: 30),
          GradingCriterion(
            id: 'completion',
            name: 'Completion',
            percentage: 70,
          ),
        ],
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
        attachments: const [
          AssignmentAttachment(
            id: 'material-1',
            name: 'Rubric.pdf',
            kind: AssignmentAttachmentKind.file,
            storagePath: 'materials/course-1/assign-1/user-1/rubric.pdf',
            mimeType: 'application/pdf',
            sizeBytes: 2048,
          ),
          AssignmentAttachment(
            id: 'material-2',
            name: 'Reference',
            kind: AssignmentAttachmentKind.link,
            url: 'https://example.com/reference',
          ),
        ],
        requiresAttachment: true,
        maxPoints: 50,
        gradingCriteria: const [
          GradingCriterion(id: 'accuracy', name: 'Accuracy', percentage: 30),
          GradingCriterion(
            id: 'completion',
            name: 'Completion',
            percentage: 70,
          ),
        ],
        dueDate: DateTime(2024, 5, 1),
        allowLateSubmission: false,
        latePenaltyPercent: 25,
        isPublished: true,
        createdAt: createdAt,
        updatedAt: DateTime(2024, 3, 10),
      );

      final roundtripped = AssignmentModel.fromMap(original.toMap());

      expect(roundtripped, equals(original));
      expect(roundtripped.attachments, hasLength(2));
      expect(roundtripped.requiresAttachment, isTrue);
      expect(roundtripped.gradingCriteria, hasLength(2));
      expect(
        roundtripped.gradingCriteria.first.equivalentPoints(
          roundtripped.maxPoints,
        ),
        15,
      );
    });

    test('grading criteria total and points follow the activity total', () {
      const criteria = [
        GradingCriterion(id: 'accuracy', name: 'Accuracy', percentage: 30),
        GradingCriterion(id: 'completion', name: 'Completion', percentage: 70),
      ];

      expect(criteria.totalPercentage, 100);
      expect(criteria.hasValidPercentageTotal, isTrue);
      expect(criteria.first.equivalentPoints(100), 30);
      expect(criteria.first.equivalentPoints(25), 7.5);

      const belowTotal = [
        GradingCriterion(id: 'accuracy', name: 'Accuracy', percentage: 30),
        GradingCriterion(id: 'completion', name: 'Completion', percentage: 60),
      ];
      const aboveTotal = [
        GradingCriterion(id: 'accuracy', name: 'Accuracy', percentage: 60),
        GradingCriterion(id: 'completion', name: 'Completion', percentage: 50),
      ];
      expect(belowTotal.totalPercentage, 90);
      expect(belowTotal.hasValidPercentageTotal, isFalse);
      expect(aboveTotal.totalPercentage, 110);
      expect(aboveTotal.hasValidPercentageTotal, isFalse);
    });

    test('criterion scores preserve the rubric snapshot and sum the grade', () {
      const scores = [
        CriterionScore(
          criterionId: 'accuracy',
          criterionName: 'Accuracy',
          maxPoints: 40,
          score: 39,
        ),
        CriterionScore(
          criterionId: 'completeness',
          criterionName: 'Completeness',
          maxPoints: 30,
          score: 28,
        ),
        CriterionScore(
          criterionId: 'presentation',
          criterionName: 'Presentation',
          maxPoints: 30,
          score: 27,
        ),
      ];

      expect(scores.totalScore, 94);
      expect(scores.totalMaxPoints, 100);
      expect(CriterionScore.fromMap(scores.first.toMap()), scores.first);
    });

    test('identifies plain activities and code activities', () {
      final activity = makeAssignment(language: ProgrammingLanguage.plaintext);
      final codeAssignment = makeAssignment();

      expect(activity.isCodeActivity, isFalse);
      expect(codeAssignment.isCodeActivity, isTrue);
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
