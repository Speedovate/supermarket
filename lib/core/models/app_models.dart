import 'dart:convert';

enum FulfillmentMethod { pickup, delivery }

enum OrderStatus { waiting, checking, ready, completed, cancelled }

enum AvailabilityStatus {
  pending,
  available,
  partiallyAvailable,
  unavailable,
  substituted,
}

enum CustomerConfirmationStatus { pending, confirmed, declined }

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.normalizedName,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final String normalizedName;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Category copyWith({
    int? id,
    String? name,
    String? normalizedName,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      normalizedName: normalizedName ?? this.normalizedName,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'normalizedName': normalizedName,
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Category.fromMap(Map<String, dynamic> map) {
    final fallbackDate = DateTime(2026, 7, 31);
    return Category(
      id: map['id'] is int
          ? map['id'] as int
          : int.tryParse('${map['id']}') ?? 0,
      name: map['name'] as String,
      normalizedName: map['normalizedName'] as String,
      isActive: map['isActive'] as bool,
      createdAt: map['createdAt'] == null
          ? fallbackDate
          : DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] == null
          ? fallbackDate
          : DateTime.parse(map['updatedAt'] as String),
    );
  }
}

class Product {
  const Product({
    required this.id,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
    required this.name,
    required this.category,
    required this.details,
    required this.price,
    required this.sold,
    this.photoUrl,
    this.photoStoragePath,
  });

  final int id;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String name;
  final int category;
  final String details;
  final int price;
  final int sold;
  final String? photoUrl;
  final String? photoStoragePath;

  String get normalizedName => name.trim().toLowerCase();

  bool get isActive => active;

  int get categoryId => category;

  int get referencePriceCentavos => price;

  DateTime get priceUpdatedAt => updatedAt;

  String get displayUnit => details.trim();

  String get quantity => _parseLegacyMeasure(details).quantity;

  String get unit => _parseLegacyMeasure(details).unit;

  String get type => _parseLegacyMeasure(details).type;

  Product copyWith({
    int? id,
    bool? active,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? name,
    int? category,
    int? categoryId,
    String? details,
    int? price,
    int? sold,
    int? referencePriceCentavos,
    bool? isActive,
    DateTime? priceUpdatedAt,
    Object? photoUrl = _sentinel,
    Object? photoStoragePath = _sentinel,
  }) {
    return Product(
      id: id ?? this.id,
      active: active ?? isActive ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? priceUpdatedAt ?? this.updatedAt,
      name: name ?? this.name,
      category: category ?? categoryId ?? this.category,
      details: details ?? this.details,
      price: price ?? referencePriceCentavos ?? this.price,
      sold: sold ?? this.sold,
      photoUrl: photoUrl == _sentinel ? this.photoUrl : photoUrl as String?,
      photoStoragePath: photoStoragePath == _sentinel
          ? this.photoStoragePath
          : photoStoragePath as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'active': active,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'name': name,
    'normalizedName': normalizedName,
    'category': category,
    'details': details,
    'price': price,
    'sold': sold,
    'photoUrl': photoUrl,
    'photoStoragePath': photoStoragePath,
  };

  factory Product.fromMap(Map<String, dynamic> map) {
    final parsedLegacyUnit = _parseLegacyMeasure(map['unit'] as String?);
    final legacyDetails = [
      (map['quantity'] as String?)?.trim() ?? parsedLegacyUnit.quantity,
      (map['unit'] as String?)?.trim() ?? parsedLegacyUnit.unit,
      (map['type'] as String?)?.trim() ?? parsedLegacyUnit.type,
    ].where((item) => item.isNotEmpty).join(itemNeedsSpaceJoiner);
    final fallbackDate = DateTime(2026, 7, 31);
    return Product(
      id: _parseInt(map['id']),
      active: (map['active'] ?? map['isActive']) as bool? ?? true,
      createdAt: map['createdAt'] == null
          ? fallbackDate
          : DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : map['priceUpdatedAt'] != null
          ? DateTime.parse(map['priceUpdatedAt'] as String)
          : fallbackDate,
      name: map['name'] as String,
      category: _parseInt(map['category'] ?? map['categoryId']),
      details: (map['details'] as String?)?.trim().isNotEmpty == true
          ? (map['details'] as String).trim()
          : legacyDetails,
      price: _parseInt(map['price'] ?? map['referencePriceCentavos']),
      sold: _parseInt(map['sold']),
      photoUrl: (map['photoUrl'] as String?)?.trim().isEmpty == true
          ? null
          : (map['photoUrl'] as String?)?.trim(),
      photoStoragePath:
          (map['photoStoragePath'] as String?)?.trim().isEmpty == true
          ? null
          : (map['photoStoragePath'] as String?)?.trim(),
    );
  }
}

class AppBanner {
  const AppBanner({
    required this.id,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
    required this.imageUrl,
    this.externalUrl,
  });

  final int id;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String imageUrl;
  final String? externalUrl;

  bool get isActive => active;

  AppBanner copyWith({
    int? id,
    bool? active,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? imageUrl,
    String? externalUrl,
  }) {
    return AppBanner(
      id: id ?? this.id,
      active: active ?? isActive ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      imageUrl: imageUrl ?? this.imageUrl,
      externalUrl: externalUrl ?? this.externalUrl,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'active': active,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'imageUrl': imageUrl,
    'externalUrl': externalUrl,
  };

  factory AppBanner.fromMap(Map<String, dynamic> map) {
    final fallbackDate = DateTime(2026, 8, 7);
    return AppBanner(
      id: _parseInt(map['id']),
      active: (map['active'] ?? map['isActive']) as bool? ?? true,
      createdAt: map['createdAt'] == null
          ? fallbackDate
          : DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] == null
          ? fallbackDate
          : DateTime.parse(map['updatedAt'] as String),
      imageUrl: (map['imageUrl'] as String? ?? '').trim(),
      externalUrl: (map['externalUrl'] as String?)?.trim().isEmpty == true
          ? null
          : (map['externalUrl'] as String?)?.trim(),
    );
  }
}

class _ParsedMeasure {
  const _ParsedMeasure({
    required this.quantity,
    required this.unit,
    required this.type,
  });

  final String quantity;
  final String unit;
  final String type;
}

_ParsedMeasure _parseLegacyMeasure(String? raw) {
  final source = raw?.trim() ?? '';
  final match = RegExp(
    r'^(\d+(?:\.\d+)?)\s*([A-Za-z]+)\s*(.*)$',
  ).firstMatch(source);
  if (match == null) {
    return _ParsedMeasure(quantity: '', unit: source, type: '');
  }

  return _ParsedMeasure(
    quantity: match.group(1)?.trim() ?? '',
    unit: match.group(2)?.trim() ?? '',
    type: match.group(3)?.trim() ?? '',
  );
}

int _parseInt(Object? value) {
  if (value is int) {
    return value;
  }
  return int.tryParse('$value') ?? 0;
}

const itemNeedsSpaceJoiner = ' ';

class CartItem {
  const CartItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.unit,
    required this.referenceUnitPriceCentavos,
    this.photoUrl,
    required this.quantity,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int productId;
  final String productName;
  final String unit;
  final int referenceUnitPriceCentavos;
  final String? photoUrl;
  final int quantity;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  int get estimatedSubtotalCentavos => referenceUnitPriceCentavos * quantity;

  CartItem copyWith({
    int? id,
    int? productId,
    String? productName,
    String? unit,
    int? referenceUnitPriceCentavos,
    Object? photoUrl = _sentinel,
    int? quantity,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CartItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      unit: unit ?? this.unit,
      referenceUnitPriceCentavos:
          referenceUnitPriceCentavos ?? this.referenceUnitPriceCentavos,
      photoUrl: photoUrl == _sentinel ? this.photoUrl : photoUrl as String?,
      quantity: quantity ?? this.quantity,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'productId': productId,
    'productName': productName,
    'unit': unit,
    'referenceUnitPriceCentavos': referenceUnitPriceCentavos,
    'photoUrl': photoUrl,
    'quantity': quantity,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      id: map['id'] is int
          ? map['id'] as int
          : int.tryParse('${map['id']}') ?? 0,
      productId: map['productId'] is int
          ? map['productId'] as int
          : int.tryParse('${map['productId']}') ?? 0,
      productName: map['productName'] as String,
      unit: map['unit'] as String,
      referenceUnitPriceCentavos: map['referenceUnitPriceCentavos'] as int,
      photoUrl: map['photoUrl'] as String?,
      quantity: map['quantity'] as int,
      createdAt: map['createdAt'] == null
          ? null
          : DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] == null
          ? null
          : DateTime.parse(map['updatedAt'] as String),
    );
  }
}

class CustomerDraft {
  const CustomerDraft({
    this.id = 1,
    this.name = '',
    this.mobileNumber = '',
    this.normalizedMobileNumber = '',
    this.barangay = '',
    this.addressStreet = '',
    this.addressLandmark = '',
    this.note = '',
    this.fulfillmentMethod = FulfillmentMethod.pickup,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String name;
  final String mobileNumber;
  final String normalizedMobileNumber;
  final String barangay;
  final String addressStreet;
  final String addressLandmark;
  final String note;
  final FulfillmentMethod fulfillmentMethod;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CustomerDraft copyWith({
    int? id,
    String? name,
    String? mobileNumber,
    String? normalizedMobileNumber,
    String? barangay,
    String? addressStreet,
    String? addressLandmark,
    String? note,
    FulfillmentMethod? fulfillmentMethod,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomerDraft(
      id: id ?? this.id,
      name: name ?? this.name,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      normalizedMobileNumber:
          normalizedMobileNumber ?? this.normalizedMobileNumber,
      barangay: barangay ?? this.barangay,
      addressStreet: addressStreet ?? this.addressStreet,
      addressLandmark: addressLandmark ?? this.addressLandmark,
      note: note ?? this.note,
      fulfillmentMethod: fulfillmentMethod ?? this.fulfillmentMethod,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'mobileNumber': mobileNumber,
    'normalizedMobileNumber': normalizedMobileNumber,
    'barangay': fulfillmentMethod == FulfillmentMethod.delivery
        ? barangay
        : null,
    'addressStreet': fulfillmentMethod == FulfillmentMethod.delivery
        ? addressStreet
        : '',
    'addressLandmark': addressLandmark,
    'note': note,
    'fulfillmentMethod': fulfillmentMethod.name,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory CustomerDraft.fromMap(Map<String, dynamic> map) {
    return CustomerDraft(
      id: map['id'] is int
          ? map['id'] as int
          : int.tryParse('${map['id']}') ?? 1,
      name: map['name'] as String? ?? '',
      mobileNumber: map['mobileNumber'] as String? ?? '',
      normalizedMobileNumber: map['normalizedMobileNumber'] as String? ?? '',
      barangay: map['barangay'] as String? ?? '',
      addressStreet:
          map['addressStreet'] as String? ?? map['street'] as String? ?? '',
      addressLandmark:
          map['addressLandmark'] as String? ?? map['landmark'] as String? ?? '',
      note: map['note'] as String? ?? '',
      fulfillmentMethod: FulfillmentMethod.values.byName(
        map['fulfillmentMethod'] as String? ?? FulfillmentMethod.pickup.name,
      ),
      createdAt: map['createdAt'] == null
          ? null
          : DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] == null
          ? null
          : DateTime.parse(map['updatedAt'] as String),
    );
  }
}

class OrderItemSubstitute {
  const OrderItemSubstitute({
    this.id = 1,
    this.productName,
    this.unit,
    this.quantity,
    this.unitPriceCentavos,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String? productName;
  final String? unit;
  final int? quantity;
  final int? unitPriceCentavos;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  OrderItemSubstitute copyWith({
    int? id,
    Object? productName = _sentinel,
    Object? unit = _sentinel,
    Object? quantity = _sentinel,
    Object? unitPriceCentavos = _sentinel,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OrderItemSubstitute(
      id: id ?? this.id,
      productName: productName == _sentinel
          ? this.productName
          : productName as String?,
      unit: unit == _sentinel ? this.unit : unit as String?,
      quantity: quantity == _sentinel ? this.quantity : quantity as int?,
      unitPriceCentavos: unitPriceCentavos == _sentinel
          ? this.unitPriceCentavos
          : unitPriceCentavos as int?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'productName': productName,
    'unit': unit,
    'quantity': quantity,
    'unitPriceCentavos': unitPriceCentavos,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory OrderItemSubstitute.fromMap(Map<String, dynamic> map) {
    return OrderItemSubstitute(
      id: map['id'] is int
          ? map['id'] as int
          : int.tryParse('${map['id']}') ?? 1,
      productName: map['productName'] as String?,
      unit: map['unit'] as String?,
      quantity: map['quantity'] as int?,
      unitPriceCentavos: map['unitPriceCentavos'] as int?,
      createdAt: map['createdAt'] == null
          ? null
          : DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] == null
          ? null
          : DateTime.parse(map['updatedAt'] as String),
    );
  }
}

class OrderItem {
  const OrderItem({
    required this.id,
    required this.productId,
    required this.productName,
    this.descriptionSnapshot,
    this.photoUrlSnapshot,
    required this.unit,
    required this.requestedQuantity,
    required this.referenceUnitPriceCentavos,
    required this.estimatedSubtotalCentavos,
    this.availabilityStatus = AvailabilityStatus.pending,
    this.approvedQuantity = 0,
    required this.quotedUnitPriceCentavos,
    this.quotedSubtotalCentavos = 0,
    this.adminItemNote,
    this.substitute,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int productId;
  final String productName;
  final String? descriptionSnapshot;
  final String? photoUrlSnapshot;
  final String unit;
  final int requestedQuantity;
  final int referenceUnitPriceCentavos;
  final int estimatedSubtotalCentavos;
  final AvailabilityStatus availabilityStatus;
  final int approvedQuantity;
  final int quotedUnitPriceCentavos;
  final int quotedSubtotalCentavos;
  final String? adminItemNote;
  final OrderItemSubstitute? substitute;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  OrderItem copyWith({
    int? id,
    int? productId,
    String? productName,
    Object? descriptionSnapshot = _sentinel,
    Object? photoUrlSnapshot = _sentinel,
    String? unit,
    int? requestedQuantity,
    int? referenceUnitPriceCentavos,
    int? estimatedSubtotalCentavos,
    AvailabilityStatus? availabilityStatus,
    int? approvedQuantity,
    int? quotedUnitPriceCentavos,
    int? quotedSubtotalCentavos,
    Object? adminItemNote = _sentinel,
    Object? substitute = _sentinel,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OrderItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      descriptionSnapshot: descriptionSnapshot == _sentinel
          ? this.descriptionSnapshot
          : descriptionSnapshot as String?,
      photoUrlSnapshot: photoUrlSnapshot == _sentinel
          ? this.photoUrlSnapshot
          : photoUrlSnapshot as String?,
      unit: unit ?? this.unit,
      requestedQuantity: requestedQuantity ?? this.requestedQuantity,
      referenceUnitPriceCentavos:
          referenceUnitPriceCentavos ?? this.referenceUnitPriceCentavos,
      estimatedSubtotalCentavos:
          estimatedSubtotalCentavos ?? this.estimatedSubtotalCentavos,
      availabilityStatus: availabilityStatus ?? this.availabilityStatus,
      approvedQuantity: approvedQuantity ?? this.approvedQuantity,
      quotedUnitPriceCentavos:
          quotedUnitPriceCentavos ?? this.quotedUnitPriceCentavos,
      quotedSubtotalCentavos:
          quotedSubtotalCentavos ?? this.quotedSubtotalCentavos,
      adminItemNote: adminItemNote == _sentinel
          ? this.adminItemNote
          : adminItemNote as String?,
      substitute: substitute == _sentinel
          ? this.substitute
          : substitute as OrderItemSubstitute?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'productId': productId,
    'productName': productName,
    'descriptionSnapshot': descriptionSnapshot,
    'photoUrlSnapshot': photoUrlSnapshot,
    'unit': unit,
    'requestedQuantity': requestedQuantity,
    'referenceUnitPriceCentavos': referenceUnitPriceCentavos,
    'estimatedSubtotalCentavos': estimatedSubtotalCentavos,
    'availabilityStatus': availabilityStatus.name,
    'approvedQuantity': approvedQuantity,
    'quotedUnitPriceCentavos': quotedUnitPriceCentavos,
    'quotedSubtotalCentavos': quotedSubtotalCentavos,
    'adminItemNote': adminItemNote,
    'substitute': substitute?.toMap(),
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id'] is int
          ? map['id'] as int
          : int.tryParse('${map['id']}') ?? 0,
      productId: map['productId'] is int
          ? map['productId'] as int
          : int.tryParse('${map['productId']}') ?? 0,
      productName: map['productName'] as String,
      descriptionSnapshot: map['descriptionSnapshot'] as String?,
      photoUrlSnapshot: map['photoUrlSnapshot'] as String?,
      unit: map['unit'] as String,
      requestedQuantity: map['requestedQuantity'] as int,
      referenceUnitPriceCentavos: map['referenceUnitPriceCentavos'] as int,
      estimatedSubtotalCentavos: map['estimatedSubtotalCentavos'] as int,
      availabilityStatus: AvailabilityStatus.values.byName(
        map['availabilityStatus'] as String? ?? AvailabilityStatus.pending.name,
      ),
      approvedQuantity: map['approvedQuantity'] as int? ?? 0,
      quotedUnitPriceCentavos: map['quotedUnitPriceCentavos'] as int? ?? 0,
      quotedSubtotalCentavos: map['quotedSubtotalCentavos'] as int? ?? 0,
      adminItemNote: map['adminItemNote'] as String?,
      substitute: map['substitute'] == null
          ? null
          : OrderItemSubstitute.fromMap(
              Map<String, dynamic>.from(map['substitute'] as Map),
            ),
      createdAt: map['createdAt'] == null
          ? null
          : DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] == null
          ? null
          : DateTime.parse(map['updatedAt'] as String),
    );
  }
}

class OrderRequest {
  const OrderRequest({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.total,
    required this.name,
    required this.phone,
    required this.method,
    required this.place,
    this.addressStreet = '',
    this.addressLandmark = '',
    required this.products,
  });

  final int id;
  final OrderStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int total;
  final String name;
  final String phone;
  final FulfillmentMethod method;
  final String place;
  final String addressStreet;
  final String addressLandmark;
  final List<OrderItem> products;

  CustomerDraft get customer => CustomerDraft(
    name: name,
    mobileNumber: phone,
    normalizedMobileNumber: phone,
    barangay: method == FulfillmentMethod.delivery ? place : '',
    addressStreet: method == FulfillmentMethod.delivery ? addressStreet : '',
    addressLandmark: method == FulfillmentMethod.delivery
        ? addressLandmark
        : '',
    fulfillmentMethod: method,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  List<OrderItem> get items => products;

  int get estimatedTotalCentavos => total;

  FulfillmentMethod get fulfillmentMethod => method;

  int get deliveryFeeCentavos => 0;

  int get discountCentavos => 0;

  int get manualAdjustmentCentavos => 0;

  int get finalQuotedTotalCentavos => total;

  CustomerConfirmationStatus get customerConfirmation =>
      CustomerConfirmationStatus.pending;

  String? get cancellationReason => null;

  String? get rejectionReason => null;

  bool get bestSellerMetricsApplied => false;

  String? get createdByAdminId => null;

  String? get updatedByAdminId => null;

  OrderRequest copyWith({
    int? id,
    int? total,
    String? name,
    String? phone,
    FulfillmentMethod? method,
    String? place,
    String? addressStreet,
    String? addressLandmark,
    List<OrderItem>? products,
    CustomerDraft? customer,
    List<OrderItem>? items,
    int? estimatedTotalCentavos,
    FulfillmentMethod? fulfillmentMethod,
    OrderStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final effectiveCustomer = customer;
    return OrderRequest(
      id: id ?? this.id,
      total: total ?? estimatedTotalCentavos ?? this.total,
      name: name ?? effectiveCustomer?.name ?? this.name,
      phone: phone ?? effectiveCustomer?.mobileNumber ?? this.phone,
      method:
          method ??
          fulfillmentMethod ??
          effectiveCustomer?.fulfillmentMethod ??
          this.method,
      place: place ?? effectiveCustomer?.barangay ?? this.place,
      addressStreet:
          addressStreet ??
          effectiveCustomer?.addressStreet ??
          this.addressStreet,
      addressLandmark:
          addressLandmark ??
          effectiveCustomer?.addressLandmark ??
          this.addressLandmark,
      products: products ?? items ?? this.products,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'total': total,
    'name': name,
    'phone': phone,
    'method': method.name,
    'place': method == FulfillmentMethod.delivery ? place : '',
    'addressStreet': method == FulfillmentMethod.delivery ? addressStreet : '',
    'addressLandmark': method == FulfillmentMethod.delivery
        ? addressLandmark
        : '',
    'products': products.map((item) => item.toMap()).toList(),
  };

  factory OrderRequest.fromMap(Map<String, dynamic> map) {
    final customerMap = map['customer'] == null
        ? null
        : CustomerDraft.fromMap(
            Map<String, dynamic>.from(map['customer'] as Map),
          );
    final parsedMethod = FulfillmentMethod.values.byName(
      map['method'] as String? ??
          map['fulfillmentMethod'] as String? ??
          customerMap?.fulfillmentMethod.name ??
          FulfillmentMethod.pickup.name,
    );
    final parsedProducts =
        (map['products'] as List<dynamic>? ??
                map['items'] as List<dynamic>? ??
                [])
            .map(
              (item) =>
                  OrderItem.fromMap(Map<String, dynamic>.from(item as Map)),
            )
            .toList();
    return OrderRequest(
      id: map['id'] is int
          ? map['id'] as int
          : int.tryParse('${map['id']}') ?? 0,
      status: _parseOrderStatus(map['status'] as String?),
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      total: _parseInt(
        map['total'] ??
            map['estimatedTotalCentavos'] ??
            map['finalQuotedTotalCentavos'],
      ),
      name: map['name'] as String? ?? customerMap?.name ?? '',
      phone: map['phone'] as String? ?? customerMap?.mobileNumber ?? '',
      method: parsedMethod,
      place:
          map['place'] as String? ??
          map['barangay'] as String? ??
          customerMap?.barangay ??
          '',
      addressStreet:
          map['addressStreet'] as String? ??
          map['street'] as String? ??
          customerMap?.addressStreet ??
          '',
      addressLandmark:
          map['addressLandmark'] as String? ??
          map['landmark'] as String? ??
          customerMap?.addressLandmark ??
          '',
      products: parsedProducts,
    );
  }
}

OrderStatus _parseOrderStatus(String? raw) {
  return switch (raw) {
    'waiting' || 'newRequest' => OrderStatus.waiting,
    'checking' ||
    'underReview' ||
    'awaitingCustomerConfirmation' => OrderStatus.checking,
    'ready' ||
    'confirmed' ||
    'preparing' ||
    'readyForPickup' ||
    'outForDelivery' => OrderStatus.ready,
    'completed' => OrderStatus.completed,
    'cancelled' || 'rejected' => OrderStatus.cancelled,
    _ => OrderStatus.waiting,
  };
}

class Barangay {
  const Barangay({
    required this.id,
    required this.name,
    required this.isActive,
    required this.cutoffWeekday,
    required this.cutoffMinutes,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final bool isActive;
  final int cutoffWeekday;
  final int cutoffMinutes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Barangay copyWith({
    int? id,
    String? name,
    bool? isActive,
    int? cutoffWeekday,
    int? cutoffMinutes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Barangay(
      id: id ?? this.id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      cutoffWeekday: cutoffWeekday ?? this.cutoffWeekday,
      cutoffMinutes: cutoffMinutes ?? this.cutoffMinutes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'isActive': isActive,
    'cutoffWeekday': cutoffWeekday,
    'cutoffMinutes': cutoffMinutes,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Barangay.fromMap(Map<String, dynamic> map) {
    final fallbackDate = DateTime(2026, 8, 16);
    final parsedWeekday = _parseInt(map['cutoffWeekday']);
    final normalizedWeekday =
        parsedWeekday >= DateTime.monday && parsedWeekday <= DateTime.sunday
        ? parsedWeekday
        : DateTime.monday;
    final parsedCutoffMinutes = _parseInt(map['cutoffMinutes']);
    return Barangay(
      id: _parseInt(map['id']),
      name: (map['name'] as String? ?? '').trim(),
      isActive:
          (map['isActive'] ?? map['active'] ?? map['status']) as bool? ?? true,
      cutoffWeekday: normalizedWeekday,
      cutoffMinutes: parsedCutoffMinutes >= 0 && parsedCutoffMinutes < 1440
          ? parsedCutoffMinutes
          : 17 * 60,
      createdAt: map['createdAt'] == null
          ? fallbackDate
          : DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] == null
          ? fallbackDate
          : DateTime.parse(map['updatedAt'] as String),
    );
  }
}

class AppSettings {
  const AppSettings({
    this.id = 1,
    this.bestSellersEnabled = true,
    this.bestSellersShowAll = false,
    this.bestSellerMinSoldUnits = 1,
    this.bestSellersLimit = 6,
    this.bestSellerBasis = BestSellerBasis.lifetime,
    this.storeName = "Andrew's Supermarket",
    this.storeContactNumber = '09064493206',
    this.facebookMessengerUrl =
        'https://www.facebook.com/andrew.s.supermarket.2024',
    this.supportContactUrl = '',
    this.logoReference = 'assets/branding/as_logo_dark.png',
    this.faviconReference = 'assets/branding/as_logo_dark.png',
    this.serviceableBarangays = const [],
    this.useFlatDeliveryFee = true,
    this.flatDeliveryFee = 0,
    this.deliveryFeesByBarangay = const {},
    this.minimumDeliveryOrderAmount = 0,
    this.requirePlaceForDeliveryOnly = true,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final bool bestSellersEnabled;
  final bool bestSellersShowAll;
  final int bestSellerMinSoldUnits;
  final int bestSellersLimit;
  final BestSellerBasis bestSellerBasis;
  final String storeName;
  final String storeContactNumber;
  final String facebookMessengerUrl;
  final String supportContactUrl;
  final String logoReference;
  final String faviconReference;
  final List<String> serviceableBarangays;
  final bool useFlatDeliveryFee;
  final int flatDeliveryFee;
  final Map<String, int> deliveryFeesByBarangay;
  final int minimumDeliveryOrderAmount;
  final bool requirePlaceForDeliveryOnly;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AppSettings copyWith({
    int? id,
    bool? bestSellersEnabled,
    bool? bestSellersShowAll,
    int? bestSellerMinSoldUnits,
    int? bestSellersLimit,
    BestSellerBasis? bestSellerBasis,
    String? storeName,
    String? storeContactNumber,
    String? facebookMessengerUrl,
    String? supportContactUrl,
    String? logoReference,
    String? faviconReference,
    List<String>? serviceableBarangays,
    bool? useFlatDeliveryFee,
    int? flatDeliveryFee,
    Map<String, int>? deliveryFeesByBarangay,
    int? minimumDeliveryOrderAmount,
    bool? requirePlaceForDeliveryOnly,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppSettings(
      id: id ?? this.id,
      bestSellersEnabled: bestSellersEnabled ?? this.bestSellersEnabled,
      bestSellersShowAll: bestSellersShowAll ?? this.bestSellersShowAll,
      bestSellerMinSoldUnits:
          bestSellerMinSoldUnits ?? this.bestSellerMinSoldUnits,
      bestSellersLimit: bestSellersLimit ?? this.bestSellersLimit,
      bestSellerBasis: bestSellerBasis ?? this.bestSellerBasis,
      storeName: storeName ?? this.storeName,
      storeContactNumber: storeContactNumber ?? this.storeContactNumber,
      facebookMessengerUrl: facebookMessengerUrl ?? this.facebookMessengerUrl,
      supportContactUrl: supportContactUrl ?? this.supportContactUrl,
      logoReference: logoReference ?? this.logoReference,
      faviconReference: faviconReference ?? this.faviconReference,
      serviceableBarangays: serviceableBarangays ?? this.serviceableBarangays,
      useFlatDeliveryFee: useFlatDeliveryFee ?? this.useFlatDeliveryFee,
      flatDeliveryFee: flatDeliveryFee ?? this.flatDeliveryFee,
      deliveryFeesByBarangay:
          deliveryFeesByBarangay ?? this.deliveryFeesByBarangay,
      minimumDeliveryOrderAmount:
          minimumDeliveryOrderAmount ?? this.minimumDeliveryOrderAmount,
      requirePlaceForDeliveryOnly:
          requirePlaceForDeliveryOnly ?? this.requirePlaceForDeliveryOnly,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'bestSellersEnabled': bestSellersEnabled,
    'bestSellersShowAll': bestSellersShowAll,
    'bestSellerMinSoldUnits': bestSellerMinSoldUnits,
    'bestSellersLimit': bestSellersLimit,
    'bestSellerBasis': bestSellerBasis.name,
    'storeName': storeName,
    'storeContactNumber': storeContactNumber,
    'facebookMessengerUrl': facebookMessengerUrl,
    'supportContactUrl': supportContactUrl,
    'logoReference': logoReference,
    'faviconReference': faviconReference,
    'serviceableBarangays': serviceableBarangays,
    'useFlatDeliveryFee': useFlatDeliveryFee,
    'flatDeliveryFee': flatDeliveryFee,
    'deliveryFeesByBarangay': deliveryFeesByBarangay,
    'minimumDeliveryOrderAmount': minimumDeliveryOrderAmount,
    'requirePlaceForDeliveryOnly': requirePlaceForDeliveryOnly,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      id: map['id'] is int
          ? map['id'] as int
          : int.tryParse('${map['id']}') ?? 1,
      bestSellersEnabled: map['bestSellersEnabled'] as bool? ?? true,
      bestSellersShowAll: map['bestSellersShowAll'] as bool? ?? false,
      bestSellerMinSoldUnits: _parseInt(map['bestSellerMinSoldUnits']) == 0
          ? 1
          : _parseInt(map['bestSellerMinSoldUnits']),
      bestSellersLimit: _parseInt(map['bestSellersLimit']) == 0
          ? 6
          : _parseInt(map['bestSellersLimit']),
      bestSellerBasis: _parseBestSellerBasis(map['bestSellerBasis'] as String?),
      storeName: (map['storeName'] as String?)?.trim().isNotEmpty == true
          ? (map['storeName'] as String).trim()
          : "Andrew's Supermarket",
      storeContactNumber: (map['storeContactNumber'] as String? ?? '').trim(),
      facebookMessengerUrl: (map['facebookMessengerUrl'] as String? ?? '')
          .trim(),
      supportContactUrl: (map['supportContactUrl'] as String? ?? '').trim(),
      logoReference:
          (map['logoReference'] as String?)?.trim().isNotEmpty == true
          ? (map['logoReference'] as String).trim()
          : 'assets/branding/as_logo_dark.png',
      faviconReference:
          (map['faviconReference'] as String?)?.trim().isNotEmpty == true
          ? (map['faviconReference'] as String).trim()
          : 'assets/branding/as_logo_dark.png',
      serviceableBarangays:
          (map['serviceableBarangays'] as List<dynamic>?)
              ?.map((item) => '$item'.trim())
              .where((item) => item.isNotEmpty)
              .toList() ??
          const [],
      useFlatDeliveryFee: map['useFlatDeliveryFee'] as bool? ?? true,
      flatDeliveryFee: _parseInt(map['flatDeliveryFee']),
      deliveryFeesByBarangay:
          (map['deliveryFeesByBarangay'] as Map?)?.map(
            (key, value) => MapEntry('$key', _parseInt(value)),
          ) ??
          const {},
      minimumDeliveryOrderAmount: _parseInt(map['minimumDeliveryOrderAmount']),
      requirePlaceForDeliveryOnly:
          map['requirePlaceForDeliveryOnly'] as bool? ?? true,
      createdAt: map['createdAt'] == null
          ? null
          : DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] == null
          ? null
          : DateTime.parse(map['updatedAt'] as String),
    );
  }
}

enum BestSellerBasis { lifetime, recent30Days }

BestSellerBasis _parseBestSellerBasis(String? raw) {
  return switch (raw) {
    'recent30Days' => BestSellerBasis.recent30Days,
    _ => BestSellerBasis.lifetime,
  };
}

class AdminSession {
  const AdminSession({
    this.id = 1,
    required this.uid,
    required this.email,
    required this.displayName,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String uid;
  final String email;
  final String displayName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AdminSession copyWith({
    int? id,
    String? uid,
    String? email,
    String? displayName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AdminSession(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'uid': uid,
    'email': email,
    'name': displayName,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  factory AdminSession.fromMap(Map<String, dynamic> map) {
    return AdminSession(
      id: map['id'] is int
          ? map['id'] as int
          : int.tryParse('${map['id']}') ?? 1,
      uid: map['uid'] as String,
      email: map['email'] as String,
      displayName:
          (map['name'] as String?) ??
          (map['displayName'] as String?) ??
          '',
      createdAt: (map['created_at'] ?? map['createdAt']) == null
          ? null
          : DateTime.parse('${map['created_at'] ?? map['createdAt']}'),
      updatedAt: (map['updated_at'] ?? map['updatedAt']) == null
          ? null
          : DateTime.parse('${map['updated_at'] ?? map['updatedAt']}'),
    );
  }
}

class PersistedData {
  const PersistedData({
    this.id = 1,
    required this.categories,
    required this.barangays,
    required this.banners,
    required this.products,
    required this.orders,
    required this.settings,
    required this.cart,
    required this.customerDraft,
    this.adminSession,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final List<Category> categories;
  final List<Barangay> barangays;
  final List<AppBanner> banners;
  final List<Product> products;
  final List<OrderRequest> orders;
  final AppSettings settings;
  final List<CartItem> cart;
  final CustomerDraft customerDraft;
  final AdminSession? adminSession;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toMap() => {
    'id': id,
    'categories': categories.map((item) => item.toMap()).toList(),
    'barangays': barangays.map((item) => item.toMap()).toList(),
    'banners': banners.map((item) => item.toMap()).toList(),
    'products': products.map((item) => item.toMap()).toList(),
    'orders': orders.map((item) => item.toMap()).toList(),
    'settings': settings.toMap(),
    'cart': cart.map((item) => item.toMap()).toList(),
    'customerDraft': customerDraft.toMap(),
    'adminSession': adminSession?.toMap(),
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  String toJson() => jsonEncode(toMap());

  factory PersistedData.fromJson(String source) {
    final map = jsonDecode(source) as Map<String, dynamic>;
    return PersistedData(
      id: map['id'] is int
          ? map['id'] as int
          : int.tryParse('${map['id']}') ?? 1,
      categories: (map['categories'] as List<dynamic>)
          .map(
            (item) => Category.fromMap(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      barangays: ((map['barangays'] as List<dynamic>?) ?? const <dynamic>[])
          .map(
            (item) => Barangay.fromMap(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      banners: ((map['banners'] as List<dynamic>?) ?? const <dynamic>[])
          .map(
            (item) => AppBanner.fromMap(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      products: (map['products'] as List<dynamic>)
          .map(
            (item) => Product.fromMap(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      orders: (map['orders'] as List<dynamic>)
          .map(
            (item) =>
                OrderRequest.fromMap(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      settings: AppSettings.fromMap(
        Map<String, dynamic>.from(map['settings'] as Map),
      ),
      cart: (map['cart'] as List<dynamic>)
          .map(
            (item) => CartItem.fromMap(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      customerDraft: CustomerDraft.fromMap(
        Map<String, dynamic>.from(map['customerDraft'] as Map),
      ),
      adminSession: map['adminSession'] == null
          ? null
          : AdminSession.fromMap(
              Map<String, dynamic>.from(map['adminSession'] as Map),
            ),
      createdAt: map['createdAt'] == null
          ? null
          : DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] == null
          ? null
          : DateTime.parse(map['updatedAt'] as String),
    );
  }
}

const _sentinel = Object();
