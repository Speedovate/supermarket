import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/app_models.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../app_state/app_controller.dart';

class AdminProductsPage extends ConsumerStatefulWidget {
  const AdminProductsPage({super.key});

  @override
  ConsumerState<AdminProductsPage> createState() => _AdminProductsPageState();
}

class _AdminProductsPageState extends ConsumerState<AdminProductsPage> {
  static const double _filtersMenuWidth = 248;
  static const double _filtersContentHorizontalPadding = 16;
  static const double _columnWidthAllowance = 2;
  static const double _dateHeaderExtraAllowance = 2;
  static const double _actionHitSize = 34;
  static double get _actionsWidth => _actionHitSize * 4;
  static double get _filtersFieldWidth =>
      _filtersMenuWidth - (_filtersContentHorizontalPadding * 2);

  String query = '';
  DateTime? createdAtFilter;
  DateTime? updatedAtFilter;
  int? categoryFilter;
  String? statusFilter;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final categories = [...state.categories]
      ..sort((a, b) => a.id.compareTo(b.id));
    final categoryById = {
      for (final category in categories) category.id: category.name,
    };
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 700;
    final gap = _columnGapForWidth(screenWidth);
    final textScale = _textScaleForWidth(screenWidth);
    final headerStyle = TextStyle(
      fontWeight: FontWeight.w700,
      color: AppColors.logoBlue,
      fontSize: 14 * textScale,
      height: 1.15,
    );
    final bodyStyle =
        (Theme.of(context).textTheme.bodyMedium ??
                const TextStyle(fontSize: 14, height: 1.15))
            .copyWith(
              fontSize:
                  ((Theme.of(context).textTheme.bodyMedium?.fontSize) ?? 14) *
                  textScale,
              height: 1.15,
            );

    final normalizedQuery = query.trim().toLowerCase();
    final products = [...state.products]
      ..sort(
        (a, b) => (b.updatedAt ?? b.priceUpdatedAt).compareTo(
          a.updatedAt ?? a.priceUpdatedAt,
        ),
      );
    final filteredProducts = products.where((product) {
      final categoryName = categoryById[product.categoryId] ?? '';
      final matchesQuery =
          normalizedQuery.isEmpty ||
          product.name.toLowerCase().contains(normalizedQuery) ||
          categoryName.toLowerCase().contains(normalizedQuery) ||
          '${product.id}'.contains(normalizedQuery);
      final createdAt = product.createdAt ?? product.priceUpdatedAt;
      final updatedAt = product.updatedAt ?? product.priceUpdatedAt;
      final matchesCreatedAt =
          createdAtFilter == null || _isSameDay(createdAt, createdAtFilter!);
      final matchesUpdatedAt =
          updatedAtFilter == null || _isSameDay(updatedAt, updatedAtFilter!);
      final matchesCategory =
          categoryFilter == null || product.categoryId == categoryFilter;
      final matchesStatus = switch (statusFilter) {
        'active' => product.isActive,
        'inactive' => !product.isActive,
        _ => true,
      };
      return matchesQuery &&
          matchesCreatedAt &&
          matchesUpdatedAt &&
          matchesCategory &&
          matchesStatus;
    }).toList();

    final widths = _computeProductColumnWidths(
      screenWidth: screenWidth,
      products: filteredProducts,
      categoryById: categoryById,
      headerStyle: headerStyle,
      bodyStyle: bodyStyle,
      gap: gap,
    );
    final activeFilterCount =
        (createdAtFilter == null ? 0 : 1) +
        (updatedAtFilter == null ? 0 : 1) +
        (categoryFilter == null ? 0 : 1) +
        (statusFilter == null ? 0 : 1);
    final toolbarActionSize = isMobile ? 48.0 : 0.0;

    return ListView(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: isMobile
                  ? Row(
                      children: [
                        Expanded(
                          child: TextField(
                            onChanged: (value) => setState(() => query = value),
                            decoration: const InputDecoration(
                              hintText: 'Search',
                              hintStyle: TextStyle(
                                color: AppColors.logoBlue,
                                height: 1.15,
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: AppColors.logoBlue,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        MenuAnchor(
                          style: const MenuStyle(
                            backgroundColor: WidgetStatePropertyAll(
                              Colors.white,
                            ),
                            surfaceTintColor: WidgetStatePropertyAll(
                              Colors.white,
                            ),
                            padding: WidgetStatePropertyAll(EdgeInsets.zero),
                            shape: WidgetStatePropertyAll(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(16),
                                ),
                              ),
                            ),
                          ),
                          menuChildren: [
                            _buildFiltersMenu(
                              context: context,
                              products: products,
                              categories: categories,
                            ),
                          ],
                          builder: (context, controller, child) {
                            return MousePressable(
                              onTap: () {
                                if (controller.isOpen) {
                                  controller.close();
                                } else {
                                  controller.open();
                                }
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                width: toolbarActionSize,
                                height: toolbarActionSize,
                                decoration: BoxDecoration(
                                  color: AppColors.logoBlue,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.filter_list_rounded,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    )
                  : Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: 280,
                          child: TextField(
                            onChanged: (value) => setState(() => query = value),
                            decoration: const InputDecoration(
                              hintText: 'Search',
                              hintStyle: TextStyle(
                                color: AppColors.logoBlue,
                                height: 1.15,
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: AppColors.logoBlue,
                              ),
                            ),
                          ),
                        ),
                        MenuAnchor(
                          style: const MenuStyle(
                            backgroundColor: WidgetStatePropertyAll(
                              Colors.white,
                            ),
                            surfaceTintColor: WidgetStatePropertyAll(
                              Colors.white,
                            ),
                            padding: WidgetStatePropertyAll(EdgeInsets.zero),
                            shape: WidgetStatePropertyAll(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(16),
                                ),
                              ),
                            ),
                          ),
                          menuChildren: [
                            _buildFiltersMenu(
                              context: context,
                              products: products,
                              categories: categories,
                            ),
                          ],
                          builder: (context, controller, child) {
                            return MousePressable(
                              onTap: () {
                                if (controller.isOpen) {
                                  controller.close();
                                } else {
                                  controller.open();
                                }
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.logoBlue,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.filter_list_rounded,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Filters',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        height: 1.15,
                                      ),
                                    ),
                                    if (activeFilterCount > 0) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        '$activeFilterCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          height: 1.15,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(width: 8),
                                    Icon(
                                      controller.isOpen
                                          ? Icons.keyboard_arrow_up_rounded
                                          : Icons
                                                .keyboard_arrow_down_rounded,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
            ),
            SizedBox(width: isMobile ? 8 : 12),
            MousePressable(
              onTap: () => _showProductDialog(context, ref),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: isMobile ? toolbarActionSize : null,
                height: isMobile ? toolbarActionSize : null,
                padding: isMobile
                    ? EdgeInsets.zero
                    : const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.logoBlue,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add, size: 18, color: Colors.white),
                    if (!isMobile) ...[
                      const SizedBox(width: 8),
                      const Text(
                        'New Product',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth =
                widths.id +
                gap +
                widths.name +
                gap +
                widths.status +
                gap +
                widths.category +
                gap +
                widths.price +
                gap +
                widths.createdAt +
                gap +
                widths.updatedAt +
                gap +
                _actionsWidth;
            final effectiveTableWidth = constraints.maxWidth > contentWidth + 40
                ? constraints.maxWidth
                : contentWidth + 40;
            final trailingSpace = effectiveTableWidth - (contentWidth + 40);

            return SectionCard(
              showShadow: false,
              padding: EdgeInsets.zero,
              borderRadius: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ColoredBox(
                  color: Colors.white,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: effectiveTableWidth,
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppColors.logoBlue.withValues(alpha: 0.10),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                              ),
                            ),
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                            child: _ProductHeaderRow(
                              widths: widths,
                              trailingSpace: trailingSpace,
                              isEmpty: filteredProducts.isEmpty,
                            ),
                          ),
                          const Divider(height: 0, thickness: 0.6),
                          if (filteredProducts.isEmpty)
                            ClipRRect(
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(16),
                                bottomRight: Radius.circular(16),
                              ),
                              child: const EmptyStateCard(
                                title: 'No products found',
                                message: 'Adjust filters or add a new product.',
                                showBorder: false,
                              ),
                            )
                          else
                            Column(
                              children: [
                                for (
                                  var i = 0;
                                  i < filteredProducts.length;
                                  i++
                                ) ...[
                                  _ProductRow(
                                    product: filteredProducts[i],
                                    categoryName:
                                        categoryById[filteredProducts[i]
                                            .categoryId] ??
                                        '',
                                    widths: widths,
                                    trailingSpace: trailingSpace,
                                    isLast: i == filteredProducts.length - 1,
                                    onPreview: () => _showProductPreviewDialog(
                                      context,
                                      filteredProducts[i],
                                    ),
                                    onEdit: () => _showProductDialog(
                                      context,
                                      ref,
                                      initial: filteredProducts[i],
                                    ),
                                    onToggleActive: () async {
                                      final product = filteredProducts[i];
                                      final nextIsActive = !product.isActive;
                                      final shouldToggle =
                                          await _showToggleProductStatusDialog(
                                            context,
                                            product.name,
                                            nextIsActive,
                                          );
                                      if (shouldToggle == true) {
                                        await ref
                                            .read(
                                              appControllerProvider.notifier,
                                            )
                                            .saveProduct(
                                              product.copyWith(
                                                isActive: nextIsActive,
                                                updatedAt: DateTime.now(),
                                              ),
                                            );
                                      }
                                    },
                                    onDelete: () => _deleteProduct(
                                      context,
                                      filteredProducts[i],
                                    ),
                                  ),
                                  if (i != filteredProducts.length - 1)
                                    const Divider(height: 0, thickness: 0.6),
                                ],
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  InputDecoration _filterDropdownDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(height: 1.15),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      filled: true,
      fillColor: const Color(0xFFF7F9FF),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFC7D7FE)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFC7D7FE)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.logoBlue),
      ),
    );
  }

  Widget _buildFiltersMenu({
    required BuildContext context,
    required List<Product> products,
    required List<Category> categories,
  }) {
    return SizedBox(
      width: _filtersMenuWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FiltersSection(
            title: 'Created at',
            child: SizedBox(
              width: _filtersFieldWidth,
              child: _DateField(
                label: createdAtFilter == null
                    ? 'Any'
                    : formatAsOfDate(createdAtFilter!),
                decoration: _filterDropdownDecoration('Created at'),
                icon: Icons.calendar_month_rounded,
                onTap: () async {
                  final dates = products
                      .map((item) => item.createdAt ?? item.priceUpdatedAt)
                      .toList();
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: dates.isEmpty
                        ? DateTime(2026, 1, 1)
                        : dates.reduce((a, b) => a.isBefore(b) ? a : b),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    initialDate:
                        createdAtFilter ??
                        (dates.isEmpty ? DateTime.now() : dates.first),
                  );
                  if (picked != null && mounted) {
                    setState(() => createdAtFilter = picked);
                  }
                },
              ),
            ),
          ),
          const _FilterDivider(),
          _FiltersSection(
            title: 'Updated at',
            child: SizedBox(
              width: _filtersFieldWidth,
              child: _DateField(
                label: updatedAtFilter == null
                    ? 'Any'
                    : formatAsOfDate(updatedAtFilter!),
                decoration: _filterDropdownDecoration('Updated at'),
                icon: Icons.calendar_month_rounded,
                onTap: () async {
                  final dates = products
                      .map((item) => item.updatedAt ?? item.priceUpdatedAt)
                      .toList();
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: dates.isEmpty
                        ? DateTime(2026, 1, 1)
                        : dates.reduce((a, b) => a.isBefore(b) ? a : b),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    initialDate:
                        updatedAtFilter ??
                        (dates.isEmpty ? DateTime.now() : dates.first),
                  );
                  if (picked != null && mounted) {
                    setState(() => updatedAtFilter = picked);
                  }
                },
              ),
            ),
          ),
          const _FilterDivider(),
          _FiltersSection(
            title: 'Category',
            child: SizedBox(
              width: _filtersFieldWidth,
              child: DropdownButtonFormField<int?>(
                isExpanded: true,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.logoBlue,
                  size: 24,
                ),
                initialValue: categoryFilter,
                decoration: _filterDropdownDecoration('Category'),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Any')),
                  ...categories.map(
                    (item) =>
                        DropdownMenuItem<int?>(value: item.id, child: Text(item.name)),
                  ),
                ],
                onChanged: (value) {
                  setState(() => categoryFilter = value);
                },
              ),
            ),
          ),
          const _FilterDivider(),
          _FiltersSection(
            title: 'Product status',
            child: SizedBox(
              width: _filtersFieldWidth,
              child: DropdownButtonFormField<String?>(
                isExpanded: true,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.logoBlue,
                  size: 24,
                ),
                initialValue: statusFilter,
                decoration: _filterDropdownDecoration('Product status'),
                items: const [
                  DropdownMenuItem<String?>(value: null, child: Text('Any')),
                  DropdownMenuItem<String?>(value: 'active', child: Text('Active')),
                  DropdownMenuItem<String?>(
                    value: 'inactive',
                    child: Text('Inactive'),
                  ),
                ],
                onChanged: (value) {
                  setState(() => statusFilter = value);
                },
              ),
            ),
          ),
          const _FilterDivider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              _filtersContentHorizontalPadding,
              12,
              _filtersContentHorizontalPadding,
              _filtersContentHorizontalPadding,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: _filtersFieldWidth,
                child: MousePressable(
                  onTap: () {
                    setState(() {
                      createdAtFilter = null;
                      updatedAtFilter = null;
                      categoryFilter = null;
                      statusFilter = null;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE4E7EC)),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Clear',
                      style: TextStyle(fontWeight: FontWeight.w700, height: 1.15),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  _ProductColumnWidths _computeProductColumnWidths({
    required double screenWidth,
    required List<Product> products,
    required Map<int, String> categoryById,
    required TextStyle headerStyle,
    required TextStyle bodyStyle,
    required double gap,
  }) {
    final badgeTextStyle = bodyStyle.copyWith(fontWeight: FontWeight.w700);

    double maxWidth(
      String header,
      Iterable<String> values, {
      TextStyle? valuesStyle,
    }) {
      final painter = TextPainter(textDirection: TextDirection.ltr);
      var max = 0.0;
      final effectiveValuesStyle = valuesStyle ?? bodyStyle;
      for (final value in [header, ...values]) {
        painter.text = TextSpan(text: value, style: effectiveValuesStyle);
        painter.layout();
        max = math.max(max, painter.width);
      }
      painter.text = TextSpan(text: header, style: headerStyle);
      painter.layout();
      max = math.max(max, painter.width);
      return max.ceilToDouble() + _columnWidthAllowance;
    }

    double cappedMaxWidth(
      String header,
      Iterable<String> values, {
      required double max,
      TextStyle? valuesStyle,
    }) {
      final width = maxWidth(header, values, valuesStyle: valuesStyle);
      return width > max ? max : width;
    }

    return _ProductColumnWidths(
      gap: gap,
      id: maxWidth('ID', products.map((item) => '${item.id}')),
      name: cappedMaxWidth(
        'Name',
        products.map((item) => item.name),
        max: screenWidth < 700 ? 144 : 176,
      ),
      category: cappedMaxWidth(
        'Category',
        products.map((item) => categoryById[item.categoryId] ?? ''),
        max: screenWidth < 700 ? 128 : 156,
      ),
      status: maxWidth(
        'Status',
        products.map((item) => item.isActive ? 'Active' : 'Inactive'),
        valuesStyle: badgeTextStyle,
      ) + 24,
      price: maxWidth(
        'Price',
        products.map((item) => formatPesos(item.referencePriceCentavos)),
      ),
      createdAt: maxWidth(
        'Created at',
        products.map(
          (item) =>
              '${formatOrderDate(item.createdAt ?? item.priceUpdatedAt)}\n${formatOrderTimeWithSeconds(item.createdAt ?? item.priceUpdatedAt)}',
        ),
      ) + _dateHeaderExtraAllowance,
      updatedAt: maxWidth(
        'Updated at',
        products.map(
          (item) =>
              '${formatOrderDate(item.updatedAt ?? item.priceUpdatedAt)}\n${formatOrderTimeWithSeconds(item.updatedAt ?? item.priceUpdatedAt)}',
        ),
      ) + _dateHeaderExtraAllowance,
    );
  }

  double _columnGapForWidth(double width) {
    if (width <= 360) {
      return 24;
    }
    if (width < 700) {
      return 32;
    }
    return 40;
  }

  double _textScaleForWidth(double width) {
    if (width <= 360) {
      return 0.82;
    }
    if (width < 700) {
      return 0.90;
    }
    return 1;
  }

  Future<void> _deleteProduct(BuildContext context, Product product) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AppModalFrame(
          title: 'Remove Product?',
          actions: [
            AppModalButton(
              label: 'Close',
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            const SizedBox(width: 10),
            AppModalButton(
              label: 'Delete',
              isPrimary: true,
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
          child: AppModalBodyText('${product.name.trim()} will be deleted.'),
        );
      },
    );
    if (shouldDelete != true || !mounted) {
      return;
    }
    await ref.read(appControllerProvider.notifier).deleteProduct(product.id);
  }

  Future<bool?> _showToggleProductStatusDialog(
    BuildContext context,
    String productName,
    bool nextIsActive,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AppModalFrame(
          title: nextIsActive ? 'Activate Product?' : 'Deactivate Product?',
          actions: [
            AppModalButton(
              label: 'Close',
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            const SizedBox(width: 10),
            AppModalButton(
              label: nextIsActive ? 'Activate' : 'Deactivate',
              isPrimary: true,
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
          child: AppModalBodyText(
            nextIsActive
                ? '${productName.trim()} will be activated.'
                : '${productName.trim()} will be deactivated.',
          ),
        );
      },
    );
  }

  Future<void> _showProductPreviewDialog(
    BuildContext context,
    Product product,
  ) {
    final titleStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w800,
      height: 1.15,
    );
    final unitStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      color: const Color(0xFF667085),
      fontSize: 12,
      height: 1.15,
    );
    final priceStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
      fontSize: 16,
      color: AppColors.logoBlue,
      fontWeight: FontWeight.w800,
      height: 1.15,
    );
    final asOfStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      color: const Color(0xFF667085),
      fontSize: 11.5,
      height: 1.15,
    );

    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AppModalFrame(
          title: '',
          actions: [
            AppModalButton(
              label: 'Close',
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: SizedBox(
                  width: 300,
                  height: 300,
                  child: ProductPlaceholder(
                    fullRounded: true,
                    label: product.name,
                    posterMode: true,
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
            ],
          ),
        );
      },
    );
  }

  Future<void> _showProductDialog(
    BuildContext context,
    WidgetRef ref, {
    Product? initial,
  }) async {
    final state = ref.read(appControllerProvider);
    final categories = state.categories.toList();
    final nameController = TextEditingController(text: initial?.name ?? '');
    final quantityController = TextEditingController(
      text: initial?.quantity ?? '',
    );
    final unitController = TextEditingController(text: initial?.unit ?? '');
    final typeController = TextEditingController(text: initial?.type ?? '');
    final priceController = TextEditingController(
      text: initial == null
          ? ''
          : (initial.referencePriceCentavos / 100).toStringAsFixed(2),
    );
    var selectedCategory = initial?.categoryId ?? categories.first.id;
    var isActive = initial?.isActive ?? true;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AppModalFrame(
              title: initial == null ? 'New Product' : 'Edit Product',
              actions: [
                AppModalButton(
                  label: 'Close',
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                const SizedBox(width: 10),
                AppModalButton(
                  label: 'Save',
                  isPrimary: true,
                  onPressed: () async {
                    final parsedPrice =
                        (double.tryParse(priceController.text.trim()) ?? 0) *
                        100;
                    final product = Product(
                      createdAt: initial?.createdAt ?? DateTime.now(),
                      updatedAt: DateTime.now(),
                      id:
                          initial?.id ??
                          ((state.products
                                  .map((item) => item.id)
                                  .fold<int>(
                                    0,
                                    (max, value) => value > max ? value : max,
                                  )) +
                              1),
                      name: nameController.text.trim(),
                      categoryId: selectedCategory,
                      categoryNameSnapshot: '',
                      quantity: quantityController.text.trim(),
                      unit: unitController.text.trim(),
                      type: typeController.text.trim(),
                      referencePriceCentavos: parsedPrice.round(),
                      priceUpdatedAt:
                          initial?.priceUpdatedAt ?? DateTime(2026, 7, 31),
                      isActive: isActive,
                      validOrderedQuantity: initial?.validOrderedQuantity ?? 0,
                      validOrderCount: initial?.validOrderCount ?? 0,
                      photoUrl: initial?.photoUrl,
                      photoStoragePath: initial?.photoStoragePath,
                      lastValidOrderAt: initial?.lastValidOrderAt,
                    );
                    await ref
                        .read(appControllerProvider.notifier)
                        .saveProduct(product);
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                ),
              ],
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Product name',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: selectedCategory,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: categories
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.id,
                              child: Text(item.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(
                        () => selectedCategory = value ?? selectedCategory,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: quantityController,
                      decoration: const InputDecoration(labelText: 'Quantity'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: unitController,
                      decoration: const InputDecoration(labelText: 'Unit'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: typeController,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        hintText: 'pack, bottle, can, tube',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Reference price (PHP)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      dense: true,
                      visualDensity: const VisualDensity(vertical: -4),
                      contentPadding: EdgeInsets.zero,
                      thumbColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return Colors.white;
                        }
                        return null;
                      }),
                      trackColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return AppColors.statusActiveGreen;
                        }
                        return null;
                      }),
                      title: const Text('Active'),
                      value: isActive,
                      onChanged: (value) => setState(() => isActive = value),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _FiltersSection extends StatelessWidget {
  const _FiltersSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _AdminProductsPageState._filtersContentHorizontalPadding,
        16,
        _AdminProductsPageState._filtersContentHorizontalPadding,
        16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.logoBlue,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _FilterDivider extends StatelessWidget {
  const _FilterDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 0.6, color: Color(0xFFE4E7EC));
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.decoration,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final InputDecoration decoration;
  final IconData icon;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final isPlaceholder = label == 'Any';
    return MousePressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        isEmpty: false,
        decoration: decoration,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFF1D2939),
                  fontSize: isPlaceholder ? 16.5 : 16,
                  height: 1.15,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(icon, color: AppColors.logoBlue, size: 22),
          ],
        ),
      ),
    );
  }
}

class _ProductHeaderRow extends StatelessWidget {
  const _ProductHeaderRow({
    required this.widths,
    required this.trailingSpace,
    required this.isEmpty,
  });

  final _ProductColumnWidths widths;
  final double trailingSpace;
  final bool isEmpty;

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      fontWeight: FontWeight.w700,
      color: AppColors.logoBlue,
      fontSize: 14 * _textScaleForWidth(MediaQuery.of(context).size.width),
      height: 1.15,
    );
    return Row(
      children: [
        SizedBox(
          width: widths.id,
          child: Text('ID', style: labelStyle, maxLines: 1),
        ),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.name,
          child: Text('Name', style: labelStyle, maxLines: 1),
        ),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.status,
          child: Text('Status', style: labelStyle, maxLines: 1),
        ),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.category,
          child: Text('Category', style: labelStyle, maxLines: 1),
        ),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.price,
          child: Text('Price', style: labelStyle, maxLines: 1),
        ),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.createdAt,
          child: Text(
            'Created at',
            style: labelStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.updatedAt,
          child: Text(
            'Updated at',
            style: labelStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: widths.gap),
        if (trailingSpace > 0)
          SizedBox(width: trailingSpace),
        SizedBox(
          width: _AdminProductsPageState._actionsWidth,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Actions',
              style: labelStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product,
    required this.categoryName,
    required this.widths,
    required this.trailingSpace,
    required this.isLast,
    required this.onPreview,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  final Product product;
  final String categoryName;
  final _ProductColumnWidths widths;
  final double trailingSpace;
  final bool isLast;
  final VoidCallback onPreview;
  final VoidCallback onEdit;
  final Future<void> Function() onToggleActive;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final status = product.isActive ? 'Active' : 'Inactive';
    final scale = _textScaleForWidth(MediaQuery.of(context).size.width);
    final bodyStyle = DefaultTextStyle.of(context).style.copyWith(
      fontSize: (DefaultTextStyle.of(context).style.fontSize ?? 14) * scale,
      height: 1.15,
    );
    final createdAt = product.createdAt ?? product.priceUpdatedAt;
    final updatedAt = product.updatedAt ?? product.priceUpdatedAt;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isLast
            ? const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: widths.id,
              child: Text('${product.id}', style: bodyStyle),
            ),
            SizedBox(width: widths.gap),
            SizedBox(
              width: widths.name,
              child: Text(
                product.name,
                style: bodyStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: widths.gap),
            SizedBox(
              width: widths.status,
              child: Align(
                alignment: Alignment.centerLeft,
                child: AdminStateBadge(
                  label: status,
                  color: product.isActive
                      ? AppColors.statusActiveGreen
                      : const Color(0xFF98A2B3),
                  fontSize: bodyStyle.fontSize ?? 14,
                ),
              ),
            ),
            SizedBox(width: widths.gap),
            SizedBox(
              width: widths.category,
              child: Text(
                categoryName,
                style: bodyStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: widths.gap),
            SizedBox(
              width: widths.price,
              child: Text(
                formatPesos(product.referencePriceCentavos),
                style: bodyStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: widths.gap),
            SizedBox(
              width: widths.createdAt,
              child: Text(
                '${formatOrderDate(createdAt)}\n${formatOrderTimeWithSeconds(createdAt)}',
                style: bodyStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: widths.gap),
            SizedBox(
              width: widths.updatedAt,
              child: Text(
                '${formatOrderDate(updatedAt)}\n${formatOrderTimeWithSeconds(updatedAt)}',
                style: bodyStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: widths.gap),
            if (trailingSpace > 0)
              SizedBox(width: trailingSpace),
            SizedBox(
              width: _AdminProductsPageState._actionsWidth,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  MousePressable(
                    onTap: onPreview,
                    borderRadius: BorderRadius.circular(10),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.visibility_outlined, size: 18),
                    ),
                  ),
                  MousePressable(
                    onTap: onEdit,
                    borderRadius: BorderRadius.circular(10),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.edit_outlined, size: 18),
                    ),
                  ),
                  MousePressable(
                    onTap: onToggleActive,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        product.isActive
                            ? Icons.close_rounded
                            : Icons.check_rounded,
                        size: 18,
                      ),
                    ),
                  ),
                  MousePressable(
                    onTap: onDelete,
                    borderRadius: BorderRadius.circular(10),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.delete_outline, size: 18),
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

class _ProductColumnWidths {
  const _ProductColumnWidths({
    required this.gap,
    required this.id,
    required this.name,
    required this.category,
    required this.status,
    required this.price,
    required this.createdAt,
    required this.updatedAt,
  });

  final double gap;
  final double id;
  final double name;
  final double category;
  final double status;
  final double price;
  final double createdAt;
  final double updatedAt;
}

bool _isSameDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

double _textScaleForWidth(double width) {
  if (width <= 360) {
    return 0.82;
  }
  if (width < 700) {
    return 0.90;
  }
  return 1;
}
