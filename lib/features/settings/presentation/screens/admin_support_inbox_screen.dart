import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../data/models/support_request.dart';
import '../../data/repositories/support_repository.dart';

enum _SupportTypeFilter { all, feedback, bug }

class AdminSupportInboxScreen extends StatefulWidget {
  const AdminSupportInboxScreen({super.key});

  @override
  State<AdminSupportInboxScreen> createState() =>
      _AdminSupportInboxScreenState();
}

class _AdminSupportInboxScreenState extends State<AdminSupportInboxScreen> {
  final _searchController = TextEditingController();
  List<SupportRequestRecord> _requests = const [];
  _SupportTypeFilter _typeFilter = _SupportTypeFilter.all;
  SupportRequestStatus? _statusFilter;
  String? _selectedRequestId;
  String? _updatingRequestId;
  String _searchQuery = '';
  String? _errorMessage;
  bool _isLoading = true;

  SupportRequestRecord? get _selectedRequest {
    final id = _selectedRequestId;
    if (id == null) return null;
    for (final request in _requests) {
      if (request.id == id) return request;
    }
    return null;
  }

  List<SupportRequestRecord> get _filteredRequests {
    final query = _searchQuery.trim().toLowerCase();
    return _requests.where((request) {
      final typeMatches = switch (_typeFilter) {
        _SupportTypeFilter.all => true,
        _SupportTypeFilter.feedback =>
          request.type == SupportRequestType.feedback,
        _SupportTypeFilter.bug => request.type == SupportRequestType.bug,
      };
      final statusMatches =
          _statusFilter == null || request.status == _statusFilter;
      final queryMatches =
          query.isEmpty ||
          [
            request.subject,
            request.description,
            request.category,
            request.userDisplayName,
            request.userEmail ?? '',
          ].any((value) => value.toLowerCase().contains(query));
      return typeMatches && statusMatches && queryMatches;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final requests = await context.read<SupportRepository>().getRequests();
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _selectedRequestId =
            requests.any((request) => request.id == _selectedRequestId)
            ? _selectedRequestId
            : (requests.isEmpty ? null : requests.first.id);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load support requests.';
      });
    }
  }

  Future<void> _updateStatus(
    SupportRequestRecord request,
    SupportRequestStatus status,
  ) async {
    if (_updatingRequestId != null || request.status == status) return;

    setState(() => _updatingRequestId = request.id);
    try {
      await context.read<SupportRepository>().updateStatus(request.id, status);
      if (!mounted) return;
      setState(() {
        _requests = _requests
            .map(
              (item) =>
                  item.id == request.id ? item.copyWith(status: status) : item,
            )
            .toList();
        _updatingRequestId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request marked ${status.label.toLowerCase()}.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _updatingRequestId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update the request status.')),
      );
    }
  }

  void _selectRequest(SupportRequestRecord request, bool isCompact) {
    setState(() => _selectedRequestId = request.id);
    if (!isCompact) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.94,
        child: _RequestDetail(
          request: request,
          isUpdating: _updatingRequestId == request.id,
          onStatusChanged: (status) async {
            await _updateStatus(request, status);
            if (context.mounted) Navigator.pop(context);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final requests = _filteredRequests;
    return Scaffold(
      appBar: AppBar(
        leading: const AppDrawerButton(),
        title: Text('Support Inbox', style: AppTextStyles.h3),
        actions: [
          IconButton(
            tooltip: 'Refresh requests',
            onPressed: _isLoading ? null : _loadRequests,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1440),
          child: Column(
            children: [
              _SummaryBar(requests: _requests),
              Divider(height: 1, color: colors.outlineVariant),
              _FilterBar(
                searchController: _searchController,
                searchQuery: _searchQuery,
                typeFilter: _typeFilter,
                statusFilter: _statusFilter,
                onSearchChanged: (value) =>
                    setState(() => _searchQuery = value),
                onClearSearch: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                onTypeChanged: (value) => setState(() => _typeFilter = value),
                onStatusChanged: (value) =>
                    setState(() => _statusFilter = value),
              ),
              Divider(height: 1, color: colors.outlineVariant),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 900;
                    if (_isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (_errorMessage != null) {
                      return _InboxError(
                        message: _errorMessage!,
                        onRetry: _loadRequests,
                      );
                    }
                    if (requests.isEmpty) {
                      return _EmptyInbox(hasFilters: _requests.isNotEmpty);
                    }

                    final requestList = _RequestList(
                      requests: requests,
                      selectedRequestId: _selectedRequestId,
                      onRefresh: _loadRequests,
                      onSelected: (request) =>
                          _selectRequest(request, isCompact),
                    );
                    if (isCompact) return requestList;

                    return Row(
                      children: [
                        SizedBox(width: 430, child: requestList),
                        VerticalDivider(width: 1, color: colors.outlineVariant),
                        Expanded(
                          child: _selectedRequest == null
                              ? const _SelectRequestPrompt()
                              : _RequestDetail(
                                  request: _selectedRequest!,
                                  isUpdating:
                                      _updatingRequestId ==
                                      _selectedRequest!.id,
                                  onStatusChanged: (status) =>
                                      _updateStatus(_selectedRequest!, status),
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  final List<SupportRequestRecord> requests;

  const _SummaryBar({required this.requests});

  @override
  Widget build(BuildContext context) {
    int count(SupportRequestStatus status) =>
        requests.where((request) => request.status == status).length;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          _Metric(label: 'Total', value: requests.length),
          _Metric(
            label: 'Open',
            value: count(SupportRequestStatus.open),
            color: Theme.of(context).colorScheme.error,
          ),
          _Metric(
            label: 'In Review',
            value: count(SupportRequestStatus.inReview),
          ),
          _Metric(
            label: 'Resolved',
            value: count(SupportRequestStatus.resolved),
            color: Colors.green,
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final int value;
  final Color? color;

  const _Metric({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 132,
      child: Row(
        children: [
          Text(
            '$value',
            style: AppTextStyles.h3.copyWith(color: color ?? colors.primary),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final _SupportTypeFilter typeFilter;
  final SupportRequestStatus? statusFilter;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<_SupportTypeFilter> onTypeChanged;
  final ValueChanged<SupportRequestStatus?> onStatusChanged;

  const _FilterBar({
    required this.searchController,
    required this.searchQuery,
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
        final compact = constraints.maxWidth < 980;
        final search = TextField(
          controller: searchController,
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            labelText: 'Search requests',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: searchQuery.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: onClearSearch,
                    icon: const Icon(Icons.close),
                  ),
          ),
        );
        final typeControl = SegmentedButton<_SupportTypeFilter>(
          segments: const [
            ButtonSegment(value: _SupportTypeFilter.all, label: Text('All')),
            ButtonSegment(
              value: _SupportTypeFilter.feedback,
              label: Text('Feedback'),
              icon: Icon(Icons.feedback_outlined),
            ),
            ButtonSegment(
              value: _SupportTypeFilter.bug,
              label: Text('Bugs'),
              icon: Icon(Icons.bug_report_outlined),
            ),
          ],
          selected: {typeFilter},
          showSelectedIcon: false,
          onSelectionChanged: (selection) => onTypeChanged(selection.first),
        );
        final statusControl = DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: statusFilter?.databaseValue ?? 'all',
          decoration: const InputDecoration(labelText: 'Status'),
          items: [
            const DropdownMenuItem<String>(
              value: 'all',
              child: Text('All statuses'),
            ),
            ...SupportRequestStatus.values.map(
              (status) => DropdownMenuItem<String>(
                value: status.databaseValue,
                child: Text(status.label),
              ),
            ),
          ],
          onChanged: (value) {
            if (value == null || value == 'all') {
              onStatusChanged(null);
              return;
            }
            onStatusChanged(SupportRequestStatusValue.fromDatabase(value));
          },
        );

        if (compact) {
          return Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                search,
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: typeControl,
                ),
                const SizedBox(height: 12),
                statusControl,
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: 14),
              typeControl,
              const SizedBox(width: 14),
              SizedBox(width: 170, child: statusControl),
            ],
          ),
        );
      },
    );
  }
}

class _RequestList extends StatelessWidget {
  final List<SupportRequestRecord> requests;
  final String? selectedRequestId;
  final Future<void> Function() onRefresh;
  final ValueChanged<SupportRequestRecord> onSelected;

  const _RequestList({
    required this.requests,
    required this.selectedRequestId,
    required this.onRefresh,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: requests.length,
        separatorBuilder: (_, _) =>
            Divider(height: 1, color: colors.outlineVariant),
        itemBuilder: (context, index) {
          final request = requests[index];
          final selected = request.id == selectedRequestId;
          return Material(
            color: selected
                ? colors.primaryContainer.withValues(alpha: 0.4)
                : Colors.transparent,
            child: InkWell(
              onTap: () => onSelected(request),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TypeIcon(type: request.type),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  request.subject,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _StatusDot(status: request.status),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            request.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 9),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  request.userDisplayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.caption,
                                ),
                              ),
                              Text(
                                DateFormat('MMM d').format(request.createdAt),
                                style: AppTextStyles.caption.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
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
}

class _RequestDetail extends StatelessWidget {
  final SupportRequestRecord request;
  final bool isUpdating;
  final ValueChanged<SupportRequestStatus> onStatusChanged;

  const _RequestDetail({
    required this.request,
    required this.isUpdating,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TypeIcon(type: request.type, large: true),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(request.subject, style: AppTextStyles.h3),
                  const SizedBox(height: 6),
                  Text(
                    '${request.type == SupportRequestType.bug ? 'Bug report' : 'Feedback'} - ${request.category}',
                    style: AppTextStyles.caption.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 150,
              child: DropdownButtonFormField<SupportRequestStatus>(
                key: ValueKey('${request.id}-${request.status.databaseValue}'),
                isExpanded: true,
                initialValue: request.status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: SupportRequestStatus.values
                    .map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(status.label),
                      ),
                    )
                    .toList(),
                onChanged: isUpdating
                    ? null
                    : (status) {
                        if (status != null) onStatusChanged(status);
                      },
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Divider(color: colors.outlineVariant),
        const SizedBox(height: 18),
        _DetailLabel('Submitted by'),
        SelectableText(request.userDisplayName),
        if (request.userEmail != null) ...[
          const SizedBox(height: 4),
          SelectableText(
            request.userEmail!,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 18),
        _DetailLabel('Submitted'),
        Text(DateFormat('MMM d, yyyy - h:mm a').format(request.createdAt)),
        const SizedBox(height: 22),
        _DetailLabel(
          request.type == SupportRequestType.bug ? 'What happened' : 'Feedback',
        ),
        SelectableText(
          request.description,
          style: AppTextStyles.bodyMedium.copyWith(height: 1.55),
        ),
        if (_metadataText(request, 'steps_to_reproduce') case final steps?) ...[
          const SizedBox(height: 22),
          const _DetailLabel('Steps to reproduce'),
          SelectableText(steps, style: const TextStyle(height: 1.5)),
        ],
        if (_metadataText(request, 'expected_result') case final expected?) ...[
          const SizedBox(height: 22),
          const _DetailLabel('Expected result'),
          SelectableText(expected, style: const TextStyle(height: 1.5)),
        ],
        const SizedBox(height: 26),
        Divider(color: colors.outlineVariant),
        const SizedBox(height: 16),
        Wrap(
          spacing: 20,
          runSpacing: 10,
          children: [
            _MetadataItem(
              label: 'Platform',
              value: _metadataText(request, 'platform') ?? 'Unknown',
            ),
            _MetadataItem(
              label: 'App version',
              value: _metadataText(request, 'app_version') ?? 'Unknown',
            ),
            _MetadataItem(
              label: 'User role',
              value: request.userRole ?? 'Unknown',
            ),
            _MetadataItem(label: 'Request ID', value: request.id),
          ],
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  static String? _metadataText(SupportRequestRecord request, String key) {
    final value = request.metadata[key];
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }
}

class _DetailLabel extends StatelessWidget {
  final String text;

  const _DetailLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        text.toUpperCase(),
        style: AppTextStyles.caption.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MetadataItem extends StatelessWidget {
  final String label;
  final String value;

  const _MetadataItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_DetailLabel(label), SelectableText(value, maxLines: 2)],
      ),
    );
  }
}

class _TypeIcon extends StatelessWidget {
  final SupportRequestType type;
  final bool large;

  const _TypeIcon({required this.type, this.large = false});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: large ? 46 : 34,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          type == SupportRequestType.bug
              ? Icons.bug_report_outlined
              : Icons.feedback_outlined,
          size: large ? 25 : 19,
          color: colors.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final SupportRequestStatus status;

  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = switch (status) {
      SupportRequestStatus.open => colors.error,
      SupportRequestStatus.inReview => colors.primary,
      SupportRequestStatus.resolved => Colors.green,
      SupportRequestStatus.closed => colors.outline,
    };
    return Tooltip(
      message: status.label,
      child: Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _SelectRequestPrompt extends StatelessWidget {
  const _SelectRequestPrompt();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 44, color: colors.onSurfaceVariant),
          const SizedBox(height: 12),
          const Text('Select a request to review'),
        ],
      ),
    );
  }
}

class _EmptyInbox extends StatelessWidget {
  final bool hasFilters;

  const _EmptyInbox({required this.hasFilters});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasFilters ? Icons.filter_alt_off : Icons.inbox_outlined,
            size: 44,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            hasFilters ? 'No requests match these filters.' : 'Inbox is empty.',
          ),
        ],
      ),
    );
  }
}

class _InboxError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _InboxError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 44),
          const SizedBox(height: 12),
          Text(message),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
