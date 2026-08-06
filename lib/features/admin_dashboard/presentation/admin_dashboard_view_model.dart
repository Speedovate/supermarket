import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_models.dart';
import '../../app_state/app_controller.dart';

class AdminDashboardMetric {
  const AdminDashboardMetric(this.label, this.value);

  final String label;
  final int value;
}

class AdminBestSellerItem {
  const AdminBestSellerItem({
    required this.product,
    required this.orderedQuantity,
    required this.orderCount,
  });

  final Product product;
  final int orderedQuantity;
  final int orderCount;
}

class AdminDashboardViewModelState {
  const AdminDashboardViewModelState({
    required this.metrics,
    required this.recentOrders,
    required this.totalOrders,
    required this.activeProducts,
    required this.categories,
    required this.bestSellers,
  });

  final List<AdminDashboardMetric> metrics;
  final List<OrderRequest> recentOrders;
  final int totalOrders;
  final int activeProducts;
  final int categories;
  final List<AdminBestSellerItem> bestSellers;
}

String _dashboardMetricLabel(OrderStatus status) {
  return switch (status) {
    OrderStatus.newRequest => 'Orders',
    _ => status.name,
  };
}

final adminDashboardViewModelProvider = Provider<AdminDashboardViewModelState>((
  ref,
) {
  final state = ref.watch(appControllerProvider);
  final activeProducts = state.products.where((item) => item.isActive).length;
  final categories = state.categories.length;
  final metrics = OrderStatus.values
      .map(
        (status) => AdminDashboardMetric(
          _dashboardMetricLabel(status),
          state.orders.where((order) => order.status == status).length,
        ),
      )
      .toList();
  final bestSellers = state.products
      .where((item) => item.isActive)
      .map(
        (product) => AdminBestSellerItem(
          product: product,
          orderedQuantity: product.validOrderedQuantity,
          orderCount: product.validOrderCount,
        ),
      )
      .where((item) => item.orderedQuantity > 0 || item.orderCount > 0)
      .toList()
    ..sort((a, b) {
      final quantityCompare = b.orderedQuantity.compareTo(a.orderedQuantity);
      if (quantityCompare != 0) {
        return quantityCompare;
      }
      final orderCountCompare = b.orderCount.compareTo(a.orderCount);
      if (orderCountCompare != 0) {
        return orderCountCompare;
      }
      final aLast = a.product.lastValidOrderAt;
      final bLast = b.product.lastValidOrderAt;
      if (aLast == null && bLast == null) {
        return a.product.name.compareTo(b.product.name);
      }
      if (aLast == null) {
        return 1;
      }
      if (bLast == null) {
        return -1;
      }
      return bLast.compareTo(aLast);
    });

  return AdminDashboardViewModelState(
    metrics: metrics,
    recentOrders: [...state.orders]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    totalOrders: state.orders.length,
    activeProducts: activeProducts,
    categories: categories,
    bestSellers: bestSellers,
  );
});
