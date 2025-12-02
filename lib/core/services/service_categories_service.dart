import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service to manage service categories from Firebase
class ServiceCategoriesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get all unique categories from provider_services collection
  Future<List<String>> getCategoriesFromFirebase() async {
    try {
      // Fetch all services from provider_services collection
      final querySnapshot = await _firestore
          .collection('provider_services')
          .get();

      final categories = <String>{};
      
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final category = data['category'] as String?;
        if (category != null && category.isNotEmpty) {
          categories.add(category);
        }
      }

      // Sort categories alphabetically
      final sortedCategories = categories.toList()..sort();
      
      debugPrint('✅ Fetched ${sortedCategories.length} categories from Firebase: $sortedCategories');
      return sortedCategories;
    } catch (e) {
      debugPrint('❌ Error fetching categories from Firebase: $e');
      // Return default categories as fallback
      return ['Cleaning', 'Electrical', 'Plumbing', 'Carpentry', 'Painting', 'AC Repair'];
    }
  }

  /// Get categories stream for real-time updates
  Stream<List<String>> getCategoriesStream() {
    return _firestore
        .collection('provider_services')
        .snapshots()
        .map((snapshot) {
      final categories = <String>{};
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final category = data['category'] as String?;
        if (category != null && category.isNotEmpty) {
          categories.add(category);
        }
      }

      final sortedCategories = categories.toList()..sort();
      return sortedCategories;
    });
  }

  /// Get default categories (fallback)
  List<String> getDefaultCategories() {
    return ['Cleaning', 'Electrical', 'Plumbing', 'Carpentry', 'Painting', 'AC Repair'];
  }
}

/// Provider for ServiceCategoriesService
final serviceCategoriesServiceProvider = Provider<ServiceCategoriesService>((ref) {
  return ServiceCategoriesService();
});

/// Provider for categories list
final categoriesProvider = FutureProvider<List<String>>((ref) async {
  final categoriesService = ref.read(serviceCategoriesServiceProvider);
  return await categoriesService.getCategoriesFromFirebase();
});

/// Provider for categories stream
final categoriesStreamProvider = StreamProvider<List<String>>((ref) {
  final categoriesService = ref.read(serviceCategoriesServiceProvider);
  return categoriesService.getCategoriesStream();
});

