import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_terminal/core/network/api_exception.dart';
import 'package:pos_terminal/features/pos/data/customer_repository.dart';
import 'package:pos_terminal/features/pos/data/models/customer_model.dart';

// --- Events ---
sealed class CustomerEvent extends Equatable {
  const CustomerEvent();

  @override
  List<Object?> get props => [];
}

class CustomerSearchRequested extends CustomerEvent {
  final String query;

  const CustomerSearchRequested({required this.query});

  @override
  List<Object?> get props => [query];
}

class CustomerSelected extends CustomerEvent {
  final CustomerModel customer;

  const CustomerSelected({required this.customer});

  @override
  List<Object?> get props => [customer];
}

class CustomerCleared extends CustomerEvent {
  const CustomerCleared();
}

class CustomerCreateRequested extends CustomerEvent {
  final String firstName;
  final String phone;
  final String? lastName;
  final String customerType;
  final String? address;
  final double? debtLimitUzs;
  final String? notes;

  const CustomerCreateRequested({
    required this.firstName,
    required this.phone,
    this.lastName,
    this.customerType = 'individual',
    this.address,
    this.debtLimitUzs,
    this.notes,
  });

  @override
  List<Object?> get props => [
    firstName,
    phone,
    lastName,
    customerType,
    address,
    debtLimitUzs,
    notes,
  ];
}

// --- States ---
sealed class CustomerState extends Equatable {
  const CustomerState();

  @override
  List<Object?> get props => [];
}

class CustomerInitial extends CustomerState {
  const CustomerInitial();
}

class CustomerSearching extends CustomerState {
  const CustomerSearching();
}

class CustomerSearchLoaded extends CustomerState {
  final List<CustomerModel> customers;

  const CustomerSearchLoaded({required this.customers});

  @override
  List<Object?> get props => [customers];
}

class CustomerSelectedState extends CustomerState {
  final CustomerModel customer;
  final CustomerBalanceModel balance;

  const CustomerSelectedState({required this.customer, required this.balance});

  @override
  List<Object?> get props => [customer, balance];
}

class CustomerError extends CustomerState {
  final String message;

  const CustomerError({required this.message});

  @override
  List<Object?> get props => [message];
}

// --- BLoC ---
class CustomerBloc extends Bloc<CustomerEvent, CustomerState> {
  final CustomerRepository _customerRepository;
  Timer? _debounce;

  CustomerBloc({required CustomerRepository customerRepository})
    : _customerRepository = customerRepository,
      super(const CustomerInitial()) {
    on<CustomerSearchRequested>(_onSearchRequested);
    on<CustomerSelected>(_onSelected);
    on<CustomerCleared>(_onCleared);
    on<CustomerCreateRequested>(_onCreateRequested);
  }

  Future<void> _onSearchRequested(
    CustomerSearchRequested event,
    Emitter<CustomerState> emit,
  ) async {
    _debounce?.cancel();

    if (event.query.isEmpty) {
      emit(const CustomerInitial());
      return;
    }

    final completer = Completer<void>();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      completer.complete();
    });

    await completer.future;

    emit(const CustomerSearching());
    try {
      final customers = await _customerRepository.searchCustomers(event.query);
      emit(CustomerSearchLoaded(customers: customers));
    } on ApiException catch (e) {
      emit(CustomerError(message: e.message));
    }
  }

  Future<void> _onSelected(
    CustomerSelected event,
    Emitter<CustomerState> emit,
  ) async {
    try {
      final balance = await _customerRepository.getCustomerBalance(
        event.customer.id,
      );
      emit(CustomerSelectedState(customer: event.customer, balance: balance));
    } on ApiException catch (e) {
      emit(CustomerError(message: e.message));
    }
  }

  void _onCleared(CustomerCleared event, Emitter<CustomerState> emit) {
    emit(const CustomerInitial());
  }

  Future<void> _onCreateRequested(
    CustomerCreateRequested event,
    Emitter<CustomerState> emit,
  ) async {
    try {
      final customer = await _customerRepository.createCustomer(
        firstName: event.firstName,
        phone: event.phone,
        lastName: event.lastName,
        customerType: event.customerType,
        address: event.address,
        debtLimitUzs: event.debtLimitUzs,
        notes: event.notes,
      );
      // Auto-select the newly created customer
      add(CustomerSelected(customer: customer));
    } on ApiException catch (e) {
      emit(CustomerError(message: e.message));
    }
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
