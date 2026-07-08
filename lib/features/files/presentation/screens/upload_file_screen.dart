import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

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

  String _selectedFileType = 'pdf';
  bool _isUploading = false;

  final List<Map<String, dynamic>> _fileTypes = [
    {'ext': 'pdf', 'name': 'PDF Document', 'icon': Icons.picture_as_pdf},
    {'ext': 'docx', 'name': 'Word Document', 'icon': Icons.description},
    {'ext': 'pptx', 'name': 'PowerPoint', 'icon': Icons.slideshow},
    {'ext': 'mp4', 'name': 'Video', 'icon': Icons.videocam},
    {'ext': 'png', 'name': 'Image', 'icon': Icons.image},
    {'ext': 'zip', 'name': 'Archive', 'icon': Icons.archive},
    {'ext': 'dart', 'name': 'Dart Code', 'icon': Icons.code},
    {'ext': 'py', 'name': 'Python Code', 'icon': Icons.code},
    {'ext': 'js', 'name': 'JavaScript', 'icon': Icons.code},
    {'ext': 'md', 'name': 'Markdown', 'icon': Icons.description},
  ];

  @override
  void dispose() {
    _fileNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

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
                  content: Text('File uploaded successfully!'),
                  backgroundColor: AppColors.success,
                ),
              );
              context.pop();
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
            appBar: AppBar(
              title: const Text('Upload File'),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // File picker simulation
                    _buildFilePickerSection(context),
                    const SizedBox(height: 24),

                    // File name
                    _buildInputSection(
                      label: 'File Name',
                      child: TextFormField(
                        controller: _fileNameController,
                        decoration: InputDecoration(
                          hintText: 'Enter file name',
                          hintStyle: TextStyle(
                            color: AppColors.textMuted,
                          ),
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          suffixText: '.$_selectedFileType',
                          suffixStyle: TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        style: TextStyle(color: AppColors.textPrimary),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a file name';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Description
                    _buildInputSection(
                      label: 'Description (optional)',
                      child: TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Describe what this file contains...',
                          hintStyle: TextStyle(
                            color: AppColors.textMuted,
                          ),
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
                    const SizedBox(height: 20),

                    // File type selection
                    _buildInputSection(
                      label: 'File Type (Demo)',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _fileTypes.map((type) {
                          final isSelected = _selectedFileType == type['ext'];
                          return ChoiceChip(
                            selected: isSelected,
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  type['icon'] as IconData,
                                  size: 16,
                                  color: isSelected
                                      ? AppColors.background
                                      : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(type['name'] as String),
                              ],
                            ),
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? AppColors.background
                                  : AppColors.textSecondary,
                              fontSize: 12,
                            ),
                            selectedColor: AppColors.primary,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedFileType = type['ext'] as String;
                                });
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Upload progress
                    if (state is FileUploading) ...[
                      _buildUploadProgress(state.progress),
                      const SizedBox(height: 24),
                    ],

                    // Upload button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isUploading
                            ? null
                            : () => _uploadFile(context),
                        icon: _isUploading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.textPrimary,
                                ),
                              )
                            : Icon(Icons.cloud_upload),
                        label: Text(
                          _isUploading ? 'Uploading...' : 'Upload File',
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.background,
                          disabledBackgroundColor: AppColors.primary.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Info note
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AppColors.info,
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'This is a demo upload screen. In production, this would use Supabase Storage for actual file uploads.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
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
        },
      ),
    );
  }

  Widget _buildFilePickerSection(BuildContext context) {
    return InkWell(
      onTap: () {
        // In production, this would open file picker
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File picker would open here'),
            backgroundColor: AppColors.info,
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            width: 2,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
              'or drag and drop here',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Text(
              'Max file size: 100MB • Supported: PDF, DOC, PPT, Images, Videos, Code files',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
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
                _getStatusText(progress.status),
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

  String _getStatusText(UploadStatus status) {
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

  void _uploadFile(BuildContext blocContext) {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final fileName = '${_fileNameController.text}.$_selectedFileType';
    final mimeType = _getMimeType(_selectedFileType);
    final fileSize =
        (500000 + (DateTime.now().millisecond * 10000)); // Random size

    blocContext.read<FileBloc>().add(
      UploadFile(
        courseId: widget.courseId,
        lessonId: widget.lessonId,
        fileName: fileName,
        mimeType: mimeType,
        fileSize: fileSize,
        description: _descriptionController.text,
        uploaderId: 'demo-user',
        uploaderName: 'Demo User',
      ),
    );
  }

  String _getMimeType(String ext) {
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'mp4':
        return 'video/mp4';
      case 'png':
        return 'image/png';
      case 'zip':
        return 'application/zip';
      case 'dart':
        return 'text/x-dart';
      case 'py':
        return 'text/x-python';
      case 'js':
        return 'application/javascript';
      case 'md':
        return 'text/markdown';
      default:
        return 'application/octet-stream';
    }
  }
}
