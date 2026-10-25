import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/quiz_repository.dart';

class QuizSecurityReview extends StatefulWidget {
  const QuizSecurityReview({super.key, required this.quizId});
  final String quizId;
  @override
  State<QuizSecurityReview> createState() => _QuizSecurityReviewState();
}

class _QuizSecurityReviewState extends State<QuizSecurityReview> {
  Future<List<Map<String, dynamic>>>? _events;
  void _refresh() => setState(() {
    _events = context.read<QuizRepository>().getSecurityEvents(widget.quizId);
  });

  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: const Text('Quiz activity review'),
    onExpansionChanged: (open) {
      if (open && _events == null) _refresh();
    },
    children: [
      const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          'Client-reported signals are not proof of cheating. Interruptions may be legitimate. '
          'Delivery is best effort; offline sessions or closing a browser can lose events. '
          'Showing the latest 500 events.',
        ),
      ),
      TextButton(onPressed: _refresh, child: const Text('Refresh')),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _events,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Text(
              'Activity could not be loaded. Retry with Refresh.',
            );
          }
          if (!snapshot.hasData) return const LinearProgressIndicator();
          if (snapshot.data!.isEmpty) {
            return const Text('No recorded activity.');
          }
          return Column(
            children: snapshot.data!.map((event) {
              final attempt = event['quiz_attempts'] as Map<String, dynamic>;
              return ListTile(
                title: Text('${event['event_type']} · ${event['platform']}'),
                subtitle: Text(
                  'Student ${attempt['user_id']} · Attempt ${attempt['attempt_number']}\n'
                  '${DateTime.parse(event['created_at'] as String).toLocal()}',
                ),
              );
            }).toList(),
          );
        },
      ),
    ],
  );
}
