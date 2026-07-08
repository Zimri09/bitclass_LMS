import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/course_banner.dart';
import '../../../../shared/widgets/glow_card.dart';
import '../../../../shared/widgets/loading_widgets.dart';
import '../../data/models/course_model.dart';
import '../bloc/course_bloc.dart';

/// Course catalog screen showing all available courses
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
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App bar
          SliverAppBar(
            floating: true,
            title: Text('Browse Courses', style: AppTextStyles.h3),
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
                        hintText: 'Search courses...',
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

              if (state is CoursesLoaded) {
                if (state.courses.isEmpty) {
                  return SliverFillRemaining(
                    child: EmptyState(
                      icon: Icons.school_outlined,
                      title: 'No courses found',
                      subtitle: _selectedCategory != null
                          ? 'Try a different category'
                          : 'Check back later for new courses',
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _CourseCard(course: state.courses[index]),
                      ),
                      childCount: state.courses.length,
                    ),
                  ),
                );
              }

              return const SliverCourseGridSkeleton();
            },
          ),
        ],
      ),
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
    return GlowCard(
      glowColor: AppColors.primary,
      glowIntensity: 0.1,
      padding: EdgeInsets.zero,
      onTap: () => context.go(AppRoutes.courseDetailPath(course.id)),
      child: Row(
        children: [
          // Thumbnail
          CourseBannerWidget(
            thumbnailUrl: course.thumbnailUrl,
            width: 100,
            height: 100,
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(12),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      course.category,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Title
                  Text(
                    course.title,
                    style: AppTextStyles.h4,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // Instructor & stats
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          course.instructorName,
                          style: AppTextStyles.caption,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.people_outline,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${course.enrollmentCount}',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
