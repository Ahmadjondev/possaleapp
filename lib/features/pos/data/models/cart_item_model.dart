import 'package:equatable/equatable.dart';
import 'product_model.dart';

class CartItemModel extends Equatable {
  final String cartKey;
  final int productId;
  final String name;
  final String code;
  final double priceUzs;
  final double priceUsd;
  final double originalPriceUzs;
  final double originalPriceUsd;
  final bool isPriceOverridden;
  final double costPriceUzs;
  final double quantity;
  final double maxQuantity;
  final double discountUzs;
  final String itemType; // product, part, measurable
  final String unitType; // pcs, kg, l, m, etc.
  final bool allowsDecimalQuantity;

  const CartItemModel({
    required this.cartKey,
    required this.productId,
    required this.name,
    this.code = '',
    required this.priceUzs,
    this.priceUsd = 0,
    required this.originalPriceUzs,
    this.originalPriceUsd = 0,
    this.isPriceOverridden = false,
    this.costPriceUzs = 0,
    this.quantity = 1,
    this.maxQuantity = 0,
    this.discountUzs = 0,
    this.itemType = 'product',
    this.unitType = 'pcs',
    this.allowsDecimalQuantity = false,
  });

  double get lineTotal => quantity * priceUzs - discountUzs;

  double get lineTotalUsd => quantity * priceUsd;

  double get profitMarginUzs => priceUzs - costPriceUzs;

  /// Create a cart item from a product (initial add).
  factory CartItemModel.fromProduct(ProductModel product) {
    return CartItemModel(
      cartKey: '${product.itemType}_${product.id}',
      productId: product.id,
      name: product.name,
      code: product.code,
      priceUzs: product.priceUzs,
      priceUsd: product.priceUsd,
      originalPriceUzs: product.priceUzs,
      originalPriceUsd: product.priceUsd,
      costPriceUzs: product.costPriceUzs,
      quantity: 1,
      maxQuantity: product.quantity,
      itemType: product.itemType,
      unitType: product.unitType,
      allowsDecimalQuantity: product.allowsDecimalQuantity,
    );
  }

  CartItemModel copyWith({
    double? priceUzs,
    double? priceUsd,
    bool? isPriceOverridden,
    double? quantity,
    double? discountUzs,
  }) {
    return CartItemModel(
      cartKey: cartKey,
      productId: productId,
      name: name,
      code: code,
      priceUzs: priceUzs ?? this.priceUzs,
      priceUsd: priceUsd ?? this.priceUsd,
      originalPriceUzs: originalPriceUzs,
      originalPriceUsd: originalPriceUsd,
      isPriceOverridden: isPriceOverridden ?? this.isPriceOverridden,
      costPriceUzs: costPriceUzs,
      quantity: quantity ?? this.quantity,
      maxQuantity: maxQuantity,
      discountUzs: discountUzs ?? this.discountUzs,
      itemType: itemType,
      unitType: unitType,
      allowsDecimalQuantity: allowsDecimalQuantity,
    );
  }

  /// Serialize for the quick-sale API (SaleWriteSerializer expects 'product').
  Map<String, dynamic> toSaleJson() => {
    'product': productId,
    'quantity': quantity,
    'unit_price_uzs': priceUzs,
    'unit_price_usd': priceUsd,
    'discount_uzs': discountUzs,
    'item_type': itemType,
  };

  /// Serialize for draft API (DraftSaveSerializer expects 'product_id').
  Map<String, dynamic> toCheckoutJson() => {
    'product_id': productId,
    'quantity': quantity,
    'unit_price_uzs': priceUzs,
    'unit_price_usd': priceUsd,
    'discount_uzs': discountUzs,
    'item_type': itemType,
  };

  @override
  List<Object?> get props => [cartKey, quantity, priceUzs, discountUzs];
}
