import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trivora_provider/core/providers/auth_provider.dart';
import 'package:trivora_provider/core/services/payment_methods_service.dart';

/// Payment Methods Page - Manage payment method preferences
class PaymentMethodsPage extends ConsumerStatefulWidget {
  const PaymentMethodsPage({super.key});

  @override
  ConsumerState<PaymentMethodsPage> createState() => _PaymentMethodsPageState();
}

class _PaymentMethodsPageState extends ConsumerState<PaymentMethodsPage> {
  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authStateProvider).valueOrNull;
    if (authUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please login to view payment methods')),
      );
    }

    final paymentMethodsService = ref.watch(paymentMethodsServiceProvider);
    final availableMethods = paymentMethodsService.getAvailablePaymentMethods();
    final preferencesStream = paymentMethodsService.getPaymentMethodPreferencesStream(authUser.uid);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Methods'),
      ),
      body: StreamBuilder<Map<String, bool>>(
        stream: preferencesStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final preferences = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Payment Methods',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choose which payment methods you want to accept from customers',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ...availableMethods.map((method) {
                final isEnabled = preferences[method.id] ?? method.isEnabled;
                return _buildPaymentMethodCard(
                  context,
                  method.copyWith(isEnabled: isEnabled),
                  authUser.uid,
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPaymentMethodCard(
    BuildContext context,
    PaymentMethod method,
    String providerId,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: SwitchListTile(
        secondary: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: method.isEnabled
                ? Theme.of(context).colorScheme.primaryContainer
                : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            method.icon,
            style: const TextStyle(fontSize: 24),
          ),
        ),
        title: Text(
          method.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: method.isEnabled ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Text(method.description),
        value: method.isEnabled,
        onChanged: (value) {
          _updatePaymentMethod(providerId, method.id, value);
        },
      ),
    );
  }

  Future<void> _updatePaymentMethod(String providerId, String methodId, bool isEnabled) async {
    try {
      final paymentMethodsService = ref.read(paymentMethodsServiceProvider);
      await paymentMethodsService.updatePaymentMethodPreference(
        providerId: providerId,
        methodId: methodId,
        isEnabled: isEnabled,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEnabled
                ? '${methodId.toUpperCase()} enabled'
                : '${methodId.toUpperCase()} disabled'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
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

