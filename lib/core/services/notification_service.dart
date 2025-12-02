import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trivora_provider/core/config/app_config.dart';

/// Service to handle push notifications using Firebase Cloud Messaging
class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  String? _fcmToken;
  
  /// Initialize notification service
  /// Request permissions and get FCM token
  Future<void> initialize(String providerId) async {
    try {
      // Request notification permissions
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ User granted notification permission');
        
        // Get FCM token
        _fcmToken = await _messaging.getToken();
        debugPrint('✅ FCM Token: $_fcmToken');
        
        // Save token to Firestore
        if (_fcmToken != null && providerId.isNotEmpty) {
          await _saveFCMToken(providerId, _fcmToken!);
        }
        
        // Listen for token refresh
        _messaging.onTokenRefresh.listen((newToken) {
          _fcmToken = newToken;
          debugPrint('🔄 FCM Token refreshed: $newToken');
          if (providerId.isNotEmpty) {
            _saveFCMToken(providerId, newToken);
          }
        });
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('⚠️ User granted provisional notification permission');
      } else {
        debugPrint('❌ User declined notification permission');
      }
    } catch (e) {
      debugPrint('❌ Error initializing notifications: $e');
    }
  }
  
  /// Save FCM token to Firestore
  Future<void> _saveFCMToken(String providerId, String token) async {
    try {
      await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ FCM token saved to Firestore');
    } catch (e) {
      debugPrint('❌ Error saving FCM token: $e');
    }
  }
  
  /// Get notification preferences for a provider
  Future<Map<String, dynamic>> getNotificationPreferences(String providerId) async {
    try {
      final doc = await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .get();
      
      if (doc.exists) {
        final data = doc.data() ?? {};
        return {
          'bookingNotifications': data['bookingNotifications'] ?? true,
          'serviceNotifications': data['serviceNotifications'] ?? true,
          'paymentNotifications': data['paymentNotifications'] ?? true,
          'pushNotificationsEnabled': data['pushNotificationsEnabled'] ?? true,
        };
      }
      
      // Return defaults if document doesn't exist
      return {
        'bookingNotifications': true,
        'serviceNotifications': true,
        'paymentNotifications': true,
        'pushNotificationsEnabled': true,
      };
    } catch (e) {
      debugPrint('❌ Error getting notification preferences: $e');
      return {
        'bookingNotifications': true,
        'serviceNotifications': true,
        'paymentNotifications': true,
        'pushNotificationsEnabled': true,
      };
    }
  }
  
  /// Update notification preferences
  Future<void> updateNotificationPreferences(
    String providerId,
    Map<String, dynamic> preferences,
  ) async {
    try {
      await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .update({
        'notificationPreferences': preferences,
        'notificationPreferencesUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Notification preferences updated');
    } catch (e) {
      debugPrint('❌ Error updating notification preferences: $e');
      throw Exception('Failed to update notification preferences: $e');
    }
  }

  /// Get notification preferences stream for real-time updates
  Stream<Map<String, dynamic>> getNotificationPreferencesStream(String providerId) {
    return _firestore
        .collection(AppConfig.providersCollection)
        .doc(providerId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) {
        return {
          'push': true,
          'email': true,
          'inApp': true,
        };
      }

      final data = doc.data() ?? {};
      final preferences = data['notificationPreferences'] as Map<String, dynamic>? ?? {};

      return {
        'push': preferences['push'] as bool? ?? true,
        'email': preferences['email'] as bool? ?? true,
        'inApp': preferences['inApp'] as bool? ?? true,
      };
    });
  }
  
  /// Send notification to provider (for testing)
  /// In production, this would be done via Cloud Functions
  Future<void> sendNotificationToProvider(
    String providerId,
    String title,
    String body,
    Map<String, dynamic>? data,
  ) async {
    try {
      // Get provider's FCM token
      final providerDoc = await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .get();
      
      if (!providerDoc.exists) {
        throw Exception('Provider not found');
      }
      
      final providerData = providerDoc.data() ?? {};
      final fcmToken = providerData['fcmToken'] as String?;
      
      if (fcmToken == null) {
        debugPrint('⚠️ Provider has no FCM token');
        return;
      }
      
      // Create notification document in Firestore
      await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('notifications')
          .add({
        'title': title,
        'body': body,
        'data': data ?? {},
        'read': false,
        'type': data?['type'] ?? 'general',
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('✅ Notification saved to Firestore');
      
      // Note: Actual push notification would be sent via Cloud Functions
      // This is just storing the notification in Firestore
    } catch (e) {
      debugPrint('❌ Error sending notification: $e');
      throw Exception('Failed to send notification: $e');
    }
  }
  
  /// Get notifications stream for real-time updates
  Stream<List<Map<String, dynamic>>> getNotificationsStream(String providerId) {
    try {
      return _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'title': data['title'] ?? '',
            'body': data['body'] ?? '',
            'data': data['data'] ?? {},
            'read': data['read'] ?? false,
            'type': data['type'] ?? 'general',
            'createdAt': (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          };
        }).toList();
      });
    } catch (e) {
      debugPrint('❌ Error creating notifications stream: $e');
      return Stream.value([]);
    }
  }
  
  /// Mark notification as read
  Future<void> markAsRead(String providerId, String notificationId) async {
    try {
      await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
      debugPrint('✅ Notification marked as read');
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
    }
  }
  
  /// Mark all notifications as read
  Future<void> markAllAsRead(String providerId) async {
    try {
      final notifications = await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .get();
      
      final batch = _firestore.batch();
      for (var doc in notifications.docs) {
        batch.update(doc.reference, {'read': true});
      }
      
      await batch.commit();
      debugPrint('✅ All notifications marked as read');
    } catch (e) {
      debugPrint('❌ Error marking all notifications as read: $e');
    }
  }
}

/// Provider for NotificationService
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

