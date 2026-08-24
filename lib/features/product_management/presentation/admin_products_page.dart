import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/app_models.dart';
import '../../../core/utils/catalog_excel.dart';
import '../../../core/utils/download_bytes.dart';
import '../../../core/utils/pick_excel_file.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../app_state/app_controller.dart';
import 'admin_product_dialog.dart';

class AdminProductsPage extends ConsumerStatefulWidget {
  const AdminProductsPage({super.key});

  @override
  ConsumerState<AdminProductsPage> createState() => _AdminProductsPageState();
}

class _AdminProductsPageState extends ConsumerState<AdminProductsPage> {
  static const double _filtersMenuWidth = 248;
  static const double _filtersContentHorizontalPadding = 16;
  static const double _columnWidthAllowance = 2;
  static const double _dateHeaderExtraAllowance = 2;
  static const double _actionHitSize = 34;
  static double get _actionsWidth => _actionHitSize * 4;
  static double get _filtersFieldWidth =>
      _filtersMenuWidth - (_filtersContentHorizontalPadding * 2);

  final TextEditingController _queryController = TextEditingController();
  final GlobalKey _mobileFiltersAnchorKey = GlobalKey();
  final GlobalKey _desktopFiltersAnchorKey = GlobalKey();
  final LayerLink _mobileFiltersLayerLink = LayerLink();
  final LayerLink _desktopFiltersLayerLink = LayerLink();
  String query = '';
  DateTime? createdAtFilter;
  DateTime? updatedAtFilter;
  int? categoryFilter;
  String? statusFilter;
  String? priceSort;
  String? nameSort;
  String? soldSort;

  _ResolvedImportedCatalog _resolveImportedCatalog({
    required ImportedCatalogWorkbook imported,
    required _ProductImportMode importMode,
  }) {
    final now = DateTime.now();
    final state = ref.read(appControllerProvider);

    if (importMode == _ProductImportMode.replace) {
      final categories = <Category>[];
      final categoryIdByNormalizedName = <String, int>{};
      var nextCategoryId = 1;
      for (final row in imported.products) {
        final normalizedCategory = row.categoryName.trim().toLowerCase();
        if (normalizedCategory.isEmpty ||
            categoryIdByNormalizedName.containsKey(normalizedCategory)) {
          continue;
        }
        categoryIdByNormalizedName[normalizedCategory] = nextCategoryId;
        categories.add(
          Category(
            id: nextCategoryId,
            name: row.categoryName.trim(),
            normalizedName: normalizedCategory,
            isActive: true,
            createdAt: now,
            updatedAt: now,
          ),
        );
        nextCategoryId++;
      }

      final products = <Product>[];
      for (var index = 0; index < imported.products.length; index++) {
        final row = imported.products[index];
        final normalizedCategory = row.categoryName.trim().toLowerCase();
        final createdAt = row.createdAt ?? now;
        final updatedAt = row.updatedAt ?? createdAt;
        products.add(
          Product(
            id: index + 1,
            active: true,
            createdAt: createdAt,
            updatedAt: updatedAt,
            name: row.name.trim(),
            category: normalizedCategory.isEmpty
                ? 0
                : (categoryIdByNormalizedName[normalizedCategory] ?? 0),
            details: row.details.trim(),
            price: row.priceCentavos,
            sold: 0,
          ),
        );
      }

      return _ResolvedImportedCatalog(
        categories: categories,
        products: products,
      );
    }

    final categories = [...state.categories];
    final categoryIdByNormalizedName = {
      for (final category in categories) category.normalizedName: category.id,
    };
    var nextCategoryId = categories.isEmpty
        ? 1
        : categories.map((item) => item.id).reduce(math.max) + 1;
    for (final row in imported.products) {
      final categoryName = row.categoryName.trim();
      final normalizedCategory = categoryName.toLowerCase();
      if (normalizedCategory.isEmpty ||
          categoryIdByNormalizedName.containsKey(normalizedCategory)) {
        continue;
      }
      categoryIdByNormalizedName[normalizedCategory] = nextCategoryId;
      categories.add(
        Category(
          id: nextCategoryId,
          name: categoryName,
          normalizedName: normalizedCategory,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
      );
      nextCategoryId++;
    }

    var nextProductId = state.products.isEmpty
        ? 1
        : state.products.map((item) => item.id).reduce(math.max) + 1;
    final products = <Product>[];
    for (final row in imported.products) {
      final normalizedCategory = row.categoryName.trim().toLowerCase();
      final createdAt = row.createdAt ?? now;
      final updatedAt = row.updatedAt ?? createdAt;
      products.add(
        Product(
          id: nextProductId++,
          active: true,
          createdAt: createdAt,
          updatedAt: updatedAt,
          name: row.name.trim(),
          category: normalizedCategory.isEmpty
              ? 0
              : (categoryIdByNormalizedName[normalizedCategory] ?? 0),
          details: row.details.trim(),
          price: row.priceCentavos,
          sold: 0,
        ),
      );
    }

    return _ResolvedImportedCatalog(categories: categories, products: products);
  }

  Future<void> _showProductFileActionsDialog(BuildContext context) async {
    var selected = _ProductFileAction.importProducts;
    var importMode = _ProductImportMode.additional;
    String? selectedFileName;
    Uint8List? selectedBytes;
    String? inlineError;
    final result = await showDialog<_ProductFileActionResult>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> pickWorkbook() async {
              final picked = await pickExcelFile();
              if (picked == null) {
                return;
              }
              setState(() {
                selectedFileName = picked.name;
                selectedBytes = Uint8List.fromList(picked.bytes);
                inlineError = null;
              });
            }

            return AppModalFrame(
              title: '${selected.label}?',
              actions: [
                AppModalButton(
                  label: 'Close',
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                const SizedBox(width: 10),
                AppModalButton(
                  label: selected.actionLabel,
                  isPrimary: true,
                  onPressed: () {
                    if (selected == _ProductFileAction.importProducts &&
                        selectedBytes == null) {
                      setState(() {
                        inlineError = 'Excel file is required.';
                      });
                      return;
                    }
                    Navigator.of(dialogContext).pop(
                      _ProductFileActionResult(
                        action: selected,
                        fileName: selectedFileName,
                        bytes: selectedBytes,
                        importMode: importMode,
                      ),
                    );
                  },
                ),
              ],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RadioGroup<_ProductFileAction>(
                    groupValue: selected,
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        selected = value;
                        inlineError = null;
                      });
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final action in _ProductFileAction.values)
                          RadioListTile<_ProductFileAction>(
                            value: action,
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: const VisualDensity(
                              horizontal: -4,
                              vertical: -4,
                            ),
                            title: Text(action.label),
                          ),
                      ],
                    ),
                  ),
                  if (selected == _ProductFileAction.importProducts) ...[
                    const SizedBox(height: 12),
                    MousePressable(
                      onTap: pickWorkbook,
                      borderRadius: BorderRadius.circular(16),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: const Icon(
                                  Icons.upload_rounded,
                                  size: 18,
                                  color: AppColors.logoBlue,
                                ),
                              ),
                            ],
                          ),
                        ),
                        child: Text(
                          selectedFileName ?? 'Upload Excel File',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: const Color(0xFF172033),
                                height: 1.15,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    IgnorePointer(
                      ignoring: false,
                      child: RadioGroup<_ProductImportMode>(
                        groupValue: importMode,
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            importMode = value;
                            inlineError = null;
                          });
                        },
                        child: Row(
                          children: [
                            Expanded(
                              child: RadioListTile<_ProductImportMode>(
                                value: _ProductImportMode.additional,
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: const VisualDensity(
                                  horizontal: -4,
                                  vertical: -4,
                                ),
                                title: const Text('Additional'),
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<_ProductImportMode>(
                                value: _ProductImportMode.replace,
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: const VisualDensity(
                                  horizontal: -4,
                                  vertical: -4,
                                ),
                                title: const Text('Replace'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    AppModalBodyText(
                      importMode == _ProductImportMode.replace
                          ? 'Importing will override all current products and categories.'
                          : 'Importing will append new products and categories only.',
                    ),
                    if (inlineError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        inlineError!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFE31E24),
                          fontWeight: FontWeight.w600,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            );
          },
        );
      },
    );
    if (result == null || !mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(this.context);
    messenger.clearSnackBars();
    var importStage = 'preparing import';
    try {
      if (result.action == _ProductFileAction.exportProducts) {
        final state = ref.read(appControllerProvider);
        final workbook = buildCatalogWorkbook(
          categories: state.categories,
          products: state.products,
        );
        final date = DateTime.now();
        final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
        final period = date.hour >= 12 ? 'PM' : 'AM';
        final fileName =
            'Products ${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year} ${hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:$period.xlsx';
        await downloadBytes(
          bytes: workbook,
          fileName: fileName,
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
        messenger.showSnackBar(successSnackBar('Products exported.'));
        return;
      }

      final importBytes = result.bytes;
      if (importBytes == null) {
        messenger.showSnackBar(errorSnackBar('Excel file is required.'));
        return;
      }
      importStage = 'parsing the Excel file';
      final imported = parseCatalogWorkbook(importBytes);
      importStage = 'resolving categories and products';
      final resolvedImport = _resolveImportedCatalog(
        imported: imported,
        importMode: result.importMode,
      );
      importStage = 'confirming the import';
      final shouldImport = await _showImportProductsConfirmationDialog(
        this.context,
        importMode: result.importMode,
        categoryCount: result.importMode == _ProductImportMode.replace
            ? resolvedImport.categories.length
            : resolvedImport.categories.length -
                  ref.read(appControllerProvider).categories.length,
        productCount: imported.products.length,
      );
      if (shouldImport != true || !mounted) {
        return;
      }
      if (result.importMode == _ProductImportMode.replace) {
        importStage = 'replacing current categories and products';
        await ref
            .read(appControllerProvider.notifier)
            .replaceCategoriesAndProducts(
              categories: resolvedImport.categories,
              products: resolvedImport.products,
            );
      } else {
        final currentState = ref.read(appControllerProvider);
        final existingCategoryIds = currentState.categories
            .map((item) => item.id)
            .toSet();
        final existingProductKeys = currentState.products
            .map(
              (item) =>
                  '${item.name.trim().toLowerCase()}|||${item.details.trim().toLowerCase()}',
            )
            .toSet();
        final duplicateImportedKeys = <String>{};
        final seenImportedKeys = <String>{};
        final duplicateExistingLabels = <String>{};
        for (final product in resolvedImport.products) {
          final key =
              '${product.name.trim().toLowerCase()}|||${product.details.trim().toLowerCase()}';
          if (!seenImportedKeys.add(key)) {
            duplicateImportedKeys.add(
              '${product.name.trim()} | ${product.details.trim()}',
            );
          }
          if (existingProductKeys.contains(key)) {
            duplicateExistingLabels.add(
              '${product.name.trim()} | ${product.details.trim()}',
            );
          }
        }
        if (duplicateImportedKeys.isNotEmpty ||
            duplicateExistingLabels.isNotEmpty) {
          final parts = <String>[
            if (duplicateImportedKeys.isNotEmpty)
              'duplicate imported product${duplicateImportedKeys.length == 1 ? '' : 's'}: ${duplicateImportedKeys.join(', ')}',
            if (duplicateExistingLabels.isNotEmpty)
              'existing product duplicate${duplicateExistingLabels.length == 1 ? '' : 's'}: ${duplicateExistingLabels.join(', ')}',
          ];
          throw CatalogWorkbookException(
            'Additional import prevents duplicate name + details combinations. Found ${parts.join(' and ')}.',
          );
        }
        importStage = 'saving imported categories';
        for (final category in resolvedImport.categories) {
          if (existingCategoryIds.contains(category.id)) {
            continue;
          }
          await ref.read(appControllerProvider.notifier).saveCategory(category);
        }
        importStage = 'saving imported products';
        for (final product in resolvedImport.products) {
          await ref.read(appControllerProvider.notifier).saveProduct(product);
        }
      }
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        successSnackBar(
          'Imported ${imported.products.length} product${imported.products.length == 1 ? '' : 's'}.',
        ),
      );
    } on CatalogWorkbookException catch (error) {
      messenger.showSnackBar(errorSnackBar(error.message));
    } on UnsupportedError catch (error) {
      messenger.showSnackBar(errorSnackBar('$error'));
    } catch (error, stackTrace) {
      debugPrint(
        'Products import failed during $importStage.\n'
        'File: ${result.fileName ?? 'unknown'}\n'
        'Mode: ${result.importMode.name}\n'
        'Error: $error\n'
        '$stackTrace',
      );
      messenger.showSnackBar(
        errorSnackBar(
          'Import failed while $importStage. '
          '${'$error'.replaceFirst('Exception: ', '').replaceFirst('Bad state: ', '')}',
        ),
      );
    }
  }

  Future<bool?> _showImportProductsConfirmationDialog(
    BuildContext context, {
    required _ProductImportMode importMode,
    required int categoryCount,
    required int productCount,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AppModalFrame(
          title: 'Import Products?',
          actions: [
            AppModalButton(
              label: 'Close',
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            const SizedBox(width: 10),
            AppModalButton(
              label: importMode == _ProductImportMode.replace
                  ? 'Replace'
                  : 'Additional',
              isPrimary: true,
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
          child: AppModalBodyText(
            importMode == _ProductImportMode.replace
                ? 'This will override all current products and categories with $categoryCount categor${categoryCount == 1 ? 'y' : 'ies'} and $productCount product${productCount == 1 ? '' : 's'}.'
                : 'This will append $categoryCount new categor${categoryCount == 1 ? 'y' : 'ies'} and $productCount new product${productCount == 1 ? '' : 's'} without overriding existing data.',
          ),
        );
      },
    );
  }

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
    final categories = ref.read(appControllerProvider).categories;
    query = uri.queryParameters['query'] ?? uri.queryParameters['q'] ?? '';
    if (_queryController.text != query) {
      _queryController.value = TextEditingValue(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
      );
    }
    createdAtFilter = _parseRouteDate(
      uri.queryParameters['filters[created_at]'],
    );
    updatedAtFilter = _parseRouteDate(
      uri.queryParameters['filters[updated_at]'],
    );
    categoryFilter = _parseCategoryFilter(
      uri.queryParameters['filters[category]'],
      categories,
    );
    statusFilter = _normalizeNullable(uri.queryParameters['filters[status]']);
    priceSort = _normalizeNullable(uri.queryParameters['filters[price]']);
    nameSort = _normalizeNullable(uri.queryParameters['filters[name]']);
    soldSort = _normalizeNullable(uri.queryParameters['filters[sold]']);
  }

  Future<void> _showFiltersMenu({
    required GlobalKey anchorKey,
    required LayerLink anchorLink,
    required List<Product> products,
    required List<Category> categories,
  }) async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      return;
    }
    final anchorBox = anchorKey.currentContext?.findRenderObject() as RenderBox?;
    final overlayState = Overlay.of(context);
    final overlayBox = overlayState.context.findRenderObject() as RenderBox?;
    if (anchorBox == null ||
        overlayBox == null ||
        !anchorBox.hasSize ||
        !overlayBox.hasSize) {
      return;
    }
    final mediaQuery = MediaQuery.of(context);
    final anchorTopLeft = anchorBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    final anchorBottom = anchorTopLeft.dy + anchorBox.size.height;
    final horizontalInset = 0.0;
    final menuWidth = math.min(
      _filtersMenuWidth,
      math.max(0.0, overlayBox.size.width - (horizontalInset * 2)),
    );
    final desiredLeft = anchorTopLeft.dx.clamp(
      horizontalInset,
      math.max(horizontalInset, overlayBox.size.width - menuWidth - horizontalInset),
    );
    final followerOffsetX = desiredLeft - anchorTopLeft.dx;
    final maxMenuHeight = math.max(
      0.0,
      overlayBox.size.height -
          mediaQuery.padding.bottom -
          anchorBottom -
          28,
    );

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close filters',
      barrierColor: Colors.transparent,
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => Navigator.of(dialogContext).pop(),
                ),
              ),
              CompositedTransformFollower(
                link: anchorLink,
                showWhenUnlinked: false,
                targetAnchor: Alignment.bottomLeft,
                followerAnchor: Alignment.topLeft,
                offset: Offset(followerOffsetX, 0),
                child: Material(
                  color: Colors.transparent,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: menuWidth,
                      maxHeight: maxMenuHeight <= 0
                          ? overlayBox.size.height
                          : maxMenuHeight,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 24,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        child: SizedBox(
                          width: menuWidth,
                          child: _buildFiltersMenu(
                            context: dialogContext,
                            anchorKey: anchorKey,
                            products: products,
                            categories: categories,
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
      },
      transitionDuration: Duration.zero,
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          child,
    );
  }

  void _setFilters(VoidCallback update) {
    setState(update);
    _updateRouteFilters();
  }

  void _updateRouteFilters() {
    final currentUri = GoRouterState.of(context).uri;
    final categories = ref.read(appControllerProvider).categories;
    final params = <String, String>{};
    if (query.trim().isNotEmpty) {
      params['query'] = query.trim();
    }
    if (categoryFilter != null) {
      final category = categories.cast<Category?>().firstWhere(
        (item) => item?.id == categoryFilter,
        orElse: () => null,
      );
      if (category != null) {
        params['filters[category]'] = _slugify(category.name);
      } else {
        params['filters[category]'] = '$categoryFilter';
      }
    }
    if (statusFilter != null) {
      params['filters[status]'] = statusFilter!;
    }
    if (priceSort != null) {
      params['filters[price]'] = priceSort!;
    }
    if (nameSort != null) {
      params['filters[name]'] = nameSort!;
    }
    if (soldSort != null) {
      params['filters[sold]'] = soldSort!;
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
    final categories = [...state.categories]
      ..sort((a, b) {
        final nameCompare = a.name.toLowerCase().compareTo(
          b.name.toLowerCase(),
        );
        if (nameCompare != 0) {
          return nameCompare;
        }
        return a.id.compareTo(b.id);
      });
    final categoryById = {
      for (final category in categories) category.id: category.name,
    };
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
    final products = [...state.products];
    final filteredProducts =
        products.where((product) {
          final categoryName = categoryById[product.categoryId] ?? '';
          final matchesQuery =
              normalizedQuery.isEmpty ||
              product.name.toLowerCase().contains(normalizedQuery) ||
              product.details.toLowerCase().contains(normalizedQuery) ||
              categoryName.toLowerCase().contains(normalizedQuery) ||
              '${product.id}'.contains(normalizedQuery);
          final createdAt = product.createdAt;
          final updatedAt = product.updatedAt;
          final matchesCreatedAt =
              createdAtFilter == null ||
              _isSameDay(createdAt, createdAtFilter!);
          final matchesUpdatedAt =
              updatedAtFilter == null ||
              _isSameDay(updatedAt, updatedAtFilter!);
          final matchesCategory =
              categoryFilter == null || product.categoryId == categoryFilter;
          final matchesStatus = switch (statusFilter) {
            'active' => product.isActive,
            'inactive' => !product.isActive,
            _ => true,
          };
          return matchesQuery &&
              matchesCreatedAt &&
              matchesUpdatedAt &&
              matchesCategory &&
              matchesStatus;
        }).toList()..sort((a, b) {
          if (priceSort != null) {
            final priceCompare = priceSort == 'low_high'
                ? a.referencePriceCentavos.compareTo(b.referencePriceCentavos)
                : b.referencePriceCentavos.compareTo(a.referencePriceCentavos);
            if (priceCompare != 0) {
              return priceCompare;
            }
          }
          if (nameSort != null) {
            final nameCompare = nameSort == 'a_z'
                ? a.name.toLowerCase().compareTo(b.name.toLowerCase())
                : b.name.toLowerCase().compareTo(a.name.toLowerCase());
            if (nameCompare != 0) {
              return nameCompare;
            }
          }
          if (soldSort != null) {
            final soldCompare = soldSort == 'few_many'
                ? a.sold.compareTo(b.sold)
                : b.sold.compareTo(a.sold);
            if (soldCompare != 0) {
              return soldCompare;
            }
          }
          return b.id.compareTo(a.id);
        });

    final widths = _computeProductColumnWidths(
      screenWidth: screenWidth,
      products: products,
      categoryById: categoryById,
      headerStyle: headerStyle,
      bodyStyle: bodyStyle,
      gap: gap,
    );
    final activeFilterCount =
        (createdAtFilter == null ? 0 : 1) +
        (updatedAtFilter == null ? 0 : 1) +
        (categoryFilter == null ? 0 : 1) +
        (statusFilter == null ? 0 : 1) +
        (priceSort == null ? 0 : 1) +
        (nameSort == null ? 0 : 1) +
        (soldSort == null ? 0 : 1);
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
                            onChanged: (value) =>
                                _setFilters(() => query = value),
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
                        MousePressable(
                          onTap: () => _showFiltersMenu(
                            anchorKey: _mobileFiltersAnchorKey,
                            anchorLink: _mobileFiltersLayerLink,
                            products: products,
                            categories: categories,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          child: CompositedTransformTarget(
                            link: _mobileFiltersLayerLink,
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
                          ),
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
                            onChanged: (value) =>
                                _setFilters(() => query = value),
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
                        MousePressable(
                          onTap: () => _showFiltersMenu(
                            anchorKey: _desktopFiltersAnchorKey,
                            anchorLink: _desktopFiltersLayerLink,
                            products: products,
                            categories: categories,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          child: CompositedTransformTarget(
                            link: _desktopFiltersLayerLink,
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
                                  const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            SizedBox(width: isMobile ? 8 : 12),
            MousePressable(
              onTap: () => _showProductFileActionsDialog(context),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: isMobile ? toolbarActionSize : 48,
                height: isMobile ? toolbarActionSize : 48,
                decoration: BoxDecoration(
                  color: AppColors.logoBlue,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.insert_drive_file_outlined,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(width: isMobile ? 8 : 12),
            MousePressable(
              onTap: () => _showProductDialog(context, ref),
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
                        'New Product',
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
                  widths.details +
                  gap +
                  widths.category +
                  gap +
                  widths.price +
                  gap +
                  widths.sold +
                  gap +
                  widths.createdAt +
                  gap +
                  widths.updatedAt +
                  gap +
                  _actionsWidth;
              final effectiveTableWidth =
                  constraints.maxWidth > contentWidth + 40
                  ? constraints.maxWidth
                  : contentWidth + 40;
              final trailingSpace = effectiveTableWidth - (contentWidth + 40);
              const headerHeight = 53.0;
              const dividerHeight = 0.6;
              const emptyStateHeight = 232.0;
              final rowHeights = filteredProducts
                  .map(
                    (product) => _measureProductRowHeight(
                      product: product,
                      categoryName: categoryById[product.categoryId] ?? '',
                      widths: widths,
                      bodyStyle: bodyStyle,
                    ),
                  )
                  .toList();
              final contentHeightEstimate = filteredProducts.isEmpty
                  ? emptyStateHeight
                  : rowHeights.fold<double>(0, (sum, height) => sum + height) +
                        math.max(0, filteredProducts.length - 1) *
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
                        width: effectiveTableWidth,
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
                              child: _ProductHeaderRow(
                                widths: widths,
                                trailingSpace: trailingSpace,
                                isEmpty: filteredProducts.isEmpty,
                              ),
                            ),
                            const Divider(
                              height: 0,
                              thickness: 0.6,
                              color: Color(0xFFE4E7EC),
                            ),
                            if (filteredProducts.isEmpty)
                              if (shouldScrollBody)
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(16),
                                      bottomRight: Radius.circular(16),
                                    ),
                                    child: const EmptyStateCard(
                                      title: 'No products found',
                                      message:
                                          'Adjust filters or add a new product.',
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
                                    title: 'No products found',
                                    message:
                                        'Adjust filters or add a new product.',
                                    showBorder: false,
                                  ),
                                )
                            else
                              shouldScrollBody
                                  ? Expanded(
                                      child: ListView.separated(
                                        padding: EdgeInsets.zero,
                                        itemCount: filteredProducts.length,
                                        itemBuilder: (context, i) => _ProductRow(
                                          product: filteredProducts[i],
                                          categoryName:
                                              categoryById[filteredProducts[i]
                                                  .categoryId] ??
                                              '',
                                          widths: widths,
                                          trailingSpace: trailingSpace,
                                          isLast:
                                              i == filteredProducts.length - 1,
                                          onPreview: () =>
                                              _showProductPreviewDialog(
                                                context,
                                                filteredProducts[i],
                                              ),
                                          onEdit: () => _showProductDialog(
                                            context,
                                            ref,
                                            initial: filteredProducts[i],
                                          ),
                                          onToggleActive: () async {
                                            final product = filteredProducts[i];
                                            final nextIsActive =
                                                !product.isActive;
                                            final shouldToggle =
                                                await _showToggleProductStatusDialog(
                                                  context,
                                                  product.name,
                                                  nextIsActive,
                                                );
                                            if (shouldToggle == true) {
                                              await ref
                                                  .read(
                                                    appControllerProvider
                                                        .notifier,
                                                  )
                                                  .saveProduct(
                                                    product.copyWith(
                                                      isActive: nextIsActive,
                                                      updatedAt: DateTime.now(),
                                                    ),
                                                  );
                                            }
                                          },
                                          onDelete: () => _deleteProduct(
                                            context,
                                            filteredProducts[i],
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
                                        for (
                                          var i = 0;
                                          i < filteredProducts.length;
                                          i++
                                        ) ...[
                                          _ProductRow(
                                            product: filteredProducts[i],
                                            categoryName:
                                                categoryById[filteredProducts[i]
                                                    .categoryId] ??
                                                '',
                                            widths: widths,
                                            trailingSpace: trailingSpace,
                                            isLast:
                                                i ==
                                                filteredProducts.length - 1,
                                            onPreview: () =>
                                                _showProductPreviewDialog(
                                                  context,
                                                  filteredProducts[i],
                                                ),
                                            onEdit: () => _showProductDialog(
                                              context,
                                              ref,
                                              initial: filteredProducts[i],
                                            ),
                                            onToggleActive: () async {
                                              final product =
                                                  filteredProducts[i];
                                              final nextIsActive =
                                                  !product.isActive;
                                              final shouldToggle =
                                                  await _showToggleProductStatusDialog(
                                                    context,
                                                    product.name,
                                                    nextIsActive,
                                                  );
                                              if (shouldToggle == true) {
                                                await ref
                                                    .read(
                                                      appControllerProvider
                                                          .notifier,
                                                    )
                                                    .saveProduct(
                                                      product.copyWith(
                                                        isActive: nextIsActive,
                                                        updatedAt:
                                                            DateTime.now(),
                                                      ),
                                                    );
                                              }
                                            },
                                            onDelete: () => _deleteProduct(
                                              context,
                                              filteredProducts[i],
                                            ),
                                          ),
                                          if (i != filteredProducts.length - 1)
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
    required List<Product> products,
    required List<Category> categories,
  }) {
    final menuContent = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FiltersSection(
          title: 'Category',
          child: SizedBox(
            width: _filtersFieldWidth,
            child: AppPopupMenuField<int>(
              value: categoryFilter,
              decoration: _filterDropdownDecoration('Category'),
              options: [
                const AppPopupMenuOption<int?>(value: null, label: 'Any'),
                ...categories.map(
                  (item) => AppPopupMenuOption<int?>(
                    value: item.id,
                    label: item.name,
                  ),
                ),
              ],
              onChanged: (value) {
                _setFilters(() => categoryFilter = value);
              },
            ),
          ),
        ),
        const _FilterDivider(),
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
          title: 'Sold',
          child: SizedBox(
            width: _filtersFieldWidth,
            child: AppPopupMenuField<String>(
              value: soldSort,
              decoration: _filterDropdownDecoration('Sold'),
              options: const [
                AppPopupMenuOption<String?>(value: null, label: 'Any'),
                AppPopupMenuOption<String?>(
                  value: 'few_many',
                  label: 'Few-Many',
                ),
                AppPopupMenuOption<String?>(
                  value: 'many_few',
                  label: 'Many-Few',
                ),
              ],
              onChanged: (value) {
                _setFilters(() => soldSort = value);
              },
            ),
          ),
        ),
        const _FilterDivider(),
        _FiltersSection(
          title: 'Price',
          child: SizedBox(
            width: _filtersFieldWidth,
            child: AppPopupMenuField<String>(
              value: priceSort,
              decoration: _filterDropdownDecoration('Price'),
              options: const [
                AppPopupMenuOption<String?>(value: null, label: 'Any'),
                AppPopupMenuOption<String?>(
                  value: 'low_high',
                  label: 'Low-High',
                ),
                AppPopupMenuOption<String?>(
                  value: 'high_low',
                  label: 'High-Low',
                ),
              ],
              onChanged: (value) {
                _setFilters(() => priceSort = value);
              },
            ),
          ),
        ),
        const _FilterDivider(),
        _FiltersSection(
          title: 'Name',
          child: SizedBox(
            width: _filtersFieldWidth,
            child: AppPopupMenuField<String>(
              value: nameSort,
              decoration: _filterDropdownDecoration('Name'),
              options: const [
                AppPopupMenuOption<String?>(value: null, label: 'Any'),
                AppPopupMenuOption<String?>(value: 'a_z', label: 'A-Z'),
                AppPopupMenuOption<String?>(value: 'z_a', label: 'Z-A'),
              ],
              onChanged: (value) {
                _setFilters(() => nameSort = value);
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
                final dates = products.map((item) => item.createdAt).toList();
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
                final dates = products.map((item) => item.updatedAt).toList();
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
                    categoryFilter = null;
                    statusFilter = null;
                    priceSort = null;
                    nameSort = null;
                    soldSort = null;
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
    );
    return menuContent;
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

  int? _parseCategoryFilter(String? raw, List<Category> categories) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final parsedId = int.tryParse(raw);
    if (parsedId != null) {
      return parsedId;
    }
    final normalized = raw.trim().toLowerCase();
    final category = categories.cast<Category?>().firstWhere(
      (item) =>
          item != null &&
          (item.name.toLowerCase() == normalized ||
              _slugify(item.name) == normalized),
      orElse: () => null,
    );
    return category?.id;
  }

  String _slugify(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');

  _ProductColumnWidths _computeProductColumnWidths({
    required double screenWidth,
    required List<Product> products,
    required Map<int, String> categoryById,
    required TextStyle headerStyle,
    required TextStyle bodyStyle,
    required double gap,
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
      TextStyle? valuesStyle,
    }) {
      final width = maxWidth(header, values, valuesStyle: valuesStyle);
      return width > max ? max : width;
    }

    return _ProductColumnWidths(
      gap: gap,
      id: maxWidth('ID', products.map((item) => '${item.id}')),
      name: cappedMaxWidth(
        'Name',
        products.map((item) => item.name),
        max: screenWidth < 700 ? 144 : 176,
      ),
      details: cappedMaxWidth(
        'Details',
        products.map((item) => item.details),
        max: screenWidth < 700 ? 132 : 164,
      ),
      category: cappedMaxWidth(
        'Category',
        products.map((item) => categoryById[item.categoryId] ?? ''),
        max: screenWidth < 700 ? 128 : 156,
      ),
      price: maxWidth(
        'Price',
        products.map((item) => formatPesos(item.referencePriceCentavos)),
      ),
      sold: maxWidth('Sold', products.map((item) => '${item.sold}')) + 8,
      createdAt:
          maxWidth(
            'Created at',
            products.map(
              (item) =>
                  '${formatOrderDate(item.createdAt)}\n${formatOrderTimeWithSeconds(item.createdAt)}',
            ),
          ) +
          _dateHeaderExtraAllowance,
      updatedAt:
          maxWidth(
            'Updated at',
            products.map(
              (item) =>
                  '${formatOrderDate(item.updatedAt)}\n${formatOrderTimeWithSeconds(item.updatedAt)}',
            ),
          ) +
          _dateHeaderExtraAllowance,
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

  double _measureProductRowHeight({
    required Product product,
    required String categoryName,
    required _ProductColumnWidths widths,
    required TextStyle bodyStyle,
  }) {
    final createdAtText =
        '${formatOrderDate(product.createdAt)}\n${formatOrderTimeWithSeconds(product.createdAt)}';
    final updatedAtText =
        '${formatOrderDate(product.updatedAt)}\n${formatOrderTimeWithSeconds(product.updatedAt)}';

    final tallestContent = <double>[
      _measureTextHeight('${product.id}', bodyStyle, widths.id, maxLines: 1),
      _measureTextHeight(product.name, bodyStyle, widths.name),
      _measureTextHeight(
        product.details,
        bodyStyle,
        widths.details,
        maxLines: 1,
      ),
      _measureTextHeight(categoryName, bodyStyle, widths.category, maxLines: 1),
      _measureTextHeight(
        formatPesos(product.referencePriceCentavos),
        bodyStyle,
        widths.price,
        maxLines: 1,
      ),
      _measureTextHeight(
        '${product.sold}',
        bodyStyle,
        widths.sold,
        maxLines: 1,
      ),
      _measureTextHeight(
        createdAtText,
        bodyStyle,
        widths.createdAt,
        maxLines: 2,
      ),
      _measureTextHeight(
        updatedAtText,
        bodyStyle,
        widths.updatedAt,
        maxLines: 2,
      ),
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

  Future<void> _deleteProduct(BuildContext context, Product product) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AppModalFrame(
          title: 'Remove Product?',
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
          child: AppModalBodyText('${product.name.trim()} will be deleted.'),
        );
      },
    );
    if (shouldDelete != true || !mounted) {
      return;
    }
    await ref.read(appControllerProvider.notifier).deleteProduct(product.id);
  }

  Future<bool?> _showToggleProductStatusDialog(
    BuildContext context,
    String productName,
    bool nextIsActive,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AppModalFrame(
          title: nextIsActive ? 'Activate Product?' : 'Deactivate Product?',
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
                ? '${productName.trim()} will be activated.'
                : '${productName.trim()} will be deactivated.',
          ),
        );
      },
    );
  }

  Future<void> _showProductPreviewDialog(
    BuildContext context,
    Product product,
  ) {
    final titleStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w800,
      height: 1.15,
    );
    final unitStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      color: const Color(0xFF667085),
      fontSize: 12,
      height: 1.15,
    );
    final priceStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
      fontSize: 16,
      color: AppColors.logoBlue,
      fontWeight: FontWeight.w800,
      height: 1.15,
    );
    final asOfStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      color: const Color(0xFF667085),
      fontSize: 11.5,
      height: 1.15,
    );

    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AppModalFrame(
          title: '',
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
              Center(
                child: SizedBox(
                  width: 300,
                  height: 300,
                  child: ProductPlaceholder(
                    fullRounded: true,
                    label: product.name,
                    posterMode: true,
                    imageUrl: product.photoUrl,
                    imageFit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(product.name, style: titleStyle),
              const SizedBox(height: 2),
              Text(product.displayUnit, style: unitStyle),
              const SizedBox(height: 12),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: 4,
                runSpacing: 4,
                children: [
                  Text(
                    formatPesos(product.referencePriceCentavos),
                    style: priceStyle,
                  ),
                  Text(
                    'as of ${formatAsOfDate(product.priceUpdatedAt)}',
                    style: asOfStyle,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showProductDialog(
    BuildContext context,
    WidgetRef ref, {
    Product? initial,
  }) async {
    await showAdminProductDialog(context, ref, initial: initial);
  }
}

enum _ProductFileAction {
  importProducts('Import Products'),
  exportProducts('Export Products');

  const _ProductFileAction(this.label);

  final String label;

  String get actionLabel => label.split(' ').first;
}

enum _ProductImportMode { additional, replace }

class _ProductFileActionResult {
  const _ProductFileActionResult({
    required this.action,
    this.fileName,
    this.bytes,
    this.importMode = _ProductImportMode.additional,
  });

  final _ProductFileAction action;
  final String? fileName;
  final Uint8List? bytes;
  final _ProductImportMode importMode;
}

class _ResolvedImportedCatalog {
  const _ResolvedImportedCatalog({
    required this.categories,
    required this.products,
  });

  final List<Category> categories;
  final List<Product> products;
}

class _FiltersSection extends StatelessWidget {
  const _FiltersSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _AdminProductsPageState._filtersContentHorizontalPadding,
        16,
        _AdminProductsPageState._filtersContentHorizontalPadding,
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

class _ProductHeaderRow extends StatelessWidget {
  const _ProductHeaderRow({
    required this.widths,
    required this.trailingSpace,
    required this.isEmpty,
  });

  final _ProductColumnWidths widths;
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
          child: _SelectableCellText('ID', style: labelStyle, maxLines: 1),
        ),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.name,
          child: _SelectableCellText('Name', style: labelStyle, maxLines: 1),
        ),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.details,
          child: _SelectableCellText('Details', style: labelStyle, maxLines: 1),
        ),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.category,
          child: _SelectableCellText(
            'Category',
            style: labelStyle,
            maxLines: 1,
          ),
        ),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.price,
          child: _SelectableCellText('Price', style: labelStyle, maxLines: 1),
        ),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.sold,
          child: _SelectableCellText('Sold', style: labelStyle, maxLines: 1),
        ),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.createdAt,
          child: _SelectableCellText(
            'Created at',
            style: labelStyle,
            maxLines: 1,
          ),
        ),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.updatedAt,
          child: _SelectableCellText(
            'Updated at',
            style: labelStyle,
            maxLines: 1,
          ),
        ),
        SizedBox(width: widths.gap),
        if (trailingSpace > 0) SizedBox(width: trailingSpace),
        SizedBox(
          width: _AdminProductsPageState._actionsWidth,
          child: Align(
            alignment: Alignment.centerRight,
            child: _SelectableCellText(
              'Actions',
              style: labelStyle,
              maxLines: 1,
              textAlign: TextAlign.right,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product,
    required this.categoryName,
    required this.widths,
    required this.trailingSpace,
    required this.isLast,
    required this.onPreview,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  final Product product;
  final String categoryName;
  final _ProductColumnWidths widths;
  final double trailingSpace;
  final bool isLast;
  final VoidCallback onPreview;
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
    final createdAt = product.createdAt;
    final updatedAt = product.updatedAt;

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
              child: _SelectableCellText('${product.id}', style: bodyStyle),
            ),
            SizedBox(width: widths.gap),
            SizedBox(
              width: widths.name,
              child: _SelectableCellText(product.name, style: bodyStyle),
            ),
            SizedBox(width: widths.gap),
            SizedBox(
              width: widths.details,
              child: _SelectableCellText(
                product.details,
                style: bodyStyle,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: widths.gap),
            SizedBox(
              width: widths.category,
              child: _SelectableCellText(
                categoryName,
                style: bodyStyle,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: widths.gap),
            SizedBox(
              width: widths.price,
              child: _SelectableCellText(
                formatPesos(product.referencePriceCentavos),
                style: bodyStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: widths.gap),
            SizedBox(
              width: widths.sold,
              child: _SelectableCellText(
                '${product.sold}',
                style: bodyStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: widths.gap),
            SizedBox(
              width: widths.createdAt,
              child: _SelectableCellText(
                '${formatOrderDate(createdAt)}\n${formatOrderTimeWithSeconds(createdAt)}',
                style: bodyStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: widths.gap),
            SizedBox(
              width: widths.updatedAt,
              child: _SelectableCellText(
                '${formatOrderDate(updatedAt)}\n${formatOrderTimeWithSeconds(updatedAt)}',
                style: bodyStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: widths.gap),
            if (trailingSpace > 0) SizedBox(width: trailingSpace),
            SizedBox(
              width: _AdminProductsPageState._actionsWidth,
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
                    onTap: onToggleActive,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        product.isActive
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

class _SelectableCellText extends StatelessWidget {
  const _SelectableCellText(
    this.text, {
    required this.style,
    this.maxLines,
    this.overflow,
    this.softWrap,
    this.textAlign,
  });

  final String text;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
      textAlign: textAlign,
    );
  }
}

class _ProductColumnWidths {
  const _ProductColumnWidths({
    required this.gap,
    required this.id,
    required this.name,
    required this.category,
    required this.details,
    required this.price,
    required this.sold,
    required this.createdAt,
    required this.updatedAt,
  });

  final double gap;
  final double id;
  final double name;
  final double category;
  final double details;
  final double price;
  final double sold;
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
