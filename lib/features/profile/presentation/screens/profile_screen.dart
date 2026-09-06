import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:signature/signature.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/glow_card.dart';
import '../../../../shared/widgets/app_shell.dart';
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
  late final SignatureController _signatureController;
  Uint8List? _savedSignatureBytes;
  bool _signatureLoading = false;
  bool _signatureBusy = false;
  String? _loadedSignaturePath;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _ageController = TextEditingController();
    _bioController = TextEditingController();
    _signatureController = SignatureController(
      penStrokeWidth: 2.5,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _ageController.dispose();
    _bioController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedSignature(String? signaturePath) async {
    if (signaturePath == null || signaturePath.isEmpty) return;
    setState(() => _signatureLoading = true);
    try {
      final bytes = await context
          .read<AuthRepository>()
          .downloadInstructorSignature(signaturePath);
      if (mounted) setState(() => _savedSignatureBytes = bytes);
    } catch (_) {
      // The profile remains usable when an old signature object is unavailable.
    } finally {
      if (mounted) setState(() => _signatureLoading = false);
    }
  }

  Future<void> _saveSignature() async {
    if (_signatureBusy) return;
    final authRepository = context.read<AuthRepository>();
    final authBloc = context.read<AuthBloc>();
    final bytes = await _signatureController.toPngBytes();
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draw your signature before saving.')),
      );
      return;
    }

    setState(() => _signatureBusy = true);
    try {
      final updatedUser = await authRepository.uploadInstructorSignature(bytes);
      if (!mounted) return;
      authBloc.add(AuthUserUpdated(updatedUser));
      setState(() => _savedSignatureBytes = bytes);
      _signatureController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Instructor signature saved.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save signature: $error')),
      );
    } finally {
      if (mounted) setState(() => _signatureBusy = false);
    }
  }

  Future<void> _clearSignature() async {
    if (_signatureBusy) return;
    _signatureController.clear();
    if (_savedSignatureBytes == null) return;

    setState(() => _signatureBusy = true);
    final authRepository = context.read<AuthRepository>();
    final authBloc = context.read<AuthBloc>();
    try {
      final updatedUser = await authRepository.clearInstructorSignature();
      if (!mounted) return;
      authBloc.add(AuthUserUpdated(updatedUser));
      setState(() => _savedSignatureBytes = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Instructor signature cleared.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to clear signature: $error')),
      );
    } finally {
      if (mounted) setState(() => _signatureBusy = false);
    }
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
            leading: const AppDrawerButton(),
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
                  onPressed: profileState.isBusy
                      ? null
                      : () => _saveProfile(context),
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
    if (user.isStaff &&
        user.signaturePath != null &&
        user.signaturePath != _loadedSignaturePath &&
        !_signatureLoading) {
      _loadedSignaturePath = user.signaturePath;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadSavedSignature(user.signaturePath);
      });
    }
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
          if (user.isStaff) ...[
            const SizedBox(height: 20),
            _buildSignatureCard(context, pad),
          ],
        ],
      ),
    );
  }

  Widget _buildSignatureCard(BuildContext context, double pad) {
    final hasSavedSignature = _savedSignatureBytes != null;
    return GlowCard(
      glowColor: AppColors.secondary,
      glowIntensity: 0.06,
      isHoverable: false,
      padding: EdgeInsets.all(pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.draw_outlined, color: AppColors.secondary, size: 20),
              const SizedBox(width: 8),
              Text('Digital Signature', style: AppTextStyles.h4),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Your saved signature will appear on exported Word forms.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          if (_signatureLoading)
            const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (hasSavedSignature) ...[
            Text('Saved signature', style: AppTextStyles.label),
            const SizedBox(height: 8),
            Container(
              height: 120,
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.white,
              child: Image.memory(_savedSignatureBytes!, fit: BoxFit.contain),
            ),
            const SizedBox(height: 16),
            Text(
              'Draw a replacement to update it.',
              style: AppTextStyles.label,
            ),
            const SizedBox(height: 8),
          ],
          Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.surfaceLight),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Signature(
              controller: _signatureController,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _signatureBusy ? null : _saveSignature,
                icon: const Icon(Icons.save_outlined, size: 18),
                label: Text(hasSavedSignature ? 'Update' : 'Save'),
              ),
              OutlinedButton.icon(
                onPressed: _signatureBusy ? null : _clearSignature,
                icon: const Icon(Icons.clear, size: 18),
                label: const Text('Clear'),
              ),
            ],
          ),
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
                width: 104,
                height: 104,
                padding: const EdgeInsets.all(3),
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
                        child: SizedBox.expand(
                          child: Image.network(
                            user.avatarUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _initialAvatar(user),
                          ),
                        ),
                      )
                    : _initialAvatar(user),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: IconButton.filled(
                  onPressed: isUploading
                      ? null
                      : () => context
                            .read<ProfileCubit>()
                            .selectAndUploadAvatar(),
                  icon: const Icon(Icons.edit, size: 16),
                  tooltip: 'Choose JPG profile photo',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    fixedSize: const Size(34, 34),
                    padding: EdgeInsets.zero,
                    side: BorderSide(color: AppColors.background, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'JPG images only',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
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

  Widget _initialAvatar(UserModel user) {
    return Center(
      child: Text(
        user.displayNameOrEmail[0].toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 40,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildDetailsCard(BuildContext context, UserModel user, double pad) {
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
                icon: Icon(
                  Icons.edit_outlined,
                  size: 16,
                  color: AppColors.primary,
                ),
                label: Text('Edit', style: TextStyle(color: AppColors.primary)),
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

          _detailRow(
            Icons.person_outlined,
            'First Name',
            user.firstName ?? 'Not set',
          ),
          _divider(),
          _detailRow(
            Icons.person_outlined,
            'Last Name',
            user.lastName ?? 'Not set',
          ),
          _divider(),
          _detailRow(
            Icons.cake_outlined,
            'Age',
            user.age != null ? '${user.age} years old' : 'Not set',
          ),
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

  Widget _divider() => Divider(height: 28, color: AppColors.surfaceLight);

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
                      Expanded(
                        child: _buildField(
                          controller: _firstNameController,
                          label: 'First Name',
                          icon: Icons.person_outlined,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Required';
                            }
                            if (v.length > 50) return 'Too long';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildField(
                          controller: _lastNameController,
                          label: 'Last Name',
                          icon: Icons.person_outlined,
                          validator: (v) {
                            if (v != null && v.length > 50) return 'Too long';
                            return null;
                          },
                        ),
                      ),
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

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  String _formatDate(DateTime date) {
    const months = [
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
