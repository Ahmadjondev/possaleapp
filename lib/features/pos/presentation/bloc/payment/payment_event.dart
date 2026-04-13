import 'package:equatable/equatable.dart';
import 'package:pos_terminal/features/pos/data/models/cart_item_model.dart';
import 'package:pos_terminal/features/pos/data/models/customer_model.dart';
import 'package:pos_terminal/features/pos/data/models/payment_model.dart';

sealed class PaymentEvent extends Equatable {
  const PaymentEvent();

  @override
  List<Object?> get props => [];
}

/// Initialize payment flow with cart data.
class PaymentStarted extends PaymentEvent {
  final List<CartItemModel> items;
  final double subtotalUzs;

  const PaymentStarted({required this.items, required this.subtotalUzs});

  @override
  List<Object?> get props => [items, subtotalUzs];
}

/// Change the primary payment method.
class PaymentMethodChanged extends PaymentEvent {
  final PaymentMethod method;

  const PaymentMethodChanged({required this.method});

  @override
  List<Object?> get props => [method];
}

/// Enter/update payment amount.
class PaymentAmountEntered extends PaymentEvent {
  final double amount;

  const PaymentAmountEntered({required this.amount});

  @override
  List<Object?> get props => [amount];
}

/// Change overall sale discount.
class PaymentDiscountChanged extends PaymentEvent {
  final DiscountType type;
  final double value;

  const PaymentDiscountChanged({required this.type, required this.value});

  @override
  List<Object?> get props => [type, value];
}

/// Set the customer for the sale.
class PaymentCustomerSelected extends PaymentEvent {
  final CustomerModel customer;
  final CustomerBalanceModel balance;

  const PaymentCustomerSelected({
    required this.customer,
    required this.balance,
  });

  @override
  List<Object?> get props => [customer, balance];
}

/// Clear selected customer.
class PaymentCustomerCleared extends PaymentEvent {
  const PaymentCustomerCleared();
}

/// Toggle using customer balance/credit.
class PaymentUseBalanceToggled extends PaymentEvent {
  const PaymentUseBalanceToggled();
}

/// Add a payment item for mixed payments.
class PaymentItemAdded extends PaymentEvent {
  final PaymentItemModel paymentItem;

  const PaymentItemAdded({required this.paymentItem});

  @override
  List<Object?> get props => [paymentItem];
}

/// Remove a payment item from mixed payments.
class PaymentItemRemoved extends PaymentEvent {
  final int index;

  const PaymentItemRemoved({required this.index});

  @override
  List<Object?> get props => [index];
}

/// Submit the sale.
class PaymentSubmitted extends PaymentEvent {
  final int warehouseId;
  final String? note;

  const PaymentSubmitted({required this.warehouseId, this.note});

  @override
  List<Object?> get props => [warehouseId, note];
}

/// Cancel / close the payment modal.
class PaymentCancelled extends PaymentEvent {
  const PaymentCancelled();
}

/// Set reference text for bank / P2P payments.
class PaymentReferenceChanged extends PaymentEvent {
  final String reference;

  const PaymentReferenceChanged({required this.reference});

  @override
  List<Object?> get props => [reference];
}
