import 'package:flutter/material.dart';

import '../../../core/theme/admin_theme.dart';
import '../../../core/widgets/admin_page.dart';
import '../../dashboard/data/admin_models.dart';
import '../../dashboard/data/admin_repository.dart';

class AdminCoursesScreen extends StatefulWidget {
  final AdminRepository repository;

  const AdminCoursesScreen({super.key, required this.repository});

  @override
  State<AdminCoursesScreen> createState() => _AdminCoursesScreenState();
}

class _AdminCoursesScreenState extends State<AdminCoursesScreen> {
  final _searchController = TextEditingController();
  List<AdminCourse> _courses = const [];
  bool _isLoading = true;
  String? _error;
  String _status = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final courses = await widget.repository.fetchCourses();
      if (!mounted) return;
      setState(() => _courses = courses);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Courses could not be loaded.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<AdminCourse> get _filteredCourses {
    final query = _searchController.text.trim().toLowerCase();
    return _courses
        .where((course) {
          final matchesStatus =
              _status == 'all' ||
              (_status == 'published' && course.isPublished) ||
              (_status == 'draft' && !course.isPublished);
          final matchesQuery =
              query.isEmpty ||
              course.title.toLowerCase().contains(query) ||
              course.instructorName.toLowerCase().contains(query) ||
              (course.category?.toLowerCase().contains(query) ?? false);
          return matchesStatus && matchesQuery;
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return AdminPage(
      title: 'Courses',
      description: 'Review published and draft courses across the platform.',
      action: OutlinedButton.icon(
        onPressed: _isLoading ? null : _load,
        icon: const Icon(Icons.refresh, size: 19),
        label: const Text('Refresh'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CourseFilters(
            controller: _searchController,
            status: _status,
            onSearchChanged: (_) => setState(() {}),
            onStatusChanged: (value) => setState(() => _status = value),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 100),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            AdminErrorPanel(message: _error!, onRetry: _load)
          else if (_filteredCourses.isEmpty)
            const AdminEmptyPanel(
              icon: Icons.menu_book_outlined,
              title: 'No matching courses',
              message: 'Try a different search or publishing filter.',
            )
          else
            _CourseGrid(courses: _filteredCourses),
          if (!_isLoading && _error == null) ...[
            const SizedBox(height: 12),
            Text(
              'Showing ${_filteredCourses.length} of ${_courses.length} loaded '
              'courses.',
              style: const TextStyle(
                color: AdminColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CourseFilters extends StatelessWidget {
  final TextEditingController controller;
  final String status;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onStatusChanged;

  const _CourseFilters({
    required this.controller,
    required this.status,
    required this.onSearchChanged,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 14,
          runSpacing: 14,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: TextField(
                controller: controller,
                onChanged: onSearchChanged,
                decoration: const InputDecoration(
                  hintText: 'Search title, category, or instructor…',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            for (final value in const [
              ('all', 'All'),
              ('published', 'Published'),
              ('draft', 'Drafts'),
            ])
              ChoiceChip(
                label: Text(value.$2),
                selected: status == value.$1,
                onSelected: (_) => onStatusChanged(value.$1),
              ),
          ],
        ),
      ),
    );
  }
}

class _CourseGrid extends StatelessWidget {
  final List<AdminCourse> courses;

  const _CourseGrid({required this.courses});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1120
            ? 3
            : constraints.maxWidth >= 680
            ? 2
            : 1;
        const spacing = 16.0;
        final cardWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final course in courses)
              SizedBox(
                width: cardWidth,
                child: _CourseCard(course: course),
              ),
          ],
        );
      },
    );
  }
}

class _CourseCard extends StatelessWidget {
  final AdminCourse course;

  const _CourseCard({required this.course});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AdminColors.primarySoft,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.menu_book_outlined,
                    color: AdminColors.primary,
                  ),
                ),
                const Spacer(),
                AdminStatusChip(
                  label: course.isPublished ? 'Published' : 'Draft',
                  color: course.isPublished
                      ? AdminColors.success
                      : AdminColors.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              course.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              course.category?.isNotEmpty == true
                  ? course.category!
                  : 'Uncategorized',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  size: 18,
                  color: AdminColors.textSecondary,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    course.instructorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _CourseMetric(
                  icon: Icons.group_outlined,
                  value: course.enrollmentCount,
                  label: 'students',
                ),
                const SizedBox(width: 18),
                _CourseMetric(
                  icon: Icons.play_lesson_outlined,
                  value: course.lessonCount,
                  label: 'lessons',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseMetric extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;

  const _CourseMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: AdminColors.textSecondary),
        const SizedBox(width: 6),
        Text(
          '$value $label',
          style: const TextStyle(
            color: AdminColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
