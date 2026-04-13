class WarehouseModel {
  final int id;
  final String name;
  final String location;

  const WarehouseModel({
    required this.id,
    required this.name,
    this.location = '',
  });

  factory WarehouseModel.fromJson(Map<String, dynamic> json) {
    return WarehouseModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      location: json['location'] as String? ?? '',
    );
  }
}
