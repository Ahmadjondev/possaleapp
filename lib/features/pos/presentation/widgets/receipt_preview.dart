import 'package:flutter/material.dart';
import 'package:pos_terminal/core/constants/app_colors.dart';
import 'package:pos_terminal/core/di/injection.dart';
import 'package:pos_terminal/core/printing/receipt_builder.dart';
import 'package:pos_terminal/core/printing/printer_config.dart';
import 'package:pos_terminal/core/printing/printer_service.dart';
import 'package:pos_terminal/features/pos/data/models/receipt_model.dart';
import 'package:pos_terminal/features/pos/presentation/pos_screen.dart';
import 'package:pos_terminal/core/constants/app_colors_extension.dart';

const _paymentLabels = {
  'cash': 'Нақд пул',
  'terminal': 'Карта терминали',
  'p2p': 'P2P ўтказма',
  'bank': 'Банк ўтказмаси',
  'debt': 'Қарз',
};

const _unitLabels = {
  'pcs': 'дона',
  'kg': 'кг',
  'g': 'г',
  'l': 'л',
  'm': 'м',
  'set': 'тўплам',
};

class ReceiptPreviewDialog extends StatefulWidget {
  final ReceiptModel receipt;

  const ReceiptPreviewDialog({super.key, required this.receipt});

  @override
  State<ReceiptPreviewDialog> createState() => _ReceiptPreviewDialogState();
}

class _ReceiptPreviewDialogState extends State<ReceiptPreviewDialog> {
  bool _printing = false;

  ReceiptModel get r => widget.receipt;

  // ── ESC-POS printing ────────────────────────────────────────
  Future<void> _printReceipt() async {
    setState(() => _printing = true);
    try {
      final result = await ReceiptBuilder.printReceipt(
        r,
        getIt<PrinterService>(),
        getIt<PrinterConfigStorage>(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.success ? 'Чек чоп этилди' : 'Хатолик: ${result.error}',
            ),
            backgroundColor: result.success
                ? AppColors.success
                : AppColors.danger,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Хатолик: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  String _fmtQty(double v) =>
      v == v.toInt() ? v.toInt().toString() : v.toStringAsFixed(2);

  // ── UI build ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 400,
        height: 600,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: context.colors.border),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.receipt_long,
                    color: AppColors.accent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ЧЕК',
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '#${r.saleNumber}',
                    style: TextStyle(
                      color: context.colors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // Receipt content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // ── Business header ──
                    if (r.businessName != null)
                      Text(
                        r.businessName!,
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    if (r.businessAddress != null)
                      Text(
                        r.businessAddress!,
                        style: TextStyle(
                          color: context.colors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    if (r.businessPhone != null)
                      Text(
                        r.businessPhone!,
                        style: TextStyle(
                          color: context.colors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'ЧЕК',
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // ── Meta ──
                    Divider(color: context.colors.border, height: 16),
                    _ReceiptRow(label: 'Сана:', value: r.date),
                    if (r.cashierName != null)
                      _ReceiptRow(label: 'Кассир:', value: r.cashierName!),
                    if (r.customerName != null)
                      _ReceiptRow(label: 'Мижоз:', value: r.customerName!),
                    if (r.customerPhone != null)
                      _ReceiptRow(label: 'Телефон:', value: r.customerPhone!),
                    if (r.customerAddress != null)
                      _ReceiptRow(label: 'Манзил:', value: r.customerAddress!),
                    _ReceiptRow(label: 'Чек:', value: '#${r.saleNumber}'),
                    Divider(color: context.colors.border, height: 16),

                    // ── Items table header ──
                    Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Text(
                            'Товар',
                            style: TextStyle(
                              color: context.colors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Сони',
                            style: TextStyle(
                              color: context.colors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Нархи',
                            style: TextStyle(
                              color: context.colors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Жами',
                            style: TextStyle(
                              color: context.colors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    Divider(color: context.colors.border, height: 8),

                    // ── Items ──
                    ...r.items.map((item) {
                      final unitLabel =
                          _unitLabels[item.unitType] ?? item.unitType;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Text(
                                item.name,
                                style: TextStyle(
                                  color: context.colors.textPrimary,
                                  fontSize: 12,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '${_fmtQty(item.quantity)} $unitLabel',
                                style: TextStyle(
                                  color: context.colors.textMuted,
                                  fontSize: 11,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                formatMoneyShort(item.unitPrice),
                                style: TextStyle(
                                  color: context.colors.textMuted,
                                  fontSize: 11,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                formatMoneyShort(item.lineTotal),
                                style: TextStyle(
                                  color: context.colors.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    Divider(color: context.colors.border, height: 16),

                    // ── Totals ──
                    _ReceiptRow(
                      label: 'Умумий нарх:',
                      value: formatMoney(r.subtotalUzs),
                    ),
                    if (r.discountUzs > 0)
                      _ReceiptRow(
                        label: 'Чегирма:',
                        value: '-${formatMoney(r.discountUzs)}',
                        valueColor: AppColors.danger,
                      ),
                    _ReceiptRow(
                      label: 'ЖАМИ:',
                      value: formatMoney(r.totalUzs),
                      isBold: true,
                      fontSize: 15,
                    ),
                    Divider(color: context.colors.border, height: 12),

                    // ── Payments ──
                    ...r.payments.map((p) {
                      final label = _paymentLabels[p.method] ?? p.method;
                      return _ReceiptRow(
                        label: label,
                        value: formatMoney(p.amountUzs),
                      );
                    }),

                    if (r.changeDueUzs > 0) ...[
                      const SizedBox(height: 4),
                      _ReceiptRow(
                        label: 'Қайтим:',
                        value: formatMoney(r.changeDueUzs),
                        valueColor: AppColors.success,
                        isBold: true,
                      ),
                    ],

                    // ── Balance ──
                    if (r.balanceAppliedUzs > 0 ||
                        r.balanceCreditedUzs > 0) ...[
                      Divider(color: context.colors.border, height: 12),
                      if (r.balanceAppliedUzs > 0)
                        _ReceiptRow(
                          label: 'Балансдан ишлатилди:',
                          value: formatMoney(r.balanceAppliedUzs),
                        ),
                      if (r.balanceCreditedUzs > 0)
                        _ReceiptRow(
                          label: 'Балансга сақланди:',
                          value: formatMoney(r.balanceCreditedUzs),
                        ),
                    ],

                    // ── Customer balance / debt ──
                    if (r.customerCreditUzs > 0 || r.customerDebtUzs > 0) ...[
                      Divider(color: context.colors.border, height: 12),
                      if (r.customerCreditUzs > 0)
                        _ReceiptRow(
                          label: 'Мижоз баланси:',
                          value: formatMoney(r.customerCreditUzs),
                        ),
                      if (r.customerDebtUzs > 0)
                        _ReceiptRow(
                          label: 'Мижоз қарзи:',
                          value: formatMoney(r.customerDebtUzs),
                          valueColor: AppColors.warning,
                        ),
                    ],

                    // ── Debt banner ──
                    if (r.hasDebt && r.debtTotalRemainingUzs > 0) ...[
                      Divider(color: context.colors.border, height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.danger.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '⚠ Қолган қарз: ${formatMoney(r.debtTotalRemainingUzs)}',
                              style: const TextStyle(
                                color: AppColors.danger,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (r.debtActivePlans > 0)
                              Text(
                                'Фаол режалар: ${r.debtActivePlans}',
                                style: TextStyle(
                                  color: context.colors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            if (r.hasOverdue)
                              Text(
                                'Муддати ўтган: ${r.debtWorstOverdueDays} кун',
                                style: const TextStyle(
                                  color: AppColors.danger,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],

                    // ── Footer ──
                    const SizedBox(height: 12),
                    Divider(color: context.colors.border, height: 8),
                    const SizedBox(height: 8),
                    Text(
                      'Харидингиз учун раҳмат!',
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: context.colors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.colors.textSecondary,
                        side: BorderSide(color: context.colors.border),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text('Ёпиш'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _printing ? null : _printReceipt,
                      icon: _printing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.print, size: 16),
                      label: const Text('Чоп этиш'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;
  final double fontSize;

  const _ReceiptRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isBold = false,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? context.colors.textPrimary,
              fontSize: isBold ? fontSize + 2 : fontSize,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
