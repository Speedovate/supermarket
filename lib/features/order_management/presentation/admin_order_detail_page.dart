import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/app_models.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../app_state/app_controller.dart';
import '../../catalog/presentation/catalog_page.dart';
import '../../product_management/presentation/admin_product_dialog.dart';

class AdminOrderDetailPage extends ConsumerStatefulWidget {
  const AdminOrderDetailPage({super.key, required this.orderId});

  final int orderId;

  @override
  ConsumerState<AdminOrderDetailPage> createState() =>
      _AdminOrderDetailPageState();
}

class _AdminOrderDetailPageState extends ConsumerState<AdminOrderDetailPage> {
  late OrderRequest editableOrder;
  late List<CartItem> _originalCart;
  late CustomerDraft _originalDraft;
  bool initialized = false;
  bool _restoredPreviewState = false;

  void _initializeOrderPreview() {
    final appState = ref.read(appControllerProvider);
    final order = appState.orders.firstWhere(
      (item) => item.id == widget.orderId,
    );
    editableOrder = order;
    _originalCart = [...appState.cart];
    _originalDraft = appState.customerDraft;
    initialized = true;
    _restoredPreviewState = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.read(appControllerProvider.notifier).addOrderToCart(order);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initialized) {
      _initializeOrderPreview();
    }
  }

  @override
  void didUpdateWidget(covariant AdminOrderDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderId == widget.orderId || !initialized) {
      return;
    }

    if (!_restoredPreviewState) {
      _restoredPreviewState = true;
      ref
          .read(appControllerProvider.notifier)
          .replaceCartAndDraft(
            cart: _originalCart,
            customerDraft: _originalDraft,
          );
    }

    _initializeOrderPreview();
  }

  @override
  void dispose() {
    if (!_restoredPreviewState && initialized) {
      _restoredPreviewState = true;
      ref
          .read(appControllerProvider.notifier)
          .replaceCartAndDraft(
            cart: _originalCart,
            customerDraft: _originalDraft,
          );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final persistedOrder = state.orders
        .where((item) => item.id == widget.orderId)
        .firstOrNull;

    if (persistedOrder == null) {
      return const Center(child: Text('Order not found.'));
    }
    if (initialized &&
        (persistedOrder.updatedAt != editableOrder.updatedAt ||
            persistedOrder.total != editableOrder.total ||
            persistedOrder.items.length != editableOrder.items.length)) {
      editableOrder = persistedOrder;
    }
    final order = initialized ? editableOrder : persistedOrder;

    final productsById = {
      for (final product in state.products) product.id: product,
    };
    final orderProducts = order.items
        .map(
          (item) =>
              productsById[item.productId] ??
              Product(
                id: item.productId,
                active: true,
                createdAt: order.createdAt,
                updatedAt: order.updatedAt,
                name: item.productName,
                category: 0,
                details: item.unit,
                price: item.referenceUnitPriceCentavos,
                sold: 0,
              ),
        )
        .toList();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _OrderSummaryTable(
          order: order,
          onCopy: () => _copyOrderSummary(context, order),
          onEdit: () => _showEditOrderDialog(context, order),
          onAddProduct: () => _showAddProductDialog(context),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            const gridSpacing = 16.0;
            final width = constraints.maxWidth;
            final columns = _homeCatalogColumnsForWidth(width);
            final resolvedCardWidth = columns == 1
                ? width
                : (width - ((columns - 1) * gridSpacing)) / columns;
            final gridCardDensity = _homeCardDensityForWidth(resolvedCardWidth);
            final resolvedCardHeight = switch (columns) {
              1 => lerpDouble(194.0, 186.0, gridCardDensity)!,
              2 =>
                resolvedCardWidth + lerpDouble(185.0, 172.0, gridCardDensity)!,
              3 =>
                resolvedCardWidth + lerpDouble(190.0, 174.0, gridCardDensity)!,
              4 =>
                resolvedCardWidth + lerpDouble(181.0, 168.0, gridCardDensity)!,
              _ =>
                resolvedCardWidth + lerpDouble(173.0, 160.0, gridCardDensity)!,
            };
            final gridAspectRatio = resolvedCardWidth / resolvedCardHeight;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: orderProducts.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: gridSpacing,
                mainAxisSpacing: gridSpacing,
                childAspectRatio: gridAspectRatio,
              ),
              itemBuilder: (context, i) {
                final orderItem = order.items[i];
                final orderItemId = orderItem.id;
                return ProductCard(
                  key: ValueKey(orderItem.id),
                  product: orderProducts[i],
                  adaptiveSizing: true,
                  showImage: columns != 1,
                  modalDisplayName: orderItem.productName,
                  modalDisplayUnit: orderItem.unit,
                  modalDisplayPriceCentavos:
                      orderItem.referenceUnitPriceCentavos,
                  modalDisplayPriceUpdatedAt: order.updatedAt,
                  showModalEditAction: true,
                  adminReadOnly: true,
                  initialAdminQuantity: orderItem.requestedQuantity,
                  onModalEditProduct: (modalContext) async {
                    final latestItemIndex = editableOrder.items.indexWhere(
                      (item) => item.id == orderItemId,
                    );
                    if (latestItemIndex == -1) {
                      return null;
                    }
                    final latestOrderItem =
                        editableOrder.items[latestItemIndex];
                    final latestProduct = Product(
                      id: orderProducts[i].id,
                      active: orderProducts[i].active,
                      createdAt: orderProducts[i].createdAt,
                      updatedAt: order.updatedAt,
                      name: latestOrderItem.productName,
                      category: orderProducts[i].categoryId,
                      details: latestOrderItem.unit,
                      price: latestOrderItem.referenceUnitPriceCentavos,
                      sold: orderProducts[i].sold,
                    );
                    final updatedProduct = await showAdminProductDialog(
                      modalContext,
                      ref,
                      initial: latestProduct,
                    );
                    if (updatedProduct == null) {
                      return null;
                    }
                    final now = updatedProduct.updatedAt;
                    final updatedItems = [...editableOrder.items];
                    updatedItems[latestItemIndex] = latestOrderItem.copyWith(
                      productName: updatedProduct.name,
                      unit: updatedProduct.displayUnit,
                      referenceUnitPriceCentavos:
                          updatedProduct.referencePriceCentavos,
                      quotedUnitPriceCentavos:
                          updatedProduct.referencePriceCentavos,
                      estimatedSubtotalCentavos:
                          latestOrderItem.requestedQuantity *
                          updatedProduct.referencePriceCentavos,
                      quotedSubtotalCentavos:
                          latestOrderItem.requestedQuantity *
                          updatedProduct.referencePriceCentavos,
                      updatedAt: now,
                    );
                    final updatedTotal = updatedItems.fold<int>(
                      0,
                      (sum, item) =>
                          sum +
                          (item.requestedQuantity *
                              item.referenceUnitPriceCentavos),
                    );
                    final updatedOrder = editableOrder.copyWith(
                      items: updatedItems,
                      total: updatedTotal,
                      updatedAt: now,
                    );
                    await ref
                        .read(appControllerProvider.notifier)
                        .updateOrder(updatedOrder);
                    if (!mounted || !modalContext.mounted) {
                      return null;
                    }
                    setState(() {
                      editableOrder = updatedOrder;
                    });
                    final messenger = ScaffoldMessenger.of(modalContext);
                    messenger.clearSnackBars();
                    messenger.showSnackBar(successSnackBar('Product updated.'));
                    return updatedProduct;
                  },
                  onAdminQuantitySaved: (quantity) async {
                    final latestItems = [...editableOrder.items];
                    final latestItemIndex = latestItems.indexWhere(
                      (item) => item.id == orderItemId,
                    );
                    if (latestItemIndex == -1) {
                      return;
                    }

                    final latestOrderItem = latestItems[latestItemIndex];
                    if (quantity <= 0) {
                      latestItems.removeAt(latestItemIndex);
                    } else {
                      latestItems[latestItemIndex] = latestOrderItem.copyWith(
                        requestedQuantity: quantity,
                        estimatedSubtotalCentavos:
                            quantity *
                            latestOrderItem.referenceUnitPriceCentavos,
                        quotedSubtotalCentavos:
                            quantity *
                            latestOrderItem.referenceUnitPriceCentavos,
                        updatedAt: DateTime.now(),
                      );
                    }

                    final now = DateTime.now();
                    final updatedOrder = editableOrder.copyWith(
                      items: latestItems,
                      total: latestItems.fold<int>(
                        0,
                        (sum, item) =>
                            sum +
                            (item.requestedQuantity *
                                item.referenceUnitPriceCentavos),
                      ),
                      updatedAt: now,
                    );

                    setState(() {
                      editableOrder = updatedOrder;
                    });
                    await ref
                        .read(appControllerProvider.notifier)
                        .updateOrder(updatedOrder);
                    await ref
                        .read(appControllerProvider.notifier)
                        .addOrderToCart(updatedOrder);
                    if (!mounted) {
                      return;
                    }
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }

  Future<void> _copyOrderSummary(
    BuildContext context,
    OrderRequest order,
  ) async {
    final methodLabel = order.method == FulfillmentMethod.pickup
        ? 'For Pickup'
        : displayFulfillment(order.method);
    final methodLine =
        order.method == FulfillmentMethod.delivery &&
            order.place.trim().isNotEmpty
        ? '$methodLabel - ${order.place}'
        : methodLabel;
    final addressLines = order.method == FulfillmentMethod.delivery
        ? [
            if (order.addressStreet.trim().isNotEmpty ||
                order.addressLandmark.trim().isNotEmpty)
              order.addressStreet.trim().isNotEmpty
                  ? order.addressStreet.trim()
                  : order.addressLandmark.trim(),
          ]
        : const <String>[];
    final productLines = order.items.isEmpty
        ? ['Items: -']
        : [
            'Items:',
            ...order.items.map(
              (item) =>
                  '- ${item.productName} | ${item.unit} | x${item.requestedQuantity}',
            ),
          ];
    final summary = [
      'Order #${order.id}',
      methodLine,
      '${formatOrderDate(order.createdAt)} ${formatOrderTimeWithSeconds(order.createdAt)}',
      if (addressLines.isNotEmpty) ...[...addressLines],
      '',
      order.name,
      order.phone,
      '',
      ...productLines,
    ].join('\n');

    await Clipboard.setData(ClipboardData(text: summary));
    if (!context.mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(successSnackBar('Order copied.'));
  }

  Future<void> _showAddProductDialog(BuildContext context) async {
    final state = ref.read(appControllerProvider);
    final categoriesById = {
      for (final category in state.categories) category.id: category.name,
    };
    final activeCategories = [
      ...state.categories.where((item) => item.isActive),
    ]..sort((a, b) => a.id.compareTo(b.id));
    final activeProducts = [...state.products.where((item) => item.isActive)]
      ..sort((a, b) {
        final createdAtCompare = b.createdAt.compareTo(a.createdAt);
        if (createdAtCompare != 0) {
          return createdAtCompare;
        }
        return b.id.compareTo(a.id);
      });
    final searchController = TextEditingController();
    Product? selectedProduct;
    var selectedCategoryId = 'all';
    var selectedSort = CatalogSortOption.defaultOrder;
    var selectedQuantity = 1;
    var isSubmittingAdd = false;
    var isQuantityDialogOpen = false;

    void submitAdd(BuildContext dialogContext) {
      if (isSubmittingAdd) {
        return;
      }
      if (isQuantityDialogOpen) {
        return;
      }
      if (selectedProduct == null) {
        final messenger = ScaffoldMessenger.of(dialogContext);
        messenger.clearSnackBars();
        messenger.showSnackBar(errorSnackBar('Please select a product.'));
        return;
      }
      if (selectedQuantity <= 0) {
        final messenger = ScaffoldMessenger.of(dialogContext);
        messenger.clearSnackBars();
        messenger.showSnackBar(errorSnackBar('Please enter a valid quantity.'));
        return;
      }
      isSubmittingAdd = true;
      Navigator.of(dialogContext).pop(true);
    }

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final query = searchController.text.trim().toLowerCase();
            final filteredProducts =
                activeProducts.where((product) {
                  final categoryName = categoriesById[product.categoryId] ?? '';
                  final matchesCategory =
                      selectedCategoryId == 'all' ||
                      product.categoryId.toString() == selectedCategoryId;
                  final matchesQuery =
                      query.isEmpty ||
                      product.name.toLowerCase().contains(query) ||
                      product.displayUnit.toLowerCase().contains(query) ||
                      categoryName.toLowerCase().contains(query) ||
                      '${product.id}'.contains(query);
                  return matchesCategory && matchesQuery;
                }).toList()..sort((a, b) {
                  switch (selectedSort) {
                    case CatalogSortOption.defaultOrder:
                      final createdAtCompare = b.createdAt.compareTo(
                        a.createdAt,
                      );
                      if (createdAtCompare != 0) {
                        return createdAtCompare;
                      }
                      return b.id.compareTo(a.id);
                    case CatalogSortOption.nameAscending:
                      return a.name.toLowerCase().compareTo(
                        b.name.toLowerCase(),
                      );
                    case CatalogSortOption.nameDescending:
                      return b.name.toLowerCase().compareTo(
                        a.name.toLowerCase(),
                      );
                    case CatalogSortOption.priceLowToHigh:
                      return a.referencePriceCentavos.compareTo(
                        b.referencePriceCentavos,
                      );
                    case CatalogSortOption.priceHighToLow:
                      return b.referencePriceCentavos.compareTo(
                        a.referencePriceCentavos,
                      );
                  }
                });

            final dialog = Dialog(
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.all(24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Add Product',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      height: 1.15,
                                    ),
                              ),
                            ),
                            Theme(
                              data: Theme.of(context).copyWith(
                                focusColor: Colors.transparent,
                                hoverColor: Colors.black.withValues(
                                  alpha: AppColors.neutralHoverOverlayAlpha,
                                ),
                                highlightColor: Colors.black.withValues(
                                  alpha: AppColors.neutralPressedOverlayAlpha,
                                ),
                                splashColor: Colors.transparent,
                              ),
                              child: Builder(
                                builder: (themedContext) {
                                  return MousePressable(
                                    onTap: () async {
                                      final button =
                                          themedContext.findRenderObject()
                                              as RenderBox;
                                      final overlay =
                                          Overlay.of(
                                                themedContext,
                                              ).context.findRenderObject()
                                              as RenderBox;
                                      final result =
                                          await showMenu<CatalogSortOption>(
                                            context: themedContext,
                                            color: Colors.white,
                                            surfaceTintColor: Colors.white,
                                            menuPadding: EdgeInsets.zero,
                                            position: RelativeRect.fromRect(
                                              Rect.fromPoints(
                                                button.localToGlobal(
                                                  Offset.zero,
                                                  ancestor: overlay,
                                                ),
                                                button.localToGlobal(
                                                  button.size.bottomRight(
                                                    Offset.zero,
                                                  ),
                                                  ancestor: overlay,
                                                ),
                                              ),
                                              Offset.zero & overlay.size,
                                            ),
                                            items: [
                                              for (final option
                                                  in CatalogSortOption.values)
                                                PopupMenuItem<
                                                  CatalogSortOption
                                                >(
                                                  value: option,
                                                  mouseCursor:
                                                      SystemMouseCursors.click,
                                                  child: Text(
                                                    option.label,
                                                    style: const TextStyle(
                                                      height: 1.15,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          );
                                      if (result != null) {
                                        setModalState(() {
                                          selectedSort = result;
                                        });
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: const Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Icon(
                                        Icons.filter_list_rounded,
                                        color: AppColors.logoBlue,
                                        size: 18,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: searchController,
                          onChanged: (_) => setModalState(() {}),
                          onSubmitted: (_) => submitAdd(dialogContext),
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
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Color(0xFFD0D5DD),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: AppColors.logoBlue,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            const SizedBox(width: 16),
                            _AdminAddProductCategoryPill(
                              label: 'All',
                              selected: selectedCategoryId == 'all',
                              onTap: () {
                                setModalState(() {
                                  selectedCategoryId = 'all';
                                });
                              },
                            ),
                            for (
                              var i = 0;
                              i < activeCategories.length;
                              i++
                            ) ...[
                              const SizedBox(width: 10),
                              _AdminAddProductCategoryPill(
                                label: activeCategories[i].name,
                                selected:
                                    selectedCategoryId ==
                                    activeCategories[i].id.toString(),
                                onTap: () {
                                  setModalState(() {
                                    selectedCategoryId = activeCategories[i].id
                                        .toString();
                                  });
                                },
                              ),
                            ],
                            const SizedBox(width: 16),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 280),
                        child: filteredProducts.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: EmptyStateCard(
                                  title: 'No products found',
                                  message:
                                      'Try a different search term or switch categories.',
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                itemCount: filteredProducts.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final product = filteredProducts[index];
                                  final isSelected =
                                      selectedProduct?.id == product.id;
                                  return MousePressable(
                                    onTap: () {
                                      setModalState(() {
                                        selectedProduct = product;
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: _AdminAddProductListItem(
                                      product: product,
                                      isSelected: isSelected,
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _OrderEditLabel(title: 'Quantity'),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _OrderModalQuantityControl(
                          quantity: selectedQuantity,
                          height: 44,
                          onDecrease: () async {
                            if (selectedQuantity <= 1) {
                              return;
                            }
                            setModalState(() {
                              selectedQuantity -= 1;
                            });
                          },
                          onIncrease: () async {
                            setModalState(() {
                              selectedQuantity += 1;
                            });
                          },
                          onEditQuantity: () async {
                            int? nextQuantity;
                            try {
                              isQuantityDialogOpen = true;
                              nextQuantity =
                                  await _showModalQuantityInputDialog(
                                    context,
                                    initialQuantity: selectedQuantity,
                                  );
                            } finally {
                              isQuantityDialogOpen = false;
                            }
                            if (nextQuantity == null ||
                                nextQuantity == selectedQuantity ||
                                nextQuantity <= 0) {
                              return;
                            }
                            setModalState(() {
                              selectedQuantity = nextQuantity!;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 44,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFE31E24),
                                    backgroundColor: const Color(0x1AE31E24),
                                    side: BorderSide.none,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(false),
                                  child: Text(
                                    'Close',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          color: const Color(0xFFE31E24),
                                          fontWeight: FontWeight.w700,
                                          height: 1.15,
                                        ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SizedBox(
                                height: 44,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.logoBlue,
                                    backgroundColor: AppColors.logoBlue
                                        .withValues(alpha: 0.10),
                                    side: BorderSide.none,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  onPressed: () => submitAdd(dialogContext),
                                  child: Text(
                                    'Add',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          color: AppColors.logoBlue,
                                          fontWeight: FontWeight.w700,
                                          height: 1.15,
                                        ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );

            return CallbackShortcuts(
              bindings: <ShortcutActivator, VoidCallback>{
                const SingleActivator(LogicalKeyboardKey.enter): () =>
                    submitAdd(dialogContext),
                const SingleActivator(LogicalKeyboardKey.numpadEnter): () =>
                    submitAdd(dialogContext),
              },
              child: dialog,
            );
          },
        );
      },
    );

    if (shouldSave != true ||
        !mounted ||
        selectedProduct == null ||
        selectedQuantity <= 0) {
      searchController.dispose();
      return;
    }
    final quantity = selectedQuantity;

    final now = DateTime.now();
    final nextItems = [...editableOrder.items];
    final existingIndex = nextItems.indexWhere(
      (item) => item.productId == selectedProduct!.id,
    );
    if (existingIndex >= 0) {
      final existing = nextItems[existingIndex];
      final nextQuantity = existing.requestedQuantity + quantity;
      nextItems[existingIndex] = existing.copyWith(
        requestedQuantity: nextQuantity,
        unit: selectedProduct!.displayUnit,
        productName: selectedProduct!.name,
        referenceUnitPriceCentavos: selectedProduct!.referencePriceCentavos,
        quotedUnitPriceCentavos: selectedProduct!.referencePriceCentavos,
        estimatedSubtotalCentavos:
            nextQuantity * selectedProduct!.referencePriceCentavos,
        quotedSubtotalCentavos:
            nextQuantity * selectedProduct!.referencePriceCentavos,
        updatedAt: now,
      );
    } else {
      final nextId = nextItems.isEmpty
          ? 1
          : nextItems.map((item) => item.id).reduce(math.max) + 1;
      nextItems.add(
        OrderItem(
          id: nextId,
          productId: selectedProduct!.id,
          productName: selectedProduct!.name,
          unit: selectedProduct!.displayUnit,
          requestedQuantity: quantity,
          referenceUnitPriceCentavos: selectedProduct!.referencePriceCentavos,
          estimatedSubtotalCentavos:
              quantity * selectedProduct!.referencePriceCentavos,
          quotedUnitPriceCentavos: selectedProduct!.referencePriceCentavos,
          quotedSubtotalCentavos:
              quantity * selectedProduct!.referencePriceCentavos,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    final updatedOrder = editableOrder.copyWith(
      items: nextItems,
      total: nextItems.fold<int>(
        0,
        (sum, item) =>
            sum + (item.requestedQuantity * item.referenceUnitPriceCentavos),
      ),
      updatedAt: now,
    );

    await ref.read(appControllerProvider.notifier).updateOrder(updatedOrder);
    await ref.read(appControllerProvider.notifier).addOrderToCart(updatedOrder);
    if (!mounted) {
      searchController.dispose();
      return;
    }
    setState(() {
      editableOrder = updatedOrder;
    });
    final messenger = ScaffoldMessenger.of(this.context);
    messenger.clearSnackBars();
    messenger.showSnackBar(successSnackBar('Product added.'));
    searchController.dispose();
  }

  Future<void> _showEditOrderDialog(
    BuildContext context,
    OrderRequest order,
  ) async {
    var selectedStatus = order.status;
    var selectedMethod = order.method;
    var selectedPlace = order.place.trim();
    var selectedStreet = order.addressStreet.trim();
    final serviceableBarangays = ref
        .read(appControllerProvider.notifier)
        .serviceableBarangays;

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AppModalFrame(
              title: 'Edit Order',
              actions: [
                AppModalButton(
                  label: 'Close',
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                ),
                const SizedBox(width: 10),
                AppModalButton(
                  label: 'Save',
                  isPrimary: true,
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                ),
              ],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _OrderEditLabel(title: 'Status'),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<OrderStatus>(
                    isExpanded: true,
                    initialValue: selectedStatus,
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.logoBlue,
                      size: 24,
                    ),
                    decoration: _orderEditDropdownDecoration('Status'),
                    items: OrderStatus.values
                        .map(
                          (status) => DropdownMenuItem<OrderStatus>(
                            value: status,
                            child: Text(displayStatus(status)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() => selectedStatus = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  _OrderEditLabel(title: 'Method'),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<FulfillmentMethod>(
                    isExpanded: true,
                    initialValue: selectedMethod,
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.logoBlue,
                      size: 24,
                    ),
                    decoration: _orderEditDropdownDecoration('Method'),
                    items: FulfillmentMethod.values
                        .map(
                          (method) => DropdownMenuItem<FulfillmentMethod>(
                            value: method,
                            child: Text(displayFulfillment(method)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        selectedMethod = value;
                        if (selectedMethod != FulfillmentMethod.delivery) {
                          selectedPlace = '';
                          selectedStreet = '';
                        }
                      });
                    },
                  ),
                  if (selectedMethod == FulfillmentMethod.delivery) ...[
                    const SizedBox(height: 12),
                    _OrderEditLabel(title: 'Barangay'),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: serviceableBarangays.contains(selectedPlace)
                          ? selectedPlace
                          : null,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.logoBlue,
                        size: 24,
                      ),
                      decoration: _orderEditDropdownDecoration('Barangay'),
                      items: serviceableBarangays
                          .map(
                            (place) => DropdownMenuItem<String>(
                              value: place,
                              child: Text(place),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() => selectedPlace = value);
                      },
                    ),
                    if (selectedPlace.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _OrderEditLabel(title: 'Street/Landmark'),
                      const SizedBox(height: 10),
                      TextFormField(
                        initialValue: selectedStreet,
                        decoration: _orderEditDropdownDecoration(
                          'Street/Landmark',
                        ),
                        onChanged: (value) => selectedStreet = value,
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

    if (shouldSave != true || !mounted) {
      return;
    }

    if (selectedMethod == FulfillmentMethod.delivery &&
        selectedPlace.trim().isEmpty) {
      final messenger = ScaffoldMessenger.of(this.context);
      messenger.clearSnackBars();
      messenger.showSnackBar(errorSnackBar('Barangay is required.'));
      return;
    }
    if (selectedMethod == FulfillmentMethod.delivery &&
        selectedStreet.trim().isEmpty) {
      final messenger = ScaffoldMessenger.of(this.context);
      messenger.clearSnackBars();
      messenger.showSnackBar(errorSnackBar('Street/Landmark is required.'));
      return;
    }

    final updatedOrder = ref
        .read(appControllerProvider)
        .orders
        .firstWhere((item) => item.id == order.id)
        .copyWith(
          status: selectedStatus,
          method: selectedMethod,
          place: selectedMethod == FulfillmentMethod.delivery
              ? selectedPlace
              : '',
          addressStreet: selectedMethod == FulfillmentMethod.delivery
              ? selectedStreet
              : '',
          addressLandmark: '',
          updatedAt: DateTime.now(),
        );

    await ref.read(appControllerProvider.notifier).updateOrder(updatedOrder);
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(this.context);
    messenger.clearSnackBars();
    messenger.showSnackBar(successSnackBar('Order updated.'));
  }
}

class _OrderSummaryTable extends StatelessWidget {
  const _OrderSummaryTable({
    required this.order,
    required this.onCopy,
    required this.onEdit,
    required this.onAddProduct,
  });

  final OrderRequest order;
  final Future<void> Function() onCopy;
  final VoidCallback onEdit;
  final Future<void> Function() onAddProduct;

  @override
  Widget build(BuildContext context) {
    final widths = _computeOrderSummaryWidths(
      context: context,
      screenWidth: MediaQuery.of(context).size.width,
      order: order,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveTableWidth =
            constraints.maxWidth > widths.tableWidth + 40
            ? constraints.maxWidth
            : widths.tableWidth + 40;
        final trailingSpace = effectiveTableWidth - (widths.tableWidth + 40);

        return SectionCard(
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
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: effectiveTableWidth,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _OrderClientIdentity(
                            order: order,
                            onAddProduct: onAddProduct,
                          ),
                          const Divider(
                            height: 0,
                            thickness: 0.6,
                            color: Color(0xFFE4E7EC),
                          ),
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppColors.logoBlue.withValues(alpha: 0.10),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(0),
                                topRight: Radius.circular(0),
                              ),
                            ),
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                            child: _OrderSummaryHeaderRow(
                              widths: widths,
                              trailingSpace: trailingSpace,
                            ),
                          ),
                          const Divider(
                            height: 0,
                            thickness: 0.6,
                            color: Color(0xFFE4E7EC),
                          ),
                          _OrderSummaryRow(
                            order: order,
                            widths: widths,
                            trailingSpace: trailingSpace,
                            onCopy: onCopy,
                            onEdit: onEdit,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OrderClientIdentity extends StatelessWidget {
  const _OrderClientIdentity({required this.order, required this.onAddProduct});

  final OrderRequest order;
  final Future<void> Function() onAddProduct;

  @override
  Widget build(BuildContext context) {
    final initial = order.name.trim().isEmpty
        ? 'C'
        : order.name.trim().characters.first.toUpperCase();
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: const Color(0xFF172033),
      height: 1.15,
    );
    final subtitleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: const Color(0xFF667085),
      height: 1.15,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 16, 20, 16),
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
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  order.name.trim().isEmpty ? '-' : order.name.trim(),
                  style: titleStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  order.phone.trim().isEmpty ? '-' : order.phone.trim(),
                  style: subtitleStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.logoBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () {
                onAddProduct();
              },
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                'Add Product',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderSummaryWidths {
  const _OrderSummaryWidths({
    required this.gap,
    required this.id,
    required this.status,
    required this.method,
    required this.place,
    required this.total,
    required this.createdAt,
    required this.updatedAt,
    required this.actions,
  });

  final double gap;
  final double id;
  final double status;
  final double method;
  final double place;
  final double total;
  final double createdAt;
  final double updatedAt;
  final double actions;

  double get tableWidth =>
      id +
      gap +
      status +
      gap +
      method +
      gap +
      place +
      gap +
      total +
      gap +
      createdAt +
      gap +
      updatedAt +
      gap +
      actions;
}

const double _orderSummaryColumnWidthAllowance = 8;
const double _orderSummaryActionHitSize = 34;
const double _orderSummaryStatusBadgeHorizontalPadding = 24;
double get _orderSummaryActionsWidth => _orderSummaryActionHitSize * 2;

_OrderSummaryWidths _computeOrderSummaryWidths({
  required BuildContext context,
  required double screenWidth,
  required OrderRequest order,
}) {
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
  final gap = 20.0;

  double maxWidth(String header, String value, {double? max}) {
    painter.text = TextSpan(text: header, style: headerStyle);
    painter.layout();
    var width =
        painter.width.ceilToDouble() + _orderSummaryColumnWidthAllowance;
    painter.text = TextSpan(text: value, style: bodyStyle);
    painter.layout(maxWidth: screenWidth);
    width = math.max(
      width,
      painter.width.ceilToDouble() + _orderSummaryColumnWidthAllowance,
    );
    if (max != null && width > max) {
      return max;
    }
    return width;
  }

  final placeValue =
      order.method == FulfillmentMethod.delivery &&
          order.place.trim().isNotEmpty
      ? order.place.trim()
      : '-';

  return _OrderSummaryWidths(
    gap: gap,
    id: maxWidth('ID', '${order.id}'),
    status:
        maxWidth(
          'Status',
          displayStatus(order.status),
          max: math.max(96, screenWidth < 700 ? 120 : 132),
        ) +
        _orderSummaryStatusBadgeHorizontalPadding,
    method: maxWidth('Method', displayFulfillment(order.method)),
    place: maxWidth('Barangay', placeValue, max: screenWidth < 700 ? 160 : 220),
    total: maxWidth('Total', formatPesos(order.total)),
    createdAt: maxWidth(
      'Created at',
      '${formatOrderDate(order.createdAt)}\n${formatOrderTimeWithSeconds(order.createdAt)}',
    ),
    updatedAt: maxWidth(
      'Updated at',
      '${formatOrderDate(order.updatedAt)}\n${formatOrderTimeWithSeconds(order.updatedAt)}',
    ),
    actions: _orderSummaryActionsWidth,
  );
}

class _OrderSummaryHeaderRow extends StatelessWidget {
  const _OrderSummaryHeaderRow({
    required this.widths,
    required this.trailingSpace,
  });

  final _OrderSummaryWidths widths;
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
        SizedBox(
          width: widths.id,
          child: Text('ID', style: labelStyle, maxLines: 1),
        ),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.status,
          child: Text('Status', style: labelStyle, maxLines: 1),
        ),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.method,
          child: Text('Method', style: labelStyle, maxLines: 1),
        ),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.place,
          child: Text('Barangay', style: labelStyle, maxLines: 1),
        ),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.total,
          child: Text('Total', style: labelStyle, maxLines: 1),
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
          width: widths.actions,
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

class _OrderSummaryRow extends StatelessWidget {
  const _OrderSummaryRow({
    required this.order,
    required this.widths,
    required this.trailingSpace,
    required this.onCopy,
    required this.onEdit,
  });

  final OrderRequest order;
  final _OrderSummaryWidths widths;
  final double trailingSpace;
  final Future<void> Function() onCopy;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final scale = _textScaleForWidth(MediaQuery.of(context).size.width);
    final bodyStyle = DefaultTextStyle.of(context).style.copyWith(
      fontSize: (DefaultTextStyle.of(context).style.fontSize ?? 14) * scale,
      height: 1.15,
    );
    final placeValue =
        order.method == FulfillmentMethod.delivery &&
            order.place.trim().isNotEmpty
        ? order.place.trim()
        : '-';

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: widths.id,
              child: Text('${order.id}', style: bodyStyle),
            ),
            SizedBox(width: widths.gap),
            SizedBox(
              width: widths.status,
              child: Align(
                alignment: Alignment.centerLeft,
                child: StatusBadge(
                  status: order.status,
                  fontSize:
                      (Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14) *
                      scale,
                ),
              ),
            ),
            SizedBox(width: widths.gap),
            SizedBox(
              width: widths.method,
              child: Text(
                displayFulfillment(order.method),
                style: bodyStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: widths.gap),
            SizedBox(
              width: widths.place,
              child: Text(placeValue, style: bodyStyle, softWrap: true),
            ),
            SizedBox(width: widths.gap),
            SizedBox(
              width: widths.total,
              child: Text(
                formatPesos(order.total),
                style: bodyStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: widths.gap),
            SizedBox(
              width: widths.createdAt,
              child: Text(
                '${formatOrderDate(order.createdAt)}\n${formatOrderTimeWithSeconds(order.createdAt)}',
                style: bodyStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: widths.gap),
            SizedBox(
              width: widths.updatedAt,
              child: Text(
                '${formatOrderDate(order.updatedAt)}\n${formatOrderTimeWithSeconds(order.updatedAt)}',
                style: bodyStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: widths.gap + trailingSpace),
            SizedBox(
              width: widths.actions,
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
                    onTap: onCopy,
                    borderRadius: BorderRadius.circular(10),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.content_copy_outlined,
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

class _OrderEditLabel extends StatelessWidget {
  const _OrderEditLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: const Color(0xFF101828),
        height: 1.15,
      ),
    );
  }
}

class _AdminAddProductListItem extends StatelessWidget {
  const _AdminAddProductListItem({
    required this.product,
    required this.isSelected,
  });

  final Product product;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    const titleFontSize = 14.0;
    const unitFontSize = 12.0;
    const priceFontSize = 14.0;
    const contentHeight = 72.0;
    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.logoBlue.withValues(alpha: 0.10)
            : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected ? AppColors.logoBlue : const Color(0xFFE4E7EC),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: Container(
              padding: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE4E7EC)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ProductPlaceholder(
                label: product.name,
                height: 72,
                fullRounded: true,
                imageUrl: product.photoUrl,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: contentHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.displayUnit,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF667085),
                      height: 1.15,
                      fontSize: unitFontSize,
                    ),
                  ),
                  const Spacer(),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.end,
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      Text(
                        formatPesos(product.referencePriceCentavos),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: priceFontSize,
                          color: AppColors.logoBlue,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                      Text(
                        'as of ${formatAsOfDate(product.priceUpdatedAt)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF667085),
                          height: 1.15,
                          fontSize: unitFontSize,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminAddProductCategoryPill extends StatelessWidget {
  const _AdminAddProductCategoryPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final controlExtent = MediaQuery.of(context).size.width < 700 ? 36.0 : 40.0;
    return MousePressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      stateBuilder: selected
          ? (context, hovered, pressed, child) {
              final states = <WidgetState>{
                if (hovered) WidgetState.hovered,
                if (pressed) WidgetState.pressed,
              };
              return Container(
                height: controlExtent,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: AppColors.brandingBlueInteractiveBackground(states),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.brandingBlueInteractiveBackground(states),
                  ),
                ),
                child: Center(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.15,
                    ),
                  ),
                ),
              );
            }
          : null,
      hoverOverlayAlpha: selected ? 0 : AppColors.neutralHoverOverlayAlpha,
      pressedOverlayAlpha: selected ? 0 : AppColors.neutralPressedOverlayAlpha,
      child: Container(
        height: controlExtent,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: selected ? AppColors.logoBlue : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.logoBlue : const Color(0xFFE4E7EC),
          ),
        ),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : const Color(0xFF172033),
              height: 1.15,
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderModalQuantityControl extends StatelessWidget {
  const _OrderModalQuantityControl({
    required this.quantity,
    required this.height,
    required this.onDecrease,
    required this.onIncrease,
    required this.onEditQuantity,
  });

  final int quantity;
  final double height;
  final Future<void> Function() onDecrease;
  final Future<void> Function() onIncrease;
  final Future<void> Function() onEditQuantity;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.logoBlue,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            SizedBox(
              width: height,
              height: height,
              child: IconButton(
                onPressed: onDecrease,
                style: ButtonStyle(
                  backgroundColor: _modalStrongBlueBackground(),
                  foregroundColor: WidgetStateProperty.all(Colors.white),
                  overlayColor: _modalTransparentInteractionOverlay(),
                  splashFactory: NoSplash.splashFactory,
                  animationDuration: Duration.zero,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
                splashRadius: 1,
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                icon: const Icon(Icons.remove, color: Colors.white),
              ),
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onEditQuantity,
                child: Center(
                  child: Text(
                    '$quantity',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: height,
              height: height,
              child: IconButton(
                onPressed: onIncrease,
                style: ButtonStyle(
                  backgroundColor: _modalStrongBlueBackground(),
                  foregroundColor: WidgetStateProperty.all(Colors.white),
                  overlayColor: _modalTransparentInteractionOverlay(),
                  splashFactory: NoSplash.splashFactory,
                  animationDuration: Duration.zero,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
                splashRadius: 1,
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                icon: const Icon(Icons.add, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

WidgetStateProperty<Color?> _modalStrongBlueBackground() {
  return WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.pressed)) {
      return AppColors.darken(
        AppColors.logoBlue,
        AppColors.brandingBluePressedOverlayAlpha,
      );
    }
    if (states.contains(WidgetState.hovered)) {
      return AppColors.darken(
        AppColors.logoBlue,
        AppColors.brandingBlueHoverOverlayAlpha,
      );
    }
    if (states.contains(WidgetState.focused)) {
      return AppColors.darken(
        AppColors.logoBlue,
        AppColors.brandingBlueFocusOverlayAlpha,
      );
    }
    return AppColors.logoBlue;
  });
}

WidgetStateProperty<Color?> _modalTransparentInteractionOverlay() {
  return WidgetStateProperty.all(Colors.transparent);
}

Future<int?> _showModalQuantityInputDialog(
  BuildContext context, {
  required int initialQuantity,
}) async {
  final controller = TextEditingController(text: '$initialQuantity');
  var isSubmitting = false;
  final value = await showDialog<int>(
    context: context,
    builder: (dialogContext) {
      void submit() {
        if (isSubmitting) {
          return;
        }
        final parsed = int.tryParse(controller.text.trim());
        if (parsed == null || parsed <= 0) {
          final messenger = ScaffoldMessenger.of(dialogContext);
          messenger.clearSnackBars();
          messenger.showSnackBar(
            errorSnackBar('Please enter a valid quantity.'),
          );
          return;
        }
        isSubmitting = true;
        Navigator.of(dialogContext).pop(parsed);
      }

      return AppModalFrame(
        title: 'Update Quantity',
        onSubmit: submit,
        actions: [
          AppModalButton(
            label: 'Close',
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          const SizedBox(width: 10),
          AppModalButton(label: 'Save', isPrimary: true, onPressed: submit),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _OrderEditLabel(title: 'Quantity'),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => submit(),
              decoration: InputDecoration(
                hintText: 'Quantity',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.logoBlue),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
  controller.dispose();
  return value;
}

InputDecoration _orderEditDropdownDecoration(String hintText) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(
      color: Color(0xFF667085),
      fontWeight: FontWeight.w700,
      height: 1.15,
    ),
    filled: true,
    fillColor: const Color(0xFFF9FAFB),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.logoBlue, width: 1.2),
    ),
  );
}

int _homeCatalogColumnsForWidth(double width) {
  if (width >= 1300) {
    return 6;
  }
  if (width >= 1070) {
    return 5;
  }
  if (width >= 820) {
    return 4;
  }
  if (width >= 550) {
    return 3;
  }
  if (width >= 500) {
    return 2;
  }
  if (width > 360) {
    return 2;
  }
  return 1;
}

double _homeCardDensityForWidth(double width) {
  const compactWidth = 210.0;
  const regularWidth = 240.0;
  if (width <= compactWidth) {
    return 1;
  }
  if (width >= regularWidth) {
    return 0;
  }
  return ((regularWidth - width) / (regularWidth - compactWidth)).clamp(0, 1);
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
