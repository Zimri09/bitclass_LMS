import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/utils/upload_file.dart';

String fileTypeLabel(String mime) {
  if (mime == 'application/pdf') return 'PDF';
  if (mime.contains('wordprocessingml')) return 'DOCX';
  if (mime == 'application/msword') return 'DOC';
  if (mime.contains('presentationml')) return 'PPTX';
  if (mime.contains('powerpoint')) return 'PPT';
  if (mime.contains('spreadsheetml')) return 'XLSX';
  if (mime.contains('excel')) return 'XLS';
  if (mime == 'text/plain') return 'TXT';
  if (mime == 'application/octet-stream' || mime.isEmpty) return 'File';
  return mime.split('/').last.toUpperCase();
}

String fileSizeLabel(int bytes) => bytes < 1024
    ? '$bytes B'
    : bytes < 1024 * 1024
    ? '${(bytes / 1024).toStringAsFixed(1)} KB'
    : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

IconData fileMimeIcon(String mime) {
  if (mime == 'application/pdf') return Icons.picture_as_pdf_outlined;
  if (mime.contains('word') || mime.contains('opendocument.text')) {
    return Icons.article_outlined;
  }
  if (mime.contains('presentation') || mime.contains('powerpoint')) {
    return Icons.slideshow_outlined;
  }
  if (mime.contains('spreadsheet') ||
      mime.contains('excel') ||
      mime == 'text/csv') {
    return Icons.table_chart_outlined;
  }
  if (mime.startsWith('image/')) return Icons.image_outlined;
  if (mime.startsWith('video/')) return Icons.videocam_outlined;
  if (mime.startsWith('audio/')) return Icons.audiotrack_outlined;
  if (mime.contains('zip') ||
      mime.contains('compressed') ||
      mime.contains('tar') ||
      mime.contains('rar')) {
    return Icons.folder_zip_outlined;
  }
  if (mime == 'text/plain' || mime == 'text/markdown') {
    return Icons.text_snippet_outlined;
  }
  if (mime.startsWith('text/') ||
      mime.contains('json') ||
      mime.contains('xml') ||
      mime.contains('javascript')) {
    return Icons.code;
  }
  return Icons.insert_drive_file_outlined;
}

/// Uses validated MIME metadata. Private images resolve through signed URLs;
/// thumbnails never require making a storage bucket public.
class UploadFilePreview extends StatefulWidget {
  final String mimeType;
  final Uint8List? bytes;
  final Future<String> Function()? loadUrl;
  final Future<Uint8List> Function()? loadBytes;
  final String? sourceKey;
  const UploadFilePreview({
    super.key,
    required this.mimeType,
    this.bytes,
    this.loadUrl,
    this.loadBytes,
    this.sourceKey,
  });
  @override
  State<UploadFilePreview> createState() => _UploadFilePreviewState();
}

class _UploadFilePreviewState extends State<UploadFilePreview> {
  Future<String>? _url;
  Future<Uint8List>? _data;
  bool get _isImage =>
      widget.mimeType.startsWith('image/') &&
      widget.mimeType != 'image/svg+xml';
  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(UploadFilePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sourceKey != widget.sourceKey ||
        oldWidget.mimeType != widget.mimeType) {
      _resolve();
    }
  }

  void _resolve() {
    _data = _isImage && widget.bytes == null ? widget.loadBytes?.call() : null;
    _url = _isImage && widget.bytes == null ? widget.loadUrl?.call() : null;
  }

  Widget _icon() => Icon(
    fileMimeIcon(widget.mimeType),
    color: Theme.of(context).colorScheme.primary,
  );
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: SizedBox(
      width: 48,
      height: 48,
      child: !_isImage
          ? _icon()
          : widget.bytes != null
          ? Image.memory(
              widget.bytes!,
              fit: BoxFit.cover,
              cacheWidth: 144,
              errorBuilder: (_, _, _) => _icon(),
            )
          : _data != null
          ? FutureBuilder<Uint8List>(
              future: _data,
              builder: (context, snapshot) => snapshot.hasData
                  ? Image.memory(
                      snapshot.data!,
                      fit: BoxFit.cover,
                      cacheWidth: 144,
                      errorBuilder: (_, _, _) => _icon(),
                    )
                  : _icon(),
            )
          : _url == null
          ? _icon()
          : FutureBuilder<String>(
              future: _url,
              builder: (context, snapshot) => snapshot.hasData
                  ? Image.network(
                      snapshot.data!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _icon(),
                    )
                  : _icon(),
            ),
    ),
  );
}

class PendingUploadTile extends StatelessWidget {
  final UploadFileData file;
  final VoidCallback? onRemove;
  const PendingUploadTile({super.key, required this.file, this.onRemove});
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      leading: UploadFilePreview(mimeType: file.mimeType, bytes: file.bytes),
      title: Text(file.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${fileTypeLabel(file.mimeType)} · ${fileSizeLabel(file.bytes.length)}',
      ),
      trailing: onRemove == null
          ? null
          : IconButton(
              tooltip: 'Remove ${file.name}',
              onPressed: onRemove,
              icon: const Icon(Icons.close),
            ),
    ),
  );
}

Future<List<UploadFileData>?> reviewUploadFiles(
  BuildContext context,
  List<UploadFileData> files,
) {
  final selected = List<UploadFileData>.of(files);
  return showDialog<List<UploadFileData>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Selected files'),
        content: SizedBox(
          width: 500,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .55,
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final file in selected)
                  PendingUploadTile(
                    file: file,
                    onRemove: () => setState(() => selected.remove(file)),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: selected.isEmpty
                ? null
                : () => Navigator.pop(context, selected),
            child: Text('Attach ${selected.length} files'),
          ),
        ],
      ),
    ),
  );
}
