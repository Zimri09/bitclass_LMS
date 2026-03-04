import 'package:hive_flutter/hive_flutter.dart';

import '../models/models.dart';

/// Repository for persisting local application settings using Hive
class SettingsRepository {
  static const String _boxName = 'app_settings';
  static const String _settingsKey = 'settings';

  Box? _box;

  /// Open the Hive box (call once at startup or lazily)
  Future<void> _ensureBoxOpen() async {
    _box ??= await Hive.openBox(_boxName);
  }

  /// Load saved settings, or return defaults if none exist
  Future<AppSettingsModel> getSettings() async {
    await _ensureBoxOpen();
    final data = _box!.get(_settingsKey);
    if (data == null) return AppSettingsModel.defaults;
    return AppSettingsModel.fromMap(Map<String, dynamic>.from(data as Map));
  }

  /// Persist settings to local storage
  Future<void> saveSettings(AppSettingsModel settings) async {
    await _ensureBoxOpen();
    await _box!.put(_settingsKey, settings.toMap());
  }

  /// Update a single setting and persist
  Future<AppSettingsModel> updateDarkMode(bool value) async {
    final current = await getSettings();
    final updated = current.copyWith(darkMode: value);
    await saveSettings(updated);
    return updated;
  }

  Future<AppSettingsModel> updateAutoPlayVideos(bool value) async {
    final current = await getSettings();
    final updated = current.copyWith(autoPlayVideos: value);
    await saveSettings(updated);
    return updated;
  }

  Future<AppSettingsModel> updateDownloadOverWifiOnly(bool value) async {
    final current = await getSettings();
    final updated = current.copyWith(downloadOverWifiOnly: value);
    await saveSettings(updated);
    return updated;
  }
}
