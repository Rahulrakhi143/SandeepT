// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:trivora_provider/core/config/app_config.dart';
import 'package:trivora_provider/firebase_options.dart';

/// Script to add sample services to Firebase
/// Run this once to populate services for a provider
Future<void> main() async {
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  const providerId = 'rUkwGGjoeVZE90FbQhO5BlVvwFm1';
  final firestore = FirebaseFirestore.instance;

  // Sample services data based on the image
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
    print('🚀 Starting to add services to Firebase...');
    print('📍 Provider ID: $providerId');
    print('📍 Location: /providers/$providerId/services/');
    print('');

    int successCount = 0;
    int errorCount = 0;

    for (var serviceData in services) {
      try {
        // Add to services subcollection
        final serviceRef = firestore
            .collection(AppConfig.providersCollection)
            .doc(providerId)
            .collection('services')
            .doc();

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

        await serviceRef.set(service);
        print('✅ Added: ${serviceData['serviceName']} (ID: ${serviceRef.id})');
        successCount++;
      } catch (e) {
        print('❌ Error adding ${serviceData['serviceName']}: $e');
        errorCount++;
      }
    }

    print('');
    print('📊 Summary:');
    print('   ✅ Success: $successCount');
    print('   ❌ Errors: $errorCount');
    print('   📍 Total: ${services.length}');
    print('');
    print('✨ Done! Services added to Firebase.');

    // Also add to provider_services collection if it exists
    // (Some projects might use a separate collection)
    try {
      print('');
      print('🔄 Also adding to provider_services collection...');
      
      for (var serviceData in services) {
        try {
          final serviceRef = firestore
              .collection(AppConfig.providersCollection)
              .doc(providerId)
              .collection('provider_services')
              .doc();

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

          await serviceRef.set(service);
          print('✅ Added to provider_services: ${serviceData['serviceName']}');
        } catch (e) {
          print('⚠️ Could not add to provider_services: $e');
        }
      }
    } catch (e) {
      print('⚠️ provider_services collection not available: $e');
    }
  } catch (e) {
    print('❌ Fatal error: $e');
  }
}

