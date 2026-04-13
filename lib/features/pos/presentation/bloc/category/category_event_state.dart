import 'package:equatable/equatable.dart';
import 'package:pos_terminal/features/pos/data/models/category_model.dart';

sealed class CategoryEvent extends Equatable {
  const CategoryEvent();

  @override
  List<Object?> get props => [];
}

class CategoriesLoadRequested extends CategoryEvent {
  const CategoriesLoadRequested();
}

class CategorySelected extends CategoryEvent {
  final int? categoryId;

  const CategorySelected({this.categoryId});

  @override
  List<Object?> get props => [categoryId];
}

// --- States ---

sealed class CategoryState extends Equatable {
  const CategoryState();

  @override
  List<Object?> get props => [];
}

class CategoryInitial extends CategoryState {
  const CategoryInitial();
}

class CategoryLoading extends CategoryState {
  const CategoryLoading();
}

class CategoryLoaded extends CategoryState {
  final List<CategoryModel> categories;
  final int? selectedId;

  const CategoryLoaded({required this.categories, this.selectedId});

  @override
  List<Object?> get props => [categories, selectedId];
}

class CategoryError extends CategoryState {
  final String message;

  const CategoryError({required this.message});

  @override
  List<Object?> get props => [message];
}
