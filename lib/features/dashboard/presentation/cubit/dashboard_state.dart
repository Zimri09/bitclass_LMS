part of 'dashboard_cubit.dart';

/// Status of the dashboard data loading
enum DashboardStatus { initial, loading, loaded, error }

/// State for the DashboardCubit
class DashboardState extends Equatable {
  final DashboardStatus status;

  // Student stats
  final int enrolledCount;
  final int completedCount;
  final String averageGrade;

  // Instructor stats
  final int coursesTaughtCount;
  final int totalStudents;
  final int pendingSubmissions;

  // Shared
  final List<NotificationModel> recentActivity;
  final List<AssignmentModel> upcomingDeadlines;
  final String? errorMessage;

  const DashboardState({
    this.status = DashboardStatus.initial,
    this.enrolledCount = 0,
    this.completedCount = 0,
    this.averageGrade = '-',
    this.coursesTaughtCount = 0,
    this.totalStudents = 0,
    this.pendingSubmissions = 0,
    this.recentActivity = const [],
    this.upcomingDeadlines = const [],
    this.errorMessage,
  });

  @override
  List<Object?> get props => [
    status,
    enrolledCount,
    completedCount,
    averageGrade,
    coursesTaughtCount,
    totalStudents,
    pendingSubmissions,
    recentActivity,
    upcomingDeadlines,
    errorMessage,
  ];

  DashboardState copyWith({
    DashboardStatus? status,
    int? enrolledCount,
    int? completedCount,
    String? averageGrade,
    int? coursesTaughtCount,
    int? totalStudents,
    int? pendingSubmissions,
    List<NotificationModel>? recentActivity,
    List<AssignmentModel>? upcomingDeadlines,
    String? errorMessage,
  }) {
    return DashboardState(
      status: status ?? this.status,
      enrolledCount: enrolledCount ?? this.enrolledCount,
      completedCount: completedCount ?? this.completedCount,
      averageGrade: averageGrade ?? this.averageGrade,
      coursesTaughtCount: coursesTaughtCount ?? this.coursesTaughtCount,
      totalStudents: totalStudents ?? this.totalStudents,
      pendingSubmissions: pendingSubmissions ?? this.pendingSubmissions,
      recentActivity: recentActivity ?? this.recentActivity,
      upcomingDeadlines: upcomingDeadlines ?? this.upcomingDeadlines,
      errorMessage: errorMessage,
    );
  }
}
