import 'package:flutter/material.dart';

import '../../../core/theme/admin_theme.dart';
import '../../../core/widgets/admin_page.dart';
import '../../dashboard/data/admin_repository.dart';
import '../data/admin_support_request.dart';

enum _RequestTypeFilter { all, feedback, bug }

class AdminSupportScreen extends StatefulWidget {
  final AdminRepository repository;

  const AdminSupportScreen({super.key, required this.repository});

  @override
  State<AdminSupportScreen> createState() => _AdminSupportScreenState();
}

class _AdminSupportScreenState extends State<AdminSupportScreen> {
  final _searchController = TextEditingController();
  List<AdminSupportRequest> _requests = const [];
  _RequestTypeFilter _typeFilter = _RequestTypeFilter.all;
  AdminSupportRequestStatus? _statusFilter;
  bool _isLoading = true;
  String _search = '';
  String? _error;

  List<AdminSupportRequest> get _visibleRequests {
    final query = _search.trim().toLowerCase();
    return _requests
        .where((request) {
          final typeMatches = switch (_typeFilter) {
            _RequestTypeFilter.all => true,
            _RequestTypeFilter.feedback =>
              request.type == AdminSupportRequestType.feedback,
            _RequestTypeFilter.bug =>
              request.type == AdminSupportRequestType.bug,
          };
          final statusMatches =
              _statusFilter == null || request.status == _statusFilter;
          final searchMatches =
              query.isEmpty ||
              [
                request.subject,
                request.description,
                request.category,
                request.displayName,
                request.email,
              ].any((value) => value.toLowerCase().contains(query));
          return typeMatches && statusMatches && searchMatches;
        })
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final requests = await widget.repository.fetchSupportRequests();
      if (!mounted) return;
      setState(() => _requests = requests);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Support requests could not be loaded.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _updateStatus(
    AdminSupportRequest request,
    AdminSupportRequestStatus status,
  ) async {
    if (request.status == status) return true;
    try {
      await widget.repository.updateSupportRequestStatus(
        requestId: request.id,
        status: status,
      );
      if (!mounted) return false;
      setState(() {
        _requests = _requests
            .map(
              (item) =>
                  item.id == request.id ? item.copyWith(status: status) : item,
            )
            .toList(growable: false);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request marked ${status.label.toLowerCase()}.'),
        ),
      );
      return true;
    } catch (_) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request status could not be updated.')),
      );
      return false;
    }
  }

  Future<void> _openRequest(AdminSupportRequest request) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _RequestDialog(
        request: request,
        onStatusChanged: (status) async {
          final updated = await _updateStatus(request, status);
          if (updated && dialogContext.mounted) {
            Navigator.of(dialogContext).pop();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleRequests = _visibleRequests;
    return AdminPage(
      title: 'Support inbox',
      description:
          'Review feedback and bug reports submitted from the BitClass app.',
      action: OutlinedButton.icon(
        onPressed: _isLoading ? null : _load,
        icon: const Icon(Icons.refresh, size: 19),
        label: const Text('Refresh'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Summary(requests: _requests),
          const SizedBox(height: 18),
          _Filters(
            searchController: _searchController,
            search: _search,
            typeFilter: _typeFilter,
            statusFilter: _statusFilter,
            onSearchChanged: (value) => setState(() => _search = value),
            onClearSearch: () {
              _searchController.clear();
              setState(() => _search = '');
            },
            onTypeChanged: (value) => setState(() => _typeFilter = value),
            onStatusChanged: (value) => setState(() => _statusFilter = value),
          ),
          const SizedBox(height: 18),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 100),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            AdminErrorPanel(message: _error!, onRetry: _load)
          else if (visibleRequests.isEmpty)
            AdminEmptyPanel(
              icon: Icons.inbox_outlined,
              title: _requests.isEmpty
                  ? 'No support requests yet'
                  : 'No matching requests',
              message: _requests.isEmpty
                  ? 'New feedback and bug reports will appear here.'
                  : 'Adjust the search or filters to see more requests.',
            )
          else
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (
                    var index = 0;
                    index < visibleRequests.length;
                    index++
                  ) ...[
                    _RequestRow(
                      request: visibleRequests[index],
                      onTap: () => _openRequest(visibleRequests[index]),
                    ),
                    if (index != visibleRequests.length - 1) const Divider(),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final List<AdminSupportRequest> requests;

  const _Summary({required this.requests});

  @override
  Widget build(BuildContext context) {
    int count(AdminSupportRequestStatus status) =>
        requests.where((request) => request.status == status).length;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _SummaryItem(label: 'Total', value: requests.length),
        _SummaryItem(
          label: 'Open',
          value: count(AdminSupportRequestStatus.open),
          color: AdminColors.danger,
        ),
        _SummaryItem(
          label: 'In review',
          value: count(AdminSupportRequestStatus.inReview),
          color: AdminColors.primary,
        ),
        _SummaryItem(
          label: 'Resolved',
          value: count(AdminSupportRequestStatus.resolved),
          color: AdminColors.success,
        ),
      ],
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.value,
    this.color = AdminColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 164,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        border: Border.all(color: AdminColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AdminColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  final TextEditingController searchController;
  final String search;
  final _RequestTypeFilter typeFilter;
  final AdminSupportRequestStatus? statusFilter;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<_RequestTypeFilter> onTypeChanged;
  final ValueChanged<AdminSupportRequestStatus?> onStatusChanged;

  const _Filters({
    required this.searchController,
    required this.search,
    required this.typeFilter,
    required this.statusFilter,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onTypeChanged,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 920;
        final searchField = TextField(
          controller: searchController,
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            labelText: 'Search requests',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: search.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: onClearSearch,
                    icon: const Icon(Icons.close),
                  ),
          ),
        );
        final typeControl = SegmentedButton<_RequestTypeFilter>(
          segments: const [
            ButtonSegment(value: _RequestTypeFilter.all, label: Text('All')),
            ButtonSegment(
              value: _RequestTypeFilter.feedback,
              label: Text('Feedback'),
              icon: Icon(Icons.feedback_outlined),
            ),
            ButtonSegment(
              value: _RequestTypeFilter.bug,
              label: Text('Bugs'),
              icon: Icon(Icons.bug_report_outlined),
            ),
          ],
          selected: {typeFilter},
          showSelectedIcon: false,
          onSelectionChanged: (values) => onTypeChanged(values.first),
        );
        final statusControl = DropdownButtonFormField<String>(
          initialValue: statusFilter?.databaseValue ?? 'all',
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Status'),
          items: [
            const DropdownMenuItem(value: 'all', child: Text('All statuses')),
            ...AdminSupportRequestStatus.values.map(
              (status) => DropdownMenuItem(
                value: status.databaseValue,
                child: Text(status.label),
              ),
            ),
          ],
          selectedItemBuilder: (context) => [
            const Text(
              'All statuses',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            ...AdminSupportRequestStatus.values.map(
              (status) => Text(
                status.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          onChanged: (value) => onStatusChanged(
            value == null || value == 'all'
                ? null
                : AdminSupportRequestStatusValue.fromDatabase(value),
          ),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              searchField,
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: typeControl,
              ),
              const SizedBox(height: 12),
              statusControl,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: searchField),
            const SizedBox(width: 14),
            typeControl,
            const SizedBox(width: 14),
            SizedBox(width: 170, child: statusControl),
          ],
        );
      },
    );
  }
}

class _RequestRow extends StatelessWidget {
  final AdminSupportRequest request;
  final VoidCallback onTap;

  const _RequestRow({required this.request, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isBug = request.type == AdminSupportRequestType.bug;
    return InkWell(
      onTap: onTap,
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
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isBug ? Icons.bug_report_outlined : Icons.feedback_outlined,
                color: AdminColors.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    request.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${request.displayName}  |  ${_formatTimestamp(request.createdAt)}',
                    style: const TextStyle(
                      color: AdminColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            AdminStatusChip(
              label: request.status.label,
              color: _statusColor(request.status),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: AdminColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _RequestDialog extends StatefulWidget {
  final AdminSupportRequest request;
  final Future<void> Function(AdminSupportRequestStatus status) onStatusChanged;

  const _RequestDialog({required this.request, required this.onStatusChanged});

  @override
  State<_RequestDialog> createState() => _RequestDialogState();
}

class _RequestDialogState extends State<_RequestDialog> {
  bool _isUpdating = false;

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      request.subject,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: _isUpdating
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        AdminStatusChip(
                          label: request.type == AdminSupportRequestType.bug
                              ? 'Bug report'
                              : 'Feedback',
                          color: AdminColors.primary,
                        ),
                        AdminStatusChip(
                          label: request.category,
                          color: AdminColors.secondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const _DetailLabel('Submitted by'),
                    SelectableText(request.displayName),
                    SelectableText(
                      request.email,
                      style: const TextStyle(color: AdminColors.textSecondary),
                    ),
                    const SizedBox(height: 18),
                    const _DetailLabel('Submitted'),
                    Text(_formatTimestamp(request.createdAt)),
                    const SizedBox(height: 22),
                    _DetailLabel(
                      request.type == AdminSupportRequestType.bug
                          ? 'What happened'
                          : 'Feedback',
                    ),
                    SelectableText(
                      request.description,
                      style: const TextStyle(height: 1.5),
                    ),
                    if (_metadataText(request, 'steps_to_reproduce')
                        case final steps?) ...[
                      const SizedBox(height: 22),
                      const _DetailLabel('Steps to reproduce'),
                      SelectableText(steps),
                    ],
                    if (_metadataText(request, 'expected_result')
                        case final expected?) ...[
                      const SizedBox(height: 22),
                      const _DetailLabel('Expected result'),
                      SelectableText(expected),
                    ],
                    const SizedBox(height: 22),
                    Wrap(
                      spacing: 24,
                      runSpacing: 14,
                      children: [
                        _Metadata(
                          label: 'Platform',
                          value:
                              _metadataText(request, 'platform') ?? 'Unknown',
                        ),
                        _Metadata(
                          label: 'App version',
                          value:
                              _metadataText(request, 'app_version') ??
                              'Unknown',
                        ),
                        _Metadata(label: 'User role', value: request.role),
                        _Metadata(label: 'Request ID', value: request.id),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Text('Status'),
                  const SizedBox(width: 14),
                  Expanded(
                    child: DropdownButtonFormField<AdminSupportRequestStatus>(
                      initialValue: request.status,
                      items: AdminSupportRequestStatus.values
                          .map(
                            (status) => DropdownMenuItem(
                              value: status,
                              child: Text(status.label),
                            ),
                          )
                          .toList(),
                      onChanged: _isUpdating
                          ? null
                          : (status) async {
                              if (status == null || status == request.status) {
                                return;
                              }
                              setState(() => _isUpdating = true);
                              await widget.onStatusChanged(status);
                              if (mounted) setState(() => _isUpdating = false);
                            },
                    ),
                  ),
                  if (_isUpdating) ...[
                    const SizedBox(width: 14),
                    const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailLabel extends StatelessWidget {
  final String text;

  const _DetailLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AdminColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Metadata extends StatelessWidget {
  final String label;
  final String value;

  const _Metadata({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_DetailLabel(label), SelectableText(value, maxLines: 2)],
      ),
    );
  }
}

String? _metadataText(AdminSupportRequest request, String key) {
  final value = request.metadata[key];
  return value is String && value.trim().isNotEmpty ? value.trim() : null;
}

Color _statusColor(AdminSupportRequestStatus status) => switch (status) {
  AdminSupportRequestStatus.open => AdminColors.danger,
  AdminSupportRequestStatus.inReview => AdminColors.primary,
  AdminSupportRequestStatus.resolved => AdminColors.success,
  AdminSupportRequestStatus.closed => AdminColors.textSecondary,
};

String _formatTimestamp(DateTime? value) {
  if (value == null) return 'Unknown time';
  final local = value.toLocal();
  final minute = local.minute.toString().padLeft(2, '0');
  final hour = local.hour == 0
      ? 12
      : local.hour > 12
      ? local.hour - 12
      : local.hour;
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '${local.month}/${local.day}/${local.year} $hour:$minute $period';
}
