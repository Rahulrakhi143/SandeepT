import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Custom Sidebar Navigation Widget
/// Matches the design with vertical icons and labels
class CustomSidebar extends StatelessWidget {
  final String selectedRoute;
  final Function(String) onItemSelected;

  const CustomSidebar({
    super.key,
    required this.selectedRoute,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(
            color: Colors.grey.shade300,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          _buildNavItem(
            context,
            icon: Icons.dashboard,
            label: 'Dashboard',
            route: '/dashboard',
            isSelected: selectedRoute == '/dashboard',
          ),
          const SizedBox(height: 16),
          _buildNavItem(
            context,
            icon: Icons.calendar_today,
            label: 'Bookings',
            route: '/bookings',
            isSelected: selectedRoute == '/bookings',
          ),
          const SizedBox(height: 16),
          _buildNavItem(
            context,
            icon: Icons.calendar_month,
            label: 'Calendar',
            route: '/calendar',
            isSelected: selectedRoute == '/calendar',
          ),
          const SizedBox(height: 16),
          _buildNavItem(
            context,
            icon: Icons.account_balance_wallet,
            label: 'Earnings',
            route: '/earnings',
            isSelected: selectedRoute == '/earnings',
          ),
          const SizedBox(height: 16),
          _buildNavItem(
            context,
            icon: Icons.folder,
            label: 'Documents',
            route: '/documents',
            isSelected: selectedRoute == '/documents',
          ),
          const SizedBox(height: 16),
          _buildNavItem(
            context,
            icon: Icons.settings,
            label: 'Settings',
            route: '/settings',
            isSelected: selectedRoute == '/settings',
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        onItemSelected(route);
        context.go(route);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade700,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

