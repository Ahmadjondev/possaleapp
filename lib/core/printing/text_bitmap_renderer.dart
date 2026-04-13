import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'tspl_commands.dart';

/// A single column descriptor for [TextBitmapRenderer.renderColumns].
class ColumnSpec {
  final String text;

  /// Fraction of the total paper width (0.0–1.0).
  final double widthFraction;
  final ui.TextAlign align;
  final bool bold;

  /// Overrides the row-level font size when set.
  final double? fontSize;

  /// Max number of text lines. Use > 1 to allow wrapping.
  final int maxLines;

  const ColumnSpec(
    this.text,
    this.widthFraction, {
    this.align = ui.TextAlign.left,
    this.bold = false,
    this.fontSize,
    this.maxLines = 1,
  });
}

class TextBitmapRenderer {
  /// Render a single text snippet as a tight bitmap (for TSPL labels).
  static Future<BitmapData> render(
    String text, {
    double fontSize = 20,
    bool bold = false,
  }) async {
    final style = ui.TextStyle(
      fontSize: fontSize,
      color: const ui.Color(0xFF000000),
      fontWeight: bold ? ui.FontWeight.w700 : ui.FontWeight.w400,
    );

    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(textDirection: ui.TextDirection.ltr, maxLines: 1),
          )
          ..pushStyle(style)
          ..addText(text);

    final paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: double.infinity));

    final pxW = paragraph.longestLine.ceil();
    final pxH = paragraph.height.ceil();

    if (pxW <= 0 || pxH <= 0) {
      return BitmapData(
        widthBytes: 0,
        pixelWidth: 0,
        height: 0,
        data: Uint8List(0),
      );
    }

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, pxW.toDouble(), pxH.toDouble()),
    );

    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, pxW.toDouble(), pxH.toDouble()),
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    );

    canvas.drawParagraph(paragraph, ui.Offset.zero);

    final picture = recorder.endRecording();
    final image = await picture.toImage(pxW, pxH);

    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();

    if (byteData == null) {
      throw Exception('Failed to render text to image');
    }

    return _rgbaToBitmap(byteData, pxW, pxH);
  }

  /// Render a line of text as a fixed-width bitmap for ESC/POS receipt printing.
  ///
  /// The output bitmap is always [paperWidthDots] pixels wide, with text
  /// positioned according to [align]. This bypasses printer codepages entirely,
  /// ensuring Uzbek Cyrillic (Ғ, Қ, Ҳ, Ў, etc.) prints correctly.
  static Future<BitmapData> renderLine(
    String text, {
    required int paperWidthDots,
    double fontSize = 22,
    bool bold = false,
    ui.TextAlign align = ui.TextAlign.left,
  }) async {
    if (text.isEmpty) {
      return BitmapData(
        widthBytes: 0,
        pixelWidth: 0,
        height: 0,
        data: Uint8List(0),
      );
    }

    final style = ui.TextStyle(
      fontSize: fontSize,
      color: const ui.Color(0xFF000000),
      fontWeight: bold ? ui.FontWeight.w700 : ui.FontWeight.w400,
    );

    final para =
        (ui.ParagraphBuilder(
                ui.ParagraphStyle(
                  textDirection: ui.TextDirection.ltr,
                  textAlign: align,
                  maxLines: 2,
                ),
              )
              ..pushStyle(style)
              ..addText(text))
            .build()
          ..layout(ui.ParagraphConstraints(width: paperWidthDots.toDouble()));

    final pxW = paperWidthDots;
    final pxH = para.height.ceil();
    if (pxH <= 0) {
      return BitmapData(
        widthBytes: 0,
        pixelWidth: 0,
        height: 0,
        data: Uint8List(0),
      );
    }

    return _renderParagraphToBitmap(para, pxW, pxH);
  }

  /// Render a left + right aligned row as a single fixed-width bitmap line.
  ///
  /// Measures the right text first, then constrains the left text to the
  /// remaining space so that the two sides never overlap.
  static Future<BitmapData> renderRow(
    String left,
    String right, {
    required int paperWidthDots,
    double fontSize = 22,
    bool bold = false,
  }) async {
    final style = ui.TextStyle(
      fontSize: fontSize,
      color: const ui.Color(0xFF000000),
      fontWeight: bold ? ui.FontWeight.w700 : ui.FontWeight.w400,
    );

    const gap = 8.0; // minimum pixel gap between left & right
    final totalWidth = paperWidthDots.toDouble();

    // 1. Layout right paragraph at unlimited width to measure it.
    final rightPara =
        (ui.ParagraphBuilder(
                ui.ParagraphStyle(
                  textDirection: ui.TextDirection.ltr,
                  textAlign: ui.TextAlign.right,
                  maxLines: 1,
                ),
              )
              ..pushStyle(style)
              ..addText(right))
            .build()
          ..layout(ui.ParagraphConstraints(width: totalWidth));
    final rightWidth = rightPara.longestLine.ceilToDouble();

    // 2. Constrain left paragraph so it cannot run into the right text.
    final leftMaxWidth = math.max(
      totalWidth - rightWidth - gap,
      totalWidth * 0.3,
    );
    final leftPara =
        (ui.ParagraphBuilder(
                ui.ParagraphStyle(
                  textDirection: ui.TextDirection.ltr,
                  textAlign: ui.TextAlign.left,
                  maxLines: 2,
                  ellipsis: '…',
                ),
              )
              ..pushStyle(style)
              ..addText(left))
            .build()
          ..layout(ui.ParagraphConstraints(width: leftMaxWidth));

    final pxW = paperWidthDots;
    final pxH = math.max(leftPara.height, rightPara.height).ceil();
    if (pxH <= 0) {
      return BitmapData(
        widthBytes: 0,
        pixelWidth: 0,
        height: 0,
        data: Uint8List(0),
      );
    }

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, pxW.toDouble(), pxH.toDouble()),
    );

    // White background
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, pxW.toDouble(), pxH.toDouble()),
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    );

    canvas.drawParagraph(leftPara, ui.Offset.zero);
    // Draw right text anchored to the right edge
    final rightX = totalWidth - rightWidth;
    canvas.drawParagraph(rightPara, ui.Offset(rightX, 0));

    final picture = recorder.endRecording();
    final image = await picture.toImage(pxW, pxH);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();

    if (byteData == null) throw Exception('Failed to render row to image');

    return _rgbaToBitmap(byteData, pxW, pxH);
  }

  /// Convert an already-laid-out paragraph to a 1-bit bitmap.
  static Future<BitmapData> _renderParagraphToBitmap(
    ui.Paragraph paragraph,
    int pxW,
    int pxH,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, pxW.toDouble(), pxH.toDouble()),
    );

    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, pxW.toDouble(), pxH.toDouble()),
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    );

    canvas.drawParagraph(paragraph, ui.Offset.zero);

    final picture = recorder.endRecording();
    final image = await picture.toImage(pxW, pxH);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();

    if (byteData == null) throw Exception('Failed to render text to image');

    return _rgbaToBitmap(byteData, pxW, pxH);
  }

  /// Convert RGBA byte data to a 1-bit monochrome bitmap.
  static BitmapData _rgbaToBitmap(ByteData byteData, int pxW, int pxH) {
    final wBytes = (pxW + 7) ~/ 8;
    final bits = Uint8List(wBytes * pxH);

    for (var y = 0; y < pxH; y++) {
      for (var x = 0; x < pxW; x++) {
        final off = (y * pxW + x) * 4;
        final r = byteData.getUint8(off);
        final g = byteData.getUint8(off + 1);
        final b = byteData.getUint8(off + 2);

        if ((r * 299 + g * 587 + b * 114) < 128000) {
          bits[y * wBytes + x ~/ 8] |= (0x80 >> (x & 7));
        }
      }
    }

    // Clear trailing garbage bits
    final validBits = pxW % 8;
    if (validBits != 0) {
      final mask = 0xFF << (8 - validBits);
      for (var y = 0; y < pxH; y++) {
        bits[y * wBytes + (wBytes - 1)] &= mask;
      }
    }

    return BitmapData(
      widthBytes: wBytes,
      pixelWidth: pxW,
      height: pxH,
      data: bits,
    );
  }

  /// Render multiple columns side-by-side into one full-width bitmap row.
  ///
  /// Column widths are specified as fractions of [paperWidthDots]. The last
  /// column automatically absorbs any rounding remainder. Supports per-column
  /// alignment and multi-line wrapping (set [ColumnSpec.maxLines] > 1).
  static Future<BitmapData> renderColumns(
    List<ColumnSpec> columns, {
    required int paperWidthDots,
    double fontSize = 20,
  }) async {
    // Compute pixel widths; last column takes the remainder to avoid gaps
    final widths = <int>[];
    var used = 0;
    for (var i = 0; i < columns.length; i++) {
      final w = i < columns.length - 1
          ? (paperWidthDots * columns[i].widthFraction).round()
          : paperWidthDots - used;
      widths.add(w);
      used += w;
    }

    // Build and layout each column's paragraph
    final paragraphs = <ui.Paragraph>[];
    for (var i = 0; i < columns.length; i++) {
      final spec = columns[i];
      final colWidth = widths[i];
      final style = ui.TextStyle(
        fontSize: spec.fontSize ?? fontSize,
        color: const ui.Color(0xFF000000),
        fontWeight: spec.bold ? ui.FontWeight.w700 : ui.FontWeight.w400,
      );
      final para =
          (ui.ParagraphBuilder(
                  ui.ParagraphStyle(
                    textDirection: ui.TextDirection.ltr,
                    textAlign: spec.align,
                    maxLines: spec.maxLines,
                    ellipsis: spec.maxLines == 1 ? '…' : null,
                  ),
                )
                ..pushStyle(style)
                ..addText(spec.text))
              .build()
            ..layout(ui.ParagraphConstraints(width: colWidth.toDouble()));
      paragraphs.add(para);
    }

    final pxW = paperWidthDots;
    final pxH = paragraphs.map((p) => p.height.ceil()).reduce(math.max);

    if (pxH <= 0) {
      return BitmapData(
        widthBytes: 0,
        pixelWidth: 0,
        height: 0,
        data: Uint8List(0),
      );
    }

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, pxW.toDouble(), pxH.toDouble()),
    );

    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, pxW.toDouble(), pxH.toDouble()),
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    );

    var xOff = 0;
    for (var i = 0; i < paragraphs.length; i++) {
      // Vertically center short columns in taller rows
      final yOff = ((pxH - paragraphs[i].height) / 2).floorToDouble();
      canvas.drawParagraph(paragraphs[i], ui.Offset(xOff.toDouble(), yOff));
      xOff += widths[i];
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(pxW, pxH);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();

    if (byteData == null) throw Exception('Failed to render columns to image');

    return _rgbaToBitmap(byteData, pxW, pxH);
  }

  /// Render a labeled field where the value wraps under itself, not the label.
  ///
  /// Produces output like:
  /// ```
  /// Мижоз:   Muhammadjon Abdug'aniyev
  ///          Flutter Developer Senior
  /// ```
  /// The [label] occupies a fixed-width left column ([labelWidthFraction] of
  /// the paper width). The [value] fills the remaining space and word-wraps
  /// to multiple lines, all aligned under the value start position.
  static Future<BitmapData> renderLabeledField(
    String label,
    String value, {
    required int paperWidthDots,
    double fontSize = 22,
    bool bold = false,
    double labelWidthFraction = 0.24,
    int maxLines = 3,
  }) async {
    final totalWidth = paperWidthDots.toDouble();
    final labelWidth = (totalWidth * labelWidthFraction).roundToDouble();
    final valueWidth = totalWidth - labelWidth;

    final labelStyle = ui.TextStyle(
      fontSize: fontSize,
      color: const ui.Color(0xFF000000),
      fontWeight: ui.FontWeight.w400,
    );
    final valueStyle = ui.TextStyle(
      fontSize: fontSize,
      color: const ui.Color(0xFF000000),
      fontWeight: bold ? ui.FontWeight.w700 : ui.FontWeight.w400,
    );

    // Label: single line, left-aligned, fixed width
    final labelPara =
        (ui.ParagraphBuilder(
                ui.ParagraphStyle(
                  textDirection: ui.TextDirection.ltr,
                  textAlign: ui.TextAlign.left,
                  maxLines: 1,
                ),
              )
              ..pushStyle(labelStyle)
              ..addText(label))
            .build()
          ..layout(ui.ParagraphConstraints(width: labelWidth));

    // Value: multi-line word-wrap, left-aligned, fills remaining width
    final valuePara =
        (ui.ParagraphBuilder(
                ui.ParagraphStyle(
                  textDirection: ui.TextDirection.ltr,
                  textAlign: ui.TextAlign.left,
                  maxLines: maxLines,
                  ellipsis: '…',
                ),
              )
              ..pushStyle(valueStyle)
              ..addText(value))
            .build()
          ..layout(ui.ParagraphConstraints(width: valueWidth));

    final pxW = paperWidthDots;
    final pxH = math.max(labelPara.height, valuePara.height).ceil();
    if (pxH <= 0) {
      return BitmapData(
        widthBytes: 0,
        pixelWidth: 0,
        height: 0,
        data: Uint8List(0),
      );
    }

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, pxW.toDouble(), pxH.toDouble()),
    );

    // White background
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, pxW.toDouble(), pxH.toDouble()),
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    );

    // Label at x=0, value at x=labelWidth — wrapped lines stay under value
    canvas.drawParagraph(labelPara, ui.Offset.zero);
    canvas.drawParagraph(valuePara, ui.Offset(labelWidth, 0));

    final picture = recorder.endRecording();
    final image = await picture.toImage(pxW, pxH);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();

    if (byteData == null) {
      throw Exception('Failed to render labeled field to image');
    }

    return _rgbaToBitmap(byteData, pxW, pxH);
  }

  /// Generate a thin dashed separator line as a pure bitmap.
  ///
  /// No raw text bytes are sent, avoiding CJK firmware misinterpretation.
  /// [height] is the total pixel height (including padding); the dashes
  /// are centred vertically within that height.
  static BitmapData renderSeparator({
    required int paperWidthDots,
    int height = 7,
    int dashWidth = 4,
    int gapWidth = 3,
  }) {
    final pxW = paperWidthDots;
    final wBytes = (pxW + 7) ~/ 8;
    final bits = Uint8List(wBytes * height);

    // Draw dashed line in the vertical centre
    final yMid = height ~/ 2;
    final cycle = dashWidth + gapWidth;

    for (var x = 0; x < pxW; x++) {
      if (x % cycle < dashWidth) {
        bits[yMid * wBytes + x ~/ 8] |= (0x80 >> (x & 7));
      }
    }

    return BitmapData(
      widthBytes: wBytes,
      pixelWidth: pxW,
      height: height,
      data: bits,
    );
  }
}
