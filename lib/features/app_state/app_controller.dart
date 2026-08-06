import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/sample_data.dart';
import '../../core/models/app_models.dart';
import '../../core/services/local_store_service.dart';
import '../../core/utils/formatters.dart';

final localStoreServiceProvider = Provider<LocalStoreService>(
  (ref) => LocalStoreService(),
);

final appControllerProvider = NotifierProvider<AppController, AppState>(
  AppController.new,
);

final routerRefreshProvider = Provider<ValueNotifier<int>>((ref) {
  final notifier = ValueNotifier<int>(0);
  ref.listen(
    appControllerProvider.select(
      (state) => (state.initialized, state.adminSession?.uid),
    ),
    (previousValue, nextValue) {
      notifier.value++;
    },
  );
  return notifier;
});

class AppState {
  const AppState({
    this.initialized = false,
    this.loading = false,
    this.submittingOrder = false,
    this.adminLoading = false,
    this.errorMessage,
    this.lastSubmittedOrderId,
    this.categories = const [],
    this.products = const [],
    this.cart = const [],
    this.orders = const [],
    this.settings = const AppSettings(),
    this.customerDraft = const CustomerDraft(),
    this.adminSession,
  });

  final bool initialized;
  final bool loading;
  final bool submittingOrder;
  final bool adminLoading;
  final String? errorMessage;
  final int? lastSubmittedOrderId;
  final List<Category> categories;
  final List<Product> products;
  final List<CartItem> cart;
  final List<OrderRequest> orders;
  final AppSettings settings;
  final CustomerDraft customerDraft;
  final AdminSession? adminSession;

  int get cartCount => cart.fold(0, (sum, item) => sum + item.quantity);
  int get cartTotalCentavos =>
      cart.fold(0, (sum, item) => sum + item.estimatedSubtotalCentavos);

  AppState copyWith({
    bool? initialized,
    bool? loading,
    bool? submittingOrder,
    bool? adminLoading,
    Object? errorMessage = _sentinel,
    Object? lastSubmittedOrderId = _sentinel,
    List<Category>? categories,
    List<Product>? products,
    List<CartItem>? cart,
    List<OrderRequest>? orders,
    AppSettings? settings,
    CustomerDraft? customerDraft,
    Object? adminSession = _sentinel,
  }) {
    return AppState(
      initialized: initialized ?? this.initialized,
      loading: loading ?? this.loading,
      submittingOrder: submittingOrder ?? this.submittingOrder,
      adminLoading: adminLoading ?? this.adminLoading,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
      lastSubmittedOrderId: lastSubmittedOrderId == _sentinel
          ? this.lastSubmittedOrderId
          : lastSubmittedOrderId as int?,
      categories: categories ?? this.categories,
      products: products ?? this.products,
      cart: cart ?? this.cart,
      orders: orders ?? this.orders,
      settings: settings ?? this.settings,
      customerDraft: customerDraft ?? this.customerDraft,
      adminSession: adminSession == _sentinel
          ? this.adminSession
          : adminSession as AdminSession?,
    );
  }
}

class AppController extends Notifier<AppState> {
  late final LocalStoreService _store;

  @override
  AppState build() {
    _store = ref.read(localStoreServiceProvider);
    Future<void>.microtask(_initialize);
    return const AppState();
  }

  Future<void> _initialize() async {
    try {
      final persisted = await _store.load();
      if (persisted == null) {
        state = state.copyWith(
          initialized: true,
          categories: sampleCategories,
          products: sampleProducts,
          settings: const AppSettings(),
        );
        await _persist();
        return;
      }

      state = state.copyWith(
        initialized: true,
        categories: persisted.categories,
        products: persisted.products,
        orders: persisted.orders,
        settings: persisted.settings,
        cart: persisted.cart,
        customerDraft: persisted.customerDraft,
        adminSession: persisted.adminSession,
      );
    } catch (_) {
      await _store.clear();
      state = state.copyWith(
        initialized: true,
        categories: sampleCategories,
        products: sampleProducts,
        orders: const [],
        settings: const AppSettings(),
        cart: const [],
        customerDraft: const CustomerDraft(),
      );
      await _persist();
    }
  }

  List<Category> get publicCategories =>
      state.categories.where((item) => item.isActive).toList();

  List<Product> publicProductsFor({
    required String categoryId,
    required String query,
  }) {
    final activeCategoryIds = publicCategories.map((item) => item.id).toSet();
    final normalizedQuery = query.trim().toLowerCase();
    return state.products.where((product) {
      final categoryMatch = categoryId == 'all'
          ? true
          : product.categoryId.toString() == categoryId;
      final publiclyVisible =
          product.isActive && activeCategoryIds.contains(product.categoryId);
      final searchMatch = normalizedQuery.isEmpty
          ? true
          : product.normalizedName.contains(normalizedQuery);
      return categoryMatch && publiclyVisible && searchMatch;
    }).toList();
  }

  List<Product> get bestSellerProducts {
    if (!state.settings.bestSellersEnabled) {
      return const [];
    }

    final products = publicProductsFor(categoryId: 'all', query: '')
      ..sort((a, b) {
        final quantityCompare = b.validOrderedQuantity.compareTo(
          a.validOrderedQuantity,
        );
        if (quantityCompare != 0) {
          return quantityCompare;
        }
        return b.validOrderCount.compareTo(a.validOrderCount);
      });

    final rankedProducts = products
        .where((product) => product.validOrderedQuantity > 0)
        .take(state.settings.bestSellersLimit)
        .toList();
    if (rankedProducts.isNotEmpty) {
      return rankedProducts;
    }

    final mockPriority = {
      for (var i = 0; i < sampleBestSellerProductIds.length; i++)
        sampleBestSellerProductIds[i]: i,
    };
    final mockedProducts = [...products]
      ..sort((a, b) {
        final aPriority = mockPriority[a.id] ?? 1 << 20;
        final bPriority = mockPriority[b.id] ?? 1 << 20;
        if (aPriority != bPriority) {
          return aPriority.compareTo(bPriority);
        }
        return a.name.compareTo(b.name);
      });

    return mockedProducts
        .where((product) => mockPriority.containsKey(product.id))
        .take(state.settings.bestSellersLimit)
        .toList();
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  Future<void> addToCart(Product product, {int quantity = 1}) async {
    final now = DateTime.now();
    final existingIndex = state.cart.indexWhere(
      (item) => item.productId == product.id,
    );
    final nextCart = [...state.cart];

    if (existingIndex == -1) {
      nextCart.add(
        CartItem(
          id: product.id,
          productId: product.id,
          productName: product.name,
          unit: product.displayUnit,
          referenceUnitPriceCentavos: product.referencePriceCentavos,
          photoUrl: product.photoUrl,
          quantity: quantity,
          createdAt: now,
          updatedAt: now,
        ),
      );
    } else {
      nextCart[existingIndex] = nextCart[existingIndex].copyWith(
        quantity: nextCart[existingIndex].quantity + quantity,
        updatedAt: now,
      );
    }

    state = state.copyWith(cart: nextCart);
    await _persist();
  }

  Future<void> updateCartQuantity(int productId, int quantity) async {
    final now = DateTime.now();
    final next = state.cart
        .map((item) {
          if (item.productId != productId) {
            return item;
          }
          return item.copyWith(quantity: quantity, updatedAt: now);
        })
        .where((item) => item.quantity > 0)
        .toList();

    state = state.copyWith(cart: next);
    await _persist();
  }

  Future<void> removeFromCart(int productId) async {
    state = state.copyWith(
      cart: state.cart.where((item) => item.productId != productId).toList(),
    );
    await _persist();
  }

  Future<void> addOrderToCart(OrderRequest order) async {
    final now = DateTime.now();
    final nextCart = order.items
        .map(
          (orderItem) => CartItem(
            id: orderItem.id,
            productId: orderItem.productId,
            productName: orderItem.productName,
            unit: orderItem.unit,
            referenceUnitPriceCentavos: orderItem.referenceUnitPriceCentavos,
            photoUrl: orderItem.photoUrlSnapshot,
            quantity: orderItem.requestedQuantity,
            createdAt: orderItem.createdAt ?? order.createdAt,
            updatedAt: now,
          ),
        )
        .toList();

    state = state.copyWith(
      cart: nextCart,
      customerDraft: order.customer.copyWith(
        normalizedMobileNumber: normalizePhoneNumber(
          order.customer.mobileNumber,
        ),
        updatedAt: now,
      ),
    );
    await _persist();
  }

  Future<void> updateCustomerDraft(CustomerDraft draft) async {
    final now = DateTime.now();
    state = state.copyWith(
      customerDraft: draft.copyWith(
        createdAt: draft.createdAt ?? state.customerDraft.createdAt ?? now,
        updatedAt: now,
      ),
    );
    await _persist();
  }

  String? validateCheckoutDraft(CustomerDraft draft) {
    if (draft.name.trim().isEmpty) {
      return 'Customer name is required.';
    }
    if (!isValidPhilippineMobile(draft.mobileNumber.trim())) {
      return 'Enter a valid Philippine mobile number.';
    }
    if (draft.fulfillmentMethod == FulfillmentMethod.delivery &&
        draft.barangay.trim().isEmpty) {
      return 'Place is required.';
    }
    if (state.cart.isEmpty) {
      return 'Add at least one product before submitting.';
    }
    return null;
  }

  Future<int?> submitOrder() async {
    final error = validateCheckoutDraft(state.customerDraft);
    if (error != null) {
      state = state.copyWith(errorMessage: error);
      return null;
    }
    if (state.submittingOrder) {
      return null;
    }

    state = state.copyWith(submittingOrder: true, errorMessage: null);
    final now = DateTime.now();
    final orderId =
        (state.orders.map((item) => item.id).fold<int>(0, (max, value) {
          return value > max ? value : max;
        })) +
        1;
    final nextSerial = state.orders.length + 1;
    final date =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final reference = 'AS-$date-${nextSerial.toString().padLeft(4, '0')}';

    final normalizedCustomer = state.customerDraft.copyWith(
      normalizedMobileNumber: normalizePhoneNumber(
        state.customerDraft.mobileNumber,
      ),
    );
    final items = state.cart
        .map(
          (item) => OrderItem(
            id: item.productId,
            productId: item.productId,
            productName: item.productName,
            unit: item.unit,
            requestedQuantity: item.quantity,
            referenceUnitPriceCentavos: item.referenceUnitPriceCentavos,
            estimatedSubtotalCentavos: item.estimatedSubtotalCentavos,
            quotedUnitPriceCentavos: item.referenceUnitPriceCentavos,
            photoUrlSnapshot: item.photoUrl,
            descriptionSnapshot: null,
            createdAt: item.createdAt ?? now,
            updatedAt: now,
          ),
        )
        .toList();

    final order = OrderRequest(
      id: orderId,
      referenceNumber: reference,
      customer: normalizedCustomer,
      items: items,
      estimatedTotalCentavos: state.cartTotalCentavos,
      fulfillmentMethod: normalizedCustomer.fulfillmentMethod,
      deliveryFeeCentavos: 0,
      discountCentavos: 0,
      manualAdjustmentCentavos: 0,
      finalQuotedTotalCentavos: 0,
      status: OrderStatus.newRequest,
      customerConfirmation: CustomerConfirmationStatus.pending,
      bestSellerMetricsApplied: false,
      createdAt: now,
      updatedAt: now,
      statusHistory: const [],
    );

    state = state.copyWith(
      submittingOrder: false,
      orders: [order, ...state.orders],
      cart: const [],
      lastSubmittedOrderId: orderId,
      customerDraft: const CustomerDraft(),
    );
    await _persist();
    return orderId;
  }

  Future<bool> loginAdmin({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(adminLoading: true, errorMessage: null);
    final success =
        email.trim().toLowerCase() == demoAdminEmail &&
        password == demoAdminPassword;

    if (!success) {
      state = state.copyWith(
        adminLoading: false,
        errorMessage: 'Invalid admin credentials.',
      );
      return false;
    }

    state = state.copyWith(
      adminLoading: false,
      adminSession: AdminSession(
        uid: 'demo-admin',
        email: demoAdminEmail,
        displayName: 'Andrew Admin',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    await _persist();
    return true;
  }

  Future<void> logoutAdmin() async {
    state = state.copyWith(adminSession: null);
    await _persist();
  }

  Future<void> saveProduct(Product product) async {
    final now = DateTime.now();
    final category = state.categories.firstWhere(
      (item) => item.id == product.categoryId,
    );
    final updated = product.copyWith(
      name: product.name.trim(),
      categoryNameSnapshot: category.name,
      quantity: product.quantity.trim(),
      unit: product.unit.trim(),
      type: product.type.trim(),
      priceUpdatedAt: product.priceUpdatedAt,
      createdAt: product.createdAt ?? now,
      updatedAt: now,
    );
    final next = [...state.products];
    final index = next.indexWhere((item) => item.id == updated.id);
    if (index == -1) {
      next.add(updated);
    } else {
      next[index] = updated;
    }
    state = state.copyWith(products: next, errorMessage: null);
    await _persist();
  }

  Future<void> deleteProduct(int productId) async {
    state = state.copyWith(
      products: state.products.where((item) => item.id != productId).toList(),
      cart: state.cart.where((item) => item.productId != productId).toList(),
      errorMessage: null,
    );
    await _persist();
  }

  Future<void> saveCategory(Category category) async {
    final next = [...state.categories];
    final index = next.indexWhere((item) => item.id == category.id);
    if (index == -1) {
      next.insert(0, category);
    } else {
      next[index] = category;
    }
    state = state.copyWith(categories: next, errorMessage: null);
    await _persist();
  }

  Future<void> deleteCategory(int categoryId) async {
    final nextCategories = state.categories
        .where((item) => item.id != categoryId)
        .toList();
    final nextProducts = state.products.map((product) {
      if (product.categoryId != categoryId) {
        return product;
      }
      return product.copyWith(categoryId: 8, categoryNameSnapshot: 'Others');
    }).toList();

    state = state.copyWith(
      categories: nextCategories,
      products: nextProducts,
      errorMessage: null,
    );
    await _persist();
  }

  Future<void> reorderCategories(int oldIndex, int newIndex) async {
    final next = [...state.categories];
    if (oldIndex < 0 || oldIndex >= next.length) {
      return;
    }
    if (newIndex < 0 || newIndex > next.length) {
      return;
    }

    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    final moved = next.removeAt(oldIndex);
    next.insert(newIndex, moved);
    state = state.copyWith(categories: next, errorMessage: null);
    await _persist();
  }

  Future<void> reorderCategoriesByIds(List<int> orderedIds) async {
    final categoryById = {
      for (final category in state.categories) category.id: category,
    };
    final ordered = orderedIds
        .map((id) => categoryById[id])
        .whereType<Category>()
        .toList();
    final remaining = state.categories
        .where((category) => !orderedIds.contains(category.id))
        .toList();

    state = state.copyWith(
      categories: [...ordered, ...remaining],
      errorMessage: null,
    );
    await _persist();
  }

  Future<void> saveSettings(AppSettings settings) async {
    final now = DateTime.now();
    state = state.copyWith(
      settings: settings.copyWith(
        createdAt: settings.createdAt ?? state.settings.createdAt ?? now,
        updatedAt: now,
      ),
    );
    await _persist();
  }

  Future<void> updateOrder(OrderRequest nextOrder) async {
    final currentOrder = state.orders.firstWhere(
      (item) => item.id == nextOrder.id,
    );
    final updatedOrder = _applyBestSellerMetrics(currentOrder, nextOrder);
    final updatedOrders = state.orders
        .map((item) => item.id == nextOrder.id ? updatedOrder : item)
        .toList();

    state = state.copyWith(orders: updatedOrders);
    await _persist();
  }

  OrderRequest _applyBestSellerMetrics(
    OrderRequest previous,
    OrderRequest next,
  ) {
    final wasCounted = previous.bestSellerMetricsApplied;
    final shouldCount = _isBestSellerStatus(next.status);
    var products = [...state.products];
    var metricsApplied = wasCounted;

    if (!wasCounted && shouldCount) {
      products = _updateProductMetrics(products, next.items, add: true);
      metricsApplied = true;
    }

    if (wasCounted && !_isBestSellerStatus(next.status)) {
      products = _updateProductMetrics(products, previous.items, add: false);
      metricsApplied = false;
    }

    state = state.copyWith(products: products);
    return next.copyWith(bestSellerMetricsApplied: metricsApplied);
  }

  List<Product> _updateProductMetrics(
    List<Product> source,
    List<OrderItem> items, {
    required bool add,
  }) {
    return source.map((product) {
      final matching = items.where((item) => item.productId == product.id);
      if (matching.isEmpty) {
        return product;
      }
      final quantity = matching.fold(
        0,
        (sum, item) => sum + item.requestedQuantity,
      );
      return product.copyWith(
        validOrderedQuantity:
            product.validOrderedQuantity + (add ? quantity : -quantity),
        validOrderCount: product.validOrderCount + (add ? 1 : -1),
        lastValidOrderAt: add ? DateTime.now() : product.lastValidOrderAt,
      );
    }).toList();
  }

  bool _isBestSellerStatus(OrderStatus status) {
    return {
      OrderStatus.confirmed,
      OrderStatus.preparing,
      OrderStatus.readyForPickup,
      OrderStatus.outForDelivery,
      OrderStatus.completed,
    }.contains(status);
  }

  Future<void> _persist() async {
    await _store.save(
      PersistedData(
        categories: state.categories,
        products: state.products,
        orders: state.orders,
        settings: state.settings,
        cart: state.cart,
        customerDraft: state.customerDraft,
        adminSession: state.adminSession,
        createdAt: state.initialized
            ? state.settings.createdAt
            : DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }
}

const _sentinel = Object();
