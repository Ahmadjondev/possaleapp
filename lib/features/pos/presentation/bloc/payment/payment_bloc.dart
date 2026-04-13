import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_terminal/core/network/api_exception.dart';
import 'package:pos_terminal/features/pos/data/models/payment_model.dart';
import 'package:pos_terminal/features/pos/data/customer_repository.dart';
import 'package:pos_terminal/features/pos/data/pos_repository.dart';

import 'payment_event.dart';
import 'payment_state.dart';

class PaymentBloc extends Bloc<PaymentEvent, PaymentState> {
  final PosRepository _posRepository;
  final CustomerRepository? _customerRepository;

  PaymentBloc({
    required PosRepository posRepository,
    CustomerRepository? customerRepository,
  }) : _posRepository = posRepository,
       _customerRepository = customerRepository,
       super(const PaymentIdle()) {
    on<PaymentStarted>(_onStarted);
    on<PaymentMethodChanged>(_onMethodChanged);
    on<PaymentAmountEntered>(_onAmountEntered);
    on<PaymentDiscountChanged>(_onDiscountChanged);
    on<PaymentCustomerSelected>(_onCustomerSelected);
    on<PaymentCustomerCleared>(_onCustomerCleared);
    on<PaymentUseBalanceToggled>(_onUseBalanceToggled);
    on<PaymentItemAdded>(_onItemAdded);
    on<PaymentItemRemoved>(_onItemRemoved);
    on<PaymentReferenceChanged>(_onReferenceChanged);
    on<PaymentSubmitted>(_onSubmitted);
    on<PaymentCancelled>(_onCancelled);
  }

  void _onStarted(PaymentStarted event, Emitter<PaymentState> emit) {
    if (state is PaymentInProgress) {
      // Update cart data while preserving payment settings
      final s = state as PaymentInProgress;
      emit(s.copyWith(items: event.items, subtotalUzs: event.subtotalUzs));
    } else {
      emit(
        PaymentInProgress(items: event.items, subtotalUzs: event.subtotalUzs),
      );
    }
  }

  void _onMethodChanged(
    PaymentMethodChanged event,
    Emitter<PaymentState> emit,
  ) {
    if (state is! PaymentInProgress) return;
    final s = state as PaymentInProgress;
    emit(s.copyWith(method: event.method));
  }

  void _onAmountEntered(
    PaymentAmountEntered event,
    Emitter<PaymentState> emit,
  ) {
    if (state is! PaymentInProgress) return;
    final s = state as PaymentInProgress;
    emit(s.copyWith(enteredAmount: event.amount));
  }

  void _onDiscountChanged(
    PaymentDiscountChanged event,
    Emitter<PaymentState> emit,
  ) {
    if (state is! PaymentInProgress) return;
    final s = state as PaymentInProgress;
    emit(s.copyWith(discountType: event.type, discountValue: event.value));
  }

  void _onCustomerSelected(
    PaymentCustomerSelected event,
    Emitter<PaymentState> emit,
  ) {
    if (state is! PaymentInProgress) return;
    final s = state as PaymentInProgress;
    emit(s.copyWith(customer: event.customer, customerBalance: event.balance));
  }

  void _onCustomerCleared(
    PaymentCustomerCleared event,
    Emitter<PaymentState> emit,
  ) {
    if (state is! PaymentInProgress) return;
    final s = state as PaymentInProgress;
    emit(s.copyWith(clearCustomer: true));
  }

  void _onUseBalanceToggled(
    PaymentUseBalanceToggled event,
    Emitter<PaymentState> emit,
  ) {
    if (state is! PaymentInProgress) return;
    final s = state as PaymentInProgress;
    emit(s.copyWith(useBalance: !s.useBalance));
  }

  void _onItemAdded(PaymentItemAdded event, Emitter<PaymentState> emit) {
    if (state is! PaymentInProgress) return;
    final s = state as PaymentInProgress;
    final items = [...s.paymentItems, event.paymentItem];
    emit(s.copyWith(paymentItems: items));
  }

  void _onItemRemoved(PaymentItemRemoved event, Emitter<PaymentState> emit) {
    if (state is! PaymentInProgress) return;
    final s = state as PaymentInProgress;
    final items = List<PaymentItemModel>.from(s.paymentItems);
    if (event.index < items.length) items.removeAt(event.index);
    emit(s.copyWith(paymentItems: items));
  }

  void _onReferenceChanged(
    PaymentReferenceChanged event,
    Emitter<PaymentState> emit,
  ) {
    if (state is! PaymentInProgress) return;
    final s = state as PaymentInProgress;
    emit(s.copyWith(reference: event.reference));
  }

  Future<void> _onSubmitted(
    PaymentSubmitted event,
    Emitter<PaymentState> emit,
  ) async {
    if (state is! PaymentInProgress) return;
    final s = state as PaymentInProgress;

    if (!s.isValid) return;

    emit(const PaymentProcessing());

    try {
      // Build payments list
      List<Map<String, dynamic>> payments;
      if (s.isMixed) {
        payments = s.paymentItems.map((p) => p.toJson()).toList();
      } else {
        payments = [
          PaymentItemModel(
            method: s.method,
            amountUzs: s.method == PaymentMethod.debt
                ? s.effectiveTotalUzs
                : s.enteredAmount,
            reference: s.reference,
          ).toJson(),
        ];
      }

      // Build payload matching SaleWriteSerializer field names
      final payload = <String, dynamic>{
        'items': s.items.map((i) => i.toSaleJson()).toList(),
        'warehouse': event.warehouseId,
        'payments': payments,
      };

      if (s.customer != null) {
        payload['customer'] = s.customer!.id;
      }

      if (s.discountType != DiscountType.none) {
        payload['discount_type'] = s.discountType == DiscountType.percent
            ? 'percent'
            : 'amount';
        payload['discount_value'] = s.discountValue;
      }

      if (s.balanceAppliedUzs > 0) {
        payload['balance_applied_uzs'] = s.balanceAppliedUzs;
      }

      if (event.note != null && event.note!.isNotEmpty) {
        payload['notes'] = event.note;
      }

      final sale = await _posRepository.quickSale(payload);

      // Invalidate caches — stock quantities changed after sale
      _posRepository.invalidateProductCache();
      if (s.customer != null) {
        _customerRepository?.invalidateBalance(s.customer!.id);
      }

      // Fetch receipt
      try {
        final receipt = await _posRepository.getReceipt(sale.id);
        emit(PaymentSuccess(sale: sale, receipt: receipt));
      } catch (_) {
        emit(PaymentSuccess(sale: sale));
      }
    } on ApiException catch (e) {
      emit(PaymentFailed(message: e.message, previousState: s));
    } catch (e) {
      emit(
        PaymentFailed(message: 'Failed to process sale: $e', previousState: s),
      );
    }
  }

  void _onCancelled(PaymentCancelled event, Emitter<PaymentState> emit) {
    emit(const PaymentIdle());
  }
}
