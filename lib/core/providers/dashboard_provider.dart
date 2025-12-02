import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trivora_provider/core/providers/auth_provider.dart';
import 'package:trivora_provider/core/services/backend_service.dart';

/// Provider for dashboard statistics
final dashboardStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final authUser = ref.watch(authStateProvider).valueOrNull;
  final userId = authUser?.uid;
  if (userId == null) return {};

  final backendService = ref.watch(backendServiceProvider);
  return backendService.getDashboardStats(userId);
});

/// Provider for active bookings count
final activeBookingsCountProvider = StreamProvider<int>((ref) async* {
  final authUser = ref.watch(authStateProvider).valueOrNull;
  final userId = authUser?.uid;
  if (userId == null) {
    yield 0;
    return;
  }

  final backendService = ref.watch(backendServiceProvider);
  backendService.initializeData(userId);
  
  // Emit updates every 2 seconds
  while (true) {
    final stats = backendService.getDashboardStats(userId);
    yield stats['activeBookings'] as int;
    await Future.delayed(const Duration(seconds: 2));
  }
});

/// Provider for today's earnings
final todayEarningsProvider = StreamProvider<double>((ref) async* {
  final authUser = ref.watch(authStateProvider).valueOrNull;
  final userId = authUser?.uid;
  if (userId == null) {
    yield 0.0;
    return;
  }

  final backendService = ref.watch(backendServiceProvider);
  backendService.initializeData(userId);
  
  // Emit updates every 2 seconds
  while (true) {
    final stats = backendService.getDashboardStats(userId);
    yield stats['todayEarnings'] as double;
    await Future.delayed(const Duration(seconds: 2));
  }
});

/// Provider for provider rating
final providerRatingProvider = FutureProvider<double>((ref) async {
  final authUser = ref.watch(authStateProvider).valueOrNull;
  final userId = authUser?.uid;
  if (userId == null) return 0.0;

  final backendService = ref.watch(backendServiceProvider);
  backendService.initializeData(userId);
  final stats = backendService.getDashboardStats(userId);
  return stats['rating'] as double;
});

/// Provider for total bookings count
final totalBookingsCountProvider = StreamProvider<int>((ref) async* {
  final authUser = ref.watch(authStateProvider).valueOrNull;
  final userId = authUser?.uid;
  if (userId == null) {
    yield 0;
    return;
  }

  final backendService = ref.watch(backendServiceProvider);
  backendService.initializeData(userId);
  
  // Emit updates every 2 seconds
  while (true) {
    final stats = backendService.getDashboardStats(userId);
    yield stats['totalBookings'] as int;
    await Future.delayed(const Duration(seconds: 2));
  }
});

/// Provider for upcoming bookings stream
/// Optimized to prevent infinite loops and reduce CPU usage
final upcomingBookingsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) async* {
  final authUser = ref.watch(authStateProvider).valueOrNull;
  final userId = authUser?.uid;
  if (userId == null) {
    yield [];
    return;
  }

  final backendService = ref.read(backendServiceProvider);
  backendService.initializeData(userId);
  
  // Emit initial data
  final bookings = backendService.getBookings(userId);
  final now = DateTime.now();
  final upcoming = bookings.where((booking) {
    final status = booking['status'] as String;
    final scheduledDate = booking['scheduledDate'] as DateTime;
    return ['pending', 'accepted', 'confirmed'].contains(status) &&
        scheduledDate.isAfter(now);
  }).toList();
  
  upcoming.sort((a, b) {
    final dateA = a['scheduledDate'] as DateTime;
    final dateB = b['scheduledDate'] as DateTime;
    return dateA.compareTo(dateB);
  });
  
  yield upcoming.take(10).toList();
  
  // Only update periodically, not continuously
  // Use a timer-based approach instead of infinite loop
  await for (final _ in Stream.periodic(const Duration(seconds: 30))) {
    // Check if provider is still active
    final currentAuthUser = ref.read(authStateProvider).valueOrNull;
    if (currentAuthUser == null || currentAuthUser.uid != userId) break;
    
    final updatedBookings = backendService.getBookings(userId);
    final updatedNow = DateTime.now();
    final updatedUpcoming = updatedBookings.where((booking) {
      final status = booking['status'] as String;
      final scheduledDate = booking['scheduledDate'] as DateTime;
      return ['pending', 'accepted', 'confirmed'].contains(status) &&
          scheduledDate.isAfter(updatedNow);
    }).toList();
    
    updatedUpcoming.sort((a, b) {
      final dateA = a['scheduledDate'] as DateTime;
      final dateB = b['scheduledDate'] as DateTime;
      return dateA.compareTo(dateB);
    });
    
    yield updatedUpcoming.take(10).toList();
  }
});

/// Provider for provider online status
final providerOnlineStatusProvider = StreamProvider<bool>((ref) async* {
  final authUser = ref.watch(authStateProvider).valueOrNull;
  final userId = authUser?.uid;
  if (userId == null) {
    yield false;
    return;
  }

  // Mock online status - can be made interactive
  yield true;
});
