part of 'profile_cubit.dart';

/// Status of profile operations
enum ProfileStatus { idle, saving, uploadingAvatar, error }

/// State for the ProfileCubit
class ProfileState extends Equatable {
  final ProfileStatus status;
  final bool isEditing;
  final String? successMessage;
  final String? errorMessage;

  const ProfileState({
    this.status = ProfileStatus.idle,
    this.isEditing = false,
    this.successMessage,
    this.errorMessage,
  });

  bool get isBusy =>
      status == ProfileStatus.saving ||
      status == ProfileStatus.uploadingAvatar;

  @override
  List<Object?> get props => [status, isEditing, successMessage, errorMessage];

  ProfileState copyWith({
    ProfileStatus? status,
    bool? isEditing,
    String? successMessage,
    String? errorMessage,
  }) {
    return ProfileState(
      status: status ?? this.status,
      isEditing: isEditing ?? this.isEditing,
      successMessage: successMessage,
      errorMessage: errorMessage,
    );
  }
}
