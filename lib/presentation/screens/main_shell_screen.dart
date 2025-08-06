import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';
import '../widgets/app_navigation_drawer.dart';
import '../widgets/bottom_navigation_widget.dart';
import '../widgets/breadcrumb_widget.dart';
import '../../navigation/app_router.dart';
import '../../navigation/app_navigation_service.dart';

class MainShellScreen extends StatefulWidget {
  final Widget child;

  const MainShellScreen({
    super.key,
    required this.child,
  });

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isDrawerExpanded = true;

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = ResponsiveBreakpoints.of(context).largerThan(TABLET);
    final bool isMobile = ResponsiveBreakpoints.of(context).equals(MOBILE);

    return CallbackShortcuts(
      bindings: {
        // Keyboard shortcuts
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
            _handleQuickAction('invoice'),
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
            _showGlobalSearch(),
        const SingleActivator(LogicalKeyboardKey.keyB, control: true): () =>
            _toggleDrawer(),
        const SingleActivator(LogicalKeyboardKey.escape): () => _handleEscape(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          key: _scaffoldKey,
          appBar: _buildAppBar(context, isDesktop),
          drawer: isMobile ? const AppNavigationDrawer() : null,
          body: Row(
            children: [
              // Side navigation for desktop/tablet
              if (isDesktop) ...[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: _isDrawerExpanded ? 280 : 72,
                  child: AppNavigationDrawer(
                    isDesktopMode: true,
                    isExpanded: _isDrawerExpanded,
                    onToggle: () =>
                        setState(() => _isDrawerExpanded = !_isDrawerExpanded),
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1),
              ],

              // Main content area
              Expanded(
                child: Column(
                  children: [
                    // Breadcrumbs for desktop
                    if (isDesktop) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          border: Border(
                            bottom: BorderSide(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                        ),
                        child: BreadcrumbWidget(
                          breadcrumbs: AppNavigationService().getBreadcrumbs(
                              GoRouterState.of(context).uri.path),
                        ),
                      ),
                    ],

                    // Main content
                    Expanded(child: widget.child),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: isMobile ? const BottomNavigationWidget() : null,
          floatingActionButton: _buildFloatingActionButton(context),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDesktop) {
    final currentLocation = GoRouterState.of(context).uri.path;
    final String title = _getTitleForRoute(currentLocation);

    return AppBar(
      title: isDesktop && _isDrawerExpanded
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo/Brand for desktop when drawer is expanded
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.business,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'BizSync',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  height: 24,
                  width: 1,
                  color: Theme.of(context).dividerColor,
                ),
                const SizedBox(width: 16),
                Flexible(child: Text(title)),
              ],
            )
          : Text(title),
      centerTitle: !isDesktop,
      leading: isDesktop
          ? null
          : IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
      actions: [
        // Global search
        IconButton(
          icon: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.search),
              if (isDesktop)
                Positioned(
                  bottom: -4,
                  right: -4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '⌘K',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          onPressed: _showGlobalSearch,
          tooltip: isDesktop ? 'Global Search (Ctrl+K)' : 'Search',
        ),

        // Notifications
        IconButton(
          icon: Stack(
            children: [
              const Icon(Icons.notifications_outlined),
              Positioned(
                right: 0,
                top: 0,
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
                  child: const Text(
                    '3',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
          onPressed: () => context.go('/notifications'),
          tooltip: 'Notifications',
        ),

        // Quick actions for desktop
        if (isDesktop) ...[
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: () => _showQuickActionMenu(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Quick Add'),
          ),
          const SizedBox(width: 8),
        ],

        // User profile menu
        PopupMenuButton<String>(
          icon: CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Text(
              'U',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          onSelected: _handleUserMenuAction,
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'profile',
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Profile'),
                subtitle: const Text('user@example.com'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'settings',
              child: ListTile(
                leading: Icon(Icons.settings_outlined),
                title: Text('Settings'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'backup',
              child: ListTile(
                leading: Icon(Icons.backup_outlined),
                title: Text('Backup & Sync'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'help',
              child: ListTile(
                leading: Icon(Icons.help_outline),
                title: Text('Help & Support'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'logout',
              child: ListTile(
                leading: Icon(Icons.logout, color: Colors.red),
                title: Text('Sign Out', style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget? _buildFloatingActionButton(BuildContext context) {
    final currentLocation = GoRouterState.of(context).uri.path;
    final isMobile = ResponsiveBreakpoints.of(context).equals(MOBILE);

    if (!isMobile) return null; // Only show FAB on mobile

    // Show context-specific FAB
    if (currentLocation.startsWith('/invoices')) {
      return FloatingActionButton(
        onPressed: () => context.go('/invoices/create'),
        tooltip: 'New Invoice',
        child: const Icon(Icons.receipt_long),
      );
    } else if (currentLocation.startsWith('/customers')) {
      return FloatingActionButton(
        onPressed: () => context.go('/customers/create'),
        tooltip: 'New Customer',
        child: const Icon(Icons.person_add),
      );
    }

    // Default FAB with quick actions
    return FloatingActionButton(
      onPressed: () => _showQuickActionMenu(context),
      tooltip: 'Quick Add',
      child: const Icon(Icons.add),
    );
  }

  void _showQuickActionMenu(BuildContext context) {
    final isDesktop = ResponsiveBreakpoints.of(context).largerThan(TABLET);

    if (isDesktop) {
      // Show as dropdown menu for desktop
      final RenderBox button = context.findRenderObject() as RenderBox;
      final RenderBox overlay =
          Overlay.of(context).context.findRenderObject() as RenderBox;
      final RelativeRect position = RelativeRect.fromRect(
        Rect.fromPoints(
          button.localToGlobal(Offset.zero, ancestor: overlay),
          button.localToGlobal(button.size.bottomRight(Offset.zero),
              ancestor: overlay),
        ),
        Offset.zero & overlay.size,
      );

      showMenu(
        context: context,
        position: position,
        items: [
          PopupMenuItem(
            value: 'invoice',
            child: ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('New Invoice'),
              subtitle: const Text('Ctrl+N'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            value: 'customer',
            child: ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('New Customer'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            value: 'payment',
            child: ListTile(
              leading: const Icon(Icons.qr_code),
              title: const Text('Payment QR'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            value: 'tax',
            child: ListTile(
              leading: const Icon(Icons.calculate),
              title: const Text('Tax Calculator'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ).then((value) {
        if (value != null) {
          _handleQuickAction(value);
        }
      });
    } else {
      // Show as bottom sheet for mobile
      showModalBottomSheet(
        context: context,
        builder: (context) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 2,
                childAspectRatio: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _QuickActionTile(
                    icon: Icons.receipt_long,
                    label: 'New Invoice',
                    onTap: () {
                      Navigator.pop(context);
                      _handleQuickAction('invoice');
                    },
                  ),
                  _QuickActionTile(
                    icon: Icons.person_add,
                    label: 'New Customer',
                    onTap: () {
                      Navigator.pop(context);
                      _handleQuickAction('customer');
                    },
                  ),
                  _QuickActionTile(
                    icon: Icons.qr_code,
                    label: 'Payment QR',
                    onTap: () {
                      Navigator.pop(context);
                      _handleQuickAction('payment');
                    },
                  ),
                  _QuickActionTile(
                    icon: Icons.calculate,
                    label: 'Tax Calculator',
                    onTap: () {
                      Navigator.pop(context);
                      _handleQuickAction('tax');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
    }
  }

  void _handleQuickAction(String action) {
    switch (action) {
      case 'invoice':
        context.go('/invoices/create');
        break;
      case 'customer':
        context.go('/customers/create');
        break;
      case 'payment':
        context.go('/payments/sgqr');
        break;
      case 'tax':
        context.go('/tax/calculator');
        break;
    }
  }

  void _showGlobalSearch() {
    showSearch(
      context: context,
      delegate: _GlobalSearchDelegate(),
    );
  }

  void _toggleDrawer() {
    if (ResponsiveBreakpoints.of(context).largerThan(TABLET)) {
      setState(() => _isDrawerExpanded = !_isDrawerExpanded);
    } else {
      _scaffoldKey.currentState?.openDrawer();
    }
  }

  void _handleEscape() {
    // Close any open overlays
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  void _handleUserMenuAction(String action) {
    switch (action) {
      case 'profile':
        _showProfileDialog();
        break;
      case 'settings':
        context.go('/settings');
        break;
      case 'backup':
        context.go('/backup');
        break;
      case 'help':
        _showHelpDialog();
        break;
      case 'logout':
        _showLogoutConfirmation();
        break;
    }
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _performLogout();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Signed out successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _showProfileDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('User Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                radius: 40,
                backgroundColor: Colors.blue,
                child: Icon(Icons.person, size: 40, color: Colors.white),
              ),
              const SizedBox(height: 16),
              const Text(
                'Business Owner',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('owner@mybusiness.com'),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              _buildProfileRow('Company', 'My Business Pte Ltd'),
              _buildProfileRow('GST Registration', 'GST Registered'),
              _buildProfileRow('Business Type', 'Private Limited'),
              _buildProfileRow('Industry', 'Professional Services'),
              _buildProfileRow('License Version', 'BizSync Pro'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.go('/settings');
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Profile'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                  fontWeight: FontWeight.w500, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Support'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BizSync Help Center',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              _buildHelpOption(
                Icons.book,
                'User Guide',
                'Learn how to use BizSync effectively',
                () => _openUserGuide(),
              ),
              _buildHelpOption(
                Icons.video_library,
                'Video Tutorials',
                'Watch step-by-step tutorials',
                () => _openVideoTutorials(),
              ),
              _buildHelpOption(
                Icons.quiz,
                'FAQs',
                'Frequently asked questions',
                () => _openFAQs(),
              ),
              _buildHelpOption(
                Icons.support_agent,
                'Contact Support',
                'Get help from our support team',
                () => _contactSupport(),
              ),
              _buildHelpOption(
                Icons.bug_report,
                'Report Issue',
                'Report bugs or suggest features',
                () => _reportIssue(),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'App Information',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              _buildInfoRow('Version', '1.0.0'),
              _buildInfoRow('Build', '${DateTime.now().year}.1.1'),
              _buildInfoRow('Platform', 'Flutter'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpOption(
      IconData icon, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _openUserGuide() {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening user guide...'),
        duration: Duration(seconds: 2),
      ),
    );
    // Here you would typically open a URL or navigate to a guide screen
  }

  void _openVideoTutorials() {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening video tutorials...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _openFAQs() {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening FAQs...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _contactSupport() {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening support contact...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _reportIssue() {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening issue reporting...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _performLogout() {
    // Clear any cached data, tokens, etc.
    // For now, just navigate back to splash screen or login
    context.go('/splash');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Successfully signed out'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _getTitleForRoute(String route) {
    switch (route) {
      case '/':
        return 'Dashboard';
      case '/dashboard':
        return 'Business Dashboard';
      case '/invoices':
        return 'Invoice Management';
      case '/customers':
        return 'Customer Management';
      case '/employees':
        return 'Employee Management';
      case '/payments':
        return 'Payment Center';
      case '/tax':
        return 'Tax Management';
      case '/sync':
        return 'Sync & Share';
      case '/backup':
        return 'Backup & Restore';
      case '/notifications':
        return 'Notifications';
      case '/settings':
        return 'Settings';
      default:
        if (route.startsWith('/invoices/create')) return 'Create Invoice';
        if (route.startsWith('/invoices/edit')) return 'Edit Invoice';
        if (route.startsWith('/invoices/detail')) return 'Invoice Details';
        if (route.startsWith('/customers/create')) return 'Add Customer';
        if (route.startsWith('/customers/edit')) return 'Edit Customer';
        if (route.startsWith('/employees/')) return 'Employee Management';
        if (route.startsWith('/tax/')) return 'Tax Management';
        return 'BizSync';
    }
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlobalSearchDelegate extends SearchDelegate<String> {
  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
          showSuggestions(context);
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, ''),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchContent(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return _buildRecentSearches(context);
    }
    return _buildSearchContent(context);
  }

  Widget _buildSearchContent(BuildContext context) {
    final suggestions = [
      _SearchSuggestion('Invoices', Icons.receipt_long, '/invoices'),
      _SearchSuggestion('Create Invoice', Icons.add, '/invoices/create'),
      _SearchSuggestion('Customers', Icons.people, '/customers'),
      _SearchSuggestion('Add Customer', Icons.person_add, '/customers/create'),
      _SearchSuggestion('Payment QR', Icons.qr_code, '/payments/sgqr'),
      _SearchSuggestion('Tax Calculator', Icons.calculate, '/tax/calculator'),
      _SearchSuggestion(
          'Employee Payroll', Icons.payments, '/employees/payroll'),
      _SearchSuggestion('Backup Settings', Icons.backup, '/backup'),
      _SearchSuggestion('Settings', Icons.settings, '/settings'),
    ]
        .where((suggestion) =>
            suggestion.title.toLowerCase().contains(query.toLowerCase()))
        .toList();

    if (suggestions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No results found for "$query"',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
                'Try searching for invoices, customers, or other features'),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = suggestions[index];
        return ListTile(
          leading: Icon(suggestion.icon),
          title: RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyLarge,
              children: _highlightSearchTerm(suggestion.title, query, context),
            ),
          ),
          onTap: () {
            close(context, suggestion.title);
            context.go(suggestion.route);
          },
        );
      },
    );
  }

  Widget _buildRecentSearches(BuildContext context) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.receipt_long),
          title: const Text('Create Invoice'),
          subtitle: const Text('Start a new invoice'),
          onTap: () {
            close(context, 'Create Invoice');
            context.go('/invoices/create');
          },
        ),
        ListTile(
          leading: const Icon(Icons.person_add),
          title: const Text('Add Customer'),
          subtitle: const Text('Add a new customer'),
          onTap: () {
            close(context, 'Add Customer');
            context.go('/customers/create');
          },
        ),
        ListTile(
          leading: const Icon(Icons.qr_code),
          title: const Text('Payment QR'),
          subtitle: const Text('Generate payment QR code'),
          onTap: () {
            close(context, 'Payment QR');
            context.go('/payments/sgqr');
          },
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Search Tips',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
          ),
        ),
        const ListTile(
          leading: Icon(Icons.lightbulb_outline),
          title: Text('Search for features'),
          subtitle: Text('e.g., "invoices", "customers", "settings"'),
        ),
        const ListTile(
          leading: Icon(Icons.lightbulb_outline),
          title: Text('Use keyboard shortcuts'),
          subtitle: Text('Ctrl+K to open search, Escape to close'),
        ),
      ],
    );
  }

  List<TextSpan> _highlightSearchTerm(
      String text, String searchTerm, BuildContext context) {
    if (searchTerm.isEmpty) {
      return [TextSpan(text: text)];
    }

    final List<TextSpan> spans = [];
    final lowerText = text.toLowerCase();
    final lowerSearchTerm = searchTerm.toLowerCase();
    int start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerSearchTerm, start);
      if (index == -1) {
        if (start < text.length) {
          spans.add(TextSpan(text: text.substring(start)));
        }
        break;
      }

      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }

      spans.add(TextSpan(
        text: text.substring(index, index + searchTerm.length),
        style: TextStyle(
          backgroundColor:
              Theme.of(context).colorScheme.primary.withOpacity(0.3),
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ));

      start = index + searchTerm.length;
    }

    return spans;
  }
}

class _SearchSuggestion {
  final String title;
  final IconData icon;
  final String route;

  _SearchSuggestion(this.title, this.icon, this.route);
}
