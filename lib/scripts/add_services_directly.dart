// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:trivora_provider/core/config/app_config.dart';
import 'package:trivora_provider/firebase_options.dart';

/// Direct script to add services to Firebase
/// Run: dart lib/scripts/add_services_directly.dart
Future<void> main() async {
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  const providerId = 'rUkwGGjoeVZE90FbQhO5BlVvwFm1';
  final firestore = FirebaseFirestore.instance;

  // Sample services data from the image
  final services = [
    {
      'serviceName': 'Plumbing',
      'description': 'Professional Plumbing service by expert',
      'basePrice': 814,
      'duration': 79,
      'category': 'Plumbing',
      'status': 'active',
      'isActive': true,
    },
    {
      'serviceName': 'Carpentry',
      'description': 'Professional Carpentry service by expert',
      'basePrice': 411,
      'duration': 66,
      'category': 'Carpentry',
      'status': 'active',
      'isActive': true,
    },
    {
      'serviceName': 'Electrical',
      'description': 'Professional Electrical service by expert',
      'basePrice': 410,
      'duration': 31,
      'category': 'Electrical',
      'status': 'active',
      'isActive': true,
    },
    {
      'serviceName': 'Cleaning',
      'description': 'Professional Cleaning service by expert',
      'basePrice': 264,
      'duration': 52,
      'category': 'Cleaning',
      'status': 'active',
      'isActive': true,
    },
    {
      'serviceName': 'Painting',
      'description': 'Professional Painting service by expert',
      'basePrice': 500,
      'duration': 60,
      'category': 'Painting',
      'status': 'active',
      'isActive': true,
    },
  ];

  try {
    print('🚀 Adding services to Firebase...');
    print('📍 Provider ID: $providerId');
    print('📍 Location 1: /providers/$providerId/services/');
    print('📍 Location 2: /providers/$providerId/provider_services/');
    print('');

    int successCount = 0;

    for (var serviceData in services) {
      try {
        // Generate a document ID
        final serviceId = firestore
            .collection(AppConfig.providersCollection)
            .doc(providerId)
            .collection('services')
            .doc()
            .id;

        final service = {
          'providerId': providerId,
          'serviceName': serviceData['serviceName'],
          'description': serviceData['description'],
          'basePrice': serviceData['basePrice'],
          'duration': serviceData['duration'],
          'category': serviceData['category'],
          'status': serviceData['status'],
          'isActive': serviceData['isActive'],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // Add to services subcollection
        await firestore
            .collection(AppConfig.providersCollection)
            .doc(providerId)
            .collection('services')
            .doc(serviceId)
            .set(service);

        // Also add to provider_services subcollection
        await firestore
            .collection(AppConfig.providersCollection)
            .doc(providerId)
            .collection('provider_services')
            .doc(serviceId)
            .set(service);

        print('✅ Added: ${serviceData['serviceName']} (ID: $serviceId)');
        print('   → /providers/$providerId/services/$serviceId');
        print('   → /providers/$providerId/provider_services/$serviceId');
        successCount++;
      } catch (e) {
        print('❌ Error adding ${serviceData['serviceName']}: $e');
      }
    }

    print('');
    print('📊 Summary:');
    print('   ✅ Successfully added: $successCount services');
    print('   📍 Location: /providers/$providerId/services/');
    print('   📍 Also added to: /providers/$providerId/provider_services/');
    print('');
    print('✨ Done! Services are now in Firebase.');
  } catch (e) {
    print('❌ Fatal error: $e');
  }
}

