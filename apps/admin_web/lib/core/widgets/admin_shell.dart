import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/dashboard/data/admin_models.dart';
import '../auth/admin_session_controller.dart';
import '../theme/admin_theme.dart';
import 'admin_brand_logo.dart';

class AdminShell extends StatelessWidget {
  final AdminSessionController session;
  final String currentPath;
  final Widget child;

  const AdminShell({
    super.key,
    required this.session,
    required this.currentPath,
    required this.child,
  });

  static const _destinations = <_AdminDestination>[
    _AdminDestination(
      path: '/overview',
      label: 'Overview',
      icon: Icons.space_dashboard_outlined,
      selectedIcon: Icons.space_dashboard,
    ),
    _AdminDestination(
      path: '/users',
      label: 'Users',
      icon: Icons.group_outlined,
      selectedIcon: Icons.group,
    ),
    _AdminDestination(
      path: '/courses',
      label: 'Courses',
      icon: Icons.menu_book_outlined,
      selectedIcon: Icons.menu_book,
    ),
    _AdminDestination(
      path: '/audit',
      label: 'Audit log',
      icon: Icons.history_outlined,
      selectedIcon: Icons.history,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            SizedBox(
              width: 260,
              child: _AdminNavigation(
                session: session,
                currentPath: currentPath,
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  _AdminTopBar(session: session),
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AdminColors.navigation,
        surfaceTintColor: Colors.transparent,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdminBrandLogo(size: 32, borderRadius: 7),
            SizedBox(width: 10),
            Text(
              'BitClass Admin',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        actions: [_AccountMenu(session: session)],
      ),
      drawer: Drawer(
        width: 280,
        child: _AdminNavigation(
          session: session,
          currentPath: currentPath,
          closeOnNavigate: true,
        ),
      ),
      body: child,
    );
  }
}

class _AdminNavigation extends StatelessWidget {
  final AdminSessionController session;
  final String currentPath;
  final bool closeOnNavigate;

  const _AdminNavigation({
    required this.session,
    required this.currentPath,
    this.closeOnNavigate = false,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AdminColors.navigation,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 24, 22, 28),
              child: Row(
                children: [
                  _SidebarBrandMark(),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BitClass',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'ADMIN CONSOLE',
                        style: TextStyle(
                          color: AdminColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 22),
              child: Text(
                'WORKSPACE',
                style: TextStyle(
                  color: AdminColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 10),
            for (final destination in AdminShell._destinations)
              _NavigationTile(
                destination: destination,
                selected: currentPath == destination.path,
                onTap: () {
                  if (closeOnNavigate) Navigator.of(context).pop();
                  context.go(destination.path);
                },
              ),
            const Spacer(),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: _SidebarAccount(
                account: session.account,
                onSignOut: session.signOut,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigationTile extends StatelessWidget {
  final _AdminDestination destination;
  final bool selected;
  final VoidCallback onTap;

  const _NavigationTile({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: selected ? AdminColors.primarySoft : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  size: 21,
                  color: selected
                      ? AdminColors.primary
                      : AdminColors.textSecondary,
                ),
                const SizedBox(width: 14),
                Text(
                  destination.label,
                  style: TextStyle(
                    color: selected
                        ? AdminColors.textPrimary
                        : AdminColors.textSecondary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminTopBar extends StatelessWidget {
  final AdminSessionController session;

  const _AdminTopBar({required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: AdminColors.background,
        border: Border(bottom: BorderSide(color: AdminColors.border)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.shield_outlined,
            size: 18,
            color: AdminColors.success,
          ),
          const SizedBox(width: 9),
          const Text(
            'Administrator session',
            style: TextStyle(color: AdminColors.textSecondary, fontSize: 13),
          ),
          const Spacer(),
          _AccountMenu(session: session),
        ],
      ),
    );
  }
}

class _AccountMenu extends StatelessWidget {
  final AdminSessionController session;

  const _AccountMenu({required this.session});

  @override
  Widget build(BuildContext context) {
    final account = session.account;
    return PopupMenuButton<String>(
      tooltip: 'Account menu',
      onSelected: (value) {
        if (value == 'sign-out') session.signOut();
      },
      itemBuilder: (context) => [
        if (account != null)
          PopupMenuItem(
            enabled: false,
            child: SizedBox(
              width: 220,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    account.email,
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
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'sign-out',
          child: Row(
            children: [
              Icon(Icons.logout, size: 18),
              SizedBox(width: 10),
              Text('Sign out'),
            ],
          ),
        ),
      ],
      child: _AccountAvatar(account: account),
    );
  }
}

class _SidebarAccount extends StatelessWidget {
  final AdminAccount? account;
  final VoidCallback onSignOut;

  const _SidebarAccount({required this.account, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _AccountAvatar(account: account),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                account?.displayName ?? 'Administrator',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                account?.email ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AdminColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Sign out',
          onPressed: onSignOut,
          icon: const Icon(Icons.logout, size: 19),
        ),
      ],
    );
  }
}

class _AccountAvatar extends StatelessWidget {
  final AdminAccount? account;

  const _AccountAvatar({required this.account});

  @override
  Widget build(BuildContext context) {
    final label = account?.displayName.trim() ?? '';
    return CircleAvatar(
      radius: 18,
      backgroundColor: AdminColors.primarySoft,
      foregroundColor: AdminColors.primary,
      child: Text(
        label.isEmpty ? 'A' : label.substring(0, 1).toUpperCase(),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _SidebarBrandMark extends StatelessWidget {
  const _SidebarBrandMark();

  @override
  Widget build(BuildContext context) {
    return const AdminBrandLogo(size: 40, borderRadius: 10);
  }
}

class _AdminDestination {
  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const _AdminDestination({
    required this.path,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}
