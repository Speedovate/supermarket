import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/admin_auth/presentation/admin_login_page.dart';
import '../features/admin_dashboard/presentation/admin_dashboard_page.dart';
import '../features/app_state/app_controller.dart';
import '../features/catalog/presentation/catalog_page.dart';
import '../features/category_management/presentation/admin_categories_page.dart';
import '../features/checkout/presentation/order_review_page.dart';
import '../features/checkout/presentation/order_success_page.dart';
import '../features/order_management/presentation/admin_order_detail_page.dart';
import '../features/order_management/presentation/admin_orders_page.dart';
import '../features/product_management/presentation/admin_products_page.dart';
import '../features/settings/presentation/admin_settings_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authToken = ref.watch(
    appControllerProvider.select((state) => state.adminSession?.uid),
  );
  final refresh = ref.watch(routerRefreshProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final goingToAdmin = state.uri.path.startsWith('/admin');
      final goingToLogin = state.uri.path == '/admin/login';
      final isAuthed = authToken != null;

      if (goingToAdmin && !goingToLogin && !isAuthed) {
        return '/admin/login';
      }

      if (goingToLogin && isAuthed) {
        return '/admin/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const CatalogPage()),
      GoRoute(
        path: '/order-review',
        builder: (context, state) => const OrderReviewPage(),
      ),
      GoRoute(
        path: '/order-success/:orderId',
        builder: (context, state) {
          final orderId = state.pathParameters['orderId'] ?? '';
          return OrderSuccessPage(orderId: orderId);
        },
      ),
      GoRoute(
        path: '/admin/login',
        builder: (context, state) => const AdminLoginPage(),
      ),
      GoRoute(
        path: '/admin/dashboard',
        builder: (context, state) => const AdminDashboardPage(),
      ),
      GoRoute(
        path: '/admin/products',
        builder: (context, state) => const AdminProductsPage(),
      ),
      GoRoute(
        path: '/admin/categories',
        builder: (context, state) => const AdminCategoriesPage(),
      ),
      GoRoute(
        path: '/admin/orders',
        builder: (context, state) => const AdminOrdersPage(),
      ),
      GoRoute(
        path: '/admin/orders/:orderId',
        builder: (context, state) {
          final orderId = state.pathParameters['orderId'] ?? '';
          return AdminOrderDetailPage(orderId: orderId);
        },
      ),
      GoRoute(
        path: '/admin/settings',
        builder: (context, state) => const AdminSettingsPage(),
      ),
    ],
  );
});
