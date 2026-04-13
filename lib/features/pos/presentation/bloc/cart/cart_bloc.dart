import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_terminal/features/pos/data/models/cart_item_model.dart';

import 'cart_event.dart';
import 'cart_state.dart';

class CartBloc extends Bloc<CartEvent, CartState> {
  CartBloc() : super(const CartState()) {
    on<CartItemAdded>(_onItemAdded);
    on<CartItemAddedWithQuantity>(_onItemAddedWithQuantity);
    on<CartItemRemoved>(_onItemRemoved);
    on<CartQuantityUpdated>(_onQuantityUpdated);
    on<CartItemDiscountUpdated>(_onItemDiscountUpdated);
    on<CartItemPriceUpdated>(_onItemPriceUpdated);
    on<CartItemPriceReset>(_onItemPriceReset);
    on<CartCleared>(_onCleared);
    on<CartItemReordered>(_onItemReordered);
    on<CartDraftLoaded>(_onDraftLoaded);
  }

  void _onItemAdded(CartItemAdded event, Emitter<CartState> emit) {
    final product = event.product;
    if (product.quantity <= 0) return; // Out of stock

    final items = List<CartItemModel>.from(state.items);
    final cartKey = '${product.itemType}_${product.id}';
    final existingIndex = items.indexWhere((i) => i.cartKey == cartKey);

    if (existingIndex >= 0) {
      // Merge: increment quantity up to max
      final existing = items[existingIndex];
      final newQty = existing.quantity + 1;
      if (newQty > existing.maxQuantity && existing.maxQuantity > 0) return;
      items[existingIndex] = existing.copyWith(quantity: newQty);
    } else {
      items.add(CartItemModel.fromProduct(product));
    }

    emit(state.copyWith(items: items));
  }

  void _onItemAddedWithQuantity(
    CartItemAddedWithQuantity event,
    Emitter<CartState> emit,
  ) {
    final product = event.product;
    if (product.quantity <= 0) return;

    final items = List<CartItemModel>.from(state.items);
    final cartKey = '${product.itemType}_${product.id}';
    final existingIndex = items.indexWhere((i) => i.cartKey == cartKey);

    var qty = event.quantity;
    if (existingIndex >= 0) {
      final existing = items[existingIndex];
      qty += existing.quantity;
      if (existing.maxQuantity > 0 && qty > existing.maxQuantity) {
        qty = existing.maxQuantity;
      }
      items[existingIndex] = existing.copyWith(quantity: qty);
    } else {
      final item = CartItemModel.fromProduct(product);
      if (item.maxQuantity > 0 && qty > item.maxQuantity) {
        qty = item.maxQuantity;
      }
      items.add(item.copyWith(quantity: qty));
    }

    emit(state.copyWith(items: items));
  }

  void _onItemRemoved(CartItemRemoved event, Emitter<CartState> emit) {
    final items = state.items.where((i) => i.cartKey != event.cartKey).toList();
    emit(state.copyWith(items: items));
  }

  void _onQuantityUpdated(CartQuantityUpdated event, Emitter<CartState> emit) {
    final items = List<CartItemModel>.from(state.items);
    final index = items.indexWhere((i) => i.cartKey == event.cartKey);
    if (index < 0) return;

    final item = items[index];
    var qty = event.quantity;

    // Enforce limits
    if (qty <= 0) {
      items.removeAt(index);
    } else {
      if (item.maxQuantity > 0 && qty > item.maxQuantity) {
        qty = item.maxQuantity;
      }
      // Enforce integer for non-decimal items
      if (!item.allowsDecimalQuantity) qty = qty.roundToDouble();
      items[index] = item.copyWith(quantity: qty);
    }

    emit(state.copyWith(items: items));
  }

  void _onItemDiscountUpdated(
    CartItemDiscountUpdated event,
    Emitter<CartState> emit,
  ) {
    final items = List<CartItemModel>.from(state.items);
    final index = items.indexWhere((i) => i.cartKey == event.cartKey);
    if (index < 0) return;

    items[index] = items[index].copyWith(discountUzs: event.discountUzs);
    emit(state.copyWith(items: items));
  }

  void _onItemPriceUpdated(
    CartItemPriceUpdated event,
    Emitter<CartState> emit,
  ) {
    final items = List<CartItemModel>.from(state.items);
    final index = items.indexWhere((i) => i.cartKey == event.cartKey);
    if (index < 0) return;

    items[index] = items[index].copyWith(
      priceUzs: event.newPriceUzs,
      isPriceOverridden: true,
    );
    emit(state.copyWith(items: items));
  }

  void _onItemPriceReset(CartItemPriceReset event, Emitter<CartState> emit) {
    final items = List<CartItemModel>.from(state.items);
    final index = items.indexWhere((i) => i.cartKey == event.cartKey);
    if (index < 0) return;

    final item = items[index];
    items[index] = item.copyWith(
      priceUzs: item.originalPriceUzs,
      isPriceOverridden: false,
    );
    emit(state.copyWith(items: items));
  }

  void _onCleared(CartCleared event, Emitter<CartState> emit) {
    emit(const CartState());
  }

  void _onItemReordered(CartItemReordered event, Emitter<CartState> emit) {
    final items = List<CartItemModel>.from(state.items);
    var newIndex = event.newIndex;
    if (newIndex > event.oldIndex) newIndex--;
    final item = items.removeAt(event.oldIndex);
    items.insert(newIndex, item);
    emit(state.copyWith(items: items));
  }

  void _onDraftLoaded(CartDraftLoaded event, Emitter<CartState> emit) {
    emit(CartState(items: event.items));
  }
}
