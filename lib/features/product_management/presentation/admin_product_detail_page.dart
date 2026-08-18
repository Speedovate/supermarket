import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/utils/formatters.dart';
import '../../app_state/app_controller.dart';

class AdminProductDetailPage extends ConsumerWidget {
  const AdminProductDetailPage({super.key, required this.productId});

  final int productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final product = state.products
        .where((item) => item.id == productId)
        .firstOrNull;

    if (product == null) {
      return const Center(child: Text('Product not found.'));
    }

    final categoryName =
        state.categories
            .where((item) => item.id == product.categoryId)
            .firstOrNull
            ?.name ??
        '-';

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
                        SizedBox(
                          width: 64,
                          height: 64,
                          child: ProductPlaceholder(
                            label: '',
                            imageUrl: product.photoUrl,
                            fullRounded: true,
                            backgroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF172033),
                                      height: 1.15,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                product.details,
                                style: const TextStyle(
                                  color: Color(0xFF667085),
                                  height: 1.15,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AdminStateBadge(
                          label: product.isActive ? 'Active' : 'Inactive',
                          color: product.isActive
                              ? AppColors.statusActiveGreen
                              : const Color(0xFF98A2B3),
                        ),
                      ],
                    ),
                  ),
                  const Divider(
                    height: 0,
                    thickness: 0.6,
                    color: Color(0xFFE4E7EC),
                  ),
                  _DetailTable(
                    headers: const [
                      'ID',
                      'Category',
                      'Price',
                      'Created at',
                      'Updated at',
                    ],
                    values: [
                      '${product.id}',
                      categoryName,
                      formatPesos(product.referencePriceCentavos),
                      '${formatOrderDate(product.createdAt)}\n${formatOrderTimeWithSeconds(product.createdAt)}',
                      '${formatOrderDate(product.updatedAt)}\n${formatOrderTimeWithSeconds(product.updatedAt)}',
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailTable extends StatelessWidget {
  const _DetailTable({required this.headers, required this.values});

  final List<String> headers;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final widths = _measureTableWidths(context, headers, values);
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
                          child: Text(
                            headers[i],
                            style: const TextStyle(
                              color: AppColors.logoBlue,
                              fontWeight: FontWeight.w700,
                              height: 1.15,
                            ),
                          ),
                        ),
                        if (i != headers.length - 1) const SizedBox(width: 40),
                      ],
                      if (trailingSpace > 0) SizedBox(width: trailingSpace),
                    ],
                  ),
                ),
                const Divider(
                  height: 0,
                  thickness: 0.6,
                  color: Color(0xFFE4E7EC),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      for (var i = 0; i < values.length; i++) ...[
                        SizedBox(
                          width: widths[i],
                          child: Text(
                            values[i],
                            style: const TextStyle(
                              color: Color(0xFF172033),
                              height: 1.15,
                            ),
                          ),
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

List<double> _measureTableWidths(
  BuildContext context,
  List<String> headers,
  List<String> values,
) {
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
    width = width > painter.width.ceilToDouble() + 2
        ? width
        : painter.width.ceilToDouble() + 2;
    widths.add(width);
  }
  return widths;
}
