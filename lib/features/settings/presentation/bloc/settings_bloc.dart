import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_terminal/core/printing/printer_config.dart';
import 'package:pos_terminal/core/printing/printer_service.dart';
import 'package:pos_terminal/features/auth/data/auth_local_storage.dart';
import 'package:pos_terminal/features/settings/data/settings_repository.dart';
import 'package:pos_terminal/features/settings/data/warehouse_model.dart';

// ── Events ──────────────────────────────────────────────────────────

abstract class SettingsEvent {
  const SettingsEvent();
}

class SettingsLoaded extends SettingsEvent {
  const SettingsLoaded();
}

class WarehouseChanged extends SettingsEvent {
  final int warehouseId;
  const WarehouseChanged(this.warehouseId);
}

class ReceiptPrinterUpdated extends SettingsEvent {
  final PrinterConfig config;
  const ReceiptPrinterUpdated(this.config);
}

class LabelPrinterUpdated extends SettingsEvent {
  final LabelPrinterConfig config;
  const LabelPrinterUpdated(this.config);
}

class PrinterTestRequested extends SettingsEvent {
  final bool isLabel;
  const PrinterTestRequested({this.isLabel = false});
}

class PrintTestPageRequested extends SettingsEvent {
  final bool isLabel;
  const PrintTestPageRequested({this.isLabel = false});
}

class PrinterDiscoveryRequested extends SettingsEvent {
  const PrinterDiscoveryRequested();
}

class UsbPortDiscoveryRequested extends SettingsEvent {
  const UsbPortDiscoveryRequested();
}

class ServerUrlUpdated extends SettingsEvent {
  final String url;
  const ServerUrlUpdated(this.url);
}

// ── State ───────────────────────────────────────────────────────────

class SettingsState {
  final List<WarehouseModel> warehouses;
  final int? selectedWarehouseId;
  final PrinterConfig receiptPrinter;
  final LabelPrinterConfig labelPrinter;
  final List<String> availablePrinters;
  final List<String> availableUsbPorts;
  final String serverUrl;
  final bool isLoading;
  final bool isDiscovering;
  final bool isTesting;
  final String? receiptTestResult;
  final String? labelTestResult;
  final String? error;

  const SettingsState({
    this.warehouses = const [],
    this.selectedWarehouseId,
    this.receiptPrinter = const PrinterConfig(),
    this.labelPrinter = const LabelPrinterConfig(),
    this.availablePrinters = const [],
    this.availableUsbPorts = const [],
    this.serverUrl = '',
    this.isLoading = false,
    this.isDiscovering = false,
    this.isTesting = false,
    this.receiptTestResult,
    this.labelTestResult,
    this.error,
  });

  SettingsState copyWith({
    List<WarehouseModel>? warehouses,
    int? selectedWarehouseId,
    PrinterConfig? receiptPrinter,
    LabelPrinterConfig? labelPrinter,
    List<String>? availablePrinters,
    List<String>? availableUsbPorts,
    String? serverUrl,
    bool? isLoading,
    bool? isDiscovering,
    bool? isTesting,
    String? receiptTestResult,
    String? labelTestResult,
    String? error,
  }) {
    return SettingsState(
      warehouses: warehouses ?? this.warehouses,
      selectedWarehouseId: selectedWarehouseId ?? this.selectedWarehouseId,
      receiptPrinter: receiptPrinter ?? this.receiptPrinter,
      labelPrinter: labelPrinter ?? this.labelPrinter,
      availablePrinters: availablePrinters ?? this.availablePrinters,
      availableUsbPorts: availableUsbPorts ?? this.availableUsbPorts,
      serverUrl: serverUrl ?? this.serverUrl,
      isLoading: isLoading ?? this.isLoading,
      isDiscovering: isDiscovering ?? this.isDiscovering,
      isTesting: isTesting ?? this.isTesting,
      receiptTestResult: receiptTestResult,
      labelTestResult: labelTestResult,
      error: error,
    );
  }
}

// ── BLoC ────────────────────────────────────────────────────────────

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final SettingsRepository _settingsRepo;
  final PrinterConfigStorage _printerStorage;
  final PrinterService _printerService;
  final AuthLocalStorage _authStorage;

  SettingsBloc({
    required SettingsRepository settingsRepository,
    required PrinterConfigStorage printerStorage,
    required PrinterService printerService,
    required AuthLocalStorage authStorage,
  }) : _settingsRepo = settingsRepository,
       _printerStorage = printerStorage,
       _printerService = printerService,
       _authStorage = authStorage,
       super(const SettingsState()) {
    on<SettingsLoaded>(_onLoaded);
    on<WarehouseChanged>(_onWarehouseChanged);
    on<ReceiptPrinterUpdated>(_onReceiptPrinterUpdated);
    on<LabelPrinterUpdated>(_onLabelPrinterUpdated);
    on<PrinterTestRequested>(_onPrinterTest);
    on<PrintTestPageRequested>(_onPrintTestPage);
    on<PrinterDiscoveryRequested>(_onPrinterDiscovery);
    on<UsbPortDiscoveryRequested>(_onUsbPortDiscovery);
    on<ServerUrlUpdated>(_onServerUrlUpdated);
  }

  Future<void> _onLoaded(
    SettingsLoaded event,
    Emitter<SettingsState> emit,
  ) async {
    emit(
      state.copyWith(
        isLoading: true,
        receiptPrinter: _printerStorage.receiptConfig,
        labelPrinter: _printerStorage.labelConfig,
        serverUrl: _authStorage.getServerUrl() ?? '',
      ),
    );

    try {
      final warehouses = await _settingsRepo.getWarehouses();
      final savedId = _authStorage.getWarehouseId();
      emit(
        state.copyWith(
          warehouses: warehouses,
          selectedWarehouseId: savedId,
          isLoading: false,
        ),
      );
      // Auto-discover printers if USB mode is configured
      if (state.receiptPrinter.connectionType == ConnectionType.usb ||
          state.labelPrinter.connectionType == ConnectionType.usb) {
        add(const PrinterDiscoveryRequested());
      }
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onWarehouseChanged(
    WarehouseChanged event,
    Emitter<SettingsState> emit,
  ) async {
    await _authStorage.saveWarehouseId(event.warehouseId);
    emit(state.copyWith(selectedWarehouseId: event.warehouseId));
  }

  Future<void> _onReceiptPrinterUpdated(
    ReceiptPrinterUpdated event,
    Emitter<SettingsState> emit,
  ) async {
    await _printerStorage.saveReceiptConfig(event.config);
    emit(state.copyWith(receiptPrinter: event.config));
  }

  Future<void> _onLabelPrinterUpdated(
    LabelPrinterUpdated event,
    Emitter<SettingsState> emit,
  ) async {
    await _printerStorage.saveLabelConfig(event.config);
    emit(state.copyWith(labelPrinter: event.config));
  }

  Future<void> _onPrinterTest(
    PrinterTestRequested event,
    Emitter<SettingsState> emit,
  ) async {
    emit(
      state.copyWith(
        isTesting: true,
        receiptTestResult: event.isLabel ? state.receiptTestResult : null,
        labelTestResult: event.isLabel ? null : state.labelTestResult,
      ),
    );
    try {
      final success = event.isLabel
          ? await _printerService.testLabelConnection(state.labelPrinter)
          : await _printerService.testConnection(state.receiptPrinter);
      final msg = success ? 'Уланиш муваффақиятли!' : 'Принтер топилмади';
      emit(
        state.copyWith(
          isTesting: false,
          receiptTestResult: event.isLabel ? state.receiptTestResult : msg,
          labelTestResult: event.isLabel ? msg : state.labelTestResult,
        ),
      );
    } catch (e) {
      final msg = 'Хатолик: $e';
      emit(
        state.copyWith(
          isTesting: false,
          receiptTestResult: event.isLabel ? state.receiptTestResult : msg,
          labelTestResult: event.isLabel ? msg : state.labelTestResult,
        ),
      );
    }
  }

  Future<void> _onPrintTestPage(
    PrintTestPageRequested event,
    Emitter<SettingsState> emit,
  ) async {
    emit(
      state.copyWith(
        isTesting: true,
        receiptTestResult: event.isLabel ? state.receiptTestResult : null,
        labelTestResult: event.isLabel ? null : state.labelTestResult,
      ),
    );
    try {
      if (event.isLabel) {
        await _printerService.printTestLabel(state.labelPrinter);
        emit(
          state.copyWith(
            isTesting: false,
            labelTestResult: 'Тест этикетка чоп этилди!',
          ),
        );
      } else {
        await _printerService.printTestPage(state.receiptPrinter);
        emit(
          state.copyWith(
            isTesting: false,
            receiptTestResult: 'Тест чек чоп этилди!',
          ),
        );
      }
    } catch (e) {
      final msg = 'Хатолик: $e';
      emit(
        state.copyWith(
          isTesting: false,
          receiptTestResult: event.isLabel ? state.receiptTestResult : msg,
          labelTestResult: event.isLabel ? msg : state.labelTestResult,
        ),
      );
    }
  }

  Future<void> _onPrinterDiscovery(
    PrinterDiscoveryRequested event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(isDiscovering: true));
    try {
      final results = await Future.wait([
        _printerService.listPrinters(),
        _printerService.listWindowsUsbPorts(),
      ]);
      emit(
        state.copyWith(
          isDiscovering: false,
          availablePrinters: results[0],
          availableUsbPorts: results[1],
        ),
      );
    } catch (e) {
      emit(state.copyWith(isDiscovering: false));
    }
  }

  Future<void> _onUsbPortDiscovery(
    UsbPortDiscoveryRequested event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(isDiscovering: true));
    try {
      final ports = await _printerService.listWindowsUsbPorts();
      emit(state.copyWith(isDiscovering: false, availableUsbPorts: ports));
    } catch (e) {
      emit(state.copyWith(isDiscovering: false));
    }
  }

  Future<void> _onServerUrlUpdated(
    ServerUrlUpdated event,
    Emitter<SettingsState> emit,
  ) async {
    await _authStorage.saveServerUrl(event.url);
    emit(state.copyWith(serverUrl: event.url));
  }
}
