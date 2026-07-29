import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/reaction_type.dart';

class ReactionControl extends StatelessWidget {
  final Map<String, int> reactionCounts;
  final int totalCount;
  final ReactionType? selectedReaction;
  final ValueChanged<ReactionType>? onReactionSelected;
  final bool compact;

  const ReactionControl({
    super.key,
    required this.reactionCounts,
    required this.totalCount,
    required this.selectedReaction,
    required this.onReactionSelected,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedReaction != null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Builder(
          builder: (buttonContext) => Semantics(
            button: true,
            label: 'Reaction. Hold to choose a reaction.',
            child: InkWell(
              onTap: onReactionSelected == null
                  ? null
                  : () => onReactionSelected!(
                      selectedReaction ?? ReactionType.like,
                    ),
              onLongPress: onReactionSelected == null
                  ? null
                  : () => _showReactionPicker(buttonContext),
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 6 : 8,
                  vertical: 5,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected)
                      Text(
                        selectedReaction!.emoji,
                        style: TextStyle(fontSize: compact ? 16 : 18),
                      )
                    else
                      Icon(
                        Icons.add_reaction_outlined,
                        size: compact ? 16 : 18,
                        color: AppColors.textSecondary,
                      ),
                    const SizedBox(width: 5),
                    Text(
                      selectedReaction?.label ?? 'React',
                      style: TextStyle(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        fontSize: compact ? 12 : 13,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (totalCount > 0) ...[
          const SizedBox(width: 4),
          InkWell(
            onTap: () => _showReactionBreakdown(context),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _leadingEmojis(),
                    style: TextStyle(fontSize: compact ? 12 : 14),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$totalCount',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: compact ? 11 : 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _leadingEmojis() {
    return ReactionType.values
        .where((reaction) => (reactionCounts[reaction.value] ?? 0) > 0)
        .take(3)
        .map((reaction) => reaction.emoji)
        .join();
  }

  Future<void> _showReactionPicker(BuildContext context) async {
    final button = context.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final buttonRect = Rect.fromPoints(
      button.localToGlobal(Offset.zero, ancestor: overlay),
      button.localToGlobal(
        button.size.bottomRight(Offset.zero),
        ancestor: overlay,
      ),
    );
    final selected = await showMenu<ReactionType>(
      context: context,
      color: AppColors.surface,
      elevation: 8,
      position: RelativeRect.fromRect(buttonRect, Offset.zero & overlay.size),
      items: [
        PopupMenuItem<ReactionType>(
          enabled: false,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Builder(
            builder: (menuContext) => Row(
              mainAxisSize: MainAxisSize.min,
              children: ReactionType.values.map((reaction) {
                final active = selectedReaction == reaction;
                return Semantics(
                  button: true,
                  selected: active,
                  label: reaction.label,
                  child: InkWell(
                    onTap: () => Navigator.of(menuContext).pop(reaction),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 50,
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.primary.withValues(alpha: 0.14)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            reaction.emoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            reaction.label,
                            style: TextStyle(
                              color: active
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              fontSize: 9,
                              fontWeight: active
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );

    if (selected != null) onReactionSelected?.call(selected);
  }

  Future<void> _showReactionBreakdown(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$totalCount ${totalCount == 1 ? 'reaction' : 'reactions'}',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              for (final reaction in ReactionType.values)
                if ((reactionCounts[reaction.value] ?? 0) > 0)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Text(
                      reaction.emoji,
                      style: TextStyle(fontSize: 26),
                    ),
                    title: Text(
                      reaction.label,
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                    trailing: Text(
                      '${reactionCounts[reaction.value]}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
