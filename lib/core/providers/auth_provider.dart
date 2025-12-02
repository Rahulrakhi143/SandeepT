import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trivora_provider/core/config/app_config.dart';

/// Provider for current Firebase Auth user
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Provider for current provider's Firestore document
/// This app is for providers only, so we check the providers collection
final currentUserProvider = StreamProvider<Map<String, dynamic>?>((ref) async* {
  await for (final authUser in FirebaseAuth.instance.authStateChanges()) {
    if (authUser?.uid != null) {
      try {
        // Check providers collection (this app is provider-only)
        final providerDoc = await FirebaseFirestore.instance
            .collection(AppConfig.providersCollection)
            .doc(authUser!.uid)
            .get();
        
        if (providerDoc.exists) {
          yield providerDoc.data();
        } else {
          // If not found in providers, check users collection (for migration)
          final userDoc = await FirebaseFirestore.instance
              .collection(AppConfig.usersCollection)
              .doc(authUser.uid)
              .get();
          
          if (userDoc.exists && userDoc.data()?['role'] == AppConfig.roleProvider) {
            // Migrate to providers collection
            await FirebaseFirestore.instance
                .collection(AppConfig.providersCollection)
                .doc(authUser.uid)
                .set({
              'userId': authUser.uid,
              ...userDoc.data()!,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          yield userDoc.data();
        } else {
          yield null;
          }
        }
      } catch (e) {
        yield null;
      }
    } else {
      yield null;
    }
  }
});

/// Provider for checking if user is authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).valueOrNull != null;
});

/// Provider for checking if user is a provider
/// This app is provider-only, so authenticated users are providers
final isProviderProvider = Provider<bool>((ref) {
  final userData = ref.watch(currentUserProvider).valueOrNull;
  final authUser = ref.watch(authStateProvider).valueOrNull;
  // If user is authenticated and has provider document, they are a provider
  return authUser != null && (userData?['role'] == AppConfig.roleProvider || userData != null);
});
