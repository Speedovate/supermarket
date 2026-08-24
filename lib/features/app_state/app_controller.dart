import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/sample_data.dart';
import '../../core/models/app_models.dart';
import '../../core/services/firebase_auth_service.dart';
import '../../core/services/firebase_firestore_service.dart';
import '../../core/services/firebase_storage_service.dart';
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
    this.catalogHydrated = false,
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
  final bool catalogHydrated;
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
    bool? catalogHydrated,
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
      catalogHydrated: catalogHydrated ?? this.catalogHydrated,
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
  late final FirebaseAdminAuthService _auth;
  late final FirestoreCatalogService _firestoreCatalog;
  late final FirebaseProductImageStorageService _productImageStorage;
  StreamSubscription<List<Category>>? _categoriesSubscription;
  StreamSubscription<List<Barangay>>? _barangaysSubscription;
  StreamSubscription<List<AppBanner>>? _bannersSubscription;
  StreamSubscription<List<Product>>? _productsSubscription;
  StreamSubscription<AppSettings?>? _settingsSubscription;
  StreamSubscription<List<OrderRequest>>? _ordersSubscription;
  bool? _catalogRealtimeIncludesInactive;
  bool _realtimeSyncScheduled = false;
  static const _defaultStoreContactNumber = '09064493206';
  static const _defaultFacebookMessengerUrl =
      'https://www.facebook.com/andrew.s.supermarket.2024';

  bool _isCurrentAdminRoute() {
    final path = Uri.base.path;
    return path == '/admin' ||
        path == '/admin/' ||
        path.startsWith('/admin/');
  }

  bool _hasActiveAdminContext([AdminSession? session]) {
    return session != null && _isCurrentAdminRoute();
  }

  @override
  AppState build() {
    _store = ref.read(localStoreServiceProvider);
    _auth = ref.read(firebaseAdminAuthServiceProvider);
    _firestoreCatalog = ref.read(firestoreCatalogServiceProvider);
    _productImageStorage = ref.read(firebaseProductImageStorageServiceProvider);
    Future<void>.microtask(_initialize);
    return const AppState();
  }

  Future<void> _initialize() async {
    try {
      final persisted = await _store.load();
      if (persisted == null) {
        _applyDefaultState();
      } else {
        _applyPersistedState(persisted);
      }

      await _syncAdminSessionFromFirebase();
      unawaited(_hydratePublicDataFromFirebase());
      _scheduleRealtimeSync();
      unawaited(_refreshOrdersFromFirebase());
    } catch (_) {
      _applyDefaultState();
      await _syncAdminSessionFromFirebase();
      unawaited(_hydratePublicDataFromFirebase());
      _scheduleRealtimeSync();
      unawaited(_refreshOrdersFromFirebase());
    }
  }

  Future<void> reloadFromStore() async {
    try {
      final persisted = await _store.load();
      if (persisted == null) {
        return;
      }
      _applyPersistedState(persisted);
      await _syncAdminSessionFromFirebase();
      unawaited(_hydratePublicDataFromFirebase());
      _scheduleRealtimeSync();
      unawaited(_refreshOrdersFromFirebase());
    } catch (_) {
      // Keep the current in-memory state if refresh fails.
    }
  }

  Future<void> refreshFromFirebase() async {
    state = state.copyWith(loading: true);
    await _syncAdminSessionFromFirebase();
    await _hydratePublicDataFromFirebase();
    _startRealtimeSync();
    await _refreshOrdersFromFirebase();
  }

  void _startRealtimeSync() {
    _realtimeSyncScheduled = false;
    final includeInactive = _hasActiveAdminContext(state.adminSession);
    if (_catalogRealtimeIncludesInactive != includeInactive) {
      unawaited(_categoriesSubscription?.cancel());
      unawaited(_barangaysSubscription?.cancel());
      unawaited(_bannersSubscription?.cancel());
      unawaited(_productsSubscription?.cancel());
      _categoriesSubscription = null;
      _barangaysSubscription = null;
      _bannersSubscription = null;
      _productsSubscription = null;
      _catalogRealtimeIncludesInactive = includeInactive;
    }
    _categoriesSubscription ??= _firestoreCatalog.watchCategories(
      includeInactive: includeInactive,
    ).listen((categories) async {
      state = state.copyWith(categories: categories);
      await _persist();
    }, onError: _handleRealtimeSyncError);
    _barangaysSubscription ??= _firestoreCatalog.watchBarangays(
      includeInactive: includeInactive,
    ).listen((barangays) async {
      state = state.copyWith(
        barangays: _normalizeBarangays(barangays, settings: state.settings),
      );
      await _persist();
    }, onError: _handleRealtimeSyncError);
    _bannersSubscription ??= _firestoreCatalog.watchBanners(
      includeInactive: includeInactive,
    ).listen((banners) async {
      state = state.copyWith(banners: banners);
      await _persist();
    }, onError: _handleRealtimeSyncError);
    _productsSubscription ??= _firestoreCatalog.watchProducts(
      includeInactive: includeInactive,
    ).listen((products) async {
      state = state.copyWith(
        products: products,
        cart: _syncCartWithProducts(products: products),
      );
      await _persist();
    }, onError: _handleRealtimeSyncError);
    _settingsSubscription ??= _firestoreCatalog.watchSettings().listen((
      settings,
    ) async {
      if (settings == null) {
        return;
      }
      state = state.copyWith(settings: _normalizeSettings(settings));
      await _persist();
    }, onError: _handleRealtimeSyncError);
    _restartOrdersRealtimeSync();
    ref.onDispose(() {
      unawaited(_categoriesSubscription?.cancel());
      unawaited(_barangaysSubscription?.cancel());
      unawaited(_bannersSubscription?.cancel());
      unawaited(_productsSubscription?.cancel());
      unawaited(_settingsSubscription?.cancel());
      unawaited(_ordersSubscription?.cancel());
    });
  }

  void _scheduleRealtimeSync() {
    if (_realtimeSyncScheduled) {
      return;
    }
    _realtimeSyncScheduled = true;
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 900), () async {
        _startRealtimeSync();
      }),
    );
  }

  void _restartOrdersRealtimeSync() {
    unawaited(_ordersSubscription?.cancel());
    final adminSession = state.adminSession;
    final hasActiveAdminContext = _hasActiveAdminContext(adminSession);
    final trackedPhones = _customerLookupPhones();
    final stream = hasActiveAdminContext
        ? _firestoreCatalog.watchOrders()
        : _firestoreCatalog.watchOrdersForNormalizedPhones(
            trackedPhones,
          );
    _ordersSubscription = stream.listen((orders) async {
      final nextOrders = hasActiveAdminContext
          ? orders
          : _mergeOrdersPreservingLocal(
              existing: state.orders,
              incoming: orders,
              trackedPhones: trackedPhones,
            );
      state = state.copyWith(
        orders: nextOrders,
        products: hasActiveAdminContext
            ? _reconcileProductSoldWithOrders(
                products: state.products,
                orders: nextOrders,
                shouldPersistRemotely: true,
              ).products
            : state.products,
      );
      await _persist();
      if (hasActiveAdminContext) {
        final soldSync = _reconcileProductSoldWithOrders(
          products: state.products,
          orders: nextOrders,
          shouldPersistRemotely: true,
        );
        if (soldSync.changedProducts.isNotEmpty) {
          state = state.copyWith(products: soldSync.products);
          await _persist();
          await _firestoreCatalog.saveProducts(soldSync.changedProducts);
        }
      }
    }, onError: _handleRealtimeSyncError);
  }

  void _handleRealtimeSyncError(Object error, StackTrace stackTrace) {
    if (error is FirebaseException && error.code == 'permission-denied') {
      state = state.copyWith(loading: false);
      return;
    }
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'app_state_realtime_sync',
        context: ErrorDescription('while listening to Firestore realtime data'),
      ),
    );
  }

  void _applyDefaultState() {
    state = state.copyWith(
      initialized: true,
      categories: const [],
      barangays: const [],
      banners: const [],
      products: const [],
      orders: const [],
      settings: const AppSettings(),
      cart: const [],
      customerDraft: const CustomerDraft(),
      adminSession: null,
      catalogHydrated: false,
    );
  }

  void _applyPersistedState(PersistedData persisted) {
    final sanitizedOrders = _hasActiveAdminContext(persisted.adminSession)
        ? persisted.orders
        : _filterClientVisibleOrders(
            persisted.orders,
            trackedPhones: _clientScopedPhoneSeeds(
              orders: persisted.orders,
              draft: persisted.customerDraft,
            ),
          );
    final syncedCart = _syncCartWithProducts(
      products: persisted.products,
      cart: persisted.cart,
    );
    final hasPersistedCatalogContent =
        persisted.categories.isNotEmpty ||
        persisted.barangays.isNotEmpty ||
        persisted.banners.isNotEmpty ||
        persisted.products.isNotEmpty;
    state = state.copyWith(
      initialized: true,
      categories: persisted.categories,
      barangays: _normalizeBarangays(
        persisted.barangays,
        settings: persisted.settings,
      ),
      banners: persisted.banners,
      products: persisted.products,
      orders: sanitizedOrders,
      settings: _normalizeSettings(persisted.settings),
      cart: syncedCart,
      customerDraft: _resolveAutofillDraft(
        currentDraft: persisted.customerDraft,
        orders: sanitizedOrders,
      ),
      adminSession: persisted.adminSession,
      catalogHydrated: hasPersistedCatalogContent,
    );
  }

  Future<void> _hydratePublicDataFromFirebase() async {
    final shouldManageLoading = state.loading || !state.catalogHydrated;
    final includeInactive = _hasActiveAdminContext(state.adminSession);
    if (shouldManageLoading) {
      state = state.copyWith(loading: true);
    }
    try {
      final catalogMeta = await _firestoreCatalog.loadCatalogMeta();
      if (catalogMeta != null &&
          state.catalogHydrated &&
          !_isPublicCatalogStale(catalogMeta)) {
        return;
      }

      var snapshot = await _firestoreCatalog.loadCatalogSnapshot(
        includeInactive: includeInactive,
      );
      if (snapshot == null) {
        await _firestoreCatalog.seedInitialData(
          categories: sampleCategories,
          barangays: sampleBarangays,
          banners: sampleBanners,
          products: sampleProducts,
          settings: const AppSettings(),
        );
        snapshot = await _firestoreCatalog.loadCatalogSnapshot(
          includeInactive: includeInactive,
        );
      }
      if (snapshot == null) {
        return;
      }

      state = state.copyWith(
        categories: snapshot.categories.isNotEmpty
            ? snapshot.categories
            : state.categories,
        barangays: snapshot.barangays.isNotEmpty
            ? _normalizeBarangays(
                snapshot.barangays,
                settings: snapshot.settings ?? state.settings,
              )
            : state.barangays,
        banners: snapshot.banners.isNotEmpty ? snapshot.banners : state.banners,
        products: snapshot.products,
        cart: _syncCartWithProducts(products: snapshot.products),
        settings: snapshot.settings == null
            ? state.settings
            : _normalizeSettings(snapshot.settings!),
        catalogHydrated: true,
      );
      await _persist();
    } catch (_) {
      // Keep current local session data if Firebase fetch fails.
    } finally {
      if (shouldManageLoading) {
        state = state.copyWith(loading: false);
      }
    }
  }

  bool _isPublicCatalogStale(CatalogMetaSnapshot meta) {
    return _isRemoteCollectionNewer(
          remote: meta.categoriesUpdatedAt,
          local: _latestCategoryUpdatedAt(state.categories),
        ) ||
        _isRemoteCollectionNewer(
          remote: meta.barangaysUpdatedAt,
          local: _latestBarangayUpdatedAt(state.barangays),
        ) ||
        _isRemoteCollectionNewer(
          remote: meta.bannersUpdatedAt,
          local: _latestBannerUpdatedAt(state.banners),
        ) ||
        _isRemoteCollectionNewer(
          remote: meta.productsUpdatedAt,
          local: _latestProductUpdatedAt(state.products),
        ) ||
        _isRemoteCollectionNewer(
          remote: meta.settingsUpdatedAt,
          local: state.settings.updatedAt ?? state.settings.createdAt,
        );
  }

  bool _isRemoteCollectionNewer({
    required DateTime? remote,
    required DateTime? local,
  }) {
    if (remote == null) {
      return false;
    }
    if (local == null) {
      return true;
    }
    return remote.isAfter(local);
  }

  DateTime? _latestCategoryUpdatedAt(List<Category> items) {
    if (items.isEmpty) {
      return null;
    }
    return items
        .map((item) => item.updatedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }

  DateTime? _latestBarangayUpdatedAt(List<Barangay> items) {
    if (items.isEmpty) {
      return null;
    }
    return items
        .map((item) => item.updatedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }

  DateTime? _latestBannerUpdatedAt(List<AppBanner> items) {
    if (items.isEmpty) {
      return null;
    }
    return items
        .map((item) => item.updatedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }

  DateTime? _latestProductUpdatedAt(List<Product> items) {
    if (items.isEmpty) {
      return null;
    }
    return items
        .map((item) => item.updatedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }

  Future<void> _syncAdminSessionFromFirebase() async {
    final user = _auth.currentUser;
    if (user == null) {
      state = state.copyWith(adminSession: null, initialized: true);
      await _persist();
      return;
    }

    final firestoreSession = await _firestoreCatalog.loadAdminSession(user.uid);
    if (firestoreSession == null) {
      await _auth.signOut();
      state = state.copyWith(adminSession: null, initialized: true);
      await _persist();
      _restartOrdersRealtimeSync();
      return;
    }

    state = state.copyWith(adminSession: firestoreSession, initialized: true);
    await _persist();
    _restartOrdersRealtimeSync();
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
    return settings.serviceableBarangays
        .asMap()
        .entries
        .where((entry) => entry.value.trim().isNotEmpty)
        .map(
          (entry) => Barangay(
            id: entry.key + 1,
            name: formatBarangayName(entry.value),
            isActive: true,
            cutoffWeekday: DateTime.monday,
            cutoffMinutes: 5 * 60,
            createdAt: DateTime(2026, 8, 18),
            updatedAt: DateTime(2026, 8, 18),
          ),
        )
        .toList();
  }

  CustomerDraft _resolveAutofillDraft({
    required CustomerDraft currentDraft,
    required List<OrderRequest> orders,
  }) {
    final hasDraftContent =
        currentDraft.name.trim().isNotEmpty ||
        currentDraft.mobileNumber.trim().isNotEmpty ||
        currentDraft.barangay.trim().isNotEmpty ||
        currentDraft.addressStreet.trim().isNotEmpty ||
        currentDraft.addressLandmark.trim().isNotEmpty ||
        currentDraft.note.trim().isNotEmpty;
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

  List<CartItem> _syncCartWithProducts({
    required List<Product> products,
    List<CartItem>? cart,
  }) {
    final sourceCart = cart ?? state.cart;
    if (sourceCart.isEmpty) {
      return sourceCart;
    }
    final productsById = {for (final product in products) product.id: product};
    return sourceCart
        .map((item) {
          final product = productsById[item.productId];
          if (product == null) {
            return null;
          }
          return item.copyWith(
            productName: product.name,
            unit: product.displayUnit,
            referenceUnitPriceCentavos: product.referencePriceCentavos,
            photoUrl: product.photoUrl,
          );
        })
        .nonNulls
        .toList();
  }

  List<Product> publicProductsFor({
    required String categoryId,
    required String query,
  }) {
    final activeCategoryIds = publicCategories.map((item) => item.id).toSet();
    final normalizedQuery = query.trim().toLowerCase();
    return state.products.where((product) {
      final isUnassignedCategory =
          product.category <= 0 || !activeCategoryIds.contains(product.category);
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
          : product.normalizedName.contains(normalizedQuery) ||
                product.details.toLowerCase().contains(normalizedQuery);
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
    final effectiveCutoff = current.isAfter(currentWeekCutoff)
        ? currentWeekCutoff.add(const Duration(days: 7))
        : currentWeekCutoff;
    final nextDeliveryStart = effectiveCutoff.add(const Duration(days: 1));
    final nextDeliveryEnd = effectiveCutoff.add(const Duration(days: 2));
    if (!current.isAfter(currentWeekCutoff)) {
      return '$cutoffLabel\n\nOrder will be delivered on ${displayWeekday(nextDeliveryStart.weekday)} or ${displayWeekday(nextDeliveryEnd.weekday)}.';
    }
    return '$cutoffLabel. Your order will be processed next ${displayWeekday(effectiveCutoff.weekday)} or you can select pickup instead to get your order faster.\n\nOrder will be delivered on ${displayWeekday(nextDeliveryStart.weekday)} or ${displayWeekday(nextDeliveryEnd.weekday)}.';
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
        normalizedMobileNumber: normalizePhoneNumber(draft.mobileNumber),
        createdAt: draft.createdAt ?? state.customerDraft.createdAt ?? now,
        updatedAt: now,
      ),
    );
    await _persist();
    _restartOrdersRealtimeSync();
    unawaited(_refreshOrdersFromFirebase());
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
    if (state.settings.minimumDeliveryOrderAmount > 0 &&
        state.cartTotalCentavos < state.settings.minimumDeliveryOrderAmount) {
      return 'Minimum order amount is ${formatPesos(state.settings.minimumDeliveryOrderAmount)}';
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

    try {
      state = state.copyWith(submittingOrder: true, errorMessage: null);
      final currentCart = [...state.cart];
      final currentOrders = [...state.orders];
      final currentCartTotalCentavos = state.cartTotalCentavos;
      final now = DateTime.now();
      final fallbackNextOrderId =
          currentOrders.fold<int>(
            0,
            (maxId, order) => math.max(maxId, order.id),
          ) +
          1;
      final orderId = await _firestoreCatalog.reserveNextOrderId(
        fallbackNextOrderId: fallbackNextOrderId,
      );
      final normalizedCustomer = state.customerDraft.copyWith(
        normalizedMobileNumber: normalizePhoneNumber(
          state.customerDraft.mobileNumber,
        ),
      );
      final items = currentCart
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
        total: currentCartTotalCentavos,
        name: normalizedCustomer.name,
        phone: normalizedCustomer.mobileNumber,
        method: normalizedCustomer.fulfillmentMethod,
        place: normalizedCustomer.barangay,
        addressStreet: normalizedCustomer.addressStreet,
        addressLandmark: normalizedCustomer.addressLandmark,
        products: items,
      );

      await _firestoreCatalog.saveOrder(order);
      state = state.copyWith(
        orders: [order, ...currentOrders],
        cart: const [],
        lastSubmittedOrderId: orderId,
        customerDraft: normalizedCustomer.copyWith(
          createdAt: normalizedCustomer.createdAt ?? now,
          updatedAt: now,
        ),
      );
      await _refreshOrdersFromFirebase();
      state = state.copyWith(submittingOrder: false);
      await _persist();
      return orderId;
    } on FirebaseException catch (error) {
      state = state.copyWith(
        submittingOrder: false,
        errorMessage: _mapFirebaseOperationError(error),
      );
      await _persist();
      return null;
    } catch (_) {
      state = state.copyWith(
        submittingOrder: false,
        errorMessage: 'Unable to submit your order right now.',
      );
      await _persist();
      return null;
    }
  }

  Future<bool> loginAdmin({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(adminLoading: true, errorMessage: null);
    try {
      final credential = await _auth.signIn(email: email, password: password);
      final user = credential.user;
      if (user == null) {
        state = state.copyWith(
          adminLoading: false,
          errorMessage: 'Unable to sign in.',
        );
        return false;
      }
      final adminSession = await _firestoreCatalog.loadAdminSession(user.uid);
      if (adminSession == null) {
        await _auth.signOut();
        state = state.copyWith(
          adminLoading: false,
          errorMessage: 'This account is not an admin.',
          adminSession: null,
        );
        await _persist();
        return false;
      }
      state = state.copyWith(
        adminLoading: false,
        adminSession: adminSession,
        errorMessage: null,
      );
      await _persist();
      _startRealtimeSync();
      _restartOrdersRealtimeSync();
      await _refreshOrdersFromFirebase();
      return true;
    } on FirebaseAuthException catch (error) {
      state = state.copyWith(
        adminLoading: false,
        errorMessage: _mapAdminLoginError(error),
      );
      return false;
    } on FirebaseException catch (error) {
      state = state.copyWith(
        adminLoading: false,
        errorMessage: _mapFirebaseOperationError(error),
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        adminLoading: false,
        errorMessage: 'Unable to sign in right now.',
      );
      return false;
    }
  }

  Future<void> logoutAdmin() async {
    await _auth.signOut();
    final trackedPhones = _clientScopedPhoneSeeds();
    state = state.copyWith(
      adminSession: null,
      orders: _filterClientVisibleOrders(state.orders, trackedPhones: trackedPhones),
    );
    await _persist();
    _startRealtimeSync();
    _restartOrdersRealtimeSync();
    await _refreshOrdersFromFirebase();
  }

  Future<void> saveProduct(Product product) async {
    final now = DateTime.now();
    final normalizedPhotoUrl = product.photoUrl?.trim();
    final normalizedPhotoStoragePath = product.photoStoragePath?.trim();
    final previousProduct = state.products
        .where((item) => item.id == product.id)
        .firstOrNull;
    final resolvedPhoto = await _resolveProductPhoto(
      productId: product.id,
      photoUrl: normalizedPhotoUrl,
      photoStoragePath: normalizedPhotoStoragePath,
    );
    final updated = product.copyWith(
      name: product.name.trim(),
      details: product.details.trim(),
      photoUrl: resolvedPhoto.photoUrl,
      photoStoragePath: resolvedPhoto.photoStoragePath,
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
    await _firestoreCatalog.saveProduct(updated);
    await _persist();
    if (previousProduct?.photoStoragePath != null &&
        previousProduct!.photoStoragePath != updated.photoStoragePath &&
        updated.photoStoragePath != null) {
      unawaited(
        _productImageStorage.deleteByPath(previousProduct.photoStoragePath),
      );
    }
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
    await _firestoreCatalog.saveBanner(updated);
    await _persist();
  }

  Future<void> deleteBanner(int bannerId) async {
    state = state.copyWith(
      banners: state.banners.where((item) => item.id != bannerId).toList(),
      errorMessage: null,
    );
    await _firestoreCatalog.deleteBanner(bannerId);
    await _persist();
  }

  Future<void> deleteProduct(int productId) async {
    final removedProduct = state.products
        .where((item) => item.id == productId)
        .firstOrNull;
    state = state.copyWith(
      products: state.products.where((item) => item.id != productId).toList(),
      cart: state.cart.where((item) => item.productId != productId).toList(),
      errorMessage: null,
    );
    await _firestoreCatalog.deleteProduct(productId);
    await _persist();
    unawaited(_productImageStorage.deleteByPath(removedProduct?.photoStoragePath));
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
    await _firestoreCatalog.saveCategory(category, sortOrder: next.indexWhere((item) => item.id == category.id));
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
      return product.copyWith(category: 0);
    }).toList();

    state = state.copyWith(
      categories: nextCategories,
      products: nextProducts,
      errorMessage: null,
    );
    await _firestoreCatalog.deleteCategory(categoryId);
    for (final product in nextProducts.where((item) => item.category == 0)) {
      await _firestoreCatalog.saveProduct(product);
    }
    await _persist();
  }

  Future<void> replaceCategoriesAndProducts({
    required List<Category> categories,
    required List<Product> products,
  }) async {
    final normalizedCategories = [
      for (final category in categories)
        category.copyWith(
          name: category.name.trim(),
          normalizedName: category.name.trim().toLowerCase(),
        ),
    ];
    final normalizedProducts = [
      for (final product in products)
        product.copyWith(
          name: product.name.trim(),
          details: product.details.trim(),
          category: normalizedCategories.any((item) => item.id == product.categoryId)
              ? product.categoryId
              : 0,
        ),
    ];
    final syncedCart = _syncCartWithProducts(
      products: normalizedProducts,
      cart: state.cart,
    );
    state = state.copyWith(
      categories: normalizedCategories,
      products: normalizedProducts,
      cart: syncedCart,
      errorMessage: null,
    );
    await _firestoreCatalog.replaceCategoriesAndProducts(
      categories: normalizedCategories,
      products: normalizedProducts,
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
    for (var index = 0; index < next.length; index++) {
      await _firestoreCatalog.saveCategory(next[index], sortOrder: index);
    }
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
    final next = [...ordered, ...remaining];
    for (var index = 0; index < next.length; index++) {
      await _firestoreCatalog.saveCategory(next[index], sortOrder: index);
    }
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
    await _firestoreCatalog.saveSettings(state.settings);
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
    await _firestoreCatalog.saveBarangay(updated);
    await _persist();
  }

  Future<void> deleteBarangay(int barangayId) async {
    final next = state.barangays.where((item) => item.id != barangayId).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    state = state.copyWith(barangays: next, errorMessage: null);
    await _firestoreCatalog.deleteBarangay(barangayId);
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
    if (state.adminSession != null) {
      await _firestoreCatalog.saveAdminSession(state.adminSession!);
    }
    await _firestoreCatalog.saveSettings(state.settings);
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
    await _firestoreCatalog.saveOrder(nextOrder);
    for (final product in nextProducts) {
      if (state.products.any((item) => item.id == product.id)) {
        continue;
      }
    }
    for (final product in nextProducts.where((item) {
      final previous = state.products.where((product) => product.id == item.id).firstOrNull;
      return previous?.sold != item.sold;
    })) {
      await _firestoreCatalog.saveProduct(product);
    }
    await _persist();
  }

  Future<void> _refreshOrdersFromFirebase() async {
    try {
      final adminSession = state.adminSession;
      final hasActiveAdminContext = _hasActiveAdminContext(adminSession);
      final trackedPhones = _customerLookupPhones();
      final remoteOrders = hasActiveAdminContext
          ? await _firestoreCatalog.loadOrders()
          : await _firestoreCatalog.loadOrdersForNormalizedPhones(
              trackedPhones,
            );
      final nextOrders = hasActiveAdminContext
          ? remoteOrders
          : _mergeOrdersPreservingLocal(
              existing: state.orders,
              incoming: remoteOrders,
              trackedPhones: trackedPhones,
            );
      state = state.copyWith(
        orders: nextOrders,
        products: hasActiveAdminContext
            ? _reconcileProductSoldWithOrders(
                products: state.products,
                orders: nextOrders,
                shouldPersistRemotely: true,
              ).products
            : state.products,
      );
      await _persist();
      if (hasActiveAdminContext) {
        final soldSync = _reconcileProductSoldWithOrders(
          products: state.products,
          orders: nextOrders,
          shouldPersistRemotely: true,
        );
        if (soldSync.changedProducts.isNotEmpty) {
          state = state.copyWith(products: soldSync.products);
          await _persist();
          await _firestoreCatalog.saveProducts(soldSync.changedProducts);
        }
      }
    } catch (_) {
      // Keep local cached orders when the network fetch fails.
    }
  }

  Set<String> _customerLookupPhones() {
    return _clientScopedPhoneSeeds();
  }

  Set<String> _clientScopedPhoneSeeds({
    List<OrderRequest>? orders,
    CustomerDraft? draft,
  }) {
    final sourceOrders = orders ?? state.orders;
    final sourceDraft = draft ?? state.customerDraft;
    final phones = <String>{};
    final normalizedDraft = normalizePhoneNumber(sourceDraft.mobileNumber);
    if (normalizedDraft.isNotEmpty) {
      phones.add(normalizedDraft);
      return phones;
    }

    final distinctOrderPhones = sourceOrders
        .map((order) => normalizePhoneNumber(order.phone))
        .where((phone) => phone.isNotEmpty)
        .toSet();
    if (distinctOrderPhones.length == 1) {
      phones.add(distinctOrderPhones.first);
    }
    return phones;
  }

  List<OrderRequest> _filterClientVisibleOrders(
    List<OrderRequest> orders, {
    required Set<String> trackedPhones,
  }) {
    if (trackedPhones.isEmpty) {
      return const [];
    }
    final filtered = orders.where((order) {
      final normalizedPhone = normalizePhoneNumber(order.phone);
      return normalizedPhone.isNotEmpty && trackedPhones.contains(normalizedPhone);
    }).toList()
      ..sort((a, b) {
        final updatedCompare = b.updatedAt.compareTo(a.updatedAt);
        if (updatedCompare != 0) {
          return updatedCompare;
        }
        final createdCompare = b.createdAt.compareTo(a.createdAt);
        if (createdCompare != 0) {
          return createdCompare;
        }
        return b.id.compareTo(a.id);
      });
    return filtered;
  }

  List<OrderRequest> _mergeOrdersPreservingLocal({
    required List<OrderRequest> existing,
    required List<OrderRequest> incoming,
    required Set<String> trackedPhones,
  }) {
    final incomingById = <int, OrderRequest>{
      for (final order in incoming) order.id: order,
    };
    final mergedById = <int, OrderRequest>{
      for (final order in existing)
        if (!_shouldPruneLocalOrder(
          order,
          trackedPhones: trackedPhones,
          incomingById: incomingById,
        ))
          order.id: order,
    };

    for (final order in incoming) {
      final previous = mergedById[order.id];
      if (previous == null || order.updatedAt.isAfter(previous.updatedAt)) {
        mergedById[order.id] = order;
      }
    }

    final merged = mergedById.values.toList()
      ..sort((a, b) {
        final updatedCompare = b.updatedAt.compareTo(a.updatedAt);
        if (updatedCompare != 0) {
          return updatedCompare;
        }
        final createdCompare = b.createdAt.compareTo(a.createdAt);
        if (createdCompare != 0) {
          return createdCompare;
        }
        return b.id.compareTo(a.id);
      });
    return merged;
  }

  bool _shouldPruneLocalOrder(
    OrderRequest order, {
    required Set<String> trackedPhones,
    required Map<int, OrderRequest> incomingById,
  }) {
    if (incomingById.containsKey(order.id)) {
      return false;
    }
    final normalizedPhone = normalizePhoneNumber(order.phone);
    if (normalizedPhone.isEmpty) {
      return false;
    }
    return trackedPhones.contains(normalizedPhone);
  }

  String _mapAdminLoginError(FirebaseAuthException error) {
    return switch (error.code) {
      'invalid-email' => 'Enter a valid email address.',
      'user-disabled' => 'This admin account has been disabled.',
      'user-not-found' => 'No admin account found for this email.',
      'wrong-password' || 'invalid-credential' => 'Incorrect email or password.',
      'too-many-requests' =>
        'Too many attempts. Please try again in a moment.',
      'network-request-failed' =>
        'Network error. Please check your connection and try again.',
      _ => (error.message?.trim().isNotEmpty ?? false)
          ? error.message!.trim()
          : 'Unable to sign in right now.',
    };
  }

  String _mapFirebaseOperationError(FirebaseException error) {
    return switch (error.code) {
      'permission-denied' =>
        'Firebase denied access. Check your Firestore admin document and rules.',
      'unavailable' =>
        'Firebase is temporarily unavailable. Please try again.',
      _ => (error.message?.trim().isNotEmpty ?? false)
          ? error.message!.trim()
          : 'Unable to sign in right now.',
    };
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

  ({List<Product> products, List<Product> changedProducts})
  _reconcileProductSoldWithOrders({
    required List<Product> products,
    required List<OrderRequest> orders,
    required bool shouldPersistRemotely,
  }) {
    if (products.isEmpty) {
      return (products: products, changedProducts: const []);
    }

    final totalsByProductId = <int, int>{};
    for (final order in orders) {
      if (order.status != OrderStatus.completed) {
        continue;
      }
      for (final item in order.items) {
        totalsByProductId.update(
          item.productId,
          (value) => value + item.requestedQuantity,
          ifAbsent: () => item.requestedQuantity,
        );
      }
    }

    final changedProducts = <Product>[];
    final reconciledProducts = products.map((product) {
      final resolvedSold = totalsByProductId[product.id] ?? 0;
      if (product.sold == resolvedSold) {
        return product;
      }
      final updated = product.copyWith(
        sold: resolvedSold,
        updatedAt: shouldPersistRemotely ? DateTime.now() : product.updatedAt,
      );
      changedProducts.add(updated);
      return updated;
    }).toList();

    return (products: reconciledProducts, changedProducts: changedProducts);
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

  Future<({String? photoUrl, String? photoStoragePath})> _resolveProductPhoto({
    required int productId,
    required String? photoUrl,
    required String? photoStoragePath,
  }) async {
    final trimmedPhotoUrl = photoUrl?.trim() ?? '';
    final trimmedStoragePath = photoStoragePath?.trim() ?? '';
    if (trimmedPhotoUrl.isEmpty) {
      return (photoUrl: null, photoStoragePath: null);
    }
    if (!trimmedPhotoUrl.startsWith('data:image/')) {
      return (
        photoUrl: trimmedPhotoUrl,
        photoStoragePath: trimmedStoragePath.isEmpty ? null : trimmedStoragePath,
      );
    }

    try {
      final upload = await _productImageStorage.uploadProductImageDataUrl(
        productId: productId,
        dataUrl: trimmedPhotoUrl,
      );
      return (
        photoUrl: upload.downloadUrl,
        photoStoragePath: upload.storagePath,
      );
    } catch (error) {
      throw StateError('Unable to upload product image to Firebase Storage: $error');
    }
  }
}

const _sentinel = Object();
