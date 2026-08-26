import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/errors/app_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/url_utils.dart';
import '../../../../shared/widgets/loading_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
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
  int _reloadKey = 0;
  final Map<String, OfflineCourseFile> _offlineFiles = {};
  final Set<String> _downloadingFileIds = {};
  final Map<String, double> _downloadProgress = {};

  String? get _currentUserId {
    final authState = context.read<AuthBloc>().state;
    return authState is AuthAuthenticated ? authState.user.id : null;
  }

  bool get _canUpload {
    final authState = context.read<AuthBloc>().state;
    return authState is AuthAuthenticated && authState.user.isStaff;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOfflineFiles());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: ValueKey(_reloadKey),
      child: BlocProvider(
        create: (context) =>
            FileBloc(fileRepository: context.read<FileRepository>())
              ..add(LoadCourseFiles(courseId: widget.courseId)),
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Course Materials'),
            actions: [
              if (_canUpload)
                IconButton(
                  icon: Icon(Icons.upload_file),
                  onPressed: _openUpload,
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
                              style: TextStyle(color: AppColors.textSecondary),
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
          _buildFilterBar(),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final chips = <Widget>[
      _buildFilterChip(null, 'All', Icons.folder),
      _buildFilterChip(FileType.document, 'Documents', Icons.description),
      _buildFilterChip(FileType.image, 'Images', Icons.image),
      _buildFilterChip(FileType.video, 'Videos', Icons.videocam),
      _buildFilterChip(FileType.code, 'Code', Icons.code),
      _buildFilterChip(FileType.archive, 'Archives', Icons.archive),
    ];

    if (kIsWeb) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Wrap(spacing: 8, runSpacing: 8, children: chips),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < chips.length; index++) ...[
            if (index > 0) const SizedBox(width: 8),
            chips[index],
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip(FileType? type, String label, IconData icon) {
    final isSelected = _selectedFilter == type;
    return ChoiceChip(
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
      showCheckmark: false,
      onSelected: (_) => _selectFilter(type),
    );
  }

  void _selectFilter(FileType? type) {
    setState(() {
      _selectedFilter = type;
      _searchController.clear();
    });
    context.read<FileBloc>().add(
      FilterFilesByType(courseId: widget.courseId, type: type),
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
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            hasFilter
                ? 'Try a different filter or clear it'
                : 'Upload course materials to get started',
            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
          if (!hasFilter && _canUpload) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _openUpload,
              icon: Icon(Icons.upload_file),
              label: const Text('Upload File'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openUpload() async {
    if (!_canUpload) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only instructors can upload files.')),
      );
      return;
    }

    await context.push('/courses/${widget.courseId}/files/upload');
    if (mounted) {
      setState(() => _reloadKey++);
    }
  }

  Widget _buildFileCard(BuildContext context, CourseFile file) {
    final offline = _offlineFiles[file.id];
    final isDownloading = _downloadingFileIds.contains(file.id);
    final progress = _downloadProgress[file.id] ?? 0;

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
                  file.isExternalLink ? Icons.link : _getTypeIcon(file.type),
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            file.name,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (offline != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.offline_pin,
                                  size: 13,
                                  color: AppColors.success,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Offline',
                                  style: TextStyle(
                                    color: AppColors.success,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (isDownloading) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: progress > 0 ? progress : null,
                              minHeight: 3,
                              color: AppColors.primary,
                              backgroundColor: AppColors.surfaceLight,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            progress > 0
                                ? '${(progress * 100).round()}%'
                                : 'Starting...',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
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
                        if (!file.isExternalLink) ...[
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
                        ],
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
                icon: Icon(Icons.more_vert, color: AppColors.textSecondary),
                onPressed: () => _showFileOptions(context, file),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFileOptions(BuildContext blocContext, CourseFile file) {
    final offline = _offlineFiles[file.id];
    final isDownloading = _downloadingFileIds.contains(file.id);

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
            if (file.isExternalLink)
              ListTile(
                leading: Icon(Icons.open_in_new, color: AppColors.textPrimary),
                title: Text(
                  'Open Link',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _openExternalLink(file);
                },
              )
            else if (isDownloading)
              ListTile(
                leading: SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.primary,
                  ),
                ),
                title: Text(
                  'Downloading...',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
              )
            else if (offline == null)
              ListTile(
                leading: Icon(
                  Icons.download_outlined,
                  color: AppColors.textPrimary,
                ),
                title: Text(
                  'Download',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _downloadFile(blocContext, file);
                },
              )
            else ...[
              ListTile(
                leading: Icon(
                  Icons.offline_pin_outlined,
                  color: AppColors.textPrimary,
                ),
                title: Text(
                  'View Offline',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _openOfflineFile(offline);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: AppColors.error),
                title: Text(
                  'Remove Download',
                  style: TextStyle(color: AppColors.error),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmRemoveDownload(offline);
                },
              ),
            ],
            if (_canUpload)
              ListTile(
                leading: Icon(
                  Icons.delete_forever_outlined,
                  color: AppColors.error,
                ),
                title: Text(
                  'Delete Material',
                  style: TextStyle(color: AppColors.error),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteMaterial(blocContext, file);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _loadOfflineFiles() async {
    final userId = _currentUserId;
    if (userId == null) return;

    try {
      final files = await context.read<FileRepository>().getOfflineFiles(
        userId,
      );
      if (!mounted) return;
      setState(() {
        _offlineFiles
          ..clear()
          ..addEntries(
            files.map((offline) => MapEntry(offline.file.id, offline)),
          );
      });
    } catch (_) {
      // The online materials list remains usable if the local index fails.
    }
  }

  Future<void> _downloadFile(BuildContext blocContext, CourseFile file) async {
    final userId = _currentUserId;
    if (userId == null || _downloadingFileIds.contains(file.id)) return;
    final repository = context.read<FileRepository>();
    final messenger = ScaffoldMessenger.of(blocContext);

    setState(() {
      _downloadingFileIds.add(file.id);
      _downloadProgress[file.id] = 0;
    });

    try {
      final offline = await repository.downloadForOffline(
        userId: userId,
        file: file,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _downloadProgress[file.id] = progress);
        },
      );

      try {
        await repository.recordDownload(widget.courseId, file.id);
      } catch (_) {
        // A local download remains valid even if analytics cannot be recorded.
      }

      if (!mounted) return;
      setState(() => _offlineFiles[file.id] = offline);
      messenger.showSnackBar(
        SnackBar(
          content: Text('${file.name} is available offline.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            userFriendlyErrorMessage(
              error,
              fallback: 'Could not download this file.',
            ),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _downloadingFileIds.remove(file.id);
          _downloadProgress.remove(file.id);
        });
      }
    }
  }

  Future<void> _openOfflineFile(OfflineCourseFile offline) async {
    try {
      await context.read<FileRepository>().openOfflineFile(offline);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFriendlyErrorMessage(error)),
          backgroundColor: AppColors.error,
        ),
      );
      await _loadOfflineFiles();
    }
  }

  Future<void> _openExternalLink(CourseFile file) async {
    try {
      final uri = normalizeWebUrl(file.url);
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) throw StateError('No application accepted this URL.');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'This link cannot be opened. Check the URL and try again.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _confirmRemoveDownload(OfflineCourseFile offline) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove offline file?'),
        content: Text(
          '"${offline.file.name}" will be removed from this device. '
          'The original learning material will remain in the course.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await context.read<FileRepository>().removeOfflineFile(
      userId: offline.userId,
      fileId: offline.file.id,
    );
    if (!mounted) return;
    setState(() => _offlineFiles.remove(offline.file.id));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Offline download removed.')));
  }

  Future<void> _confirmDeleteMaterial(
    BuildContext blocContext,
    CourseFile file,
  ) async {
    final fileBloc = blocContext.read<FileBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete learning material?'),
        content: Text(
          '"${file.name}" will be removed from the course for everyone. '
          'This action cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    fileBloc.add(DeleteFile(fileId: file.id, courseId: widget.courseId));
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
