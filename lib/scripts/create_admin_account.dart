// ignore_for_file: avoid_print
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trivora_provider/firebase_options.dart';

/// Script to create admin account
/// Run this once to set up the admin account
Future<void> createAdminAccount() async {
  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized');

    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;

    const adminEmail = 'chouhansandeep14209@gmail.com';
    const adminPassword = '12345678';
    const adminDisplayName = 'Admin Sandeep';

    // Check if admin already exists
    try {
      final existingUser = await auth.signInWithEmailAndPassword(
        email: adminEmail,
        password: adminPassword,
      );

      print('ℹ️ Admin account already exists');
      
      // Update admin document
      await firestore.collection('admins').doc(existingUser.user!.uid).set({
        'email': adminEmail,
        'displayName': adminDisplayName,
        'isActive': true,
        'role': 'admin',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ Admin document updated in Firestore');
      print('Admin UID: ${existingUser.user!.uid}');
      
      await auth.signOut();
      return;
    } catch (e) {
      // User doesn't exist, create new one
      print('Creating new admin account...');
    }

    // Create admin user in Firebase Auth
    final userCredential = await auth.createUserWithEmailAndPassword(
      email: adminEmail,
      password: adminPassword,
    );

    var user = userCredential.user;
    if (user == null) {
      throw Exception('Failed to create user');
    }

    // Update display name
    await user.updateDisplayName(adminDisplayName);
    await user.reload();
    user = auth.currentUser!;

    print('✅ Admin user created in Firebase Auth');
    print('Admin UID: ${user.uid}');

    // Create admin document in Firestore
    await firestore.collection('admins').doc(user.uid).set({
      'email': adminEmail,
      'displayName': adminDisplayName,
      'isActive': true,
      'role': 'admin',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastLoginAt': null,
    });

    print('✅ Admin document created in Firestore');
    print('\n📋 Admin Account Details:');
    print('Email: $adminEmail');
    print('Password: $adminPassword');
    print('Display Name: $adminDisplayName');
    print('UID: ${user.uid}');
    print('\n✅ Admin account created successfully!');
    print('You can now login at /admin/login');

    await auth.signOut();
  } catch (e, stackTrace) {
    print('❌ Error creating admin account: $e');
    print('Stack trace: $stackTrace');
    rethrow;
  }
}

/// Main entry point for running the script directly
Future<void> main() async {
  await createAdminAccount();
}

