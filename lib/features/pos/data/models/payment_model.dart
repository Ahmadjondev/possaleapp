import 'package:equatable/equatable.dart';

/// Supported payment methods.
enum PaymentMethod {
  cash,
  terminal,
  p2p,
  bank,
  debt,
  other;

  String get label {
    switch (this) {
      case cash:
        return 'Нақд';
      case terminal:
        return 'Карта';
      case p2p:
        return 'P2P';
      case bank:
        return 'Банк';
      case debt:
        return 'Қарз';
      case other:
        return 'Бошқа';
    }
  }

  String get apiValue => name;

  static PaymentMethod fromString(String value) {
    return PaymentMethod.values.firstWhere(
      (m) => m.name == value,
      orElse: () => PaymentMethod.cash,
    );
  }
}

/// Discount type for the cart-level discount.
enum DiscountType { none, amount, percent }

class PaymentItemModel extends Equatable {
  final PaymentMethod method;
  final double amountUzs;
  final double amountUsd;
  final String currency;
  final String reference;

  const PaymentItemModel({
    required this.method,
    this.amountUzs = 0,
    this.amountUsd = 0,
    this.currency = 'UZS',
    this.reference = '',
  });

  Map<String, dynamic> toJson() => {
    'method': method.apiValue,
    'amount_uzs': amountUzs,
    'amount_usd': amountUsd,
    'currency': currency,
    'reference': reference,
  };

  @override
  List<Object?> get props => [method, amountUzs, amountUsd, currency];
}
