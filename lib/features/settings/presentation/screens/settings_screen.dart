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
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text('Settings', style: AppTextStyles.h3),
            backgroundColor: AppColors.surface,
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
              _buildSettingsCard([
                _buildSwitchTile(
                  icon: Icons.dark_mode,
                  title: 'Dark Mode',
                  subtitle: 'Use dark theme',
                  value: appSettings.darkMode,
                  onChanged: (value) =>
                      context.read<SettingsCubit>().setDarkMode(value),
                ),
              ]),
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
                const Divider(height: 1),
                _buildSwitchTile(
                  icon: Icons.email,
                  title: 'Email Notifications',
                  subtitle: 'Receive email updates',
                  value: notif?.emailEnabled ?? true,
                  onChanged: (value) =>
                      _updateNotificationSetting(emailEnabled: value),
                ),
                const Divider(height: 1),
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
                const Divider(height: 1),
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
                const Divider(height: 1),
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
                const Divider(height: 1),
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
                const Divider(height: 1),
                _buildNavigationTile(
                  icon: Icons.lock,
                  title: 'Change Password',
                  onTap: () => _showChangePasswordDialog(),
                ),
                const Divider(height: 1),
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
                const Divider(height: 1),
                _buildNavigationTile(
                  icon: Icons.feedback,
                  title: 'Send Feedback',
                  onTap: () => _showComingSoon('Feedback'),
                ),
                const Divider(height: 1),
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
                const Divider(height: 1),
                _buildNavigationTile(
                  icon: Icons.description,
                  title: 'Terms of Service',
                  onTap: () => _showComingSoon('Terms of Service'),
                ),
                const Divider(height: 1),
                _buildNavigationTile(
                  icon: Icons.privacy_tip,
                  title: 'Privacy Policy',
                  onTap: () => _showComingSoon('Privacy Policy'),
                ),
                const Divider(height: 1),
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
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: AppTextStyles.caption.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(icon, color: AppColors.primary),
      title: Text(title, style: AppTextStyles.bodyMedium),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
      ),
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppColors.primary,
    );
  }

  Widget _buildNavigationTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: AppTextStyles.bodyMedium),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      onTap: onTap,
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: AppTextStyles.bodyMedium),
      trailing: Text(
        value,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textSecondary,
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
    final color = isDestructive ? AppColors.error : AppColors.primary;
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon!'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
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
                const SnackBar(
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
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthBloc>().add(AuthLogoutRequested());
            },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }
}
