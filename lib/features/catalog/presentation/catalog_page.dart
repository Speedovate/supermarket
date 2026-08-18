import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/app_models.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/open_external_url.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../app_state/app_controller.dart';
import 'catalog_view_model.dart';

typedef _CustomerControllers = ({
  TextEditingController name,
  TextEditingController mobile,
  TextEditingController barangay,
  TextEditingController street,
});

Future<void> _showProductDetailsModal(
  BuildContext context,
  Product product, {
  String? displayUnit,
  int? displayPriceCentavos,
  DateTime? displayPriceUpdatedAt,
  String? displayName,
  Future<Product?> Function(BuildContext context)? onEditProduct,
  bool showEditAction = false,
  bool adminReadOnly = false,
  int? initialAdminQuantity,
  Future<void> Function(int quantity)? onAdminQuantitySaved,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => _ProductModal(
      product: product,
      displayUnit: displayUnit,
      displayPriceCentavos: displayPriceCentavos,
      displayPriceUpdatedAt: displayPriceUpdatedAt,
      displayName: displayName,
      onEditProduct: onEditProduct,
      showEditAction: showEditAction,
      adminReadOnly: adminReadOnly,
      initialAdminQuantity: initialAdminQuantity,
      onAdminQuantitySaved: onAdminQuantitySaved,
    ),
  );
}

void _popAllRoutesUntilFirst(BuildContext context) {
  Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
}

class _PhilippineMobileInputFormatter extends TextInputFormatter {
  const _PhilippineMobileInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text;
    final digitsOnly = raw.replaceAll(RegExp(r'[^0-9]'), '');

    String nextText;
    if (raw.startsWith('+639')) {
      final localDigits = digitsOnly.replaceFirst(RegExp(r'^639'), '');
      nextText = '09$localDigits';
    } else if (digitsOnly.startsWith('639')) {
      final localDigits = digitsOnly.substring(3);
      nextText = '09$localDigits';
    } else if (digitsOnly.startsWith('9')) {
      nextText = '0$digitsOnly';
    } else {
      nextText = digitsOnly;
    }

    if (nextText.length > 11) {
      nextText = nextText.substring(0, 11);
    }

    if (nextText == oldValue.text) {
      return newValue.copyWith(
        selection: TextSelection.collapsed(offset: nextText.length),
        composing: TextRange.empty,
      );
    }

    return TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
      composing: TextRange.empty,
    );
  }
}

class CatalogPage extends ConsumerStatefulWidget {
  const CatalogPage({super.key});

  @override
  ConsumerState<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends ConsumerState<CatalogPage> {
  final _searchController = TextEditingController();
  final _bestSellersScrollController = ScrollController();
  final _desktopCartScrollController = ScrollController();
  late final TextEditingController _customerNameController;
  late final TextEditingController _customerMobileController;
  late final TextEditingController _customerBarangayController;
  late final TextEditingController _customerStreetController;
  Timer? _debounce;
  String _query = '';
  String _categoryId = 'all';
  CatalogSortOption _sortOption = CatalogSortOption.defaultOrder;
  CatalogSortOption _bestSellersSortOption = CatalogSortOption.defaultOrder;
  bool _isBestSellersInteracting = false;
  bool _desktopCartPanelOpen = false;
  bool _cartBottomSheetOpen = false;
  bool _previousOrdersExpanded = false;
  String _selectedCartThreadId = 'current';
  BuildContext? _cartBottomSheetContext;

  bool get _showBestSellersLeftControl =>
      _bestSellersScrollController.hasClients &&
      _bestSellersScrollController.offset >
          _bestSellersScrollController.position.minScrollExtent + 0.5;

  bool get _showBestSellersRightControl =>
      _bestSellersScrollController.hasClients &&
      _bestSellersScrollController.offset <
          _bestSellersScrollController.position.maxScrollExtent - 0.5;

  void _handleBestSellersScroll() {
    if (mounted) {
      setState(() {});
    }
  }

  void _scheduleBestSellersVisibilityRefresh() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _bestSellersScrollController.hasClients) {
        setState(() {});
      }
    });
  }

  @override
  void initState() {
    super.initState();
    final draft = ref.read(appControllerProvider).customerDraft;
    _customerNameController = TextEditingController(text: draft.name);
    _customerMobileController = TextEditingController(text: draft.mobileNumber);
    _customerBarangayController = TextEditingController(text: draft.barangay);
    _customerStreetController = TextEditingController(
      text: draft.addressStreet.trim().isNotEmpty
          ? draft.addressStreet
          : draft.addressLandmark,
    );
    _bestSellersScrollController.addListener(_handleBestSellersScroll);
    _scheduleBestSellersVisibilityRefresh();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _customerNameController.dispose();
    _customerMobileController.dispose();
    _customerBarangayController.dispose();
    _customerStreetController.dispose();
    _bestSellersScrollController.removeListener(_handleBestSellersScroll);
    _bestSellersScrollController.dispose();
    _desktopCartScrollController.dispose();
    super.dispose();
  }

  Future<void> _scrollClientCartPanelToTop() async {
    await WidgetsBinding.instance.endOfFrame;
    if (!_desktopCartScrollController.hasClients) {
      return;
    }
    await _desktopCartScrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  _CustomerControllers get _customerControllers => (
    name: _customerNameController,
    mobile: _customerMobileController,
    barangay: _customerBarangayController,
    street: _customerStreetController,
  );

  CustomerDraft _buildCustomerDraft(FulfillmentMethod method) {
    final existingDraft = ref.read(appControllerProvider).customerDraft;
    final now = DateTime.now();
    final isDelivery = method == FulfillmentMethod.delivery;
    final hasBarangay = _customerBarangayController.text.trim().isNotEmpty;
    return CustomerDraft(
      name: _customerNameController.text,
      mobileNumber: _customerMobileController.text,
      normalizedMobileNumber: normalizePhoneNumber(
        _customerMobileController.text,
      ),
      barangay: isDelivery ? _customerBarangayController.text : '',
      addressStreet: isDelivery && hasBarangay
          ? _customerStreetController.text
          : '',
      addressLandmark: '',
      fulfillmentMethod: method,
      createdAt: existingDraft.createdAt ?? now,
      updatedAt: now,
    );
  }

  Future<void> _persistCustomerDraft({FulfillmentMethod? method}) async {
    final currentMethod =
        method ??
        ref.read(appControllerProvider).customerDraft.fulfillmentMethod;
    await ref
        .read(appControllerProvider.notifier)
        .updateCustomerDraft(_buildCustomerDraft(currentMethod));
  }

  Future<void> _handleCartTap(double width) async {
    if (_canShowDesktopCartPanel(width)) {
      if (_cartBottomSheetOpen && _cartBottomSheetContext?.mounted == true) {
        Navigator.of(_cartBottomSheetContext!).pop();
      }
      if (mounted) {
        setState(() => _desktopCartPanelOpen = !_desktopCartPanelOpen);
      }
      return;
    }

    await _showCartBottomSheet();
  }

  Future<void> _showCartBottomSheet() async {
    if (mounted && _desktopCartPanelOpen) {
      setState(() => _desktopCartPanelOpen = false);
    }
    _cartBottomSheetOpen = true;
    var localSelectedThreadId = _selectedCartThreadId;
    var localPreviousOrdersExpanded = _previousOrdersExpanded;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(
        minWidth: MediaQuery.of(context).size.width,
        maxWidth: MediaQuery.of(context).size.width,
      ),
      builder: (sheetContext) {
        _cartBottomSheetContext = sheetContext;
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Consumer(
              builder: (sheetContext, ref, _) {
                final appState = ref.watch(appControllerProvider);
                final matchingOrders = _matchingCustomerOrders(appState);
                final selectedThreadId =
                    {
                      'current',
                      ...matchingOrders.map((order) => '${order.id}'),
                    }.contains(localSelectedThreadId)
                    ? localSelectedThreadId
                    : 'current';

                return ScaffoldMessenger(
                  child: Scaffold(
                    backgroundColor: Colors.transparent,
                    resizeToAvoidBottomInset: false,
                    body: SafeArea(
                      top: false,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: 0.92,
                          widthFactor: 1,
                          child: DecoratedBox(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(28),
                              ),
                            ),
                            child: _DesktopCartPanel(
                              width: MediaQuery.of(sheetContext).size.width,
                              isBottomSheet: true,
                              scrollController: _desktopCartScrollController,
                              customerDraft: appState.customerDraft,
                              customerControllers: _customerControllers,
                              cart: appState.cart,
                              matchingOrders: matchingOrders,
                              selectedThreadId: selectedThreadId,
                              previousOrdersExpanded: localPreviousOrdersExpanded,
                              totalCentavos: appState.cartTotalCentavos,
                              submitting: appState.submittingOrder,
                              onClose: () => Navigator.of(sheetContext).pop(),
                              onContactUs: () => _showContactUsDialog(
                                sheetContext,
                                appState.settings,
                              ),
                              settings: appState.settings,
                              serviceableBarangays: ref
                                  .read(appControllerProvider.notifier)
                                  .serviceableBarangays,
                              onThreadSelected: (value) {
                                setSheetState(() {
                                  localSelectedThreadId = value;
                                  localPreviousOrdersExpanded = false;
                                });
                                if (mounted) {
                                  setState(() {
                                    _selectedCartThreadId = value;
                                    _previousOrdersExpanded = false;
                                  });
                                }
                              },
                              onPreviousOrdersExpandedChanged: (value) {
                                setSheetState(() {
                                  localPreviousOrdersExpanded = value;
                                });
                                if (mounted) {
                                  setState(() => _previousOrdersExpanded = value);
                                }
                              },
                              onDraftChanged: _persistCustomerDraft,
                              onReviewOrder: () async {
                                final messenger = ScaffoldMessenger.of(
                                  sheetContext,
                                );
                                await _persistCustomerDraft();
                                if (!mounted) {
                                  return;
                                }
                                final nextDraft = ref
                                    .read(appControllerProvider)
                                    .customerDraft;
                                final error = ref
                                    .read(appControllerProvider.notifier)
                                    .validateCheckoutDraft(nextDraft);
                                if (error != null) {
                                  messenger.clearSnackBars();
                                  messenger.showSnackBar(errorSnackBar(error));
                                  return;
                                }
                                final itemCount = ref
                                    .read(appControllerProvider)
                                    .cart
                                    .fold<int>(
                                      0,
                                      (sum, item) => sum + item.quantity,
                                    );
                                if (!sheetContext.mounted) {
                                  return;
                                }
                                final shouldPlaceOrder =
                                    await _showPlaceOrderConfirmationDialog(
                                      sheetContext,
                                      itemCount: itemCount,
                                    );
                                if (!mounted || shouldPlaceOrder != true) {
                                  return;
                                }
                                final orderId = await ref
                                    .read(appControllerProvider.notifier)
                                    .submitOrder();
                                if (!mounted) {
                                  return;
                                }
                                if (orderId == null) {
                                  final submitError = ref
                                          .read(appControllerProvider)
                                          .errorMessage ??
                                      'Unable to submit your order right now.';
                                  messenger.clearSnackBars();
                                  messenger.showSnackBar(
                                    errorSnackBar(submitError),
                                  );
                                  return;
                                }
                                _customerNameController.clear();
                                _customerMobileController.clear();
                                _customerBarangayController.clear();
                                _customerStreetController.clear();
                                setSheetState(() {
                                  localPreviousOrdersExpanded = false;
                                  localSelectedThreadId = '$orderId';
                                });
                                setState(() {
                                  _previousOrdersExpanded = false;
                                  _selectedCartThreadId = '$orderId';
                                });
                                await _scrollClientCartPanelToTop();
                                if (!sheetContext.mounted) {
                                  return;
                                }
                                await _showOrderPlacedDialog(sheetContext);
                              },
                              onOrderAgain: (order) async {
                                final shouldOrderAgain =
                                    await _showOrderAgainDialog(sheetContext);
                                if (!mounted || shouldOrderAgain != true) {
                                  return;
                                }
                                await ref
                                    .read(appControllerProvider.notifier)
                                    .addOrderToCart(order);
                                if (!mounted) {
                                  return;
                                }
                                final nextDraft = ref
                                    .read(appControllerProvider)
                                    .customerDraft;
                                _customerNameController.text = nextDraft.name;
                                _customerMobileController.text =
                                    nextDraft.mobileNumber;
                                _customerBarangayController.text =
                                    nextDraft.barangay;
                                setSheetState(() {
                                  localSelectedThreadId = 'current';
                                  localPreviousOrdersExpanded = false;
                                });
                                setState(() {
                                  _selectedCartThreadId = 'current';
                                  _previousOrdersExpanded = false;
                                });
                                await _scrollClientCartPanelToTop();
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
    _cartBottomSheetOpen = false;
    _cartBottomSheetContext = null;
  }

  List<OrderRequest> _matchingCustomerOrders(AppState state) {
    return state.orders;
  }

  Future<void> _snapBestSellersToNearest(double itemExtent) async {
    if (!_bestSellersScrollController.hasClients) {
      return;
    }

    final position = _bestSellersScrollController.position;
    final current = position.pixels;
    final min = position.minScrollExtent;
    final max = position.maxScrollExtent;
    final distanceToStart = current - min;
    final distanceToEnd = max - current;

    final target = distanceToStart <= itemExtent / 2
        ? min
        : distanceToEnd <= itemExtent / 2
        ? max
        : ((current / itemExtent).roundToDouble() * itemExtent).clamp(min, max);

    if ((target - current).abs() < 0.5) {
      return;
    }

    await _bestSellersScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  Future<void> _scrollBestSellersBy(double delta) async {
    if (!_bestSellersScrollController.hasClients) {
      return;
    }
    final position = _bestSellersScrollController.position;
    final target = (_bestSellersScrollController.offset + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    await _bestSellersScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
    await _snapBestSellersToNearest(
      _currentBestSellerItemExtent ?? delta.abs(),
    );
  }

  double? _currentBestSellerItemExtent;

  bool _handleBestSellerSnapNotification(
    ScrollNotification notification,
    double itemExtent,
  ) {
    final isInteracting =
        notification is ScrollStartNotification ||
        (notification is UserScrollNotification &&
            notification.direction != ScrollDirection.idle);
    final isSettled =
        notification is ScrollEndNotification ||
        (notification is UserScrollNotification &&
            notification.direction == ScrollDirection.idle);
    if (isInteracting && !_isBestSellersInteracting && mounted) {
      setState(() => _isBestSellersInteracting = true);
    } else if (isSettled && _isBestSellersInteracting && mounted) {
      setState(() => _isBestSellersInteracting = false);
    }

    final shouldSnap =
        notification is ScrollEndNotification ||
        (notification is UserScrollNotification &&
            notification.direction == ScrollDirection.idle);
    if (shouldSnap) {
      unawaited(_snapBestSellersToNearest(itemExtent));
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(catalogViewModelProvider);
    final appState = ref.watch(appControllerProvider);
    final controller = ref.watch(appControllerProvider.notifier);
    final allPublicProducts = controller.publicProductsFor(
      categoryId: 'all',
      query: '',
    );
    final visibleCategoryIds = allPublicProducts
        .map((product) => product.categoryId)
        .where((categoryId) => categoryId > 0)
        .toSet();
    final visibleCategories = vm.categories
        .where((category) => visibleCategoryIds.contains(category.id))
        .toList();
    final hasOtherProducts = allPublicProducts.any((product) {
      final categoryId = product.categoryId;
      return categoryId <= 0 ||
          !vm.categories.any((category) => category.id == categoryId);
    });
    final hasSelectedVisibleCategory =
        _categoryId == 'all' ||
        (_categoryId == 'others' && hasOtherProducts) ||
        visibleCategories.any((category) => category.id.toString() == _categoryId);
    if (!hasSelectedVisibleCategory) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _categoryId == 'all') {
          return;
        }
        setState(() => _categoryId = 'all');
      });
    }
    final products = controller.publicProductsFor(
      categoryId: _categoryId,
      query: _query,
    );
    final sortedProducts = _sortProducts(products, _sortOption);
    final sortedBestSellers = _sortProducts(
      vm.bestSellers,
      _bestSellersSortOption,
    );
    final activeBanners = [...appState.banners.where((item) => item.isActive)]
      ..sort((a, b) {
        final createdAtCompare = b.createdAt.compareTo(a.createdAt);
        if (createdAtCompare != 0) {
          return createdAtCompare;
        }
        return b.id.compareTo(a.id);
      });
    final selectedCategory = visibleCategories.cast<Category?>().firstWhere(
      (category) => category?.id.toString() == _categoryId,
      orElse: () => null,
    );
    final selectedCategoryTitle = _categoryId == 'all'
        ? 'All Products'
        : _categoryId == 'others'
        ? 'Others'
        : selectedCategory?.name ?? 'All Products';
    final media = MediaQuery.of(context);
    final width = media.size.width;
    final isDesktopCartCapable = _canShowDesktopCartPanel(width);
    if (!isDesktopCartCapable &&
        _desktopCartPanelOpen &&
        !_cartBottomSheetOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || _cartBottomSheetOpen) {
          return;
        }
        setState(() => _desktopCartPanelOpen = false);
        await _showCartBottomSheet();
      });
    }
    if (isDesktopCartCapable &&
        !_desktopCartPanelOpen &&
        _cartBottomSheetOpen &&
        _cartBottomSheetContext?.mounted == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _cartBottomSheetContext?.mounted != true) {
          return;
        }
        Navigator.of(_cartBottomSheetContext!).pop();
        setState(() => _desktopCartPanelOpen = true);
      });
    }
    final showDesktopCartPanel = isDesktopCartCapable && _desktopCartPanelOpen;
    if (showDesktopCartPanel &&
        _cartBottomSheetOpen &&
        _cartBottomSheetContext?.mounted == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_cartBottomSheetContext?.mounted == true) {
          Navigator.of(_cartBottomSheetContext!).pop();
        }
      });
    }
    final mainContentWidth =
        width - (showDesktopCartPanel ? _kDesktopCartPanelWidth : 0);
    final isMobile = mainContentWidth < _kMobileBreakpoint;
    const maxContentWidth = 1440.0;
    final gridPadding = _outerHorizontalPaddingForWidth(mainContentWidth);
    const gridSpacing = 16.0;
    final availableGridWidth = mainContentWidth - (gridPadding * 2);
    final columns = _catalogColumnsForWidth(mainContentWidth);
    final resolvedCardWidth = columns == 1
        ? availableGridWidth
        : (availableGridWidth - ((columns - 1) * gridSpacing)) / columns;
    _currentBestSellerItemExtent = resolvedCardWidth + gridSpacing;
    _scheduleBestSellersVisibilityRefresh();
    final gridCardDensity = _cardDensityForWidth(resolvedCardWidth);
    final resolvedCardHeight = switch (columns) {
      1 => lerpDouble(210.0, 202.0, gridCardDensity)!,
      2 => resolvedCardWidth + lerpDouble(201.0, 188.0, gridCardDensity)!,
      3 => resolvedCardWidth + lerpDouble(206.0, 190.0, gridCardDensity)!,
      4 => resolvedCardWidth + lerpDouble(197.0, 184.0, gridCardDensity)!,
      _ => resolvedCardWidth + lerpDouble(189.0, 176.0, gridCardDensity)!,
    };
    final gridAspectRatio = resolvedCardWidth / resolvedCardHeight;
    final bottomScrollPadding = vm.cartCount > 0 && !showDesktopCartPanel
        ? (_kFloatingCartButtonBottomOffset * 2) + _kFloatingCartButtonHeight
        : gridPadding;
    final matchingOrders = _matchingCustomerOrders(appState);
    final selectedThreadId =
        {
          'current',
          ...matchingOrders.map((order) => '${order.id}'),
        }.contains(_selectedCartThreadId)
        ? _selectedCartThreadId
        : 'current';
    final showCatalogLoading =
        appState.loading &&
        !appState.catalogHydrated &&
        vm.categories.isEmpty &&
        appState.products.isEmpty &&
        activeBanners.isEmpty;

    final mainPane = MediaQuery(
      data: media.copyWith(size: Size(mainContentWidth, media.size.height)),
      child: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: maxContentWidth),
                child: _TopBar(
                  searchController: _searchController,
                  query: _query,
                  onSearchChanged: (value) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 250), () {
                      setState(() => _query = value.trim().toLowerCase());
                    });
                  },
                  cartCount: vm.cartCount,
                  loading: showCatalogLoading,
                  hasOtherProducts: hasOtherProducts,
                  categories: visibleCategories,
                  selectedId: _categoryId,
                  onSelected: (value) => setState(() => _categoryId = value),
                  showCartPanelOpenState: showDesktopCartPanel,
                  onCartTap: () => _handleCartTap(mainContentWidth),
                ),
              ),
            ),
            Expanded(
              child: Container(
                color: AppColors.homeScrollableBackground,
                child: CustomScrollView(
                  slivers: [
                    if (showCatalogLoading)
                      SliverToBoxAdapter(
                        child: _CatalogLoadingSections(
                          horizontalPadding: gridPadding,
                          cardHeight: resolvedCardHeight,
                          columns: columns,
                          cardAspectRatio: gridAspectRatio,
                          bottomPadding: bottomScrollPadding,
                        ),
                      )
                    else ...[
                    if (activeBanners.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(0, 18, 0, 0),
                          child: _HeroBanner(
                            banners: activeBanners,
                            isMobile: isMobile,
                            horizontalPadding: gridPadding,
                            columns: columns,
                            cardWidth: resolvedCardWidth,
                            gridSpacing: gridSpacing,
                          ),
                        ),
                      ),
                    if (vm.bestSellers.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            gridPadding,
                            activeBanners.isNotEmpty ? 2 : 18,
                            gridPadding,
                            0,
                          ),
                          child: _SectionHeader(
                            title: 'Best Sellers',
                            icon: Icons.local_fire_department_rounded,
                            iconColor: const Color(0xFFE31E24),
                            titleFontSize: isMobile ? 14 : null,
                            trailing: _SortButton(
                              selected: _bestSellersSortOption,
                              onSelected: (value) {
                                setState(() => _bestSellersSortOption = value);
                              },
                            ),
                          ),
                        ),
                      ),
                    if (vm.bestSellers.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(0, 18, 0, 0),
                          child: SizedBox(
                            height: resolvedCardHeight,
                            child: Stack(
                              children: [
                                NotificationListener<ScrollNotification>(
                                  onNotification: (notification) =>
                                      _handleBestSellerSnapNotification(
                                        notification,
                                        _currentBestSellerItemExtent!,
                                      ),
                                  child: ListView.separated(
                                    controller: _bestSellersScrollController,
                                    scrollDirection: Axis.horizontal,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: gridPadding,
                                    ),
                                    physics: const ClampingScrollPhysics(),
                                    itemCount: sortedBestSellers.length,
                                    separatorBuilder: (context, index) =>
                                        const SizedBox(width: 16),
                                    itemBuilder: (context, index) => SizedBox(
                                      width: resolvedCardWidth,
                                      height: resolvedCardHeight,
                                      child: ProductCard(
                                        key: ValueKey(
                                          'best-seller-${sortedBestSellers[index].id}',
                                        ),
                                        product: sortedBestSellers[index],
                                        adaptiveSizing: true,
                                        showImage: columns != 1,
                                      ),
                                    ),
                                  ),
                                ),
                                if (!_isBestSellersInteracting)
                                  IgnorePointer(
                                    child: _HorizontalEdgeMasks(
                                      sideWidth: gridPadding,
                                    ),
                                  ),
                                if (_showBestSellersLeftControl)
                                  Positioned(
                                    left:
                                        gridPadding -
                                        (_controlExtentForWidth(
                                              mainContentWidth,
                                            ) /
                                            2) +
                                        2,
                                    top: 0,
                                    bottom: 0,
                                    child: Center(
                                      child: _ScrollChevronButton(
                                        icon: Icons.chevron_left_rounded,
                                        size: _controlExtentForWidth(
                                          mainContentWidth,
                                        ),
                                        onTap: () => _scrollBestSellersBy(
                                          -_currentBestSellerItemExtent!,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (_showBestSellersRightControl)
                                  Positioned(
                                    right:
                                        gridPadding -
                                        (_controlExtentForWidth(
                                              mainContentWidth,
                                            ) /
                                            2) +
                                        2,
                                    top: 0,
                                    bottom: 0,
                                    child: Center(
                                      child: _ScrollChevronButton(
                                        icon: Icons.chevron_right_rounded,
                                        size: _controlExtentForWidth(
                                          mainContentWidth,
                                        ),
                                        onTap: () => _scrollBestSellersBy(
                                          _currentBestSellerItemExtent!,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          gridPadding,
                          18,
                          gridPadding,
                          0,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _SectionHeader(
                                title: selectedCategoryTitle,
                                icon: Icons.grid_view_outlined,
                                iconColor: AppColors.logoBlue,
                                titleFontSize: isMobile ? 14 : null,
                              ),
                            ),
                            _SortButton(
                              selected: _sortOption,
                              onSelected: (value) {
                                setState(() => _sortOption = value);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (sortedProducts.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            gridPadding,
                            18,
                            gridPadding,
                            bottomScrollPadding,
                          ),
                          child: EmptyStateCard(
                            title: 'No products found',
                            message: _query.isNotEmpty
                                ? 'Try a different search term or switch categories.'
                                : 'There are no active products in this section yet.',
                            actionLabel: 'Reset Filters',
                            onAction: () {
                              _searchController.clear();
                              setState(() {
                                _query = '';
                                _categoryId = 'all';
                              });
                            },
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          gridPadding,
                          18,
                          gridPadding,
                          bottomScrollPadding,
                        ),
                        sliver: SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                mainAxisSpacing: gridSpacing,
                                crossAxisSpacing: gridSpacing,
                                childAspectRatio: gridAspectRatio,
                              ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => ProductCard(
                              key: ValueKey(
                                'catalog-${sortedProducts[index].id}',
                              ),
                              product: sortedProducts[index],
                              adaptiveSizing: true,
                              showImage: columns != 1,
                            ),
                            childCount: sortedProducts.length,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
      floatingActionButtonLocation: columns <= 2
          ? FloatingActionButtonLocation.centerFloat
          : FloatingActionButtonLocation.endFloat,
      floatingActionButton: showDesktopCartPanel
          ? null
          : CartFab(
              itemCount: vm.cartCount,
              totalCentavos: vm.cartTotalCentavos,
              fullWidth: columns <= 2,
              horizontalMargin: gridPadding,
              onTap: () => _handleCartTap(mainContentWidth),
            ),
      body: showDesktopCartPanel
          ? Row(
              children: [
                Expanded(child: mainPane),
                _DesktopCartPanel(
                  width: _kDesktopCartPanelWidth,
                  scrollController: _desktopCartScrollController,
                  customerDraft: appState.customerDraft,
                  customerControllers: _customerControllers,
                  cart: appState.cart,
                  matchingOrders: matchingOrders,
                  selectedThreadId: selectedThreadId,
                  previousOrdersExpanded: _previousOrdersExpanded,
                  totalCentavos: appState.cartTotalCentavos,
                  submitting: appState.submittingOrder,
                  onClose: () => setState(() => _desktopCartPanelOpen = false),
                  onContactUs: () =>
                      _showContactUsDialog(context, appState.settings),
                  settings: appState.settings,
                  serviceableBarangays: ref
                      .read(appControllerProvider.notifier)
                      .serviceableBarangays,
                  onThreadSelected: (value) {
                    setState(() {
                      _selectedCartThreadId = value;
                      _previousOrdersExpanded = false;
                    });
                  },
                  onPreviousOrdersExpandedChanged: (value) {
                    setState(() => _previousOrdersExpanded = value);
                  },
                  onDraftChanged: _persistCustomerDraft,
                  onReviewOrder: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await _persistCustomerDraft();
                    if (!mounted) {
                      return;
                    }
                    final nextDraft = ref
                        .read(appControllerProvider)
                        .customerDraft;
                    final error = ref
                        .read(appControllerProvider.notifier)
                        .validateCheckoutDraft(nextDraft);
                    if (error != null) {
                      messenger.clearSnackBars();
                      messenger.showSnackBar(errorSnackBar(error));
                      return;
                    }
                    final itemCount = ref
                        .read(appControllerProvider)
                        .cart
                        .fold<int>(0, (sum, item) => sum + item.quantity);
                    if (!context.mounted) {
                      return;
                    }
                    final shouldPlaceOrder =
                        await _showPlaceOrderConfirmationDialog(
                          context,
                          itemCount: itemCount,
                        );
                    if (!mounted || shouldPlaceOrder != true) {
                      return;
                    }
                    final orderId = await ref
                        .read(appControllerProvider.notifier)
                        .submitOrder();
                    if (!mounted) {
                      return;
                    }
                    if (orderId == null) {
                      final submitError = ref
                              .read(appControllerProvider)
                              .errorMessage ??
                          'Unable to submit your order right now.';
                      messenger.clearSnackBars();
                      messenger.showSnackBar(errorSnackBar(submitError));
                      return;
                    }
                    _customerNameController.clear();
                    _customerMobileController.clear();
                    _customerBarangayController.clear();
                    _customerStreetController.clear();
                    setState(() {
                      _previousOrdersExpanded = false;
                      _selectedCartThreadId = '$orderId';
                    });
                    await _scrollClientCartPanelToTop();
                    if (!context.mounted) {
                      return;
                    }
                    await _showOrderPlacedDialog(context);
                  },
                  onOrderAgain: (order) async {
                    final shouldOrderAgain = await _showOrderAgainDialog(
                      context,
                    );
                    if (!mounted || shouldOrderAgain != true) {
                      return;
                    }
                    await ref
                        .read(appControllerProvider.notifier)
                        .addOrderToCart(order);
                    if (!mounted) {
                      return;
                    }
                    final nextDraft = ref
                        .read(appControllerProvider)
                        .customerDraft;
                    _customerNameController.text = nextDraft.name;
                    _customerMobileController.text = nextDraft.mobileNumber;
                    _customerBarangayController.text = nextDraft.barangay;
                    _customerStreetController.text =
                        nextDraft.addressStreet.trim().isNotEmpty
                        ? nextDraft.addressStreet
                        : nextDraft.addressLandmark;
                    setState(() {
                      _selectedCartThreadId = 'current';
                      _previousOrdersExpanded = false;
                    });
                    await _scrollClientCartPanelToTop();
                  },
                ),
              ],
            )
          : mainPane,
    );
  }
}

enum CatalogSortOption {
  defaultOrder('Default'),
  nameAscending('Name A-Z'),
  nameDescending('Name Z-A'),
  priceLowToHigh('Price Low-High'),
  priceHighToLow('Price High-Low');

  const CatalogSortOption(this.label);

  final String label;
}

const _kHeaderControlHeight = 44.0;
const _kFloatingCartButtonHeight = 56.0;
const _kFloatingCartButtonBottomOffset = 16.0;
const _kDesktopCartPanelWidth = 420.0;
const _kSharedModalMaxWidth = 332.0;
const _kSharedModalButtonHeight = 44.0;
const _kCartPanelStatusFontSize = 12.0;
const _kCartPanelActionFontSize = 12.0;
const _kMobileBreakpoint = 700.0;

bool _canShowDesktopCartPanel(double width) {
  return _catalogColumnsForWidth(width - _kDesktopCartPanelWidth) >= 2;
}

WidgetStateProperty<Color?> _transparentInteractionOverlay() {
  return WidgetStateProperty.all(Colors.transparent);
}

TextStyle _cartPanelActionTextStyle({
  double fontSize = _kCartPanelActionFontSize,
  Color color = const Color(0xFF172033),
}) {
  return TextStyle(
    fontSize: fontSize,
    fontWeight: FontWeight.w700,
    color: color,
    height: 1.15,
  );
}

TextStyle? _clientNumberTextStyle(
  BuildContext context, {
  double? fontSize,
  Color color = const Color(0xFF172033),
}) {
  return Theme.of(context).textTheme.bodyMedium?.copyWith(
    fontSize: fontSize,
    fontWeight: FontWeight.w400,
    color: color,
    height: 1.15,
  );
}

TextStyle? _clientPriceTextStyle(
  BuildContext context, {
  double? fontSize,
  Color color = AppColors.logoBlue,
}) {
  return Theme.of(context).textTheme.bodyMedium?.copyWith(
    fontSize: fontSize,
    fontWeight: FontWeight.w400,
    color: color,
    height: 1.15,
  );
}

class _InlineCartCountBadge extends StatelessWidget {
  const _InlineCartCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Color(0xFFE31E24),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        formatCompactCount(count),
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w400,
          height: 1,
        ),
      ),
    );
  }
}

ThemeData _interactiveMenuTheme(BuildContext context) {
  return Theme.of(context).copyWith(
    focusColor: Colors.transparent,
    hoverColor: Colors.black.withValues(
      alpha: AppColors.neutralHoverOverlayAlpha,
    ),
    highlightColor: Colors.black.withValues(
      alpha: AppColors.neutralPressedOverlayAlpha,
    ),
    splashColor: Colors.transparent,
  );
}

WidgetStateProperty<Color?> _strongBlueBackground({Color? baseColor}) {
  return WidgetStateProperty.resolveWith((states) {
    return AppColors.brandingBlueInteractiveBackground(
      states,
      baseColor: baseColor ?? AppColors.logoBlue,
    );
  });
}

WidgetStateProperty<Color?> _lightBlueBackground({required Color baseColor}) {
  return WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.pressed)) {
      return AppColors.darken(baseColor, AppColors.neutralPressedOverlayAlpha);
    }
    if (states.contains(WidgetState.hovered)) {
      return AppColors.darken(baseColor, AppColors.neutralHoverOverlayAlpha);
    }
    if (states.contains(WidgetState.focused)) {
      return AppColors.darken(baseColor, AppColors.neutralFocusOverlayAlpha);
    }
    return baseColor;
  });
}

WidgetStateProperty<Color?> _strongBlueOverlay() {
  return WidgetStateProperty.resolveWith((states) {
    return Colors.transparent;
  });
}

double _controlExtentForWidth(double width) {
  return _catalogColumnsForWidth(width) <= 2 ? 36.0 : _kHeaderControlHeight;
}

List<Product> _sortProducts(
  List<Product> products,
  CatalogSortOption sortOption,
) {
  final sorted = [...products];
  switch (sortOption) {
    case CatalogSortOption.defaultOrder:
      return sorted;
    case CatalogSortOption.nameAscending:
      sorted.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    case CatalogSortOption.nameDescending:
      sorted.sort(
        (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
      );
    case CatalogSortOption.priceLowToHigh:
      sorted.sort(
        (a, b) => a.referencePriceCentavos.compareTo(b.referencePriceCentavos),
      );
    case CatalogSortOption.priceHighToLow:
      sorted.sort(
        (a, b) => b.referencePriceCentavos.compareTo(a.referencePriceCentavos),
      );
  }
  return sorted;
}

int _catalogColumnsForWidth(double width) {
  if (width >= 1300) {
    return 6;
  }
  if (width >= 1070) {
    return 5;
  }
  if (width >= 820) {
    return 4;
  }
  if (width >= 550) {
    return 3;
  }
  if (width >= 500) {
    return 2;
  }
  if (width > 360) {
    return 2;
  }
  return 1;
}

double _outerHorizontalPaddingForWidth(double width) {
  final columns = _catalogColumnsForWidth(width);
  if (columns <= 2) {
    return 24.0;
  }
  return 40.0;
}

double _cardDensityForWidth(double width) {
  const compactWidth = 210.0;
  const regularWidth = 240.0;
  if (width <= compactWidth) {
    return 1;
  }
  if (width >= regularWidth) {
    return 0;
  }
  return ((regularWidth - width) / (regularWidth - compactWidth)).clamp(0, 1);
}

class _Header extends StatelessWidget {
  const _Header({
    required this.searchController,
    required this.query,
    required this.onSearchChanged,
    required this.cartCount,
    required this.showCartPanelOpenState,
    required this.onCartTap,
  });

  final TextEditingController searchController;
  final String query;
  final ValueChanged<String> onSearchChanged;
  final int cartCount;
  final bool showCartPanelOpenState;
  final VoidCallback onCartTap;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 700;
    final stackSearch = isMobile;
    final columns = _catalogColumnsForWidth(width);
    final hideCartLabel =
        stackSearch && ((columns == 2 && width < 430) || columns == 1);
    final horizontalInset = _outerHorizontalPaddingForWidth(width);
    final searchGap = stackSearch ? 0.0 : 40.0;
    final trailingSearchPadding = showCartPanelOpenState ? 0.0 : searchGap;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalInset,
        16,
        horizontalInset,
        stackSearch ? 0 : 16,
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const BrandLogo(),
              if (stackSearch) const Expanded(child: SizedBox()),
              if (!stackSearch) SizedBox(width: searchGap),
              if (!stackSearch)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: trailingSearchPadding),
                    child: _SearchField(
                      searchController: searchController,
                      query: query,
                      onSearchChanged: onSearchChanged,
                    ),
                  ),
                ),
              if (!showCartPanelOpenState)
                _CartButton(
                  cartCount: cartCount,
                  showLabel: !hideCartLabel,
                  onTap: onCartTap,
                ),
            ],
          ),
          if (stackSearch) ...[
            const SizedBox(height: 16),
            _SearchField(
              searchController: searchController,
              query: query,
              onSearchChanged: onSearchChanged,
            ),
            const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.searchController,
    required this.query,
    required this.onSearchChanged,
    required this.cartCount,
    required this.loading,
    required this.hasOtherProducts,
    required this.categories,
    required this.selectedId,
    required this.onSelected,
    required this.showCartPanelOpenState,
    required this.onCartTap,
  });

  final TextEditingController searchController;
  final String query;
  final ValueChanged<String> onSearchChanged;
  final int cartCount;
  final bool loading;
  final bool hasOtherProducts;
  final List<Category> categories;
  final String selectedId;
  final ValueChanged<String> onSelected;
  final bool showCartPanelOpenState;
  final VoidCallback onCartTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ColoredBox(
        color: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(
              searchController: searchController,
              query: query,
              onSearchChanged: onSearchChanged,
              cartCount: cartCount,
              showCartPanelOpenState: showCartPanelOpenState,
              onCartTap: onCartTap,
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFE4E7EC)),
            if (loading)
              const _CategoryStripLoading()
            else
              _CategoryStrip(
                categories: categories,
                selectedId: selectedId,
                showOthers: hasOtherProducts,
                onSelected: onSelected,
              ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFE4E7EC)),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.searchController,
    required this.query,
    required this.onSearchChanged,
  });

  final TextEditingController searchController;
  final String query;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: searchController,
      onChanged: onSearchChanged,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: 'Search products...',
        suffixIcon: query.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: () {
                  searchController.clear();
                  onSearchChanged('');
                },
                icon: const Icon(Icons.close),
              ),
      ),
    );
  }
}

class _CartButton extends StatelessWidget {
  const _CartButton({
    required this.cartCount,
    this.showLabel = true,
    required this.onTap,
  });

  final int cartCount;
  final bool showLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const badgeTextStyle = TextStyle(
      color: Colors.white,
      fontSize: 10,
      fontWeight: FontWeight.w400,
      height: 1,
    );
    final badgeLabel = formatCompactCount(cartCount);
    final badgeTextPainter = TextPainter(
      text: TextSpan(text: badgeLabel, style: badgeTextStyle),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    final badgeWidth = math.max(16.0, badgeTextPainter.width + 8);
    final badgePadding = showLabel
        ? const EdgeInsets.only(right: 10)
        : const EdgeInsets.only(top: 4, right: 12);
    final buttonSize = showLabel ? null : math.max(48.0, badgeWidth + 30);
    return MousePressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: buttonSize,
        height: buttonSize ?? 48,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: showLabel ? 12 : 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: badgePadding,
                child: Badge(
                  isLabelVisible: cartCount > 0,
                  alignment: AlignmentDirectional.topEnd,
                  label: Text(
                    badgeLabel,
                    style: badgeTextStyle,
                  ),
                  child: const Icon(Icons.shopping_cart_outlined, size: 28),
                ),
              ),
              if (showLabel) ...[
                const SizedBox(width: 8),
                const Text(
                  'Cart',
                  style: TextStyle(fontWeight: FontWeight.w700, height: 1.15),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({
    required this.categories,
    required this.selectedId,
    required this.showOthers,
    required this.onSelected,
  });

  final List<Category> categories;
  final String selectedId;
  final bool showOthers;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final edgeInset = _outerHorizontalPaddingForWidth(
      MediaQuery.of(context).size.width,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            SizedBox(width: edgeInset),
            _CategoryPill(
              label: 'All',
              selected: selectedId == 'all',
              onTap: () => onSelected('all'),
            ),
            for (var i = 0; i < categories.length; i++) ...[
              const SizedBox(width: 10),
              _CategoryPill(
                label: categories[i].name,
                selected: selectedId == categories[i].id.toString(),
                onTap: () => onSelected(categories[i].id.toString()),
              ),
            ],
            if (showOthers) ...[
              const SizedBox(width: 10),
              _CategoryPill(
                label: 'Others',
                selected: selectedId == 'others',
                onTap: () => onSelected('others'),
              ),
            ],
            SizedBox(width: edgeInset),
          ],
        ),
      ),
    );
  }
}

class _CategoryStripLoading extends StatelessWidget {
  const _CategoryStripLoading();

  @override
  Widget build(BuildContext context) {
    final edgeInset = _outerHorizontalPaddingForWidth(
      MediaQuery.of(context).size.width,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Row(
          children: [
            SizedBox(width: edgeInset),
            for (final width in const [74.0, 96.0, 92.0, 110.0, 88.0]) ...[
              _ShimmerSurface(
                child: Container(
                  width: width,
                  height: _controlExtentForWidth(
                    MediaQuery.of(context).size.width,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F4F7),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFE4E7EC)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            SizedBox(width: edgeInset),
          ],
        ),
      ),
    );
  }
}

class _CatalogLoadingSections extends StatelessWidget {
  const _CatalogLoadingSections({
    required this.horizontalPadding,
    required this.cardHeight,
    required this.columns,
    required this.cardAspectRatio,
    required this.bottomPadding,
  });

  final double horizontalPadding;
  final double cardHeight;
  final int columns;
  final double cardAspectRatio;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        18,
        horizontalPadding,
        bottomPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CatalogLoadingHeader(),
          const SizedBox(height: 18),
          SizedBox(
            height: cardHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 6,
              separatorBuilder: (context, index) => const SizedBox(width: 16),
              itemBuilder: (context, index) => SizedBox(
                width: cardHeight * cardAspectRatio,
                child: const _CatalogLoadingProductCard(),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const _CatalogLoadingHeader(),
          const SizedBox(height: 18),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: columns * 2,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: cardAspectRatio,
            ),
            itemBuilder: (context, index) => const _CatalogLoadingProductCard(),
          ),
        ],
      ),
    );
  }
}

class _CatalogLoadingHeader extends StatelessWidget {
  const _CatalogLoadingHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ShimmerSurface(
          child: Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: Color(0xFFF2F4F7),
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 10),
        _ShimmerSurface(
          child: Container(
            width: 148,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F4F7),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }
}

class _CatalogLoadingProductCard extends StatelessWidget {
  const _CatalogLoadingProductCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 10,
            child: _ShimmerSurface(
              child: Container(
                color: const Color(0xFFF2F4F7),
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE4E7EC)),
          Expanded(
            flex: 7,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ShimmerSurface(
                    child: Container(
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F4F7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ShimmerSurface(
                    child: Container(
                      width: 84,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F4F7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: _ShimmerSurface(
                          child: Container(
                            height: 16,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2F4F7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _ShimmerSurface(
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F4F7),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimmerSurface extends StatefulWidget {
  const _ShimmerSurface({required this.child});

  final Widget child;

  @override
  State<_ShimmerSurface> createState() => _ShimmerSurfaceState();
}

class _ShimmerSurfaceState extends State<_ShimmerSurface>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1350),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final width = bounds.width <= 0 ? 1.0 : bounds.width;
            return LinearGradient(
              begin: Alignment(-1.6 + (_controller.value * 2.8), 0),
              end: Alignment(-0.6 + (_controller.value * 2.8), 0),
              colors: const [
                Color(0xFFE5E7EB),
                Color(0xFFD1D5DB),
                Color(0xFFE5E7EB),
              ],
              stops: const [0.15, 0.5, 0.85],
            ).createShader(Rect.fromLTWH(0, 0, width, bounds.height));
          },
          child: child,
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.icon,
    this.iconColor,
    this.titleFontSize,
    this.trailing,
  });

  final String title;
  final IconData? icon;
  final Color? iconColor;
  final double? titleFontSize;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: iconColor ?? AppColors.logoBlue, size: 28),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.15,
              fontSize: titleFontSize,
            ),
          ),
        ),
        if (trailing != null) ...[trailing!],
      ],
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.selected, required this.onSelected});

  final CatalogSortOption selected;
  final ValueChanged<CatalogSortOption> onSelected;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    final controlExtent = _controlExtentForWidth(
      MediaQuery.of(context).size.width,
    );
    final popupTheme = _interactiveMenuTheme(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isMobile) ...[
          const Text(
            'Sort by',
            style: TextStyle(fontWeight: FontWeight.w700, height: 1.15),
          ),
          const SizedBox(width: 8),
        ],
        Theme(
          data: popupTheme,
          child: Builder(
            builder: (themedContext) {
              return MousePressable(
                onTap: () async {
                  final button = themedContext.findRenderObject() as RenderBox;
                  final overlay =
                      Overlay.of(themedContext).context.findRenderObject()
                          as RenderBox;
                  final result = await showMenu<CatalogSortOption>(
                    context: themedContext,
                    color: Colors.white,
                    surfaceTintColor: Colors.white,
                    menuPadding: EdgeInsets.zero,
                    position: RelativeRect.fromRect(
                      Rect.fromPoints(
                        button.localToGlobal(Offset.zero, ancestor: overlay),
                        button.localToGlobal(
                          button.size.bottomRight(Offset.zero),
                          ancestor: overlay,
                        ),
                      ),
                      Offset.zero & overlay.size,
                    ),
                    items: [
                      for (final option in CatalogSortOption.values)
                        PopupMenuItem<CatalogSortOption>(
                          value: option,
                          mouseCursor: SystemMouseCursors.click,
                          child: Text(
                            option.label,
                            style: const TextStyle(height: 1.15),
                          ),
                        ),
                    ],
                  );
                  if (result != null) {
                    onSelected(result);
                  }
                },
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  height: controlExtent,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFE4E7EC)),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          selected.label,
                          style: const TextStyle(height: 1.15),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final controlExtent = _controlExtentForWidth(
      MediaQuery.of(context).size.width,
    );
    return MousePressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      stateBuilder: selected
          ? (context, hovered, pressed, child) {
              final states = <WidgetState>{
                if (hovered) WidgetState.hovered,
                if (pressed) WidgetState.pressed,
              };
              return Container(
                height: controlExtent,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: AppColors.brandingBlueInteractiveBackground(states),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.brandingBlueInteractiveBackground(states),
                  ),
                ),
                child: Center(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.15,
                    ),
                  ),
                ),
              );
            }
          : null,
      hoverOverlayAlpha: selected ? 0 : AppColors.neutralHoverOverlayAlpha,
      pressedOverlayAlpha: selected ? 0 : AppColors.neutralPressedOverlayAlpha,
      child: Container(
        height: controlExtent,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: selected ? AppColors.logoBlue : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.logoBlue : const Color(0xFFE4E7EC),
          ),
        ),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : const Color(0xFF172033),
              height: 1.15,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroBanner extends StatefulWidget {
  const _HeroBanner({
    required this.banners,
    required this.isMobile,
    required this.horizontalPadding,
    required this.columns,
    required this.cardWidth,
    required this.gridSpacing,
  });

  final List<AppBanner> banners;
  final bool isMobile;
  final double horizontalPadding;
  final int columns;
  final double cardWidth;
  final double gridSpacing;

  @override
  State<_HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<_HeroBanner> {
  final _bannerScrollController = ScrollController();
  bool _isBannerInteracting = false;
  double _currentBannerItemExtent = 0;

  int get _activeBannerIndex {
    if (!_bannerScrollController.hasClients || widget.banners.length <= 1) {
      return 0;
    }
    if (_currentBannerItemExtent <= 0) {
      return 0;
    }
    final min = _bannerScrollController.position.minScrollExtent;
    final relativeOffset = (_bannerScrollController.offset - min).clamp(
      0.0,
      double.infinity,
    );
    final index = (relativeOffset / _currentBannerItemExtent).round();
    return index.clamp(0, widget.banners.length - 1);
  }

  bool get _showLeftControl =>
      _bannerScrollController.hasClients &&
      _bannerScrollController.offset >
          _bannerScrollController.position.minScrollExtent + 0.5;

  bool get _showRightControl =>
      _bannerScrollController.hasClients &&
      _bannerScrollController.offset <
          _bannerScrollController.position.maxScrollExtent - 0.5;

  bool get _showBannerIndicator =>
      _bannerScrollController.hasClients &&
      (_bannerScrollController.position.maxScrollExtent -
                  _bannerScrollController.position.minScrollExtent)
              .abs() >
          0.5;

  void _handleBannerScroll() {
    if (mounted) {
      setState(() {});
    }
  }

  void _scheduleBannerVisibilityRefresh() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _bannerScrollController.hasClients) {
        setState(() {});
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _bannerScrollController.addListener(_handleBannerScroll);
    _scheduleBannerVisibilityRefresh();
  }

  @override
  void didUpdateWidget(covariant _HeroBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banners.length != widget.banners.length ||
        oldWidget.columns != widget.columns ||
        oldWidget.cardWidth != widget.cardWidth ||
        oldWidget.gridSpacing != widget.gridSpacing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_bannerScrollController.hasClients) {
          return;
        }
        unawaited(_snapBannerToNearest(jumpOnly: true));
      });
    }
  }

  Future<void> _snapBannerToNearest({bool jumpOnly = false}) async {
    if (!_bannerScrollController.hasClients || widget.banners.length <= 1) {
      return;
    }
    if (_currentBannerItemExtent <= 0) {
      return;
    }

    final position = _bannerScrollController.position;
    final current = position.pixels;
    final min = position.minScrollExtent;
    final max = position.maxScrollExtent.clamp(
      position.minScrollExtent,
      double.infinity,
    );
    final relativeOffset = (current - min).clamp(0.0, double.infinity);
    final nearestIndex = (relativeOffset / _currentBannerItemExtent).round();
    final target = (min + (nearestIndex * _currentBannerItemExtent)).clamp(
      min,
      max,
    );

    if ((target - current).abs() < 0.5) {
      return;
    }

    if (jumpOnly) {
      _bannerScrollController.jumpTo(target);
      return;
    }

    await _bannerScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  bool _handleBannerSnapNotification(ScrollNotification notification) {
    final isInteracting =
        notification is ScrollStartNotification ||
        (notification is UserScrollNotification &&
            notification.direction != ScrollDirection.idle);
    final isSettled =
        notification is ScrollEndNotification ||
        (notification is UserScrollNotification &&
            notification.direction == ScrollDirection.idle);
    if (isInteracting && !_isBannerInteracting && mounted) {
      setState(() => _isBannerInteracting = true);
    } else if (isSettled && _isBannerInteracting && mounted) {
      setState(() => _isBannerInteracting = false);
    }

    final shouldSnap =
        notification is ScrollEndNotification ||
        (notification is UserScrollNotification &&
            notification.direction == ScrollDirection.idle);
    if (shouldSnap) {
      unawaited(_snapBannerToNearest());
    }
    return false;
  }

  Future<void> _scrollBannerBy(double delta) async {
    if (!_bannerScrollController.hasClients) {
      return;
    }
    final position = _bannerScrollController.position;
    final target = (_bannerScrollController.offset + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    await _bannerScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
    await _snapBannerToNearest();
  }

  @override
  void dispose() {
    _bannerScrollController.removeListener(_handleBannerScroll);
    _bannerScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final controlExtent = _controlExtentForWidth(
          MediaQuery.of(context).size.width,
        );
        final bannerGap = widget.gridSpacing;
        final units = switch (widget.columns) {
          1 => 1.0,
          2 => 2.0,
          3 => 3.0,
          4 => 2.0,
          5 => 2.5,
          _ => 3.0,
        };
        final internalGaps = switch (widget.columns) {
          1 => 0,
          2 => 1,
          3 => 2,
          4 => 1,
          5 => 1.5,
          _ => 2,
        };
        final bannerWidth =
            (widget.cardWidth * units) + (widget.gridSpacing * internalGaps);
        _currentBannerItemExtent = bannerWidth + bannerGap;
        _scheduleBannerVisibilityRefresh();

        final bannerHeight = bannerWidth / 3;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: bannerHeight,
              child: Stack(
                children: [
                  NotificationListener<ScrollNotification>(
                    onNotification: _handleBannerSnapNotification,
                    child: ListView.separated(
                      controller: _bannerScrollController,
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(
                        horizontal: widget.horizontalPadding,
                      ),
                      physics: const ClampingScrollPhysics(),
                      itemCount: widget.banners.length,
                      separatorBuilder: (context, index) =>
                          SizedBox(width: bannerGap),
                      itemBuilder: (context, index) => SizedBox(
                        key: ValueKey('banner-${widget.banners[index].id}'),
                        width: bannerWidth,
                        child: MousePressable(
                          onTap: () {
                            final externalUrl =
                                widget.banners[index].externalUrl?.trim() ?? '';
                            if (externalUrl.isEmpty) {
                              return;
                            }
                            unawaited(openExternalUrl(externalUrl));
                          },
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                          child: _PromoBannerPlaceholder(
                            banner: widget.banners[index],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!_isBannerInteracting)
                    IgnorePointer(
                      child: _HorizontalEdgeMasks(
                        sideWidth: widget.horizontalPadding,
                      ),
                    ),
                  if (_showLeftControl)
                    Positioned(
                      left: widget.horizontalPadding - (controlExtent / 2) + 2,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _ScrollChevronButton(
                          icon: Icons.chevron_left_rounded,
                          size: controlExtent,
                          onTap: () =>
                              _scrollBannerBy(-bannerWidth - bannerGap),
                        ),
                      ),
                    ),
                  if (_showRightControl)
                    Positioned(
                      right: widget.horizontalPadding - (controlExtent / 2) + 2,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _ScrollChevronButton(
                          icon: Icons.chevron_right_rounded,
                          size: controlExtent,
                          onTap: () => _scrollBannerBy(bannerWidth + bannerGap),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 8,
              width: double.infinity,
              child: _showBannerIndicator
                  ? Center(
                      child: Transform.translate(
                        offset: const Offset(0, 2),
                        child: _BannerIndexIndicator(
                          activeIndex: _activeBannerIndex,
                          count: widget.banners.length,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 4),
          ],
        );
      },
    );
  }
}

class _PromoBannerPlaceholder extends StatelessWidget {
  const _PromoBannerPlaceholder({required this.banner});

  final AppBanner banner;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: const BoxDecoration(color: Colors.white),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE4E7EC), width: 1),
          ),
          child: _BannerImage(imageUrl: banner.imageUrl),
        ),
      ),
    );
  }
}

class _BannerImage extends StatelessWidget {
  const _BannerImage({required this.imageUrl});

  static const _webBannerImageProxyPrefix = String.fromEnvironment(
    'BANNER_IMAGE_PROXY_PREFIX',
    defaultValue: '',
  );

  final String imageUrl;

  String get _resolvedImageUrl {
    if (!kIsWeb ||
        _webBannerImageProxyPrefix.isEmpty ||
        imageUrl.startsWith('assets/') ||
        !(imageUrl.startsWith('http://') || imageUrl.startsWith('https://'))) {
      return imageUrl;
    }
    return '$_webBannerImageProxyPrefix${Uri.encodeComponent(imageUrl)}';
  }

  @override
  Widget build(BuildContext context) {
    if (imageUrl.startsWith('assets/')) {
      return _BannerFallbackPlaceholder(imageAssetPath: imageUrl);
    }

    return Image.network(
      _resolvedImageUrl,
      fit: BoxFit.cover,
      cacheWidth: 400,
      cacheHeight: 400,
      webHtmlElementStrategy: kIsWeb
          ? WebHtmlElementStrategy.prefer
          : WebHtmlElementStrategy.never,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return const _BannerFallbackPlaceholder();
      },
      errorBuilder: (context, error, stackTrace) {
        return const _BannerFallbackPlaceholder();
      },
    );
  }
}

class _BannerFallbackPlaceholder extends StatelessWidget {
  const _BannerFallbackPlaceholder({
    this.imageAssetPath = 'assets/branding/as_logo_lite.png',
  });

  final String imageAssetPath;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          color: AppColors.logoBlue,
          child: Center(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                constraints.maxWidth * 0.125,
                24,
              ),
              child: Image.asset(imageAssetPath, fit: BoxFit.contain),
            ),
          ),
        );
      },
    );
  }
}

class _ScrollChevronButton extends StatelessWidget {
  const _ScrollChevronButton({
    required this.icon,
    required this.onTap,
    required this.size,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return MousePressable(
      onTap: onTap,
      shape: BoxShape.circle,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE4E7EC)),
        ),
        child: Icon(
          icon,
          color: const Color(0xFF172033),
          size: size >= 44 ? 24 : 20,
        ),
      ),
    );
  }
}

class _HorizontalEdgeMasks extends StatelessWidget {
  const _HorizontalEdgeMasks({required this.sideWidth});

  final double sideWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Row(
        children: [
          Container(
            width: sideWidth,
            color: AppColors.homeScrollableBackground,
          ),
          const Spacer(),
          Container(
            width: sideWidth,
            color: AppColors.homeScrollableBackground,
          ),
        ],
      ),
    );
  }
}

class _DesktopCartPanel extends ConsumerWidget {
  const _DesktopCartPanel({
    required this.width,
    required this.scrollController,
    required this.settings,
    required this.serviceableBarangays,
    required this.customerDraft,
    required this.customerControllers,
    required this.cart,
    required this.matchingOrders,
    required this.selectedThreadId,
    required this.previousOrdersExpanded,
    required this.totalCentavos,
    required this.submitting,
    required this.onClose,
    required this.onContactUs,
    required this.onThreadSelected,
    required this.onPreviousOrdersExpandedChanged,
    required this.onDraftChanged,
    required this.onReviewOrder,
    required this.onOrderAgain,
    this.isBottomSheet = false,
  });

  final double width;
  final ScrollController scrollController;
  final AppSettings settings;
  final List<String> serviceableBarangays;
  final CustomerDraft customerDraft;
  final _CustomerControllers customerControllers;
  final List<CartItem> cart;
  final List<OrderRequest> matchingOrders;
  final String selectedThreadId;
  final bool previousOrdersExpanded;
  final int totalCentavos;
  final bool submitting;
  final VoidCallback onClose;
  final VoidCallback onContactUs;
  final ValueChanged<String> onThreadSelected;
  final ValueChanged<bool> onPreviousOrdersExpandedChanged;
  final Future<void> Function({FulfillmentMethod? method}) onDraftChanged;
  final Future<void> Function() onReviewOrder;
  final Future<void> Function(OrderRequest order) onOrderAgain;
  final bool isBottomSheet;

  Future<void> _scrollToRevealBarangayField(BuildContext fieldContext) async {
    if (!isBottomSheet || !scrollController.hasClients) {
      return;
    }
    await WidgetsBinding.instance.endOfFrame;
    if (!scrollController.hasClients || !fieldContext.mounted) {
      return;
    }

    await Scrollable.ensureVisible(
      fieldContext,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      alignment: 0.08,
    );

    await WidgetsBinding.instance.endOfFrame;
    if (!scrollController.hasClients || !fieldContext.mounted) {
      return;
    }

    final renderObject = fieldContext.findRenderObject();
    if (renderObject is! RenderBox) {
      return;
    }

    final media = MediaQuery.of(fieldContext);
    final fieldTop = renderObject.localToGlobal(Offset.zero).dy;
    final fieldHeight = renderObject.size.height;
    const overlayGap = 12.0;
    const searchFieldHeight = 68.0;
    const bottomOuterPadding = 24.0;
    const targetVisiblePadding = 16.0;
    final visibleBottom =
        media.size.height - media.viewInsets.bottom - bottomOuterPadding;
    final requiredBottom =
        fieldTop +
        fieldHeight +
        overlayGap +
        searchFieldHeight +
        targetVisiblePadding;
    final missingSpace = requiredBottom - visibleBottom;

    if (missingSpace <= 0) {
      return;
    }

    final nextOffset = math.min(
      scrollController.offset + missingSpace,
      scrollController.position.maxScrollExtent,
    );
    if ((nextOffset - scrollController.offset).abs() < 1) {
      return;
    }
    await scrollController.animateTo(
      nextOffset,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keyboardInset = isBottomSheet
        ? MediaQuery.of(context).viewInsets.bottom
        : 0.0;
    final selectedOrder = selectedThreadId == 'current'
        ? null
        : matchingOrders.cast<OrderRequest?>().firstWhere(
            (order) => '${order?.id}' == selectedThreadId,
            orElse: () => null,
          );
    final finalCartCount = cart.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );
    final isCurrentSelection = selectedOrder == null;
    final showPrimaryAction = isCurrentSelection ? cart.isNotEmpty : true;
    final selectedItemCount = isCurrentSelection
        ? finalCartCount
        : selectedOrder.items.fold<int>(
            0,
            (sum, item) => sum + item.requestedQuantity,
          );
    final selectedTotalCentavos = isCurrentSelection
        ? totalCentavos
        : selectedOrder.estimatedTotalCentavos;

    return SafeArea(
      left: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: Container(
          width: width,
          decoration: BoxDecoration(
            color: Colors.white,
            border: isBottomSheet
                ? null
                : const Border(left: BorderSide(color: Color(0xFFE4E7EC))),
            borderRadius: isBottomSheet
                ? const BorderRadius.vertical(top: Radius.circular(28))
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isBottomSheet) ...[
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 48,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD0D5DD),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  isBottomSheet ? 16 : 24,
                  24,
                  0,
                ),
                child: Row(
                  children: [
                    MousePressable(
                      onTap: isCurrentSelection
                          ? null
                          : () => onThreadSelected('current'),
                      borderRadius: BorderRadius.circular(16),
                      hoverOverlayAlpha: isCurrentSelection
                          ? 0
                          : AppColors.neutralHoverOverlayAlpha,
                      pressedOverlayAlpha: isCurrentSelection
                          ? 0
                          : AppColors.neutralPressedOverlayAlpha,
                      child: SizedBox(
                        height: 48,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 6,
                            right: 12,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: Badge(
                                  isLabelVisible: finalCartCount > 0,
                                  alignment: AlignmentDirectional.topEnd,
                                  label: Text(
                                    formatCompactCount(finalCartCount),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w400,
                                      height: 1,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.shopping_cart_outlined,
                                    size: 28,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Cart',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      height: 1.15,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    MousePressable(
                      onTap: onClose,
                      borderRadius: BorderRadius.circular(12),
                      child: const SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(Icons.close_rounded),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(
                    isBottomSheet ? 0 : 24,
                    0,
                    isBottomSheet ? 0 : 24,
                    24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (matchingOrders.isNotEmpty) ...[
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isBottomSheet ? 24 : 0,
                          ),
                          child: _DesktopCartThreadsCard(
                            matchingOrders: matchingOrders,
                            selectedThreadId: selectedThreadId,
                            customerDraft: customerDraft,
                            currentCartCount: finalCartCount,
                            previousOrdersExpanded: previousOrdersExpanded,
                            onSelected: onThreadSelected,
                            onPreviousOrdersExpandedChanged:
                                onPreviousOrdersExpandedChanged,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isBottomSheet ? 24 : 0,
                        ),
                        child: _DesktopCartCustomerCard(
                          settings: settings,
                          serviceableBarangays: serviceableBarangays,
                          draft: customerDraft,
                        controllers: customerControllers,
                        selectedOrder: selectedOrder,
                        onContactUs: onContactUs,
                        onDraftChanged: onDraftChanged,
                        onBarangayActivated: _scrollToRevealBarangayField,
                      ),
                    ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isBottomSheet ? 24 : 0,
                        ),
                        child: _DesktopCartThreadDetailCard(
                          selectedOrder: selectedOrder,
                          previousOrdersExpanded: previousOrdersExpanded,
                          currentCartCount: finalCartCount,
                          cart: cart,
                          totalCentavos: totalCentavos,
                          onContactUs: onContactUs,
                          onBackToCart: () => onThreadSelected('current'),
                          onContinueShopping: onClose,
                        ),
                      ),
                      if (showPrimaryAction) ...[
                        const SizedBox(height: 16),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isBottomSheet ? 24 : 0,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '$selectedItemCount item${selectedItemCount == 1 ? '' : 's'}',
                                  style: _clientNumberTextStyle(context),
                                ),
                              ),
                              Text(
                                formatPesos(selectedTotalCentavos),
                                style: _clientPriceTextStyle(context),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isBottomSheet ? 24 : 0,
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                shape: const StadiumBorder(),
                              ),
                              onPressed: submitting
                                  ? null
                                  : isCurrentSelection
                                  ? onReviewOrder
                                  : () => onOrderAgain(selectedOrder),
                              child: submitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : Text(
                                      isCurrentSelection
                                          ? 'Place Order'
                                          : 'Order Again',
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopCartCustomerCard extends ConsumerStatefulWidget {
  const _DesktopCartCustomerCard({
    required this.settings,
    required this.serviceableBarangays,
    required this.draft,
    required this.controllers,
    required this.selectedOrder,
    required this.onContactUs,
    required this.onDraftChanged,
    required this.onBarangayActivated,
  });

  final AppSettings settings;
  final List<String> serviceableBarangays;
  final CustomerDraft draft;
  final _CustomerControllers controllers;
  final OrderRequest? selectedOrder;
  final VoidCallback onContactUs;
  final Future<void> Function({FulfillmentMethod? method}) onDraftChanged;
  final Future<void> Function(BuildContext fieldContext) onBarangayActivated;

  @override
  ConsumerState<_DesktopCartCustomerCard> createState() =>
      _DesktopCartCustomerCardState();
}

class _DesktopCartCustomerCardState
    extends ConsumerState<_DesktopCartCustomerCard> {
  bool _isBarangayMenuOpen = false;

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final controllers = widget.controllers;
    final selectedOrder = widget.selectedOrder;
    final isReadOnly = selectedOrder != null;
    final effectiveDraft = selectedOrder?.customer ?? widget.draft;
    final appController = ref.read(appControllerProvider.notifier);
    final barangays = {
      ...widget.serviceableBarangays,
      if (controllers.barangay.text.trim().isNotEmpty)
        controllers.barangay.text.trim(),
    }.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final cutoffReference = isReadOnly ? selectedOrder.createdAt : null;
    final hideStreetLabel =
        _isBarangayMenuOpen && controllers.street.text.trim().isNotEmpty;
    final cutoffMessage =
        effectiveDraft.fulfillmentMethod == FulfillmentMethod.delivery &&
            effectiveDraft.barangay.trim().isNotEmpty
        ? appController.barangayCutoffMessage(
            effectiveDraft.barangay,
            now: cutoffReference,
          )
        : null;
    final isCutoffReached =
        effectiveDraft.fulfillmentMethod == FulfillmentMethod.delivery &&
            effectiveDraft.barangay.trim().isNotEmpty
        ? appController.isBarangayCutoffReached(
            effectiveDraft.barangay,
            now: cutoffReference,
          )
        : false;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Details',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF172033),
                    height: 1.15,
                  ),
                ),
              ),
              if (isReadOnly)
                const Icon(
                  Icons.lock_rounded,
                  size: 18,
                  color: Color(0xFF667085),
                )
              else
                MousePressable(
                  onTap: widget.onContactUs,
                  hoverOverlayAlpha: 0,
                  pressedOverlayAlpha: 0,
                  child: Text(
                    'Need Help?',
                    style: _cartPanelActionTextStyle(color: AppColors.logoBlue),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (isReadOnly) ...[
            _ReadOnlyDetailsField(label: 'Name', value: effectiveDraft.name),
            const SizedBox(height: 12),
            _ReadOnlyDetailsField(
              label: 'Phone',
              value: effectiveDraft.mobileNumber,
            ),
          ] else ...[
            TextField(
              controller: controllers.name,
              onChanged: (_) => widget.onDraftChanged(),
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controllers.mobile,
              keyboardType: TextInputType.number,
              inputFormatters: [
                LengthLimitingTextInputFormatter(11),
                _PhilippineMobileInputFormatter(),
              ],
              onChanged: (_) => widget.onDraftChanged(),
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
          ],
          if ((settings.requirePlaceForDeliveryOnly &&
                  effectiveDraft.fulfillmentMethod ==
                      FulfillmentMethod.delivery) ||
              (!settings.requirePlaceForDeliveryOnly)) ...[
            const SizedBox(height: 12),
            if (isReadOnly)
              _ReadOnlyDetailsField(
                label: 'Barangay',
                value: effectiveDraft.barangay,
              )
            else
              _BarangayField(
                controller: controllers.barangay,
                items: barangays,
                onActivated: widget.onBarangayActivated,
                onMenuVisibilityChanged: (isOpen) {
                  if (!mounted || _isBarangayMenuOpen == isOpen) {
                    return;
                  }
                  setState(() => _isBarangayMenuOpen = isOpen);
                },
                onChanged: () async {
                  await widget.onDraftChanged();
                },
              ),
            if (effectiveDraft.fulfillmentMethod ==
                    FulfillmentMethod.delivery &&
                effectiveDraft.barangay.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              if (isReadOnly)
                _ReadOnlyDetailsField(
                  label: 'Street/Landmark',
                  value: effectiveDraft.addressStreet.trim().isNotEmpty
                      ? effectiveDraft.addressStreet
                      : effectiveDraft.addressLandmark,
                )
              else
                TextField(
                  controller: controllers.street,
                  onChanged: (_) => widget.onDraftChanged(),
                  decoration: InputDecoration(
                    labelText: hideStreetLabel ? null : 'Street/Landmark',
                  ),
                ),
              if (cutoffMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  cutoffMessage,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isCutoffReached
                        ? const Color(0xFFE31E24)
                        : const Color(0xFF667085),
                    height: 1.25,
                  ),
                ),
              ],
            ],
          ],
          const SizedBox(height: 12),
          IgnorePointer(
            ignoring: isReadOnly,
            child: Opacity(
              opacity: isReadOnly ? 0.72 : 1,
                child: RadioGroup<FulfillmentMethod>(
                  groupValue: effectiveDraft.fulfillmentMethod,
                  onChanged: (value) async {
                    await widget.onDraftChanged(method: value);
                  },
                child: Row(
                  children: [
                    Expanded(
                      child: RadioListTile<FulfillmentMethod>(
                        value: FulfillmentMethod.pickup,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: const VisualDensity(
                          horizontal: -4,
                          vertical: -4,
                        ),
                        title: const Text('Pickup'),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<FulfillmentMethod>(
                        value: FulfillmentMethod.delivery,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: const VisualDensity(
                          horizontal: -4,
                          vertical: -4,
                        ),
                        title: const Text('Delivery'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyDetailsField extends StatelessWidget {
  const _ReadOnlyDetailsField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: Text(
        value.trim().isEmpty ? '-' : value.trim(),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF172033),
          height: 1.15,
        ),
      ),
    );
  }
}

class _BarangayField extends StatefulWidget {
  const _BarangayField({
    required this.controller,
    required this.items,
    required this.onActivated,
    required this.onMenuVisibilityChanged,
    required this.onChanged,
  });

  final TextEditingController controller;
  final List<String> items;
  final Future<void> Function(BuildContext fieldContext) onActivated;
  final ValueChanged<bool> onMenuVisibilityChanged;
  final Future<void> Function() onChanged;

  @override
  State<_BarangayField> createState() => _BarangayFieldState();
}

class _BarangayFieldState extends State<_BarangayField> {
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _fieldKey = GlobalKey();
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  OverlayEntry? _overlayEntry;
  bool _menuOpen = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode()..addListener(_handleSearchFocusChange);
    widget.controller.addListener(_handleControllerChange);
  }

  @override
  void didUpdateWidget(covariant _BarangayField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChange);
      widget.controller.addListener(_handleControllerChange);
    }
  }

  @override
  void dispose() {
    _removeOverlay(notify: false);
    _searchController.dispose();
    _searchFocusNode
      ..removeListener(_handleSearchFocusChange)
      ..dispose();
    widget.controller.removeListener(_handleControllerChange);
    super.dispose();
  }

  void _handleSearchFocusChange() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleControllerChange() {
    if (mounted) {
      _overlayEntry?.markNeedsBuild();
      setState(() {});
    }
  }

  List<String> get _matches {
    final query = _searchController.text.trim().toLowerCase();
    return widget.items
        .where((item) => query.isEmpty || item.toLowerCase().contains(query))
        .toList();
  }

  bool get _showNoMatchState =>
      _searchController.text.trim().isNotEmpty && _matches.isEmpty;

  void _showOverlay() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(widget.onActivated(context));
      _overlayEntry ??= _buildOverlayEntry();
      final overlay = Overlay.of(context);
      if (_overlayEntry!.mounted) {
        _overlayEntry!.markNeedsBuild();
      } else {
        overlay.insert(_overlayEntry!);
      }
      _searchFocusNode.requestFocus();
      if (mounted) {
        setState(() => _menuOpen = true);
      }
      widget.onMenuVisibilityChanged(true);
    });
  }

  void _removeOverlay({bool notify = true}) {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _searchController.clear();
    widget.onMenuVisibilityChanged(false);
    if (notify && mounted) {
      setState(() => _menuOpen = false);
    }
  }

  Future<void> _clearBarangaySelection() async {
    widget.controller.clear();
    _searchController.clear();
    _overlayEntry?.markNeedsBuild();
    if (mounted) {
      setState(() {});
    }
    await widget.onChanged();
  }

  OverlayEntry _buildOverlayEntry() {
    return OverlayEntry(
      builder: (context) {
        final renderBox =
            _fieldKey.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox == null) {
          return const SizedBox.shrink();
        }
        final size = renderBox.size;
        final fieldOffset = renderBox.localToGlobal(Offset.zero);
        final media = MediaQuery.of(context);
        const overlayGap = 12.0;
        const bottomOuterPadding = 24.0;
        final availableHeight =
            media.size.height -
            fieldOffset.dy -
            size.height -
            overlayGap -
            media.padding.bottom -
            bottomOuterPadding;
        final resolvedMaxHeight = availableHeight.clamp(160.0, 480.0);
        final matches = _matches;
        final showNoMatchState = _showNoMatchState;
        return Positioned.fill(
          child: IgnorePointer(
            ignoring: false,
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _removeOverlay,
                    child: const SizedBox.expand(),
                  ),
                ),
                CompositedTransformFollower(
                  link: _layerLink,
                  showWhenUnlinked: false,
                  offset: Offset(0, size.height + overlayGap),
                  child: Material(
                    color: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: bottomOuterPadding),
                      child: Container(
                        width: size.width,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE4E7EC)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: resolvedMaxHeight),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: TextField(
                                  controller: _searchController,
                                  focusNode: _searchFocusNode,
                                  onChanged: (_) {
                                    _overlayEntry?.markNeedsBuild();
                                    if (mounted) {
                                      setState(() {});
                                    }
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'Search barangay...',
                                    suffixIcon:
                                        widget.controller.text.trim().isNotEmpty ||
                                            _searchController.text.trim().isNotEmpty
                                        ? IconButton(
                                            tooltip: 'Clear barangay',
                                            onPressed: () async {
                                              await _clearBarangaySelection();
                                            },
                                            icon: const Icon(Icons.close),
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                              const Divider(
                                height: 1,
                                thickness: 1,
                                color: Color(0xFFE4E7EC),
                              ),
                              if (showNoMatchState)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  child: Text(
                                    'No matching barangays',
                                    style: Theme.of(context).textTheme.bodyMedium
                                        ?.copyWith(
                                          color: const Color(0xFF667085),
                                          height: 1.15,
                                        ),
                                  ),
                                )
                              else
                                Flexible(
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    itemCount: matches.length,
                                    itemBuilder: (context, index) {
                                      return MousePressable(
                                        onTap: () async {
                                          widget.controller.text = matches[index];
                                          widget.controller.selection =
                                              TextSelection.collapsed(
                                                offset:
                                                    widget.controller.text.length,
                                              );
                                          _removeOverlay();
                                          await widget.onChanged();
                                        },
                                        borderRadius: BorderRadius.circular(0),
                                        child: Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.fromLTRB(
                                            14,
                                            10,
                                            14,
                                            10,
                                          ),
                                          constraints: const BoxConstraints(
                                            minHeight: 44,
                                          ),
                                          alignment: Alignment.centerLeft,
                                          decoration: BoxDecoration(
                                            border: index == matches.length - 1
                                                ? null
                                                : const Border(
                                                    bottom: BorderSide(
                                                      color: Color(0xFFE4E7EC),
                                                    ),
                                                  ),
                                          ),
                                          child: Text(
                                            matches[index],
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyLarge
                                                ?.copyWith(
                                                  height: 1.15,
                                                  color: const Color(0xFF101828),
                                                ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: KeyedSubtree(
        key: _fieldKey,
        child: MousePressable(
          onTap: _menuOpen ? _removeOverlay : _showOverlay,
          borderRadius: BorderRadius.circular(16),
          child: InputDecorator(
            decoration: const InputDecoration(),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.controller.text.trim().isEmpty
                        ? 'Barangay'
                        : widget.controller.text.trim(),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.15,
                      color: const Color(0xFF101828),
                    ),
                  ),
                ),
                Icon(
                  _menuOpen
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopCartThreadsCard extends StatelessWidget {
  const _DesktopCartThreadsCard({
    required this.matchingOrders,
    required this.selectedThreadId,
    required this.customerDraft,
    required this.currentCartCount,
    required this.previousOrdersExpanded,
    required this.onSelected,
    required this.onPreviousOrdersExpandedChanged,
  });

  final List<OrderRequest> matchingOrders;
  final String selectedThreadId;
  final CustomerDraft customerDraft;
  final int currentCartCount;
  final bool previousOrdersExpanded;
  final ValueChanged<String> onSelected;
  final ValueChanged<bool> onPreviousOrdersExpandedChanged;

  @override
  Widget build(BuildContext context) {
    if (matchingOrders.isEmpty) {
      return const SizedBox.shrink();
    }

    final selectedOrder = matchingOrders.cast<OrderRequest?>().firstWhere(
      (order) => '${order?.id}' == selectedThreadId,
      orElse: () => null,
    );
    final selectedLabel = selectedThreadId == 'current'
        ? 'Current Cart'
        : selectedOrder == null
        ? 'Current Cart'
        : formatOrderThreadDateTime(selectedOrder.createdAt);
    final headerLabel = previousOrdersExpanded ? 'Orders' : selectedLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE4E7EC)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              MousePressable(
                onTap: () =>
                    onPreviousOrdersExpandedChanged(!previousOrdersExpanded),
                borderRadius: BorderRadius.circular(0),
                hoverOverlayAlpha: previousOrdersExpanded
                    ? 0
                    : AppColors.neutralHoverOverlayAlpha,
                pressedOverlayAlpha: previousOrdersExpanded
                    ? 0
                    : AppColors.neutralPressedOverlayAlpha,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          headerLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF172033),
                            height: 1.15,
                          ),
                        ),
                      ),
                      Icon(
                        previousOrdersExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: const Color(0xFF344054),
                      ),
                    ],
                  ),
                ),
              ),
              if (previousOrdersExpanded) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(
                    children: [
                      _CartThreadTile(
                        title: 'Current Cart',
                        subtitle: null,
                        selected: selectedThreadId == 'current',
                        status: null,
                        statusLabel: currentCartCount == 0
                            ? 'Empty'
                            : 'Ordering',
                        statusLabelColor: AppColors.logoBlue,
                        onTap: () => onSelected('current'),
                      ),
                      for (final order in matchingOrders) ...[
                        const SizedBox(height: 10),
                        _CartThreadTile(
                          title:
                              '${formatOrderDate(order.createdAt)} • ${formatOrderTimeWithSeconds(order.createdAt)}',
                          subtitle: null,
                          selected: selectedThreadId == '${order.id}',
                          status: order.status,
                          onTap: () => onSelected('${order.id}'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CartThreadTile extends StatelessWidget {
  const _CartThreadTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.status,
    this.statusLabel,
    this.statusLabelColor,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final OrderStatus? status;
  final String? statusLabel;
  final Color? statusLabelColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const orderTextSize = 14.0;
    return MousePressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      hoverOverlayAlpha: selected ? 0 : AppColors.neutralHoverOverlayAlpha,
      pressedOverlayAlpha: selected ? 0 : AppColors.neutralPressedOverlayAlpha,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.logoBlue : const Color(0xFFE4E7EC),
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: orderTextSize,
                      height: 1.15,
                    ),
                  ),
                ),
                if (status != null)
                  status == OrderStatus.waiting
                      ? _CustomStatusBadge(
                          label: displayStatus(status!),
                          fontSize: _kCartPanelStatusFontSize,
                          color: const Color(0xFFFFA726),
                        )
                      : StatusBadge(
                          status: status!,
                          fontSize: _kCartPanelStatusFontSize,
                        )
                else if (statusLabel != null)
                  _CustomStatusBadge(
                    label: statusLabel!,
                    fontSize: _kCartPanelStatusFontSize,
                    color: statusLabelColor ?? AppColors.logoBlue,
                  ),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF667085),
                  height: 1.15,
                  fontSize: orderTextSize,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CustomStatusBadge extends StatelessWidget {
  const _CustomStatusBadge({
    required this.label,
    required this.fontSize,
    this.color = AppColors.logoBlue,
  });

  final String label;
  final double fontSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: fontSize,
            height: 1.15,
          ),
        ),
      ),
    );
  }
}

class _DesktopCartThreadDetailCard extends StatelessWidget {
  const _DesktopCartThreadDetailCard({
    required this.selectedOrder,
    required this.previousOrdersExpanded,
    required this.currentCartCount,
    required this.cart,
    required this.totalCentavos,
    required this.onContactUs,
    required this.onBackToCart,
    required this.onContinueShopping,
  });

  final OrderRequest? selectedOrder;
  final bool previousOrdersExpanded;
  final int currentCartCount;
  final List<CartItem> cart;
  final int totalCentavos;
  final VoidCallback onContactUs;
  final VoidCallback onBackToCart;
  final VoidCallback onContinueShopping;

  @override
  Widget build(BuildContext context) {
    final isCurrent = selectedOrder == null;
    final topActionTextStyle = _cartPanelActionTextStyle();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isCurrent && !previousOrdersExpanded) ...[
          Row(
            children: [
              if (selectedOrder != null)
                StatusBadge(
                  status: selectedOrder!.status,
                  fontSize: _kCartPanelStatusFontSize,
                ),
              const Spacer(),
              MousePressable(
                onTap: onContactUs,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.logoBlue.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Need Help?',
                    style: topActionTextStyle.copyWith(
                      color: AppColors.logoBlue,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              MousePressable(
                onTap: onBackToCart,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.logoBlue.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Back to Cart',
                        style: topActionTextStyle.copyWith(
                          color: AppColors.logoBlue,
                        ),
                      ),
                      if (currentCartCount > 0) ...[
                        const SizedBox(width: 8),
                        _InlineCartCountBadge(count: currentCartCount),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        if (isCurrent && cart.isEmpty)
          EmptyStateCard(
            title: 'Cart is empty',
            message:
                'Browse products, categories, and best sellers and add items for your order.',
            actionLabel: 'Continue Ordering',
            onAction: onContinueShopping,
          )
        else if (!isCurrent && selectedOrder!.items.isEmpty)
          EmptyStateCard(
            title: 'No items found',
            message: 'This previous order does not have any saved items.',
            actionLabel: 'Back to Cart',
            onAction: onBackToCart,
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth;
              final items = isCurrent
                  ? cart.length
                  : selectedOrder!.items.length;
              return Column(
                children: [
                  for (var index = 0; index < items; index++) ...[
                    if (isCurrent)
                      _CurrentCartItemCard(item: cart[index], width: itemWidth)
                    else
                      _PreviousOrderItemCard(
                        item: selectedOrder!.items[index],
                        width: itemWidth,
                      ),
                    if (index != items - 1) const SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
      ],
    );
  }
}

class _CurrentCartItemCard extends ConsumerWidget {
  const _CurrentCartItemCard({required this.item, required this.width});

  final CartItem item;
  final double width;

  Future<bool> _confirmRemoval(BuildContext context) async {
    final shouldRemove = await _showRemoveProductDialog(context);
    return shouldRemove == true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(
      appControllerProvider.select(
        (state) => state.products
            .where((product) => product.id == item.productId)
            .cast<Product?>()
            .firstWhere((product) => product != null, orElse: () => null),
      ),
    );
    const titleFontSize = 14.0;
    const unitFontSize = 12.0;
    const priceFontSize = 14.0;
    const contentHeight = 72.0;
    return Dismissible(
      key: ValueKey('cart-item-${item.productId}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmRemoval(context),
      onDismissed: (_) {
        ref.read(appControllerProvider.notifier).removeFromCart(item.productId);
      },
      background: Container(
        width: width,
        decoration: BoxDecoration(
          color: const Color(0xFFE31E24),
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      child: GestureDetector(
        onLongPress: () async {
          if (!await _confirmRemoval(context)) {
            return;
          }
          await ref
              .read(appControllerProvider.notifier)
              .removeFromCart(item.productId);
        },
        child: MousePressable(
          onTap: product == null
              ? null
              : () => _showProductDetailsModal(context, product),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: width,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE4E7EC)),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: Container(
                    padding: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE4E7EC)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ProductPlaceholder(
                      label: 'Product',
                      height: 72,
                      fullRounded: true,
                      imageUrl: item.photoUrl ?? product?.photoUrl,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: contentHeight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.unit,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: const Color(0xFF667085),
                                height: 1.15,
                                fontSize: unitFontSize,
                              ),
                        ),
                        const Spacer(),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.end,
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    formatPesos(item.referenceUnitPriceCentavos),
                                    style: _clientPriceTextStyle(
                                      context,
                                      fontSize: priceFontSize,
                                    ),
                                  ),
                                  if (product != null)
                                    Text(
                                      'as of ${formatAsOfDate(product.priceUpdatedAt)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: const Color(0xFF667085),
                                            height: 1.15,
                                            fontSize: unitFontSize,
                                          ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'x${item.quantity}',
                              style: _clientNumberTextStyle(
                                context,
                                fontSize: priceFontSize,
                                color: AppColors.logoBlue,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviousOrderItemCard extends ConsumerWidget {
  const _PreviousOrderItemCard({required this.item, required this.width});

  final OrderItem item;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(
      appControllerProvider.select(
        (state) => state.products
            .where((product) => product.id == item.productId)
            .cast<Product?>()
            .firstWhere((product) => product != null, orElse: () => null),
      ),
    );
    const titleFontSize = 14.0;
    const unitFontSize = 12.0;
    const priceFontSize = 14.0;
    const contentHeight = 72.0;
    return MousePressable(
      onTap: product == null
          ? null
          : () => _showProductDetailsModal(context, product),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE4E7EC)),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: Container(
                padding: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE4E7EC)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ProductPlaceholder(
                  label: 'Previous Product',
                  height: 72,
                  fullRounded: true,
                  imageUrl: item.photoUrlSnapshot ?? product?.photoUrl,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: contentHeight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.unit,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF667085),
                        height: 1.15,
                        fontSize: unitFontSize,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.end,
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              Text(
                                formatPesos(item.referenceUnitPriceCentavos),
                                style: _clientPriceTextStyle(
                                  context,
                                  fontSize: priceFontSize,
                                ),
                              ),
                              if (product != null)
                                Text(
                                  'as of ${formatAsOfDate(product.priceUpdatedAt)}',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: const Color(0xFF667085),
                                        height: 1.15,
                                        fontSize: unitFontSize,
                                      ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'x${item.requestedQuantity}',
                          style: _clientNumberTextStyle(
                            context,
                            fontSize: priceFontSize,
                            color: AppColors.logoBlue,
                          ),
                        ),
                      ],
                    ),
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

class _BannerIndexIndicator extends StatelessWidget {
  const _BannerIndexIndicator({required this.activeIndex, required this.count});

  final int activeIndex;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < count; index++) ...[
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: index == activeIndex ? 20 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: index == activeIndex
                  ? AppColors.logoBlue
                  : const Color(0xFFD0D5DD),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          if (index != count - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class ProductCard extends ConsumerStatefulWidget {
  const ProductCard({
    super.key,
    required this.product,
    this.compact = false,
    this.adaptiveSizing = false,
    this.posterMode = false,
    this.showImage = true,
    this.modalDisplayUnit,
    this.modalDisplayPriceCentavos,
    this.modalDisplayPriceUpdatedAt,
    this.modalDisplayName,
    this.onModalEditProduct,
    this.showModalEditAction = false,
    this.adminReadOnly = false,
    this.initialAdminQuantity,
    this.onAdminQuantitySaved,
  });

  final Product product;
  final bool compact;
  final bool adaptiveSizing;
  final bool posterMode;
  final bool showImage;
  final String? modalDisplayUnit;
  final int? modalDisplayPriceCentavos;
  final DateTime? modalDisplayPriceUpdatedAt;
  final String? modalDisplayName;
  final Future<Product?> Function(BuildContext context)? onModalEditProduct;
  final bool showModalEditAction;
  final bool adminReadOnly;
  final int? initialAdminQuantity;
  final Future<void> Function(int quantity)? onAdminQuantitySaved;

  @override
  ConsumerState<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends ConsumerState<ProductCard> {
  bool _suspendCardMouseRegion = false;

  Future<void> _showProductModal(BuildContext context, int cartQuantity) async {
    final latestProduct =
        ref.read(appControllerProvider).products.where((item) => item.id == widget.product.id).firstOrNull ??
        widget.product;
    await _showProductDetailsModal(
      context,
      latestProduct,
      displayUnit: widget.modalDisplayUnit,
      displayPriceCentavos: widget.modalDisplayPriceCentavos,
      displayPriceUpdatedAt: widget.modalDisplayPriceUpdatedAt,
      displayName: widget.modalDisplayName,
      onEditProduct: widget.onModalEditProduct,
      showEditAction: widget.showModalEditAction,
      adminReadOnly: widget.adminReadOnly,
      initialAdminQuantity: widget.initialAdminQuantity,
      onAdminQuantitySaved: widget.onAdminQuantitySaved,
    );
  }

  @override
  Widget build(BuildContext context) {
    final liveProduct =
        ref.watch(
          appControllerProvider.select(
            (state) =>
                state.products
                    .where((item) => item.id == widget.product.id)
                    .cast<Product?>()
                    .firstWhere((item) => item != null, orElse: () => null),
          ),
        ) ??
        widget.product;
    final displayName = widget.modalDisplayName ?? liveProduct.name;
    final displayUnit = widget.modalDisplayUnit ?? liveProduct.displayUnit;
    final displayPriceCentavos =
        widget.modalDisplayPriceCentavos ?? liveProduct.referencePriceCentavos;
    final displayPriceUpdatedAt =
        widget.modalDisplayPriceUpdatedAt ?? liveProduct.priceUpdatedAt;
    final cartItem = ref.watch(
      appControllerProvider.select(
        (state) => state.cart
            .where((item) => item.productId == widget.product.id)
            .cast<CartItem?>()
            .firstWhere((item) => item != null, orElse: () => null),
      ),
    );
    final cartQuantity = cartItem?.quantity ?? 0;
    final effectiveCardQuantity = widget.adminReadOnly
        ? (widget.initialAdminQuantity ?? 0)
        : cartQuantity;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardDensity = widget.adaptiveSizing
            ? _cardDensityForWidth(constraints.maxWidth)
            : (widget.compact ? 1.0 : 0.0);
        final cardPadding = lerpDouble(16.0, 10.0, cardDensity)!;
        final titleFontSize = lerpDouble(16.0, 14.0, cardDensity)!;
        final titleBottomGap = lerpDouble(6.0, 4.0, cardDensity)!;
        final unitFontSize = lerpDouble(13.0, 12.0, cardDensity)!;
        final priceFontSize = lerpDouble(16.0, 14.0, cardDensity)!;
        final priceButtonSpacing = lerpDouble(12.0, 8.0, cardDensity)!;
        final unitPriceSpacing = widget.showImage
            ? 0.0
            : lerpDouble(10.0, 8.0, cardDensity)!;
        const buttonHeight = _kSharedModalButtonHeight;
        const buttonVerticalPadding = 14.0;
        return MousePressable(
          enabled: !_suspendCardMouseRegion,
          onTap: () => _showProductModal(context, cartQuantity),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE4E7EC)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.showImage) ...[
                  AspectRatio(
                    aspectRatio: 1,
                    child: ProductPlaceholder(
                      label: displayName,
                      posterMode: widget.posterMode,
                      imageUrl: liveProduct.photoUrl,
                    ),
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFE4E7EC),
                  ),
                ],
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, contentConstraints) {
                      final tightHeightFactor =
                          ((92.0 - contentConstraints.maxHeight) / 28.0).clamp(
                            0.0,
                            1.0,
                          );
                      final resolvedCardPadding = lerpDouble(
                        cardPadding,
                        6.0,
                        tightHeightFactor,
                      )!;
                      final resolvedTitleFontSize = lerpDouble(
                        titleFontSize,
                        11.5,
                        tightHeightFactor,
                      )!;
                      final resolvedTitleBottomGap = lerpDouble(
                        titleBottomGap,
                        2.0,
                        tightHeightFactor,
                      )!;
                      final resolvedUnitFontSize = lerpDouble(
                        unitFontSize,
                        10.0,
                        tightHeightFactor,
                      )!;
                      final resolvedPriceFontSize = lerpDouble(
                        priceFontSize,
                        12.0,
                        tightHeightFactor,
                      )!;
                      final resolvedPriceButtonSpacing = lerpDouble(
                        priceButtonSpacing,
                        6.0,
                        tightHeightFactor,
                      )!;
                      final resolvedUnitPriceSpacing =
                          widget.showImage && tightHeightFactor > 0
                          ? 0.0
                          : unitPriceSpacing;
                      final resolvedTitleStyle = Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            fontSize: resolvedTitleFontSize,
                          );
                      final titlePainter =
                          TextPainter(
                            text: TextSpan(
                              text: displayName,
                              style: resolvedTitleStyle,
                            ),
                            maxLines: 2,
                            textDirection: Directionality.of(context),
                          )..layout(
                            maxWidth:
                                contentConstraints.maxWidth -
                                (resolvedCardPadding * 2),
                          );
                      final titleBlockHeight = titlePainter.height;

                      return Column(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.all(resolvedCardPadding),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    height: titleBlockHeight,
                                    child: Align(
                                      alignment: Alignment.topLeft,
                                      child: Text(
                                        displayName,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: resolvedTitleStyle,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: resolvedTitleBottomGap),
                                  Text(
                                    displayUnit,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: const Color(0xFF667085),
                                          height: 1.15,
                                          fontSize: resolvedUnitFontSize,
                                        ),
                                  ),
                                  SizedBox(height: resolvedUnitPriceSpacing),
                                  if (tightHeightFactor >= 0.55) ...[
                                    Text(
                                      formatPesos(displayPriceCentavos),
                                      style: _clientPriceTextStyle(
                                        context,
                                        fontSize: resolvedPriceFontSize,
                                      ),
                                    ),
                                    Text(
                                      'as of ${formatAsOfDate(displayPriceUpdatedAt)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: const Color(0xFF667085),
                                            height: 1.15,
                                            fontSize: resolvedUnitFontSize,
                                          ),
                                    ),
                                  ] else ...[
                                    const Spacer(),
                                    Wrap(
                                      crossAxisAlignment:
                                          WrapCrossAlignment.end,
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: [
                                        Text(
                                          formatPesos(displayPriceCentavos),
                                          style: _clientPriceTextStyle(
                                            context,
                                            fontSize: resolvedPriceFontSize,
                                          ),
                                        ),
                                        Text(
                                          'as of ${formatAsOfDate(displayPriceUpdatedAt)}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: const Color(0xFF667085),
                                                height: 1.15,
                                                fontSize: resolvedUnitFontSize,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          MouseRegion(
                            onEnter: (_) =>
                                setState(() => _suspendCardMouseRegion = true),
                            onExit: (_) =>
                                setState(() => _suspendCardMouseRegion = false),
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                resolvedCardPadding,
                                0,
                                resolvedCardPadding,
                                resolvedCardPadding,
                              ),
                              child: Column(
                                children: [
                                  SizedBox(height: resolvedPriceButtonSpacing),
                                  if (effectiveCardQuantity == 0)
                                    SizedBox(
                                      width: double.infinity,
                                      height: buttonHeight,
                                      child: ElevatedButton(
                                        style:
                                            ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.logoBlue,
                                              elevation: 0,
                                              shadowColor: Colors.transparent,
                                              minimumSize: Size(
                                                0,
                                                buttonHeight,
                                              ),
                                              maximumSize: Size(
                                                double.infinity,
                                                buttonHeight,
                                              ),
                                              fixedSize: Size(
                                                double.infinity,
                                                buttonHeight,
                                              ),
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                              padding: EdgeInsets.symmetric(
                                                vertical: buttonVerticalPadding,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                            ).copyWith(
                                              backgroundColor:
                                                  _strongBlueBackground(),
                                              overlayColor:
                                                  _strongBlueOverlay(),
                                            ),
                                        onPressed: () async {
                                          if (widget.adminReadOnly) {
                                            await widget.onAdminQuantitySaved
                                                ?.call(1);
                                            return;
                                          }
                                          await ref
                                              .read(
                                                appControllerProvider.notifier,
                                              )
                                              .addToCart(
                                                widget.product,
                                                quantity: 1,
                                              );
                                        },
                                        child: const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.add_shopping_cart),
                                            SizedBox(width: 4),
                                            Text('Add to Cart'),
                                          ],
                                        ),
                                      ),
                                    )
                                  else
                                    _CartQuantityControl(
                                      quantity: effectiveCardQuantity,
                                      height: buttonHeight,
                                      onDecrease: () async {
                                        if (widget.adminReadOnly) {
                                          if (effectiveCardQuantity <= 1) {
                                            final shouldRemove =
                                                await _showRemoveProductDialog(
                                                  context,
                                                );
                                            if (shouldRemove != true) {
                                              return;
                                            }
                                            await widget.onAdminQuantitySaved
                                                ?.call(0);
                                            return;
                                          }
                                          await widget.onAdminQuantitySaved
                                              ?.call(effectiveCardQuantity - 1);
                                          return;
                                        }
                                        final controller = ref.read(
                                          appControllerProvider.notifier,
                                        );
                                        if (cartQuantity <= 1) {
                                          final shouldRemove =
                                              await _showRemoveProductDialog(
                                                context,
                                              );
                                          if (shouldRemove != true) {
                                            return;
                                          }
                                          await controller.removeFromCart(
                                            widget.product.id,
                                          );
                                          if (!context.mounted) {
                                            return;
                                          }
                                          _popAllRoutesUntilFirst(context);
                                        } else {
                                          await controller.updateCartQuantity(
                                            widget.product.id,
                                            cartQuantity - 1,
                                          );
                                        }
                                      },
                                      onIncrease: () async {
                                        if (widget.adminReadOnly) {
                                          await widget.onAdminQuantitySaved
                                              ?.call(effectiveCardQuantity + 1);
                                          return;
                                        }
                                        await ref
                                            .read(
                                              appControllerProvider.notifier,
                                            )
                                            .updateCartQuantity(
                                              widget.product.id,
                                              cartQuantity + 1,
                                            );
                                      },
                                      onEditQuantity: () async {
                                        final nextQuantity =
                                            await _showQuantityInputDialog(
                                              context,
                                              initialQuantity:
                                                  effectiveCardQuantity,
                                            );
                                        if (nextQuantity == null ||
                                            nextQuantity ==
                                                effectiveCardQuantity) {
                                          return;
                                        }
                                        if (!context.mounted) {
                                          return;
                                        }
                                        if (widget.adminReadOnly) {
                                          if (nextQuantity <= 0) {
                                            final shouldRemove =
                                                await _showRemoveProductDialog(
                                                  context,
                                                );
                                            if (shouldRemove != true) {
                                              return;
                                            }
                                            await widget.onAdminQuantitySaved
                                                ?.call(0);
                                            return;
                                          }
                                          await widget.onAdminQuantitySaved
                                              ?.call(nextQuantity);
                                          return;
                                        }
                                        final controller = ref.read(
                                          appControllerProvider.notifier,
                                        );
                                        if (nextQuantity <= 0) {
                                          final shouldRemove =
                                              await _showRemoveProductDialog(
                                                context,
                                              );
                                          if (shouldRemove != true) {
                                            return;
                                          }
                                          await controller.removeFromCart(
                                            widget.product.id,
                                          );
                                          if (!context.mounted) {
                                            return;
                                          }
                                          _popAllRoutesUntilFirst(context);
                                          return;
                                        }
                                        await controller.updateCartQuantity(
                                          widget.product.id,
                                          nextQuantity,
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProductModal extends ConsumerStatefulWidget {
  const _ProductModal({
    required this.product,
    this.displayUnit,
    this.displayPriceCentavos,
    this.displayPriceUpdatedAt,
    this.displayName,
    this.onEditProduct,
    this.showEditAction = false,
    this.adminReadOnly = false,
    this.initialAdminQuantity,
    this.onAdminQuantitySaved,
  });

  final Product product;
  final String? displayUnit;
  final int? displayPriceCentavos;
  final DateTime? displayPriceUpdatedAt;
  final String? displayName;
  final Future<Product?> Function(BuildContext context)? onEditProduct;
  final bool showEditAction;
  final bool adminReadOnly;
  final int? initialAdminQuantity;
  final Future<void> Function(int quantity)? onAdminQuantitySaved;

  @override
  ConsumerState<_ProductModal> createState() => _ProductModalState();
}

class _ProductModalState extends ConsumerState<_ProductModal> {
  int? _draftQuantity;
  String? _liveDisplayName;
  String? _liveDisplayUnit;
  int? _liveDisplayPriceCentavos;
  DateTime? _liveDisplayPriceUpdatedAt;
  String? _livePhotoUrl;

  @override
  Widget build(BuildContext context) {
    final liveProduct =
        ref.watch(
          appControllerProvider.select(
            (state) =>
                state.products
                    .where((item) => item.id == widget.product.id)
                    .cast<Product?>()
                    .firstWhere((item) => item != null, orElse: () => null),
          ),
        ) ??
        widget.product;
    final cartItem = ref.watch(
      appControllerProvider.select(
        (state) => state.cart
            .where((item) => item.productId == widget.product.id)
            .cast<CartItem?>()
            .firstWhere((item) => item != null, orElse: () => null),
      ),
    );
    final cartQuantity = cartItem?.quantity ?? 0;
    final resolvedInitialQuantity = widget.adminReadOnly
        ? (widget.initialAdminQuantity ?? 0)
        : cartQuantity;
    final draftQuantity = _draftQuantity ?? resolvedInitialQuantity;
    final displayName =
        _liveDisplayName ?? widget.displayName ?? liveProduct.name;
    final displayUnit =
        _liveDisplayUnit ?? widget.displayUnit ?? liveProduct.displayUnit;
    final displayPriceCentavos =
        _liveDisplayPriceCentavos ??
        widget.displayPriceCentavos ??
        liveProduct.referencePriceCentavos;
    final displayPriceUpdatedAt =
        _liveDisplayPriceUpdatedAt ??
        widget.displayPriceUpdatedAt ??
        liveProduct.priceUpdatedAt;
    final viewportWidth = MediaQuery.of(context).size.width;
    final viewportHeight = MediaQuery.of(context).size.height;
    const contentPadding = 16.0;
    const buttonHeight = 44.0;
    const minModalWidth = 280.0;
    const maxModalWidth = _kSharedModalMaxWidth;
    final dialogMaxWidth = math.min(maxModalWidth, viewportWidth - 96);
    final dialogMaxHeight = viewportHeight - 96;
    final innerMaxWidth = dialogMaxWidth - (contentPadding * 2);
    final innerMaxHeight = dialogMaxHeight - (contentPadding * 2);
    final titleStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w800,
      height: 1.15,
    );
    final unitStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      color: const Color(0xFF667085),
      height: 1.15,
      fontSize: 12,
    );
    final priceStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontSize: 16,
      color: AppColors.logoBlue,
      fontWeight: FontWeight.w400,
      height: 1.15,
    );
    final asOfStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      color: const Color(0xFF667085),
      height: 1.15,
      fontSize: 11.5,
    );
    final actionLabelStyle = Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700, height: 1.15);
    final addToCartLabelStyle = actionLabelStyle?.copyWith(color: Colors.white);
    final closeLabelStyle = actionLabelStyle?.copyWith(
      color: const Color(0xFFE31E24),
    );
    final unitPainter = TextPainter(
      text: TextSpan(text: displayUnit, style: unitStyle),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout(maxWidth: innerMaxWidth);
    final titlePainter = TextPainter(
      text: TextSpan(text: displayName, style: titleStyle),
      textDirection: Directionality.of(context),
    )..layout(maxWidth: innerMaxWidth);
    final pricePainter = TextPainter(
      text: TextSpan(
        text: formatPesos(displayPriceCentavos),
        style: priceStyle,
      ),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout(maxWidth: innerMaxWidth);
    final asOfPainter = TextPainter(
      text: TextSpan(
        text: 'as of ${formatAsOfDate(displayPriceUpdatedAt)}',
        style: asOfStyle,
      ),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout(maxWidth: innerMaxWidth);
    final actionAreaHeight = widget.adminReadOnly
        ? (buttonHeight * 2) + 12
        : buttonHeight;
    final fixedContentHeight =
        20 +
        titlePainter.height +
        2 +
        unitPainter.height +
        12 +
        math.max(pricePainter.height, asOfPainter.height) +
        24 +
        actionAreaHeight;
    final responsiveImageSize = math.max(
      120.0,
      math.min(
        300.0,
        math.min(innerMaxWidth, innerMaxHeight - fixedContentHeight),
      ),
    );
    final modalWidth = math.max(
      minModalWidth,
      math.min(dialogMaxWidth, responsiveImageSize + (contentPadding * 2)),
    );
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: SizedBox(
        width: modalWidth,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: dialogMaxHeight),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(contentPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: SizedBox(
                    width: responsiveImageSize,
                    height: responsiveImageSize,
                    child: ProductPlaceholder(
                      label: displayName,
                      posterMode: true,
                      fullRounded: true,
                      imageUrl: _livePhotoUrl ?? liveProduct.photoUrl,
                      imageFit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(displayName, style: titleStyle),
                const SizedBox(height: 2),
                Text(displayUnit, style: unitStyle),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.end,
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          Text(
                            formatPesos(displayPriceCentavos),
                            style: priceStyle,
                          ),
                          Text(
                            'as of ${formatAsOfDate(displayPriceUpdatedAt)}',
                            style: asOfStyle,
                          ),
                        ],
                      ),
                    ),
                    if (widget.showEditAction && widget.onEditProduct != null)
                      MousePressable(
                        onTap: () async {
                          final result = await widget.onEditProduct!(context);
                          if (mounted) {
                            setState(() {
                              if (result != null) {
                                _liveDisplayName = result.name;
                                _liveDisplayUnit = result.displayUnit;
                                _liveDisplayPriceCentavos =
                                    result.referencePriceCentavos;
                                _liveDisplayPriceUpdatedAt =
                                    result.priceUpdatedAt;
                                _livePhotoUrl = result.photoUrl;
                              }
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: AppColors.logoBlue,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                if (!widget.adminReadOnly && draftQuantity == 0)
                  SizedBox(
                    width: double.infinity,
                    height: buttonHeight,
                    child: ElevatedButton.icon(
                      style:
                          ElevatedButton.styleFrom(
                            backgroundColor: AppColors.logoBlue,
                            textStyle: actionLabelStyle,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            minimumSize: const Size(0, buttonHeight),
                            maximumSize: const Size(
                              double.infinity,
                              buttonHeight,
                            ),
                            fixedSize: const Size(
                              double.infinity,
                              buttonHeight,
                            ),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ).copyWith(
                            backgroundColor: _strongBlueBackground(),
                            overlayColor: _strongBlueOverlay(),
                          ),
                      onPressed: () => setState(() => _draftQuantity = 1),
                      icon: const Icon(Icons.add_shopping_cart),
                      label: Text('Add to Cart', style: addToCartLabelStyle),
                    ),
                  )
                else if (!widget.adminReadOnly)
                  _CartQuantityControl(
                    quantity: draftQuantity,
                    height: buttonHeight,
                    onDecrease: () async {
                      if (draftQuantity <= 1) {
                        if (cartQuantity <= 0) {
                          setState(() => _draftQuantity = 0);
                          return;
                        }
                        final shouldRemove = await _showRemoveProductDialog(
                          context,
                        );
                        if (shouldRemove != true) {
                          return;
                        }
                        if (cartQuantity > 0) {
                          await ref
                              .read(appControllerProvider.notifier)
                              .removeFromCart(widget.product.id);
                          if (!context.mounted) {
                            return;
                          }
                          _popAllRoutesUntilFirst(context);
                          return;
                        }
                        setState(() => _draftQuantity = 0);
                        if (!mounted) {
                          return;
                        }
                        _popAllRoutesUntilFirst(this.context);
                        return;
                      }
                      setState(() => _draftQuantity = draftQuantity - 1);
                    },
                    onIncrease: () async {
                      setState(() => _draftQuantity = draftQuantity + 1);
                    },
                    onEditQuantity: () async {
                      final nextQuantity = await _showQuantityInputDialog(
                        context,
                        initialQuantity: draftQuantity,
                      );
                      if (nextQuantity == null ||
                          nextQuantity == draftQuantity) {
                        return;
                      }
                      if (!context.mounted) {
                        return;
                      }
                      if (nextQuantity <= 0 && cartQuantity > 0) {
                        final controller = ref.read(
                          appControllerProvider.notifier,
                        );
                        final shouldRemove = await _showRemoveProductDialog(
                          context,
                        );
                        if (shouldRemove != true) {
                          return;
                        }
                        await controller.removeFromCart(widget.product.id);
                        if (!mounted) {
                          return;
                        }
                        _popAllRoutesUntilFirst(this.context);
                        return;
                      }
                      setState(() => _draftQuantity = nextQuantity);
                    },
                  ),
                const SizedBox(height: 12),
                if (widget.adminReadOnly)
                  Column(
                    children: [
                      _CartQuantityControl(
                        quantity: draftQuantity,
                        height: buttonHeight,
                        onDecrease: () async {
                          if (draftQuantity <= 1) {
                            final shouldRemove = await _showRemoveProductDialog(
                              context,
                            );
                            if (shouldRemove != true) {
                              return;
                            }
                            await widget.onAdminQuantitySaved?.call(0);
                            if (!mounted) {
                              return;
                            }
                            Navigator.of(this.context).pop();
                            return;
                          }
                          final nextQuantity = draftQuantity - 1;
                          setState(() => _draftQuantity = nextQuantity);
                          await widget.onAdminQuantitySaved?.call(nextQuantity);
                        },
                        onIncrease: () async {
                          final nextQuantity = draftQuantity + 1;
                          setState(() => _draftQuantity = nextQuantity);
                          await widget.onAdminQuantitySaved?.call(nextQuantity);
                        },
                        onEditQuantity: () async {
                          final nextQuantity = await _showQuantityInputDialog(
                            context,
                            initialQuantity: draftQuantity,
                          );
                          if (nextQuantity == null ||
                              nextQuantity == draftQuantity) {
                            return;
                          }
                          if (!context.mounted) {
                            return;
                          }
                          if (nextQuantity <= 0) {
                            final shouldRemove = await _showRemoveProductDialog(
                              context,
                            );
                            if (shouldRemove != true) {
                              return;
                            }
                            await widget.onAdminQuantitySaved?.call(0);
                            if (!mounted) {
                              return;
                            }
                            Navigator.of(this.context).pop();
                            return;
                          }
                          setState(() => _draftQuantity = nextQuantity);
                          await widget.onAdminQuantitySaved?.call(nextQuantity);
                        },
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: buttonHeight,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFE31E24),
                            backgroundColor: const Color(0x1AE31E24),
                            textStyle: actionLabelStyle,
                            minimumSize: const Size(0, buttonHeight),
                            maximumSize: const Size(
                              double.infinity,
                              buttonHeight,
                            ),
                            fixedSize: const Size(
                              double.infinity,
                              buttonHeight,
                            ),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text('Close', style: closeLabelStyle),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: buttonHeight,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFE31E24),
                              backgroundColor: const Color(0x1AE31E24),
                              textStyle: actionLabelStyle,
                              minimumSize: const Size(0, buttonHeight),
                              maximumSize: const Size(
                                double.infinity,
                                buttonHeight,
                              ),
                              fixedSize: const Size(
                                double.infinity,
                                buttonHeight,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text('Close', style: closeLabelStyle),
                          ),
                        ),
                      ),
                      if (cartQuantity > 0 || draftQuantity >= 1) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: buttonHeight,
                            child: OutlinedButton(
                              style:
                                  OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.logoBlue,
                                    backgroundColor: AppColors.logoBlue
                                        .withValues(alpha: 0.10),
                                    textStyle: actionLabelStyle,
                                    minimumSize: const Size(0, buttonHeight),
                                    maximumSize: const Size(
                                      double.infinity,
                                      buttonHeight,
                                    ),
                                    fixedSize: const Size(
                                      double.infinity,
                                      buttonHeight,
                                    ),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    side: BorderSide.none,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ).copyWith(
                                    backgroundColor: _lightBlueBackground(
                                      baseColor: AppColors.logoBlue.withValues(
                                        alpha: 0.10,
                                      ),
                                    ),
                                    overlayColor: _strongBlueOverlay(),
                                  ),
                              onPressed: () async {
                                final nextQuantity =
                                    _draftQuantity ?? cartQuantity;
                                if (widget.onAdminQuantitySaved != null) {
                                  await widget.onAdminQuantitySaved!(
                                    nextQuantity,
                                  );
                                  if (!mounted) {
                                    return;
                                  }
                                  Navigator.of(this.context).pop();
                                  return;
                                }
                                final controller = ref.read(
                                  appControllerProvider.notifier,
                                );
                                if (nextQuantity != cartQuantity) {
                                  if (nextQuantity <= 0) {
                                    final shouldRemove =
                                        cartQuantity > 0
                                            ? await _showRemoveProductDialog(
                                              context,
                                            )
                                            : true;
                                    if (shouldRemove != true) {
                                      return;
                                    }
                                    await controller.removeFromCart(
                                      widget.product.id,
                                    );
                                    if (!mounted) {
                                      return;
                                    }
                                    _popAllRoutesUntilFirst(this.context);
                                    return;
                                  } else if (cartQuantity <= 0) {
                                    await controller.addToCart(
                                      widget.product,
                                      quantity: nextQuantity,
                                    );
                                  } else {
                                    await controller.updateCartQuantity(
                                      widget.product.id,
                                      nextQuantity,
                                    );
                                  }
                                }
                                if (!mounted) {
                                  return;
                                }
                                Navigator.of(this.context).pop();
                              },
                              child: Text(
                                'Save',
                                style: actionLabelStyle?.copyWith(
                                  color: AppColors.logoBlue,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CartQuantityControl extends StatelessWidget {
  const _CartQuantityControl({
    required this.quantity,
    required this.height,
    required this.onDecrease,
    required this.onIncrease,
    required this.onEditQuantity,
  });

  final int quantity;
  final double height;
  final Future<void> Function() onDecrease;
  final Future<void> Function() onIncrease;
  final Future<void> Function() onEditQuantity;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.logoBlue,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            SizedBox(
              width: height,
              height: height,
              child: IconButton(
                onPressed: onDecrease,
                style: ButtonStyle(
                  backgroundColor: _strongBlueBackground(),
                  foregroundColor: WidgetStateProperty.all(Colors.white),
                  overlayColor: _transparentInteractionOverlay(),
                  splashFactory: NoSplash.splashFactory,
                  animationDuration: Duration.zero,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
                splashRadius: 1,
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                icon: const Icon(Icons.remove, color: Colors.white),
              ),
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onEditQuantity,
                child: Center(
                  child: Text(
                    '$quantity',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: height,
              height: height,
              child: IconButton(
                onPressed: onIncrease,
                style: ButtonStyle(
                  backgroundColor: _strongBlueBackground(),
                  foregroundColor: WidgetStateProperty.all(Colors.white),
                  overlayColor: _transparentInteractionOverlay(),
                  splashFactory: NoSplash.splashFactory,
                  animationDuration: Duration.zero,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
                splashRadius: 1,
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                icon: const Icon(Icons.add, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<int?> _showQuantityInputDialog(
  BuildContext context, {
  required int initialQuantity,
}) async {
  return showDialog<int>(
    context: context,
    builder: (dialogContext) =>
        _QuantityInputDialog(initialQuantity: initialQuantity),
  );
}

Future<bool?> _showRemoveProductDialog(BuildContext context) async {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => const _RemoveProductDialog(),
  );
}

Future<void> _showOrderPlacedDialog(BuildContext context) async {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => const _OrderPlacedDialog(),
  );
}

Future<bool?> _showOrderAgainDialog(BuildContext context) async {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => const _OrderAgainDialog(),
  );
}

Future<bool?> _showPlaceOrderConfirmationDialog(
  BuildContext context, {
  required int itemCount,
}) async {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) =>
        _PlaceOrderConfirmationDialog(itemCount: itemCount),
  );
}

Future<void> _showContactUsDialog(
  BuildContext context,
  AppSettings settings,
) async {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => _ContactUsDialog(settings: settings),
  );
}

class _OrderPlacedDialog extends StatelessWidget {
  const _OrderPlacedDialog();

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w800,
      height: 1.15,
    );
    final bodyStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: const Color(0xFF667085),
      height: 1.15,
    );
    final actionLabelStyle = Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700, height: 1.15);

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kSharedModalMaxWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Order Placed', style: titleStyle),
              const SizedBox(height: 10),
              Text('Order has been placed successfully.', style: bodyStyle),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: _kSharedModalButtonHeight,
                child: OutlinedButton(
                  style:
                      OutlinedButton.styleFrom(
                        backgroundColor: AppColors.logoBlue.withValues(
                          alpha: 0.10,
                        ),
                        foregroundColor: AppColors.logoBlue,
                        textStyle: actionLabelStyle,
                        minimumSize: const Size(0, _kSharedModalButtonHeight),
                        maximumSize: const Size(
                          double.infinity,
                          _kSharedModalButtonHeight,
                        ),
                        fixedSize: const Size(
                          double.infinity,
                          _kSharedModalButtonHeight,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ).copyWith(
                        backgroundColor: _lightBlueBackground(
                          baseColor: AppColors.logoBlue.withValues(alpha: 0.10),
                        ),
                        overlayColor: _strongBlueOverlay(),
                      ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Close',
                    style: actionLabelStyle?.copyWith(
                      color: AppColors.logoBlue,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceOrderConfirmationDialog extends StatelessWidget {
  const _PlaceOrderConfirmationDialog({required this.itemCount});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w800,
      height: 1.15,
    );
    final bodyStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: const Color(0xFF667085),
      height: 1.15,
    );
    final actionLabelStyle = Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700, height: 1.15);

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kSharedModalMaxWidth),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Place order?', style: titleStyle),
              const SizedBox(height: 10),
              Text(
                'Are you sure you want to order $itemCount item${itemCount == 1 ? '' : 's'}?',
                style: bodyStyle,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: _kSharedModalButtonHeight,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFE31E24),
                          backgroundColor: const Color(0x1AE31E24),
                          textStyle: actionLabelStyle,
                          minimumSize: const Size(0, _kSharedModalButtonHeight),
                          maximumSize: const Size(
                            double.infinity,
                            _kSharedModalButtonHeight,
                          ),
                          fixedSize: const Size(
                            double.infinity,
                            _kSharedModalButtonHeight,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(
                          'No',
                          style: actionLabelStyle?.copyWith(
                            color: const Color(0xFFE31E24),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: _kSharedModalButtonHeight,
                      child: OutlinedButton(
                        style:
                            OutlinedButton.styleFrom(
                              backgroundColor: AppColors.logoBlue.withValues(
                                alpha: 0.10,
                              ),
                              foregroundColor: AppColors.logoBlue,
                              textStyle: actionLabelStyle,
                              minimumSize: const Size(
                                0,
                                _kSharedModalButtonHeight,
                              ),
                              maximumSize: const Size(
                                double.infinity,
                                _kSharedModalButtonHeight,
                              ),
                              fixedSize: const Size(
                                double.infinity,
                                _kSharedModalButtonHeight,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ).copyWith(
                              backgroundColor: _lightBlueBackground(
                                baseColor: AppColors.logoBlue.withValues(
                                  alpha: 0.10,
                                ),
                              ),
                              overlayColor: _strongBlueOverlay(),
                            ),
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text(
                          'Yes',
                          style: actionLabelStyle?.copyWith(
                            color: AppColors.logoBlue,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactUsDialog extends StatelessWidget {
  const _ContactUsDialog({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w800,
      height: 1.15,
    );

    Future<void> handleAction({
      required String? url,
      required String successMessage,
      required String errorMessage,
    }) async {
      final messenger = ScaffoldMessenger.of(context);
      if (url == null || url.trim().isEmpty) {
        messenger.clearSnackBars();
        messenger.showSnackBar(errorSnackBar(errorMessage));
        return;
      }
      final opened = await openExternalUrl(url.trim());
      if (!context.mounted) {
        return;
      }
      messenger.clearSnackBars();
      messenger.showSnackBar(
        opened ? successSnackBar(successMessage) : errorSnackBar(errorMessage),
      );
    }

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kSharedModalMaxWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text('Need Help?', style: titleStyle)),
                  MousePressable(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(12),
                    child: const SizedBox(
                      width: 28,
                      height: 28,
                      child: Icon(Icons.close_rounded),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _ContactUsActionButton(
                icon: Icons.facebook,
                label: 'Message us on Facebook',
                onPressed: () => handleAction(
                  url: settings.facebookMessengerUrl,
                  successMessage: 'Opening Facebook / Messenger.',
                  errorMessage: 'Facebook link not set.',
                ),
              ),
              const SizedBox(height: 10),
              _ContactUsActionButton(
                icon: Icons.sms_outlined,
                label: 'Send us a message',
                onPressed: () => handleAction(
                  url: settings.storeContactNumber.trim().isEmpty
                      ? null
                      : 'sms:${settings.storeContactNumber.trim()}',
                  successMessage: 'Opening SMS.',
                  errorMessage: 'Phone number not set.',
                ),
              ),
              const SizedBox(height: 10),
              _ContactUsActionButton(
                icon: Icons.call_outlined,
                label: 'Contact us',
                onPressed: () => handleAction(
                  url: settings.storeContactNumber.trim().isEmpty
                      ? null
                      : 'tel:${settings.storeContactNumber.trim()}',
                  successMessage: 'Opening contact number.',
                  errorMessage: 'Phone number not set.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactUsActionButton extends StatelessWidget {
  const _ContactUsActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final actionLabelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w700,
      height: 1.15,
      color: AppColors.logoBlue,
    );

    return SizedBox(
      width: double.infinity,
      height: _kSharedModalButtonHeight,
      child: OutlinedButton(
        style:
            OutlinedButton.styleFrom(
              backgroundColor: AppColors.logoBlue.withValues(alpha: 0.10),
              foregroundColor: AppColors.logoBlue,
              textStyle: actionLabelStyle,
              alignment: Alignment.centerLeft,
              minimumSize: const Size(0, _kSharedModalButtonHeight),
              maximumSize: const Size(
                double.infinity,
                _kSharedModalButtonHeight,
              ),
              fixedSize: const Size(double.infinity, _kSharedModalButtonHeight),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ).copyWith(
              backgroundColor: _lightBlueBackground(
                baseColor: AppColors.logoBlue.withValues(alpha: 0.10),
              ),
              overlayColor: _strongBlueOverlay(),
            ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppColors.logoBlue),
            const SizedBox(width: 8),
            Text(label, style: actionLabelStyle),
          ],
        ),
      ),
    );
  }
}

class _OrderAgainDialog extends StatelessWidget {
  const _OrderAgainDialog();

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w800,
      height: 1.15,
    );
    final bodyStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: const Color(0xFF667085),
      height: 1.15,
    );
    final actionLabelStyle = Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700, height: 1.15);

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kSharedModalMaxWidth),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Order again?', style: titleStyle),
              const SizedBox(height: 10),
              Text('Current cart will be replaced.', style: bodyStyle),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: _kSharedModalButtonHeight,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFE31E24),
                          backgroundColor: const Color(0x1AE31E24),
                          textStyle: actionLabelStyle,
                          minimumSize: const Size(0, _kSharedModalButtonHeight),
                          maximumSize: const Size(
                            double.infinity,
                            _kSharedModalButtonHeight,
                          ),
                          fixedSize: const Size(
                            double.infinity,
                            _kSharedModalButtonHeight,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(
                          'No',
                          style: actionLabelStyle?.copyWith(
                            color: const Color(0xFFE31E24),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: _kSharedModalButtonHeight,
                      child: OutlinedButton(
                        style:
                            OutlinedButton.styleFrom(
                              backgroundColor: AppColors.logoBlue.withValues(
                                alpha: 0.10,
                              ),
                              foregroundColor: AppColors.logoBlue,
                              textStyle: actionLabelStyle,
                              minimumSize: const Size(
                                0,
                                _kSharedModalButtonHeight,
                              ),
                              maximumSize: const Size(
                                double.infinity,
                                _kSharedModalButtonHeight,
                              ),
                              fixedSize: const Size(
                                double.infinity,
                                _kSharedModalButtonHeight,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ).copyWith(
                              backgroundColor: _lightBlueBackground(
                                baseColor: AppColors.logoBlue.withValues(
                                  alpha: 0.10,
                                ),
                              ),
                              overlayColor: _strongBlueOverlay(),
                            ),
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text(
                          'Yes',
                          style: actionLabelStyle?.copyWith(
                            color: AppColors.logoBlue,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuantityInputDialog extends StatefulWidget {
  const _QuantityInputDialog({required this.initialQuantity});

  final int initialQuantity;

  @override
  State<_QuantityInputDialog> createState() => _QuantityInputDialogState();
}

class _QuantityInputDialogState extends State<_QuantityInputDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.initialQuantity}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_isSubmitting) {
      return;
    }
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) {
      _isSubmitting = true;
      Navigator.of(context).pop(0);
      return;
    }
    if (_formKey.currentState?.validate() ?? false) {
      _isSubmitting = true;
      Navigator.of(context).pop(int.parse(trimmed));
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w800,
      height: 1.15,
    );
    final actionLabelStyle = Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700, height: 1.15);
    const contentPadding = 16.0;
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kSharedModalMaxWidth),
        child: Padding(
          padding: const EdgeInsets.all(contentPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Update Quantity', style: titleStyle),
              const SizedBox(height: 16),
              Form(
                key: _formKey,
                child: TextFormField(
                  controller: _controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(hintText: 'Enter Quantity'),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) {
                      return null;
                    }
                    final parsed = int.tryParse(trimmed);
                    if (parsed == null || parsed < 0) {
                      return 'Enter a valid quantity';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: _kSharedModalButtonHeight,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFE31E24),
                          backgroundColor: const Color(0x1AE31E24),
                          textStyle: actionLabelStyle,
                          minimumSize: const Size(0, _kSharedModalButtonHeight),
                          maximumSize: const Size(
                            double.infinity,
                            _kSharedModalButtonHeight,
                          ),
                          fixedSize: const Size(
                            double.infinity,
                            _kSharedModalButtonHeight,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'Close',
                          style: actionLabelStyle?.copyWith(
                            color: const Color(0xFFE31E24),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: _kSharedModalButtonHeight,
                      child: OutlinedButton(
                        style:
                            OutlinedButton.styleFrom(
                              backgroundColor: AppColors.logoBlue.withValues(
                                alpha: 0.10,
                              ),
                              foregroundColor: AppColors.logoBlue,
                              textStyle: actionLabelStyle,
                              minimumSize: const Size(
                                0,
                                _kSharedModalButtonHeight,
                              ),
                              maximumSize: const Size(
                                double.infinity,
                                _kSharedModalButtonHeight,
                              ),
                              fixedSize: const Size(
                                double.infinity,
                                _kSharedModalButtonHeight,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ).copyWith(
                              backgroundColor: _lightBlueBackground(
                                baseColor: AppColors.logoBlue.withValues(
                                  alpha: 0.10,
                                ),
                              ),
                              overlayColor: _strongBlueOverlay(),
                            ),
                        onPressed: _submit,
                        child: Text(
                          'Save',
                          style: actionLabelStyle?.copyWith(
                            color: AppColors.logoBlue,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RemoveProductDialog extends StatelessWidget {
  const _RemoveProductDialog();

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w800,
      height: 1.15,
    );
    final bodyStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: const Color(0xFF667085),
      height: 1.15,
    );
    final actionLabelStyle = Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700, height: 1.15);
    const contentPadding = 16.0;
    const buttonHeight = _kSharedModalButtonHeight;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kSharedModalMaxWidth),
        child: Padding(
          padding: const EdgeInsets.all(contentPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Remove Item?', style: titleStyle),
              const SizedBox(height: 8),
              Text('Item will be removed from cart.', style: bodyStyle),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: buttonHeight,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFE31E24),
                          backgroundColor: const Color(0x1AE31E24),
                          textStyle: actionLabelStyle,
                          minimumSize: const Size(0, buttonHeight),
                          maximumSize: const Size(
                            double.infinity,
                            buttonHeight,
                          ),
                          fixedSize: const Size(double.infinity, buttonHeight),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(
                          'Close',
                          style: actionLabelStyle?.copyWith(
                            color: const Color(0xFFE31E24),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: buttonHeight,
                      child: OutlinedButton(
                        style:
                            OutlinedButton.styleFrom(
                              backgroundColor: AppColors.logoBlue.withValues(
                                alpha: 0.10,
                              ),
                              foregroundColor: AppColors.logoBlue,
                              textStyle: actionLabelStyle,
                              minimumSize: const Size(0, buttonHeight),
                              maximumSize: const Size(
                                double.infinity,
                                buttonHeight,
                              ),
                              fixedSize: const Size(
                                double.infinity,
                                buttonHeight,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ).copyWith(
                              backgroundColor: _lightBlueBackground(
                                baseColor: AppColors.logoBlue.withValues(
                                  alpha: 0.10,
                                ),
                              ),
                              overlayColor: _strongBlueOverlay(),
                            ),
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text(
                          'Remove',
                          style: actionLabelStyle?.copyWith(
                            color: AppColors.logoBlue,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
