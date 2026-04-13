import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_terminal/core/network/api_exception.dart';
import 'package:pos_terminal/features/pos/data/pos_repository.dart';

import 'product_event.dart';
import 'product_state.dart';

class ProductBloc extends Bloc<ProductEvent, ProductState> {
  final PosRepository _posRepository;
  int _warehouseId;
  String _currentQuery = '';
  int? _currentCategoryId;
  Timer? _debounce;

  ProductBloc({required PosRepository posRepository, required int warehouseId})
    : _posRepository = posRepository,
      _warehouseId = warehouseId,
      super(const ProductInitial()) {
    on<ProductsLoadRequested>(_onLoadRequested);
    on<ProductSearchRequested>(_onSearchRequested);
    on<ProductCategoryChanged>(_onCategoryChanged);
    on<ProductBarcodeScanned>(_onBarcodeScanned);
    on<ProductWarehouseChanged>(_onWarehouseChanged);
  }

  Future<void> _onLoadRequested(
    ProductsLoadRequested event,
    Emitter<ProductState> emit,
  ) async {
    emit(const ProductLoading());
    try {
      final products = await _posRepository.searchProducts(
        query: '',
        warehouseId: _warehouseId,
      );
      emit(ProductLoaded(products: products));
    } on ApiException catch (e) {
      emit(ProductError(message: e.message));
    }
  }

  Future<void> _onSearchRequested(
    ProductSearchRequested event,
    Emitter<ProductState> emit,
  ) async {
    _currentQuery = event.query;
    _debounce?.cancel();

    if (event.query.isEmpty && _currentCategoryId == null) {
      add(const ProductsLoadRequested());
      return;
    }

    // Debounce 300ms for typing
    final completer = Completer<void>();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      completer.complete();
    });

    await completer.future;

    // Check if query is still the same after debounce
    if (_currentQuery != event.query) return;

    emit(const ProductLoading());
    try {
      final products = await _posRepository.searchProducts(
        query: event.query,
        warehouseId: _warehouseId,
        categoryId: _currentCategoryId,
      );
      emit(
        ProductLoaded(
          products: products,
          query: event.query,
          categoryId: _currentCategoryId,
        ),
      );
    } on ApiException catch (e) {
      emit(ProductError(message: e.message));
    }
  }

  Future<void> _onCategoryChanged(
    ProductCategoryChanged event,
    Emitter<ProductState> emit,
  ) async {
    _currentCategoryId = event.categoryId;
    emit(const ProductLoading());
    try {
      final products = await _posRepository.searchProducts(
        query: _currentQuery,
        warehouseId: _warehouseId,
        categoryId: event.categoryId,
      );
      emit(
        ProductLoaded(
          products: products,
          query: _currentQuery,
          categoryId: event.categoryId,
        ),
      );
    } on ApiException catch (e) {
      emit(ProductError(message: e.message));
    }
  }

  Future<void> _onBarcodeScanned(
    ProductBarcodeScanned event,
    Emitter<ProductState> emit,
  ) async {
    try {
      final product = await _posRepository.scanBarcode(
        barcode: event.barcode,
        warehouseId: _warehouseId,
      );
      if (product != null) {
        emit(ProductScanned(product: product));
        // Return to previous loaded state after scan
        final products = await _posRepository.searchProducts(
          query: _currentQuery,
          warehouseId: _warehouseId,
          categoryId: _currentCategoryId,
        );
        emit(
          ProductLoaded(
            products: products,
            query: _currentQuery,
            categoryId: _currentCategoryId,
          ),
        );
      }
    } on ApiException catch (e) {
      emit(ProductError(message: e.message));
    }
  }

  Future<void> _onWarehouseChanged(
    ProductWarehouseChanged event,
    Emitter<ProductState> emit,
  ) async {
    _warehouseId = event.warehouseId;
    add(const ProductsLoadRequested());
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
