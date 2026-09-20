import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  bool _isSameDay(DateTime a, DateTime b) {
    final localA = a.toLocal();
    final localB = b.toLocal();
    return localA.year == localB.year &&
        localA.month == localB.month &&
        localA.day == localB.day;
  }

  Widget _buildEmptyState(String initials) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              backgroundImage: widget.participantAvatarUrl?.isNotEmpty == true
                  ? NetworkImage(widget.participantAvatarUrl!)
                  : null,
              child: widget.participantAvatarUrl?.isNotEmpty == true
                  ? null
                  : Text(
                      initials,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.participantName,
              style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'This is the beginning of your private direct message history with ${widget.participantName}.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline, size: 15, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'Direct conversation · Private and encrypted',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 42, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              'Unable to load this conversation.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
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
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(
            color: AppColors.border.withValues(alpha: 0.8),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppColors.border.withValues(alpha: 0.9),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Focus(
                      onKeyEvent: (node, event) {
                        if (event is KeyDownEvent &&
                            event.logicalKey == LogicalKeyboardKey.enter &&
                            !HardwareKeyboard.instance.isShiftPressed) {
                          _sendMessage();
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: TextField(
                        controller: _messageController,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(
                          hintText: 'Write a message...',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _messageController,
                  builder: (context, value, child) {
                    final canSend = value.text.trim().isNotEmpty && !_isSending;
                    return Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: canSend
                            ? AppColors.primary
                            : AppColors.primary.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                        boxShadow: canSend
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: IconButton(
                        tooltip: 'Send message',
                        padding: EdgeInsets.zero,
                        onPressed: canSend ? _sendMessage : null,
                        icon: _isSending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 19,
                              ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 0,
        elevation: 0.5,
        scrolledUnderElevation: 1,
        actions: [
          IconButton(
            tooltip: 'Delete conversation',
            onPressed: _deleteConversation,
            icon: const Icon(Icons.delete_outline),
          ),
          const SizedBox(width: 8),
        ],
        title: Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              backgroundImage: widget.participantAvatarUrl?.isNotEmpty == true
                  ? NetworkImage(widget.participantAvatarUrl!)
                  : null,
              child: widget.participantAvatarUrl?.isNotEmpty == true
                  ? null
                  : Text(
                      initials,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.participantName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Direct Message',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _loadError != null
                    ? _buildErrorState()
                    : _messages.isEmpty
                    ? _buildEmptyState(initials)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isSent =
                              message.senderId == widget.currentUserId;
                          final showDateDivider = index == 0 ||
                              !_isSameDay(
                                message.createdAt,
                                _messages[index - 1].createdAt,
                              );

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (showDateDivider)
                                _DateDivider(date: message.createdAt),
                              _MessageBubble(
                                message: message,
                                isSent: isSent,
                                canModify: _modifiableMessageIds
                                    .contains(message.id),
                                repository: _repository,
                                onChanged: () => _loadMessages(silent: true),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }
}

class _DateDivider extends StatelessWidget {
  final DateTime date;

  const _DateDivider({required this.date});

  @override
  Widget build(BuildContext context) {
    final localDate = date.toLocal();
    final now = DateTime.now();
    final isToday = localDate.year == now.year &&
        localDate.month == now.month &&
        localDate.day == now.day;
    final isYesterday = localDate.year == now.year &&
        localDate.month == now.month &&
        localDate.day == now.day - 1;

    final String label = isToday
        ? 'Today'
        : isYesterday
            ? 'Yesterday'
            : DateFormat('MMMM d, y').format(localDate);

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 14),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatefulWidget {
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

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  bool _isHovered = false;

  Future<void> _showMenu(BuildContext context, TapDownDetails? details) async {
    if (!widget.canModify || widget.message.isUnsent) return;

    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final position = details != null
        ? RelativeRect.fromRect(
            details.globalPosition & const Size(40, 40),
            Offset.zero & overlay.size,
          )
        : RelativeRect.fromLTRB(
            overlay.size.width - 150,
            overlay.size.height / 2,
            0,
            0,
          );

    final selected = await showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: const [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 18),
              SizedBox(width: 10),
              Text('Edit message'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'unsend',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18, color: AppColors.error),
              SizedBox(width: 10),
              Text('Unsend message', style: TextStyle(color: AppColors.error)),
            ],
          ),
        ),
      ],
    );

    if (!context.mounted) return;
    if (selected == 'edit') _edit(context);
    if (selected == 'unsend') _unsend(context);
  }

  Future<void> _edit(BuildContext context) async {
    final controller = TextEditingController(text: widget.message.body);
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
      await widget.repository.editMessage(
        messageId: widget.message.id,
        body: body,
      );
      widget.onChanged();
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
      await widget.repository.unsendMessage(widget.message.id);
      widget.onChanged();
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
    final maxBubbleWidth =
        (MediaQuery.sizeOf(context).width * 0.72).clamp(240.0, 560.0);
    final isSent = widget.isSent;
    final message = widget.message;

    final bubbleRadius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isSent ? 16 : 4),
      bottomRight: Radius.circular(isSent ? 4 : 16),
    );

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxBubbleWidth),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isSent ? AppColors.primary : AppColors.surface,
        borderRadius: bubbleRadius,
        border: isSent
            ? null
            : Border.all(color: AppColors.border.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: isSent
                ? AppColors.primary.withValues(alpha: 0.18)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message.body,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.35,
              color: isSent ? Colors.white : AppColors.textPrimary,
              fontStyle: message.isUnsent ? FontStyle.italic : null,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.editedAt != null && !message.isUnsent) ...[
                Text(
                  'Edited · ',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w400,
                    color: isSent ? Colors.white70 : AppColors.textMuted,
                  ),
                ),
              ],
              Text(
                DateFormat('h:mm a').format(message.createdAt.toLocal()),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: isSent ? Colors.white70 : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    TapDownDetails? tapDownDetails;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Row(
          mainAxisAlignment:
              isSent ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (isSent && widget.canModify && !message.isUnsent) ...[
              AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: _isHovered ? 1.0 : 0.0,
                child: IconButton(
                  icon: const Icon(Icons.more_horiz, size: 16),
                  color: AppColors.textSecondary,
                  tooltip: 'Message options',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints.tightFor(width: 28, height: 28),
                  onPressed: () => _showMenu(context, null),
                ),
              ),
              const SizedBox(width: 4),
            ],
            GestureDetector(
              onTapDown: (d) => tapDownDetails = d,
              onLongPress: () => _showMenu(context, tapDownDetails),
              onSecondaryTapDown: (d) => _showMenu(context, d),
              child: bubble,
            ),
          ],
        ),
      ),
    );
  }
}
