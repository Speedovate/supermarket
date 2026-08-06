import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import 'admin_dashboard_view_model.dart';

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(adminDashboardViewModelProvider);
    final width = MediaQuery.of(context).size.width;
    final metrics = <AdminDashboardMetric>[
      AdminDashboardMetric('Orders', vm.totalOrders),
      AdminDashboardMetric('Products', vm.activeProducts),
      AdminDashboardMetric('Best Sellers', vm.bestSellers.length),
      AdminDashboardMetric('Categories', vm.categories),
    ];
    final visibleMetrics = metrics.take(4).toList();
    final metricColumns = width >= 1320
        ? 4
        : width >= 760
        ? 2
        : 2;

    return ListView(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: metricColumns,
            mainAxisSpacing: 20,
            crossAxisSpacing: 20,
            mainAxisExtent: 154,
          ),
          itemCount: visibleMetrics.length,
          itemBuilder: (context, index) {
            final metric = visibleMetrics[index];
            const accent = AppColors.logoBlue;
            const tint = Color(0xFFF2F6FF);
            return Container(
              padding: const EdgeInsets.fromLTRB(28, 22, 28, 22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFEFF2FA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metric.label,
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: tint,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      NumberFormat.decimalPattern().format(metric.value),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 32,
                        height: 1.05,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
