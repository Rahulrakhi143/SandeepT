import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trivora_provider/core/providers/admin_auth_provider.dart';
import 'package:trivora_provider/core/services/admin_service.dart';
import 'package:trivora_provider/core/services/admin_auth_service.dart';

/// Admin Dashboard Page (Web Only)
class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  int _selectedIndex = 0;
  
  static _AdminDashboardPageState? of(BuildContext context) {
    return context.findAncestorStateOfType<_AdminDashboardPageState>();
  }
  
  void setSelectedIndex(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _showAdminLogoutDialog(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout from admin account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final adminAuthService = ref.read(adminAuthServiceProvider);
        await adminAuthService.signOut();
        
        if (context.mounted) {
          // Clear any cached admin data
          ref.invalidate(currentAdminUserProvider);
          ref.invalidate(adminAuthStateProvider);
          
          // Navigate to login page
          context.go('/admin/login');
          
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Logged out successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        // ignore: avoid_print
        print('❌ Error logging out: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Error logging out: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if web
    if (!kIsWeb) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin Dashboard')),
        body: const Center(
          child: Text('Admin Dashboard is only available on web'),
        ),
      );
    }

    final adminUserAsync = ref.watch(currentAdminUserProvider);

    return adminUserAsync.when(
      data: (adminUser) {
        if (adminUser == null) {
          // Redirect to admin login
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/admin/login');
          });
          return Scaffold(
            appBar: AppBar(title: const Text('Admin Dashboard')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return _buildDashboard(context, ref, adminUser);
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Admin Dashboard')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Admin Dashboard')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/admin/login'),
                child: const Text('Go to Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard(
      BuildContext context, WidgetRef ref, Map<String, dynamic> adminUser) {
    return PopScope(
      canPop: false, // Prevent back button navigation
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          // If somehow back is pressed, redirect to admin dashboard
          context.go('/admin');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false, // Remove back button
          title: const Text('Admin Dashboard'),
          actions: [
          // Admin info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Text(
                adminUser['email'] ?? 'Admin',
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showAdminLogoutDialog(context, ref),
            tooltip: 'Logout',
          ),
        ],
        ),
        body: Row(
        children: [
          // Sidebar Navigation
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people),
                selectedIcon: Icon(Icons.people),
                label: Text('Providers'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.person),
                selectedIcon: Icon(Icons.person),
                label: Text('Users'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.book),
                selectedIcon: Icon(Icons.book),
                label: Text('Bookings'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.payment),
                selectedIcon: Icon(Icons.payment),
                label: Text('Payments'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.build),
                selectedIcon: Icon(Icons.build),
                label: Text('Services'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings),
                selectedIcon: Icon(Icons.settings),
                label: Text('Settings'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // Main Content
          Expanded(
            child: _buildContent(),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return const _DashboardView();
      case 1:
        return const _ProvidersView();
      case 2:
        return const _UsersView();
      case 3:
        return const _BookingsView();
      case 4:
        return const _PaymentsView();
      case 5:
        return const _ProviderServicesView();
      case 6:
        return const _SettingsView();
      default:
        return const _DashboardView();
    }
  }
}

/// Dashboard Overview
class _DashboardView extends ConsumerStatefulWidget {
  const _DashboardView();

  @override
  ConsumerState<_DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends ConsumerState<_DashboardView> {
  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(_dashboardStatsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Dashboard Overview',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    // ignore: unused_result
                    onPressed: () => ref.refresh(_dashboardStatsProvider),
                    tooltip: 'Refresh Stats',
                  ),
                  IconButton(
                    icon: const Icon(Icons.download),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Export feature coming soon')),
                      );
                    },
                    tooltip: 'Export Data',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          statsAsync.when(
            data: (stats) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatsGrid(context, stats),
                const SizedBox(height: 32),
                _buildQuickActions(context, ref),
                const SizedBox(height: 32),
                _buildRecentActivity(context, ref),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Column(
                children: [
                  Icon(Icons.error_outline,
                      size: 48, color: Colors.red.shade300),
                  const SizedBox(height: 16),
                  Text('Error loading stats: $error'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    // ignore: unused_result
                    onPressed: () => ref.refresh(_dashboardStatsProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, Map<String, dynamic> stats) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 2.5,
      children: [
        _buildStatCard(
          context,
          'Total Providers',
          stats['totalProviders'].toString(),
          Icons.people,
          Colors.blue,
        ),
        _buildStatCard(
          context,
          'Active Providers',
          stats['activeProviders'].toString(),
          Icons.person,
          Colors.green,
        ),
        _buildStatCard(
          context,
          'Total Bookings',
          stats['totalBookings'].toString(),
          Icons.book,
          Colors.orange,
        ),
        _buildStatCard(
          context,
          'Completed',
          stats['completedBookings'].toString(),
          Icons.check_circle,
          Colors.teal,
        ),
        _buildStatCard(
          context,
          'Pending',
          stats['pendingBookings'].toString(),
          Icons.pending,
          Colors.amber,
        ),
        _buildStatCard(
          context,
          'Total Revenue',
          '₹${NumberFormat('#,##,###').format(stats['totalRevenue'])}',
          Icons.currency_rupee,
          Colors.purple,
        ),
        _buildStatCard(
          context,
          'Platform Revenue',
          '₹${NumberFormat('#,##,###').format(stats['platformRevenue'])}',
          Icons.account_balance,
          Colors.indigo,
        ),
        _buildStatCard(
          context,
          'Provider Earnings',
          '₹${NumberFormat('#,##,###').format(stats['providerEarnings'])}',
          Icons.wallet,
          Colors.green,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return _InteractiveStatCard(
      title: title,
      value: value,
      icon: icon,
      color: color,
    );
  }

  Widget _buildQuickActions(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Quick Actions',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Icon(Icons.flash_on, color: Colors.amber.shade700),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildActionButton(
                  context,
                  'View All Providers',
                  Icons.people,
                  Colors.blue,
                  () {
                    _AdminDashboardPageState.of(context)?.setSelectedIndex(1);
                  },
                ),
                _buildActionButton(
                  context,
                  'View All Bookings',
                  Icons.book,
                  Colors.orange,
                  () {
                    _AdminDashboardPageState.of(context)?.setSelectedIndex(3);
                  },
                ),
                _buildActionButton(
                  context,
                  'View Payments',
                  Icons.payment,
                  Colors.green,
                  () {
                    _AdminDashboardPageState.of(context)?.setSelectedIndex(4);
                  },
                ),
                _buildActionButton(
                  context,
                  'System Settings',
                  Icons.settings,
                  Colors.grey,
                  () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Settings coming soon')),
                    );
                  },
                ),
                _buildActionButton(
                  context,
                  'Seed Dummy Data',
                  Icons.data_object,
                  Colors.purple,
                  () {
                    context.go('/seed-dummy-data');
                  },
                ),
                _buildActionButton(
                  context,
                  'Add Account',
                  Icons.person_add,
                  Colors.teal,
                  () {
                    _showAddAccountDialog(context, ref);
                  },
                ),
                _buildActionButton(
                  context,
                  'Platform Fee',
                  Icons.percent,
                  Colors.indigo,
                  () {
                    _AdminDashboardPageState.of(context)?.setSelectedIndex(6);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddAccountDialog(BuildContext context, WidgetRef ref) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Admin Account'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Display Name *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password *',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              const Text(
                'Note: Firebase Auth account needs to be created separately using Firebase Console or Admin SDK.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty ||
                  emailController.text.isEmpty ||
                  passwordController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all fields')),
                );
                return;
              }

              try {
                final adminService = ref.read(adminServiceProvider);
                await adminService.createAdminAccount(
                  email: emailController.text,
                  password: passwordController.text,
                  displayName: nameController.text,
                );

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Admin account document created. Please create Firebase Auth account separately.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return _InteractiveActionButton(
      label: label,
      icon: icon,
      color: color,
      onTap: onTap,
    );
  }
}

/// Interactive Action Button with hover effects
class _InteractiveActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _InteractiveActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_InteractiveActionButton> createState() => _InteractiveActionButtonState();
}

class _InteractiveActionButtonState extends State<_InteractiveActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.identity()..scale(_isHovered ? 1.05 : 1.0),
        child: ElevatedButton.icon(
          onPressed: widget.onTap,
          icon: Icon(widget.icon, size: 18),
          label: Text(widget.label),
          style: ElevatedButton.styleFrom(
            backgroundColor: _isHovered 
                ? widget.color.withValues(alpha: 0.2) 
                : widget.color.withValues(alpha: 0.1),
            foregroundColor: widget.color,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            elevation: _isHovered ? 4 : 2,
          ),
        ),
      ),
    );
  }

}

Widget _buildRecentActivity(BuildContext context, WidgetRef ref) {
  return Card(
    elevation: 3,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Activity',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              TextButton.icon(
                onPressed: () {
                  // ignore: unused_result
                  ref.refresh(_dashboardStatsProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Activity refreshed'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 5,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              return _InteractiveActivityItem(
                index: index,
              );
            },
          ),
        ],
      ),
    ),
  );
}

/// Interactive Activity Item Widget
class _InteractiveActivityItem extends StatefulWidget {
  final int index;

  const _InteractiveActivityItem({
    required this.index,
  });

  @override
  State<_InteractiveActivityItem> createState() => _InteractiveActivityItemState();
}

class _InteractiveActivityItemState extends State<_InteractiveActivityItem> {
  bool _isHovered = false;

  Color _getActivityColor(int index) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
    ];
    return colors[index % colors.length];
  }

  IconData _getActivityIcon(int index) {
    final icons = [
      Icons.person_add,
      Icons.check_circle,
      Icons.payment,
      Icons.notifications,
      Icons.settings,
    ];
    return icons[index % icons.length];
  }

  String _getActivityTitle(int index) {
    final titles = [
      'New Provider Registered',
      'Booking Completed',
      'Payment Received',
      'System Notification',
      'Settings Updated',
    ];
    return titles[index % titles.length];
  }

  String _getActivityDescription(int index) {
    final descriptions = [
      'A new provider joined the platform',
      'Service booking was successfully completed',
      'Payment transaction was processed',
      'System update notification sent',
      'Admin settings were modified',
    ];
    return descriptions[index % descriptions.length];
  }

  @override
  Widget build(BuildContext context) {
    final color = _getActivityColor(widget.index);
    final icon = _getActivityIcon(widget.index);
    final title = _getActivityTitle(widget.index);
    final description = _getActivityDescription(widget.index);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(_isHovered ? 12 : 10),
        decoration: BoxDecoration(
          color: _isHovered ? color.withValues(alpha: 0.05) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: InkWell(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$title: $description'),
                duration: const Duration(seconds: 1),
              ),
            );
          },
          borderRadius: BorderRadius.circular(8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                  ],
                ),
              ),
              Text(
                '${widget.index + 1}h ago',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade500,
                      fontSize: 11,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Providers Management View
class _ProvidersView extends ConsumerStatefulWidget {
  const _ProvidersView();

  @override
  ConsumerState<_ProvidersView> createState() => _ProvidersViewState();
}

class _ProvidersViewState extends ConsumerState<_ProvidersView> {
  String _searchQuery = '';
  String _statusFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final adminService = ref.read(adminServiceProvider);
    final providersStream = adminService.getAllProviders();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Providers Management',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Export feature coming soon')),
                      );
                    },
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Export'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => setState(() {}),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Search and Filter Bar
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search providers by name, email, or phone...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                flex: 1,
                child: DropdownButton<String>(
                  value: _statusFilter,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Status')),
                    DropdownMenuItem(value: 'online', child: Text('Online')),
                    DropdownMenuItem(value: 'offline', child: Text('Offline')),
                    DropdownMenuItem(
                        value: 'suspended', child: Text('Suspended')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _statusFilter = value ?? 'all';
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: providersStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            size: 48, color: Colors.red.shade300),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                var providers = snapshot.data ?? [];

                // Apply filters
                if (_searchQuery.isNotEmpty) {
                  providers = providers.where((provider) {
                    final name = (provider['displayName'] ?? '')
                        .toString()
                        .toLowerCase();
                    final email =
                        (provider['email'] ?? '').toString().toLowerCase();
                    final phone =
                        (provider['phone'] ?? '').toString().toLowerCase();
                    return name.contains(_searchQuery) ||
                        email.contains(_searchQuery) ||
                        phone.contains(_searchQuery);
                  }).toList();
                }

                if (_statusFilter != 'all') {
                  providers = providers.where((provider) {
                    final isActive = provider['isActive'] ?? true;
                    final isOnline = provider['isOnline'] ?? false;
                    if (_statusFilter == 'suspended') return !isActive;
                    if (_statusFilter == 'online') return isActive && isOnline;
                    if (_statusFilter == 'offline') {
                      return isActive && !isOnline;
                    }
                    return true;
                  }).toList();
                }

                if (providers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty || _statusFilter != 'all'
                              ? 'No providers match your filters'
                              : 'No providers found',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                        ),
                      ],
                    ),
                  );
                }

                return Card(
                  elevation: 2,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Email')),
                        DataColumn(label: Text('Phone')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Bookings'), numeric: true),
                        DataColumn(label: Text('Rating'), numeric: true),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: providers.map((provider) {
                        final isActive = provider['isActive'] ?? true;
                        final isOnline = provider['isOnline'] ?? false;
                        final totalBookings = provider['totalBookings'] ?? 0;
                        final rating = provider['rating'] ?? 0.0;

                        return DataRow(
                          cells: [
                            DataCell(
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundImage:
                                        provider['photoUrl'] != null
                                            ? NetworkImage(provider['photoUrl'])
                                            : null,
                                    child: provider['photoUrl'] == null
                                        ? Text(
                                            (provider['displayName'] ??
                                                    'N/A')[0]
                                                .toUpperCase(),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(provider['displayName'] ?? 'N/A'),
                                ],
                              ),
                            ),
                            DataCell(Text(provider['email'] ?? 'N/A')),
                            DataCell(Text(provider['phone'] ?? 'N/A')),
                            DataCell(
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? (isOnline
                                              ? Colors.green
                                              : Colors.grey)
                                          : Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(isActive
                                      ? (isOnline ? 'Online' : 'Offline')
                                      : 'Suspended'),
                                ],
                              ),
                            ),
                            DataCell(Text(totalBookings.toString())),
                            DataCell(
                              Row(
                                children: [
                                  const Icon(Icons.star,
                                      size: 16, color: Colors.amber),
                                  const SizedBox(width: 4),
                                  Text(rating.toStringAsFixed(1)),
                                ],
                              ),
                            ),
                            DataCell(
                              Row(
                                children: [
                                  IconButton(
                                    icon:
                                        const Icon(Icons.visibility, size: 18),
                                    onPressed: () {
                                      _showProviderDetails(context, provider);
                                    },
                                    tooltip: 'View Details',
                                    color: Colors.blue,
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      isActive
                                          ? Icons.block
                                          : Icons.check_circle,
                                      size: 18,
                                      color:
                                          isActive ? Colors.red : Colors.green,
                                    ),
                                    onPressed: () async {
                                      await _toggleProviderStatus(
                                        context,
                                        ref,
                                        provider['id'] as String,
                                        !isActive,
                                      );
                                    },
                                    tooltip: isActive ? 'Suspend' : 'Activate',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showProviderDetails(
      BuildContext context, Map<String, dynamic> provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(provider['displayName'] ?? 'Provider Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Email', provider['email'] ?? 'N/A'),
              _buildDetailRow('Phone', provider['phone'] ?? 'N/A'),
              _buildDetailRow('Status',
                  provider['isActive'] == true ? 'Active' : 'Suspended'),
              _buildDetailRow(
                  'Online', provider['isOnline'] == true ? 'Yes' : 'No'),
              _buildDetailRow('Total Bookings',
                  (provider['totalBookings'] ?? 0).toString()),
              _buildDetailRow(
                  'Rating', (provider['rating'] ?? 0.0).toStringAsFixed(1)),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  static Future<void> _toggleProviderStatus(
    BuildContext context,
    WidgetRef ref,
    String providerId,
    bool isActive,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isActive ? 'Activate Provider' : 'Suspend Provider'),
        content: Text(
          isActive
              ? 'Are you sure you want to activate this provider?'
              : 'Are you sure you want to suspend this provider?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isActive ? Colors.green : Colors.red,
            ),
            child: Text(isActive ? 'Activate' : 'Suspend'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final adminService = ref.read(adminServiceProvider);
        await adminService.updateProviderStatus(
          providerId: providerId,
          isActive: isActive,
          reason: isActive ? null : 'Suspended by admin',
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isActive
                    ? 'Provider activated successfully'
                    : 'Provider suspended successfully',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

/// Users Management View
class _UsersView extends ConsumerStatefulWidget {
  const _UsersView();

  @override
  ConsumerState<_UsersView> createState() => _UsersViewState();
}

class _UsersViewState extends ConsumerState<_UsersView> {
  String _searchQuery = '';
  String _statusFilter = 'all';
  String _typeFilter = 'all'; // all, user, provider

  @override
  Widget build(BuildContext context) {
    final adminService = ref.read(adminServiceProvider);
    final usersStream = adminService.getAllUsers();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Users Management',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Export feature coming soon')),
                      );
                    },
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Export'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => setState(() {}),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Search and Filter Bar
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search users by name, email, or phone...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                flex: 1,
                child: DropdownButton<String>(
                  value: _typeFilter,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Types')),
                    DropdownMenuItem(value: 'user', child: Text('Users')),
                    DropdownMenuItem(value: 'provider', child: Text('Providers')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _typeFilter = value ?? 'all';
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                flex: 1,
                child: DropdownButton<String>(
                  value: _statusFilter,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Status')),
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                    DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _statusFilter = value ?? 'all';
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: usersStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                var users = snapshot.data ?? [];

                // Apply search filter
                if (_searchQuery.isNotEmpty) {
                  users = users.where((user) {
                    final name = (user['displayName'] ?? user['name'] ?? '').toString().toLowerCase();
                    final email = (user['email'] ?? '').toString().toLowerCase();
                    final phone = (user['phone'] ?? '').toString().toLowerCase();
                    return name.contains(_searchQuery) ||
                        email.contains(_searchQuery) ||
                        phone.contains(_searchQuery);
                  }).toList();
                }

                // Apply type filter (user/provider)
                if (_typeFilter != 'all') {
                  users = users.where((user) {
                    final userType = user['userType'] ?? user['role'] ?? 'user';
                    return userType == _typeFilter;
                  }).toList();
                }

                // Apply status filter
                if (_statusFilter != 'all') {
                  users = users.where((user) {
                    final isActive = user['isActive'] ?? true;
                    if (_statusFilter == 'active') {
                      return isActive;
                    } else if (_statusFilter == 'inactive') {
                      return !isActive;
                    } else if (_statusFilter == 'suspended') {
                      return !isActive && user['suspendedAt'] != null;
                    }
                    return true;
                  }).toList();
                }

                if (users.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_outline, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty || _statusFilter != 'all'
                              ? 'No users match your filters'
                              : 'No users found',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                        ),
                      ],
                    ),
                  );
                }

                return Card(
                  elevation: 2,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: DataTable(
                        columnSpacing: 12,
                        horizontalMargin: 12,
                        dataRowMinHeight: 44,
                        dataRowMaxHeight: 48,
                        columns: const [
                          DataColumn(label: Text('Type', style: TextStyle(fontSize: 12))),
                          DataColumn(label: Text('Name', style: TextStyle(fontSize: 12))),
                          DataColumn(label: Text('Email', style: TextStyle(fontSize: 12))),
                          DataColumn(label: Text('Phone', style: TextStyle(fontSize: 12))),
                          DataColumn(label: Text('Status', style: TextStyle(fontSize: 12))),
                          DataColumn(label: Text('Role', style: TextStyle(fontSize: 12))),
                          DataColumn(label: Text('Bookings', style: TextStyle(fontSize: 12))),
                          DataColumn(label: Text('Created', style: TextStyle(fontSize: 12))),
                          DataColumn(label: Text('Actions', style: TextStyle(fontSize: 12))),
                        ],
                        rows: users.map((user) {
                          final isActive = user['isActive'] ?? true;
                          final createdAt = user['createdAt'] as Timestamp?;
                          final role = user['role'] ?? 'user';

                          final userType = user['userType'] ?? user['role'] ?? 'user';
                          final isProvider = userType == 'provider';
                          final totalBookings = user['totalBookings'] ?? 0;
                          final completedBookings = user['completedBookings'] ?? 0;
                          final rating = user['rating'] ?? 0.0;

                          return DataRow(
                            cells: [
                              DataCell(
                                SizedBox(
                                  width: 100,
                                  child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isProvider
                                        ? Colors.purple.withValues(alpha: 0.2)
                                        : Colors.orange.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isProvider ? Icons.build : Icons.person,
                                        size: 12,
                                        color: isProvider ? Colors.purple : Colors.orange,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          isProvider ? 'Provider' : 'User',
                                          style: TextStyle(
                                            color: isProvider ? Colors.purple : Colors.orange,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 200,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundImage: user['photoUrl'] != null
                                          ? NetworkImage(user['photoUrl'])
                                          : null,
                                      child: user['photoUrl'] == null
                                          ? Text(
                                              (user['displayName'] ?? user['name'] ?? 'U')
                                                  .toString()
                                                  .substring(0, 1)
                                                  .toUpperCase(),
                                              style: const TextStyle(fontSize: 12),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        user['displayName'] ?? user['name'] ?? 'Unknown',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 180,
                                child: Text(
                                  user['email'] ?? 'N/A',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 120,
                                child: Text(
                                  user['phone'] ?? 'N/A',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 100,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? Colors.green.withValues(alpha: 0.2)
                                        : Colors.red.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isProvider && user['isOnline'] == true)
                                        Container(
                                          width: 6,
                                          height: 6,
                                          margin: const EdgeInsets.only(right: 4),
                                          decoration: const BoxDecoration(
                                            color: Colors.green,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      Flexible(
                                        child: Text(
                                          isActive ? 'Active' : 'Inactive',
                                          style: TextStyle(
                                            color: isActive ? Colors.green : Colors.red,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 80,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    role.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              isProvider
                                  ? SizedBox(
                                      width: 120,
                                      child: rating > 0
                                          ? Text(
                                              'T:$totalBookings D:$completedBookings ⭐${rating.toStringAsFixed(1)}',
                                              style: const TextStyle(fontSize: 10, height: 1.1),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            )
                                          : Text(
                                              'T:$totalBookings D:$completedBookings',
                                              style: const TextStyle(fontSize: 10, height: 1.1),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                    )
                                  : const Text('N/A', style: TextStyle(fontSize: 11)),
                            ),
                            DataCell(
                              SizedBox(
                                width: 100,
                                child: Text(
                                  createdAt != null
                                      ? DateFormat('MMM d, y').format(createdAt.toDate())
                                      : 'N/A',
                                  style: const TextStyle(fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 100,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.visibility, size: 16),
                                      onPressed: () {
                                        _showUserDetails(context, user);
                                      },
                                      tooltip: 'View Details',
                                      color: Colors.blue,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: Icon(
                                        isActive ? Icons.block : Icons.check_circle,
                                        size: 16,
                                      ),
                                      onPressed: () {
                                        _toggleUserStatus(context, ref, user, !isActive);
                                      },
                                      tooltip: isActive ? 'Suspend' : 'Activate',
                                      color: isActive ? Colors.red : Colors.green,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showUserDetails(BuildContext context, Map<String, dynamic> user) {
    final createdAt = user['createdAt'] as Timestamp?;
    final updatedAt = user['updatedAt'] as Timestamp?;
    final userType = user['userType'] ?? user['role'] ?? 'user';
    final isProvider = userType == 'provider';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${isProvider ? 'Provider' : 'User'} Details - ${user['displayName'] ?? user['name'] ?? 'Unknown'}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Type', isProvider ? 'Provider' : 'User'),
              _buildDetailRow('Name', user['displayName'] ?? user['name'] ?? 'N/A'),
              _buildDetailRow('Email', user['email'] ?? 'N/A'),
              _buildDetailRow('Phone', user['phone'] ?? 'N/A'),
              _buildDetailRow('Role', (user['role'] ?? userType).toUpperCase()),
              _buildDetailRow(
                'Status',
                (user['isActive'] == true ? 'Active' : 'Inactive'),
              ),
              if (isProvider) ...[
                _buildDetailRow(
                  'Online Status',
                  (user['isOnline'] == true ? 'Online' : 'Offline'),
                ),
                _buildDetailRow(
                  'Rating',
                  user['rating'] != null ? '⭐ ${(user['rating'] as num).toStringAsFixed(1)}' : 'N/A',
                ),
                _buildDetailRow(
                  'Total Bookings',
                  (user['totalBookings'] ?? 0).toString(),
                ),
                _buildDetailRow(
                  'Completed Bookings',
                  (user['completedBookings'] ?? 0).toString(),
                ),
              ],
              _buildDetailRow(
                'Verified',
                (user['isVerified'] == true ? 'Yes' : 'No'),
              ),
              _buildDetailRow(
                'Password',
                user['password'] ?? user['tempPassword'] ?? 'Not stored (Firebase Auth)',
              ),
              _buildDetailRow(
                'Created At',
                createdAt != null
                    ? DateFormat('MMM d, y h:mm a').format(createdAt.toDate())
                    : 'N/A',
              ),
              _buildDetailRow(
                'Updated At',
                updatedAt != null
                    ? DateFormat('MMM d, y h:mm a').format(updatedAt.toDate())
                    : 'N/A',
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  static Future<void> _toggleUserStatus(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> user,
    bool isActive,
  ) async {
    final userType = user['userType'] ?? user['role'] ?? 'user';
    final isProvider = userType == 'provider';
    final userId = user['id'] as String;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isActive 
            ? 'Activate ${isProvider ? 'Provider' : 'User'}' 
            : 'Suspend ${isProvider ? 'Provider' : 'User'}'),
        content: Text(
          isActive
              ? 'Are you sure you want to activate this ${isProvider ? 'provider' : 'user'}?'
              : 'Are you sure you want to suspend this ${isProvider ? 'provider' : 'user'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isActive ? Colors.green : Colors.red,
            ),
            child: Text(isActive ? 'Activate' : 'Suspend'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final adminService = ref.read(adminServiceProvider);
        
        if (isProvider) {
          // Update provider status
          await adminService.updateProviderStatus(
            providerId: userId,
            isActive: isActive,
            reason: isActive ? null : 'Suspended by admin',
          );
        } else {
          // Update user status
          await adminService.updateUserStatus(
            userId: userId,
            isActive: isActive,
            reason: isActive ? null : 'Suspended by admin',
          );
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${isProvider ? 'Provider' : 'User'} ${isActive ? 'activated' : 'suspended'} successfully',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

/// Bookings View
class _BookingsView extends ConsumerStatefulWidget {
  const _BookingsView();

  @override
  ConsumerState<_BookingsView> createState() => _BookingsViewState();
}

class _BookingsViewState extends ConsumerState<_BookingsView> {
  String _statusFilter = 'all';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final adminService = ref.read(adminServiceProvider);
    final bookingsStream = adminService.getAllBookingsStream(
        status: _statusFilter == 'all' ? null : _statusFilter);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'All Bookings',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Export feature coming soon')),
                      );
                    },
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Export'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => setState(() {}),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Search and Filter Bar
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  decoration: InputDecoration(
                    hintText:
                        'Search bookings by customer name, service, or booking ID...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                flex: 1,
                child: DropdownButton<String>(
                  value: _statusFilter,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Status')),
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(
                        value: 'accepted', child: Text('Accepted')),
                    DropdownMenuItem(
                        value: 'in_progress', child: Text('In Progress')),
                    DropdownMenuItem(
                        value: 'completed', child: Text('Completed')),
                    DropdownMenuItem(
                        value: 'cancelled', child: Text('Cancelled')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _statusFilter = value ?? 'all';
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: bookingsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            size: 48, color: Colors.red.shade300),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                var bookings = snapshot.data ?? [];

                // Apply search filter
                if (_searchQuery.isNotEmpty) {
                  bookings = bookings.where((booking) {
                    final customerName = (booking['customerName'] ?? '')
                        .toString()
                        .toLowerCase();
                    final serviceName =
                        (booking['serviceName'] ?? '').toString().toLowerCase();
                    final bookingId =
                        (booking['id'] ?? '').toString().toLowerCase();
                    return customerName.contains(_searchQuery) ||
                        serviceName.contains(_searchQuery) ||
                        bookingId.contains(_searchQuery);
                  }).toList();
                }

                if (bookings.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.book_outlined,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty || _statusFilter != 'all'
                              ? 'No bookings match your filters'
                              : 'No bookings found',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                        ),
                      ],
                    ),
                  );
                }

                return Card(
                  elevation: 2,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Booking ID')),
                        DataColumn(label: Text('Customer')),
                        DataColumn(label: Text('Service')),
                        DataColumn(label: Text('Amount')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Payment')),
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: bookings.map((booking) {
                        final status = booking['status'] ?? 'pending';
                        final amount = booking['amount'] ?? 0.0;
                        final paymentStatus =
                            booking['paymentStatus'] ?? 'unpaid';
                        final scheduledDate =
                            booking['scheduledDate'] as Timestamp?;
                        final createdAt = booking['createdAt'] as Timestamp?;

                        return DataRow(
                          cells: [
                            DataCell(Text(
                              booking['id'].toString().substring(0, 8),
                              style: const TextStyle(fontFamily: 'monospace'),
                            )),
                            DataCell(
                                Text(booking['customerName'] ?? 'Unknown')),
                            DataCell(Text(booking['serviceName'] ?? 'N/A')),
                            DataCell(Text('₹${amount.toStringAsFixed(0)}')),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(status)
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    color: _getStatusColor(status),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(Text(paymentStatus.toUpperCase())),
                            DataCell(Text(
                              scheduledDate != null
                                  ? DateFormat('MMM d, y')
                                      .format(scheduledDate.toDate())
                                  : createdAt != null
                                      ? DateFormat('MMM d, y')
                                          .format(createdAt.toDate())
                                      : 'N/A',
                            )),
                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.visibility, size: 18),
                                onPressed: () {
                                  _showBookingDetails(context, booking);
                                },
                                tooltip: 'View Details',
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.amber;
      case 'accepted':
        return Colors.blue;
      case 'in_progress':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _showBookingDetails(BuildContext context, Map<String, dynamic> booking) async {
    final scheduledDate = booking['scheduledDate'] as Timestamp?;
    final createdAt = booking['createdAt'] as Timestamp?;
    final providerId = booking['providerId'] as String?;

    // Fetch provider details
    Map<String, dynamic>? providerData;
    if (providerId != null) {
      try {
        final adminService = ref.read(adminServiceProvider);
        providerData = await adminService.getProviderDetails(providerId);
      } catch (e) {
        // ignore: avoid_print
        print('❌ Error fetching provider details: $e');
      }
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            'Booking Details - ${booking['id'].toString().substring(0, 8)}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(
                  'Customer Name', booking['customerName'] ?? 'N/A'),
              _buildDetailRow(
                  'Customer Phone', booking['customerPhone'] ?? 'N/A'),
              _buildDetailRow('Service', booking['serviceName'] ?? 'N/A'),
              _buildDetailRow('Amount',
                  '₹${(booking['amount'] ?? 0.0).toStringAsFixed(2)}'),
              _buildDetailRow(
                  'Status', (booking['status'] ?? 'pending').toUpperCase()),
              _buildDetailRow('Payment Status',
                  (booking['paymentStatus'] ?? 'unpaid').toUpperCase()),
              _buildDetailRow('Payment Method',
                  (booking['paymentMethod'] ?? 'cod').toUpperCase()),
              _buildDetailRow('Address', booking['address'] ?? 'N/A'),
              const Divider(height: 24),
              // Provider Information Section
              Text(
                'Provider Information',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              _buildDetailRow(
                'Provider Name',
                providerData?['displayName'] ?? providerData?['name'] ?? 'N/A',
              ),
              _buildDetailRow(
                'Provider Email',
                providerData?['email'] ?? 'N/A',
              ),
              _buildDetailRow(
                'Provider Phone',
                providerData?['phone'] ?? 'N/A',
              ),
              _buildDetailRow(
                'Provider Password',
                providerData?['password'] ?? providerData?['tempPassword'] ?? 'Not stored (Firebase Auth)',
              ),
              const Divider(height: 24),
              _buildDetailRow(
                'Scheduled Date',
                scheduledDate != null
                    ? DateFormat('MMM d, y h:mm a')
                        .format(scheduledDate.toDate())
                    : 'N/A',
              ),
              _buildDetailRow(
                'Created At',
                createdAt != null
                    ? DateFormat('MMM d, y h:mm a').format(createdAt.toDate())
                    : 'N/A',
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

/// Payments View
class _PaymentsView extends ConsumerStatefulWidget {
  const _PaymentsView();

  @override
  ConsumerState<_PaymentsView> createState() => _PaymentsViewState();
}

class _PaymentsViewState extends ConsumerState<_PaymentsView> {
  String _statusFilter = 'all';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final adminService = ref.read(adminServiceProvider);
    final paymentsStream = adminService.getAllPaymentsStream();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'All Payments',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Export feature coming soon')),
                      );
                    },
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Export'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => setState(() {}),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Search and Filter Bar
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search payments by booking ID or provider...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                flex: 1,
                child: DropdownButton<String>(
                  value: _statusFilter,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Status')),
                    DropdownMenuItem(value: 'paid', child: Text('Paid')),
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'failed', child: Text('Failed')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _statusFilter = value ?? 'all';
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: paymentsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            size: 48, color: Colors.red.shade300),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                var payments = snapshot.data ?? [];

                // Apply filters
                if (_statusFilter != 'all') {
                  payments = payments.where((payment) {
                    return (payment['status'] ?? '').toString().toLowerCase() ==
                        _statusFilter;
                  }).toList();
                }

                if (_searchQuery.isNotEmpty) {
                  payments = payments.where((payment) {
                    final bookingId =
                        (payment['bookingId'] ?? '').toString().toLowerCase();
                    final paymentId =
                        (payment['id'] ?? '').toString().toLowerCase();
                    return bookingId.contains(_searchQuery) ||
                        paymentId.contains(_searchQuery);
                  }).toList();
                }

                if (payments.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.payment_outlined,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty || _statusFilter != 'all'
                              ? 'No payments match your filters'
                              : 'No payments found',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                        ),
                      ],
                    ),
                  );
                }

                // Calculate totals
                final totalAmount = payments.fold<double>(
                  0.0,
                  (total, payment) => total + (payment['amount'] ?? 0.0),
                );
                final totalPlatformFee = payments.fold<double>(
                  0.0,
                  (total, payment) => total + (payment['platformFee'] ?? 0.0),
                );
                final totalProviderEarnings = payments.fold<double>(
                  0.0,
                  (total, payment) => total + (payment['providerEarning'] ?? 0.0),
                );

                return Column(
                  children: [
                    // Summary Cards
                    Row(
                      children: [
                        Expanded(
                          child: Card(
                            color: Colors.blue.shade50,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Total Amount',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '₹${NumberFormat('#,##,###').format(totalAmount)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Card(
                            color: Colors.purple.shade50,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Platform Fee',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '₹${NumberFormat('#,##,###').format(totalPlatformFee)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.purple,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Card(
                            color: Colors.green.shade50,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Provider Earnings',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '₹${NumberFormat('#,##,###').format(totalProviderEarnings)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Payments Table
                    Expanded(
                      child: Card(
                        elevation: 2,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Payment ID')),
                              DataColumn(label: Text('Booking ID')),
                              DataColumn(label: Text('Amount'), numeric: true),
                              DataColumn(
                                  label: Text('Platform Fee'), numeric: true),
                              DataColumn(
                                  label: Text('Provider Earning'),
                                  numeric: true),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Method')),
                              DataColumn(label: Text('Date')),
                            ],
                            rows: payments.map((payment) {
                              final amount = payment['amount'] ?? 0.0;
                              final platformFee = payment['platformFee'] ?? 0.0;
                              final providerEarning =
                                  payment['providerEarning'] ?? 0.0;
                              final status = payment['status'] ?? 'pending';
                              final paidAt = payment['paidAt'] as Timestamp?;
                              final createdAt =
                                  payment['createdAt'] as Timestamp?;

                              return DataRow(
                                cells: [
                                  DataCell(Text(
                                    payment['id'].toString().substring(0, 8),
                                    style: const TextStyle(
                                        fontFamily: 'monospace'),
                                  )),
                                  DataCell(Text(
                                    (payment['bookingId'] ?? '')
                                        .toString()
                                        .substring(0, 8),
                                    style: const TextStyle(
                                        fontFamily: 'monospace'),
                                  )),
                                  DataCell(
                                      Text('₹${amount.toStringAsFixed(2)}')),
                                  DataCell(Text(
                                      '₹${platformFee.toStringAsFixed(2)}')),
                                  DataCell(Text(
                                      '₹${providerEarning.toStringAsFixed(2)}')),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: status == 'paid'
                                            ? Colors.green
                                                .withValues(alpha: 0.2)
                                            : Colors.amber
                                                .withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        status.toUpperCase(),
                                        style: TextStyle(
                                          color: status == 'paid'
                                              ? Colors.green
                                              : Colors.amber,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(
                                      (payment['paymentMethod'] ?? 'cod')
                                          .toUpperCase())),
                                  DataCell(Text(
                                    paidAt != null
                                        ? DateFormat('MMM d, y')
                                            .format(paidAt.toDate())
                                        : createdAt != null
                                            ? DateFormat('MMM d, y')
                                                .format(createdAt.toDate())
                                            : 'N/A',
                                  )),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Provider Services Management View
class _ProviderServicesView extends ConsumerStatefulWidget {
  const _ProviderServicesView();

  @override
  ConsumerState<_ProviderServicesView> createState() => _ProviderServicesViewState();
}

class _ProviderServicesViewState extends ConsumerState<_ProviderServicesView> {
  String _searchQuery = '';
  String? _providerFilter;

  @override
  Widget build(BuildContext context) {
    final adminService = ref.read(adminServiceProvider);
    final servicesStream = adminService.getAllProviderServices(providerId: _providerFilter);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Provider Services Management',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddServiceDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Add Service'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Search and Filter Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search services...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: servicesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                      ],
                    ),
                  );
                }

                var services = snapshot.data ?? [];

                // Apply search filter
                if (_searchQuery.isNotEmpty) {
                  services = services.where((service) {
                    final name = (service['serviceName'] ?? '').toString().toLowerCase();
                    final category = (service['category'] ?? '').toString().toLowerCase();
                    return name.contains(_searchQuery) || category.contains(_searchQuery);
                  }).toList();
                }

                if (services.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.build_circle, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'No services found',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Service Name')),
                      DataColumn(label: Text('Provider ID')),
                      DataColumn(label: Text('Category')),
                      DataColumn(label: Text('Base Price')),
                      DataColumn(label: Text('Platform Fee')),
                      DataColumn(label: Text('Duration')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: services.map((service) {
                      final serviceName = service['serviceName'] ?? 'N/A';
                      final providerId = service['providerId'] ?? 'N/A';
                      final category = service['category'] ?? 'N/A';
                      final basePrice = (service['basePrice'] ?? 0.0).toDouble();
                      final platformFee = (service['platformFee'] ?? 0.0).toDouble();
                      final duration = service['duration'] ?? 0;
                      final isActive = service['isActive'] ?? true;

                      return DataRow(
                        cells: [
                          DataCell(Text(serviceName)),
                          DataCell(Text(providerId.length > 20 ? '${providerId.substring(0, 20)}...' : providerId)),
                          DataCell(Text(category)),
                          DataCell(Text('₹${basePrice.toStringAsFixed(2)}')),
                          DataCell(Text('₹${platformFee.toStringAsFixed(2)}')),
                          DataCell(Text('$duration min')),
                          DataCell(
                            Chip(
                              label: Text(isActive ? 'Active' : 'Inactive'),
                              backgroundColor: isActive ? Colors.green.shade100 : Colors.red.shade100,
                              labelStyle: TextStyle(
                                color: isActive ? Colors.green.shade800 : Colors.red.shade800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18),
                                  onPressed: () => _showEditServiceDialog(context, service),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 18),
                                  color: Colors.red,
                                  onPressed: () => _showDeleteServiceDialog(context, service),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddServiceDialog(BuildContext context) {
    final providerIdController = TextEditingController();
    final serviceNameController = TextEditingController();
    final descriptionController = TextEditingController();
    final basePriceController = TextEditingController();
    final durationController = TextEditingController();
    final categoryController = TextEditingController();
    final platformFeePercentageController = TextEditingController(text: '10.0');
    bool isActive = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Provider Service'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: providerIdController,
                    decoration: const InputDecoration(
                      labelText: 'Provider ID *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: serviceNameController,
                    decoration: const InputDecoration(
                      labelText: 'Service Name *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description *',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: basePriceController,
                          decoration: const InputDecoration(
                            labelText: 'Base Price (₹) *',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: durationController,
                          decoration: const InputDecoration(
                            labelText: 'Duration (minutes) *',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: categoryController,
                          decoration: const InputDecoration(
                            labelText: 'Category *',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: platformFeePercentageController,
                          decoration: const InputDecoration(
                            labelText: 'Platform Fee (%) *',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('Active'),
                    value: isActive,
                    onChanged: (value) {
                      setDialogState(() {
                        isActive = value ?? true;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (providerIdController.text.isEmpty ||
                    serviceNameController.text.isEmpty ||
                    descriptionController.text.isEmpty ||
                    basePriceController.text.isEmpty ||
                    durationController.text.isEmpty ||
                    categoryController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all required fields')),
                  );
                  return;
                }

                try {
                  final adminService = ref.read(adminServiceProvider);
                  await adminService.createProviderService(
                    providerId: providerIdController.text,
                    serviceName: serviceNameController.text,
                    description: descriptionController.text,
                    basePrice: double.parse(basePriceController.text),
                    duration: int.parse(durationController.text),
                    category: categoryController.text,
                    platformFeePercentage: double.parse(platformFeePercentageController.text),
                  );

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Service added successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Add Service'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditServiceDialog(BuildContext context, Map<String, dynamic> service) {
    // Similar to add dialog but with pre-filled values
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit service feature coming soon')),
    );
  }

  void _showDeleteServiceDialog(BuildContext context, Map<String, dynamic> service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Service'),
        content: Text('Are you sure you want to delete "${service['serviceName']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Delete feature coming soon')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// Settings View - Platform Fee Management
class _SettingsView extends ConsumerStatefulWidget {
  const _SettingsView();

  @override
  ConsumerState<_SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<_SettingsView> {
  @override
  Widget build(BuildContext context) {
    final adminService = ref.read(adminServiceProvider);
    final feeConfigFuture = adminService.getPlatformFeeConfig();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Platform Fee Configuration',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showPlatformFeeDialog(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<Map<String, dynamic>>(
                    future: feeConfigFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      }

                      final config = snapshot.data ?? {};
                      final defaultFee = (config['defaultFeePercentage'] ?? 10.0).toDouble();
                      final minFee = (config['minFee'] ?? 0.0).toDouble();
                      final maxFee = (config['maxFee'] ?? 100.0).toDouble();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildConfigRow('Default Fee Percentage', '${defaultFee.toStringAsFixed(1)}%'),
                          const SizedBox(height: 12),
                          _buildConfigRow('Minimum Fee', '${minFee.toStringAsFixed(1)}%'),
                          const SizedBox(height: 12),
                          _buildConfigRow('Maximum Fee', '${maxFee.toStringAsFixed(1)}%'),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      ],
    );
  }

  void _showPlatformFeeDialog(BuildContext context) {
    final defaultFeeController = TextEditingController();
    final minFeeController = TextEditingController();
    final maxFeeController = TextEditingController();

    final adminService = ref.read(adminServiceProvider);
    adminService.getPlatformFeeConfig().then((config) {
      defaultFeeController.text = (config['defaultFeePercentage'] ?? 10.0).toString();
      minFeeController.text = (config['minFee'] ?? 0.0).toString();
      maxFeeController.text = (config['maxFee'] ?? 100.0).toString();
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Platform Fee Configuration'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: defaultFeeController,
                decoration: const InputDecoration(
                  labelText: 'Default Fee Percentage (%) *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: minFeeController,
                decoration: const InputDecoration(
                  labelText: 'Minimum Fee (%) *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: maxFeeController,
                decoration: const InputDecoration(
                  labelText: 'Maximum Fee (%) *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await adminService.updatePlatformFeeConfig(
                  defaultFeePercentage: double.tryParse(defaultFeeController.text),
                  minFee: double.tryParse(minFeeController.text),
                  maxFee: double.tryParse(maxFeeController.text),
                );

                if (context.mounted) {
                  Navigator.pop(context);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Platform fee configuration updated'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}

/// Interactive Stat Card Widget
class _InteractiveStatCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _InteractiveStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  State<_InteractiveStatCard> createState() => _InteractiveStatCardState();
}

class _InteractiveStatCardState extends State<_InteractiveStatCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        transform: Matrix4.identity()..scale(_isHovered ? 1.02 : 1.0),
        child: Card(
          elevation: _isHovered ? 4 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${widget.title}: ${widget.value}'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(widget.icon, color: widget.color, size: 15),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade600,
                                fontSize: 9,
                                height: 1.0,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            widget.value,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: widget.color,
                                  fontSize: 14,
                                  height: 1.0,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Provider for dashboard stats
final _dashboardStatsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final adminService = ref.read(adminServiceProvider);
  return await adminService.getDashboardStats();
});
