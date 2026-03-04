/// Firestore collection paths used throughout the app
class FirestorePaths {
  FirestorePaths._();

  // Root collections
  static const String users = 'users';
  static const String courses = 'courses';
  static const String notifications = 'notifications';
  static const String enrollments = 'enrollments';

  // User subcollections
  static String userProfile(String userId) => '$users/$userId';
  static String userEnrollments(String userId) => '$users/$userId/enrollments';
  static String userNotificationSettings(String userId) =>
      '$users/$userId/settings/notifications';
  static String userDeviceTokens(String userId) =>
      '$users/$userId/deviceTokens';

  // Course subcollections
  static String courseLessons(String courseId) => '$courses/$courseId/lessons';
  static String courseQuizzes(String courseId) => '$courses/$courseId/quizzes';
  static String courseAssignments(String courseId) =>
      '$courses/$courseId/assignments';
  static String courseFiles(String courseId) => '$courses/$courseId/files';
  static String courseDiscussionChannels(String courseId) =>
      '$courses/$courseId/discussionChannels';
  static String courseEnrollments(String courseId) =>
      '$courses/$courseId/enrollments';

  // Lesson progress
  static String lessonProgress(
    String userId,
    String courseId,
    String lessonId,
  ) => '$users/$userId/courses/$courseId/lessons/$lessonId/progress';

  // Quiz attempts
  static String quizAttempts(String courseId, String quizId) =>
      '$courses/$courseId/quizzes/$quizId/attempts';

  // Assignment submissions
  static String assignmentSubmissions(String courseId, String assignmentId) =>
      '$courses/$courseId/assignments/$assignmentId/submissions';

  // Discussion threads
  static String discussionThreads(String courseId, String channelId) =>
      '$courses/$courseId/discussionChannels/$channelId/threads';

  // Thread replies
  static String threadReplies(
    String courseId,
    String channelId,
    String threadId,
  ) =>
      '$courses/$courseId/discussionChannels/$channelId/threads/$threadId/replies';
}
