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
  List<MessageModel> _messages = const [];
  final Set<String> _modifiableMessageIds = {};
  RealtimeChannel? _realtimeChannel;
  Timer? _editWindowTimer;
  bool _isLoading = true;
  bool _isSending = false;

  MessagingRepository get _repository => context.read<MessagingRepository>();

  @override
  void initState() {
    super.initState();
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
    if (!silent && mounted) setState(() => _isLoading = true);
    try {
      final messages = await _repository.getConversation(
        courseId: widget.courseId,
        participantId: widget.participantId,
      );
      await _repository.markConversationRead(
        courseId: widget.courseId,
        participantId: widget.participantId,
      );
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _isLoading = false;
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
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
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
    } finally {
      if (mounted) setState(() => _isSending = false);
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
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        hintText: 'Write a message...',
                        border: OutlineInputBorder(),
                        isDense: true,
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
      onChanged();
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
      onChanged();
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
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 360),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(13, 9, 7, 7),
      decoration: BoxDecoration(
        color: isSent ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: isSent
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
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
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  icon: const Icon(Icons.more_vert, color: Colors.white70),
                  onSelected: (value) {
                    if (value == 'edit') _edit(context);
                    if (value == 'unsend') _unsend(context);
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'unsend', child: Text('Unsend')),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.editedAt != null && !message.isUnsent)
                Text(
                  'Edited  ',
                  style: AppTextStyles.caption.copyWith(
                    color: isSent ? Colors.white70 : AppColors.textMuted,
                  ),
                ),
              Text(
                DateFormat('h:mm a').format(message.createdAt),
                style: AppTextStyles.caption.copyWith(
                  color: isSent ? Colors.white70 : AppColors.textMuted,
                ),
              ),
            ],
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
