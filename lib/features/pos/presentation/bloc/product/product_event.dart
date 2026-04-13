import 'package:equatable/equatable.dart';

sealed class ProductEvent extends Equatable {
  const ProductEvent();

  @override
  List<Object?> get props => [];
}

/// Search products by text query.
class ProductSearchRequested extends ProductEvent {
  final String query;

  const ProductSearchRequested({required this.query});

  @override
  List<Object?> get props => [query];
}

/// Filter products by category.
class ProductCategoryChanged extends ProductEvent {
  final int? categoryId;

  const ProductCategoryChanged({this.categoryId});

  @override
  List<Object?> get props => [categoryId];
}

/// Barcode scanned — look up single product.
class ProductBarcodeScanned extends ProductEvent {
  final String barcode;

  const ProductBarcodeScanned({required this.barcode});

  @override
  List<Object?> get props => [barcode];
}

/// Set the warehouse for product queries.
class ProductWarehouseChanged extends ProductEvent {
  final int warehouseId;

  const ProductWarehouseChanged({required this.warehouseId});

  @override
  List<Object?> get props => [warehouseId];
}

/// Load initial products on screen open.
class ProductsLoadRequested extends ProductEvent {
  const ProductsLoadRequested();
}
