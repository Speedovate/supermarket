import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/app_models.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../app_state/app_controller.dart';

class AdminOrdersPage extends ConsumerStatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  ConsumerState<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends ConsumerState<AdminOrdersPage> {
  static const double _filtersMenuWidth = 248;
  static const double _filtersContentHorizontalPadding = 16;
  static const double _columnWidthAllowance = 8;
  static const double _dateHeaderExtraAllowance = 8;
  static const double _statusBadgeHorizontalPadding = 28;
  static const double _actionHitSize = 34;
  static double get _actionsWidth => _actionHitSize * 4;
  static double get _filtersFieldWidth =>
      _filtersMenuWidth - (_filtersContentHorizontalPadding * 2);

  final TextEditingController _queryController = TextEditingController();
  String query = '';
  DateTime? createdAtFilter;
  DateTime? updatedAtFilter;
  OrderStatus? statusFilter;
  FulfillmentMethod? methodFilter;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyRouteFilters();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _applyRouteFilters() {
    final uri = GoRouterState.of(context).uri;
    query = uri.queryParameters['query'] ?? uri.queryParameters['q'] ?? '';
    if (_queryController.text != query) {
      _queryController.value = TextEditingValue(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
      );
    }
    createdAtFilter = _parseRouteDate(uri.queryParameters['filters[created_at]']);
    updatedAtFilter = _parseRouteDate(uri.queryParameters['filters[updated_at]']);
    statusFilter = _parseOrderStatus(uri.queryParameters['filters[status]']);
    methodFilter = _parseMethod(uri.queryParameters['filters[method]']);
  }

  void _setFilters(VoidCallback update) {
    setState(update);
    _updateRouteFilters();
  }

  void _updateRouteFilters() {
    final currentUri = GoRouterState.of(context).uri;
    final params = <String, String>{};
    if (query.trim().isNotEmpty) {
      params['query'] = query.trim();
    }
    if (statusFilter != null) {
      params['filters[status]'] = statusFilter!.name;
    }
    if (methodFilter != null) {
      params['filters[method]'] = methodFilter!.name;
    }
    if (createdAtFilter != null) {
      params['filters[created_at]'] = _formatRouteDate(createdAtFilter!);
    }
    if (updatedAtFilter != null) {
      params['filters[updated_at]'] = _formatRouteDate(updatedAtFilter!);
    }
    final nextUri = Uri(path: currentUri.path, queryParameters: params);
    if (nextUri.toString() != currentUri.toString()) {
      context.replace(nextUri.toString());
    }
  }

  String _displayBarangayWithCutoff(OrderRequest order) {
    if (order.method != FulfillmentMethod.delivery) {
      return '-';
    }
    final place = order.place.trim();
    if (place.isEmpty) {
      return '-';
    }
    Barangay? barangay;
    for (final item in ref.read(appControllerProvider).barangays) {
      if (item.name.trim().toLowerCase() == place.toLowerCase()) {
        barangay = item;
        break;
      }
    }
    if (barangay == null) {
      return place;
    }
    return '$place - ${formatBarangayCutoffValue(barangay)}';
  }

  @override
  Widget build(BuildContext context) {
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

    final orders = [...ref.watch(appControllerProvider).orders]
      ..sort((a, b) => b.id.compareTo(a.id));
    final normalized = query.trim().toLowerCase();
    final filteredOrders = orders.where((order) {
      final matchesQuery =
          normalized.isEmpty ||
          order.name.toLowerCase().contains(normalized) ||
          order.phone.toLowerCase().contains(normalized) ||
          order.place.toLowerCase().contains(normalized) ||
          order.addressStreet.toLowerCase().contains(normalized) ||
          order.addressLandmark.toLowerCase().contains(normalized) ||
          displayFulfillment(order.method).toLowerCase().contains(normalized) ||
          displayStatus(order.status).toLowerCase().contains(normalized) ||
          '${order.id}'.contains(normalized);
      final matchesCreatedAt =
          createdAtFilter == null ||
          _isSameDay(order.createdAt, createdAtFilter!);
      final matchesUpdatedAt =
          updatedAtFilter == null ||
          _isSameDay(order.updatedAt, updatedAtFilter!);
      final matchesStatus =
          statusFilter == null || order.status == statusFilter;
      final matchesMethod = methodFilter == null || order.method == methodFilter;
      return matchesQuery &&
          matchesCreatedAt &&
          matchesUpdatedAt &&
          matchesStatus &&
          matchesMethod;
    }).toList();

    final widths = _computeOrderColumnWidths(
      screenWidth: screenWidth,
      orders: filteredOrders,
      headerStyle: headerStyle,
      bodyStyle: bodyStyle,
      gap: gap,
    );
    final activeFilterCount =
        (createdAtFilter == null ? 0 : 1) +
        (updatedAtFilter == null ? 0 : 1) +
        (statusFilter == null ? 0 : 1) +
        (methodFilter == null ? 0 : 1);
    final toolbarActionSize = isMobile ? 48.0 : 0.0;

    return Column(
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
                            controller: _queryController,
                            onChanged: (value) => _setFilters(() => query = value),
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
                            _buildFiltersMenu(context: context, orders: orders),
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
                            controller: _queryController,
                            onChanged: (value) => _setFilters(() => query = value),
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
                            _buildFiltersMenu(context: context, orders: orders),
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
          ],
        ),
        const SizedBox(height: 12),
        Flexible(
          fit: FlexFit.loose,
          child: LayoutBuilder(
            builder: (context, constraints) {
            final contentWidth =
                widths.id +
                gap +
                widths.name +
                gap +
                widths.phone +
                gap +
                widths.status +
                gap +
                widths.items +
                gap +
                widths.total +
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
            const headerHeight = 53.0;
            const dividerHeight = 0.6;
            const emptyStateHeight = 232.0;
            final rowHeights = filteredOrders
                .map(
                  (order) => _measureOrderRowHeight(
                    order: order,
                    widths: widths,
                    bodyStyle: bodyStyle,
                  ),
                )
                .toList();
            final contentHeightEstimate = filteredOrders.isEmpty
                ? emptyStateHeight
                : rowHeights.fold<double>(0, (sum, height) => sum + height) +
                    math.max(0, filteredOrders.length - 1) * dividerHeight;
            final maxTableHeight = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : headerHeight + dividerHeight + contentHeightEstimate;
            final targetTableHeight = math.min(
              maxTableHeight,
              headerHeight + dividerHeight + contentHeightEstimate,
            );
            final shouldScrollBody =
                headerHeight + dividerHeight + contentHeightEstimate >
                maxTableHeight;

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
                      height: shouldScrollBody ? targetTableHeight : null,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
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
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                            child: _OrderHeaderRow(
                              widths: widths,
                              trailingSpace: trailingSpace,
                              isEmpty: filteredOrders.isEmpty,
                            ),
                          ),
                          const Divider(
                            height: 0,
                            thickness: 0.6,
                            color: Color(0xFFE4E7EC),
                          ),
                          if (filteredOrders.isEmpty)
                            if (shouldScrollBody)
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(16),
                                    bottomRight: Radius.circular(16),
                                  ),
                                  child: const EmptyStateCard(
                                    title: 'No orders found',
                                    message:
                                        'Customer submissions will appear here.',
                                    showBorder: false,
                                  ),
                                ),
                              )
                            else
                              ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(16),
                                  bottomRight: Radius.circular(16),
                                ),
                                child: const EmptyStateCard(
                                  title: 'No orders found',
                                  message:
                                      'Customer submissions will appear here.',
                                  showBorder: false,
                                ),
                              )
                          else
                            shouldScrollBody
                                ? Expanded(
                                    child: ListView.separated(
                                      padding: EdgeInsets.zero,
                                      itemCount: filteredOrders.length,
                                      itemBuilder: (context, i) => _OrderRow(
                                        order: filteredOrders[i],
                                        widths: widths,
                                        trailingSpace: trailingSpace,
                                        isLast: i == filteredOrders.length - 1,
                                        onView: () => _showOrderPreviewDialog(
                                          context,
                                          filteredOrders[i],
                                        ),
                                        onEdit: () => _showEditOrderStatusDialog(
                                          context,
                                          filteredOrders[i],
                                        ),
                                        onCopy: () => _copyOrderSummary(
                                          context,
                                          filteredOrders[i],
                                        ),
                                        onOpen: () => context.go(
                                          '/admin/orders/${filteredOrders[i].id}',
                                        ),
                                      ),
                                      separatorBuilder: (context, i) =>
                                          const Divider(
                                            height: 0,
                                            thickness: 0.6,
                                            color: Color(0xFFE4E7EC),
                                          ),
                                    ),
                                  )
                                : Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      for (var i = 0; i < filteredOrders.length; i++) ...[
                                        _OrderRow(
                                          order: filteredOrders[i],
                                          widths: widths,
                                          trailingSpace: trailingSpace,
                                          isLast: i == filteredOrders.length - 1,
                                          onView: () => _showOrderPreviewDialog(
                                            context,
                                            filteredOrders[i],
                                          ),
                                          onEdit: () => _showEditOrderStatusDialog(
                                            context,
                                            filteredOrders[i],
                                          ),
                                          onCopy: () => _copyOrderSummary(
                                            context,
                                            filteredOrders[i],
                                          ),
                                          onOpen: () => context.go(
                                            '/admin/orders/${filteredOrders[i].id}',
                                          ),
                                        ),
                                        if (i != filteredOrders.length - 1)
                                          const Divider(
                                            height: 0,
                                            thickness: 0.6,
                                            color: Color(0xFFE4E7EC),
                                          ),
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
    required List<OrderRequest> orders,
  }) {
    return SizedBox(
      width: _filtersMenuWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FiltersSection(
            title: 'Status',
            child: SizedBox(
              width: _filtersFieldWidth,
              child: DropdownButtonFormField<OrderStatus?>(
                isExpanded: true,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.logoBlue,
                  size: 24,
                ),
                initialValue: statusFilter,
                decoration: _filterDropdownDecoration('Status'),
                items: [
                  const DropdownMenuItem<OrderStatus?>(
                    value: null,
                    child: Text('Any'),
                  ),
                  ...OrderStatus.values.map(
                    (status) => DropdownMenuItem<OrderStatus?>(
                      value: status,
                      child: Text(displayStatus(status)),
                    ),
                  ),
                ],
                onChanged: (value) {
                  _setFilters(() => statusFilter = value);
                },
              ),
            ),
          ),
          const _FilterDivider(),
          _FiltersSection(
            title: 'Method',
            child: SizedBox(
              width: _filtersFieldWidth,
              child: DropdownButtonFormField<FulfillmentMethod?>(
                isExpanded: true,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.logoBlue,
                  size: 24,
                ),
                initialValue: methodFilter,
                decoration: _filterDropdownDecoration('Method'),
                items: [
                  const DropdownMenuItem<FulfillmentMethod?>(
                    value: null,
                    child: Text('Any'),
                  ),
                  ...FulfillmentMethod.values.map(
                    (method) => DropdownMenuItem<FulfillmentMethod?>(
                      value: method,
                      child: Text(displayFulfillment(method)),
                    ),
                  ),
                ],
                onChanged: (value) {
                  _setFilters(() => methodFilter = value);
                },
              ),
            ),
          ),
          const _FilterDivider(),
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
                  final dates = orders.map((item) => item.createdAt).toList();
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
                    _setFilters(() => createdAtFilter = picked);
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
                  final dates = orders.map((item) => item.updatedAt).toList();
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
                    _setFilters(() => updatedAtFilter = picked);
                  }
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
                    _setFilters(() {
                      createdAtFilter = null;
                      updatedAtFilter = null;
                      statusFilter = null;
                      methodFilter = null;
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

  DateTime? _parseRouteDate(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  String _formatRouteDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  OrderStatus? _parseOrderStatus(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return OrderStatus.values.cast<OrderStatus?>().firstWhere(
      (item) => item?.name == value,
      orElse: () => null,
    );
  }

  FulfillmentMethod? _parseMethod(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return FulfillmentMethod.values.cast<FulfillmentMethod?>().firstWhere(
      (item) => item?.name == value,
      orElse: () => null,
    );
  }

  _OrderColumnWidths _computeOrderColumnWidths({
    required double screenWidth,
    required List<OrderRequest> orders,
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

    return _OrderColumnWidths(
      gap: gap,
      id: maxWidth('ID', orders.map((item) => '${item.id}')),
      name: cappedMaxWidth(
        'Name',
        orders.map((item) => item.name),
        max: screenWidth < 700 ? 132 : 168,
      ),
      phone: maxWidth(
        'Phone',
        orders.map((item) => item.phone),
      ),
      total: maxWidth(
        'Total',
        orders.map((item) => formatPesos(item.total)),
      ),
      status: maxWidth(
        'Status',
        orders.map((item) => displayStatus(item.status)),
        valuesStyle: badgeTextStyle,
      ) + _statusBadgeHorizontalPadding,
      items: maxWidth(
        'Items',
        orders.map(
          (item) => '${item.items.fold<int>(0, (sum, entry) => sum + entry.requestedQuantity)}',
        ),
      ),
      createdAt: maxWidth(
        'Created at',
        orders.map(
          (item) =>
              '${formatOrderDate(item.createdAt)}\n${formatOrderTimeWithSeconds(item.createdAt)}',
        ),
      ) + _dateHeaderExtraAllowance,
      updatedAt: maxWidth(
        'Updated at',
        orders.map(
          (item) =>
              '${formatOrderDate(item.updatedAt)}\n${formatOrderTimeWithSeconds(item.updatedAt)}',
        ),
      ) + _dateHeaderExtraAllowance,
    );
  }

  double _columnGapForWidth(double width) {
    return 20;
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

  Future<void> _copyOrderSummary(
    BuildContext context,
    OrderRequest order,
  ) async {
    final methodLabel = order.method == FulfillmentMethod.pickup
        ? 'For Pickup'
        : displayFulfillment(order.method);
    final methodLine = order.method == FulfillmentMethod.delivery &&
            order.place.trim().isNotEmpty
        ? '$methodLabel - ${order.place}'
        : methodLabel;
    final addressLines =
        order.method == FulfillmentMethod.delivery
        ? [
            if (order.addressStreet.trim().isNotEmpty ||
                order.addressLandmark.trim().isNotEmpty)
              order.addressStreet.trim().isNotEmpty
                  ? order.addressStreet.trim()
                  : order.addressLandmark.trim(),
          ]
        : const <String>[];
    final productLines = order.products.isEmpty
        ? ['Items: -']
        : [
            'Items:',
            ...order.products.map(
              (item) =>
                  '- ${item.productName} | ${item.unit} | x${item.requestedQuantity}',
            ),
          ];
    final summary = [
      'Order #${order.id}',
      methodLine,
      '${formatOrderDate(order.createdAt)} ${formatOrderTimeWithSeconds(order.createdAt)}',
      if (addressLines.isNotEmpty) ...[
        ...addressLines,
      ],
      '',
      order.name,
      order.phone,
      '',
      ...productLines,
    ].join('\n');

    await Clipboard.setData(ClipboardData(text: summary));
    if (!context.mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(successSnackBar('Order copied.'));
  }

  Future<void> _showOrderPreviewDialog(
    BuildContext context,
    OrderRequest order,
  ) async {
    final itemCount = order.products.fold<int>(
      0,
      (sum, item) => sum + item.requestedQuantity,
    );
    final bodyStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(height: 1.15);
    final labelStyle = bodyStyle?.copyWith(
      fontWeight: FontWeight.w700,
      color: const Color(0xFF101828),
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AppModalFrame(
          title: 'Order #${order.id}',
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
              Text('Name', style: labelStyle),
              Text(order.name, style: bodyStyle),
              const SizedBox(height: 10),
              Text('Phone', style: labelStyle),
              PhoneActionText(order.phone, style: bodyStyle),
              const SizedBox(height: 10),
              Text('Method', style: labelStyle),
              Text(displayFulfillment(order.method), style: bodyStyle),
              const SizedBox(height: 10),
              Text('Barangay', style: labelStyle),
              Text(_displayBarangayWithCutoff(order), style: bodyStyle),
              if (order.method == FulfillmentMethod.delivery) ...[
                const SizedBox(height: 10),
                Text('Street/Landmark', style: labelStyle),
                Text(
                  order.addressStreet.trim().isNotEmpty
                      ? order.addressStreet
                      : order.addressLandmark.trim().isNotEmpty
                      ? order.addressLandmark
                      : '-',
                  style: bodyStyle,
                ),
              ],
              const SizedBox(height: 10),
              Text('Status', style: labelStyle),
              Text(displayStatus(order.status), style: bodyStyle),
              const SizedBox(height: 10),
              Text('Total', style: labelStyle),
              Text(formatPesos(order.total), style: bodyStyle),
              const SizedBox(height: 10),
              Text('Created at', style: labelStyle),
              Text(
                '${formatOrderDate(order.createdAt)} ${formatOrderTimeWithSeconds(order.createdAt)}',
                style: bodyStyle,
              ),
              const SizedBox(height: 10),
              Text('Updated at', style: labelStyle),
              Text(
                '${formatOrderDate(order.updatedAt)} ${formatOrderTimeWithSeconds(order.updatedAt)}',
                style: bodyStyle,
              ),
              const SizedBox(height: 10),
              Text('Items', style: labelStyle),
              const SizedBox(height: 4),
              MousePressable(
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  context.go('/admin/orders/${order.id}');
                },
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View $itemCount products',
                        style: const TextStyle(
                          color: AppColors.logoBlue,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.open_in_new_rounded,
                        size: 16,
                        color: AppColors.logoBlue,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showEditOrderStatusDialog(
    BuildContext context,
    OrderRequest order,
  ) async {
    var selectedStatus = order.status;
    var selectedMethod = order.method;
    var selectedPlace = order.place.trim();
    var selectedStreet = order.addressStreet.trim();
    final serviceableBarangays =
        ref.read(appControllerProvider.notifier).serviceableBarangays;

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AppModalFrame(
              title: 'Edit Order',
              actions: [
                AppModalButton(
                  label: 'Close',
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                ),
                const SizedBox(width: 10),
                AppModalButton(
                  label: 'Save',
                  isPrimary: true,
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                ),
              ],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Status',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF101828),
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<OrderStatus>(
                    isExpanded: true,
                    initialValue: selectedStatus,
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.logoBlue,
                      size: 24,
                    ),
                    decoration: _filterDropdownDecoration('Status'),
                    items: OrderStatus.values
                        .map(
                          (status) => DropdownMenuItem<OrderStatus>(
                            value: status,
                            child: Text(displayStatus(status)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() => selectedStatus = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Method',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF101828),
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<FulfillmentMethod>(
                    isExpanded: true,
                    initialValue: selectedMethod,
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.logoBlue,
                      size: 24,
                    ),
                    decoration: _filterDropdownDecoration('Method'),
                    items: FulfillmentMethod.values
                        .map(
                          (method) => DropdownMenuItem<FulfillmentMethod>(
                            value: method,
                            child: Text(displayFulfillment(method)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        selectedMethod = value;
                        if (selectedMethod != FulfillmentMethod.delivery) {
                          selectedPlace = '';
                          selectedStreet = '';
                        }
                      });
                    },
                  ),
                  if (selectedMethod == FulfillmentMethod.delivery) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Barangay',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF101828),
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: serviceableBarangays.contains(selectedPlace)
                          ? selectedPlace
                          : null,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.logoBlue,
                        size: 24,
                      ),
                      decoration: _filterDropdownDecoration('Barangay'),
                      items: serviceableBarangays
                          .map(
                            (place) => DropdownMenuItem<String>(
                              value: place,
                              child: Text(place),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() => selectedPlace = value);
                      },
                    ),
                    if (selectedPlace.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Street/Landmark',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF101828),
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        initialValue: selectedStreet,
                        decoration: _filterDropdownDecoration(
                          'Street/Landmark',
                        ),
                        onChanged: (value) => selectedStreet = value,
                      ),
                    ],
                  ],
                ],
              ),
            );
          },
        );
      },
    );

    if (shouldSave != true || !mounted) {
      return;
    }

    if (selectedMethod == FulfillmentMethod.delivery &&
        selectedPlace.trim().isEmpty) {
      final messenger = ScaffoldMessenger.of(this.context);
      messenger.clearSnackBars();
      messenger.showSnackBar(errorSnackBar('Barangay is required.'));
      return;
    }
    if (selectedMethod == FulfillmentMethod.delivery &&
        selectedStreet.trim().isEmpty) {
      final messenger = ScaffoldMessenger.of(this.context);
      messenger.clearSnackBars();
      messenger.showSnackBar(errorSnackBar('Street/Landmark is required.'));
      return;
    }

    final now = DateTime.now();
    final current = ref
        .read(appControllerProvider)
        .orders
        .firstWhere((item) => item.id == order.id);

    final updatedOrder = current.copyWith(
      status: selectedStatus,
      method: selectedMethod,
      place: selectedMethod == FulfillmentMethod.delivery ? selectedPlace : '',
      addressStreet: selectedMethod == FulfillmentMethod.delivery
          ? selectedStreet
          : '',
      addressLandmark: '',
      updatedAt: now,
    );

    await ref.read(appControllerProvider.notifier).updateOrder(updatedOrder);
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(this.context);
    messenger.clearSnackBars();
    messenger.showSnackBar(successSnackBar('Order updated.'));
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
        _AdminOrdersPageState._filtersContentHorizontalPadding,
        16,
        _AdminOrdersPageState._filtersContentHorizontalPadding,
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

class _OrderHeaderRow extends StatelessWidget {
  const _OrderHeaderRow({
    required this.widths,
    required this.trailingSpace,
    required this.isEmpty,
  });

  final _OrderColumnWidths widths;
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
          width: widths.phone,
          child: Text('Phone', style: labelStyle, maxLines: 1),
        ),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.status,
          child: Text('Status', style: labelStyle, maxLines: 1),
        ),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.items,
          child: Text('Items', style: labelStyle, maxLines: 1),
        ),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.total,
          child: Text('Total', style: labelStyle, maxLines: 1),
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
        SizedBox(width: widths.gap + trailingSpace),
        SizedBox(
          width: _AdminOrdersPageState._actionsWidth,
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

class _OrderRow extends StatelessWidget {
  const _OrderRow({
    required this.order,
    required this.widths,
    required this.trailingSpace,
    required this.isLast,
    required this.onView,
    required this.onEdit,
    required this.onCopy,
    required this.onOpen,
  });

  final OrderRequest order;
  final _OrderColumnWidths widths;
  final double trailingSpace;
  final bool isLast;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onCopy;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scale = _textScaleForWidth(MediaQuery.of(context).size.width);
    final bodyStyle = DefaultTextStyle.of(context).style.copyWith(
      fontSize: (DefaultTextStyle.of(context).style.fontSize ?? 14) * scale,
      height: 1.15,
    );
    final itemCount = order.items.fold<int>(
      0,
      (sum, item) => sum + item.requestedQuantity,
    );

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
              child: Text('${order.id}', style: bodyStyle),
            ),
            SizedBox(width: widths.gap),
            SizedBox(
              width: widths.name,
              child: Text(
                order.name,
                style: bodyStyle,
                softWrap: true,
              ),
            ),
            SizedBox(width: widths.gap),
            SizedBox(
              width: widths.phone,
              child: PhoneActionText(
                order.phone,
                style: bodyStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: widths.gap),
            SizedBox(
              width: widths.status,
              child: Align(
                alignment: Alignment.centerLeft,
                child: StatusBadge(
                  status: order.status,
                  fontSize: bodyStyle.fontSize ?? 14,
                ),
              ),
            ),
            SizedBox(width: widths.gap),
            SizedBox(
              width: widths.items,
              child: Text(
                '$itemCount',
                style: bodyStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: widths.gap),
            SizedBox(
              width: widths.total,
              child: Text(
                formatPesos(order.total),
                style: bodyStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: widths.gap),
            SizedBox(
              width: widths.createdAt,
              child: Text(
                '${formatOrderDate(order.createdAt)}\n${formatOrderTimeWithSeconds(order.createdAt)}',
                style: bodyStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: widths.gap),
            SizedBox(
              width: widths.updatedAt,
              child: Text(
                '${formatOrderDate(order.updatedAt)}\n${formatOrderTimeWithSeconds(order.updatedAt)}',
                style: bodyStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: widths.gap + trailingSpace),
            SizedBox(
              width: _AdminOrdersPageState._actionsWidth,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  MousePressable(
                    onTap: onView,
                    borderRadius: BorderRadius.circular(10),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.visibility_outlined,
                        size: 18,
                        color: AppColors.logoBlue,
                      ),
                    ),
                  ),
                  MousePressable(
                    onTap: onEdit,
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
                  MousePressable(
                    onTap: onCopy,
                    borderRadius: BorderRadius.circular(10),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.content_copy_outlined,
                        size: 18,
                        color: AppColors.logoBlue,
                      ),
                    ),
                  ),
                  MousePressable(
                    onTap: onOpen,
                    borderRadius: BorderRadius.circular(10),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.open_in_new_rounded,
                        size: 18,
                        color: AppColors.logoBlue,
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

class _OrderColumnWidths {
  const _OrderColumnWidths({
    required this.gap,
    required this.id,
    required this.name,
    required this.phone,
    required this.total,
    required this.status,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  final double gap;
  final double id;
  final double name;
  final double phone;
  final double total;
  final double status;
  final double items;
  final double createdAt;
  final double updatedAt;
}

double _measureOrderTextHeight(
  String text,
  TextStyle style,
  double maxWidth, {
  int? maxLines,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: maxLines,
    ellipsis: maxLines == null ? null : '...',
  )..layout(maxWidth: maxWidth);
  return painter.height;
}

double _measureOrderRowHeight({
  required OrderRequest order,
  required _OrderColumnWidths widths,
  required TextStyle bodyStyle,
}) {
  final createdAtText =
      '${formatOrderDate(order.createdAt)}\n${formatOrderTimeWithSeconds(order.createdAt)}';
  final updatedAtText =
      '${formatOrderDate(order.updatedAt)}\n${formatOrderTimeWithSeconds(order.updatedAt)}';

  final tallestContent = <double>[
    _measureOrderTextHeight('${order.id}', bodyStyle, widths.id, maxLines: 1),
    _measureOrderTextHeight(
      order.name,
      bodyStyle,
      widths.name,
    ),
    _measureOrderTextHeight(
      order.phone,
      bodyStyle,
      widths.phone,
      maxLines: 1,
    ),
    34,
    _measureOrderTextHeight(
      '${order.items.fold<int>(0, (sum, item) => sum + item.requestedQuantity)}',
      bodyStyle,
      widths.items,
      maxLines: 1,
    ),
    _measureOrderTextHeight(
      formatPesos(order.total),
      bodyStyle,
      widths.total,
      maxLines: 1,
    ),
    _measureOrderTextHeight(
      createdAtText,
      bodyStyle,
      widths.createdAt,
      maxLines: 2,
    ),
    _measureOrderTextHeight(
      updatedAtText,
      bodyStyle,
      widths.updatedAt,
      maxLines: 2,
    ),
    34,
  ].reduce(math.max);

  return tallestContent + 32;
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
