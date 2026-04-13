import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pos_terminal/core/constants/app_colors.dart';
import 'package:pos_terminal/core/di/injection.dart';
import 'package:pos_terminal/features/pos/data/models/exchange_rate_model.dart';
import 'package:pos_terminal/features/pos/data/pos_repository.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/cart/cart_bloc.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/customer/customer_bloc.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/draft/draft_bloc.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/payment/payment_bloc.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/payment/payment_event.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/payment/payment_state.dart';
import 'package:pos_terminal/features/pos/presentation/widgets/draft_list_dialog.dart';
import 'package:pos_terminal/features/pos/presentation/widgets/featured_products_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_terminal/core/constants/app_colors_extension.dart';

class PosRightSidebar extends StatefulWidget {
  final int warehouseId;
  final TextEditingController? noteController;

  const PosRightSidebar({
    super.key,
    required this.warehouseId,
    this.noteController,
  });

  @override
  State<PosRightSidebar> createState() => _PosRightSidebarState();
}

class _PosRightSidebarState extends State<PosRightSidebar> {
  bool _autoPrint = false;
  static const _autoPrintKey = 'pos_auto_print';
  ExchangeRateModel? _exchangeRate;

  @override
  void initState() {
    super.initState();
    _loadAutoPrint();
    _loadExchangeRate();
  }

  Future<void> _loadExchangeRate() async {
    try {
      final rate = await getIt<PosRepository>().getExchangeRate();
      if (mounted) setState(() => _exchangeRate = rate);
    } catch (_) {}
  }

  Future<void> _loadAutoPrint() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _autoPrint = prefs.getBool(_autoPrintKey) ?? false);
    }
  }

  Future<void> _toggleAutoPrint() async {
    final newVal = !_autoPrint;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoPrintKey, newVal);
    if (mounted) setState(() => _autoPrint = newVal);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      color: context.colors.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Column(
          children: [
            // ── Exchange rate badge ────────────────
            if (_exchangeRate != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'USD/UZS',
                        style: TextStyle(
                          color: context.colors.textMuted,
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _exchangeRate!.rate.toStringAsFixed(0),
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Top action buttons ─────────────────
            _SidebarTile(
              icon: Icons.receipt_long,
              label: 'Савдолар',
              bgColor: AppColors.accent,
              onTap: () => context.go('/sales'),
            ),
            const SizedBox(height: 6),
            _SidebarTile(
              icon: Icons.bolt,
              label: 'Тез сотув',
              bgColor: AppColors.warning,
              onTap: () => FeaturedProductsDialog.show(context),
            ),
            const SizedBox(height: 6),
            _SidebarTile(
              icon: Icons.list_alt,
              label: 'Қораламалар',
              bgColor: AppColors.info,
              onTap: () => DraftListDialog.show(context),
            ),
            const SizedBox(height: 6),
            _SidebarTile(
              icon: Icons.qr_code,
              label: 'Штрих-код',
              bgColor: AppColors.success,
              onTap: () => context.go('/barcode-printing'),
            ),
            const SizedBox(height: 6),
            _SidebarTile(
              icon: Icons.star_border,
              label: 'Бошқарув',
              bgColor: AppColors.purple,
              onTap: () => context.go('/featured'),
            ),

            const Spacer(),

            // ── Print toggle ───────────────────────
            _PrintToggle(value: _autoPrint, onTap: _toggleAutoPrint),
            const SizedBox(height: 8),

            // ── Draft button ───────────────────────
            _ActionButton(
              icon: Icons.save_outlined,
              label: 'Қоралама',
              shortcut: 'F5',
              bgColor: context.colors.surfaceLight,
              fgColor: context.colors.textSecondary,
              onTap: () => _saveDraft(context),
            ),
            const SizedBox(height: 6),

            // ── Payment button ─────────────────────
            BlocBuilder<PaymentBloc, PaymentState>(
              builder: (context, state) {
                final isValid = state is PaymentInProgress && state.isValid;
                return _ActionButton(
                  icon: Icons.payments,
                  label: 'Сотиш',
                  shortcut: 'F2',
                  height: 120,
                  bgColor: isValid
                      ? AppColors.success
                      : AppColors.success.withValues(alpha: 0.2),
                  fgColor: isValid ? Colors.white : context.colors.textMuted,
                  onTap: isValid ? () => _submitPayment(context) : null,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveDraft(BuildContext context) async {
    final cartState = context.read<CartBloc>().state;
    if (cartState.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: Text(
          'Қораламага сақлаш',
          style: TextStyle(color: context.colors.textPrimary, fontSize: 16),
        ),
        content: Text(
          '${cartState.items.length} маҳсулот қораламага сақлансинми?',
          style: TextStyle(color: context.colors.textSecondary, fontSize: 14),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.colors.textSecondary,
              side: BorderSide(color: context.colors.border),
            ),
            child: const Text('Бекор қилиш'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.info,
              foregroundColor: Colors.white,
            ),
            child: const Text('Сақлаш'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final payload = <String, dynamic>{
      'items': cartState.items.map((i) => i.toCheckoutJson()).toList(),
      'warehouse_id': widget.warehouseId,
    };

    final customerState = context.read<CustomerBloc>().state;
    if (customerState is CustomerSelectedState) {
      payload['customer_id'] = customerState.customer.id;
    }

    final note = widget.noteController?.text ?? '';
    if (note.isNotEmpty) {
      payload['note'] = note;
    }

    context.read<DraftBloc>().add(DraftSaveRequested(payload: payload));
  }

  void _submitPayment(BuildContext context) {
    context.read<PaymentBloc>().add(
      PaymentSubmitted(
        warehouseId: widget.warehouseId,
        note: widget.noteController?.text ?? '',
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Top action tile — icon + label with colored background
// ─────────────────────────────────────────────────────────────
class _SidebarTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bgColor;
  final VoidCallback onTap;

  const _SidebarTile({
    required this.icon,
    required this.label,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bgColor.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: bgColor, size: 24),
              const SizedBox(height: 5),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: bgColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Big action button at bottom — Draft / Payment
// ─────────────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String shortcut;
  final Color bgColor;
  final Color fgColor;
  final double height;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.shortcut,
    required this.bgColor,
    required this.fgColor,
    this.height = 80,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          height: height,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: fgColor, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: fgColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                shortcut,
                style: TextStyle(
                  color: fgColor.withValues(alpha: 0.6),
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Print toggle — compact checkbox row
// ─────────────────────────────────────────────────────────────
class _PrintToggle extends StatelessWidget {
  final bool value;
  final VoidCallback onTap;

  const _PrintToggle({required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: value
              ? AppColors.success.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: value
                ? AppColors.success.withValues(alpha: 0.3)
                : context.colors.border,
          ),
        ),
        child: Row(
          children: [
            Checkbox(
              value: value,
              splashRadius: 0,
              onChanged: (value) => onTap(),
              activeColor: AppColors.success,
            ),
            Icon(
              Icons.print,
              size: 18,
              color: value ? AppColors.success : context.colors.textMuted,
            ),
            const SizedBox(height: 3),
            // Text(
            //   'Чоп этиш',
            //   style: TextStyle(
            //     color: value ? AppColors.success : context.colors.textMuted,
            //     fontSize: 9,
            //     fontWeight: FontWeight.w600,
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}
