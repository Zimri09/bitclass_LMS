import 'package:equatable/equatable.dart';

import 'notification_model.dart';

/// User notification preferences
class NotificationSettings extends Equatable {
  final String userId;
  final bool pushEnabled;
  final bool emailEnabled;
  final Map<NotificationType, bool> typeSettings;
  final bool quietHoursEnabled;
  final int quietHoursStart; // Hour of day (0-23)
  final int quietHoursEnd;
  final DateTime updatedAt;

  const NotificationSettings({
    required this.userId,
    this.pushEnabled = true,
    this.emailEnabled = true,
    Map<NotificationType, bool>? typeSettings,
    this.quietHoursEnabled = false,
    this.quietHoursStart = 22,
    this.quietHoursEnd = 8,
    required this.updatedAt,
  }) : typeSettings = typeSettings ?? const {};

  /// Get default settings with all notification types enabled
  factory NotificationSettings.defaults(String userId) {
    return NotificationSettings(
      userId: userId,
      pushEnabled: true,
      emailEnabled: true,
      typeSettings: {for (var type in NotificationType.values) type: true},
      updatedAt: DateTime.now(),
    );
  }

  bool isTypeEnabled(NotificationType type) {
    return typeSettings[type] ?? true;
  }

  NotificationSettings copyWith({
    String? userId,
    bool? pushEnabled,
    bool? emailEnabled,
    Map<NotificationType, bool>? typeSettings,
    bool? quietHoursEnabled,
    int? quietHoursStart,
    int? quietHoursEnd,
    DateTime? updatedAt,
  }) {
    return NotificationSettings(
      userId: userId ?? this.userId,
      pushEnabled: pushEnabled ?? this.pushEnabled,
      emailEnabled: emailEnabled ?? this.emailEnabled,
      typeSettings: typeSettings ?? this.typeSettings,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'pushEnabled': pushEnabled,
      'emailEnabled': emailEnabled,
      'typeSettings': typeSettings.map(
        (key, value) => MapEntry(key.name, value),
      ),
      'quietHoursEnabled': quietHoursEnabled,
      'quietHoursStart': quietHoursStart,
      'quietHoursEnd': quietHoursEnd,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    final typeSettingsJson =
        json['typeSettings'] as Map<String, dynamic>? ?? {};
    final typeSettings = <NotificationType, bool>{};

    for (var entry in typeSettingsJson.entries) {
      final type = NotificationType.values.firstWhere(
        (e) => e.name == entry.key,
        orElse: () => NotificationType.general,
      );
      typeSettings[type] = entry.value as bool;
    }

    return NotificationSettings(
      userId: json['userId'] as String,
      pushEnabled: json['pushEnabled'] as bool? ?? true,
      emailEnabled: json['emailEnabled'] as bool? ?? true,
      typeSettings: typeSettings,
      quietHoursEnabled: json['quietHoursEnabled'] as bool? ?? false,
      quietHoursStart: json['quietHoursStart'] as int? ?? 22,
      quietHoursEnd: json['quietHoursEnd'] as int? ?? 8,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// Create from Firestore document (alias for fromJson)
  factory NotificationSettings.fromMap(Map<String, dynamic> map) {
    return NotificationSettings.fromJson(map);
  }

  /// Convert to Firestore document
  Map<String, dynamic> toMap() => toJson();

  @override
  List<Object?> get props => [
    userId,
    pushEnabled,
    emailEnabled,
    typeSettings,
    quietHoursEnabled,
    quietHoursStart,
    quietHoursEnd,
    updatedAt,
  ];
}
