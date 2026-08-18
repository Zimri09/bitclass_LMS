import 'package:flutter/material.dart';

import '../../../core/theme/admin_theme.dart';
import '../../../core/widgets/admin_page.dart';
import '../../dashboard/data/admin_models.dart';
import '../../dashboard/data/admin_repository.dart';

class AdminUsersScreen extends StatefulWidget {
  final AdminRepository repository;

  const AdminUsersScreen({super.key, required this.repository});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _searchController = TextEditingController();
  List<AdminAccount> _users = const [];
  bool _isLoading = true;
  String? _error;
  String _role = 'all';

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
      final users = await widget.repository.fetchUsers();
      if (!mounted) return;
      setState(() => _users = users);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Users could not be loaded.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<AdminAccount> get _filteredUsers {
    final query = _searchController.text.trim().toLowerCase();
    return _users
        .where((user) {
          final matchesRole = _role == 'all' || user.role == _role;
          final matchesQuery =
              query.isEmpty ||
              user.displayName.toLowerCase().contains(query) ||
              user.email.toLowerCase().contains(query);
          return matchesRole && matchesQuery;
        })
        .toList(growable: false);
  }

  Future<void> _changeRole(AdminAccount user) async {
    var selectedRole = user.role;
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Change user role'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(user.displayName),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(value: 'student', child: Text('Student')),
                    DropdownMenuItem(
                      value: 'instructor',
                      child: Text('Instructor'),
                    ),
                    DropdownMenuItem(
                      value: 'admin',
                      child: Text('Administrator'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedRole = value);
                    }
                  },
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: reasonController,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Reason (optional)',
                    hintText: 'Why is this role changing?',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selectedRole == user.role
                  ? null
                  : () => Navigator.of(context).pop(true),
              child: const Text('Save role'),
            ),
          ],
        ),
      ),
    );
    final reason = reasonController.text;
    reasonController.dispose();
    if (confirmed != true || !mounted) return;

    await _runUserAction(
      () => widget.repository.setUserRole(
        userId: user.id,
        role: selectedRole,
        reason: reason,
      ),
      successMessage: '${user.displayName} is now a $selectedRole.',
    );
  }

  Future<void> _changeSuspension(AdminAccount user) async {
    final willSuspend = !user.isSuspended;
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(willSuspend ? 'Suspend user?' : 'Restore user?'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                willSuspend
                    ? '${user.displayName} will be blocked from signing in.'
                    : '${user.displayName} will be allowed to sign in again.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                maxLength: 500,
                decoration: InputDecoration(
                  labelText: willSuspend
                      ? 'Reason for suspension'
                      : 'Reason for restoration (optional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(willSuspend ? 'Suspend' : 'Restore'),
          ),
        ],
      ),
    );
    final reason = reasonController.text;
    reasonController.dispose();
    if (confirmed != true || !mounted) return;

    await _runUserAction(
      () => widget.repository.setUserSuspension(
        userId: user.id,
        suspended: willSuspend,
        reason: reason,
      ),
      successMessage: willSuspend
          ? '${user.displayName} was suspended.'
          : '${user.displayName} was restored.',
    );
  }

  Future<void> _runUserAction(
    Future<AdminAccount> Function() action, {
    required String successMessage,
  }) async {
    try {
      final updated = await action();
      if (!mounted) return;
      setState(() {
        _users = [
          for (final user in _users) user.id == updated.id ? updated : user,
        ];
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The secure admin action could not be completed.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPage(
      title: 'Users',
      description:
          'Review registered students, instructors, and administrators.',
      action: OutlinedButton.icon(
        onPressed: _isLoading ? null : _load,
        icon: const Icon(Icons.refresh, size: 19),
        label: const Text('Refresh'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _UserFilters(
            controller: _searchController,
            role: _role,
            onSearchChanged: (_) => setState(() {}),
            onRoleChanged: (value) => setState(() => _role = value),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 100),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            AdminErrorPanel(message: _error!, onRetry: _load)
          else if (_filteredUsers.isEmpty)
            const AdminEmptyPanel(
              icon: Icons.person_search_outlined,
              title: 'No matching users',
              message: 'Try a different search or role filter.',
            )
          else
            _UsersCollection(
              users: _filteredUsers,
              onChangeRole: _changeRole,
              onChangeSuspension: _changeSuspension,
            ),
          if (!_isLoading && _error == null) ...[
            const SizedBox(height: 12),
            Text(
              'Showing ${_filteredUsers.length} of ${_users.length} loaded users. '
              'Sensitive changes run through the verified admin service.',
              style: const TextStyle(
                color: AdminColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UserFilters extends StatelessWidget {
  final TextEditingController controller;
  final String role;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onRoleChanged;

  const _UserFilters({
    required this.controller,
    required this.role,
    required this.onSearchChanged,
    required this.onRoleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 14,
          runSpacing: 14,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: TextField(
                controller: controller,
                onChanged: onSearchChanged,
                decoration: const InputDecoration(
                  hintText: 'Search name or email…',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            for (final value in const [
              ('all', 'All'),
              ('student', 'Students'),
              ('instructor', 'Instructors'),
              ('admin', 'Admins'),
            ])
              ChoiceChip(
                label: Text(value.$2),
                selected: role == value.$1,
                onSelected: (_) => onRoleChanged(value.$1),
              ),
          ],
        ),
      ),
    );
  }
}

class _UsersCollection extends StatelessWidget {
  final List<AdminAccount> users;
  final ValueChanged<AdminAccount> onChangeRole;
  final ValueChanged<AdminAccount> onChangeSuspension;

  const _UsersCollection({
    required this.users,
    required this.onChangeRole,
    required this.onChangeSuspension,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 820) {
          return Column(
            children: [
              for (var index = 0; index < users.length; index++) ...[
                _UserCard(
                  user: users[index],
                  onChangeRole: onChangeRole,
                  onChangeSuspension: onChangeSuspension,
                ),
                if (index != users.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        }

        return Card(
          child: SizedBox(
            width: constraints.maxWidth,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('USER')),
                DataColumn(label: Text('ROLE')),
                DataColumn(label: Text('JOINED')),
                DataColumn(label: Text('ACCESS')),
              ],
              rows: [for (final user in users) _userRow(user)],
            ),
          ),
        );
      },
    );
  }

  DataRow _userRow(AdminAccount user) {
    return DataRow(
      cells: [
        DataCell(
          Row(
            children: [
              _UserAvatar(user: user),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AdminColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        DataCell(
          Wrap(
            spacing: 6,
            children: [
              AdminStatusChip(label: user.role, color: _roleColor(user.role)),
              if (user.isSuspended)
                const AdminStatusChip(
                  label: 'Suspended',
                  color: AdminColors.danger,
                ),
            ],
          ),
        ),
        DataCell(Text(_formatDate(user.createdAt))),
        DataCell(
          _UserActions(
            user: user,
            onChangeRole: onChangeRole,
            onChangeSuspension: onChangeSuspension,
          ),
        ),
      ],
    );
  }
}

class _UserCard extends StatelessWidget {
  final AdminAccount user;
  final ValueChanged<AdminAccount> onChangeRole;
  final ValueChanged<AdminAccount> onChangeSuspension;

  const _UserCard({
    required this.user,
    required this.onChangeRole,
    required this.onChangeSuspension,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _UserAvatar(user: user),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      AdminStatusChip(
                        label: user.role,
                        color: _roleColor(user.role),
                      ),
                      Text(
                        'Joined ${_formatDate(user.createdAt)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _UserActions(
              user: user,
              onChangeRole: onChangeRole,
              onChangeSuspension: onChangeSuspension,
            ),
          ],
        ),
      ),
    );
  }
}

enum _UserAction { changeRole, changeSuspension }

class _UserActions extends StatelessWidget {
  final AdminAccount user;
  final ValueChanged<AdminAccount> onChangeRole;
  final ValueChanged<AdminAccount> onChangeSuspension;

  const _UserActions({
    required this.user,
    required this.onChangeRole,
    required this.onChangeSuspension,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_UserAction>(
      tooltip: 'Manage ${user.displayName}',
      onSelected: (action) {
        switch (action) {
          case _UserAction.changeRole:
            onChangeRole(user);
          case _UserAction.changeSuspension:
            onChangeSuspension(user);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: _UserAction.changeRole,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.manage_accounts_outlined),
            title: Text('Change role'),
          ),
        ),
        PopupMenuItem(
          value: _UserAction.changeSuspension,
          child: ListTile(
            dense: true,
            leading: Icon(
              user.isSuspended
                  ? Icons.person_add_alt_outlined
                  : Icons.block_outlined,
            ),
            title: Text(user.isSuspended ? 'Restore access' : 'Suspend access'),
          ),
        ),
      ],
      icon: const Icon(Icons.more_vert),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final AdminAccount user;

  const _UserAvatar({required this.user});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundColor: _roleColor(user.role).withValues(alpha: 0.12),
      foregroundColor: _roleColor(user.role),
      child: Text(
        user.displayName.substring(0, 1).toUpperCase(),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}

Color _roleColor(String role) {
  return switch (role) {
    'admin' => const Color(0xFF9B7EDE),
    'instructor' => AdminColors.primary,
    _ => AdminColors.secondary,
  };
}

String _formatDate(DateTime? value) {
  if (value == null) return 'Unknown';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[value.month - 1]} ${value.day}, ${value.year}';
}
