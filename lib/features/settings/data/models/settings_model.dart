import 'package:equatable/equatable.dart';

/// Local application settings (theme, learning preferences)
class AppSettingsModel extends Equatable {
  final bool darkMode;
  final bool autoPlayVideos;
  final bool downloadOverWifiOnly;

  const AppSettingsModel({
    this.darkMode = true,
    this.autoPlayVideos = false,
    this.downloadOverWifiOnly = true,
  });

  /// Default settings
  static const AppSettingsModel defaults = AppSettingsModel();

  @override
  List<Object?> get props => [darkMode, autoPlayVideos, downloadOverWifiOnly];

  AppSettingsModel copyWith({
    bool? darkMode,
    bool? autoPlayVideos,
    bool? downloadOverWifiOnly,
  }) {
    return AppSettingsModel(
      darkMode: darkMode ?? this.darkMode,
      autoPlayVideos: autoPlayVideos ?? this.autoPlayVideos,
      downloadOverWifiOnly: downloadOverWifiOnly ?? this.downloadOverWifiOnly,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'darkMode': darkMode,
      'autoPlayVideos': autoPlayVideos,
      'downloadOverWifiOnly': downloadOverWifiOnly,
    };
  }

  factory AppSettingsModel.fromMap(Map<String, dynamic> map) {
    return AppSettingsModel(
      darkMode: map['darkMode'] as bool? ?? true,
      autoPlayVideos: map['autoPlayVideos'] as bool? ?? false,
      downloadOverWifiOnly: map['downloadOverWifiOnly'] as bool? ?? true,
    );
  }
}
