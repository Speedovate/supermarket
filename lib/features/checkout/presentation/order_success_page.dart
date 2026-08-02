import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/common_widgets.dart';
import '../../app_state/app_controller.dart';

class OrderSuccessPage extends ConsumerWidget {
  const OrderSuccessPage({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(appControllerProvider).orders;
    final order = orders.where((item) => item.id == orderId).isEmpty
        ? null
        : orders.firstWhere((item) => item.id == orderId);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: EmptyStateCard(
              title: 'Your order request has been received.',
              message: order == null
                  ? 'Andrew\'s Supermarket will check product availability and contact you through your mobile number with the final quotation.'
                  : 'Reference number: ${order.referenceNumber}\n\nAndrew\'s Supermarket will check product availability and contact you through your mobile number with the final quotation. This order is not yet confirmed.',
              actionLabel: 'Return to homepage',
              onAction: () => context.go('/'),
            ),
          ),
        ),
      ),
    );
  }
}
