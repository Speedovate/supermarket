import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/firebase_paths.dart';
import '../models/app_models.dart';
import '../utils/formatters.dart';

final firebaseFirestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

final firestoreCatalogServiceProvider = Provider<FirestoreCatalogService>(
  (ref) => FirestoreCatalogService(ref.read(firebaseFirestoreProvider)),
);

class FirestoreCatalogSnapshot {
  const FirestoreCatalogSnapshot({
    required this.categories,
    required this.barangays,
    required this.banners,
    required this.products,
    this.settings,
  });

  final List<Category> categories;
  final List<Barangay> barangays;
  final List<AppBanner> banners;
  final List<Product> products;
  final AppSettings? settings;

  bool get hasAnyData =>
      categories.isNotEmpty ||
      barangays.isNotEmpty ||
      banners.isNotEmpty ||
      products.isNotEmpty ||
      settings != null;
}

class CatalogMetaSnapshot {
  const CatalogMetaSnapshot({
    this.categoriesUpdatedAt,
    this.barangaysUpdatedAt,
    this.bannersUpdatedAt,
    this.productsUpdatedAt,
    this.settingsUpdatedAt,
  });

  final DateTime? categoriesUpdatedAt;
  final DateTime? barangaysUpdatedAt;
  final DateTime? bannersUpdatedAt;
  final DateTime? productsUpdatedAt;
  final DateTime? settingsUpdatedAt;

  bool get hasAnyData =>
      categoriesUpdatedAt != null ||
      barangaysUpdatedAt != null ||
      bannersUpdatedAt != null ||
      productsUpdatedAt != null ||
      settingsUpdatedAt != null;
}

class ProductManifestSnapshot {
  const ProductManifestSnapshot({this.updatedAt, required this.itemUpdatedAts});

  final DateTime? updatedAt;
  final Map<int, DateTime> itemUpdatedAts;

  bool get hasAnyData => updatedAt != null || itemUpdatedAts.isNotEmpty;
}

class FirestoreCatalogService {
  FirestoreCatalogService(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _catalogMetaRef => _firestore
      .collection(FirebasePaths.system)
      .doc(FirebasePaths.catalogMetaDocumentId);

  DocumentReference<Map<String, dynamic>> get _categoriesManifestRef =>
      _firestore
          .collection(FirebasePaths.system)
          .doc(FirebasePaths.categoriesManifestDocumentId);

  DocumentReference<Map<String, dynamic>> get _barangaysManifestRef =>
      _firestore
          .collection(FirebasePaths.system)
          .doc(FirebasePaths.barangaysManifestDocumentId);

  DocumentReference<Map<String, dynamic>> get _bannersManifestRef => _firestore
      .collection(FirebasePaths.system)
      .doc(FirebasePaths.bannersManifestDocumentId);

  DocumentReference<Map<String, dynamic>> get _productsManifestRef => _firestore
      .collection(FirebasePaths.system)
      .doc(FirebasePaths.productsManifestDocumentId);

  Future<FirestoreCatalogSnapshot?> loadCatalogSnapshot({
    bool includeInactive = false,
  }) async {
    final results = await Future.wait<Object?>([
      loadCategories(includeInactive: includeInactive),
      loadBarangays(includeInactive: includeInactive),
      loadBanners(includeInactive: includeInactive),
      loadProducts(includeInactive: includeInactive),
      loadSettings(),
    ]);

    final snapshot = FirestoreCatalogSnapshot(
      categories: results[0]! as List<Category>,
      barangays: results[1]! as List<Barangay>,
      banners: results[2]! as List<AppBanner>,
      products: results[3]! as List<Product>,
      settings: results[4] as AppSettings?,
    );

    return snapshot.hasAnyData ? snapshot : null;
  }

  Future<FirestoreCatalogSnapshot?> loadPublicSnapshot() async {
    return loadCatalogSnapshot(includeInactive: false);
  }

  Future<CatalogMetaSnapshot?> loadCatalogMeta() async {
    final snapshot = await _catalogMetaRef.get();
    final data = snapshot.data();
    if (data == null) {
      return null;
    }
    final normalized = _normalizeFirestoreMap(data);
    final meta = CatalogMetaSnapshot(
      categoriesUpdatedAt: _parseMetaDate(normalized['categoriesUpdatedAt']),
      barangaysUpdatedAt: _parseMetaDate(normalized['barangaysUpdatedAt']),
      bannersUpdatedAt: _parseMetaDate(normalized['bannersUpdatedAt']),
      productsUpdatedAt: _parseMetaDate(normalized['productsUpdatedAt']),
      settingsUpdatedAt: _parseMetaDate(normalized['settingsUpdatedAt']),
    );
    return meta.hasAnyData ? meta : null;
  }

  Stream<CatalogMetaSnapshot?> watchCatalogMeta() {
    return _catalogMetaRef.snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) {
        return null;
      }
      final normalized = _normalizeFirestoreMap(data);
      final meta = CatalogMetaSnapshot(
        categoriesUpdatedAt: _parseMetaDate(normalized['categoriesUpdatedAt']),
        barangaysUpdatedAt: _parseMetaDate(normalized['barangaysUpdatedAt']),
        bannersUpdatedAt: _parseMetaDate(normalized['bannersUpdatedAt']),
        productsUpdatedAt: _parseMetaDate(normalized['productsUpdatedAt']),
        settingsUpdatedAt: _parseMetaDate(normalized['settingsUpdatedAt']),
      );
      return meta.hasAnyData ? meta : null;
    });
  }

  Future<List<Category>> loadCategories({bool includeInactive = true}) async {
    final categories =
        (includeInactive
              ? (await _firestore.collection(FirebasePaths.categories).get())
                    .docs
                    .map(_categoryFromSnapshot)
                    .toList()
              : await _loadPublicCategories())
          ..sort(_compareCategoriesBySortOrder);
    return categories;
  }

  Future<List<Category>> loadCategoriesByIds(Iterable<int> ids) async {
    final items = await _loadDocumentsByIds(
      collectionPath: FirebasePaths.categories,
      ids: ids,
      mapper: _categoryFromSnapshot,
    );
    items.sort(_compareCategoriesBySortOrder);
    return items;
  }

  Stream<List<Category>> watchCategories({bool includeInactive = true}) {
    if (includeInactive) {
      return _firestore.collection(FirebasePaths.categories).snapshots().map((
        snapshot,
      ) {
        final categories = snapshot.docs.map(_categoryFromSnapshot).toList()
          ..sort(_compareCategoriesBySortOrder);
        return categories;
      });
    }

    return Stream.fromFuture(_loadPublicCategories()).asyncExpand((
      items,
    ) async* {
      yield items..sort(_compareCategoriesBySortOrder);
    });
  }

  Future<List<Barangay>> loadBarangays({bool includeInactive = true}) async {
    final query = includeInactive
        ? _firestore.collection(FirebasePaths.barangays).orderBy('name')
        : _firestore
              .collection(FirebasePaths.barangays)
              .where('active', isEqualTo: true);
    final snapshot = await query.get();
    final barangays = snapshot.docs.map(_barangayFromSnapshot).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return barangays;
  }

  Future<List<Barangay>> loadBarangaysByIds(Iterable<int> ids) async {
    final items = await _loadDocumentsByIds(
      collectionPath: FirebasePaths.barangays,
      ids: ids,
      mapper: _barangayFromSnapshot,
    );
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return items;
  }

  Stream<List<Barangay>> watchBarangays({bool includeInactive = true}) {
    final query = includeInactive
        ? _firestore.collection(FirebasePaths.barangays).orderBy('name')
        : _firestore
              .collection(FirebasePaths.barangays)
              .where('active', isEqualTo: true);
    return query.snapshots().map((snapshot) {
      final barangays = snapshot.docs.map(_barangayFromSnapshot).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return barangays;
    });
  }

  Future<List<AppBanner>> loadBanners({bool includeInactive = true}) async {
    final banners =
        (includeInactive
              ? (await _firestore
                        .collection(FirebasePaths.banners)
                        .orderBy('id')
                        .get())
                    .docs
                    .map(_bannerFromSnapshot)
                    .toList()
              : await _loadPublicBanners())
          ..sort((a, b) => a.id.compareTo(b.id));
    return banners;
  }

  Future<List<AppBanner>> loadBannersByIds(Iterable<int> ids) async {
    final items = await _loadDocumentsByIds(
      collectionPath: FirebasePaths.banners,
      ids: ids,
      mapper: _bannerFromSnapshot,
    );
    items.sort((a, b) => a.id.compareTo(b.id));
    return items;
  }

  Stream<List<AppBanner>> watchBanners({bool includeInactive = true}) {
    if (includeInactive) {
      return _firestore
          .collection(FirebasePaths.banners)
          .orderBy('id')
          .snapshots()
          .map((snapshot) {
            final banners = snapshot.docs.map(_bannerFromSnapshot).toList()
              ..sort((a, b) => a.id.compareTo(b.id));
            return banners;
          });
    }

    return Stream.fromFuture(_loadPublicBanners()).asyncExpand((items) async* {
      yield items..sort((a, b) => a.id.compareTo(b.id));
    });
  }

  Future<List<Product>> loadProducts({bool includeInactive = true}) async {
    final products =
        (includeInactive
              ? (await _firestore
                        .collection(FirebasePaths.products)
                        .orderBy('id')
                        .get())
                    .docs
                    .map(_productFromSnapshot)
                    .toList()
              : await _loadPublicProducts())
          ..sort((a, b) => a.id.compareTo(b.id));
    return products;
  }

  Future<List<Product>> loadProductsByIds(Iterable<int> ids) async {
    final productIds = ids.toSet().toList()..sort();
    if (productIds.isEmpty) {
      return const [];
    }

    final products = <Product>[];
    for (var index = 0; index < productIds.length; index += 10) {
      final end = math.min(index + 10, productIds.length);
      final group = productIds.sublist(index, end);
      final snapshot = await _firestore
          .collection(FirebasePaths.products)
          .where(
            FieldPath.documentId,
            whereIn: group.map((id) => '$id').toList(),
          )
          .get();
      products.addAll(snapshot.docs.map(_productFromSnapshot));
    }
    products.sort((a, b) => a.id.compareTo(b.id));
    return products;
  }

  Future<ProductManifestSnapshot?> loadProductsManifest() async {
    final snapshot = await _productsManifestRef.get();
    return _productManifestFromSnapshot(snapshot);
  }

  Future<ProductManifestSnapshot?> loadCategoriesManifest() async {
    final snapshot = await _categoriesManifestRef.get();
    return _productManifestFromSnapshot(snapshot);
  }

  Future<ProductManifestSnapshot?> loadBarangaysManifest() async {
    final snapshot = await _barangaysManifestRef.get();
    return _productManifestFromSnapshot(snapshot);
  }

  Future<ProductManifestSnapshot?> loadBannersManifest() async {
    final snapshot = await _bannersManifestRef.get();
    return _productManifestFromSnapshot(snapshot);
  }

  Stream<List<Product>> watchProducts({bool includeInactive = true}) {
    if (includeInactive) {
      return _firestore
          .collection(FirebasePaths.products)
          .orderBy('id')
          .snapshots()
          .map((snapshot) {
            final products = snapshot.docs.map(_productFromSnapshot).toList()
              ..sort((a, b) => a.id.compareTo(b.id));
            return products;
          });
    }

    return Stream.fromFuture(_loadPublicProducts()).asyncExpand((items) async* {
      yield items..sort((a, b) => a.id.compareTo(b.id));
    });
  }

  Future<List<OrderRequest>> loadOrders() async {
    final query = await _firestore
        .collection(FirebasePaths.orders)
        .orderBy('createdAt', descending: true)
        .get();
    return query.docs.map(_orderFromSnapshot).toList();
  }

  Stream<List<OrderRequest>> watchOrders() {
    return _firestore
        .collection(FirebasePaths.orders)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_orderFromSnapshot).toList());
  }

  Future<List<OrderRequest>> loadOrdersForNormalizedPhones(
    Iterable<String> phones,
  ) async {
    final normalizedPhones = phones
        .map((item) => normalizePhoneNumber(item))
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
    if (normalizedPhones.isEmpty) {
      return const [];
    }

    final groups = <List<String>>[];
    for (var index = 0; index < normalizedPhones.length; index += 10) {
      final end = (index + 10) > normalizedPhones.length
          ? normalizedPhones.length
          : index + 10;
      groups.add(normalizedPhones.sublist(index, end));
    }

    final orders = <OrderRequest>[];
    for (final group in groups) {
      final query = await _firestore
          .collection(FirebasePaths.orders)
          .where('customer.normalizedMobileNumber', whereIn: group)
          .get();
      orders.addAll(query.docs.map(_orderFromSnapshot));
    }

    final byId = <int, OrderRequest>{};
    for (final order in orders) {
      byId[order.id] = order;
    }
    final deduped = byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return deduped;
  }

  Stream<List<OrderRequest>> watchOrdersForNormalizedPhones(
    Iterable<String> phones,
  ) async* {
    final normalizedPhones = phones
        .map((item) => normalizePhoneNumber(item))
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
    if (normalizedPhones.isEmpty) {
      yield const [];
      return;
    }

    final groups = <List<String>>[];
    for (var index = 0; index < normalizedPhones.length; index += 10) {
      final end = (index + 10) > normalizedPhones.length
          ? normalizedPhones.length
          : index + 10;
      groups.add(normalizedPhones.sublist(index, end));
    }

    final streams = groups
        .map(
          (group) => _firestore
              .collection(FirebasePaths.orders)
              .where('customer.normalizedMobileNumber', whereIn: group)
              .snapshots(),
        )
        .toList();

    yield* Stream.multi((controller) {
      final snapshots = List<QuerySnapshot<Map<String, dynamic>>?>.filled(
        streams.length,
        null,
      );
      final subscriptions =
          <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];

      void emitMerged() {
        final orders = <OrderRequest>[];
        for (final snapshot in snapshots) {
          if (snapshot == null) {
            continue;
          }
          orders.addAll(snapshot.docs.map(_orderFromSnapshot));
        }
        final byId = <int, OrderRequest>{};
        for (final order in orders) {
          byId[order.id] = order;
        }
        final deduped = byId.values.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        controller.add(deduped);
      }

      for (var index = 0; index < streams.length; index++) {
        final subscription = streams[index].listen((snapshot) {
          snapshots[index] = snapshot;
          emitMerged();
        }, onError: controller.addError);
        subscriptions.add(subscription);
      }

      controller.onCancel = () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      };
    });
  }

  Future<AppSettings?> loadSettings() async {
    final exact = await _firestore
        .collection(FirebasePaths.appSettings)
        .doc(FirebasePaths.defaultSettingsDocumentId)
        .get();
    if (exact.exists && exact.data() != null) {
      return _settingsFromSnapshot(exact);
    }

    final fallback = await _firestore
        .collection(FirebasePaths.appSettings)
        .limit(1)
        .get();
    if (fallback.docs.isEmpty) {
      return null;
    }
    return _settingsFromSnapshot(fallback.docs.first);
  }

  Stream<AppSettings?> watchSettings() {
    return _firestore
        .collection(FirebasePaths.appSettings)
        .doc(FirebasePaths.defaultSettingsDocumentId)
        .snapshots()
        .map(
          (doc) => !doc.exists || doc.data() == null
              ? null
              : _settingsFromSnapshot(doc),
        );
  }

  Future<void> saveProduct(Product product) async {
    final batch = _firestore.batch();
    batch.set(
      _firestore.collection(FirebasePaths.products).doc('${product.id}'),
      _productData(product),
    );
    batch.set(
      _catalogMetaRef,
      _catalogMetaData(products: true),
      SetOptions(merge: true),
    );
    batch.set(
      _productsManifestRef,
      _productsManifestEntryData(product),
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<void> saveProducts(Iterable<Product> products) async {
    final items = products.toList();
    if (items.isEmpty) {
      return;
    }
    final batch = _firestore.batch();
    for (final product in items) {
      batch.set(
        _firestore.collection(FirebasePaths.products).doc('${product.id}'),
        _productData(product),
      );
    }
    batch.set(
      _catalogMetaRef,
      _catalogMetaData(products: true),
      SetOptions(merge: true),
    );
    batch.set(
      _productsManifestRef,
      _productsManifestEntriesData(items),
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<void> deleteProduct(int productId) async {
    final batch = _firestore.batch();
    batch.delete(
      _firestore.collection(FirebasePaths.products).doc('$productId'),
    );
    batch.set(
      _catalogMetaRef,
      _catalogMetaData(products: true),
      SetOptions(merge: true),
    );
    batch.set(
      _productsManifestRef,
      _deleteProductManifestEntryData(productId),
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<void> saveCategory(Category category, {int? sortOrder}) async {
    final batch = _firestore.batch();
    batch.set(
      _firestore.collection(FirebasePaths.categories).doc('${category.id}'),
      _categoryData(category, sortOrder: sortOrder ?? category.id),
    );
    batch.set(
      _catalogMetaRef,
      _catalogMetaData(categories: true),
      SetOptions(merge: true),
    );
    batch.set(
      _categoriesManifestRef,
      _manifestEntryData(category.id, category.updatedAt),
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<void> saveCategories(Iterable<Category> categories) async {
    final items = categories.toList()
      ..sort((a, b) {
        final bySortOrder = a.sortOrder.compareTo(b.sortOrder);
        if (bySortOrder != 0) {
          return bySortOrder;
        }
        return a.id.compareTo(b.id);
      });
    if (items.isEmpty) {
      return;
    }

    final batch = _firestore.batch();
    for (var index = 0; index < items.length; index++) {
      final category = items[index].copyWith(sortOrder: index);
      batch.set(
        _firestore.collection(FirebasePaths.categories).doc('${category.id}'),
        _categoryData(category, sortOrder: index),
      );
    }
    batch.set(
      _catalogMetaRef,
      _catalogMetaData(categories: true),
      SetOptions(merge: true),
    );
    batch.set(
      _categoriesManifestRef,
      _manifestData(items.map((item) => (item.id, item.updatedAt))),
    );
    await batch.commit();
  }

  Future<void> deleteCategory(int categoryId) async {
    final batch = _firestore.batch();
    batch.delete(
      _firestore.collection(FirebasePaths.categories).doc('$categoryId'),
    );
    batch.set(
      _catalogMetaRef,
      _catalogMetaData(categories: true),
      SetOptions(merge: true),
    );
    batch.set(
      _categoriesManifestRef,
      _deleteManifestEntryData(categoryId),
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<void> replaceCategoriesAndProducts({
    required List<Category> categories,
    required List<Product> products,
  }) async {
    final categorySnapshot = await _firestore
        .collection(FirebasePaths.categories)
        .get();
    final productSnapshot = await _firestore
        .collection(FirebasePaths.products)
        .get();

    final operations = <void Function(WriteBatch)>[
      for (final doc in categorySnapshot.docs)
        (batch) => batch.delete(doc.reference),
      for (final doc in productSnapshot.docs)
        (batch) => batch.delete(doc.reference),
      for (var index = 0; index < categories.length; index++)
        (batch) => batch.set(
          _firestore
              .collection(FirebasePaths.categories)
              .doc('${categories[index].id}'),
          _categoryData(categories[index], sortOrder: index),
        ),
      for (final product in products)
        (batch) => batch.set(
          _firestore.collection(FirebasePaths.products).doc('${product.id}'),
          _productData(product),
        ),
    ];

    const maxBatchOperations = 400;
    for (
      var start = 0;
      start < operations.length;
      start += maxBatchOperations
    ) {
      final batch = _firestore.batch();
      final end = math.min(start + maxBatchOperations, operations.length);
      for (var index = start; index < end; index++) {
        operations[index](batch);
      }
      await batch.commit();
    }
    final batch = _firestore.batch();
    batch.set(
      _catalogMetaRef,
      _catalogMetaData(categories: true, products: true),
      SetOptions(merge: true),
    );
    batch.set(
      _categoriesManifestRef,
      _manifestData(categories.map((item) => (item.id, item.updatedAt))),
    );
    batch.set(_productsManifestRef, _productsManifestData(products));
    await batch.commit();
  }

  Future<void> saveBarangay(Barangay barangay) async {
    final batch = _firestore.batch();
    batch.set(
      _firestore.collection(FirebasePaths.barangays).doc('${barangay.id}'),
      _barangayData(barangay),
    );
    batch.set(
      _catalogMetaRef,
      _catalogMetaData(barangays: true),
      SetOptions(merge: true),
    );
    batch.set(
      _barangaysManifestRef,
      _manifestEntryData(barangay.id, barangay.updatedAt),
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<void> deleteBarangay(int barangayId) async {
    final batch = _firestore.batch();
    batch.delete(
      _firestore.collection(FirebasePaths.barangays).doc('$barangayId'),
    );
    batch.set(
      _catalogMetaRef,
      _catalogMetaData(barangays: true),
      SetOptions(merge: true),
    );
    batch.set(
      _barangaysManifestRef,
      _deleteManifestEntryData(barangayId),
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<void> saveBanner(AppBanner banner) async {
    final batch = _firestore.batch();
    batch.set(
      _firestore.collection(FirebasePaths.banners).doc('${banner.id}'),
      _bannerData(banner),
    );
    batch.set(
      _catalogMetaRef,
      _catalogMetaData(banners: true),
      SetOptions(merge: true),
    );
    batch.set(
      _bannersManifestRef,
      _manifestEntryData(banner.id, banner.updatedAt),
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<void> deleteBanner(int bannerId) async {
    final batch = _firestore.batch();
    batch.delete(_firestore.collection(FirebasePaths.banners).doc('$bannerId'));
    batch.set(
      _catalogMetaRef,
      _catalogMetaData(banners: true),
      SetOptions(merge: true),
    );
    batch.set(
      _bannersManifestRef,
      _deleteManifestEntryData(bannerId),
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _firestore
        .collection(FirebasePaths.appSettings)
        .doc(FirebasePaths.defaultSettingsDocumentId)
        .set(_settingsData(settings));
    await _touchCatalogMeta(settings: true);
  }

  Future<void> saveOrder(OrderRequest order) async {
    await _firestore
        .collection(FirebasePaths.orders)
        .doc('${order.id}')
        .set(_orderData(order));
  }

  Future<int> reserveNextOrderId() async {
    final counterRef = _firestore
        .collection(FirebasePaths.system)
        .doc(FirebasePaths.ordersCounterDocumentId);

    return _firestore.runTransaction<int>((transaction) async {
      final snapshot = await transaction.get(counterRef);
      final data = snapshot.data();
      final currentNextOrderId = data == null
          ? 0
          : _coerceInt(data['nextOrderId']);
      final reservedOrderId = currentNextOrderId > 0 ? currentNextOrderId : 1;

      transaction.set(counterRef, {
        'nextOrderId': reservedOrderId + 1,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));

      return reservedOrderId;
    });
  }

  Future<int> reserveNextCategoryId({int fallbackNextCategoryId = 1}) async {
    final reserved = await reserveNextCategoryIds(
      count: 1,
      fallbackNextCategoryId: fallbackNextCategoryId,
    );
    return reserved.first;
  }

  Future<List<int>> reserveNextCategoryIds({
    required int count,
    int fallbackNextCategoryId = 1,
  }) async {
    if (count <= 0) {
      return const [];
    }
    final counterRef = _firestore
        .collection(FirebasePaths.system)
        .doc(FirebasePaths.categoriesCounterDocumentId);
    final latestCategoryQuery = await _firestore
        .collection(FirebasePaths.categories)
        .orderBy('id', descending: true)
        .limit(1)
        .get();
    final remoteNextCategoryId = latestCategoryQuery.docs.isEmpty
        ? 1
        : (_coerceInt(latestCategoryQuery.docs.first.data()['id']) + 1);
    final baselineNextCategoryId = math.max(
      1,
      remoteNextCategoryId > 0 ? remoteNextCategoryId : fallbackNextCategoryId,
    );

    return _firestore.runTransaction<List<int>>((transaction) async {
      final snapshot = await transaction.get(counterRef);
      final data = snapshot.data();
      final currentNextCategoryId = data == null
          ? 0
          : _coerceInt(data['nextCategoryId']);
      final reservedStartId = currentNextCategoryId > 0
          ? math.max(currentNextCategoryId, baselineNextCategoryId)
          : baselineNextCategoryId;
      final reservedIds = List<int>.generate(
        count,
        (index) => reservedStartId + index,
      );

      transaction.set(counterRef, {
        'nextCategoryId': reservedStartId + count,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));

      return reservedIds;
    });
  }

  Future<int> reserveNextBarangayId({int fallbackNextBarangayId = 1}) async {
    final reserved = await reserveNextBarangayIds(
      count: 1,
      fallbackNextBarangayId: fallbackNextBarangayId,
    );
    return reserved.first;
  }

  Future<List<int>> reserveNextBarangayIds({
    required int count,
    int fallbackNextBarangayId = 1,
  }) async {
    if (count <= 0) {
      return const [];
    }
    final counterRef = _firestore
        .collection(FirebasePaths.system)
        .doc(FirebasePaths.barangaysCounterDocumentId);
    final latestBarangayQuery = await _firestore
        .collection(FirebasePaths.barangays)
        .orderBy('id', descending: true)
        .limit(1)
        .get();
    final remoteNextBarangayId = latestBarangayQuery.docs.isEmpty
        ? 1
        : (_coerceInt(latestBarangayQuery.docs.first.data()['id']) + 1);
    final baselineNextBarangayId = math.max(
      1,
      remoteNextBarangayId > 0 ? remoteNextBarangayId : fallbackNextBarangayId,
    );

    return _firestore.runTransaction<List<int>>((transaction) async {
      final snapshot = await transaction.get(counterRef);
      final data = snapshot.data();
      final currentNextBarangayId = data == null
          ? 0
          : _coerceInt(data['nextBarangayId']);
      final reservedStartId = currentNextBarangayId > 0
          ? math.max(currentNextBarangayId, baselineNextBarangayId)
          : baselineNextBarangayId;
      final reservedIds = List<int>.generate(
        count,
        (index) => reservedStartId + index,
      );

      transaction.set(counterRef, {
        'nextBarangayId': reservedStartId + count,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));

      return reservedIds;
    });
  }

  Future<int> reserveNextBannerId({int fallbackNextBannerId = 1}) async {
    final reserved = await reserveNextBannerIds(
      count: 1,
      fallbackNextBannerId: fallbackNextBannerId,
    );
    return reserved.first;
  }

  Future<List<int>> reserveNextBannerIds({
    required int count,
    int fallbackNextBannerId = 1,
  }) async {
    if (count <= 0) {
      return const [];
    }
    final counterRef = _firestore
        .collection(FirebasePaths.system)
        .doc(FirebasePaths.bannersCounterDocumentId);
    final latestBannerQuery = await _firestore
        .collection(FirebasePaths.banners)
        .orderBy('id', descending: true)
        .limit(1)
        .get();
    final remoteNextBannerId = latestBannerQuery.docs.isEmpty
        ? 1
        : (_coerceInt(latestBannerQuery.docs.first.data()['id']) + 1);
    final baselineNextBannerId = math.max(
      1,
      remoteNextBannerId > 0 ? remoteNextBannerId : fallbackNextBannerId,
    );

    return _firestore.runTransaction<List<int>>((transaction) async {
      final snapshot = await transaction.get(counterRef);
      final data = snapshot.data();
      final currentNextBannerId = data == null
          ? 0
          : _coerceInt(data['nextBannerId']);
      final reservedStartId = currentNextBannerId > 0
          ? math.max(currentNextBannerId, baselineNextBannerId)
          : baselineNextBannerId;
      final reservedIds = List<int>.generate(
        count,
        (index) => reservedStartId + index,
      );

      transaction.set(counterRef, {
        'nextBannerId': reservedStartId + count,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));

      return reservedIds;
    });
  }

  Future<int> reserveNextProductId({int fallbackNextProductId = 1}) async {
    final reserved = await reserveNextProductIds(
      count: 1,
      fallbackNextProductId: fallbackNextProductId,
    );
    return reserved.first;
  }

  Future<List<int>> reserveNextProductIds({
    required int count,
    int fallbackNextProductId = 1,
  }) async {
    if (count <= 0) {
      return const [];
    }
    final counterRef = _firestore
        .collection(FirebasePaths.system)
        .doc(FirebasePaths.productsCounterDocumentId);
    final latestProductQuery = await _firestore
        .collection(FirebasePaths.products)
        .orderBy('id', descending: true)
        .limit(1)
        .get();
    final remoteNextProductId = latestProductQuery.docs.isEmpty
        ? 1
        : (_coerceInt(latestProductQuery.docs.first.data()['id']) + 1);
    final baselineNextProductId = math.max(
      1,
      remoteNextProductId > 0 ? remoteNextProductId : fallbackNextProductId,
    );

    return _firestore.runTransaction<List<int>>((transaction) async {
      final snapshot = await transaction.get(counterRef);
      final data = snapshot.data();
      final currentNextProductId = data == null
          ? 0
          : _coerceInt(data['nextProductId']);
      final reservedStartId = currentNextProductId > 0
          ? math.max(currentNextProductId, baselineNextProductId)
          : baselineNextProductId;
      final reservedIds = List<int>.generate(
        count,
        (index) => reservedStartId + index,
      );

      transaction.set(counterRef, {
        'nextProductId': reservedStartId + count,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));

      return reservedIds;
    });
  }

  int _coerceInt(Object? value) {
    if (value is int) {
      return value;
    }
    return int.tryParse('$value') ?? 0;
  }

  Future<void> _touchCatalogMeta({
    bool categories = false,
    bool barangays = false,
    bool banners = false,
    bool products = false,
    bool settings = false,
  }) async {
    await _catalogMetaRef.set(
      _catalogMetaData(
        categories: categories,
        barangays: barangays,
        banners: banners,
        products: products,
        settings: settings,
      ),
      SetOptions(merge: true),
    );
  }

  Map<String, dynamic> _catalogMetaData({
    bool categories = false,
    bool barangays = false,
    bool banners = false,
    bool products = false,
    bool settings = false,
  }) {
    final now = DateTime.now().toIso8601String();
    final data = <String, dynamic>{'updatedAt': now};
    if (categories) {
      data['categoriesUpdatedAt'] = now;
    }
    if (barangays) {
      data['barangaysUpdatedAt'] = now;
    }
    if (banners) {
      data['bannersUpdatedAt'] = now;
    }
    if (products) {
      data['productsUpdatedAt'] = now;
    }
    if (settings) {
      data['settingsUpdatedAt'] = now;
    }
    return data;
  }

  Future<List<T>> _loadDocumentsByIds<T>({
    required String collectionPath,
    required Iterable<int> ids,
    required T Function(QueryDocumentSnapshot<Map<String, dynamic>> doc) mapper,
  }) async {
    final itemIds = ids.toSet().toList()..sort();
    if (itemIds.isEmpty) {
      return const [];
    }

    final items = <T>[];
    for (var index = 0; index < itemIds.length; index += 10) {
      final end = math.min(index + 10, itemIds.length);
      final group = itemIds.sublist(index, end);
      final snapshot = await _firestore
          .collection(collectionPath)
          .where(
            FieldPath.documentId,
            whereIn: group.map((id) => '$id').toList(),
          )
          .get();
      items.addAll(snapshot.docs.map(mapper));
    }
    return items;
  }

  ProductManifestSnapshot? _productManifestFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) {
      return null;
    }
    final normalized = _normalizeFirestoreMap(data);
    final itemsRaw = normalized['items'];
    final itemUpdatedAts = <int, DateTime>{};
    if (itemsRaw is Map<String, dynamic>) {
      for (final entry in itemsRaw.entries) {
        final id = int.tryParse(entry.key);
        final updatedAt = _parseMetaDate(entry.value);
        if (id == null || updatedAt == null) {
          continue;
        }
        itemUpdatedAts[id] = updatedAt;
      }
    }
    final manifest = ProductManifestSnapshot(
      updatedAt: _parseMetaDate(normalized['updatedAt']),
      itemUpdatedAts: itemUpdatedAts,
    );
    return manifest.hasAnyData ? manifest : null;
  }

  Map<String, dynamic> _productsManifestData(Iterable<Product> products) {
    return _manifestData(
      products.map((product) => (product.id, product.updatedAt)),
    );
  }

  Map<String, dynamic> _productsManifestEntryData(Product product) {
    return _manifestEntryData(product.id, product.updatedAt);
  }

  Map<String, dynamic> _productsManifestEntriesData(
    Iterable<Product> products,
  ) {
    return _manifestEntriesData(
      products.map((product) => (product.id, product.updatedAt)),
    );
  }

  Map<String, dynamic> _deleteProductManifestEntryData(int productId) {
    return _deleteManifestEntryData(productId);
  }

  Map<String, dynamic> _manifestData(Iterable<(int, DateTime)> entries) {
    final now = DateTime.now().toIso8601String();
    return {
      'updatedAt': now,
      'items': {
        for (final entry in entries) '${entry.$1}': entry.$2.toIso8601String(),
      },
    };
  }

  Map<String, dynamic> _manifestEntryData(int id, DateTime updatedAt) {
    return {
      'updatedAt': DateTime.now().toIso8601String(),
      'items.$id': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> _manifestEntriesData(Iterable<(int, DateTime)> entries) {
    final data = <String, dynamic>{
      'updatedAt': DateTime.now().toIso8601String(),
    };
    for (final entry in entries) {
      data['items.${entry.$1}'] = entry.$2.toIso8601String();
    }
    return data;
  }

  Map<String, dynamic> _deleteManifestEntryData(int id) {
    return {
      'updatedAt': DateTime.now().toIso8601String(),
      'items.$id': FieldValue.delete(),
    };
  }

  DateTime? _parseMetaDate(Object? value) {
    if (value == null) {
      return null;
    }
    final raw = '$value'.trim();
    if (raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  Future<AdminSession?> loadAdminSession(String uid) async {
    final doc = await _firestore
        .collection(FirebasePaths.admins)
        .doc(uid)
        .get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }
    final map = _normalizeFirestoreMap(doc.data()!);
    map.putIfAbsent('uid', () => uid);
    map.putIfAbsent('id', () => 1);
    map.putIfAbsent('email', () => map['email'] ?? '');
    map.putIfAbsent('displayName', () => map['displayName'] ?? '');
    return AdminSession.fromMap(map);
  }

  Future<void> saveAdminSession(AdminSession session) async {
    await _firestore
        .collection(FirebasePaths.admins)
        .doc(session.uid)
        .set(session.toMap(), SetOptions(merge: true));
  }

  Category _categoryFromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final map = _normalizeFirestoreMap(doc.data());
    map.putIfAbsent('id', () => int.tryParse(doc.id) ?? 0);
    map.putIfAbsent(
      'normalizedName',
      () => '${map['name'] ?? ''}'.trim().toLowerCase(),
    );
    map.putIfAbsent(
      'sortOrder',
      () => map['id'] is int
          ? map['id'] as int
          : int.tryParse('${map['id']}') ?? 0,
    );
    return Category.fromMap(map);
  }

  int _compareCategoriesBySortOrder(Category a, Category b) {
    final bySortOrder = a.sortOrder.compareTo(b.sortOrder);
    if (bySortOrder != 0) {
      return bySortOrder;
    }
    return a.id.compareTo(b.id);
  }

  Barangay _barangayFromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final map = _normalizeFirestoreMap(doc.data());
    map.putIfAbsent('id', () => int.tryParse(doc.id) ?? 0);
    return Barangay.fromMap(map);
  }

  AppBanner _bannerFromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final map = _normalizeFirestoreMap(doc.data());
    map.putIfAbsent('id', () => int.tryParse(doc.id) ?? 0);
    return AppBanner.fromMap(map);
  }

  Product _productFromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final map = _normalizeFirestoreMap(doc.data());
    map.putIfAbsent('id', () => int.tryParse(doc.id) ?? 0);
    return Product.fromMap(map);
  }

  OrderRequest _orderFromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final map = _normalizeFirestoreMap(doc.data());
    map.putIfAbsent('id', () => int.tryParse(doc.id) ?? 0);
    return OrderRequest.fromMap(map);
  }

  AppSettings _settingsFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final map = _normalizeFirestoreMap(doc.data() ?? const {});
    map.putIfAbsent('id', () => int.tryParse(doc.id) ?? 1);
    return AppSettings.fromMap(map);
  }

  Map<String, dynamic> _categoryData(
    Category category, {
    required int sortOrder,
  }) {
    return {
      ...category.toMap(),
      'isActive': category.isActive,
      'active': category.isActive,
      'status': category.isActive,
      'sortOrder': sortOrder,
    };
  }

  Map<String, dynamic> _barangayData(Barangay barangay) {
    return {
      ...barangay.toMap(),
      'active': barangay.isActive,
      'status': barangay.isActive,
    };
  }

  Map<String, dynamic> _bannerData(AppBanner banner) {
    return {
      ...banner.toMap(),
      'isActive': banner.isActive,
      'active': banner.isActive,
      'status': banner.isActive,
    };
  }

  Map<String, dynamic> _productData(Product product) {
    return {
      ...product.toMap(),
      'categoryId': product.categoryId,
      'isActive': product.isActive,
      'active': product.isActive,
      'status': product.isActive,
    };
  }

  Future<List<Category>> _loadPublicCategories() async {
    final snapshot = await _firestore
        .collection(FirebasePaths.categories)
        .where('isActive', isEqualTo: true)
        .get();
    return snapshot.docs.map(_categoryFromSnapshot).toList();
  }

  Future<List<AppBanner>> _loadPublicBanners() async {
    final snapshot = await _firestore
        .collection(FirebasePaths.banners)
        .where('isActive', isEqualTo: true)
        .get();
    return snapshot.docs.map(_bannerFromSnapshot).toList();
  }

  Future<List<Product>> _loadPublicProducts() async {
    final snapshot = await _firestore
        .collection(FirebasePaths.products)
        .where('isActive', isEqualTo: true)
        .get();
    return snapshot.docs.map(_productFromSnapshot).toList();
  }

  Map<String, dynamic> _settingsData(AppSettings settings) {
    return {...settings.toMap(), 'id': settings.id};
  }

  Map<String, dynamic> _orderData(OrderRequest order) {
    final customer = order.customer.copyWith(
      normalizedMobileNumber: normalizePhoneNumber(order.phone),
    );
    return {
      ...order.toMap(),
      'estimatedTotalCentavos': order.estimatedTotalCentavos,
      'finalQuotedTotalCentavos': order.finalQuotedTotalCentavos,
      'bestSellerMetricsApplied': order.bestSellerMetricsApplied,
      'deliveryFeeCentavos': order.deliveryFeeCentavos,
      'discountCentavos': order.discountCentavos,
      'manualAdjustmentCentavos': order.manualAdjustmentCentavos,
      'fulfillmentMethod': order.fulfillmentMethod.name,
      'customerConfirmation': order.customerConfirmation.name,
      'customer': customer.toMap(),
      'items': order.items.map((item) => item.toMap()).toList(),
    };
  }

  Map<String, dynamic> _normalizeFirestoreMap(Map<String, dynamic> raw) {
    return raw.map(
      (key, value) => MapEntry(key, _normalizeFirestoreValue(value)),
    );
  }

  dynamic _normalizeFirestoreValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    }
    if (value is Map) {
      return value.map(
        (key, nestedValue) =>
            MapEntry('$key', _normalizeFirestoreValue(nestedValue)),
      );
    }
    if (value is List) {
      return value.map(_normalizeFirestoreValue).toList();
    }
    return value;
  }
}
