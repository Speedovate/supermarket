import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_models.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/admin_scaffold.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../app_state/app_controller.dart';

class AdminOrderDetailPage extends ConsumerStatefulWidget {
  const AdminOrderDetailPage({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<AdminOrderDetailPage> createState() =>
      _AdminOrderDetailPageState();
}

class _AdminOrderDetailPageState extends ConsumerState<AdminOrderDetailPage> {
  late OrderRequest editableOrder;
  bool initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initialized) {
      final order = ref
          .read(appControllerProvider)
          .orders
          .firstWhere((item) => item.id == widget.orderId);
      editableOrder = order;
      initialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final matches = state.orders
        .where((item) => item.id == widget.orderId)
        .toList();
    final order = matches.isEmpty ? null : matches.first;

    if (order == null) {
      return const Scaffold(body: Center(child: Text('Order not found.')));
    }

    return AdminScaffold(
      title: order.referenceNumber,
      selectedRoute: '/admin/orders',
      actions: [
        TextButton.icon(
          onPressed: _saveOrder,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Save Changes'),
        ),
      ],
      child: ListView(
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.customer.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text('Mobile: ${order.customer.mobileNumber}'),
                Text('Barangay: ${order.customer.barangay}'),
                if (order.customer.addressLandmark.trim().isNotEmpty)
                  Text('Address / landmark: ${order.customer.addressLandmark}'),
                Text(
                  'Fulfillment: ${displayFulfillment(order.fulfillmentMethod)}',
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
                  'Order Items',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < editableOrder.items.length; i++) ...[
                  _OrderItemEditor(
                    item: editableOrder.items[i],
                    onChanged: (item) {
                      setState(() {
                        final items = [...editableOrder.items];
                        items[i] = item;
                        editableOrder = editableOrder.copyWith(items: items);
                      });
                    },
                  ),
                  const Divider(height: 28),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<OrderStatus>(
                  initialValue: editableOrder.status,
                  decoration: const InputDecoration(labelText: 'Order status'),
                  items: OrderStatus.values
                      .map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(displayStatus(status)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    if (value != null) {
                      editableOrder = editableOrder.copyWith(status: value);
                    }
                  }),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  initialValue: editableOrder.quotationNote ?? '',
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Customer-facing quotation note',
                  ),
                  onChanged: (value) => editableOrder = editableOrder.copyWith(
                    quotationNote: value.trim().isEmpty ? null : value.trim(),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  initialValue: editableOrder.internalAdminNote ?? '',
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Internal admin note',
                  ),
                  onChanged: (value) => editableOrder = editableOrder.copyWith(
                    internalAdminNote: value.trim().isEmpty
                        ? null
                        : value.trim(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveOrder() async {
    final quotedItems = editableOrder.items
        .map(
          (item) => item.copyWith(
            quotedSubtotalCentavos:
                item.approvedQuantity * item.quotedUnitPriceCentavos,
          ),
        )
        .toList();
    final quotedTotal = quotedItems.fold<int>(
      0,
      (sum, item) => sum + item.quotedSubtotalCentavos,
    );
    final current = ref
        .read(appControllerProvider)
        .orders
        .firstWhere((item) => item.id == widget.orderId);
    final history = editableOrder.status == current.status
        ? current.statusHistory
        : [
            StatusHistoryEntry(
              previousStatus: current.status,
              newStatus: editableOrder.status,
              timestamp: DateTime.now(),
              adminUserId:
                  ref.read(appControllerProvider).adminSession?.uid ??
                  'demo-admin',
            ),
            ...current.statusHistory,
          ];

    final order = editableOrder.copyWith(
      items: quotedItems,
      finalQuotedTotalCentavos: quotedTotal,
      updatedAt: DateTime.now(),
      statusHistory: history,
    );
    await ref.read(appControllerProvider.notifier).updateOrder(order);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Order updated.')));
    }
  }
}

class _OrderItemEditor extends StatelessWidget {
  const _OrderItemEditor({required this.item, required this.onChanged});

  final OrderItem item;
  final ValueChanged<OrderItem> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.productName,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text('Requested: ${item.requestedQuantity} ${item.unit}'),
        Text('Reference: ${formatPesos(item.referenceUnitPriceCentavos)}'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<AvailabilityStatus>(
                initialValue: item.availabilityStatus,
                decoration: const InputDecoration(labelText: 'Availability'),
                items: AvailabilityStatus.values
                    .map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(displayAvailability(status)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    onChanged(item.copyWith(availabilityStatus: value));
                  }
                },
              ),
            ),
            SizedBox(
              width: 160,
              child: TextFormField(
                initialValue: '${item.approvedQuantity}',
                decoration: const InputDecoration(
                  labelText: 'Approved quantity',
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) => onChanged(
                  item.copyWith(
                    approvedQuantity: int.tryParse(value.trim()) ?? 0,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 180,
              child: TextFormField(
                initialValue: (item.quotedUnitPriceCentavos / 100)
                    .toStringAsFixed(2),
                decoration: const InputDecoration(labelText: 'Quoted price'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (value) => onChanged(
                  item.copyWith(
                    quotedUnitPriceCentavos:
                        ((double.tryParse(value.trim()) ?? 0) * 100).round(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
