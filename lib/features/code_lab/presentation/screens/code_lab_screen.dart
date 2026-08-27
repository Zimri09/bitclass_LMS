import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../assignments/data/models/assignment_model.dart';
import '../../../assignments/presentation/widgets/code_editor.dart';
import '../../data/models/code_execution_language.dart';
import '../../data/models/code_execution_result.dart';
import '../../data/repositories/code_execution_repository.dart';

class CodeLabScreen extends StatefulWidget {
  const CodeLabScreen({super.key});

  @override
  State<CodeLabScreen> createState() => _CodeLabScreenState();
}

class _CodeLabScreenState extends State<CodeLabScreen> {
  final _stdinController = TextEditingController();
  final Map<CodeExecutionLanguage, String> _sources = {
    for (final language in CodeExecutionLanguage.values)
      language: language.starterCode,
  };
  CodeExecutionLanguage _language = CodeExecutionLanguage.python;
  CodeExecutionResult? _result;
  String? _error;
  String _submittedStdin = '';
  bool _isRunning = false;
  bool _showProgramInput = false;
  int _editorRevision = 0;

  String get _source => _sources[_language] ?? _language.starterCode;

  @override
  void dispose() {
    _stdinController.dispose();
    super.dispose();
  }

  Future<void> _runCode() async {
    if (_isRunning) return;
    final stdin = _stdinController.text;
    final sourceBytes = utf8.encode(_source).length;
    final stdinBytes = utf8.encode(stdin).length;
    if (_source.trim().isEmpty ||
        sourceBytes > CodeExecutionRepository.maxSourceBytes ||
        stdinBytes > CodeExecutionRepository.maxStdinBytes) {
      setState(() {
        _error = _source.trim().isEmpty
            ? 'Enter ${_language.displayName} code before running.'
            : sourceBytes > CodeExecutionRepository.maxSourceBytes
            ? '${_language.displayName} source must be 20 KB or less.'
            : 'Program input must be 8 KB or less.';
      });
      return;
    }

    setState(() {
      _isRunning = true;
      _result = null;
      _error = null;
      _submittedStdin = stdin;
    });
    try {
      final result = await context
          .read<CodeExecutionRepository>()
          .execute(language: _language, source: _source, stdin: stdin);
      if (!mounted) return;
      setState(() => _result = result);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  void _reset() {
    FocusScope.of(context).unfocus();
    setState(() {
      _sources[_language] = _language.starterCode;
      _stdinController.clear();
      _result = null;
      _error = null;
      _submittedStdin = '';
      _showProgramInput = false;
      _editorRevision++;
    });
  }

  void _selectLanguage(CodeExecutionLanguage language) {
    if (_isRunning || language == _language) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _language = language;
      _result = null;
      _error = null;
      _submittedStdin = '';
      _editorRevision++;
    });
  }

  void _removeProgramInput() {
    FocusScope.of(context).unfocus();
    setState(() {
      _stdinController.clear();
      _showProgramInput = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        leading: const AppDrawerButton(),
        title: const Text('Code Lab'),
        actions: [
          TextButton.icon(
            onPressed: _isRunning ? null : _reset,
            icon: const Icon(Icons.restart_alt, size: 18),
            label: const Text('Reset'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontal = constraints.maxWidth >= 980;
            return SingleChildScrollView(
              padding: EdgeInsets.all(constraints.maxWidth < 600 ? 16 : 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1240),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildIntro(colors),
                      const SizedBox(height: 20),
                      if (horizontal)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: _buildEditor(colors, 520)),
                            const SizedBox(width: 20),
                            Expanded(flex: 2, child: _buildConsolePane(colors)),
                          ],
                        )
                      else ...[
                        _buildEditor(colors, 380),
                        const SizedBox(height: 20),
                        _buildConsolePane(colors),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildIntro(AppColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.16),
            AppColors.secondary.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.terminal,
              color: AppColors.warning,
              size: 30,
            ),
          ),
          SizedBox(
            width: 520,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Python & C Sandbox', style: AppTextStyles.h3),
                const SizedBox(height: 5),
                Text(
                  'Write, compile, and run one isolated program at a time. Your Python and C drafts are kept separately while you switch.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          SegmentedButton<CodeExecutionLanguage>(
            key: const ValueKey('code-lab-language-selector'),
            segments: const [
              ButtonSegment(
                value: CodeExecutionLanguage.python,
                label: Text('Python'),
                icon: Icon(Icons.code),
              ),
              ButtonSegment(
                value: CodeExecutionLanguage.c,
                label: Text('C'),
                icon: Icon(Icons.memory),
              ),
            ],
            selected: {_language},
            onSelectionChanged: _isRunning
                ? null
                : (selection) => _selectLanguage(selection.first),
          ),
          const _SafetyPill(icon: Icons.wifi_off, label: 'No network'),
          const _SafetyPill(
            icon: Icons.timer_outlined,
            label: '5 second limit',
          ),
          const _SafetyPill(
            icon: Icons.delete_sweep_outlined,
            label: 'Ephemeral',
          ),
        ],
      ),
    );
  }

  Widget _buildEditor(AppColorScheme colors, double height) {
    final sourceBytes = utf8.encode(_source).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'main${_language.fileExtension}',
              key: const ValueKey('code-lab-filename'),
              style: AppTextStyles.h4,
            ),
            const Spacer(),
            Text(
              '$sourceBytes / ${CodeExecutionRepository.maxSourceBytes} bytes',
              style: AppTextStyles.caption.copyWith(
                color: sourceBytes > CodeExecutionRepository.maxSourceBytes
                    ? AppColors.error
                    : colors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        CodeEditor(
          key: ValueKey(
            'code-lab-editor-${_language.name}-$_editorRevision',
          ),
          initialCode: _source,
          language: _language == CodeExecutionLanguage.python
              ? ProgrammingLanguage.python
              : ProgrammingLanguage.cpp,
          syntax: _language == CodeExecutionLanguage.python
              ? CodeEditorSyntax.python
              : CodeEditorSyntax.c,
          languageLabel: _language.displayName,
          height: height,
          readOnly: _isRunning,
          onChanged: (value) => setState(() => _sources[_language] = value),
        ),
      ],
    );
  }

  Widget _buildConsolePane(AppColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildProgramInput(colors),
        const SizedBox(height: 14),
        FilledButton.icon(
          key: const ValueKey('code-lab-run'),
          onPressed: _isRunning ? null : _runCode,
          icon: _isRunning
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.play_arrow_rounded),
          label: Text(
            _isRunning ? 'Running safely...' : 'Run ${_language.displayName}',
          ),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15),
            backgroundColor: AppColors.secondary,
          ),
        ),
        const SizedBox(height: 20),
        _buildOutput(colors),
      ],
    );
  }

  Widget _buildProgramInput(AppColorScheme colors) {
    if (!_showProgramInput) {
      return OutlinedButton.icon(
        key: const ValueKey('code-lab-add-input'),
        onPressed: _isRunning
            ? null
            : () => setState(() => _showProgramInput = true),
        icon: const Icon(Icons.keyboard_alt_outlined),
        label: const Text('Add program input'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      );
    }

    final stdinBytes = utf8.encode(_stdinController.text).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Program inputs (optional)',
                style: AppTextStyles.h4,
              ),
            ),
            TextButton.icon(
              key: const ValueKey('code-lab-remove-input'),
              onPressed: _isRunning ? null : _removeProgramInput,
              icon: const Icon(Icons.close, size: 17),
              label: const Text('Remove'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _language == CodeExecutionLanguage.python
              ? 'Enter one answer per line. Each input() call reads the next line.'
              : 'Enter input exactly as the program expects. scanf() and fgets() read from these lines.',
          style: AppTextStyles.bodySmall.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: 10),
        TextField(
          key: const ValueKey('code-lab-stdin'),
          controller: _stdinController,
          enabled: !_isRunning,
          minLines: 3,
          maxLines: 6,
          style: AppTextStyles.codeSmall,
          decoration: const InputDecoration(
            hintText: 'Maria\n20\nManila',
            alignLabelWithHint: true,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Text(
          '$stdinBytes / ${CodeExecutionRepository.maxStdinBytes} bytes',
          textAlign: TextAlign.end,
          style: AppTextStyles.caption.copyWith(
            color: stdinBytes > CodeExecutionRepository.maxStdinBytes
                ? AppColors.error
                : colors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildOutput(AppColorScheme colors) {
    final result = _result;
    final hasError = _error != null || (result != null && !result.succeeded);
    final showSubmittedInput =
        _submittedStdin.isNotEmpty && (_error != null || result != null);
    final output =
        _error ??
        (result == null
            ? 'Output will appear here after you run the program.'
            : [
                if (result.stdout.isNotEmpty) result.stdout,
                if (result.stderr.isNotEmpty) result.stderr,
                if (result.stdout.isEmpty && result.stderr.isEmpty)
                  '[program finished without output]',
              ].join(
                result.stdout.isNotEmpty && result.stderr.isNotEmpty
                    ? '\n'
                    : '',
              ));
    final outputTitle = switch (result?.phase) {
      CodeExecutionPhase.compile => 'Compile error',
      CodeExecutionPhase.runtime when hasError => 'Runtime error',
      _ => 'Console',
    };

    return Container(
      constraints: const BoxConstraints(minHeight: 190),
      decoration: BoxDecoration(
        color: AppColors.codeBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasError
              ? AppColors.error.withValues(alpha: 0.55)
              : colors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.75),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(13),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  hasError ? Icons.error_outline : Icons.terminal,
                  size: 17,
                  color: hasError ? AppColors.error : AppColors.secondary,
                ),
                const SizedBox(width: 8),
                Text(outputTitle, style: AppTextStyles.label),
                const Spacer(),
                if (result != null)
                  Text(
                    '${result.durationMs} ms | exit ${result.exitCode}',
                    style: AppTextStyles.caption,
                  ),
              ],
            ),
          ),
          if (showSubmittedInput) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Input supplied',
                    style: AppTextStyles.caption.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 5),
                  SelectableText(
                    _submittedStdin
                        .split('\n')
                        .map((line) => '> $line')
                        .join('\n'),
                    key: const ValueKey('code-lab-input-echo'),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13,
                      height: 1.5,
                      color: const Color(0xFFFFD166),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colors.border),
          ],
          Padding(
            padding: const EdgeInsets.all(14),
            child: SelectableText(
              output,
              key: const ValueKey('code-lab-output'),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 13,
                height: 1.55,
                color: hasError
                    ? const Color(0xFFFF8A80)
                    : const Color(0xFFB7F7C5),
              ),
            ),
          ),
          if (result?.timedOut == true || result?.truncated == true)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Text(
                result!.timedOut
                    ? 'Execution stopped after the time limit.'
                    : 'Output was shortened to the safety limit.',
                style: AppTextStyles.caption.copyWith(color: AppColors.warning),
              ),
            ),
        ],
      ),
    );
  }
}

class _SafetyPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SafetyPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
