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
    this.categoriesMetaUpdatedAt,
    this.barangays = const [],
    this.barangaysMetaUpdatedAt,
    this.banners = const [],
    this.bannersMetaUpdatedAt,
    this.products = const [],
    this.productsMetaUpdatedAt,
    this.cart = const [],
    this.orders = const [],
    this.settings = const AppSettings(),
    this.settingsMetaUpdatedAt,
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
  final DateTime? categoriesMetaUpdatedAt;
  final List<Barangay> barangays;
  final DateTime? barangaysMetaUpdatedAt;
  final List<AppBanner> banners;
  final DateTime? bannersMetaUpdatedAt;
  final List<Product> products;
  final DateTime? productsMetaUpdatedAt;
  final List<CartItem> cart;
  final List<OrderRequest> orders;
  final AppSettings settings;
  final DateTime? settingsMetaUpdatedAt;
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
    Object? categoriesMetaUpdatedAt = _sentinel,
    List<Barangay>? barangays,
    Object? barangaysMetaUpdatedAt = _sentinel,
    List<AppBanner>? banners,
    Object? bannersMetaUpdatedAt = _sentinel,
    List<Product>? products,
    Object? productsMetaUpdatedAt = _sentinel,
    List<CartItem>? cart,
    List<OrderRequest>? orders,
    AppSettings? settings,
    Object? settingsMetaUpdatedAt = _sentinel,
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
      categoriesMetaUpdatedAt: categoriesMetaUpdatedAt == _sentinel
          ? this.categoriesMetaUpdatedAt
          : categoriesMetaUpdatedAt as DateTime?,
      barangays: barangays ?? this.barangays,
      barangaysMetaUpdatedAt: barangaysMetaUpdatedAt == _sentinel
          ? this.barangaysMetaUpdatedAt
          : barangaysMetaUpdatedAt as DateTime?,
      banners: banners ?? this.banners,
      bannersMetaUpdatedAt: bannersMetaUpdatedAt == _sentinel
          ? this.bannersMetaUpdatedAt
          : bannersMetaUpdatedAt as DateTime?,
      products: products ?? this.products,
      productsMetaUpdatedAt: productsMetaUpdatedAt == _sentinel
          ? this.productsMetaUpdatedAt
          : productsMetaUpdatedAt as DateTime?,
      cart: cart ?? this.cart,
      orders: orders ?? this.orders,
      settings: settings ?? this.settings,
      settingsMetaUpdatedAt: settingsMetaUpdatedAt == _sentinel
          ? this.settingsMetaUpdatedAt
          : settingsMetaUpdatedAt as DateTime?,
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
  StreamSubscription<CatalogMetaSnapshot?>? _catalogMetaSubscription;
  String? _ordersRealtimeScopeKey;
  bool? _catalogRealtimeIncludesInactive;
  bool _realtimeSyncScheduled = false;
  bool _disposeSyncRegistered = false;
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
      _restartOrdersRealtimeSync();
      if (!_hasOrdersRealtimeCoverage()) {
        unawaited(_refreshOrdersFromFirebase());
      }
    } catch (_) {
      _applyDefaultState();
      await _syncAdminSessionFromFirebase();
      unawaited(_hydratePublicDataFromFirebase());
      _scheduleRealtimeSync();
      _restartOrdersRealtimeSync();
      if (!_hasOrdersRealtimeCoverage()) {
        unawaited(_refreshOrdersFromFirebase());
      }
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
      _restartOrdersRealtimeSync();
      if (!_hasOrdersRealtimeCoverage()) {
        unawaited(_refreshOrdersFromFirebase());
      }
    } catch (_) {
      // Keep the current in-memory state if refresh fails.
    }
  }

  Future<void> refreshFromFirebase() async {
    state = state.copyWith(loading: true);
    await _syncAdminSessionFromFirebase();
    await _hydratePublicDataFromFirebase();
    _startRealtimeSync();
    if (_hasOrdersRealtimeCoverage()) {
      state = state.copyWith(loading: false);
      return;
    }
    await _refreshOrdersFromFirebase();
  }

  void _startRealtimeSync() {
    _realtimeSyncScheduled = false;
    final includeInactive = _hasActiveAdminContext(state.adminSession);
    if (_catalogRealtimeIncludesInactive != includeInactive) {
      _catalogRealtimeIncludesInactive = includeInactive;
    }
    unawaited(_categoriesSubscription?.cancel());
    unawaited(_barangaysSubscription?.cancel());
    unawaited(_bannersSubscription?.cancel());
    unawaited(_productsSubscription?.cancel());
    unawaited(_settingsSubscription?.cancel());
    _categoriesSubscription = null;
    _barangaysSubscription = null;
    _bannersSubscription = null;
    _productsSubscription = null;
    _settingsSubscription = null;
    _catalogMetaSubscription ??= _firestoreCatalog.watchCatalogMeta().listen((
      meta,
    ) async {
      if (meta == null) {
        return;
      }
      await _syncCatalogFromMeta(
        meta,
        includeInactive: _hasActiveAdminContext(state.adminSession),
      );
    }, onError: _handleRealtimeSyncError);
    _restartOrdersRealtimeSync();
    if (!_disposeSyncRegistered) {
      _disposeSyncRegistered = true;
      ref.onDispose(() {
        unawaited(_catalogMetaSubscription?.cancel());
        unawaited(_categoriesSubscription?.cancel());
        unawaited(_barangaysSubscription?.cancel());
        unawaited(_bannersSubscription?.cancel());
        unawaited(_productsSubscription?.cancel());
        unawaited(_settingsSubscription?.cancel());
        unawaited(_ordersSubscription?.cancel());
      });
    }
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
    final adminSession = state.adminSession;
    final hasActiveAdminContext = _hasActiveAdminContext(adminSession);
    final trackedPhones = _customerLookupPhones();
    final nextScopeKey = _buildOrdersRealtimeScopeKey(
      hasActiveAdminContext: hasActiveAdminContext,
      trackedPhones: trackedPhones,
    );
    if (_ordersSubscription != null && _ordersRealtimeScopeKey == nextScopeKey) {
      return;
    }
    unawaited(_ordersSubscription?.cancel());
    _ordersRealtimeScopeKey = nextScopeKey;
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
          final now = DateTime.now();
          state = state.copyWith(
            products: soldSync.products,
            productsMetaUpdatedAt: now,
            catalogHydrated: true,
          );
          await _persist();
          await _firestoreCatalog.saveProducts(soldSync.changedProducts);
          await _reconcileProductsAfterMutation(fallbackUpdatedAt: now);
        }
      }
    }, onError: _handleRealtimeSyncError);
  }

  bool _hasOrdersRealtimeCoverage() {
    if (_ordersSubscription == null) {
      return false;
    }
    final hasActiveAdminContext = _hasActiveAdminContext(state.adminSession);
    final trackedPhones = _customerLookupPhones();
    return _ordersRealtimeScopeKey ==
        _buildOrdersRealtimeScopeKey(
          hasActiveAdminContext: hasActiveAdminContext,
          trackedPhones: trackedPhones,
        );
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
      categoriesMetaUpdatedAt: null,
      barangays: const [],
      barangaysMetaUpdatedAt: null,
      banners: const [],
      bannersMetaUpdatedAt: null,
      products: const [],
      productsMetaUpdatedAt: null,
      orders: const [],
      settings: const AppSettings(),
      settingsMetaUpdatedAt: null,
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
      categoriesMetaUpdatedAt:
          persisted.categoriesMetaUpdatedAt ??
          _latestCategoryUpdatedAt(persisted.categories),
      barangays: _normalizeBarangays(
        persisted.barangays,
        settings: persisted.settings,
      ),
      barangaysMetaUpdatedAt:
          persisted.barangaysMetaUpdatedAt ??
          _latestBarangayUpdatedAt(persisted.barangays),
      banners: persisted.banners,
      bannersMetaUpdatedAt:
          persisted.bannersMetaUpdatedAt ??
          _latestBannerUpdatedAt(persisted.banners),
      products: persisted.products,
      productsMetaUpdatedAt:
          persisted.productsMetaUpdatedAt ??
          _latestProductUpdatedAt(persisted.products),
      orders: sanitizedOrders,
      settings: _normalizeSettings(persisted.settings),
      settingsMetaUpdatedAt:
          persisted.settingsMetaUpdatedAt ??
          persisted.settings.updatedAt ??
          persisted.settings.createdAt,
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
          !includeInactive &&
          !_needsCatalogReconciliation(includeInactive: includeInactive) &&
          !_isPublicCatalogStale(catalogMeta)) {
        final manifest = await _firestoreCatalog.loadProductsManifest();
        final remoteManifestCount = manifest?.itemUpdatedAts.length ?? 0;
        if (_isPublicProductsCacheSuspicious(
          remoteManifestCount: remoteManifestCount,
          localProductCount: state.products.length,
        )) {
          await _syncProductsByFullFetch(
            includeInactive: false,
            remoteProductsUpdatedAt:
                catalogMeta.productsUpdatedAt ??
                state.productsMetaUpdatedAt ??
                DateTime.now(),
          );
          return;
        }
      }
      if (catalogMeta != null &&
          state.catalogHydrated &&
          !_needsCatalogReconciliation(includeInactive: includeInactive) &&
          !_isPublicCatalogStale(catalogMeta)) {
        return;
      }
      if (catalogMeta != null &&
          state.catalogHydrated &&
          !_needsCatalogReconciliation(includeInactive: includeInactive)) {
        final syncedSelectively = await _syncCatalogFromMeta(
          catalogMeta,
          includeInactive: includeInactive,
        );
        if (syncedSelectively) {
          return;
        }
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

      final resolvedProducts = snapshot.products.isNotEmpty
          ? snapshot.products
          : state.products;
      final resolvedCategories = snapshot.categories.isNotEmpty
          ? snapshot.categories
          : state.categories;
      final resolvedBarangays = snapshot.barangays.isNotEmpty
          ? snapshot.barangays
          : state.barangays;
      final resolvedBanners = snapshot.banners.isNotEmpty
          ? snapshot.banners
          : state.banners;

      state = state.copyWith(
        categories: resolvedCategories,
        categoriesMetaUpdatedAt:
            catalogMeta?.categoriesUpdatedAt ?? state.categoriesMetaUpdatedAt,
        barangays: resolvedBarangays.isNotEmpty
            ? _normalizeBarangays(
                resolvedBarangays,
                settings: snapshot.settings ?? state.settings,
              )
            : state.barangays,
        barangaysMetaUpdatedAt:
            catalogMeta?.barangaysUpdatedAt ?? state.barangaysMetaUpdatedAt,
        banners: resolvedBanners,
        bannersMetaUpdatedAt:
            catalogMeta?.bannersUpdatedAt ?? state.bannersMetaUpdatedAt,
        products: resolvedProducts,
        productsMetaUpdatedAt:
            catalogMeta?.productsUpdatedAt ??
            _latestProductUpdatedAt(resolvedProducts),
        cart: _syncCartWithProducts(products: resolvedProducts),
        settings: snapshot.settings == null
            ? state.settings
            : _normalizeSettings(snapshot.settings!),
        settingsMetaUpdatedAt:
            catalogMeta?.settingsUpdatedAt ?? state.settingsMetaUpdatedAt,
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

  bool _needsCatalogReconciliation({required bool includeInactive}) {
    if (!state.catalogHydrated) {
      return true;
    }

    final hasCategories = includeInactive
        ? state.categories.isNotEmpty
        : publicCategories.isNotEmpty;
    final hasBarangays = includeInactive
        ? state.barangays.isNotEmpty
        : activeBarangays.isNotEmpty;
    final hasProducts = includeInactive
        ? state.products.isNotEmpty
        : state.products.any((product) => product.isActive);

    return !hasCategories || !hasBarangays || !hasProducts;
  }

  bool _isPublicCatalogStale(CatalogMetaSnapshot meta) {
    return _isRemoteCollectionNewer(
          remote: meta.categoriesUpdatedAt,
          local: state.categoriesMetaUpdatedAt,
        ) ||
        _isRemoteCollectionNewer(
          remote: meta.barangaysUpdatedAt,
          local: state.barangaysMetaUpdatedAt,
        ) ||
        _isRemoteCollectionNewer(
          remote: meta.bannersUpdatedAt,
          local: state.bannersMetaUpdatedAt,
        ) ||
        _isRemoteCollectionNewer(
          remote: meta.productsUpdatedAt,
          local: state.productsMetaUpdatedAt,
        ) ||
        _isRemoteCollectionNewer(
          remote: meta.settingsUpdatedAt,
          local: state.settingsMetaUpdatedAt,
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
    return !remote.isAtSameMomentAs(local);
  }

  bool _isPublicProductsCacheSuspicious({
    required int remoteManifestCount,
    required int localProductCount,
  }) {
    if (remoteManifestCount <= 0) {
      return false;
    }
    if (localProductCount <= 0) {
      return true;
    }
    if (localProductCount > remoteManifestCount) {
      return true;
    }
    final missingCount = remoteManifestCount - localProductCount;
    if (localProductCount == 1 && remoteManifestCount > 1) {
      return true;
    }
    if (missingCount >= 64) {
      return true;
    }
    return (localProductCount / remoteManifestCount) <= 0.66;
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

  Future<bool> _syncCatalogFromMeta(
    CatalogMetaSnapshot meta, {
    required bool includeInactive,
  }) async {
    var didSync = false;
    if (_isRemoteCollectionNewer(
      remote: meta.categoriesUpdatedAt,
      local: state.categoriesMetaUpdatedAt,
    )) {
      await _syncCategoriesFromManifest(
        remoteUpdatedAt: meta.categoriesUpdatedAt!,
        includeInactive: includeInactive,
      );
      didSync = true;
    }
    if (_isRemoteCollectionNewer(
      remote: meta.barangaysUpdatedAt,
      local: state.barangaysMetaUpdatedAt,
    )) {
      await _syncBarangaysFromManifest(
        remoteUpdatedAt: meta.barangaysUpdatedAt!,
        includeInactive: includeInactive,
      );
      didSync = true;
    }
    if (_isRemoteCollectionNewer(
      remote: meta.bannersUpdatedAt,
      local: state.bannersMetaUpdatedAt,
    )) {
      await _syncBannersFromManifest(
        remoteUpdatedAt: meta.bannersUpdatedAt!,
        includeInactive: includeInactive,
      );
      didSync = true;
    }
    if (_isRemoteCollectionNewer(
      remote: meta.productsUpdatedAt,
      local: state.productsMetaUpdatedAt,
    )) {
      await _syncProductsFromManifest(
        remoteProductsUpdatedAt: meta.productsUpdatedAt!,
        includeInactive: includeInactive,
      );
      didSync = true;
    }
    if (_isRemoteCollectionNewer(
      remote: meta.settingsUpdatedAt,
      local: state.settingsMetaUpdatedAt,
    )) {
      await _syncSettingsFromFirebase(
        remoteUpdatedAt: meta.settingsUpdatedAt!,
      );
      didSync = true;
    }
    return didSync;
  }

  Future<void> _syncCategoriesFromManifest({
    required DateTime remoteUpdatedAt,
    required bool includeInactive,
  }) async {
    try {
      final manifest = await _firestoreCatalog.loadCategoriesManifest();
      if (manifest == null) {
        throw StateError('Missing categories manifest.');
      }
      final localById = {for (final item in state.categories) item.id: item};
      final remoteIds = manifest.itemUpdatedAts.keys.toSet();
      final localIds = localById.keys.toSet();
      final idsToRemove = localIds.difference(remoteIds);
      final idsToFetch = <int>{};
      for (final entry in manifest.itemUpdatedAts.entries) {
        final local = localById[entry.key];
        if (local == null || local.updatedAt.isBefore(entry.value)) {
          idsToFetch.add(entry.key);
        }
      }
      final fetched = idsToFetch.isEmpty
          ? const <Category>[]
          : await _firestoreCatalog.loadCategoriesByIds(idsToFetch);
      final visibleFetched = includeInactive
          ? fetched
          : fetched.where((item) => item.isActive).toList();
      final hiddenFetchedIds = includeInactive
          ? const <int>{}
          : idsToFetch.difference(visibleFetched.map((item) => item.id).toSet());
      final nextById = <int, Category>{};
      for (final item in state.categories) {
        if (idsToRemove.contains(item.id) || hiddenFetchedIds.contains(item.id)) {
          continue;
        }
        nextById[item.id] = item;
      }
      for (final item in visibleFetched) {
        nextById[item.id] = item;
      }
      final next = nextById.values.toList()
        ..sort((a, b) {
          final bySortOrder = a.sortOrder.compareTo(b.sortOrder);
          if (bySortOrder != 0) {
            return bySortOrder;
          }
          return a.id.compareTo(b.id);
        });
      state = state.copyWith(
        categories: next,
        categoriesMetaUpdatedAt: remoteUpdatedAt,
      );
      await _persist();
    } catch (_) {
      final next = await _firestoreCatalog.loadCategories(
        includeInactive: includeInactive,
      );
      if (next.isEmpty && state.categories.isNotEmpty) {
        return;
      }
      state = state.copyWith(
        categories: next,
        categoriesMetaUpdatedAt: remoteUpdatedAt,
      );
      await _persist();
    }
  }

  Future<void> _syncBarangaysFromManifest({
    required DateTime remoteUpdatedAt,
    required bool includeInactive,
  }) async {
    try {
      final manifest = await _firestoreCatalog.loadBarangaysManifest();
      if (manifest == null) {
        throw StateError('Missing barangays manifest.');
      }
      final localById = {for (final item in state.barangays) item.id: item};
      final remoteIds = manifest.itemUpdatedAts.keys.toSet();
      final localIds = localById.keys.toSet();
      final idsToRemove = localIds.difference(remoteIds);
      final idsToFetch = <int>{};
      for (final entry in manifest.itemUpdatedAts.entries) {
        final local = localById[entry.key];
        if (local == null || local.updatedAt.isBefore(entry.value)) {
          idsToFetch.add(entry.key);
        }
      }
      final fetched = idsToFetch.isEmpty
          ? const <Barangay>[]
          : await _firestoreCatalog.loadBarangaysByIds(idsToFetch);
      final visibleFetched = includeInactive
          ? fetched
          : fetched.where((item) => item.isActive).toList();
      final hiddenFetchedIds = includeInactive
          ? const <int>{}
          : idsToFetch.difference(visibleFetched.map((item) => item.id).toSet());
      final nextById = <int, Barangay>{};
      for (final item in state.barangays) {
        if (idsToRemove.contains(item.id) || hiddenFetchedIds.contains(item.id)) {
          continue;
        }
        nextById[item.id] = item;
      }
      for (final item in visibleFetched) {
        nextById[item.id] = item;
      }
      final next = nextById.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      state = state.copyWith(
        barangays: _normalizeBarangays(next, settings: state.settings),
        barangaysMetaUpdatedAt: remoteUpdatedAt,
      );
      await _persist();
    } catch (_) {
      final next = await _firestoreCatalog.loadBarangays(
        includeInactive: includeInactive,
      );
      if (next.isEmpty && state.barangays.isNotEmpty) {
        return;
      }
      state = state.copyWith(
        barangays: _normalizeBarangays(next, settings: state.settings),
        barangaysMetaUpdatedAt: remoteUpdatedAt,
      );
      await _persist();
    }
  }

  Future<void> _syncBannersFromManifest({
    required DateTime remoteUpdatedAt,
    required bool includeInactive,
  }) async {
    try {
      final manifest = await _firestoreCatalog.loadBannersManifest();
      if (manifest == null) {
        throw StateError('Missing banners manifest.');
      }
      final localById = {for (final item in state.banners) item.id: item};
      final remoteIds = manifest.itemUpdatedAts.keys.toSet();
      final localIds = localById.keys.toSet();
      final idsToRemove = localIds.difference(remoteIds);
      final idsToFetch = <int>{};
      for (final entry in manifest.itemUpdatedAts.entries) {
        final local = localById[entry.key];
        if (local == null || local.updatedAt.isBefore(entry.value)) {
          idsToFetch.add(entry.key);
        }
      }
      final fetched = idsToFetch.isEmpty
          ? const <AppBanner>[]
          : await _firestoreCatalog.loadBannersByIds(idsToFetch);
      final visibleFetched = includeInactive
          ? fetched
          : fetched.where((item) => item.isActive).toList();
      final hiddenFetchedIds = includeInactive
          ? const <int>{}
          : idsToFetch.difference(visibleFetched.map((item) => item.id).toSet());
      final nextById = <int, AppBanner>{};
      for (final item in state.banners) {
        if (idsToRemove.contains(item.id) || hiddenFetchedIds.contains(item.id)) {
          continue;
        }
        nextById[item.id] = item;
      }
      for (final item in visibleFetched) {
        nextById[item.id] = item;
      }
      final next = nextById.values.toList()..sort((a, b) => a.id.compareTo(b.id));
      state = state.copyWith(
        banners: next,
        bannersMetaUpdatedAt: remoteUpdatedAt,
      );
      await _persist();
    } catch (_) {
      final next = await _firestoreCatalog.loadBanners(
        includeInactive: includeInactive,
      );
      if (next.isEmpty && state.banners.isNotEmpty) {
        return;
      }
      state = state.copyWith(
        banners: next,
        bannersMetaUpdatedAt: remoteUpdatedAt,
      );
      await _persist();
    }
  }

  Future<void> _syncProductsFromManifest({
    required DateTime remoteProductsUpdatedAt,
    required bool includeInactive,
  }) async {
    if (!_isRemoteCollectionNewer(
      remote: remoteProductsUpdatedAt,
      local: state.productsMetaUpdatedAt,
    )) {
      return;
    }
    if (includeInactive) {
      await _syncProductsByFullFetch(
        includeInactive: true,
        remoteProductsUpdatedAt: remoteProductsUpdatedAt,
      );
      return;
    }

    try {
      final manifest = await _firestoreCatalog.loadProductsManifest();
      if (manifest == null) {
        await _syncProductsByFullFetch(
          includeInactive: false,
          remoteProductsUpdatedAt: remoteProductsUpdatedAt,
        );
        return;
      }

      final localById = {for (final product in state.products) product.id: product};
      final remoteIds = manifest.itemUpdatedAts.keys.toSet();
      if (remoteIds.isEmpty) {
        await _syncProductsByFullFetch(
          includeInactive: false,
          remoteProductsUpdatedAt: remoteProductsUpdatedAt,
        );
        return;
      }
      if (!includeInactive &&
          _isPublicProductsCacheSuspicious(
            remoteManifestCount: remoteIds.length,
            localProductCount: state.products.length,
          )) {
        await _syncProductsByFullFetch(
          includeInactive: false,
          remoteProductsUpdatedAt: remoteProductsUpdatedAt,
        );
        return;
      }
      final localIds = localById.keys.toSet();
      final idsToRemove = localIds.difference(remoteIds);
      final idsToFetch = <int>{};

      for (final entry in manifest.itemUpdatedAts.entries) {
        final local = localById[entry.key];
        if (local == null || local.updatedAt.isBefore(entry.value)) {
          idsToFetch.add(entry.key);
        }
      }

      final fetchedProducts = idsToFetch.isEmpty
          ? const <Product>[]
          : await _firestoreCatalog.loadProductsByIds(idsToFetch);
      final visibleFetchedProducts = fetchedProducts
          .where((product) => product.isActive)
          .toList();
      final fetchedVisibleIds = visibleFetchedProducts.map((item) => item.id).toSet();
      final idsHiddenOrMissing = idsToFetch.difference(fetchedVisibleIds);

      final nextById = <int, Product>{};
      for (final product in state.products) {
        if (idsToRemove.contains(product.id) ||
            idsHiddenOrMissing.contains(product.id)) {
          continue;
        }
        nextById[product.id] = product;
      }
      for (final product in visibleFetchedProducts) {
        nextById[product.id] = product;
      }

      final nextProducts = nextById.values.toList()
        ..sort((a, b) => a.id.compareTo(b.id));
      state = state.copyWith(
        products: nextProducts,
        productsMetaUpdatedAt: remoteProductsUpdatedAt,
        cart: _syncCartWithProducts(products: nextProducts),
        catalogHydrated: true,
      );
      await _persist();
    } catch (_) {
      await _syncProductsByFullFetch(
        includeInactive: false,
        remoteProductsUpdatedAt: remoteProductsUpdatedAt,
      );
    }
  }

  Future<void> _syncSettingsFromFirebase({
    required DateTime remoteUpdatedAt,
  }) async {
    final settings = await _firestoreCatalog.loadSettings();
    if (settings == null) {
      return;
    }
    state = state.copyWith(
      settings: _normalizeSettings(settings),
      settingsMetaUpdatedAt: remoteUpdatedAt,
    );
    await _persist();
  }

  Future<void> _syncProductsByFullFetch({
    required bool includeInactive,
    required DateTime remoteProductsUpdatedAt,
  }) async {
    final products = await _firestoreCatalog.loadProducts(
      includeInactive: includeInactive,
    );
    if (products.isEmpty && state.products.isNotEmpty) {
      return;
    }
    state = state.copyWith(
      products: products,
      productsMetaUpdatedAt: remoteProductsUpdatedAt,
      cart: _syncCartWithProducts(products: products),
      catalogHydrated: true,
    );
    await _persist();
  }

  Future<void> _reconcileProductsAfterMutation({
    required DateTime fallbackUpdatedAt,
  }) async {
    final includeInactive = _hasActiveAdminContext(state.adminSession);
    final catalogMeta = await _firestoreCatalog.loadCatalogMeta();
    final remoteUpdatedAt = catalogMeta?.productsUpdatedAt ?? fallbackUpdatedAt;
    await _syncProductsFromManifest(
      remoteProductsUpdatedAt: remoteUpdatedAt,
      includeInactive: includeInactive,
    );
  }

  Future<void> _reconcileCategoriesAfterMutation({
    required DateTime fallbackUpdatedAt,
  }) async {
    final includeInactive = _hasActiveAdminContext(state.adminSession);
    final catalogMeta = await _firestoreCatalog.loadCatalogMeta();
    final remoteUpdatedAt =
        catalogMeta?.categoriesUpdatedAt ?? fallbackUpdatedAt;
    await _syncCategoriesFromManifest(
      remoteUpdatedAt: remoteUpdatedAt,
      includeInactive: includeInactive,
    );
  }

  Future<void> _reconcileBarangaysAfterMutation({
    required DateTime fallbackUpdatedAt,
  }) async {
    final includeInactive = _hasActiveAdminContext(state.adminSession);
    final catalogMeta = await _firestoreCatalog.loadCatalogMeta();
    final remoteUpdatedAt =
        catalogMeta?.barangaysUpdatedAt ?? fallbackUpdatedAt;
    await _syncBarangaysFromManifest(
      remoteUpdatedAt: remoteUpdatedAt,
      includeInactive: includeInactive,
    );
  }

  Future<void> _reconcileBannersAfterMutation({
    required DateTime fallbackUpdatedAt,
  }) async {
    final includeInactive = _hasActiveAdminContext(state.adminSession);
    final catalogMeta = await _firestoreCatalog.loadCatalogMeta();
    final remoteUpdatedAt = catalogMeta?.bannersUpdatedAt ?? fallbackUpdatedAt;
    await _syncBannersFromManifest(
      remoteUpdatedAt: remoteUpdatedAt,
      includeInactive: includeInactive,
    );
  }

  Future<void> _reconcileSettingsAfterMutation({
    required DateTime fallbackUpdatedAt,
  }) async {
    final catalogMeta = await _firestoreCatalog.loadCatalogMeta();
    final remoteUpdatedAt = catalogMeta?.settingsUpdatedAt ?? fallbackUpdatedAt;
    await _syncSettingsFromFirebase(remoteUpdatedAt: remoteUpdatedAt);
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

  List<Category> get publicCategories {
    final assignedCategoryIds = state.products
        .where((product) => product.isActive && product.categoryId > 0)
        .map((product) => product.categoryId)
        .toSet();
    return state.categories
        .where(
          (category) =>
              category.isActive && assignedCategoryIds.contains(category.id),
        )
        .toList();
  }

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
    if (!state.settings.bestSellersEnabled ||
        state.settings.bestSellersLimit <= 0) {
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
    final hasReachedCutoff = !current.isBefore(currentWeekCutoff);
    final effectiveCutoff = hasReachedCutoff
        ? currentWeekCutoff.add(const Duration(days: 7))
        : currentWeekCutoff;
    final nextDeliveryStart = effectiveCutoff.add(const Duration(days: 1));
    final nextDeliveryEnd = effectiveCutoff.add(const Duration(days: 2));
    final nextDeliveryLabel =
        '${displayWeekday(nextDeliveryStart.weekday)} or ${displayWeekday(nextDeliveryEnd.weekday)}';
    if (!hasReachedCutoff) {
      return '$cutoffLabel\n\nOrder will be delivered on $nextDeliveryLabel.';
    }
    return '$cutoffLabel\n\nOrder will be processed next ${displayWeekday(effectiveCutoff.weekday)} and will be delivered on $nextDeliveryLabel. You can select pickup to get your order faster.';
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
    return !current.isBefore(currentWeekCutoff);
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
    final previousNormalizedMobileNumber = normalizePhoneNumber(
      state.customerDraft.mobileNumber,
    );
    final nextNormalizedMobileNumber = normalizePhoneNumber(draft.mobileNumber);
    state = state.copyWith(
      customerDraft: draft.copyWith(
        normalizedMobileNumber: nextNormalizedMobileNumber,
        createdAt: draft.createdAt ?? state.customerDraft.createdAt ?? now,
        updatedAt: now,
      ),
    );
    await _persist();
    if (previousNormalizedMobileNumber != nextNormalizedMobileNumber) {
      _restartOrdersRealtimeSync();
    }
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
        state.settings.minimumDeliveryOrderAmount > 0 &&
        state.cartTotalCentavos < state.settings.minimumDeliveryOrderAmount) {
      return '${formatPesos(state.settings.minimumDeliveryOrderAmount)} min order amount for delivery.';
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
      _restartOrdersRealtimeSync();
      if (!_hasOrdersRealtimeCoverage()) {
        await _refreshOrdersFromFirebase();
      }
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
      if (!_hasOrdersRealtimeCoverage()) {
        await _refreshOrdersFromFirebase();
      }
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
    if (!_hasOrdersRealtimeCoverage()) {
      await _refreshOrdersFromFirebase();
    }
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
    next.sort((a, b) => a.id.compareTo(b.id));
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
    state = state.copyWith(
      products: next,
      productsMetaUpdatedAt: updated.updatedAt,
      cart: nextCart,
      catalogHydrated: true,
      errorMessage: null,
    );
    await _firestoreCatalog.saveProduct(updated);
    await _reconcileProductsAfterMutation(
      fallbackUpdatedAt: updated.updatedAt,
    );
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
    next.sort((a, b) => a.id.compareTo(b.id));
    state = state.copyWith(
      banners: next,
      bannersMetaUpdatedAt: now,
      catalogHydrated: true,
      errorMessage: null,
    );
    await _firestoreCatalog.saveBanner(updated);
    await _reconcileBannersAfterMutation(fallbackUpdatedAt: now);
    await _persist();
  }

  Future<void> deleteBanner(int bannerId) async {
    final now = DateTime.now();
    state = state.copyWith(
      banners: state.banners.where((item) => item.id != bannerId).toList(),
      bannersMetaUpdatedAt: now,
      catalogHydrated: true,
      errorMessage: null,
    );
    await _firestoreCatalog.deleteBanner(bannerId);
    await _reconcileBannersAfterMutation(fallbackUpdatedAt: now);
    await _persist();
  }

  Future<void> deleteProduct(int productId) async {
    final removedProduct = state.products
        .where((item) => item.id == productId)
        .firstOrNull;
    final now = DateTime.now();
    state = state.copyWith(
      products: state.products.where((item) => item.id != productId).toList(),
      productsMetaUpdatedAt: now,
      cart: state.cart.where((item) => item.productId != productId).toList(),
      catalogHydrated: true,
      errorMessage: null,
    );
    await _firestoreCatalog.deleteProduct(productId);
    await _reconcileProductsAfterMutation(fallbackUpdatedAt: now);
    await _persist();
    unawaited(_productImageStorage.deleteByPath(removedProduct?.photoStoragePath));
  }

  Future<void> saveCategory(Category category) async {
    final now = DateTime.now();
    final next = [...state.categories];
    final index = next.indexWhere((item) => item.id == category.id);
    final previousCategory = index == -1 ? null : next[index];
    if (index == -1) {
      next.insert(
        0,
        category.copyWith(
          sortOrder: 0,
          createdAt: category.createdAt,
          updatedAt: now,
        ),
      );
    } else {
      next[index] = category.copyWith(
        sortOrder: next[index].sortOrder,
        updatedAt: now,
      );
    }
    final normalized = [
      for (var i = 0; i < next.length; i++) next[i].copyWith(sortOrder: i),
    ];
    final shouldUnassignProducts =
        previousCategory != null &&
        previousCategory.isActive &&
        !category.isActive;
    final nextProducts = shouldUnassignProducts
        ? state.products.map((product) {
            if (product.category != category.id) {
              return product;
            }
            return product.copyWith(category: 0, updatedAt: now);
          }).toList()
        : state.products;
    state = state.copyWith(
      categories: normalized,
      categoriesMetaUpdatedAt: now,
      products: nextProducts,
      productsMetaUpdatedAt: shouldUnassignProducts
          ? now
          : state.productsMetaUpdatedAt,
      cart: shouldUnassignProducts
          ? _syncCartWithProducts(products: nextProducts)
          : state.cart,
      catalogHydrated: true,
      errorMessage: null,
    );
    await _firestoreCatalog.saveCategories(normalized);
    if (shouldUnassignProducts) {
      final reassignedProducts = nextProducts
          .where((item) => item.category == 0)
          .toList();
      await _firestoreCatalog.saveProducts(reassignedProducts);
    }
    await _reconcileCategoriesAfterMutation(fallbackUpdatedAt: now);
    if (shouldUnassignProducts) {
      await _reconcileProductsAfterMutation(fallbackUpdatedAt: now);
    }
    await _persist();
  }

  Future<void> deleteCategory(int categoryId) async {
    final now = DateTime.now();
    final nextCategories = state.categories
        .where((item) => item.id != categoryId)
        .toList();
    final nextProducts = state.products.map((product) {
      if (product.category != categoryId) {
        return product;
      }
      return product.copyWith(category: 0, updatedAt: now);
    }).toList();

    state = state.copyWith(
      categories: nextCategories,
      categoriesMetaUpdatedAt: now,
      products: nextProducts,
      productsMetaUpdatedAt: now,
      cart: _syncCartWithProducts(products: nextProducts),
      catalogHydrated: true,
      errorMessage: null,
    );
    await _firestoreCatalog.deleteCategory(categoryId);
    final reassignedProducts = nextProducts
        .where((item) => item.category == 0)
        .toList();
    await _firestoreCatalog.saveProducts(reassignedProducts);
    await _reconcileCategoriesAfterMutation(fallbackUpdatedAt: now);
    await _reconcileProductsAfterMutation(fallbackUpdatedAt: now);
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
    final now = DateTime.now();
    state = state.copyWith(
      categories: normalizedCategories,
      categoriesMetaUpdatedAt: now,
      products: normalizedProducts,
      productsMetaUpdatedAt: now,
      cart: syncedCart,
      catalogHydrated: true,
      errorMessage: null,
    );
    await _firestoreCatalog.replaceCategoriesAndProducts(
      categories: normalizedCategories,
      products: normalizedProducts,
    );
    await _reconcileCategoriesAfterMutation(fallbackUpdatedAt: now);
    await _reconcileProductsAfterMutation(fallbackUpdatedAt: now);
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
    final now = DateTime.now();
    final normalized = [
      for (var index = 0; index < next.length; index++)
        next[index].copyWith(sortOrder: index, updatedAt: now),
    ];
    state = state.copyWith(
      categories: normalized,
      categoriesMetaUpdatedAt: now,
      catalogHydrated: true,
      errorMessage: null,
    );
    await _firestoreCatalog.saveCategories(normalized);
    await _reconcileCategoriesAfterMutation(fallbackUpdatedAt: now);
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

    final merged = [...ordered, ...remaining];
    final now = DateTime.now();
    final next = [
      for (var i = 0; i < merged.length; i++)
        merged[i].copyWith(sortOrder: i, updatedAt: now),
    ];
    state = state.copyWith(
      categories: next,
      categoriesMetaUpdatedAt: now,
      catalogHydrated: true,
      errorMessage: null,
    );
    await _firestoreCatalog.saveCategories(next);
    await _reconcileCategoriesAfterMutation(fallbackUpdatedAt: now);
    await _persist();
  }

  Future<void> saveSettings(AppSettings settings) async {
    final now = DateTime.now();
    state = state.copyWith(
      settings: settings.copyWith(
        createdAt: settings.createdAt ?? state.settings.createdAt ?? now,
        updatedAt: now,
      ),
      settingsMetaUpdatedAt: now,
    );
    await _firestoreCatalog.saveSettings(state.settings);
    await _reconcileSettingsAfterMutation(fallbackUpdatedAt: now);
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
    state = state.copyWith(
      barangays: next,
      barangaysMetaUpdatedAt: now,
      catalogHydrated: true,
      errorMessage: null,
    );
    await _firestoreCatalog.saveBarangay(updated);
    await _reconcileBarangaysAfterMutation(fallbackUpdatedAt: now);
    await _persist();
  }

  Future<void> deleteBarangay(int barangayId) async {
    final now = DateTime.now();
    final next = state.barangays.where((item) => item.id != barangayId).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    state = state.copyWith(
      barangays: next,
      barangaysMetaUpdatedAt: now,
      catalogHydrated: true,
      errorMessage: null,
    );
    await _firestoreCatalog.deleteBarangay(barangayId);
    await _reconcileBarangaysAfterMutation(fallbackUpdatedAt: now);
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
      settingsMetaUpdatedAt: now,
    );
    if (state.adminSession != null) {
      await _firestoreCatalog.saveAdminSession(state.adminSession!);
    }
    await _firestoreCatalog.saveSettings(state.settings);
    await _reconcileSettingsAfterMutation(fallbackUpdatedAt: now);
    await _persist();
  }

  Future<void> updateOrder(OrderRequest nextOrder) async {
    final now = DateTime.now();
    final previousProducts = state.products;
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
          updatedAt: now,
        );
      }).toList();
    }

    final updatedOrders = state.orders
        .map((item) => item.id == nextOrder.id ? nextOrder : item)
        .toList();

    final changedProducts = nextProducts.where((item) {
      final previous = previousProducts
          .where((product) => product.id == item.id)
          .firstOrNull;
      return previous?.sold != item.sold;
    }).toList();
    state = state.copyWith(
      orders: updatedOrders,
      products: nextProducts,
      productsMetaUpdatedAt: changedProducts.isNotEmpty
          ? now
          : state.productsMetaUpdatedAt,
      catalogHydrated: true,
    );
    await _firestoreCatalog.saveOrder(nextOrder);
    await _firestoreCatalog.saveProducts(changedProducts);
    if (changedProducts.isNotEmpty) {
      await _reconcileProductsAfterMutation(fallbackUpdatedAt: now);
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
          final now = DateTime.now();
          state = state.copyWith(
            products: soldSync.products,
            productsMetaUpdatedAt: now,
            catalogHydrated: true,
          );
          await _persist();
          await _firestoreCatalog.saveProducts(soldSync.changedProducts);
          await _reconcileProductsAfterMutation(fallbackUpdatedAt: now);
        }
      }
    } catch (_) {
      // Keep local cached orders when the network fetch fails.
    }
  }

  Set<String> _customerLookupPhones() {
    return _clientScopedPhoneSeeds();
  }

  String _buildOrdersRealtimeScopeKey({
    required bool hasActiveAdminContext,
    required Set<String> trackedPhones,
  }) {
    if (hasActiveAdminContext) {
      return 'admin';
    }
    final phones = [...trackedPhones]..sort();
    return 'client:${phones.join(',')}';
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
      final existing = await _store.load();
      final shouldProtectExistingCatalog =
          existing != null &&
          existing.products.isNotEmpty &&
          state.products.isEmpty &&
          state.catalogHydrated;
      final shouldProtectExistingProductsCache =
          existing != null &&
          existing.products.isNotEmpty &&
          state.products.isNotEmpty &&
          state.products.length < existing.products.length &&
          (() {
            final existingMeta = existing.productsMetaUpdatedAt;
            final nextMeta = state.productsMetaUpdatedAt;
            if (existingMeta == null) {
              return false;
            }
            if (nextMeta == null) {
              return true;
            }
            return !nextMeta.isAfter(existingMeta);
          })();

      final persistedCategories = shouldProtectExistingCatalog
          ? existing.categories
          : state.categories;
      final persistedCategoriesMetaUpdatedAt = shouldProtectExistingCatalog
          ? existing.categoriesMetaUpdatedAt
          : state.categoriesMetaUpdatedAt;
      final persistedBarangays = shouldProtectExistingCatalog
          ? existing.barangays
          : state.barangays;
      final persistedBarangaysMetaUpdatedAt = shouldProtectExistingCatalog
          ? existing.barangaysMetaUpdatedAt
          : state.barangaysMetaUpdatedAt;
      final persistedBanners = shouldProtectExistingCatalog
          ? existing.banners
          : state.banners;
      final persistedBannersMetaUpdatedAt = shouldProtectExistingCatalog
          ? existing.bannersMetaUpdatedAt
          : state.bannersMetaUpdatedAt;
      final persistedProducts = shouldProtectExistingCatalog
          ? existing.products
          : shouldProtectExistingProductsCache
          ? existing.products
          : state.products;
      final persistedProductsMetaUpdatedAt = shouldProtectExistingCatalog
          ? existing.productsMetaUpdatedAt
          : shouldProtectExistingProductsCache
          ? existing.productsMetaUpdatedAt
          : state.productsMetaUpdatedAt;

      await _store.save(
        PersistedData(
          categories: persistedCategories,
          categoriesMetaUpdatedAt: persistedCategoriesMetaUpdatedAt,
          barangays: persistedBarangays,
          barangaysMetaUpdatedAt: persistedBarangaysMetaUpdatedAt,
          banners: persistedBanners,
          bannersMetaUpdatedAt: persistedBannersMetaUpdatedAt,
          products: persistedProducts,
          productsMetaUpdatedAt: persistedProductsMetaUpdatedAt,
          orders: state.orders,
          settings: state.settings,
          settingsMetaUpdatedAt: state.settingsMetaUpdatedAt,
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
