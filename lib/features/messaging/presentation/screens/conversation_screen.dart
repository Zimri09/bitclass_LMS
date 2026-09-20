import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/message_model.dart';
import '../../data/repositories/messaging_repository.dart';

class ConversationScreen extends StatefulWidget {
  final String courseId;
  final String currentUserId;
  final String participantId;
  final String participantName;
  final String? participantAvatarUrl;

  const ConversationScreen({
    super.key,
    required this.courseId,
    required this.currentUserId,
    required this.participantId,
    required this.participantName,
    this.participantAvatarUrl,
  });

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  late final MessagingRepository _messagingRepository;
  List<MessageModel> _messages = const [];
  final Set<String> _modifiableMessageIds = {};
  RealtimeChannel? _realtimeChannel;
  Timer? _editWindowTimer;
  bool _isLoading = true;
  bool _isSending = false;
  Object? _loadError;
  int _loadGeneration = 0;

  MessagingRepository get _repository => _messagingRepository;

  @override
  void initState() {
    super.initState();
    _messagingRepository = context.read<MessagingRepository>();
    _loadMessages();
    _realtimeChannel = _repository.subscribeToConversation(
      courseId: widget.courseId,
      onChanged: () => _loadMessages(silent: true),
    );
    _editWindowTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _refreshModificationEligibility();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _editWindowTimer?.cancel();
    unawaited(_repository.removeRealtimeChannel(_realtimeChannel));
    super.dispose();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    final loadGeneration = ++_loadGeneration;
    if (!silent && mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }
    try {
      final messages = await _repository.getConversation(
        courseId: widget.courseId,
        participantId: widget.participantId,
      );
      await _repository.markConversationRead(
        courseId: widget.courseId,
        participantId: widget.participantId,
      );
      if (!mounted || loadGeneration != _loadGeneration) return;
      setState(() {
        _messages = messages;
        _isLoading = false;
        _loadError = null;
      });
      await _refreshModificationEligibility();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (error) {
      _repository.logError(error);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = error;
        });
      }
    }
  }

  Future<void> _refreshModificationEligibility() async {
    final eligibleIds = <String>{};
    for (final message in _messages) {
      if (message.senderId != widget.currentUserId || message.isUnsent) {
        continue;
      }
      try {
        if (await _repository.canModifyMessage(message.id)) {
          eligibleIds.add(message.id);
        }
      } catch (_) {
        // The database remains the final authority when a mutation is sent.
      }
    }
    if (!mounted) return;
    setState(() {
      _modifiableMessageIds
        ..clear()
        ..addAll(eligibleIds);
    });
  }

  Future<void> _sendMessage() async {
    final body = _messageController.text.trim();
    if (body.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    try {
      await _repository.sendMessage(
        courseId: widget.courseId,
        recipientId: widget.participantId,
        body: body,
      );
      _messageController.clear();
      await _loadMessages(silent: true);
    } catch (error) {
      _repository.logError(error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to send message: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _deleteConversation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this conversation?'),
        content: const Text('This will clear all messages from your view.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _repository.deleteConversation(
        courseId: widget.courseId,
        participantId: widget.participantId,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to delete conversation: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = widget.participantName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0])
        .join()
        .toUpperCase();
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        actions: [
          IconButton(
            tooltip: 'Delete conversation',
            onPressed: _deleteConversation,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: widget.participantAvatarUrl?.isNotEmpty == true
                  ? NetworkImage(widget.participantAvatarUrl!)
                  : null,
              child: widget.participantAvatarUrl?.isNotEmpty == true
                  ? null
                  : Text(initials, style: AppTextStyles.bodySmall),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.participantName,
                style: AppTextStyles.bodyLarge,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _loadError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Unable to load this conversation.',
                            style: AppTextStyles.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$_loadError',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _loadMessages,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _messages.isEmpty
                ? Center(
                    child: Text(
                      'Start a private conversation.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isSent = message.senderId == widget.currentUserId;
                      return _MessageBubble(
                        message: message,
                        isSent: isSent,
                        canModify: _modifiableMessageIds.contains(message.id),
                        repository: _repository,
                        onChanged: () => _loadMessages(silent: true),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 3,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        hintText: 'Write a message...',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Send message',
                    onPressed: _isSending ? null : _sendMessage,
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isSent;
  final bool canModify;
  final MessagingRepository repository;
  final VoidCallback onChanged;

  const _MessageBubble({
    required this.message,
    required this.isSent,
    required this.canModify,
    required this.repository,
    required this.onChanged,
  });

  Future<void> _edit(BuildContext context) async {
    final controller = TextEditingController(text: message.body);
    final body = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 1,
          maxLines: 5,
          maxLength: 4000,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (body == null || body.trim().isEmpty || !context.mounted) return;
    try {
      await repository.editMessage(messageId: message.id, body: body);
      // Realtime subscription will bring the updated message.
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to edit message: $error')),
        );
      }
    }
  }

  Future<void> _unsend(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsend message?'),
        content: const Text(
          'This message will be replaced with “Message unsent”.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unsend'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await repository.unsendMessage(message.id);
      // Realtime subscription will bring the updated message.
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to unsend message: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxBubbleWidth = MediaQuery.sizeOf(context).width * 0.75;
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxBubbleWidth),
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.fromLTRB(10, 6, 4, 4),
      decoration: BoxDecoration(
        color: isSent ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: isSent
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Text(
                  message.body,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isSent ? Colors.white : AppColors.textPrimary,
                    fontStyle: message.isUnsent ? FontStyle.italic : null,
                  ),
                ),
              ),
              if (isSent && !message.isUnsent && canModify)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    iconSize: 14,
                    splashRadius: 14,
                    icon: const Icon(Icons.more_vert, color: Colors.white70, size: 14),
                    onSelected: (value) {
                      if (value == 'edit') _edit(context);
                      if (value == 'unsend') _unsend(context);
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'unsend', child: Text('Unsend')),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${message.editedAt != null && !message.isUnsent ? 'Edited · ' : ''}${DateFormat('h:mm a').format(message.createdAt)}',
            style: AppTextStyles.caption.copyWith(
              fontSize: 10,
              color: isSent ? Colors.white70 : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: bubble,
    );
  }
}
