import '../models/models.dart';

/// Builds the complete FCM topic set for one signed-in app installation.
class PushTopicPlanner {
  const PushTopicPlanner._();

  static Set<String> topicsFor({
    required String role,
    required Iterable<String> courseIds,
    required NotificationSettings settings,
  }) {
    if (!settings.pushEnabled) {
      return const <String>{};
    }

    return <String>{
      'role_${_sanitize(role)}',
      for (final type in NotificationType.values)
        if (settings.isTypeEnabled(type)) 'type_${_sanitize(type.name)}',
      for (final courseId in courseIds)
        if (courseId.trim().isNotEmpty) 'course_${_sanitize(courseId)}',
    };
  }

  static String _sanitize(String value) {
    return value.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9\-_.~%]'),
      '_',
    );
  }
}
