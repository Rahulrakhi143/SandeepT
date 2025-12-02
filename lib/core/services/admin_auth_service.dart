import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Admin Authentication Service
class AdminAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Sign in admin with email and password
  Future<User> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        throw Exception('User not found after sign in');
      }

      // Verify admin role
      final adminDoc = await _firestore
          .collection('admins')
          .doc(user.uid)
          .get();

      if (!adminDoc.exists) {
        // Sign out if not an admin
        await _auth.signOut();
        throw Exception('Access denied. Admin account required.');
      }

      final adminData = adminDoc.data();
      if (adminData?['isActive'] != true) {
        await _auth.signOut();
        throw Exception('Admin account is inactive. Please contact support.');
      }

      // Update last login
      await _firestore.collection('admins').doc(user.uid).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ignore: avoid_print
      print('✅ Admin signed in: ${user.email}');
      return user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Failed to sign in: $e');
    }
  }

  /// Sign out admin
  Future<void> signOut() async {
    try {
      // Sign out from Firebase Auth
      await _auth.signOut();
      
      // Clear any admin-specific data if needed
      // ignore: avoid_print
      print('✅ Admin signed out successfully');
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error signing out admin: $e');
      throw Exception('Failed to sign out: $e');
    }
  }

  /// Get current admin user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// Check if current user is admin
  Future<bool> isAdmin() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final adminDoc = await _firestore
          .collection('admins')
          .doc(user.uid)
          .get();

      if (!adminDoc.exists) return false;

      final adminData = adminDoc.data();
      return adminData?['isActive'] == true;
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error checking admin status: $e');
      return false;
    }
  }

  /// Get admin data from Firestore
  Future<Map<String, dynamic>?> getAdminData(String uid) async {
    try {
      final doc = await _firestore.collection('admins').doc(uid).get();
      if (!doc.exists) return null;

      final data = doc.data();
      return {
        'id': doc.id,
        ...?data,
      };
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error fetching admin data: $e');
      return null;
    }
  }

  /// Stream of admin auth state
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No admin account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This admin account has been disabled.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled.';
      default:
        return 'Authentication failed: ${e.message}';
    }
  }
}

/// Provider for AdminAuthService
final adminAuthServiceProvider = Provider<AdminAuthService>((ref) {
  return AdminAuthService();
});

