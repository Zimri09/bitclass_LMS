import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/glow_card.dart';
import '../../../../shared/widgets/loading_widgets.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../cubit/profile_cubit.dart';

/// Profile screen for viewing and editing user profile
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _displayNameController;
  late TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController();
    _bioController = TextEditingController();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _startEditing(dynamic user) {
    _displayNameController.text = user.displayName ?? '';
    _bioController.text = user.bio ?? '';
    context.read<ProfileCubit>().startEditing();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ProfileCubit(
        authRepository: context.read<AuthRepository>(),
        authBloc: context.read<AuthBloc>(),
      ),
      child: BlocConsumer<ProfileCubit, ProfileState>(
        listener: (context, profileState) {
          if (profileState.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(profileState.successMessage!),
                backgroundColor: AppColors.success,
              ),
            );
            context.read<ProfileCubit>().clearMessages();
          }
          if (profileState.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(profileState.errorMessage!),
                backgroundColor: AppColors.error,
              ),
            );
            context.read<ProfileCubit>().clearMessages();
          }
        },
        builder: (context, profileState) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: AppColors.background,
              title: Text('Profile', style: AppTextStyles.h3),
              actions: [
                if (profileState.isEditing) ...[
                  TextButton(
                    onPressed: profileState.isBusy
                        ? null
                        : () => context.read<ProfileCubit>().cancelEditing(),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: profileState.isBusy
                        ? null
                        : () {
                            if (_formKey.currentState!.validate()) {
                              context.read<ProfileCubit>().saveProfile(
                                displayName: _displayNameController.text.trim(),
                                bio: _bioController.text.trim(),
                              );
                            }
                          },
                    child: Text(
                      profileState.status == ProfileStatus.saving
                          ? 'Saving...'
                          : 'Save',
                      style: TextStyle(color: AppColors.success),
                    ),
                  ),
                ],
              ],
            ),
            body: BlocBuilder<AuthBloc, AuthState>(
              builder: (context, authState) {
                if (authState is AuthAuthenticated) {
                  return _buildProfileContent(
                    context,
                    authState.user,
                    profileState,
                  );
                }
                return const ProfileSkeleton();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileContent(
    BuildContext context,
    dynamic user,
    ProfileState profileState,
  ) {
    final isUploadingAvatar =
        profileState.status == ProfileStatus.uploadingAvatar;

    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        children: [
          // Avatar section
          GlowCard(
            glowColor: AppColors.primary,
            glowIntensity: 0.1,
            isHoverable: false,
            padding: EdgeInsets.all(isMobile ? 20 : 32),
            child: Column(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.primary, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.glowPrimary,
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: isUploadingAvatar
                          ? const Center(
                              child: SizedBox(
                                width: 32,
                                height: 32,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: AppColors.primary,
                                ),
                              ),
                            )
                          : user.avatarUrl != null
                          ? ClipOval(
                              child: Image.network(
                                user.avatarUrl!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Center(
                              child: Text(
                                user.displayNameOrEmail[0].toUpperCase(),
                                style: AppTextStyles.h1.copyWith(
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.background,
                            width: 2,
                          ),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.camera_alt,
                            size: 14,
                            color: AppColors.background,
                          ),
                          onPressed: isUploadingAvatar
                              ? null
                              : () => _showAvatarOptions(context),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(user.displayNameOrEmail, style: AppTextStyles.h2),
                const SizedBox(height: 4),
                Text(user.email, style: AppTextStyles.bodySmall),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: user.isInstructor
                        ? AppColors.secondary.withValues(alpha: 0.1)
                        : AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: user.isInstructor
                          ? AppColors.secondary
                          : AppColors.primary,
                    ),
                  ),
                  child: Text(
                    user.role.toString().toUpperCase(),
                    style: AppTextStyles.label.copyWith(
                      color: user.isInstructor
                          ? AppColors.secondary
                          : AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Profile details
          GlowCard(
            glowColor: AppColors.primary,
            glowIntensity: 0.05,
            isHoverable: false,
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: profileState.isEditing
                ? _buildEditForm()
                : _buildProfileDetails(context, user),
          ),
        ],
      ),
    );
  }

  void _showAvatarOptions(BuildContext outerContext) {
    final cubit = outerContext.read<ProfileCubit>();

    showModalBottomSheet(
      context: outerContext,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text('Update Profile Photo', style: AppTextStyles.h3),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildAvatarOption(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    onTap: () {
                      Navigator.pop(context);
                      cubit.uploadAvatar('camera');
                    },
                  ),
                  _buildAvatarOption(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: () {
                      Navigator.pop(context);
                      cubit.uploadAvatar('gallery');
                    },
                  ),
                  _buildAvatarOption(
                    icon: Icons.delete_outline,
                    label: 'Remove',
                    color: AppColors.error,
                    onTap: () {
                      Navigator.pop(context);
                      cubit.removeAvatar();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: (color ?? AppColors.primary).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color ?? AppColors.primary, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: color ?? AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileDetails(BuildContext context, dynamic user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Profile Details', style: AppTextStyles.h4),
            IconButton(
              icon: const Icon(Icons.edit, color: AppColors.primary),
              onPressed: () => _startEditing(user),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildDetailRow(
          icon: Icons.badge_outlined,
          label: 'Display Name',
          value: user.displayName ?? 'Not set',
        ),
        const Divider(height: 32),
        _buildDetailRow(
          icon: Icons.email_outlined,
          label: 'Email',
          value: user.email,
        ),
        const Divider(height: 32),
        _buildDetailRow(
          icon: Icons.info_outline,
          label: 'Bio',
          value: user.bio ?? 'No bio added yet',
        ),
        const Divider(height: 32),
        _buildDetailRow(
          icon: Icons.calendar_today_outlined,
          label: 'Member Since',
          value: _formatDate(user.createdAt),
        ),
      ],
    );
  }

  Widget _buildEditForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Edit Profile', style: AppTextStyles.h4),
          const SizedBox(height: 24),
          TextFormField(
            controller: _displayNameController,
            decoration: const InputDecoration(
              labelText: 'Display Name',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            validator: (value) {
              if (value != null && value.length > 50) {
                return 'Display name is too long';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _bioController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Bio',
              prefixIcon: Icon(Icons.info_outline),
              alignLabelWithHint: true,
            ),
            validator: (value) {
              if (value != null && value.length > 500) {
                return 'Bio is too long (max 500 characters)';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.label),
              const SizedBox(height: 4),
              Text(value, style: AppTextStyles.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
