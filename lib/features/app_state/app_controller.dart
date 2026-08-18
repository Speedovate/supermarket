import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/barangays.dart';
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
    this.barangays = const [],
    this.banners = const [],
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
  final List<Barangay> barangays;
  final List<AppBanner> banners;
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
    List<Barangay>? barangays,
    List<AppBanner>? banners,
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
      barangays: barangays ?? this.barangays,
      banners: banners ?? this.banners,
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
  static const _defaultStoreContactNumber = '09064493206';
  static const _defaultFacebookMessengerUrl =
      'https://www.facebook.com/andrew.s.supermarket.2024';

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
        _applyDefaultState();
        await _persist();
        return;
      }

      _applyPersistedState(persisted);
    } catch (_) {
      await _store.clear();
      _applyDefaultState();
      await _persist();
    }
  }

  Future<void> reloadFromStore() async {
    try {
      final persisted = await _store.load();
      if (persisted == null) {
        return;
      }
      _applyPersistedState(persisted);
    } catch (_) {
      // Keep the current in-memory state if refresh fails.
    }
  }

  void _applyDefaultState() {
    state = state.copyWith(
      initialized: true,
      categories: sampleCategories,
      barangays: sampleBarangays,
      banners: sampleBanners,
      products: sampleProducts,
      orders: const [],
      settings: const AppSettings(),
      cart: const [],
      customerDraft: const CustomerDraft(),
      adminSession: null,
    );
  }

  void _applyPersistedState(PersistedData persisted) {
    state = state.copyWith(
      initialized: true,
      categories: persisted.categories,
      barangays: _normalizeBarangays(
        persisted.barangays,
        settings: persisted.settings,
      ),
      banners: persisted.banners,
      products: persisted.products,
      orders: persisted.orders,
      settings: _normalizeSettings(persisted.settings),
      cart: persisted.cart,
      customerDraft: _resolveAutofillDraft(
        currentDraft: persisted.customerDraft,
        orders: persisted.orders,
      ),
      adminSession: persisted.adminSession,
    );
  }

  AppSettings _normalizeSettings(AppSettings settings) {
    return settings.copyWith(
      storeContactNumber: settings.storeContactNumber.trim().isEmpty
          ? _defaultStoreContactNumber
          : settings.storeContactNumber.trim(),
      facebookMessengerUrl: settings.facebookMessengerUrl.trim().isEmpty
          ? _defaultFacebookMessengerUrl
          : settings.facebookMessengerUrl.trim(),
    );
  }

  List<Barangay> _normalizeBarangays(
    List<Barangay> persistedBarangays, {
    required AppSettings settings,
  }) {
    if (persistedBarangays.isNotEmpty) {
      final sanitized = persistedBarangays
          .where((item) => item.name.trim().isNotEmpty)
          .map(
            (item) => item.copyWith(
              name: formatBarangayName(item.name),
              cutoffWeekday:
                  item.cutoffWeekday >= DateTime.monday &&
                      item.cutoffWeekday <= DateTime.sunday
                  ? item.cutoffWeekday
                  : DateTime.monday,
              cutoffMinutes:
                  item.cutoffMinutes >= 0 && item.cutoffMinutes < 1440
                  ? item.cutoffMinutes
                  : 5 * 60,
            ),
          )
          .toList();
      if (sanitized.isNotEmpty) {
        sanitized.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        return sanitized;
      }
    }

    final fallbackNames = settings.serviceableBarangays.isNotEmpty
        ? settings.serviceableBarangays
        : puertoPrincesaBarangays;
    final baseDate = DateTime(2026, 8, 1);
    return List<Barangay>.generate(fallbackNames.length, (index) {
      final name = formatBarangayName(fallbackNames[index]);
      final matchedSample = sampleBarangays.cast<Barangay?>().firstWhere(
        (item) => item?.name.toLowerCase() == name.toLowerCase(),
        orElse: () => null,
      );
      if (matchedSample != null) {
        return matchedSample;
      }
      final seededDate = baseDate.add(Duration(days: index));
      return Barangay(
        id: index + 1,
        name: name,
        isActive: true,
        cutoffWeekday: DateTime.monday,
        cutoffMinutes: 5 * 60,
        createdAt: seededDate,
        updatedAt: seededDate,
      );
    });
  }

  CustomerDraft _resolveAutofillDraft({
    required CustomerDraft currentDraft,
    required List<OrderRequest> orders,
  }) {
    final hasDraftContent =
        currentDraft.name.trim().isNotEmpty ||
        currentDraft.mobileNumber.trim().isNotEmpty ||
        currentDraft.barangay.trim().isNotEmpty;
    if (hasDraftContent || orders.isEmpty) {
      return currentDraft;
    }

    final latestOrder = [...orders]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final latestCustomer = latestOrder.first.customer;
    final now = DateTime.now();
    return latestCustomer.copyWith(
      normalizedMobileNumber: normalizePhoneNumber(latestCustomer.mobileNumber),
      createdAt: currentDraft.createdAt ?? latestCustomer.createdAt ?? now,
      updatedAt: now,
    );
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
      final isUnassignedCategory = !activeCategoryIds.contains(
        product.category,
      );
      final categoryMatch = switch (categoryId) {
        'all' => true,
        'others' => isUnassignedCategory,
        _ => product.category.toString() == categoryId,
      };
      final publiclyVisible =
          product.active &&
          (activeCategoryIds.contains(product.category) ||
              isUnassignedCategory);
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

    final settings = state.settings;
    final metrics = settings.bestSellerBasis == BestSellerBasis.lifetime
        ? {
            for (final product in state.products)
              product.id: (
                quantity: product.sold,
                count: product.sold > 0 ? 1 : 0,
              ),
          }
        : _recentBestSellerMetrics();

    final products = publicProductsFor(categoryId: 'all', query: '')
      ..sort((a, b) {
        final aMetrics = metrics[a.id] ?? (quantity: 0, count: 0);
        final bMetrics = metrics[b.id] ?? (quantity: 0, count: 0);
        final quantityCompare = bMetrics.quantity.compareTo(aMetrics.quantity);
        if (quantityCompare != 0) {
          return quantityCompare;
        }
        return bMetrics.count.compareTo(aMetrics.count);
      });

    final rankedProducts = products
        .where(
          (product) =>
              (metrics[product.id]?.quantity ?? 0) >=
              settings.bestSellerMinSoldUnits,
        )
        .toList();
    if (rankedProducts.isNotEmpty) {
      return settings.bestSellersShowAll
          ? rankedProducts
          : rankedProducts.take(settings.bestSellersLimit).toList();
    }
    return const [];
  }

  Map<int, ({int quantity, int count})> _recentBestSellerMetrics() {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final metrics = <int, ({int quantity, int count})>{};
    for (final order in state.orders) {
      if (order.status != OrderStatus.completed ||
          order.createdAt.isBefore(cutoff)) {
        continue;
      }
      for (final item in order.items) {
        final current = metrics[item.productId] ?? (quantity: 0, count: 0);
        metrics[item.productId] = (
          quantity: current.quantity + item.requestedQuantity,
          count: current.count + 1,
        );
      }
    }
    return metrics;
  }

  List<Barangay> get activeBarangays {
    final active =
        state.barangays
            .where((item) => item.isActive && item.name.trim().isNotEmpty)
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    if (active.isNotEmpty) {
      return active;
    }
    return _normalizeBarangays(
        const [],
        settings: state.settings,
      ).where((item) => item.isActive).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  List<String> get serviceableBarangays =>
      activeBarangays.map((item) => item.name).toList();

  Barangay? barangayByName(String name) {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    for (final barangay in state.barangays) {
      if (barangay.name.trim().toLowerCase() == normalized) {
        return barangay;
      }
    }
    for (final barangay in _normalizeBarangays(
      const [],
      settings: state.settings,
    )) {
      if (barangay.name.trim().toLowerCase() == normalized) {
        return barangay;
      }
    }
    return null;
  }

  String? barangayCutoffMessage(String name, {DateTime? now}) {
    final barangay = barangayByName(name);
    if (barangay == null) {
      return null;
    }
    final current = now ?? DateTime.now();
    final cutoffLabel = formatBarangayCutoffSchedule(barangay);
    final currentWeekCutoff = _currentWeekCutoff(
      barangay: barangay,
      reference: current,
    );
    if (!current.isAfter(currentWeekCutoff)) {
      return cutoffLabel;
    }
    final nextCutoff = currentWeekCutoff.add(const Duration(days: 7));
    return '$cutoffLabel. Your order will be processed next ${displayWeekday(nextCutoff.weekday)} or you can select pickup instead to get your order faster.';
  }

  bool isBarangayCutoffReached(String name, {DateTime? now}) {
    final barangay = barangayByName(name);
    if (barangay == null) {
      return false;
    }
    final current = now ?? DateTime.now();
    final currentWeekCutoff = _currentWeekCutoff(
      barangay: barangay,
      reference: current,
    );
    return current.isAfter(currentWeekCutoff);
  }

  DateTime _currentWeekCutoff({
    required Barangay barangay,
    required DateTime reference,
  }) {
    return _cutoffDateForReference(
      reference,
      weekday: barangay.cutoffWeekday,
      cutoffMinutes: barangay.cutoffMinutes,
    );
  }

  DateTime _cutoffDateForReference(
    DateTime reference, {
    required int weekday,
    required int cutoffMinutes,
  }) {
    final startOfDay = DateTime(reference.year, reference.month, reference.day);
    final daysUntil = weekday - reference.weekday;
    return startOfDay.add(Duration(days: daysUntil, minutes: cutoffMinutes));
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

  Future<void> replaceCartAndDraft({
    required List<CartItem> cart,
    required CustomerDraft customerDraft,
  }) async {
    state = state.copyWith(cart: [...cart], customerDraft: customerDraft);
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
      return 'Please enter your name';
    }
    if (!isValidPhilippineMobile(draft.mobileNumber.trim())) {
      return 'Please enter your phone number';
    }
    final requiresPlace = state.settings.requirePlaceForDeliveryOnly
        ? draft.fulfillmentMethod == FulfillmentMethod.delivery
        : true;
    if (requiresPlace && draft.barangay.trim().isEmpty) {
      return 'Please select a barangay';
    }
    if (draft.fulfillmentMethod == FulfillmentMethod.delivery &&
        draft.barangay.trim().isNotEmpty &&
        !serviceableBarangays.contains(draft.barangay.trim())) {
      return 'Please select a serviceable barangay';
    }
    if (draft.fulfillmentMethod == FulfillmentMethod.delivery &&
        draft.addressStreet.trim().isEmpty) {
      return 'Please enter your street/landmark';
    }
    if (draft.fulfillmentMethod == FulfillmentMethod.delivery &&
        state.cartTotalCentavos < state.settings.minimumDeliveryOrderAmount) {
      return 'Minimum order for delivery not reached';
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
      status: OrderStatus.waiting,
      createdAt: now,
      updatedAt: now,
      total: state.cartTotalCentavos,
      name: normalizedCustomer.name,
      phone: normalizedCustomer.mobileNumber,
      method: normalizedCustomer.fulfillmentMethod,
      place: normalizedCustomer.barangay,
      addressStreet: normalizedCustomer.addressStreet,
      addressLandmark: normalizedCustomer.addressLandmark,
      products: items,
    );

    state = state.copyWith(
      submittingOrder: false,
      orders: [order, ...state.orders],
      cart: const [],
      lastSubmittedOrderId: orderId,
      customerDraft: normalizedCustomer.copyWith(
        createdAt: normalizedCustomer.createdAt ?? now,
        updatedAt: now,
      ),
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
        displayName: 'Arjie Lim',
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
    final updated = product.copyWith(
      name: product.name.trim(),
      details: product.details.trim(),
      photoUrl: product.photoUrl?.trim().isEmpty ?? true
          ? null
          : product.photoUrl?.trim(),
      photoStoragePath: product.photoStoragePath?.trim().isEmpty ?? true
          ? null
          : product.photoStoragePath?.trim(),
      createdAt: product.createdAt,
      updatedAt: now,
    );
    final next = [...state.products];
    final index = next.indexWhere((item) => item.id == updated.id);
    if (index == -1) {
      next.add(updated);
    } else {
      next[index] = updated;
    }
    final nextCart = state.cart
        .map(
          (item) => item.productId == updated.id
              ? item.copyWith(
                  productName: updated.name,
                  unit: updated.displayUnit,
                  referenceUnitPriceCentavos: updated.referencePriceCentavos,
                  photoUrl: updated.photoUrl,
                  updatedAt: now,
                )
              : item,
        )
        .toList();
    state = state.copyWith(products: next, cart: nextCart, errorMessage: null);
    await _persist();
  }

  Future<void> saveBanner(AppBanner banner) async {
    final now = DateTime.now();
    final updated = banner.copyWith(
      imageUrl: banner.imageUrl.trim(),
      externalUrl: banner.externalUrl?.trim().isEmpty ?? true
          ? null
          : banner.externalUrl?.trim(),
      createdAt: banner.createdAt,
      updatedAt: now,
    );
    final next = [...state.banners];
    final index = next.indexWhere((item) => item.id == updated.id);
    if (index == -1) {
      next.add(updated);
    } else {
      next[index] = updated;
    }
    state = state.copyWith(banners: next, errorMessage: null);
    await _persist();
  }

  Future<void> deleteBanner(int bannerId) async {
    state = state.copyWith(
      banners: state.banners.where((item) => item.id != bannerId).toList(),
      errorMessage: null,
    );
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
      if (product.category != categoryId) {
        return product;
      }
      return product.copyWith(category: 8);
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

  Future<void> saveBarangay(Barangay barangay) async {
    final now = DateTime.now();
    final updated = barangay.copyWith(
      name: formatBarangayName(barangay.name),
      createdAt: barangay.createdAt,
      updatedAt: now,
    );
    final next = [...state.barangays];
    final index = next.indexWhere((item) => item.id == updated.id);
    if (index == -1) {
      next.add(updated);
    } else {
      next[index] = updated;
    }
    next.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    state = state.copyWith(barangays: next, errorMessage: null);
    await _persist();
  }

  Future<void> deleteBarangay(int barangayId) async {
    final next = state.barangays.where((item) => item.id != barangayId).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    state = state.copyWith(barangays: next, errorMessage: null);
    await _persist();
  }

  Future<void> updateAdminProfile({
    required String displayName,
    required String email,
    required AppSettings settings,
  }) async {
    final now = DateTime.now();
    final currentSession = state.adminSession;
    state = state.copyWith(
      adminSession: currentSession?.copyWith(
        displayName: displayName,
        email: email,
        createdAt: currentSession.createdAt ?? now,
        updatedAt: now,
      ),
      settings: settings.copyWith(
        createdAt: settings.createdAt ?? state.settings.createdAt ?? now,
        updatedAt: now,
      ),
    );
    await _persist();
  }

  Future<void> updateOrder(OrderRequest nextOrder) async {
    final currentOrder = state.orders
        .where((item) => item.id == nextOrder.id)
        .firstOrNull;
    final currentIsCompleted = currentOrder?.status == OrderStatus.completed;
    final nextIsCompleted = nextOrder.status == OrderStatus.completed;

    var nextProducts = state.products;
    if (currentOrder != null && (currentIsCompleted || nextIsCompleted)) {
      final previousTotals = currentIsCompleted
          ? _orderQuantityTotalsByProductId(currentOrder)
          : const <int, int>{};
      final nextTotals = nextIsCompleted
          ? _orderQuantityTotalsByProductId(nextOrder)
          : const <int, int>{};
      final affectedProductIds = {...previousTotals.keys, ...nextTotals.keys};

      nextProducts = state.products.map((product) {
        if (!affectedProductIds.contains(product.id)) {
          return product;
        }
        final previousQuantity = previousTotals[product.id] ?? 0;
        final nextQuantity = nextTotals[product.id] ?? 0;
        final delta = nextQuantity - previousQuantity;
        if (delta == 0) {
          return product;
        }
        return product.copyWith(
          sold: math.max(0, product.sold + delta),
          updatedAt: DateTime.now(),
        );
      }).toList();
    }

    final updatedOrders = state.orders
        .map((item) => item.id == nextOrder.id ? nextOrder : item)
        .toList();

    state = state.copyWith(orders: updatedOrders, products: nextProducts);
    await _persist();
  }

  Map<int, int> _orderQuantityTotalsByProductId(OrderRequest order) {
    final totals = <int, int>{};
    for (final item in order.items) {
      totals.update(
        item.productId,
        (value) => value + item.requestedQuantity,
        ifAbsent: () => item.requestedQuantity,
      );
    }
    return totals;
  }

  Future<void> _persist() async {
    try {
      await _store.save(
        PersistedData(
          categories: state.categories,
          barangays: state.barangays,
          banners: state.banners,
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
    } catch (_) {
      state = state.copyWith(
        errorMessage:
            'Unable to save the latest local changes. Try a smaller product image.',
      );
    }
  }
}

const _sentinel = Object();
