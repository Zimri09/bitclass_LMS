import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/classroom_course_card.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/loading_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/models/course_model.dart';
import '../bloc/course_bloc.dart';

/// Student course list showing only classes the student has joined.
class CourseCatalogScreen extends StatefulWidget {
  const CourseCatalogScreen({super.key});

  @override
  State<CourseCatalogScreen> createState() => _CourseCatalogScreenState();
}

class _CourseCatalogScreenState extends State<CourseCatalogScreen> {
  final _searchController = TextEditingController();
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadCourses() {
    context.read<CourseBloc>().add(
      LoadCourses(
        category: _selectedCategory,
        searchQuery: _searchController.text.isNotEmpty
            ? _searchController.text
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final canJoinClasses =
        authState is AuthAuthenticated && authState.user.role == 'student';

    return Scaffold(
      body: BlocListener<CourseBloc, CourseState>(
        listener: (context, state) {
          if (state is CourseJoinedByCode) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Joined "${state.course.title}" successfully!',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
                backgroundColor: AppColors.success,
                duration: const Duration(seconds: 3),
              ),
            );
            context.go(AppRoutes.courseDetailPath(state.course.id));
          } else if (state is CourseError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        child: CustomScrollView(
          slivers: [
            // App bar
            SliverAppBar(
              floating: true,
              leading: const AppDrawerButton(),
              title: Text('Classes', style: AppTextStyles.h3),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(120),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    children: [
                      // Search bar
                      TextField(
                        controller: _searchController,
                        onSubmitted: (_) => _loadCourses(),
                        decoration: InputDecoration(
                          hintText: 'Search your classes...',
                          prefixIcon: Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    _loadCourses();
                                  },
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Category filter
                      SizedBox(
                        height: 36,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _buildCategoryChip(null, 'All'),
                            ...AppConstants.courseCategories.map(
                              (cat) => _buildCategoryChip(cat, cat),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Course grid
            BlocBuilder<CourseBloc, CourseState>(
              builder: (context, state) {
                final visibleCourses = switch (state) {
                  CoursesLoaded(:final courses) => courses,
                  CourseJoining(:final courses) => courses,
                  CourseJoinFailure(:final courses) => courses,
                  _ => null,
                };

                if (visibleCourses != null) {
                  if (visibleCourses.isEmpty) {
                    return SliverFillRemaining(
                      child: EmptyState(
                        icon: Icons.school_outlined,
                        title: 'No classes joined yet',
                        subtitle: _selectedCategory != null
                            ? 'Try a different category'
                            : 'Use your instructor\'s class code to join one',
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _CourseCard(course: visibleCourses[index]),
                        ),
                        childCount: visibleCourses.length,
                      ),
                    ),
                  );
                }

                if (state is CourseLoading) {
                  return const SliverCourseGridSkeleton();
                }

                if (state is CourseError) {
                  return SliverFillRemaining(
                    child: ErrorState(
                      message: state.message,
                      onRetry: _loadCourses,
                    ),
                  );
                }

                return const SliverCourseGridSkeleton();
              },
            ),
          ],
        ),
      ),
      floatingActionButton: canJoinClasses
          ? FloatingActionButton.extended(
              onPressed: () => _showJoinByCodeSheet(context),
              backgroundColor: AppColors.secondary,
              icon: const Icon(Icons.vpn_key_rounded, color: Colors.white),
              label: const Text(
                'Join class',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : null,
    );
  }

  /// Shows a bottom sheet for joining a course by its code
  void _showJoinByCodeSheet(BuildContext context) {
    final codeController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return BlocProvider.value(
          value: context.read<CourseBloc>(),
          child: BlocConsumer<CourseBloc, CourseState>(
            listener: (ctx, state) {
              if (state is CourseJoinedByCode) {
                Navigator.of(sheetCtx).pop();
              }
            },
            builder: (ctx, state) {
              final isLoading = state is CourseJoining;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Drag handle
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 20),
                              decoration: BoxDecoration(
                                color: AppColors.border,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),

                          // Icon + title
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.secondary,
                                      AppColors.primary,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.vpn_key_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Join a Course',
                                    style: AppTextStyles.h3,
                                  ),
                                  Text(
                                    'Enter the 6-character code from your instructor',
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),

                          // Code input
                          TextFormField(
                            controller: codeController,
                            autofocus: true,
                            textCapitalization: TextCapitalization.characters,
                            maxLength: 6,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[A-Za-z0-9]'),
                              ),
                              UpperCaseTextFormatter(),
                            ],
                            style: AppTextStyles.h2.copyWith(
                              letterSpacing: 8,
                              color: AppColors.primary,
                            ),
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              hintText: 'ABC123',
                              hintStyle: AppTextStyles.h2.copyWith(
                                letterSpacing: 8,
                                color: AppColors.textMuted,
                              ),
                              counterText: '',
                              prefixIcon: const Icon(Icons.tag),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppColors.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppColors.primary,
                                  width: 2,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a course code';
                              }
                              if (value.trim().length != 6) {
                                return 'Code must be exactly 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),

                          // Hint
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 14,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Ask your instructor for the course code',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                          if (state is CourseJoinFailure) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.error.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Text(
                                state.message,
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),

                          // Join button
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: isLoading
                                  ? null
                                  : () {
                                      if (formKey.currentState!.validate()) {
                                        final authState = context
                                            .read<AuthBloc>()
                                            .state;
                                        if (authState is AuthAuthenticated) {
                                          context.read<CourseBloc>().add(
                                            JoinCourseByCode(
                                              code: codeController.text.trim(),
                                              userId: authState.user.id,
                                              studentName: authState
                                                  .user
                                                  .displayNameOrEmail,
                                              studentEmail:
                                                  authState.user.email,
                                            ),
                                          );
                                        }
                                      }
                                    },
                              icon: isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.login_rounded),
                              label: Text(
                                isLoading ? 'Joining...' : 'Join Course',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secondary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                textStyle: AppTextStyles.buttonMedium,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCategoryChip(String? value, String label) {
    final isSelected = _selectedCategory == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        labelStyle: TextStyle(
          color: isSelected ? AppColors.background : AppColors.textPrimary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
        selectedColor: AppColors.primary,
        checkmarkColor: AppColors.background,
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.border,
        ),
        onSelected: (_) {
          setState(() {
            _selectedCategory = value;
          });
          _loadCourses();
        },
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final CourseModel course;

  const _CourseCard({required this.course});

  @override
  Widget build(BuildContext context) {
    return ClassroomCourseCard(
      course: course,
      onTap: () => context.go(AppRoutes.courseDetailPath(course.id)),
      footer: [
        Icon(Icons.people_outline, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text('${course.enrollmentCount}', style: AppTextStyles.caption),
        const SizedBox(width: 14),
        Icon(Icons.menu_book_outlined, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text('${course.lessonCount}', style: AppTextStyles.caption),
      ],
    );
  }
}

/// TextInputFormatter that converts all input to uppercase
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
