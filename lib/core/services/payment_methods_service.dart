import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trivora_provider/core/config/app_config.dart';

/// Service to manage provider payment methods
class PaymentMethodsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get available payment methods
  List<PaymentMethod> getAvailablePaymentMethods() {
    return [
      PaymentMethod(
        id: 'cod',
        name: 'Cash on Delivery (COD)',
        description: 'Accept cash payments when service is completed',
        icon: '💵',
        isEnabled: true, // Default enabled
      ),
      PaymentMethod(
        id: 'online',
        name: 'Online Payment',
        description: 'Accept payments via credit/debit cards, UPI, wallets',
        icon: '💳',
        isEnabled: false,
      ),
      PaymentMethod(
        id: 'upi',
        name: 'UPI',
        description: 'Accept payments via UPI (Google Pay, PhonePe, etc.)',
        icon: '📱',
        isEnabled: false,
      ),
      PaymentMethod(
        id: 'bank_transfer',
        name: 'Bank Transfer',
        description: 'Accept payments via bank transfer/NEFT',
        icon: '🏦',
        isEnabled: false,
      ),
    ];
  }

  /// Get provider's payment method preferences
  Future<Map<String, bool>> getPaymentMethodPreferences(String providerId) async {
    try {
      final doc = await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .get();

      if (!doc.exists) {
        // Return defaults if document doesn't exist
        return {
          'cod': true,
          'online': false,
          'upi': false,
          'bank_transfer': false,
        };
      }

      final data = doc.data() ?? {};
      final paymentMethods = data['paymentMethods'] as Map<String, dynamic>? ?? {};

      return {
        'cod': paymentMethods['cod'] as bool? ?? true,
        'online': paymentMethods['online'] as bool? ?? false,
        'upi': paymentMethods['upi'] as bool? ?? false,
        'bank_transfer': paymentMethods['bank_transfer'] as bool? ?? false,
      };
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error fetching payment method preferences: $e');
      // Return defaults on error
      return {
        'cod': true,
        'online': false,
        'upi': false,
        'bank_transfer': false,
      };
    }
  }

  /// Update payment method preference
  Future<void> updatePaymentMethodPreference({
    required String providerId,
    required String methodId,
    required bool isEnabled,
  }) async {
    try {
      await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .update({
        'paymentMethods.$methodId': isEnabled,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ignore: avoid_print
      print('✅ Payment method $methodId updated to $isEnabled');
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error updating payment method preference: $e');
      throw Exception('Failed to update payment method preference: $e');
    }
  }

  /// Update all payment method preferences at once
  Future<void> updateAllPaymentMethodPreferences({
    required String providerId,
    required Map<String, bool> preferences,
  }) async {
    try {
      await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .update({
        'paymentMethods': preferences,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ignore: avoid_print
      print('✅ All payment method preferences updated');
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error updating payment method preferences: $e');
      throw Exception('Failed to update payment method preferences: $e');
    }
  }

  /// Get stream of payment method preferences
  Stream<Map<String, bool>> getPaymentMethodPreferencesStream(String providerId) {
    return _firestore
        .collection(AppConfig.providersCollection)
        .doc(providerId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) {
        return {
          'cod': true,
          'online': false,
          'upi': false,
          'bank_transfer': false,
        };
      }

      final data = doc.data() ?? {};
      final paymentMethods = data['paymentMethods'] as Map<String, dynamic>? ?? {};

      return {
        'cod': paymentMethods['cod'] as bool? ?? true,
        'online': paymentMethods['online'] as bool? ?? false,
        'upi': paymentMethods['upi'] as bool? ?? false,
        'bank_transfer': paymentMethods['bank_transfer'] as bool? ?? false,
      };
    });
  }
}

/// Payment method model
class PaymentMethod {
  final String id;
  final String name;
  final String description;
  final String icon;
  final bool isEnabled;

  PaymentMethod({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.isEnabled,
  });

  PaymentMethod copyWith({
    String? id,
    String? name,
    String? description,
    String? icon,
    bool? isEnabled,
  }) {
    return PaymentMethod(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}

/// Provider for PaymentMethodsService
final paymentMethodsServiceProvider = Provider<PaymentMethodsService>((ref) {
  return PaymentMethodsService();
});

