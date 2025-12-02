import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trivora_provider/core/providers/auth_provider.dart';
import 'package:trivora_provider/core/services/backend_service.dart';
import 'package:trivora_provider/core/services/firestore_bookings_service.dart';

/// Provider for bookings list - fetches from Firestore
final bookingsProvider = StateNotifierProvider<BookingsNotifier, AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final authUser = ref.watch(authStateProvider).valueOrNull;
  final userId = authUser?.uid ?? '';
  final firestoreService = ref.watch(firestoreBookingsServiceProvider);
  final backendService = ref.watch(backendServiceProvider);
  return BookingsNotifier(firestoreService, backendService, userId);
});

class BookingsNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final FirestoreBookingsService _firestoreService;
  final BackendService _backendService;
  final String _userId;
  String? _statusFilter;

  BookingsNotifier(this._firestoreService, this._backendService, this._userId)
      : super(const AsyncValue.loading()) {
    loadBookings();
  }

  Future<void> loadBookings({String? status}) async {
    _statusFilter = status;
    state = const AsyncValue.loading();
    
    try {
      // First try to fetch from Firestore
      final firestoreBookings = await _firestoreService.getBookings(_userId, status: status);
      
      if (firestoreBookings.isNotEmpty) {
        // Use Firestore data
        state = AsyncValue.data(firestoreBookings);
        // ignore: avoid_print
        print('✅ Loaded ${firestoreBookings.length} bookings from Firestore');
      } else {
        // Fallback to backend service if Firestore is empty
        _backendService.initializeData(_userId);
        final backendBookings = _backendService.getBookings(_userId, status: status);
        state = AsyncValue.data(backendBookings);
        // ignore: avoid_print
        print('⚠️ Firestore empty, using backend service data: ${backendBookings.length} bookings');
      }
    } catch (e, stackTrace) {
      // If Firestore fails, fallback to backend service
      try {
        _backendService.initializeData(_userId);
        final backendBookings = _backendService.getBookings(_userId, status: status);
        state = AsyncValue.data(backendBookings);
        // ignore: avoid_print
        print('⚠️ Firestore error, using backend service: $e');
      } catch (e2) {
        state = AsyncValue.error(e2, stackTrace);
      }
    }
  }

  Future<void> acceptBooking(String bookingId) async {
    try {
      // Update in Firestore
      await _firestoreService.acceptBooking(_userId, bookingId);
      // Also update in backend service for consistency
      await _backendService.acceptBooking(bookingId, _userId);
      // Reload bookings
      await loadBookings(status: _statusFilter);
    } catch (e) {
      // If Firestore fails, try backend service
      try {
        await _backendService.acceptBooking(bookingId, _userId);
        await loadBookings(status: _statusFilter);
      } catch (e2) {
        throw Exception('Failed to accept booking: $e2');
      }
    }
  }

  Future<void> rejectBooking(String bookingId, String reason) async {
    try {
      // Update in Firestore
      await _firestoreService.rejectBooking(_userId, bookingId, reason);
      // Also update in backend service for consistency
      await _backendService.rejectBooking(bookingId, _userId, reason);
      // Reload bookings
      await loadBookings(status: _statusFilter);
    } catch (e) {
      // If Firestore fails, try backend service
      try {
        await _backendService.rejectBooking(bookingId, _userId, reason);
        await loadBookings(status: _statusFilter);
      } catch (e2) {
        throw Exception('Failed to reject booking: $e2');
      }
    }
  }

  Future<void> updateStatus(String bookingId, String status) async {
    try {
      // Update in Firestore
      await _firestoreService.updateBookingStatus(_userId, bookingId, status);
      // Also update in backend service for consistency
      await _backendService.updateBookingStatus(bookingId, _userId, status);
      // Reload bookings
      await loadBookings(status: _statusFilter);
    } catch (e) {
      // If Firestore fails, try backend service
      try {
        await _backendService.updateBookingStatus(bookingId, _userId, status);
        await loadBookings(status: _statusFilter);
      } catch (e2) {
        throw Exception('Failed to update booking status: $e2');
      }
    }
  }
  
  Future<void> completeBooking(String bookingId) async {
    try {
      // Update in Firestore
      await _firestoreService.completeBooking(_userId, bookingId);
      // Also update in backend service for consistency
      await _backendService.completeBooking(bookingId, _userId);
      // Reload bookings
      await loadBookings(status: _statusFilter);
    } catch (e) {
      // If Firestore fails, try backend service
      try {
        await _backendService.completeBooking(bookingId, _userId);
        await loadBookings(status: _statusFilter);
      } catch (e2) {
        throw Exception('Failed to complete booking: $e2');
      }
    }
  }
}

/// Bookings page showing all bookings for the provider
class BookingsPage extends ConsumerStatefulWidget {
  const BookingsPage({super.key});

  @override
  ConsumerState<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends ConsumerState<BookingsPage> {
  String? _selectedStatus;

  @override
  Widget build(BuildContext context) {
    final authUserAsync = ref.watch(authStateProvider);
    final authUser = authUserAsync.valueOrNull;
    if (authUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please login to view bookings')),
      );
    }

    final bookingsAsync = ref.watch(bookingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bookings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(bookingsProvider.notifier).loadBookings(status: _selectedStatus);
            },
          ),
        ],
      ),
      body: bookingsAsync.when(
        data: (bookings) {
          if (bookings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No bookings yet',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your bookings will appear here',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(bookingsProvider.notifier).loadBookings(status: _selectedStatus);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: bookings.length,
              itemBuilder: (context, index) {
                final booking = bookings[index];
                final status = booking['status'] as String;
                final statusColor = _getStatusColor(status);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () => context.go('/bookings/${booking['id']}'),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                              radius: 24,
                              child: Icon(
                                Icons.build,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    booking['serviceName'] as String,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildInfoRow(Icons.person, 'Customer: ${booking['customerName']}'),
                                  const SizedBox(height: 4),
                                  _buildInfoRow(Icons.phone, 'Phone: ${booking['customerPhone']}'),
                                  const SizedBox(height: 4),
                                  _buildInfoRow(Icons.currency_rupee, 'Amount: ₹${booking['amount']}'),
                                  const SizedBox(height: 4),
                                  _buildInfoRow(
                                    Icons.calendar_today,
                                    'Date: ${_formatDate(booking['scheduledDate'] as DateTime)}',
                                  ),
                                  if (status == 'pending') ...[
                                    const SizedBox(height: 16),
                                    const Divider(),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () => _acceptBooking(context, ref, booking['id'] as String),
                                            icon: const Icon(Icons.check, size: 18),
                                            label: const Text('Accept'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () => _cancelBooking(context, ref, booking['id'] as String),
                                            icon: const Icon(Icons.close, size: 18),
                                            label: const Text('Cancel'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.red,
                                              side: const BorderSide(color: Colors.red),
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Chip(
                                  label: Text(
                                    status.toUpperCase(),
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  backgroundColor: statusColor.withValues(alpha: 0.2),
                                  labelStyle: TextStyle(color: statusColor),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading bookings',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.red.shade600,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade500,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.read(bookingsProvider.notifier).loadBookings(status: _selectedStatus);
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Bookings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String?>(
              title: const Text('All'),
              value: null,
              groupValue: _selectedStatus,
              onChanged: (value) {
                setState(() => _selectedStatus = value);
                ref.read(bookingsProvider.notifier).loadBookings();
                Navigator.pop(context);
              },
            ),
            RadioListTile<String?>(
              title: const Text('Pending'),
              value: 'pending',
              groupValue: _selectedStatus,
              onChanged: (value) {
                setState(() => _selectedStatus = value);
                ref.read(bookingsProvider.notifier).loadBookings(status: value);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String?>(
              title: const Text('Accepted'),
              value: 'accepted',
              groupValue: _selectedStatus,
              onChanged: (value) {
                setState(() => _selectedStatus = value);
                ref.read(bookingsProvider.notifier).loadBookings(status: value);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String?>(
              title: const Text('In-Progress'),
              value: 'in_progress',
              groupValue: _selectedStatus,
              onChanged: (value) {
                setState(() => _selectedStatus = value);
                ref.read(bookingsProvider.notifier).loadBookings(status: value);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String?>(
              title: const Text('Completed'),
              value: 'completed',
              groupValue: _selectedStatus,
              onChanged: (value) {
                setState(() => _selectedStatus = value);
                ref.read(bookingsProvider.notifier).loadBookings(status: value);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _acceptBooking(BuildContext context, WidgetRef ref, String bookingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept Booking'),
        content: const Text('Are you sure you want to accept this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Accept'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(bookingsProvider.notifier).acceptBooking(bookingId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Booking accepted successfully!'),
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

  Future<void> _cancelBooking(BuildContext context, WidgetRef ref, String bookingId) async {
    final reasonController = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Are you sure you want to cancel this booking?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (Optional)',
                hintText: 'Enter cancellation reason...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel Booking'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final reason = reasonController.text.trim();
        await ref.read(bookingsProvider.notifier).rejectBooking(
          bookingId,
          reason.isNotEmpty ? reason : 'Cancelled by provider',
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Booking cancelled successfully'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to cancel booking: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'confirmed':
        return Colors.blue;
      case 'in_progress':
        return Colors.purple;
      case 'completed':
        return Colors.teal;
      case 'cancelled':
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
