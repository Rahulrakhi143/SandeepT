import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trivora_provider/core/providers/auth_provider.dart';
import 'package:trivora_provider/core/providers/dashboard_provider.dart';
import 'package:trivora_provider/core/services/firebase_auth_service.dart';

/// Provider Dashboard Page
/// Responsive layout: Sidebar for web, Bottom nav for mobile
class ProviderDashboardPage extends ConsumerStatefulWidget {
  const ProviderDashboardPage({super.key});

  @override
  ConsumerState<ProviderDashboardPage> createState() => _ProviderDashboardPageState();
}

class _ProviderDashboardPageState extends ConsumerState<ProviderDashboardPage> {
  @override
  Widget build(BuildContext context) {
    final authUserAsync = ref.watch(authStateProvider);
    final authUser = authUserAsync.valueOrNull;

    return _buildDashboardContent(context, authUser);
  }

  Widget _buildDashboardContent(BuildContext context, dynamic user) {
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 120,
          floating: false,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            title: const Text(
              'Provider Dashboard',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primaryContainer,
                  ],
                ),
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {
                // Navigate to notifications
              },
            ),
            PopupMenuButton(
              itemBuilder: (context) => [
                PopupMenuItem(
                  child: const Text('Profile'),
                  onTap: () => context.go('/profile'),
                ),
                PopupMenuItem(
                  child: const Text('Settings'),
                  onTap: () {},
                ),
                PopupMenuItem(
                  child: const Text('Sync to Firebase'),
                  onTap: () => context.go('/sync-firebase'),
                ),
                PopupMenuItem(
                  child: const Text('Seed OTP Data'),
                  onTap: () => context.go('/seed-otp-data'),
                ),
                PopupMenuItem(
                  child: const Text('Logout'),
                  onTap: () => _showLogoutDialog(context, ref),
                ),
              ],
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(
                            Icons.person,
                            size: 30,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome back!',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              Text(
                                currentUser?['displayName'] ?? user?.displayName ?? 'Provider',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ],
                          ),
                        ),
                        // Online/Offline Toggle
                        ref.watch(providerOnlineStatusProvider).when(
                          data: (isOnline) => Row(
                            children: [
                              Switch(
                                value: isOnline,
                                onChanged: (value) {
                                  // Update online status
                                    ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Status updated to ${value ? "Online" : "Offline"}'),
                                      backgroundColor: value ? Colors.green : Colors.orange,
                                    ),
                                    );
                                },
                              ),
                              const SizedBox(width: 8),
                              Text(isOnline ? 'Online' : 'Offline'),
                            ],
                          ),
                          loading: () => const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          error: (error, stack) => const Text('Error'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Quick Stats
                Text(
                  'Quick Stats',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Builder(
                  builder: (context) {
                    final activeBookingsAsync = ref.watch(activeBookingsCountProvider);
                    final todayEarningsAsync = ref.watch(todayEarningsProvider);
                    final ratingAsync = ref.watch(providerRatingProvider);
                    final totalBookingsAsync = ref.watch(totalBookingsCountProvider);

                    return GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.5,
                      children: [
                        _buildStatCard(
                          context,
                          'Active Bookings',
                          activeBookingsAsync.valueOrNull?.toString() ?? '0',
                          Icons.event_available,
                          Colors.blue,
                          isLoading: activeBookingsAsync.isLoading,
                        ),
                        _buildStatCard(
                          context,
                          "Today's Earnings",
                          '₹${(todayEarningsAsync.valueOrNull ?? 0.0).toStringAsFixed(0)}',
                          Icons.account_balance_wallet,
                          Colors.green,
                          isLoading: todayEarningsAsync.isLoading,
                        ),
                        _buildStatCard(
                          context,
                          'Rating',
                          ratingAsync.valueOrNull?.toStringAsFixed(1) ?? '0.0',
                          Icons.star,
                          Colors.orange,
                          isLoading: ratingAsync.isLoading,
                        ),
                        _buildStatCard(
                          context,
                          'Total Bookings',
                          totalBookingsAsync.valueOrNull?.toString() ?? '0',
                          Icons.calendar_today,
                          Colors.purple,
                          isLoading: totalBookingsAsync.isLoading,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                
                // Quick Actions
                Text(
                  'Quick Actions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 2.5,
                  children: [
                    _buildActionCard(
                      context,
                      'My Services',
                      Icons.build,
                      () => context.go('/services'),
                    ),
                    _buildActionCard(
                      context,
                      'My Bookings',
                      Icons.calendar_today,
                      () => context.go('/bookings'),
                    ),
                    _buildActionCard(
                      context,
                      'Earnings',
                      Icons.account_balance_wallet,
                      () => context.go('/earnings'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Upcoming Bookings
                Text(
                  'Upcoming Bookings',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                _buildUpcomingBookings(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color, {
    bool isLoading = false,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingBookings(BuildContext context) {
    final upcomingBookingsAsync = ref.watch(upcomingBookingsProvider);

    return upcomingBookingsAsync.when(
      data: (upcomingBookings) {
        if (upcomingBookings.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                'No upcoming bookings',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'You will see your bookings here',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }

        return Column(
          children: upcomingBookings.take(3).map((booking) {
            final serviceName = booking['serviceName'] as String? ?? 'Service';
            final customerName = booking['customerName'] as String? ?? 'Customer';
            final status = booking['status'] as String? ?? 'pending';
            final scheduledDate = booking['scheduledDate'];

            String timeText = 'Upcoming';
            if (scheduledDate != null && scheduledDate is DateTime) {
              final date = scheduledDate;
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final bookingDate = DateTime(date.year, date.month, date.day);

              if (bookingDate == today) {
                timeText = 'Today, ${_formatTime(date)}';
              } else if (bookingDate == today.add(const Duration(days: 1))) {
                timeText = 'Tomorrow, ${_formatTime(date)}';
              } else {
                timeText = '${date.day}/${date.month}, ${_formatTime(date)}';
              }
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(
                    Icons.build,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: Text(serviceName),
                subtitle: Text('$customerName • $timeText'),
                trailing: Chip(
                  label: Text(
                    status,
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: status == 'accepted'
                      ? Colors.green.withValues(alpha: 0.2)
                      : Colors.orange.withValues(alpha: 0.2),
                ),
                onTap: () => context.go('/bookings/${booking['id']}'),
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  String _formatTime(DateTime date) {
    final hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  Future<void> _showLogoutDialog(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final authService = ref.read(firebaseAuthServiceProvider);
        await authService.signOut();
        
        if (context.mounted) {
          context.go('/login');
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to logout: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

