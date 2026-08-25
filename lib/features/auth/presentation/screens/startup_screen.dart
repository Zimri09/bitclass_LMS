import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/bitclass_logo.dart';

/// Neutral startup surface shown while the persisted Supabase session and
/// local profile snapshot are restored. It intentionally never renders Login.
class StartupScreen extends StatelessWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BitClassLogo(size: 76, showGlow: true),
              const SizedBox(height: 24),
              Text('BitClass', style: AppTextStyles.h2),
              const SizedBox(height: 18),
              CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                'Restoring your session...',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
