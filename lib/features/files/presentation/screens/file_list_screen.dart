import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/loading_widgets.dart';
import '../../data/models/models.dart';
import '../../data/repositories/file_repository.dart';
import '../bloc/bloc.dart';

/// Screen showing all files for a course
class FileListScreen extends StatefulWidget {
  final String courseId;

  const FileListScreen({super.key, required this.courseId});

  @override
  State<FileListScreen> createState() => _FileListScreenState();
}

class _FileListScreenState extends State<FileListScreen> {
  final TextEditingController _searchController = TextEditingController();
  FileType? _selectedFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          FileBloc(fileRepository: context.read<FileRepository>())
            ..add(LoadCourseFiles(courseId: widget.courseId)),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Course Materials'),
          actions: [
            IconButton(
              icon: Icon(Icons.upload_file),
              onPressed: () =>
                  context.push('/courses/${widget.courseId}/files/upload'),
              tooltip: 'Upload File',
            ),
          ],
        ),
        body: Column(
          children: [
            // Search and filter bar
            _buildSearchFilterBar(),
            // File list
            Expanded(
              child: BlocBuilder<FileBloc, FileState>(
                builder: (context, state) {
                  if (state is FilesLoading) {
                    return const FileListSkeleton();
                  }

                  if (state is FileError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: AppColors.error,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            state.message,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (state is FilesLoaded) {
                    if (state.files.isEmpty) {
                      return _buildEmptyState(state.filterType != null);
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        context.read<FileBloc>().add(
                          LoadCourseFiles(courseId: widget.courseId),
                        );
                      },
                      color: AppColors.primary,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: state.files.length,
                        itemBuilder: (context, index) {
                          return _buildFileCard(context, state.files[index]);
                        },
                      ),
                    );
                  }

                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.surface,
      child: Column(
        children: [
          // Search field
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search files...',
              hintStyle: TextStyle(color: AppColors.textMuted),
              prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: AppColors.textMuted),
                      onPressed: () {
                        _searchController.clear();
                        context.read<FileBloc>().add(
                          LoadCourseFiles(courseId: widget.courseId),
                        );
                        setState(() {});
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            style: TextStyle(color: AppColors.textPrimary),
            onSubmitted: (query) {
              if (query.isNotEmpty) {
                context.read<FileBloc>().add(
                  SearchFiles(courseId: widget.courseId, query: query),
                );
              }
            },
          ),
          const SizedBox(height: 12),
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(null, 'All', Icons.folder),
                const SizedBox(width: 8),
                _buildFilterChip(
                  FileType.document,
                  'Documents',
                  Icons.description,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(FileType.image, 'Images', Icons.image),
                const SizedBox(width: 8),
                _buildFilterChip(FileType.video, 'Videos', Icons.videocam),
                const SizedBox(width: 8),
                _buildFilterChip(FileType.code, 'Code', Icons.code),
                const SizedBox(width: 8),
                _buildFilterChip(FileType.archive, 'Archives', Icons.archive),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(FileType? type, String label, IconData icon) {
    final isSelected = _selectedFilter == type;
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? AppColors.background : AppColors.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.background : AppColors.textSecondary,
      ),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surfaceLight,
      checkmarkColor: AppColors.background,
      showCheckmark: false,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = selected ? type : null;
        });
        context.read<FileBloc>().add(
          FilterFilesByType(courseId: widget.courseId, type: _selectedFilter),
        );
      },
    );
  }

  Widget _buildEmptyState(bool hasFilter) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasFilter ? Icons.filter_list_off : Icons.folder_open,
            color: AppColors.textSecondary,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            hasFilter ? 'No files match your filter' : 'No files uploaded yet',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasFilter
                ? 'Try a different filter or clear it'
                : 'Upload course materials to get started',
            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
          if (!hasFilter) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () =>
                  context.push('/courses/${widget.courseId}/files/upload'),
              icon: Icon(Icons.upload_file),
              label: const Text('Upload File'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFileCard(BuildContext context, CourseFile file) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showFileOptions(context, file),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // File type icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getTypeColor(file.type).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getTypeIcon(file.type),
                  color: _getTypeColor(file.type),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              // File info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.name,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (file.description.isNotEmpty)
                      Text(
                        file.description,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          file.formattedSize,
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.download,
                          size: 12,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${file.downloadCount}',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _formatDate(file.createdAt),
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // More button
              IconButton(
                icon: Icon(
                  Icons.more_vert,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => _showFileOptions(context, file),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFileOptions(BuildContext blocContext, CourseFile file) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(Icons.download, color: AppColors.textPrimary),
              title: Text(
                'Download',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              onTap: () {
                Navigator.pop(context);
                blocContext.read<FileBloc>().add(
                  RecordDownload(courseId: widget.courseId, fileId: file.id),
                );
                ScaffoldMessenger.of(blocContext).showSnackBar(
                  SnackBar(
                    content: Text('Download started (demo)'),
                    backgroundColor: AppColors.info,
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.share, color: AppColors.textPrimary),
              title: Text(
                'Share',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(blocContext).showSnackBar(
                  SnackBar(
                    content: Text('Share feature coming soon'),
                    backgroundColor: AppColors.info,
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.edit, color: AppColors.textPrimary),
              title: Text(
                'Edit Details',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              onTap: () {
                Navigator.pop(context);
                _showEditDialog(blocContext, file);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: AppColors.error),
              title: Text(
                'Delete',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(blocContext, file);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext blocContext, CourseFile file) {
    final nameController = TextEditingController(text: file.name);
    final descController = TextEditingController(text: file.description);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Edit File Details',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'File Name',
                labelStyle: TextStyle(color: AppColors.textSecondary),
              ),
              style: TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: InputDecoration(
                labelText: 'Description',
                labelStyle: TextStyle(color: AppColors.textSecondary),
              ),
              style: TextStyle(color: AppColors.textPrimary),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              blocContext.read<FileBloc>().add(
                UpdateFile(
                  courseId: widget.courseId,
                  fileId: file.id,
                  name: nameController.text,
                  description: descController.text,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext blocContext, CourseFile file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete File?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete "${file.name}"? This action cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              blocContext.read<FileBloc>().add(
                DeleteFile(fileId: file.id, courseId: widget.courseId),
              );
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  IconData _getTypeIcon(FileType type) {
    switch (type) {
      case FileType.document:
        return Icons.description;
      case FileType.image:
        return Icons.image;
      case FileType.video:
        return Icons.videocam;
      case FileType.audio:
        return Icons.audiotrack;
      case FileType.code:
        return Icons.code;
      case FileType.archive:
        return Icons.archive;
      case FileType.other:
        return Icons.insert_drive_file;
    }
  }

  Color _getTypeColor(FileType type) {
    switch (type) {
      case FileType.document:
        return AppColors.info;
      case FileType.image:
        return AppColors.success;
      case FileType.video:
        return AppColors.error;
      case FileType.audio:
        return AppColors.warning;
      case FileType.code:
        return AppColors.primary;
      case FileType.archive:
        return AppColors.secondary;
      case FileType.other:
        return AppColors.textSecondary;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
