import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../app_state/app_controller.dart';

class OrderReviewPage extends ConsumerWidget {
  const OrderReviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final draft = state.customerDraft;

    if (state.cart.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order Review')),
        body: Center(
          child: EmptyStateCard(
            title: 'No items to review',
            message: 'Cart is empty.',
            actionLabel: 'Back to catalog',
            onAction: () => context.go('/'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Review Your Order')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customer details',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Text('Name: ${draft.name}'),
                Text('Mobile: ${draft.mobileNumber}'),
                Text('Barangay: ${draft.barangay}'),
                Text(
                  'Fulfillment: ${displayFulfillment(draft.fulfillmentMethod)}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Products',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                for (final item in state.cart) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.productName),
                    subtitle: Text('${item.quantity} × ${item.unit}'),
                    trailing: Text(formatPesos(item.estimatedSubtotalCentavos)),
                  ),
                  const Divider(),
                ],
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Estimated total',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      formatPesos(state.cartTotalCentavos),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => context.pop(),
                child: const Text('Edit Details'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: state.submittingOrder
                    ? null
                    : () async {
                        final orderId = await ref
                            .read(appControllerProvider.notifier)
                            .submitOrder();
                        if (!context.mounted || orderId == null) {
                          return;
                        }
                        context.go('/order-success/$orderId');
                      },
                child: Text(
                  state.submittingOrder ? 'Submitting...' : 'Submit Order',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
