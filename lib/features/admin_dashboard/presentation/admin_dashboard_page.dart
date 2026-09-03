import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../app_state/app_controller.dart';
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
  final GlobalKey _mobileFiltersAnchorKey = GlobalKey();
  final GlobalKey _desktopFiltersAnchorKey = GlobalKey();

  DateTime? startDateFilter;
  DateTime? endDateFilter;
  bool _loadingOrders = true;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      await ref.read(appControllerProvider.notifier).refreshFromFirebase();
      if (mounted) {
        setState(() => _loadingOrders = false);
      }
    });
  }

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
      AdminDashboardMetric(
        'Completed',
        vm.metrics.where((metric) => metric.label == 'Completed').first.value,
      ),
      AdminDashboardMetric('Products', vm.activeProducts),
      AdminDashboardMetric('Categories', vm.categories),
    ];
    final metricColumns = width >= 1320
        ? 4
        : width >= 760
        ? 2
        : 2;
    final metricValueFontSize = isMobile ? 24.0 : 32.0;
    final toolbarActionSize = isMobile ? 48.0 : 0.0;
    final salesOrdersLabel =
        '${vm.filteredSalesOrders} ${vm.filteredSalesOrders == 1 ? 'order' : 'orders'}';
    final chartWidth = math.max<double>(
      width - 64,
      math.max<double>(680, (vm.salesPoints.length * 92).toDouble()),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // The scaffold already removes the mobile header and safe areas. Scale
        // the dashboard within that remaining viewport before allowing scroll.
        final availableHeight = constraints.maxHeight;
        final metricMainAxisExtent = isMobile
            ? (availableHeight >= 700 ? 126.0 : 118.0)
            : 154.0;
        final metricSpacing = isMobile ? 12.0 : 20.0;
        final sectionSpacing = isMobile ? 14.0 : 20.0;
        final salesChartHeight = isMobile
            ? (availableHeight - 490).clamp(190.0, 280.0)
            : 280.0;
        final metricCardPadding = isMobile
            ? const EdgeInsets.fromLTRB(16, 16, 16, 16)
            : const EdgeInsets.fromLTRB(28, 22, 28, 22);
        final metricValuePadding = isMobile
            ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10)
            : const EdgeInsets.symmetric(horizontal: 18, vertical: 14);
        final metricLabelGap = isMobile ? 12.0 : 22.0;

        return ListView(
          children: [
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: metricColumns,
                mainAxisSpacing: metricSpacing,
                crossAxisSpacing: metricSpacing,
                mainAxisExtent: metricMainAxisExtent,
              ),
              itemCount: metrics.length,
              itemBuilder: (context, index) {
                final metric = metrics[index];
                const accent = AppColors.logoBlue;
                const tint = Color(0xFFF2F6FF);
                final route = switch (metric.label) {
                  'Orders' => '/admin/orders',
                  'Products' => '/admin/products',
                  'Completed' => '/admin/orders?filters[status]=completed',
                  'Categories' => '/admin/categories',
                  _ => '/admin/dashboard',
                };
                return MousePressable(
                  onTap: () => context.go(route),
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    padding: metricCardPadding,
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
                        SizedBox(height: metricLabelGap),
                        Container(
                          width: double.infinity,
                          alignment: Alignment.center,
                          padding: metricValuePadding,
                          decoration: BoxDecoration(
                            color: tint,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: _loadingOrders
                              ? const SizedBox.square(
                                  dimension: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: accent,
                                  ),
                                )
                              : Text(
                                  NumberFormat.decimalPattern().format(
                                    metric.value,
                                  ),
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .displaySmall
                                      ?.copyWith(
                                        color: accent,
                                        fontWeight: FontWeight.w800,
                                        fontSize: metricValueFontSize,
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
            SizedBox(height: sectionSpacing),
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
                    menuChildren: [
                      _buildFiltersMenu(
                        context: context,
                        anchorKey: _mobileFiltersAnchorKey,
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
                          key: _mobileFiltersAnchorKey,
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
                    menuChildren: [
                      _buildFiltersMenu(
                        context: context,
                        anchorKey: _desktopFiltersAnchorKey,
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
                          key: _desktopFiltersAnchorKey,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.logoBlue,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Filters',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.filter_list_rounded,
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
            SizedBox(height: isMobile ? 10 : 12),
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
                        padding: EdgeInsets.fromLTRB(
                          20,
                          isMobile ? 14 : 16,
                          20,
                          isMobile ? 14 : 16,
                        ),
                        child: isMobile
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        _loadingOrders
                                            ? '...'
                                            : formatPesos(
                                                vm.filteredSalesCentavos,
                                              ),
                                        style: const TextStyle(
                                          color: AppColors.logoBlue,
                                          fontWeight: FontWeight.w800,
                                          height: 1.15,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        _loadingOrders
                                            ? '...'
                                            : salesOrdersLabel,
                                        style: const TextStyle(
                                          color: AppColors.logoBlue,
                                          fontWeight: FontWeight.w600,
                                          height: 1.15,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (startDateFilter != null ||
                                      endDateFilter != null) ...[
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
                                        _loadingOrders
                                            ? '...'
                                            : formatPesos(
                                                vm.filteredSalesCentavos,
                                              ),
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
                                        _loadingOrders
                                            ? '...'
                                            : salesOrdersLabel,
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
                      if (_loadingOrders)
                        SizedBox(
                          height: salesChartHeight + 48,
                          child: const Center(
                            child: SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.logoBlue,
                              ),
                            ),
                          ),
                        )
                      else if (vm.salesPoints.isEmpty)
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
                          padding: EdgeInsets.all(isMobile ? 14 : 20),
                          child: SizedBox(
                            width: chartWidth,
                            child: _SalesChart(
                              points: vm.salesPoints,
                              chartHeight: salesChartHeight,
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

  Widget _buildFiltersMenu({
    required BuildContext context,
    required GlobalKey anchorKey,
  }) {
    final menuContent = SizedBox(
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
        ],
      ),
    );
    final anchorContext = anchorKey.currentContext;
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final anchorBox = anchorContext?.findRenderObject() as RenderBox?;
    if (overlayBox == null ||
        anchorBox == null ||
        !overlayBox.hasSize ||
        !anchorBox.hasSize) {
      return menuContent;
    }
    final anchorTopLeft = anchorBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    final anchorBottom = anchorTopLeft.dy + anchorBox.size.height;
    final maxMenuHeight = math.max(
      0.0,
      overlayBox.size.height - anchorBottom - 28,
    );
    if (maxMenuHeight <= 0) {
      return menuContent;
    }
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: _filtersMenuWidth,
        maxHeight: maxMenuHeight,
      ),
      child: SingleChildScrollView(child: menuContent),
    );
  }

  InputDecoration _filterDropdownDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: AppColors.logoBlue, height: 1.15),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 6, 16),
      filled: true,
      fillColor: AppColors.logoBlueSoft,
      isDense: true,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: AppColors.logoBlue.withValues(alpha: 0.16),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.logoBlue),
      ),
    );
  }
}

class _SalesChart extends StatelessWidget {
  const _SalesChart({required this.points, required this.chartHeight});

  final List<AdminSalesPoint> points;
  final double chartHeight;

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
          height: chartHeight,
          child: CustomPaint(
            size: Size(double.infinity, chartHeight),
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
                        maxLines: 1,
                        softWrap: false,
                        style: labelStyle,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatPesos(point.salesCentavos),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        softWrap: false,
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
                  fontSize: isPlaceholder ? 14 : 15.5,
                  height: 1.15,
                ),
              ),
            ),
            Icon(icon, color: AppColors.logoBlue, size: 18),
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
