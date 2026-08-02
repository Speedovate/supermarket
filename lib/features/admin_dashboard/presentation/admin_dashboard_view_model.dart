import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_models.dart';
import '../../app_state/app_controller.dart';

class AdminDashboardMetric {
  const AdminDashboardMetric(this.label, this.value);

  final String label;
  final int value;
}

class AdminDashboardViewModelState {
  const AdminDashboardViewModelState({
    required this.metrics,
    required this.recentOrders,
    required this.activeProducts,
    required this.categories,
  });

  final List<AdminDashboardMetric> metrics;
  final List<OrderRequest> recentOrders;
  final int activeProducts;
  final int categories;
}

final adminDashboardViewModelProvider = Provider<AdminDashboardViewModelState>((
  ref,
) {
  final state = ref.watch(appControllerProvider);
  final activeProducts = state.products
      .where((item) => item.isActive && !item.isArchived)
      .length;
  final categories = state.categories.where((item) => !item.isArchived).length;
  final metrics = OrderStatus.values
      .map(
        (status) => AdminDashboardMetric(
          status.name,
          state.orders.where((order) => order.status == status).length,
        ),
      )
      .toList();

  return AdminDashboardViewModelState(
    metrics: metrics,
    recentOrders: [...state.orders]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    activeProducts: activeProducts,
    categories: categories,
  );
});
