import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trivora_provider/core/providers/auth_provider.dart';
import 'package:trivora_provider/core/services/firestore_bookings_service.dart';
import 'package:trivora_provider/core/services/cod_otp_service.dart';
import 'package:trivora_provider/shared/widgets/main_layout.dart';
import 'package:intl/intl.dart';

/// Test page for OTP confirmation UI
/// This is a dummy UI for testing OTP flow
class OTPConfirmationTestPage extends ConsumerStatefulWidget {
  final String? bookingId;
  
  const OTPConfirmationTestPage({
    super.key,
    this.bookingId,
  });

  @override
  ConsumerState<OTPConfirmationTestPage> createState() => _OTPConfirmationTestPageState();
}

class _OTPConfirmationTestPageState extends ConsumerState<OTPConfirmationTestPage> {
  final _otpController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _bookingData;
  Map<String, dynamic>? _otpStatus;

  @override
  void initState() {
    super.initState();
    if (widget.bookingId != null) {
      _loadBookingData();
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _loadBookingData() async {
    if (widget.bookingId == null) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final authUser = ref.read(authStateProvider).valueOrNull;
      if (authUser == null) return;

      final firestoreService = ref.read(firestoreBookingsServiceProvider);
      final bookings = await firestoreService.getBookings(authUser.uid);
      final booking = bookings.firstWhere(
        (b) => b['id'] == widget.bookingId,
        orElse: () => <String, dynamic>{},
      );

      if (booking.isNotEmpty) {
        setState(() {
          _bookingData = booking;
        });
        await _loadOTPStatus();
      }
    } catch (e) {
      debugPrint('Error loading booking: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadOTPStatus() async {
    if (widget.bookingId == null || _bookingData == null) return;

    try {
      final authUser = ref.read(authStateProvider).valueOrNull;
      if (authUser == null) return;

      final otpService = ref.read(codOTPServiceProvider);
      final status = await otpService.getOTPStatus(
        providerId: authUser.uid,
        bookingId: widget.bookingId!,
      );

      setState(() {
        _otpStatus = status;
      });
    } catch (e) {
      debugPrint('Error loading OTP status: $e');
    }
  }

  Future<void> _generateOTP() async {
    if (_bookingData == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authUser = ref.read(authStateProvider).valueOrNull;
      if (authUser == null) return;

      final otpService = ref.read(codOTPServiceProvider);
      final customerId = _bookingData!['customerId'] as String? ?? '';
      
      await otpService.generateOTP(
        providerId: authUser.uid,
        bookingId: widget.bookingId!,
        customerId: customerId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP generated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadBookingData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyOTP() async {
    if (_otpController.text.trim().length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 6-digit OTP'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authUser = ref.read(authStateProvider).valueOrNull;
      if (authUser == null) return;

      final otpService = ref.read(codOTPServiceProvider);
      final verified = await otpService.verifyOTP(
        providerId: authUser.uid,
        bookingId: widget.bookingId!,
        otpEntered: _otpController.text.trim(),
      );

      if (verified && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP verified! Service completed successfully.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
        _otpController.clear();
        await _loadBookingData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _resendOTP() async {
    if (_bookingData == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authUser = ref.read(authStateProvider).valueOrNull;
      if (authUser == null) return;

      final otpService = ref.read(codOTPServiceProvider);
      final customerId = _bookingData!['customerId'] as String? ?? '';
      
      await otpService.resendOTP(
        providerId: authUser.uid,
        bookingId: widget.bookingId!,
        customerId: customerId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP resent successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadBookingData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      currentRoute: '/bookings',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('OTP Confirmation (Test)'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/bookings'),
          ),
        ),
        body: _isLoading && _bookingData == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Booking Info Card
                    if (_bookingData != null) ...[
                      Card(
                        color: Colors.blue.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Booking Information',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              _buildInfoRow('Service', _bookingData!['serviceName'] ?? 'N/A'),
                              _buildInfoRow('Customer', _bookingData!['customerName'] ?? 'N/A'),
                              _buildInfoRow('Amount', '₹${(_bookingData!['amount'] ?? 0).toStringAsFixed(2)}'),
                              _buildInfoRow('Status', _bookingData!['status'] ?? 'N/A'),
                              _buildInfoRow('Payment Status', _bookingData!['paymentStatus'] ?? 'unpaid'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // OTP Status Card
                    if (_otpStatus != null) ...[
                      Card(
                        color: _otpStatus!['expired'] == true
                            ? Colors.orange.shade50
                            : _otpStatus!['verified'] == true
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
                                    _otpStatus!['expired'] == true
                                        ? Icons.error_outline
                                        : _otpStatus!['verified'] == true
                                            ? Icons.check_circle
                                            : Icons.access_time,
                                    color: _otpStatus!['expired'] == true
                                        ? Colors.orange
                                        : _otpStatus!['verified'] == true
                                            ? Colors.green
                                            : Colors.blue,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _otpStatus!['expired'] == true
                                        ? 'OTP Expired'
                                        : _otpStatus!['verified'] == true
                                            ? 'OTP Verified'
                                            : 'OTP Active',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ],
                              ),
                              if (_otpStatus!['expiresAt'] != null && !_otpStatus!['expired']!) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Expires at: ${DateFormat('hh:mm a').format(_otpStatus!['expiresAt'] as DateTime)}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                              if (_otpStatus!['resendCount'] > 0) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Resend attempts: ${_otpStatus!['resendCount']}/3',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // OTP Input Section
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Enter OTP',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _otpController,
                              decoration: const InputDecoration(
                                labelText: '6-Digit OTP',
                                hintText: 'Enter OTP',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.lock),
                              ),
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 24,
                                letterSpacing: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _isLoading ? null : _verifyOTP,
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.verified),
                              label: Text(_isLoading ? 'Verifying...' : 'Verify OTP'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Action Buttons
                    if (_bookingData != null) ...[
                      if (_bookingData!['status'] == 'accepted' || _bookingData!['status'] == 'confirmed') ...[
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _generateOTP,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Start Service & Generate OTP'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (_otpStatus != null && _otpStatus!['expired'] == true && _otpStatus!['verified'] != true) ...[
                        OutlinedButton.icon(
                          onPressed: _isLoading ? null : _resendOTP,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Resend OTP'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ],
                    ],

                    const SizedBox(height: 24),

                    // Test Instructions
                    Card(
                      color: Colors.grey.shade100,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Test Instructions',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            const Text('1. Run the seed script to create dummy bookings with OTP'),
                            const Text('2. Check the console for OTP values'),
                            const Text('3. Use those OTPs to test verification'),
                            const Text('4. Test expired OTP scenario'),
                            const Text('5. Test resend OTP (max 3 attempts)'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}

