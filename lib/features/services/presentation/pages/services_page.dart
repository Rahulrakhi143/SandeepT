import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trivora_provider/core/providers/auth_provider.dart';
import 'package:trivora_provider/core/services/backend_service.dart';
import 'package:trivora_provider/core/services/firestore_services_service.dart';
import 'package:trivora_provider/core/config/app_config.dart';
import 'package:trivora_provider/features/services/presentation/pages/add_service_dialog.dart';

/// Provider for services list - fetches from Firestore
final servicesProvider = StateNotifierProvider<ServicesNotifier, AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final authUser = ref.watch(authStateProvider).valueOrNull;
  final userId = authUser?.uid ?? '';
  final firestoreService = ref.watch(firestoreServicesServiceProvider);
  final backendService = ref.watch(backendServiceProvider);
  return ServicesNotifier(firestoreService, backendService, userId);
});

class ServicesNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final FirestoreServicesService _firestoreService;
  final BackendService _backendService;
  final String _userId;

  ServicesNotifier(this._firestoreService, this._backendService, this._userId)
      : super(const AsyncValue.loading()) {
    if (_userId.isNotEmpty) {
      loadServices();
    }
  }

  Future<void> loadServices() async {
    state = const AsyncValue.loading();
    
    try {
      // First try to fetch from Firestore
      final firestoreServices = await _firestoreService.getServices(_userId);
      
      if (firestoreServices.isNotEmpty) {
        // Use Firestore data
        state = AsyncValue.data(firestoreServices);
        // ignore: avoid_print
        print('✅ Loaded ${firestoreServices.length} services from Firestore');
      } else {
        // Fallback to backend service if Firestore is empty
        _backendService.initializeData(_userId);
        final backendServices = _backendService.getServices(_userId);
        state = AsyncValue.data(backendServices);
        // ignore: avoid_print
        print('⚠️ Firestore empty, using backend service data: ${backendServices.length} services');
      }
    } catch (e, stackTrace) {
      // If Firestore fails, fallback to backend service
      try {
        _backendService.initializeData(_userId);
        final backendServices = _backendService.getServices(_userId);
        state = AsyncValue.data(backendServices);
        // ignore: avoid_print
        print('⚠️ Firestore error, using backend service: $e');
      } catch (e2) {
        state = AsyncValue.error(e2, stackTrace);
      }
    }
  }

  Future<void> addService(Map<String, dynamic> serviceData) async {
    try {
      // Add to Firestore
      await _firestoreService.addService(_userId, serviceData);
      // Also add to backend service for consistency
      await _backendService.addService(_userId, serviceData);
      // Reload services
      await loadServices();
    } catch (e) {
      // If Firestore fails, try backend service
      try {
        await _backendService.addService(_userId, serviceData);
        await loadServices();
      } catch (e2) {
        throw Exception('Failed to add service: $e2');
      }
    }
  }

  Future<void> updateService(String serviceId, Map<String, dynamic> data) async {
    try {
      // Update in Firestore
      await _firestoreService.updateService(_userId, serviceId, data);
      // Also update in backend service for consistency
      await _backendService.updateService(serviceId, _userId, data);
      // Reload services
      await loadServices();
    } catch (e) {
      // If Firestore fails, try backend service
      try {
        await _backendService.updateService(serviceId, _userId, data);
        await loadServices();
      } catch (e2) {
        throw Exception('Failed to update service: $e2');
      }
    }
  }

  Future<void> deleteService(String serviceId) async {
    try {
      // Delete from Firestore
      await _firestoreService.deleteService(_userId, serviceId);
      // Also delete from backend service for consistency
      await _backendService.deleteService(serviceId, _userId);
      // Reload services
      await loadServices();
    } catch (e) {
      // If Firestore fails, try backend service
      try {
        await _backendService.deleteService(serviceId, _userId);
        await loadServices();
      } catch (e2) {
        throw Exception('Failed to delete service: $e2');
      }
    }
  }
  
  Future<void> toggleServiceStatus(String serviceId, bool isActive) async {
    try {
      // Update in Firestore
      await _firestoreService.toggleServiceStatus(_userId, serviceId, isActive);
      // Also update in backend service for consistency
      await _backendService.toggleServiceStatus(serviceId, _userId, isActive);
      // Reload services
      await loadServices();
    } catch (e) {
      // If Firestore fails, try backend service
      try {
        await _backendService.toggleServiceStatus(serviceId, _userId, isActive);
        await loadServices();
      } catch (e2) {
        throw Exception('Failed to update service status: $e2');
      }
    }
  }

}

/// Services management page
class ServicesPage extends ConsumerWidget {
  const ServicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUserAsync = ref.watch(authStateProvider);
    final authUser = authUserAsync.valueOrNull;
    if (authUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please login to view services')),
      );
    }

    final servicesAsync = ref.watch(servicesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('My Services'),
            Text(
              'Manage your service offerings',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
              onPressed: () => _showAddServiceDialog(context, ref),
              tooltip: 'Add New Service',
            ),
            PopupMenuButton(
              icon: const Icon(Icons.more_vert),
              itemBuilder: (context) => [
                PopupMenuItem(
                  child: const Row(
                    children: [
                      Icon(Icons.cloud_upload, size: 20),
                      SizedBox(width: 8),
                      Text('Add Sample Services to Firebase'),
                    ],
                  ),
                  onTap: () {
                    Future.delayed(
                      const Duration(milliseconds: 100),
                      () {
                        if (context.mounted) {
                          _addSampleServicesToFirebase(context, ref);
                        }
                      },
                    );
                  },
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.read(servicesProvider.notifier).loadServices();
              },
              tooltip: 'Refresh',
          ),
        ],
      ),
      body: servicesAsync.when(
        data: (services) {
          if (services.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.build_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No services yet',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your first service to get started',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(servicesProvider.notifier).loadServices();
            },
            child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: services.length,
            itemBuilder: (context, index) {
              final service = services[index];
                final status = service['status'] as String? ?? 'active';
                final statusColor = _getStatusColor(status);

              return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                              child: Icon(
                                Icons.build,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    service['serviceName'] as String,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    service['description'] as String,
                                    style: Theme.of(context).textTheme.bodySmall,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                            ),
                        Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: statusColor),
                          ),
                          child: Text(
                                status.toUpperCase(),
                            style: TextStyle(
                                  color: statusColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                          ],
                        ),
                        const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.currency_rupee, size: 16, color: Colors.grey.shade600),
                              Text(
                                '₹${service['basePrice']}',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                              const SizedBox(width: 16),
                              Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                              Text(
                                '${service['duration']} min',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            const Spacer(),
                            Tooltip(
                              message: 'Edit Service',
                              child: IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _showEditServiceDialog(context, ref, service),
                              ),
                            ),
                            Tooltip(
                              message: 'Delete Service',
                              child: IconButton(
                                icon: const Icon(Icons.delete),
                                color: Colors.red,
                                onPressed: () => _deleteService(context, ref, service['id'] as String),
                              ),
                            ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading services',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.red.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade500,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.read(servicesProvider.notifier).loadServices();
                },
                child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  void _showAddServiceDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final priceController = TextEditingController();
    final durationController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AddServiceDialogWidget(
        nameController: nameController,
        descriptionController: descriptionController,
        priceController: priceController,
        durationController: durationController,
      ),
    );
  }

  void _showEditServiceDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> service) {
    final nameController = TextEditingController(text: service['serviceName'] as String);
    final descriptionController = TextEditingController(text: service['description'] as String);
    final priceController = TextEditingController(text: (service['basePrice'] as num).toString());
    final durationController = TextEditingController(text: (service['duration'] as num).toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
          title: const Text('Edit Service'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Service Name'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: priceController,
                decoration: const InputDecoration(labelText: 'Base Price (₹)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: durationController,
                decoration: const InputDecoration(labelText: 'Duration (minutes)'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                await ref.read(servicesProvider.notifier).updateService(service['id'] as String, {
                  'serviceName': nameController.text,
                    'description': descriptionController.text,
                  'basePrice': int.tryParse(priceController.text) ?? service['basePrice'],
                  'duration': int.tryParse(durationController.text) ?? service['duration'],
                  });
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                      content: Text('Service updated successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                      content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            child: const Text('Save'),
            ),
          ],
      ),
    );
  }

  Future<void> _deleteService(BuildContext context, WidgetRef ref, String serviceId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Service'),
        content: const Text('Are you sure you want to delete this service?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(servicesProvider.notifier).deleteService(serviceId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Service deleted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.grey;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }


  Future<void> _addSampleServicesToFirebase(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Sample Services to Firebase'),
        content: const Text(
          'This will add 5 sample services to Firebase:\n\n'
          '• Plumbing (₹814, 79 min)\n'
          '• Carpentry (₹411, 66 min)\n'
          '• Electrical (₹410, 31 min)\n'
          '• Cleaning (₹264, 52 min)\n'
          '• Painting (₹500, 60 min)\n\n'
          'Services will be added to:\n'
          '/providers/{yourId}/services/\n\n'
          'Do you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add Services'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final authUser = ref.read(authStateProvider).valueOrNull;
    if (authUser == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login first'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Show loading
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    try {
      final firestoreService = ref.read(firestoreServicesServiceProvider);
      final providerId = authUser.uid;

      // Sample services data - set as active
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

      // Add each service to both 'services' and 'provider_services' subcollections
      final firestore = FirebaseFirestore.instance;
      
      for (var serviceData in services) {
        // Add via service (to 'services' subcollection)
        final serviceId = await firestoreService.addService(providerId, serviceData);
        
        // Also add to 'provider_services' subcollection
        try {
          final serviceDoc = await firestore
              .collection(AppConfig.providersCollection)
              .doc(providerId)
              .collection('services')
              .doc(serviceId)
              .get();
          
          if (serviceDoc.exists) {
            final serviceDataMap = serviceDoc.data()!;
            await firestore
                .collection(AppConfig.providersCollection)
                .doc(providerId)
                .collection('provider_services')
                .doc(serviceId)
                .set(serviceDataMap);
          }
        } catch (e) {
          // ignore: avoid_print
          print('⚠️ Could not add to provider_services: $e');
        }
      }

      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
      }

      // Reload services
      await ref.read(servicesProvider.notifier).loadServices();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Successfully added 5 services to Firebase!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error adding services: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
