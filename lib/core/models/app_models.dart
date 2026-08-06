import 'dart:convert';

enum FulfillmentMethod { pickup, delivery }

enum OrderStatus {
  newRequest,
  underReview,
  awaitingCustomerConfirmation,
  confirmed,
  preparing,
  readyForPickup,
  outForDelivery,
  completed,
  cancelled,
  rejected,
}

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
    required this.name,
    this.photoUrl,
    this.photoStoragePath,
    required this.categoryId,
    required this.categoryNameSnapshot,
    required this.quantity,
    required this.unit,
    this.type = '',
    required this.referencePriceCentavos,
    required this.priceUpdatedAt,
    required this.isActive,
    required this.validOrderedQuantity,
    required this.validOrderCount,
    this.lastValidOrderAt,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String name;
  final String? photoUrl;
  final String? photoStoragePath;
  final int categoryId;
  final String categoryNameSnapshot;
  final String quantity;
  final String unit;
  final String type;
  final int referencePriceCentavos;
  final DateTime priceUpdatedAt;
  final bool isActive;
  final int validOrderedQuantity;
  final int validOrderCount;
  final DateTime? lastValidOrderAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get normalizedName => name.trim().toLowerCase();

  String get displayUnit {
    final suffix = type.trim();
    final base = '${quantity.trim()}${unit.trim()}';
    return suffix.isEmpty ? base : '$base $suffix';
  }

  Product copyWith({
    int? id,
    String? name,
    Object? photoUrl = _sentinel,
    Object? photoStoragePath = _sentinel,
    int? categoryId,
    String? categoryNameSnapshot,
    String? quantity,
    String? unit,
    String? type,
    int? referencePriceCentavos,
    DateTime? priceUpdatedAt,
    bool? isActive,
    int? validOrderedQuantity,
    int? validOrderCount,
    Object? lastValidOrderAt = _sentinel,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      photoUrl: photoUrl == _sentinel ? this.photoUrl : photoUrl as String?,
      photoStoragePath: photoStoragePath == _sentinel
          ? this.photoStoragePath
          : photoStoragePath as String?,
      categoryId: categoryId ?? this.categoryId,
      categoryNameSnapshot: categoryNameSnapshot ?? this.categoryNameSnapshot,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      type: type ?? this.type,
      referencePriceCentavos:
          referencePriceCentavos ?? this.referencePriceCentavos,
      priceUpdatedAt: priceUpdatedAt ?? this.priceUpdatedAt,
      isActive: isActive ?? this.isActive,
      validOrderedQuantity: validOrderedQuantity ?? this.validOrderedQuantity,
      validOrderCount: validOrderCount ?? this.validOrderCount,
      lastValidOrderAt: lastValidOrderAt == _sentinel
          ? this.lastValidOrderAt
          : lastValidOrderAt as DateTime?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'normalizedName': normalizedName,
    'photoUrl': photoUrl,
    'photoStoragePath': photoStoragePath,
    'categoryId': categoryId,
    'categoryNameSnapshot': categoryNameSnapshot,
    'quantity': quantity,
    'unit': unit,
    'type': type,
    'displayUnit': displayUnit,
    'referencePriceCentavos': referencePriceCentavos,
    'priceUpdatedAt': priceUpdatedAt.toIso8601String(),
    'isActive': isActive,
    'validOrderedQuantity': validOrderedQuantity,
    'validOrderCount': validOrderCount,
    'lastValidOrderAt': lastValidOrderAt?.toIso8601String(),
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory Product.fromMap(Map<String, dynamic> map) {
    final parsedLegacyUnit = _parseLegacyMeasure(map['unit'] as String?);
    return Product(
      id: map['id'] is int
          ? map['id'] as int
          : int.tryParse('${map['id']}') ?? 0,
      name: map['name'] as String,
      photoUrl: map['photoUrl'] as String?,
      photoStoragePath: map['photoStoragePath'] as String?,
      categoryId: map['categoryId'] is int
          ? map['categoryId'] as int
          : int.tryParse('${map['categoryId']}') ?? 0,
      categoryNameSnapshot: map['categoryNameSnapshot'] as String,
      quantity: (map['quantity'] as String?)?.trim().isNotEmpty == true
          ? (map['quantity'] as String).trim()
          : parsedLegacyUnit.quantity,
      unit:
          (map['unit'] as String?)?.trim().isNotEmpty == true &&
              (map['quantity'] != null || map['type'] != null)
          ? (map['unit'] as String).trim()
          : parsedLegacyUnit.unit,
      type: (map['type'] as String?)?.trim().isNotEmpty == true
          ? (map['type'] as String).trim()
          : parsedLegacyUnit.type,
      referencePriceCentavos: map['referencePriceCentavos'] as int,
      priceUpdatedAt: map['priceUpdatedAt'] == null
          ? DateTime(2026, 7, 31)
          : DateTime.parse(map['priceUpdatedAt'] as String),
      isActive: map['isActive'] as bool,
      validOrderedQuantity: map['validOrderedQuantity'] as int,
      validOrderCount: map['validOrderCount'] as int,
      lastValidOrderAt: map['lastValidOrderAt'] == null
          ? null
          : DateTime.parse(map['lastValidOrderAt'] as String),
      createdAt: map['createdAt'] == null
          ? null
          : DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] == null
          ? null
          : DateTime.parse(map['updatedAt'] as String),
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
      addressLandmark: map['addressLandmark'] as String? ?? '',
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

class StatusHistoryEntry {
  const StatusHistoryEntry({
    required this.id,
    required this.previousStatus,
    required this.newStatus,
    required this.timestamp,
    required this.adminUserId,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final OrderStatus previousStatus;
  final OrderStatus newStatus;
  final DateTime timestamp;
  final String adminUserId;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toMap() => {
    'id': id,
    'previousStatus': previousStatus.name,
    'newStatus': newStatus.name,
    'timestamp': timestamp.toIso8601String(),
    'adminUserId': adminUserId,
    'note': note,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory StatusHistoryEntry.fromMap(Map<String, dynamic> map) {
    return StatusHistoryEntry(
      id: map['id'] is int
          ? map['id'] as int
          : int.tryParse('${map['id']}') ?? 0,
      previousStatus: OrderStatus.values.byName(
        map['previousStatus'] as String,
      ),
      newStatus: OrderStatus.values.byName(map['newStatus'] as String),
      timestamp: DateTime.parse(map['timestamp'] as String),
      adminUserId: map['adminUserId'] as String,
      note: map['note'] as String?,
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
    required this.referenceNumber,
    required this.customer,
    required this.items,
    required this.estimatedTotalCentavos,
    required this.fulfillmentMethod,
    required this.deliveryFeeCentavos,
    required this.discountCentavos,
    required this.manualAdjustmentCentavos,
    required this.finalQuotedTotalCentavos,
    this.quotationNote,
    this.internalAdminNote,
    required this.status,
    required this.customerConfirmation,
    this.cancellationReason,
    this.rejectionReason,
    required this.bestSellerMetricsApplied,
    required this.createdAt,
    required this.updatedAt,
    this.createdByAdminId,
    this.updatedByAdminId,
    required this.statusHistory,
  });

  final int id;
  final String referenceNumber;
  final CustomerDraft customer;
  final List<OrderItem> items;
  final int estimatedTotalCentavos;
  final FulfillmentMethod fulfillmentMethod;
  final int deliveryFeeCentavos;
  final int discountCentavos;
  final int manualAdjustmentCentavos;
  final int finalQuotedTotalCentavos;
  final String? quotationNote;
  final String? internalAdminNote;
  final OrderStatus status;
  final CustomerConfirmationStatus customerConfirmation;
  final String? cancellationReason;
  final String? rejectionReason;
  final bool bestSellerMetricsApplied;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdByAdminId;
  final String? updatedByAdminId;
  final List<StatusHistoryEntry> statusHistory;

  OrderRequest copyWith({
    int? id,
    String? referenceNumber,
    CustomerDraft? customer,
    List<OrderItem>? items,
    int? estimatedTotalCentavos,
    FulfillmentMethod? fulfillmentMethod,
    int? deliveryFeeCentavos,
    int? discountCentavos,
    int? manualAdjustmentCentavos,
    int? finalQuotedTotalCentavos,
    Object? quotationNote = _sentinel,
    Object? internalAdminNote = _sentinel,
    OrderStatus? status,
    CustomerConfirmationStatus? customerConfirmation,
    Object? cancellationReason = _sentinel,
    Object? rejectionReason = _sentinel,
    bool? bestSellerMetricsApplied,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? createdByAdminId = _sentinel,
    Object? updatedByAdminId = _sentinel,
    List<StatusHistoryEntry>? statusHistory,
  }) {
    return OrderRequest(
      id: id ?? this.id,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      customer: customer ?? this.customer,
      items: items ?? this.items,
      estimatedTotalCentavos:
          estimatedTotalCentavos ?? this.estimatedTotalCentavos,
      fulfillmentMethod: fulfillmentMethod ?? this.fulfillmentMethod,
      deliveryFeeCentavos: deliveryFeeCentavos ?? this.deliveryFeeCentavos,
      discountCentavos: discountCentavos ?? this.discountCentavos,
      manualAdjustmentCentavos:
          manualAdjustmentCentavos ?? this.manualAdjustmentCentavos,
      finalQuotedTotalCentavos:
          finalQuotedTotalCentavos ?? this.finalQuotedTotalCentavos,
      quotationNote: quotationNote == _sentinel
          ? this.quotationNote
          : quotationNote as String?,
      internalAdminNote: internalAdminNote == _sentinel
          ? this.internalAdminNote
          : internalAdminNote as String?,
      status: status ?? this.status,
      customerConfirmation: customerConfirmation ?? this.customerConfirmation,
      cancellationReason: cancellationReason == _sentinel
          ? this.cancellationReason
          : cancellationReason as String?,
      rejectionReason: rejectionReason == _sentinel
          ? this.rejectionReason
          : rejectionReason as String?,
      bestSellerMetricsApplied:
          bestSellerMetricsApplied ?? this.bestSellerMetricsApplied,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdByAdminId: createdByAdminId == _sentinel
          ? this.createdByAdminId
          : createdByAdminId as String?,
      updatedByAdminId: updatedByAdminId == _sentinel
          ? this.updatedByAdminId
          : updatedByAdminId as String?,
      statusHistory: statusHistory ?? this.statusHistory,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'referenceNumber': referenceNumber,
    'customer': customer.toMap(),
    'items': items.map((item) => item.toMap()).toList(),
    'estimatedTotalCentavos': estimatedTotalCentavos,
    'fulfillmentMethod': fulfillmentMethod.name,
    'deliveryFeeCentavos': deliveryFeeCentavos,
    'discountCentavos': discountCentavos,
    'manualAdjustmentCentavos': manualAdjustmentCentavos,
    'finalQuotedTotalCentavos': finalQuotedTotalCentavos,
    'quotationNote': quotationNote,
    'internalAdminNote': internalAdminNote,
    'status': status.name,
    'customerConfirmation': customerConfirmation.name,
    'cancellationReason': cancellationReason,
    'rejectionReason': rejectionReason,
    'bestSellerMetricsApplied': bestSellerMetricsApplied,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'createdByAdminId': createdByAdminId,
    'updatedByAdminId': updatedByAdminId,
    'statusHistory': statusHistory.map((entry) => entry.toMap()).toList(),
  };

  factory OrderRequest.fromMap(Map<String, dynamic> map) {
    return OrderRequest(
      id: map['id'] is int
          ? map['id'] as int
          : int.tryParse('${map['id']}') ?? 0,
      referenceNumber: map['referenceNumber'] as String,
      customer: CustomerDraft.fromMap(
        Map<String, dynamic>.from(map['customer'] as Map),
      ),
      items: (map['items'] as List<dynamic>)
          .map(
            (item) => OrderItem.fromMap(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      estimatedTotalCentavos: map['estimatedTotalCentavos'] as int,
      fulfillmentMethod: FulfillmentMethod.values.byName(
        map['fulfillmentMethod'] as String,
      ),
      deliveryFeeCentavos: map['deliveryFeeCentavos'] as int? ?? 0,
      discountCentavos: map['discountCentavos'] as int? ?? 0,
      manualAdjustmentCentavos: map['manualAdjustmentCentavos'] as int? ?? 0,
      finalQuotedTotalCentavos: map['finalQuotedTotalCentavos'] as int? ?? 0,
      quotationNote: map['quotationNote'] as String?,
      internalAdminNote: map['internalAdminNote'] as String?,
      status: OrderStatus.values.byName(map['status'] as String),
      customerConfirmation: CustomerConfirmationStatus.values.byName(
        map['customerConfirmation'] as String? ??
            CustomerConfirmationStatus.pending.name,
      ),
      cancellationReason: map['cancellationReason'] as String?,
      rejectionReason: map['rejectionReason'] as String?,
      bestSellerMetricsApplied:
          map['bestSellerMetricsApplied'] as bool? ?? false,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      createdByAdminId: map['createdByAdminId'] as String?,
      updatedByAdminId: map['updatedByAdminId'] as String?,
      statusHistory: (map['statusHistory'] as List<dynamic>? ?? [])
          .map(
            (entry) => StatusHistoryEntry.fromMap(
              Map<String, dynamic>.from(entry as Map),
            ),
          )
          .toList(),
    );
  }
}

class AppSettings {
  const AppSettings({
    this.id = 1,
    this.bestSellersEnabled = true,
    this.bestSellersLimit = 6,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final bool bestSellersEnabled;
  final int bestSellersLimit;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AppSettings copyWith({
    int? id,
    bool? bestSellersEnabled,
    int? bestSellersLimit,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppSettings(
      id: id ?? this.id,
      bestSellersEnabled: bestSellersEnabled ?? this.bestSellersEnabled,
      bestSellersLimit: bestSellersLimit ?? this.bestSellersLimit,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'bestSellersEnabled': bestSellersEnabled,
    'bestSellersLimit': bestSellersLimit,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      id: map['id'] is int
          ? map['id'] as int
          : int.tryParse('${map['id']}') ?? 1,
      bestSellersEnabled: map['bestSellersEnabled'] as bool? ?? true,
      bestSellersLimit: map['bestSellersLimit'] as int? ?? 6,
      createdAt: map['createdAt'] == null
          ? null
          : DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] == null
          ? null
          : DateTime.parse(map['updatedAt'] as String),
    );
  }
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

  Map<String, dynamic> toMap() => {
    'id': id,
    'uid': uid,
    'email': email,
    'displayName': displayName,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory AdminSession.fromMap(Map<String, dynamic> map) {
    return AdminSession(
      id: map['id'] is int
          ? map['id'] as int
          : int.tryParse('${map['id']}') ?? 1,
      uid: map['uid'] as String,
      email: map['email'] as String,
      displayName: map['displayName'] as String,
      createdAt: map['createdAt'] == null
          ? null
          : DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] == null
          ? null
          : DateTime.parse(map['updatedAt'] as String),
    );
  }
}

class PersistedData {
  const PersistedData({
    this.id = 1,
    required this.categories,
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
