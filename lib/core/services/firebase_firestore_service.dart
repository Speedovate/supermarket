import 'dart:async';

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

class FirestoreCatalogService {
  FirestoreCatalogService(this._firestore);

  final FirebaseFirestore _firestore;

  Future<FirestoreCatalogSnapshot?> loadPublicSnapshot() async {
    final results = await Future.wait<Object?>([
      loadCategories(includeInactive: false),
      loadBarangays(includeInactive: false),
      loadBanners(includeInactive: false),
      loadProducts(includeInactive: false),
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

  Future<List<Category>> loadCategories({bool includeInactive = true}) async {
    final query = includeInactive
        ? _firestore.collection(FirebasePaths.categories).orderBy('id')
        : _firestore
              .collection(FirebasePaths.categories)
              .where('isActive', isEqualTo: true);
    final snapshot = await query.get();
    final categories = snapshot.docs.map(_categoryFromSnapshot).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return categories;
  }

  Stream<List<Category>> watchCategories({bool includeInactive = true}) {
    final query = includeInactive
        ? _firestore.collection(FirebasePaths.categories).orderBy('id')
        : _firestore
              .collection(FirebasePaths.categories)
              .where('isActive', isEqualTo: true);
    return query
        .snapshots()
        .map((snapshot) {
          final categories = snapshot.docs.map(_categoryFromSnapshot).toList()
            ..sort((a, b) => a.id.compareTo(b.id));
          return categories;
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

  Stream<List<Barangay>> watchBarangays({bool includeInactive = true}) {
    final query = includeInactive
        ? _firestore.collection(FirebasePaths.barangays).orderBy('name')
        : _firestore
              .collection(FirebasePaths.barangays)
              .where('active', isEqualTo: true);
    return query
        .snapshots()
        .map((snapshot) {
          final barangays = snapshot.docs.map(_barangayFromSnapshot).toList()
            ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          return barangays;
        });
  }

  Future<List<AppBanner>> loadBanners({bool includeInactive = true}) async {
    final query = includeInactive
        ? _firestore.collection(FirebasePaths.banners).orderBy('id')
        : _firestore
              .collection(FirebasePaths.banners)
              .where('isActive', isEqualTo: true);
    final snapshot = await query.get();
    final banners = snapshot.docs.map(_bannerFromSnapshot).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return banners;
  }

  Stream<List<AppBanner>> watchBanners({bool includeInactive = true}) {
    final query = includeInactive
        ? _firestore.collection(FirebasePaths.banners).orderBy('id')
        : _firestore
              .collection(FirebasePaths.banners)
              .where('isActive', isEqualTo: true);
    return query
        .snapshots()
        .map((snapshot) {
          final banners = snapshot.docs.map(_bannerFromSnapshot).toList()
            ..sort((a, b) => a.id.compareTo(b.id));
          return banners;
        });
  }

  Future<List<Product>> loadProducts({bool includeInactive = true}) async {
    final query = includeInactive
        ? _firestore.collection(FirebasePaths.products).orderBy('id')
        : _firestore
              .collection(FirebasePaths.products)
              .where('isActive', isEqualTo: true);
    final snapshot = await query.get();
    final products = snapshot.docs.map(_productFromSnapshot).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return products;
  }

  Stream<List<Product>> watchProducts({bool includeInactive = true}) {
    final query = includeInactive
        ? _firestore.collection(FirebasePaths.products).orderBy('id')
        : _firestore
              .collection(FirebasePaths.products)
              .where('isActive', isEqualTo: true);
    return query
        .snapshots()
        .map((snapshot) {
          final products = snapshot.docs.map(_productFromSnapshot).toList()
            ..sort((a, b) => a.id.compareTo(b.id));
          return products;
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
      final subscriptions = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];

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
        final subscription = streams[index].listen(
          (snapshot) {
            snapshots[index] = snapshot;
            emitMerged();
          },
          onError: controller.addError,
        );
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

  Future<void> seedInitialData({
    required List<Category> categories,
    required List<Barangay> barangays,
    required List<AppBanner> banners,
    required List<Product> products,
    required AppSettings settings,
  }) async {
    final batch = _firestore.batch();

    for (var index = 0; index < categories.length; index++) {
      final category = categories[index];
      final ref = _firestore
          .collection(FirebasePaths.categories)
          .doc('${category.id}');
      batch.set(ref, _categoryData(category, sortOrder: index));
    }

    for (final barangay in barangays) {
      final ref = _firestore
          .collection(FirebasePaths.barangays)
          .doc('${barangay.id}');
      batch.set(ref, _barangayData(barangay));
    }

    for (final banner in banners) {
      final ref = _firestore.collection(FirebasePaths.banners).doc('${banner.id}');
      batch.set(ref, _bannerData(banner));
    }

    for (final product in products) {
      final ref = _firestore
          .collection(FirebasePaths.products)
          .doc('${product.id}');
      batch.set(ref, _productData(product));
    }

    final settingsRef = _firestore
        .collection(FirebasePaths.appSettings)
        .doc(FirebasePaths.defaultSettingsDocumentId);
    batch.set(settingsRef, _settingsData(settings));

    await batch.commit();
  }

  Future<void> saveProduct(Product product) async {
    await _firestore
        .collection(FirebasePaths.products)
        .doc('${product.id}')
        .set(_productData(product));
  }

  Future<void> deleteProduct(int productId) async {
    await _firestore.collection(FirebasePaths.products).doc('$productId').delete();
  }

  Future<void> saveCategory(Category category, {int? sortOrder}) async {
    await _firestore.collection(FirebasePaths.categories).doc('${category.id}').set(
      _categoryData(category, sortOrder: sortOrder ?? category.id),
    );
  }

  Future<void> deleteCategory(int categoryId) async {
    await _firestore
        .collection(FirebasePaths.categories)
        .doc('$categoryId')
        .delete();
  }

  Future<void> saveBarangay(Barangay barangay) async {
    await _firestore
        .collection(FirebasePaths.barangays)
        .doc('${barangay.id}')
        .set(_barangayData(barangay));
  }

  Future<void> deleteBarangay(int barangayId) async {
    await _firestore
        .collection(FirebasePaths.barangays)
        .doc('$barangayId')
        .delete();
  }

  Future<void> saveBanner(AppBanner banner) async {
    await _firestore
        .collection(FirebasePaths.banners)
        .doc('${banner.id}')
        .set(_bannerData(banner));
  }

  Future<void> deleteBanner(int bannerId) async {
    await _firestore.collection(FirebasePaths.banners).doc('$bannerId').delete();
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _firestore
        .collection(FirebasePaths.appSettings)
        .doc(FirebasePaths.defaultSettingsDocumentId)
        .set(_settingsData(settings));
  }

  Future<void> saveOrder(OrderRequest order) async {
    await _firestore.collection(FirebasePaths.orders).doc('${order.id}').set(
      _orderData(order),
    );
  }

  Future<AdminSession?> loadAdminSession(String uid) async {
    final doc = await _firestore.collection(FirebasePaths.admins).doc(uid).get();
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
    await _firestore.collection(FirebasePaths.admins).doc(session.uid).set(
      session.toMap(),
      SetOptions(merge: true),
    );
  }

  Category _categoryFromSnapshot(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final map = _normalizeFirestoreMap(doc.data());
    map.putIfAbsent('id', () => int.tryParse(doc.id) ?? 0);
    map.putIfAbsent('normalizedName', () => '${map['name'] ?? ''}'.trim().toLowerCase());
    return Category.fromMap(map);
  }

  Barangay _barangayFromSnapshot(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final map = _normalizeFirestoreMap(doc.data());
    map.putIfAbsent('id', () => int.tryParse(doc.id) ?? 0);
    return Barangay.fromMap(map);
  }

  AppBanner _bannerFromSnapshot(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final map = _normalizeFirestoreMap(doc.data());
    map.putIfAbsent('id', () => int.tryParse(doc.id) ?? 0);
    return AppBanner.fromMap(map);
  }

  Product _productFromSnapshot(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final map = _normalizeFirestoreMap(doc.data());
    map.putIfAbsent('id', () => int.tryParse(doc.id) ?? 0);
    return Product.fromMap(map);
  }

  OrderRequest _orderFromSnapshot(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final map = _normalizeFirestoreMap(doc.data());
    map.putIfAbsent('id', () => int.tryParse(doc.id) ?? 0);
    return OrderRequest.fromMap(map);
  }

  AppSettings _settingsFromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = _normalizeFirestoreMap(doc.data() ?? const {});
    map.putIfAbsent('id', () => int.tryParse(doc.id) ?? 1);
    return AppSettings.fromMap(map);
  }

  Map<String, dynamic> _categoryData(Category category, {required int sortOrder}) {
    return {
      ...category.toMap(),
      'isActive': category.isActive,
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
    };
  }

  Map<String, dynamic> _productData(Product product) {
    return {
      ...product.toMap(),
      'categoryId': product.categoryId,
      'isActive': product.isActive,
    };
  }

  Map<String, dynamic> _settingsData(AppSettings settings) {
    return {
      ...settings.toMap(),
      'id': settings.id,
    };
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
    return raw.map((key, value) => MapEntry(key, _normalizeFirestoreValue(value)));
  }

  dynamic _normalizeFirestoreValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    }
    if (value is Map) {
      return value.map(
        (key, nestedValue) => MapEntry('$key', _normalizeFirestoreValue(nestedValue)),
      );
    }
    if (value is List) {
      return value.map(_normalizeFirestoreValue).toList();
    }
    return value;
  }
}
