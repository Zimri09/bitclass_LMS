import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/back_navigation_controller.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';

/// Responsive breakpoints
class _Breakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
}

/// Main application shell with responsive navigation.
/// - Mobile (<600px): Google Classroom-style navigation drawer
/// - Tablet (600–900px): Collapsed rail sidebar (72px)
/// - Desktop (>900px): Expanded sidebar (260px)
class AppShell extends StatefulWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  State<AppShell> createState() => _AppShellState();

  /// Opens the shell drawer from a screen nested inside its own [Scaffold].
  static void openDrawer(BuildContext context) {
    final drawerScope = context
        .dependOnInheritedWidgetOfExactType<_AppShellDrawerScope>();
    drawerScope?.scaffoldKey.currentState?.openDrawer();
  }
}

/// Use this in a primary screen app bar to open the application navigation.
class AppDrawerButton extends StatelessWidget {
  const AppDrawerButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.menu),
      tooltip: 'Open navigation',
      onPressed: () => AppShell.openDrawer(context),
    );
  }
}

class _AppShellState extends State<AppShell> {
  bool _isExpanded = true;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _backNavigation = BackNavigationController();
  String? _lastObservedPath;
  Timer? _offlineRetryTimer;

  @override
  void dispose() {
    _offlineRetryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final isInstructor =
        authState is AuthAuthenticated && authState.user.role == 'instructor';
    final isOffline = authState is AuthAuthenticated && authState.isOffline;
    _syncOfflineRetry(isOffline);
    final width = MediaQuery.sizeOf(context).width;
    final currentPath = GoRouterState.of(context).matchedLocation;
    if (_lastObservedPath != currentPath) {
      _lastObservedPath = currentPath;
      _backNavigation.reset();
    }

    final layout = width < _Breakpoints.mobile
        ? _buildMobileLayout(context, isInstructor, isOffline)
        : width < _Breakpoints.tablet
        ? _buildTabletLayout(context, isInstructor, isOffline)
        : _buildDesktopLayout(context, isInstructor, isOffline);
    final canPop = GoRouter.of(context).canPop();

    return PopScope<Object?>(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _backNavigation.reset();
          return;
        }
        _handleRootBack(context);
      },
      child: layout,
    );
  }

  void _syncOfflineRetry(bool isOffline) {
    if (!isOffline) {
      _offlineRetryTimer?.cancel();
      _offlineRetryTimer = null;
      return;
    }
    _offlineRetryTimer ??= Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated && authState.isOffline) {
        context.read<AuthBloc>().add(AuthCheckRequested());
      }
    });
  }

  void _handleRootBack(BuildContext context) {
    final currentPath = GoRouterState.of(context).matchedLocation;
    final action = _backNavigation.handle(
      isHome:
          currentPath == AppRoutes.dashboard ||
          currentPath == AppRoutes.courses,
    );

    switch (action) {
      case RootBackAction.navigateHome:
        context.go(AppRoutes.dashboard);
      case RootBackAction.promptExit:
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit BitClass.'),
              duration: Duration(seconds: 2),
            ),
          );
      case RootBackAction.exitApp:
        SystemNavigator.pop();
    }
  }

  void _openDestination(BuildContext context, {required String destination}) {
    final authState = context.read<AuthBloc>().state;
    final isOffline = authState is AuthAuthenticated && authState.isOffline;
    final isOfflineDestination =
        destination == AppRoutes.dashboard ||
        destination == AppRoutes.courses ||
        destination == AppRoutes.offlineFiles;
    if (isOffline && !isOfflineDestination) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'This feature needs an internet connection. Offline Files are still available.',
            ),
          ),
        );
      return;
    }
    _backNavigation.reset();
    final currentPath = GoRouterState.of(context).matchedLocation;
    if (destination == AppRoutes.dashboard) {
      context.go(AppRoutes.dashboard);
      return;
    }
    if (currentPath == destination) return;
    context.push(destination);
  }

  bool _isDestinationActive(_NavItem item, String currentPath) {
    if (item.path == AppRoutes.dashboard) {
      return currentPath == AppRoutes.dashboard ||
          currentPath == AppRoutes.courses;
    }
    return currentPath == item.path || currentPath.startsWith('${item.path}/');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Mobile layout — Google Classroom-style drawer navigation
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMobileLayout(
    BuildContext context,
    bool isInstructor,
    bool isOffline,
  ) {
    return Scaffold(
      key: _scaffoldKey,
      body: _AppShellDrawerScope(
        scaffoldKey: _scaffoldKey,
        child: widget.child,
      ),
      drawer: _buildDrawer(context, isInstructor, isOffline),
    );
  }

  Widget _buildDrawer(BuildContext context, bool isInstructor, bool isOffline) {
    final currentPath = GoRouterState.of(context).matchedLocation;
    final colors = AppColors.of(context);

    return Drawer(
      backgroundColor: colors.backgroundSecondary,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            _buildExpandedHeader(),
            Divider(),

            // All nav items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  ..._getAllNavItems(isInstructor, isOffline).map(
                    (item) => _buildDrawerNavItem(
                      context: context,
                      item: item,
                      currentPath: currentPath,
                    ),
                  ),
                ],
              ),
            ),

            Divider(),
            _buildLogoutButton(context, expanded: true),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerNavItem({
    required BuildContext context,
    required _NavItem item,
    required String currentPath,
  }) {
    final colors = AppColors.of(context);

    if (item.isSectionHeader) {
      return Padding(
        padding: const EdgeInsets.only(left: 12, top: 20, bottom: 8),
        child: Text(
          item.label,
          style: AppTextStyles.caption.copyWith(
            letterSpacing: 1,
            fontWeight: FontWeight.w600,
            color: colors.textMuted,
          ),
        ),
      );
    }

    final isActive = _isDestinationActive(item, currentPath);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () {
            _scaffoldKey.currentState?.closeDrawer();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _openDestination(this.context, destination: item.path);
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(
                  isActive ? item.activeIcon : item.icon,
                  color: isActive ? AppColors.primary : colors.textSecondary,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style:
                        (isActive
                                ? AppTextStyles.navItemActive
                                : AppTextStyles.navItem)
                            .copyWith(
                              color: isActive
                                  ? AppColors.primary
                                  : colors.textSecondary,
                            ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Tablet layout — collapsed rail sidebar (72px)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTabletLayout(
    BuildContext context,
    bool isInstructor,
    bool isOffline,
  ) {
    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 72,
            child: _buildSidebar(
              context,
              isInstructor,
              isOffline,
              expanded: false,
            ),
          ),
          Expanded(child: widget.child),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Desktop layout — expandable sidebar
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildDesktopLayout(
    BuildContext context,
    bool isInstructor,
    bool isOffline,
  ) {
    return Scaffold(
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _isExpanded ? 260 : 72,
            child: _buildSidebar(
              context,
              isInstructor,
              isOffline,
              expanded: _isExpanded,
            ),
          ),
          Expanded(child: widget.child),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Shared sidebar (tablet rail / desktop expanded)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSidebar(
    BuildContext context,
    bool isInstructor,
    bool isOffline, {
    required bool expanded,
  }) {
    final currentPath = GoRouterState.of(context).matchedLocation;
    final colors = AppColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.backgroundSecondary,
        border: Border(right: BorderSide(color: colors.border, width: 1)),
      ),
      child: Column(
        children: [
          // Logo/Brand
          expanded ? _buildExpandedHeader() : _buildCollapsedHeader(),
          const SizedBox(height: 8),
          Divider(),
          const SizedBox(height: 8),

          // Navigation items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final item in _getAllNavItems(isInstructor, isOffline))
                  _buildSidebarNavItem(
                    context: context,
                    item: item,
                    currentPath: currentPath,
                    expanded: expanded,
                  ),
              ],
            ),
          ),

          // Bottom section
          Divider(),
          _buildLogoutButton(context, expanded: expanded),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Header widgets
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCollapsedHeader() {
    return GestureDetector(
      onTap: () => setState(() => _isExpanded = true),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.center,
        child: _buildLogo(),
      ),
    );
  }

  Widget _buildExpandedHeader() {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildLogo(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BitClass',
                  style: AppTextStyles.h4.copyWith(color: colors.textPrimary),
                ),
                Text(
                  'Learn to Code',
                  style: AppTextStyles.caption.copyWith(
                    color: colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          // Only show collapse on desktop
          if (MediaQuery.sizeOf(context).width >= _Breakpoints.tablet)
            IconButton(
              icon: Icon(Icons.chevron_left, color: colors.textSecondary),
              onPressed: () => setState(() => _isExpanded = false),
              tooltip: 'Collapse',
            ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppColors.glowPrimary,
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(Icons.code, color: AppColors.background, size: 24),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Navigation items
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSidebarNavItem({
    required BuildContext context,
    required _NavItem item,
    required String currentPath,
    required bool expanded,
  }) {
    final isActive = _isDestinationActive(item, currentPath);
    final colors = AppColors.of(context);

    if (item.isSectionHeader) {
      if (!expanded) return const SizedBox(height: 16);
      return Padding(
        padding: const EdgeInsets.only(left: 12, top: 16, bottom: 8),
        child: Text(
          item.label,
          style: AppTextStyles.caption.copyWith(
            letterSpacing: 1,
            fontWeight: FontWeight.w600,
            color: colors.textMuted,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => _openDestination(context, destination: item.path),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: expanded ? 12 : 0,
              vertical: 12,
            ),
            child: Row(
              mainAxisAlignment: expanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Icon(
                  isActive ? item.activeIcon : item.icon,
                  color: isActive ? AppColors.primary : colors.textSecondary,
                  size: 22,
                ),
                if (expanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.label,
                      style:
                          (isActive
                                  ? AppTextStyles.navItemActive
                                  : AppTextStyles.navItem)
                              .copyWith(
                                color: isActive
                                    ? AppColors.primary
                                    : colors.textSecondary,
                              ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, {required bool expanded}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () {
            context.read<AuthBloc>().add(AuthLogoutRequested());
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: expanded ? 12 : 0,
              vertical: 12,
            ),
            child: Row(
              mainAxisAlignment: expanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Icon(Icons.logout, color: AppColors.error, size: 22),
                if (expanded) ...[
                  const SizedBox(width: 12),
                  Text(
                    'Logout',
                    style: AppTextStyles.navItem.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Navigation data
  // ═══════════════════════════════════════════════════════════════════════════

  /// Full list of nav items for sidebar / drawer
  List<_NavItem> _getAllNavItems(bool isInstructor, bool isOffline) {
    final classes = _NavItem(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
      label: 'Classes',
      path: AppRoutes.dashboard,
    );
    final offlineFiles = _NavItem(
      icon: Icons.download_for_offline_outlined,
      activeIcon: Icons.download_for_offline,
      label: 'Offline Files',
      path: AppRoutes.offlineFiles,
    );
    if (isOffline) return [classes, offlineFiles];

    return [
      classes,
      _NavItem(
        icon: isInstructor
            ? Icons.fact_check_outlined
            : Icons.check_box_outline_blank,
        activeIcon: isInstructor ? Icons.fact_check : Icons.check_box,
        label: isInstructor ? 'Work Queue' : 'To-do',
        path: AppRoutes.todos,
      ),
      _NavItem(
        icon: Icons.terminal_outlined,
        activeIcon: Icons.terminal,
        label: 'Code Lab',
        path: AppRoutes.codeLab,
      ),
      offlineFiles,
      if (isInstructor) ...[
        _NavItem(
          icon: Icons.add_box_outlined,
          activeIcon: Icons.add_box,
          label: 'Create Course',
          path: AppRoutes.createCourse,
        ),
      ] else ...[
        _NavItem(
          icon: Icons.grade_outlined,
          activeIcon: Icons.grade,
          label: 'My Grades',
          path: AppRoutes.grades,
        ),
      ],
      _NavItem.section('ACCOUNT'),
      _NavItem(
        icon: Icons.notifications_outlined,
        activeIcon: Icons.notifications,
        label: 'Notifications',
        path: AppRoutes.notifications,
      ),
      _NavItem(
        icon: Icons.person_outline,
        activeIcon: Icons.person,
        label: 'Profile',
        path: AppRoutes.profile,
      ),
      _NavItem(
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings,
        label: 'Settings',
        path: AppRoutes.settings,
      ),
    ];
  }
}

class _AppShellDrawerScope extends InheritedWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;

  const _AppShellDrawerScope({required this.scaffoldKey, required super.child});

  @override
  bool updateShouldNotify(_AppShellDrawerScope oldWidget) =>
      scaffoldKey != oldWidget.scaffoldKey;
}

/// Simple data class for navigation items
class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String path;
  final bool isSectionHeader;

  _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.path,
  }) : isSectionHeader = false;

  _NavItem.section(this.label)
    : icon = Icons.label,
      activeIcon = Icons.label,
      path = '',
      isSectionHeader = true;
}
