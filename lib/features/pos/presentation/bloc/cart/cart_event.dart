import 'package:equatable/equatable.dart';
import 'package:pos_terminal/features/pos/data/models/cart_item_model.dart';
import 'package:pos_terminal/features/pos/data/models/product_model.dart';

sealed class CartEvent extends Equatable {
  const CartEvent();

  @override
  List<Object?> get props => [];
}

/// Add a product to the cart (or increment if already present).
class CartItemAdded extends CartEvent {
  final ProductModel product;

  const CartItemAdded({required this.product});

  @override
  List<Object?> get props => [product];
}

/// Add a product with a specific quantity (from quantity dialog).
class CartItemAddedWithQuantity extends CartEvent {
  final ProductModel product;
  final double quantity;

  const CartItemAddedWithQuantity({
    required this.product,
    required this.quantity,
  });

  @override
  List<Object?> get props => [product, quantity];
}

/// Remove a cart item by its key.
class CartItemRemoved extends CartEvent {
  final String cartKey;

  const CartItemRemoved({required this.cartKey});

  @override
  List<Object?> get props => [cartKey];
}

/// Update quantity for a cart item.
class CartQuantityUpdated extends CartEvent {
  final String cartKey;
  final double quantity;

  const CartQuantityUpdated({required this.cartKey, required this.quantity});

  @override
  List<Object?> get props => [cartKey, quantity];
}

/// Update discount for a specific cart item.
class CartItemDiscountUpdated extends CartEvent {
  final String cartKey;
  final double discountUzs;

  const CartItemDiscountUpdated({
    required this.cartKey,
    required this.discountUzs,
  });

  @override
  List<Object?> get props => [cartKey, discountUzs];
}

/// Override unit price for a cart item.
class CartItemPriceUpdated extends CartEvent {
  final String cartKey;
  final double newPriceUzs;

  const CartItemPriceUpdated({
    required this.cartKey,
    required this.newPriceUzs,
  });

  @override
  List<Object?> get props => [cartKey, newPriceUzs];
}

/// Reset overridden price back to original.
class CartItemPriceReset extends CartEvent {
  final String cartKey;

  const CartItemPriceReset({required this.cartKey});

  @override
  List<Object?> get props => [cartKey];
}

/// Clear the entire cart.
class CartCleared extends CartEvent {
  const CartCleared();
}

/// Reorder cart items (drag & drop).
class CartItemReordered extends CartEvent {
  final int oldIndex;
  final int newIndex;

  const CartItemReordered({required this.oldIndex, required this.newIndex});

  @override
  List<Object?> get props => [oldIndex, newIndex];
}

/// Load cart items from a draft.
class CartDraftLoaded extends CartEvent {
  final List<CartItemModel> items;

  const CartDraftLoaded({required this.items});

  @override
  List<Object?> get props => [items];
}
