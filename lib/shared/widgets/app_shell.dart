import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/router/app_routes.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';

/// Responsive breakpoints
class _Breakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
}

/// Main application shell with responsive navigation
/// - Mobile (<600px): Bottom navigation bar + drawer for extra items
/// - Tablet (600–900px): Collapsed rail sidebar (72px)
/// - Desktop (>900px): Expanded sidebar (260px)
class AppShell extends StatefulWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _isExpanded = true;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final isInstructor =
        authState is AuthAuthenticated && authState.user.role == 'instructor';
    final width = MediaQuery.sizeOf(context).width;

    if (width < _Breakpoints.mobile) {
      return _buildMobileLayout(context, isInstructor);
    } else if (width < _Breakpoints.tablet) {
      return _buildTabletLayout(context, isInstructor);
    } else {
      return _buildDesktopLayout(context, isInstructor);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Mobile layout — bottom navigation + drawer
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMobileLayout(BuildContext context, bool isInstructor) {
    final currentPath = GoRouterState.of(context).matchedLocation;
    final bottomItems = _getBottomNavItems(isInstructor);
    final currentIndex = _getBottomNavIndex(currentPath, bottomItems);

    return Scaffold(
      key: _scaffoldKey,
      body: widget.child,
      drawer: _buildDrawer(context, isInstructor),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (int i = 0; i < bottomItems.length; i++)
                  _buildBottomNavItem(
                    context: context,
                    item: bottomItems[i],
                    isActive: i == currentIndex,
                  ),
                // More button opens drawer
                _buildBottomNavItem(
                  context: context,
                  item: _NavItem(
                    icon: Icons.menu,
                    activeIcon: Icons.menu,
                    label: 'More',
                    path: '',
                  ),
                  isActive: false,
                  onTap: () => _scaffoldKey.currentState?.openDrawer(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required BuildContext context,
    required _NavItem item,
    required bool isActive,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap ?? () => context.go(item.path),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive ? item.activeIcon : item.icon,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
                size: 22,
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  color: isActive ? AppColors.primary : AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, bool isInstructor) {
    final currentPath = GoRouterState.of(context).matchedLocation;

    return Drawer(
      backgroundColor: AppColors.backgroundSecondary,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            _buildExpandedHeader(),
            const Divider(),

            // All nav items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  ..._getAllNavItems(isInstructor).map(
                    (item) => _buildDrawerNavItem(
                      context: context,
                      item: item,
                      currentPath: currentPath,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(),
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
    final isActive =
        currentPath == item.path || currentPath.startsWith('${item.path}/');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isActive ? AppColors.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () {
            Navigator.of(context).pop(); // close drawer
            context.go(item.path);
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: isActive
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border(
                      left: BorderSide(color: AppColors.primary, width: 3),
                    ),
                  )
                : null,
            child: Row(
              children: [
                Icon(
                  isActive ? item.activeIcon : item.icon,
                  color: isActive ? AppColors.primary : AppColors.textSecondary,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: isActive
                        ? AppTextStyles.navItemActive
                        : AppTextStyles.navItem,
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

  Widget _buildTabletLayout(BuildContext context, bool isInstructor) {
    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 72,
            child: _buildSidebar(context, isInstructor, expanded: false),
          ),
          Expanded(child: widget.child),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Desktop layout — expandable sidebar
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildDesktopLayout(BuildContext context, bool isInstructor) {
    return Scaffold(
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _isExpanded ? 260 : 72,
            child: _buildSidebar(context, isInstructor, expanded: _isExpanded),
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
    bool isInstructor, {
    required bool expanded,
  }) {
    final currentPath = GoRouterState.of(context).matchedLocation;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        border: Border(right: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Column(
        children: [
          // Logo/Brand
          expanded ? _buildExpandedHeader() : _buildCollapsedHeader(),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),

          // Navigation items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final item in _getAllNavItems(isInstructor))
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
          const Divider(),
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
                Text('BitClass', style: AppTextStyles.h4),
                Text('Learn to Code', style: AppTextStyles.caption),
              ],
            ),
          ),
          // Only show collapse on desktop
          if (MediaQuery.sizeOf(context).width >= _Breakpoints.tablet)
            IconButton(
              icon: const Icon(
                Icons.chevron_left,
                color: AppColors.textSecondary,
              ),
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
      child: const Icon(Icons.code, color: AppColors.background, size: 24),
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
    final isActive =
        currentPath == item.path || currentPath.startsWith('${item.path}/');

    if (item.isSectionHeader) {
      if (!expanded) return const SizedBox(height: 16);
      return Padding(
        padding: const EdgeInsets.only(left: 12, top: 16, bottom: 8),
        child: Text(
          item.label,
          style: AppTextStyles.caption.copyWith(
            letterSpacing: 1,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isActive ? AppColors.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => context.go(item.path),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: expanded ? 12 : 0,
              vertical: 12,
            ),
            decoration: isActive
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border(
                      left: BorderSide(color: AppColors.primary, width: 3),
                    ),
                  )
                : null,
            child: Row(
              mainAxisAlignment: expanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Icon(
                  isActive ? item.activeIcon : item.icon,
                  color: isActive ? AppColors.primary : AppColors.textSecondary,
                  size: 22,
                ),
                if (expanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.label,
                      style: isActive
                          ? AppTextStyles.navItemActive
                          : AppTextStyles.navItem,
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
                const Icon(Icons.logout, color: AppColors.error, size: 22),
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

  /// Bottom nav items — a compact subset for mobile
  List<_NavItem> _getBottomNavItems(bool isInstructor) {
    return [
      _NavItem(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard,
        label: 'Home',
        path: AppRoutes.dashboard,
      ),
      _NavItem(
        icon: Icons.explore_outlined,
        activeIcon: Icons.explore,
        label: 'Courses',
        path: AppRoutes.courses,
      ),
      if (isInstructor)
        _NavItem(
          icon: Icons.school_outlined,
          activeIcon: Icons.school,
          label: 'Teach',
          path: AppRoutes.myCourses,
        )
      else
        _NavItem(
          icon: Icons.grade_outlined,
          activeIcon: Icons.grade,
          label: 'Grades',
          path: AppRoutes.grades,
        ),
      _NavItem(
        icon: Icons.notifications_outlined,
        activeIcon: Icons.notifications,
        label: 'Alerts',
        path: AppRoutes.notifications,
      ),
    ];
  }

  /// Full list of nav items for sidebar / drawer
  List<_NavItem> _getAllNavItems(bool isInstructor) {
    return [
      _NavItem(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard,
        label: 'Dashboard',
        path: AppRoutes.dashboard,
      ),
      _NavItem(
        icon: Icons.explore_outlined,
        activeIcon: Icons.explore,
        label: 'Browse Courses',
        path: AppRoutes.courses,
      ),
      if (isInstructor) ...[
        _NavItem(
          icon: Icons.school_outlined,
          activeIcon: Icons.school,
          label: 'My Courses',
          path: AppRoutes.myCourses,
        ),
        _NavItem(
          icon: Icons.add_box_outlined,
          activeIcon: Icons.add_box,
          label: 'Create Course',
          path: AppRoutes.createCourse,
        ),
      ] else ...[
        _NavItem(
          icon: Icons.bookmark_outline,
          activeIcon: Icons.bookmark,
          label: 'Enrolled Courses',
          path: AppRoutes.enrolledCourses,
        ),
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

  int _getBottomNavIndex(String currentPath, List<_NavItem> items) {
    for (int i = 0; i < items.length; i++) {
      if (currentPath == items[i].path ||
          currentPath.startsWith('${items[i].path}/')) {
        return i;
      }
    }
    return -1; // no match — user is on a page not in bottom nav
  }
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
