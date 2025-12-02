import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trivora_provider/core/config/app_config.dart';

/// Service to handle OTP generation and verification for service start and completion
class ServiceOTPService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _random = Random();

  /// Generate Start OTP for service start verification
  /// Returns the plain OTP (for notification, not stored)
  Future<String> generateStartOtp({
    required String providerId,
    required String bookingId,
    required String customerId,
  }) async {
    try {
      // Get booking document to check resend count
      final bookingDoc = await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('bookings')
          .doc(bookingId)
          .get();

      if (!bookingDoc.exists) {
        throw Exception('Booking not found');
      }

      final bookingData = bookingDoc.data() ?? {};
      final startOtpData = bookingData['startOtp'] as Map<String, dynamic>?;
      final resendCount = (startOtpData?['resendCount'] as int? ?? 0);
      
      // Check if previous OTP exists and is expired or used
      if (startOtpData != null) {
        final isUsed = startOtpData['used'] == true;
        final expiresAt = (startOtpData['expiresAt'] as Timestamp?)?.toDate();
        final isExpired = expiresAt != null && DateTime.now().isAfter(expiresAt);
        
        // Only check resend count if OTP is still valid (not expired and not used)
        if (!isExpired && !isUsed) {
          // OTP is still valid, check resend count
          if (resendCount >= 3) {
            throw Exception('Maximum OTP resend attempts (3) reached. Please wait for the current OTP to expire or contact support.');
          }
        }
        // If OTP is expired or used, allow regeneration (resend count will be reset)
      }

      // Generate 6-digit OTP
      final otp = (100000 + _random.nextInt(900000)).toString();

      // Hash the OTP using SHA256
      final bytes = utf8.encode(otp);
      final hash = sha256.convert(bytes);
      final otpHash = hash.toString();

      // Calculate expiration time (10 minutes from now)
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(minutes: 10));

      // Calculate new resend count (reset if previous OTP expired/used, otherwise increment)
      int newResendCount = resendCount;
      if (startOtpData != null) {
        final isUsed = startOtpData['used'] == true;
        final expiresAtOld = (startOtpData['expiresAt'] as Timestamp?)?.toDate();
        final isExpired = expiresAtOld != null && DateTime.now().isAfter(expiresAtOld);
        
        if (isExpired || isUsed) {
          // Reset resend count for new OTP generation
          newResendCount = 1;
        } else {
          // Increment resend count
          newResendCount = resendCount + 1;
        }
      } else {
        // First time generating OTP
        newResendCount = 1;
      }

      // Update booking document with hashed OTP
      await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('bookings')
          .doc(bookingId)
          .update({
        'startOtp': {
          'otpHash': otpHash,
          'createdAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(expiresAt),
          'used': false,
          'resendCount': newResendCount,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Save OTP to provider's booking document for verification
      await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('bookings')
          .doc(bookingId)
          .update({
        'startOtpPlain': otp, // Store plain OTP for provider verification
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Send notification to customer with OTP
      await _sendNotificationToCustomer(
        customerId,
        bookingId,
        'Service Start OTP',
        'Your OTP to start the service is: $otp. Please share this with your service provider. Valid for 10 minutes.',
        'service_start_otp',
        otp,
      );

      // Send notification to provider
      await _sendNotificationToProvider(
        providerId,
        bookingId,
        'Start OTP Generated',
        'OTP has been generated and sent to customer. Please ask the customer for the OTP to start the service.',
        'start_otp_generated',
      );

      // ignore: avoid_print
      print('✅ Start OTP generated for booking: $bookingId, OTP: $otp');
      return otp; // Return plain OTP for testing/logging
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error generating start OTP: $e');
      throw Exception('Failed to generate start OTP: $e');
    }
  }

  /// Verify Start OTP and start the service
  Future<bool> verifyStartOtpAndStartService({
    required String providerId,
    required String bookingId,
    required String otpEntered,
  }) async {
    try {
      // Get booking document
      final bookingDoc = await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('bookings')
          .doc(bookingId)
          .get();

      if (!bookingDoc.exists) {
        throw Exception('Booking not found');
      }

      final bookingData = bookingDoc.data() ?? {};
      final startOtpData = bookingData['startOtp'] as Map<String, dynamic>?;

      if (startOtpData == null) {
        throw Exception('No start OTP found. Please generate OTP first.');
      }

      // Check if OTP is already used
      if (startOtpData['used'] == true) {
        throw Exception('This OTP has already been used.');
      }

      // Check expiration
      final expiresAt = (startOtpData['expiresAt'] as Timestamp?)?.toDate();
      if (expiresAt == null || DateTime.now().isAfter(expiresAt)) {
        throw Exception('OTP has expired. Please generate a new OTP.');
      }

      // Hash the entered OTP
      final bytes = utf8.encode(otpEntered);
      final hash = sha256.convert(bytes);
      final enteredHash = hash.toString();

      // Get stored hash and plain OTP (for verification)
      final storedHash = startOtpData['otpHash'] as String?;
      final storedPlainOtp = bookingData['startOtpPlain'] as String?;
      
      // Verify OTP - check both hash and plain OTP
      bool isValid = false;
      if (storedHash != null && enteredHash == storedHash) {
        isValid = true;
      } else if (storedPlainOtp != null && otpEntered == storedPlainOtp) {
        isValid = true;
      }
      
      if (!isValid) {
        throw Exception('Invalid OTP. Please enter the correct OTP.');
      }

      // OTP verified - Start the service
      final customerId = bookingData['customerId'] as String? ?? '';

      await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('bookings')
          .doc(bookingId)
          .update({
        'status': 'in_progress',
        'serviceStartTime': FieldValue.serverTimestamp(),
        'startOtp.used': true,
        'startOtp.verifiedAt': FieldValue.serverTimestamp(),
        'startOtpPlain': FieldValue.delete(), // Remove plain OTP after use
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Delete the hashed OTP data after use
      await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('bookings')
          .doc(bookingId)
          .update({
        'startOtp': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Send notifications
      await _sendNotificationToCustomer(
        customerId,
        bookingId,
        'Service Started',
        'Your service has been started by the provider.',
        'service_started',
        null,
      );

      await _sendNotificationToProvider(
        providerId,
        bookingId,
        'Service Started',
        'Service has been started successfully.',
        'service_started',
      );

      // ignore: avoid_print
      print('✅ Start OTP verified and service started: $bookingId');
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error verifying start OTP: $e');
      rethrow;
    }
  }

  /// Generate Completion OTP for service completion verification
  /// Returns the plain OTP (for notification, not stored)
  Future<String> generateCompletionOtp({
    required String providerId,
    required String bookingId,
    required String customerId,
  }) async {
    try {
      // Get booking document to check resend count
      final bookingDoc = await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('bookings')
          .doc(bookingId)
          .get();

      if (!bookingDoc.exists) {
        throw Exception('Booking not found');
      }

      final bookingData = bookingDoc.data() ?? {};
      final status = bookingData['status'] as String? ?? '';

      // Check if service is in progress
      if (status != 'in_progress') {
        throw Exception('Service must be in progress to generate completion OTP.');
      }

      final completionOtpData = bookingData['completionOtp'] as Map<String, dynamic>?;
      final resendCount = (completionOtpData?['resendCount'] as int? ?? 0);

      // Check max resend attempts (3)
      if (resendCount >= 3) {
        throw Exception('Maximum OTP resend attempts (3) reached. Please contact support.');
      }

      // Generate 6-digit OTP
      final otp = (100000 + _random.nextInt(900000)).toString();

      // Hash the OTP using SHA256
      final bytes = utf8.encode(otp);
      final hash = sha256.convert(bytes);
      final otpHash = hash.toString();

      // Calculate expiration time (10 minutes from now)
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(minutes: 10));

      // Calculate new resend count (reset if previous OTP expired/used, otherwise increment)
      int newResendCount = resendCount;
      if (completionOtpData != null) {
        final isUsed = completionOtpData['used'] == true;
        final expiresAtOld = (completionOtpData['expiresAt'] as Timestamp?)?.toDate();
        final isExpired = expiresAtOld != null && DateTime.now().isAfter(expiresAtOld);
        
        if (isExpired || isUsed) {
          // Reset resend count for new OTP generation
          newResendCount = 1;
        } else {
          // Increment resend count
          newResendCount = resendCount + 1;
        }
      } else {
        // First time generating OTP
        newResendCount = 1;
      }

      // Update booking document with hashed OTP
      await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('bookings')
          .doc(bookingId)
          .update({
        'completionOtp': {
          'otpHash': otpHash,
          'createdAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(expiresAt),
          'used': false,
          'resendCount': newResendCount,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Save OTP to provider's booking document for verification
      await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('bookings')
          .doc(bookingId)
          .update({
        'completionOtpPlain': otp, // Store plain OTP for provider verification
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Send notification to customer with OTP
      await _sendNotificationToCustomer(
        customerId,
        bookingId,
        'Service Completion OTP',
        'Your OTP to complete the service is: $otp. Please share this with your service provider. Valid for 10 minutes.',
        'service_completion_otp',
        otp,
      );

      // Send notification to provider
      await _sendNotificationToProvider(
        providerId,
        bookingId,
        'Completion OTP Generated',
        'OTP has been generated and sent to customer. Please ask the customer for the OTP to complete the service.',
        'completion_otp_generated',
      );

      // ignore: avoid_print
      print('✅ Completion OTP generated for booking: $bookingId, OTP: $otp');
      return otp; // Return plain OTP for testing/logging
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error generating completion OTP: $e');
      throw Exception('Failed to generate completion OTP: $e');
    }
  }

  /// Verify Completion OTP and complete the service
  Future<bool> verifyCompletionOtp({
    required String providerId,
    required String bookingId,
    required String otpEntered,
  }) async {
    try {
      // Get booking document
      final bookingDoc = await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('bookings')
          .doc(bookingId)
          .get();

      if (!bookingDoc.exists) {
        throw Exception('Booking not found');
      }

      final bookingData = bookingDoc.data() ?? {};
      final completionOtpData = bookingData['completionOtp'] as Map<String, dynamic>?;

      if (completionOtpData == null) {
        throw Exception('No completion OTP found. Please generate OTP first.');
      }

      // Check if OTP is already used
      if (completionOtpData['used'] == true) {
        throw Exception('This OTP has already been used.');
      }

      // Check expiration
      final expiresAt = (completionOtpData['expiresAt'] as Timestamp?)?.toDate();
      if (expiresAt == null || DateTime.now().isAfter(expiresAt)) {
        throw Exception('OTP has expired. Please generate a new OTP.');
      }

      // Hash the entered OTP
      final bytes = utf8.encode(otpEntered);
      final hash = sha256.convert(bytes);
      final enteredHash = hash.toString();

      // Get stored hash and plain OTP (for verification)
      final storedHash = completionOtpData['otpHash'] as String?;
      final storedPlainOtp = bookingData['completionOtpPlain'] as String?;
      
      // Verify OTP - check both hash and plain OTP
      bool isValid = false;
      if (storedHash != null && enteredHash == storedHash) {
        isValid = true;
      } else if (storedPlainOtp != null && otpEntered == storedPlainOtp) {
        isValid = true;
      }
      
      if (!isValid) {
        throw Exception('Invalid OTP. Please enter the correct OTP.');
      }

      // OTP verified - Complete the service
      final customerId = bookingData['customerId'] as String? ?? '';
      final baseAmount = (bookingData['amount'] ?? 0).toDouble();
      final paymentMethod = bookingData['paymentMethod'] as String? ?? 'cod';
      final serviceStartTime = (bookingData['serviceStartTime'] as Timestamp?)?.toDate();
      final scheduledDate = (bookingData['scheduledDate'] as Timestamp?)?.toDate();
      final scheduledDuration = (bookingData['scheduledDuration'] as int? ?? 60); // Default 60 minutes
      
      // Calculate actual service duration
      DateTime? actualStartTime = serviceStartTime;
      final actualEndTime = DateTime.now();
      int actualDurationMinutes = 0;
      
      if (actualStartTime != null) {
        actualDurationMinutes = actualEndTime.difference(actualStartTime).inMinutes;
      } else if (scheduledDate != null) {
        // If serviceStartTime is not available, use scheduledDate as fallback
        actualStartTime = scheduledDate;
        actualDurationMinutes = actualEndTime.difference(actualStartTime).inMinutes;
      }
      
      // Calculate payment based on actual duration vs scheduled duration
      double finalAmount = baseAmount;
      double extraAmount = 0.0;
      
      if (actualDurationMinutes > scheduledDuration) {
        // Calculate extra time worked
        final extraMinutes = actualDurationMinutes - scheduledDuration;
        // Calculate extra payment (proportional to base amount)
        final ratePerMinute = baseAmount / scheduledDuration.toDouble();
        extraAmount = (extraMinutes * ratePerMinute).toDouble();
        finalAmount = baseAmount + extraAmount;
      }

      // Update booking status and payment
      await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('bookings')
          .doc(bookingId)
          .update({
        'status': 'completed',
        'serviceEndTime': FieldValue.serverTimestamp(),
        'paymentStatus': 'paid', // Always set to paid when OTP verified
        'actualDurationMinutes': actualDurationMinutes,
        'scheduledDurationMinutes': scheduledDuration,
        'extraDurationMinutes': actualDurationMinutes > scheduledDuration ? (actualDurationMinutes - scheduledDuration) : 0,
        'baseAmount': baseAmount,
        'extraAmount': extraAmount,
        'finalAmount': finalAmount,
        'completionOtp.used': true,
        'completionOtp.verifiedAt': FieldValue.serverTimestamp(),
        'completionOtpPlain': FieldValue.delete(), // Remove plain OTP after use
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Delete the hashed OTP data after use
      await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('bookings')
          .doc(bookingId)
          .update({
        'completionOtp': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update provider earnings (for COD payments) - use finalAmount
      if (paymentMethod.toLowerCase() == 'cod') {
        await _updateProviderEarnings(providerId, bookingId, finalAmount);
      }

      // Send notifications
      await _sendNotificationToCustomer(
        customerId,
        bookingId,
        'Service Completed',
        'Your service has been completed successfully. Payment received.',
        'service_completed',
        null,
      );

      await _sendNotificationToProvider(
        providerId,
        bookingId,
        'Service Completed',
        'Service completed successfully. Payment received and earnings updated.',
        'service_completed',
      );

      // ignore: avoid_print
      print('✅ Completion OTP verified and service completed: $bookingId');
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error verifying completion OTP: $e');
      rethrow;
    }
  }

  /// Update provider earnings after service completion
  Future<void> _updateProviderEarnings(
    String providerId,
    String bookingId,
    double finalAmount, // Changed parameter name to finalAmount
  ) async {
    try {
      const platformFeeRate = 0.10; // 10% platform fee
      final platformFee = finalAmount * platformFeeRate;
      final providerEarning = finalAmount - platformFee;

      // Update provider's wallet balance
      final walletRef = _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection(AppConfig.providerWalletsCollection)
          .doc('wallet');

      await _firestore.runTransaction((transaction) async {
        final walletDoc = await transaction.get(walletRef);
        double currentBalance = (walletDoc.data()?['balance'] ?? 0).toDouble();
        transaction.set(
          walletRef,
          {
            'balance': currentBalance + providerEarning,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });

      // Create a wallet transaction record
      await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('walletTransactions')
          .add({
        'type': 'earning',
        'amount': providerEarning,
        'baseAmount': finalAmount,
        'bookingId': bookingId,
        'transactionDate': FieldValue.serverTimestamp(),
        'description': 'Earnings from booking $bookingId (Final Amount: ₹${finalAmount.toStringAsFixed(2)})',
      });

      // Create a payment record
      await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection(AppConfig.providerPaymentsCollection)
          .add({
        'bookingId': bookingId,
        'baseAmount': finalAmount, // Store final amount (base + extra)
        'amount': finalAmount, // For backward compatibility
        'platformFee': platformFee,
        'providerEarning': providerEarning,
        'status': 'paid',
        'paymentMethod': 'COD',
        'paidAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // ignore: avoid_print
      print('✅ Provider earnings updated for booking: $bookingId');
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error updating provider earnings: $e');
      // Don't throw - earnings update failure shouldn't block completion
    }
  }

  /// Send notification to customer via Firestore
  Future<void> _sendNotificationToCustomer(
    String customerId,
    String bookingId,
    String title,
    String body,
    String type,
    String? otp,
  ) async {
    try {
      await _firestore.collection(AppConfig.notificationsCollection).add({
        'userId': customerId,
        'title': title,
        'body': body,
        'type': type,
        'data': {
          'bookingId': bookingId,
          if (otp != null) 'otp': otp,
        },
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error sending notification to customer: $e');
    }
  }

  /// Send notification to provider via Firestore
  Future<void> _sendNotificationToProvider(
    String providerId,
    String bookingId,
    String title,
    String body,
    String type,
  ) async {
    try {
      await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('notifications')
          .add({
        'title': title,
        'body': body,
        'type': type,
        'data': {
          'bookingId': bookingId,
        },
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error sending notification to provider: $e');
    }
  }
}

/// Provider for ServiceOTPService
final serviceOTPServiceProvider = Provider<ServiceOTPService>((ref) {
  return ServiceOTPService();
});

