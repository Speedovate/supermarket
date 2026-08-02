import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/app_models.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/admin_scaffold.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../app_state/app_controller.dart';

class AdminOrdersPage extends ConsumerStatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  ConsumerState<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends ConsumerState<AdminOrdersPage> {
  String query = '';
  OrderStatus? statusFilter;
  FulfillmentMethod? methodFilter;

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(appControllerProvider).orders.where((order) {
      final normalized = query.trim().toLowerCase();
      final matchesQuery =
          normalized.isEmpty ||
          order.referenceNumber.toLowerCase().contains(normalized) ||
          order.customer.name.toLowerCase().contains(normalized) ||
          order.customer.mobileNumber.toLowerCase().contains(normalized) ||
          order.customer.barangay.toLowerCase().contains(normalized);
      final matchesStatus =
          statusFilter == null || order.status == statusFilter;
      final matchesMethod =
          methodFilter == null || order.fulfillmentMethod == methodFilter;
      return matchesQuery && matchesStatus && matchesMethod;
    }).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return AdminScaffold(
      title: 'Orders',
      selectedRoute: '/admin/orders',
      child: ListView(
        children: [
          SectionCard(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 300,
                  child: TextField(
                    onChanged: (value) => setState(() => query = value),
                    decoration: const InputDecoration(
                      labelText: 'Search orders',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<OrderStatus?>(
                    initialValue: statusFilter,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: [
                      const DropdownMenuItem<OrderStatus?>(
                        value: null,
                        child: Text('All statuses'),
                      ),
                      ...OrderStatus.values.map(
                        (status) => DropdownMenuItem<OrderStatus?>(
                          value: status,
                          child: Text(displayStatus(status)),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => statusFilter = value),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<FulfillmentMethod?>(
                    initialValue: methodFilter,
                    decoration: const InputDecoration(labelText: 'Method'),
                    items: [
                      const DropdownMenuItem<FulfillmentMethod?>(
                        value: null,
                        child: Text('All methods'),
                      ),
                      ...FulfillmentMethod.values.map(
                        (method) => DropdownMenuItem<FulfillmentMethod?>(
                          value: method,
                          child: Text(displayFulfillment(method)),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => methodFilter = value),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (orders.isEmpty)
            const EmptyStateCard(
              title: 'No order requests',
              message: 'Customer submissions will appear here.',
            )
          else
            ...orders.map(
              (order) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => context.push('/admin/orders/${order.id}'),
                  child: SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                order.referenceNumber,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            StatusBadge(status: order.status),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 20,
                          runSpacing: 10,
                          children: [
                            Text('Customer: ${order.customer.name}'),
                            Text('Mobile: ${order.customer.mobileNumber}'),
                            Text('Barangay: ${order.customer.barangay}'),
                            Text(
                              'Method: ${displayFulfillment(order.fulfillmentMethod)}',
                            ),
                            Text(
                              'Estimated: ${formatPesos(order.estimatedTotalCentavos)}',
                            ),
                            Text(
                              'Quoted: ${formatPesos(order.finalQuotedTotalCentavos)}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
