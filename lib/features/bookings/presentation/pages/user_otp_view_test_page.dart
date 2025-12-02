import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trivora_provider/core/config/app_config.dart';
import 'package:trivora_provider/shared/widgets/main_layout.dart';
import 'package:intl/intl.dart';

/// Test page to simulate user's view of OTP
/// This shows what a user would see when they receive an OTP
class UserOTPViewTestPage extends ConsumerStatefulWidget {
  final String? bookingId;
  
  const UserOTPViewTestPage({
    super.key,
    this.bookingId,
  });

  @override
  ConsumerState<UserOTPViewTestPage> createState() => _UserOTPViewTestPageState();
}

class _UserOTPViewTestPageState extends ConsumerState<UserOTPViewTestPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  List<Map<String, dynamic>> _userNotifications = [];
  Map<String, dynamic>? _selectedNotification;
  String? _displayedOTP;

  @override
  void initState() {
    super.initState();
    _loadUserNotifications();
  }

  Future<void> _loadUserNotifications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get all notifications from the notifications collection
      final notificationsSnapshot = await _firestore
          .collection(AppConfig.notificationsCollection)
          .where('type', isEqualTo: 'cod_otp_generated')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      final notifications = <Map<String, dynamic>>[];
      for (var doc in notificationsSnapshot.docs) {
        final data = doc.data();
        notifications.add({
          'id': doc.id,
          'userId': data['userId'] ?? '',
          'title': data['title'] ?? '',
          'body': data['body'] ?? '',
          'data': data['data'] ?? {},
          'createdAt': (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'read': data['read'] ?? false,
        });
      }

      setState(() {
        _userNotifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _selectNotification(Map<String, dynamic> notification) {
    setState(() {
      _selectedNotification = notification;
      final notificationData = notification['data'] as Map<String, dynamic>?;
      _displayedOTP = notificationData?['otp'] as String?;
    });
  }

  Future<void> _loadBookingDetails(String bookingId) async {
    // Try to find booking in any provider's bookings
    try {
      final providersSnapshot = await _firestore
          .collection(AppConfig.providersCollection)
          .limit(10)
          .get();

      for (var providerDoc in providersSnapshot.docs) {
        final bookingDoc = await providerDoc.reference
            .collection('bookings')
            .doc(bookingId)
            .get();

        if (bookingDoc.exists) {
          final bookingData = bookingDoc.data() ?? {};
          setState(() {
            _selectedNotification = {
              ..._selectedNotification!,
              'booking': {
                'id': bookingId,
                'serviceName': bookingData['serviceName'] ?? 'Service',
                'amount': bookingData['amount'] ?? 0.0,
                'address': bookingData['address'] ?? '',
                'scheduledDate': (bookingData['scheduledDate'] as Timestamp?)?.toDate(),
                'status': bookingData['status'] ?? 'pending',
                'paymentMethod': bookingData['paymentMethod'] ?? 'cod',
              },
            };
          });
          break;
        }
      }
    } catch (e) {
      debugPrint('Error loading booking details: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      currentRoute: '/bookings',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('User OTP View (Test)'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/bookings'),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Row(
                children: [
                  // Left Panel: Notifications List
                  Expanded(
                    flex: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              border: Border(
                                bottom: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.notifications, color: Colors.blue.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  'OTP Notifications (${_userNotifications.length})',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.refresh),
                                  onPressed: _loadUserNotifications,
                                  tooltip: 'Refresh',
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: _userNotifications.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.notifications_none,
                                          size: 64,
                                          color: Colors.grey.shade400,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'No OTP notifications found',
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                color: Colors.grey.shade600,
                                              ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Seed dummy data first to see notifications',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: Colors.grey.shade500,
                                              ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: _userNotifications.length,
                                    itemBuilder: (context, index) {
                                      final notification = _userNotifications[index];
                                      final isSelected = _selectedNotification?['id'] == notification['id'];
                                      final createdAt = notification['createdAt'] as DateTime;
                                      final notificationData = notification['data'] as Map<String, dynamic>?;
                                      final otp = notificationData?['otp'] as String?;

                                      return InkWell(
                                        onTap: () {
                                          _selectNotification(notification);
                                          final bookingId = notificationData?['bookingId'] as String?;
                                          if (bookingId != null) {
                                            _loadBookingDetails(bookingId);
                                          }
                                        },
                                        child: Container(
                                          color: isSelected
                                              ? Colors.blue.shade50
                                              : Colors.transparent,
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: Colors.orange.shade100,
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Icon(
                                                      Icons.lock,
                                                      size: 20,
                                                      color: Colors.orange.shade700,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          notification['title'] ?? 'OTP Notification',
                                                          style: Theme.of(context)
                                                              .textTheme
                                                              .bodyMedium
                                                              ?.copyWith(
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                        ),
                                                        const SizedBox(height: 4),
                                                        Text(
                                                          DateFormat('MMM dd, hh:mm a').format(createdAt),
                                                          style: Theme.of(context)
                                                              .textTheme
                                                              .bodySmall
                                                              ?.copyWith(
                                                                color: Colors.grey.shade600,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  if (otp != null)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.green.shade100,
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        'OTP: $otp',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.green.shade900,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Right Panel: OTP Display (User View)
                  Expanded(
                    flex: 2,
                    child: _selectedNotification == null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.touch_app,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Select a notification to view OTP',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: Colors.grey.shade600,
                                      ),
                                ),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Header
                                Card(
                                  color: Colors.blue.shade50,
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.verified_user,
                                              size: 32,
                                              color: Colors.blue.shade700,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                _selectedNotification!['title'] ?? 'OTP for Service Completion',
                                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.blue.shade900,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          _selectedNotification!['body'] ?? '',
                                          style: Theme.of(context).textTheme.bodyLarge,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 24),

                                // OTP Display Card
                                if (_displayedOTP != null) ...[
                                  Card(
                                    elevation: 4,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(32),
                                      child: Column(
                                        children: [
                                          Text(
                                            'Your OTP Code',
                                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                  color: Colors.grey.shade600,
                                                ),
                                          ),
                                          const SizedBox(height: 16),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 32,
                                              vertical: 24,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade50,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: Colors.blue.shade300,
                                                width: 2,
                                              ),
                                            ),
                                            child: Text(
                                              _displayedOTP!,
                                              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 8,
                                                    color: Colors.blue.shade900,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.access_time,
                                                size: 16,
                                                color: Colors.grey.shade600,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Valid for 10 minutes',
                                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                      color: Colors.grey.shade600,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                ],

                                // Booking Details
                                if (_selectedNotification!['booking'] != null) ...[
                                  Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Booking Details',
                                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          const SizedBox(height: 16),
                                          _buildDetailRow(
                                            'Service',
                                            _selectedNotification!['booking']['serviceName'] ?? 'N/A',
                                            Icons.build,
                                          ),
                                          const Divider(),
                                          _buildDetailRow(
                                            'Amount',
                                            '₹${(_selectedNotification!['booking']['amount'] ?? 0.0).toStringAsFixed(2)}',
                                            Icons.currency_rupee,
                                          ),
                                          const Divider(),
                                          _buildDetailRow(
                                            'Address',
                                            _selectedNotification!['booking']['address'] ?? 'N/A',
                                            Icons.location_on,
                                          ),
                                          if (_selectedNotification!['booking']['scheduledDate'] != null) ...[
                                            const Divider(),
                                            _buildDetailRow(
                                              'Scheduled Date',
                                              DateFormat('MMM dd, yyyy hh:mm a').format(
                                                _selectedNotification!['booking']['scheduledDate'] as DateTime,
                                              ),
                                              Icons.calendar_today,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                ],

                                // Instructions Card
                                Card(
                                  color: Colors.orange.shade50,
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.info_outline,
                                              color: Colors.orange.shade700,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Important Instructions',
                                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.orange.shade900,
                                                  ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        _buildInstructionItem(
                                          'Do not share this OTP until the service is fully completed',
                                        ),
                                        _buildInstructionItem(
                                          'Share the OTP only with the service provider',
                                        ),
                                        _buildInstructionItem(
                                          'The OTP will expire in 10 minutes',
                                        ),
                                        _buildInstructionItem(
                                          'If OTP expires, you can request a new one (max 3 attempts)',
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 24),

                                // Action Buttons
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          // Simulate resend OTP
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Resend OTP functionality (simulated)'),
                                              backgroundColor: Colors.blue,
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.refresh),
                                        label: const Text('Resend OTP'),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Contact Support (simulated)'),
                                              backgroundColor: Colors.blue,
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.support_agent),
                                        label: const Text('Contact Support'),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
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
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 16,
            color: Colors.orange.shade700,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

