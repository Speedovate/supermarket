import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/app_models.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../app_state/app_controller.dart';
import 'catalog_view_model.dart';

class CatalogPage extends ConsumerStatefulWidget {
  const CatalogPage({super.key});

  @override
  ConsumerState<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends ConsumerState<CatalogPage> {
  final _searchController = TextEditingController();
  final _bestSellersScrollController = ScrollController();
  Timer? _debounce;
  String _query = '';
  String _categoryId = 'all';
  CatalogSortOption _sortOption = CatalogSortOption.defaultOrder;
  CatalogSortOption _bestSellersSortOption = CatalogSortOption.defaultOrder;
  bool _isBestSellersInteracting = false;

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
    _bestSellersScrollController.addListener(_handleBestSellersScroll);
    _scheduleBestSellersVisibilityRefresh();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _bestSellersScrollController.removeListener(_handleBestSellersScroll);
    _bestSellersScrollController.dispose();
    super.dispose();
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
    final controller = ref.watch(appControllerProvider.notifier);
    final products = controller.publicProductsFor(
      categoryId: _categoryId,
      query: _query,
    );
    final sortedProducts = _sortProducts(products, _sortOption);
    final sortedBestSellers = _sortProducts(
      vm.bestSellers,
      _bestSellersSortOption,
    );
    final selectedCategory = vm.categories.cast<Category?>().firstWhere(
      (category) => category?.id == _categoryId,
      orElse: () => null,
    );
    final selectedCategoryTitle = _categoryId == 'all'
        ? 'All Products'
        : selectedCategory?.name ?? 'All Products';
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 700;
    const maxContentWidth = 1440.0;
    final gridPadding = _outerHorizontalPaddingForWidth(width);
    const gridSpacing = 16.0;
    final availableGridWidth = width - (gridPadding * 2);
    final columns = _catalogColumnsForWidth(width);
    final resolvedCardWidth = columns == 1
        ? availableGridWidth
        : (availableGridWidth - ((columns - 1) * gridSpacing)) / columns;
    _currentBestSellerItemExtent = resolvedCardWidth + gridSpacing;
    _scheduleBestSellersVisibilityRefresh();
    final gridCardDensity = _cardDensityForWidth(resolvedCardWidth);
    final resolvedCardHeight = switch (columns) {
      1 => lerpDouble(194.0, 186.0, gridCardDensity)!,
      2 => resolvedCardWidth + lerpDouble(185.0, 172.0, gridCardDensity)!,
      3 => resolvedCardWidth + lerpDouble(190.0, 174.0, gridCardDensity)!,
      4 => resolvedCardWidth + lerpDouble(181.0, 168.0, gridCardDensity)!,
      _ => resolvedCardWidth + lerpDouble(173.0, 160.0, gridCardDensity)!,
    };
    final gridAspectRatio = resolvedCardWidth / resolvedCardHeight;
    final bottomScrollPadding = vm.cartCount > 0
        ? (_kFloatingCartButtonBottomOffset * 2) + _kFloatingCartButtonHeight
        : gridPadding;

    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButtonLocation: columns <= 2
          ? FloatingActionButtonLocation.centerFloat
          : FloatingActionButtonLocation.endFloat,
      floatingActionButton: CartFab(
        itemCount: vm.cartCount,
        totalCentavos: vm.cartTotalCentavos,
        fullWidth: columns <= 2,
        horizontalMargin: gridPadding,
      ),
      body: SafeArea(
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
                  categories: vm.categories,
                  selectedId: _categoryId,
                  onSelected: (value) => setState(() => _categoryId = value),
                ),
              ),
            ),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        0,
                        18,
                        0,
                        0,
                      ),
                      child: _HeroBanner(
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
                          2,
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
                        padding: EdgeInsets.fromLTRB(
                          0,
                          18,
                          0,
                          0,
                        ),
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
                                      (_controlExtentForWidth(width) / 2) +
                                      2,
                                  top: 0,
                                  bottom: 0,
                                  child: Center(
                                    child: _ScrollChevronButton(
                                      icon: Icons.chevron_left_rounded,
                                      size: _controlExtentForWidth(width),
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
                                      (_controlExtentForWidth(width) / 2) +
                                      2,
                                  top: 0,
                                  bottom: 0,
                                  child: Center(
                                    child: _ScrollChevronButton(
                                      icon: Icons.chevron_right_rounded,
                                      size: _controlExtentForWidth(width),
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
                          24,
                          gridPadding,
                          bottomScrollPadding,
                        ),
                        child: EmptyStateCard(
                          title: 'No products found',
                          message: _query.isNotEmpty
                              ? 'Try a different search term or switch categories.'
                              : 'There are no active products in this section yet.',
                          actionLabel: 'Reset filters',
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
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: gridSpacing,
                          crossAxisSpacing: gridSpacing,
                          childAspectRatio: gridAspectRatio,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => ProductCard(
                            product: sortedProducts[index],
                            adaptiveSizing: true,
                            showImage: columns != 1,
                          ),
                          childCount: sortedProducts.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum CatalogSortOption {
  defaultOrder('Default'),
  nameAscending('Name A-Z'),
  priceLowToHigh('Price Low-High'),
  priceHighToLow('Price High-Low'),
  sizeSmallToLarge('Size Small-Large'),
  sizeLargeToSmall('Size Large-Small');

  const CatalogSortOption(this.label);

  final String label;
}

const _kHeaderControlHeight = 44.0;
const _kFloatingCartButtonHeight = 56.0;
const _kFloatingCartButtonBottomOffset = 16.0;

double _controlExtentForWidth(double width) {
  return _catalogColumnsForWidth(width) == 1 ? 36.0 : _kHeaderControlHeight;
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
    case CatalogSortOption.sizeSmallToLarge:
      sorted.sort((a, b) => _compareProductMeasures(a, b));
    case CatalogSortOption.sizeLargeToSmall:
      sorted.sort((a, b) => _compareProductMeasures(b, a));
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

int _compareProductMeasures(Product a, Product b) {
  final left = _normalizedMeasureFor(a);
  final right = _normalizedMeasureFor(b);

  if (left.familyRank != right.familyRank) {
    return left.familyRank.compareTo(right.familyRank);
  }
  final valueComparison = left.value.compareTo(right.value);
  if (valueComparison != 0) {
    return valueComparison;
  }
  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
}

_NormalizedMeasure _normalizedMeasureFor(Product product) {
  final numericValue = double.tryParse(product.quantity.trim()) ?? 0;
  final normalizedUnit = product.unit.trim().toLowerCase();

  switch (normalizedUnit) {
    case 'mg':
      return _NormalizedMeasure(familyRank: 0, value: numericValue / 1000);
    case 'g':
      return _NormalizedMeasure(familyRank: 0, value: numericValue);
    case 'kg':
      return _NormalizedMeasure(familyRank: 0, value: numericValue * 1000);
    case 'ml':
      return _NormalizedMeasure(familyRank: 1, value: numericValue);
    case 'l':
      return _NormalizedMeasure(familyRank: 1, value: numericValue * 1000);
    default:
      return _NormalizedMeasure(familyRank: 2, value: numericValue);
  }
}

class _NormalizedMeasure {
  const _NormalizedMeasure({required this.familyRank, required this.value});

  final int familyRank;
  final double value;
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
  return _catalogColumnsForWidth(width) == 1 ? 24.0 : 40.0;
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
  });

  final TextEditingController searchController;
  final String query;
  final ValueChanged<String> onSearchChanged;
  final int cartCount;

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
                    padding: EdgeInsets.only(right: searchGap),
                    child: _SearchField(
                      searchController: searchController,
                      query: query,
                      onSearchChanged: onSearchChanged,
                    ),
                  ),
                ),
              _CartButton(
                cartCount: cartCount,
                showLabel: !hideCartLabel,
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
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  final TextEditingController searchController;
  final String query;
  final ValueChanged<String> onSearchChanged;
  final int cartCount;
  final List<Category> categories;
  final String selectedId;
  final ValueChanged<String> onSelected;

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
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFE4E7EC)),
            _CategoryStrip(
              categories: categories,
              selectedId: selectedId,
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
  });

  final int cartCount;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => context.push('/cart'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Badge.count(
              count: cartCount,
              isLabelVisible: cartCount > 0,
              child: const Icon(Icons.shopping_cart_outlined, size: 28),
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
    );
  }
}

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Category> categories;
  final String selectedId;
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
                selected: selectedId == categories[i].id,
                onTap: () => onSelected(categories[i].id),
              ),
            ],
            SizedBox(width: edgeInset),
          ],
        ),
      ),
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final button = context.findRenderObject() as RenderBox;
        final overlay =
            Overlay.of(context).context.findRenderObject() as RenderBox;
        final result = await showMenu<CatalogSortOption>(
          context: context,
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
                child: Text(option.label, style: const TextStyle(height: 1.15)),
              ),
          ],
        );
        if (result != null) {
          onSelected(result);
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isMobile) ...[
            const Text(
              'Sort by:',
              style: TextStyle(fontWeight: FontWeight.w700, height: 1.15),
            ),
            const SizedBox(width: 8),
          ],
          Container(
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
                  Text(selected.label, style: const TextStyle(height: 1.15)),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down),
                ],
              ),
            ),
          ),
        ],
      ),
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
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
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
    required this.isMobile,
    required this.horizontalPadding,
    required this.columns,
    required this.cardWidth,
    required this.gridSpacing,
  });

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

  int get _activeBannerIndex {
    if (!_bannerScrollController.hasClients) {
      return 0;
    }
    final position = _bannerScrollController.position;
    final min = position.minScrollExtent;
    final max = position.maxScrollExtent;
    if ((max - min).abs() < 0.5) {
      return 0;
    }
    final progress = ((_bannerScrollController.offset - min) / (max - min))
        .clamp(0.0, 1.0);
    return progress >= 0.5 ? 1 : 0;
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

  Future<void> _snapBannerToNearest() async {
    if (!_bannerScrollController.hasClients) {
      return;
    }

    final position = _bannerScrollController.position;
    final current = position.pixels;
    final min = position.minScrollExtent;
    final max = position.maxScrollExtent;
    final midpoint = (min + max) / 2;
    final target = current <= midpoint ? min : max;

    if ((target - current).abs() < 0.5) {
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
                      itemCount: 2,
                      separatorBuilder: (context, index) =>
                          SizedBox(width: bannerGap),
                      itemBuilder: (context, index) => SizedBox(
                        width: bannerWidth,
                        child: const _PromoBannerPlaceholder(),
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
                      left:
                          widget.horizontalPadding -
                          (controlExtent / 2) +
                          2,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _ScrollChevronButton(
                          icon: Icons.chevron_left_rounded,
                          size: controlExtent,
                          onTap: () => _scrollBannerBy(-bannerWidth - bannerGap),
                        ),
                      ),
                    ),
                  if (_showRightControl)
                    Positioned(
                      right:
                          widget.horizontalPadding -
                          (controlExtent / 2) +
                          2,
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
                          count: 2,
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
  const _PromoBannerPlaceholder();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 3,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE4E7EC)),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Image.asset(
              'assets/branding/andrews_logo.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
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
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE4E7EC)),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF172033),
            size: size >= 44 ? 24 : 20,
          ),
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
          Container(width: sideWidth, color: Colors.white),
          const Spacer(),
          Container(width: sideWidth, color: Colors.white),
        ],
      ),
    );
  }
}

class _BannerIndexIndicator extends StatelessWidget {
  const _BannerIndexIndicator({
    required this.activeIndex,
    required this.count,
  });

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
  });

  final Product product;
  final bool compact;
  final bool adaptiveSizing;
  final bool posterMode;
  final bool showImage;

  @override
  ConsumerState<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends ConsumerState<ProductCard> {
  Future<void> _showProductModal(BuildContext context, int cartQuantity) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _ProductModal(product: widget.product),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartItem = ref.watch(
      appControllerProvider.select(
        (state) => state.cart
            .where((item) => item.productId == widget.product.id)
            .cast<CartItem?>()
            .firstWhere((item) => item != null, orElse: () => null),
      ),
    );
    final cartQuantity = cartItem?.quantity ?? 0;

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
        const buttonHeight = 36.0;
        const buttonVerticalPadding = 14.0;
        final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
          height: 1.15,
          fontSize: titleFontSize,
        );
        final titlePainter = TextPainter(
          text: TextSpan(text: widget.product.name, style: titleStyle),
          maxLines: 2,
          textDirection: Directionality.of(context),
        )..layout(maxWidth: constraints.maxWidth - (cardPadding * 2));
        final titleBlockHeight = titlePainter.height;

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
              if (widget.showImage) ...[
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showProductModal(context, cartQuantity),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: ProductPlaceholder(
                      label: widget.product.name,
                      posterMode: widget.posterMode,
                    ),
                  ),
                ),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFE4E7EC),
                ),
              ],
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: widget.showImage
                            ? null
                            : () => _showProductModal(context, cartQuantity),
                        child: Padding(
                          padding: EdgeInsets.all(cardPadding),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: titleBlockHeight,
                                child: Align(
                                  alignment: Alignment.topLeft,
                                  child: Text(
                                    widget.product.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: titleStyle,
                                  ),
                                ),
                              ),
                              SizedBox(height: titleBottomGap),
                              Text(
                                widget.product.displayUnit,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF667085),
                                  height: 1.15,
                                  fontSize: unitFontSize,
                                ),
                              ),
                              SizedBox(height: unitPriceSpacing),
                              const Spacer(),
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.end,
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    formatPesos(
                                      widget.product.referencePriceCentavos,
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: AppColors.logoBlue,
                                          fontWeight: FontWeight.w800,
                                          height: 1.15,
                                          fontSize: priceFontSize,
                                        ),
                                  ),
                                  Text(
                                    'as of ${formatAsOfDate(widget.product.priceUpdatedAt)}',
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
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        cardPadding,
                        0,
                        cardPadding,
                        cardPadding,
                      ),
                      child: Column(
                        children: [
                          SizedBox(height: priceButtonSpacing),
                          if (cartQuantity == 0)
                            SizedBox(
                              width: double.infinity,
                              height: buttonHeight,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.logoBlue,
                                  minimumSize: Size(0, buttonHeight),
                                  maximumSize: Size(double.infinity, buttonHeight),
                                  fixedSize: Size(double.infinity, buttonHeight),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  padding: EdgeInsets.symmetric(
                                    vertical: buttonVerticalPadding,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                onPressed: () async {
                                  await ref
                                      .read(appControllerProvider.notifier)
                                      .addToCart(widget.product, quantity: 1);
                                },
                                icon: const Icon(Icons.add_shopping_cart),
                                label: const Text('Add to Cart'),
                              ),
                            )
                          else
                            _CartQuantityControl(
                              quantity: cartQuantity,
                              height: buttonHeight,
                              onDecrease: () async {
                                final controller = ref.read(
                                  appControllerProvider.notifier,
                                );
                                if (cartQuantity <= 1) {
                                  await controller.removeFromCart(
                                    widget.product.id,
                                  );
                                } else {
                                  await controller.updateCartQuantity(
                                    widget.product.id,
                                    cartQuantity - 1,
                                  );
                                }
                              },
                              onIncrease: () async {
                                await ref
                                    .read(appControllerProvider.notifier)
                                    .updateCartQuantity(
                                      widget.product.id,
                                      cartQuantity + 1,
                                    );
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProductModal extends ConsumerWidget {
  const _ProductModal({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItem = ref.watch(
      appControllerProvider.select(
        (state) => state.cart
            .where((item) => item.productId == product.id)
            .cast<CartItem?>()
            .firstWhere((item) => item != null, orElse: () => null),
      ),
    );
    final cartQuantity = cartItem?.quantity ?? 0;
    final viewportWidth = MediaQuery.of(context).size.width;
    final viewportHeight = MediaQuery.of(context).size.height;
    const contentPadding = 16.0;
    const buttonHeight = 44.0;
    const minModalWidth = 280.0;
    const maxModalWidth = 520.0;
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
    final priceStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
      fontSize: 16,
      color: AppColors.logoBlue,
      fontWeight: FontWeight.w800,
      height: 1.15,
    );
    final asOfStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      color: const Color(0xFF667085),
      height: 1.15,
      fontSize: 11.5,
    );
    final actionLabelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w700,
      height: 1.15,
    );
    final addToCartLabelStyle = actionLabelStyle?.copyWith(color: Colors.white);
    final closeLabelStyle = actionLabelStyle?.copyWith(
      color: const Color(0xFFE31E24),
    );
    final unitPainter = TextPainter(
      text: TextSpan(text: product.displayUnit, style: unitStyle),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout(maxWidth: innerMaxWidth);
    final titlePainter = TextPainter(
      text: TextSpan(text: product.name, style: titleStyle),
      textDirection: Directionality.of(context),
    )..layout(maxWidth: innerMaxWidth);
    final pricePainter = TextPainter(
      text: TextSpan(
        text: formatPesos(product.referencePriceCentavos),
        style: priceStyle,
      ),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout(maxWidth: innerMaxWidth);
    final asOfPainter = TextPainter(
      text: TextSpan(
        text: 'as of ${formatAsOfDate(product.priceUpdatedAt)}',
        style: asOfStyle,
      ),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout(maxWidth: innerMaxWidth);
    final fixedContentHeight =
        20 +
        titlePainter.height +
        2 +
        unitPainter.height +
        12 +
        math.max(pricePainter.height, asOfPainter.height) +
        24 +
        buttonHeight;
    final responsiveImageSize = math.max(
      120.0,
      math.min(
        350.0,
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
                      label: product.name,
                      posterMode: true,
                      fullRounded: true,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(product.name, style: titleStyle),
                const SizedBox(height: 2),
                Text(product.displayUnit, style: unitStyle),
                const SizedBox(height: 12),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    Text(
                      formatPesos(product.referencePriceCentavos),
                      style: priceStyle,
                    ),
                    Text(
                      'as of ${formatAsOfDate(product.priceUpdatedAt)}',
                      style: asOfStyle,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (cartQuantity == 0)
                  SizedBox(
                    width: double.infinity,
                    height: buttonHeight,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.logoBlue,
                        textStyle: actionLabelStyle,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, buttonHeight),
                        maximumSize: const Size(double.infinity, buttonHeight),
                        fixedSize: const Size(double.infinity, buttonHeight),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      onPressed: () async {
                        await ref
                            .read(appControllerProvider.notifier)
                            .addToCart(product, quantity: 1);
                      },
                      icon: const Icon(Icons.add_shopping_cart),
                      label: Text('Add to Cart', style: addToCartLabelStyle),
                    ),
                  )
                else
                  _CartQuantityControl(
                    quantity: cartQuantity,
                    height: buttonHeight,
                    onDecrease: () async {
                      final controller = ref.read(
                        appControllerProvider.notifier,
                      );
                      if (cartQuantity <= 1) {
                        await controller.removeFromCart(product.id);
                      } else {
                        await controller.updateCartQuantity(
                          product.id,
                          cartQuantity - 1,
                        );
                      }
                    },
                    onIncrease: () async {
                        await ref
                            .read(appControllerProvider.notifier)
                            .updateCartQuantity(product.id, cartQuantity + 1);
                      },
                    ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: buttonHeight,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE31E24),
                      textStyle: actionLabelStyle,
                      minimumSize: const Size(0, buttonHeight),
                      maximumSize: const Size(double.infinity, buttonHeight),
                      fixedSize: const Size(double.infinity, buttonHeight),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      side: const BorderSide(color: Color(0xFFE4E7EC)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ).copyWith(
                      overlayColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.pressed)) {
                          return Colors.black.withValues(alpha: 0.12);
                        }
                        if (states.contains(WidgetState.hovered)) {
                          return Colors.black.withValues(alpha: 0.06);
                        }
                        if (states.contains(WidgetState.focused)) {
                          return Colors.black.withValues(alpha: 0.08);
                        }
                        return null;
                      }),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Close', style: closeLabelStyle),
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

class _CartQuantityControl extends StatelessWidget {
  const _CartQuantityControl({
    required this.quantity,
    required this.height,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int quantity;
  final double height;
  final Future<void> Function() onDecrease;
  final Future<void> Function() onIncrease;

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
            SizedBox(
              width: height,
              height: height,
              child: IconButton(
                onPressed: onIncrease,
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
