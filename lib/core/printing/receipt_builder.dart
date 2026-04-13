import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:intl/intl.dart';

import 'package:pos_terminal/core/printing/esc_pos_commands.dart';
import 'package:pos_terminal/core/printing/printer_config.dart';
import 'package:pos_terminal/core/printing/printer_service.dart';
import 'package:pos_terminal/core/printing/text_bitmap_renderer.dart';
import 'package:pos_terminal/features/pos/data/models/receipt_model.dart';

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

final _moneyFormat = NumberFormat('#,###', 'uz');

String _fmtMoney(double v) => '${_moneyFormat.format(v.round())} сўм';

/// Shortened number (no currency symbol) for narrow table columns.
String _fmtNum(double v) => _moneyFormat.format(v.round());

String _fmtQty(double v) =>
    v == v.toInt() ? v.toInt().toString() : v.toStringAsFixed(2);

/// Builds ESC/POS receipt bytes with bitmap text rendering.
///
/// All text is rendered as raster images via [TextBitmapRenderer],
/// bypassing CP866 / codepage limitations. This ensures Uzbek Cyrillic
/// characters (Ғ, Қ, Ҳ, Ў, ҳ, қ, ғ, ў) print correctly on ALL
/// ESC/POS printers, including Xprinter models with CJK firmware.
class ReceiptBuilder {
  /// Build full receipt as ESC/POS bytes with bitmap text.
  static Future<Uint8List> build(ReceiptModel r, PrinterConfig config) async {
    final b = EscPosBuilder(charsPerLine: config.charsPerLine)..initialize();
    final dots = b.paperWidthDots;
    const normal = 26.0;
    const large = 36.0;
    const small = 22.0;
    const totalSize = 32.0;

    // ── Max characters for the product name column (single-row threshold) ──
    // 80mm ≈ 48 chars → ~20 chars fit in 42% column at 22pt
    // 57mm ≈ 32 chars → ~13 chars fit in 42% column at 22pt
    final nameColMaxChars = config.charsPerLine == 48 ? 20 : 13;

    // ── Helpers ──
    Future<void> bLine(
      String text, {
      double fontSize = normal,
      bool bold = false,
      ui.TextAlign align = ui.TextAlign.left,
    }) async {
      final bmp = await TextBitmapRenderer.renderLine(
        text,
        paperWidthDots: dots,
        fontSize: fontSize,
        bold: bold,
        align: align,
      );
      if (bmp.height > 0) b.rasterImage(bmp.widthBytes, bmp.height, bmp.data);
    }

    Future<void> bRow(
      String left,
      String right, {
      double fontSize = normal,
      bool bold = false,
    }) async {
      final bmp = await TextBitmapRenderer.renderRow(
        left,
        right,
        paperWidthDots: dots,
        fontSize: fontSize,
        bold: bold,
      );
      if (bmp.height > 0) b.rasterImage(bmp.widthBytes, bmp.height, bmp.data);
    }

    Future<void> bCols(List<ColumnSpec> cols, {double fontSize = 22}) async {
      final bmp = await TextBitmapRenderer.renderColumns(
        cols,
        paperWidthDots: dots,
        fontSize: fontSize,
      );
      if (bmp.height > 0) b.rasterImage(bmp.widthBytes, bmp.height, bmp.data);
    }

    /// Labeled field: label at fixed left column, value wraps under itself.
    ///
    /// Example output:
    /// ```
    /// Мижоз:   Muhammadjon Abdug'aniyev
    ///          Flutter Developer Senior
    /// ```
    Future<void> bField(
      String label,
      String value, {
      double fontSize = small,
      bool bold = false,
    }) async {
      final bmp = await TextBitmapRenderer.renderLabeledField(
        label,
        value,
        paperWidthDots: dots,
        fontSize: fontSize,
        bold: bold,
      );
      if (bmp.height > 0) b.rasterImage(bmp.widthBytes, bmp.height, bmp.data);
    }

    /// Bitmap-based dashed separator — no raw text bytes at all.
    void bSep() {
      final sep = TextBitmapRenderer.renderSeparator(paperWidthDots: dots);
      b.rasterImage(sep.widthBytes, sep.height, sep.data);
    }

    // ── Header (business info) ──
    if (r.businessName != null && r.businessName!.isNotEmpty) {
      await bLine(
        r.businessName!,
        fontSize: large,
        bold: true,
        align: ui.TextAlign.center,
      );
    }
    if (r.businessAddress != null && r.businessAddress!.isNotEmpty) {
      await bLine(
        r.businessAddress!,
        fontSize: small,
        align: ui.TextAlign.center,
      );
    }
    if (r.businessPhone != null && r.businessPhone!.isNotEmpty) {
      await bLine(
        r.businessPhone!,
        fontSize: small,
        align: ui.TextAlign.center,
      );
    }

    b.emptyLine();
    await bLine('ЧЕК', fontSize: large, bold: true, align: ui.TextAlign.center);
    b.emptyLine();

    // ── Meta (date, cashier, client, phone, address, receipt #) ──
    // Each field uses bField() — the value wraps to multiple lines under
    // itself (not under the label), preventing any overlap.
    bSep();
    await bField('Сана:', r.date);
    if (r.cashierName != null && r.cashierName!.isNotEmpty) {
      await bField('Кассир:', r.cashierName!);
    }
    if (r.customerName != null && r.customerName!.isNotEmpty) {
      await bField('Мижоз:', r.customerName!);
    }
    if (r.customerPhone != null && r.customerPhone!.isNotEmpty) {
      await bField('Телефон:', r.customerPhone!);
    }
    if (r.customerAddress != null && r.customerAddress!.isNotEmpty) {
      await bField('Манзил:', r.customerAddress!);
    }
    await bField('Чек:', '#${r.saleNumber}');
    bSep();

    // ── Items header ──
    await bCols([
      ColumnSpec('Товар', 0.42, bold: true),
      ColumnSpec('Сони', 0.17, align: ui.TextAlign.center, bold: true),
      ColumnSpec('Нархи', 0.20, align: ui.TextAlign.right, bold: true),
      ColumnSpec('Жами', 0.21, align: ui.TextAlign.right, bold: true),
    ]);
    bSep();

    // ── Items ──
    // Short names → single 4-column row.
    // Long names  → 2-row format: full-width name, then qty|price|total.
    for (final item in r.items) {
      final unitLabel = _unitLabels[item.unitType] ?? item.unitType;
      final qty = '${_fmtQty(item.quantity)} $unitLabel';
      final price = _fmtNum(item.unitPrice);
      final total = _fmtNum(item.lineTotal);

      if (item.name.length <= nameColMaxChars) {
        // ── Single row: all 4 columns ──
        await bCols([
          ColumnSpec(item.name, 0.42, maxLines: 1),
          ColumnSpec(qty, 0.17, align: ui.TextAlign.center),
          ColumnSpec(price, 0.20, align: ui.TextAlign.right),
          ColumnSpec(total, 0.21, align: ui.TextAlign.right),
        ], fontSize: 22);
      } else {
        // ── Two rows: name on its own line, then numbers ──
        await bLine(item.name, fontSize: 22);
        await bCols([
          ColumnSpec('', 0.42), // empty name column
          ColumnSpec(qty, 0.17, align: ui.TextAlign.center),
          ColumnSpec(price, 0.20, align: ui.TextAlign.right),
          ColumnSpec(total, 0.21, align: ui.TextAlign.right),
        ], fontSize: 22);
      }
    }
    bSep();

    // ── Totals ──
    if (r.discountUzs > 0) {
      await bRow('Умумий нарх:', _fmtMoney(r.subtotalUzs));
      await bRow('Чегирма:', '-${_fmtMoney(r.discountUzs)}');
    }
    await bRow('ЖАМИ:', _fmtMoney(r.totalUzs), fontSize: totalSize, bold: true);
    bSep();

    // ── Payments ──
    for (final p in r.payments) {
      final label = _paymentLabels[p.method.toLowerCase()] ?? p.method;
      await bRow(label, _fmtMoney(p.amountUzs));
    }

    if (r.changeDueUzs > 0) {
      b.emptyLine();
      await bRow('Қайтим:', _fmtMoney(r.changeDueUzs), bold: true);
    }

    // ── Balance ──
    if (r.balanceAppliedUzs > 0 || r.balanceCreditedUzs > 0) {
      bSep();
      if (r.balanceAppliedUzs > 0) {
        await bRow('Балансдан ишлатилди:', _fmtMoney(r.balanceAppliedUzs));
      }
      if (r.balanceCreditedUzs > 0) {
        await bRow('Балансга сақланди:', _fmtMoney(r.balanceCreditedUzs));
      }
    }

    // ── Customer balance / debt ──
    if (r.customerCreditUzs > 0 || r.customerDebtUzs > 0) {
      bSep();
      if (r.customerCreditUzs > 0) {
        await bRow('Мижоз баланси:', _fmtMoney(r.customerCreditUzs));
      }
      if (r.customerDebtUzs > 0) {
        await bRow('Мижоз қарзи:', _fmtMoney(r.customerDebtUzs));
      }
    }

    // ── Debt banner ──
    if (r.hasDebt && r.debtTotalRemainingUzs > 0) {
      bSep();
      await bLine(
        '⚠ Қолган қарз: ${_fmtMoney(r.debtTotalRemainingUzs)}',
        bold: true,
        align: ui.TextAlign.center,
      );
      if (r.debtActivePlans > 0) {
        await bLine(
          'Фаол режалар: ${r.debtActivePlans}',
          align: ui.TextAlign.center,
        );
      }
      if (r.hasOverdue) {
        await bLine(
          'Муддати ўтган: ${r.debtWorstOverdueDays} кун',
          align: ui.TextAlign.center,
        );
      }
    }

    // ── Footer ──
    bSep();
    b.emptyLine();
    await bLine(
      'Харидингиз учун раҳмат!',
      fontSize: normal,
      align: ui.TextAlign.center,
    );
    b.emptyLine();
    b.feed(3);
    b.cut();

    return b.bytes;
  }

  /// Build receipt bytes and send to the configured printer.
  static Future<PrintResult> printReceipt(
    ReceiptModel receipt,
    PrinterService printerService,
    PrinterConfigStorage configStorage,
  ) async {
    final config = configStorage.receiptConfig;
    if (!config.isConfigured) {
      return const PrintResult(
        success: false,
        error: 'Чек принтер созланмаган',
      );
    }
    final bytes = await build(receipt, config);
    return printerService.sendReceiptBytes(bytes, config);
  }
}
