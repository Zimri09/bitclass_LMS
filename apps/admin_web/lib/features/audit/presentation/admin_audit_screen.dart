import 'package:flutter/material.dart';

import '../../../core/theme/admin_theme.dart';
import '../../../core/widgets/admin_page.dart';
import '../../dashboard/data/admin_models.dart';
import '../../dashboard/data/admin_repository.dart';

class AdminAuditScreen extends StatefulWidget {
  final AdminRepository repository;

  const AdminAuditScreen({super.key, required this.repository});

  @override
  State<AdminAuditScreen> createState() => _AdminAuditScreenState();
}

class _AdminAuditScreenState extends State<AdminAuditScreen> {
  List<AdminAuditLog> _logs = const [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final logs = await widget.repository.fetchAuditLogs();
      if (!mounted) return;
      setState(() => _logs = logs);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Audit history could not be loaded.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPage(
      title: 'Audit log',
      description: 'Review security-sensitive administrator actions recorded by BitClass.',
      action: OutlinedButton.icon(
        onPressed: _isLoading ? null : _load,
        icon: const Icon(Icons.refresh, size: 19),
        label: const Text('Refresh'),
      ),
      child: _isLoading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 100),
              child: Center(child: CircularProgressIndicator()),
            )
          : _error != null
          ? AdminErrorPanel(message: _error!, onRetry: _load)
          : _logs.isEmpty
          ? const AdminEmptyPanel(
              icon: Icons.history_outlined,
              title: 'No administrator actions yet',
              message: 'Role, suspension, and course changes will appear here.',
            )
          : Column(
              children: [
                for (var index = 0; index < _logs.length; index++) ...[
                  _AuditCard(log: _logs[index]),
                  if (index != _logs.length - 1) const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }
}

class _AuditCard extends StatelessWidget {
  final AdminAuditLog log;

  const _AuditCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final target =
        log.newValues['target_email'] ??
        log.newValues['title'] ??
        log.previousValues['title'] ??
        log.targetId ??
        'Unknown target';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AdminColors.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.admin_panel_settings_outlined,
                color: AdminColors.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        log.actionLabel,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      AdminStatusChip(
                        label: log.targetType,
                        color: AdminColors.secondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$target · ${log.actorEmail}',
                    style: const TextStyle(
                      color: AdminColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  if (log.reason?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 8),
                    Text('Reason: ${log.reason}'),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _formatTimestamp(log.createdAt),
              style: const TextStyle(
                color: AdminColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatTimestamp(DateTime? value) {
  if (value == null) return 'Unknown time';
  final local = value.toLocal();
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.month}/${local.day}/${local.year} '
      '${local.hour}:$minute';
}
