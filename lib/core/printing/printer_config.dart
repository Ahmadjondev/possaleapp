import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Printer connection type.
enum ConnectionType { network, usb }

/// USB printing mode.
enum UsbMode { cups, file }

/// Paper width for receipt printers.
enum PaperWidth { mm57, mm80 }

/// Receipt printer configuration (ESC/POS thermal printers).
class PrinterConfig {
  final String name;
  final String ip;
  final int port;
  final PaperWidth paperWidth;
  final int codepage;
  final ConnectionType connectionType;
  final UsbMode usbMode;
  final String cupsPrinterName;
  final String devicePath;

  const PrinterConfig({
    this.name = 'Receipt Printer',
    this.ip = '',
    this.port = 9100,
    this.paperWidth = PaperWidth.mm80,
    this.codepage = 17,
    this.connectionType = ConnectionType.usb,
    this.usbMode = UsbMode.cups,
    this.cupsPrinterName = '',
    this.devicePath = '',
  });

  int get charsPerLine => paperWidth == PaperWidth.mm57 ? 32 : 48;

  bool get isConfigured {
    if (connectionType == ConnectionType.network) return ip.isNotEmpty;
    if (usbMode == UsbMode.cups) return cupsPrinterName.isNotEmpty;
    return devicePath.isNotEmpty;
  }

  String get connectionLabel {
    if (connectionType == ConnectionType.network) return 'LAN $ip:$port';
    if (usbMode == UsbMode.cups) return 'USB "$cupsPrinterName"';
    return 'USB $devicePath';
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'ip': ip,
    'port': port,
    'paperWidth': paperWidth.name,
    'codepage': codepage,
    'connectionType': connectionType.name,
    'usbMode': usbMode.name,
    'cupsPrinterName': cupsPrinterName,
    'devicePath': devicePath,
  };

  factory PrinterConfig.fromJson(Map<String, dynamic> json) => PrinterConfig(
    name: json['name'] as String? ?? 'Receipt Printer',
    ip: json['ip'] as String? ?? '',
    port: json['port'] as int? ?? 9100,
    paperWidth: PaperWidth.values.firstWhere(
      (e) => e.name == json['paperWidth'],
      orElse: () => PaperWidth.mm80,
    ),
    codepage: json['codepage'] as int? ?? 17,
    connectionType: ConnectionType.values.firstWhere(
      (e) => e.name == json['connectionType'],
      orElse: () => ConnectionType.usb,
    ),
    usbMode: UsbMode.values.firstWhere(
      (e) => e.name == json['usbMode'],
      orElse: () => UsbMode.cups,
    ),
    cupsPrinterName: json['cupsPrinterName'] as String? ?? '',
    devicePath: json['devicePath'] as String? ?? '',
  );

  PrinterConfig copyWith({
    String? name,
    String? ip,
    int? port,
    PaperWidth? paperWidth,
    int? codepage,
    ConnectionType? connectionType,
    UsbMode? usbMode,
    String? cupsPrinterName,
    String? devicePath,
  }) => PrinterConfig(
    name: name ?? this.name,
    ip: ip ?? this.ip,
    port: port ?? this.port,
    paperWidth: paperWidth ?? this.paperWidth,
    codepage: codepage ?? this.codepage,
    connectionType: connectionType ?? this.connectionType,
    usbMode: usbMode ?? this.usbMode,
    cupsPrinterName: cupsPrinterName ?? this.cupsPrinterName,
    devicePath: devicePath ?? this.devicePath,
  );
}

/// Label printer configuration (TSPL barcode printers).
class LabelPrinterConfig {
  final String name;
  final String ip;
  final int port;
  final ConnectionType connectionType;
  final UsbMode usbMode;
  final String cupsPrinterName;
  final String devicePath;
  final int labelWidth;
  final int labelHeight;
  final int speed;
  final int density;
  final int defaultTemplateId;

  const LabelPrinterConfig({
    this.name = 'Barcode Printer',
    this.ip = '',
    this.port = 9100,
    this.connectionType = ConnectionType.usb,
    this.usbMode = UsbMode.cups,
    this.cupsPrinterName = '',
    this.devicePath = '',
    this.labelWidth = 57,
    this.labelHeight = 40,
    this.speed = 4,
    this.density = 8,
    this.defaultTemplateId = 0,
  });

  bool get isConfigured {
    if (connectionType == ConnectionType.network) return ip.isNotEmpty;
    if (usbMode == UsbMode.cups) return cupsPrinterName.isNotEmpty;
    return devicePath.isNotEmpty;
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'ip': ip,
    'port': port,
    'connectionType': connectionType.name,
    'usbMode': usbMode.name,
    'cupsPrinterName': cupsPrinterName,
    'devicePath': devicePath,
    'labelWidth': labelWidth,
    'labelHeight': labelHeight,
    'speed': speed,
    'density': density,
    'defaultTemplateId': defaultTemplateId,
  };

  factory LabelPrinterConfig.fromJson(Map<String, dynamic> json) =>
      LabelPrinterConfig(
        name: json['name'] as String? ?? 'Barcode Printer',
        ip: json['ip'] as String? ?? '',
        port: json['port'] as int? ?? 9100,
        connectionType: ConnectionType.values.firstWhere(
          (e) => e.name == json['connectionType'],
          orElse: () => ConnectionType.usb,
        ),
        usbMode: UsbMode.values.firstWhere(
          (e) => e.name == json['usbMode'],
          orElse: () => UsbMode.cups,
        ),
        cupsPrinterName: json['cupsPrinterName'] as String? ?? '',
        devicePath: json['devicePath'] as String? ?? '',
        labelWidth: json['labelWidth'] as int? ?? 57,
        labelHeight: json['labelHeight'] as int? ?? 40,
        speed: json['speed'] as int? ?? 4,
        density: json['density'] as int? ?? 8,
        defaultTemplateId: json['defaultTemplateId'] as int? ?? 0,
      );

  LabelPrinterConfig copyWith({
    String? name,
    String? ip,
    int? port,
    ConnectionType? connectionType,
    UsbMode? usbMode,
    String? cupsPrinterName,
    String? devicePath,
    int? labelWidth,
    int? labelHeight,
    int? speed,
    int? density,
    int? defaultTemplateId,
  }) => LabelPrinterConfig(
    name: name ?? this.name,
    ip: ip ?? this.ip,
    port: port ?? this.port,
    connectionType: connectionType ?? this.connectionType,
    usbMode: usbMode ?? this.usbMode,
    cupsPrinterName: cupsPrinterName ?? this.cupsPrinterName,
    devicePath: devicePath ?? this.devicePath,
    labelWidth: labelWidth ?? this.labelWidth,
    labelHeight: labelHeight ?? this.labelHeight,
    speed: speed ?? this.speed,
    density: density ?? this.density,
    defaultTemplateId: defaultTemplateId ?? this.defaultTemplateId,
  );
}

/// Persists printer configurations via SharedPreferences.
class PrinterConfigStorage {
  static const _keyReceipt = 'printer_config';
  static const _keyLabel = 'label_printer_config';
  static const _keySetupCompleted = 'pos_setup_completed';

  final SharedPreferences _prefs;

  PrinterConfigStorage(this._prefs);

  /// Whether first-time setup wizard has been completed.
  bool get isSetupCompleted => _prefs.getBool(_keySetupCompleted) ?? false;

  Future<void> markSetupCompleted() => _prefs.setBool(_keySetupCompleted, true);

  Future<void> resetSetup() => _prefs.setBool(_keySetupCompleted, false);

  PrinterConfig get receiptConfig {
    final raw = _prefs.getString(_keyReceipt);
    if (raw == null) return const PrinterConfig();
    try {
      return PrinterConfig.fromJson(json.decode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const PrinterConfig();
    }
  }

  Future<void> saveReceiptConfig(PrinterConfig config) =>
      _prefs.setString(_keyReceipt, json.encode(config.toJson()));

  LabelPrinterConfig get labelConfig {
    final raw = _prefs.getString(_keyLabel);
    if (raw == null) return const LabelPrinterConfig();
    try {
      return LabelPrinterConfig.fromJson(
        json.decode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return const LabelPrinterConfig();
    }
  }

  Future<void> saveLabelConfig(LabelPrinterConfig config) =>
      _prefs.setString(_keyLabel, json.encode(config.toJson()));
}
