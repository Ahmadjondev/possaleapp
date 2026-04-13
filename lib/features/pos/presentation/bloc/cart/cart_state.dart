import 'package:equatable/equatable.dart';
import 'package:pos_terminal/features/pos/data/models/cart_item_model.dart';

class CartState extends Equatable {
  final List<CartItemModel> items;

  const CartState({this.items = const []});

  int get itemCount => items.length;

  double get subtotalUzs =>
      items.fold(0, (sum, item) => sum + item.quantity * item.priceUzs);

  double get totalDiscountUzs =>
      items.fold(0, (sum, item) => sum + item.discountUzs);

  double get totalUzs => subtotalUzs - totalDiscountUzs;

  bool get isEmpty => items.isEmpty;

  bool get isNotEmpty => items.isNotEmpty;

  CartState copyWith({List<CartItemModel>? items}) {
    return CartState(items: items ?? this.items);
  }

  @override
  List<Object?> get props => [items];
}
