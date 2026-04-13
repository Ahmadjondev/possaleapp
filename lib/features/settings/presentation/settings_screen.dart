import 'dart:io' show Platform, exit;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:pos_terminal/core/constants/app_colors.dart';
import 'package:pos_terminal/core/di/injection.dart';
import 'package:pos_terminal/core/printing/printer_config.dart';
import 'package:pos_terminal/core/printing/printer_service.dart';
import 'package:pos_terminal/core/theme/theme_cubit.dart';
import 'package:pos_terminal/features/auth/data/auth_local_storage.dart';
import 'package:pos_terminal/features/auth/domain/user_model.dart';
import 'package:pos_terminal/features/settings/data/settings_repository.dart';
import 'package:pos_terminal/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:pos_terminal/core/constants/app_colors_extension.dart';

enum _SettingsSection { general, printer, system }

class SettingsScreen extends StatelessWidget {
  final UserModel user;

  const SettingsScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SettingsBloc(
        settingsRepository: getIt<SettingsRepository>(),
        printerStorage: getIt<PrinterConfigStorage>(),
        printerService: getIt<PrinterService>(),
        authStorage: getIt<AuthLocalStorage>(),
      )..add(const SettingsLoaded()),
      child: _SettingsBody(user: user),
    );
  }
}

class _SettingsBody extends StatefulWidget {
  final UserModel user;
  const _SettingsBody({required this.user});

  @override
  State<_SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends State<_SettingsBody> {
  _SettingsSection _section = _SettingsSection.general;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: Column(
        children: [
          _buildTopBar(context),
          Expanded(
            child: Row(
              children: [
                _buildSidebar(),
                Container(width: 1, color: context.colors.border),
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: context.colors.surface,
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: context.colors.textSecondary,
              size: 20,
            ),
            tooltip: 'Орқага',
            onPressed: () => context.pop(),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.settings, color: AppColors.accent, size: 20),
          const SizedBox(width: 8),
          Text(
            'Созламалар',
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            widget.user.displayName,
            style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 220,
      color: context.colors.surface,
      child: Column(
        children: [
          const SizedBox(height: 8),
          _sidebarItem(
            icon: Icons.tune,
            label: 'Умумий',
            section: _SettingsSection.general,
          ),
          _sidebarItem(
            icon: Icons.print,
            label: 'Принтер',
            section: _SettingsSection.printer,
          ),
          _sidebarItem(
            icon: Icons.dns_outlined,
            label: 'Тизим',
            section: _SettingsSection.system,
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem({
    required IconData icon,
    required String label,
    required _SettingsSection section,
  }) {
    final selected = _section == section;
    return Material(
      color: selected
          ? AppColors.accent.withValues(alpha: 0.15)
          : Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _section = section),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: selected ? AppColors.accent : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? AppColors.accent
                    : context.colors.textSecondary,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? context.colors.textPrimary
                      : context.colors.textSecondary,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return switch (_section) {
      _SettingsSection.general => _GeneralSection(user: widget.user),
      _SettingsSection.printer => const _PrinterSection(),
      _SettingsSection.system => const _SystemSection(),
    };
  }
}

// ═══════════════════════════════════════════════════════════════════
//  GENERAL SECTION — warehouse selector
// ═══════════════════════════════════════════════════════════════════

class _GeneralSection extends StatelessWidget {
  final UserModel user;
  const _GeneralSection({required this.user});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        // Show warehouse picker only when user has no fixed warehouse
        // (defaultWarehouseId == null means admin with "all" scope)
        final showWarehouse =
            user.defaultWarehouseId == null || state.warehouses.length > 1;

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const _SectionHeader(title: 'Умумий созламалар'),
            const SizedBox(height: 16),
            if (showWarehouse) ...[
              _WarehouseTile(
                warehouses: state.warehouses,
                selectedId:
                    state.selectedWarehouseId ?? user.defaultWarehouseId,
                isLoading: state.isLoading,
              ),
              const SizedBox(height: 12),
            ],
            const _ThemeTile(),
            const SizedBox(height: 12),
            if (state.error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  state.error!,
                  style: const TextStyle(color: AppColors.danger, fontSize: 12),
                ),
              ),
              const SizedBox(height: 12),
            ],
            _SettingsTile(
              icon: Icons.business,
              title: 'Бизнес',
              subtitle: user.businessName ?? '—',
              child: const SizedBox.shrink(),
            ),
            const SizedBox(height: 12),
            _SettingsTile(
              icon: Icons.person_outline,
              title: 'Фойдаланувчи',
              subtitle: '${user.displayName} (${user.role})',
              child: const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }
}

class _WarehouseTile extends StatelessWidget {
  final List warehouses;
  final int? selectedId;
  final bool isLoading;
  const _WarehouseTile({
    required this.warehouses,
    this.selectedId,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warehouse_outlined,
                color: AppColors.accent,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Омборхона',
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'POS учун омборхонани танланг',
                      style: TextStyle(
                        color: context.colors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isLoading)
            const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (warehouses.isEmpty)
            Text(
              'Омборхоналар топилмади',
              style: TextStyle(color: context.colors.textMuted, fontSize: 12),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: context.colors.surfaceLight,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: context.colors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _validatedValue(),
                  dropdownColor: context.colors.surface,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 13,
                  ),
                  isExpanded: true,
                  hint: Text(
                    'Омборхона танланг',
                    style: TextStyle(
                      color: context.colors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                  items: warehouses.map<DropdownMenuItem<int>>((w) {
                    return DropdownMenuItem(
                      value: w.id as int,
                      child: Text(
                        '${w.name}${w.location.isNotEmpty ? ' — ${w.location}' : ''}',
                      ),
                    );
                  }).toList(),
                  onChanged: (id) {
                    if (id != null) {
                      context.read<SettingsBloc>().add(WarehouseChanged(id));
                    }
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  int? _validatedValue() {
    if (selectedId == null) return null;
    final exists = warehouses.any((w) => w.id == selectedId);
    return exists ? selectedId : null;
  }
}

// ═══════════════════════════════════════════════════════════════════
//  THEME TILE — light / dark / system toggle
// ═══════════════════════════════════════════════════════════════════

class _ThemeTile extends StatelessWidget {
  const _ThemeTile();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (context, themeMode) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.colors.border),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.palette_outlined,
                color: AppColors.accent,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Мавзу',
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Ёруғ ёки қоронғу режим',
                      style: TextStyle(
                        color: context.colors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.settings_suggest, size: 16),
                    label: Text('Тизим'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode, size: 16),
                    label: Text('Ёруғ'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode, size: 16),
                    label: Text('Қоронғу'),
                  ),
                ],
                selected: {themeMode},
                onSelectionChanged: (modes) {
                  context.read<ThemeCubit>().setThemeMode(modes.first);
                },
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStatePropertyAll(
                    const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  PRINTER SECTION — receipt + label printer configuration
// ═══════════════════════════════════════════════════════════════════

class _PrinterSection extends StatelessWidget {
  const _PrinterSection();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // ── Receipt Printer ────────────────────────────────────
            const _SectionHeader(title: 'Чек принтер (ESC/POS)'),
            const SizedBox(height: 16),
            _receiptPrinterForm(context, state),
            const SizedBox(height: 32),
            // ── Label Printer ──────────────────────────────────────
            const _SectionHeader(title: 'Штрих-код принтер (TSPL)'),
            const SizedBox(height: 4),
            Text(
              'Xprinter XP-365B ёки бошқа TSPL принтер учун',
              style: TextStyle(color: context.colors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            _labelPrinterForm(context, state),
          ],
        );
      },
    );
  }

  Widget _receiptPrinterForm(BuildContext context, SettingsState state) {
    final cfg = state.receiptPrinter;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Connection type
        _SettingsTile(
          icon: Icons.cable,
          title: 'Уланиш тури',
          subtitle: cfg.connectionType == ConnectionType.network
              ? 'Тармоқ (LAN)'
              : 'USB',
          child: SegmentedButton<ConnectionType>(
            segments: const [
              ButtonSegment(value: ConnectionType.usb, label: Text('USB')),
              ButtonSegment(value: ConnectionType.network, label: Text('LAN')),
            ],
            selected: {cfg.connectionType},
            onSelectionChanged: (v) {
              context.read<SettingsBloc>().add(
                ReceiptPrinterUpdated(cfg.copyWith(connectionType: v.first)),
              );
            },
            style: ButtonStyle(
              foregroundColor: WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.selected)
                    ? context.colors.textPrimary
                    : context.colors.textSecondary,
              ),
              backgroundColor: WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.selected)
                    ? AppColors.accent
                    : context.colors.surfaceLight,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Network fields
        if (cfg.connectionType == ConnectionType.network) ...[
          _TextFieldTile(
            icon: Icons.lan,
            title: 'IP манзил',
            value: cfg.ip,
            hint: '192.168.1.100',
            onChanged: (v) => context.read<SettingsBloc>().add(
              ReceiptPrinterUpdated(cfg.copyWith(ip: v)),
            ),
          ),
          const SizedBox(height: 12),
          _TextFieldTile(
            icon: Icons.numbers,
            title: 'Порт',
            value: cfg.port.toString(),
            hint: '9100',
            onChanged: (v) => context.read<SettingsBloc>().add(
              ReceiptPrinterUpdated(
                cfg.copyWith(port: int.tryParse(v) ?? 9100),
              ),
            ),
          ),
        ],

        // USB fields
        if (cfg.connectionType == ConnectionType.usb) ...[
          // USB mode selector
          _SettingsTile(
            icon: Icons.settings_ethernet,
            title: 'USB режими',
            subtitle: cfg.usbMode == UsbMode.cups
                ? (Platform.isWindows ? 'Windows Printer' : 'CUPS принтер')
                : (Platform.isWindows ? 'Порт (USB)' : 'Қурилма файли'),
            child: SegmentedButton<UsbMode>(
              segments: [
                ButtonSegment(
                  value: UsbMode.cups,
                  label: Text(
                    Platform.isWindows ? 'Printer' : 'CUPS',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                ButtonSegment(
                  value: UsbMode.file,
                  label: Text(
                    Platform.isWindows ? 'USB порт' : 'Қурилма',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
              selected: {cfg.usbMode},
              onSelectionChanged: (v) {
                context.read<SettingsBloc>().add(
                  ReceiptPrinterUpdated(cfg.copyWith(usbMode: v.first)),
                );
                // Auto-discover on mode switch
                if (v.first == UsbMode.cups &&
                    state.availablePrinters.isEmpty) {
                  context.read<SettingsBloc>().add(
                    const PrinterDiscoveryRequested(),
                  );
                }
                if (v.first == UsbMode.file &&
                    Platform.isWindows &&
                    state.availableUsbPorts.isEmpty) {
                  context.read<SettingsBloc>().add(
                    const UsbPortDiscoveryRequested(),
                  );
                }
              },
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.selected)
                      ? context.colors.textPrimary
                      : context.colors.textSecondary,
                ),
                backgroundColor: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.selected)
                      ? AppColors.accent
                      : context.colors.surfaceLight,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // CUPS printer picker
          if (cfg.usbMode == UsbMode.cups)
            _PrinterPickerTile(
              availablePrinters: state.availablePrinters,
              selectedPrinter: cfg.cupsPrinterName,
              isLoading: state.isDiscovering,
              onDiscover: () => context.read<SettingsBloc>().add(
                const PrinterDiscoveryRequested(),
              ),
              onSelected: (name) => context.read<SettingsBloc>().add(
                ReceiptPrinterUpdated(cfg.copyWith(cupsPrinterName: name)),
              ),
            ),

          // Windows USB port picker
          if (cfg.usbMode == UsbMode.file && Platform.isWindows)
            _UsbPortPickerTile(
              availablePorts: state.availableUsbPorts,
              selectedPort: cfg.devicePath,
              isLoading: state.isDiscovering,
              onDiscover: () => context.read<SettingsBloc>().add(
                const UsbPortDiscoveryRequested(),
              ),
              onSelected: (port) => context.read<SettingsBloc>().add(
                ReceiptPrinterUpdated(cfg.copyWith(devicePath: port)),
              ),
            ),

          // macOS/Linux device path
          if (cfg.usbMode == UsbMode.file && !Platform.isWindows)
            _TextFieldTile(
              icon: Icons.usb,
              title: 'Қурилма йўли',
              value: cfg.devicePath,
              hint: '/dev/usb/lp0',
              onChanged: (v) => context.read<SettingsBloc>().add(
                ReceiptPrinterUpdated(cfg.copyWith(devicePath: v)),
              ),
            ),
        ],

        const SizedBox(height: 12),
        // Paper width
        _SettingsTile(
          icon: Icons.straighten,
          title: 'Қоғоз кенглиги',
          subtitle: cfg.paperWidth == PaperWidth.mm80 ? '80мм' : '57мм',
          child: SegmentedButton<PaperWidth>(
            segments: const [
              ButtonSegment(value: PaperWidth.mm80, label: Text('80мм')),
              ButtonSegment(value: PaperWidth.mm57, label: Text('57мм')),
            ],
            selected: {cfg.paperWidth},
            onSelectionChanged: (v) {
              context.read<SettingsBloc>().add(
                ReceiptPrinterUpdated(cfg.copyWith(paperWidth: v.first)),
              );
            },
            style: ButtonStyle(
              foregroundColor: WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.selected)
                    ? context.colors.textPrimary
                    : context.colors.textSecondary,
              ),
              backgroundColor: WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.selected)
                    ? AppColors.accent
                    : context.colors.surfaceLight,
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),
        _testConnectionButton(context, state, isLabel: false),
      ],
    );
  }

  Widget _labelPrinterForm(BuildContext context, SettingsState state) {
    final cfg = state.labelPrinter;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingsTile(
          icon: Icons.cable,
          title: 'Уланиш тури',
          subtitle: cfg.connectionType == ConnectionType.network
              ? 'Тармоқ (LAN)'
              : 'USB',
          child: SegmentedButton<ConnectionType>(
            segments: const [
              ButtonSegment(value: ConnectionType.usb, label: Text('USB')),
              ButtonSegment(value: ConnectionType.network, label: Text('LAN')),
            ],
            selected: {cfg.connectionType},
            onSelectionChanged: (v) {
              context.read<SettingsBloc>().add(
                LabelPrinterUpdated(cfg.copyWith(connectionType: v.first)),
              );
            },
            style: ButtonStyle(
              foregroundColor: WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.selected)
                    ? context.colors.textPrimary
                    : context.colors.textSecondary,
              ),
              backgroundColor: WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.selected)
                    ? AppColors.accent
                    : context.colors.surfaceLight,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        if (cfg.connectionType == ConnectionType.network) ...[
          _TextFieldTile(
            icon: Icons.lan,
            title: 'IP манзил',
            value: cfg.ip,
            hint: '192.168.1.101',
            onChanged: (v) => context.read<SettingsBloc>().add(
              LabelPrinterUpdated(cfg.copyWith(ip: v)),
            ),
          ),
          const SizedBox(height: 12),
          _TextFieldTile(
            icon: Icons.numbers,
            title: 'Порт',
            value: cfg.port.toString(),
            hint: '9100',
            onChanged: (v) => context.read<SettingsBloc>().add(
              LabelPrinterUpdated(cfg.copyWith(port: int.tryParse(v) ?? 9100)),
            ),
          ),
        ],

        if (cfg.connectionType == ConnectionType.usb) ...[
          // USB mode selector
          _SettingsTile(
            icon: Icons.settings_ethernet,
            title: 'USB режими',
            subtitle: cfg.usbMode == UsbMode.cups
                ? (Platform.isWindows ? 'Windows Printer' : 'CUPS принтер')
                : (Platform.isWindows ? 'Порт (USB)' : 'Қурилма файли'),
            child: SegmentedButton<UsbMode>(
              segments: [
                ButtonSegment(
                  value: UsbMode.cups,
                  label: Text(
                    Platform.isWindows ? 'Printer' : 'CUPS',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                ButtonSegment(
                  value: UsbMode.file,
                  label: Text(
                    Platform.isWindows ? 'USB порт' : 'Қурилма',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
              selected: {cfg.usbMode},
              onSelectionChanged: (v) {
                context.read<SettingsBloc>().add(
                  LabelPrinterUpdated(cfg.copyWith(usbMode: v.first)),
                );
                if (v.first == UsbMode.cups &&
                    state.availablePrinters.isEmpty) {
                  context.read<SettingsBloc>().add(
                    const PrinterDiscoveryRequested(),
                  );
                }
                if (v.first == UsbMode.file &&
                    Platform.isWindows &&
                    state.availableUsbPorts.isEmpty) {
                  context.read<SettingsBloc>().add(
                    const UsbPortDiscoveryRequested(),
                  );
                }
              },
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.selected)
                      ? context.colors.textPrimary
                      : context.colors.textSecondary,
                ),
                backgroundColor: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.selected)
                      ? AppColors.accent
                      : context.colors.surfaceLight,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // CUPS printer picker
          if (cfg.usbMode == UsbMode.cups)
            _PrinterPickerTile(
              availablePrinters: state.availablePrinters,
              selectedPrinter: cfg.cupsPrinterName,
              isLoading: state.isDiscovering,
              onDiscover: () => context.read<SettingsBloc>().add(
                const PrinterDiscoveryRequested(),
              ),
              onSelected: (name) => context.read<SettingsBloc>().add(
                LabelPrinterUpdated(cfg.copyWith(cupsPrinterName: name)),
              ),
            ),

          // Windows USB port picker
          if (cfg.usbMode == UsbMode.file && Platform.isWindows)
            _UsbPortPickerTile(
              availablePorts: state.availableUsbPorts,
              selectedPort: cfg.devicePath,
              isLoading: state.isDiscovering,
              onDiscover: () => context.read<SettingsBloc>().add(
                const UsbPortDiscoveryRequested(),
              ),
              onSelected: (port) => context.read<SettingsBloc>().add(
                LabelPrinterUpdated(cfg.copyWith(devicePath: port)),
              ),
            ),

          // macOS/Linux device path
          if (cfg.usbMode == UsbMode.file && !Platform.isWindows)
            _TextFieldTile(
              icon: Icons.usb,
              title: 'Қурилма йўли',
              value: cfg.devicePath,
              hint: '/dev/usb/lp0',
              onChanged: (v) => context.read<SettingsBloc>().add(
                LabelPrinterUpdated(cfg.copyWith(devicePath: v)),
              ),
            ),
        ],

        const SizedBox(height: 12),
        // Label dimensions
        Row(
          children: [
            Expanded(
              child: _TextFieldTile(
                icon: Icons.width_normal,
                title: 'Кенглик (мм)',
                value: cfg.labelWidth.toString(),
                hint: '57',
                onChanged: (v) => context.read<SettingsBloc>().add(
                  LabelPrinterUpdated(
                    cfg.copyWith(labelWidth: int.tryParse(v) ?? 57),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TextFieldTile(
                icon: Icons.height,
                title: 'Баландлик (мм)',
                value: cfg.labelHeight.toString(),
                hint: '40',
                onChanged: (v) => context.read<SettingsBloc>().add(
                  LabelPrinterUpdated(
                    cfg.copyWith(labelHeight: int.tryParse(v) ?? 40),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        _testConnectionButton(context, state, isLabel: true),
      ],
    );
  }

  Widget _testConnectionButton(
    BuildContext context,
    SettingsState state, {
    required bool isLabel,
  }) {
    final testResult = isLabel
        ? state.labelTestResult
        : state.receiptTestResult;
    return Row(
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.wifi_tethering, size: 16),
          label: const Text('Текшириш'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          onPressed: state.isTesting
              ? null
              : () => context.read<SettingsBloc>().add(
                  PrinterTestRequested(isLabel: isLabel),
                ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          icon: Icon(
            isLabel ? Icons.label_outline : Icons.receipt_long,
            size: 16,
          ),
          label: const Text('Тест чоп этиш'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accent,
            side: const BorderSide(color: AppColors.accent),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          onPressed: state.isTesting
              ? null
              : () => context.read<SettingsBloc>().add(
                  PrintTestPageRequested(isLabel: isLabel),
                ),
        ),
        const SizedBox(width: 12),
        if (state.isTesting)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else if (testResult != null)
          Flexible(
            child: Text(
              testResult,
              style: TextStyle(
                color:
                    testResult.contains('муваффақиятли') ||
                        testResult.contains('чоп этилди')
                    ? AppColors.success
                    : AppColors.danger,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  SYSTEM SECTION — server URL, about
// ═══════════════════════════════════════════════════════════════════

class _SystemSection extends StatefulWidget {
  const _SystemSection();

  @override
  State<_SystemSection> createState() => _SystemSectionState();
}

class _SystemSectionState extends State<_SystemSection> {
  late TextEditingController _urlCtrl;
  String _savedUrl = '';

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  bool get _hasChanges => _urlCtrl.text.trim() != _savedUrl;

  Future<void> _onSave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).dialogBackgroundColor,
        title: Text(
          'Огоҳлантириш',
          style: TextStyle(color: context.colors.textPrimary, fontSize: 16),
        ),
        content: Text(
          'Сервер манзилини ўзгартирсангиз, дастур тўлиқ қайта юкланади. Давом этасизми?',
          style: TextStyle(color: context.colors.textSecondary, fontSize: 14),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.colors.textSecondary,
              side: BorderSide(color: context.colors.border),
            ),
            child: const Text('Йўқ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ҳа'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      context.read<SettingsBloc>().add(ServerUrlUpdated(_urlCtrl.text.trim()));
      // Give time for the save to complete, then restart the app
      await Future.delayed(const Duration(milliseconds: 300));
      exit(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        // Sync controller with bloc state on first load
        if (_savedUrl != state.serverUrl) {
          _savedUrl = state.serverUrl;
          if (_urlCtrl.text != state.serverUrl) {
            _urlCtrl.text = state.serverUrl;
          }
        }

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const _SectionHeader(title: 'Тизим созламалари'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.dns_outlined,
                        color: AppColors.accent,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Сервер манзили (POS URL)',
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _urlCtrl,
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: 'https://example.com',
                      hintStyle: TextStyle(
                        color: context.colors.textMuted,
                        fontSize: 13,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      filled: true,
                      fillColor: context.colors.surfaceLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: context.colors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: context.colors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: AppColors.accent),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (_hasChanges) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _onSave,
                        icon: const Icon(Icons.save, size: 18),
                        label: const Text('Сақлаш'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            _SettingsTile(
              icon: Icons.info_outline,
              title: 'Дастур ҳақида',
              subtitle: 'POS Terminal v1.0.0',
              child: const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: context.colors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: context.colors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          child,
        ],
      ),
    );
  }
}

class _TextFieldTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String value;
  final String hint;
  final ValueChanged<String> onChanged;

  const _TextFieldTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.hint,
    required this.onChanged,
  });

  @override
  State<_TextFieldTile> createState() => _TextFieldTileState();
}

class _TextFieldTileState extends State<_TextFieldTile> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_TextFieldTile old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && _ctrl.text != widget.value) {
      _ctrl.text = widget.value;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Icon(widget.icon, color: AppColors.accent, size: 20),
          const SizedBox(width: 12),
          Text(
            widget.title,
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: _ctrl,
              style: TextStyle(color: context.colors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: TextStyle(
                  color: context.colors.textMuted,
                  fontSize: 13,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                filled: true,
                fillColor: context.colors.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: context.colors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: context.colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: AppColors.accent),
                ),
              ),
              onChanged: widget.onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrinterPickerTile extends StatelessWidget {
  final List<String> availablePrinters;
  final String selectedPrinter;
  final bool isLoading;
  final VoidCallback onDiscover;
  final ValueChanged<String> onSelected;

  const _PrinterPickerTile({
    required this.availablePrinters,
    required this.selectedPrinter,
    this.isLoading = false,
    required this.onDiscover,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.print, color: AppColors.accent, size: 20),
              const SizedBox(width: 12),
              Text(
                'Принтер',
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton.icon(
                      icon: const Icon(Icons.refresh, size: 14),
                      label: const Text(
                        'Қидириш',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.accent,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onPressed: onDiscover,
                    ),
            ],
          ),
          if (availablePrinters.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '"Қидириш" тугмасини босинг',
              style: TextStyle(color: context.colors.textMuted, fontSize: 11),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availablePrinters.map((name) {
                final active = name == selectedPrinter;
                return ChoiceChip(
                  label: Text(
                    name,
                    style: TextStyle(
                      fontSize: 12,
                      color: active
                          ? Colors.white
                          : context.colors.textSecondary,
                    ),
                  ),
                  selected: active,
                  selectedColor: AppColors.accent,
                  backgroundColor: context.colors.surfaceLight,
                  side: BorderSide(
                    color: active ? AppColors.accent : context.colors.border,
                  ),
                  onSelected: (_) => onSelected(name),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _UsbPortPickerTile extends StatelessWidget {
  final List<String> availablePorts;
  final String selectedPort;
  final bool isLoading;
  final VoidCallback onDiscover;
  final ValueChanged<String> onSelected;

  const _UsbPortPickerTile({
    required this.availablePorts,
    required this.selectedPort,
    this.isLoading = false,
    required this.onDiscover,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.usb, color: AppColors.accent, size: 20),
              const SizedBox(width: 12),
              Text(
                'USB порт',
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton.icon(
                      icon: const Icon(Icons.refresh, size: 14),
                      label: const Text(
                        'Қидириш',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.accent,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onPressed: onDiscover,
                    ),
            ],
          ),
          if (availablePorts.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Принтерни USB орқали уланг ва "Қидириш" тугмасини босинг',
              style: TextStyle(color: context.colors.textMuted, fontSize: 11),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availablePorts.map((port) {
                final active = port == selectedPort;
                return ChoiceChip(
                  label: Text(
                    port,
                    style: TextStyle(
                      fontSize: 12,
                      color: active
                          ? Colors.white
                          : context.colors.textSecondary,
                    ),
                  ),
                  selected: active,
                  selectedColor: AppColors.accent,
                  backgroundColor: context.colors.surfaceLight,
                  side: BorderSide(
                    color: active ? AppColors.accent : context.colors.border,
                  ),
                  onSelected: (_) => onSelected(port),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
