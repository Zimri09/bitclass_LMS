import 'dart:developer';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/errors/app_error.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

part 'profile_state.dart';

/// Cubit managing profile editing and avatar operations
class ProfileCubit extends Cubit<ProfileState> {
  final AuthRepository authRepository;
  final AuthBloc authBloc;

  ProfileCubit({required this.authRepository, required this.authBloc})
    : super(const ProfileState());

  /// Enter edit mode, pre-filling controllers happens in the UI
  void startEditing() {
    emit(state.copyWith(isEditing: true));
  }

  /// Cancel editing without saving
  void cancelEditing() {
    emit(state.copyWith(isEditing: false));
  }

  /// Save profile changes
  Future<void> saveProfile({
    required String firstName,
    required String lastName,
    int? age,
    required String bio,
  }) async {
    emit(state.copyWith(status: ProfileStatus.saving));

    try {
      final updatedUser = await authRepository.updateProfile(
        firstName: firstName,
        lastName: lastName,
        age: age,
        bio: bio,
      );
      authBloc.add(AuthUserUpdated(updatedUser));
      emit(
        state.copyWith(
          status: ProfileStatus.idle,
          isEditing: false,
          successMessage: 'Profile updated successfully',
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        log('Profile save error: $e', name: 'ProfileCubit');
      }
      emit(
        state.copyWith(
          status: ProfileStatus.error,
          errorMessage: userFriendlyErrorMessage(e),
        ),
      );
    }
  }

  /// Selects and uploads a JPG avatar from the device gallery.
  Future<void> selectAndUploadAvatar() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      if (!image.name.toLowerCase().endsWith('.jpg') || !_isJpg(bytes)) {
        throw const FormatException('Only JPG image files are accepted.');
      }

      emit(state.copyWith(status: ProfileStatus.uploadingAvatar));
      final updatedUser = await authRepository.uploadProfileAvatar(bytes);
      authBloc.add(AuthUserUpdated(updatedUser));
      emit(
        state.copyWith(
          status: ProfileStatus.idle,
          successMessage: 'Profile photo updated successfully',
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        log('Avatar upload error: $e', name: 'ProfileCubit');
      }
      emit(
        state.copyWith(
          status: ProfileStatus.error,
          errorMessage: e is FormatException
              ? e.message.toString()
              : userFriendlyErrorMessage(e),
        ),
      );
    }
  }

  static bool _isJpg(Uint8List bytes) {
    return bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff;
  }

  /// Clear transient messages after showing them
  void clearMessages() {
    emit(
      state.copyWith(
        status: state.status == ProfileStatus.error
            ? ProfileStatus.idle
            : state.status,
      ),
    );
  }
}
