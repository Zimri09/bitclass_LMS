import 'dart:io' as io show File;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/models.dart';
import '../../data/repositories/file_repository.dart';
import '../bloc/bloc.dart';

/// Screen for uploading files to a course
class UploadFileScreen extends StatefulWidget {
  final String courseId;
  final String? lessonId;

  const UploadFileScreen({super.key, required this.courseId, this.lessonId});

  @override
  State<UploadFileScreen> createState() => _UploadFileScreenState();
}

class _UploadFileScreenState extends State<UploadFileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fileNameController = TextEditingController();
  final _descriptionController = TextEditingController();

  fp.PlatformFile? _pickedFile;
  Uint8List? _pickedBytes;

  bool _isPickingFile = false;
  bool _isUploading = false;

  @override
  void dispose() {
    _fileNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // ── File picking ─────────────────────────────────────────────────────────

  Future<void> _pickFile() async {
    if (_isPickingFile || _isUploading) return;
    setState(() => _isPickingFile = true);

    try {
      final result = await fp.FilePicker.platform.pickFiles(
        type: fp.FileType.any,
        withData: true, // loads bytes on web & mobile; optional on desktop
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      Uint8List? bytes = file.bytes;

      // On desktop (non-web), file_picker may not populate `bytes` even with
      // withData:true. Fall back to reading from the path via dart:io.
      if (bytes == null && !kIsWeb && file.path != null) {
        try {
          bytes = await io.File(file.path!).readAsBytes();
        } catch (_) {}
      }

      if (bytes == null) {
        _showError('Could not read the selected file. Please try again.');
        return;
      }

      setState(() {
        _pickedFile = file;
        _pickedBytes = bytes;
        _fileNameController.text = _stripExtension(file.name);
      });
    } catch (e) {
      _showError('Failed to pick file: $e');
    } finally {
      if (mounted) setState(() => _isPickingFile = false);
    }
  }

  String _stripExtension(String name) {
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  String get _ext => (_pickedFile?.extension ?? '').toLowerCase();

  String get _fullFileName {
    final base = _fileNameController.text.trim();
    return _ext.isNotEmpty ? '$base.$_ext' : base;
  }

  String get _mimeType {
    const mimes = <String, String>{
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'ppt': 'application/vnd.ms-powerpoint',
      'pptx':
          'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'xls': 'application/vnd.ms-excel',
      'xlsx':
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'mp4': 'video/mp4',
      'avi': 'video/x-msvideo',
      'mov': 'video/quicktime',
      'mkv': 'video/x-matroska',
      'webm': 'video/webm',
      'mp3': 'audio/mpeg',
      'wav': 'audio/wav',
      'ogg': 'audio/ogg',
      'aac': 'audio/aac',
      'png': 'image/png',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'svg': 'image/svg+xml',
      'bmp': 'image/bmp',
      'zip': 'application/zip',
      'rar': 'application/x-rar-compressed',
      '7z': 'application/x-7z-compressed',
      'tar': 'application/x-tar',
      'gz': 'application/gzip',
      'dart': 'text/x-dart',
      'py': 'text/x-python',
      'js': 'application/javascript',
      'ts': 'text/typescript',
      'html': 'text/html',
      'css': 'text/css',
      'json': 'application/json',
      'xml': 'application/xml',
      'yaml': 'application/yaml',
      'yml': 'application/yaml',
      'md': 'text/markdown',
      'txt': 'text/plain',
      'csv': 'text/csv',
    };
    return mimes[_ext] ?? 'application/octet-stream';
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  // ── Upload ───────────────────────────────────────────────────────────────

  void _uploadFile(BuildContext blocContext) {
    if (_pickedFile == null || _pickedBytes == null) {
      _showError('Please select a file first.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final user = Supabase.instance.client.auth.currentUser;
    final uploaderId = user?.id ?? 'anonymous';
    final uploaderName =
        user?.userMetadata?['full_name'] as String? ??
        user?.email ??
        'Unknown User';

    blocContext.read<FileBloc>().add(
      UploadFile(
        courseId: widget.courseId,
        lessonId: widget.lessonId,
        fileName: _fullFileName,
        mimeType: _mimeType,
        fileSize: _pickedBytes!.length,
        description: _descriptionController.text.trim(),
        uploaderId: uploaderId,
        uploaderName: uploaderName,
        fileData: _pickedBytes,
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          FileBloc(fileRepository: context.read<FileRepository>()),
      child: BlocConsumer<FileBloc, FileState>(
        listener: (context, state) {
          if (state is FileUploading) {
            setState(() => _isUploading = true);
            if (state.progress.status == UploadStatus.completed) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('File uploaded successfully!'),
                  backgroundColor: AppColors.success,
                ),
              );
              context.pop();
            } else if (state.progress.status == UploadStatus.failed) {
              setState(() => _isUploading = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.progress.errorMessage ?? 'Upload failed'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          } else if (state is FileError) {
            setState(() => _isUploading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(title: const Text('Upload File')),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDropZone(),
                    const SizedBox(height: 24),

                    _buildInputSection(
                      label: 'File Name',
                      child: TextFormField(
                        controller: _fileNameController,
                        enabled: _pickedFile != null && !_isUploading,
                        decoration: InputDecoration(
                          hintText:
                              _pickedFile == null
                                  ? 'Select a file first'
                                  : 'Enter display name',
                          hintStyle: TextStyle(color: AppColors.textMuted),
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          suffixText:
                              _ext.isNotEmpty ? '.$_ext' : null,
                          suffixStyle:
                              TextStyle(color: AppColors.textSecondary),
                        ),
                        style: TextStyle(color: AppColors.textPrimary),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Please enter a file name'
                                : null,
                      ),
                    ),
                    const SizedBox(height: 20),

                    _buildInputSection(
                      label: 'Description (optional)',
                      child: TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        enabled: !_isUploading,
                        decoration: InputDecoration(
                          hintText: 'Describe what this file contains...',
                          hintStyle: TextStyle(color: AppColors.textMuted),
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        style: TextStyle(color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(height: 32),

                    if (state is FileUploading) ...[
                      _buildUploadProgress(state.progress),
                      const SizedBox(height: 24),
                    ],

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed:
                            (_isUploading || _pickedFile == null)
                                ? null
                                : () => _uploadFile(context),
                        icon:
                            _isUploading
                                ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(Icons.cloud_upload),
                        label: Text(
                          _isUploading ? 'Uploading...' : 'Upload File',
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.background,
                          disabledBackgroundColor: AppColors.primary.withValues(
                            alpha: 0.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Widgets ───────────────────────────────────────────────────────────────

  Widget _buildDropZone() {
    final hasFile = _pickedFile != null;

    return GestureDetector(
      onTap: (_isPickingFile || _isUploading) ? null : _pickFile,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        decoration: BoxDecoration(
          color:
              hasFile
                  ? AppColors.primary.withValues(alpha: 0.07)
                  : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                hasFile
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.3),
            width: hasFile ? 2 : 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isPickingFile) ...[
              CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 12),
              Text(
                'Opening file picker…',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ] else if (hasFile) ...[
              _fileTypeIcon(_ext),
              const SizedBox(height: 12),
              Text(
                _pickedFile!.name,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                _formatBytes(_pickedFile!.size),
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.swap_horiz, size: 16, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    'Tap to change file',
                    style: TextStyle(color: AppColors.primary, fontSize: 13),
                  ),
                ],
              ),
            ] else ...[
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.cloud_upload_outlined,
                  color: AppColors.primary,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Tap to select a file',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'PDF, DOC, PPT, Images, Videos, Code files & more',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _fileTypeIcon(String extension) {
    final type = CourseFile.getTypeFromExtension(extension);
    IconData icon;
    Color color;
    switch (type) {
      case FileType.document:
        icon = Icons.picture_as_pdf;
        color = Colors.red.shade400;
      case FileType.image:
        icon = Icons.image;
        color = Colors.green.shade400;
      case FileType.video:
        icon = Icons.videocam;
        color = Colors.purple.shade400;
      case FileType.audio:
        icon = Icons.audiotrack;
        color = Colors.orange.shade400;
      case FileType.code:
        icon = Icons.code;
        color = Colors.cyan.shade400;
      case FileType.archive:
        icon = Icons.archive;
        color = Colors.brown.shade400;
      case FileType.other:
        icon = Icons.insert_drive_file;
        color = AppColors.textSecondary;
    }
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: color, size: 32),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Widget _buildInputSection({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildUploadProgress(UploadProgress progress) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _statusText(progress.status),
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${progress.progressPercent}%',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.progress,
              backgroundColor: AppColors.surfaceLight,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress.status == UploadStatus.completed
                    ? AppColors.success
                    : AppColors.primary,
              ),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  String _statusText(UploadStatus status) {
    switch (status) {
      case UploadStatus.pending:
        return 'Preparing...';
      case UploadStatus.uploading:
        return 'Uploading...';
      case UploadStatus.processing:
        return 'Processing...';
      case UploadStatus.completed:
        return 'Completed!';
      case UploadStatus.failed:
        return 'Failed';
      case UploadStatus.cancelled:
        return 'Cancelled';
    }
  }
}
