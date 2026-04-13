import 'package:equatable/equatable.dart';
import 'package:pos_terminal/features/pos/data/models/parse_helpers.dart';

class CustomerModel extends Equatable {
  final int id;
  final String firstName;
  final String lastName;
  final String? middleName;
  final String? phone;
  final String? phoneSecondary;
  final String? companyName;
  final String customerType; // individual, business, mechanic, shop
  final double balanceUzs;
  final double balanceUsd;

  const CustomerModel({
    required this.id,
    this.firstName = '',
    this.lastName = '',
    this.middleName,
    this.phone,
    this.phoneSecondary,
    this.companyName,
    this.customerType = 'individual',
    this.balanceUzs = 0,
    this.balanceUsd = 0,
  });

  String get displayName {
    if (companyName != null && companyName!.isNotEmpty) return companyName!;
    final parts = [firstName, lastName].where((s) => s.isNotEmpty);
    return parts.isEmpty ? 'Customer #$id' : parts.join(' ');
  }

  String get displayPhone => phone ?? '';

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: (json['id'] as num).toInt(),
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      middleName: json['middle_name'] as String?,
      phone: json['phone'] as String?,
      phoneSecondary: json['phone_secondary'] as String?,
      companyName: json['company_name'] as String?,
      customerType: json['customer_type'] as String? ?? 'individual',
      balanceUzs: parseDouble(json['balance_uzs']),
      balanceUsd: parseDouble(json['balance_usd']),
    );
  }

  @override
  List<Object?> get props => [id];
}

class CustomerBalanceModel extends Equatable {
  final double creditUzs;
  final double creditUsd;
  final double debtUzs;
  final double debtUsd;
  final double debtLimitUzs;
  final double effectiveDebtLimitUzs;
  final double availableDebtUzs;

  const CustomerBalanceModel({
    this.creditUzs = 0,
    this.creditUsd = 0,
    this.debtUzs = 0,
    this.debtUsd = 0,
    this.debtLimitUzs = 0,
    this.effectiveDebtLimitUzs = 0,
    this.availableDebtUzs = 0,
  });

  factory CustomerBalanceModel.fromJson(Map<String, dynamic> json) {
    return CustomerBalanceModel(
      creditUzs: parseDouble(json['credit_uzs']),
      creditUsd: parseDouble(json['credit_usd']),
      debtUzs: parseDouble(json['debt_uzs']),
      debtUsd: parseDouble(json['debt_usd']),
      debtLimitUzs: parseDouble(json['debt_limit_uzs']),
      effectiveDebtLimitUzs: parseDouble(json['effective_debt_limit_uzs']),
      availableDebtUzs: parseDouble(json['available_debt_uzs']),
    );
  }

  @override
  List<Object?> get props => [debtUzs, creditUzs, availableDebtUzs];
}
