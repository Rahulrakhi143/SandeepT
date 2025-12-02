import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trivora_provider/core/services/service_categories_service.dart';
import 'package:trivora_provider/features/services/presentation/pages/services_page.dart';

/// Add Service Dialog with Firebase categories
class AddServiceDialogWidget extends ConsumerStatefulWidget {
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final TextEditingController priceController;
  final TextEditingController durationController;

  const AddServiceDialogWidget({
    super.key,
    required this.nameController,
    required this.descriptionController,
    required this.priceController,
    required this.durationController,
  });

  @override
  ConsumerState<AddServiceDialogWidget> createState() => _AddServiceDialogState();
}

class _AddServiceDialogState extends ConsumerState<AddServiceDialogWidget> {
  String? selectedCategory;

  @override
  Widget build(BuildContext context) {
    // Get categories from Firebase
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    return AlertDialog(
      title: const Text('Add Service'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: widget.nameController,
              decoration: const InputDecoration(
                labelText: 'Service Name',
                hintText: 'e.g., Plumbing',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            categoriesAsync.when(
              data: (categories) {
                // Initialize selectedCategory if not set
                if (selectedCategory == null && categories.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    setState(() {
                      selectedCategory = categories.first;
                    });
                  });
                }

                return DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: categories
                      .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedCategory = value;
                      });
                      widget.nameController.text = value;
                    }
                  },
                );
              },
              loading: () => DropdownButtonFormField<String>(
                value: null,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                  suffixIcon: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                items: const [],
                onChanged: null,
              ),
              error: (error, stack) {
                // Fallback to default categories on error
                final defaultCategories = ref.read(serviceCategoriesServiceProvider).getDefaultCategories();
                if (selectedCategory == null && defaultCategories.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    setState(() {
                      selectedCategory = defaultCategories.first;
                    });
                  });
                }

                return DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: defaultCategories
                      .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedCategory = value;
                      });
                      widget.nameController.text = value;
                    }
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: widget.descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Service description',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: widget.priceController,
              decoration: const InputDecoration(
                labelText: 'Base Price (₹)',
                hintText: '500',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: widget.durationController,
              decoration: const InputDecoration(
                labelText: 'Duration (minutes)',
                hintText: '60',
                border: OutlineInputBorder(),
              ),
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
            if (widget.nameController.text.isNotEmpty &&
                widget.priceController.text.isNotEmpty &&
                widget.durationController.text.isNotEmpty &&
                selectedCategory != null) {
              try {
                await ref.read(servicesProvider.notifier).addService({
                  'serviceName': widget.nameController.text,
                  'description': widget.descriptionController.text.isNotEmpty
                      ? widget.descriptionController.text
                      : 'Professional ${widget.nameController.text} service',
                  'basePrice': int.tryParse(widget.priceController.text) ?? 500,
                  'duration': int.tryParse(widget.durationController.text) ?? 60,
                  'category': selectedCategory!,
                });
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Service added successfully!'),
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
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please fill all required fields including category'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

