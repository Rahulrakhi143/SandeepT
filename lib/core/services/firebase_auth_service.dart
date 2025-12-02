import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trivora_provider/core/config/app_config.dart';

/// Firebase Authentication Service
class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Get auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with email and password
  Future<User> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (credential.user == null) {
        throw Exception('Sign in failed - no user returned');
      }

      await _ensureUserDocument(credential.user!);
      return credential.user!;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Sign in failed: $e');
    }
  }

  /// Sign up with email and password
  Future<User> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
    String? phone,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (credential.user == null) {
        throw Exception('Sign up failed - no user returned');
      }

      // Update display name
      await credential.user!.updateDisplayName(displayName);
      await credential.user!.reload();

      // Create provider document in providers collection
      await _firestore
          .collection(AppConfig.providersCollection)
          .doc(credential.user!.uid)
          .set({
        'userId': credential.user!.uid,
        'email': email.trim(),
        if (phone != null) 'phone': phone,
        'displayName': displayName,
        'role': AppConfig.roleProvider,
        'isOnline': false,
        'isVerified': false,
        'rating': 0.0,
        'totalBookings': 0,
        'completedBookings': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isEmailVerified': credential.user!.emailVerified,
        'isPhoneVerified': phone != null,
      });

      return credential.user!;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Sign up failed: $e');
    }
  }

  /// Send OTP to phone number
  Future<String> sendOTP({required String phoneNumber}) async {
    try {
      String formattedPhone = phoneNumber;
      if (!phoneNumber.startsWith('+')) {
        formattedPhone = '+91$phoneNumber'; // Default to India
      }

      String? verificationId;
      
      await _auth.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        verificationCompleted: (PhoneAuthCredential credential) {
          // Auto-verification completed
        },
        verificationFailed: (FirebaseAuthException e) {
          throw _handleAuthException(e);
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

      return verificationId!;
    } catch (e) {
      throw Exception('Failed to send OTP: $e');
    }
  }

  /// Verify OTP
  Future<User> verifyOTP({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user == null) {
        throw Exception('OTP verification failed - no user returned');
      }

      await _ensureUserDocument(userCredential.user!);
      return userCredential.user!;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('OTP verification failed: $e');
    }
  }

  /// Sign in with Google
  Future<User> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception('Google sign in was cancelled');
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user == null) {
        throw Exception('Google sign in failed - no user returned');
      }

      await _ensureUserDocument(userCredential.user!);
      return userCredential.user!;
    } catch (e) {
      throw Exception('Google sign in failed: $e');
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      // Sign out from Google Sign In (if signed in with Google)
      // Only attempt if Google Sign In is available and initialized
      try {
        // Check if user is signed in with Google before attempting sign out
        final googleUser = await _googleSignIn.signInSilently();
        if (googleUser != null) {
          await _googleSignIn.signOut();
        }
      } catch (e) {
        // Ignore Google Sign In errors (user might not have signed in with Google)
        // This is expected if Google Sign In is not configured or user didn't use Google sign in
        // ignore: avoid_print
        print('⚠️ Google Sign In sign out skipped (this is normal if not using Google sign in): $e');
      }
      
      // Sign out from Firebase Auth (this is the main sign out)
      await _auth.signOut();
      
      // ignore: avoid_print
      print('✅ Successfully signed out from Firebase');
    } catch (e) {
      // If Firebase sign out fails, still try to clear Google Sign In
      try {
        await _googleSignIn.signOut();
      } catch (_) {
        // Ignore Google Sign In errors
      }
      throw Exception('Sign out failed: $e');
    }
  }

  /// Update user display name
  Future<void> updateDisplayName(String displayName) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      // Ensure document exists
      await verifyProviderDocument(user.uid);

      await user.updateDisplayName(displayName);
      await user.reload();

      // Update provider document
      await _updateProviderDocument(user.uid, {
        'displayName': displayName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // ignore: avoid_print
      print('✅ Display name updated in Firestore: $displayName');
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error updating display name: $e');
      throw Exception('Failed to update display name: $e');
    }
  }

  /// Update user photo URL
  Future<void> updatePhotoURL(String photoURL) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      // Ensure document exists
      await verifyProviderDocument(user.uid);

      await user.updatePhotoURL(photoURL);
      await user.reload();

      // Update provider document
      await _updateProviderDocument(user.uid, {
        'photoUrl': photoURL,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // ignore: avoid_print
      print('✅ Photo URL updated in Firestore: $photoURL');
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error updating photo URL: $e');
      throw Exception('Failed to update photo: $e');
    }
  }

  /// Update user profile (name and/or photo)
  Future<void> updateProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      if (displayName != null) {
        await user.updateDisplayName(displayName);
      }
      if (photoURL != null) {
        await user.updatePhotoURL(photoURL);
      }
      await user.reload();

      // Update provider document
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (displayName != null) {
        updateData['displayName'] = displayName;
      }
      if (photoURL != null) {
        updateData['photoUrl'] = photoURL;
      }

      await _updateProviderDocument(user.uid, updateData);
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  /// Update user phone number in Firestore
  /// Note: To update phone in Firebase Auth, use phone verification
  Future<void> updatePhoneNumber(String phoneNumber) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      // Ensure document exists
      await verifyProviderDocument(user.uid);

      // Update provider document
      await _updateProviderDocument(user.uid, {
        'phone': phoneNumber,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // ignore: avoid_print
      print('✅ Phone number updated in Firestore: $phoneNumber');
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error updating phone number: $e');
      throw Exception('Failed to update phone number: $e');
    }
  }

  /// Update user email
  /// Note: Email update sends verification email to new address
  Future<void> updateEmail(String newEmail) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      // Ensure document exists
      await verifyProviderDocument(user.uid);

      // Send verification email to new address (recommended method)
      await user.verifyBeforeUpdateEmail(newEmail.trim());

      // Update provider document immediately (user will verify via email)
      await _updateProviderDocument(user.uid, {
        'email': newEmail.trim(),
        'emailPendingVerification': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // ignore: avoid_print
      print('✅ Email updated in Firestore: $newEmail');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw Exception('Please logout and login again to update email');
      }
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Failed to update email: $e');
    }
  }

  /// Update about/bio for provider
  Future<void> updateAbout(String about) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      // Ensure document exists
      await verifyProviderDocument(user.uid);

      // Update provider document
      await _updateProviderDocument(user.uid, {
        'about': about,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // ignore: avoid_print
      print('✅ About updated in Firestore: $about');
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error updating about: $e');
      throw Exception('Failed to update about: $e');
    }
  }

  /// Update account information (phone, email, about)
  Future<void> updateAccountInfo({
    String? phone,
    String? email,
    String? about,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (phone != null) {
        updateData['phone'] = phone;
      }

      if (email != null) {
        // Send verification email to new address (recommended method)
        await user.verifyBeforeUpdateEmail(email.trim());
        updateData['email'] = email.trim();
        updateData['emailPendingVerification'] = true;
      }

      if (about != null) {
        updateData['about'] = about;
      }

      // Reload user if email was updated
      if (email != null) {
        await user.reload();
      }

      // Update provider document
      await _updateProviderDocument(user.uid, updateData);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw Exception('Please logout and login again to update email');
      }
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Failed to update account info: $e');
    }
  }

  /// Ensure provider document exists in Firestore
  Future<void> _ensureUserDocument(User firebaseUser) async {
    try {
      // Check if provider document exists
      final providerDoc = await _firestore
          .collection(AppConfig.providersCollection)
          .doc(firebaseUser.uid)
          .get();

      if (!providerDoc.exists) {
        // Create new provider document (this app is for providers only)
        await _firestore
            .collection(AppConfig.providersCollection)
            .doc(firebaseUser.uid)
            .set({
          'userId': firebaseUser.uid,
          'email': firebaseUser.email ?? '',
          if (firebaseUser.phoneNumber != null) 'phone': firebaseUser.phoneNumber,
          'displayName': firebaseUser.displayName ?? 'Provider',
          'role': AppConfig.roleProvider,
          'isOnline': false,
          'isVerified': false,
          'rating': 0.0,
          'totalBookings': 0,
          'completedBookings': 0,
          if (firebaseUser.photoURL != null) 'photoUrl': firebaseUser.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'isEmailVerified': firebaseUser.emailVerified,
          'isPhoneVerified': firebaseUser.phoneNumber != null,
        });
      }
    } catch (e) {
      // Log error but don't throw - user is still authenticated
      // ignore: avoid_print
      print('Warning: Failed to ensure provider document: $e');
    }
  }

  /// Update provider document in Firestore
  Future<void> _updateProviderDocument(String userId, Map<String, dynamic> data) async {
    try {
      // First, ensure the document exists
      final docRef = _firestore.collection(AppConfig.providersCollection).doc(userId);
      final doc = await docRef.get();
      
      if (!doc.exists) {
        // Document doesn't exist, create it with current user data
        final user = _auth.currentUser;
        if (user == null) {
          throw Exception('No user logged in');
        }
        
        await docRef.set({
          'userId': userId,
          'email': user.email ?? '',
          if (user.phoneNumber != null) 'phone': user.phoneNumber,
          'displayName': user.displayName ?? 'Provider',
          'role': AppConfig.roleProvider,
          'isOnline': false,
          'isVerified': false,
          'rating': 0.0,
          'totalBookings': 0,
          'completedBookings': 0,
          if (user.photoURL != null) 'photoUrl': user.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'isEmailVerified': user.emailVerified,
          'isPhoneVerified': user.phoneNumber != null,
          ...data, // Merge with update data
        }, SetOptions(merge: true));
      } else {
        // Document exists, update it
        await docRef.update(data);
      }
      
      // Verify the update was successful
      final updatedDoc = await docRef.get();
      if (!updatedDoc.exists) {
        throw Exception('Failed to verify document update');
      }
      
      // ignore: avoid_print
      print('✅ Provider document updated successfully in Firestore');
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error updating provider document: $e');
      throw Exception('Failed to update provider document: $e');
    }
  }

  /// Get provider document from Firestore
  Future<Map<String, dynamic>?> getProviderDocument(String userId) async {
    try {
      final doc = await _firestore
          .collection(AppConfig.providersCollection)
          .doc(userId)
          .get();
      
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      // ignore: avoid_print
      print('Error getting provider document: $e');
      return null;
    }
  }

  /// Verify provider document exists and has required fields
  Future<bool> verifyProviderDocument(String userId) async {
    try {
      final doc = await _firestore
          .collection(AppConfig.providersCollection)
          .doc(userId)
          .get();
      
      if (!doc.exists) {
        // Create document if it doesn't exist
        final user = _auth.currentUser;
        if (user != null) {
          await _ensureUserDocument(user);
          return true;
        }
        return false;
      }
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('Error verifying provider document: $e');
      return false;
    }
  }

  /// Change user password
  /// Requires current password for reauthentication
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      if (user.email == null || user.email!.isEmpty) {
        throw Exception('Email is required to change password');
      }

      // Reauthenticate user with current password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(newPassword);

      // Update Firestore
      await _firestore
          .collection(AppConfig.providersCollection)
          .doc(user.uid)
          .update({
        'passwordChangedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ignore: avoid_print
      print('✅ Password changed successfully');
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Failed to change password: $e');
    }
  }

  /// Handle Firebase Auth exceptions
  Exception _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return Exception('No account found with this email');
      case 'wrong-password':
        return Exception('Incorrect password');
      case 'email-already-in-use':
        return Exception('An account already exists with this email');
      case 'weak-password':
        return Exception('Password is too weak. Please choose a stronger password');
      case 'invalid-email':
        return Exception('Invalid email address');
      case 'invalid-verification-code':
        return Exception('Invalid OTP code');
      case 'invalid-verification-id':
        return Exception('Invalid verification ID');
      case 'too-many-requests':
        return Exception('Too many requests. Please try again later');
      case 'requires-recent-login':
        return Exception('Please login again to change your password');
      default:
        return Exception(e.message ?? 'Authentication failed');
    }
  }
}

/// Provider for FirebaseAuthService
final firebaseAuthServiceProvider = Provider<FirebaseAuthService>((ref) {
  return FirebaseAuthService();
});

