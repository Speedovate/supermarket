import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/admin_scaffold.dart';
import '../../../core/widgets/common_widgets.dart';
import 'admin_dashboard_view_model.dart';

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(adminDashboardViewModelProvider);
    final metrics = <AdminDashboardMetric>[
      AdminDashboardMetric('Total Products', vm.activeProducts),
      AdminDashboardMetric('Total Categories', vm.categories),
      ...vm.metrics,
    ];

    return AdminScaffold(
      title: 'Dashboard',
      selectedRoute: '/admin/dashboard',
      child: ListView(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A172A91),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dashboard Overview',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Operational snapshot for products, categories, and incoming order requests.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final metric in metrics.take(5))
                SizedBox(
                  width: 210,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x12172A91),
                          blurRadius: 18,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          metric.label,
                          style: const TextStyle(color: Color(0xFF667085)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          NumberFormat.decimalPattern().format(metric.value),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A172A91),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recent Order Requests',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                if (vm.recentOrders.isEmpty)
                  const EmptyStateCard(
                    title: 'No order requests',
                    message: 'Customer submissions will appear here.',
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        const Color(0xFFF4F7FF),
                      ),
                      columns: const [
                        DataColumn(label: Text('Customer')),
                        DataColumn(label: Text('Barangay')),
                        DataColumn(label: Text('Method')),
                        DataColumn(label: Text('Estimate')),
                        DataColumn(label: Text('Status')),
                      ],
                      rows: vm.recentOrders.take(8).map((order) {
                        return DataRow(
                          cells: [
                            DataCell(Text(order.customer.name)),
                            DataCell(Text(order.customer.barangay)),
                            DataCell(
                              Text(displayFulfillment(order.fulfillmentMethod)),
                            ),
                            DataCell(
                              Text(formatPesos(order.estimatedTotalCentavos)),
                            ),
                            DataCell(StatusBadge(status: order.status)),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
