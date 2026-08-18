import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../app_state/app_controller.dart';

class AdminCategoryDetailPage extends ConsumerWidget {
  const AdminCategoryDetailPage({super.key, required this.categoryId});

  final int categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final category = state.categories.where((item) => item.id == categoryId).firstOrNull;

    if (category == null) {
      return const Center(child: Text('Category not found.'));
    }

    final products = state.products
        .where((item) => item.categoryId == category.id)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return ListView(
      children: [
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.logoBlue,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            category.name.trim().isEmpty
                                ? 'C'
                                : category.name.trim().characters.first.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              height: 1.15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            category.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF172033),
                              height: 1.15,
                            ),
                          ),
                        ),
                        AdminStateBadge(
                          label: category.isActive ? 'Active' : 'Inactive',
                          color: category.isActive
                              ? AppColors.statusActiveGreen
                              : const Color(0xFF98A2B3),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 0, thickness: 0.6, color: Color(0xFFE4E7EC)),
                  _CategoryDetailTable(
                    categoryId: category.id,
                    itemCount: products.length,
                    createdAt: category.createdAt,
                    updatedAt: category.updatedAt,
                  ),
                ],
              ),
            ),
          ),
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
                    color: AppColors.logoBlue.withValues(alpha: 0.10),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: const Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Products',
                            style: TextStyle(
                              color: AppColors.logoBlue,
                              fontWeight: FontWeight.w700,
                              height: 1.15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 0, thickness: 0.6, color: Color(0xFFE4E7EC)),
                  if (products.isEmpty)
                    const EmptyStateCard(
                      title: 'No products found',
                      message: 'No products are assigned to this category.',
                      showBorder: false,
                    )
                  else
                    ...products.asMap().entries.map((entry) {
                      final product = entry.value;
                      final isLast = entry.key == products.length - 1;
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
                        child: Column(
                          children: [
                            MousePressable(
                              onTap: () => context.go('/admin/products/${product.id}'),
                              borderRadius: isLast
                                  ? const BorderRadius.only(
                                      bottomLeft: Radius.circular(16),
                                      bottomRight: Radius.circular(16),
                                    )
                                  : BorderRadius.zero,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        product.name,
                                        style: const TextStyle(
                                          color: Color(0xFF172033),
                                          height: 1.15,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Text(
                                      product.details,
                                      style: const TextStyle(
                                        color: Color(0xFF667085),
                                        height: 1.15,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Text(
                                      formatPesos(product.referencePriceCentavos),
                                      style: const TextStyle(
                                        color: Color(0xFF172033),
                                        height: 1.15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (!isLast)
                              const Divider(
                                height: 0,
                                thickness: 0.6,
                                color: Color(0xFFE4E7EC),
                              ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryDetailTable extends StatelessWidget {
  const _CategoryDetailTable({
    required this.categoryId,
    required this.itemCount,
    required this.createdAt,
    required this.updatedAt,
  });

  final int categoryId;
  final int itemCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  Widget build(BuildContext context) {
    return _SimpleDetailTable(
      headers: const ['ID', 'Items', 'Created at', 'Updated at'],
      values: [
        '$categoryId',
        '$itemCount',
        '${formatOrderDate(createdAt)}\n${formatOrderTimeWithSeconds(createdAt)}',
        '${formatOrderDate(updatedAt)}\n${formatOrderTimeWithSeconds(updatedAt)}',
      ],
    );
  }
}

class _SimpleDetailTable extends StatelessWidget {
  const _SimpleDetailTable({required this.headers, required this.values});

  final List<String> headers;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    final headerStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: AppColors.logoBlue,
      height: 1.15,
    );
    final bodyStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: const Color(0xFF172033),
      height: 1.15,
    );
    final painter = TextPainter(textDirection: TextDirection.ltr);
    final widths = <double>[];
    for (var i = 0; i < headers.length; i++) {
      painter.text = TextSpan(text: headers[i], style: headerStyle);
      painter.layout();
      var width = painter.width.ceilToDouble() + 2;
      painter.text = TextSpan(text: values[i], style: bodyStyle);
      painter.layout();
      if (painter.width.ceilToDouble() + 2 > width) {
        width = painter.width.ceilToDouble() + 2;
      }
      widths.add(width);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth =
            widths.fold<double>(0, (sum, width) => sum + width) +
            ((widths.length - 1) * 40);
        final effectiveWidth = constraints.maxWidth > contentWidth + 40
            ? constraints.maxWidth
            : contentWidth + 40;
        final trailingSpace = effectiveWidth - (contentWidth + 40);

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: effectiveWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  color: AppColors.logoBlue.withValues(alpha: 0.10),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Row(
                    children: [
                      for (var i = 0; i < headers.length; i++) ...[
                        SizedBox(
                          width: widths[i],
                          child: Text(headers[i], style: headerStyle),
                        ),
                        if (i != headers.length - 1) const SizedBox(width: 40),
                      ],
                      if (trailingSpace > 0) SizedBox(width: trailingSpace),
                    ],
                  ),
                ),
                const Divider(height: 0, thickness: 0.6, color: Color(0xFFE4E7EC)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Row(
                    children: [
                      for (var i = 0; i < values.length; i++) ...[
                        SizedBox(
                          width: widths[i],
                          child: Text(values[i], style: bodyStyle),
                        ),
                        if (i != values.length - 1) const SizedBox(width: 40),
                      ],
                      if (trailingSpace > 0) SizedBox(width: trailingSpace),
                    ],
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
