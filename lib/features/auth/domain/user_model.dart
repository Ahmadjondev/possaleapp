import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final int id;
  final String username;
  final String firstName;
  final String lastName;
  final String role;
  final int? tenantRoleId;
  final String? tenantRoleName;
  final String? phone;
  final int? defaultWarehouseId;
  final String? defaultWarehouseName;
  final String? businessName;

  const UserModel({
    required this.id,
    required this.username,
    this.firstName = '',
    this.lastName = '',
    this.role = 'cashier',
    this.tenantRoleId,
    this.tenantRoleName,
    this.phone,
    this.defaultWarehouseId,
    this.defaultWarehouseName,
    this.businessName,
  });

  String get displayName {
    if (firstName.isNotEmpty || lastName.isNotEmpty) {
      return '$firstName $lastName'.trim();
    }
    return username;
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Handle both /api/users/me/ and token claims
    final data = json['data'] is Map
        ? json['data'] as Map<String, dynamic>
        : json;
    return UserModel(
      id: data['id'] ?? 0,
      username: data['username'] ?? '',
      firstName: data['first_name'] ?? '',
      lastName: data['last_name'] ?? '',
      role: data['role'] ?? 'cashier',
      tenantRoleId: data['tenant_role_id'],
      tenantRoleName: data['tenant_role_name'],
      phone: data['phone'],
      defaultWarehouseId: data['default_warehouse_id'],
      defaultWarehouseName: data['default_warehouse_name'],
      businessName: data['business_name'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'first_name': firstName,
    'last_name': lastName,
    'role': role,
    'tenant_role_id': tenantRoleId,
    'tenant_role_name': tenantRoleName,
    'phone': phone,
    'default_warehouse_id': defaultWarehouseId,
    'default_warehouse_name': defaultWarehouseName,
    'business_name': businessName,
  };

  @override
  List<Object?> get props => [id, username, role, tenantRoleId];
}
