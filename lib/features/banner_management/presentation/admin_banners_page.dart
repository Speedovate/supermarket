import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/app_models.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../app_state/app_controller.dart';

class AdminBannersPage extends ConsumerStatefulWidget {
  const AdminBannersPage({super.key});

  @override
  ConsumerState<AdminBannersPage> createState() => _AdminBannersPageState();
}

class _AdminBannersPageState extends ConsumerState<AdminBannersPage> {
  static const double _filtersMenuWidth = 248;
  static const double _filtersContentHorizontalPadding = 16;
  static const double _columnWidthAllowance = 2;
  static const double _dateHeaderExtraAllowance = 2;
  static const double _statusBadgeHorizontalPadding = 28;
  static const double _actionHitSize = 34;
  static double get _actionsWidth => _actionHitSize * 3;
  static double get _filtersFieldWidth =>
      _filtersMenuWidth - (_filtersContentHorizontalPadding * 2);

  final TextEditingController _queryController = TextEditingController();
  final GlobalKey _mobileFiltersAnchorKey = GlobalKey();
  final GlobalKey _desktopFiltersAnchorKey = GlobalKey();
  String query = '';
  DateTime? createdAtFilter;
  DateTime? updatedAtFilter;
  String? statusFilter;

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
    statusFilter = _normalizeNullable(uri.queryParameters['filters[status]']);
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
      params['filters[status]'] = statusFilter!;
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
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
    final banners = [...state.banners]..sort((a, b) => b.id.compareTo(a.id));
    final filteredBanners = banners.where((banner) {
      final matchesQuery =
          normalizedQuery.isEmpty ||
          banner.imageUrl.toLowerCase().contains(normalizedQuery) ||
          (banner.externalUrl ?? '').toLowerCase().contains(normalizedQuery) ||
          '${banner.id}'.contains(normalizedQuery);
      final matchesCreatedAt =
          createdAtFilter == null || _isSameDay(banner.createdAt, createdAtFilter!);
      final matchesUpdatedAt =
          updatedAtFilter == null || _isSameDay(banner.updatedAt, updatedAtFilter!);
      final matchesStatus = switch (statusFilter) {
        'active' => banner.isActive,
        'inactive' => !banner.isActive,
        _ => true,
      };
      return matchesQuery &&
          matchesCreatedAt &&
          matchesUpdatedAt &&
          matchesStatus;
    }).toList();

    final widths = _computeBannerColumnWidths(
      screenWidth: screenWidth,
      banners: banners,
      headerStyle: headerStyle,
      bodyStyle: bodyStyle,
    );
    final activeFilterCount =
        (createdAtFilter == null ? 0 : 1) +
        (updatedAtFilter == null ? 0 : 1) +
        (statusFilter == null ? 0 : 1);
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
                            decoration: InputDecoration(
                              hintText: 'Search',
                              hintStyle: const TextStyle(
                                color: AppColors.logoBlue,
                                height: 1.15,
                              ),
                              prefixIcon: const Icon(
                                Icons.search,
                                color: AppColors.logoBlue,
                              ),
                              suffixIcon: query.trim().isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Clear search',
                                      onPressed: () {
                                        _queryController.clear();
                                        _setFilters(() => query = '');
                                      },
                                      icon: const Icon(Icons.close),
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
                              anchorKey: _mobileFiltersAnchorKey,
                              banners: banners,
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
                            decoration: InputDecoration(
                              hintText: 'Search',
                              hintStyle: const TextStyle(
                                color: AppColors.logoBlue,
                                height: 1.15,
                              ),
                              prefixIcon: const Icon(
                                Icons.search,
                                color: AppColors.logoBlue,
                              ),
                              suffixIcon: query.trim().isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Clear search',
                                      onPressed: () {
                                        _queryController.clear();
                                        _setFilters(() => query = '');
                                      },
                                      icon: const Icon(Icons.close),
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
                              anchorKey: _desktopFiltersAnchorKey,
                              banners: banners,
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
            ),
            SizedBox(width: isMobile ? 8 : 12),
            MousePressable(
              onTap: () => _showBannerDialog(context, ref),
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
                        'New Banner',
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
        Flexible(
          fit: FlexFit.loose,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final contentWidth =
                  widths.id +
                  gap +
                  widths.status +
                  gap +
                  widths.imageUrl +
                  gap +
                  widths.externalUrl +
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
              final rowHeights = filteredBanners
                  .map(
                    (banner) => _measureBannerRowHeight(
                      banner: banner,
                      widths: widths,
                      bodyStyle: bodyStyle,
                    ),
                  )
                  .toList();
              final contentHeightEstimate = filteredBanners.isEmpty
                  ? emptyStateHeight
                  : rowHeights.fold<double>(0, (sum, height) => sum + height) +
                      math.max(0, filteredBanners.length - 1) * dividerHeight;
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
                              child: _BannerHeaderRow(
                                widths: widths,
                                trailingSpace: trailingSpace,
                              ),
                            ),
                            const Divider(
                              height: 0,
                              thickness: 0.6,
                              color: Color(0xFFE4E7EC),
                            ),
                            if (filteredBanners.isEmpty)
                              if (shouldScrollBody)
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(16),
                                      bottomRight: Radius.circular(16),
                                    ),
                                    child: const EmptyStateCard(
                                      title: 'No banners found',
                                      message:
                                          'Adjust filters or add a new banner.',
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
                                    title: 'No banners found',
                                    message:
                                        'Adjust filters or add a new banner.',
                                    showBorder: false,
                                  ),
                                )
                            else
                              shouldScrollBody
                                  ? Expanded(
                                      child: ListView.separated(
                                        padding: EdgeInsets.zero,
                                        itemCount: filteredBanners.length,
                                        itemBuilder: (context, i) => _BannerRow(
                                          banner: filteredBanners[i],
                                          widths: widths,
                                          trailingSpace: trailingSpace,
                                          isLast:
                                              i == filteredBanners.length - 1,
                                          onEdit: () => _showBannerDialog(
                                            context,
                                            ref,
                                            initial: filteredBanners[i],
                                          ),
                                          onToggleActive: () async {
                                            final banner = filteredBanners[i];
                                            final nextIsActive = !banner.isActive;
                                            final shouldToggle =
                                                await _showToggleBannerStatusDialog(
                                                  context,
                                                  banner.id,
                                                  nextIsActive,
                                                );
                                            if (shouldToggle == true) {
                                              await ref
                                                  .read(
                                                    appControllerProvider.notifier,
                                                  )
                                                  .saveBanner(
                                                    banner.copyWith(
                                                      isActive: nextIsActive,
                                                      updatedAt: DateTime.now(),
                                                    ),
                                                  );
                                            }
                                          },
                                          onDelete: () => _deleteBanner(
                                            context,
                                            filteredBanners[i],
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
                                        for (var i = 0;
                                            i < filteredBanners.length;
                                            i++) ...[
                                          _BannerRow(
                                            banner: filteredBanners[i],
                                            widths: widths,
                                            trailingSpace: trailingSpace,
                                            isLast:
                                                i == filteredBanners.length - 1,
                                            onEdit: () => _showBannerDialog(
                                              context,
                                              ref,
                                              initial: filteredBanners[i],
                                            ),
                                            onToggleActive: () async {
                                              final banner = filteredBanners[i];
                                              final nextIsActive =
                                                  !banner.isActive;
                                              final shouldToggle =
                                                  await _showToggleBannerStatusDialog(
                                                    context,
                                                    banner.id,
                                                    nextIsActive,
                                                  );
                                              if (shouldToggle == true) {
                                                await ref
                                                    .read(
                                                      appControllerProvider
                                                          .notifier,
                                                    )
                                                    .saveBanner(
                                                      banner.copyWith(
                                                        isActive: nextIsActive,
                                                        updatedAt:
                                                            DateTime.now(),
                                                      ),
                                                    );
                                              }
                                            },
                                            onDelete: () => _deleteBanner(
                                              context,
                                              filteredBanners[i],
                                            ),
                                          ),
                                          if (i != filteredBanners.length - 1)
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

  Widget _buildFiltersMenu({
    required BuildContext context,
    required GlobalKey anchorKey,
    required List<AppBanner> banners,
  }) {
    final menuContent = SizedBox(
      width: _filtersMenuWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FiltersSection(
            title: 'Status',
            child: SizedBox(
              width: _filtersFieldWidth,
              child: AppPopupMenuField<String>(
                value: statusFilter,
                decoration: _filterDropdownDecoration('Status'),
                options: const [
                  AppPopupMenuOption<String?>(value: null, label: 'Any'),
                  AppPopupMenuOption<String?>(value: 'active', label: 'Active'),
                  AppPopupMenuOption<String?>(
                    value: 'inactive',
                    label: 'Inactive',
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
                  final dates = banners.map((item) => item.createdAt).toList();
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
                  final dates = banners.map((item) => item.updatedAt).toList();
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
    return SizedBox(
      width: _filtersMenuWidth,
      height: maxMenuHeight,
      child: SingleChildScrollView(child: menuContent),
    );
  }

  String? _normalizeNullable(String? value) =>
      value == null || value.isEmpty ? null : value;

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

  _BannerColumnWidths _computeBannerColumnWidths({
    required double screenWidth,
    required List<AppBanner> banners,
    required TextStyle headerStyle,
    required TextStyle bodyStyle,
  }) {
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
    }) {
      final width = maxWidth(header, values);
      return width > max ? max : width;
    }

    return _BannerColumnWidths(
      gap: _columnGapForWidth(screenWidth),
      id: maxWidth('ID', banners.map((item) => '${item.id}')),
      status: maxWidth(
        'Status',
        banners.map((item) => item.isActive ? 'Active' : 'Inactive'),
      ) + _statusBadgeHorizontalPadding,
      imageUrl: cappedMaxWidth(
        'Image URL',
        banners.map((item) => item.imageUrl),
        max: screenWidth < 700 ? 220 : 300,
      ),
      externalUrl: cappedMaxWidth(
        'External URL',
        banners.map((item) => item.externalUrl ?? ''),
        max: screenWidth < 700 ? 220 : 300,
      ),
      createdAt: maxWidth(
        'Created at',
        banners.map(
          (item) =>
              '${formatOrderDate(item.createdAt)}\n${formatOrderTimeWithSeconds(item.createdAt)}',
        ),
      ) + _dateHeaderExtraAllowance,
      updatedAt: maxWidth(
        'Updated at',
        banners.map(
          (item) =>
              '${formatOrderDate(item.updatedAt)}\n${formatOrderTimeWithSeconds(item.updatedAt)}',
        ),
      ) + _dateHeaderExtraAllowance,
    );
  }

  double _measureTextHeight(
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

  double _measureBannerRowHeight({
    required AppBanner banner,
    required _BannerColumnWidths widths,
    required TextStyle bodyStyle,
  }) {
    final createdAtText =
        '${formatOrderDate(banner.createdAt)}\n${formatOrderTimeWithSeconds(banner.createdAt)}';
    final updatedAtText =
        '${formatOrderDate(banner.updatedAt)}\n${formatOrderTimeWithSeconds(banner.updatedAt)}';

    final tallestContent = <double>[
      _measureTextHeight('${banner.id}', bodyStyle, widths.id, maxLines: 1),
      _measureTextHeight(
        banner.isActive ? 'Active' : 'Inactive',
        bodyStyle,
        widths.status,
        maxLines: 1,
      ),
      _measureTextHeight(banner.imageUrl, bodyStyle, widths.imageUrl, maxLines: 2),
      _measureTextHeight(
        (banner.externalUrl ?? '').isEmpty ? '-' : banner.externalUrl!,
        bodyStyle,
        widths.externalUrl,
        maxLines: 2,
      ),
      _measureTextHeight(createdAtText, bodyStyle, widths.createdAt, maxLines: 2),
      _measureTextHeight(updatedAtText, bodyStyle, widths.updatedAt, maxLines: 2),
      34,
    ].reduce(math.max);

    return tallestContent + 32;
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

  Future<void> _deleteBanner(BuildContext context, AppBanner banner) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AppModalFrame(
          title: 'Remove Banner?',
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
          child: AppModalBodyText('Banner #${banner.id} will be deleted.'),
        );
      },
    );
    if (shouldDelete != true || !mounted) {
      return;
    }
    await ref.read(appControllerProvider.notifier).deleteBanner(banner.id);
  }

  Future<bool?> _showToggleBannerStatusDialog(
    BuildContext context,
    int bannerId,
    bool nextIsActive,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AppModalFrame(
          title: nextIsActive ? 'Activate Banner?' : 'Deactivate Banner?',
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
                ? 'Banner #$bannerId will be activated.'
                : 'Banner #$bannerId will be deactivated.',
          ),
        );
      },
    );
  }

  Future<void> _showBannerDialog(
    BuildContext context,
    WidgetRef ref, {
    AppBanner? initial,
  }) async {
    final nextId =
        initial?.id ??
        ((ref
                    .read(appControllerProvider)
                    .banners
                    .map((item) => item.id)
                    .fold<int>(0, (max, value) => value > max ? value : max)) +
                1);
    final banner = await showAdminBannerDialog(
      context,
      initial: initial,
      nextId: nextId,
    );
    if (banner == null) {
      return;
    }
    await ref.read(appControllerProvider.notifier).saveBanner(banner);
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
        _AdminBannersPageState._filtersContentHorizontalPadding,
        16,
        _AdminBannersPageState._filtersContentHorizontalPadding,
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

class _BannerHeaderRow extends StatelessWidget {
  const _BannerHeaderRow({
    required this.widths,
    required this.trailingSpace,
  });

  final _BannerColumnWidths widths;
  final double trailingSpace;

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
        SizedBox(width: widths.id, child: Text('ID', style: labelStyle)),
        SizedBox(width: widths.gap),
        SizedBox(width: widths.status, child: Text('Status', style: labelStyle)),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.imageUrl,
          child: Text('Image URL', style: labelStyle, maxLines: 1),
        ),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.externalUrl,
          child: Text('External URL', style: labelStyle, maxLines: 1),
        ),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.createdAt,
          child: Text('Created at', style: labelStyle),
        ),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.updatedAt,
          child: Text('Updated at', style: labelStyle),
        ),
        SizedBox(width: widths.gap),
        if (trailingSpace > 0) SizedBox(width: trailingSpace),
        SizedBox(
          width: _AdminBannersPageState._actionsWidth,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text('Actions', style: labelStyle, textAlign: TextAlign.right),
          ),
        ),
      ],
    );
  }
}

class _BannerRow extends StatelessWidget {
  const _BannerRow({
    required this.banner,
    required this.widths,
    required this.trailingSpace,
    required this.isLast,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  final AppBanner banner;
  final _BannerColumnWidths widths;
  final double trailingSpace;
  final bool isLast;
  final VoidCallback onEdit;
  final Future<void> Function() onToggleActive;
  final Future<void> Function() onDelete;

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
            SizedBox(width: widths.id, child: Text('${banner.id}', style: bodyStyle)),
            SizedBox(width: widths.gap),
            SizedBox(
              width: widths.status,
              child: Align(
                alignment: Alignment.centerLeft,
                child: AdminStateBadge(
                  label: banner.isActive ? 'Active' : 'Inactive',
                  color: banner.isActive
                      ? AppColors.statusActiveGreen
                      : const Color(0xFFE53935),
                  fontSize: bodyStyle.fontSize ?? 14,
                ),
              ),
            ),
            SizedBox(width: widths.gap),
            SizedBox(
              width: widths.imageUrl,
              child: Text(
                banner.imageUrl,
                style: bodyStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: widths.gap),
            SizedBox(
              width: widths.externalUrl,
              child: Text(
                (banner.externalUrl ?? '').isEmpty ? '-' : banner.externalUrl!,
                style: bodyStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: widths.gap),
            SizedBox(
              width: widths.createdAt,
              child: Text(
                '${formatOrderDate(banner.createdAt)}\n${formatOrderTimeWithSeconds(banner.createdAt)}',
                style: bodyStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: widths.gap),
            SizedBox(
              width: widths.updatedAt,
              child: Text(
                '${formatOrderDate(banner.updatedAt)}\n${formatOrderTimeWithSeconds(banner.updatedAt)}',
                style: bodyStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: widths.gap),
            if (trailingSpace > 0) SizedBox(width: trailingSpace),
            SizedBox(
              width: _AdminBannersPageState._actionsWidth,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
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
                    onTap: onToggleActive,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        banner.isActive
                            ? Icons.close_rounded
                            : Icons.check_rounded,
                        size: 18,
                        color: AppColors.logoBlue,
                      ),
                    ),
                  ),
                  MousePressable(
                    onTap: onDelete,
                    borderRadius: BorderRadius.circular(10),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.delete_outline,
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

class _BannerColumnWidths {
  const _BannerColumnWidths({
    required this.gap,
    required this.id,
    required this.status,
    required this.imageUrl,
    required this.externalUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  final double gap;
  final double id;
  final double status;
  final double imageUrl;
  final double externalUrl;
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

Future<AppBanner?> showAdminBannerDialog(
  BuildContext context,
  {
  AppBanner? initial,
  required int nextId,
}) async {
  return showDialog<AppBanner>(
    context: context,
    builder: (dialogContext) {
      return _AdminBannerDialog(initial: initial, nextId: nextId);
    },
  );
}

class _AdminBannerDialog extends StatefulWidget {
  const _AdminBannerDialog({required this.initial, required this.nextId});

  final AppBanner? initial;
  final int nextId;

  @override
  State<_AdminBannerDialog> createState() => _AdminBannerDialogState();
}

class _AdminBannerDialogState extends State<_AdminBannerDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _imageUrlController;
  late final TextEditingController _externalUrlController;
  late bool _isActive;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _imageUrlController = TextEditingController(
      text: widget.initial?.imageUrl ?? '',
    );
    _externalUrlController = TextEditingController(
      text: widget.initial?.externalUrl ?? '',
    );
    _isActive = widget.initial?.isActive ?? true;
  }

  @override
  void dispose() {
    _imageUrlController.dispose();
    _externalUrlController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_isSubmitting) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    _isSubmitting = true;
    final banner = AppBanner(
      id: widget.initial?.id ?? widget.nextId,
      active: _isActive,
      createdAt: widget.initial?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      imageUrl: _imageUrlController.text.trim(),
      externalUrl: _externalUrlController.text.trim().isEmpty
          ? null
          : _externalUrlController.text.trim(),
    );
    Navigator.of(context).pop(banner);
  }

  @override
  Widget build(BuildContext context) {
    return AppModalFrame(
      title: widget.initial == null ? 'New Banner' : 'Edit Banner',
      onSubmit: _submit,
      actions: [
        AppModalButton(
          label: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 10),
        AppModalButton(label: 'Save', isPrimary: true, onPressed: _submit),
      ],
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 6),
              TextFormField(
                controller: _imageUrlController,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => _submit(),
                decoration: const InputDecoration(labelText: 'Image URL'),
                validator: (value) {
                  if ((value?.trim() ?? '').isEmpty) {
                    return 'Image URL is required.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _externalUrlController,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: const InputDecoration(labelText: 'External URL'),
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
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
