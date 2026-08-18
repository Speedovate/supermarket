import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_models.dart';
import '../../../core/utils/formatters.dart';
import '../../app_state/app_controller.dart';

class AdminDashboardMetric {
  const AdminDashboardMetric(this.label, this.value);

  final String label;
  final int value;
}

class AdminSalesPoint {
  const AdminSalesPoint({
    required this.date,
    required this.salesCentavos,
    required this.orderCount,
  });

  final DateTime date;
  final int salesCentavos;
  final int orderCount;
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
    required this.salesPoints,
    required this.filteredSalesCentavos,
    required this.filteredSalesOrders,
  });

  final List<AdminDashboardMetric> metrics;
  final List<OrderRequest> recentOrders;
  final int totalOrders;
  final int activeProducts;
  final int categories;
  final List<AdminBestSellerItem> bestSellers;
  final List<AdminSalesPoint> salesPoints;
  final int filteredSalesCentavos;
  final int filteredSalesOrders;
}

String _dashboardMetricLabel(OrderStatus status) {
  return switch (status) {
    OrderStatus.waiting => 'Orders',
    _ => displayStatus(status),
  };
}

class AdminDashboardSalesFilter {
  const AdminDashboardSalesFilter({this.startDate, this.endDate});

  final DateTime? startDate;
  final DateTime? endDate;
}

final adminDashboardViewModelProvider =
    Provider.family<AdminDashboardViewModelState, AdminDashboardSalesFilter>((
      ref,
      filter,
    ) {
      final state = ref.watch(appControllerProvider);
      final activeProducts = state.products.where((item) => item.active).length;
      final categories = state.categories.length;
      final metrics = OrderStatus.values
          .map(
            (status) => AdminDashboardMetric(
              _dashboardMetricLabel(status),
              state.orders.where((order) => order.status == status).length,
            ),
          )
          .toList();
      final sellerStats =
          <int, ({int quantity, int count, DateTime? lastOrderAt})>{};
      for (final order in state.orders) {
        final countsTowardBestSellers = {
          OrderStatus.ready,
          OrderStatus.completed,
        }.contains(order.status);
        if (!countsTowardBestSellers) {
          continue;
        }
        for (final item in order.items) {
          final current =
              sellerStats[item.productId] ??
              (quantity: 0, count: 0, lastOrderAt: null);
          sellerStats[item.productId] = (
            quantity: current.quantity + item.requestedQuantity,
            count: current.count + 1,
            lastOrderAt:
                current.lastOrderAt == null ||
                    order.updatedAt.isAfter(current.lastOrderAt!)
                ? order.updatedAt
                : current.lastOrderAt,
          );
        }
      }

      final bestSellers =
          state.products
              .where((item) => item.active)
              .map((product) {
                final stats =
                    sellerStats[product.id] ??
                    (quantity: 0, count: 0, lastOrderAt: null);
                return (
                  item: AdminBestSellerItem(
                    product: product,
                    orderedQuantity: stats.quantity,
                    orderCount: stats.count,
                  ),
                  lastOrderAt: stats.lastOrderAt,
                );
              })
              .where(
                (entry) =>
                    entry.item.orderedQuantity > 0 || entry.item.orderCount > 0,
              )
              .toList()
            ..sort((a, b) {
              final quantityCompare = b.item.orderedQuantity.compareTo(
                a.item.orderedQuantity,
              );
              if (quantityCompare != 0) {
                return quantityCompare;
              }
              final orderCountCompare = b.item.orderCount.compareTo(
                a.item.orderCount,
              );
              if (orderCountCompare != 0) {
                return orderCountCompare;
              }
              final aLast = a.lastOrderAt;
              final bLast = b.lastOrderAt;
              if (aLast == null && bLast == null) {
                return a.item.product.name.compareTo(b.item.product.name);
              }
              if (aLast == null) {
                return 1;
              }
              if (bLast == null) {
                return -1;
              }
              return bLast.compareTo(aLast);
            });

      final countedSalesStatuses = {OrderStatus.ready, OrderStatus.completed};
      final filteredOrders = state.orders.where((order) {
        if (!countedSalesStatuses.contains(order.status)) {
          return false;
        }
        final orderDate = DateTime(
          order.createdAt.year,
          order.createdAt.month,
          order.createdAt.day,
        );
        final startDate = filter.startDate == null
            ? null
            : DateTime(
                filter.startDate!.year,
                filter.startDate!.month,
                filter.startDate!.day,
              );
        final endDate = filter.endDate == null
            ? null
            : DateTime(
                filter.endDate!.year,
                filter.endDate!.month,
                filter.endDate!.day,
              );
        final matchesStart =
            startDate == null || !orderDate.isBefore(startDate);
        final matchesEnd = endDate == null || !orderDate.isAfter(endDate);
        return matchesStart && matchesEnd;
      }).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      final salesByDay = <DateTime, ({int salesCentavos, int orderCount})>{};
      for (final order in filteredOrders) {
        final date = DateTime(
          order.createdAt.year,
          order.createdAt.month,
          order.createdAt.day,
        );
        final current = salesByDay[date] ?? (salesCentavos: 0, orderCount: 0);
        salesByDay[date] = (
          salesCentavos: current.salesCentavos + order.finalQuotedTotalCentavos,
          orderCount: current.orderCount + 1,
        );
      }

      final effectiveStartDate =
          filter.startDate == null && salesByDay.isNotEmpty
          ? salesByDay.keys.reduce((a, b) => a.isBefore(b) ? a : b)
          : filter.startDate == null
          ? null
          : DateTime(
              filter.startDate!.year,
              filter.startDate!.month,
              filter.startDate!.day,
            );
      final effectiveEndDate = filter.endDate == null && salesByDay.isNotEmpty
          ? salesByDay.keys.reduce((a, b) => a.isAfter(b) ? a : b)
          : filter.endDate == null
          ? null
          : DateTime(
              filter.endDate!.year,
              filter.endDate!.month,
              filter.endDate!.day,
            );

      final salesPoints = <AdminSalesPoint>[];
      if (effectiveStartDate != null && effectiveEndDate != null) {
        for (
          var date = effectiveStartDate;
          !date.isAfter(effectiveEndDate);
          date = date.add(const Duration(days: 1))
        ) {
          final current = salesByDay[date] ?? (salesCentavos: 0, orderCount: 0);
          salesPoints.add(
            AdminSalesPoint(
              date: date,
              salesCentavos: current.salesCentavos,
              orderCount: current.orderCount,
            ),
          );
        }
      }

      final filteredSalesCentavos = filteredOrders.fold<int>(
        0,
        (sum, order) => sum + order.finalQuotedTotalCentavos,
      );

      return AdminDashboardViewModelState(
        metrics: metrics,
        recentOrders: [...state.orders]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        totalOrders: state.orders.length,
        activeProducts: activeProducts,
        categories: categories,
        bestSellers: bestSellers.map((entry) => entry.item).toList(),
        salesPoints: salesPoints,
        filteredSalesCentavos: filteredSalesCentavos,
        filteredSalesOrders: filteredOrders.length,
      );
    });
