import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/app_models.dart';
import '../../../core/services/firebase_firestore_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../app_state/app_controller.dart';

class AdminBarangaysPage extends ConsumerStatefulWidget {
  const AdminBarangaysPage({super.key});

  @override
  ConsumerState<AdminBarangaysPage> createState() => _AdminBarangaysPageState();
}

class _AdminBarangaysPageState extends ConsumerState<AdminBarangaysPage> {
  static const double _filtersMenuWidth = 248;
  static const double _filtersContentHorizontalPadding = 16;
  static double get _filtersFieldWidth =>
      _filtersMenuWidth - (_filtersContentHorizontalPadding * 2);
  static const double _columnWidthAllowance = 2;
  static const double _headerLabelExtraAllowance = 12;
  static const double _dateHeaderExtraAllowance = 2;
  static const double _statusBadgeHorizontalPadding = 28;
  static const double _actionHitSize = 34;
  static double get _actionsWidth => _actionHitSize * 4;

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
    final textScale = _textScaleForWidth(screenWidth);
    final gap = 20.0;
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

    final barangays = [...state.barangays]..sort((a, b) => b.id.compareTo(a.id));
    final normalizedQuery = query.trim().toLowerCase();
    final filteredBarangays = barangays.where((barangay) {
      final matchesQuery =
          normalizedQuery.isEmpty ||
          barangay.name.toLowerCase().contains(normalizedQuery) ||
          '${barangay.id}'.contains(normalizedQuery);
      final matchesCreatedAt =
          createdAtFilter == null || _isSameDay(barangay.createdAt, createdAtFilter!);
      final matchesUpdatedAt =
          updatedAtFilter == null || _isSameDay(barangay.updatedAt, updatedAtFilter!);
      final matchesStatus = switch (statusFilter) {
        'active' => barangay.isActive,
        'inactive' => !barangay.isActive,
        _ => true,
      };
      return matchesQuery &&
          matchesCreatedAt &&
          matchesUpdatedAt &&
          matchesStatus;
    }).toList();

    final widths = _computeBarangayColumnWidths(
      screenWidth: screenWidth,
      barangays: barangays,
      headerStyle: headerStyle,
      bodyStyle: bodyStyle,
      gap: gap,
    );
    final activeFilterCount =
        (createdAtFilter == null ? 0 : 1) +
        (updatedAtFilter == null ? 0 : 1) +
        (statusFilter == null ? 0 : 1);
    final toolbarActionSize = isMobile ? 48.0 : 0.0;

    return Column(
      children: [
        Row(
          crossAxisAlignment: isMobile
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
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
              onTap: () => _showBarangayDialog(context),
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
                        'New Barangay',
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
                        widths.name +
                        gap +
                        widths.status +
                        gap +
                        widths.cutoff +
                        gap +
                        widths.createdAt +
                        gap +
                        widths.updatedAt +
                        gap +
                        _actionsWidth;
                    final effectiveWidth = constraints.maxWidth > contentWidth + 40
                        ? constraints.maxWidth
                        : contentWidth + 40;
                    final trailingSpace = effectiveWidth - (contentWidth + 40);
                    const headerHeight = 53.0;
                    const dividerHeight = 0.6;
                    const emptyStateHeight = 232.0;
                    final rowHeights = filteredBarangays
                        .map(
                          (barangay) => _measureBarangayRowHeight(
                            barangay: barangay,
                            widths: widths,
                            bodyStyle: bodyStyle,
                          ),
                        )
                        .toList(growable: false);
                    final contentHeightEstimate = filteredBarangays.isEmpty
                        ? emptyStateHeight
                        : rowHeights.fold<double>(0, (sum, height) => sum + height) +
                            math.max(0, filteredBarangays.length - 1) *
                                dividerHeight;
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
                              width: effectiveWidth,
                              height: shouldScrollBody ? targetTableHeight : null,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: AppColors.logoBlue.withValues(
                                        alpha: 0.10,
                                      ),
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(16),
                                        topRight: Radius.circular(16),
                                      ),
                                    ),
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      16,
                                      20,
                                      16,
                                    ),
                                    child: _BarangayHeaderRow(
                                      widths: widths,
                                      trailingSpace: trailingSpace,
                                    ),
                                  ),
                                  const Divider(
                                    height: 0,
                                    thickness: 0.6,
                                    color: Color(0xFFE4E7EC),
                                  ),
                                  if (filteredBarangays.isEmpty)
                                    if (shouldScrollBody)
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: const BorderRadius.only(
                                            bottomLeft: Radius.circular(16),
                                            bottomRight: Radius.circular(16),
                                          ),
                                          child: const EmptyStateCard(
                                            title: 'No barangays found',
                                            message:
                                                'Adjust filters or add a new barangay.',
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
                                          title: 'No barangays found',
                                          message:
                                              'Adjust filters or add a new barangay.',
                                          showBorder: false,
                                        ),
                                      )
                                  else
                                    shouldScrollBody
                                        ? Expanded(
                                            child: ListView.separated(
                                              padding: EdgeInsets.zero,
                                              itemCount: filteredBarangays.length,
                                              itemBuilder: (context, index) {
                                                final barangay =
                                                    filteredBarangays[index];
                                                return _BarangayRow(
                                                  barangay: barangay,
                                                  widths: widths,
                                                  trailingSpace: trailingSpace,
                                                  isLast: index ==
                                                      filteredBarangays.length - 1,
                                                  onPreview: () =>
                                                      _showBarangayPreviewDialog(
                                                        context,
                                                        barangay,
                                                      ),
                                                  onEdit: () =>
                                                      _showBarangayDialog(
                                                        context,
                                                        barangay: barangay,
                                                      ),
                                                  onToggleStatus: () =>
                                                      _showToggleBarangayStatusDialog(
                                                        context,
                                                        barangay,
                                                      ),
                                                  onDelete: () =>
                                                      _confirmDeleteBarangay(
                                                        context,
                                                        barangay,
                                                      ),
                                                );
                                              },
                                              separatorBuilder: (context, index) =>
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
                                                  i < filteredBarangays.length;
                                                  i++) ...[
                                                _BarangayRow(
                                                  barangay: filteredBarangays[i],
                                                  widths: widths,
                                                  trailingSpace: trailingSpace,
                                                  isLast: i ==
                                                      filteredBarangays.length - 1,
                                                  onPreview: () =>
                                                      _showBarangayPreviewDialog(
                                                        context,
                                                        filteredBarangays[i],
                                                      ),
                                                  onEdit: () =>
                                                      _showBarangayDialog(
                                                        context,
                                                        barangay:
                                                            filteredBarangays[i],
                                                      ),
                                                  onToggleStatus: () =>
                                                      _showToggleBarangayStatusDialog(
                                                        context,
                                                        filteredBarangays[i],
                                                      ),
                                                  onDelete: () =>
                                                      _confirmDeleteBarangay(
                                                        context,
                                                        filteredBarangays[i],
                                                      ),
                                                ),
                                                if (i !=
                                                    filteredBarangays.length - 1)
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
                onChanged: (value) => _setFilters(() => statusFilter = value),
              ),
            ),
          ),
          const _FilterDivider(),
          _FiltersSection(
            title: 'Created at',
            child: SizedBox(
              width: _filtersFieldWidth,
              child: _FilterDateField(
                value: createdAtFilter,
                decoration: _filterDropdownDecoration('Created at'),
                onTap: () async {
                  final selected = await showDatePicker(
                    context: context,
                    initialDate: createdAtFilter ?? DateTime(2026, 8, 16),
                    firstDate: DateTime(2024, 1, 1),
                    lastDate: DateTime(2030, 12, 31),
                  );
                  if (selected == null) {
                    return;
                  }
                  _setFilters(() => createdAtFilter = selected);
                },
                onClear: createdAtFilter == null
                    ? null
                    : () => _setFilters(() => createdAtFilter = null),
              ),
            ),
          ),
          const _FilterDivider(),
          _FiltersSection(
            title: 'Updated at',
            child: SizedBox(
              width: _filtersFieldWidth,
              child: _FilterDateField(
                value: updatedAtFilter,
                decoration: _filterDropdownDecoration('Updated at'),
                onTap: () async {
                  final selected = await showDatePicker(
                    context: context,
                    initialDate: updatedAtFilter ?? DateTime(2026, 8, 16),
                    firstDate: DateTime(2024, 1, 1),
                    lastDate: DateTime(2030, 12, 31),
                  );
                  if (selected == null) {
                    return;
                  }
                  _setFilters(() => updatedAtFilter = selected);
                },
                onClear: updatedAtFilter == null
                    ? null
                    : () => _setFilters(() => updatedAtFilter = null),
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
                  onTap: () => _setFilters(() {
                    query = '';
                    statusFilter = null;
                    createdAtFilter = null;
                    updatedAtFilter = null;
                  }),
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

  Future<void> _showBarangayDialog(
    BuildContext context, {
    Barangay? barangay,
  }) async {
    final nameController = TextEditingController(text: barangay?.name ?? '');
    var selectedWeekday = barangay?.cutoffWeekday ?? DateTime.monday;
    var selectedTime = TimeOfDay(
      hour: ((barangay?.cutoffMinutes ?? (5 * 60)) ~/ 60) % 24,
      minute: (barangay?.cutoffMinutes ?? (5 * 60)) % 60,
    );
    var selectedActive = barangay?.isActive ?? true;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var isSubmitting = false;
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> pickTime() async {
              if (isSubmitting) {
                return;
              }
              final nextTime = await showTimePicker(
                context: context,
                initialTime: selectedTime,
              );
              if (nextTime == null) {
                return;
              }
              setState(() => selectedTime = nextTime);
            }

            Future<void> submit() async {
              if (isSubmitting) {
                return;
              }

              final trimmedName = nameController.text.trim();
              if (trimmedName.isEmpty) {
                final messenger = ScaffoldMessenger.of(this.context);
                messenger.clearSnackBars();
                messenger.showSnackBar(errorSnackBar('Please enter a name.'));
                return;
              }

              final existingDuplicate = ref
                  .read(appControllerProvider)
                  .barangays
                  .where((item) => item.id != barangay?.id)
                  .any(
                    (item) =>
                        item.name.trim().toLowerCase() ==
                        trimmedName.toLowerCase(),
                  );
              if (existingDuplicate) {
                final messenger = ScaffoldMessenger.of(this.context);
                messenger.clearSnackBars();
                messenger.showSnackBar(
                  errorSnackBar('A barangay with that name already exists.'),
                );
                return;
              }

              final now = DateTime.now();
              final currentBarangays = ref.read(appControllerProvider).barangays;
              final fallbackNextBarangayId =
                  (currentBarangays.map((item) => item.id).fold<int>(0, _mathMax)) + 1;
              final cutoffMinutes = (selectedTime.hour * 60) + selectedTime.minute;

              setState(() => isSubmitting = true);
              try {
                final resolvedBarangayId =
                    barangay?.id ??
                    await ref
                        .read(firestoreCatalogServiceProvider)
                        .reserveNextBarangayId(
                          fallbackNextBarangayId: fallbackNextBarangayId,
                        );
                await ref.read(appControllerProvider.notifier).saveBarangay(
                  Barangay(
                    id: resolvedBarangayId,
                    name: trimmedName,
                    isActive: selectedActive,
                    cutoffWeekday: selectedWeekday,
                    cutoffMinutes: cutoffMinutes,
                    createdAt: barangay?.createdAt ?? now,
                    updatedAt: now,
                  ),
                );
                if (!dialogContext.mounted) {
                  return;
                }
                Navigator.of(dialogContext).pop();
                if (!mounted) {
                  return;
                }
                final messenger = ScaffoldMessenger.of(this.context);
                messenger.clearSnackBars();
                messenger.showSnackBar(
                  successSnackBar(
                    barangay == null ? 'Barangay added.' : 'Barangay updated.',
                  ),
                );
              } finally {
                if (dialogContext.mounted) {
                  setState(() => isSubmitting = false);
                }
              }
            }

            return AppModalFrame(
              title: barangay == null ? 'New Barangay' : 'Edit Barangay',
              actions: [
                AppModalButton(
                  label: 'Cancel',
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                ),
                const SizedBox(width: 10),
                AppModalButton(
                  label: 'Save',
                  isPrimary: true,
                  isLoading: isSubmitting,
                  onPressed: submit,
                ),
              ],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: selectedWeekday,
                    isExpanded: true,
                    decoration: _filterDropdownDecoration('Cutoff Day'),
                    items: List.generate(
                      7,
                      (index) => DateTime.monday + index,
                    ).map((weekday) {
                      return DropdownMenuItem<int>(
                        value: weekday,
                        child: Text(displayWeekday(weekday)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() => selectedWeekday = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: const InputDecoration(labelText: 'Cutoff Time'),
                    child: MousePressable(
                      onTap: pickTime,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              size: 18,
                              color: AppColors.logoBlue,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              formatCutoffTimeFromMinutes(
                                (selectedTime.hour * 60) + selectedTime.minute,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<bool>(
                    initialValue: selectedActive,
                    isExpanded: true,
                    decoration: _filterDropdownDecoration('Status'),
                    items: const [
                      DropdownMenuItem<bool>(value: true, child: Text('Active')),
                      DropdownMenuItem<bool>(
                        value: false,
                        child: Text('Inactive'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() => selectedActive = value);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );

  }

  Future<void> _confirmDeleteBarangay(
    BuildContext context,
    Barangay barangay,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var isDeleting = false;
        return StatefulBuilder(
          builder: (context, setState) => AppModalFrame(
            title: 'Delete Barangay',
            actions: [
              AppModalButton(
                label: 'Cancel',
                onPressed: isDeleting
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
              ),
              const SizedBox(width: 10),
              AppModalButton(
                label: 'Delete',
                isPrimary: true,
                isLoading: isDeleting,
                onPressed: () async {
                  if (isDeleting) {
                    return;
                  }
                  setState(() => isDeleting = true);
                  try {
                    await ref
                        .read(appControllerProvider.notifier)
                        .deleteBarangay(barangay.id);
                    if (!dialogContext.mounted) {
                      return;
                    }
                    Navigator.of(dialogContext).pop();
                    if (!mounted) {
                      return;
                    }
                    final messenger = ScaffoldMessenger.of(this.context);
                    messenger.clearSnackBars();
                    messenger.showSnackBar(successSnackBar('Barangay deleted.'));
                  } finally {
                    if (dialogContext.mounted) {
                      setState(() => isDeleting = false);
                    }
                  }
                },
              ),
            ],
            child: AppModalBodyText(
              'Remove ${barangay.name}? Existing orders will keep their saved barangay text.',
            ),
          ),
        );
      },
    );
  }

  Future<void> _showToggleBarangayStatusDialog(
    BuildContext context,
    Barangay barangay,
  ) {
    final nextIsActive = !barangay.isActive;
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var isSubmitting = false;
        return StatefulBuilder(
          builder: (context, setState) => AppModalFrame(
            title: nextIsActive ? 'Activate Barangay?' : 'Deactivate Barangay?',
            actions: [
              AppModalButton(
                label: 'Close',
                onPressed: isSubmitting
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
              ),
              const SizedBox(width: 10),
              AppModalButton(
                label: nextIsActive ? 'Activate' : 'Deactivate',
                isPrimary: true,
                isLoading: isSubmitting,
                onPressed: () async {
                  if (isSubmitting) {
                    return;
                  }
                  setState(() => isSubmitting = true);
                  try {
                    await ref.read(appControllerProvider.notifier).saveBarangay(
                      barangay.copyWith(isActive: nextIsActive),
                    );
                    if (!dialogContext.mounted) {
                      return;
                    }
                    Navigator.of(dialogContext).pop();
                    if (!mounted) {
                      return;
                    }
                    final messenger = ScaffoldMessenger.of(this.context);
                    messenger.clearSnackBars();
                    messenger.showSnackBar(
                      successSnackBar(
                        '${barangay.name} marked ${barangay.isActive ? 'inactive' : 'active'}.',
                      ),
                    );
                  } finally {
                    if (dialogContext.mounted) {
                      setState(() => isSubmitting = false);
                    }
                  }
                },
              ),
            ],
            child: AppModalBodyText(
              nextIsActive
                  ? '${barangay.name.trim()} will be activated.'
                  : '${barangay.name.trim()} will be deactivated.',
            ),
          ),
        );
      },
    );
  }

  Future<void> _showBarangayPreviewDialog(
    BuildContext context,
    Barangay barangay,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AppModalFrame(
        title: 'Barangay Details',
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
            _ReadOnlyBarangayField(label: 'ID', value: '${barangay.id}'),
            const SizedBox(height: 12),
            _ReadOnlyBarangayField(label: 'Name', value: barangay.name),
            const SizedBox(height: 12),
            _ReadOnlyBarangayField(
              label: 'Status',
              value: displayBarangayStatus(barangay.isActive),
            ),
            const SizedBox(height: 12),
            _ReadOnlyBarangayField(
              label: 'Cutoff',
              value: formatBarangayCutoffValue(barangay),
            ),
            const SizedBox(height: 12),
            _ReadOnlyBarangayField(
              label: 'Created At',
              value:
                  '${formatOrderDate(barangay.createdAt)} ${formatOrderTimeWithSeconds(barangay.createdAt)}',
            ),
            const SizedBox(height: 12),
            _ReadOnlyBarangayField(
              label: 'Updated At',
              value:
                  '${formatOrderDate(barangay.updatedAt)} ${formatOrderTimeWithSeconds(barangay.updatedAt)}',
            ),
          ],
        ),
      ),
    );
  }

}

class _BarangayHeaderRow extends StatelessWidget {
  const _BarangayHeaderRow({
    required this.widths,
    required this.trailingSpace,
  });

  final _BarangayColumnWidths widths;
  final double trailingSpace;

  @override
  Widget build(BuildContext context) {
    final scale = _textScaleForWidth(MediaQuery.of(context).size.width);
    final labelStyle = TextStyle(
      fontWeight: FontWeight.w700,
      color: AppColors.logoBlue,
      fontSize: 14 * scale,
      height: 1.15,
    );

    return Row(
      children: [
        SizedBox(
          width: widths.id,
          child: Text(
            'ID',
            style: labelStyle,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
          ),
        ),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.name,
          child: Text(
            'Name',
            style: labelStyle,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
          ),
        ),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.status,
          child: Text(
            'Status',
            style: labelStyle,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
          ),
        ),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.cutoff,
          child: Text(
            'Cutoff',
            style: labelStyle,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
          ),
        ),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.createdAt,
          child: Text(
            'Created at',
            style: labelStyle,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
          ),
        ),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.updatedAt,
          child: Text(
            'Updated at',
            style: labelStyle,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
          ),
        ),
        SizedBox(width: widths.gap + trailingSpace),
        SizedBox(
          width: _AdminBarangaysPageState._actionsWidth,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Actions',
              style: labelStyle,
              textAlign: TextAlign.right,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
            ),
          ),
        ),
      ],
    );
  }
}

class _BarangayRow extends StatelessWidget {
  const _BarangayRow({
    required this.barangay,
    required this.widths,
    required this.trailingSpace,
    required this.isLast,
    required this.onPreview,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onDelete,
  });

  final Barangay barangay;
  final _BarangayColumnWidths widths;
  final double trailingSpace;
  final bool isLast;
  final VoidCallback onPreview;
  final VoidCallback onEdit;
  final Future<void> Function() onToggleStatus;
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
            SizedBox(width: widths.id, child: Text('${barangay.id}', style: bodyStyle)),
            SizedBox(width: widths.gap),
            SizedBox(
              width: widths.name,
              child: Text(
                barangay.name,
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
                  label: displayBarangayStatus(barangay.isActive),
                  color: barangay.isActive
                      ? AppColors.statusActiveGreen
                      : const Color(0xFFE53935),
                  fontSize: bodyStyle.fontSize ?? 14,
                ),
              ),
            ),
            SizedBox(width: widths.gap),
            SizedBox(
              width: widths.cutoff,
              child: Text(
                formatBarangayCutoffValue(barangay),
                style: bodyStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: widths.gap),
            SizedBox(
              width: widths.createdAt,
              child: Text(
                '${formatOrderDate(barangay.createdAt)}\n${formatOrderTimeWithSeconds(barangay.createdAt)}',
                style: bodyStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: widths.gap),
            SizedBox(
              width: widths.updatedAt,
              child: Text(
                '${formatOrderDate(barangay.updatedAt)}\n${formatOrderTimeWithSeconds(barangay.updatedAt)}',
                style: bodyStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: widths.gap + trailingSpace),
            SizedBox(
              width: _AdminBarangaysPageState._actionsWidth,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  MousePressable(
                    onTap: onPreview,
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
                    onTap: onToggleStatus,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        barangay.isActive
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
                        color: Color(0xFFE31E24),
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

class _ReadOnlyBarangayField extends StatelessWidget {
  const _ReadOnlyBarangayField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: Text(
        value,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.15),
      ),
    );
  }
}

class _BarangayColumnWidths {
  const _BarangayColumnWidths({
    required this.gap,
    required this.id,
    required this.name,
    required this.status,
    required this.cutoff,
    required this.createdAt,
    required this.updatedAt,
  });

  final double gap;
  final double id;
  final double name;
  final double status;
  final double cutoff;
  final double createdAt;
  final double updatedAt;
}

_BarangayColumnWidths _computeBarangayColumnWidths({
  required double screenWidth,
  required List<Barangay> barangays,
  required TextStyle headerStyle,
  required TextStyle bodyStyle,
  required double gap,
}) {
  final badgeTextStyle = bodyStyle.copyWith(fontWeight: FontWeight.w700);
  final painter = TextPainter(textDirection: TextDirection.ltr);

  double maxWidth(
    String header,
    Iterable<String> values, {
    TextStyle? valuesStyle,
    double? max,
  }) {
    painter.text = TextSpan(text: header, style: headerStyle);
    painter.layout();
    var width = painter.width.ceilToDouble() +
        _AdminBarangaysPageState._columnWidthAllowance +
        _AdminBarangaysPageState._headerLabelExtraAllowance;
    final effectiveValuesStyle = valuesStyle ?? bodyStyle;
    for (final value in values) {
      painter.text = TextSpan(text: value, style: effectiveValuesStyle);
      painter.layout(maxWidth: screenWidth);
      final current = painter.width.ceilToDouble() +
          _AdminBarangaysPageState._columnWidthAllowance;
      if (current > width) {
        width = current;
      }
    }
    if (max != null && width > max) {
      return max;
    }
    return width;
  }

  return _BarangayColumnWidths(
    gap: gap,
    id: maxWidth('ID', barangays.map((item) => '${item.id}')),
    name: maxWidth(
      'Name',
      barangays.map((item) => item.name),
      max: screenWidth < 700 ? 160 : 220,
    ),
    status: maxWidth(
      'Status',
      barangays.map((item) => displayBarangayStatus(item.isActive)),
      valuesStyle: badgeTextStyle,
    ) +
        _AdminBarangaysPageState._statusBadgeHorizontalPadding,
    cutoff: maxWidth(
      'Cutoff',
      barangays.map((item) => formatBarangayCutoffValue(item)),
    ),
    createdAt: maxWidth(
      'Created at',
      barangays.map(
        (item) =>
            '${formatOrderDate(item.createdAt)}\n${formatOrderTimeWithSeconds(item.createdAt)}',
      ),
    ) +
        _AdminBarangaysPageState._dateHeaderExtraAllowance,
    updatedAt: maxWidth(
      'Updated at',
      barangays.map(
        (item) =>
            '${formatOrderDate(item.updatedAt)}\n${formatOrderTimeWithSeconds(item.updatedAt)}',
      ),
    ) +
        _AdminBarangaysPageState._dateHeaderExtraAllowance,
  );
}

double _measureBarangayTextHeight(
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

double _measureBarangayRowHeight({
  required Barangay barangay,
  required _BarangayColumnWidths widths,
  required TextStyle bodyStyle,
}) {
  final createdAtText =
      '${formatOrderDate(barangay.createdAt)}\n${formatOrderTimeWithSeconds(barangay.createdAt)}';
  final updatedAtText =
      '${formatOrderDate(barangay.updatedAt)}\n${formatOrderTimeWithSeconds(barangay.updatedAt)}';

  final tallestContent = <double>[
    _measureBarangayTextHeight(
      '${barangay.id}',
      bodyStyle,
      widths.id,
      maxLines: 1,
    ),
    _measureBarangayTextHeight(
      barangay.name,
      bodyStyle,
      widths.name,
      maxLines: 2,
    ),
    34,
    _measureBarangayTextHeight(
      formatBarangayCutoffValue(barangay),
      bodyStyle,
      widths.cutoff,
      maxLines: 1,
    ),
    _measureBarangayTextHeight(
      createdAtText,
      bodyStyle,
      widths.createdAt,
      maxLines: 2,
    ),
    _measureBarangayTextHeight(
      updatedAtText,
      bodyStyle,
      widths.updatedAt,
      maxLines: 2,
    ),
    34,
  ].reduce(math.max);

  return tallestContent + 32;
}

class _FilterDateField extends StatelessWidget {
  const _FilterDateField({
    required this.value,
    required this.decoration,
    required this.onTap,
    this.onClear,
  });

  final DateTime? value;
  final InputDecoration decoration;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final label = value == null ? 'Any' : formatAsOfDate(value!);
    final isPlaceholder = value == null;
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
            if (onClear != null) ...[
              const SizedBox(width: 8),
              MousePressable(
                onTap: onClear,
                borderRadius: BorderRadius.circular(999),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.logoBlue,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 2),
            const Icon(
              Icons.calendar_month_rounded,
              size: 18,
              color: AppColors.logoBlue,
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration _filterDropdownDecoration(String label) {
  return InputDecoration(
    hintText: label,
    hintStyle: const TextStyle(color: AppColors.logoBlue, height: 1.15),
    filled: true,
    fillColor: AppColors.logoBlueSoft,
    isDense: true,
    contentPadding: const EdgeInsets.fromLTRB(16, 16, 6, 16),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: AppColors.logoBlue.withValues(alpha: 0.16)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.logoBlue),
    ),
  );
}

class _FiltersSection extends StatelessWidget {
  const _FiltersSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _AdminBarangaysPageState._filtersContentHorizontalPadding,
        16,
        _AdminBarangaysPageState._filtersContentHorizontalPadding,
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

double _textScaleForWidth(double width) {
  if (width <= 360) {
    return 0.82;
  }
  if (width < 700) {
    return 0.90;
  }
  return 1;
}

String? _normalizeNullable(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

DateTime? _parseRouteDate(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return DateTime.tryParse(trimmed);
}

String _formatRouteDate(DateTime value) {
  final normalized = DateTime(value.year, value.month, value.day);
  return normalized.toIso8601String().split('T').first;
}

bool _isSameDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

int _mathMax(int current, int next) => current > next ? current : next;
