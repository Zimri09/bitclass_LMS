import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/course_model.dart';
import '../../data/repositories/course_repository.dart';

/// Screen that shows the list of students enrolled in a course.
/// Accessible to the course instructor/owner.
class EnrolledStudentsScreen extends StatefulWidget {
  final String courseId;

  const EnrolledStudentsScreen({super.key, required this.courseId});

  @override
  State<EnrolledStudentsScreen> createState() => _EnrolledStudentsScreenState();
}

class _EnrolledStudentsScreenState extends State<EnrolledStudentsScreen> {
  List<EnrollmentModel> _enrollments = [];
  List<EnrollmentModel> _filtered = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  String _sortBy = 'date'; // 'date', 'name', 'progress'

  @override
  void initState() {
    super.initState();
    _loadEnrollments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEnrollments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = context.read<CourseRepository>();
      final enrollments = await repo.getCourseEnrollments(widget.courseId);
      setState(() {
        _enrollments = enrollments;
        _filtered = enrollments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onSearch(String query) {
    setState(() {
      if (query.isEmpty) {
        _filtered = _enrollments;
      } else {
        final q = query.toLowerCase();
        _filtered = _enrollments.where((e) {
          final name = (e.studentName ?? '').toLowerCase();
          final email = (e.studentEmail ?? '').toLowerCase();
          return name.contains(q) || email.contains(q);
        }).toList();
      }
      _applySorting();
    });
  }

  void _applySorting() {
    switch (_sortBy) {
      case 'name':
        _filtered.sort(
          (a, b) => (a.studentName ?? '').compareTo(b.studentName ?? ''),
        );
      case 'progress':
        _filtered.sort((a, b) => b.progress.compareTo(a.progress));
      case 'date':
      default:
        _filtered.sort((a, b) => b.enrolledAt.compareTo(a.enrolledAt));
    }
  }

  void _changeSortBy(String value) {
    setState(() {
      _sortBy = value;
      _applySorting();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enrolled Students'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort by',
            onSelected: _changeSortBy,
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'date',
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 18,
                      color: _sortBy == 'date'
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Enrollment Date',
                      style: TextStyle(
                        color: _sortBy == 'date' ? AppColors.primary : null,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'name',
                child: Row(
                  children: [
                    Icon(
                      Icons.sort_by_alpha,
                      size: 18,
                      color: _sortBy == 'name'
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Name',
                      style: TextStyle(
                        color: _sortBy == 'name' ? AppColors.primary : null,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'progress',
                child: Row(
                  children: [
                    Icon(
                      Icons.trending_up,
                      size: 18,
                      color: _sortBy == 'progress'
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Progress',
                      style: TextStyle(
                        color: _sortBy == 'progress' ? AppColors.primary : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildErrorState()
          : _buildContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            'Failed to load enrollments',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? '',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadEnrollments,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        _buildSummaryBar(),
        _buildSearchBar(),
        Expanded(
          child: _filtered.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadEnrollments,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _buildStudentCard(_filtered[index]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSummaryBar() {
    final total = _enrollments.length;
    final completed = _enrollments.where((e) => e.isCompleted).length;
    final avgProgress = total > 0
        ? _enrollments.fold<double>(0, (sum, e) => sum + e.progress) / total
        : 0.0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _buildStatItem(
            icon: Icons.people,
            label: 'Total',
            value: '$total',
            color: AppColors.primary,
          ),
          _buildDivider(),
          _buildStatItem(
            icon: Icons.check_circle,
            label: 'Completed',
            value: '$completed',
            color: AppColors.success,
          ),
          _buildDivider(),
          _buildStatItem(
            icon: Icons.trending_up,
            label: 'Avg Progress',
            value: '${(avgProgress * 100).toInt()}%',
            color: AppColors.warning,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 40, color: AppColors.border);
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearch,
        decoration: InputDecoration(
          hintText: 'Search students...',
          prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _onSearch('');
                  },
                )
              : null,
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.primary),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasSearch = _searchController.text.isNotEmpty;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasSearch ? Icons.search_off : Icons.people_outline,
            size: 64,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            hasSearch
                ? 'No students match your search'
                : 'No students enrolled yet',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary),
          ),
          if (!hasSearch) ...[
            const SizedBox(height: 8),
            Text(
              'Share your course link to get students enrolled.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStudentCard(EnrollmentModel enrollment) {
    final name = enrollment.studentName ?? 'Unknown Student';
    final email = enrollment.studentEmail ?? '';
    final initials = _getInitials(name);
    final enrolledDate = _formatDate(enrollment.enrolledAt);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enrollment.isCompleted
              ? AppColors.success.withValues(alpha: 0.5)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primary.withValues(alpha: 0.2),
            child: Text(
              initials,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (enrollment.isCompleted)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Completed',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: AppColors.success),
                        ),
                      ),
                  ],
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 6),
                // Progress bar
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: enrollment.progress,
                          minHeight: 6,
                          backgroundColor: AppColors.backgroundSecondary,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            enrollment.isCompleted
                                ? AppColors.success
                                : AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${enrollment.progressPercent}%',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Enrolled $enrolledDate',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty || name == 'Unknown Student') return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} weeks ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
