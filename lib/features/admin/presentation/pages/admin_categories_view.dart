// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trivora_provider/core/services/admin_service.dart';

/// Service Categories Management View for Admin
class AdminCategoriesView extends ConsumerStatefulWidget {
  const AdminCategoriesView({super.key});

  @override
  ConsumerState<AdminCategoriesView> createState() => _AdminCategoriesViewState();
}

class _AdminCategoriesViewState extends ConsumerState<AdminCategoriesView> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final adminService = ref.read(adminServiceProvider);
    final categoriesStream = adminService.getAllServiceCategories();

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
                  'Service Categories Management',
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
                    onPressed: () => _showCreateCategoryDialog(context, ref),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Create Category'),
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
          
          // Search Bar
          TextField(
            decoration: InputDecoration(
              hintText: 'Search categories by name...',
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
          const SizedBox(height: 24),
          
          // Categories Grid/List
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: categoriesStream,
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

                var categories = snapshot.data ?? [];

                // Apply search filter
                if (_searchQuery.isNotEmpty) {
                  categories = categories.where((category) {
                    final name = (category['name'] ?? '').toString().toLowerCase();
                    return name.contains(_searchQuery);
                  }).toList();
                }

                if (categories.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.category_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No categories found',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create a new category to get started',
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
                        dataRowMinHeight: 48,
                        dataRowMaxHeight: 72,
                        columns: const [
                          DataColumn(label: Text('Category Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Default Fee %', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Created', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Actions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                        ],
                        rows: categories.map((category) {
                          final isActive = category['isActive'] ?? true;
                          final defaultFee = (category['defaultPlatformFeePercentage'] ?? 10.0).toDouble();
                          final createdAt = category['createdAt'];

                          return DataRow(
                            cells: [
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _getIconForCategory(category['icon'] ?? 'build'),
                                      size: 20,
                                      color: Colors.blue.shade700,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      category['name'] ?? 'Unknown',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 250,
                                  child: Text(
                                    category['description'] ?? 'No description',
                                    style: const TextStyle(fontSize: 12),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  '${defaultFee.toStringAsFixed(1)}%',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
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
                                Text(
                                  createdAt != null
                                      ? _formatDate(createdAt)
                                      : 'N/A',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 18),
                                      color: Colors.blue,
                                      onPressed: () => _showEditCategoryDialog(context, ref, category),
                                      tooltip: 'Edit',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, size: 18),
                                      color: Colors.red,
                                      onPressed: () => _showDeleteCategoryDialog(context, ref, category),
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

  IconData _getIconForCategory(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'electrical':
      case 'electric':
        return Icons.electrical_services;
      case 'plumbing':
      case 'plumber':
        return Icons.plumbing;
      case 'cleaning':
        return Icons.cleaning_services;
      case 'ac':
      case 'ac repair':
        return Icons.ac_unit;
      case 'carpentry':
      case 'carpenter':
        return Icons.carpenter;
      case 'beauty':
        return Icons.face;
      default:
        return Icons.build;
    }
  }

  String _formatDate(dynamic timestamp) {
    try {
      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        return '${date.day}/${date.month}/${date.year}';
      }
      return 'N/A';
    } catch (e) {
      return 'N/A';
    }
  }

  void _showCreateCategoryDialog(BuildContext context, WidgetRef ref) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final feePercentageController = TextEditingController(text: '10.0');
    String selectedIcon = 'build';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create New Category'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Category Name *',
                      border: OutlineInputBorder(),
                      hintText: 'e.g., Electrical, Plumbing',
                    ),
                    validator: (value) => value?.isEmpty ?? true ? 'Please enter category name' : null,
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
                        child: DropdownButtonFormField<String>(
                          value: selectedIcon,
                          decoration: const InputDecoration(
                            labelText: 'Icon',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'build', child: Text('Build (Default)')),
                            DropdownMenuItem(value: 'electrical', child: Text('Electrical')),
                            DropdownMenuItem(value: 'plumbing', child: Text('Plumbing')),
                            DropdownMenuItem(value: 'cleaning', child: Text('Cleaning')),
                            DropdownMenuItem(value: 'ac', child: Text('AC Repair')),
                            DropdownMenuItem(value: 'carpentry', child: Text('Carpentry')),
                            DropdownMenuItem(value: 'beauty', child: Text('Beauty')),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              selectedIcon = value ?? 'build';
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: feePercentageController,
                          decoration: const InputDecoration(
                            labelText: 'Default Fee (%) *',
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
                    await adminService.createServiceCategory(
                      name: nameController.text.trim(),
                      description: descriptionController.text.trim(),
                      icon: selectedIcon,
                      defaultPlatformFeePercentage: double.parse(feePercentageController.text),
                    );

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ Category created successfully'),
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

  void _showEditCategoryDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> category) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: category['name'] ?? '');
    final descriptionController = TextEditingController(text: category['description'] ?? '');
    final feePercentageController = TextEditingController(
      text: (category['defaultPlatformFeePercentage'] ?? 10.0).toString(),
    );
    String selectedIcon = category['icon'] ?? 'build';
    bool isActive = category['isActive'] ?? true;
    final categoryId = category['id'] ?? '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Category'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Category Name *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value?.isEmpty ?? true ? 'Please enter category name' : null,
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
                        child: DropdownButtonFormField<String>(
                          value: selectedIcon,
                          decoration: const InputDecoration(
                            labelText: 'Icon',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'build', child: Text('Build (Default)')),
                            DropdownMenuItem(value: 'electrical', child: Text('Electrical')),
                            DropdownMenuItem(value: 'plumbing', child: Text('Plumbing')),
                            DropdownMenuItem(value: 'cleaning', child: Text('Cleaning')),
                            DropdownMenuItem(value: 'ac', child: Text('AC Repair')),
                            DropdownMenuItem(value: 'carpentry', child: Text('Carpentry')),
                            DropdownMenuItem(value: 'beauty', child: Text('Beauty')),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              selectedIcon = value ?? 'build';
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: feePercentageController,
                          decoration: const InputDecoration(
                            labelText: 'Default Fee (%) *',
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
                    await adminService.updateServiceCategory(
                      categoryId: categoryId,
                      name: nameController.text.trim(),
                      description: descriptionController.text.trim(),
                      icon: selectedIcon,
                      defaultPlatformFeePercentage: double.parse(feePercentageController.text),
                      isActive: isActive,
                    );

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ Category updated successfully'),
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

  void _showDeleteCategoryDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text(
          'Are you sure you want to delete "${category['name'] ?? 'this category'}"?\n\nThis action cannot be undone. Make sure no services are using this category.',
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
                await adminService.deleteServiceCategory(
                  categoryId: category['id'] ?? '',
                );

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Category deleted successfully'),
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

