import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../shared/widgets/upload_file_preview.dart';
import '../../data/repositories/assignment_repository.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/assignment_attachment.dart';

class AssignmentAttachmentTile extends StatelessWidget {
  final AssignmentAttachment attachment;
  final VoidCallback? onOpen;
  final VoidCallback? onRemove;
  final bool isBusy;
  final Uint8List? previewBytes;

  const AssignmentAttachmentTile({
    super.key,
    required this.attachment,
    this.onOpen,
    this.onRemove,
    this.isBusy = false,
    this.previewBytes,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = attachment.isLink
        ? _linkHost(attachment.url)
        : '${fileTypeLabel(attachment.mimeType ?? '')} · ${attachment.formattedSize}';

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
                child: attachment.isLink
                    ? const Icon(Icons.link_rounded)
                    : UploadFilePreview(
                        mimeType: attachment.mimeType ?? '',
                        bytes: previewBytes,
                        sourceKey: attachment.storagePath,
                        loadUrl: attachment.isStoredFile
                            ? () => context
                                  .read<AssignmentRepository>()
                                  .getAttachmentUrl(attachment)
                            : null,
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
