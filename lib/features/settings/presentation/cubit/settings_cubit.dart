import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/models.dart';
import '../../data/repositories/settings_repository.dart';

part 'settings_state.dart';

/// Cubit for managing app settings state
class SettingsCubit extends Cubit<SettingsState> {
  final SettingsRepository settingsRepository;

  SettingsCubit({required this.settingsRepository})
    : super(const SettingsState());

  /// Load settings from local storage
  Future<void> loadSettings() async {
    emit(state.copyWith(isLoading: true));
    try {
      final settings = await settingsRepository.getSettings();
      emit(state.copyWith(settings: settings, isLoading: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false));
    }
  }

  /// Update dark mode preference
  Future<void> setDarkMode(bool value) async {
    final updated = await settingsRepository.updateDarkMode(value);
    emit(state.copyWith(settings: updated));
  }

  /// Update auto-play videos preference
  Future<void> setAutoPlayVideos(bool value) async {
    final updated = await settingsRepository.updateAutoPlayVideos(value);
    emit(state.copyWith(settings: updated));
  }

  /// Update download over Wi-Fi only preference
  Future<void> setDownloadOverWifiOnly(bool value) async {
    final updated = await settingsRepository.updateDownloadOverWifiOnly(value);
    emit(state.copyWith(settings: updated));
  }
}
