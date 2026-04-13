import 'package:equatable/equatable.dart';
import 'package:pos_terminal/features/pos/data/models/cart_item_model.dart';
import 'package:pos_terminal/features/pos/data/models/customer_model.dart';
import 'package:pos_terminal/features/pos/data/models/payment_model.dart';
import 'package:pos_terminal/features/pos/data/models/receipt_model.dart';
import 'package:pos_terminal/features/pos/data/models/sale_model.dart';

sealed class PaymentState extends Equatable {
  const PaymentState();

  @override
  List<Object?> get props => [];
}

class PaymentIdle extends PaymentState {
  const PaymentIdle();
}

class PaymentInProgress extends PaymentState {
  final List<CartItemModel> items;
  final double subtotalUzs;
  final PaymentMethod method;
  final double enteredAmount;
  final String reference;
  final CustomerModel? customer;
  final CustomerBalanceModel? customerBalance;
  final bool useBalance;
  final DiscountType discountType;
  final double discountValue;
  final List<PaymentItemModel> paymentItems; // for mixed payments

  const PaymentInProgress({
    required this.items,
    required this.subtotalUzs,
    this.method = PaymentMethod.cash,
    this.enteredAmount = 0,
    this.reference = '',
    this.customer,
    this.customerBalance,
    this.useBalance = false,
    this.discountType = DiscountType.none,
    this.discountValue = 0,
    this.paymentItems = const [],
  });

  /// Calculate total discount in UZS.
  double get discountAmountUzs {
    switch (discountType) {
      case DiscountType.none:
        return 0;
      case DiscountType.percent:
        return subtotalUzs * discountValue / 100;
      case DiscountType.amount:
        return discountValue;
    }
  }

  /// Total after discount.
  double get totalUzs => subtotalUzs - discountAmountUzs;

  /// Balance applied from customer credit.
  double get balanceAppliedUzs {
    if (!useBalance || customerBalance == null) return 0;
    final credit = customerBalance!.creditUzs;
    return credit > totalUzs ? totalUzs : credit;
  }

  /// Effective total after balance applied.
  double get effectiveTotalUzs => totalUzs - balanceAppliedUzs;

  /// Total already paid via mixed payment items.
  double get mixedPaidUzs =>
      paymentItems.fold(0, (sum, p) => sum + p.amountUzs);

  /// Remaining balance to pay.
  double get remainingUzs {
    if (paymentItems.isNotEmpty) {
      return effectiveTotalUzs - mixedPaidUzs;
    }
    return effectiveTotalUzs - enteredAmount;
  }

  /// Change to return (negative means underpaid).
  double get changeDueUzs {
    if (paymentItems.isNotEmpty) {
      final paid = mixedPaidUzs;
      return paid > effectiveTotalUzs ? paid - effectiveTotalUzs : 0;
    }
    return enteredAmount > effectiveTotalUzs
        ? enteredAmount - effectiveTotalUzs
        : 0;
  }

  /// Whether payment is valid for submission.
  bool get isValid {
    if (items.isEmpty) return false;
    if (method == PaymentMethod.debt) {
      if (customer == null) return false;
      if (customerBalance != null &&
          effectiveTotalUzs > customerBalance!.availableDebtUzs) {
        return false;
      }
      return true;
    }
    if (paymentItems.isNotEmpty) {
      return mixedPaidUzs >= effectiveTotalUzs;
    }
    return enteredAmount >= effectiveTotalUzs;
  }

  bool get isMixed => paymentItems.isNotEmpty;

  PaymentInProgress copyWith({
    List<CartItemModel>? items,
    double? subtotalUzs,
    PaymentMethod? method,
    double? enteredAmount,
    String? reference,
    CustomerModel? customer,
    CustomerBalanceModel? customerBalance,
    bool? useBalance,
    DiscountType? discountType,
    double? discountValue,
    List<PaymentItemModel>? paymentItems,
    bool clearCustomer = false,
  }) {
    return PaymentInProgress(
      items: items ?? this.items,
      subtotalUzs: subtotalUzs ?? this.subtotalUzs,
      method: method ?? this.method,
      enteredAmount: enteredAmount ?? this.enteredAmount,
      reference: reference ?? this.reference,
      customer: clearCustomer ? null : (customer ?? this.customer),
      customerBalance: clearCustomer
          ? null
          : (customerBalance ?? this.customerBalance),
      useBalance: clearCustomer ? false : (useBalance ?? this.useBalance),
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      paymentItems: paymentItems ?? this.paymentItems,
    );
  }

  @override
  List<Object?> get props => [
    items,
    subtotalUzs,
    method,
    enteredAmount,
    reference,
    customer,
    customerBalance,
    useBalance,
    discountType,
    discountValue,
    paymentItems,
  ];
}

class PaymentProcessing extends PaymentState {
  const PaymentProcessing();
}

class PaymentSuccess extends PaymentState {
  final SaleModel sale;
  final ReceiptModel? receipt;

  const PaymentSuccess({required this.sale, this.receipt});

  @override
  List<Object?> get props => [sale, receipt];
}

class PaymentFailed extends PaymentState {
  final String message;
  final PaymentInProgress previousState;

  const PaymentFailed({required this.message, required this.previousState});

  @override
  List<Object?> get props => [message, previousState];
}
