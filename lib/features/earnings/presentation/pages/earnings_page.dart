import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trivora_provider/core/providers/auth_provider.dart';
import 'package:trivora_provider/core/providers/dashboard_provider.dart';
import 'package:trivora_provider/core/services/backend_service.dart';

/// Provider for payments list
final paymentsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final authUser = ref.watch(authStateProvider).valueOrNull;
  final userId = authUser?.uid;
  if (userId == null) return [];
  
  final backendService = ref.watch(backendServiceProvider);
  backendService.initializeData(userId);
  return backendService.getPayments(userId);
});

/// Provider for wallet balance
final walletBalanceProvider = FutureProvider<double>((ref) async {
  final authUser = ref.watch(authStateProvider).valueOrNull;
  final userId = authUser?.uid;
  if (userId == null) return 0.0;
  
  final backendService = ref.watch(backendServiceProvider);
  backendService.initializeData(userId);
  return backendService.getWalletBalance(userId);
});

/// Earnings page showing provider earnings and payment history
class EarningsPage extends ConsumerWidget {
  const EarningsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUserAsync = ref.watch(authStateProvider);
    final authUser = authUserAsync.valueOrNull;
    if (authUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please login to view earnings')),
      );
    }

    final todayEarningsAsync = ref.watch(todayEarningsProvider);
    final paymentsAsync = ref.watch(paymentsProvider);
    final walletBalanceAsync = ref.watch(walletBalanceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Earnings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(paymentsProvider);
              ref.invalidate(walletBalanceProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(paymentsProvider);
          ref.invalidate(walletBalanceProvider);
        },
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Wallet Balance Card
              walletBalanceAsync.when(
                data: (balance) => Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Wallet Balance',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '₹${balance.toStringAsFixed(0)}',
                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                loading: () => const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (_, __) => const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Error loading balance'),
                  ),
                ),
            ),
            const SizedBox(height: 16),
              // Today's Earnings
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Today's Earnings",
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          todayEarningsAsync.when(
                            data: (earnings) => Text(
                              '₹${earnings.toStringAsFixed(0)}',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                            loading: () => const CircularProgressIndicator(),
                            error: (_, __) => const Text('Error'),
                          ),
                        ],
                      ),
                      Icon(
                        Icons.account_balance_wallet,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Payment History',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
              paymentsAsync.when(
                data: (payments) {
                  if (payments.isEmpty) {
                    return const Center(
                    child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('No payments yet'),
                    ),
                  );
                }

                  return Column(
                    children: payments.map((payment) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: Colors.green.withValues(alpha: 0.2),
                          child: const Icon(
                            Icons.payment,
                            color: Colors.green,
                            size: 20,
                          ),
                        ),
                        title: Text('₹${payment['amount']}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              '${_formatDate(payment['createdAt'] as DateTime)} • ${payment['paymentMethod']}',
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Earned: ₹${payment['providerEarning']}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                        trailing: Chip(
                          label: const Text('COMPLETED'),
                          backgroundColor: Colors.green.withValues(alpha: 0.2),
                          labelStyle: const TextStyle(color: Colors.green, fontSize: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                        isThreeLine: true,
                      ),
                    )).toList(),
                    );
                  },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('Error: $error')),
            ),
          ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
