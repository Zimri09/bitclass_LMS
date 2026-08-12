import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/assignment_attachment.dart';

class AssignmentAttachmentTile extends StatelessWidget {
  final AssignmentAttachment attachment;
  final VoidCallback? onOpen;
  final VoidCallback? onRemove;
  final bool isBusy;

  const AssignmentAttachmentTile({
    super.key,
    required this.attachment,
    this.onOpen,
    this.onRemove,
    this.isBusy = false,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = attachment.isLink
        ? _linkHost(attachment.url)
        : attachment.formattedSize;

    return Material(
      color: AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: isBusy ? null : onOpen,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  attachment.isLink
                      ? Icons.link_rounded
                      : Icons.insert_drive_file_outlined,
                  color: AppColors.primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attachment.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isBusy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (onRemove != null)
                IconButton(
                  tooltip: 'Remove',
                  onPressed: onRemove,
                  icon: const Icon(Icons.close, size: 20),
                )
              else if (onOpen != null)
                const Icon(Icons.open_in_new, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  String _linkHost(String? value) {
    final uri = Uri.tryParse(value ?? '');
    return uri?.host.isNotEmpty == true ? uri!.host : 'Web link';
  }
}
