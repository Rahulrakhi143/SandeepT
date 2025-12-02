import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Provider for current Firebase Auth user
final firebaseAuthStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Provider for current user's Firestore document
final firebaseCurrentUserProvider = StreamProvider<Map<String, dynamic>?>((ref) async* {
  await for (final authUser in FirebaseAuth.instance.authStateChanges()) {
    if (authUser?.uid != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(authUser!.uid)
            .get();
        
        if (userDoc.exists) {
          yield userDoc.data();
        } else {
          yield null;
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
final firebaseIsAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(firebaseAuthStateProvider).valueOrNull != null;
});

/// Provider for checking if user is a provider
final firebaseIsProviderProvider = Provider<bool>((ref) {
  final userData = ref.watch(firebaseCurrentUserProvider).valueOrNull;
  return userData?['role'] == 'provider';
});

