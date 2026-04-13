import 'package:equatable/equatable.dart';
import 'package:pos_terminal/features/pos/data/models/parse_helpers.dart';

class SaleModel extends Equatable {
  final int id;
  final String saleNumber;
  final String status;
  final int? warehouseId;
  final int? cashierId;
  final String? cashierName;
  final int? customerId;
  final String? customerName;
  final String discountType;
  final double discountValue;
  final double subtotalUzs;
  final double subtotalUsd;
  final double totalUzs;
  final double totalUsd;
  final double totalPaidUzs;
  final double totalPaidUsd;
  final double changeDueUzs;
  final bool isCreditSale;
  final double balanceAppliedUzs;
  final String? note;
  final String? createdAt;

  const SaleModel({
    required this.id,
    this.saleNumber = '',
    this.status = 'paid',
    this.warehouseId,
    this.cashierId,
    this.cashierName,
    this.customerId,
    this.customerName,
    this.discountType = 'none',
    this.discountValue = 0,
    this.subtotalUzs = 0,
    this.subtotalUsd = 0,
    this.totalUzs = 0,
    this.totalUsd = 0,
    this.totalPaidUzs = 0,
    this.totalPaidUsd = 0,
    this.changeDueUzs = 0,
    this.isCreditSale = false,
    this.balanceAppliedUzs = 0,
    this.note,
    this.createdAt,
  });

  factory SaleModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map
        ? json['data'] as Map<String, dynamic>
        : json;
    return SaleModel(
      id: (data['id'] as num).toInt(),
      saleNumber: data['sale_number'] as String? ?? '',
      status: data['status'] as String? ?? 'paid',
      warehouseId:
          (data['warehouse_id'] as num?)?.toInt() ??
          (data['warehouse'] as num?)?.toInt(),
      cashierId:
          (data['cashier_id'] as num?)?.toInt() ??
          (data['cashier'] as num?)?.toInt(),
      cashierName: data['cashier_name'] as String?,
      customerId:
          (data['customer_id'] as num?)?.toInt() ??
          (data['customer'] as num?)?.toInt(),
      customerName: data['customer_name'] as String?,
      discountType: data['discount_type'] as String? ?? 'none',
      discountValue: parseDouble(data['discount_value']),
      subtotalUzs: parseDouble(data['subtotal_uzs']),
      subtotalUsd: parseDouble(data['subtotal_usd']),
      totalUzs: parseDouble(data['total_uzs']),
      totalUsd: parseDouble(data['total_usd']),
      totalPaidUzs: parseDouble(data['total_paid_uzs']),
      totalPaidUsd: parseDouble(data['total_paid_usd']),
      changeDueUzs: parseDouble(data['change_due_uzs']),
      isCreditSale: data['is_credit_sale'] as bool? ?? false,
      balanceAppliedUzs: parseDouble(data['balance_applied_uzs']),
      note: data['note'] as String?,
      createdAt: data['created_at'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, saleNumber];
}
