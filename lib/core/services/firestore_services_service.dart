import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trivora_provider/core/config/app_config.dart';
import 'package:trivora_provider/core/services/notification_service.dart';

/// Service to fetch and manage services from Firestore
class FirestoreServicesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get all services for a provider from Firestore
  /// Checks both 'services' and 'provider_services' subcollections
  Future<List<Map<String, dynamic>>> getServices(String providerId) async {
    try {
      if (providerId.isEmpty) {
        return [];
      }
      
      final services = <Map<String, dynamic>>[];
      
      // First, try to get from 'services' subcollection
      try {
        final querySnapshot = await _firestore
            .collection(AppConfig.providersCollection)
            .doc(providerId)
            .collection('services')
            .orderBy('createdAt', descending: true)
            .get();
        
        for (var doc in querySnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          final service = {
            'id': doc.id,
            'providerId': data['providerId'] ?? providerId,
            'serviceName': data['serviceName'] ?? '',
            'description': data['description'] ?? '',
            'basePrice': (data['basePrice'] ?? 0).toInt(),
            'duration': (data['duration'] ?? 60).toInt(),
            'category': data['category'] ?? '',
            'isActive': data['isActive'] ?? true,
            'status': data['status'] ?? (data['isActive'] == true ? 'active' : 'pending'),
            'createdAt': (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            'updatedAt': (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          };
          services.add(service);
        }
      } catch (e) {
        // ignore: avoid_print
        print('⚠️ Could not read from services subcollection: $e');
      }
      
      // If no services found, try 'provider_services' subcollection
      if (services.isEmpty) {
        try {
          final providerServicesSnapshot = await _firestore
              .collection(AppConfig.providersCollection)
              .doc(providerId)
              .collection('provider_services')
              .orderBy('createdAt', descending: true)
              .get();
          
          for (var doc in providerServicesSnapshot.docs) {
            final data = doc.data() as Map<String, dynamic>? ?? {};
            final service = {
              'id': doc.id,
              'providerId': data['providerId'] ?? providerId,
              'serviceName': data['serviceName'] ?? '',
              'description': data['description'] ?? '',
              'basePrice': (data['basePrice'] ?? 0).toInt(),
              'duration': (data['duration'] ?? 60).toInt(),
              'category': data['category'] ?? '',
              'isActive': data['isActive'] ?? true,
              'status': data['status'] ?? (data['isActive'] == true ? 'active' : 'pending'),
              'createdAt': (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              'updatedAt': (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            };
            services.add(service);
          }
        } catch (e) {
          // ignore: avoid_print
          print('⚠️ Could not read from provider_services subcollection: $e');
        }
      }

      return services;
    } catch (e) {
      // ignore: avoid_print
      print('Error fetching services from Firestore: $e');
      return [];
    }
  }

  /// Get services stream for real-time updates
  Stream<List<Map<String, dynamic>>> getServicesStream(String providerId) {
    try {
      return _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('services')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((querySnapshot) {
        final services = <Map<String, dynamic>>[];
        for (var doc in querySnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          final service = {
            'id': doc.id,
            'providerId': data['providerId'] ?? providerId,
            'serviceName': data['serviceName'] ?? '',
            'description': data['description'] ?? '',
            'basePrice': (data['basePrice'] ?? 0).toInt(),
            'duration': (data['duration'] ?? 60).toInt(),
            'category': data['category'] ?? '',
            'isActive': data['isActive'] ?? true,
            'status': data['status'] ?? (data['isActive'] == true ? 'active' : 'pending'),
            'createdAt': (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            'updatedAt': (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          };
          services.add(service);
        }
        return services;
      });
    } catch (e) {
      // ignore: avoid_print
      print('Error creating services stream: $e');
      return Stream.value([]);
    }
  }

  /// Add a new service to Firestore
  /// Service is automatically associated with the provider
  Future<String> addService(String providerId, Map<String, dynamic> serviceData) async {
    try {
      if (providerId.isEmpty) {
        throw Exception('Provider ID is required to add a service');
      }
      
      // Add to both 'services' and 'provider_services' subcollections for compatibility
      final docRef = _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('services')
          .doc();
      
      // Also create reference for provider_services
      final providerServicesRef = _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('provider_services')
          .doc(docRef.id);

      // Services are automatically active when created by provider
      // No approval needed - this app is provider-only
      final isActive = serviceData['isActive'] as bool? ?? true;
      final status = serviceData['status'] as String? ?? 'active';

      final service = {
        'providerId': providerId,
        'serviceName': serviceData['serviceName'] ?? '',
        'description': serviceData['description'] ?? '',
        'basePrice': serviceData['basePrice'] ?? 0,
        'duration': serviceData['duration'] ?? 60,
        'category': serviceData['category'] ?? '',
        'isActive': isActive,
        'status': status,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Save to services subcollection
      await docRef.set(service);
      
      // Also save to provider_services subcollection for compatibility
      try {
        await providerServicesRef.set(service);
        // ignore: avoid_print
        print('✅ Service also added to provider_services: ${docRef.id}');
      } catch (e) {
        // ignore: avoid_print
        print('⚠️ Could not add to provider_services: $e');
      }
      
      // ignore: avoid_print
      print('✅ Service added to Firestore: ${docRef.id}');
      
      // Send notification to provider about new service
      try {
        final notificationService = NotificationService();
        final preferences = await notificationService.getNotificationPreferences(providerId);
        
        if (preferences['serviceNotifications'] == true && 
            preferences['pushNotificationsEnabled'] == true) {
          await notificationService.sendNotificationToProvider(
            providerId,
            'New Service Added',
            'Service "${serviceData['serviceName'] ?? 'New service'}" has been added successfully',
            {
              'type': 'service_added',
              'serviceId': docRef.id,
              'serviceName': serviceData['serviceName'] ?? '',
            },
          );
        }
      } catch (e) {
        // ignore: avoid_print
        print('⚠️ Could not send notification: $e');
      }
      
      return docRef.id;
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error adding service: $e');
      throw Exception('Failed to add service: $e');
    }
  }

  /// Update service in Firestore
  /// Only updates if the service belongs to the specified provider
  /// Checks both 'services' and 'provider_services' subcollections
  Future<void> updateService(
    String providerId,
    String serviceId,
    Map<String, dynamic> data,
  ) async {
    try {
      if (providerId.isEmpty || serviceId.isEmpty) {
        throw Exception('Provider ID and Service ID are required');
      }
      
      final updateData = {
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      bool serviceFound = false;
      bool providerServiceFound = false;

      // Check and update in services subcollection
      try {
        final serviceDoc = await _firestore
            .collection(AppConfig.providersCollection)
            .doc(providerId)
            .collection('services')
            .doc(serviceId)
            .get();
        
        if (serviceDoc.exists) {
          await _firestore
              .collection(AppConfig.providersCollection)
              .doc(providerId)
              .collection('services')
              .doc(serviceId)
              .update(updateData);
          serviceFound = true;
          // ignore: avoid_print
          print('✅ Service updated in services subcollection: $serviceId');
        }
      } catch (e) {
        // ignore: avoid_print
        print('⚠️ Could not update in services subcollection: $e');
      }
      
      // Check and update in provider_services subcollection
      try {
        final providerServicesDoc = await _firestore
            .collection(AppConfig.providersCollection)
            .doc(providerId)
            .collection('provider_services')
            .doc(serviceId)
            .get();
        
        if (providerServicesDoc.exists) {
          await _firestore
              .collection(AppConfig.providersCollection)
              .doc(providerId)
              .collection('provider_services')
              .doc(serviceId)
              .update(updateData);
          providerServiceFound = true;
          // ignore: avoid_print
          print('✅ Service updated in provider_services subcollection: $serviceId');
        }
      } catch (e) {
        // ignore: avoid_print
        print('⚠️ Could not update in provider_services subcollection: $e');
      }
      
      // If service not found in either subcollection, throw error
      if (!serviceFound && !providerServiceFound) {
        throw Exception('Service not found in either subcollection. Service ID: $serviceId');
      }
      
      // If found in one but not the other, create it in the missing one
      if (serviceFound && !providerServiceFound) {
        try {
          // Get the full service data from services subcollection
          final serviceDoc = await _firestore
              .collection(AppConfig.providersCollection)
              .doc(providerId)
              .collection('services')
              .doc(serviceId)
              .get();
          
          if (serviceDoc.exists) {
            final serviceData = serviceDoc.data()!;
            await _firestore
                .collection(AppConfig.providersCollection)
                .doc(providerId)
                .collection('provider_services')
                .doc(serviceId)
                .set(serviceData);
            // ignore: avoid_print
            print('✅ Service created in provider_services subcollection: $serviceId');
          }
        } catch (e) {
          // ignore: avoid_print
          print('⚠️ Could not create in provider_services: $e');
        }
      } else if (!serviceFound && providerServiceFound) {
        try {
          // Get the full service data from provider_services subcollection
          final providerServiceDoc = await _firestore
              .collection(AppConfig.providersCollection)
              .doc(providerId)
              .collection('provider_services')
              .doc(serviceId)
              .get();
          
          if (providerServiceDoc.exists) {
            final serviceData = providerServiceDoc.data()!;
            await _firestore
                .collection(AppConfig.providersCollection)
                .doc(providerId)
                .collection('services')
                .doc(serviceId)
                .set(serviceData);
            // ignore: avoid_print
            print('✅ Service created in services subcollection: $serviceId');
          }
        } catch (e) {
          // ignore: avoid_print
          print('⚠️ Could not create in services: $e');
        }
      }
      
      // ignore: avoid_print
      print('✅ Service update completed: $serviceId');
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error updating service: $e');
      throw Exception('Failed to update service: $e');
    }
  }

  /// Delete service from Firestore
  /// Only deletes if the service belongs to the specified provider
  /// Deletes from both 'services' and 'provider_services' subcollections
  Future<void> deleteService(String providerId, String serviceId) async {
    try {
      if (providerId.isEmpty || serviceId.isEmpty) {
        throw Exception('Provider ID and Service ID are required');
      }
      
      bool serviceFound = false;
      bool providerServiceFound = false;
      
      // Try to delete from services subcollection
      try {
        final serviceDoc = await _firestore
            .collection(AppConfig.providersCollection)
            .doc(providerId)
            .collection('services')
            .doc(serviceId)
            .get();
        
        if (serviceDoc.exists) {
          await _firestore
              .collection(AppConfig.providersCollection)
              .doc(providerId)
              .collection('services')
              .doc(serviceId)
              .delete();
          serviceFound = true;
          // ignore: avoid_print
          print('✅ Service deleted from services subcollection: $serviceId');
        }
      } catch (e) {
        // ignore: avoid_print
        print('⚠️ Could not delete from services subcollection: $e');
      }
      
      // Try to delete from provider_services subcollection
      try {
        final providerServicesDoc = await _firestore
            .collection(AppConfig.providersCollection)
            .doc(providerId)
            .collection('provider_services')
            .doc(serviceId)
            .get();
        
        if (providerServicesDoc.exists) {
          await _firestore
              .collection(AppConfig.providersCollection)
              .doc(providerId)
              .collection('provider_services')
              .doc(serviceId)
              .delete();
          providerServiceFound = true;
          // ignore: avoid_print
          print('✅ Service deleted from provider_services subcollection: $serviceId');
        }
      } catch (e) {
        // ignore: avoid_print
        print('⚠️ Could not delete from provider_services subcollection: $e');
      }
      
      // If service not found in either subcollection, throw error
      if (!serviceFound && !providerServiceFound) {
        throw Exception('Service not found in either subcollection. Service ID: $serviceId');
      }
      
      // ignore: avoid_print
      print('✅ Service deletion completed: $serviceId');
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error deleting service: $e');
      throw Exception('Failed to delete service: $e');
    }
  }

  /// Toggle service active status
  Future<void> toggleServiceStatus(String providerId, String serviceId, bool isActive) async {
    try {
      final updateData = {
        'isActive': isActive,
        'status': isActive ? 'active' : 'inactive',
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      // Update in services subcollection
      await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('services')
          .doc(serviceId)
          .update(updateData);
      
      // Also update in provider_services subcollection
      try {
        final providerServicesDoc = await _firestore
            .collection(AppConfig.providersCollection)
            .doc(providerId)
            .collection('provider_services')
            .doc(serviceId)
            .get();
        
        if (providerServicesDoc.exists) {
          await _firestore
              .collection(AppConfig.providersCollection)
              .doc(providerId)
              .collection('provider_services')
              .doc(serviceId)
              .update(updateData);
          // ignore: avoid_print
          print('✅ Service status also toggled in provider_services: $serviceId -> $isActive');
        }
      } catch (e) {
        // ignore: avoid_print
        print('⚠️ Could not update provider_services: $e');
      }
      
      // ignore: avoid_print
      print('✅ Service status toggled in Firestore: $serviceId -> $isActive');
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error toggling service status: $e');
      throw Exception('Failed to toggle service status: $e');
    }
  }
}

/// Provider for FirestoreServicesService
final firestoreServicesServiceProvider = Provider<FirestoreServicesService>((ref) {
  return FirestoreServicesService();
});

