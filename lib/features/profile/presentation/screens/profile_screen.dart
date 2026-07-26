import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/glow_card.dart';
import '../../../../shared/widgets/loading_widgets.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../cubit/profile_cubit.dart';

/// Profile screen for viewing and editing user profile
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ProfileCubit(
        authRepository: context.read<AuthRepository>(),
        authBloc: context.read<AuthBloc>(),
      ),
      child: const _ProfileBody(),
    );
  }
}

class _ProfileBody extends StatefulWidget {
  const _ProfileBody();

  @override
  State<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<_ProfileBody> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _ageController;
  late final TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _ageController = TextEditingController();
    _bioController = TextEditingController();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _ageController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _startEditing(BuildContext ctx, UserModel user) {
    _firstNameController.text = user.firstName ?? '';
    _lastNameController.text = user.lastName ?? '';
    _ageController.text = user.age != null ? '${user.age}' : '';
    _bioController.text = user.bio ?? '';
    ctx.read<ProfileCubit>().startEditing();
  }

  void _saveProfile(BuildContext ctx) {
    if (_formKey.currentState!.validate()) {
      final ageText = _ageController.text.trim();
      ctx.read<ProfileCubit>().saveProfile(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        age: ageText.isNotEmpty ? int.tryParse(ageText) : null,
        bio: _bioController.text.trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProfileCubit, ProfileState>(
      listener: (context, state) {
        if (state.successMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(state.successMessage!),
                ],
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
          context.read<ProfileCubit>().clearMessages();
        }
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(state.errorMessage!)),
                ],
              ),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
          context.read<ProfileCubit>().clearMessages();
        }
      },
      builder: (context, profileState) {
        return Scaffold(
          appBar: AppBar(
            title: Text('Profile', style: AppTextStyles.h3),
            actions: [
              if (profileState.isEditing) ...[
                TextButton(
                  onPressed: profileState.isBusy
                      ? null
                      : () => context.read<ProfileCubit>().cancelEditing(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(width: 4),
                FilledButton.icon(
                  onPressed: profileState.isBusy ? null : () => _saveProfile(context),
                  icon: profileState.status == ProfileStatus.saving
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined, size: 16),
                  label: Text(
                    profileState.status == ProfileStatus.saving
                        ? 'Saving...'
                        : 'Save',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ],
          ),
          body: BlocBuilder<AuthBloc, AuthState>(
            builder: (context, authState) {
              if (authState is AuthAuthenticated) {
                return _buildContent(context, authState.user, profileState);
              }
              return const ProfileSkeleton();
            },
          ),
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    UserModel user,
    ProfileState profileState,
  ) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final pad = isMobile ? 16.0 : 24.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Column(
        children: [
          _buildAvatarCard(context, user, profileState),
          const SizedBox(height: 20),
          if (profileState.isEditing)
            _buildEditCard(context, pad)
          else
            _buildDetailsCard(context, user, pad),
        ],
      ),
    );
  }

  // ─── Avatar Card ────────────────────────────────────────────────────────────

  Widget _buildAvatarCard(
    BuildContext context,
    UserModel user,
    ProfileState profileState,
  ) {
    final isUploading = profileState.status == ProfileStatus.uploadingAvatar;

    return GlowCard(
      glowColor: AppColors.primary,
      glowIntensity: 0.12,
      isHoverable: false,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        children: [
          // Avatar
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
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: isUploading
                    ? Center(
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
                          width: 100,
                          height: 100,
                        ),
                      )
                    : Center(
                        child: Text(
                          user.displayNameOrEmail[0].toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: isUploading
                      ? null
                      : () => _showAvatarOptions(context),
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
                    child: Icon(
                      Icons.camera_alt,
                      size: 15,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            user.displayNameOrEmail,
            style: AppTextStyles.h2,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            user.email,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: user.isInstructor
                  ? AppColors.secondary.withValues(alpha: 0.15)
                  : AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: user.isInstructor
                    ? AppColors.secondary
                    : AppColors.primary,
              ),
            ),
            child: Text(
              user.role.toUpperCase(),
              style: AppTextStyles.label.copyWith(
                color: user.isInstructor
                    ? AppColors.secondary
                    : AppColors.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── View Mode ───────────────────────────────────────────────────────────────

  Widget _buildDetailsCard(
    BuildContext context,
    UserModel user,
    double pad,
  ) {
    return GlowCard(
      glowColor: AppColors.primary,
      glowIntensity: 0.05,
      isHoverable: false,
      padding: EdgeInsets.all(pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Profile Details', style: AppTextStyles.h4),
              TextButton.icon(
                onPressed: () => _startEditing(context, user),
                icon: Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                label: Text(
                  'Edit',
                  style: TextStyle(color: AppColors.primary),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          _detailRow(Icons.person_outlined, 'First Name', user.firstName ?? 'Not set'),
          _divider(),
          _detailRow(Icons.person_outlined, 'Last Name', user.lastName ?? 'Not set'),
          _divider(),
          _detailRow(Icons.cake_outlined, 'Age', user.age != null ? '${user.age} years old' : 'Not set'),
          _divider(),
          _detailRow(Icons.email_outlined, 'Email', user.email),
          _divider(),
          _detailRow(
            Icons.info_outline,
            'Bio',
            user.bio?.isNotEmpty == true ? user.bio! : 'No bio added yet',
          ),
          _divider(),
          _detailRow(
            Icons.calendar_today_outlined,
            'Member Since',
            _formatDate(user.createdAt),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Divider(
    height: 28,
    color: AppColors.surfaceLight,
  );

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.textSecondary, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.label.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Edit Mode ───────────────────────────────────────────────────────────────

  Widget _buildEditCard(BuildContext context, double pad) {
    return GlowCard(
      glowColor: AppColors.secondary,
      glowIntensity: 0.08,
      isHoverable: false,
      padding: EdgeInsets.all(pad),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.edit_outlined, color: AppColors.secondary, size: 20),
                const SizedBox(width: 8),
                Text('Edit Profile', style: AppTextStyles.h4),
              ],
            ),
            const SizedBox(height: 24),

            // First & Last Name in a row on wider screens
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 480) {
                  return Row(
                    children: [
                      Expanded(child: _buildField(
                        controller: _firstNameController,
                        label: 'First Name',
                        icon: Icons.person_outlined,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          if (v.length > 50) return 'Too long';
                          return null;
                        },
                      )),
                      const SizedBox(width: 16),
                      Expanded(child: _buildField(
                        controller: _lastNameController,
                        label: 'Last Name',
                        icon: Icons.person_outlined,
                        validator: (v) {
                          if (v != null && v.length > 50) return 'Too long';
                          return null;
                        },
                      )),
                    ],
                  );
                }
                return Column(
                  children: [
                    _buildField(
                      controller: _firstNameController,
                      label: 'First Name',
                      icon: Icons.person_outlined,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (v.length > 50) return 'Too long';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                      controller: _lastNameController,
                      label: 'Last Name',
                      icon: Icons.person_outlined,
                      validator: (v) {
                        if (v != null && v.length > 50) return 'Too long';
                        return null;
                      },
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // Age
            _buildField(
              controller: _ageController,
              label: 'Age',
              icon: Icons.cake_outlined,
              keyboardType: TextInputType.number,
              hint: 'e.g. 21',
              validator: (v) {
                if (v != null && v.trim().isNotEmpty) {
                  final n = int.tryParse(v.trim());
                  if (n == null) return 'Enter a valid number';
                  if (n < 1 || n > 120) return 'Must be between 1 and 120';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Bio
            _buildField(
              controller: _bioController,
              label: 'Bio',
              icon: Icons.info_outline,
              maxLines: 3,
              hint: 'Tell us a little about yourself...',
              alignLabelWithHint: true,
              validator: (v) {
                if (v != null && v.length > 500) {
                  return 'Max 500 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 28),

            // Save button (also shown inline for convenience)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _saveProfile(context),
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save Changes'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    int maxLines = 1,
    bool alignLabelWithHint = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        alignLabelWithHint: alignLabelWithHint,
        filled: true,
        fillColor: AppColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.error, width: 2),
        ),
      ),
      validator: validator,
    );
  }

  // ─── Avatar Options ──────────────────────────────────────────────────────────

  void _showAvatarOptions(BuildContext ctx) {
    final cubit = ctx.read<ProfileCubit>();
    showModalBottomSheet(
      context: ctx,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: AppColors.surface,
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
              const SizedBox(height: 20),
              Text('Update Profile Photo', style: AppTextStyles.h3),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _avatarOption(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    onTap: () {
                      Navigator.pop(context);
                      cubit.uploadAvatar('camera');
                    },
                  ),
                  _avatarOption(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: () {
                      Navigator.pop(context);
                      cubit.uploadAvatar('gallery');
                    },
                  ),
                  _avatarOption(
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
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final c = color ?? AppColors.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: c, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(color: c),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
