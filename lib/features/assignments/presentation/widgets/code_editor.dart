import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/models.dart';

enum CodeEditorSyntax { automatic, python, c }

class _SyntaxHighlightingController extends TextEditingController {
  CodeEditorSyntax syntax;

  _SyntaxHighlightingController({required String text, required this.syntax})
    : super(text: text);

  static final RegExp _pythonTokens = RegExp(
    r'(#[^\n]*)'
    r'''|("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')'''
    r'|(\b(?:and|as|assert|async|await|break|class|continue|def|del|elif|else|except|False|finally|for|from|global|if|import|in|is|lambda|None|nonlocal|not|or|pass|raise|return|True|try|while|with|yield)\b)'
    r'|(\b(?:0[xX][0-9a-fA-F]+|\d+(?:\.\d+)?)\b)',
    multiLine: true,
  );

  static final RegExp _cTokens = RegExp(
    r'(/\*[\s\S]*?\*/|//[^\n]*)'
    r'''|("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')'''
    r'|(^\s*#[^\n]*)'
    r'|(\b(?:auto|break|case|char|const|continue|default|do|double|else|enum|extern|float|for|goto|if|inline|int|long|register|restrict|return|short|signed|sizeof|static|struct|switch|typedef|union|unsigned|void|volatile|while|_Bool|_Complex|_Imaginary)\b)'
    r'|(\b(?:0[xX][0-9a-fA-F]+|\d+(?:\.\d+)?[fFlLuU]*)\b)',
    multiLine: true,
  );

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (withComposing &&
        value.composing.isValid &&
        !value.composing.isCollapsed) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    final pattern = switch (syntax) {
      CodeEditorSyntax.python => _pythonTokens,
      CodeEditorSyntax.c => _cTokens,
      CodeEditorSyntax.automatic => null,
    };
    final baseStyle = style ?? const TextStyle();
    if (pattern == null || text.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      final color = match.group(1) != null
          ? const Color(0xFF6A9955)
          : match.group(2) != null
          ? const Color(0xFFCE9178)
          : match.group(3) != null
          ? const Color(0xFFDCDCAA)
          : match.group(4) != null
          ? const Color(0xFFC586C0)
          : const Color(0xFFB5CEA8);
      spans.add(
        TextSpan(
          text: match.group(0),
          style: TextStyle(color: color, fontWeight: FontWeight.w500),
        ),
      );
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return TextSpan(style: baseStyle, children: spans);
  }
}

/// A snapshot of the editor state at a point in time.
class _EditorSnapshot {
  final String text;
  final TextSelection selection;

  const _EditorSnapshot({required this.text, required this.selection});
}

/// Manages undo/redo history with debounced snapshot capture.
class _UndoRedoManager {
  final List<_EditorSnapshot> _history = [];
  int _currentIndex = -1;
  static const int _maxHistory = 50;

  bool get canUndo => _currentIndex > 0;
  bool get canRedo => _currentIndex < _history.length - 1;

  /// Push the initial state. Call once at init.
  void init(String text) {
    _history.clear();
    _currentIndex = -1;
    push(text, const TextSelection.collapsed(offset: 0));
  }

  /// Record a new snapshot, discarding any redo history.
  void push(String text, TextSelection selection) {
    // Don't push duplicate of current state
    if (_currentIndex >= 0 && _history[_currentIndex].text == text) return;

    // Discard redo history
    if (_currentIndex < _history.length - 1) {
      _history.removeRange(_currentIndex + 1, _history.length);
    }

    _history.add(_EditorSnapshot(text: text, selection: selection));
    _currentIndex = _history.length - 1;

    // Cap history size
    if (_history.length > _maxHistory) {
      _history.removeAt(0);
      _currentIndex--;
    }
  }

  /// Return the previous snapshot, or null if at the beginning.
  _EditorSnapshot? undo() {
    if (!canUndo) return null;
    _currentIndex--;
    return _history[_currentIndex];
  }

  /// Return the next snapshot, or null if at the end.
  _EditorSnapshot? redo() {
    if (!canRedo) return null;
    _currentIndex++;
    return _history[_currentIndex];
  }
}

/// A simple code editor widget with syntax highlighting placeholder
class CodeEditor extends StatefulWidget {
  final String initialCode;
  final ProgrammingLanguage language;
  final bool readOnly;
  final ValueChanged<String>? onChanged;
  final double? height;
  final CodeEditorSyntax syntax;
  final String? languageLabel;

  const CodeEditor({
    super.key,
    this.initialCode = '',
    this.language = ProgrammingLanguage.dart,
    this.readOnly = false,
    this.onChanged,
    this.height,
    this.syntax = CodeEditorSyntax.automatic,
    this.languageLabel,
  });

  @override
  State<CodeEditor> createState() => _CodeEditorState();
}

class _CodeEditorState extends State<CodeEditor> {
  late _SyntaxHighlightingController _controller;
  late ScrollController _scrollController;
  late FocusNode _focusNode;
  int _lineCount = 1;

  final _UndoRedoManager _undoRedoManager = _UndoRedoManager();
  Timer? _debounceTimer;
  bool _isRestoringSnapshot = false;
  static const _debounceDuration = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _controller = _SyntaxHighlightingController(
      text: widget.initialCode,
      syntax: _effectiveSyntax,
    );
    _scrollController = ScrollController();
    _focusNode = FocusNode();
    _undoRedoManager.init(widget.initialCode);
    _updateLineCount();
    _controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(CodeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.syntax = _effectiveSyntax;
    if (widget.initialCode != oldWidget.initialCode &&
        widget.initialCode != _controller.text) {
      _controller.text = widget.initialCode;
      _updateLineCount();
    }
  }

  CodeEditorSyntax get _effectiveSyntax {
    if (widget.syntax != CodeEditorSyntax.automatic) return widget.syntax;
    return switch (widget.language) {
      ProgrammingLanguage.python => CodeEditorSyntax.python,
      ProgrammingLanguage.cpp => CodeEditorSyntax.c,
      _ => CodeEditorSyntax.automatic,
    };
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    _updateLineCount();
    widget.onChanged?.call(_controller.text);

    if (_isRestoringSnapshot) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      _undoRedoManager.push(_controller.text, _controller.selection);
      setState(() {}); // Rebuild to update undo/redo button states
    });
  }

  void _performUndo() {
    final snapshot = _undoRedoManager.undo();
    if (snapshot == null) return;
    _restoreSnapshot(snapshot);
  }

  void _performRedo() {
    final snapshot = _undoRedoManager.redo();
    if (snapshot == null) return;
    _restoreSnapshot(snapshot);
  }

  void _restoreSnapshot(_EditorSnapshot snapshot) {
    _isRestoringSnapshot = true;
    _controller.text = snapshot.text;
    // Clamp selection to valid range
    final maxOffset = snapshot.text.length;
    _controller.selection = TextSelection(
      baseOffset: snapshot.selection.baseOffset.clamp(0, maxOffset),
      extentOffset: snapshot.selection.extentOffset.clamp(0, maxOffset),
    );
    _isRestoringSnapshot = false;
    _updateLineCount();
    widget.onChanged?.call(_controller.text);
    setState(() {});
  }

  void _updateLineCount() {
    final newLineCount = '\n'.allMatches(_controller.text).length + 1;
    if (newLineCount != _lineCount) {
      setState(() {
        _lineCount = newLineCount;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = _getLanguageAccentColor(widget.language);
    final codeTextColor = _getLanguageTextColor(widget.language);

    return Shortcuts(
      shortcuts: !widget.readOnly
          ? <ShortcutActivator, Intent>{
              const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
                  const _UndoIntent(),
              const SingleActivator(
                LogicalKeyboardKey.keyZ,
                control: true,
                shift: true,
              ): const _RedoIntent(),
              const SingleActivator(LogicalKeyboardKey.keyY, control: true):
                  const _RedoIntent(),
            }
          : <ShortcutActivator, Intent>{},
      child: Actions(
        actions: <Type, Action<Intent>>{
          _UndoIntent: CallbackAction<_UndoIntent>(
            onInvoke: (_) {
              _performUndo();
              return null;
            },
          ),
          _RedoIntent: CallbackAction<_RedoIntent>(
            onInvoke: (_) {
              _performRedo();
              return null;
            },
          ),
        },
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: AppColors.codeBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accentColor.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Toolbar
              _buildToolbar(accentColor),
              // Editor
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Line numbers
                    _buildLineNumbers(),
                    // Code input
                    Expanded(
                      child: _buildCodeInput(
                        accentColor: accentColor,
                        codeTextColor: codeTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar(Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getLanguageIcon(widget.language),
                  size: 14,
                  color: accentColor,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.languageLabel ?? widget.language.displayName,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          if (!widget.readOnly) ...[
            _buildToolbarAction(
              icon: Icons.undo,
              tooltip: 'Undo (Ctrl+Z)',
              onPressed: _undoRedoManager.canUndo ? _performUndo : null,
              enabled: _undoRedoManager.canUndo,
            ),
            _buildToolbarAction(
              icon: Icons.redo,
              tooltip: 'Redo (Ctrl+Shift+Z)',
              onPressed: _undoRedoManager.canRedo ? _performRedo : null,
              enabled: _undoRedoManager.canRedo,
            ),
            const SizedBox(width: 8),
          ],
          _buildToolbarAction(
            icon: Icons.copy,
            tooltip: 'Copy all',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _controller.text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Code copied to clipboard'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          if (!widget.readOnly)
            _buildToolbarAction(
              icon: Icons.clear_all,
              tooltip: 'Clear',
              onPressed: () {
                _controller.clear();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildToolbarAction({
    required IconData icon,
    required String tooltip,
    VoidCallback? onPressed,
    bool enabled = true,
  }) {
    final color = enabled ? AppColors.textSecondary : AppColors.textMuted;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }

  Widget _buildLineNumbers() {
    return Container(
      width: 50,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(
          _lineCount,
          (index) => Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(
              '${index + 1}',
              style: GoogleFonts.firaCode(
                fontSize: 13,
                height: 1.5,
                color: AppColors.codeLineNumber,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCodeInput({
    required Color accentColor,
    required Color codeTextColor,
  }) {
    return SingleChildScrollView(
      controller: _scrollController,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        readOnly: widget.readOnly,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        style: GoogleFonts.firaCode(
          fontSize: 13,
          height: 1.5,
          color: codeTextColor,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: AppColors.codeBackground,
          contentPadding: const EdgeInsets.all(12),
          border: InputBorder.none,
          hintText: widget.readOnly ? null : 'Start coding here...',
          hintStyle: GoogleFonts.firaCode(
            fontSize: 13,
            color: AppColors.textMuted,
          ),
        ),
        cursorColor: accentColor,
      ),
    );
  }

  Color _getLanguageAccentColor(ProgrammingLanguage language) {
    if (_effectiveSyntax == CodeEditorSyntax.c) return AppColors.info;
    switch (language) {
      case ProgrammingLanguage.dart:
        return AppColors.primary;
      case ProgrammingLanguage.python:
        return AppColors.warning;
      case ProgrammingLanguage.javascript:
        return AppColors.secondary;
      case ProgrammingLanguage.typescript:
        return AppColors.info;
      case ProgrammingLanguage.html:
        return AppColors.error;
      case ProgrammingLanguage.css:
        return AppColors.primaryDark;
      case ProgrammingLanguage.sql:
        return AppColors.success;
      default:
        return AppColors.primary;
    }
  }

  Color _getLanguageTextColor(ProgrammingLanguage language) {
    if (_effectiveSyntax == CodeEditorSyntax.python ||
        _effectiveSyntax == CodeEditorSyntax.c) {
      return const Color(0xFFD4D4D4);
    }
    switch (language) {
      case ProgrammingLanguage.python:
        return AppColors.warning;
      case ProgrammingLanguage.javascript:
        return AppColors.secondary;
      case ProgrammingLanguage.typescript:
        return AppColors.info;
      case ProgrammingLanguage.html:
        return AppColors.error;
      case ProgrammingLanguage.css:
        return AppColors.primary;
      case ProgrammingLanguage.sql:
        return AppColors.success;
      case ProgrammingLanguage.dart:
      default:
        return AppColors.textPrimary;
    }
  }

  IconData _getLanguageIcon(ProgrammingLanguage language) {
    if (_effectiveSyntax == CodeEditorSyntax.c) return Icons.memory;
    switch (language) {
      case ProgrammingLanguage.dart:
        return Icons.flutter_dash;
      case ProgrammingLanguage.python:
        return Icons.code;
      case ProgrammingLanguage.javascript:
      case ProgrammingLanguage.typescript:
        return Icons.javascript;
      case ProgrammingLanguage.html:
        return Icons.html;
      case ProgrammingLanguage.css:
        return Icons.css;
      case ProgrammingLanguage.sql:
        return Icons.storage;
      default:
        return Icons.code;
    }
  }
}

/// Intent classes for keyboard shortcut bindings.
class _UndoIntent extends Intent {
  const _UndoIntent();
}

class _RedoIntent extends Intent {
  const _RedoIntent();
}

/// A read-only code viewer for displaying submitted code
class CodeViewer extends StatelessWidget {
  final String code;
  final ProgrammingLanguage language;
  final double? height;

  const CodeViewer({
    super.key,
    required this.code,
    this.language = ProgrammingLanguage.dart,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return CodeEditor(
      initialCode: code,
      language: language,
      readOnly: true,
      height: height,
    );
  }
}
