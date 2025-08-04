import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../core/animations/animated_widgets.dart';
import '../../core/animations/animation_constants.dart';
import '../../core/animations/animation_utils.dart';

class AppNavigationDrawer extends StatefulWidget {
  final bool isDesktopMode;
  final bool isExpanded;
  final VoidCallback? onToggle;

  const AppNavigationDrawer({
    super.key,
    this.isDesktopMode = false,
    this.isExpanded = true,
    this.onToggle,
  });

  @override
  State<AppNavigationDrawer> createState() => _AppNavigationDrawerState();
}

class _AppNavigationDrawerState extends State<AppNavigationDrawer> {
  String? _expandedSection;

  @override
  Widget build(BuildContext context) {
    final currentLocation = GoRouterState.of(context).uri.path;

    return Container(
      width: widget.isDesktopMode ? (widget.isExpanded ? 280 : 72) : null,
      child: Drawer(
        child: Column(
          children: [
            // Header
            _buildDrawerHeader(context),

            // Navigation Items
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Home/Dashboard
                  _NavigationTile(
                    icon: Icons.dashboard_outlined,
                    selectedIcon: Icons.dashboard,
                    title: 'Dashboard',
                    route: '/',
                    currentRoute: currentLocation,
                    isExpanded: widget.isExpanded,
                    onTap: () => _navigateTo(context, '/'),
                  ),

                  const SizedBox(height: 8),

                  // Business Operations Section
                  if (widget.isExpanded) ...[
                    _SectionHeader('Business Operations'),
                  ],

                  // Invoices with submenu
                  _NavigationTile(
                    icon: Icons.receipt_long_outlined,
                    selectedIcon: Icons.receipt_long,
                    title: 'Invoices',
                    route: '/invoices',
                    currentRoute: currentLocation,
                    isExpanded: widget.isExpanded,
                    hasSubmenu: true,
                    isSubmenuExpanded: _expandedSection == 'invoices',
                    onTap: () => _navigateTo(context, '/invoices'),
                    onSubmenuToggle: () => _toggleSubmenu('invoices'),
                    submenuItems: [
                      _SubmenuItem('All Invoices', '/invoices', Icons.list),
                      _SubmenuItem(
                          'Create Invoice', '/invoices/create', Icons.add),
                      _SubmenuItem('Draft Invoices', '/invoices?status=draft',
                          Icons.drafts),
                      _SubmenuItem('Overdue Invoices',
                          '/invoices?status=overdue', Icons.warning),
                    ],
                  ),

                  // Customers
                  _NavigationTile(
                    icon: Icons.people_outlined,
                    selectedIcon: Icons.people,
                    title: 'Customers',
                    route: '/customers',
                    currentRoute: currentLocation,
                    isExpanded: widget.isExpanded,
                    hasSubmenu: true,
                    isSubmenuExpanded: _expandedSection == 'customers',
                    onTap: () => _navigateTo(context, '/customers'),
                    onSubmenuToggle: () => _toggleSubmenu('customers'),
                    submenuItems: [
                      _SubmenuItem('All Customers', '/customers', Icons.list),
                      _SubmenuItem('Add Customer', '/customers/create',
                          Icons.person_add),
                    ],
                  ),

                  // Inventory
                  _NavigationTile(
                    icon: Icons.inventory_2_outlined,
                    selectedIcon: Icons.inventory_2,
                    title: 'Inventory',
                    route: '/inventory',
                    currentRoute: currentLocation,
                    isExpanded: widget.isExpanded,
                    hasSubmenu: true,
                    isSubmenuExpanded: _expandedSection == 'inventory',
                    onTap: () => _navigateTo(context, '/inventory'),
                    onSubmenuToggle: () => _toggleSubmenu('inventory'),
                    submenuItems: [
                      _SubmenuItem('All Products', '/inventory', Icons.list),
                      _SubmenuItem(
                          'Add Product', '/inventory/create', Icons.add_box),
                      _SubmenuItem('Low Stock', '/inventory?filter=low_stock',
                          Icons.warning),
                    ],
                  ),

                  // Vendors
                  _NavigationTile(
                    icon: Icons.store_outlined,
                    selectedIcon: Icons.store,
                    title: 'Vendors',
                    route: '/vendors',
                    currentRoute: currentLocation,
                    isExpanded: widget.isExpanded,
                    hasSubmenu: true,
                    isSubmenuExpanded: _expandedSection == 'vendors',
                    onTap: () => _navigateTo(context, '/vendors'),
                    onSubmenuToggle: () => _toggleSubmenu('vendors'),
                    submenuItems: [
                      _SubmenuItem('All Vendors', '/vendors', Icons.list),
                      _SubmenuItem(
                          'Add Vendor', '/vendors/create', Icons.add_business),
                      _SubmenuItem('International',
                          '/vendors?filter=international', Icons.public),
                    ],
                  ),

                  // Payments
                  _NavigationTile(
                    icon: Icons.payment_outlined,
                    selectedIcon: Icons.payment,
                    title: 'Payments',
                    route: '/payments',
                    currentRoute: currentLocation,
                    isExpanded: widget.isExpanded,
                    hasSubmenu: true,
                    isSubmenuExpanded: _expandedSection == 'payments',
                    onTap: () => _navigateTo(context, '/payments'),
                    onSubmenuToggle: () => _toggleSubmenu('payments'),
                    submenuItems: [
                      _SubmenuItem(
                          'Payment Center', '/payments', Icons.dashboard),
                      _SubmenuItem(
                          'SGQR Generator', '/payments/sgqr', Icons.qr_code),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Management Section
                  if (widget.isExpanded) ...[
                    _SectionHeader('Management'),
                  ],

                  // Employee Management
                  _NavigationTile(
                    icon: Icons.badge_outlined,
                    selectedIcon: Icons.badge,
                    title: 'Employee Management',
                    route: '/employees',
                    currentRoute: currentLocation,
                    isExpanded: widget.isExpanded,
                    hasSubmenu: true,
                    isSubmenuExpanded: _expandedSection == 'employees',
                    onTap: () => _navigateTo(context, '/employees'),
                    onSubmenuToggle: () => _toggleSubmenu('employees'),
                    submenuItems: [
                      _SubmenuItem('All Employees', '/employees', Icons.list),
                      _SubmenuItem('Add Employee', '/employees/create',
                          Icons.person_add),
                      _SubmenuItem('Employee Reports', '/employees/reports',
                          Icons.analytics),
                    ],
                  ),

                  // Payroll
                  _NavigationTile(
                    icon: Icons.payments_outlined,
                    selectedIcon: Icons.payments,
                    title: 'Payroll',
                    route: '/payroll',
                    currentRoute: currentLocation,
                    isExpanded: widget.isExpanded,
                    hasSubmenu: true,
                    isSubmenuExpanded: _expandedSection == 'payroll',
                    onTap: () => _navigateTo(context, '/payroll'),
                    onSubmenuToggle: () => _toggleSubmenu('payroll'),
                    submenuItems: [
                      _SubmenuItem(
                          'Process Payroll', '/payroll', Icons.play_arrow),
                      _SubmenuItem(
                          'Payroll History', '/payroll#history', Icons.history),
                      _SubmenuItem('CPF Reports', '/payroll#reports',
                          Icons.account_balance),
                      _SubmenuItem(
                          'IR8A Forms', '/payroll#ir8a', Icons.description),
                    ],
                  ),

                  // Tax Management
                  _NavigationTile(
                    icon: Icons.account_balance_outlined,
                    selectedIcon: Icons.account_balance,
                    title: 'Tax Center',
                    route: '/tax',
                    currentRoute: currentLocation,
                    isExpanded: widget.isExpanded,
                    hasSubmenu: true,
                    isSubmenuExpanded: _expandedSection == 'tax',
                    onTap: () => _navigateTo(context, '/tax'),
                    onSubmenuToggle: () => _toggleSubmenu('tax'),
                    submenuItems: [
                      _SubmenuItem('Tax Dashboard', '/tax', Icons.dashboard),
                      _SubmenuItem(
                          'Tax Calculator', '/tax/calculator', Icons.calculate),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Analytics Section
                  if (widget.isExpanded) ...[
                    _SectionHeader('Analytics & Reports'),
                  ],

                  // Forecasting & Analytics
                  _NavigationTile(
                    icon: Icons.trending_up_outlined,
                    selectedIcon: Icons.trending_up,
                    title: 'Forecasting',
                    route: '/forecasting',
                    currentRoute: currentLocation,
                    isExpanded: widget.isExpanded,
                    hasSubmenu: true,
                    isSubmenuExpanded: _expandedSection == 'forecasting',
                    onTap: () => _navigateTo(context, '/forecasting'),
                    onSubmenuToggle: () => _toggleSubmenu('forecasting'),
                    submenuItems: [
                      _SubmenuItem(
                          'Dashboard', '/forecasting', Icons.dashboard),
                      _SubmenuItem('Revenue Forecast', '/forecasting/revenue',
                          Icons.trending_up),
                      _SubmenuItem('Expense Forecast', '/forecasting/expenses',
                          Icons.trending_down),
                      _SubmenuItem('Cash Flow Forecast',
                          '/forecasting/cashflow', Icons.account_balance),
                      _SubmenuItem('Inventory Forecast',
                          '/forecasting/inventory', Icons.inventory),
                      _SubmenuItem('Financial Reports', '/forecasting/reports',
                          Icons.assessment),
                    ],
                  ),

                  // Reports & Analytics
                  _NavigationTile(
                    icon: Icons.analytics_outlined,
                    selectedIcon: Icons.analytics,
                    title: 'Reports',
                    route: '/reports',
                    currentRoute: currentLocation,
                    isExpanded: widget.isExpanded,
                    hasSubmenu: true,
                    isSubmenuExpanded: _expandedSection == 'reports',
                    onTap: () => _navigateTo(context, '/reports'),
                    onSubmenuToggle: () => _toggleSubmenu('reports'),
                    submenuItems: [
                      _SubmenuItem('Dashboard', '/reports', Icons.dashboard),
                      _SubmenuItem(
                          'Sales Report', '/reports/sales', Icons.show_chart),
                      _SubmenuItem(
                          'Tax Report', '/reports/tax', Icons.receipt_long),
                      _SubmenuItem('Financial Report', '/reports/financial',
                          Icons.account_balance),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // System Section
                  if (widget.isExpanded) ...[
                    _SectionHeader('System'),
                  ],

                  // Notifications
                  _NavigationTile(
                    icon: Icons.notifications_outlined,
                    selectedIcon: Icons.notifications,
                    title: 'Notifications',
                    route: '/notifications',
                    currentRoute: currentLocation,
                    isExpanded: widget.isExpanded,
                    badge: '3',
                    onTap: () => _navigateTo(context, '/notifications'),
                  ),

                  // Sync & Share
                  _NavigationTile(
                    icon: Icons.sync_outlined,
                    selectedIcon: Icons.sync,
                    title: 'Sync & Share',
                    route: '/sync',
                    currentRoute: currentLocation,
                    isExpanded: widget.isExpanded,
                    onTap: () => _navigateTo(context, '/sync'),
                  ),

                  // Backup & Restore
                  _NavigationTile(
                    icon: Icons.backup_outlined,
                    selectedIcon: Icons.backup,
                    title: 'Backup & Restore',
                    route: '/backup',
                    currentRoute: currentLocation,
                    isExpanded: widget.isExpanded,
                    onTap: () => _navigateTo(context, '/backup'),
                  ),

                  // Settings
                  _NavigationTile(
                    icon: Icons.settings_outlined,
                    selectedIcon: Icons.settings,
                    title: 'Settings',
                    route: '/settings',
                    currentRoute: currentLocation,
                    isExpanded: widget.isExpanded,
                    onTap: () => _navigateTo(context, '/settings'),
                  ),
                ],
              ),
            ),

            // Footer with toggle button for desktop
            if (widget.isDesktopMode) ...[
              const Divider(height: 1),
              Container(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  onPressed: widget.onToggle,
                  icon: Icon(
                    widget.isExpanded
                        ? Icons.keyboard_arrow_left
                        : Icons.keyboard_arrow_right,
                  ),
                  tooltip:
                      widget.isExpanded ? 'Collapse sidebar' : 'Expand sidebar',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context) {
    if (widget.isDesktopMode && !widget.isExpanded) {
      // Collapsed header - just logo
      return Container(
        height: 64,
        alignment: Alignment.center,
        child: Icon(
          Icons.business,
          color: Theme.of(context).colorScheme.primary,
          size: 28,
        ),
      );
    }

    return DrawerHeader(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withOpacity(0.8),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.business,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'BizSync',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Professional Business Management',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateTo(BuildContext context, String route) {
    context.go(route);

    // Close drawer on mobile
    if (!widget.isDesktopMode) {
      Navigator.of(context).pop();
    }
  }

  void _toggleSubmenu(String section) {
    setState(() {
      _expandedSection = _expandedSection == section ? null : section;
    });
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}

class _NavigationTile extends StatefulWidget {
  final IconData icon;
  final IconData? selectedIcon;
  final String title;
  final String route;
  final String currentRoute;
  final bool isExpanded;
  final String? badge;
  final bool hasSubmenu;
  final bool isSubmenuExpanded;
  final VoidCallback onTap;
  final VoidCallback? onSubmenuToggle;
  final List<_SubmenuItem>? submenuItems;

  const _NavigationTile({
    required this.icon,
    this.selectedIcon,
    required this.title,
    required this.route,
    required this.currentRoute,
    required this.onTap,
    this.isExpanded = true,
    this.badge,
    this.hasSubmenu = false,
    this.isSubmenuExpanded = false,
    this.onSubmenuToggle,
    this.submenuItems,
  });

  @override
  State<_NavigationTile> createState() => _NavigationTileState();
}

class _NavigationTileState extends State<_NavigationTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AnimationConstants.buttonPress,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AnimationConstants.buttonCurve,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = _isRouteSelected();
    final displayIcon = isSelected && widget.selectedIcon != null
        ? widget.selectedIcon!
        : widget.icon;

    return AnimationUtils.slideAndFade(
      begin: const Offset(-20, 0),
      child: Column(
        children: [
          MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: GestureDetector(
              onTapDown: (_) => _controller.forward(),
              onTapUp: (_) {
                _controller.reverse();
                widget.hasSubmenu
                    ? widget.onSubmenuToggle?.call()
                    : widget.onTap();
              },
              onTapCancel: () => _controller.reverse(),
              child: AnimatedBuilder(
                animation: _scaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: AnimatedContainer(
                      duration: AnimationConstants.cardHover,
                      curve: AnimationConstants.cardCurve,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.1)
                            : _isHovered
                                ? Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.05)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.3),
                                width: 1,
                              )
                            : null,
                      ),
                      child: ListTile(
                        leading: Stack(
                          children: [
                            AnimatedContainer(
                              duration: AnimationConstants.cardHover,
                              child: Icon(
                                displayIcon,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : _isHovered
                                        ? Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withOpacity(0.8)
                                        : null,
                                size: _isHovered ? 26 : 24,
                              ),
                            ),
                            if (widget.badge != null && widget.isExpanded)
                              Positioned(
                                right: -2,
                                top: -2,
                                child: AnimationUtils.scaleIn(
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 12,
                                      minHeight: 12,
                                    ),
                                    child: Text(
                                      widget.badge!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: widget.isExpanded
                            ? AnimatedDefaultTextStyle(
                                duration: AnimationConstants.cardHover,
                                style: TextStyle(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : _isHovered
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withOpacity(0.8)
                                          : Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.color,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  fontSize: _isHovered ? 15 : 14,
                                ),
                                child: Text(widget.title),
                              )
                            : null,
                        trailing: widget.isExpanded && widget.hasSubmenu
                            ? AnimatedRotation(
                                duration: AnimationConfig.drawerSlide.duration,
                                curve: AnimationConfig.drawerSlide.curve,
                                turns: widget.isSubmenuExpanded ? 0.5 : 0,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.expand_more,
                                    size: 20,
                                  ),
                                  onPressed: widget.onSubmenuToggle,
                                ),
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // Animated submenu expansion
          if (widget.hasSubmenu && widget.submenuItems != null)
            AnimatedSize(
              duration: AnimationConfig.drawerSlide.duration,
              curve: AnimationConfig.drawerSlide.curve,
              child: widget.isSubmenuExpanded
                  ? Container(
                      margin: const EdgeInsets.only(left: 16),
                      child: AnimationLimiter(
                        child: Column(
                          children: AnimationConfiguration.toStaggeredList(
                            duration: AnimationConstants.fast,
                            delay: AnimationConstants.listItemStagger,
                            childAnimationBuilder: (widget) => SlideAnimation(
                              horizontalOffset: 20.0,
                              child: FadeInAnimation(child: widget),
                            ),
                            children: widget.submenuItems!
                                .map((item) => _buildSubmenuTile(item))
                                .toList(),
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }

  Widget _buildSubmenuTile(_SubmenuItem item) {
    final isSelected = widget.currentRoute.startsWith(item.route);

    return AnimatedCard(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      elevation: 0,
      hoverElevation: 2,
      child: ListTile(
        leading: Icon(
          item.icon,
          size: 18,
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        ),
        title: Text(
          item.title,
          style: TextStyle(
            fontSize: 13,
            color: isSelected ? Theme.of(context).colorScheme.primary : null,
            fontWeight: isSelected ? FontWeight.w600 : null,
          ),
        ),
        onTap: () {
          if (item.route.startsWith('http')) {
            // External link - handle appropriately
          } else {
            GoRouter.of(context).go(item.route);
          }
        },
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        selected: isSelected,
        selectedTileColor:
            Theme.of(context).colorScheme.primary.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  bool _isRouteSelected() {
    if (widget.route == '/' && widget.currentRoute == '/') {
      return true;
    }
    if (widget.route != '/' && widget.currentRoute.startsWith(widget.route)) {
      return true;
    }
    return false;
  }
}

// Helper classes remain the same

class _SubmenuItem {
  final String title;
  final String route;
  final IconData icon;

  _SubmenuItem(this.title, this.route, this.icon);
}

// _SubmenuTile is now handled within _NavigationTile
