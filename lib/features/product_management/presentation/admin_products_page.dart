import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_models.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/admin_scaffold.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../app_state/app_controller.dart';

class AdminProductsPage extends ConsumerStatefulWidget {
  const AdminProductsPage({super.key});

  @override
  ConsumerState<AdminProductsPage> createState() => _AdminProductsPageState();
}

class _AdminProductsPageState extends ConsumerState<AdminProductsPage> {
  String query = '';
  String categoryFilter = 'all';
  String statusFilter = 'active';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final categories =
        state.categories.where((item) => !item.isArchived).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final products = state.products.where((product) {
      final matchesQuery =
          query.trim().isEmpty ||
          product.normalizedName.contains(query.trim().toLowerCase());
      final matchesCategory = categoryFilter == 'all'
          ? true
          : product.categoryId == categoryFilter;
      final matchesStatus = switch (statusFilter) {
        'active' => product.isActive && !product.isArchived,
        'inactive' => !product.isActive && !product.isArchived,
        'archived' => product.isArchived,
        _ => true,
      };
      return matchesQuery && matchesCategory && matchesStatus;
    }).toList();

    return AdminScaffold(
      title: 'Products',
      selectedRoute: '/admin/products',
      actions: [
        TextButton.icon(
          onPressed: () => _showProductDialog(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('New Product'),
        ),
      ],
      child: ListView(
        children: [
          SectionCard(
            child: Wrap(
              runSpacing: 12,
              spacing: 12,
              children: [
                SizedBox(
                  width: 280,
                  child: TextField(
                    onChanged: (value) => setState(() => query = value),
                    decoration: const InputDecoration(
                      labelText: 'Search by name',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    initialValue: categoryFilter,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: [
                      const DropdownMenuItem(
                        value: 'all',
                        child: Text('All categories'),
                      ),
                      ...categories.map(
                        (item) => DropdownMenuItem(
                          value: item.id,
                          child: Text(item.name),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => categoryFilter = value ?? 'all'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    initialValue: statusFilter,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(
                        value: 'inactive',
                        child: Text('Inactive'),
                      ),
                      DropdownMenuItem(
                        value: 'archived',
                        child: Text('Archived'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => statusFilter = value ?? 'active'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (products.isEmpty)
            const EmptyStateCard(
              title: 'No products found',
              message: 'Adjust filters or add a new product.',
            )
          else
            SectionCard(
              padding: EdgeInsets.zero,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Product')),
                  DataColumn(label: Text('Category')),
                  DataColumn(label: Text('Unit')),
                  DataColumn(label: Text('Price')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: products.map((product) {
                  final status = product.isArchived
                      ? 'Archived'
                      : product.isActive
                      ? 'Active'
                      : 'Inactive';
                  return DataRow(
                    cells: [
                      DataCell(Text(product.name)),
                      DataCell(Text(product.categoryNameSnapshot)),
                      DataCell(Text(product.displayUnit)),
                      DataCell(
                        Text(formatPesos(product.referencePriceCentavos)),
                      ),
                      DataCell(Text(status)),
                      DataCell(
                        Wrap(
                          spacing: 8,
                          children: [
                            IconButton(
                              tooltip: 'Edit product',
                              onPressed: () => _showProductDialog(
                                context,
                                ref,
                                initial: product,
                              ),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showProductDialog(
    BuildContext context,
    WidgetRef ref, {
    Product? initial,
  }) async {
    final state = ref.read(appControllerProvider);
    final categories =
        state.categories.where((item) => !item.isArchived).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
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
    var isArchived = initial?.isArchived ?? false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(initial == null ? 'New Product' : 'Edit Product'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                        ),
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
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active'),
                        value: isActive,
                        onChanged: (value) => setState(() => isActive = value),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Archived'),
                        value: isArchived,
                        onChanged: (value) =>
                            setState(() => isArchived = value),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final parsedPrice =
                    (double.tryParse(priceController.text.trim()) ?? 0) * 100;
                final product = Product(
                  id:
                      initial?.id ??
                      '${(state.products
                                .map((item) => int.tryParse(item.id) ?? 0)
                                .fold<int>(0, (max, value) => value > max ? value : max)) + 1}',
                  name: nameController.text,
                  categoryId: selectedCategory,
                  categoryNameSnapshot: '',
                  quantity: quantityController.text,
                  unit: unitController.text,
                  type: typeController.text,
                  referencePriceCentavos: parsedPrice.round(),
                  priceUpdatedAt: initial?.priceUpdatedAt ?? DateTime(2026, 7, 31),
                  isActive: isActive,
                  isArchived: isArchived,
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
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}
