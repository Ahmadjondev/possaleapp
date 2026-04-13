import 'package:pos_terminal/features/pos/data/models/cart_item_model.dart';
import 'package:pos_terminal/features/pos/data/models/parse_helpers.dart';

class DraftModel {
  final int id;
  final List<DraftItemModel> items;
  final int? customerId;
  final String? customerName;
  final String? discountType;
  final double discountValue;
  final String? note;
  final String? createdAt;
  final double totalUzs;
  final int itemCount;
  final String? saleNumber;

  const DraftModel({
    required this.id,
    this.items = const [],
    this.customerId,
    this.customerName,
    this.discountType,
    this.discountValue = 0,
    this.note,
    this.createdAt,
    this.totalUzs = 0,
    this.itemCount = 0,
    this.saleNumber,
  });

  factory DraftModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map
        ? json['data'] as Map<String, dynamic>
        : json;
    return DraftModel(
      id: (data['id'] as num).toInt(),
      items:
          (data['items'] as List<dynamic>?)
              ?.map((e) => DraftItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      customerId:
          (data['customer_id'] as num?)?.toInt() ??
          (data['customer'] as num?)?.toInt(),
      customerName: data['customer_name'] as String?,
      discountType: data['discount_type'] as String?,
      discountValue: parseDouble(data['discount_value']),
      note: data['note'] as String?,
      createdAt: data['created_at'] as String? ?? '',
      totalUzs: parseDouble(data['total_uzs']),
      itemCount: (data['item_count'] as num?)?.toInt() ?? 0,
      saleNumber: data['sale_number'] as String?,
    );
  }
}

class DraftItemModel {
  final int productId;
  final String name;
  final String code;
  final double quantity;
  final double priceUzs;
  final double priceUsd;
  final double costPriceUzs;
  final double maxQuantity;
  final double discountUzs;
  final String itemType;
  final String unitType;
  final bool allowsDecimalQuantity;

  const DraftItemModel({
    required this.productId,
    this.name = '',
    this.code = '',
    this.quantity = 1,
    this.priceUzs = 0,
    this.priceUsd = 0,
    this.costPriceUzs = 0,
    this.maxQuantity = 0,
    this.discountUzs = 0,
    this.itemType = 'product',
    this.unitType = 'pcs',
    this.allowsDecimalQuantity = false,
  });

  factory DraftItemModel.fromJson(Map<String, dynamic> json) {
    return DraftItemModel(
      productId:
          (json['product_id'] as num?)?.toInt() ??
          (json['product'] as num?)?.toInt() ??
          0,
      name: json['name'] as String? ?? json['product_name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      quantity: parseDouble(json['quantity'], 1),
      priceUzs: parseDouble(json['price_uzs'] ?? json['unit_price_uzs']),
      priceUsd: parseDouble(json['price_usd'] ?? json['unit_price_usd']),
      costPriceUzs: parseDouble(json['cost_price_uzs']),
      maxQuantity: parseDouble(json['max_quantity'] ?? json['stock']),
      discountUzs: parseDouble(json['discount_uzs']),
      itemType: json['item_type'] as String? ?? 'product',
      unitType: json['unit_type'] as String? ?? 'pcs',
      allowsDecimalQuantity: json['allows_decimal_quantity'] as bool? ?? false,
    );
  }

  CartItemModel toCartItem() {
    return CartItemModel(
      cartKey: '${itemType}_$productId',
      productId: productId,
      name: name,
      code: code,
      priceUzs: priceUzs,
      priceUsd: priceUsd,
      originalPriceUzs: priceUzs,
      originalPriceUsd: priceUsd,
      costPriceUzs: costPriceUzs,
      quantity: quantity,
      maxQuantity: maxQuantity,
      discountUzs: discountUzs,
      itemType: itemType,
      unitType: unitType,
      allowsDecimalQuantity: allowsDecimalQuantity,
    );
  }
}
