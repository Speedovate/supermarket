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
    required this.isArchived,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final String normalizedName;
  final bool isActive;
  final bool isArchived;
  final int sortOrder;

  Category copyWith({
    String? id,
    String? name,
    String? normalizedName,
    bool? isActive,
    bool? isArchived,
    int? sortOrder,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      normalizedName: normalizedName ?? this.normalizedName,
      isActive: isActive ?? this.isActive,
      isArchived: isArchived ?? this.isArchived,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'normalizedName': normalizedName,
    'isActive': isActive,
    'isArchived': isArchived,
    'sortOrder': sortOrder,
  };

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as String,
      name: map['name'] as String,
      normalizedName: map['normalizedName'] as String,
      isActive: map['isActive'] as bool,
      isArchived: map['isArchived'] as bool,
      sortOrder: map['sortOrder'] as int,
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
    required this.isArchived,
    required this.validOrderedQuantity,
    required this.validOrderCount,
    this.lastValidOrderAt,
  });

  final String id;
  final String name;
  final String? photoUrl;
  final String? photoStoragePath;
  final String categoryId;
  final String categoryNameSnapshot;
  final String quantity;
  final String unit;
  final String type;
  final int referencePriceCentavos;
  final DateTime priceUpdatedAt;
  final bool isActive;
  final bool isArchived;
  final int validOrderedQuantity;
  final int validOrderCount;
  final DateTime? lastValidOrderAt;

  String get normalizedName => name.trim().toLowerCase();

  String get displayUnit {
    final suffix = type.trim();
    final base = '${quantity.trim()}${unit.trim()}';
    return suffix.isEmpty ? base : '$base $suffix';
  }

  Product copyWith({
    String? id,
    String? name,
    Object? photoUrl = _sentinel,
    Object? photoStoragePath = _sentinel,
    String? categoryId,
    String? categoryNameSnapshot,
    String? quantity,
    String? unit,
    String? type,
    int? referencePriceCentavos,
    DateTime? priceUpdatedAt,
    bool? isActive,
    bool? isArchived,
    int? validOrderedQuantity,
    int? validOrderCount,
    Object? lastValidOrderAt = _sentinel,
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
      isArchived: isArchived ?? this.isArchived,
      validOrderedQuantity: validOrderedQuantity ?? this.validOrderedQuantity,
      validOrderCount: validOrderCount ?? this.validOrderCount,
      lastValidOrderAt: lastValidOrderAt == _sentinel
          ? this.lastValidOrderAt
          : lastValidOrderAt as DateTime?,
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
    'isArchived': isArchived,
    'validOrderedQuantity': validOrderedQuantity,
    'validOrderCount': validOrderCount,
    'lastValidOrderAt': lastValidOrderAt?.toIso8601String(),
  };

  factory Product.fromMap(Map<String, dynamic> map) {
    final parsedLegacyUnit = _parseLegacyMeasure(map['unit'] as String?);
    return Product(
      id: map['id'] as String,
      name: map['name'] as String,
      photoUrl: map['photoUrl'] as String?,
      photoStoragePath: map['photoStoragePath'] as String?,
      categoryId: map['categoryId'] as String,
      categoryNameSnapshot: map['categoryNameSnapshot'] as String,
      quantity:
          (map['quantity'] as String?)?.trim().isNotEmpty == true
              ? (map['quantity'] as String).trim()
              : parsedLegacyUnit.quantity,
      unit:
          (map['unit'] as String?)?.trim().isNotEmpty == true &&
              (map['quantity'] != null || map['type'] != null)
          ? (map['unit'] as String).trim()
          : parsedLegacyUnit.unit,
      type:
          (map['type'] as String?)?.trim().isNotEmpty == true
              ? (map['type'] as String).trim()
              : parsedLegacyUnit.type,
      referencePriceCentavos: map['referencePriceCentavos'] as int,
      priceUpdatedAt: map['priceUpdatedAt'] == null
          ? DateTime(2026, 7, 31)
          : DateTime.parse(map['priceUpdatedAt'] as String),
      isActive: map['isActive'] as bool,
      isArchived: map['isArchived'] as bool,
      validOrderedQuantity: map['validOrderedQuantity'] as int,
      validOrderCount: map['validOrderCount'] as int,
      lastValidOrderAt: map['lastValidOrderAt'] == null
          ? null
          : DateTime.parse(map['lastValidOrderAt'] as String),
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
  final match = RegExp(r'^(\d+(?:\.\d+)?)\s*([A-Za-z]+)\s*(.*)$').firstMatch(
    source,
  );
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
    required this.productId,
    required this.productName,
    required this.unit,
    required this.referenceUnitPriceCentavos,
    this.photoUrl,
    required this.quantity,
  });

  final String productId;
  final String productName;
  final String unit;
  final int referenceUnitPriceCentavos;
  final String? photoUrl;
  final int quantity;

  int get estimatedSubtotalCentavos => referenceUnitPriceCentavos * quantity;

  CartItem copyWith({
    String? productId,
    String? productName,
    String? unit,
    int? referenceUnitPriceCentavos,
    Object? photoUrl = _sentinel,
    int? quantity,
  }) {
    return CartItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      unit: unit ?? this.unit,
      referenceUnitPriceCentavos:
          referenceUnitPriceCentavos ?? this.referenceUnitPriceCentavos,
      photoUrl: photoUrl == _sentinel ? this.photoUrl : photoUrl as String?,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'productName': productName,
    'unit': unit,
    'referenceUnitPriceCentavos': referenceUnitPriceCentavos,
    'photoUrl': photoUrl,
    'quantity': quantity,
  };

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      productId: map['productId'] as String,
      productName: map['productName'] as String,
      unit: map['unit'] as String,
      referenceUnitPriceCentavos: map['referenceUnitPriceCentavos'] as int,
      photoUrl: map['photoUrl'] as String?,
      quantity: map['quantity'] as int,
    );
  }
}

class CustomerDraft {
  const CustomerDraft({
    this.name = '',
    this.mobileNumber = '',
    this.normalizedMobileNumber = '',
    this.barangay = '',
    this.addressLandmark = '',
    this.note = '',
    this.fulfillmentMethod = FulfillmentMethod.pickup,
  });

  final String name;
  final String mobileNumber;
  final String normalizedMobileNumber;
  final String barangay;
  final String addressLandmark;
  final String note;
  final FulfillmentMethod fulfillmentMethod;

  CustomerDraft copyWith({
    String? name,
    String? mobileNumber,
    String? normalizedMobileNumber,
    String? barangay,
    String? addressLandmark,
    String? note,
    FulfillmentMethod? fulfillmentMethod,
  }) {
    return CustomerDraft(
      name: name ?? this.name,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      normalizedMobileNumber:
          normalizedMobileNumber ?? this.normalizedMobileNumber,
      barangay: barangay ?? this.barangay,
      addressLandmark: addressLandmark ?? this.addressLandmark,
      note: note ?? this.note,
      fulfillmentMethod: fulfillmentMethod ?? this.fulfillmentMethod,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'mobileNumber': mobileNumber,
    'normalizedMobileNumber': normalizedMobileNumber,
    'barangay': fulfillmentMethod == FulfillmentMethod.delivery
        ? barangay
        : null,
    'addressLandmark': addressLandmark,
    'note': note,
    'fulfillmentMethod': fulfillmentMethod.name,
  };

  factory CustomerDraft.fromMap(Map<String, dynamic> map) {
    return CustomerDraft(
      name: map['name'] as String? ?? '',
      mobileNumber: map['mobileNumber'] as String? ?? '',
      normalizedMobileNumber: map['normalizedMobileNumber'] as String? ?? '',
      barangay: map['barangay'] as String? ?? '',
      addressLandmark: map['addressLandmark'] as String? ?? '',
      note: map['note'] as String? ?? '',
      fulfillmentMethod: FulfillmentMethod.values.byName(
        map['fulfillmentMethod'] as String? ?? FulfillmentMethod.pickup.name,
      ),
    );
  }
}

class OrderItemSubstitute {
  const OrderItemSubstitute({
    this.productName,
    this.unit,
    this.quantity,
    this.unitPriceCentavos,
  });

  final String? productName;
  final String? unit;
  final int? quantity;
  final int? unitPriceCentavos;

  OrderItemSubstitute copyWith({
    Object? productName = _sentinel,
    Object? unit = _sentinel,
    Object? quantity = _sentinel,
    Object? unitPriceCentavos = _sentinel,
  }) {
    return OrderItemSubstitute(
      productName: productName == _sentinel
          ? this.productName
          : productName as String?,
      unit: unit == _sentinel ? this.unit : unit as String?,
      quantity: quantity == _sentinel ? this.quantity : quantity as int?,
      unitPriceCentavos: unitPriceCentavos == _sentinel
          ? this.unitPriceCentavos
          : unitPriceCentavos as int?,
    );
  }

  Map<String, dynamic> toMap() => {
    'productName': productName,
    'unit': unit,
    'quantity': quantity,
    'unitPriceCentavos': unitPriceCentavos,
  };

  factory OrderItemSubstitute.fromMap(Map<String, dynamic> map) {
    return OrderItemSubstitute(
      productName: map['productName'] as String?,
      unit: map['unit'] as String?,
      quantity: map['quantity'] as int?,
      unitPriceCentavos: map['unitPriceCentavos'] as int?,
    );
  }
}

class OrderItem {
  const OrderItem({
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
  });

  final String productId;
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

  OrderItem copyWith({
    String? productId,
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
  }) {
    return OrderItem(
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
    );
  }

  Map<String, dynamic> toMap() => {
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
  };

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: map['productId'] as String,
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
    );
  }
}

class StatusHistoryEntry {
  const StatusHistoryEntry({
    required this.previousStatus,
    required this.newStatus,
    required this.timestamp,
    required this.adminUserId,
    this.note,
  });

  final OrderStatus previousStatus;
  final OrderStatus newStatus;
  final DateTime timestamp;
  final String adminUserId;
  final String? note;

  Map<String, dynamic> toMap() => {
    'previousStatus': previousStatus.name,
    'newStatus': newStatus.name,
    'timestamp': timestamp.toIso8601String(),
    'adminUserId': adminUserId,
    'note': note,
  };

  factory StatusHistoryEntry.fromMap(Map<String, dynamic> map) {
    return StatusHistoryEntry(
      previousStatus: OrderStatus.values.byName(
        map['previousStatus'] as String,
      ),
      newStatus: OrderStatus.values.byName(map['newStatus'] as String),
      timestamp: DateTime.parse(map['timestamp'] as String),
      adminUserId: map['adminUserId'] as String,
      note: map['note'] as String?,
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

  final String id;
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
    String? id,
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
      id: map['id'] as String,
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
    this.bestSellersEnabled = true,
    this.bestSellersLimit = 6,
  });

  final bool bestSellersEnabled;
  final int bestSellersLimit;

  AppSettings copyWith({bool? bestSellersEnabled, int? bestSellersLimit}) {
    return AppSettings(
      bestSellersEnabled: bestSellersEnabled ?? this.bestSellersEnabled,
      bestSellersLimit: bestSellersLimit ?? this.bestSellersLimit,
    );
  }

  Map<String, dynamic> toMap() => {
    'bestSellersEnabled': bestSellersEnabled,
    'bestSellersLimit': bestSellersLimit,
  };

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      bestSellersEnabled: map['bestSellersEnabled'] as bool? ?? true,
      bestSellersLimit: map['bestSellersLimit'] as int? ?? 6,
    );
  }
}

class AdminSession {
  const AdminSession({
    required this.uid,
    required this.email,
    required this.displayName,
  });

  final String uid;
  final String email;
  final String displayName;

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'email': email,
    'displayName': displayName,
  };

  factory AdminSession.fromMap(Map<String, dynamic> map) {
    return AdminSession(
      uid: map['uid'] as String,
      email: map['email'] as String,
      displayName: map['displayName'] as String,
    );
  }
}

class PersistedData {
  const PersistedData({
    required this.categories,
    required this.products,
    required this.orders,
    required this.settings,
    required this.cart,
    required this.customerDraft,
  });

  final List<Category> categories;
  final List<Product> products;
  final List<OrderRequest> orders;
  final AppSettings settings;
  final List<CartItem> cart;
  final CustomerDraft customerDraft;

  Map<String, dynamic> toMap() => {
    'categories': categories.map((item) => item.toMap()).toList(),
    'products': products.map((item) => item.toMap()).toList(),
    'orders': orders.map((item) => item.toMap()).toList(),
    'settings': settings.toMap(),
    'cart': cart.map((item) => item.toMap()).toList(),
    'customerDraft': customerDraft.toMap(),
  };

  String toJson() => jsonEncode(toMap());

  factory PersistedData.fromJson(String source) {
    final map = jsonDecode(source) as Map<String, dynamic>;
    return PersistedData(
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
    );
  }
}

const _sentinel = Object();
