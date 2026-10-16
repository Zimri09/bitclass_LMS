import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/errors/app_error.dart';
import '../../../attendance/data/models/attendance_models.dart';
import '../../../courses/data/models/course_model.dart';
import '../../data/models/student_performance.dart';

Future<void> showStudentPerformanceDialog(
  BuildContext context, {
  required CourseModel course,
  required Future<StudentPerformance> Function() load,
}) => showDialog<void>(
  context: context,
  barrierColor: Colors.black54,
  barrierDismissible: true,
  builder: (_) => BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
    child: StudentPerformanceDialog(course: course, load: load),
  ),
);

class StudentPerformanceDialog extends StatefulWidget {
  final CourseModel course;
  final Future<StudentPerformance> Function() load;
  const StudentPerformanceDialog({
    super.key,
    required this.course,
    required this.load,
  });
  @override
  State<StudentPerformanceDialog> createState() =>
      _StudentPerformanceDialogState();
}

class _StudentPerformanceDialogState extends State<StudentPerformanceDialog> {
  late Future<StudentPerformance> _future;
  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(16),
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 600,
        maxHeight: MediaQuery.sizeOf(context).height * .85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Student performance',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: 'Close preview',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: FutureBuilder<StudentPerformance>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading performance...'),
                      ],
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(userFriendlyErrorMessage(snapshot.error!)),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _future = widget.load();
                              });
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final data = snapshot.data!;
                final avatar = data.student.avatarUrl;
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            foregroundImage: avatar == null || avatar.isEmpty
                                ? null
                                : NetworkImage(avatar),
                            child: Text(
                              data.student.displayName.trim().isEmpty
                                  ? '?'
                                  : data.student.displayName
                                        .trim()[0]
                                        .toUpperCase(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data.student.displayName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(widget.course.title),
                                Text(
                                  '${widget.course.category} • ${widget.course.instructorName}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _section(context, 'Overall performance', [
                        Text(
                          _points(data.earned, data.possible),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Text('Total quiz and activity points'),
                        const SizedBox(height: 8),
                        Text(
                          'Weighted course grade: ${_percentage(data.student.overallGrade)}',
                        ),
                        const Text(
                          'The course grade uses the existing category weights. Attendance is summarized separately.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ]),
                      _scores(
                        context,
                        'Quiz scores',
                        data.quizzes,
                        'No quizzes in this course.',
                      ),
                      _scores(
                        context,
                        'Activity scores',
                        data.activities,
                        'No activities in this course.',
                      ),
                      _section(context, 'Attendance summary', [
                        Text('Total sessions: ${data.sessionCount}'),
                        const SizedBox(height: 8),
                        if (data.attendance.isEmpty)
                          const Text('No attendance records for this student.'),
                        Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          children: [
                            for (final status in AttendanceStatus.values)
                              Text('${status.label}: ${data.count(status)}'),
                          ],
                        ),
                        if (data.sessionCount > data.attendance.length)
                          Text(
                            'Unrecorded: ${data.sessionCount - data.attendance.length}',
                          ),
                        const SizedBox(height: 8),
                        Text(
                          'Attendance: ${_percentage(data.student.attendanceGrade)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const Text(
                          'Present = 100%, Late = 75%, Absent = 0%. Excused and unrecorded sessions are excluded.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ]),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );

  Widget _scores(
    BuildContext context,
    String title,
    List<PerformanceScore> scores,
    String empty,
  ) => _section(context, title, [
    if (scores.isEmpty)
      Text(empty)
    else ...[
      Text(
        _points(
          scores.fold(0, (sum, s) => sum + s.earned),
          scores.fold(0, (sum, s) => sum + s.possible),
        ),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      for (final score in scores)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                score.title,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(_points(score.earned, score.possible)),
              Text(score.status, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      const SizedBox(height: 10),
      const Text(
        'Ungraded or missing work contributes 0 points under the current grading rules.',
        style: TextStyle(fontSize: 12),
      ),
    ],
  ]);

  Widget _section(BuildContext context, String title, List<Widget> children) =>
      Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      );
}

String _number(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(2);
String _percentage(double? value) =>
    value == null ? '—' : '${value.toStringAsFixed(1)}%';
String _points(double earned, double possible) =>
    '${_number(earned)} / ${_number(possible)} points (${_percentage(possible > 0 ? earned / possible * 100 : null)})';
