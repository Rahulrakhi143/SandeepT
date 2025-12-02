import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:trivora_provider/shared/widgets/custom_sidebar.dart';

/// Main Layout with Sidebar Navigation
/// Wraps all main pages with consistent sidebar navigation
class MainLayout extends StatefulWidget {
  final Widget child;
  final String currentRoute;

  const MainLayout({
    super.key,
    required this.child,
    required this.currentRoute,
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 600;

    // Web layout with sidebar
    if (isWeb || kIsWeb) {
      return Scaffold(
        body: Row(
          children: [
            CustomSidebar(
              selectedRoute: widget.currentRoute,
              onItemSelected: (route) {
                // Navigation handled by GoRouter
              },
            ),
            Expanded(
              child: widget.child,
            ),
          ],
        ),
      );
    }

    // Mobile layout - no sidebar, just content
    return Scaffold(
      body: widget.child,
    );
  }
}

