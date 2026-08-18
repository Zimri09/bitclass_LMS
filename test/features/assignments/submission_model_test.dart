import 'package:bitclass/features/assignments/data/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 13, 12);

  AssignmentModel assignment({DateTime? dueDate}) => AssignmentModel(
    id: 'assignment-1',
    courseId: 'course-1',
    title: 'Research activity',
    description: 'Research a topic',
    language: ProgrammingLanguage.plaintext,
    dueDate: dueDate,
    createdAt: DateTime.utc(2026, 8, 1),
  );

  SubmissionModel submission({
    SubmissionStatus status = SubmissionStatus.draft,
    bool isLate = false,
    DateTime? submittedAt,
  }) => SubmissionModel(
    id: 'submission-1',
    assignmentId: 'assignment-1',
    courseId: 'course-1',
    userId: 'student-1',
    userDisplayName: 'Student One',
    code: '',
    attachments: const [
      AssignmentAttachment(
        id: 'work-1',
        name: 'Answer.pdf',
        kind: AssignmentAttachmentKind.file,
        storagePath: 'submissions/course-1/assignment-1/student-1/answer.pdf',
      ),
    ],
    status: status,
    isLate: isLate,
    createdAt: DateTime.utc(2026, 8, 10),
    submittedAt: submittedAt,
  );

  group('Classroom assignment status', () {
    test('draft is assigned before the deadline', () {
      expect(
        submission().classroomStatus(
          assignment(dueDate: now.add(const Duration(hours: 1))),
          now: now,
        ),
        ClassroomSubmissionStatus.assigned,
      );
    });

    test('draft is missing after the deadline', () {
      expect(
        submission().classroomStatus(
          assignment(dueDate: now.subtract(const Duration(minutes: 1))),
          now: now,
        ),
        ClassroomSubmissionStatus.missing,
      );
    });

    test('submitted and done have distinct statuses', () {
      final currentAssignment = assignment();
      expect(
        submission(
          status: SubmissionStatus.submitted,
        ).classroomStatus(currentAssignment, now: now),
        ClassroomSubmissionStatus.submitted,
      );
      expect(
        submission(
          status: SubmissionStatus.done,
        ).classroomStatus(currentAssignment, now: now),
        ClassroomSubmissionStatus.done,
      );
    });

    test('late takes precedence over submitted or done', () {
      expect(
        submission(
          status: SubmissionStatus.submitted,
          isLate: true,
        ).classroomStatus(assignment(), now: now),
        ClassroomSubmissionStatus.late,
      );
    });
  });

  group('Unsubmit eligibility', () {
    test('submitted work can be taken back before the deadline', () {
      expect(
        submission(status: SubmissionStatus.submitted).canUnsubmit(
          assignment(dueDate: now.add(const Duration(minutes: 1))),
          now: now,
        ),
        isTrue,
      );
    });

    test('submitted work cannot be taken back after the deadline', () {
      expect(
        submission(status: SubmissionStatus.submitted).canUnsubmit(
          assignment(dueDate: now.subtract(const Duration(minutes: 1))),
          now: now,
        ),
        isFalse,
      );
    });

    test('graded work and drafts cannot be unsubmitted', () {
      expect(
        submission(
          status: SubmissionStatus.graded,
        ).canUnsubmit(assignment(), now: now),
        isFalse,
      );
      expect(submission().canUnsubmit(assignment(), now: now), isFalse);
    });
  });

  test('attachment metadata survives a submission map round trip', () {
    final original = submission(
      status: SubmissionStatus.submitted,
    ).copyWith(assignmentTitle: 'Research activity', assignmentMaxPoints: 25);
    final restored = SubmissionModel.fromMap(original.toMap());

    expect(restored, original);
    expect(restored.attachments.single.name, 'Answer.pdf');
    expect(restored.assignmentDisplayTitle, 'Research activity');
    expect(restored.resolvedMaxPoints, 25);
  });
}
