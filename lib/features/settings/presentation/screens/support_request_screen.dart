import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/models/support_request.dart';
import '../../data/repositories/support_repository.dart';

class SupportRequestScreen extends StatefulWidget {
  final SupportRequestType type;

  const SupportRequestScreen({super.key, required this.type});

  @override
  State<SupportRequestScreen> createState() => _SupportRequestScreenState();
}

class _SupportRequestScreenState extends State<SupportRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _stepsController = TextEditingController();
  final _expectedController = TextEditingController();

  late String _category;
  bool _isSubmitting = false;

  bool get _isBug => widget.type == SupportRequestType.bug;

  List<String> get _categories => _isBug
      ? const ['Low', 'Medium', 'High', 'Critical']
      : const [
          'General',
          'Learning experience',
          'Feature request',
          'Accessibility',
        ];

  @override
  void initState() {
    super.initState();
    _category = _isBug ? 'Medium' : 'General';
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    _stepsController.dispose();
    _expectedController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated || authState.isOffline) {
      _showMessage('Connect to the internet and sign in before submitting.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await context.read<SupportRepository>().submitRequest(
        userId: authState.user.id,
        type: widget.type,
        category: _category,
        subject: _subjectController.text,
        description: _descriptionController.text,
        metadata: {
          'app_version': AppConstants.appVersion,
          'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
          'role': authState.user.role,
          if (_isBug) 'steps_to_reproduce': _stepsController.text.trim(),
          if (_isBug) 'expected_result': _expectedController.text.trim(),
        },
      );
      if (!mounted) return;

      _subjectController.clear();
      _descriptionController.clear();
      _stepsController.clear();
      _expectedController.clear();
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.check_circle_outline),
          title: Text(_isBug ? 'Bug report submitted' : 'Feedback submitted'),
          content: Text(
            _isBug
                ? 'Your report has been recorded for review.'
                : 'Thank you. Your feedback has been recorded for review.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        _showMessage('Could not submit your request. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String? _validateRequired(
    String? value, {
    required String label,
    required int minimum,
  }) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) return '$label is required.';
    if (normalized.length < minimum) {
      return '$label must be at least $minimum characters.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(
          _isBug ? 'Report a Bug' : 'Send Feedback',
          style: AppTextStyles.h3,
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  _isBug
                      ? 'Tell us what went wrong'
                      : 'Share your experience',
                  style: AppTextStyles.h2.copyWith(color: colors.onSurface),
                ),
                const SizedBox(height: 8),
                Text(
                  _isBug
                      ? 'Include enough detail to help reproduce the problem.'
                      : 'Your feedback helps improve BitClass for students and instructors.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: InputDecoration(
                    labelText: _isBug ? 'Severity' : 'Category',
                    prefixIcon: Icon(
                      _isBug
                          ? Icons.priority_high
                          : Icons.category_outlined,
                    ),
                  ),
                  items: _categories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ),
                      )
                      .toList(),
                  onChanged: _isSubmitting
                      ? null
                      : (value) {
                          if (value != null) setState(() => _category = value);
                        },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _subjectController,
                  enabled: !_isSubmitting,
                  maxLength: 160,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: _isBug ? 'Issue summary' : 'Subject',
                    prefixIcon: const Icon(Icons.subject),
                  ),
                  validator: (value) => _validateRequired(
                    value,
                    label: _isBug ? 'Issue summary' : 'Subject',
                    minimum: 3,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descriptionController,
                  enabled: !_isSubmitting,
                  minLines: 5,
                  maxLines: 9,
                  maxLength: 5000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: _isBug ? 'What happened?' : 'Your feedback',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) => _validateRequired(
                    value,
                    label: _isBug ? 'Problem description' : 'Feedback',
                    minimum: 10,
                  ),
                ),
                if (_isBug) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _stepsController,
                    enabled: !_isSubmitting,
                    minLines: 4,
                    maxLines: 7,
                    maxLength: 2000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Steps to reproduce',
                      alignLabelWithHint: true,
                    ),
                    validator: (value) => _validateRequired(
                      value,
                      label: 'Steps to reproduce',
                      minimum: 10,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _expectedController,
                    enabled: !_isSubmitting,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 1000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Expected result',
                      alignLabelWithHint: true,
                    ),
                    validator: (value) => _validateRequired(
                      value,
                      label: 'Expected result',
                      minimum: 5,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(_isSubmitting ? 'Submitting...' : 'Submit'),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
