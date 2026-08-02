import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/loading_widgets.dart';
import '../../../courses/data/models/course_model.dart';
import '../../../courses/data/repositories/course_repository.dart';
import '../../data/models/attendance_models.dart';
import '../../data/repositories/attendance_repository.dart';

class AttendanceScreen extends StatefulWidget {
  final CourseModel course;
  final bool isCourseOwner;
  final String currentUserId;
  final Widget? courseMenu;

  const AttendanceScreen({
    super.key,
    required this.course,
    required this.isCourseOwner,
    required this.currentUserId,
    this.courseMenu,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  List<AttendanceSession> _sessions = const [];
  List<AttendanceRecord> _records = const [];
  List<CourseRosterMember> _roster = const [];
  final Set<String> _checkingIn = {};
  final Stopwatch _serverClock = Stopwatch();
  RealtimeChannel? _realtimeChannel;
  Timer? _clockTimer;
  Timer? _realtimeDebounce;
  DateTime? _serverTime;
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isCreatingSession = false;
  String? _error;

  AttendanceRepository get _repository => context.read<AttendanceRepository>();

  @override
  void initState() {
    super.initState();
    _loadAttendance();
    _realtimeChannel = _repository.subscribeToCourse(
      courseId: widget.course.id,
      onChanged: _scheduleRealtimeRefresh,
    );
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _realtimeDebounce?.cancel();
    unawaited(_repository.removeRealtimeChannel(_realtimeChannel));
    super.dispose();
  }

  DateTime get _secureNow {
    final base = _serverTime;
    return base == null
        ? DateTime.now().toUtc()
        : base.add(_serverClock.elapsed);
  }

  void _scheduleRealtimeRefresh() {
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(
      const Duration(milliseconds: 250),
      () => _loadAttendance(silent: true),
    );
  }

  Future<void> _loadAttendance({bool silent = false}) async {
    final courseRepository = context.read<CourseRepository>();
    if (!silent && mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final serverTime = await _repository.getServerTime();
      final sessions = await _repository.getSessions(widget.course.id);
      final records = await _repository.getCourseRecords(widget.course.id);
      final roster = widget.isCourseOwner
          ? await courseRepository.getCourseRoster(widget.course.id)
          : const <CourseRosterMember>[];
      if (!mounted) return;
      _serverClock
        ..reset()
        ..start();
      setState(() {
        _serverTime = serverTime;
        _sessions = sessions;
        _records = records;
        _roster = roster;
        _isLoading = false;
        _isRefreshing = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        _error = userFriendlyErrorMessage(error);
      });
    }
  }

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    await _loadAttendance(silent: true);
  }

  Future<void> _createSession() async {
    if (_isCreatingSession) return;
    setState(() => _isCreatingSession = true);
    try {
      final serverTime = await _repository.getServerTime();
      if (!mounted) return;
      final request = await showDialog<_NewAttendanceSession>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _CreateAttendanceSessionDialog(
          serverTime: serverTime,
          existingSessions: _sessions,
        ),
      );
      if (request == null || !mounted) return;

      await _repository.createSession(
        courseId: widget.course.id,
        attendanceDate: request.attendanceDate,
        opensAt: request.opensAt,
        lateAt: request.lateAt,
        closesAt: request.closesAt,
        creatorId: widget.currentUserId,
        demoStudentIds: _roster.map((student) => student.userId).toList(),
      );
      await _loadAttendance(silent: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attendance session created.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFriendlyErrorMessage(error)),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isCreatingSession = false);
    }
  }

  Future<void> _checkIn(AttendanceSession session) async {
    if (_checkingIn.contains(session.id)) return;
    setState(() => _checkingIn.add(session.id));
    try {
      final result = await _repository.checkIn(
        sessionId: session.id,
        studentId: widget.currentUserId,
      );
      _serverClock
        ..reset()
        ..start();
      _serverTime = result.serverTime;
      await _loadAttendance(silent: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Checked in as ${result.status.label}.'),
          backgroundColor: _statusColor(result.status),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFriendlyErrorMessage(error)),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _checkingIn.remove(session.id));
    }
  }

  Future<void> _editRecord(AttendanceRecord record) async {
    final correction = await showDialog<_AttendanceCorrection>(
      context: context,
      builder: (_) => _AttendanceCorrectionDialog(record: record),
    );
    if (correction == null || !mounted) return;

    try {
      await _repository.updateRecord(
        record: record,
        status: correction.status,
        note: correction.note,
        instructorId: widget.currentUserId,
      );
      await _loadAttendance(silent: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attendance record updated.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFriendlyErrorMessage(error)),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _showHistory(AttendanceRecord record, String studentName) async {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _AttendanceHistorySheet(
        studentName: studentName,
        changes: _repository.getRecordChanges(record.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const BitClassLoader(message: 'Loading attendance...');
    }
    if (_error != null && _sessions.isEmpty) {
      return ErrorState(message: _error!, onRetry: _loadAttendance);
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Row(
            children: [
              Expanded(child: Text('Attendance', style: AppTextStyles.h3)),
              if (_isRefreshing)
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ?widget.courseMenu,
            ],
          ),
          const SizedBox(height: 6),
          Text(
            widget.isCourseOwner
                ? 'Create sessions and monitor student check-ins in real time.'
                : 'Check in during the attendance window and review your history.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (widget.isCourseOwner) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _isCreatingSession ? null : _createSession,
              icon: _isCreatingSession
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_alarm),
              label: Text(
                _isCreatingSession
                    ? 'Creating attendance session...'
                    : 'Create attendance session',
              ),
            ),
          ],
          const SizedBox(height: 20),
          if (_sessions.isEmpty)
            _EmptyAttendance(isInstructor: widget.isCourseOwner)
          else if (widget.isCourseOwner)
            ..._sessions.map(_buildInstructorSession)
          else
            ..._sessions.map(_buildStudentSession),
        ],
      ),
    );
  }

  Widget _buildInstructorSession(AttendanceSession session) {
    final records = _records
        .where((record) => record.sessionId == session.id)
        .toList();
    final recordsByStudent = {
      for (final record in records) record.studentId: record,
    };
    final counts = {
      for (final status in AttendanceStatus.values)
        status: records.where((record) => record.status == status).length,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: session == _sessions.first,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
        title: Text(
          DateFormat.yMMMMd().format(session.attendanceDate.toLocal()),
          style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: _SessionTimeline(session: session, serverNow: _secureNow),
        ),
        trailing: _WindowChip(window: session.windowAt(_secureNow)),
        children: [
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AttendanceStatus.values
                  .map(
                    (status) =>
                        _CountChip(status: status, count: counts[status] ?? 0),
                  )
                  .toList(),
            ),
          ),
          if (_roster.isEmpty)
            const Padding(
              padding: EdgeInsets.all(18),
              child: Text('No students are enrolled in this course.'),
            )
          else
            ..._roster.map((student) {
              final record = recordsByStudent[student.userId];
              return _InstructorAttendanceTile(
                student: student,
                record: record,
                session: session,
                serverNow: _secureNow,
                onEdit: record == null ? null : () => _editRecord(record),
                onHistory: record == null
                    ? null
                    : () => _showHistory(record, student.displayName),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildStudentSession(AttendanceSession session) {
    AttendanceRecord? record;
    for (final item in _records) {
      if (item.sessionId == session.id &&
          item.studentId == widget.currentUserId) {
        record = item;
        break;
      }
    }
    final window = session.windowAt(_secureNow);
    final checkedIn = record?.checkInAt != null;
    final canCheckIn = !checkedIn && session.isCheckInOpenAt(_secureNow);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat.yMMMMd().format(
                      session.attendanceDate.toLocal(),
                    ),
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _StudentRecordChip(record: record, window: window),
              ],
            ),
            const SizedBox(height: 12),
            _SessionTimeline(session: session, serverNow: _secureNow),
            if (record?.checkInAt != null) ...[
              const SizedBox(height: 12),
              Text(
                'Checked in ${DateFormat.yMMMd().add_jm().format(record!.checkInAt!.toLocal())}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            if (record?.note?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                'Instructor note: ${record!.note}',
                style: AppTextStyles.bodySmall,
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canCheckIn && !_checkingIn.contains(session.id)
                    ? () => _checkIn(session)
                    : null,
                icon: _checkingIn.contains(session.id)
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.how_to_reg),
                label: Text(
                  checkedIn
                      ? 'Checked in'
                      : switch (window) {
                          AttendanceWindow.upcoming => 'Not open yet',
                          AttendanceWindow.closed => 'Attendance closed',
                          _ => 'Check In',
                        },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewAttendanceSession {
  final DateTime attendanceDate;
  final DateTime opensAt;
  final DateTime lateAt;
  final DateTime closesAt;

  const _NewAttendanceSession({
    required this.attendanceDate,
    required this.opensAt,
    required this.lateAt,
    required this.closesAt,
  });
}

class _CreateAttendanceSessionDialog extends StatefulWidget {
  final DateTime serverTime;
  final List<AttendanceSession> existingSessions;

  const _CreateAttendanceSessionDialog({
    required this.serverTime,
    required this.existingSessions,
  });

  @override
  State<_CreateAttendanceSessionDialog> createState() =>
      _CreateAttendanceSessionDialogState();
}

class _CreateAttendanceSessionDialogState
    extends State<_CreateAttendanceSessionDialog> {
  final Stopwatch _serverClock = Stopwatch();
  late DateTime _date;
  late DateTime _opensAt;
  late DateTime _lateAt;
  late DateTime _closesAt;
  bool _showValidationErrors = false;

  @override
  void initState() {
    super.initState();
    _serverClock.start();
    _opensAt = _ceilToMinute(widget.serverTime.toLocal());
    _date = _dateOnly(_opensAt);
    _lateAt = _opensAt.add(const Duration(minutes: 15));
    _closesAt = _lateAt.add(const Duration(minutes: 15));
  }

  @override
  void dispose() {
    _serverClock.stop();
    super.dispose();
  }

  DateTime get _serverNow =>
      widget.serverTime.toLocal().add(_serverClock.elapsed);

  AttendanceSessionValidation get _validation =>
      validateAttendanceSessionSchedule(
        attendanceDate: _date,
        opensAt: _opensAt,
        lateAt: _lateAt,
        closesAt: _closesAt,
        serverNow: _serverNow,
        existingSessions: widget.existingSessions,
      );

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  DateTime _ceilToMinute(DateTime value) {
    final minute = DateTime(
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
    );
    return value.isAfter(minute)
        ? minute.add(const Duration(minutes: 1))
        : minute;
  }

  DateTime _laterOf(DateTime first, DateTime second) {
    return first.isAfter(second) ? first : second;
  }

  Future<void> _pickDate() async {
    final today = _dateOnly(_serverNow);
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (selected == null) return;

    final dayShift = selected.difference(_date).inDays;
    var opensAt = _opensAt.add(Duration(days: dayShift));
    var lateAt = _lateAt.add(Duration(days: dayShift));
    var closesAt = _closesAt.add(Duration(days: dayShift));
    final earliestOpening = _laterOf(selected, _ceilToMinute(_serverNow));
    if (opensAt.isBefore(earliestOpening)) {
      final lateDuration = _lateAt.difference(_opensAt);
      final closingDuration = _closesAt.difference(_lateAt);
      opensAt = earliestOpening;
      lateAt = opensAt.add(lateDuration);
      closesAt = lateAt.add(closingDuration);
    }

    setState(() {
      _date = selected;
      _opensAt = opensAt;
      _lateAt = lateAt;
      _closesAt = closesAt;
    });
  }

  Future<void> _pickTime({
    required String title,
    required DateTime current,
    required DateTime minimum,
    required DateTime maximum,
    required ValueChanged<DateTime> onSelected,
  }) async {
    final selected = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AllowedTimePickerSheet(
        title: title,
        current: current,
        minimum: minimum,
        maximum: maximum,
        attendanceDate: _date,
      ),
    );
    if (selected != null) setState(() => onSelected(selected));
  }

  void _submit() {
    final validation = _validation;
    setState(() => _showValidationErrors = true);
    if (!validation.isValid) return;

    Navigator.of(context).pop(
      _NewAttendanceSession(
        attendanceDate: _date,
        opensAt: _opensAt,
        lateAt: _lateAt,
        closesAt: _closesAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final validation = _validation;
    final endOfAttendanceDate = _date
        .add(const Duration(days: 1))
        .subtract(const Duration(minutes: 1));
    return AlertDialog(
      title: const Text('Create attendance'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Attendance date'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormat.yMMMMd().format(_date)),
                  if (_showValidationErrors && validation.dateError != null)
                    _FieldError(validation.dateError!),
                ],
              ),
              onTap: _pickDate,
            ),
            _TimePickerTile(
              label: 'Opening time',
              value: _opensAt,
              attendanceDate: _date,
              errorText: _showValidationErrors ? validation.openingError : null,
              onTap: () => _pickTime(
                title: 'Opening time',
                current: _opensAt,
                minimum: _laterOf(_date, _ceilToMinute(_serverNow)),
                maximum: endOfAttendanceDate,
                onSelected: (value) => _opensAt = value,
              ),
            ),
            _TimePickerTile(
              label: 'Late time',
              value: _lateAt,
              attendanceDate: _date,
              errorText: _showValidationErrors
                  ? validation.lateTimeError
                  : null,
              onTap: () => _pickTime(
                title: 'Late time',
                current: _lateAt,
                minimum: _opensAt.add(const Duration(minutes: 1)),
                maximum: _opensAt.add(const Duration(days: 1)),
                onSelected: (value) => _lateAt = value,
              ),
            ),
            _TimePickerTile(
              label: 'Closing time',
              value: _closesAt,
              attendanceDate: _date,
              errorText: _showValidationErrors ? validation.closingError : null,
              onTap: () => _pickTime(
                title: 'Closing time',
                current: _closesAt,
                minimum: _lateAt.add(const Duration(minutes: 1)),
                maximum: _lateAt.add(const Duration(days: 1)),
                onSelected: (value) => _closesAt = value,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Create')),
      ],
    );
  }
}

class _TimePickerTile extends StatelessWidget {
  final String label;
  final DateTime value;
  final DateTime attendanceDate;
  final String? errorText;
  final VoidCallback onTap;

  const _TimePickerTile({
    required this.label,
    required this.value,
    required this.attendanceDate,
    this.errorText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.schedule),
      title: Text(label),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatAttendanceTime(value, attendanceDate),
            style: AppTextStyles.bodyMedium,
          ),
          if (errorText != null) _FieldError(errorText!),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _FieldError extends StatelessWidget {
  final String message;

  const _FieldError(this.message);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        message,
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
      ),
    );
  }
}

class _AllowedTimePickerSheet extends StatefulWidget {
  final String title;
  final DateTime current;
  final DateTime minimum;
  final DateTime maximum;
  final DateTime attendanceDate;

  const _AllowedTimePickerSheet({
    required this.title,
    required this.current,
    required this.minimum,
    required this.maximum,
    required this.attendanceDate,
  });

  @override
  State<_AllowedTimePickerSheet> createState() =>
      _AllowedTimePickerSheetState();
}

class _AllowedTimePickerSheetState extends State<_AllowedTimePickerSheet> {
  String? _quickEntryError;

  Future<void> _typeTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(widget.current),
      initialEntryMode: TimePickerEntryMode.inputOnly,
      helpText: 'Type ${widget.title.toLowerCase()}',
      confirmText: 'Use time',
    );
    if (selected == null || !mounted) return;

    final candidates = _typedTimeCandidates(selected);
    if (candidates.isEmpty) {
      setState(() {
        _quickEntryError =
            'Enter a time between '
            '${_formatAttendanceTime(widget.minimum, widget.attendanceDate)} '
            'and ${_formatAttendanceTime(widget.maximum, widget.attendanceDate)}.';
      });
      return;
    }

    candidates.sort((first, second) {
      final firstDistance = first.difference(widget.current).abs();
      final secondDistance = second.difference(widget.current).abs();
      return firstDistance.compareTo(secondDistance);
    });
    Navigator.of(context).pop(candidates.first);
  }

  List<DateTime> _typedTimeCandidates(TimeOfDay selected) {
    final candidates = <DateTime>[];
    var day = DateTime(
      widget.minimum.year,
      widget.minimum.month,
      widget.minimum.day,
    );
    final lastDay = DateTime(
      widget.maximum.year,
      widget.maximum.month,
      widget.maximum.day,
    );

    while (!day.isAfter(lastDay)) {
      final candidate = DateTime(
        day.year,
        day.month,
        day.day,
        selected.hour,
        selected.minute,
      );
      if (!candidate.isBefore(widget.minimum) &&
          !candidate.isAfter(widget.maximum)) {
        candidates.add(candidate);
      }
      day = day.add(const Duration(days: 1));
    }
    return candidates;
  }

  @override
  Widget build(BuildContext context) {
    final first = DateTime(
      widget.minimum.year,
      widget.minimum.month,
      widget.minimum.day,
      widget.minimum.hour,
      widget.minimum.minute,
    );
    final count = widget.maximum.isBefore(first)
        ? 0
        : widget.maximum.difference(first).inMinutes + 1;

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.68,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text(widget.title, style: AppTextStyles.h4),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'Type a time for faster entry, or choose from the valid list below. Times may continue into the next day.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _typeTime,
                  icon: const Icon(Icons.keyboard_alt_outlined),
                  label: const Text('Type time'),
                ),
              ),
            ),
            if (_quickEntryError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: _FieldError(_quickEntryError!),
              ),
            const Divider(height: 1),
            Expanded(
              child: count == 0
                  ? const Center(child: Text('No valid times remain.'))
                  : ListView.builder(
                      itemCount: count,
                      itemBuilder: (context, index) {
                        final value = first.add(Duration(minutes: index));
                        final selected =
                            value.year == widget.current.year &&
                            value.month == widget.current.month &&
                            value.day == widget.current.day &&
                            value.hour == widget.current.hour &&
                            value.minute == widget.current.minute;
                        return ListTile(
                          title: Text(
                            _formatAttendanceTime(value, widget.attendanceDate),
                          ),
                          trailing: selected
                              ? const Icon(
                                  Icons.check_circle,
                                  color: AppColors.primary,
                                )
                              : null,
                          onTap: () => Navigator.of(context).pop(value),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatAttendanceTime(DateTime value, DateTime attendanceDate) {
  final sameDay =
      value.year == attendanceDate.year &&
      value.month == attendanceDate.month &&
      value.day == attendanceDate.day;
  final time = DateFormat.jm().format(value);
  return sameDay
      ? time
      : '${DateFormat.MMMd().format(value)}\n$time (next day)';
}

class _AttendanceCorrection {
  final AttendanceStatus status;
  final String? note;

  const _AttendanceCorrection({required this.status, this.note});
}

class _AttendanceCorrectionDialog extends StatefulWidget {
  final AttendanceRecord record;

  const _AttendanceCorrectionDialog({required this.record});

  @override
  State<_AttendanceCorrectionDialog> createState() =>
      _AttendanceCorrectionDialogState();
}

class _AttendanceCorrectionDialogState
    extends State<_AttendanceCorrectionDialog> {
  late AttendanceStatus _status;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _status = widget.record.status;
    _noteController = TextEditingController(text: widget.record.note);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Update attendance'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<AttendanceStatus>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'Status'),
            items: AttendanceStatus.values
                .map(
                  (status) => DropdownMenuItem(
                    value: status,
                    child: Text(status.label),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _status = value);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Reason or note (optional)',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _AttendanceCorrection(
              status: _status,
              note: _noteController.text.trim().isEmpty
                  ? null
                  : _noteController.text.trim(),
            ),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _AttendanceHistorySheet extends StatelessWidget {
  final String studentName;
  final Future<List<AttendanceRecordChange>> changes;

  const _AttendanceHistorySheet({
    required this.studentName,
    required this.changes,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.55,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$studentName history', style: AppTextStyles.h4),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<AttendanceRecordChange>>(
                  future: changes,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text('Unable to load change history.'),
                      );
                    }
                    final items = snapshot.data ?? [];
                    if (items.isEmpty) {
                      return const Center(
                        child: Text('No attendance changes yet.'),
                      );
                    }
                    return ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            item.changeType == 'check_in'
                                ? Icons.how_to_reg
                                : Icons.edit_note,
                          ),
                          title: Text(
                            '${item.previousStatus.label} → ${item.updatedStatus.label}',
                          ),
                          subtitle: Text(
                            '${item.changeType == 'check_in' ? 'Student check-in' : 'Manual correction'} · '
                            '${DateFormat.yMMMd().add_jm().format(item.changedAt.toLocal())}'
                            '${item.updatedNote == null ? '' : '\n${item.updatedNote}'}',
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InstructorAttendanceTile extends StatelessWidget {
  final CourseRosterMember student;
  final AttendanceRecord? record;
  final AttendanceSession session;
  final DateTime serverNow;
  final VoidCallback? onEdit;
  final VoidCallback? onHistory;

  const _InstructorAttendanceTile({
    required this.student,
    required this.record,
    required this.session,
    required this.serverNow,
    this.onEdit,
    this.onHistory,
  });

  @override
  Widget build(BuildContext context) {
    final currentRecord = record;
    final window = session.windowAt(serverNow);
    final pending =
        currentRecord?.checkInAt == null &&
        window != AttendanceWindow.closed &&
        currentRecord?.status == AttendanceStatus.absent;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _AttendanceAvatar(
        name: student.displayName,
        avatarUrl: student.avatarUrl,
      ),
      title: Text(student.displayName),
      subtitle: Text(
        currentRecord?.checkInAt == null
            ? pending
                  ? 'Waiting for check-in'
                  : 'No check-in recorded'
            : 'Checked in ${DateFormat.jm().format(currentRecord!.checkInAt!.toLocal())}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          pending
              ? const _NeutralChip(label: 'Pending')
              : _StatusChip(
                  status: currentRecord?.status ?? AttendanceStatus.absent,
                ),
          if (currentRecord != null)
            PopupMenuButton<String>(
              tooltip: 'Attendance actions',
              onSelected: (value) {
                if (value == 'edit') onEdit?.call();
                if (value == 'history') onHistory?.call();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit record')),
                PopupMenuItem(value: 'history', child: Text('View history')),
              ],
            ),
        ],
      ),
    );
  }
}

class _SessionTimeline extends StatelessWidget {
  final AttendanceSession session;
  final DateTime serverNow;

  const _SessionTimeline({required this.session, required this.serverNow});

  @override
  Widget build(BuildContext context) {
    final format = DateFormat.jm();
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      children: [
        Text('Opens ${format.format(session.opensAt.toLocal())}'),
        Text('Late from ${format.format(session.lateAt.toLocal())}'),
        Text('Closes ${format.format(session.closesAt.toLocal())}'),
      ],
    );
  }
}

class _WindowChip extends StatelessWidget {
  final AttendanceWindow window;

  const _WindowChip({required this.window});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (window) {
      AttendanceWindow.upcoming => ('Upcoming', AppColors.info),
      AttendanceWindow.present => ('Present window', AppColors.success),
      AttendanceWindow.late => ('Late window', AppColors.warning),
      AttendanceWindow.closed => ('Closed', AppColors.textMuted),
    };
    return Chip(
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.14),
      side: BorderSide.none,
      labelStyle: AppTextStyles.caption.copyWith(color: color),
    );
  }
}

class _StudentRecordChip extends StatelessWidget {
  final AttendanceRecord? record;
  final AttendanceWindow window;

  const _StudentRecordChip({required this.record, required this.window});

  @override
  Widget build(BuildContext context) {
    if (record?.checkInAt == null && window != AttendanceWindow.closed) {
      return const _NeutralChip(label: 'Not checked in');
    }
    return _StatusChip(status: record?.status ?? AttendanceStatus.absent);
  }
}

class _CountChip extends StatelessWidget {
  final AttendanceStatus status;
  final int count;

  const _CountChip({required this.status, required this.count});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: color,
        child: Text('$count', style: const TextStyle(color: Colors.white)),
      ),
      label: Text(status.label),
      side: BorderSide(color: color.withValues(alpha: 0.35)),
      backgroundColor: color.withValues(alpha: 0.08),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final AttendanceStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Chip(
      label: Text(status.label),
      visualDensity: VisualDensity.compact,
      side: BorderSide.none,
      backgroundColor: color.withValues(alpha: 0.14),
      labelStyle: AppTextStyles.caption.copyWith(color: color),
    );
  }
}

class _NeutralChip extends StatelessWidget {
  final String label;

  const _NeutralChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      side: BorderSide.none,
      backgroundColor: AppColors.textMuted.withValues(alpha: 0.12),
      labelStyle: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
    );
  }
}

class _AttendanceAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;

  const _AttendanceAvatar({required this.name, this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0])
        .join()
        .toUpperCase();
    return CircleAvatar(
      backgroundImage: avatarUrl?.isNotEmpty == true
          ? NetworkImage(avatarUrl!)
          : null,
      child: avatarUrl?.isNotEmpty == true ? null : Text(initials),
    );
  }
}

class _EmptyAttendance extends StatelessWidget {
  final bool isInstructor;

  const _EmptyAttendance({required this.isInstructor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 72),
      child: Column(
        children: [
          Icon(Icons.fact_check_outlined, size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text('No attendance sessions yet', style: AppTextStyles.h4),
          const SizedBox(height: 8),
          Text(
            isInstructor
                ? 'Create the first session for this course.'
                : 'Your instructor has not created attendance yet.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

Color _statusColor(AttendanceStatus status) {
  return switch (status) {
    AttendanceStatus.present => AppColors.success,
    AttendanceStatus.late => AppColors.warning,
    AttendanceStatus.absent => AppColors.error,
    AttendanceStatus.excused => AppColors.info,
  };
}
