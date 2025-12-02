import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trivora_provider/core/providers/auth_provider.dart';
import 'package:trivora_provider/core/providers/admin_auth_provider.dart';
import 'package:trivora_provider/features/auth/presentation/pages/provider_login_page.dart';
import 'package:trivora_provider/features/auth/presentation/pages/provider_signup_page.dart';
import 'package:trivora_provider/features/dashboard/presentation/pages/provider_dashboard_page.dart';
import 'package:trivora_provider/features/bookings/presentation/pages/bookings_page.dart';
import 'package:trivora_provider/features/bookings/presentation/pages/booking_detail_page.dart';
import 'package:trivora_provider/features/bookings/presentation/pages/otp_confirmation_test_page.dart';
import 'package:trivora_provider/features/bookings/presentation/pages/user_otp_view_test_page.dart';
import 'package:trivora_provider/features/services/presentation/pages/services_page.dart';
import 'package:trivora_provider/features/earnings/presentation/pages/earnings_page.dart';
import 'package:trivora_provider/features/calendar/presentation/pages/calendar_page.dart';
import 'package:trivora_provider/features/documents/presentation/pages/documents_page.dart';
import 'package:trivora_provider/features/settings/presentation/pages/settings_page.dart';
import 'package:trivora_provider/features/settings/presentation/pages/payment_methods_page.dart';
import 'package:trivora_provider/features/settings/presentation/pages/privacy_security_page.dart';
import 'package:trivora_provider/features/profile/presentation/pages/profile_page.dart';
import 'package:trivora_provider/features/admin/presentation/pages/admin_dashboard_page.dart';
import 'package:trivora_provider/features/admin/presentation/pages/admin_login_page.dart';
import 'package:trivora_provider/shared/widgets/main_layout.dart';

/// Application router for Provider App
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final adminAuthState = ref.watch(adminAuthStateProvider);
  final currentAdminUser = ref.watch(currentAdminUserProvider);
  
  return GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: true,
    routes: [
      // Auth Routes
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const ProviderLoginPage(),
      ),
      GoRoute(
        path: '/signup',
        name: 'signup',
        builder: (context, state) => const ProviderSignupPage(),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(title: const Text('Provider Onboarding')),
            body: const Center(
              child: Text('Onboarding Page - To be implemented'),
            ),
          );
        },
      ),
      
      // Dashboard (protected route)
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const MainLayout(
          currentRoute: '/dashboard',
          child: ProviderDashboardPage(),
        ),
      ),
      
      // Bookings routes
      GoRoute(
        path: '/bookings',
        name: 'bookings',
        builder: (context, state) {
          return const MainLayout(
            currentRoute: '/bookings',
            child: BookingsPage(),
          );
        },
      ),
      GoRoute(
        path: '/bookings/:id',
        name: 'booking-detail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return BookingDetailPage(bookingId: id);
        },
      ),
      GoRoute(
        path: '/bookings/:id/otp-test',
        name: 'otp-confirmation-test',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return OTPConfirmationTestPage(bookingId: id);
        },
      ),
      GoRoute(
        path: '/user-otp-view-test',
        name: 'user-otp-view-test',
        builder: (context, state) {
          return const UserOTPViewTestPage();
        },
      ),
      
      // Services routes
      GoRoute(
        path: '/services',
        name: 'services',
        builder: (context, state) {
          return const MainLayout(
            currentRoute: '/services',
            child: ServicesPage(),
          );
        },
      ),
      
      // Earnings routes
      GoRoute(
        path: '/earnings',
        name: 'earnings',
        builder: (context, state) {
          return const MainLayout(
            currentRoute: '/earnings',
            child: EarningsPage(),
          );
        },
      ),
      
      // Calendar routes
      GoRoute(
        path: '/calendar',
        name: 'calendar',
        builder: (context, state) {
          return const MainLayout(
            currentRoute: '/calendar',
            child: CalendarPage(),
          );
        },
      ),
      
      // Documents routes
      GoRoute(
        path: '/documents',
        name: 'documents',
        builder: (context, state) {
          return const MainLayout(
            currentRoute: '/documents',
            child: DocumentsPage(),
          );
        },
      ),
      
      // Settings routes
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) {
          return const MainLayout(
            currentRoute: '/settings',
            child: SettingsPage(),
          );
        },
      ),
      GoRoute(
        path: '/settings/payment-methods',
        name: 'payment-methods',
        builder: (context, state) {
          return const MainLayout(
            currentRoute: '/settings',
            child: PaymentMethodsPage(),
          );
        },
      ),
      GoRoute(
        path: '/settings/privacy-security',
        name: 'privacy-security',
        builder: (context, state) {
          return const MainLayout(
            currentRoute: '/settings',
            child: PrivacySecurityPage(),
          );
        },
      ),
      
      // Profile routes
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) {
          return const ProfilePage();
        },
      ),
      
      // Admin Routes (Web Only) - Protected routes
      GoRoute(
        path: '/admin/login',
        name: 'admin-login',
        builder: (context, state) {
          return const AdminLoginPage();
        },
      ),
      // Admin creation route removed - admins cannot create other admin accounts
      // GoRoute(
      //   path: '/admin/create',
      //   name: 'create-admin',
      //   builder: (context, state) {
      //     return const CreateAdminPage();
      //   },
      // ),
      GoRoute(
        path: '/admin',
        name: 'admin-dashboard',
        builder: (context, state) {
          return const AdminDashboardPage();
        },
      ),
    ],
    redirect: (context, state) {
      final currentPath = state.uri.path;
      final isProviderLoggedIn = authState.valueOrNull != null;
      final isAdminLoggedIn = adminAuthState.valueOrNull != null;
      final adminUser = currentAdminUser.valueOrNull;
      final isActiveAdmin = adminUser != null && adminUser['isActive'] == true;
      
      // Admin routes
      final isAdminRoute = currentPath.startsWith('/admin');
      final isAdminLoginRoute = currentPath == '/admin/login';
      
      // Provider routes
      final isProviderRoute = !isAdminRoute && currentPath != '/login' && 
                             currentPath != '/signup' && 
                             currentPath != '/onboarding';
      final isProviderAuthRoute = currentPath == '/login' || 
                                  currentPath == '/signup' ||
                                  currentPath == '/onboarding';
      
      // ========== ADMIN ROUTE PROTECTION ==========
      if (isAdminRoute) {
        // If trying to access admin routes but not logged in as admin
        if (!isAdminLoggedIn || !isActiveAdmin) {
          // Allow access to admin login/create pages
          if (isAdminLoginRoute) {
            return null; // Allow access to login/create
          }
          // Redirect to admin login
          return '/admin/login';
        }
        
        // If admin is logged in and on admin login page, redirect to admin dashboard
        if (isAdminLoginRoute && isActiveAdmin) {
          return '/admin';
        }
        
        // Admin is logged in and accessing admin routes - allow access
        return null;
      }
      
      // ========== PROVIDER ROUTE PROTECTION ==========
      if (isProviderRoute) {
        // If admin is logged in, prevent access to provider routes
        if (isAdminLoggedIn && isActiveAdmin) {
          // Admin cannot access provider routes - redirect to admin dashboard
          return '/admin';
        }
        
        // If not logged in as provider and trying to access provider routes
        if (!isProviderLoggedIn) {
          return '/login';
        }
        
        // Provider is logged in - allow access
        return null;
      }
      
      // ========== AUTH ROUTES (Login/Signup) ==========
      if (isProviderAuthRoute) {
        // If admin is logged in, redirect to admin dashboard
        if (isAdminLoggedIn && isActiveAdmin) {
          return '/admin';
        }
        
        // If provider is logged in, redirect to dashboard
        if (isProviderLoggedIn) {
          return '/dashboard';
        }
        
        // Not logged in - allow access to auth pages
        return null;
      }
      
      return null;
    },
  );
});
