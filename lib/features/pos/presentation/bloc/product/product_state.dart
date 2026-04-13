import 'package:equatable/equatable.dart';
import 'package:pos_terminal/features/pos/data/models/product_model.dart';

sealed class ProductState extends Equatable {
  const ProductState();

  @override
  List<Object?> get props => [];
}

class ProductInitial extends ProductState {
  const ProductInitial();
}

class ProductLoading extends ProductState {
  const ProductLoading();
}

class ProductLoaded extends ProductState {
  final List<ProductModel> products;
  final String query;
  final int? categoryId;

  const ProductLoaded({
    required this.products,
    this.query = '',
    this.categoryId,
  });

  @override
  List<Object?> get props => [products, query, categoryId];
}

/// A single product found via barcode scan — auto-add to cart.
class ProductScanned extends ProductState {
  final ProductModel product;

  const ProductScanned({required this.product});

  @override
  List<Object?> get props => [product];
}

class ProductError extends ProductState {
  final String message;

  const ProductError({required this.message});

  @override
  List<Object?> get props => [message];
}
