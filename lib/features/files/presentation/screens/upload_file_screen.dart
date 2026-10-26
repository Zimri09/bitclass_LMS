import 'package:bitclass_notifications/bitclass_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/utils/url_utils.dart';
import '../../../../core/utils/upload_file.dart';
import '../../../../shared/widgets/upload_file_preview.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/models/models.dart';
import '../../data/repositories/file_repository.dart';

enum _UploadSource { device, url }

class _PendingFile {
  final UploadFileData file;
  final TextEditingController name;
  UploadProgress? progress;
  _PendingFile(this.file) : name = TextEditingController(text: file.name);
  bool get completed => progress?.isCompleted ?? false;
}

class UploadFileScreen extends StatefulWidget {
  final String courseId;
  final String? lessonId;
  const UploadFileScreen({super.key, required this.courseId, this.lessonId});
  @override
  State<UploadFileScreen> createState() => _UploadFileScreenState();
}

class _UploadFileScreenState extends State<UploadFileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _url = TextEditingController();
  final _description = TextEditingController();
  final _files = <_PendingFile>[];
  _UploadSource _source = _UploadSource.device;
  bool _isPicking = false;
  bool _isUploading = false;
  @override
  void dispose() {
    for (final file in _files) {
      file.name.dispose();
    }
    _title.dispose();
    _url.dispose();
    _description.dispose();
    super.dispose();
  }

  void _message(String value) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showAppSnackBar(SnackBar(content: Text(value)));
    }
  }

  Future<void> _pick() async {
    if (_isPicking || _isUploading) return;
    setState(() => _isPicking = true);
    try {
      final files = await pickUploadData(maxBytes: maxCourseUploadBytes);
      if (mounted) setState(() => _files.addAll(files.map(_PendingFile.new)));
    } catch (error) {
      _message(userFriendlyErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> _submit() async {
    if (_isPicking || _isUploading || !_formKey.currentState!.validate()) {
      return;
    }
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated || !auth.user.isStaff) {
      _message('Only staff can upload files.');
      return;
    }
    final repository = context.read<FileRepository>();
    setState(() => _isUploading = true);
    var succeeded = false;
    try {
      if (_source == _UploadSource.url) {
        await repository.createUrlResource(
          courseId: widget.courseId,
          lessonId: widget.lessonId,
          name: _title.text,
          url: normalizeWebUrl(_url.text).toString(),
          description: _description.text,
          uploaderId: auth.user.id,
          uploaderName: auth.user.displayNameOrEmail,
        );
        succeeded = true;
      } else {
        // Retry only unfinished files; successful uploads retain their records.
        for (final item in _files.where((item) => !item.completed)) {
          try {
            await for (final progress in repository.uploadFileWithData(
              courseId: widget.courseId,
              lessonId: widget.lessonId,
              fileName: item.name.text.trim(),
              mimeType: item.file.mimeType,
              fileData: item.file.bytes,
              description: _description.text.trim(),
              uploaderId: auth.user.id,
              uploaderName: auth.user.displayNameOrEmail,
            )) {
              if (!mounted) return;
              setState(() => item.progress = progress);
            }
            if (!item.completed) {
              throw StateError(
                item.progress?.errorMessage ??
                    'Upload did not finish. Try again.',
              );
            }
          } catch (error) {
            if (!mounted) return;
            setState(
              () => item.progress = UploadProgress(
                fileId: '',
                fileName: item.file.name,
                status: UploadStatus.failed,
                progress: 0,
                startedAt: DateTime.now(),
                errorMessage: userFriendlyErrorMessage(error),
              ),
            );
          }
        }
        succeeded = _files.isNotEmpty && _files.every((item) => item.completed);
        if (!succeeded) {
          _message(
            'Some files could not be uploaded. Saved files are kept; retry the remaining files.',
          );
        }
      }
    } catch (error) {
      _message(userFriendlyErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
    if (succeeded && mounted) {
      _message(
        _source == _UploadSource.url
            ? 'Web link saved successfully.'
            : '${_files.length} files uploaded successfully.',
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthBloc>().state;
    final canUpload = auth is AuthAuthenticated && auth.user.isStaff;
    return PopScope(
      canPop: !_isUploading,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.lessonId == null
                ? 'Add Learning Material'
                : 'Attach Resources to Lesson',
          ),
        ),
        body: !canUpload
            ? const Center(
                child: Text('Only staff can upload files to a course.'),
              )
            : Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SegmentedButton<_UploadSource>(
                            segments: const [
                              ButtonSegment(
                                value: _UploadSource.device,
                                icon: Icon(Icons.upload_file),
                                label: Text('Device Files'),
                              ),
                              ButtonSegment(
                                value: _UploadSource.url,
                                icon: Icon(Icons.link),
                                label: Text('Web Link'),
                              ),
                            ],
                            selected: {_source},
                            onSelectionChanged: _isUploading || _isPicking
                                ? null
                                : (value) =>
                                      setState(() => _source = value.single),
                          ),
                          const SizedBox(height: 20),
                          if (_source == _UploadSource.url) ...[
                            TextFormField(
                              controller: _title,
                              enabled: !_isUploading,
                              decoration: const InputDecoration(
                                labelText: 'Link Title',
                              ),
                              validator: (value) =>
                                  value?.trim().isEmpty != false
                                  ? 'Please enter a link title'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _url,
                              enabled: !_isUploading,
                              keyboardType: TextInputType.url,
                              validator: validateWebUrl,
                              decoration: const InputDecoration(
                                labelText: 'Web address',
                                hintText: 'https://example.com/resource',
                              ),
                            ),
                          ] else ...[
                            OutlinedButton.icon(
                              onPressed: _isUploading || _isPicking
                                  ? null
                                  : _pick,
                              icon: const Icon(Icons.add),
                              label: Text(
                                _isPicking
                                    ? 'Reading files...'
                                    : 'Select files',
                              ),
                            ),
                            const Text(
                              'Up to 50 MB per file. Review or remove files before uploading.',
                            ),
                            for (final item in _files)
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    children: [
                                      PendingUploadTile(
                                        file: item.file,
                                        onRemove: _isUploading || item.completed
                                            ? null
                                            : () {
                                                setState(
                                                  () => _files.remove(item),
                                                );
                                                item.name.dispose();
                                              },
                                      ),
                                      TextFormField(
                                        controller: item.name,
                                        enabled:
                                            !_isUploading && !item.completed,
                                        decoration: const InputDecoration(
                                          labelText: 'File Name',
                                        ),
                                        validator: (value) =>
                                            value?.trim().isEmpty != false
                                            ? 'Please enter a file name'
                                            : null,
                                      ),
                                      if (item.progress != null) ...[
                                        const SizedBox(height: 8),
                                        if (item.progress!.isInProgress)
                                          LinearProgressIndicator(
                                            value: item.progress!.progress,
                                          ),
                                        Text(
                                          item.completed
                                              ? 'Uploaded'
                                              : item.progress!.isFailed
                                              ? item.progress!.errorMessage ??
                                                    'Upload failed'
                                              : '${item.progress!.progressPercent}%',
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                          ],
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _description,
                            enabled: !_isUploading,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Description (optional)',
                            ),
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed:
                                _isUploading ||
                                    _isPicking ||
                                    (_source == _UploadSource.device &&
                                        _files.isEmpty)
                                ? null
                                : _submit,
                            icon: _isUploading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.cloud_upload),
                            label: Text(
                              _isUploading
                                  ? 'Uploading...'
                                  : _source == _UploadSource.url
                                  ? 'Save Web Link'
                                  : 'Upload Files',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
