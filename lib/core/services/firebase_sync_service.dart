import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trivora_provider/core/config/app_config.dart';
import 'package:trivora_provider/core/services/backend_service.dart';

/// Service to sync backend data to Firebase Firestore
class FirebaseSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BackendService _backendService = BackendService();

  /// Sync all backend data to Firebase
  Future<void> syncAllDataToFirebase(String userId) async {
    try {
      // Initialize backend data
      _backendService.initializeData(userId);

      // Sync providers
      await _syncProviderToFirebase(userId);

      // Sync services
      await _syncServicesToFirebase(userId);

      // Sync bookings
      await _syncBookingsToFirebase(userId);

      // Sync payments
      await _syncPaymentsToFirebase(userId);

      // Sync wallet
      await _syncWalletToFirebase(userId);
    } catch (e) {
      throw Exception('Failed to sync data to Firebase: $e');
    }
  }

  /// Sync provider data to Firebase
  Future<void> _syncProviderToFirebase(String userId) async {
    // Get existing provider data or create new
    final providerDoc = await _firestore
        .collection(AppConfig.providersCollection)
        .doc(userId)
        .get();

    final providerData = {
      'userId': userId,
      'isOnline': providerDoc.data()?['isOnline'] ?? true,
      'rating': providerDoc.data()?['rating'] ?? 4.5,
      'totalBookings': providerDoc.data()?['totalBookings'] ?? 0,
      'completedBookings': providerDoc.data()?['completedBookings'] ?? 0,
      'isVerified': providerDoc.data()?['isVerified'] ?? true,
      'role': AppConfig.roleProvider,
      'updatedAt': FieldValue.serverTimestamp(),
      if (!providerDoc.exists) 'createdAt': FieldValue.serverTimestamp(),
    };

    await _firestore
        .collection(AppConfig.providersCollection)
        .doc(userId)
        .set(providerData, SetOptions(merge: true));
  }

  /// Sync services to Firebase
  Future<void> _syncServicesToFirebase(String userId) async {
    final services = _backendService.getServices(userId);
    
    for (var service in services) {
      final serviceData = {
        'providerId': userId,
        'serviceName': service['serviceName'],
        'description': service['description'],
        'basePrice': service['basePrice'],
        'duration': service['duration'],
        'category': service['category'],
        'isActive': service['isActive'],
        'createdAt': Timestamp.fromDate(service['createdAt'] as DateTime),
        'updatedAt': Timestamp.fromDate(service['updatedAt'] as DateTime),
      };

      await _firestore
          .collection(AppConfig.providersCollection)
          .doc(userId)
          .collection('services')
          .doc(service['id'] as String)
          .set(serviceData, SetOptions(merge: true));
    }
  }

  /// Sync bookings to Firebase
  Future<void> _syncBookingsToFirebase(String userId) async {
    final bookings = _backendService.getBookings(userId);
    
    for (var booking in bookings) {
      final bookingData = {
        'providerId': userId,
        'customerId': booking['customerId'],
        'customerName': booking['customerName'],
        'customerPhone': booking['customerPhone'],
        'serviceName': booking['serviceName'],
        'status': booking['status'],
        'amount': booking['amount'],
        'scheduledDate': Timestamp.fromDate(booking['scheduledDate'] as DateTime),
        'address': booking['address'],
        'createdAt': Timestamp.fromDate(booking['createdAt'] as DateTime),
        'updatedAt': Timestamp.fromDate(booking['updatedAt'] as DateTime),
      };

      await _firestore
          .collection(AppConfig.providersCollection)
          .doc(userId)
          .collection('bookings')
          .doc(booking['id'] as String)
          .set(bookingData, SetOptions(merge: true));
    }
  }

  /// Sync payments to Firebase
  Future<void> _syncPaymentsToFirebase(String userId) async {
    final payments = _backendService.getPayments(userId);
    
    for (var payment in payments) {
      final paymentData = {
        'providerId': userId,
        'bookingId': payment['bookingId'],
        'amount': payment['amount'],
        'platformFee': payment['platformFee'],
        'providerEarning': payment['providerEarning'],
        'status': payment['status'],
        'paymentMethod': payment['paymentMethod'],
        'createdAt': Timestamp.fromDate(payment['createdAt'] as DateTime),
        'updatedAt': Timestamp.fromDate(payment['updatedAt'] as DateTime),
      };

      await _firestore
          .collection(AppConfig.providersCollection)
          .doc(userId)
          .collection('payments')
          .doc(payment['id'] as String)
          .set(paymentData, SetOptions(merge: true));
    }
  }

  /// Sync wallet to Firebase
  Future<void> _syncWalletToFirebase(String userId) async {
    final balance = _backendService.getWalletBalance(userId);
    
    final walletData = {
      'providerId': userId,
      'balance': balance,
      'pendingBalance': 0.0,
      'totalEarnings': balance,
      'lastUpdated': FieldValue.serverTimestamp(),
    };

    await _firestore
        .collection(AppConfig.providersCollection)
        .doc(userId)
        .collection('wallet')
        .doc('balance')
        .set(walletData, SetOptions(merge: true));
  }

  /// Add random data to Firebase (one-time operation)
  Future<void> addRandomDataToFirebase(String userId) async {
    try {
      // Initialize backend with random data
      _backendService.initializeData(userId);
      
      // Sync all data to Firebase
      await syncAllDataToFirebase(userId);
    } catch (e) {
      throw Exception('Failed to add random data to Firebase: $e');
    }
  }
}

/// Provider for FirebaseSyncService
final firebaseSyncServiceProvider = Provider<FirebaseSyncService>((ref) {
  return FirebaseSyncService();
});

