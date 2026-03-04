part of 'settings_cubit.dart';

/// State for the SettingsCubit
class SettingsState extends Equatable {
  final AppSettingsModel settings;
  final bool isLoading;

  const SettingsState({
    this.settings = const AppSettingsModel(),
    this.isLoading = false,
  });

  @override
  List<Object?> get props => [settings, isLoading];

  SettingsState copyWith({AppSettingsModel? settings, bool? isLoading}) {
    return SettingsState(
      settings: settings ?? this.settings,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
