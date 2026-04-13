import 'package:equatable/equatable.dart';

class CategoryModel extends Equatable {
  final int id;
  final String name;
  final int? parentId;
  final int productCount;

  const CategoryModel({
    required this.id,
    required this.name,
    this.parentId,
    this.productCount = 0,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      parentId:
          (json['parent_id'] as num?)?.toInt() ??
          (json['parent'] as num?)?.toInt(),
      productCount:
          (json['product_count'] as num?)?.toInt() ??
          (json['products_count'] as num?)?.toInt() ??
          0,
    );
  }

  @override
  List<Object?> get props => [id];
}
