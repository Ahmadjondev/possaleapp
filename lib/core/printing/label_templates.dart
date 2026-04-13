// Label layout templates for TSPL printers.
//
// Each template defines how name and price are positioned on the label
// and their relative font sizes.

enum LabelLayout {
  /// name (top) → price (bottom)
  standard,

  /// price (top, large) → name (bottom, small)
  priceTop,

  /// name → ── divider ── → price
  withDividers,

  /// price only (no name)
  priceOnly,

  /// name (large) → price (large), balanced
  balanced,
}

class LabelTemplate {
  final int id;
  final String nameUz;
  final int nameFontSize;
  final int priceFontSize;
  final bool showName;
  final LabelLayout layout;

  const LabelTemplate({
    required this.id,
    required this.nameUz,
    this.nameFontSize = 20,
    this.priceFontSize = 20,
    this.showName = true,
    this.layout = LabelLayout.standard,
  });
}

/// 5 predefined label templates (name + price only, no barcode).
///
/// Key design principle: price should always be prominently visible.
const List<LabelTemplate> kLabelTemplates = [
  // 0 — Standard: name → price (equal sizes)
  LabelTemplate(
    id: 0,
    nameUz: 'Standart',
    nameFontSize: 20,
    priceFontSize: 20,
    layout: LabelLayout.standard,
  ),

  // 1 — Price dominant: name(small) → price(BIG)
  LabelTemplate(
    id: 1,
    nameUz: 'Narx katta',
    nameFontSize: 14,
    priceFontSize: 32,
    layout: LabelLayout.standard,
  ),

  // 2 — Price on top: PRICE(huge) → name(small footer)
  LabelTemplate(
    id: 2,
    nameUz: 'Narx yuqorida',
    nameFontSize: 14,
    priceFontSize: 32,
    layout: LabelLayout.priceTop,
  ),

  // 3 — With dividers: ──name──price──
  LabelTemplate(
    id: 3,
    nameUz: 'Ajratgichli',
    nameFontSize: 20,
    priceFontSize: 24,
    layout: LabelLayout.withDividers,
  ),

  // 4 — Price only (no name)
  LabelTemplate(
    id: 4,
    nameUz: 'Faqat narx',
    nameFontSize: 16,
    priceFontSize: 36,
    showName: false,
    layout: LabelLayout.priceOnly,
  ),
];
