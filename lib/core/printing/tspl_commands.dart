import 'dart:convert';
import 'dart:typed_data';

import 'label_templates.dart';

/// Builds TSPL/TSPL2 command sequences for thermal label printers
/// such as the Xprinter XP-365B / XP-370B.
///
/// Cyrillic text is rendered as host-side bitmaps via [BitmapData] and sent
/// using the TSPL BITMAP command, because the XP-370B built-in fonts lack
/// Cyrillic glyphs. ASCII-only text uses the TEXT command with built-in fonts.
/// Barcode content is always ASCII.
class TsplBuilder {
  final List<int> _buffer = [];

  /// Raw byte output.
  Uint8List get bytes => Uint8List.fromList(_buffer);

  // ── Setup commands ─────────────────────────────────────────────────

  /// Set label size in mm.
  void size(int widthMm, int heightMm) =>
      _cmd('SIZE $widthMm mm, $heightMm mm');

  /// Set gap between labels in mm.
  void gap(int gapMm, [int offsetMm = 0]) =>
      _cmd('GAP $gapMm mm, $offsetMm mm');

  /// Print speed (1-10).
  void speed(int s) => _cmd('SPEED $s');

  /// Print density (0-15).
  void density(int d) => _cmd('DENSITY $d');

  /// Set print direction. 0 = normal, 1 = mirrored.
  void direction(int dir, [int mirror = 0]) => _cmd('DIRECTION $dir,$mirror');

  /// Clear image buffer.
  void cls() => _cmd('CLS');

  /// Set codepage for text rendering.
  void codepage(String cp) => _cmd('CODEPAGE $cp');

  // ── Content commands ───────────────────────────────────────────────

  /// Print a text string at position (x, y) in dots (203 dpi: 1mm ≈ 8 dots).
  ///
  /// [font] – built-in font name, e.g. "3" (24×24) or "TSS24.BF2" for CJK.
  /// [rotation] – 0, 90, 180, 270.
  /// [xMul], [yMul] – horizontal/vertical magnification (1-10).
  void text(
    int x,
    int y,
    String font,
    int rotation,
    int xMul,
    int yMul,
    String content,
  ) {
    // Build command header as ASCII, encode content as Windows-1251
    final header = 'TEXT $x,$y,"$font",$rotation,$xMul,$yMul,"';
    _buffer.addAll(utf8.encode(header));
    _buffer.addAll(_encodeWin1251(content));
    _buffer.addAll(utf8.encode('"\r\n'));
  }

  /// Print a 1D barcode at position (x, y).
  ///
  /// [codeType] – barcode symbology: "128", "EAN13", "39", etc.
  /// [height] – barcode bar height in dots.
  /// [readable] – 0 = no text, 1 = align left, 2 = center, 3 = align right.
  /// [rotation] – 0, 90, 180, 270.
  /// [narrow] – width of narrow bar in dots (1-10).
  /// [wide] – width of wide bar in dots (1-10).
  void barcode(
    int x,
    int y,
    String codeType,
    int height,
    int readable,
    int rotation,
    int narrow,
    int wide,
    String content,
  ) {
    final escaped = content.replaceAll('"', '\\"');
    _cmd(
      'BARCODE $x,$y,"$codeType",$height,$readable,$rotation,$narrow,$wide,"$escaped"',
    );
  }

  /// Draw a bar (filled rectangle) at position (x, y) with given size.
  void bar(int x, int y, int width, int height) =>
      _cmd('BAR $x,$y,$width,$height');

  /// Send raw monochrome bitmap at position (x, y).
  ///
  /// [widthBytes] – image width in bytes (8 pixels per byte).
  /// [height] – image height in dots.
  /// [data] – raw 1-bit/pixel bitmap, MSB = leftmost, 1 = black.
  void bitmap(int x, int y, int widthBytes, int height, Uint8List data) {
    final header = 'BITMAP $x,$y,$widthBytes,$height,0,';
    _buffer.addAll(utf8.encode(header));
    _buffer.addAll(data);
    _buffer.addAll([0x0D, 0x0A]);
  }

  // ── Print commands ─────────────────────────────────────────────────

  /// Print labels. [sets] = number of label sets, [copies] = copies per set.
  void print(int sets, [int copies = 1]) => _cmd('PRINT $sets,$copies');

  // ── Helpers ────────────────────────────────────────────────────────

  void _cmd(String command) {
    _buffer.addAll(utf8.encode('$command\r\n'));
  }

  /// Encode a string to Windows-1251 bytes for Cyrillic label text.
  static List<int> _encodeWin1251(String s) {
    final bytes = <int>[];
    for (final rune in s.runes) {
      if (rune < 0x80) {
        bytes.add(rune);
      } else if (rune >= 0x0410 && rune <= 0x042F) {
        bytes.add(rune - 0x0410 + 0xC0);
      } else if (rune >= 0x0430 && rune <= 0x044F) {
        bytes.add(rune - 0x0430 + 0xE0);
      } else if (rune == 0x0401) {
        bytes.add(0xA8);
      } else if (rune == 0x0451) {
        bytes.add(0xB8);
      } else if (rune == 0x040E) {
        bytes.add(0xA1);
      } else if (rune == 0x045E) {
        bytes.add(0xA2);
      } else if (rune == 0x2116) {
        bytes.add(0xB9);
      } else {
        bytes.add(0x3F); // Unknown → '?'
      }
    }
    return bytes;
  }

  /// Build TSPL commands for a single 57×40mm label with name + price only.
  ///
  /// Layout (57mm × 40mm at 203dpi → 456×320 dots):
  ///   - Product name (top, centered)
  ///   - Price (bottom, centered)
  static Uint8List buildLabel({
    required int labelWidth,
    required int labelHeight,
    required int printSpeed,
    required int printDensity,
    required String productName,
    required String price,
    BitmapData? nameBitmap,
    BitmapData? priceBitmap,
  }) {
    final b = TsplBuilder()
      ..size(labelWidth, labelHeight)
      ..gap(2)
      ..speed(printSpeed)
      ..density(printDensity)
      ..direction(1)
      ..cls();

    final widthDots = labelWidth * 8;
    final heightDots = labelHeight * 8;

    final nameH = nameBitmap?.height ?? 24;
    final priceH = priceBitmap?.height ?? 24;
    const gap = 12;

    final contentH = nameH + gap + priceH;
    final topY = ((heightDots - contentH) / 2)
        .clamp(4, heightDots ~/ 4)
        .toInt();

    // ── Product name ──
    if (nameBitmap != null && nameBitmap.height > 0) {
      final nameX = ((widthDots - nameBitmap.pixelWidth) / 2)
          .clamp(4, widthDots)
          .toInt();
      b.bitmap(
        nameX,
        topY,
        nameBitmap.widthBytes,
        nameBitmap.height,
        nameBitmap.data,
      );
    } else {
      final name = productName.length > 28
          ? '${productName.substring(0, 26)}..'
          : productName;
      final nameWidth = name.length * 12;
      final nameX = ((widthDots - nameWidth) / 2).clamp(4, widthDots).toInt();
      b.text(nameX, topY, '3', 0, 1, 1, name);
    }

    // ── Price ──
    final priceY = topY + nameH + gap;
    if (priceBitmap != null && priceBitmap.height > 0) {
      final priceX = ((widthDots - priceBitmap.pixelWidth) / 2)
          .clamp(4, widthDots)
          .toInt();
      b.bitmap(
        priceX,
        priceY,
        priceBitmap.widthBytes,
        priceBitmap.height,
        priceBitmap.data,
      );
    } else {
      final priceWidth = price.length * 16;
      final priceX = ((widthDots - priceWidth) / 2).clamp(4, widthDots).toInt();
      b.text(priceX, priceY, '4', 0, 1, 1, price);
    }

    b.print(1);
    return b.bytes;
  }

  /// Build TSPL commands for a label using a [LabelTemplate] to control
  /// element ordering, visibility, and relative sizing.
  /// Only name + price are printed (no barcode).
  static Uint8List buildLabelFromTemplate({
    required int labelWidth,
    required int labelHeight,
    required int printSpeed,
    required int printDensity,
    required String productName,
    required String price,
    required LabelTemplate template,
    BitmapData? nameBitmap,
    BitmapData? priceBitmap,
  }) {
    final b = TsplBuilder()
      ..size(labelWidth, labelHeight)
      ..gap(2)
      ..speed(printSpeed)
      ..density(printDensity)
      ..direction(1)
      ..cls();

    final widthDots = labelWidth * 8;
    final heightDots = labelHeight * 8;

    switch (template.layout) {
      case LabelLayout.priceTop:
        _layoutPriceTop(
          b,
          widthDots,
          heightDots,
          productName,
          price,
          template,
          nameBitmap,
          priceBitmap,
        );
      case LabelLayout.withDividers:
        _layoutWithDividers(
          b,
          widthDots,
          heightDots,
          productName,
          price,
          template,
          nameBitmap,
          priceBitmap,
        );
      case LabelLayout.priceOnly:
        _layoutPriceOnly(
          b,
          widthDots,
          heightDots,
          price,
          template,
          priceBitmap,
        );
      case LabelLayout.standard:
      case LabelLayout.balanced:
        _layoutStandard(
          b,
          widthDots,
          heightDots,
          productName,
          price,
          template,
          nameBitmap,
          priceBitmap,
        );
    }

    b.print(1);
    return b.bytes;
  }

  // ── Layout helpers ─────────────────────────────────────────────────

  static void _placeText(
    TsplBuilder b,
    int widthDots,
    int y,
    String text,
    String font,
    int maxChars,
    BitmapData? bitmap,
  ) {
    if (bitmap != null && bitmap.height > 0) {
      final x = ((widthDots - bitmap.pixelWidth) / 2)
          .clamp(4, widthDots)
          .toInt();
      b.bitmap(x, y, bitmap.widthBytes, bitmap.height, bitmap.data);
    } else {
      final truncated = text.length > maxChars
          ? '${text.substring(0, maxChars - 2)}..'
          : text;
      final charW = font == '4'
          ? 16
          : font == '5'
          ? 24
          : 12;
      final w = truncated.length * charW;
      final x = ((widthDots - w) / 2).clamp(4, widthDots).toInt();
      b.text(x, y, font, 0, 1, 1, truncated);
    }
  }

  static void _placeDivider(TsplBuilder b, int widthDots, int y) {
    b.bar(16, y, widthDots - 32, 1);
  }

  /// Standard layout: name → price (with varying font sizes).
  static void _layoutStandard(
    TsplBuilder b,
    int widthDots,
    int heightDots,
    String name,
    String price,
    LabelTemplate t,
    BitmapData? nameBmp,
    BitmapData? priceBmp,
  ) {
    final nameH = t.showName
        ? (nameBmp?.height ?? (t.nameFontSize > 20 ? 32 : 24))
        : 0;
    final priceH =
        priceBmp?.height ??
        (t.priceFontSize > 24
            ? 40
            : t.priceFontSize > 20
            ? 32
            : 24);
    const gap = 12;

    final sections = [if (t.showName) nameH, priceH];
    final contentH =
        sections.fold(0, (a, b) => a + b) + (sections.length - 1) * gap;
    var y = ((heightDots - contentH) / 2).clamp(4, heightDots ~/ 4).toInt();

    if (t.showName) {
      _placeText(b, widthDots, y, name, '3', 28, nameBmp);
      y += nameH + gap;
    }

    final priceFont = t.priceFontSize >= 28
        ? '5'
        : t.priceFontSize >= 22
        ? '4'
        : '3';
    _placeText(b, widthDots, y, price, priceFont, 20, priceBmp);
  }

  /// Price on top layout: PRICE → name
  static void _layoutPriceTop(
    TsplBuilder b,
    int widthDots,
    int heightDots,
    String name,
    String price,
    LabelTemplate t,
    BitmapData? nameBmp,
    BitmapData? priceBmp,
  ) {
    final priceH = priceBmp?.height ?? (t.priceFontSize > 24 ? 40 : 32);
    final nameH = t.showName ? (nameBmp?.height ?? 24) : 0;
    const gap = 12;

    final sections = [priceH, if (t.showName) nameH];
    final contentH =
        sections.fold(0, (a, b) => a + b) + (sections.length - 1) * gap;
    var y = ((heightDots - contentH) / 2).clamp(4, heightDots ~/ 4).toInt();

    final priceFont = t.priceFontSize >= 28 ? '5' : '4';
    _placeText(b, widthDots, y, price, priceFont, 20, priceBmp);
    y += priceH + gap;

    if (t.showName) {
      _placeText(b, widthDots, y, name, '3', 28, nameBmp);
    }
  }

  /// Price only layout (no name).
  static void _layoutPriceOnly(
    TsplBuilder b,
    int widthDots,
    int heightDots,
    String price,
    LabelTemplate t,
    BitmapData? priceBmp,
  ) {
    final priceH = priceBmp?.height ?? (t.priceFontSize > 28 ? 48 : 40);
    var y = ((heightDots - priceH) / 2).clamp(4, heightDots ~/ 4).toInt();

    final priceFont = t.priceFontSize >= 32 ? '5' : '4';
    _placeText(b, widthDots, y, price, priceFont, 20, priceBmp);
  }

  /// Divider layout: name ── divider ── price
  static void _layoutWithDividers(
    TsplBuilder b,
    int widthDots,
    int heightDots,
    String name,
    String price,
    LabelTemplate t,
    BitmapData? nameBmp,
    BitmapData? priceBmp,
  ) {
    final nameH = nameBmp?.height ?? 24;
    final priceH = priceBmp?.height ?? 28;
    const gap = 6;
    const divH = 4;

    final contentH = nameH + divH + priceH + (gap * 3);
    var y = ((heightDots - contentH) / 2).clamp(4, heightDots ~/ 4).toInt();

    _placeText(b, widthDots, y, name, '3', 28, nameBmp);
    y += nameH + gap;
    _placeDivider(b, widthDots, y);
    y += divH + gap;

    final priceFont = t.priceFontSize >= 22 ? '4' : '3';
    _placeText(b, widthDots, y, price, priceFont, 20, priceBmp);
  }
}

/// Monochrome bitmap data for the TSPL BITMAP command.
class BitmapData {
  final int widthBytes;
  final int pixelWidth;
  final int height;
  final Uint8List data;

  const BitmapData({
    required this.widthBytes,
    required this.pixelWidth,
    required this.height,
    required this.data,
  });
}
