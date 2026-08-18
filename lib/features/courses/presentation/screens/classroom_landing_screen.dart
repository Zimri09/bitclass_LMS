import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/repositories/course_repository.dart';
import '../bloc/course_bloc.dart';
import 'course_catalog_screen.dart';
import 'my_courses_screen.dart';

/// The shared Home and Classes destination, selected by the signed-in role.
class ClassroomLandingScreen extends StatelessWidget {
  const ClassroomLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is AuthAuthenticated && state.isOffline) {
          return const _OfflineHomeScreen();
        }
        if (state is AuthAuthenticated && state.user.isStaff) {
          return const MyCoursesScreen();
        }
        return BlocProvider(
          create: (context) =>
              CourseBloc(courseRepository: context.read<CourseRepository>()),
          child: const CourseCatalogScreen(),
        );
      },
    );
  }
}

class _OfflineHomeScreen extends StatelessWidget {
  const _OfflineHomeScreen();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: const AppDrawerButton(),
        title: const Text('Home'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Chip(
              avatar: const Icon(Icons.cloud_off, size: 17),
              label: const Text('Offline'),
              backgroundColor: AppColors.warning.withValues(alpha: 0.14),
              side: BorderSide(
                color: AppColors.warning.withValues(alpha: 0.35),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.offline_bolt_outlined,
                      size: 40,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('You are offline', style: AppTextStyles.h3),
                  const SizedBox(height: 10),
                  Text(
                    'Downloaded learning materials are still available. '
                    'Course updates, discussions, grades, and uploads will '
                    'resume after your connection is restored.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: colors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.push(AppRoutes.offlineFiles),
                      icon: const Icon(Icons.download_for_offline),
                      label: const Text('Open Offline Files'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () =>
                        context.read<AuthBloc>().add(AuthCheckRequested()),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry connection'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
