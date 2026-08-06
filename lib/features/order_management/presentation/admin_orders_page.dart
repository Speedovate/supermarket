import 'dart:math' as math;

import 'package:flutter/material.dart';
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
  static const double _columnWidthAllowance = 2;
  static const double _dateHeaderExtraAllowance = 2;
  static const double _actionsWidth = 72;
  static double get _filtersFieldWidth =>
      _filtersMenuWidth - (_filtersContentHorizontalPadding * 2);

  String query = '';
  DateTime? createdAtFilter;
  DateTime? updatedAtFilter;
  OrderStatus? statusFilter;
  FulfillmentMethod? methodFilter;

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
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final normalized = query.trim().toLowerCase();
    final filteredOrders = orders.where((order) {
      final matchesQuery =
          normalized.isEmpty ||
          order.referenceNumber.toLowerCase().contains(normalized) ||
          order.customer.name.toLowerCase().contains(normalized) ||
          order.customer.mobileNumber.toLowerCase().contains(normalized) ||
          order.customer.barangay.toLowerCase().contains(normalized) ||
          '${order.id}'.contains(normalized);
      final matchesCreatedAt =
          createdAtFilter == null ||
          _isSameDay(order.createdAt, createdAtFilter!);
      final matchesUpdatedAt =
          updatedAtFilter == null ||
          _isSameDay(order.updatedAt, updatedAtFilter!);
      final matchesStatus =
          statusFilter == null || order.status == statusFilter;
      final matchesMethod =
          methodFilter == null || order.fulfillmentMethod == methodFilter;
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

    return ListView(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                onChanged: (value) => setState(() => query = value),
                decoration: const InputDecoration(
                  hintText: 'Search',
                  hintStyle: TextStyle(color: AppColors.logoBlue, height: 1.15),
                  prefixIcon: Icon(Icons.search, color: AppColors.logoBlue),
                ),
              ),
            ),
            const SizedBox(width: 8),
            MenuAnchor(
              style: const MenuStyle(
                backgroundColor: WidgetStatePropertyAll(Colors.white),
                surfaceTintColor: WidgetStatePropertyAll(Colors.white),
                padding: WidgetStatePropertyAll(EdgeInsets.zero),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                ),
              ),
              menuChildren: [
                SizedBox(
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
                              final picked = await showDatePicker(
                                context: context,
                                firstDate: orders.isEmpty
                                    ? DateTime(2026, 1, 1)
                                    : orders
                                          .map((item) => item.createdAt)
                                          .reduce(
                                            (a, b) => a.isBefore(b) ? a : b,
                                          ),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                                initialDate:
                                    createdAtFilter ??
                                    (orders.isEmpty
                                        ? DateTime.now()
                                        : orders.first.createdAt),
                              );
                              if (picked != null) {
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
                              final picked = await showDatePicker(
                                context: context,
                                firstDate: orders.isEmpty
                                    ? DateTime(2026, 1, 1)
                                    : orders
                                          .map((item) => item.updatedAt)
                                          .reduce(
                                            (a, b) => a.isBefore(b) ? a : b,
                                          ),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                                initialDate:
                                    updatedAtFilter ??
                                    (orders.isEmpty
                                        ? DateTime.now()
                                        : orders.first.updatedAt),
                              );
                              if (picked != null) {
                                setState(() => updatedAtFilter = picked);
                              }
                            },
                          ),
                        ),
                      ),
                      const _FilterDivider(),
                      _FiltersSection(
                        title: 'Order status',
                        child: SizedBox(
                          width: _filtersFieldWidth,
                          child: DropdownButtonFormField<OrderStatus?>(
                            initialValue: statusFilter,
                            decoration: _filterDropdownDecoration(
                              'Order status',
                            ),
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
                              setState(() => statusFilter = value);
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
                            initialValue: methodFilter,
                            decoration: _filterDropdownDecoration('Method'),
                            items: [
                              const DropdownMenuItem<FulfillmentMethod?>(
                                value: null,
                                child: Text('Any'),
                              ),
                              ...FulfillmentMethod.values.map(
                                (method) =>
                                    DropdownMenuItem<FulfillmentMethod?>(
                                      value: method,
                                      child: Text(displayFulfillment(method)),
                                    ),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() => methodFilter = value);
                            },
                          ),
                        ),
                      ),
                      const _FilterDivider(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          _filtersContentHorizontalPadding,
                          16,
                          _filtersContentHorizontalPadding,
                          16,
                        ),
                        child: MousePressable(
                          onTap: () {
                            setState(() {
                              createdAtFilter = null;
                              updatedAtFilter = null;
                              statusFilter = null;
                              methodFilter = null;
                            });
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            height: 52,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE4E7EC),
                              ),
                            ),
                            child: const Text(
                              'Clear',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF172033),
                                height: 1.15,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              builder: (context, controller, child) {
                return _ToolbarButton(
                  label: isMobile ? null : 'Filters',
                  icon: Icons.filter_alt_outlined,
                  foregroundColor: Colors.white,
                  backgroundColor: AppColors.logoBlue,
                  counter: activeFilterCount == 0 ? null : '$activeFilterCount',
                  size: isMobile ? 48 : null,
                  onTap: () {
                    controller.isOpen ? controller.close() : controller.open();
                  },
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth =
                widths.id +
                gap +
                widths.reference +
                gap +
                widths.customer +
                gap +
                widths.method +
                gap +
                widths.status +
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
                            child: _OrderHeaderRow(
                              widths: widths,
                              trailingSpace: trailingSpace,
                              isEmpty: filteredOrders.isEmpty,
                            ),
                          ),
                          const Divider(height: 0, thickness: 0.6),
                          if (filteredOrders.isEmpty)
                            ClipRRect(
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(16),
                                bottomRight: Radius.circular(16),
                              ),
                              child: const EmptyStateCard(
                                title: 'No orders found',
                                message: 'Customer submissions will appear here.',
                                showBorder: false,
                              ),
                            )
                          else
                            Column(
                              children: [
                                for (
                                  var i = 0;
                                  i < filteredOrders.length;
                                  i++
                                ) ...[
                                  _OrderRow(
                                  order: filteredOrders[i],
                                  widths: widths,
                                  trailingSpace: trailingSpace,
                                  isLast: i == filteredOrders.length - 1,
                                ),
                                  if (i != filteredOrders.length - 1)
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
      reference: maxWidth(
        'Reference',
        orders.map((item) => item.referenceNumber),
      ),
      customer: cappedMaxWidth(
        'Customer',
        orders.map((item) => item.customer.name),
        max: screenWidth < 700 ? 132 : 168,
      ),
      method: maxWidth(
        'Method',
        orders.map((item) => displayFulfillment(item.fulfillmentMethod)),
      ),
      status: maxWidth(
        'Status',
        orders.map((item) => displayStatus(item.status)),
        valuesStyle: badgeTextStyle,
      ) + 24,
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
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.onTap,
    this.label,
    this.counter,
    this.size,
  });

  final IconData icon;
  final String? label;
  final String? counter;
  final Color foregroundColor;
  final Color backgroundColor;
  final VoidCallback onTap;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final square = size != null;
    return MousePressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      hoverOverlayAlpha: AppColors.brandingBlueHoverOverlayAlpha,
      pressedOverlayAlpha: AppColors.brandingBluePressedOverlayAlpha,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: size ?? 48,
            width: size,
            padding: EdgeInsets.symmetric(horizontal: square ? 0 : 18),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: square ? MainAxisSize.min : MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: foregroundColor, size: 20),
                if (label != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    label!,
                    style: TextStyle(
                      color: foregroundColor,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (counter != null)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE31E24),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  counter!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
              ),
            ),
        ],
      ),
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
          width: widths.reference,
          child: Text('Reference', style: labelStyle, maxLines: 1),
        ),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.customer,
          child: Text('Customer', style: labelStyle, maxLines: 1),
        ),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.method,
          child: Text('Method', style: labelStyle, maxLines: 1),
        ),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.status,
          child: Text('Status', style: labelStyle, maxLines: 1),
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
  });

  final OrderRequest order;
  final _OrderColumnWidths widths;
  final double trailingSpace;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final scale = _textScaleForWidth(MediaQuery.of(context).size.width);
    final bodyStyle = DefaultTextStyle.of(context).style.copyWith(
      fontSize: (DefaultTextStyle.of(context).style.fontSize ?? 14) * scale,
      height: 1.15,
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
              width: widths.reference,
              child: Text(
                order.referenceNumber,
                style: bodyStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: widths.gap),
            SizedBox(
              width: widths.customer,
              child: Text(
                order.customer.name,
                style: bodyStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: widths.gap),
            SizedBox(
              width: widths.method,
              child: Text(
                displayFulfillment(order.fulfillmentMethod),
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
              child: Align(
                alignment: Alignment.centerRight,
                child: MousePressable(
                  onTap: () => context.push('/admin/orders/${order.id}'),
                  borderRadius: BorderRadius.circular(10),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.open_in_new_rounded, size: 18),
                  ),
                ),
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
    required this.reference,
    required this.customer,
    required this.method,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final double gap;
  final double id;
  final double reference;
  final double customer;
  final double method;
  final double status;
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
