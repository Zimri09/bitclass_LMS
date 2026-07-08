import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/config/environment.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../notifications/data/models/notification_model.dart';
import '../../../notifications/data/models/notification_settings.dart';
import '../../../notifications/data/repositories/notification_repository.dart';
import '../cubit/settings_cubit.dart';

/// Application settings screen
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Notification settings (loaded from NotificationRepository)
  NotificationSettings? _notificationSettings;

  @override
  void initState() {
    super.initState();
    context.read<SettingsCubit>().loadSettings();
    _loadNotificationSettings();
  }

  Future<void> _loadNotificationSettings() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    final repo = context.read<NotificationRepository>();
    final settings = await repo.getSettings(authState.user.id);
    if (mounted) {
      setState(() => _notificationSettings = settings);
    }
  }

  Future<void> _updateNotificationSetting({
    bool? pushEnabled,
    bool? emailEnabled,
    NotificationType? type,
    bool? typeEnabled,
  }) async {
    if (_notificationSettings == null) return;
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    final repo = context.read<NotificationRepository>();

    if (pushEnabled != null) {
      await repo.togglePushEnabled(authState.user.id, pushEnabled);
    }
    if (type != null && typeEnabled != null) {
      await repo.toggleNotificationType(authState.user.id, type, typeEnabled);
    }

    // Reload settings to reflect changes
    final updated = await repo.getSettings(authState.user.id);
    if (mounted) {
      setState(() => _notificationSettings = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, settingsState) {
        final appSettings = settingsState.settings;
        final notif = _notificationSettings;

        return Scaffold(
          appBar: AppBar(
            title: Text('Settings', style: AppTextStyles.h3),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Environment info (for development)
              if (EnvironmentConfig.showDebugInfo) ...[
                _buildEnvironmentCard(),
                const SizedBox(height: 16),
              ],

              // Appearance
              _buildSectionHeader('Appearance'),
              _buildThemeToggleCard(
                isDark: appSettings.darkMode,
                onToggle: () => context
                    .read<SettingsCubit>()
                    .setDarkMode(!appSettings.darkMode),
              ),
              const SizedBox(height: 24),

              // Notifications
              _buildSectionHeader('Notifications'),
              _buildSettingsCard([
                _buildSwitchTile(
                  icon: Icons.notifications,
                  title: 'Push Notifications',
                  subtitle: 'Receive push notifications',
                  value: notif?.pushEnabled ?? true,
                  onChanged: (value) =>
                      _updateNotificationSetting(pushEnabled: value),
                ),
                Divider(height: 1),
                _buildSwitchTile(
                  icon: Icons.email,
                  title: 'Email Notifications',
                  subtitle: 'Receive email updates',
                  value: notif?.emailEnabled ?? true,
                  onChanged: (value) =>
                      _updateNotificationSetting(emailEnabled: value),
                ),
                Divider(height: 1),
                _buildSwitchTile(
                  icon: Icons.school,
                  title: 'Course Updates',
                  subtitle: 'New lessons and materials',
                  value:
                      notif?.isTypeEnabled(NotificationType.courseUpdate) ??
                      true,
                  onChanged: (value) => _updateNotificationSetting(
                    type: NotificationType.courseUpdate,
                    typeEnabled: value,
                  ),
                ),
                Divider(height: 1),
                _buildSwitchTile(
                  icon: Icons.grade,
                  title: 'Grade Alerts',
                  subtitle: 'New grades and feedback',
                  value:
                      notif?.isTypeEnabled(NotificationType.assignmentGraded) ??
                      true,
                  onChanged: (value) => _updateNotificationSetting(
                    type: NotificationType.assignmentGraded,
                    typeEnabled: value,
                  ),
                ),
                Divider(height: 1),
                _buildSwitchTile(
                  icon: Icons.forum,
                  title: 'Discussion Replies',
                  subtitle: 'Replies to your posts',
                  value:
                      notif?.isTypeEnabled(NotificationType.discussionReply) ??
                      true,
                  onChanged: (value) => _updateNotificationSetting(
                    type: NotificationType.discussionReply,
                    typeEnabled: value,
                  ),
                ),
              ]),
              const SizedBox(height: 24),

              // Learning
              _buildSectionHeader('Learning'),
              _buildSettingsCard([
                _buildSwitchTile(
                  icon: Icons.play_circle,
                  title: 'Auto-play Videos',
                  subtitle: 'Automatically play lesson videos',
                  value: appSettings.autoPlayVideos,
                  onChanged: (value) =>
                      context.read<SettingsCubit>().setAutoPlayVideos(value),
                ),
                Divider(height: 1),
                _buildSwitchTile(
                  icon: Icons.wifi,
                  title: 'Download on Wi-Fi Only',
                  subtitle: 'Restrict downloads to Wi-Fi',
                  value: appSettings.downloadOverWifiOnly,
                  onChanged: (value) => context
                      .read<SettingsCubit>()
                      .setDownloadOverWifiOnly(value),
                ),
              ]),
              const SizedBox(height: 24),

              // Account
              _buildSectionHeader('Account'),
              _buildSettingsCard([
                _buildNavigationTile(
                  icon: Icons.person,
                  title: 'Edit Profile',
                  onTap: () => context.push(AppRoutes.profile),
                ),
                Divider(height: 1),
                _buildNavigationTile(
                  icon: Icons.lock,
                  title: 'Change Password',
                  onTap: () => _showChangePasswordDialog(),
                ),
                Divider(height: 1),
                _buildNavigationTile(
                  icon: Icons.notifications_active,
                  title: 'Notification Preferences',
                  onTap: () => context.push(AppRoutes.notificationSettings),
                ),
              ]),
              const SizedBox(height: 24),

              // Support
              _buildSectionHeader('Support'),
              _buildSettingsCard([
                _buildNavigationTile(
                  icon: Icons.help,
                  title: 'Help Center',
                  onTap: () => _showComingSoon('Help Center'),
                ),
                Divider(height: 1),
                _buildNavigationTile(
                  icon: Icons.feedback,
                  title: 'Send Feedback',
                  onTap: () => _showComingSoon('Feedback'),
                ),
                Divider(height: 1),
                _buildNavigationTile(
                  icon: Icons.bug_report,
                  title: 'Report a Bug',
                  onTap: () => _showComingSoon('Bug Report'),
                ),
              ]),
              const SizedBox(height: 24),

              // About
              _buildSectionHeader('About'),
              _buildSettingsCard([
                _buildInfoTile(
                  icon: Icons.info,
                  title: 'Version',
                  value: AppConstants.appVersion,
                ),
                Divider(height: 1),
                _buildNavigationTile(
                  icon: Icons.description,
                  title: 'Terms of Service',
                  onTap: () => _showComingSoon('Terms of Service'),
                ),
                Divider(height: 1),
                _buildNavigationTile(
                  icon: Icons.privacy_tip,
                  title: 'Privacy Policy',
                  onTap: () => _showComingSoon('Privacy Policy'),
                ),
                Divider(height: 1),
                _buildNavigationTile(
                  icon: Icons.article,
                  title: 'Licenses',
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: AppConstants.appName,
                    applicationVersion: AppConstants.appVersionName,
                  ),
                ),
              ]),
              const SizedBox(height: 24),

              // Logout
              _buildSettingsCard([
                _buildActionTile(
                  icon: Icons.logout,
                  title: 'Log Out',
                  isDestructive: true,
                  onTap: _showLogoutDialog,
                ),
              ]),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEnvironmentCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning),
      ),
      child: Row(
        children: [
          Icon(Icons.bug_report, color: AppColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Development Mode',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning,
                  ),
                ),
                Text(
                  'Environment: ${EnvironmentConfig.current.name}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: AppTextStyles.caption.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(children: children),
    );
  }

  /// Premium animated theme toggle card
  Widget _buildThemeToggleCard({
    required bool isDark,
    required VoidCallback onToggle,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            // Animated icon
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) => RotationTransition(
                turns: anim,
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Icon(
                isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                key: ValueKey(isDark),
                color: isDark ? AppColors.primary : const Color(0xFFE97F28),
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            // Label
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isDark ? 'Dark Mode' : 'Light Mode',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    isDark
                        ? 'Switch to light theme'
                        : 'Switch to dark theme',
                    style: AppTextStyles.caption.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // Custom pill toggle
            _ThemePillToggle(isDark: isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return SwitchListTile(
      secondary: Icon(icon, color: colorScheme.primary),
      title: Text(
        title,
        style: AppTextStyles.bodyMedium.copyWith(color: colorScheme.onSurface),
      ),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.caption.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: colorScheme.primary,
    );
  }

  Widget _buildNavigationTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: colorScheme.primary),
      title: Text(
        title,
        style: AppTextStyles.bodyMedium.copyWith(color: colorScheme.onSurface),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: colorScheme.primary),
      title: Text(
        title,
        style: AppTextStyles.bodyMedium.copyWith(color: colorScheme.onSurface),
      ),
      trailing: Text(
        value,
        style: AppTextStyles.bodyMedium.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isDestructive ? colorScheme.error : colorScheme.primary;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: AppTextStyles.bodyMedium.copyWith(color: color),
      ),
      onTap: onTap,
    );
  }

  void _showComingSoon(String feature) {
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon!'),
        backgroundColor: colorScheme.primary,
      ),
    );
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current Password'),
            ),
            const SizedBox(height: 16),
            TextField(
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New Password'),
            ),
            const SizedBox(height: 16),
            TextField(
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm New Password',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Password change coming soon!'),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: const Text('Log Out'),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              onPressed: () {
                Navigator.pop(context);
                context.read<AuthBloc>().add(AuthLogoutRequested());
              },
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );
  }
}

/// Animated pill-style toggle for light/dark theme
class _ThemePillToggle extends StatelessWidget {
  final bool isDark;

  const _ThemePillToggle({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? AppColors.primary : const Color(0xFFE97F28);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: 56,
      height: 30,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: isDark
            ? primary.withValues(alpha: 0.25)
            : primary.withValues(alpha: 0.15),
        border: Border.all(color: primary.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primary,
                boxShadow: [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.5),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(
                isDark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                size: 13,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
