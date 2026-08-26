import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/bitclass_logo.dart';

class AboutBitClassScreen extends StatelessWidget {
  const AboutBitClassScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text('About BitClass', style: AppTextStyles.h3),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Center(child: BitClassLogo(size: 88, showGlow: true)),
              const SizedBox(height: 18),
              Text(
                AppConstants.appName,
                textAlign: TextAlign.center,
                style: AppTextStyles.h2.copyWith(color: colors.onSurface),
              ),
              const SizedBox(height: 6),
              Text(
                AppConstants.appTagline,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Version ${AppConstants.appVersion}',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Learning, coursework, and collaboration in one place',
                style: AppTextStyles.h4.copyWith(color: colors.onSurface),
              ),
              const SizedBox(height: 10),
              Text(
                'BitClass is a learning management system for computer science students and instructors. It brings course materials, coding activities, assessments, class discussions, grades, and offline files into a single workspace.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              Divider(color: colors.outlineVariant),
              _AboutLink(
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                onTap: () => context.push(AppRoutes.settingsTerms),
              ),
              Divider(height: 1, color: colors.outlineVariant),
              _AboutLink(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                onTap: () => context.push(AppRoutes.settingsPrivacy),
              ),
              Divider(height: 1, color: colors.outlineVariant),
              _AboutLink(
                icon: Icons.article_outlined,
                title: 'Open-source Licenses',
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: AppConstants.appName,
                  applicationVersion: AppConstants.appVersionName,
                  applicationIcon: const Padding(
                    padding: EdgeInsets.all(16),
                    child: BitClassLogo(size: 64),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutLink extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _AboutLink({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: colors.primary),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
