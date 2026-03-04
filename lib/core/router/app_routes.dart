/// Route names and paths for the application
library;

class AppRoutes {
  AppRoutes._();

  // Auth routes
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';

  // Main app routes
  static const String dashboard = '/dashboard';
  static const String profile = '/profile';

  // Course routes
  static const String courses = '/courses';
  static const String courseDetail = '/courses/:courseId';
  static const String createCourse = '/courses/create';
  static const String editCourse = '/courses/:courseId/edit';
  static const String myCourses = '/my-courses';
  static const String enrolledCourses = '/enrolled-courses';

  // Lesson routes
  static const String lesson = '/courses/:courseId/lessons/:lessonId';
  static const String createLesson = '/courses/:courseId/lessons/create';
  static const String editLesson = '/courses/:courseId/lessons/:lessonId/edit';

  // Quiz routes
  static const String quiz = '/courses/:courseId/quizzes/:quizId';
  static const String quizResult = '/courses/:courseId/quizzes/:quizId/result';
  static const String createQuiz = '/courses/:courseId/quizzes/create';

  // Assignment routes
  static const String assignments = '/courses/:courseId/assignments';
  static const String assignment =
      '/courses/:courseId/assignments/:assignmentId';
  static const String createAssignment =
      '/courses/:courseId/assignments/create';
  static const String editAssignment =
      '/courses/:courseId/assignments/:assignmentId/edit';
  static const String submitAssignment =
      '/courses/:courseId/assignments/:assignmentId/submit';
  static const String gradeAssignment =
      '/courses/:courseId/assignments/:assignmentId/grade';

  // Discussion routes
  static const String discussions = '/courses/:courseId/discussions';
  static const String channel = '/courses/:courseId/discussions/:channelId';
  static const String thread =
      '/courses/:courseId/discussions/:channelId/threads/:threadId';
  static const String createThread =
      '/courses/:courseId/discussions/:channelId/threads/create';

  // Notification routes
  static const String notifications = '/notifications';
  static const String notificationSettings = '/notifications/settings';

  // Enrolled students
  static const String courseStudents = '/courses/:courseId/students';

  // File routes
  static const String files = '/courses/:courseId/files';
  static const String uploadFile = '/courses/:courseId/files/upload';

  // Grades
  static const String grades = '/grades';

  // Settings
  static const String settings = '/settings';

  // Helper methods to build paths with parameters
  static String courseDetailPath(String courseId) => '/courses/$courseId';
  static String lessonPath(String courseId, String lessonId) =>
      '/courses/$courseId/lessons/$lessonId';
  static String quizPath(String courseId, String quizId) =>
      '/courses/$courseId/quizzes/$quizId';
  static String assignmentPath(String courseId, String assignmentId) =>
      '/courses/$courseId/assignments/$assignmentId';
  static String channelPath(String courseId, String channelId) =>
      '/courses/$courseId/discussions/$channelId';
  static String threadPath(
    String courseId,
    String channelId,
    String threadId,
  ) => '/courses/$courseId/discussions/$channelId/threads/$threadId';
  static String editCoursePath(String courseId) => '/courses/$courseId/edit';
  static String editLessonPath(String courseId, String lessonId) =>
      '/courses/$courseId/lessons/$lessonId/edit';
  static String editAssignmentPath(String courseId, String assignmentId) =>
      '/courses/$courseId/assignments/$assignmentId/edit';
  static String submitAssignmentPath(String courseId, String assignmentId) =>
      '/courses/$courseId/assignments/$assignmentId/submit';
  static String gradeAssignmentPath(String courseId, String assignmentId) =>
      '/courses/$courseId/assignments/$assignmentId/grade';
  static String quizResultPath(String courseId, String quizId) =>
      '/courses/$courseId/quizzes/$quizId/result';
  static String courseStudentsPath(String courseId) =>
      '/courses/$courseId/students';
  static String filesPath(String courseId) => '/courses/$courseId/files';
  static String uploadFilePath(String courseId) =>
      '/courses/$courseId/files/upload';
}
