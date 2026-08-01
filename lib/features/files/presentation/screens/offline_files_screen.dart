import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/models/models.dart';
import '../../data/repositories/file_repository.dart';

/// Lists files saved in app-private storage for the signed-in user.
class OfflineFilesScreen extends StatefulWidget {
  const OfflineFilesScreen({super.key});

  @override
  State<OfflineFilesScreen> createState() => _OfflineFilesScreenState();
}

class _OfflineFilesScreenState extends State<OfflineFilesScreen> {
  List<OfflineCourseFile> _files = const [];
  bool _isLoading = true;
  String? _errorMessage;

  String? get _currentUserId {
    final authState = context.read<AuthBloc>().state;
    return authState is AuthAuthenticated ? authState.user.id : null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFiles());
  }

  Future<void> _loadFiles() async {
    final userId = _currentUserId;
    if (userId == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Sign in to view your offline files.';
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final files = await context.read<FileRepository>().getOfflineFiles(
        userId,
      );
      if (!mounted) return;
      setState(() {
        _files = files;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = userFriendlyErrorMessage(
          error,
          fallback: 'Could not load offline files.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final isOffline = authState is AuthAuthenticated && authState.isOffline;
    return Scaffold(
      appBar: AppBar(
        leading: const AppDrawerButton(),
        title: const Text('Offline Files'),
        bottom: isOffline
            ? PreferredSize(
                preferredSize: const Size.fromHeight(38),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 7,
                  ),
                  color: AppColors.warning.withValues(alpha: 0.14),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_off, size: 18, color: AppColors.warning),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('Offline mode')),
                      InkWell(
                        onTap: () =>
                            context.read<AuthBloc>().add(AuthCheckRequested()),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('Retry'),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : null,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.folder_off_outlined, size: 56, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _loadFiles,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_files.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.download_for_offline_outlined,
                  size: 46,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No offline files yet',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Download a learning material from a course to open it '
                'later without an internet connection.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFiles,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.24),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.offline_bolt_outlined, color: AppColors.success),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'These files are stored on this device and can be opened '
                    'without internet.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ..._files.map(_buildFileCard),
        ],
      ),
    );
  }

  Widget _buildFileCard(OfflineCourseFile offline) {
    final file = offline.file;

    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openFile(offline),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _typeColor(file.type).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_typeIcon(file.type), color: _typeColor(file.type)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(
                          Icons.offline_pin,
                          size: 14,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Available offline',
                          style: TextStyle(
                            color: AppColors.success,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            file.formattedSize,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Offline file options',
                icon: Icon(Icons.more_vert, color: AppColors.textSecondary),
                onSelected: (value) {
                  if (value == 'open') {
                    _openFile(offline);
                  } else if (value == 'remove') {
                    _confirmRemove(offline);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'open',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.offline_pin_outlined),
                      title: Text('View Offline'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'remove',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.delete_outline,
                        color: AppColors.error,
                      ),
                      title: Text(
                        'Remove Download',
                        style: TextStyle(color: AppColors.error),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openFile(OfflineCourseFile offline) async {
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
      await _loadFiles();
    }
  }

  Future<void> _confirmRemove(OfflineCourseFile offline) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove offline file?'),
        content: Text(
          '"${offline.file.name}" will be removed from this device. '
          'The original course material will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
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
    setState(
      () => _files.removeWhere((item) => item.file.id == offline.file.id),
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Offline download removed.')));
  }

  IconData _typeIcon(FileType type) {
    return switch (type) {
      FileType.document => Icons.description_outlined,
      FileType.image => Icons.image_outlined,
      FileType.video => Icons.video_file_outlined,
      FileType.audio => Icons.audio_file_outlined,
      FileType.code => Icons.code,
      FileType.archive => Icons.archive_outlined,
      FileType.other => Icons.insert_drive_file_outlined,
    };
  }

  Color _typeColor(FileType type) {
    return switch (type) {
      FileType.document => AppColors.info,
      FileType.image => AppColors.success,
      FileType.video => AppColors.error,
      FileType.audio => AppColors.warning,
      FileType.code => AppColors.primary,
      FileType.archive => AppColors.secondary,
      FileType.other => AppColors.textSecondary,
    };
  }
}
