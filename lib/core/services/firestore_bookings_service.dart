import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trivora_provider/core/config/app_config.dart';
import 'package:trivora_provider/core/services/notification_service.dart';

/// Service to fetch and manage bookings from Firestore
class FirestoreBookingsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get all bookings for a provider from Firestore
  Future<List<Map<String, dynamic>>> getBookings(
    String providerId, {
    String? status,
  }) async {
    try {
      Query query = _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('bookings');

      // Apply status filter if provided
      if (status != null && status != 'all') {
        query = query.where('status', isEqualTo: status);
        // When filtering by status, we can't use orderBy without a composite index
        // So we'll fetch and sort in memory instead
      } else {
        // Only use orderBy when not filtering by status to avoid index requirement
        query = query.orderBy('scheduledDate', descending: false);
      }

      final querySnapshot = await query.get();

      final bookings = <Map<String, dynamic>>[];
      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final booking = {
          'id': doc.id,
          'providerId': data['providerId'] ?? providerId,
          'customerId': data['customerId'] ?? '',
          'customerName': data['customerName'] ?? 'Unknown',
          'customerPhone': data['customerPhone'] ?? '',
          'serviceName': data['serviceName'] ?? '',
          'status': data['status'] ?? 'pending',
          'amount': (data['amount'] ?? 0).toDouble(),
          'address': data['address'] ?? '',
          'paymentMethod': data['paymentMethod'] ?? data['payment_mode'] ?? 'cod',
          'scheduledDate': (data['scheduledDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'createdAt': (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'updatedAt': (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        };
        bookings.add(booking);
      }

      // Sort by scheduled date (upcoming first)
      // Always sort in memory to ensure consistent ordering
      bookings.sort((a, b) {
        final dateA = a['scheduledDate'] as DateTime;
        final dateB = b['scheduledDate'] as DateTime;
        return dateA.compareTo(dateB);
      });

      return bookings;
    } catch (e) {
      // ignore: avoid_print
      print('Error fetching bookings from Firestore: $e');
      return [];
    }
  }

  /// Get bookings stream for real-time updates
  Stream<List<Map<String, dynamic>>> getBookingsStream(
    String providerId, {
    String? status,
  }) {
    try {
      Query query = _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('bookings');

      // Apply status filter if provided
      if (status != null && status != 'all') {
        query = query.where('status', isEqualTo: status);
        // When filtering by status, we can't use orderBy without a composite index
        // So we'll fetch and sort in memory instead
      } else {
        // Only use orderBy when not filtering by status to avoid index requirement
        query = query.orderBy('scheduledDate', descending: false);
      }

      return query.snapshots().map((querySnapshot) {
        final bookings = <Map<String, dynamic>>[];
        for (var doc in querySnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          final booking = {
            'id': doc.id,
            'providerId': data['providerId'] ?? providerId,
            'customerId': data['customerId'] ?? '',
            'customerName': data['customerName'] ?? 'Unknown',
            'customerPhone': data['customerPhone'] ?? '',
            'serviceName': data['serviceName'] ?? '',
            'status': data['status'] ?? 'pending',
            'amount': (data['amount'] ?? 0).toDouble(),
            'address': data['address'] ?? '',
            'paymentMethod': data['paymentMethod'] ?? data['payment_mode'] ?? 'cod',
            'scheduledDate': (data['scheduledDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
            'createdAt': (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            'updatedAt': (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          };
          bookings.add(booking);
        }

        // Sort by scheduled date (upcoming first)
        bookings.sort((a, b) {
          final dateA = a['scheduledDate'] as DateTime;
          final dateB = b['scheduledDate'] as DateTime;
          return dateA.compareTo(dateB);
        });

        return bookings;
      });
    } catch (e) {
      // ignore: avoid_print
      print('Error creating bookings stream: $e');
      return Stream.value([]);
    }
  }

  /// Update booking status in Firestore
  Future<void> updateBookingStatus(
    String providerId,
    String bookingId,
    String status,
  ) async {
    try {
      await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('bookings')
          .doc(bookingId)
          .update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      // ignore: avoid_print
      print('✅ Booking status updated in Firestore: $bookingId -> $status');
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error updating booking status: $e');
      throw Exception('Failed to update booking status: $e');
    }
  }

  /// Accept a booking
  Future<void> acceptBooking(String providerId, String bookingId) async {
    await updateBookingStatus(providerId, bookingId, 'accepted');
    
    // Send notification to provider about accepted booking
    try {
      final notificationService = NotificationService();
      final bookingDoc = await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('bookings')
          .doc(bookingId)
          .get();
      
      if (bookingDoc.exists) {
        final bookingData = bookingDoc.data() ?? {};
        await notificationService.sendNotificationToProvider(
          providerId,
          'Booking Accepted',
          'You have accepted booking for ${bookingData['serviceName'] ?? 'service'}',
          {
            'type': 'booking_accepted',
            'bookingId': bookingId,
            'serviceName': bookingData['serviceName'] ?? '',
          },
        );
      }
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ Could not send notification: $e');
    }
  }

  /// Reject a booking
  Future<void> rejectBooking(
    String providerId,
    String bookingId,
    String reason,
  ) async {
    try {
      await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('bookings')
          .doc(bookingId)
          .update({
        'status': 'rejected',
        'rejectionReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      // ignore: avoid_print
      print('✅ Booking rejected in Firestore: $bookingId');
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error rejecting booking: $e');
      throw Exception('Failed to reject booking: $e');
    }
  }

  /// Complete a booking
  Future<void> completeBooking(String providerId, String bookingId) async {
    await updateBookingStatus(providerId, bookingId, 'completed');
  }
}

/// Provider for FirestoreBookingsService
final firestoreBookingsServiceProvider = Provider<FirestoreBookingsService>((ref) {
  return FirestoreBookingsService();
});

