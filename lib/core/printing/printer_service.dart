import 'dart:io';
import 'dart:typed_data';

import 'package:logging/logging.dart';

import 'esc_pos_commands.dart';
import 'label_templates.dart';
import 'printer_config.dart';
import 'text_bitmap_renderer.dart';
import 'tspl_commands.dart';
import 'win32_raw_printer.dart';

/// Result of a print operation.
class PrintResult {
  final bool success;
  final String? error;

  const PrintResult({required this.success, this.error});
}

/// Unified printer service for both receipt (ESC/POS) and label (TSPL) printing.
///
/// Handles transport: TCP socket, Win32 Spooler (Windows USB), CUPS/lpr
/// (macOS/Linux USB), or direct device file. Reuses [EscPosBuilder],
/// [TsplBuilder], and [Win32RawPrinter] from core/printing.
class PrinterService {
  static final _log = Logger('PrinterService');
  static const _connectTimeout = Duration(seconds: 5);

  // ── Discovery ─────────────────────────────────────────────────────

  /// Discover USB print ports registered with the Windows USB Monitor
  /// (e.g. USB001, USB002). Returns an empty list on non-Windows.
  Future<List<String>> listWindowsUsbPorts() async {
    if (!Platform.isWindows) return [];
    try {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        r"Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Print\Monitors\USB Monitor\Ports\*' -ErrorAction SilentlyContinue | ForEach-Object { $_.PSChildName }",
      ]);
      if (result.exitCode != 0) {
        _log.warning('USB Monitor registry query failed: ${result.stderr}');
        return [];
      }
      return (result.stdout as String)
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList()
        ..sort();
    } catch (e) {
      _log.warning('Failed to list Windows USB ports: $e');
      return [];
    }
  }

  /// List printers from OS spooler (Windows: Get-Printer, macOS/Linux: lpstat).
  Future<List<String>> listPrinters() async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run('powershell', [
          '-NoProfile',
          '-Command',
          'Get-Printer | Select-Object -ExpandProperty Name',
        ]);
        if (result.exitCode != 0) return [];
        return (result.stdout as String)
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList()
          ..sort();
      } else {
        final result = await Process.run('lpstat', ['-a']);
        if (result.exitCode != 0) return [];
        return (result.stdout as String)
            .split('\n')
            .where((l) => l.isNotEmpty)
            .map((l) => l.split(' ').first)
            .toList()
          ..sort();
      }
    } catch (e) {
      _log.warning('Failed to list printers: $e');
      return [];
    }
  }

  // ── Connection test ───────────────────────────────────────────────

  Future<bool> testConnection(PrinterConfig config) async {
    if (config.connectionType == ConnectionType.usb) {
      return _testUsb(config);
    }
    return _testNetwork(config.ip, config.port);
  }

  Future<bool> testLabelConnection(LabelPrinterConfig config) async {
    if (config.connectionType == ConnectionType.usb) {
      return _testUsb(
        PrinterConfig(
          connectionType: config.connectionType,
          usbMode: config.usbMode,
          cupsPrinterName: config.cupsPrinterName,
          devicePath: config.devicePath,
        ),
      );
    }
    return _testNetwork(config.ip, config.port);
  }

  Future<bool> _testNetwork(String ip, int port) async {
    try {
      final socket = await Socket.connect(ip, port, timeout: _connectTimeout);
      await socket.close();
      return true;
    } on SocketException {
      return false;
    }
  }

  Future<bool> _testUsb(PrinterConfig config) async {
    try {
      if (Platform.isWindows) {
        // On Windows, verify the printer queue exists in the spooler.
        String? queueName;
        if (config.usbMode == UsbMode.cups &&
            config.cupsPrinterName.isNotEmpty) {
          queueName = config.cupsPrinterName;
        } else if (config.devicePath.isNotEmpty) {
          queueName = await Win32RawPrinter.printerNameForPort(
            config.devicePath,
          );
        }
        if (queueName == null || queueName.isEmpty) {
          _log.info('USB test: no printer queue resolved');
          return false;
        }
        // Verify the queue name exists in the spooler
        final printers = await listPrinters();
        final found = printers.contains(queueName);
        _log.info(
          'USB test: "$queueName" ${found ? "found" : "not found"} in spooler',
        );
        return found;
      }

      // macOS / Linux
      if (config.usbMode == UsbMode.cups) {
        final printers = await listPrinters();
        final found = printers.contains(config.cupsPrinterName);
        _log.info(
          'CUPS test: "${config.cupsPrinterName}" ${found ? "found" : "not found"} in $printers',
        );
        return found;
      }
      final exists = File(config.devicePath).existsSync();
      _log.info('Device path test: "${config.devicePath}" exists=$exists');
      return exists;
    } catch (e) {
      _log.warning('USB test failed: $e');
      return false;
    }
  }

  // ── Receipt printing ──────────────────────────────────────────────

  /// Print raw ESC/POS bytes.
  Future<PrintResult> sendReceiptBytes(Uint8List bytes, PrinterConfig config) =>
      _send(bytes, config);

  /// Print a test receipt with bitmap Cyrillic rendering.
  Future<PrintResult> printTestPage(PrinterConfig config) async {
    final builder = EscPosBuilder(charsPerLine: config.charsPerLine)
      ..initialize();
    final dots = builder.paperWidthDots;

    // Title (ASCII — works on all printers)
    builder
      ..alignCenter()
      ..bold(true)
      ..setSize(CharSize.doubleAll)
      ..textLn('DIGITEX POS')
      ..setSize(CharSize.normal)
      ..bold(false)
      ..emptyLine()
      ..textLn('Printer Test Page')
      ..emptyLine()
      ..alignLeft()
      ..separator()
      ..row('Printer:', config.name)
      ..row('Connection:', config.connectionLabel)
      ..row('Paper:', config.paperWidth == PaperWidth.mm57 ? '57mm' : '80mm')
      ..separator()
      ..emptyLine()
      ..textLn('Latin: ABCDEFGabcdefg 0123456789');

    // Cyrillic lines rendered as bitmaps
    final cyrillicBmp = await TextBitmapRenderer.renderLine(
      'Кириллица: АБВГДЕЖЗабвгдежз',
      paperWidthDots: dots,
    );
    if (cyrillicBmp.height > 0) {
      builder.rasterImage(
        cyrillicBmp.widthBytes,
        cyrillicBmp.height,
        cyrillicBmp.data,
      );
    }
    final uzbekBmp = await TextBitmapRenderer.renderLine(
      'Ўзбекча: Ғ Қ Ҳ Ў ғ қ ҳ ў',
      paperWidthDots: dots,
    );
    if (uzbekBmp.height > 0) {
      builder.rasterImage(uzbekBmp.widthBytes, uzbekBmp.height, uzbekBmp.data);
    }

    builder
      ..emptyLine()
      ..separator()
      ..alignCenter()
      ..textLn('Test completed!')
      ..textLn(DateTime.now().toString().substring(0, 19))
      ..feed(4)
      ..cut();
    return _send(builder.bytes, config);
  }

  // ── Label printing ────────────────────────────────────────────────

  /// Print barcode labels for products.
  Future<PrintResult> printLabels(
    List<Map<String, dynamic>> products,
    LabelPrinterConfig config, {
    LabelTemplate? template,
  }) async {
    if (!config.isConfigured) {
      return const PrintResult(
        success: false,
        error: 'Label printer not configured',
      );
    }
    if (products.isEmpty) {
      return const PrintResult(success: false, error: 'No products to print');
    }

    final allBytes = <int>[];
    for (final p in products) {
      final name = (p['name'] as String?) ?? '';
      final price = (p['price'] as String?) ?? '';

      // Pre-render Cyrillic-capable text as bitmaps
      final truncName = name.length > 28 ? '${name.substring(0, 28)}..' : name;
      final nameFontSize = template?.nameFontSize.toDouble() ?? 20.0;
      final priceFontSize = template?.priceFontSize.toDouble() ?? 20.0;
      BitmapData? nameBitmap;
      BitmapData? priceBitmap;
      try {
        if (_hasNonAscii(truncName)) {
          nameBitmap = await TextBitmapRenderer.render(
            truncName,
            fontSize: nameFontSize,
          );
        }
        if (_hasNonAscii(price)) {
          priceBitmap = await TextBitmapRenderer.render(
            price,
            fontSize: priceFontSize,
            bold: true,
          );
        }
      } catch (e) {
        _log.warning('Bitmap text render failed, using TEXT fallback: $e');
      }

      if (template != null) {
        allBytes.addAll(
          TsplBuilder.buildLabelFromTemplate(
            labelWidth: config.labelWidth,
            labelHeight: config.labelHeight,
            printSpeed: config.speed,
            printDensity: config.density,
            productName: name,
            price: price,
            template: template,
            nameBitmap: nameBitmap,
            priceBitmap: priceBitmap,
          ),
        );
      } else {
        allBytes.addAll(
          TsplBuilder.buildLabel(
            labelWidth: config.labelWidth,
            labelHeight: config.labelHeight,
            printSpeed: config.speed,
            printDensity: config.density,
            productName: name,
            price: price,
            nameBitmap: nameBitmap,
            priceBitmap: priceBitmap,
          ),
        );
      }
    }

    return _sendLabel(Uint8List.fromList(allBytes), config);
  }

  static bool _hasNonAscii(String s) => s.runes.any((r) => r > 0x7E);

  /// Print a test label.
  Future<PrintResult> printTestLabel(LabelPrinterConfig config) {
    return printLabels([
      {'name': 'Test Product', 'price': '10 000 UZS'},
    ], config);
  }

  // ── Transport ─────────────────────────────────────────────────────

  Future<PrintResult> _send(Uint8List bytes, PrinterConfig config) {
    if (config.connectionType == ConnectionType.usb) {
      return _sendUsb(bytes, config);
    }
    return _sendNetwork(bytes, config.ip, config.port);
  }

  Future<PrintResult> _sendLabel(Uint8List bytes, LabelPrinterConfig config) {
    if (config.connectionType == ConnectionType.usb) {
      return _sendUsb(
        bytes,
        PrinterConfig(
          connectionType: config.connectionType,
          usbMode: config.usbMode,
          cupsPrinterName: config.cupsPrinterName,
          devicePath: config.devicePath,
        ),
      );
    }
    return _sendNetwork(bytes, config.ip, config.port);
  }

  Future<PrintResult> _sendNetwork(Uint8List bytes, String ip, int port) async {
    Socket? socket;
    try {
      socket = await Socket.connect(ip, port, timeout: _connectTimeout);
      socket.add(bytes);
      await socket.flush();
      return const PrintResult(success: true);
    } on SocketException catch (e) {
      return PrintResult(
        success: false,
        error: 'Connection failed: ${e.message}',
      );
    } catch (e) {
      return PrintResult(success: false, error: 'Print error: $e');
    } finally {
      try {
        await socket?.close();
      } catch (_) {}
    }
  }

  Future<PrintResult> _sendUsb(Uint8List bytes, PrinterConfig config) async {
    if (Platform.isWindows) {
      return _sendWin32(bytes, config);
    }
    if (config.usbMode == UsbMode.cups) {
      return _sendCupsLpr(bytes, config.cupsPrinterName);
    }
    // Direct device file write
    try {
      await File(config.devicePath).writeAsBytes(bytes, mode: FileMode.append);
      return const PrintResult(success: true);
    } catch (e) {
      return PrintResult(success: false, error: 'USB print error: $e');
    }
  }

  Future<PrintResult> _sendWin32(Uint8List bytes, PrinterConfig config) async {
    final printerName = await _resolveWinPrinterName(config);
    if (printerName == null || printerName.isEmpty) {
      return const PrintResult(
        success: false,
        error: 'Printer name not resolved',
      );
    }

    const maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      final result = Win32RawPrinter.sendRawData(printerName, bytes);
      if (result.success) return const PrintResult(success: true);

      _log.warning(
        'Print attempt $attempt/$maxAttempts failed: ${result.error}',
      );
      if (attempt < maxAttempts) {
        await Future<void>.delayed(Duration(milliseconds: 300 * attempt));
      } else {
        return PrintResult(
          success: false,
          error: result.error ?? 'Print failed',
        );
      }
    }
    return const PrintResult(
      success: false,
      error: 'All print attempts failed',
    );
  }

  Future<PrintResult> _sendCupsLpr(Uint8List bytes, String printerName) async {
    try {
      final tmpDir = await Directory.systemTemp.createTemp('pos_print_');
      final tmpFile = File('${tmpDir.path}/receipt.bin');
      await tmpFile.writeAsBytes(bytes);

      final result = await Process.run('lpr', [
        '-P',
        printerName,
        '-o',
        'raw',
        tmpFile.path,
      ]);
      await tmpFile.delete();
      await tmpDir.delete();

      if (result.exitCode != 0) {
        return PrintResult(
          success: false,
          error: 'CUPS lpr error: ${result.stderr}',
        );
      }
      return const PrintResult(success: true);
    } catch (e) {
      return PrintResult(success: false, error: 'CUPS print error: $e');
    }
  }

  Future<String?> _resolveWinPrinterName(PrinterConfig config) async {
    if (config.usbMode == UsbMode.cups && config.cupsPrinterName.isNotEmpty) {
      return config.cupsPrinterName;
    }
    if (config.devicePath.isNotEmpty) {
      return Win32RawPrinter.printerNameForPort(config.devicePath);
    }
    return null;
  }
}
