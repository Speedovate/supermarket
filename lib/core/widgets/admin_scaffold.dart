import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/app_state/app_controller.dart';
import 'common_widgets.dart';

class AdminScaffold extends ConsumerWidget {
  const AdminScaffold({
    super.key,
    required this.title,
    required this.selectedRoute,
    required this.child,
    this.actions = const [],
  });

  final String title;
  final String selectedRoute;
  final Widget child;
  final List<Widget> actions;

  static const _items = <({String label, IconData icon, String route})>[
    (
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      route: '/admin/dashboard',
    ),
    (
      label: 'Products',
      icon: Icons.inventory_2_outlined,
      route: '/admin/products',
    ),
    (
      label: 'Categories',
      icon: Icons.category_outlined,
      route: '/admin/categories',
    ),
    (
      label: 'Orders',
      icon: Icons.receipt_long_outlined,
      route: '/admin/orders',
    ),
    (
      label: 'Settings',
      icon: Icons.settings_outlined,
      route: '/admin/settings',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Scaffold(
      drawer: isDesktop
          ? null
          : Drawer(
              backgroundColor: const Color(0xFF172A91),
              child: _NavList(selectedRoute: selectedRoute),
            ),
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          ...actions,
          IconButton(
            tooltip: 'Logout',
            onPressed: () {
              ref.read(appControllerProvider.notifier).logoutAdmin();
              context.go('/admin/login');
            },
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          if (isDesktop)
            Container(
              width: 300,
              margin: const EdgeInsets.fromLTRB(16, 16, 0, 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1E39C8), Color(0xFF11277F)],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x332439B8),
                    blurRadius: 28,
                    offset: Offset(0, 18),
                  ),
                ],
              ),
              child: _NavList(selectedRoute: selectedRoute),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavList extends StatelessWidget {
  const _NavList({required this.selectedRoute});

  final String selectedRoute;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: const BrandLogo(compact: true, onDark: true),
        ),
        const SizedBox(height: 20),
        for (final item in AdminScaffold._items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              selected: selectedRoute == item.route,
              selectedTileColor: Colors.white.withValues(alpha: 0.14),
              iconColor: Colors.white,
              textColor: Colors.white,
              title: Text(
                item.label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              leading: Icon(item.icon),
              onTap: () => context.go(item.route),
            ),
          ),
        const Spacer(),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Andrew\'s Supermarket admin tools',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
