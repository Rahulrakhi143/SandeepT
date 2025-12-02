// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trivora_provider/core/services/admin_service.dart';
import 'package:trivora_provider/core/config/app_config.dart';

/// Services Management View for Admin
class AdminServicesView extends ConsumerStatefulWidget {
  const AdminServicesView({super.key});

  @override
  ConsumerState<AdminServicesView> createState() => _AdminServicesViewState();
}

class _AdminServicesViewState extends ConsumerState<AdminServicesView> {
  String _searchQuery = '';
  String _categoryFilter = 'all';
  String _providerFilter = 'all';
  final List<String> _providerIds = [];
  final Map<String, String> _providerNames = {};

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    try {
      final providersSnapshot = await FirebaseFirestore.instance
          .collection(AppConfig.providersCollection)
          .get();
      
      setState(() {
        _providerIds.clear();
        _providerNames.clear();
        for (var doc in providersSnapshot.docs) {
          final data = doc.data();
          _providerIds.add(doc.id);
          _providerNames[doc.id] = data['displayName'] ?? 'Unknown Provider';
        }
      });
    } catch (e) {
      print('Error loading providers: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminService = ref.read(adminServiceProvider);
    final servicesStream = adminService.getAllServices();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Services Management',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showCreateServiceDialog(context, ref),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Create Service'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => setState(() {}),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Search and Filter Bar
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search services by name, category, or provider...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                flex: 1,
                child: DropdownButtonFormField<String>(
                  value: _categoryFilter,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Categories')),
                    DropdownMenuItem(value: 'Electrical', child: Text('Electrical')),
                    DropdownMenuItem(value: 'Plumbing', child: Text('Plumbing')),
                    DropdownMenuItem(value: 'Cleaning', child: Text('Cleaning')),
                    DropdownMenuItem(value: 'AC Repair', child: Text('AC Repair')),
                    DropdownMenuItem(value: 'Carpentry', child: Text('Carpentry')),
                    DropdownMenuItem(value: 'Beauty', child: Text('Beauty')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _categoryFilter = value ?? 'all';
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                flex: 1,
                child: DropdownButtonFormField<String>(
                  value: _providerFilter,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Provider',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('All Providers')),
                    ..._providerIds.map((id) => DropdownMenuItem(
                      value: id,
                      child: Text(
                        _providerNames[id] ?? id,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _providerFilter = value ?? 'all';
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Services Table
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: servicesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                var services = snapshot.data ?? [];

                // Apply filters
                if (_searchQuery.isNotEmpty) {
                  services = services.where((service) {
                    final name = (service['serviceName'] ?? '').toString().toLowerCase();
                    final category = (service['category'] ?? '').toString().toLowerCase();
                    final providerName = (_providerNames[service['providerId']] ?? '').toString().toLowerCase();
                    return name.contains(_searchQuery) ||
                        category.contains(_searchQuery) ||
                        providerName.contains(_searchQuery);
                  }).toList();
                }

                if (_categoryFilter != 'all') {
                  services = services.where((service) {
                    return service['category'] == _categoryFilter;
                  }).toList();
                }

                if (_providerFilter != 'all') {
                  services = services.where((service) {
                    return service['providerId'] == _providerFilter;
                  }).toList();
                }

                if (services.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.build_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No services found',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create a new service to get started',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey.shade500,
                              ),
                        ),
                      ],
                    ),
                  );
                }

                return Card(
                  elevation: 2,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: DataTable(
                        columnSpacing: 12,
                        horizontalMargin: 12,
                        dataRowMinHeight: 56,
                        columns: const [
                          DataColumn(label: Text('Service Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Provider', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Base Price', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Platform Fee', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Fee %', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Duration', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Actions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                        ],
                        rows: services.map((service) {
                          final isActive = service['isActive'] ?? true;
                          final basePrice = (service['basePrice'] ?? 0.0).toDouble();
                          final platformFee = (service['platformFee'] ?? 0.0).toDouble();
                          final platformFeePercentage = (service['platformFeePercentage'] ?? 10.0).toDouble();
                          final providerId = service['providerId'] ?? '';
                          final providerName = _providerNames[providerId] ?? providerId;

                          return DataRow(
                            cells: [
                              DataCell(
                                SizedBox(
                                  width: 200,
                                  child: Text(
                                    service['serviceName'] ?? 'Unknown',
                                    style: const TextStyle(fontSize: 12),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 150,
                                  child: Text(
                                    providerName,
                                    style: const TextStyle(fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    service['category'] ?? 'N/A',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.blue.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  '₹${basePrice.toStringAsFixed(0)}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                              ),
                              DataCell(
                                Text(
                                  '₹${platformFee.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                              ),
                              DataCell(
                                Text(
                                  '${platformFeePercentage.toStringAsFixed(1)}%',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              DataCell(
                                Text(
                                  '${service['duration'] ?? 0} min',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isActive ? Colors.green.shade50 : Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isActive ? 'Active' : 'Inactive',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isActive ? Colors.green.shade700 : Colors.red.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 18),
                                      color: Colors.blue,
                                      onPressed: () => _showEditServiceDialog(context, ref, service),
                                      tooltip: 'Edit',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, size: 18),
                                      color: Colors.red,
                                      onPressed: () => _showDeleteServiceDialog(context, ref, service),
                                      tooltip: 'Delete',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateServiceDialog(BuildContext context, WidgetRef ref) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final basePriceController = TextEditingController();
    final platformFeePercentageController = TextEditingController(text: '10.0');
    final durationController = TextEditingController();
    String selectedCategory = 'Electrical';
    String? selectedProviderId = _providerIds.isNotEmpty ? _providerIds[0] : null;
    bool isActive = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create New Service'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedProviderId,
                    decoration: const InputDecoration(
                      labelText: 'Provider *',
                      border: OutlineInputBorder(),
                    ),
                    items: _providerIds.map((id) => DropdownMenuItem(
                      value: id,
                      child: Text(_providerNames[id] ?? id),
                    )).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedProviderId = value;
                      });
                    },
                    validator: (value) => value == null ? 'Please select a provider' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Service Name *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value?.isEmpty ?? true ? 'Please enter service name' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: basePriceController,
                          decoration: const InputDecoration(
                            labelText: 'Base Price (₹) *',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value?.isEmpty ?? true) return 'Please enter base price';
                            if (double.tryParse(value!) == null) return 'Invalid price';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: durationController,
                          decoration: const InputDecoration(
                            labelText: 'Duration (min) *',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value?.isEmpty ?? true) return 'Please enter duration';
                            if (int.tryParse(value!) == null) return 'Invalid duration';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Category *',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Electrical', child: Text('Electrical')),
                            DropdownMenuItem(value: 'Plumbing', child: Text('Plumbing')),
                            DropdownMenuItem(value: 'Cleaning', child: Text('Cleaning')),
                            DropdownMenuItem(value: 'AC Repair', child: Text('AC Repair')),
                            DropdownMenuItem(value: 'Carpentry', child: Text('Carpentry')),
                            DropdownMenuItem(value: 'Beauty', child: Text('Beauty')),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              selectedCategory = value ?? 'Electrical';
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: platformFeePercentageController,
                          decoration: const InputDecoration(
                            labelText: 'Platform Fee (%) *',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value?.isEmpty ?? true) return 'Required';
                            final fee = double.tryParse(value!);
                            if (fee == null) return 'Invalid';
                            if (fee < 0 || fee > 100) return '0-100%';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('Active'),
                    value: isActive,
                    onChanged: (value) {
                      setDialogState(() {
                        isActive = value ?? true;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate() && selectedProviderId != null) {
                  try {
                    final adminService = ref.read(adminServiceProvider);
                    await adminService.createService(
                      providerId: selectedProviderId!,
                      serviceName: nameController.text.trim(),
                      description: descriptionController.text.trim(),
                      basePrice: double.parse(basePriceController.text),
                      duration: int.parse(durationController.text),
                      category: selectedCategory,
                      platformFeePercentage: double.parse(platformFeePercentageController.text),
                    );

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ Service created successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('❌ Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditServiceDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> service) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: service['serviceName'] ?? '');
    final descriptionController = TextEditingController(text: service['description'] ?? '');
    final basePriceController = TextEditingController(text: (service['basePrice'] ?? 0.0).toString());
    final platformFeePercentageController = TextEditingController(
      text: (service['platformFeePercentage'] ?? 10.0).toString(),
    );
    final durationController = TextEditingController(text: (service['duration'] ?? 0).toString());
    String selectedCategory = service['category'] ?? 'Electrical';
    bool isActive = service['isActive'] ?? true;
    final providerId = service['providerId'] ?? '';
    final serviceId = service['id'] ?? '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Service'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Service Name *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value?.isEmpty ?? true ? 'Please enter service name' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: basePriceController,
                          decoration: const InputDecoration(
                            labelText: 'Base Price (₹) *',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value?.isEmpty ?? true) return 'Please enter base price';
                            if (double.tryParse(value!) == null) return 'Invalid price';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: durationController,
                          decoration: const InputDecoration(
                            labelText: 'Duration (min) *',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value?.isEmpty ?? true) return 'Please enter duration';
                            if (int.tryParse(value!) == null) return 'Invalid duration';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Category *',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Electrical', child: Text('Electrical')),
                            DropdownMenuItem(value: 'Plumbing', child: Text('Plumbing')),
                            DropdownMenuItem(value: 'Cleaning', child: Text('Cleaning')),
                            DropdownMenuItem(value: 'AC Repair', child: Text('AC Repair')),
                            DropdownMenuItem(value: 'Carpentry', child: Text('Carpentry')),
                            DropdownMenuItem(value: 'Beauty', child: Text('Beauty')),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              selectedCategory = value ?? 'Electrical';
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: platformFeePercentageController,
                          decoration: const InputDecoration(
                            labelText: 'Platform Fee (%) *',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value?.isEmpty ?? true) return 'Required';
                            final fee = double.tryParse(value!);
                            if (fee == null) return 'Invalid';
                            if (fee < 0 || fee > 100) return '0-100%';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('Active'),
                    value: isActive,
                    onChanged: (value) {
                      setDialogState(() {
                        isActive = value ?? true;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    final adminService = ref.read(adminServiceProvider);
                    await adminService.updateService(
                      providerId: providerId,
                      serviceId: serviceId,
                      serviceName: nameController.text.trim(),
                      description: descriptionController.text.trim(),
                      basePrice: double.parse(basePriceController.text),
                      duration: int.parse(durationController.text),
                      category: selectedCategory,
                      platformFeePercentage: double.parse(platformFeePercentageController.text),
                      isActive: isActive,
                    );

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ Service updated successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('❌ Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteServiceDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Service'),
        content: Text(
          'Are you sure you want to delete "${service['serviceName'] ?? 'this service'}"?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final adminService = ref.read(adminServiceProvider);
                await adminService.deleteService(
                  providerId: service['providerId'] ?? '',
                  serviceId: service['id'] ?? '',
                );

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Service deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}


