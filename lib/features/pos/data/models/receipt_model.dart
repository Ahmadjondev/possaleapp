import 'package:pos_terminal/features/pos/data/models/parse_helpers.dart';

class ReceiptModel {
  final int saleId;
  final String saleNumber;
  final String date;
  final String? cashierName;
  final String? customerName;
  final String? customerPhone;
  final List<ReceiptItemModel> items;
  final double subtotalUzs;
  final double discountUzs;
  final double totalUzs;
  final List<ReceiptPaymentModel> payments;
  final double changeDueUzs;
  final double balanceAppliedUzs;
  final double balanceCreditedUzs;
  final double debtUzs;
  final double customerCreditUzs;
  final double customerDebtUzs;
  final bool hasDebt;
  final bool hasOverdue;
  final double debtTotalRemainingUzs;
  final int debtActivePlans;
  final int debtWorstOverdueDays;
  final String? note;
  final String? businessName;
  final String? businessPhone;
  final String? businessAddress;
  final String? customerAddress;

  const ReceiptModel({
    required this.saleId,
    this.saleNumber = '',
    this.date = '',
    this.cashierName,
    this.customerName,
    this.customerPhone,
    this.customerAddress,
    this.items = const [],
    this.subtotalUzs = 0,
    this.discountUzs = 0,
    this.totalUzs = 0,
    this.payments = const [],
    this.changeDueUzs = 0,
    this.balanceAppliedUzs = 0,
    this.balanceCreditedUzs = 0,
    this.debtUzs = 0,
    this.customerCreditUzs = 0,
    this.customerDebtUzs = 0,
    this.hasDebt = false,
    this.hasOverdue = false,
    this.debtTotalRemainingUzs = 0,
    this.debtActivePlans = 0,
    this.debtWorstOverdueDays = 0,
    this.note,
    this.businessName,
    this.businessPhone,
    this.businessAddress,
  });

  factory ReceiptModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map
        ? json['data'] as Map<String, dynamic>
        : json;
    return ReceiptModel(
      saleId:
          (data['sale_id'] as num?)?.toInt() ??
          (data['id'] as num?)?.toInt() ??
          0,
      saleNumber: data['sale_number'] as String? ?? '',
      date: data['date'] as String? ?? data['created_at'] as String? ?? '',
      cashierName:
          data['cashier_name'] as String? ?? data['cashier'] as String?,
      customerName: data['customer_name'] as String?,
      customerPhone: data['customer_phone'] as String?,
      items:
          (data['items'] as List<dynamic>?)
              ?.map((e) => ReceiptItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      subtotalUzs: parseDouble(data['subtotal_uzs']),
      discountUzs: parseDouble(data['discount_uzs']),
      totalUzs: parseDouble(data['total_uzs']),
      payments:
          (data['payments'] as List<dynamic>?)
              ?.map(
                (e) => ReceiptPaymentModel.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      changeDueUzs: parseDouble(data['change_due_uzs']),
      balanceAppliedUzs: parseDouble(data['balance_applied_uzs']),
      balanceCreditedUzs: parseDouble(data['balance_credited_uzs']),
      debtUzs: parseDouble(data['debt_uzs']),
      customerCreditUzs: parseDouble(
        (data['customer_balance'] as Map<String, dynamic>?)?['credit_uzs'],
      ),
      customerDebtUzs: parseDouble(
        (data['customer_balance'] as Map<String, dynamic>?)?['debt_uzs'],
      ),
      hasDebt:
          (data['debt_summary'] as Map<String, dynamic>?)?['has_debt'] == true,
      hasOverdue:
          (data['debt_summary'] as Map<String, dynamic>?)?['has_overdue'] ==
          true,
      debtTotalRemainingUzs: parseDouble(
        (data['debt_summary'] as Map<String, dynamic>?)?['total_remaining_uzs'],
      ),
      debtActivePlans:
          ((data['debt_summary']
                      as Map<String, dynamic>?)?['active_plans_count']
                  as num?)
              ?.toInt() ??
          0,
      debtWorstOverdueDays:
          ((data['debt_summary']
                      as Map<String, dynamic>?)?['worst_overdue_days']
                  as num?)
              ?.toInt() ??
          0,
      note: data['note'] as String?,
      businessName: data['business_name'] as String?,
      businessPhone: data['business_phone'] as String?,
      businessAddress: data['business_address'] as String?,
      customerAddress: data['customer_address'] as String?,
    );
  }
}

class ReceiptItemModel {
  final String name;
  final double quantity;
  final String unitType;
  final double unitPrice;
  final double lineTotal;
  final double discount;

  const ReceiptItemModel({
    this.name = '',
    this.quantity = 0,
    this.unitType = 'pcs',
    this.unitPrice = 0,
    this.lineTotal = 0,
    this.discount = 0,
  });

  factory ReceiptItemModel.fromJson(Map<String, dynamic> json) {
    return ReceiptItemModel(
      name: json['name'] as String? ?? json['product_name'] as String? ?? '',
      quantity: parseDouble(json['quantity']),
      unitType: json['unit_type'] as String? ?? 'pcs',
      unitPrice: parseDouble(
        json['price'] ?? json['unit_price'] ?? json['unit_price_uzs'],
      ),
      lineTotal: parseDouble(
        json['total'] ?? json['line_total'] ?? json['line_total_uzs'],
      ),
      discount: parseDouble(json['discount'] ?? json['discount_uzs']),
    );
  }
}

class ReceiptPaymentModel {
  final String method;
  final double amountUzs;
  final String? reference;

  const ReceiptPaymentModel({
    this.method = 'cash',
    this.amountUzs = 0,
    this.reference,
  });

  factory ReceiptPaymentModel.fromJson(Map<String, dynamic> json) {
    return ReceiptPaymentModel(
      method: json['method'] as String? ?? 'cash',
      amountUzs: parseDouble(json['amount_uzs'] ?? json['amount']),
      reference: json['reference'] as String?,
    );
  }
}
