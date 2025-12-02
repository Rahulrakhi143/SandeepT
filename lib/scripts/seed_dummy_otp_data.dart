// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:trivora_provider/core/config/app_config.dart';
import 'package:trivora_provider/firebase_options.dart';
import 'dart:math';
import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Script to seed dummy data with OTP for testing
/// Run this script to populate Firebase with test bookings and OTP data
Future<void> main() async {
  print('🚀 Starting dummy data seeding...');
  
  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized');
    
    final firestore = FirebaseFirestore.instance;
    final random = Random();
    
    // Create dummy provider
    final providerId = 'test_provider_${DateTime.now().millisecondsSinceEpoch}';
    final providerData = {
      'displayName': 'Test Provider',
      'email': 'provider@test.com',
      'phone': '+919876543210',
      'role': 'provider',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    
    await firestore
        .collection(AppConfig.providersCollection)
        .doc(providerId)
        .set(providerData);
    print('✅ Created dummy provider: $providerId');
    
    // Create dummy users
    final userIds = <String>[];
    for (int i = 1; i <= 3; i++) {
      final userId = 'test_user_$i';
      userIds.add(userId);
      
      final userData = {
        'displayName': 'Test User $i',
        'email': 'user$i@test.com',
        'phone': '+91987654321$i',
        'role': 'user',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      await firestore
          .collection('users')
          .doc(userId)
          .set(userData, SetOptions(merge: true));
      print('✅ Created dummy user: $userId');
    }
    
    // Create dummy bookings with different OTP statuses
    final now = DateTime.now();
    
    // Booking 1: Pending OTP (just generated)
    final otp1 = (100000 + random.nextInt(900000)).toString();
    final bytes1 = utf8.encode(otp1);
    final hash1 = sha256.convert(bytes1).toString();
    final expiresAt1 = now.add(const Duration(minutes: 10));
    
    final booking1Id = 'booking_${providerId}_${now.millisecondsSinceEpoch}_1';
    final booking1Data = {
      'providerId': providerId,
      'customerId': userIds[0],
      'customerName': 'Test User 1',
      'customerPhone': '+919876543211',
      'serviceName': 'Plumbing Service',
      'status': 'in_progress',
      'amount': 1500.0,
      'address': '123 Test Street, Test City',
      'paymentMethod': 'cod',
      'paymentStatus': 'unpaid',
      'scheduledDate': Timestamp.fromDate(now.add(const Duration(hours: 2))),
      'otp': {
        'codeHash': hash1,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt1),
        'verified': false,
        'resendCount': 0,
        'failedAttempts': 0,
      },
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    
    await firestore
        .collection(AppConfig.providersCollection)
        .doc(providerId)
        .collection('bookings')
        .doc(booking1Id)
        .set(booking1Data);
    print('✅ Created booking 1 with OTP: $booking1Id');
    print('   OTP: $otp1 (expires at ${expiresAt1.toString()})');
    
    // Booking 2: Expired OTP
    final otp2 = (100000 + random.nextInt(900000)).toString();
    final bytes2 = utf8.encode(otp2);
    final hash2 = sha256.convert(bytes2).toString();
    final expiredAt = now.subtract(const Duration(minutes: 5)); // Already expired
    
    final booking2Id = 'booking_${providerId}_${now.millisecondsSinceEpoch}_2';
    final booking2Data = {
      'providerId': providerId,
      'customerId': userIds[1],
      'customerName': 'Test User 2',
      'customerPhone': '+919876543212',
      'serviceName': 'Electrical Service',
      'status': 'in_progress',
      'amount': 2000.0,
      'address': '456 Test Avenue, Test City',
      'paymentMethod': 'cod',
      'paymentStatus': 'unpaid',
      'scheduledDate': Timestamp.fromDate(now.add(const Duration(hours: 3))),
      'otp': {
        'codeHash': hash2,
        'createdAt': Timestamp.fromDate(now.subtract(const Duration(minutes: 15))),
        'expiresAt': Timestamp.fromDate(expiredAt),
        'verified': false,
        'resendCount': 1,
        'failedAttempts': 0,
      },
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    
    await firestore
        .collection(AppConfig.providersCollection)
        .doc(providerId)
        .collection('bookings')
        .doc(booking2Id)
        .set(booking2Data);
    print('✅ Created booking 2 with expired OTP: $booking2Id');
    print('   OTP: $otp2 (expired)');
    
    // Booking 3: Verified OTP (completed)
    final otp3 = (100000 + random.nextInt(900000)).toString();
    final bytes3 = utf8.encode(otp3);
    final hash3 = sha256.convert(bytes3).toString();
    
    final booking3Id = 'booking_${providerId}_${now.millisecondsSinceEpoch}_3';
    final booking3Data = {
      'providerId': providerId,
      'customerId': userIds[2],
      'customerName': 'Test User 3',
      'customerPhone': '+919876543213',
      'serviceName': 'Cleaning Service',
      'status': 'completed',
      'amount': 1200.0,
      'address': '789 Test Road, Test City',
      'paymentMethod': 'cod',
      'paymentStatus': 'paid',
      'scheduledDate': Timestamp.fromDate(now.subtract(const Duration(hours: 1))),
      'otp': {
        'codeHash': hash3,
        'createdAt': Timestamp.fromDate(now.subtract(const Duration(hours: 1, minutes: 5))),
        'expiresAt': Timestamp.fromDate(now.subtract(const Duration(minutes: 55))),
        'verified': true,
        'verifiedAt': Timestamp.fromDate(now.subtract(const Duration(hours: 1))),
        'resendCount': 0,
        'failedAttempts': 0,
      },
      'completedAt': Timestamp.fromDate(now.subtract(const Duration(hours: 1))),
      'paidAt': Timestamp.fromDate(now.subtract(const Duration(hours: 1))),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    
    await firestore
        .collection(AppConfig.providersCollection)
        .doc(providerId)
        .collection('bookings')
        .doc(booking3Id)
        .set(booking3Data);
    print('✅ Created booking 3 with verified OTP: $booking3Id');
    print('   OTP: $otp3 (verified)');
    
    // Booking 4: Accepted (no OTP yet)
    final booking4Id = 'booking_${providerId}_${now.millisecondsSinceEpoch}_4';
    final booking4Data = {
      'providerId': providerId,
      'customerId': userIds[0],
      'customerName': 'Test User 1',
      'customerPhone': '+919876543211',
      'serviceName': 'Carpentry Service',
      'status': 'accepted',
      'amount': 1800.0,
      'address': '321 Test Lane, Test City',
      'paymentMethod': 'cod',
      'paymentStatus': 'unpaid',
      'scheduledDate': Timestamp.fromDate(now.add(const Duration(hours: 4))),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    
    await firestore
        .collection(AppConfig.providersCollection)
        .doc(providerId)
        .collection('bookings')
        .doc(booking4Id)
        .set(booking4Data);
    print('✅ Created booking 4 (accepted, no OTP): $booking4Id');
    
    // Create notifications for users
    for (int i = 0; i < userIds.length; i++) {
      await firestore.collection(AppConfig.notificationsCollection).add({
        'userId': userIds[i],
        'title': 'OTP for Service Completion',
        'body': 'Your OTP for service completion is: ${i == 0 ? otp1 : (i == 1 ? otp2 : otp3)}. Valid for 10 minutes.',
        'type': 'cod_otp_generated',
        'data': {
          'bookingId': i == 0 ? booking1Id : (i == 1 ? booking2Id : booking3Id),
          'otp': i == 0 ? otp1 : (i == 1 ? otp2 : otp3),
        },
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('✅ Created notification for user: ${userIds[i]}');
    }
    
    print('\n📋 Summary:');
    print('Provider ID: $providerId');
    print('User IDs: ${userIds.join(", ")}');
    print('Booking 1 (Pending OTP): $booking1Id - OTP: $otp1');
    print('Booking 2 (Expired OTP): $booking2Id - OTP: $otp2');
    print('Booking 3 (Verified OTP): $booking3Id - OTP: $otp3');
    print('Booking 4 (Accepted): $booking4Id');
    print('\n✅ Dummy data seeding completed successfully!');
    print('\n💡 Note: Use these OTPs for testing:');
    print('   Booking 1 OTP: $otp1');
    print('   Booking 2 OTP: $otp2 (expired)');
    print('   Booking 3 OTP: $otp3 (already verified)');
    
  } catch (e, stackTrace) {
    print('❌ Error seeding dummy data: $e');
    print('Stack trace: $stackTrace');
  }
}

