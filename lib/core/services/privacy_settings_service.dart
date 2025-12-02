import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trivora_provider/core/config/app_config.dart';

/// Service to manage privacy and security settings
class PrivacySettingsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get privacy settings for a provider
  Future<Map<String, dynamic>> getPrivacySettings(String providerId) async {
    try {
      final doc = await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .get();

      if (doc.exists) {
        final data = doc.data() ?? {};
        final privacySettings = data['privacySettings'] as Map<String, dynamic>? ?? {};

        return {
          'showProfileToPublic': privacySettings['showProfileToPublic'] as bool? ?? true,
          'allowDirectMessages': privacySettings['allowDirectMessages'] as bool? ?? true,
          'shareLocation': privacySettings['shareLocation'] as bool? ?? false,
        };
      }

      // Return defaults if document doesn't exist
      return {
        'showProfileToPublic': true,
        'allowDirectMessages': true,
        'shareLocation': false,
      };
    } catch (e) {
      debugPrint('❌ Error getting privacy settings: $e');
      return {
        'showProfileToPublic': true,
        'allowDirectMessages': true,
        'shareLocation': false,
      };
    }
  }

  /// Update privacy settings
  Future<void> updatePrivacySettings(
    String providerId,
    Map<String, dynamic> settings,
  ) async {
    try {
      await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .update({
        'privacySettings': settings,
        'privacySettingsUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Privacy settings updated');
    } catch (e) {
      debugPrint('❌ Error updating privacy settings: $e');
      throw Exception('Failed to update privacy settings: $e');
    }
  }

  /// Get privacy settings stream for real-time updates
  Stream<Map<String, dynamic>> getPrivacySettingsStream(String providerId) {
    return _firestore
        .collection(AppConfig.providersCollection)
        .doc(providerId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) {
        return {
          'showProfileToPublic': true,
          'allowDirectMessages': true,
          'shareLocation': false,
        };
      }

      final data = doc.data() ?? {};
      final privacySettings = data['privacySettings'] as Map<String, dynamic>? ?? {};

      return {
        'showProfileToPublic': privacySettings['showProfileToPublic'] as bool? ?? true,
        'allowDirectMessages': privacySettings['allowDirectMessages'] as bool? ?? true,
        'shareLocation': privacySettings['shareLocation'] as bool? ?? false,
      };
    });
  }
}

/// Provider for PrivacySettingsService
final privacySettingsServiceProvider = Provider<PrivacySettingsService>((ref) {
  return PrivacySettingsService();
});

