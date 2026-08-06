import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/admin_scaffold.dart';
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
import '../features/settings/presentation/admin_profile_page.dart';
import '../features/settings/presentation/admin_settings_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(routerRefreshProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final appState = ref.read(appControllerProvider);
      final authToken = appState.adminSession?.uid;
      final initialized = appState.initialized;
      final goingToAdmin = state.uri.path.startsWith('/admin');
      final goingToLogin = state.uri.path == '/admin/login';
      final isAuthed = authToken != null;

      if (!initialized) {
        return null;
      }

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
          final orderId =
              int.tryParse(state.pathParameters['orderId'] ?? '') ?? 0;
          return OrderSuccessPage(orderId: orderId);
        },
      ),
      GoRoute(
        path: '/admin/login',
        builder: (context, state) => const AdminLoginPage(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            AdminShellFrame(currentPath: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/admin/dashboard',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: AdminDashboardPage()),
          ),
          GoRoute(
            path: '/admin/products',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: AdminProductsPage()),
          ),
          GoRoute(
            path: '/admin/categories',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: AdminCategoriesPage()),
          ),
          GoRoute(
            path: '/admin/orders',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: AdminOrdersPage()),
          ),
          GoRoute(
            path: '/admin/orders/:orderId',
            pageBuilder: (context, state) {
              final orderId =
                  int.tryParse(state.pathParameters['orderId'] ?? '') ?? 0;
              return NoTransitionPage(
                child: AdminOrderDetailPage(orderId: orderId),
              );
            },
          ),
          GoRoute(
            path: '/admin/settings',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: AdminSettingsPage()),
          ),
          GoRoute(
            path: '/admin/profile',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: AdminProfilePage()),
          ),
        ],
      ),
    ],
  );
});
