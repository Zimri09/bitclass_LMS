import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_text_styles.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final normalizedQuery = _query.trim().toLowerCase();
    final results = normalizedQuery.isEmpty
        ? _helpArticles
        : _helpArticles
              .where(
                (article) => [
                  article.category,
                  article.question,
                  article.answer,
                ].any((value) => value.toLowerCase().contains(normalizedQuery)),
              )
              .toList();

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text('Help Center', style: AppTextStyles.h3),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'How can we help?',
                style: AppTextStyles.h2.copyWith(color: colors.onSurface),
              ),
              const SizedBox(height: 8),
              Text(
                'Search common questions about accounts, classes, assessments, and offline access.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: 'Search help articles',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                normalizedQuery.isEmpty
                    ? 'Frequently Asked Questions'
                    : '${results.length} result${results.length == 1 ? '' : 's'}',
                style: AppTextStyles.h4.copyWith(color: colors.onSurface),
              ),
              const SizedBox(height: 12),
              if (results.isEmpty)
                _EmptyHelpResults(query: _query)
              else
                ...results.map(
                  (article) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: colors.surfaceContainerHighest,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: colors.outlineVariant),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ExpansionTile(
                        leading: Icon(article.icon, color: colors.primary),
                        title: Text(article.question),
                        subtitle: Text(article.category),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          20,
                          0,
                          20,
                          20,
                        ),
                        expandedCrossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(),
                          Text(
                            article.answer,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: colors.onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 22),
              Divider(color: colors.outlineVariant),
              const SizedBox(height: 22),
              Text(
                'Still need help?',
                style: AppTextStyles.h4.copyWith(color: colors.onSurface),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: () => context.push(AppRoutes.settingsFeedback),
                    icon: const Icon(Icons.feedback_outlined),
                    label: const Text('Send Feedback'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.push(AppRoutes.settingsBugReport),
                    icon: const Icon(Icons.bug_report_outlined),
                    label: const Text('Report a Bug'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyHelpResults extends StatelessWidget {
  final String query;

  const _EmptyHelpResults({required this.query});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(Icons.search_off, size: 42, color: colors.onSurfaceVariant),
          const SizedBox(height: 12),
          Text('No help articles found for "$query".'),
        ],
      ),
    );
  }
}

class _HelpArticle {
  final String category;
  final String question;
  final String answer;
  final IconData icon;

  const _HelpArticle({
    required this.category,
    required this.question,
    required this.answer,
    required this.icon,
  });
}

const _helpArticles = <_HelpArticle>[
  _HelpArticle(
    category: 'Account',
    question: 'How do I sign in?',
    answer:
        'Students can continue with a verified @bisu.edu.ph Google account. Existing instructor accounts can continue using their registered email address and password.',
    icon: Icons.login,
  ),
  _HelpArticle(
    category: 'Account',
    question: 'How do I reset my password?',
    answer:
        'Choose Forgot password on the sign-in screen, enter your registered email address, and complete the verification steps. Use the newest verification code you receive.',
    icon: Icons.password,
  ),
  _HelpArticle(
    category: 'Classes',
    question: 'Where can I find my classes?',
    answer:
        'Open Classes from the navigation menu. Students see enrolled classes, while instructors see the classes they manage.',
    icon: Icons.dashboard_outlined,
  ),
  _HelpArticle(
    category: 'Coursework',
    question: 'Where are upcoming activities shown?',
    answer:
        'Open To-do to review upcoming activities, quizzes, and lessons. A red indicator appears in navigation when new activity is available.',
    icon: Icons.check_box_outlined,
  ),
  _HelpArticle(
    category: 'Assessments',
    question: 'Why can I not retake a quiz?',
    answer:
        'Quiz attempts are controlled by the instructor. When the maximum number of attempts has been reached, another attempt cannot be started.',
    icon: Icons.quiz_outlined,
  ),
  _HelpArticle(
    category: 'Grades',
    question: 'Where can I review grades and feedback?',
    answer:
        'Open My Grades from the navigation menu. Select an assessment to review the recorded score and any instructor feedback that is available.',
    icon: Icons.grade_outlined,
  ),
  _HelpArticle(
    category: 'Offline Access',
    question: 'How do offline files work?',
    answer:
        'Download supported course files while connected, then open Offline Files from navigation. Changes that require the server remain unavailable until connectivity returns.',
    icon: Icons.offline_pin_outlined,
  ),
  _HelpArticle(
    category: 'Notifications',
    question: 'How do I change notification preferences?',
    answer:
        'Open Settings, then Notification Preferences. You can choose notification categories and quiet hours, subject to the permissions enabled in Android system settings.',
    icon: Icons.notifications_outlined,
  ),
];
