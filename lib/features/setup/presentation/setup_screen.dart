import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:pos_terminal/core/constants/app_colors.dart';
import 'package:pos_terminal/core/printing/printer_config.dart';
import 'package:pos_terminal/core/printing/printer_service.dart';
import 'package:pos_terminal/features/auth/data/auth_local_storage.dart';
import 'package:pos_terminal/core/constants/app_colors_extension.dart';

/// First-time setup wizard shown before login.
///
/// Steps:
///   0 — Server URL
///   1 — Receipt printer
///   2 — Label printer (optional)
///   3 — Finish
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  int _step = 0;
  static const _totalSteps = 4;

  // ── Step 0: Server ──
  final _serverUrlController = TextEditingController(text: 'https://');
  bool _serverTesting = false;
  String? _serverStatus;
  bool _serverOk = false;

  // ── Step 1: Receipt printer ──
  var _receiptConfig = const PrinterConfig();
  final _receiptIpController = TextEditingController();
  final _receiptPortController = TextEditingController(text: '9100');
  bool _receiptTesting = false;
  String? _receiptStatus;

  // ── Step 2: Label printer ──
  bool _enableLabel = false;
  var _labelConfig = const LabelPrinterConfig();
  final _labelIpController = TextEditingController();
  final _labelPortController = TextEditingController(text: '9100');
  bool _labelTesting = false;
  String? _labelStatus;

  // ── Services ──
  final _printerService = GetIt.I<PrinterService>();
  final _configStorage = GetIt.I<PrinterConfigStorage>();
  final _authStorage = GetIt.I<AuthLocalStorage>();

  // Discovered printers
  List<String> _osPrinters = [];
  bool _loadingPrinters = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  void _loadExisting() {
    final savedUrl = _authStorage.getServerUrl();
    if (savedUrl != null && savedUrl.isNotEmpty) {
      _serverUrlController.text = savedUrl;
    }
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _receiptIpController.dispose();
    _receiptPortController.dispose();
    _labelIpController.dispose();
    _labelPortController.dispose();
    super.dispose();
  }

  // ── Navigation ──
  void _next() {
    if (_step < _totalSteps - 1) setState(() => _step++);
  }

  void _prev() {
    if (_step > 0) setState(() => _step--);
  }

  Future<void> _finish() async {
    // Save server URL
    await _authStorage.saveServerUrl(_serverUrlController.text.trim());

    // Save printer configs
    await _configStorage.saveReceiptConfig(_receiptConfig);
    if (_enableLabel) {
      await _configStorage.saveLabelConfig(_labelConfig);
    }

    // Mark setup complete
    await _configStorage.markSetupCompleted();

    if (!mounted) return;
    // Navigate to login — GoRouter redirect will allow it now
    context.go('/login');
  }

  // ── Server test ──
  Future<void> _testServer() async {
    final url = _serverUrlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _serverTesting = true;
      _serverStatus = null;
      _serverOk = false;
    });

    try {
      final uri = Uri.parse(url);
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5);
      final request = await client.headUrl(
        uri.replace(path: '/api/auth/token/'),
      );
      final response = await request.close();
      await response.drain<void>();
      client.close();

      if (!mounted) return;
      final ok = response.statusCode < 500;
      setState(() {
        _serverOk = ok;
        _serverStatus = ok
            ? 'Connected (HTTP ${response.statusCode})'
            : 'Server error (${response.statusCode})';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _serverOk = false;
        _serverStatus = 'Failed: ${e.toString().split('\n').first}';
      });
    } finally {
      if (mounted) setState(() => _serverTesting = false);
    }
  }

  // ── Printer discovery ──
  Future<void> _discoverPrinters() async {
    setState(() => _loadingPrinters = true);
    final printers = await _printerService.listPrinters();
    if (mounted) {
      setState(() {
        _osPrinters = printers;
        _loadingPrinters = false;
      });
    }
  }

  // ── Printer test ──
  Future<void> _testReceiptPrinter() async {
    _syncReceiptConfig();
    setState(() {
      _receiptTesting = true;
      _receiptStatus = null;
    });
    final result = await _printerService.printTestPage(_receiptConfig);
    if (mounted) {
      setState(() {
        _receiptTesting = false;
        _receiptStatus = result.success
            ? 'Test page sent!'
            : 'Error: ${result.error}';
      });
    }
  }

  Future<void> _testLabelPrinter() async {
    _syncLabelConfig();
    setState(() {
      _labelTesting = true;
      _labelStatus = null;
    });
    final result = await _printerService.printTestLabel(_labelConfig);
    if (mounted) {
      setState(() {
        _labelTesting = false;
        _labelStatus = result.success
            ? 'Test label sent!'
            : 'Error: ${result.error}';
      });
    }
  }

  void _syncReceiptConfig() {
    _receiptConfig = _receiptConfig.copyWith(
      ip: _receiptIpController.text.trim(),
      port: int.tryParse(_receiptPortController.text) ?? 9100,
    );
  }

  void _syncLabelConfig() {
    _labelConfig = _labelConfig.copyWith(
      ip: _labelIpController.text.trim(),
      port: int.tryParse(_labelPortController.text) ?? 9100,
    );
  }

  // ──────────────────────────────────────────── BUILD ──

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildStepper(),
            Expanded(child: _buildStepContent()),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: context.colors.surface,
      child: Row(
        children: [
          Icon(Icons.settings_outlined, color: AppColors.accent, size: 24),
          SizedBox(width: 12),
          Text(
            'POS Terminal Setup',
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepper() {
    const labels = ['Server', 'Receipt Printer', 'Label Printer', 'Finish'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: context.colors.surface,
      child: Row(
        children: List.generate(labels.length, (i) {
          final active = i == _step;
          final done = i < _step;
          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done
                        ? AppColors.success
                        : active
                        ? AppColors.accent
                        : context.colors.surfaceLight,
                  ),
                  child: Center(
                    child: done
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: active
                                  ? Colors.white
                                  : context.colors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: active
                          ? context.colors.textPrimary
                          : context.colors.textSecondary,
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (i < labels.length - 1)
                  Expanded(
                    child: Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: done ? AppColors.success : context.colors.border,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: switch (_step) {
          0 => _buildServerStep(),
          1 => _buildReceiptStep(),
          2 => _buildLabelStep(),
          3 => _buildFinishStep(),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: context.colors.surface,
      child: Row(
        children: [
          if (_step > 0)
            OutlinedButton.icon(
              onPressed: _prev,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Back'),
            ),
          const Spacer(),
          if (_step < _totalSteps - 1)
            ElevatedButton.icon(
              onPressed: _canProceed() ? _next : null,
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: Text(_step == 2 ? 'Next' : 'Continue'),
            ),
          if (_step == _totalSteps - 1)
            ElevatedButton.icon(
              onPressed: _finish,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Complete Setup'),
            ),
        ],
      ),
    );
  }

  bool _canProceed() {
    switch (_step) {
      case 0:
        return _serverUrlController.text.trim().isNotEmpty;
      default:
        return true;
    }
  }

  // ────────────────────────────────── STEP 0: SERVER ──

  Widget _buildServerStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Server Connection',
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the backend server URL for this POS terminal.',
          style: TextStyle(color: context.colors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 24),

        TextFormField(
          controller: _serverUrlController,
          decoration: InputDecoration(
            labelText: 'Server URL',
            hintText: 'https://demo.digitex.uz',
            prefixIcon: const Icon(Icons.dns_outlined),
            suffixIcon: _serverTesting
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Test connection',
                    onPressed: _testServer,
                  ),
          ),
          keyboardType: TextInputType.url,
          onChanged: (_) => setState(() {
            _serverOk = false;
            _serverStatus = null;
          }),
        ),
        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _serverTesting ? null : _testServer,
            icon: _serverTesting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_tethering, size: 18),
            label: Text(_serverTesting ? 'Testing...' : 'Test Connection'),
          ),
        ),

        if (_serverStatus != null) ...[
          const SizedBox(height: 12),
          _statusChip(_serverStatus!, _serverOk),
        ],
      ],
    );
  }

  // ──────────────────────────────── STEP 1: RECEIPT ──

  Widget _buildReceiptStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Receipt Printer',
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Configure the thermal receipt printer. You can skip this and set it up later.',
          style: TextStyle(color: context.colors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 24),

        // Connection type
        _sectionLabel('Connection Type'),
        const SizedBox(height: 8),
        _segmented<ConnectionType>(
          value: _receiptConfig.connectionType,
          items: const {
            ConnectionType.network: 'Network (LAN)',
            ConnectionType.usb: 'USB',
          },
          onChanged: (v) => setState(
            () => _receiptConfig = _receiptConfig.copyWith(connectionType: v),
          ),
        ),
        const SizedBox(height: 16),

        // Network fields
        if (_receiptConfig.connectionType == ConnectionType.network) ...[
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _receiptIpController,
                  decoration: const InputDecoration(
                    labelText: 'IP Address',
                    hintText: '192.168.1.100',
                    prefixIcon: Icon(Icons.lan_outlined),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: TextFormField(
                  controller: _receiptPortController,
                  decoration: const InputDecoration(labelText: 'Port'),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
        ],

        // USB fields
        if (_receiptConfig.connectionType == ConnectionType.usb) ...[
          if (Platform.isMacOS || Platform.isLinux) ...[
            _sectionLabel('USB Mode'),
            const SizedBox(height: 8),
            _segmented<UsbMode>(
              value: _receiptConfig.usbMode,
              items: const {
                UsbMode.cups: 'CUPS (Recommended)',
                UsbMode.file: 'Direct Device File',
              },
              onChanged: (v) => setState(
                () => _receiptConfig = _receiptConfig.copyWith(usbMode: v),
              ),
            ),
            const SizedBox(height: 16),
          ],
          _buildUsbPrinterSelector(
            config: _receiptConfig,
            onSelect: (name) => setState(
              () => _receiptConfig = _receiptConfig.copyWith(
                cupsPrinterName: name,
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Paper width
        _sectionLabel('Paper Width'),
        const SizedBox(height: 8),
        _segmented<PaperWidth>(
          value: _receiptConfig.paperWidth,
          items: const {
            PaperWidth.mm80: '80mm (Standard)',
            PaperWidth.mm57: '57mm (Narrow)',
          },
          onChanged: (v) => setState(
            () => _receiptConfig = _receiptConfig.copyWith(paperWidth: v),
          ),
        ),
        const SizedBox(height: 24),

        // Test button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _receiptTesting ? null : _testReceiptPrinter,
            icon: _receiptTesting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.print_outlined, size: 18),
            label: Text(_receiptTesting ? 'Printing...' : 'Print Test Receipt'),
          ),
        ),

        if (_receiptStatus != null) ...[
          const SizedBox(height: 12),
          _statusChip(_receiptStatus!, _receiptStatus!.contains('sent')),
        ],
      ],
    );
  }

  // ────────────────────────────────── STEP 2: LABEL ──

  Widget _buildLabelStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Label / Barcode Printer',
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Optional — configure if you use a barcode label printer (e.g. Xprinter XP-365B).',
          style: TextStyle(color: context.colors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 16),

        SwitchListTile(
          title: Text(
            'Enable label printer',
            style: TextStyle(color: context.colors.textPrimary),
          ),
          value: _enableLabel,
          activeTrackColor: AppColors.accent,
          onChanged: (v) => setState(() => _enableLabel = v),
          contentPadding: EdgeInsets.zero,
        ),

        if (_enableLabel) ...[
          const SizedBox(height: 16),

          _sectionLabel('Connection Type'),
          const SizedBox(height: 8),
          _segmented<ConnectionType>(
            value: _labelConfig.connectionType,
            items: const {
              ConnectionType.network: 'Network (LAN)',
              ConnectionType.usb: 'USB',
            },
            onChanged: (v) => setState(
              () => _labelConfig = _labelConfig.copyWith(connectionType: v),
            ),
          ),
          const SizedBox(height: 16),

          if (_labelConfig.connectionType == ConnectionType.network) ...[
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _labelIpController,
                    decoration: const InputDecoration(
                      labelText: 'IP Address',
                      hintText: '192.168.1.101',
                      prefixIcon: Icon(Icons.lan_outlined),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _labelPortController,
                    decoration: const InputDecoration(labelText: 'Port'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ],

          if (_labelConfig.connectionType == ConnectionType.usb) ...[
            if (Platform.isMacOS || Platform.isLinux) ...[
              _sectionLabel('USB Mode'),
              const SizedBox(height: 8),
              _segmented<UsbMode>(
                value: _labelConfig.usbMode,
                items: const {
                  UsbMode.cups: 'CUPS (Recommended)',
                  UsbMode.file: 'Direct Device File',
                },
                onChanged: (v) => setState(
                  () => _labelConfig = _labelConfig.copyWith(usbMode: v),
                ),
              ),
              const SizedBox(height: 16),
            ],
            _buildUsbPrinterSelector(
              config: null,
              labelConfig: _labelConfig,
              onSelect: (name) => setState(
                () =>
                    _labelConfig = _labelConfig.copyWith(cupsPrinterName: name),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Label size
          _sectionLabel('Label Size (mm)'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildSmallField(
                  label: 'Width',
                  value: '${_labelConfig.labelWidth}',
                  onChanged: (v) => setState(
                    () => _labelConfig = _labelConfig.copyWith(
                      labelWidth: int.tryParse(v),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '×',
                style: TextStyle(color: context.colors.textSecondary, fontSize: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSmallField(
                  label: 'Height',
                  value: '${_labelConfig.labelHeight}',
                  onChanged: (v) => setState(
                    () => _labelConfig = _labelConfig.copyWith(
                      labelHeight: int.tryParse(v),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Test button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _labelTesting ? null : _testLabelPrinter,
              icon: _labelTesting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.label_outlined, size: 18),
              label: Text(_labelTesting ? 'Printing...' : 'Print Test Label'),
            ),
          ),

          if (_labelStatus != null) ...[
            const SizedBox(height: 12),
            _statusChip(_labelStatus!, _labelStatus!.contains('sent')),
          ],
        ],
      ],
    );
  }

  // ──────────────────────────────────── STEP 3: FINISH ──

  Widget _buildFinishStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.check_circle_outline,
          color: AppColors.success,
          size: 48,
        ),
        const SizedBox(height: 16),
        Text(
          'Setup Complete',
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Review your configuration below. You can always change these settings later.',
          style: TextStyle(color: context.colors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 24),

        _summaryTile(
          Icons.dns_outlined,
          'Server',
          _serverUrlController.text.trim(),
        ),
        const SizedBox(height: 12),
        _summaryTile(
          Icons.receipt_long_outlined,
          'Receipt Printer',
          _receiptConfig.isConfigured
              ? _receiptConfig.connectionLabel
              : 'Not configured (skip)',
        ),
        const SizedBox(height: 12),
        _summaryTile(
          Icons.label_outlined,
          'Label Printer',
          _enableLabel && _labelConfig.isConfigured
              ? 'Enabled — ${_labelConfig.connectionType == ConnectionType.network ? "LAN ${_labelConfig.ip}" : "USB"}'
              : 'Disabled',
        ),
      ],
    );
  }

  // ──────────────────────────────────── WIDGETS ──

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: context.colors.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _segmented<T>({
    required T value,
    required Map<T, String> items,
    required ValueChanged<T> onChanged,
  }) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<T>(
        segments: items.entries
            .map((e) => ButtonSegment<T>(value: e.key, label: Text(e.value)))
            .toList(),
        selected: {value},
        onSelectionChanged: (s) => onChanged(s.first),
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.accent;
            }
            return context.colors.surfaceLight;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return context.colors.textSecondary;
          }),
        ),
      ),
    );
  }

  Widget _statusChip(String text, bool ok) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: (ok ? AppColors.success : AppColors.danger).withValues(
          alpha: 0.1,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (ok ? AppColors.success : AppColors.danger).withValues(
            alpha: 0.3,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_outline : Icons.error_outline,
            size: 18,
            color: ok ? AppColors.success : AppColors.danger,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: ok ? AppColors.success : AppColors.danger,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsbPrinterSelector({
    PrinterConfig? config,
    LabelPrinterConfig? labelConfig,
    required ValueChanged<String> onSelect,
  }) {
    final selectedName =
        config?.cupsPrinterName ?? labelConfig?.cupsPrinterName ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _sectionLabel(
                Platform.isWindows ? 'Printer Name' : 'CUPS Printer',
              ),
            ),
            TextButton.icon(
              onPressed: _loadingPrinters ? null : _discoverPrinters,
              icon: _loadingPrinters
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search, size: 16),
              label: Text(_loadingPrinters ? 'Searching...' : 'Discover'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_osPrinters.isEmpty)
          TextFormField(
            initialValue: selectedName,
            decoration: InputDecoration(
              hintText: Platform.isWindows
                  ? 'Printer queue name'
                  : 'e.g. EPSON_TM_T20III',
              prefixIcon: const Icon(Icons.print_outlined),
            ),
            onChanged: onSelect,
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _osPrinters.map((name) {
              final selected = name == selectedName;
              return ChoiceChip(
                label: Text(name),
                selected: selected,
                onSelected: (_) => onSelect(name),
                selectedColor: AppColors.accent,
                backgroundColor: context.colors.surfaceLight,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : context.colors.textSecondary,
                  fontSize: 13,
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildSmallField({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return TextFormField(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      keyboardType: TextInputType.number,
      onChanged: onChanged,
    );
  }

  Widget _summaryTile(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
