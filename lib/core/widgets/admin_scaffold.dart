import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_colors.dart';
import '../models/app_models.dart';
import '../../features/app_state/app_controller.dart';
import 'common_widgets.dart';

double _adminMobileHorizontalPaddingForWidth(double width) {
  return 24;
}

const double _adminMobileHeaderActionSize = 40;
const double _adminSidePanelMaxWidth = 260;
const _adminNavItems = <({String label, IconData icon, String route})>[
  (
    label: 'Dashboard',
    icon: Icons.dashboard_outlined,
    route: '/admin/dashboard',
  ),
  (
    label: 'Categories',
    icon: Icons.category_outlined,
    route: '/admin/categories',
  ),
  (
    label: 'Barangays',
    icon: Icons.location_city_outlined,
    route: '/admin/barangays',
  ),
  (
    label: 'Products',
    icon: Icons.inventory_2_outlined,
    route: '/admin/products',
  ),
  (
    label: 'Banners',
    icon: Icons.view_carousel_outlined,
    route: '/admin/banners',
  ),
  (label: 'Orders', icon: Icons.receipt_long_outlined, route: '/admin/orders'),
  (label: 'Profile', icon: Icons.person_outline, route: '/admin/profile'),
];

double _adminSidePanelWidthForViewport(Size size, {required bool shellFrame}) {
  return shellFrame ? _adminSidePanelMaxWidth : 286.0;
}

double _adminMobileDrawerWidth(double viewportWidth) {
  final availableWidth = viewportWidth - 48;
  if (availableWidth <= 0) {
    return viewportWidth;
  }
  return availableWidth < _adminSidePanelMaxWidth
      ? availableWidth
      : _adminSidePanelMaxWidth;
}

class AdminShellFrame extends ConsumerStatefulWidget {
  const AdminShellFrame({
    super.key,
    required this.currentPath,
    required this.child,
  });

  final String currentPath;
  final Widget child;

  @override
  ConsumerState<AdminShellFrame> createState() => _AdminShellFrameState();
}

class _AdminShellFrameState extends ConsumerState<AdminShellFrame> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool? _lastDesktopState;
  bool _isDesktopSidePanelVisible = true;
  bool _allowMobileAutoOpen = true;
  bool _isSyncingDrawer = false;

  void _syncMobileDrawer(bool isDesktop) {
    if (_lastDesktopState == isDesktop) {
      return;
    }
    _lastDesktopState = isDesktop;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final scaffoldState = _scaffoldKey.currentState;
      if (scaffoldState == null) {
        return;
      }
      if (isDesktop) {
        if (scaffoldState.isDrawerOpen) {
          _isSyncingDrawer = true;
          scaffoldState.closeDrawer();
        }
        return;
      }
      if (_allowMobileAutoOpen) {
        if (!scaffoldState.isDrawerOpen) {
          _isSyncingDrawer = true;
          scaffoldState.openDrawer();
        }
      } else if (scaffoldState.isDrawerOpen) {
        _isSyncingDrawer = true;
        scaffoldState.closeDrawer();
      }
    });
  }

  void _handleDrawerChanged(bool isOpen) {
    if (_isSyncingDrawer) {
      _isSyncingDrawer = false;
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _isDesktopSidePanelVisible = isOpen;
      _allowMobileAutoOpen = isOpen;
    });
  }

  String get _selectedRoute {
    if (widget.currentPath.startsWith('/admin/products')) {
      return '/admin/products';
    }
    if (widget.currentPath.startsWith('/admin/banners')) {
      return '/admin/banners';
    }
    if (widget.currentPath.startsWith('/admin/barangays')) {
      return '/admin/barangays';
    }
    if (widget.currentPath.startsWith('/admin/categories')) {
      return '/admin/categories';
    }
    if (widget.currentPath.startsWith('/admin/orders')) {
      return '/admin/orders';
    }
    if (widget.currentPath.startsWith('/admin/profile')) {
      return '/admin/profile';
    }
    return '/admin/dashboard';
  }

  bool get _isOrderDetailRoute =>
      widget.currentPath.startsWith('/admin/orders/');

  bool get _isProductDetailRoute =>
      widget.currentPath.startsWith('/admin/products/');

  bool get _isCategoryDetailRoute =>
      widget.currentPath.startsWith('/admin/categories/');

  int? get _orderDetailId {
    if (!_isOrderDetailRoute) {
      return null;
    }
    final idSegment = widget.currentPath.split('/').last;
    return int.tryParse(idSegment);
  }

  int? get _productDetailId {
    if (!_isProductDetailRoute) {
      return null;
    }
    final idSegment = widget.currentPath.split('/').last;
    return int.tryParse(idSegment);
  }

  int? get _categoryDetailId {
    if (!_isCategoryDetailRoute) {
      return null;
    }
    final idSegment = widget.currentPath.split('/').last;
    return int.tryParse(idSegment);
  }

  String get _title {
    if (widget.currentPath.startsWith('/admin/products/')) {
      return 'Product #${_productDetailId ?? ''}';
    }
    if (widget.currentPath.startsWith('/admin/categories/')) {
      return 'Category #${_categoryDetailId ?? ''}';
    }
    if (widget.currentPath.startsWith('/admin/products')) {
      return 'Products';
    }
    if (widget.currentPath.startsWith('/admin/banners')) {
      return 'Banners';
    }
    if (widget.currentPath.startsWith('/admin/barangays')) {
      return 'Barangays';
    }
    if (widget.currentPath.startsWith('/admin/categories')) {
      return 'Categories';
    }
    if (widget.currentPath.startsWith('/admin/orders/')) {
      return 'Order #${_orderDetailId ?? ''}';
    }
    if (widget.currentPath.startsWith('/admin/orders')) {
      return 'Orders';
    }
    if (widget.currentPath.startsWith('/admin/profile')) {
      return 'Profile';
    }
    return 'Dashboard';
  }

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.of(context).size;
    final width = mediaSize.width;
    final isDesktop = width >= 1024;
    _syncMobileDrawer(isDesktop);
    final mobileHorizontalPadding = _adminMobileHorizontalPaddingForWidth(
      width,
    );
    final sidePanelWidth = _adminSidePanelWidthForViewport(
      mediaSize,
      shellFrame: true,
    );
    final adminSession = ref.watch(
      appControllerProvider.select((state) => state.adminSession),
    );
    final titleStyle = Theme.of(context).textTheme.headlineLarge?.copyWith(
      fontWeight: FontWeight.w800,
      color: const Color(0xFF172033),
      fontSize: 18,
      height: 1.15,
    );

    return Title(
      title: "Andrew's Admin",
      color: AppColors.logoBlue,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFFF8FAFF),
        onDrawerChanged: _handleDrawerChanged,
        drawer: isDesktop
            ? null
            : Drawer(
                width: _adminMobileDrawerWidth(width),
                backgroundColor: AppColors.logoBlueDark,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
                child: _NavList(selectedRoute: _selectedRoute),
              ),
        body: Row(
          children: [
            if (isDesktop && _isDesktopSidePanelVisible)
              Container(
                width: sidePanelWidth,
                decoration: BoxDecoration(
                  color: AppColors.logoBlueDark,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 24,
                      offset: Offset(0, 0),
                    ),
                  ],
                ),
                child: _NavList(selectedRoute: _selectedRoute),
              ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isDesktop ? 36 : mobileHorizontalPadding,
                  isDesktop ? 24 : 0,
                  isDesktop ? 36 : mobileHorizontalPadding,
                  isDesktop ? 24 : 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isDesktop)
                      SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 16, bottom: 16),
                          child: Row(
                            children: [
                              SizedBox.square(
                                dimension: _adminMobileHeaderActionSize,
                                child:
                                    (_isOrderDetailRoute ||
                                        _isProductDetailRoute ||
                                        _isCategoryDetailRoute)
                                    ? MousePressable(
                                        onTap: () => context.go(
                                          _isOrderDetailRoute
                                              ? '/admin/orders'
                                              : _isProductDetailRoute
                                              ? '/admin/products'
                                              : '/admin/categories',
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        child: const Center(
                                          child: Icon(
                                            Icons.arrow_back_rounded,
                                            color: Color(0xFF172033),
                                          ),
                                        ),
                                      )
                                    : Builder(
                                        builder: (headerContext) =>
                                            MousePressable(
                                              onTap: () => Scaffold.of(
                                                headerContext,
                                              ).openDrawer(),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: const Center(
                                                child: Icon(
                                                  Icons.menu_rounded,
                                                  color: Color(0xFF172033),
                                                ),
                                              ),
                                            ),
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF172033),
                                    fontSize: 18,
                                    height: 1.15,
                                  ),
                                ),
                              ),
                              _AdminAccountActions(
                                adminSession: adminSession,
                                compact: true,
                                onProfile: () {
                                  context.go('/admin/profile');
                                },
                                onLogout: () async {
                                  final shouldLogout =
                                      await _showLogoutConfirmation(context);
                                  if (shouldLogout != true ||
                                      !context.mounted) {
                                    return;
                                  }
                                  await ref
                                      .read(appControllerProvider.notifier)
                                      .logoutAdmin();
                                  if (context.mounted) {
                                    context.go('/admin/login');
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (isDesktop)
                      Row(
                        children: [
                          SizedBox.square(
                            dimension: _adminMobileHeaderActionSize,
                            child:
                                (_isOrderDetailRoute ||
                                    _isProductDetailRoute ||
                                    _isCategoryDetailRoute)
                                ? MousePressable(
                                    onTap: () => context.go(
                                      _isOrderDetailRoute
                                          ? '/admin/orders'
                                          : _isProductDetailRoute
                                          ? '/admin/products'
                                          : '/admin/categories',
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    child: const Center(
                                      child: Icon(
                                        Icons.arrow_back_rounded,
                                        color: Color(0xFF172033),
                                      ),
                                    ),
                                  )
                                : MousePressable(
                                    onTap: () {
                                      setState(() {
                                        _isDesktopSidePanelVisible =
                                            !_isDesktopSidePanelVisible;
                                        _allowMobileAutoOpen =
                                            _isDesktopSidePanelVisible;
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Center(
                                      child: Icon(
                                        _isDesktopSidePanelVisible
                                            ? Icons.menu_open_rounded
                                            : Icons.menu_rounded,
                                        color: const Color(0xFF172033),
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(_title, style: titleStyle)),
                          _AdminAccountActions(
                            adminSession: adminSession,
                            onProfile: () {
                              context.go('/admin/profile');
                            },
                            onLogout: () async {
                              final shouldLogout =
                                  await _showLogoutConfirmation(context);
                              if (shouldLogout != true || !context.mounted) {
                                return;
                              }
                              await ref
                                  .read(appControllerProvider.notifier)
                                  .logoutAdmin();
                              if (context.mounted) {
                                context.go('/admin/login');
                              }
                            },
                          ),
                        ],
                      ),
                    if (isDesktop) const SizedBox(height: 28),
                    Expanded(child: widget.child),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool?> _showLogoutConfirmation(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AppModalFrame(
        title: 'Logout?',
        actions: [
          AppModalButton(
            label: 'Close',
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          const SizedBox(width: 10),
          AppModalButton(
            label: 'Logout',
            isPrimary: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
        child: const AppModalBodyText('Are you sure you want to logout?'),
      );
    },
  );
}

class AdminScaffold extends ConsumerStatefulWidget {
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

  @override
  ConsumerState<AdminScaffold> createState() => _AdminScaffoldState();
}

class _AdminScaffoldState extends ConsumerState<AdminScaffold> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool? _lastDesktopState;
  bool _isDesktopSidePanelVisible = true;
  bool _allowMobileAutoOpen = true;
  bool _isSyncingDrawer = false;

  void _syncMobileDrawer(bool isDesktop) {
    if (_lastDesktopState == isDesktop) {
      return;
    }
    _lastDesktopState = isDesktop;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final scaffoldState = _scaffoldKey.currentState;
      if (scaffoldState == null) {
        return;
      }
      if (isDesktop) {
        if (scaffoldState.isDrawerOpen) {
          _isSyncingDrawer = true;
          scaffoldState.closeDrawer();
        }
        return;
      }
      if (_allowMobileAutoOpen) {
        if (!scaffoldState.isDrawerOpen) {
          _isSyncingDrawer = true;
          scaffoldState.openDrawer();
        }
      } else if (scaffoldState.isDrawerOpen) {
        _isSyncingDrawer = true;
        scaffoldState.closeDrawer();
      }
    });
  }

  void _handleDrawerChanged(bool isOpen) {
    if (_isSyncingDrawer) {
      _isSyncingDrawer = false;
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _isDesktopSidePanelVisible = isOpen;
      _allowMobileAutoOpen = isOpen;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.of(context).size;
    final width = mediaSize.width;
    final isDesktop = width >= 1024;
    _syncMobileDrawer(isDesktop);
    final mobileHorizontalPadding = _adminMobileHorizontalPaddingForWidth(
      width,
    );
    final sidePanelWidth = _adminSidePanelWidthForViewport(
      mediaSize,
      shellFrame: false,
    );
    final adminSession = ref.watch(
      appControllerProvider.select((state) => state.adminSession),
    );
    final titleStyle = Theme.of(context).textTheme.headlineLarge?.copyWith(
      fontWeight: FontWeight.w800,
      color: const Color(0xFF172033),
      fontSize: 18,
      height: 1.15,
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF7F9FF),
      onDrawerChanged: _handleDrawerChanged,
      drawer: isDesktop
          ? null
          : Drawer(
              width: _adminMobileDrawerWidth(width),
              backgroundColor: AppColors.logoBlue,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
              child: _NavList(selectedRoute: widget.selectedRoute),
            ),
      body: Row(
        children: [
          if (isDesktop && _isDesktopSidePanelVisible)
            Container(
              width: sidePanelWidth,
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              decoration: BoxDecoration(
                color: AppColors.logoBlueDark,
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.logoBlueShadowStrong,
                    blurRadius: 24,
                    offset: Offset(0, 0),
                  ),
                ],
              ),
              child: _NavList(selectedRoute: widget.selectedRoute),
            ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 28 : mobileHorizontalPadding,
                isDesktop ? 28 : 0,
                isDesktop ? 28 : mobileHorizontalPadding,
                isDesktop ? 24 : 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isDesktop)
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 16),
                        child: Row(
                          children: [
                            Builder(
                              builder: (headerContext) => SizedBox.square(
                                dimension: _adminMobileHeaderActionSize,
                                child: MousePressable(
                                  onTap: () =>
                                      Scaffold.of(headerContext).openDrawer(),
                                  borderRadius: BorderRadius.circular(12),
                                  child: const Center(
                                    child: Icon(
                                      Icons.menu_rounded,
                                      color: Color(0xFF172033),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                widget.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF172033),
                                  fontSize: 18,
                                  height: 1.15,
                                ),
                              ),
                            ),
                            ...widget.actions,
                            _AdminAccountActions(
                              adminSession: adminSession,
                              compact: true,
                              onProfile: () {
                                context.go('/admin/profile');
                              },
                              onLogout: () async {
                                final shouldLogout =
                                    await _showLogoutConfirmation(context);
                                if (shouldLogout != true || !context.mounted) {
                                  return;
                                }
                                await ref
                                    .read(appControllerProvider.notifier)
                                    .logoutAdmin();
                                if (context.mounted) {
                                  context.go('/admin/login');
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (isDesktop)
                    Row(
                      children: [
                        SizedBox.square(
                          dimension: _adminMobileHeaderActionSize,
                          child: MousePressable(
                            onTap: () {
                              setState(() {
                                _isDesktopSidePanelVisible =
                                    !_isDesktopSidePanelVisible;
                                _allowMobileAutoOpen =
                                    _isDesktopSidePanelVisible;
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Center(
                              child: Icon(
                                _isDesktopSidePanelVisible
                                    ? Icons.menu_open_rounded
                                    : Icons.menu_rounded,
                                color: const Color(0xFF172033),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(widget.title, style: titleStyle)),
                        ...widget.actions,
                        MousePressable(
                          onTap: () {
                            ref
                                .read(appControllerProvider.notifier)
                                .logoutAdmin();
                            context.go('/admin/login');
                          },
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFFE6EBF5),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.logout_rounded,
                                  size: 18,
                                  color: Color(0xFF172033),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Logout',
                                  style: TextStyle(
                                    color: Color(0xFF172033),
                                    fontWeight: FontWeight.w700,
                                    height: 1.15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (isDesktop) const SizedBox(height: 24),
                  Expanded(child: widget.child),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavList extends ConsumerWidget {
  const _NavList({required this.selectedRoute});

  final String selectedRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final waitingOrdersCount = ref.watch(
      appControllerProvider.select(
        (state) => state.orders
            .where((item) => item.status == OrderStatus.waiting)
            .length,
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final widthScale = constraints.maxWidth.isFinite
            ? (constraints.maxWidth / 304).clamp(0.78, 1.0)
            : 1.0;
        final heightScale = constraints.maxHeight.isFinite
            ? (constraints.maxHeight / 700).clamp(0.72, 1.0)
            : 1.0;
        final scale = widthScale < heightScale ? widthScale : heightScale;

        const headerHorizontal = 22.0;
        const headerTop = 26.0;
        const headerBottom = 26.0;
        const logoOffsetRight = 22.0;
        const logoBottom = 12.0;
        const logoSize = 94.0;
        const brandFontSize = 15.0;
        final navTopGap = 22.0 * scale;
        final itemOuterHorizontal = 18.0 * scale;
        final itemOuterBottom = 10.0 * scale;
        final itemInnerHorizontal = 18.0 * scale;
        final itemInnerVertical = 18.0 * scale;
        final itemRadius = 18.0 * scale;
        final itemIconSize = 24.0 * scale;
        final itemGap = 14.0 * scale;
        final itemFontSize = 15.0 * scale;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPress: () => context.go('/'),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  headerHorizontal,
                  headerTop,
                  headerHorizontal,
                  headerBottom,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1538DD),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.black.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(
                        right: logoOffsetRight,
                        bottom: logoBottom,
                      ),
                      child: Center(
                        child: Image(
                          image: const AssetImage(
                            'assets/branding/as_logo_lite.png',
                          ),
                          width: logoSize,
                          height: logoSize,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    Text(
                      "Andrew's Supermarket",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: brandFontSize,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: navTopGap),
            for (final item in _adminNavItems)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  itemOuterHorizontal,
                  0,
                  itemOuterHorizontal,
                  itemOuterBottom,
                ),
                child: MousePressable(
                  onTap: () async {
                    final navigator = Navigator.of(context);
                    if (!isDesktop && navigator.canPop()) {
                      navigator.pop();
                    }
                    if (context.mounted) {
                      context.go(item.route);
                    }
                  },
                  borderRadius: BorderRadius.circular(itemRadius),
                  hoverOverlayAlpha: 0.10,
                  pressedOverlayAlpha: 0.16,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: itemInnerHorizontal,
                      vertical: itemInnerVertical,
                    ),
                    decoration: BoxDecoration(
                      color: selectedRoute == item.route
                          ? const Color(0xFF1538DD)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(itemRadius),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          item.icon,
                          color: Colors.white,
                          size: itemIconSize,
                        ),
                        SizedBox(width: itemGap),
                        Expanded(
                          child: Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              fontSize: itemFontSize,
                              height: 1.15,
                            ),
                          ),
                        ),
                        if (item.route == '/admin/orders' &&
                            waitingOrdersCount > 0)
                          Container(
                            margin: EdgeInsets.only(left: 10 * scale),
                            padding: EdgeInsets.symmetric(
                              horizontal: waitingOrdersCount >= 100
                                  ? 7 * scale
                                  : 8 * scale,
                              vertical: 4 * scale,
                            ),
                            constraints: BoxConstraints(
                              minWidth: 24 * scale,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE31E24),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$waitingOrdersCount',
                              maxLines: 1,
                              overflow: TextOverflow.visible,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12 * scale,
                                height: 1.15,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AdminAccountActions extends StatelessWidget {
  const _AdminAccountActions({
    required this.adminSession,
    required this.onProfile,
    required this.onLogout,
    this.compact = false,
  });

  final AdminSession? adminSession;
  final VoidCallback onProfile;
  final Future<void> Function() onLogout;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final displayName = adminSession?.displayName.trim().isNotEmpty == true
        ? adminSession!.displayName.trim()
        : 'Arjie Lim';
    final email = adminSession?.email.trim().isNotEmpty == true
        ? adminSession!.email.trim()
        : 'admin@andrews.com';
    final initial = displayName.characters.first.toUpperCase();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PopupMenuButton<String>(
          color: Colors.white,
          surfaceTintColor: Colors.white,
          padding: EdgeInsets.zero,
          onSelected: (value) async {
            if (value == 'profile') {
              onProfile();
              return;
            }
            if (value == 'logout') {
              await onLogout();
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem<String>(value: 'profile', child: Text('Profile')),
            PopupMenuItem<String>(value: 'logout', child: Text('Log out')),
          ],
          child: SizedBox(
            height: 56,
            child: compact
                ? Center(
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.logoBlue,
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          height: 1,
                        ),
                      ),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF172033),
                              fontSize: 14,
                              height: 1.15,
                            ),
                          ),
                          Text(
                            email,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF667085),
                              fontSize: 12,
                              height: 1.15,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.logoBlue,
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            height: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
