import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trivora_provider/core/config/app_config.dart';

/// Service for admin operations
class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get all providers
  Stream<List<Map<String, dynamic>>> getAllProviders() {
    try {
      return _firestore
          .collection(AppConfig.providersCollection)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'userId': data['userId'] ?? doc.id,
            'email': data['email'] ?? '',
            'phone': data['phone'] ?? '',
            'displayName': data['displayName'] ?? 'Unknown',
            'photoUrl': data['photoUrl'],
            'isActive': data['isActive'] ?? true,
            'isOnline': data['isOnline'] ?? false,
            'isVerified': data['isVerified'] ?? false,
            'rating': (data['rating'] ?? 0.0).toDouble(),
            'totalBookings': data['totalBookings'] ?? 0,
            'completedBookings': data['completedBookings'] ?? 0,
            'role': data['role'] ?? 'provider',
            'about': data['about'],
            'createdAt': data['createdAt'],
            'updatedAt': data['updatedAt'],
          };
        }).toList();
      });
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error in getAllProviders stream: $e');
      return Stream.value([]);
    }
  }

  /// Get all bookings across all providers
  Future<List<Map<String, dynamic>>> getAllBookings({
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final providersSnapshot = await _firestore
          .collection(AppConfig.providersCollection)
          .get();

      final allBookings = <Map<String, dynamic>>[];

      for (var providerDoc in providersSnapshot.docs) {
        Query query = providerDoc.reference.collection('bookings');

        if (status != null && status != 'all') {
          query = query.where('status', isEqualTo: status);
        }

        if (startDate != null) {
          query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
        }

        if (endDate != null) {
          query = query.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
        }

        query = query.orderBy('createdAt', descending: true);

        final bookingsSnapshot = await query.get();

        for (var bookingDoc in bookingsSnapshot.docs) {
          final bookingData = bookingDoc.data() as Map<String, dynamic>;
          allBookings.add({
            'id': bookingDoc.id,
            'providerId': providerDoc.id,
            ...bookingData,
          });
        }
      }

      return allBookings;
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error fetching all bookings: $e');
      return [];
    }
  }

  /// Get dashboard statistics
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      // Get all providers
      final providersSnapshot = await _firestore
          .collection(AppConfig.providersCollection)
          .get();

      final totalProviders = providersSnapshot.docs.length;
      var activeProviders = 0;
      var totalBookings = 0;
      var completedBookings = 0;
      var pendingBookings = 0;
      var totalRevenue = 0.0;
      var platformRevenue = 0.0;

      // Count active providers
      for (var doc in providersSnapshot.docs) {
        final data = doc.data();
        final isActive = data['isActive'] ?? true;
        final isOnline = data['isOnline'] ?? false;
        if (isActive && isOnline) {
          activeProviders++;
        }
      }

      // Get all bookings and calculate stats
      for (var providerDoc in providersSnapshot.docs) {
        final bookingsSnapshot = await providerDoc.reference
            .collection('bookings')
            .get();

        for (var bookingDoc in bookingsSnapshot.docs) {
          final bookingData = bookingDoc.data();
          totalBookings++;

          final status = bookingData['status'] as String? ?? 'pending';
          if (status == 'completed') {
            completedBookings++;
          } else if (status == 'pending' || status == 'accepted' || status == 'in_progress') {
            pendingBookings++;
          }

          // Calculate revenue
          final amount = (bookingData['finalAmount'] ?? bookingData['amount'] ?? 0).toDouble();
          if (amount > 0 && status == 'completed') {
            totalRevenue += amount;
            platformRevenue += amount * 0.10; // 10% platform fee
          }
        }

        // Get payments
        final paymentsSnapshot = await providerDoc.reference
            .collection(AppConfig.providerPaymentsCollection)
            .where('status', isEqualTo: 'paid')
            .get();

        for (var paymentDoc in paymentsSnapshot.docs) {
          final paymentData = paymentDoc.data();
          final amount = (paymentData['amount'] ?? paymentData['baseAmount'] ?? 0).toDouble();
          final platformFee = (paymentData['platformFee'] ?? 0).toDouble();
          if (amount > 0) {
            totalRevenue += amount;
            platformRevenue += platformFee;
          }
        }
      }

      return {
        'totalProviders': totalProviders,
        'activeProviders': activeProviders,
        'totalBookings': totalBookings,
        'completedBookings': completedBookings,
        'pendingBookings': pendingBookings,
        'totalRevenue': totalRevenue,
        'platformRevenue': platformRevenue,
        'providerEarnings': totalRevenue - platformRevenue,
      };
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error fetching dashboard stats: $e');
      return {
        'totalProviders': 0,
        'activeProviders': 0,
        'totalBookings': 0,
        'completedBookings': 0,
        'pendingBookings': 0,
        'totalRevenue': 0.0,
        'platformRevenue': 0.0,
        'providerEarnings': 0.0,
      };
    }
  }

  /// Update provider status
  Future<void> updateProviderStatus({
    required String providerId,
    required bool isActive,
    String? reason,
  }) async {
    try {
      await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .update({
        'isActive': isActive,
        'isOnline': isActive ? false : null, // Set offline if suspended
        'suspendedAt': isActive ? FieldValue.delete() : FieldValue.serverTimestamp(),
        'suspensionReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ignore: avoid_print
      print('✅ Provider status updated: $providerId -> $isActive');
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error updating provider status: $e');
      throw Exception('Failed to update provider status: $e');
    }
  }

  /// Get provider details
  Future<Map<String, dynamic>?> getProviderDetails(String providerId) async {
    try {
      final doc = await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data() ?? {};
      return {
        'id': doc.id,
        'userId': data['userId'] ?? doc.id,
        'email': data['email'] ?? '',
        'phone': data['phone'] ?? '',
        'displayName': data['displayName'] ?? 'Unknown',
        'photoUrl': data['photoUrl'],
        'isActive': data['isActive'] ?? true,
        'isOnline': data['isOnline'] ?? false,
        'isVerified': data['isVerified'] ?? false,
        'rating': (data['rating'] ?? 0.0).toDouble(),
        'totalBookings': data['totalBookings'] ?? 0,
        'completedBookings': data['completedBookings'] ?? 0,
        'role': data['role'] ?? 'provider',
        'about': data['about'],
        'createdAt': data['createdAt'],
        'updatedAt': data['updatedAt'],
        ...data, // Include all other fields
      };
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error fetching provider details: $e');
      return null;
    }
  }

  /// Get provider bookings
  Stream<List<Map<String, dynamic>>> getProviderBookings(String providerId) {
    return _firestore
        .collection(AppConfig.providersCollection)
        .doc(providerId)
        .collection('bookings')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'providerId': providerId,
          ...data,
        };
      }).toList();
    });
  }

  /// Get provider payments
  Stream<List<Map<String, dynamic>>> getProviderPayments(String providerId) {
    return _firestore
        .collection(AppConfig.providersCollection)
        .doc(providerId)
        .collection(AppConfig.providerPaymentsCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'providerId': providerId,
          'bookingId': data['bookingId'] ?? '',
          'amount': (data['amount'] ?? data['baseAmount'] ?? 0).toDouble(),
          'platformFee': (data['platformFee'] ?? 0).toDouble(),
          'providerEarning': (data['providerEarning'] ?? 0).toDouble(),
          'status': data['status'] ?? 'pending',
          'paymentMethod': data['paymentMethod'] ?? 'cod',
          'createdAt': data['createdAt'],
          'paidAt': data['paidAt'],
          ...data,
        };
      }).toList();
    });
  }

  /// Get all bookings stream (real-time)
  Stream<List<Map<String, dynamic>>> getAllBookingsStream({
    String? status,
  }) {
    try {
      return _firestore
          .collection(AppConfig.providersCollection)
          .snapshots()
          .asyncMap((providersSnapshot) async {
        final allBookings = <Map<String, dynamic>>[];

        for (var providerDoc in providersSnapshot.docs) {
          Query query = providerDoc.reference.collection('bookings');

          if (status != null && status != 'all') {
            query = query.where('status', isEqualTo: status);
          }

          query = query.orderBy('createdAt', descending: true).limit(50);

          try {
            final bookingsSnapshot = await query.get();

            for (var bookingDoc in bookingsSnapshot.docs) {
              final bookingData = bookingDoc.data() as Map<String, dynamic>? ?? {};
              allBookings.add({
                'id': bookingDoc.id,
                'providerId': providerDoc.id,
                'customerId': bookingData['customerId'] ?? '',
                'customerName': bookingData['customerName'] ?? 'Unknown',
                'customerPhone': bookingData['customerPhone'] ?? '',
                'serviceName': bookingData['serviceName'] ?? '',
                'status': bookingData['status'] ?? 'pending',
                'amount': (bookingData['finalAmount'] ?? bookingData['amount'] ?? 0).toDouble(),
                'paymentMethod': bookingData['paymentMethod'] ?? 'cod',
                'paymentStatus': bookingData['paymentStatus'] ?? 'unpaid',
                'address': bookingData['address'] ?? '',
                'scheduledDate': bookingData['scheduledDate'],
                'createdAt': bookingData['createdAt'],
                'updatedAt': bookingData['updatedAt'],
                ...bookingData,
              });
            }
          } catch (e) {
            // ignore: avoid_print
            print('⚠️ Error fetching bookings for provider ${providerDoc.id}: $e');
          }
        }

        // Sort by createdAt descending
        allBookings.sort((a, b) {
          final aTime = a['createdAt'] as Timestamp?;
          final bTime = b['createdAt'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });

        return allBookings;
      });
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error in getAllBookingsStream: $e');
      return Stream.value([]);
    }
  }

  /// Get all payments stream (real-time)
  Stream<List<Map<String, dynamic>>> getAllPaymentsStream() {
    try {
      return _firestore
          .collection(AppConfig.providersCollection)
          .snapshots()
          .asyncMap((providersSnapshot) async {
        final allPayments = <Map<String, dynamic>>[];

        for (var providerDoc in providersSnapshot.docs) {
          try {
            final paymentsSnapshot = await providerDoc.reference
                .collection(AppConfig.providerPaymentsCollection)
                .orderBy('createdAt', descending: true)
                .limit(50)
                .get();

            for (var paymentDoc in paymentsSnapshot.docs) {
              final paymentData = paymentDoc.data();
              allPayments.add({
                'id': paymentDoc.id,
                'providerId': providerDoc.id,
                'bookingId': paymentData['bookingId'] ?? '',
                'amount': (paymentData['amount'] ?? paymentData['baseAmount'] ?? 0).toDouble(),
                'platformFee': (paymentData['platformFee'] ?? 0).toDouble(),
                'providerEarning': (paymentData['providerEarning'] ?? 0).toDouble(),
                'status': paymentData['status'] ?? 'pending',
                'paymentMethod': paymentData['paymentMethod'] ?? 'cod',
                'createdAt': paymentData['createdAt'],
                'paidAt': paymentData['paidAt'],
                ...paymentData,
              });
            }
          } catch (e) {
            // ignore: avoid_print
            print('⚠️ Error fetching payments for provider ${providerDoc.id}: $e');
          }
        }

        // Sort by createdAt descending
        allPayments.sort((a, b) {
          final aTime = a['createdAt'] as Timestamp?;
          final bTime = b['createdAt'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });

        return allPayments;
      });
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error in getAllPaymentsStream: $e');
      return Stream.value([]);
    }
  }

  /// Get all users and providers combined
  Stream<List<Map<String, dynamic>>> getAllUsers() {
    try {
      // Combine both users and providers collections
      return Stream.periodic(const Duration(seconds: 1)).asyncMap((_) async {
        final allData = <Map<String, dynamic>>[];

        // Fetch users
        try {
          final usersSnapshot = await _firestore
              .collection(AppConfig.usersCollection)
              .get();

          for (var doc in usersSnapshot.docs) {
            final data = doc.data();
            allData.add({
              'id': doc.id,
              'userId': data['userId'] ?? doc.id,
              'email': data['email'] ?? '',
              'phone': data['phone'] ?? '',
              'displayName': data['displayName'] ?? data['name'] ?? 'Unknown',
              'photoUrl': data['photoUrl'],
              'role': data['role'] ?? 'user',
              'userType': 'user', // Mark as user
              'isActive': data['isActive'] ?? true,
              'isVerified': data['isVerified'] ?? false,
              'isOnline': false,
              'rating': 0.0,
              'totalBookings': 0,
              'completedBookings': 0,
              'createdAt': data['createdAt'],
              'updatedAt': data['updatedAt'],
              'password': data['password'],
              'tempPassword': data['tempPassword'],
              ...data,
            });
          }
        } catch (e) {
          // ignore: avoid_print
          print('⚠️ Error fetching users: $e');
        }

        // Fetch providers
        try {
          final providersSnapshot = await _firestore
              .collection(AppConfig.providersCollection)
              .get();

          for (var doc in providersSnapshot.docs) {
            final data = doc.data();
            allData.add({
              'id': doc.id,
              'userId': data['userId'] ?? doc.id,
              'email': data['email'] ?? '',
              'phone': data['phone'] ?? '',
              'displayName': data['displayName'] ?? 'Unknown',
              'photoUrl': data['photoUrl'],
              'role': data['role'] ?? 'provider',
              'userType': 'provider', // Mark as provider
              'isActive': data['isActive'] ?? true,
              'isOnline': data['isOnline'] ?? false,
              'isVerified': data['isVerified'] ?? false,
              'rating': (data['rating'] ?? 0.0).toDouble(),
              'totalBookings': data['totalBookings'] ?? 0,
              'completedBookings': data['completedBookings'] ?? 0,
              'createdAt': data['createdAt'],
              'updatedAt': data['updatedAt'],
              'password': data['password'],
              'tempPassword': data['tempPassword'],
              ...data,
            });
          }
        } catch (e) {
          // ignore: avoid_print
          print('⚠️ Error fetching providers: $e');
        }

        // Sort by createdAt (newest first)
        allData.sort((a, b) {
          final aTime = a['createdAt'] as Timestamp?;
          final bTime = b['createdAt'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });

        return allData;
      });
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error in getAllUsers stream: $e');
      return Stream.value([]);
    }
  }

  /// Get user details
  Future<Map<String, dynamic>?> getUserDetails(String userId) async {
    try {
      final doc = await _firestore
          .collection(AppConfig.usersCollection)
          .doc(userId)
          .get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data() ?? {};
      return {
        'id': doc.id,
        'userId': data['userId'] ?? doc.id,
        'email': data['email'] ?? '',
        'phone': data['phone'] ?? '',
        'displayName': data['displayName'] ?? data['name'] ?? 'Unknown',
        'photoUrl': data['photoUrl'],
        'role': data['role'] ?? 'user',
        'isActive': data['isActive'] ?? true,
        'isVerified': data['isVerified'] ?? false,
        'createdAt': data['createdAt'],
        'updatedAt': data['updatedAt'],
        ...data,
      };
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error fetching user details: $e');
      return null;
    }
  }

  /// Update user status
  Future<void> updateUserStatus({
    required String userId,
    required bool isActive,
    String? reason,
  }) async {
    try {
      await _firestore
          .collection(AppConfig.usersCollection)
          .doc(userId)
          .update({
        'isActive': isActive,
        'suspendedAt': isActive ? FieldValue.delete() : FieldValue.serverTimestamp(),
        'suspensionReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ignore: avoid_print
      print('✅ User status updated: $userId -> $isActive');
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error updating user status: $e');
      throw Exception('Failed to update user status: $e');
    }
  }

  /// Get all services across all providers
  /// Checks both 'services' and 'provider_services' subcollections
  Stream<List<Map<String, dynamic>>> getAllServices() {
    try {
      // Get services from 'services' subcollection
      return _firestore
          .collectionGroup('services')
          .snapshots()
          .asyncMap((servicesSnapshot) async {
        final allServices = <String, Map<String, dynamic>>{};
        
        // Process 'services' subcollection
        for (var doc in servicesSnapshot.docs) {
          final data = doc.data();
          final pathParts = doc.reference.path.split('/');
          final providerId = pathParts.length >= 2 ? pathParts[pathParts.length - 3] : '';
          
          final service = {
            'id': doc.id,
            'providerId': providerId,
            'serviceName': data['serviceName'] ?? '',
            'description': data['description'] ?? '',
            'basePrice': (data['basePrice'] ?? 0.0).toDouble(),
            'platformFee': (data['platformFee'] ?? 0.0).toDouble(),
            'platformFeePercentage': (data['platformFeePercentage'] ?? 10.0).toDouble(),
            'duration': data['duration'] ?? 0,
            'category': data['category'] ?? '',
            'isActive': data['isActive'] ?? true,
            'createdAt': data['createdAt'],
            'updatedAt': data['updatedAt'],
            ...data,
          };
          
          // Use serviceId as key to avoid duplicates
          allServices['${providerId}_${doc.id}'] = service;
        }
        
        // Also get services from 'provider_services' subcollection
        try {
          final providerServicesSnapshot = await _firestore
              .collectionGroup(AppConfig.providerServicesCollection)
              .get();
          
          for (var doc in providerServicesSnapshot.docs) {
            final data = doc.data();
            final pathParts = doc.reference.path.split('/');
            final providerId = pathParts.length >= 2 ? pathParts[pathParts.length - 3] : '';
            
            final serviceKey = '${providerId}_${doc.id}';
            
            // Only add if not already in the map (services collection takes priority)
            if (!allServices.containsKey(serviceKey)) {
              final service = {
                'id': doc.id,
                'providerId': providerId,
                'serviceName': data['serviceName'] ?? '',
                'description': data['description'] ?? '',
                'basePrice': (data['basePrice'] ?? 0.0).toDouble(),
                'platformFee': (data['platformFee'] ?? 0.0).toDouble(),
                'platformFeePercentage': (data['platformFeePercentage'] ?? 10.0).toDouble(),
                'duration': data['duration'] ?? 0,
                'category': data['category'] ?? '',
                'isActive': data['isActive'] ?? true,
                'createdAt': data['createdAt'],
                'updatedAt': data['updatedAt'],
                ...data,
              };
              
              allServices[serviceKey] = service;
            }
          }
        } catch (e) {
          // ignore: avoid_print
          print('⚠️ Could not read from provider_services: $e');
        }
        
        return allServices.values.toList();
      });
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error in getAllServices stream: $e');
      return Stream.value([]);
    }
  }

  /// Create a new service (admin can create services for any provider)
  Future<void> createService({
    required String providerId,
    required String serviceName,
    required String description,
    required double basePrice,
    required int duration,
    required String category,
    double? platformFee,
    double? platformFeePercentage,
  }) async {
    try {
      final serviceId = 'service_${DateTime.now().millisecondsSinceEpoch}';
      final calculatedPlatformFee = platformFee ?? (basePrice * (platformFeePercentage ?? 10.0) / 100);
      
      final serviceData = {
        'id': serviceId,
        'providerId': providerId,
        'serviceName': serviceName,
        'description': description,
        'basePrice': basePrice,
        'platformFee': calculatedPlatformFee,
        'platformFeePercentage': platformFeePercentage ?? 10.0,
        'duration': duration,
        'category': category,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      // Save to 'services' subcollection
      await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('services')
          .doc(serviceId)
          .set(serviceData);

      // Also save to 'provider_services' subcollection for compatibility
      try {
        await _firestore
            .collection(AppConfig.providersCollection)
            .doc(providerId)
            .collection(AppConfig.providerServicesCollection)
            .doc(serviceId)
            .set(serviceData);
        // ignore: avoid_print
        print('✅ Service also added to provider_services: $serviceId');
      } catch (e) {
        // ignore: avoid_print
        print('⚠️ Could not add to provider_services: $e');
      }

      // ignore: avoid_print
      print('✅ Service created: $serviceId');
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error creating service: $e');
      throw Exception('Failed to create service: $e');
    }
  }

  /// Update a service
  Future<void> updateService({
    required String providerId,
    required String serviceId,
    String? serviceName,
    String? description,
    double? basePrice,
    double? platformFee,
    double? platformFeePercentage,
    int? duration,
    String? category,
    bool? isActive,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (serviceName != null) updateData['serviceName'] = serviceName;
      if (description != null) updateData['description'] = description;
      if (basePrice != null) {
        updateData['basePrice'] = basePrice;
        // Recalculate platform fee if base price changed
        if (platformFeePercentage != null) {
          updateData['platformFee'] = basePrice * (platformFeePercentage / 100);
        } else if (platformFee != null) {
          updateData['platformFee'] = platformFee;
        }
      }
      if (platformFee != null) updateData['platformFee'] = platformFee;
      if (platformFeePercentage != null) {
        updateData['platformFeePercentage'] = platformFeePercentage;
        // Recalculate platform fee based on base price
        final serviceDoc = await _firestore
            .collection(AppConfig.providersCollection)
            .doc(providerId)
            .collection('services')
            .doc(serviceId)
            .get();
        if (serviceDoc.exists) {
          final currentData = serviceDoc.data() ?? {};
          final currentBasePrice = (currentData['basePrice'] ?? 0.0).toDouble();
          updateData['platformFee'] = currentBasePrice * (platformFeePercentage / 100);
        }
      }
      if (duration != null) updateData['duration'] = duration;
      if (category != null) updateData['category'] = category;
      if (isActive != null) updateData['isActive'] = isActive;

      // Update in 'services' subcollection
      await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('services')
          .doc(serviceId)
          .update(updateData);

      // Also update in 'provider_services' subcollection
      try {
        await _firestore
            .collection(AppConfig.providersCollection)
            .doc(providerId)
            .collection(AppConfig.providerServicesCollection)
            .doc(serviceId)
            .update(updateData);
        // ignore: avoid_print
        print('✅ Service also updated in provider_services: $serviceId');
      } catch (e) {
        // ignore: avoid_print
        print('⚠️ Could not update in provider_services: $e');
      }

      // ignore: avoid_print
      print('✅ Service updated: $serviceId');
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error updating service: $e');
      throw Exception('Failed to update service: $e');
    }
  }

  /// Delete a service
  Future<void> deleteService({
    required String providerId,
    required String serviceId,
  }) async {
    try {
      // Delete from 'services' subcollection
      await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('services')
          .doc(serviceId)
          .delete();

      // Also delete from 'provider_services' subcollection
      try {
        await _firestore
            .collection(AppConfig.providersCollection)
            .doc(providerId)
            .collection(AppConfig.providerServicesCollection)
            .doc(serviceId)
            .delete();
        // ignore: avoid_print
        print('✅ Service also deleted from provider_services: $serviceId');
      } catch (e) {
        // ignore: avoid_print
        print('⚠️ Could not delete from provider_services: $e');
      }

      // ignore: avoid_print
      print('✅ Service deleted: $serviceId');
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error deleting service: $e');
      throw Exception('Failed to delete service: $e');
    }
  }

  /// Get all service categories
  /// Categories are stored in provider_services collection (root level) with type='category'
  Stream<List<Map<String, dynamic>>> getAllServiceCategories() {
    try {
      return _firestore
          .collection(AppConfig.serviceCategoriesCollection)
          .where('type', isEqualTo: 'category')
          .orderBy('name')
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'] ?? '',
            'description': data['description'] ?? '',
            'icon': data['icon'] ?? '',
            'isActive': data['isActive'] ?? true,
            'defaultPlatformFeePercentage': (data['defaultPlatformFeePercentage'] ?? 10.0).toDouble(),
            'createdAt': data['createdAt'],
            'updatedAt': data['updatedAt'],
            ...data,
          };
        }).toList();
      });
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error in getAllServiceCategories stream: $e');
      return Stream.value([]);
    }
  }

  /// Create a new service category
  /// Categories are stored in provider_services collection with type='category'
  Future<void> createServiceCategory({
    required String name,
    String? description,
    String? icon,
    double? defaultPlatformFeePercentage,
  }) async {
    try {
      // Check if category already exists in provider_services collection
      final existing = await _firestore
          .collection(AppConfig.serviceCategoriesCollection)
          .where('type', isEqualTo: 'category')
          .where('name', isEqualTo: name)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        throw Exception('Category "$name" already exists');
      }

      // Generate service ID similar to service format
      final categoryId = 'service_${DateTime.now().millisecondsSinceEpoch}';
      
      // Store in provider_services collection (root level, not under a provider)
      // We'll use a special provider ID or store at root
      await _firestore
          .collection(AppConfig.serviceCategoriesCollection)
          .doc(categoryId)
          .set({
        'type': 'category', // Mark as category
        'name': name,
        'description': description ?? '',
        'icon': icon ?? 'build',
        'isActive': true,
        'defaultPlatformFeePercentage': defaultPlatformFeePercentage ?? 10.0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ignore: avoid_print
      print('✅ Service category created: $name (ID: $categoryId)');
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error creating service category: $e');
      throw Exception('Failed to create service category: $e');
    }
  }

  /// Update a service category
  Future<void> updateServiceCategory({
    required String categoryId,
    String? name,
    String? description,
    String? icon,
    double? defaultPlatformFeePercentage,
    bool? isActive,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (name != null) {
        // Check if new name already exists
        final existing = await _firestore
            .collection(AppConfig.serviceCategoriesCollection)
            .where('type', isEqualTo: 'category')
            .where('name', isEqualTo: name)
            .get();
        
        // Check if any existing doc (other than current one) has this name
        final hasDuplicate = existing.docs.any((doc) => doc.id != categoryId);

        if (hasDuplicate) {
          throw Exception('Category "$name" already exists');
        }
        updateData['name'] = name;
      }
      if (description != null) updateData['description'] = description;
      if (icon != null) updateData['icon'] = icon;
      if (defaultPlatformFeePercentage != null) {
        updateData['defaultPlatformFeePercentage'] = defaultPlatformFeePercentage;
      }
      if (isActive != null) updateData['isActive'] = isActive;

      await _firestore
          .collection(AppConfig.serviceCategoriesCollection)
          .doc(categoryId)
          .update(updateData);

      // ignore: avoid_print
      print('✅ Service category updated: $categoryId');
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error updating service category: $e');
      throw Exception('Failed to update service category: $e');
    }
  }

  /// Delete a service category
  Future<void> deleteServiceCategory({
    required String categoryId,
  }) async {
    try {
      // Check if any services are using this category
      final servicesWithCategory = await _firestore
          .collectionGroup('services')
          .where('category', isEqualTo: categoryId)
          .limit(1)
          .get();

      if (servicesWithCategory.docs.isNotEmpty) {
        throw Exception('Cannot delete category. Some services are using this category.');
      }

      await _firestore
          .collection(AppConfig.serviceCategoriesCollection)
          .doc(categoryId)
          .delete();

      // ignore: avoid_print
      print('✅ Service category deleted: $categoryId');
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error deleting service category: $e');
      throw Exception('Failed to delete service category: $e');
    }
  }

  /// Create a new admin account
  Future<void> createAdminAccount({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      // Note: This requires Firebase Auth Admin SDK for server-side account creation
      // For now, we'll create the admin document and return instructions
      // The actual Firebase Auth account should be created separately
      
      // Check if admin already exists
      final existing = await _firestore
          .collection(AppConfig.adminsCollection)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      
      if (existing.docs.isNotEmpty) {
        throw Exception('Admin account with this email already exists');
      }
      
      // Create admin document (UID will be set after Firebase Auth account is created)
      // For now, we'll use a temporary document
      final adminDoc = _firestore.collection(AppConfig.adminsCollection).doc();
      
      await adminDoc.set({
        'email': email,
        'displayName': displayName,
        'role': 'admin',
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'password': password, // Note: In production, this should be handled securely
        'needsAuthCreation': true, // Flag to indicate Firebase Auth account needs to be created
      });
      
      // ignore: avoid_print
      // ignore: avoid_print
      // ignore: avoid_print
      // ignore: avoid_print
      print('✅ Admin document created. Please create Firebase Auth account separately.');
      print('Admin Document ID: ${adminDoc.id}');
      print('Email: $email');
      print('Password: $password');
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error creating admin account: $e');
      throw Exception('Failed to create admin account: $e');
    }
  }

  /// Get or set platform fee configuration
  Future<Map<String, dynamic>> getPlatformFeeConfig() async {
    try {
      final doc = await _firestore
          .collection('admin_config')
          .doc('platform_fee')
          .get();
      
      if (doc.exists) {
        return doc.data() ?? {};
      }
      
      // Return default config
      return {
        'defaultFeePercentage': 10.0,
        'minFee': 0.0,
        'maxFee': 100.0,
        'updatedAt': FieldValue.serverTimestamp(),
      };
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error getting platform fee config: $e');
      return {
        'defaultFeePercentage': 10.0,
        'minFee': 0.0,
        'maxFee': 100.0,
      };
    }
  }

  /// Update platform fee configuration
  Future<void> updatePlatformFeeConfig({
    double? defaultFeePercentage,
    double? minFee,
    double? maxFee,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (defaultFeePercentage != null) {
        updateData['defaultFeePercentage'] = defaultFeePercentage;
      }
      if (minFee != null) {
        updateData['minFee'] = minFee;
      }
      if (maxFee != null) {
        updateData['maxFee'] = maxFee;
      }
      
      await _firestore
          .collection('admin_config')
          .doc('platform_fee')
          .set(updateData, SetOptions(merge: true));
      
      // ignore: avoid_print
      print('✅ Platform fee config updated');
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error updating platform fee config: $e');
      throw Exception('Failed to update platform fee config: $e');
    }
  }

  /// Create provider service in provider_services collection (root level)
  Future<void> createProviderService({
    required String providerId,
    required String serviceName,
    required String description,
    required double basePrice,
    required int duration,
    required String category,
    double? platformFee,
    double? platformFeePercentage,
  }) async {
    try {
      final serviceId = 'service_${DateTime.now().millisecondsSinceEpoch}_${providerId.substring(0, 3)}';
      final calculatedPlatformFee = platformFee ?? (basePrice * (platformFeePercentage ?? 10.0) / 100);
      
      final serviceData = {
        'id': serviceId,
        'providerId': providerId,
        'serviceName': serviceName,
        'description': description,
        'basePrice': basePrice,
        'platformFee': calculatedPlatformFee,
        'platformFeePercentage': platformFeePercentage ?? 10.0,
        'duration': duration,
        'category': category,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      // Save to provider_services collection (root level, not under provider)
      await _firestore
          .collection('provider_services')
          .doc(serviceId)
          .set(serviceData);
      
      // Also save to provider's subcollection for compatibility
      try {
        await _firestore
            .collection(AppConfig.providersCollection)
            .doc(providerId)
            .collection('provider_services')
            .doc(serviceId)
            .set(serviceData);
      } catch (e) {
        // ignore: avoid_print
        print('⚠️ Could not add to provider subcollection: $e');
      }

      // ignore: avoid_print
      print('✅ Provider service created in provider_services: $serviceId');
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error creating provider service: $e');
      throw Exception('Failed to create provider service: $e');
    }
  }

  /// Get all provider services from provider_services collection
  Stream<List<Map<String, dynamic>>> getAllProviderServices({String? providerId}) {
    try {
      Query query = _firestore.collection('provider_services');
      
      if (providerId != null) {
        query = query.where('providerId', isEqualTo: providerId);
      }
      
      return query
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map<Map<String, dynamic>>((doc) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          return <String, dynamic>{
            'id': doc.id,
            'providerId': data['providerId'] ?? '',
            'serviceName': data['serviceName'] ?? '',
            'description': data['description'] ?? '',
            'basePrice': (data['basePrice'] ?? 0.0).toDouble(),
            'platformFee': (data['platformFee'] ?? 0.0).toDouble(),
            'platformFeePercentage': (data['platformFeePercentage'] ?? 10.0).toDouble(),
            'duration': data['duration'] ?? 0,
            'category': data['category'] ?? '',
            'isActive': data['isActive'] ?? true,
            'createdAt': data['createdAt'],
            'updatedAt': data['updatedAt'],
            ...data,
          };
        }).toList();
      });
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error in getAllProviderServices stream: $e');
      return Stream.value(<Map<String, dynamic>>[]);
    }
  }
}

/// Provider for AdminService
final adminServiceProvider = Provider<AdminService>((ref) {
  return AdminService();
});

