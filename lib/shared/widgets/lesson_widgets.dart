import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';

/// Custom code block widget with syntax highlighting styling
class CodeBlockWidget extends StatefulWidget {
  final String code;
  final String? language;
  final bool showCopyButton;
  final bool showLanguageTag;

  const CodeBlockWidget({
    super.key,
    required this.code,
    this.language,
    this.showCopyButton = true,
    this.showLanguageTag = true,
  });

  @override
  State<CodeBlockWidget> createState() => _CodeBlockWidgetState();
}

class _CodeBlockWidgetState extends State<CodeBlockWidget> {
  bool _copied = false;

  void _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _copied = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with language tag and copy button
          if (widget.showLanguageTag || widget.showCopyButton)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(7),
                  topRight: Radius.circular(7),
                ),
              ),
              child: Row(
                children: [
                  if (widget.showLanguageTag && widget.language != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        widget.language!.toUpperCase(),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (widget.showCopyButton)
                    InkWell(
                      onTap: _copyToClipboard,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _copied ? Icons.check : Icons.content_copy,
                              size: 14,
                              color: _copied
                                  ? AppColors.success
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _copied ? 'Copied!' : 'Copy',
                              style: TextStyle(
                                fontSize: 12,
                                color: _copied
                                    ? AppColors.success
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          // Code content
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              widget.code,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 13,
                height: 1.5,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Markdown content renderer with BitClass styling
class MarkdownContent extends StatelessWidget {
  final String content;
  final bool selectable;
  final EdgeInsets? padding;

  const MarkdownContent({
    super.key,
    required this.content,
    this.selectable = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Markdown(
      data: content,
      selectable: selectable,
      padding: padding ?? const EdgeInsets.all(16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      styleSheet: _buildStyleSheet(context),
      builders: {'code': _CodeBlockBuilder()},
    );
  }

  MarkdownStyleSheet _buildStyleSheet(BuildContext context) {
    return MarkdownStyleSheet(
      // Headings
      h1: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
        height: 1.3,
      ),
      h2: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
        height: 1.3,
      ),
      h3: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.3,
      ),
      h4: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.3,
      ),
      h5: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.3,
      ),
      h6: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.3,
      ),
      // Paragraph
      p: GoogleFonts.inter(
        fontSize: 15,
        color: AppColors.textPrimary,
        height: 1.7,
      ),
      // Strong and emphasis
      strong: GoogleFonts.inter(
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
      em: GoogleFonts.inter(
        fontStyle: FontStyle.italic,
        color: AppColors.textPrimary,
      ),
      // Links
      a: GoogleFonts.inter(
        color: AppColors.primary,
        decoration: TextDecoration.underline,
        decorationColor: AppColors.primary.withValues(alpha: 0.5),
      ),
      // Inline code
      code: GoogleFonts.jetBrainsMono(
        fontSize: 13,
        color: AppColors.secondary,
        backgroundColor: AppColors.surfaceLight,
      ),
      // Code block
      codeblockDecoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      codeblockPadding: const EdgeInsets.all(16),
      // Blockquote
      blockquote: GoogleFonts.inter(
        fontSize: 15,
        color: AppColors.textSecondary,
        fontStyle: FontStyle.italic,
        height: 1.7,
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.primary, width: 4)),
        color: AppColors.surfaceLight,
      ),
      blockquotePadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      // Lists
      listBullet: GoogleFonts.inter(fontSize: 15, color: AppColors.primary),
      listIndent: 24,
      // Tables
      tableHead: GoogleFonts.inter(
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
      tableBody: GoogleFonts.inter(color: AppColors.textPrimary),
      tableBorder: TableBorder.all(color: AppColors.surfaceLight, width: 1),
      tableHeadAlign: TextAlign.left,
      tableCellsPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      // Horizontal rule
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.surfaceLight, width: 2),
        ),
      ),
    );
  }
}

/// Custom builder for code blocks with language support
class _CodeBlockBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(element, TextStyle? preferredStyle) {
    String? language;
    final className = element.attributes['class'];
    if (className != null && className.startsWith('language-')) {
      language = className.substring(9);
    }

    return CodeBlockWidget(
      code: element.textContent.trim(),
      language: language,
    );
  }
}

/// Lesson navigation bar for prev/next navigation
class LessonNavigationBar extends StatelessWidget {
  final String? previousLessonTitle;
  final String? nextLessonTitle;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onMarkComplete;
  final bool isCompleted;
  final bool isLoading;

  const LessonNavigationBar({
    super.key,
    this.previousLessonTitle,
    this.nextLessonTitle,
    this.onPrevious,
    this.onNext,
    this.onMarkComplete,
    this.isCompleted = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.surfaceLight, width: 1),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 400;

          if (isNarrow) {
            // Stack layout for narrow screens
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Mark complete centered
                if (onMarkComplete != null)
                  FilledButton.icon(
                    onPressed: isLoading ? null : onMarkComplete,
                    icon: isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            isCompleted
                                ? Icons.check_circle
                                : Icons.check_circle_outline,
                            size: 18,
                          ),
                    label: Text(isCompleted ? 'Completed' : 'Mark Complete'),
                    style: FilledButton.styleFrom(
                      backgroundColor: isCompleted
                          ? AppColors.success
                          : AppColors.primary,
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (onPrevious != null)
                      TextButton.icon(
                        onPressed: onPrevious,
                        icon: const Icon(Icons.arrow_back, size: 18),
                        label: const Text('Previous'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    if (onNext != null)
                      TextButton.icon(
                        onPressed: onNext,
                        icon: const Text('Next'),
                        label: const Icon(Icons.arrow_forward, size: 18),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              // Previous button
              if (onPrevious != null)
                TextButton.icon(
                  onPressed: onPrevious,
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Previous'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                )
              else
                const SizedBox(width: 100),

              const Spacer(),

              // Mark complete button
              if (onMarkComplete != null)
                FilledButton.icon(
                  onPressed: isLoading ? null : onMarkComplete,
                  icon: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          isCompleted
                              ? Icons.check_circle
                              : Icons.check_circle_outline,
                          size: 18,
                        ),
                  label: Text(isCompleted ? 'Completed' : 'Mark Complete'),
                  style: FilledButton.styleFrom(
                    backgroundColor: isCompleted
                        ? AppColors.success
                        : AppColors.primary,
                  ),
                ),

              const Spacer(),

              // Next button
              if (onNext != null)
                TextButton.icon(
                  onPressed: onNext,
                  icon: const Text('Next'),
                  label: const Icon(Icons.arrow_forward, size: 18),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                )
              else
                const SizedBox(width: 100),
            ],
          );
        },
      ),
    );
  }
}

/// Module expansion tile for course syllabus
class ModuleTile extends StatelessWidget {
  final String title;
  final String? description;
  final int lessonCount;
  final int completedCount;
  final bool isExpanded;
  final VoidCallback? onExpand;
  final List<Widget> lessons;

  const ModuleTile({
    super.key,
    required this.title,
    this.description,
    required this.lessonCount,
    required this.completedCount,
    required this.isExpanded,
    this.onExpand,
    required this.lessons,
  });

  @override
  Widget build(BuildContext context) {
    final progress = lessonCount > 0 ? completedCount / lessonCount : 0.0;

    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          InkWell(
            onTap: onExpand,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Progress indicator
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: progress,
                          backgroundColor: AppColors.surfaceLight,
                          valueColor: AlwaysStoppedAnimation(
                            progress == 1.0
                                ? AppColors.success
                                : AppColors.primary,
                          ),
                          strokeWidth: 3,
                        ),
                        if (progress == 1.0)
                          Icon(Icons.check, color: AppColors.success, size: 20),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Title and description
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (description != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            description!,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          '$completedCount/$lessonCount lessons completed',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Expand icon
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          // Lessons list
          if (isExpanded)
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.surfaceLight, width: 1),
                ),
              ),
              child: Column(children: lessons),
            ),
        ],
      ),
    );
  }
}

/// Lesson list item tile
class LessonTile extends StatelessWidget {
  final String title;
  final String? description;
  final int durationMinutes;
  final IconData typeIcon;
  final bool isCompleted;
  final bool isLocked;
  final VoidCallback? onTap;

  const LessonTile({
    super.key,
    required this.title,
    this.description,
    required this.durationMinutes,
    required this.typeIcon,
    this.isCompleted = false,
    this.isLocked = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLocked ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.surfaceLight, width: 1),
          ),
        ),
        child: Row(
          children: [
            // Status indicator
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted
                    ? AppColors.success.withValues(alpha: 0.2)
                    : isLocked
                    ? AppColors.surfaceLight
                    : AppColors.primary.withValues(alpha: 0.2),
              ),
              child: Icon(
                isCompleted
                    ? Icons.check
                    : isLocked
                    ? Icons.lock
                    : typeIcon,
                size: 16,
                color: isCompleted
                    ? AppColors.success
                    : isLocked
                    ? AppColors.textSecondary
                    : AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            // Title and duration
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isLocked
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$durationMinutes min',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // Arrow
            if (!isLocked)
              Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
