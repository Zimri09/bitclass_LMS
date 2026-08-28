import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:intl/intl.dart';

import '../../../../core/errors/app_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/loading_widgets.dart';
import '../../../attendance/presentation/screens/attendance_screen.dart';
import '../../../courses/data/models/course_model.dart';
import '../../data/models/class_record_model.dart';
import '../../data/repositories/class_record_repository.dart';
import '../../data/services/bisu_class_record_document_service.dart';

class CourseRecordsScreen extends StatefulWidget {
  final CourseModel course;
  final String currentUserId;

  const CourseRecordsScreen({
    super.key,
    required this.course,
    required this.currentUserId,
  });

  @override
  State<CourseRecordsScreen> createState() => _CourseRecordsScreenState();
}

class _CourseRecordsScreenState extends State<CourseRecordsScreen> {
  int _selectedSection = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Course Records', style: AppTextStyles.h3),
              const SizedBox(height: 4),
              Text(
                'Review computed grades and manage attendance for this class.',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      icon: Icon(Icons.table_chart_outlined),
                      label: Text('Class record'),
                    ),
                    ButtonSegment(
                      value: 1,
                      icon: Icon(Icons.fact_check_outlined),
                      label: Text('Attendance'),
                    ),
                  ],
                  selected: {_selectedSection},
                  onSelectionChanged: (selection) {
                    setState(() => _selectedSection = selection.single);
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _selectedSection,
            children: [
              _ClassRecordView(course: widget.course),
              AttendanceScreen(
                course: widget.course,
                isCourseOwner: true,
                currentUserId: widget.currentUserId,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ClassRecordView extends StatefulWidget {
  final CourseModel course;

  const _ClassRecordView({required this.course});

  @override
  State<_ClassRecordView> createState() => _ClassRecordViewState();
}

class _ClassRecordViewState extends State<_ClassRecordView> {
  final _searchController = TextEditingController();
  CourseClassRecord? _record;
  bool _isLoading = true;
  bool _isExporting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRecord();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecord() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final record = await context
          .read<ClassRecordRepository>()
          .getCourseRecord(widget.course.id);
      if (!mounted) return;
      setState(() {
        _record = record;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = userFriendlyErrorMessage(error);
        _isLoading = false;
      });
    }
  }

  Future<void> _exportClassRecord() async {
    if (_isExporting || _record == null) return;
    setState(() => _isExporting = true);
    try {
      final bytes = await const BisuClassRecordDocumentService().generate(
        course: widget.course,
        record: _record!,
      );
      final safeCourseTitle = widget.course.title
          .trim()
          .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .replaceAll(RegExp(r'^_|_$'), '');
      final dateStamp = DateFormat('yyyyMMdd').format(DateTime.now());
      final savedUri = await fp.FilePicker.saveFile(
        fileName:
            'BISU_Class_Record_${safeCourseTitle.isEmpty ? 'Course' : safeCourseTitle}_$dateStamp.docx',
        bytes: bytes,
        mimeType:
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        dialogTitle: 'Save BISU class record',
      );
      if (!mounted || savedUri == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('BISU class record Word form saved.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to export class record: ${userFriendlyErrorMessage(error)}',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _record == null) {
      return const BitClassLoader(message: 'Building class record...');
    }
    if (_error != null && _record == null) {
      return ErrorState(message: _error!, onRetry: _loadRecord);
    }

    final record = _record!;
    final query = _searchController.text.trim().toLowerCase();
    final students = query.isEmpty
        ? record.students
        : record.students
              .where(
                (student) => student.displayName.toLowerCase().contains(query),
              )
              .toList();

    return RefreshIndicator(
      onRefresh: _loadRecord,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _RecordSummary(record: record),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _isExporting ? null : _exportClassRecord,
            icon: _isExporting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.description_outlined),
            label: Text(
              _isExporting
                  ? 'Preparing BISU Word form...'
                  : 'Export BISU Word form',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search students',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          if (record.students.isEmpty)
            const _EmptyRecord(
              icon: Icons.group_add_outlined,
              title: 'No enrolled students yet',
              message: 'Students will appear here after they join the class.',
            )
          else if (students.isEmpty)
            const _EmptyRecord(
              icon: Icons.search_off,
              title: 'No students found',
              message: 'Try a different student name.',
            )
          else
            ...students.map(
              (student) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _StudentRecordCard(student: student),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecordSummary extends StatelessWidget {
  final CourseClassRecord record;

  const _RecordSummary({required this.record});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _SummaryValue(
                  label: 'Students',
                  value: '${record.students.length}',
                ),
              ),
              Expanded(
                child: _SummaryValue(
                  label: 'Class average',
                  value: _formatGrade(record.classAverage),
                  color: _gradeColor(record.classAverage),
                ),
              ),
            ],
          ),
          const Divider(height: 28),
          Text('Current grading weights', style: AppTextStyles.label),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _WeightChip(label: 'Quizzes', value: record.weights.quizPercent),
              _WeightChip(
                label: 'Activities',
                value: record.weights.assignmentPercent,
              ),
              _WeightChip(
                label: 'Attendance',
                value: record.weights.attendancePercent,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${record.quizCount} quizzes  |  '
            '${record.assignmentCount} activities  |  '
            '${record.attendanceSessionCount} attendance sessions',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _SummaryValue({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: 3),
        Text(value, style: AppTextStyles.h3.copyWith(color: color)),
      ],
    );
  }
}

class _WeightChip extends StatelessWidget {
  final String label;
  final int value;

  const _WeightChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label $value%',
        style: AppTextStyles.label.copyWith(color: AppColors.primary),
      ),
    );
  }
}

class _StudentRecordCard extends StatelessWidget {
  final StudentClassRecord student;

  const _StudentRecordCard({required this.student});

  @override
  Widget build(BuildContext context) {
    final avatarUrl = student.avatarUrl;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                backgroundImage: avatarUrl == null || avatarUrl.isEmpty
                    ? null
                    : NetworkImage(avatarUrl),
                child: avatarUrl == null || avatarUrl.isEmpty
                    ? Text(
                        _initials(student.displayName),
                        style: AppTextStyles.h4.copyWith(
                          color: AppColors.primary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  student.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Overall', style: AppTextStyles.caption),
                  Text(
                    _formatGrade(student.overallGrade),
                    style: AppTextStyles.h3.copyWith(
                      color: _gradeColor(student.overallGrade),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _GradeMetric(label: 'Quizzes', grade: student.quizGrade),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _GradeMetric(
                  label: 'Activities',
                  grade: student.assignmentGrade,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _GradeMetric(
                  label: 'Attendance',
                  grade: student.attendanceGrade,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GradeMetric extends StatelessWidget {
  final String label;
  final double? grade;

  const _GradeMetric({required this.label, required this.grade});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            _formatGrade(grade),
            style: AppTextStyles.h4.copyWith(color: _gradeColor(grade)),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}

class _EmptyRecord extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyRecord({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 52),
      child: Column(
        children: [
          Icon(icon, size: 52, color: AppColors.textMuted),
          const SizedBox(height: 14),
          Text(title, style: AppTextStyles.h4),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }
}

String _formatGrade(double? grade) {
  return grade == null ? '--' : '${grade.toStringAsFixed(1)}%';
}

Color _gradeColor(double? grade) {
  if (grade == null) return AppColors.textMuted;
  if (grade >= 75) return AppColors.success;
  if (grade >= 60) return AppColors.warning;
  return AppColors.error;
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  final first = parts.first[0];
  final last = parts.length > 1 ? parts.last[0] : '';
  return '$first$last'.toUpperCase();
}
