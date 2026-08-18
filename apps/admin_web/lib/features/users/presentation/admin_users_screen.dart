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
            _UsersCollection(users: _filteredUsers),
          if (!_isLoading && _error == null) ...[
            const SizedBox(height: 12),
            Text(
              'Showing ${_filteredUsers.length} of ${_users.length} loaded users. '
              'Role changes remain server-controlled.',
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

  const _UsersCollection({required this.users});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 820) {
          return Column(
            children: [
              for (var index = 0; index < users.length; index++) ...[
                _UserCard(user: users[index]),
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
          AdminStatusChip(label: user.role, color: _roleColor(user.role)),
        ),
        DataCell(Text(_formatDate(user.createdAt))),
        const DataCell(
          Tooltip(
            message: 'Role changes require a secure server action',
            child: Icon(Icons.lock_outline, size: 18),
          ),
        ),
      ],
    );
  }
}

class _UserCard extends StatelessWidget {
  final AdminAccount user;

  const _UserCard({required this.user});

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
          ],
        ),
      ),
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
