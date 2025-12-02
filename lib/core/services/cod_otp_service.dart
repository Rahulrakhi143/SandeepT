import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trivora_provider/core/config/app_config.dart';
import 'package:trivora_provider/core/services/notification_service.dart';

/// Service to handle COD (Cash on Delivery) OTP generation and verification
class CODOTPService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  /// Generate a 6-digit OTP for COD completion
  /// Returns the plain OTP (only for display to user, not stored)
  Future<String> generateOTP({
    required String providerId,
    required String bookingId,
    required String customerId,
  }) async {
    try {
      // Generate 6-digit OTP
      final random = Random();
      final otp = (100000 + random.nextInt(900000)).toString();

      // Hash the OTP using SHA256
      final bytes = utf8.encode(otp);
      final hash = sha256.convert(bytes);
      final otpHash = hash.toString();

      // Calculate expiration time (10 minutes from now)
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(minutes: 10));

      // Update booking document with OTP hash
      await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('bookings')
          .doc(bookingId)
          .update({
        'otp': {
          'codeHash': otpHash,
          'createdAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(expiresAt),
          'verified': false,
          'resendCount': 0,
        },
        'status': 'in_progress', // Service is in progress
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Send notification to user with OTP (via Firestore notifications collection)
      await _firestore
          .collection(AppConfig.notificationsCollection)
          .add({
        'userId': customerId,
        'title': 'OTP for Service Completion',
        'body': 'Your OTP for service completion is: $otp. Valid for 10 minutes. Do not share until service is fully done.',
        'type': 'cod_otp_generated',
        'data': {
          'bookingId': bookingId,
          'otp': otp, // Send plain OTP to user app
          'expiresAt': expiresAt.toIso8601String(),
        },
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Send notification to provider
      await _notificationService.sendNotificationToProvider(
        providerId,
        'OTP Generated',
        'OTP has been generated. Please ask the customer for the OTP to complete the service.',
        {
          'type': 'otp_generated',
          'bookingId': bookingId,
        },
      );

      // ignore: avoid_print
      print('✅ OTP generated for booking: $bookingId');
      return otp; // Return plain OTP (only for logging/debugging, not stored)
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error generating OTP: $e');
      throw Exception('Failed to generate OTP: $e');
    }
  }

  /// Verify OTP entered by provider
  Future<bool> verifyOTP({
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
      final otpData = bookingData['otp'] as Map<String, dynamic>?;

      if (otpData == null) {
        throw Exception('OTP not found. Please generate OTP first.');
      }

      // Check if OTP is already verified
      if (otpData['verified'] == true) {
        throw Exception('OTP has already been verified. This booking is already completed.');
      }

      // Check expiration
      final expiresAt = (otpData['expiresAt'] as Timestamp?)?.toDate();
      if (expiresAt == null || DateTime.now().isAfter(expiresAt)) {
        throw Exception('OTP has expired. Please request a new OTP.');
      }

      // Hash the entered OTP
      final bytes = utf8.encode(otpEntered);
      final hash = sha256.convert(bytes);
      final enteredHash = hash.toString();

      // Get stored hash
      final storedHash = otpData['codeHash'] as String?;

      if (storedHash == null) {
        throw Exception('OTP hash not found');
      }

      // Compare hashes
      if (enteredHash != storedHash) {
        // Track failed attempts
        final failedAttempts = (otpData['failedAttempts'] as int? ?? 0) + 1;
        await _firestore
            .collection(AppConfig.providersCollection)
            .doc(providerId)
            .collection('bookings')
            .doc(bookingId)
            .update({
          'otp.failedAttempts': failedAttempts,
        });

        throw Exception('Invalid OTP. Please check and try again.');
      }

      // OTP is valid - complete the booking
      final amount = (bookingData['amount'] ?? 0).toDouble();
      final paymentMethod = bookingData['paymentMethod'] as String? ?? 'cod';
      final customerId = bookingData['customerId'] as String? ?? '';

      // Update booking status
      await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('bookings')
          .doc(bookingId)
          .update({
        'status': 'completed',
        'paymentStatus': 'paid',
        'paidAt': FieldValue.serverTimestamp(),
        'otp.verified': true,
        'otp.verifiedAt': FieldValue.serverTimestamp(),
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update provider earnings (if COD)
      if (paymentMethod.toLowerCase() == 'cod') {
        await _updateProviderEarnings(providerId, bookingId, amount);
      }

      // Send notification to user (via Firestore notifications collection)
      await _firestore
          .collection(AppConfig.notificationsCollection)
          .add({
        'userId': customerId,
        'title': 'Service Completed',
        'body': 'Your service has been completed successfully. Payment received.',
        'type': 'service_completed',
        'data': {
          'bookingId': bookingId,
        },
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _notificationService.sendNotificationToProvider(
        providerId,
        'Service Completed',
        'Service completed successfully. Payment received.',
        {
          'type': 'service_completed',
          'bookingId': bookingId,
          'amount': amount,
        },
      );

      // ignore: avoid_print
      print('✅ OTP verified and booking completed: $bookingId');
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error verifying OTP: $e');
      rethrow;
    }
  }

  /// Resend OTP (max 3 attempts)
  Future<String> resendOTP({
    required String providerId,
    required String bookingId,
    required String customerId,
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
      final otpData = bookingData['otp'] as Map<String, dynamic>?;

      // Check resend count
      final resendCount = (otpData?['resendCount'] as int? ?? 0);
      if (resendCount >= 3) {
        throw Exception('Maximum resend attempts (3) reached. Please contact support.');
      }

      // Generate new OTP
      return await generateOTP(
        providerId: providerId,
        bookingId: bookingId,
        customerId: customerId,
      );
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error resending OTP: $e');
      rethrow;
    }
  }

  /// Get OTP status for a booking
  Future<Map<String, dynamic>?> getOTPStatus({
    required String providerId,
    required String bookingId,
  }) async {
    try {
      final bookingDoc = await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('bookings')
          .doc(bookingId)
          .get();

      if (!bookingDoc.exists) {
        return null;
      }

      final bookingData = bookingDoc.data() ?? {};
      final otpData = bookingData['otp'] as Map<String, dynamic>?;

      if (otpData == null) {
        return null;
      }

      final expiresAt = (otpData['expiresAt'] as Timestamp?)?.toDate();
      final isExpired = expiresAt != null && DateTime.now().isAfter(expiresAt);
      final isVerified = otpData['verified'] == true;

      return {
        'exists': true,
        'verified': isVerified,
        'expired': isExpired,
        'expiresAt': expiresAt,
        'resendCount': otpData['resendCount'] as int? ?? 0,
        'failedAttempts': otpData['failedAttempts'] as int? ?? 0,
      };
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error getting OTP status: $e');
      return null;
    }
  }

  /// Update provider earnings after COD payment
  Future<void> _updateProviderEarnings(
    String providerId,
    String bookingId,
    double amount,
  ) async {
    try {
      // Calculate platform fee (10% example)
      const platformFeePercent = 0.10;
      final platformFee = amount * platformFeePercent;
      final providerEarning = amount - platformFee;

      // Update provider wallet
      final walletRef = _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('wallet')
          .doc('balance');

      await walletRef.set({
        'balance': FieldValue.increment(providerEarning),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Add transaction record
      await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('walletTransactions')
          .add({
        'type': 'earning',
        'amount': providerEarning,
        'bookingId': bookingId,
        'platformFee': platformFee,
        'totalAmount': amount,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update payment record
      await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('payments')
          .add({
        'bookingId': bookingId,
        'amount': amount,
        'platformFee': platformFee,
        'providerEarning': providerEarning,
        'status': 'paid',
        'paymentMethod': 'cod',
        'paidAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // ignore: avoid_print
      print('✅ Provider earnings updated: $providerEarning');
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error updating provider earnings: $e');
      // Don't throw - earnings update failure shouldn't block completion
    }
  }
}

/// Provider for CODOTPService
final codOTPServiceProvider = Provider<CODOTPService>((ref) {
  return CODOTPService();
});

