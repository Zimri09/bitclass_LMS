import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_text_styles.dart';

enum LegalDocument { terms, privacy }

class LegalDocumentScreen extends StatelessWidget {
  final LegalDocument document;

  const LegalDocumentScreen({super.key, required this.document});

  bool get _isTerms => document == LegalDocument.terms;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final sections = _isTerms ? _termsSections : _privacySections;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(
          _isTerms ? 'Terms of Service' : 'Privacy Policy',
          style: AppTextStyles.h3,
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                _isTerms ? 'BitClass Terms of Service' : 'BitClass Privacy Policy',
                style: AppTextStyles.h2.copyWith(color: colors.onSurface),
              ),
              const SizedBox(height: 8),
              Text(
                'Effective August 26, 2026',
                style: AppTextStyles.caption.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              ...sections.indexed.map(
                (entry) => _LegalSectionView(
                  number: entry.$1 + 1,
                  section: entry.$2,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => context.push(AppRoutes.settingsFeedback),
                icon: const Icon(Icons.feedback_outlined),
                label: const Text('Ask a question or send feedback'),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegalSectionView extends StatelessWidget {
  final int number;
  final _LegalSection section;

  const _LegalSectionView({required this.number, required this.section});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$number. ${section.title}',
            style: AppTextStyles.h4.copyWith(color: colors.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            section.body,
            style: AppTextStyles.bodyMedium.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalSection {
  final String title;
  final String body;

  const _LegalSection(this.title, this.body);
}

const _termsSections = <_LegalSection>[
  _LegalSection(
    'Agreement and eligibility',
    'By accessing BitClass, you agree to these terms and any applicable policies of your school or institution. You must provide accurate account information and use the service only for authorized educational purposes.',
  ),
  _LegalSection(
    'Accounts and security',
    'You are responsible for activity under your account and for protecting your sign-in credentials. Do not share an account, impersonate another person, or attempt to access a class, file, grade, or administrative function without permission.',
  ),
  _LegalSection(
    'Acceptable use',
    'Do not disrupt the service, bypass security controls, upload malicious code, harass other users, violate academic integrity rules, or submit content that is unlawful or infringes another person\'s rights. Coding tools must be used within course and institutional rules.',
  ),
  _LegalSection(
    'Course content and submissions',
    'Instructors and institutions remain responsible for course materials, grading decisions, deadlines, and academic policies. You retain ownership of original work you submit, while granting the access required to store, process, display, and assess that work within BitClass.',
  ),
  _LegalSection(
    'Service availability',
    'BitClass may be updated, interrupted, or unavailable because of maintenance, connectivity, device limitations, or third-party services. Keep appropriate copies of important work and verify that time-sensitive submissions were recorded.',
  ),
  _LegalSection(
    'Suspension and termination',
    'Access may be limited or removed when required by an institution, when an account presents a security risk, or when these terms are materially violated. Course and account records may be retained when required for academic, security, or legal purposes.',
  ),
  _LegalSection(
    'Changes to these terms',
    'These terms may be updated as BitClass and institutional requirements change. The effective date will be revised when a new version is published in the app. Continued use after an update means the revised terms apply.',
  ),
];

const _privacySections = <_LegalSection>[
  _LegalSection(
    'Information collected',
    'BitClass processes account and profile information, enrollment and course activity, assignments and quiz responses, grades and feedback, discussions, uploaded files, notification preferences, device tokens, and support requests. Technical logs may include app version, device platform, timestamps, and error details.',
  ),
  _LegalSection(
    'How information is used',
    'Information is used to authenticate users, deliver classes and learning materials, record academic work, calculate progress and grades, support communication, send requested notifications, provide offline access, secure the service, investigate problems, and improve reliability.',
  ),
  _LegalSection(
    'Authentication and service providers',
    'BitClass uses Supabase for authentication and application data. Google authentication is available for eligible student accounts. Firebase services may process device tokens and notification delivery information. These providers process data under their own security and privacy terms.',
  ),
  _LegalSection(
    'Who can access information',
    'Students can access their own records and content made available to their classes. Instructors can access course activity and submissions needed to teach and assess enrolled students. Authorized administrators and service operators may access information when needed for support, security, compliance, or institutional operations.',
  ),
  _LegalSection(
    'Storage, security, and retention',
    'BitClass uses access controls and row-level database policies to restrict data access. No system can guarantee absolute security. Records are retained while needed for the learning service, institutional requirements, dispute resolution, security, or applicable law, then deleted or de-identified when appropriate.',
  ),
  _LegalSection(
    'Your choices and rights',
    'You can update profile details and notification preferences in the app. Requests to review, correct, export, or delete account information may be subject to institutional recordkeeping duties. Use the feedback form to submit a privacy question or request.',
  ),
  _LegalSection(
    'Policy updates',
    'This policy may change when features, providers, or legal requirements change. The effective date will be updated when a revised policy is made available in BitClass.',
  ),
];
