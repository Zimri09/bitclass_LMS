import 'dart:developer';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
    required String displayName,
    required String bio,
  }) async {
    emit(state.copyWith(status: ProfileStatus.saving));

    try {
      final updatedUser = await authRepository.updateProfile(
        displayName: displayName,
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
          errorMessage: 'Failed to update profile: $e',
        ),
      );
    }
  }

  /// Upload avatar from camera or gallery
  Future<void> uploadAvatar(String source) async {
    emit(state.copyWith(status: ProfileStatus.uploadingAvatar));

    try {
      // TODO: Integrate with real image picker + storage upload
      // For now, simulate the upload in demo mode
      await Future.delayed(const Duration(seconds: 2));

      emit(
        state.copyWith(
          status: ProfileStatus.idle,
          successMessage: 'Avatar upload from $source (demo mode)',
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        log('Avatar upload error: $e', name: 'ProfileCubit');
      }
      emit(
        state.copyWith(
          status: ProfileStatus.error,
          errorMessage: 'Failed to upload avatar',
        ),
      );
    }
  }

  /// Remove avatar
  Future<void> removeAvatar() async {
    emit(state.copyWith(status: ProfileStatus.uploadingAvatar));

    try {
      // TODO: Integrate with real storage deletion
      await Future.delayed(const Duration(milliseconds: 500));

      emit(
        state.copyWith(
          status: ProfileStatus.idle,
          successMessage: 'Avatar removed (demo mode)',
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        log('Avatar remove error: $e', name: 'ProfileCubit');
      }
      emit(
        state.copyWith(
          status: ProfileStatus.error,
          errorMessage: 'Failed to remove avatar',
        ),
      );
    }
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
