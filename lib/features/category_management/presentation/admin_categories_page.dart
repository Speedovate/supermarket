import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_models.dart';
import '../../../core/widgets/admin_scaffold.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../app_state/app_controller.dart';

class AdminCategoriesPage extends ConsumerWidget {
  const AdminCategoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = [...ref.watch(appControllerProvider).categories]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return AdminScaffold(
      title: 'Categories',
      selectedRoute: '/admin/categories',
      actions: [
        TextButton.icon(
          onPressed: () => _showCategoryDialog(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('New Category'),
        ),
      ],
      child: ListView(
        children: [
          if (categories.isEmpty)
            const EmptyStateCard(
              title: 'No categories yet',
              message: 'Create your first product category.',
            )
          else
            SectionCard(
              padding: EdgeInsets.zero,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Sort Order')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: categories.map((category) {
                  final status = category.isArchived
                      ? 'Archived'
                      : category.isActive
                      ? 'Active'
                      : 'Inactive';
                  return DataRow(
                    cells: [
                      DataCell(Text(category.name)),
                      DataCell(Text('${category.sortOrder}')),
                      DataCell(Text(status)),
                      DataCell(
                        IconButton(
                          tooltip: 'Edit category',
                          onPressed: () => _showCategoryDialog(
                            context,
                            ref,
                            initial: category,
                          ),
                          icon: const Icon(Icons.edit_outlined),
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

  Future<void> _showCategoryDialog(
    BuildContext context,
    WidgetRef ref, {
    Category? initial,
  }) async {
    final categories = ref.read(appControllerProvider).categories;
    final nameController = TextEditingController(text: initial?.name ?? '');
    final sortController = TextEditingController(
      text: '${initial?.sortOrder ?? 1}',
    );
    var isActive = initial?.isActive ?? true;
    var isArchived = initial?.isArchived ?? false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(initial == null ? 'New Category' : 'Edit Category'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Category name',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: sortController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Sort order',
                      ),
                    ),
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
                      onChanged: (value) => setState(() => isArchived = value),
                    ),
                  ],
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
                final category = Category(
                  id:
                      initial?.id ??
                      '${(categories
                                .map((item) => int.tryParse(item.id) ?? 0)
                                .fold<int>(0, (max, value) => value > max ? value : max)) + 1}',
                  name: nameController.text.trim(),
                  normalizedName: nameController.text.trim().toLowerCase(),
                  isActive: isActive,
                  isArchived: isArchived,
                  sortOrder: int.tryParse(sortController.text.trim()) ?? 1,
                );
                await ref
                    .read(appControllerProvider.notifier)
                    .saveCategory(category);
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
