import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/config/environment.dart';
import '../../../../core/utils/url_utils.dart';
import '../models/models.dart';

part '../fixtures/assignment_demo_data.dart';

/// Repository for assignment operations.
class AssignmentRepository {
  static const String _assignmentsTable = 'assignments';
  static const String _submissionsTable = 'submissions';
  static const String _attachmentBucket = 'assignment_attachments';
  static const int maxAttachmentBytes = 25 * 1024 * 1024;
  static const int maxAttachments = 10;

  static const String _demoStudentUserId = 'demo-user-1';
  static const String _legacyDemoStudentUserId = 'demo_user';

  final SupabaseClient? _supabase;

  // Demo data storage
  final Map<String, AssignmentModel> _assignments = {};
  final Map<String, List<SubmissionModel>> _submissionsByAssignment = {};
  final Map<String, Map<String, SubmissionModel>> _submissionsByUser = {};

  AssignmentRepository({SupabaseClient? supabase})
    : _supabase = EnvironmentConfig.isDemoMode
          ? null
          : (supabase ?? Supabase.instance.client) {
    if (EnvironmentConfig.isDemoMode) {
      _initDemoData();
    }
  }

  bool _isDemoStudentAlias(String userId) {
    return userId == _demoStudentUserId || userId == _legacyDemoStudentUserId;
  }

  String _normalizeDemoUserId(String userId) {
    return _isDemoStudentAlias(userId) ? _demoStudentUserId : userId;
  }

  Iterable<String> _demoUserKeys(String userId) sync* {
    final normalized = _normalizeDemoUserId(userId);
    yield normalized;
    if (normalized == _demoStudentUserId) {
      yield _legacyDemoStudentUserId;
    }
  }

  Map<String, dynamic> _rowToAssignmentMap(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'courseId': row['course_id'],
      'lessonId': row['lesson_id'],
      'title': row['title'],
      'description': row['description'],
      'instructions': row['instructions'],
      'language': row['language'],
      'starterCode': row['starter_code'],
      'solutionCode': row['solution_code'],
      'attachments': row['attachments'],
      'requiresAttachment': row['requires_attachment'],
      'maxPoints': row['max_points'],
      'dueDate': row['due_date']?.toString(),
      'allowLateSubmission': row['allow_late_submission'],
      'latePenaltyPercent': row['late_penalty_percent'],
      'isPublished': row['is_published'],
      'createdAt': row['created_at']?.toString(),
      'updatedAt': row['updated_at']?.toString(),
    };
  }

  AssignmentModel _assignmentFromRow(Map<String, dynamic> row) {
    return AssignmentModel.fromMap(_rowToAssignmentMap(row));
  }

  Map<String, dynamic> _rowToSubmissionMap(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'assignmentId': row['assignment_id'],
      'courseId': row['course_id'],
      'userId': row['user_id'],
      'userDisplayName': row['user_display_name'],
      'code': row['code'],
      'attachments': row['attachments'],
      'status': row['status'],
      'score': row['score'],
      'feedback': row['feedback'],
      'gradedBy': row['graded_by'],
      'gradedAt': row['graded_at']?.toString(),
      'isLate': row['is_late'],
      'createdAt': row['created_at']?.toString(),
      'updatedAt': row['updated_at']?.toString(),
      'submittedAt': row['submitted_at']?.toString(),
    };
  }

  SubmissionModel _submissionFromRow(Map<String, dynamic> row) {
    return SubmissionModel.fromMap(_rowToSubmissionMap(row));
  }

  Map<String, dynamic> _assignmentToRow(
    AssignmentModel assignment, {
    required bool includeCreatedAt,
  }) {
    return {
      'id': assignment.id,
      'course_id': assignment.courseId,
      'lesson_id': assignment.lessonId,
      'title': assignment.title,
      'description': assignment.description,
      'instructions': assignment.instructions,
      'language': assignment.language.name,
      'starter_code': assignment.starterCode,
      'solution_code': assignment.solutionCode,
      'attachments': assignment.attachments
          .map((attachment) => attachment.toMap())
          .toList(),
      'requires_attachment': assignment.requiresAttachment,
      'max_points': assignment.maxPoints,
      'due_date': assignment.dueDate?.toUtc().toIso8601String(),
      'allow_late_submission': assignment.allowLateSubmission,
      'late_penalty_percent': assignment.latePenaltyPercent,
      'is_published': assignment.isPublished,
      if (includeCreatedAt)
        'created_at': assignment.createdAt.toUtc().toIso8601String(),
      'updated_at': (assignment.updatedAt ?? DateTime.now())
          .toUtc()
          .toIso8601String(),
    };
  }

  Map<String, dynamic> _submissionToRow(SubmissionModel submission) {
    return {
      'id': submission.id,
      'assignment_id': submission.assignmentId,
      'course_id': submission.courseId,
      'user_id': submission.userId,
      'user_display_name': submission.userDisplayName,
      'code': submission.code,
      'attachments': submission.attachments
          .map((attachment) => attachment.toMap())
          .toList(),
      'status': submission.status.name,
      'score': submission.score,
      'feedback': submission.feedback,
      'graded_by': submission.gradedBy,
      'graded_at': submission.gradedAt?.toUtc().toIso8601String(),
      'is_late': submission.isLate,
      'created_at': submission.createdAt.toUtc().toIso8601String(),
      'updated_at': (submission.updatedAt ?? DateTime.now())
          .toUtc()
          .toIso8601String(),
      'submitted_at': submission.submittedAt?.toUtc().toIso8601String(),
    };
  }

  void _cacheDemoSubmission(SubmissionModel submission) {
    for (final key in _demoUserKeys(submission.userId)) {
      _submissionsByUser[key] ??= {};
      _submissionsByUser[key]![submission.assignmentId] = submission;
    }

    final submissions = _submissionsByAssignment[submission.assignmentId] ?? [];
    final index = submissions.indexWhere(
      (item) =>
          _normalizeDemoUserId(item.userId) ==
          _normalizeDemoUserId(submission.userId),
    );
    if (index >= 0) {
      submissions[index] = submission;
    } else {
      submissions.add(submission);
    }
    _submissionsByAssignment[submission.assignmentId] = submissions;
  }

  /// Get assignments for a course. Managers may include unpublished drafts.
  Future<List<AssignmentModel>> getAssignmentsForCourse(
    String courseId, {
    bool includeDrafts = false,
  }) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      return _assignments.values
          .where(
            (assignment) =>
                assignment.courseId == courseId &&
                (includeDrafts || assignment.isPublished),
          )
          .toList()
        ..sort(
          (a, b) => a.dueDate?.compareTo(b.dueDate ?? DateTime.now()) ?? 0,
        );
    }

    try {
      var query = _supabase!
          .from(_assignmentsTable)
          .select()
          .eq('course_id', courseId);
      if (!includeDrafts) {
        query = query.eq('is_published', true);
      }
      final rows = await query.order('due_date', ascending: true);

      final assignments = (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(_assignmentFromRow)
          .toList();

      assignments.sort(
        (a, b) => a.dueDate?.compareTo(b.dueDate ?? DateTime.now()) ?? 0,
      );

      return assignments;
    } catch (e) {
      if (kDebugMode) {
        log('Error fetching assignments: $e', name: 'AssignmentRepository');
      }
      return [];
    }
  }

  /// Get a single assignment by ID
  Future<AssignmentModel?> getAssignment(String assignmentId) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 200));
      return _assignments[assignmentId];
    }

    try {
      final row = await _supabase!
          .from(_assignmentsTable)
          .select()
          .eq('id', assignmentId)
          .maybeSingle();

      if (row == null) return null;
      return _assignmentFromRow(row);
    } catch (e) {
      if (kDebugMode) {
        log('Error fetching assignment: $e', name: 'AssignmentRepository');
      }
      return null;
    }
  }

  /// Create a new assignment (instructor only)
  Future<AssignmentModel> createAssignment(AssignmentModel assignment) async {
    _validateAttachments(assignment.attachments);
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      _assignments[assignment.id] = assignment;
      return assignment;
    }

    await _supabase!
        .from(_assignmentsTable)
        .insert(_assignmentToRow(assignment, includeCreatedAt: true));

    return assignment;
  }

  /// Update an assignment (instructor only)
  Future<AssignmentModel> updateAssignment(AssignmentModel assignment) async {
    _validateAttachments(assignment.attachments);
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      _assignments[assignment.id] = assignment;
      return assignment;
    }

    final row = _assignmentToRow(assignment, includeCreatedAt: false)
      ..remove('id');
    await _supabase!
        .from(_assignmentsTable)
        .update(row)
        .eq('id', assignment.id);

    return assignment;
  }

  /// Delete an assignment (instructor only)
  Future<void> deleteAssignment(String assignmentId) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      _assignments.remove(assignmentId);
      _submissionsByAssignment.remove(assignmentId);
      for (final submissions in _submissionsByUser.values) {
        submissions.remove(assignmentId);
      }
      return;
    }

    final assignment = await getAssignment(assignmentId);
    final submissions = await getAssignmentSubmissions(assignmentId);
    final storagePaths = <String>{
      ...?assignment?.attachments
          .map((attachment) => attachment.storagePath)
          .whereType<String>(),
      ...submissions
          .expand((submission) => submission.attachments)
          .map((attachment) => attachment.storagePath)
          .whereType<String>(),
    };
    if (storagePaths.isNotEmpty) {
      await _supabase!.storage
          .from(_attachmentBucket)
          .remove(storagePaths.toList());
    }

    await _supabase!
        .from(_submissionsTable)
        .delete()
        .eq('assignment_id', assignmentId);
    await _supabase.from(_assignmentsTable).delete().eq('id', assignmentId);
  }

  Future<AssignmentAttachment> uploadAttachment({
    required String courseId,
    required String assignmentId,
    required String userId,
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
    required bool isSubmission,
  }) async {
    if (bytes.isEmpty) throw Exception('The selected file is empty.');
    if (bytes.length > maxAttachmentBytes) {
      throw Exception('Attachments must be 25 MB or smaller.');
    }

    final attachmentId = const Uuid().v4();
    final normalizedName = _safeFileName(fileName);
    final scope = isSubmission ? 'submissions' : 'materials';
    final storagePath =
        '$scope/$courseId/$assignmentId/$userId/$attachmentId-$normalizedName';

    if (!EnvironmentConfig.isDemoMode) {
      await _supabase!.storage
          .from(_attachmentBucket)
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(contentType: mimeType, upsert: false),
          );
    }

    return AssignmentAttachment(
      id: attachmentId,
      name: fileName.trim(),
      kind: AssignmentAttachmentKind.file,
      storagePath: storagePath,
      mimeType: mimeType,
      sizeBytes: bytes.length,
    );
  }

  Future<void> deleteStoredAttachment(AssignmentAttachment attachment) async {
    final path = attachment.storagePath;
    if (EnvironmentConfig.isDemoMode || path == null || path.isEmpty) return;
    await _supabase!.storage.from(_attachmentBucket).remove([path]);
  }

  Future<String> getAttachmentUrl(AssignmentAttachment attachment) async {
    if (attachment.isLink) {
      final url = attachment.url;
      if (url == null || url.isEmpty) throw Exception('This link is invalid.');
      return normalizeWebUrl(url).toString();
    }

    final path = attachment.storagePath;
    if (path == null || path.isEmpty) {
      throw Exception('This file is no longer available.');
    }
    if (EnvironmentConfig.isDemoMode) {
      return 'https://example.com/$path';
    }
    return _supabase!.storage
        .from(_attachmentBucket)
        .createSignedUrl(path, 10 * 60);
  }

  String _safeFileName(String value) {
    var result = value
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    if (result.isEmpty) result = 'attachment';
    if (result.length > 120) result = result.substring(result.length - 120);
    return result;
  }

  void _validateAttachments(List<AssignmentAttachment> attachments) {
    if (attachments.length > maxAttachments) {
      throw Exception('You can attach up to 10 items.');
    }
    for (final attachment in attachments) {
      if (attachment.name.trim().isEmpty) {
        throw Exception('Every attachment needs a name.');
      }
      if (attachment.isLink) {
        normalizeWebUrl(attachment.url ?? '');
      } else if (attachment.storagePath?.trim().isEmpty ?? true) {
        throw Exception('An attached file is missing its storage path.');
      }
    }
  }

  /// Get user's submission for an assignment
  Future<SubmissionModel?> getUserSubmission(
    String assignmentId,
    String userId,
  ) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 200));
      for (final key in _demoUserKeys(userId)) {
        final submission = _submissionsByUser[key]?[assignmentId];
        if (submission != null) return submission;
      }
      return null;
    }

    try {
      final row = await _supabase!
          .from(_submissionsTable)
          .select()
          .eq('assignment_id', assignmentId)
          .eq('user_id', userId)
          .maybeSingle();

      if (row == null) return null;
      return _submissionFromRow(row);
    } catch (e) {
      if (kDebugMode) {
        log('Error fetching user submission: $e', name: 'AssignmentRepository');
      }
      return null;
    }
  }

  /// Get all submissions for an assignment (instructor only)
  Future<List<SubmissionModel>> getAssignmentSubmissions(
    String assignmentId,
  ) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      return _submissionsByAssignment[assignmentId] ?? [];
    }

    try {
      final rows = await _supabase!
          .from(_submissionsTable)
          .select()
          .eq('assignment_id', assignmentId)
          .order('created_at', ascending: false);

      return (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(_submissionFromRow)
          .toList();
    } catch (e) {
      if (kDebugMode) {
        log(
          'Error fetching assignment submissions: $e',
          name: 'AssignmentRepository',
        );
      }
      return [];
    }
  }

  /// Save a draft submission
  Future<SubmissionModel> saveDraft({
    required String assignmentId,
    required String courseId,
    required String userId,
    required String userDisplayName,
    required String code,
    List<AssignmentAttachment>? attachments,
  }) async {
    final existing = await getUserSubmission(assignmentId, userId);
    if (existing != null && existing.status != SubmissionStatus.draft) {
      throw Exception('Unsubmit this work before making changes.');
    }
    final draftAttachments =
        attachments ?? existing?.attachments ?? const <AssignmentAttachment>[];
    _validateAttachments(draftAttachments);

    final normalizedUserId = EnvironmentConfig.isDemoMode
        ? _normalizeDemoUserId(userId)
        : userId;
    final now = DateTime.now();
    final submission = SubmissionModel(
      id: existing?.id ?? const Uuid().v4(),
      assignmentId: assignmentId,
      courseId: courseId,
      userId: normalizedUserId,
      userDisplayName: userDisplayName,
      code: code,
      attachments: draftAttachments,
      status: SubmissionStatus.draft,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      _cacheDemoSubmission(submission);
    } else {
      await _supabase!
          .from(_submissionsTable)
          .upsert(_submissionToRow(submission));
    }

    return submission;
  }

  /// Submit an assignment
  Future<SubmissionModel> submitAssignment({
    required String assignmentId,
    required String courseId,
    required String userId,
    required String userDisplayName,
    required String code,
    List<AssignmentAttachment>? attachments,
  }) async {
    final assignment = await getAssignment(assignmentId);
    if (assignment == null || assignment.courseId != courseId) {
      throw Exception('Assignment not found for this course.');
    }
    if (!assignment.isPublished) {
      throw Exception('This assignment is not available for submission.');
    }

    final now = DateTime.now();
    final isLate =
        assignment.dueDate != null && now.isAfter(assignment.dueDate!);
    if (isLate && !assignment.allowLateSubmission) {
      throw Exception(
        'The deadline has passed and late submissions are closed.',
      );
    }

    final existing = await getUserSubmission(assignmentId, userId);
    if (existing != null && existing.status != SubmissionStatus.draft) {
      throw Exception('This work is already submitted. Unsubmit it first.');
    }
    final submittedAttachments =
        attachments ?? existing?.attachments ?? const <AssignmentAttachment>[];
    _validateAttachments(submittedAttachments);
    if (assignment.requiresAttachment && submittedAttachments.isEmpty) {
      throw Exception('Attach at least one file or link before submitting.');
    }
    if (assignment.isCodeActivity && code.trim().isEmpty) {
      throw Exception('Enter your work in the code editor before submitting.');
    }

    final submission = SubmissionModel(
      id: existing?.id ?? const Uuid().v4(),
      assignmentId: assignmentId,
      courseId: courseId,
      userId: EnvironmentConfig.isDemoMode
          ? _normalizeDemoUserId(userId)
          : userId,
      userDisplayName: userDisplayName,
      code: code,
      attachments: submittedAttachments,
      status: SubmissionStatus.submitted,
      isLate: isLate,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      submittedAt: now,
    );

    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      _cacheDemoSubmission(submission);
    } else {
      await _supabase!
          .from(_submissionsTable)
          .upsert(_submissionToRow(submission));
    }

    return submission;
  }

  Future<SubmissionModel> markAsDone({
    required String assignmentId,
    required String courseId,
    required String userId,
    required String userDisplayName,
    String code = '',
    List<AssignmentAttachment>? attachments,
  }) async {
    final assignment = await getAssignment(assignmentId);
    if (assignment == null || assignment.courseId != courseId) {
      throw Exception('Assignment not found for this course.');
    }
    if (!assignment.isPublished) {
      throw Exception('This assignment is not available for completion.');
    }
    if (assignment.requiresAttachment || assignment.isCodeActivity) {
      throw Exception('This assignment must be submitted with work.');
    }

    final now = DateTime.now();
    final isLate =
        assignment.dueDate != null && now.isAfter(assignment.dueDate!);
    if (isLate && !assignment.allowLateSubmission) {
      throw Exception(
        'The deadline has passed and late submissions are closed.',
      );
    }

    final existing = await getUserSubmission(assignmentId, userId);
    if (existing != null && existing.status != SubmissionStatus.draft) {
      throw Exception('This activity is already completed.');
    }

    final completedAttachments =
        attachments ?? existing?.attachments ?? const <AssignmentAttachment>[];
    _validateAttachments(completedAttachments);

    final submission = SubmissionModel(
      id: existing?.id ?? const Uuid().v4(),
      assignmentId: assignmentId,
      courseId: courseId,
      userId: EnvironmentConfig.isDemoMode
          ? _normalizeDemoUserId(userId)
          : userId,
      userDisplayName: userDisplayName,
      code: code,
      attachments: completedAttachments,
      status: SubmissionStatus.done,
      isLate: isLate,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      submittedAt: now,
    );

    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 400));
      _cacheDemoSubmission(submission);
    } else {
      await _supabase!
          .from(_submissionsTable)
          .upsert(_submissionToRow(submission));
    }
    return submission;
  }

  Future<SubmissionModel> unsubmitAssignment({
    required String assignmentId,
    required String userId,
  }) async {
    final assignment = await getAssignment(assignmentId);
    final existing = await getUserSubmission(assignmentId, userId);
    if (assignment == null || existing == null) {
      throw Exception('Submitted work was not found.');
    }
    if (!existing.canUnsubmit(assignment)) {
      throw Exception(
        'Work can only be unsubmitted before the deadline and grading.',
      );
    }

    if (EnvironmentConfig.isDemoMode) {
      final draft = existing.copyWith(
        status: SubmissionStatus.draft,
        isLate: false,
        updatedAt: DateTime.now(),
        clearSubmittedAt: true,
      );
      _cacheDemoSubmission(draft);
      return draft;
    }

    await _supabase!.rpc(
      'unsubmit_assignment',
      params: {'p_assignment_id': assignmentId},
    );
    final draft = await getUserSubmission(assignmentId, userId);
    if (draft == null || draft.status != SubmissionStatus.draft) {
      throw Exception('The submission could not be taken back.');
    }
    return draft;
  }

  /// Grade a submission (instructor only)
  Future<SubmissionModel> gradeSubmission({
    required String submissionId,
    required String assignmentId,
    required int score,
    required String feedback,
    required String gradedBy,
  }) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 400));

      final submissions = _submissionsByAssignment[assignmentId];
      if (submissions == null) {
        throw Exception('Submission not found');
      }

      final index = submissions.indexWhere((s) => s.id == submissionId);
      if (index < 0) {
        throw Exception('Submission not found');
      }

      final updatedSubmission = submissions[index].copyWith(
        status: SubmissionStatus.graded,
        score: score,
        feedback: feedback,
        gradedBy: gradedBy,
        gradedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      submissions[index] = updatedSubmission;
      for (final key in _demoUserKeys(updatedSubmission.userId)) {
        _submissionsByUser[key] ??= {};
        _submissionsByUser[key]![assignmentId] = updatedSubmission;
      }

      return updatedSubmission;
    }

    await _supabase!
        .from(_submissionsTable)
        .update({
          'status': SubmissionStatus.graded.name,
          'score': score,
          'feedback': feedback,
          'graded_by': gradedBy,
          'graded_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', submissionId);

    final row = await _supabase
        .from(_submissionsTable)
        .select()
        .eq('id', submissionId)
        .maybeSingle();

    if (row == null) {
      throw Exception('Submission not found');
    }

    return _submissionFromRow(row);
  }

  /// Get pending submissions for instructor (ungraded submissions)
  Future<List<SubmissionModel>> getPendingSubmissions(String courseId) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      final pending = <SubmissionModel>[];
      for (final submissions in _submissionsByAssignment.values) {
        pending.addAll(
          submissions.where(
            (s) =>
                s.courseId == courseId &&
                (s.status == SubmissionStatus.submitted ||
                    s.status == SubmissionStatus.done),
          ),
        );
      }
      return pending;
    }

    try {
      final rows = await _supabase!
          .from(_submissionsTable)
          .select()
          .eq('course_id', courseId)
          .inFilter('status', [
            SubmissionStatus.submitted.name,
            SubmissionStatus.done.name,
          ]);

      return (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(_submissionFromRow)
          .toList();
    } catch (e) {
      if (kDebugMode) {
        log(
          'Error fetching pending submissions: $e',
          name: 'AssignmentRepository',
        );
      }
      return [];
    }
  }

  /// Get user's submissions across all assignments in a course
  Future<List<SubmissionModel>> getUserSubmissionsForCourse(
    String courseId,
    String userId,
  ) async {
    if (EnvironmentConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      final byId = <String, SubmissionModel>{};
      for (final key in _demoUserKeys(userId)) {
        final userSubmissions = _submissionsByUser[key];
        if (userSubmissions == null) continue;
        for (final submission in userSubmissions.values) {
          if (submission.courseId == courseId) {
            byId[submission.id] = submission;
          }
        }
      }
      return byId.values.toList();
    }

    try {
      final rows = await _supabase!
          .from(_submissionsTable)
          .select()
          .eq('course_id', courseId)
          .eq('user_id', userId);

      return (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(_submissionFromRow)
          .toList();
    } catch (e) {
      if (kDebugMode) {
        log(
          'Error fetching user submissions: $e',
          name: 'AssignmentRepository',
        );
      }
      return [];
    }
  }
}
