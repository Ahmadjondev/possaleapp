import 'package:equatable/equatable.dart';
import 'package:pos_terminal/features/pos/data/models/parse_helpers.dart';

class ProductModel extends Equatable {
  final int id;
  final String name;
  final String code;
  final String? oemNumber;
  final int? categoryId;
  final String? categoryName;
  final String unitType; // pcs, kg, g, l, m, set
  final double priceUzs;
  final double priceUsd;
  final double costPriceUzs;
  final double costPriceUsd;
  final double quantity; // stock available
  final String itemType; // product, part, measurable
  final bool allowsDecimalQuantity;
  final String? barcode;
  final String? imageUrl;

  const ProductModel({
    required this.id,
    required this.name,
    this.code = '',
    this.oemNumber,
    this.categoryId,
    this.categoryName,
    this.unitType = 'pcs',
    this.priceUzs = 0,
    this.priceUsd = 0,
    this.costPriceUzs = 0,
    this.costPriceUsd = 0,
    this.quantity = 0,
    this.itemType = 'product',
    this.allowsDecimalQuantity = false,
    this.barcode,
    this.imageUrl,
  });

  bool get inStock => quantity > 0;

  double get profitMarginUzs => priceUzs - costPriceUzs;

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final unitType = json['unit_type'] as String? ?? 'pcs';
    final itemType = json['item_type'] as String? ?? 'product';
    final allowsDecimal =
        json['allows_decimal_quantity'] as bool? ??
        const ['kg', 'g', 'l', 'm'].contains(unitType) ||
            itemType == 'measurable';

    // barcodes can be a list of strings or a single string
    final barcodes = json['barcodes'];
    String? barcode;
    if (barcodes is List && barcodes.isNotEmpty) {
      barcode = barcodes.first.toString();
    } else if (json['barcode'] is String) {
      barcode = json['barcode'] as String;
    }

    return ProductModel(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      oemNumber: json['oem_number'] as String?,
      categoryId:
          (json['category_id'] as num?)?.toInt() ??
          (json['category'] is Map
              ? (json['category']['id'] as num?)?.toInt()
              : (json['category'] as num?)?.toInt()),
      categoryName: json['category'] is Map
          ? json['category']['name'] as String?
          : json['category_name'] as String?,
      unitType: unitType,
      priceUzs: parseDouble(json['price_uzs']),
      priceUsd: parseDouble(json['price_usd']),
      costPriceUzs: parseDouble(json['cost_price_uzs']),
      costPriceUsd: parseDouble(json['cost_price_usd']),
      quantity: parseDouble(
        json['stock_quantity'] ?? json['quantity'] ?? json['stock'],
      ),
      itemType: itemType,
      allowsDecimalQuantity: allowsDecimal,
      barcode: barcode,
      imageUrl: json['image'] as String? ?? json['image_url'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, itemType];
}
