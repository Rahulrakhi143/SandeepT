import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:trivora_provider/core/config/app_config.dart';
import 'package:trivora_provider/core/services/notification_service.dart';

/// Listener service to detect new bookings and send notifications
class BookingNotificationListener {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  
  StreamSubscription<QuerySnapshot>? _bookingSubscription;
  
  /// Start listening for new bookings for a provider
  void startListening(String providerId) {
    // Stop any existing listener
    stopListening();
    
    // Listen for new pending bookings
    _bookingSubscription = _firestore
        .collection(AppConfig.providersCollection)
        .doc(providerId)
        .collection('bookings')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          // New booking detected
          final bookingData = change.doc.data() ?? {};
          _handleNewBooking(providerId, change.doc.id, bookingData);
        }
      }
    });
    
    debugPrint('✅ Started listening for new bookings: $providerId');
  }
  
  /// Handle new booking notification
  Future<void> _handleNewBooking(
    String providerId,
    String bookingId,
    Map<String, dynamic> bookingData,
  ) async {
    try {
      // Check notification preferences
      final preferences = await _notificationService.getNotificationPreferences(providerId);
      
      if (preferences['bookingNotifications'] == true && 
          preferences['pushNotificationsEnabled'] == true) {
        await _notificationService.sendNotificationToProvider(
          providerId,
          'New Booking Request',
          '${bookingData['customerName'] ?? 'A customer'} has booked "${bookingData['serviceName'] ?? 'your service'}"',
          {
            'type': 'new_booking',
            'bookingId': bookingId,
            'customerName': bookingData['customerName'] ?? '',
            'serviceName': bookingData['serviceName'] ?? '',
            'amount': bookingData['amount'] ?? 0,
          },
        );
        debugPrint('✅ Notification sent for new booking: $bookingId');
      }
    } catch (e) {
      debugPrint('❌ Error handling new booking notification: $e');
    }
  }
  
  /// Stop listening for bookings
  void stopListening() {
    _bookingSubscription?.cancel();
    _bookingSubscription = null;
    debugPrint('🛑 Stopped listening for bookings');
  }
}

