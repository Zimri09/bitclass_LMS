import 'dart:async';

import 'package:flutter/material.dart';

String formatRelativeTimestamp(DateTime timestamp, {DateTime? now}) {
  final nowUtc = (now ?? DateTime.now()).toUtc();
  final timestampUtc = timestamp.toUtc();
  final difference = nowUtc.difference(timestampUtc);
  final elapsed = difference.isNegative ? Duration.zero : difference;

  if (elapsed.inSeconds < 10) return 'Just now';
  if (elapsed.inMinutes < 1) return '${elapsed.inSeconds}s ago';
  if (elapsed.inHours < 1) return '${elapsed.inMinutes}m ago';
  if (elapsed.inDays < 1) return '${elapsed.inHours}h ago';
  if (elapsed.inDays < 7) return '${elapsed.inDays}d ago';

  final localTimestamp = timestamp.toLocal();
  return '${localTimestamp.day}/${localTimestamp.month}/${localTimestamp.year}';
}

class RelativeTimestamp extends StatefulWidget {
  final DateTime timestamp;
  final TextStyle? style;
  final String? suffix;
  final DateTime Function()? now;

  const RelativeTimestamp({
    super.key,
    required this.timestamp,
    this.style,
    this.suffix,
    this.now,
  });

  @override
  State<RelativeTimestamp> createState() => _RelativeTimestampState();
}

class _RelativeTimestampState extends State<RelativeTimestamp> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scheduleNextUpdate();
  }

  @override
  void didUpdateWidget(covariant RelativeTimestamp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timestamp != widget.timestamp) {
      _timer?.cancel();
      _scheduleNextUpdate();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _scheduleNextUpdate() {
    final elapsed = _now().toUtc().difference(widget.timestamp.toUtc());
    final delay = _nextRefreshDelay(
      elapsed.isNegative ? Duration.zero : elapsed,
    );
    if (delay == null) return;

    _timer = Timer(delay, () {
      if (!mounted) return;
      setState(() {});
      _scheduleNextUpdate();
    });
  }

  DateTime _now() => widget.now?.call() ?? DateTime.now();

  Duration? _nextRefreshDelay(Duration elapsed) {
    if (elapsed.inMinutes < 1) {
      return const Duration(seconds: 1);
    }
    if (elapsed.inHours < 1) {
      return Duration(seconds: 60 - (elapsed.inSeconds % 60));
    }
    if (elapsed.inDays < 1) {
      return Duration(minutes: 60 - (elapsed.inMinutes % 60));
    }
    if (elapsed.inDays < 7) {
      return Duration(hours: 24 - (elapsed.inHours % 24));
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final suffix = widget.suffix;
    final text = formatRelativeTimestamp(widget.timestamp, now: _now());
    return Text(
      suffix == null || suffix.isEmpty ? text : '$text - $suffix',
      style: widget.style,
    );
  }
}
