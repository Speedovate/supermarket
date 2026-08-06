import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/app_models.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../app_state/app_controller.dart';

double _categoryTextScaleForWidth(double width) {
  if (width <= 360) {
    return 0.82;
  }
  if (width < 700) {
    return 0.90;
  }
  return 1;
}

class AdminCategoriesPage extends ConsumerStatefulWidget {
  const AdminCategoriesPage({super.key});

  @override
  ConsumerState<AdminCategoriesPage> createState() =>
      _AdminCategoriesPageState();
}

class _AdminCategoriesPageState extends ConsumerState<AdminCategoriesPage> {
  static const double _filtersMenuWidth = 248;
  static const double _filtersContentHorizontalPadding = 16;
  static const double _categoryColumnWidthAllowance = 2;
  static const double _categoryDateHeaderExtraAllowance = 2;
  static const double _categoryActionsWidth = 136;
  static double get _filtersFieldWidth =>
      _filtersMenuWidth - (_filtersContentHorizontalPadding * 2);

  String query = '';
  DateTime? createdAtFilter;
  DateTime? updatedAtFilter;
  String? statusFilter;

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final appState = ref.watch(appControllerProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 700;
    final categoryColumnGap = _categoryColumnGapForWidth(screenWidth);
    final categoryTextScale = _categoryTextScaleForWidth(screenWidth);
    final allCategories = [...appState.categories];
    final headerTextStyle = TextStyle(
      fontWeight: FontWeight.w700,
      color: AppColors.logoBlue,
      fontSize: 14 * categoryTextScale,
      height: 1.15,
    );
    final baseBodyTextStyle =
        Theme.of(context).textTheme.bodyMedium ??
        const TextStyle(fontSize: 14, height: 1.15);
    final bodyTextStyle = baseBodyTextStyle.copyWith(
      fontSize: (baseBodyTextStyle.fontSize ?? 14) * categoryTextScale,
      height: 1.15,
    );
    final assignedCounts = <int, int>{
      for (final category in allCategories) category.id: 0,
    };
    for (final product in appState.products) {
      assignedCounts.update(
        product.categoryId,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    final normalizedQuery = query.trim().toLowerCase();
    final categories = allCategories.where((category) {
      final matchesQuery =
          normalizedQuery.isEmpty ||
          category.name.toLowerCase().contains(normalizedQuery) ||
          '${category.id}'.contains(normalizedQuery);
      final matchesCreatedAt =
          createdAtFilter == null ||
          !_startOfDay(
                category.createdAt,
              ).isAtSameMomentAs(_startOfDay(createdAtFilter!)) &&
              !_endOfDay(
                category.createdAt,
              ).isBefore(_startOfDay(createdAtFilter!)) &&
              !_startOfDay(
                category.createdAt,
              ).isAfter(_endOfDay(createdAtFilter!));
      final matchesUpdatedAt =
          updatedAtFilter == null ||
          !_startOfDay(
                category.updatedAt,
              ).isAtSameMomentAs(_startOfDay(updatedAtFilter!)) &&
              !_endOfDay(
                category.updatedAt,
              ).isBefore(_startOfDay(updatedAtFilter!)) &&
              !_startOfDay(
                category.updatedAt,
              ).isAfter(_endOfDay(updatedAtFilter!));
      final matchesStatus = switch (statusFilter) {
        'active' => category.isActive,
        'inactive' => !category.isActive,
        _ => true,
      };
      return matchesQuery &&
          matchesCreatedAt &&
          matchesUpdatedAt &&
          matchesStatus;
    }).toList();
    final columnWidths = _computeCategoryColumnWidths(
      screenWidth: screenWidth,
      categories: categories,
      assignedCounts: assignedCounts,
      gap: categoryColumnGap,
      headerTextStyle: headerTextStyle,
      bodyTextStyle: bodyTextStyle,
    );
    final tableContentWidth =
        columnWidths.id +
        categoryColumnGap +
        columnWidths.name +
        categoryColumnGap +
        columnWidths.status +
        categoryColumnGap +
        columnWidths.items +
        categoryColumnGap +
        columnWidths.createdAt +
        categoryColumnGap +
        columnWidths.updatedAt +
        categoryColumnGap +
        _categoryActionsWidth;
    final tableWidth = tableContentWidth + 40;
    final canReorder =
        normalizedQuery.isEmpty &&
        statusFilter == null &&
        createdAtFilter == null &&
        updatedAtFilter == null;
    final activeFilterCount =
        (createdAtFilter == null ? 0 : 1) +
        (updatedAtFilter == null ? 0 : 1) +
        (statusFilter == null ? 0 : 1);
    final toolbarActionSize = isMobile ? 48.0 : 0.0;

    return ListView(
      children: [
        Column(
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
                                onChanged: (value) =>
                                    setState(() => query = value),
                                decoration: const InputDecoration(
                                  hintText: 'Search',
                                  hintStyle: TextStyle(
                                    color: AppColors.logoBlue,
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
                                padding: WidgetStatePropertyAll(
                                  EdgeInsets.zero,
                                ),
                                shape: WidgetStatePropertyAll(
                                  RoundedRectangleBorder(
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(16),
                                    ),
                                  ),
                                ),
                              ),
                              menuChildren: [
                                SizedBox(
                                  width: _filtersMenuWidth,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          _filtersContentHorizontalPadding,
                                          16,
                                          _filtersContentHorizontalPadding,
                                          0,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            const Text(
                                              'Created at',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.logoBlue,
                                                height: 1.15,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: SizedBox(
                                                width: _filtersFieldWidth,
                                                child: _DateField(
                                                  label: createdAtFilter == null
                                                      ? 'Any'
                                                      : formatAsOfDate(
                                                          createdAtFilter!,
                                                        ),
                                                  decoration:
                                                      _filterDropdownDecoration(
                                                        'Created at',
                                                      ),
                                                  icon: Icons
                                                      .calendar_month_rounded,
                                                  onTap: () async {
                                                    final now = DateTime.now();
                                                    final earliestDate =
                                                        allCategories
                                                            .map(
                                                              (
                                                                category,
                                                              ) => category
                                                                  .createdAt,
                                                            )
                                                            .reduce(
                                                              (
                                                                value,
                                                                element,
                                                              ) =>
                                                                  value
                                                                      .isBefore(
                                                                        element,
                                                                      )
                                                                  ? value
                                                                  : element,
                                                            );
                                                    final pickedDate =
                                                        await showDatePicker(
                                                          context: context,
                                                          firstDate: DateTime(
                                                            earliestDate.year -
                                                                1,
                                                          ),
                                                          lastDate: DateTime(
                                                            now.year + 2,
                                                            12,
                                                            31,
                                                          ),
                                                          initialDate:
                                                              createdAtFilter ??
                                                              now,
                                                          currentDate: now,
                                                        );
                                                    if (pickedDate == null ||
                                                        !context.mounted) {
                                                      return;
                                                    }
                                                    setState(() {
                                                      createdAtFilter =
                                                          pickedDate;
                                                    });
                                                  },
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                          ],
                                        ),
                                      ),
                                      const _FilterDivider(),
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          _filtersContentHorizontalPadding,
                                          12,
                                          _filtersContentHorizontalPadding,
                                          0,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            const Text(
                                              'Updated at',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.logoBlue,
                                                height: 1.15,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: SizedBox(
                                                width: _filtersFieldWidth,
                                                child: _DateField(
                                                  label: updatedAtFilter == null
                                                      ? 'Any'
                                                      : formatAsOfDate(
                                                          updatedAtFilter!,
                                                        ),
                                                  decoration:
                                                      _filterDropdownDecoration(
                                                        'Updated at',
                                                      ),
                                                  icon: Icons
                                                      .calendar_month_rounded,
                                                  onTap: () async {
                                                    final now = DateTime.now();
                                                    final earliestDate =
                                                        allCategories
                                                            .map(
                                                              (
                                                                category,
                                                              ) => category
                                                                  .updatedAt,
                                                            )
                                                            .reduce(
                                                              (
                                                                value,
                                                                element,
                                                              ) =>
                                                                  value
                                                                      .isBefore(
                                                                        element,
                                                                      )
                                                                  ? value
                                                                  : element,
                                                            );
                                                    final pickedDate =
                                                        await showDatePicker(
                                                          context: context,
                                                          firstDate: DateTime(
                                                            earliestDate.year -
                                                                1,
                                                          ),
                                                          lastDate: DateTime(
                                                            now.year + 2,
                                                            12,
                                                            31,
                                                          ),
                                                          initialDate:
                                                              updatedAtFilter ??
                                                              now,
                                                          currentDate: now,
                                                        );
                                                    if (pickedDate == null ||
                                                        !context.mounted) {
                                                      return;
                                                    }
                                                    setState(() {
                                                      updatedAtFilter =
                                                          pickedDate;
                                                    });
                                                  },
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                          ],
                                        ),
                                      ),
                                      const _FilterDivider(),
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          _filtersContentHorizontalPadding,
                                          12,
                                          _filtersContentHorizontalPadding,
                                          0,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            const Text(
                                              'Category status',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.logoBlue,
                                                height: 1.15,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: SizedBox(
                                                width: _filtersFieldWidth,
                                                child: DropdownButtonFormField<String?>(
                                                  isExpanded: true,
                                                  icon: const Icon(
                                                    Icons
                                                        .keyboard_arrow_down_rounded,
                                                    color: AppColors.logoBlue,
                                                    size: 24,
                                                  ),
                                                  initialValue: statusFilter,
                                                  decoration:
                                                      _filterDropdownDecoration(
                                                        'Category status',
                                                      ),
                                                  items: const [
                                                    DropdownMenuItem<String?>(
                                                      value: null,
                                                      child: Text('Any'),
                                                    ),
                                                    DropdownMenuItem<String?>(
                                                      value: 'active',
                                                      child: Text('Active'),
                                                    ),
                                                    DropdownMenuItem<String?>(
                                                      value: 'inactive',
                                                      child: Text('Inactive'),
                                                    ),
                                                  ],
                                                  onChanged: (value) =>
                                                      setState(
                                                        () => statusFilter =
                                                            value,
                                                      ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                          ],
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
                                                  statusFilter = null;
                                                });
                                              },
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Container(
                                                width: double.infinity,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 10,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: const Color(
                                                      0xFFE4E7EC,
                                                    ),
                                                  ),
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
                                onChanged: (value) =>
                                    setState(() => query = value),
                                decoration: const InputDecoration(
                                  hintText: 'Search',
                                  hintStyle: TextStyle(
                                    color: AppColors.logoBlue,
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
                                padding: WidgetStatePropertyAll(
                                  EdgeInsets.zero,
                                ),
                                shape: WidgetStatePropertyAll(
                                  RoundedRectangleBorder(
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(16),
                                    ),
                                  ),
                                ),
                              ),
                              menuChildren: [
                                SizedBox(
                                  width: _filtersMenuWidth,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          _filtersContentHorizontalPadding,
                                          16,
                                          _filtersContentHorizontalPadding,
                                          0,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            const Text(
                                              'Created at',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.logoBlue,
                                                height: 1.15,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: SizedBox(
                                                width: _filtersFieldWidth,
                                                child: _DateField(
                                                  label: createdAtFilter == null
                                                      ? 'Any'
                                                      : formatAsOfDate(
                                                          createdAtFilter!,
                                                        ),
                                                  decoration:
                                                      _filterDropdownDecoration(
                                                        'Created at',
                                                      ),
                                                  icon: Icons
                                                      .calendar_month_rounded,
                                                  onTap: () async {
                                                    final now = DateTime.now();
                                                    final earliestDate =
                                                        allCategories
                                                            .map(
                                                              (
                                                                category,
                                                              ) => category
                                                                  .createdAt,
                                                            )
                                                            .reduce(
                                                              (
                                                                value,
                                                                element,
                                                              ) =>
                                                                  value
                                                                      .isBefore(
                                                                        element,
                                                                      )
                                                                  ? value
                                                                  : element,
                                                            );
                                                    final pickedDate =
                                                        await showDatePicker(
                                                          context: context,
                                                          firstDate: DateTime(
                                                            earliestDate.year -
                                                                1,
                                                          ),
                                                          lastDate: DateTime(
                                                            now.year + 2,
                                                            12,
                                                            31,
                                                          ),
                                                          initialDate:
                                                              createdAtFilter ??
                                                              now,
                                                          currentDate: now,
                                                        );
                                                    if (pickedDate == null ||
                                                        !context.mounted) {
                                                      return;
                                                    }
                                                    setState(() {
                                                      createdAtFilter =
                                                          pickedDate;
                                                    });
                                                  },
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                          ],
                                        ),
                                      ),
                                      const _FilterDivider(),
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          _filtersContentHorizontalPadding,
                                          12,
                                          _filtersContentHorizontalPadding,
                                          0,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            const Text(
                                              'Updated at',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.logoBlue,
                                                height: 1.15,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: SizedBox(
                                                width: _filtersFieldWidth,
                                                child: _DateField(
                                                  label: updatedAtFilter == null
                                                      ? 'Any'
                                                      : formatAsOfDate(
                                                          updatedAtFilter!,
                                                        ),
                                                  decoration:
                                                      _filterDropdownDecoration(
                                                        'Updated at',
                                                      ),
                                                  icon: Icons
                                                      .calendar_month_rounded,
                                                  onTap: () async {
                                                    final now = DateTime.now();
                                                    final earliestDate =
                                                        allCategories
                                                            .map(
                                                              (
                                                                category,
                                                              ) => category
                                                                  .updatedAt,
                                                            )
                                                            .reduce(
                                                              (
                                                                value,
                                                                element,
                                                              ) =>
                                                                  value
                                                                      .isBefore(
                                                                        element,
                                                                      )
                                                                  ? value
                                                                  : element,
                                                            );
                                                    final pickedDate =
                                                        await showDatePicker(
                                                          context: context,
                                                          firstDate: DateTime(
                                                            earliestDate.year -
                                                                1,
                                                          ),
                                                          lastDate: DateTime(
                                                            now.year + 2,
                                                            12,
                                                            31,
                                                          ),
                                                          initialDate:
                                                              updatedAtFilter ??
                                                              now,
                                                          currentDate: now,
                                                        );
                                                    if (pickedDate == null ||
                                                        !context.mounted) {
                                                      return;
                                                    }
                                                    setState(() {
                                                      updatedAtFilter =
                                                          pickedDate;
                                                    });
                                                  },
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                          ],
                                        ),
                                      ),
                                      const _FilterDivider(),
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          _filtersContentHorizontalPadding,
                                          12,
                                          _filtersContentHorizontalPadding,
                                          0,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            const Text(
                                              'Category status',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.logoBlue,
                                                height: 1.15,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: SizedBox(
                                                width: _filtersFieldWidth,
                                                child: DropdownButtonFormField<String?>(
                                                  isExpanded: true,
                                                  icon: const Icon(
                                                    Icons
                                                        .keyboard_arrow_down_rounded,
                                                    color: AppColors.logoBlue,
                                                    size: 24,
                                                  ),
                                                  initialValue: statusFilter,
                                                  decoration:
                                                      _filterDropdownDecoration(
                                                        'Category status',
                                                      ),
                                                  items: const [
                                                    DropdownMenuItem<String?>(
                                                      value: null,
                                                      child: Text('Any'),
                                                    ),
                                                    DropdownMenuItem<String?>(
                                                      value: 'active',
                                                      child: Text('Active'),
                                                    ),
                                                    DropdownMenuItem<String?>(
                                                      value: 'inactive',
                                                      child: Text('Inactive'),
                                                    ),
                                                  ],
                                                  onChanged: (value) =>
                                                      setState(
                                                        () => statusFilter =
                                                            value,
                                                      ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                          ],
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
                                                  statusFilter = null;
                                                });
                                              },
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Container(
                                                width: double.infinity,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 10,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: const Color(
                                                      0xFFE4E7EC,
                                                    ),
                                                  ),
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
                  onTap: () => _showCategoryDialog(context, ref),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: isMobile ? toolbarActionSize : null,
                    height: isMobile ? toolbarActionSize : null,
                    padding: isMobile
                        ? EdgeInsets.zero
                        : const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
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
                            'New Category',
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
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final effectiveTableWidth = constraints.maxWidth > tableWidth
                ? constraints.maxWidth
                : tableWidth;
            final trailingSpace = effectiveTableWidth - tableWidth;
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
                            child: categories.isEmpty
                                ? _CategoryHeaderRow(
                                    isEmpty: true,
                                    widths: columnWidths,
                                    trailingSpace: trailingSpace,
                                  )
                                : _CategoryHeaderRow(
                                    isEmpty: false,
                                    widths: columnWidths,
                                    trailingSpace: trailingSpace,
                                  ),
                          ),
                          const Divider(
                            height: 0,
                            thickness: 0.6,
                            color: Color(0xFFE4E7EC),
                          ),
                          if (categories.isEmpty)
                            ClipRRect(
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(16),
                                bottomRight: Radius.circular(16),
                              ),
                              child: EmptyStateCard(
                                title: 'No categories found',
                                message:
                                    normalizedQuery.isEmpty &&
                                        statusFilter == null &&
                                        createdAtFilter == null &&
                                        updatedAtFilter == null
                                    ? 'Create your first product category.'
                                    : 'Adjust filters or create a new category.',
                                showBorder: false,
                              ),
                            )
                          else if (canReorder)
                            ReorderableListView.builder(
                              shrinkWrap: true,
                              buildDefaultDragHandles: false,
                              physics: const NeverScrollableScrollPhysics(),
                              proxyDecorator: (child, index, animation) {
                                return DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(
                                      color: const Color(0xFFE4E7EC),
                                      width: 0.6,
                                    ),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    surfaceTintColor: Colors.transparent,
                                    elevation: 0,
                                    child: child,
                                  ),
                                );
                              },
                              itemCount: categories.length,
                              onReorder: (oldIndex, newIndex) {
                                final nextCategories = [...categories];
                                if (newIndex > oldIndex) {
                                  newIndex -= 1;
                                }
                                final moved = nextCategories.removeAt(oldIndex);
                                nextCategories.insert(newIndex, moved);
                                ref
                                    .read(appControllerProvider.notifier)
                                    .reorderCategoriesByIds(
                                      nextCategories
                                          .map((category) => category.id)
                                          .toList(),
                                    );
                              },
                              itemBuilder: (context, index) {
                                final category = categories[index];
                                return DecoratedBox(
                                  key: ValueKey(category.id),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: index == categories.length - 1
                                        ? const BorderRadius.only(
                                            bottomLeft: Radius.circular(16),
                                            bottomRight: Radius.circular(16),
                                          )
                                        : null,
                                  ),
                                  child: Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          20,
                                          16,
                                          20,
                                          16,
                                        ),
                                        child: _CategoryContentRow(
                                          category: category,
                                          assignedCount:
                                              assignedCounts[category.id] ?? 0,
                                          widths: columnWidths,
                                          trailingSpace: trailingSpace,
                                          onEdit: () => _showCategoryDialog(
                                            context,
                                            ref,
                                            initial: category,
                                          ),
                                          onToggleActive: () async {
                                            final nextIsActive =
                                                !category.isActive;
                                            final shouldToggle =
                                                await _showToggleCategoryStatusDialog(
                                                  context,
                                                  category.name,
                                                  nextIsActive,
                                                );
                                            if (shouldToggle == true) {
                                              await ref
                                                  .read(
                                                    appControllerProvider
                                                        .notifier,
                                                  )
                                                  .saveCategory(
                                                    category.copyWith(
                                                      isActive: nextIsActive,
                                                      updatedAt:
                                                          DateTime.now(),
                                                    ),
                                                  );
                                            }
                                          },
                                          onDelete: () async {
                                            final shouldDelete =
                                                await _showDeleteCategoryDialog(
                                                  context,
                                                  category.name,
                                                );
                                            if (shouldDelete == true) {
                                              await ref
                                                  .read(
                                                    appControllerProvider
                                                        .notifier,
                                                  )
                                                  .deleteCategory(category.id);
                                            }
                                          },
                                          dragChild:
                                              ReorderableDragStartListener(
                                                index: index,
                                                child: const Padding(
                                                  padding: EdgeInsets.only(
                                                    left: 8,
                                                  ),
                                                  child: Icon(
                                                    Icons
                                                        .drag_indicator_rounded,
                                                    size: 20,
                                                    color: Color(0xFF667085),
                                                  ),
                                                ),
                                              ),
                                        ),
                                      ),
                                      if (index != categories.length - 1)
                                        const Divider(
                                          height: 0,
                                          thickness: 0.6,
                                          color: Color(0xFFE4E7EC),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            )
                          else
                            Column(
                              children: [
                                for (
                                  var index = 0;
                                  index < categories.length;
                                  index++
                                ) ...[
                                  _CategoryRow(
                                    category: categories[index],
                                    assignedCount:
                                        assignedCounts[categories[index].id] ??
                                        0,
                                    widths: columnWidths,
                                    trailingSpace: trailingSpace,
                                    isLast: index == categories.length - 1,
                                    onEdit: () => _showCategoryDialog(
                                      context,
                                      ref,
                                      initial: categories[index],
                                    ),
                                    onToggleActive: () async {
                                      final category = categories[index];
                                      final nextIsActive =
                                          !category.isActive;
                                      final shouldToggle =
                                          await _showToggleCategoryStatusDialog(
                                            context,
                                            category.name,
                                            nextIsActive,
                                          );
                                      if (shouldToggle == true) {
                                        await ref
                                            .read(
                                              appControllerProvider.notifier,
                                            )
                                            .saveCategory(
                                              category.copyWith(
                                                isActive: nextIsActive,
                                                updatedAt: DateTime.now(),
                                              ),
                                            );
                                      }
                                    },
                                    onDelete: () async {
                                      final shouldDelete =
                                          await _showDeleteCategoryDialog(
                                            context,
                                            categories[index].name,
                                          );
                                      if (shouldDelete == true) {
                                        await ref
                                            .read(
                                              appControllerProvider.notifier,
                                            )
                                            .deleteCategory(
                                              categories[index].id,
                                            );
                                      }
                                    },
                                    dragChild: const Padding(
                                      padding: EdgeInsets.only(left: 8),
                                      child: Icon(
                                        Icons.drag_indicator_rounded,
                                        size: 20,
                                        color: Color(0xFF98A2B3),
                                      ),
                                    ),
                                  ),
                                  if (index != categories.length - 1)
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
      ],
    );
  }

  InputDecoration _filterDropdownDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: AppColors.logoBlue, height: 1.15),
      filled: true,
      fillColor: AppColors.logoBlueSoft,
      isDense: true,
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 10, 16),
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

  static DateTime _startOfDay(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static DateTime _endOfDay(DateTime value) {
    return DateTime(value.year, value.month, value.day, 23, 59, 59, 999);
  }

  _CategoryColumnWidths _computeCategoryColumnWidths({
    required double screenWidth,
    required List<Category> categories,
    required Map<int, int> assignedCounts,
    required double gap,
    required TextStyle headerTextStyle,
    required TextStyle bodyTextStyle,
  }) {
    final badgeTextStyle = bodyTextStyle.copyWith(fontWeight: FontWeight.w700);

    double measure(String text, TextStyle style) {
      final lines = text.split('\n');
      var widest = 0.0;
      for (final line in lines) {
        final painter = TextPainter(
          text: TextSpan(text: line, style: style),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();
        if (painter.width > widest) {
          widest = painter.width;
        }
      }
      return widest;
    }

    double maxWidth(
      String header,
      Iterable<String> values, {
      TextStyle? valuesStyle,
    }) {
      var widest = measure(header, headerTextStyle);
      final effectiveValuesStyle = valuesStyle ?? bodyTextStyle;
      for (final value in values) {
        final current = measure(value, effectiveValuesStyle);
        if (current > widest) {
          widest = current;
        }
      }
      return widest.ceilToDouble() + _categoryColumnWidthAllowance;
    }

    double cappedMaxWidth(
      String header,
      Iterable<String> values, {
      required double max,
    }) {
      final width = maxWidth(header, values);
      return width > max ? max : width;
    }

    return _CategoryColumnWidths(
      gap: gap,
      id: maxWidth('ID', categories.map((category) => '${category.id}')),
      name: cappedMaxWidth(
        'Name',
        categories.map((category) => category.name),
        max: _categoryNameMaxWidthForScreen(screenWidth),
      ),
      status: maxWidth(
        'Status',
        categories.map((category) => category.isActive ? 'Active' : 'Inactive'),
        valuesStyle: badgeTextStyle,
      ) + 24,
      items: maxWidth(
        'Items',
        categories.map((category) => '${assignedCounts[category.id] ?? 0}'),
      ),
      createdAt: maxWidth(
        'Created at',
        categories.map(
          (category) =>
              '${formatOrderDate(category.createdAt)}\n${formatOrderTimeWithSeconds(category.createdAt)}',
        ),
      ) + _categoryDateHeaderExtraAllowance,
      updatedAt: maxWidth(
        'Updated at',
        categories.map(
          (category) =>
              '${formatOrderDate(category.updatedAt)}\n${formatOrderTimeWithSeconds(category.updatedAt)}',
        ),
      ) + _categoryDateHeaderExtraAllowance,
    );
  }

  double _categoryColumnGapForWidth(double width) {
    if (width <= 360) {
      return 24;
    }
    if (width < 700) {
      return 32;
    }
    return 40;
  }

  double _categoryNameMaxWidthForScreen(double width) {
    if (width <= 360) {
      return 108;
    }
    if (width < 700) {
      return 128;
    }
    if (width < 1024) {
      return 152;
    }
    return 168;
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
                  color: Color(0xFF1D2939),
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

class _CategoryHeaderRow extends StatelessWidget {
  const _CategoryHeaderRow({
    required this.isEmpty,
    required this.widths,
    required this.trailingSpace,
  });

  final bool isEmpty;
  final _CategoryColumnWidths widths;
  final double trailingSpace;

  @override
  Widget build(BuildContext context) {
    final scale = _categoryTextScaleForWidth(MediaQuery.of(context).size.width);
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
          width: widths.items,
          child: Text('Items', style: labelStyle, maxLines: 1),
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
          width: _AdminCategoriesPageState._categoryActionsWidth,
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

class _CategoryContentRow extends StatelessWidget {
  const _CategoryContentRow({
    required this.category,
    required this.assignedCount,
    required this.widths,
    required this.trailingSpace,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
    required this.dragChild,
  });

  final Category category;
  final int assignedCount;
  final _CategoryColumnWidths widths;
  final double trailingSpace;
  final VoidCallback onEdit;
  final Future<void> Function() onToggleActive;
  final Future<void> Function() onDelete;
  final Widget dragChild;

  @override
  Widget build(BuildContext context) {
    final status = category.isActive ? 'Active' : 'Inactive';
    final scale = _categoryTextScaleForWidth(MediaQuery.of(context).size.width);
    final bodyStyle = DefaultTextStyle.of(context).style.copyWith(
      fontSize: (DefaultTextStyle.of(context).style.fontSize ?? 14) * scale,
      height: 1.15,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: widths.id,
          child: Text('${category.id}', style: bodyStyle),
        ),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.name,
          child: Text(
            category.name,
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
              color: category.isActive
                  ? AppColors.statusActiveGreen
                  : const Color(0xFF98A2B3),
              fontSize: bodyStyle.fontSize ?? 14,
            ),
          ),
        ),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.items,
          child: Text(
            '$assignedCount',
            style: bodyStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.createdAt,
          child: Text(
            '${formatOrderDate(category.createdAt)}\n${formatOrderTimeWithSeconds(category.createdAt)}',
            style: bodyStyle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.updatedAt,
          child: Text(
            '${formatOrderDate(category.updatedAt)}\n${formatOrderTimeWithSeconds(category.updatedAt)}',
            style: bodyStyle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: widths.gap + trailingSpace),
        SizedBox(
          width: _AdminCategoriesPageState._categoryActionsWidth,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
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
                    category.isActive
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
              dragChild,
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.assignedCount,
    required this.widths,
    required this.trailingSpace,
    required this.isLast,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
    required this.dragChild,
  });

  final Category category;
  final int assignedCount;
  final _CategoryColumnWidths widths;
  final double trailingSpace;
  final bool isLast;
  final VoidCallback onEdit;
  final Future<void> Function() onToggleActive;
  final Future<void> Function() onDelete;
  final Widget dragChild;

  @override
  Widget build(BuildContext context) {
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
        child: _CategoryContentRow(
          category: category,
          assignedCount: assignedCount,
          widths: widths,
          trailingSpace: trailingSpace,
          onEdit: onEdit,
          onToggleActive: onToggleActive,
          onDelete: onDelete,
          dragChild: dragChild,
        ),
      ),
    );
  }
}

class _CategoryColumnWidths {
  const _CategoryColumnWidths({
    required this.gap,
    required this.id,
    required this.name,
    required this.status,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  final double gap;
  final double id;
  final double name;
  final double status;
  final double items;
  final double createdAt;
  final double updatedAt;
}

extension on _AdminCategoriesPageState {
  Future<bool?> _showToggleCategoryStatusDialog(
    BuildContext context,
    String categoryName,
    bool nextIsActive,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AppModalFrame(
          title: nextIsActive ? 'Activate Category?' : 'Deactivate Category?',
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
                ? '${categoryName.trim()} will be activated.'
                : '${categoryName.trim()} will be deactivated.',
          ),
        );
      },
    );
  }

  Future<bool?> _showDeleteCategoryDialog(
    BuildContext context,
    String categoryName,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AppModalFrame(
          title: 'Remove Category?',
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
          child: AppModalBodyText('${categoryName.trim()} will be deleted.'),
        );
      },
    );
  }

  Future<void> _showCategoryDialog(
    BuildContext context,
    WidgetRef ref, {
    Category? initial,
  }) async {
    final categories = ref.read(appControllerProvider).categories;
    final nameController = TextEditingController(text: initial?.name ?? '');
    var isActive = initial?.isActive ?? true;
    final now = DateTime.now();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AppModalFrame(
              title: initial == null ? 'New Category' : 'Edit Category',
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
                    final category = Category(
                      id:
                          initial?.id ??
                          ((categories
                                  .map((item) => item.id)
                                  .fold<int>(
                                    0,
                                    (max, value) => value > max ? value : max,
                                  )) +
                              1),
                      name: nameController.text.trim(),
                      normalizedName: nameController.text.trim().toLowerCase(),
                      isActive: isActive,
                      createdAt: initial?.createdAt ?? now,
                      updatedAt: now,
                    );
                    await ref
                        .read(appControllerProvider.notifier)
                        .saveCategory(category);
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
                        labelText: 'Category name',
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
