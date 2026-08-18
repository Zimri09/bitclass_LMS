import 'dart:typed_data';

import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/environment.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/url_utils.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/models/models.dart';
import '../../data/repositories/file_repository.dart';
import '../bloc/bloc.dart';

enum _UploadSource { device, url }

String _fileExtension(String name) {
  final dot = name.lastIndexOf('.');
  return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
}

/// Screen for uploading files to a course
class UploadFileScreen extends StatefulWidget {
  final String courseId;
  final String? lessonId;

  const UploadFileScreen({super.key, required this.courseId, this.lessonId});

  @override
  State<UploadFileScreen> createState() => _UploadFileScreenState();
}

class _UploadFileScreenState extends State<UploadFileScreen> {
  static const int _maxUploadBytes = 50 * 1024 * 1024;

  final _formKey = GlobalKey<FormState>();
  final _fileNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _urlController = TextEditingController();

  fp.PlatformFile? _pickedFile;
  Uint8List? _pickedBytes;

  bool _isPickingFile = false;
  bool _isUploading = false;
  _UploadSource _source = _UploadSource.device;

  @override
  void dispose() {
    _fileNameController.dispose();
    _descriptionController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  // ── File picking ─────────────────────────────────────────────────────────

  Future<void> _pickFile() async {
    if (_isPickingFile || _isUploading) return;
    setState(() => _isPickingFile = true);

    try {
      final file = await fp.FilePicker.pickFile(type: fp.FileType.any);

      if (file == null) return;

      final fileSize = await file.length();
      if (fileSize > _maxUploadBytes) {
        _showError(
          'This file is larger than 50 MB. Compress it or increase the '
          'Supabase Storage limit before uploading.',
        );
        return;
      }
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
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

  String get _ext => _fileExtension(_pickedFile?.name ?? '');

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
      SnackBar(
        content: Text(userFriendlyErrorMessage(msg)),
        backgroundColor: AppColors.error,
      ),
    );
  }

  // ── Upload ───────────────────────────────────────────────────────────────

  void _uploadFile(BuildContext blocContext) {
    if (_isUploading) return;
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated || !authState.user.isStaff) {
      _showError('Only staff can upload files.');
      return;
    }

    if (_pickedFile == null || _pickedBytes == null) {
      _showError('Please select a file first.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final user = EnvironmentConfig.isDemoMode
        ? null
        : Supabase.instance.client.auth.currentUser;
    if (!EnvironmentConfig.isDemoMode && user == null) {
      _showError('Please sign in before uploading a file.');
      return;
    }

    final uploaderId = user?.id ?? 'demo-instructor';
    final uploaderName =
        user?.userMetadata?['full_name'] as String? ??
        user?.email ??
        'Unknown User';

    setState(() => _isUploading = true);
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

  Future<void> _saveUrlResource() async {
    if (_isUploading) return;
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated || !authState.user.isStaff) {
      _showError('Only staff can add learning materials.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final user = EnvironmentConfig.isDemoMode
        ? null
        : Supabase.instance.client.auth.currentUser;
    if (!EnvironmentConfig.isDemoMode && user == null) {
      _showError('Please sign in before adding a web link.');
      return;
    }

    final canonicalUrl = normalizeWebUrl(_urlController.text).toString();
    final uploaderId = user?.id ?? 'demo-instructor';
    final uploaderName =
        user?.userMetadata?['full_name'] as String? ??
        user?.email ??
        'Unknown User';

    setState(() => _isUploading = true);
    try {
      await context.read<FileRepository>().createUrlResource(
        courseId: widget.courseId,
        lessonId: widget.lessonId,
        name: _fileNameController.text,
        url: canonicalUrl,
        description: _descriptionController.text,
        uploaderId: uploaderId,
        uploaderName: uploaderName,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Web link saved successfully.'),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
    } catch (error) {
      if (!mounted) return;
      _showError(
        userFriendlyErrorMessage(
          error,
          fallback: 'The web link could not be saved. Please try again.',
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final canUpload = authState is AuthAuthenticated && authState.user.isStaff;

    if (!canUpload) {
      return Scaffold(
        appBar: AppBar(title: const Text('Upload File')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Only staff can upload files to a course.'),
          ),
        ),
      );
    }

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
                  content: Text(
                    userFriendlyErrorMessage(
                      state.progress.errorMessage ?? 'Upload failed',
                    ),
                  ),
                  backgroundColor: AppColors.error,
                  action: isNetworkFailure(state.progress.errorMessage ?? '')
                      ? SnackBarAction(
                          label: 'Retry',
                          onPressed: () => _uploadFile(context),
                        )
                      : null,
                ),
              );
            }
          } else if (state is FileError) {
            setState(() => _isUploading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
                action: isNetworkFailure(state.message)
                    ? SnackBarAction(
                        label: 'Retry',
                        onPressed: () => _uploadFile(context),
                      )
                    : null,
              ),
            );
          }
        },
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: Text(
                widget.lessonId == null
                    ? 'Add Learning Material'
                    : 'Attach Resource to Lesson',
              ),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSourceSelector(),
                    const SizedBox(height: 20),
                    if (_source == _UploadSource.device)
                      _buildDropZone()
                    else
                      _buildUrlInput(),
                    const SizedBox(height: 24),

                    _buildInputSection(
                      label: _source == _UploadSource.url
                          ? 'Link Title'
                          : 'File Name',
                      child: TextFormField(
                        controller: _fileNameController,
                        enabled:
                            !_isUploading &&
                            (_source == _UploadSource.url ||
                                _pickedFile != null),
                        decoration: InputDecoration(
                          hintText: _source == _UploadSource.url
                              ? 'Enter link title'
                              : _pickedFile == null
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
                              _source == _UploadSource.device && _ext.isNotEmpty
                              ? '.$_ext'
                              : null,
                          suffixStyle: TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        style: TextStyle(color: AppColors.textPrimary),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? _source == _UploadSource.url
                                  ? 'Please enter a link title'
                                  : 'Please enter a file name'
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
                          hintText: _source == _UploadSource.url
                              ? 'Describe what this link contains...'
                              : 'Describe what this file contains...',
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
                            _isUploading ||
                                (_source == _UploadSource.device &&
                                    _pickedFile == null)
                            ? null
                            : _source == _UploadSource.device
                            ? () => _uploadFile(context)
                            : _saveUrlResource,
                        icon: _isUploading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                _source == _UploadSource.device
                                    ? Icons.cloud_upload
                                    : Icons.add_link,
                              ),
                        label: Text(
                          _isUploading
                              ? _source == _UploadSource.device
                                    ? 'Uploading...'
                                    : 'Saving...'
                              : _source == _UploadSource.device
                              ? 'Upload File'
                              : 'Save Web Link',
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

  Widget _buildSourceSelector() {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<_UploadSource>(
        segments: const [
          ButtonSegment(
            value: _UploadSource.device,
            icon: Icon(Icons.upload_file),
            label: Text('Device File'),
          ),
          ButtonSegment(
            value: _UploadSource.url,
            icon: Icon(Icons.link),
            label: Text('Web Link'),
          ),
        ],
        selected: {_source},
        onSelectionChanged: _isUploading
            ? null
            : (selection) => setState(() => _source = selection.first),
      ),
    );
  }

  Widget _buildUrlInput() {
    return TextFormField(
      controller: _urlController,
      enabled: !_isUploading,
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.next,
      autocorrect: false,
      decoration: const InputDecoration(
        labelText: 'Web address',
        hintText: 'https://example.com/resource',
        prefixIcon: Icon(Icons.language),
      ),
      validator: validateWebUrl,
    );
  }

  Widget _buildDropZone() {
    final hasFile = _pickedFile != null;

    return GestureDetector(
      onTap: (_isPickingFile || _isUploading) ? null : _pickFile,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        decoration: BoxDecoration(
          color: hasFile
              ? AppColors.primary.withValues(alpha: 0.07)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasFile
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
                _formatBytes(_pickedBytes!.length),
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
