import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import 'admin_dashboard_view_model.dart';

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  static const double _filtersMenuWidth = 248;
  static const double _filtersContentHorizontalPadding = 16;
  static double get _filtersFieldWidth =>
      _filtersMenuWidth - (_filtersContentHorizontalPadding * 2);

  DateTime? startDateFilter;
  DateTime? endDateFilter;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyRouteFilters();
  }

  void _applyRouteFilters() {
    final uri = GoRouterState.of(context).uri;
    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);
    final currentMonthEnd = DateTime(now.year, now.month + 1, 0);
    startDateFilter =
        _parseRouteDate(uri.queryParameters['filters[start_date]']) ??
        currentMonthStart;
    endDateFilter =
        _parseRouteDate(uri.queryParameters['filters[end_date]']) ??
        currentMonthEnd;
  }

  void _setFilters(VoidCallback update) {
    setState(update);
    _updateRouteFilters();
  }

  void _updateRouteFilters() {
    final currentUri = GoRouterState.of(context).uri;
    final params = <String, String>{};
    if (startDateFilter != null) {
      params['filters[start_date]'] = _formatRouteDate(startDateFilter!);
    }
    if (endDateFilter != null) {
      params['filters[end_date]'] = _formatRouteDate(endDateFilter!);
    }
    final nextUri = Uri(path: currentUri.path, queryParameters: params);
    if (nextUri.toString() != currentUri.toString()) {
      context.replace(nextUri.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 700;
    final vm = ref.watch(
      adminDashboardViewModelProvider(
        AdminDashboardSalesFilter(
          startDate: startDateFilter,
          endDate: endDateFilter,
        ),
      ),
    );

    final metrics = <AdminDashboardMetric>[
      AdminDashboardMetric('Orders', vm.totalOrders),
      AdminDashboardMetric('Products', vm.activeProducts),
      AdminDashboardMetric('Best Sellers', vm.bestSellers.length),
      AdminDashboardMetric('Categories', vm.categories),
    ];
    final metricColumns = width >= 1320
        ? 4
        : width >= 760
        ? 2
        : 2;
    final activeFilterCount =
        (startDateFilter == null ? 0 : 1) + (endDateFilter == null ? 0 : 1);
    final toolbarActionSize = isMobile ? 48.0 : 0.0;
    final salesOrdersLabel =
        '${vm.filteredSalesOrders} ${vm.filteredSalesOrders == 1 ? 'order' : 'orders'}';
    final chartWidth = math.max<double>(
      width - 64,
      math.max<double>(680, (vm.salesPoints.length * 60).toDouble()),
    );

    return ListView(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: metricColumns,
            mainAxisSpacing: 20,
            crossAxisSpacing: 20,
            mainAxisExtent: 154,
          ),
          itemCount: metrics.length,
          itemBuilder: (context, index) {
            final metric = metrics[index];
            const accent = AppColors.logoBlue;
            const tint = Color(0xFFF2F6FF);
            final route = switch (metric.label) {
              'Orders' => '/admin/orders',
              'Products' => '/admin/products',
              'Best Sellers' =>
                '/admin/products?filters[status]=active&filters[sold]=many_few',
              'Categories' => '/admin/categories',
              _ => '/admin/dashboard',
            };
            return MousePressable(
              onTap: () => context.go(route),
              borderRadius: BorderRadius.circular(22),
              child: Container(
                padding: const EdgeInsets.fromLTRB(28, 22, 28, 22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFEFF2FA)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metric.label,
                      style: const TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: tint,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        NumberFormat.decimalPattern().format(metric.value),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w800,
                              fontSize: 32,
                              height: 1.05,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                'Sales',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.logoBlue,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
            ),
            if (isMobile)
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
                menuChildren: [_buildFiltersMenu(context: context)],
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
              )
            else
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
                menuChildren: [_buildFiltersMenu(context: context)],
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
                                : Icons.keyboard_arrow_down_rounded,
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
        const SizedBox(height: 12),
        SectionCard(
          showShadow: false,
          padding: EdgeInsets.zero,
          borderRadius: 16,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ColoredBox(
              color: Colors.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.logoBlue.withValues(alpha: 0.10),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: isMobile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    formatPesos(vm.filteredSalesCentavos),
                                    style: const TextStyle(
                                      color: AppColors.logoBlue,
                                      fontWeight: FontWeight.w800,
                                      height: 1.15,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    salesOrdersLabel,
                                    style: const TextStyle(
                                      color: AppColors.logoBlue,
                                      fontWeight: FontWeight.w600,
                                      height: 1.15,
                                    ),
                                  ),
                                ],
                              ),
                              if (startDateFilter != null || endDateFilter != null) ...[
                                const SizedBox(height: 10),
                                Center(
                                  child: Text(
                                    '${startDateFilter == null ? 'Any' : formatAsOfDate(startDateFilter!)} - ${endDateFilter == null ? 'Any' : formatAsOfDate(endDateFilter!)}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: AppColors.logoBlue,
                                      fontWeight: FontWeight.w600,
                                      height: 1.15,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    formatPesos(vm.filteredSalesCentavos),
                                    style: const TextStyle(
                                      color: AppColors.logoBlue,
                                      fontWeight: FontWeight.w800,
                                      height: 1.15,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child:
                                    (startDateFilter != null ||
                                            endDateFilter != null)
                                        ? Text(
                                            '${startDateFilter == null ? 'Any' : formatAsOfDate(startDateFilter!)} - ${endDateFilter == null ? 'Any' : formatAsOfDate(endDateFilter!)}',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: AppColors.logoBlue,
                                              fontWeight: FontWeight.w600,
                                              height: 1.15,
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                              ),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    salesOrdersLabel,
                                    style: const TextStyle(
                                      color: AppColors.logoBlue,
                                      fontWeight: FontWeight.w600,
                                      height: 1.15,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                  const Divider(
                    height: 0,
                    thickness: 0.6,
                    color: Color(0xFFE4E7EC),
                  ),
                  if (vm.salesPoints.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: EmptyStateCard(
                        title: 'No sales found',
                        message:
                            'Adjust the date filters or wait for processed orders.',
                        showBorder: false,
                      ),
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.all(20),
                      child: SizedBox(
                        width: chartWidth,
                        child: _SalesChart(points: vm.salesPoints),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFiltersMenu({required BuildContext context}) {
    return SizedBox(
      width: _filtersMenuWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FiltersSection(
            title: 'Start Date',
            child: SizedBox(
              width: _filtersFieldWidth,
              child: _DateField(
                label: startDateFilter == null
                    ? 'Any'
                    : formatAsOfDate(startDateFilter!),
                decoration: _filterDropdownDecoration('Start date'),
                icon: Icons.calendar_month_rounded,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime(2026, 1, 1),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    initialDate: startDateFilter ?? DateTime.now(),
                  );
                  if (picked != null && mounted) {
                    _setFilters(() {
                      startDateFilter = picked;
                      if (endDateFilter != null &&
                          endDateFilter!.isBefore(picked)) {
                        endDateFilter = picked;
                      }
                    });
                  }
                },
              ),
            ),
          ),
          const _FilterDivider(),
          _FiltersSection(
            title: 'End Date',
            child: SizedBox(
              width: _filtersFieldWidth,
              child: _DateField(
                label: endDateFilter == null
                    ? 'Any'
                    : formatAsOfDate(endDateFilter!),
                decoration: _filterDropdownDecoration('End date'),
                icon: Icons.calendar_month_rounded,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: startDateFilter ?? DateTime(2026, 1, 1),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    initialDate:
                        endDateFilter ?? startDateFilter ?? DateTime.now(),
                  );
                  if (picked != null && mounted) {
                    _setFilters(() => endDateFilter = picked);
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
                      startDateFilter = null;
                      endDateFilter = null;
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
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
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
}

class _SalesChart extends StatelessWidget {
  const _SalesChart({required this.points});

  final List<AdminSalesPoint> points;

  @override
  Widget build(BuildContext context) {
    final maxSales = points.fold<int>(
      0,
      (max, point) => point.salesCentavos > max ? point.salesCentavos : max,
    );
    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: const Color(0xFF667085),
      height: 1.15,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 280,
          child: CustomPaint(
            size: const Size(double.infinity, 280),
            painter: _SalesChartPainter(points: points, maxSales: maxSales),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final point in points)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    children: [
                      Text(
                        DateFormat('MMM d').format(point.date),
                        textAlign: TextAlign.center,
                        style: labelStyle,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatPesos(point.salesCentavos),
                        textAlign: TextAlign.center,
                        style: labelStyle?.copyWith(
                          color: AppColors.logoBlue,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _SalesChartPainter extends CustomPainter {
  const _SalesChartPainter({required this.points, required this.maxSales});

  final List<AdminSalesPoint> points;
  final int maxSales;

  @override
  void paint(Canvas canvas, Size size) {
    const leftPadding = 16.0;
    const rightPadding = 16.0;
    const topPadding = 12.0;
    const bottomPadding = 28.0;
    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;
    if (chartWidth <= 0 || chartHeight <= 0 || points.isEmpty) {
      return;
    }

    final gridPaint = Paint()
      ..color = const Color(0xFFE4E7EC)
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = AppColors.logoBlue
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fillPaint = Paint()
      ..color = AppColors.logoBlue.withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;
    final pointPaint = Paint()
      ..color = AppColors.logoBlue
      ..style = PaintingStyle.fill;
    final salesCap = maxSales <= 0 ? 1 : maxSales;

    for (var i = 0; i < 4; i++) {
      final y = topPadding + ((chartHeight / 3) * i);
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );
    }

    final path = Path();
    final fillPath = Path();
    for (var i = 0; i < points.length; i++) {
      final x =
          leftPadding +
          (points.length == 1
              ? chartWidth / 2
              : (chartWidth / (points.length - 1)) * i);
      final ratio = points[i].salesCentavos / salesCap;
      final y = topPadding + chartHeight - (chartHeight * ratio);
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, topPadding + chartHeight);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 4.5, pointPaint);
    }
    final lastX =
        leftPadding +
        (points.length == 1
            ? chartWidth / 2
            : (chartWidth / (points.length - 1)) * (points.length - 1));
    fillPath.lineTo(lastX, topPadding + chartHeight);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _SalesChartPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.maxSales != maxSales;
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
        _AdminDashboardPageState._filtersContentHorizontalPadding,
        16,
        _AdminDashboardPageState._filtersContentHorizontalPadding,
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

DateTime? _parseRouteDate(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  try {
    return DateTime.parse(value);
  } catch (_) {
    return null;
  }
}

String _formatRouteDate(DateTime value) {
  return DateTime(value.year, value.month, value.day).toIso8601String();
}
