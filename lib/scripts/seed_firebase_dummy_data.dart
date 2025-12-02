// ignore_for_file: avoid_print

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:trivora_provider/core/config/app_config.dart';
import 'package:trivora_provider/firebase_options.dart';

/// Comprehensive script to seed Firebase with dummy data for the Trivora Provider App
/// This includes providers, users, services, bookings, payments, wallets, and notifications
Future<void> seedFirebaseDummyData() async {
  print('🚀 Starting comprehensive Firebase dummy data seeding...');
  
  try {
    // Initialize Firebase (only if not already initialized)
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print('✅ Firebase initialized');
    } else {
      print('✅ Firebase already initialized');
    }
    
    final firestore = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;
    final random = Random();
    
    // Admin names and credentials
    final adminData = [
      {'name': 'Admin Sandeep', 'email': 'chouhansandeep14209@gmail.com', 'password': '12345678'},
      {'name': 'Admin Manager', 'email': 'admin@trivora.com', 'password': 'admin123'},
      {'name': 'Super Admin', 'email': 'superadmin@trivora.com', 'password': 'super123'},
    ];
    
    // ========== CREATE ADMINS ==========
    print('\n👑 Creating admin accounts...');
    final adminIds = <String>[];
    int adminCount = 0;
    
    for (int i = 0; i < adminData.length; i++) {
      final adminInfo = adminData[i];
      final adminEmail = adminInfo['email']!;
      final adminPassword = adminInfo['password']!;
      final adminDisplayName = adminInfo['name']!;
      
      try {
        // Check if admin already exists in Firestore
        final existingAdmins = await firestore
            .collection(AppConfig.adminsCollection)
            .where('email', isEqualTo: adminEmail)
            .limit(1)
            .get();
        
        String adminUid;
        
        if (existingAdmins.docs.isNotEmpty) {
          // Admin document exists, use existing UID
          adminUid = existingAdmins.docs.first.id;
          print('  ℹ️  Admin already exists: $adminDisplayName ($adminEmail)');
        } else {
          // Try to sign in with existing Firebase Auth account
          try {
            final userCredential = await auth.signInWithEmailAndPassword(
              email: adminEmail,
              password: adminPassword,
            );
            adminUid = userCredential.user!.uid;
            await auth.signOut(); // Sign out after getting UID
            print('  ℹ️  Found existing Firebase Auth account for $adminEmail');
          } catch (e) {
            // User doesn't exist in Firebase Auth, create new one
            print('  ℹ️  Creating new Firebase Auth account for $adminEmail');
            final userCredential = await auth.createUserWithEmailAndPassword(
              email: adminEmail,
              password: adminPassword,
            );
            adminUid = userCredential.user!.uid;
            
            // Update display name
            await userCredential.user!.updateDisplayName(adminDisplayName);
            await userCredential.user!.reload();
            await auth.signOut(); // Sign out after creation
            print('  ✅ Created Firebase Auth account for $adminEmail');
          }
        }
        
        // Create or update admin document in Firestore
        final adminDocData = {
          'email': adminEmail,
          'displayName': adminDisplayName,
          'role': AppConfig.roleAdmin,
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'lastLoginAt': null,
        };
        
        await firestore
            .collection(AppConfig.adminsCollection)
            .doc(adminUid)
            .set(adminDocData, SetOptions(merge: true));
        
        adminIds.add(adminUid);
        adminCount++;
        print('✅ Created/Updated admin: $adminDisplayName ($adminEmail)');
      } catch (e) {
        print('  ⚠️  Failed to create admin $adminDisplayName: $e');
        // Continue with other admins
      }
    }
    
    print('✅ Created/Updated $adminCount admin accounts');
    
    // ========== CREATE PROVIDERS ==========
    print('\n📦 Creating providers...');
    final providerIds = <String>[];
    
    // Specific provider data as provided
    final providersData = [
      {
        'id': 'prov01',
        'email': 'electrician1@trivora.com',
        'phone': '+919876543211',
        'displayName': 'Rohit Electrician',
        'photoUrl': '',
        'about': 'Expert electrician with 5+ years experience',
        'isActive': true,
        'isOnline': true,
        'isVerified': true,
        'rating': 4.6,
        'totalBookings': 180,
        'completedBookings': 160,
      },
      {
        'id': 'prov02',
        'email': 'plumber1@trivora.com',
        'phone': '+919876543212',
        'displayName': 'Amit Plumber',
        'photoUrl': '',
        'about': 'Professional plumber',
        'isActive': true,
        'isOnline': false,
        'isVerified': true,
        'rating': 4.2,
        'totalBookings': 100,
        'completedBookings': 95,
      },
      {
        'id': 'prov03',
        'email': 'cleaner1@trivora.com',
        'phone': '+919876543213',
        'displayName': 'Kavita Cleaner',
        'photoUrl': '',
        'about': 'Expert cleaning services',
        'isActive': true,
        'isOnline': false,
        'isVerified': true,
        'rating': 4.7,
        'totalBookings': 210,
        'completedBookings': 200,
      },
      {
        'id': 'prov04',
        'email': 'acservice@trivora.com',
        'phone': '+919876543214',
        'displayName': 'Rahul AC Specialist',
        'photoUrl': '',
        'about': 'AC repair and service specialist',
        'isActive': true,
        'isOnline': true,
        'isVerified': true,
        'rating': 4.9,
        'totalBookings': 350,
        'completedBookings': 340,
      },
      {
        'id': 'prov05',
        'email': 'carpenter1@trivora.com',
        'phone': '+919876543215',
        'displayName': 'Manoj Carpenter',
        'photoUrl': '',
        'about': 'Professional carpenter',
        'isActive': true,
        'isOnline': false,
        'isVerified': false,
        'rating': 4.0,
        'totalBookings': 70,
        'completedBookings': 60,
      },
      {
        'id': 'prov06',
        'email': 'beauty1@trivora.com',
        'phone': '+919876543216',
        'displayName': 'Neha Beautician',
        'photoUrl': '',
        'about': 'Beauty and salon services',
        'isActive': true,
        'isOnline': true,
        'isVerified': true,
        'rating': 4.8,
        'totalBookings': 240,
        'completedBookings': 230,
      },
      {
        'id': 'prov07',
        'email': 'inactive1@trivora.com',
        'phone': '+919876543217',
        'displayName': 'Inactive Provider',
        'photoUrl': '',
        'about': 'Inactive provider account',
        'isActive': false,
        'isOnline': false,
        'isVerified': false,
        'rating': 0.0,
        'totalBookings': 0,
        'completedBookings': 0,
      },
      {
        'id': 'prov08',
        'email': 'inactive2@trivora.com',
        'phone': '+919876543218',
        'displayName': 'Suspended Provider',
        'photoUrl': '',
        'about': 'Suspended provider account',
        'isActive': false,
        'isOnline': false,
        'isVerified': false,
        'rating': 0.0,
        'totalBookings': 0,
        'completedBookings': 0,
      },
    ];
    
    for (final providerData in providersData) {
      final providerId = providerData['id'] as String;
      providerIds.add(providerId);
      
      final createdAt = DateTime.fromMillisecondsSinceEpoch(1734938400000);
      final updatedAt = DateTime.fromMillisecondsSinceEpoch(1734938400000);
      
      final providerDocData = {
        'userId': providerId,
        'email': providerData['email'],
        'phone': providerData['phone'],
        'displayName': providerData['displayName'],
        'photoUrl': providerData['photoUrl'],
        'role': AppConfig.roleProvider,
        'about': providerData['about'],
        'isActive': providerData['isActive'],
        'isOnline': providerData['isOnline'],
        'isVerified': providerData['isVerified'],
        'rating': (providerData['rating'] as num).toDouble(),
        'totalBookings': providerData['totalBookings'],
        'completedBookings': providerData['completedBookings'],
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };
      
      await firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .set(providerDocData, SetOptions(merge: true));
      
      final isActive = providerData['isActive'] as bool? ?? false;
      print('✅ Created provider: ${providerData['displayName']} (${isActive ? "Active" : "Inactive"})');
    }
    
    // ========== CREATE SERVICES FOR PROVIDERS ==========
    print('\n🔧 Creating services...');
    int serviceCount = 0;
    
    // Services for prov01 (Rohit Electrician)
    final prov01Services = [
      {
        'id': 'serv01',
        'providerId': 'prov01',
        'serviceName': 'Fan Repair',
        'description': 'Fixing ceiling fans and table fans',
        'basePrice': 199.0,
        'platformFee': 19.9,
        'platformFeePercentage': 10.0,
        'duration': 40,
        'category': 'Electrical',
        'isActive': true,
      },
      {
        'id': 'serv02',
        'providerId': 'prov01',
        'serviceName': 'Switchboard Repair',
        'description': 'Repair and installation of switchboards',
        'basePrice': 149.0,
        'platformFee': 14.9,
        'platformFeePercentage': 10.0,
        'duration': 30,
        'category': 'Electrical',
        'isActive': true,
      },
    ];
    
    for (final serviceData in prov01Services) {
      final serviceId = serviceData['id'] as String;
      final createdAt = DateTime.fromMillisecondsSinceEpoch(1734938400000);
      
      await firestore
          .collection(AppConfig.providersCollection)
          .doc(serviceData['providerId'] as String)
          .collection('services')
          .doc(serviceId)
          .set({
        'id': serviceId,
        'providerId': serviceData['providerId'],
        'serviceName': serviceData['serviceName'],
        'description': serviceData['description'],
        'basePrice': serviceData['basePrice'],
        'duration': serviceData['duration'],
        'category': serviceData['category'],
        'isActive': serviceData['isActive'],
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(createdAt),
      });
      serviceCount++;
    }
    
    // Add more services for other providers (sample)
    const serviceCategories = ['Plumbing', 'Cleaning', 'AC Repair', 'Carpentry', 'Beauty'];
    const serviceNames = {
      'Plumbing': ['Pipe Repair', 'Leak Fixing', 'Drain Cleaning'],
      'Cleaning': ['House Cleaning', 'Office Cleaning', 'Deep Cleaning'],
      'AC Repair': ['AC Service', 'AC Installation', 'Gas Filling'],
      'Carpentry': ['Furniture Repair', 'Door Installation', 'Cabinet Making'],
      'Beauty': ['Haircut', 'Facial', 'Manicure'],
    };
    
    for (int i = 1; i < providerIds.length; i++) {
      final providerId = providerIds[i];
      final category = serviceCategories[i % serviceCategories.length];
      final names = serviceNames[category] ?? ['Service'];
      
      for (int j = 0; j < 2; j++) {
        final serviceId = 'serv_${providerId}_$j';
        final createdAt = DateTime.fromMillisecondsSinceEpoch(1734938400000);
        
        await firestore
            .collection(AppConfig.providersCollection)
            .doc(providerId)
            .collection('services')
            .doc(serviceId)
            .set({
          'id': serviceId,
          'providerId': providerId,
          'serviceName': names[j % names.length],
          'description': 'Professional ${names[j % names.length]} service',
          'basePrice': (random.nextInt(500) + 100).toDouble(),
          'platformFee': ((random.nextInt(500) + 100) * 0.1).toDouble(),
          'platformFeePercentage': 10.0,
          'duration': (random.nextInt(60) + 30),
          'category': category,
          'isActive': true,
          'createdAt': Timestamp.fromDate(createdAt),
          'updatedAt': Timestamp.fromDate(createdAt),
        });
        serviceCount++;
      }
    }
    
    print('✅ Created $serviceCount services');
    
    // ========== CREATE WALLETS FOR PROVIDERS ==========
    print('\n💰 Creating wallets...');
    
    // Wallet for prov01
    await firestore
        .collection(AppConfig.providersCollection)
        .doc('prov01')
        .collection('wallet')
        .doc('balance')
        .set({
      'balance': 12000.0,
      'pendingBalance': 500.0,
      'totalEarnings': 20000.0,
      'lastUpdated': Timestamp.fromDate(DateTime.fromMillisecondsSinceEpoch(1734950500000)),
    });
    
    // Create wallets for other providers
    for (int i = 1; i < providerIds.length; i++) {
      final providerId = providerIds[i];
      final balance = (random.nextDouble() * 10000) + 1000;
      final pendingBalance = (random.nextDouble() * 2000) + 200;
      final totalEarnings = balance + pendingBalance + (random.nextDouble() * 50000);
      
      await firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('wallet')
          .doc('balance')
          .set({
        'balance': balance,
        'pendingBalance': pendingBalance,
        'totalEarnings': totalEarnings,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    }
    
    print('✅ Created wallets for all providers');
    
    // ========== CREATE USERS (CUSTOMERS) ==========
    print('\n👥 Creating users (customers)...');
    final userIds = <String>[];
    
    final usersData = [
      {
        'id': 'user01',
        'email': 'customer1@gmail.com',
        'displayName': 'Riya Sharma',
        'isActive': true,
        'isVerified': true,
      },
      {
        'id': 'user02',
        'email': 'customer2@gmail.com',
        'displayName': 'Arjun Singh',
        'isActive': true,
        'isVerified': false,
      },
    ];
    
    for (final userData in usersData) {
      final userId = userData['id'] as String;
      userIds.add(userId);
      
      final createdAt = DateTime.fromMillisecondsSinceEpoch(1734938400000);
      
      await firestore
          .collection(AppConfig.usersCollection)
          .doc(userId)
          .set({
        'userId': userId,
        'email': userData['email'],
        'displayName': userData['displayName'],
        'role': AppConfig.roleUser,
        'isActive': userData['isActive'],
        'isVerified': userData['isVerified'],
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(createdAt),
      }, SetOptions(merge: true));
    }
    
    print('✅ Created ${userIds.length} users');
    
    // ========== CREATE BOOKINGS ==========
    print('\n📅 Creating bookings...');
    int bookingCount = 0;
    
    // Specific booking for prov01
    const bookingId = 'book001';
    final scheduledDate = DateTime.fromMillisecondsSinceEpoch(1734950000000);
    final createdAt = DateTime.fromMillisecondsSinceEpoch(1734938400000);
    final otpCreatedAt = DateTime.fromMillisecondsSinceEpoch(1734938400000);
    final otpExpiresAt = DateTime.fromMillisecondsSinceEpoch(1734939000000);
    
    await firestore
        .collection(AppConfig.providersCollection)
        .doc('prov01')
        .collection('bookings')
        .doc(bookingId)
        .set({
      'id': bookingId,
      'providerId': 'prov01',
      'customerId': 'user01',
      'customerName': 'Riya Sharma',
      'customerPhone': '+919876500000',
      'serviceName': 'Fan Repair',
      'serviceId': 'serv01',
      'status': 'completed',
      'amount': 299.0,
      'baseAmount': 199.0,
      'finalAmount': 299.0,
      'paymentMethod': 'razorpay',
      'paymentStatus': 'paid',
      'scheduledDate': Timestamp.fromDate(scheduledDate),
      'address': 'Mumbai, MH',
      'startOtp': {
        'otpHash': 'HASH111',
        'createdAt': Timestamp.fromDate(otpCreatedAt),
        'expiresAt': Timestamp.fromDate(otpExpiresAt),
        'used': true,
        'resendCount': 1,
      },
      'completionOtp': {
        'otpHash': 'HASH222',
        'createdAt': Timestamp.fromDate(otpCreatedAt),
        'expiresAt': Timestamp.fromDate(otpExpiresAt),
        'used': true,
        'resendCount': 1,
      },
      'serviceStartTime': Timestamp.fromDate(scheduledDate.add(const Duration(minutes: 10))),
      'serviceEndTime': Timestamp.fromDate(scheduledDate.add(const Duration(minutes: 50))),
      'actualDurationMinutes': 40,
      'scheduledDurationMinutes': 40,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(createdAt),
    });
    bookingCount++;
    
    // Create more bookings for variety
    final bookingStatuses = ['pending', 'accepted', 'in_progress', 'completed', 'cancelled'];
    for (int i = 0; i < 20; i++) {
      final providerId = providerIds[random.nextInt(providerIds.length)];
      final customerId = userIds[random.nextInt(userIds.length)];
      final status = bookingStatuses[random.nextInt(bookingStatuses.length)];
      final bookingId = 'book_${providerId}_${DateTime.now().millisecondsSinceEpoch}_$i';
      
      // Get provider services
      final servicesSnapshot = await firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('services')
          .limit(1)
          .get();
      
      if (servicesSnapshot.docs.isEmpty) {
        continue;
      }
      
      final serviceDoc = servicesSnapshot.docs[0];
      final serviceData = serviceDoc.data();
      
      final scheduledDate = DateTime.now().add(Duration(days: random.nextInt(30) - 10));
      final createdAt = DateTime.now().subtract(Duration(days: random.nextInt(60)));
      final baseAmount = (serviceData['basePrice'] as num?)?.toDouble() ?? 1000.0;
      final amount = baseAmount + (random.nextDouble() * 500);
      
      final paymentMethods = ['cod', 'razorpay', 'upi'];
      final paymentMethod = paymentMethods[random.nextInt(paymentMethods.length)];
      final paymentStatus = status == 'completed' ? 'paid' : 'unpaid';
      
      final bookingData = {
        'id': bookingId,
        'providerId': providerId,
        'customerId': customerId,
        'customerName': customerId == 'user01' ? 'Riya Sharma' : 'Arjun Singh',
        'customerPhone': '+91987650000${random.nextInt(10)}',
        'serviceName': serviceData['serviceName'] ?? 'Service',
        'serviceId': serviceDoc.id,
        'status': status,
        'amount': amount,
        'baseAmount': baseAmount,
        'paymentMethod': paymentMethod,
        'paymentStatus': paymentStatus,
        'scheduledDate': Timestamp.fromDate(scheduledDate),
        'address': 'Address ${random.nextInt(100)}, City, State',
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (status == 'in_progress' || status == 'completed') {
        final serviceStartTime = createdAt.add(Duration(hours: random.nextInt(24)));
        bookingData['serviceStartTime'] = Timestamp.fromDate(serviceStartTime);
        
        if (status == 'completed') {
          final serviceEndTime = serviceStartTime.add(Duration(minutes: random.nextInt(120) + 30));
          bookingData['serviceEndTime'] = Timestamp.fromDate(serviceEndTime);
          bookingData['actualDurationMinutes'] = serviceEndTime.difference(serviceStartTime).inMinutes;
          bookingData['scheduledDurationMinutes'] = serviceData['duration'] ?? 60;
        }
      }
      
      await firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('bookings')
          .doc(bookingId)
          .set(bookingData);
      bookingCount++;
    }
    
    print('✅ Created $bookingCount bookings');
    
    // ========== CREATE PAYMENTS ==========
    print('\n💳 Creating payments...');
    int paymentCount = 0;
    
    // Specific payment for prov01
    const paymentId = 'pay01';
    final paidAt = DateTime.fromMillisecondsSinceEpoch(1734950500000);
    
    await firestore
        .collection(AppConfig.providersCollection)
        .doc('prov01')
        .collection('payments')
        .doc(paymentId)
        .set({
      'id': paymentId,
      'providerId': 'prov01',
      'bookingId': 'book001',
      'customerId': 'user01',
      'amount': 299.0,
      'platformFee': 29.0,
      'providerEarning': 270.0,
      'paymentMethod': 'razorpay',
      'status': 'completed',
      'paidAt': Timestamp.fromDate(paidAt),
      'createdAt': Timestamp.fromDate(paidAt),
      'updatedAt': Timestamp.fromDate(paidAt),
    });
    paymentCount++;
    
    // Create more payments for completed bookings
    final bookingsSnapshot = await firestore
        .collectionGroup('bookings')
        .where('status', isEqualTo: 'completed')
        .where('paymentStatus', isEqualTo: 'paid')
        .limit(10)
        .get();
    
    for (final bookingDoc in bookingsSnapshot.docs) {
      final bookingData = bookingDoc.data();
      final providerId = bookingData['providerId'] as String?;
      if (providerId == null) continue;
      
      final paymentId = 'pay_${bookingDoc.id}';
      final amount = (bookingData['finalAmount'] ?? bookingData['amount'] ?? 0.0) as num;
      final platformFee = (amount * 0.1);
      final providerEarning = amount - platformFee;
      
      await firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('payments')
          .doc(paymentId)
          .set({
        'id': paymentId,
        'providerId': providerId,
        'bookingId': bookingDoc.id,
        'customerId': bookingData['customerId'],
        'amount': amount.toDouble(),
        'platformFee': platformFee.toDouble(),
        'providerEarning': providerEarning.toDouble(),
        'status': 'completed',
        'paymentMethod': bookingData['paymentMethod'] ?? 'cod',
        'paidAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      paymentCount++;
    }
    
    print('✅ Created $paymentCount payments');
    
    // ========== CREATE DOCUMENTS ==========
    print('\n📄 Creating documents...');
    
    // Document for prov01
    await firestore
        .collection(AppConfig.providersCollection)
        .doc('prov01')
        .collection('documents')
        .doc('doc01')
        .set({
      'id': 'doc01',
      'providerId': 'prov01',
      'documentType': 'aadhar',
      'documentName': 'Aadhar Card',
      'fileUrl': 'https://storage.firebase.fake/aadhar.png',
      'uploadedAt': Timestamp.fromDate(DateTime.fromMillisecondsSinceEpoch(1734938400000)),
      'verified': true,
      'verifiedAt': Timestamp.fromDate(DateTime.fromMillisecondsSinceEpoch(1734938400000)),
    });
    
    print('✅ Created documents');
    
    // ========== CREATE NOTIFICATIONS ==========
    print('\n🔔 Creating notifications...');
    int notificationCount = 0;
    
    // Specific notification
    await firestore
        .collection(AppConfig.notificationsCollection)
        .doc('notif001')
        .set({
      'id': 'notif001',
      'userId': 'prov01',
      'type': 'booking_created',
      'title': 'New Booking Assigned',
      'body': 'You received a new booking from Riya',
      'read': false,
      'data': {
        'bookingId': 'book001',
      },
      'createdAt': Timestamp.fromDate(DateTime.fromMillisecondsSinceEpoch(1734938400000)),
    });
    notificationCount++;
    
    // Create more notifications
    const notificationTypes = [
      'booking_created',
      'booking_accepted',
      'booking_completed',
      'payment_received',
      'service_start_otp',
      'service_completion_otp',
    ];
    
    for (int i = 0; i < 15; i++) {
      final targetUserId = random.nextBool()
          ? providerIds[random.nextInt(providerIds.length)]
          : userIds[random.nextInt(userIds.length)];
      final type = notificationTypes[random.nextInt(notificationTypes.length)];
      
      final titles = {
        'booking_created': 'New Booking Received',
        'booking_accepted': 'Booking Accepted',
        'booking_completed': 'Service Completed',
        'payment_received': 'Payment Received',
        'service_start_otp': 'Service Start OTP',
        'service_completion_otp': 'Service Completion OTP',
      };
      
      final bodies = {
        'booking_created': 'You have a new booking request',
        'booking_accepted': 'Your booking has been accepted',
        'booking_completed': 'Service has been completed successfully',
        'payment_received': 'Payment of ₹${(random.nextDouble() * 2000 + 500).toStringAsFixed(0)} received',
        'service_start_otp': 'OTP for service start: ${random.nextInt(900000) + 100000}',
        'service_completion_otp': 'OTP for service completion: ${random.nextInt(900000) + 100000}',
      };
      
      final notificationId = 'notif_${DateTime.now().millisecondsSinceEpoch}_$i';
      
      await firestore
          .collection(AppConfig.notificationsCollection)
          .doc(notificationId)
          .set({
        'id': notificationId,
        'userId': targetUserId,
        'type': type,
        'title': titles[type] ?? 'Notification',
        'body': bodies[type] ?? 'You have a new notification',
        'read': random.nextBool(),
        'data': {
          'bookingId': 'book_${random.nextInt(100)}',
        },
        'createdAt': FieldValue.serverTimestamp(),
      });
      notificationCount++;
    }
    
    print('✅ Created $notificationCount notifications');
    
    // ========== SUMMARY ==========
    print('\n✅ Dummy data seeding completed successfully!');
    print('\n📊 Summary:');
    print('  • Admins: $adminCount');
    print('  • Providers: ${providerIds.length}');
    print('  • Users: ${userIds.length}');
    print('  • Services: $serviceCount');
    print('  • Bookings: $bookingCount');
    print('  • Payments: $paymentCount');
    print('  • Notifications: $notificationCount');
    print('\n🎉 Firebase is now populated with dummy data!');
    print('\n📝 Admin Credentials:');
    for (int i = 0; i < adminData.length; i++) {
      final adminInfo = adminData[i];
      print('  ${i + 1}. ${adminInfo['name']}');
      print('     Email: ${adminInfo['email']}');
      print('     Password: ${adminInfo['password']}');
    }
    
  } catch (e, stackTrace) {
    print('❌ Error seeding dummy data: $e');
    print('Stack trace: $stackTrace');
    throw Exception('Failed to seed dummy data: $e');
  }
}

/// Main entry point for running the script directly
Future<void> main() async {
  await seedFirebaseDummyData();
}
