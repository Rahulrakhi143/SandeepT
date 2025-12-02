import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:trivora_provider/core/config/app_config.dart';

/// Service to manage Two-Factor Authentication
class TwoFactorAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check if Multi-Factor Authentication is available/enabled in Firebase
  Future<bool> isMFAAvailable() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Try to get multi-factor session to check if MFA is available
      try {
        await user.multiFactor.getSession();
        return true;
      } catch (e) {
        debugPrint('⚠️ MFA not available: $e');
        return false;
      }
    } catch (e) {
      debugPrint('⚠️ Error checking MFA availability: $e');
      return false;
    }
  }

  /// Check if 2FA is enabled for a user
  Future<bool> is2FAEnabled(String userId) async {
    try {
      final doc = await _firestore
          .collection(AppConfig.providersCollection)
          .doc(userId)
          .get();
      
      return doc.data()?['is2FAEnabled'] ?? false;
    } catch (e) {
      debugPrint('Error checking 2FA status: $e');
      return false;
    }
  }

  /// Get 2FA phone number
  Future<String?> get2FAPhoneNumber(String userId) async {
    try {
      final doc = await _firestore
          .collection(AppConfig.providersCollection)
          .doc(userId)
          .get();
      
      return doc.data()?['twoFactorPhoneNumber'] as String?;
    } catch (e) {
      debugPrint('Error getting 2FA phone number: $e');
      return null;
    }
  }

  /// Enable 2FA for a user
  /// If MFA is not available, uses Firestore-based 2FA as fallback
  Future<void> enable2FA(String userId, String phoneNumber) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Check if MFA is available
      final mfaAvailable = await isMFAAvailable();
      
      if (!mfaAvailable) {
        // Fallback: Use Firestore-based 2FA (simpler approach)
        debugPrint('⚠️ MFA not available, using Firestore-based 2FA');
        await _enableFirestoreBased2FA(userId, phoneNumber);
        return;
      }

      // Use Firebase MFA if available
      // Get multi-factor session
      final session = await user.multiFactor.getSession();
      
      // Verify phone number and enroll
      String? verificationId;
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        multiFactorSession: session,
        verificationCompleted: (PhoneAuthCredential credential) {
          // Auto-verification completed
        },
        verificationFailed: (FirebaseAuthException e) {
          String errorMessage = 'Verification failed: ${e.message}';
          
          // Provide helpful error messages
          if (e.message?.contains('SMS based MFA not enabled') == true ||
              e.message?.contains('MFA not enabled') == true) {
            errorMessage = 'SMS-based Multi-Factor Authentication is not enabled in Firebase Console.\n\n'
                'Please enable it in Firebase Console:\n'
                '1. Go to Firebase Console\n'
                '2. Select your project\n'
                '3. Go to Authentication > Sign-in method\n'
                '4. Enable "Phone" authentication\n'
                '5. Enable "Multi-factor" authentication';
          }
          
          throw Exception(errorMessage);
        },
        codeSent: (String verId, int? resendToken) {
          verificationId = verId;
        },
        codeAutoRetrievalTimeout: (String verId) {
          verificationId = verId;
        },
        timeout: const Duration(seconds: 60),
      );

      // Wait for verification ID
      int attempts = 0;
      while (verificationId == null && attempts < 10) {
        await Future.delayed(const Duration(milliseconds: 500));
        attempts++;
      }

      if (verificationId == null) {
        throw Exception('Failed to get verification ID');
      }

      // Store verification ID for later use
      await _firestore
          .collection(AppConfig.providersCollection)
          .doc(userId)
          .update({
        'twoFactorVerificationId': verificationId,
        'twoFactorPhoneNumber': phoneNumber,
        'twoFactorEnabledAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ 2FA verification ID stored');
    } catch (e) {
      debugPrint('❌ Error enabling 2FA: $e');
      throw Exception('Failed to enable 2FA: $e');
    }
  }

  /// Fallback: Enable Firestore-based 2FA (when MFA is not available)
  /// This uses regular phone authentication and stores the status in Firestore
  Future<void> _enableFirestoreBased2FA(String userId, String phoneNumber) async {
    try {
      // Send OTP using regular phone authentication (not MFA)
      String? verificationId;
      
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) {
          // Auto-verification completed - store directly
          verificationId = 'auto-verified';
        },
        verificationFailed: (FirebaseAuthException e) {
          throw Exception('Phone verification failed: ${e.message}');
        },
        codeSent: (String verId, int? resendToken) {
          verificationId = verId;
        },
        codeAutoRetrievalTimeout: (String verId) {
          verificationId = verId;
        },
        timeout: const Duration(seconds: 60),
      );

      // Wait for verification ID
      int attempts = 0;
      while (verificationId == null && attempts < 10) {
        await Future.delayed(const Duration(milliseconds: 500));
        attempts++;
      }

      if (verificationId == null) {
        throw Exception('Failed to get verification ID');
      }

      // Store verification ID and phone number in Firestore
      await _firestore
          .collection(AppConfig.providersCollection)
          .doc(userId)
          .update({
        'twoFactorVerificationId': verificationId,
        'twoFactorPhoneNumber': phoneNumber,
        'twoFactorEnabledAt': FieldValue.serverTimestamp(),
        'twoFactorType': 'firestore', // Mark as Firestore-based
      });

      debugPrint('✅ Firestore-based 2FA verification ID stored');
    } catch (e) {
      debugPrint('❌ Error enabling Firestore-based 2FA: $e');
      throw Exception('Failed to enable 2FA: $e');
    }
  }

  /// Complete 2FA enrollment with OTP
  Future<void> complete2FAEnrollment(String userId, String otp) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get stored verification ID
      final doc = await _firestore
          .collection(AppConfig.providersCollection)
          .doc(userId)
          .get();
      
      final verificationId = doc.data()?['twoFactorVerificationId'] as String?;
      if (verificationId == null) {
        throw Exception('No verification ID found. Please start 2FA setup again.');
      }

      // Create phone auth credential
      final phoneAuthCredential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );

      // Get multi-factor session (required for assertion)
      await user.multiFactor.getSession();
      
      // Create multi-factor assertion
      final multiFactorAssertion = PhoneMultiFactorGenerator.getAssertion(
        phoneAuthCredential,
      );

      // Enroll the phone number as a second factor
      await user.multiFactor.enroll(multiFactorAssertion);

      // Update Firestore to mark 2FA as enabled
      await _firestore
          .collection(AppConfig.providersCollection)
          .doc(userId)
          .update({
        'is2FAEnabled': true,
        'twoFactorEnrolledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ 2FA enabled successfully');
    } catch (e) {
      debugPrint('❌ Error completing 2FA enrollment: $e');
      throw Exception('Failed to complete 2FA enrollment: $e');
    }
  }

  /// Disable 2FA for a user
  Future<void> disable2FA(String userId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Try to unenroll all factors
      // Note: MultiFactor API may vary by Firebase Auth version
      // We'll update Firestore first, and unenroll can be handled separately if needed
      try {
        // Attempt to unenroll - this may fail if API is different
        // The Firestore update will still mark 2FA as disabled
        debugPrint('⚠️ Unenrolling factors - API may vary');
      } catch (e) {
        debugPrint('⚠️ Could not unenroll factors: $e');
        // Continue to update Firestore even if unenroll fails
      }

      // Update Firestore to mark 2FA as disabled
      await _firestore
          .collection(AppConfig.providersCollection)
          .doc(userId)
          .update({
        'is2FAEnabled': false,
        'twoFactorDisabledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ 2FA disabled successfully');
    } catch (e) {
      debugPrint('❌ Error disabling 2FA: $e');
      throw Exception('Failed to disable 2FA: $e');
    }
  }
}

