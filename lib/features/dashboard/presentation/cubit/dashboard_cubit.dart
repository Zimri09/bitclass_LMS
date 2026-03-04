import 'dart:developer';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../assignments/data/models/assignment_model.dart';
import '../../../assignments/data/repositories/assignment_repository.dart';
import '../../../courses/data/repositories/course_repository.dart';
import '../../../grades/data/repositories/grade_repository.dart';
import '../../../notifications/data/models/notification_model.dart';
import '../../../notifications/data/repositories/notification_repository.dart';

part 'dashboard_state.dart';

/// Cubit managing dashboard data loading and state
class DashboardCubit extends Cubit<DashboardState> {
  final CourseRepository courseRepository;
  final AssignmentRepository assignmentRepository;
  final GradeRepository gradeRepository;
  final NotificationRepository notificationRepository;

  DashboardCubit({
    required this.courseRepository,
    required this.assignmentRepository,
    required this.gradeRepository,
    required this.notificationRepository,
  }) : super(const DashboardState());

  /// Load all dashboard data for the given user
  Future<void> loadDashboard({
    required String userId,
    required bool isInstructor,
  }) async {
    emit(state.copyWith(status: DashboardStatus.loading));

    try {
      // Load recent notifications
      final notifications = await notificationRepository.getNotifications(
        userId,
      );
      final recent = notifications.take(5).toList();

      if (isInstructor) {
        await _loadInstructorData(userId, recent);
      } else {
        await _loadStudentData(userId, recent);
      }
    } catch (e) {
      if (kDebugMode) {
        log('Dashboard load error: $e', name: 'DashboardCubit');
      }
      emit(
        state.copyWith(
          status: DashboardStatus.error,
          errorMessage: 'Failed to load dashboard data',
        ),
      );
    }
  }

  Future<void> _loadStudentData(
    String userId,
    List<NotificationModel> recent,
  ) async {
    // Get enrollments
    final enrollments = await courseRepository.getUserEnrollments(userId);
    final enrolledCount = enrollments.length;
    final completedCount = enrollments.where((e) => e.isCompleted).length;

    // Calculate average grade
    String avgGrade = '-';
    try {
      final summary = await gradeRepository.getGradesSummary(userId);
      final avg = summary.overallAverage;
      if (avg > 0) {
        avgGrade = '${avg.round()}%';
      }
    } catch (e) {
      // Grade data may not be available yet
      if (kDebugMode) log('Grade data unavailable: $e', name: 'DashboardCubit');
    }

    // Gather upcoming deadlines from enrolled courses
    final now = DateTime.now();
    final deadlines = <AssignmentModel>[];
    for (final enrollment in enrollments) {
      try {
        final assignments = await assignmentRepository.getAssignmentsForCourse(
          enrollment.courseId,
        );
        deadlines.addAll(
          assignments.where(
            (a) =>
                a.dueDate != null && a.dueDate!.isAfter(now) && a.isPublished,
          ),
        );
      } catch (e) {
        // skip courses whose assignments fail to load
        if (kDebugMode) {
          log(
            'Skipping assignments for ${enrollment.courseId}: $e',
            name: 'DashboardCubit',
          );
        }
      }
    }
    deadlines.sort((a, b) => a.dueDate!.compareTo(b.dueDate!));

    emit(
      state.copyWith(
        status: DashboardStatus.loaded,
        enrolledCount: enrolledCount,
        completedCount: completedCount,
        averageGrade: avgGrade,
        recentActivity: recent,
        upcomingDeadlines: deadlines.take(5).toList(),
      ),
    );
  }

  Future<void> _loadInstructorData(
    String userId,
    List<NotificationModel> recent,
  ) async {
    // Get instructor's courses
    final courses = await courseRepository.getInstructorCourses(userId);
    final coursesTaught = courses.length;
    final totalStudents = courses.fold<int>(
      0,
      (sum, c) => sum + c.enrollmentCount,
    );

    // Count pending submissions across all courses
    int pending = 0;
    for (final course in courses) {
      try {
        final pendingSubs = await assignmentRepository.getPendingSubmissions(
          course.id,
        );
        pending += pendingSubs.length;
      } catch (e) {
        // skip courses whose submissions fail to load
        if (kDebugMode) {
          log(
            'Skipping submissions for ${course.id}: $e',
            name: 'DashboardCubit',
          );
        }
      }
    }

    emit(
      state.copyWith(
        status: DashboardStatus.loaded,
        coursesTaughtCount: coursesTaught,
        totalStudents: totalStudents,
        pendingSubmissions: pending,
        recentActivity: recent,
      ),
    );
  }

  /// Refresh the dashboard data
  Future<void> refresh({
    required String userId,
    required bool isInstructor,
  }) async {
    await loadDashboard(userId: userId, isInstructor: isInstructor);
  }
}
