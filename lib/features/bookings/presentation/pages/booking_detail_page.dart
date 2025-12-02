import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trivora_provider/core/providers/auth_provider.dart';
import 'package:trivora_provider/core/services/firestore_bookings_service.dart';
import 'package:trivora_provider/core/services/service_otp_service.dart';
import 'package:trivora_provider/shared/widgets/main_layout.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Provider for a single booking detail
final bookingDetailProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, bookingId) async {
  final authUser = ref.watch(authStateProvider).valueOrNull;
  if (authUser == null) return null;
  
  final firestoreService = ref.watch(firestoreBookingsServiceProvider);
  
  try {
    // Fetch booking from Firestore
    final bookings = await firestoreService.getBookings(authUser.uid);
    final booking = bookings.firstWhere(
      (b) => b['id'] == bookingId,
      orElse: () => <String, dynamic>{},
    );
    
    if (booking.isEmpty) return null;
    return booking;
  } catch (e) {
    // ignore: avoid_print
    print('Error fetching booking detail: $e');
    return null;
  }
});

/// Booking Detail Page
class BookingDetailPage extends ConsumerStatefulWidget {
  final String bookingId;
  
  const BookingDetailPage({
    super.key,
    required this.bookingId,
  });

  @override
  ConsumerState<BookingDetailPage> createState() => _BookingDetailPageState();
}

class _BookingDetailPageState extends ConsumerState<BookingDetailPage> {
  final TextEditingController _otpController = TextEditingController();
  
  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bookingAsync = ref.watch(bookingDetailProvider(widget.bookingId));
    
    return MainLayout(
      currentRoute: '/bookings',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Booking Details'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/bookings'),
          ),
        ),
        body: bookingAsync.when(
          data: (booking) {
            if (booking == null || booking.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Booking not found',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The booking you are looking for does not exist',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => context.go('/bookings'),
                      child: const Text('Back to Bookings'),
                    ),
                  ],
                ),
              );
            }
            
            return _buildBookingDetail(context, ref, booking);
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
                  'Error loading booking',
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
                  onPressed: () => ref.refresh(bookingDetailProvider(widget.bookingId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookingDetail(BuildContext context, WidgetRef ref, Map<String, dynamic> booking) {
    final status = booking['status'] as String? ?? 'pending';
    final statusColor = _getStatusColor(status);
    final scheduledDate = booking['scheduledDate'] as DateTime? ?? DateTime.now();
    final amount = booking['amount'] as double? ?? 0.0;
    final customerName = booking['customerName'] as String? ?? 'Unknown';
    final customerPhone = booking['customerPhone'] as String? ?? 'N/A';
    final address = booking['address'] as String? ?? 'No address provided';
    final serviceName = booking['serviceName'] as String? ?? 'Service';
    final paymentMethod = booking['paymentMethod'] as String? ?? 'Not specified';
    final paymentStatus = booking['paymentStatus'] as String? ?? 'unpaid';
    final isCompleted = status == 'completed' && paymentStatus == 'paid';
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Card
          Card(
            color: statusColor.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '₹${amount.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Service Information
          _buildSection(
            context,
            title: 'Service Information',
            icon: Icons.build,
            children: [
              _buildInfoTile(
                context,
                icon: Icons.category,
                label: 'Service',
                value: serviceName,
              ),
              const Divider(),
              _buildInfoTile(
                context,
                icon: Icons.calendar_today,
                label: 'Scheduled Date',
                value: DateFormat('EEEE, MMMM d, y').format(scheduledDate),
              ),
              const Divider(),
              _buildInfoTile(
                context,
                icon: Icons.access_time,
                label: 'Scheduled Time',
                value: DateFormat('h:mm a').format(scheduledDate),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Customer Information
          _buildSection(
            context,
            title: 'Customer Information',
            icon: Icons.person,
            children: [
              _buildInfoTile(
                context,
                icon: Icons.person_outline,
                label: 'Customer Name',
                value: customerName,
              ),
              const Divider(),
              _buildInfoTile(
                context,
                icon: Icons.phone,
                label: 'Phone Number',
                value: customerPhone,
                isPhone: true,
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Location Information
          _buildSection(
            context,
            title: 'Location',
            icon: Icons.location_on,
            children: [
              _buildInfoTile(
                context,
                icon: Icons.location_city,
                label: 'Address',
                value: address,
                isAddress: true,
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Payment Information
          _buildSection(
            context,
            title: 'Payment Information',
            icon: Icons.payment,
            children: [
              _buildInfoTile(
                context,
                icon: Icons.currency_rupee,
                label: 'Amount',
                value: '₹${amount.toStringAsFixed(0)}',
              ),
              const Divider(),
              _buildInfoTile(
                context,
                icon: _getPaymentIcon(paymentMethod),
                label: 'Payment Mode',
                value: _formatPaymentMethod(paymentMethod),
              ),
              if (paymentStatus.isNotEmpty) ...[
                const Divider(),
                _buildInfoTile(
                  context,
                  icon: paymentStatus == 'paid' ? Icons.check_circle : Icons.pending,
                  label: 'Payment Status',
                  value: paymentStatus == 'paid' ? 'Paid' : 'Unpaid',
                ),
              ],
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Service Completion Status (if completed)
          if (isCompleted) ...[
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Service Completed Successfully',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade900,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Payment received via ${_formatPaymentMethod(paymentMethod)}. Service has been completed.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.green.shade800,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // OTP Status (if in_progress and COD)
          if (status == 'in_progress' && paymentMethod.toLowerCase() == 'cod' && !isCompleted) ...[
            _buildOTPStatusCard(context, ref, booking),
            const SizedBox(height: 16),
          ],
          
          const SizedBox(height: 16),
          
          // Booking Actions (if pending)
          if (status == 'pending') ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Actions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _acceptBooking(context, ref, booking['id'] as String),
                      icon: const Icon(Icons.check),
                      label: const Text('Accept Booking'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _rejectBooking(context, ref, booking['id'] as String),
                      icon: const Icon(Icons.close),
                      label: const Text('Reject Booking'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          
          // Service Actions Card - OTP-based service lifecycle
          if (status == 'accepted' || status == 'confirmed' || status == 'in_progress') ...[
            _buildServiceActionsCard(context, ref, booking),
          ],
          
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }
  
  Widget _buildServiceActionsCard(BuildContext context, WidgetRef ref, Map<String, dynamic> booking) {
    final status = booking['status'] as String? ?? 'pending';
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Service Actions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            
            // OTP Input Text Box (Always visible)
            TextField(
              controller: _otpController,
              decoration: InputDecoration(
                labelText: 'Enter OTP',
                hintText: '6-digit OTP from customer',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: _otpController.text.length == 6
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
              ),
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                letterSpacing: 8,
                fontWeight: FontWeight.bold,
              ),
              onChanged: (value) {
                setState(() {
                  // Trigger rebuild for suffix icon
                });
              },
            ),
            const SizedBox(height: 16),
            
            // For Accepted/Confirmed Status: Generate OTP and Start Service buttons
            if (status == 'accepted' || status == 'confirmed') ...[
              // Generate OTP Button
              ElevatedButton.icon(
                onPressed: () => _generateStartOtp(context, ref, booking),
                icon: const Icon(Icons.vpn_key),
                label: const Text('Generate OTP'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 8),
              // Start Service Button (replaces "Start Service Without OTP")
              ElevatedButton.icon(
                onPressed: () => _verifyStartOtpAndStartService(context, ref, booking),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Service'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
            
            // Status: Service Started (if in_progress)
            if (status == 'in_progress') ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'STATUS: Service Started',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Generate OTP Button (at top of Complete Service button)
              ElevatedButton.icon(
                onPressed: () => _generateCompletionOtp(context, ref, booking),
                icon: const Icon(Icons.vpn_key),
                label: const Text('Generate OTP'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 8),
              // Complete Service Button (verifies OTP and completes service)
              ElevatedButton.icon(
                onPressed: () => _verifyCompletionOtp(context, ref, booking),
                icon: const Icon(Icons.check_circle),
                label: const Text('Complete Service'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
            
            // Status: Service Completed
            if (status == 'completed') ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'STATUS: Service Completed',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade900,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'All actions completed. Service summary available.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOTPStatusCard(BuildContext context, WidgetRef ref, Map<String, dynamic> booking) {
    final otpData = booking['otp'] as Map<String, dynamic>?;
    
    if (otpData == null) {
      return const SizedBox.shrink();
    }
    
    final expiresAtTimestamp = otpData['expiresAt'];
    DateTime? expiresAt;
    if (expiresAtTimestamp != null) {
      if (expiresAtTimestamp is Timestamp) {
        expiresAt = expiresAtTimestamp.toDate();
      } else if (expiresAtTimestamp is DateTime) {
        expiresAt = expiresAtTimestamp;
      } else {
        // Try to parse as Timestamp from Firestore
        try {
          expiresAt = (expiresAtTimestamp as Timestamp).toDate();
        } catch (e) {
          // ignore
        }
      }
    }
    final isExpired = expiresAt != null && DateTime.now().isAfter(expiresAt);
    final isVerified = otpData['verified'] == true;
    final resendCount = otpData['resendCount'] as int? ?? 0;
    
    return Card(
      color: isExpired 
          ? Colors.orange.shade50 
          : isVerified 
              ? Colors.green.shade50 
              : Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isExpired 
                      ? Icons.error_outline 
                      : isVerified 
                          ? Icons.check_circle 
                          : Icons.access_time,
                  color: isExpired 
                      ? Colors.orange 
                      : isVerified 
                          ? Colors.green 
                          : Colors.blue,
                ),
                const SizedBox(width: 8),
                Text(
                  isExpired 
                      ? 'OTP Expired' 
                      : isVerified 
                          ? 'OTP Verified' 
                          : 'Waiting for OTP',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isExpired 
                            ? Colors.orange 
                            : isVerified 
                                ? Colors.green 
                                : Colors.blue,
                      ),
                ),
              ],
            ),
            if (expiresAt != null && !isExpired && !isVerified) ...[
              const SizedBox(height: 8),
              Text(
                'Expires at: ${DateFormat('hh:mm a').format(expiresAt)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (isVerified) ...[
              const SizedBox(height: 8),
              Text(
                'Payment received. Service completed successfully.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.green.shade800,
                    ),
              ),
            ],
            if (resendCount > 0 && !isVerified) ...[
              const SizedBox(height: 4),
              Text(
                'Resend attempts: $resendCount/3',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Removed unused method _buildOTPVerificationCard

  // Removed unused methods: _verifyOTPWithController, _showOTPInputDialog, _resendOTP

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    bool isPhone = false,
    bool isAddress = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                ),
                const SizedBox(height: 4),
                if (isPhone)
                  InkWell(
                    onTap: () {
                      // You can add phone call functionality here
                    },
                    child: Text(
                      value,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                    ),
                  )
                else
                  Text(
                    value,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                    maxLines: isAddress ? 3 : 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
      case 'confirmed':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'rejected':
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getPaymentIcon(String paymentMethod) {
    switch (paymentMethod.toLowerCase()) {
      case 'cash':
      case 'cod':
        return Icons.money;
      case 'razorpay':
      case 'online':
        return Icons.payment;
      case 'card':
        return Icons.credit_card;
      default:
        return Icons.payment;
    }
  }

  String _formatPaymentMethod(String paymentMethod) {
    switch (paymentMethod.toLowerCase()) {
      case 'cod':
        return 'Cash on Delivery';
      case 'razorpay':
        return 'Razorpay (Online)';
      case 'cash':
        return 'Cash';
      case 'card':
        return 'Card';
      case 'online':
        return 'Online Payment';
      default:
        return paymentMethod.isNotEmpty ? paymentMethod : 'Not specified';
    }
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
        final firestoreService = ref.read(firestoreBookingsServiceProvider);
        final authUser = ref.read(authStateProvider).valueOrNull;
        if (authUser != null) {
          await firestoreService.acceptBooking(authUser.uid, bookingId);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Booking accepted successfully!'),
                backgroundColor: Colors.green,
              ),
            );
            // Refresh the booking detail
            ref.invalidate(bookingDetailProvider(bookingId));
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to accept booking: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _rejectBooking(BuildContext context, WidgetRef ref, String bookingId) async {
    final reasonController = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Booking'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejecting this booking:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'Enter rejection reason...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true && reasonController.text.trim().isNotEmpty) {
      try {
        final firestoreService = ref.read(firestoreBookingsServiceProvider);
        final authUser = ref.read(authStateProvider).valueOrNull;
        if (authUser != null) {
          await firestoreService.rejectBooking(authUser.uid, bookingId, reasonController.text.trim());
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Booking rejected'),
                backgroundColor: Colors.orange,
              ),
            );
            // Refresh the booking detail
            ref.invalidate(bookingDetailProvider(bookingId));
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to reject booking: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Removed unused methods: _generateStartServiceOTP, _showStartServiceOTPDialog, _startServiceWithOTP, _startService, _completeService

  /// Generate Start OTP for service start verification
  Future<void> _generateStartOtp(BuildContext context, WidgetRef ref, Map<String, dynamic> booking) async {
    // Show loading
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    try {
      final authUser = ref.read(authStateProvider).valueOrNull;
      if (authUser == null) {
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please login first'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final bookingId = booking['id'] as String;
      final customerId = booking['customerId'] as String? ?? '';
      
      final otpService = ref.read(serviceOTPServiceProvider);
      final otp = await otpService.generateStartOtp(
        providerId: authUser.uid,
        bookingId: bookingId,
        customerId: customerId,
      );

      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Start OTP generated and sent! OTP: $otp (for testing)'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
        ref.invalidate(bookingDetailProvider(bookingId));
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate start OTP: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Verify Start OTP and start the service
  Future<void> _verifyStartOtpAndStartService(BuildContext context, WidgetRef ref, Map<String, dynamic> booking) async {
    final otp = _otpController.text.trim();
    
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 6-digit OTP'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show loading
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    try {
      final authUser = ref.read(authStateProvider).valueOrNull;
      if (authUser == null) {
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please login first'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final bookingId = booking['id'] as String;
      final otpService = ref.read(serviceOTPServiceProvider);
      
      final verified = await otpService.verifyStartOtpAndStartService(
        providerId: authUser.uid,
        bookingId: bookingId,
        otpEntered: otp,
      );

      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        
        if (verified) {
          _otpController.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('OTP verified! Service started successfully.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
          ref.invalidate(bookingDetailProvider(bookingId));
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Generate Completion OTP for service completion verification
  Future<void> _generateCompletionOtp(BuildContext context, WidgetRef ref, Map<String, dynamic> booking) async {
    // Show loading
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    try {
      final authUser = ref.read(authStateProvider).valueOrNull;
      if (authUser == null) {
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please login first'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final bookingId = booking['id'] as String;
      final customerId = booking['customerId'] as String? ?? '';
      
      final otpService = ref.read(serviceOTPServiceProvider);
      final otp = await otpService.generateCompletionOtp(
        providerId: authUser.uid,
        bookingId: bookingId,
        customerId: customerId,
      );

      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Completion OTP generated and sent! OTP: $otp (for testing)'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
        ref.invalidate(bookingDetailProvider(bookingId));
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate completion OTP: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Verify Completion OTP and complete the service
  Future<void> _verifyCompletionOtp(BuildContext context, WidgetRef ref, Map<String, dynamic> booking) async {
    final otp = _otpController.text.trim();
    
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 6-digit OTP'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show loading
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    try {
      final authUser = ref.read(authStateProvider).valueOrNull;
      if (authUser == null) {
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please login first'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final bookingId = booking['id'] as String;
      final otpService = ref.read(serviceOTPServiceProvider);
      
      final verified = await otpService.verifyCompletionOtp(
        providerId: authUser.uid,
        bookingId: bookingId,
        otpEntered: otp,
      );

      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        
        if (verified) {
          _otpController.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('OTP verified! Service completed successfully. Payment received.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 5),
            ),
          );
          ref.invalidate(bookingDetailProvider(bookingId));
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}

