import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_terminal/core/network/api_exception.dart';
import 'package:pos_terminal/features/pos/data/category_repository.dart';
import 'package:pos_terminal/features/pos/data/models/category_model.dart';

import 'category_event_state.dart';

class CategoryBloc extends Bloc<CategoryEvent, CategoryState> {
  final CategoryRepository _categoryRepository;
  List<CategoryModel> _categories = [];

  CategoryBloc({required CategoryRepository categoryRepository})
    : _categoryRepository = categoryRepository,
      super(const CategoryInitial()) {
    on<CategoriesLoadRequested>(_onLoadRequested);
    on<CategorySelected>(_onSelected);
  }

  Future<void> _onLoadRequested(
    CategoriesLoadRequested event,
    Emitter<CategoryState> emit,
  ) async {
    emit(const CategoryLoading());
    try {
      _categories = await _categoryRepository.getCategories();
      emit(CategoryLoaded(categories: _categories));
    } on ApiException catch (e) {
      emit(CategoryError(message: e.message));
    }
  }

  void _onSelected(CategorySelected event, Emitter<CategoryState> emit) {
    emit(CategoryLoaded(categories: _categories, selectedId: event.categoryId));
  }
}
