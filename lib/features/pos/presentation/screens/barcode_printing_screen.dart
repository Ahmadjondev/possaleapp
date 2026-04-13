import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pos_terminal/core/constants/app_colors.dart';
import 'package:pos_terminal/core/di/injection.dart';
import 'package:pos_terminal/core/printing/label_templates.dart';
import 'package:pos_terminal/core/printing/printer_config.dart';
import 'package:pos_terminal/core/printing/printer_service.dart';
import 'package:pos_terminal/features/pos/data/models/product_model.dart';
import 'package:pos_terminal/features/pos/data/pos_repository.dart';
import 'package:pos_terminal/features/pos/presentation/pos_screen.dart';
import 'package:pos_terminal/core/constants/app_colors_extension.dart';

class BarcodePrintingScreen extends StatefulWidget {
  const BarcodePrintingScreen({super.key});

  @override
  State<BarcodePrintingScreen> createState() => _BarcodePrintingScreenState();
}

class _BarcodePrintingScreenState extends State<BarcodePrintingScreen> {
  final _searchCtrl = TextEditingController();
  List<ProductModel> _searchResults = [];
  final List<ProductModel> _selectedProducts = [];
  bool _searching = false;
  bool _printing = false;
  late int _selectedTemplateId;

  PosRepository get _repo => getIt<PosRepository>();

  @override
  void initState() {
    super.initState();
    _selectedTemplateId = getIt<PrinterConfigStorage>()
        .labelConfig
        .defaultTemplateId
        .clamp(0, kLabelTemplates.length - 1);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) return;

    setState(() => _searching = true);
    try {
      final results = await _repo.searchAllProducts(query);
      if (mounted)
        setState(() {
          _searchResults = results;
          _searching = false;
        });
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _addProduct(ProductModel product) {
    if (_selectedProducts.any((p) => p.id == product.id)) return;
    setState(() => _selectedProducts.add(product));
  }

  void _removeProduct(int index) {
    setState(() => _selectedProducts.removeAt(index));
  }

  void _clearSelection() {
    setState(() => _selectedProducts.clear());
  }

  Future<void> _printLabels() async {
    if (_selectedProducts.isEmpty) return;

    final config = getIt<PrinterConfigStorage>().labelConfig;
    if (!config.isConfigured) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Штрих-код принтер созланмаган. Созламаларга ўтинг.'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return;
    }

    setState(() => _printing = true);
    try {
      final products = _selectedProducts
          .map((p) => {'name': p.name, 'price': formatMoney(p.priceUzs)})
          .toList();

      final result = await getIt<PrinterService>().printLabels(
        products,
        config,
        template: kLabelTemplates[_selectedTemplateId],
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.success
                  ? '${_selectedProducts.length} та штрих-код чоп этилди'
                  : 'Хатолик: ${result.error}',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: Column(
        children: [
          // Header
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: context.colors.surface,
              border: Border(bottom: BorderSide(color: context.colors.border)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: context.colors.textPrimary,
                  ),
                  onPressed: () => context.go('/'),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.qr_code, color: AppColors.info, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Штрих-код чоп этиш',
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (_selectedProducts.isNotEmpty) ...[
                  TextButton(
                    onPressed: _clearSelection,
                    child: Text(
                      'Тозалаш',
                      style: TextStyle(
                        color: context.colors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _printing ? null : _printLabels,
                    icon: _printing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.print, size: 18),
                    label: Text('Чоп этиш (${_selectedProducts.length})'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Two-column layout
          Expanded(
            child: Row(
              children: [
                // Left: Search panel
                Expanded(flex: 1, child: _buildSearchPanel()),
                VerticalDivider(width: 1, color: context.colors.border),
                // Right: Selected / preview panel
                Expanded(flex: 1, child: _buildPreviewPanel()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchCtrl,
            autofocus: true,
            style: TextStyle(color: context.colors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Маҳсулот номи ёки штрих-код...',
              hintStyle: TextStyle(
                color: context.colors.textMuted,
                fontSize: 13,
              ),
              prefixIcon: Icon(
                Icons.search,
                size: 18,
                color: context.colors.textMuted,
              ),
              filled: true,
              fillColor: context.colors.surfaceLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: context.colors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: context.colors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.accent),
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 0,
                horizontal: 12,
              ),
            ),
            onSubmitted: (_) => _search(),
          ),
        ),

        // Results
        Expanded(
          child: _searching
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                )
              : _searchResults.isEmpty
              ? Center(
                  child: Text(
                    'Маҳсулотларни қидиринг',
                    style: TextStyle(
                      color: context.colors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final product = _searchResults[index];
                    final isSelected = _selectedProducts.any(
                      (p) => p.id == product.id,
                    );
                    return _SearchResultCard(
                      product: product,
                      isSelected: isSelected,
                      onTap: isSelected ? null : () => _addProduct(product),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTemplateButton() {
    final current = kLabelTemplates[_selectedTemplateId];
    final isDefault =
        current.id ==
        getIt<PrinterConfigStorage>().labelConfig.defaultTemplateId;
    return InkWell(
      onTap: () async {
        final result = await showDialog<int>(
          context: context,
          builder: (_) => _TemplateChooserDialog(
            selectedId: _selectedTemplateId,
            defaultId:
                getIt<PrinterConfigStorage>().labelConfig.defaultTemplateId,
          ),
        );
        if (result != null && mounted) {
          setState(() => _selectedTemplateId = result);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.colors.border)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.grid_view_rounded,
              size: 16,
              color: AppColors.accent,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Шаблон: ${current.nameUz}',
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (isDefault)
              const Icon(Icons.star, size: 14, color: AppColors.warning),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: context.colors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Panel header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: context.colors.border)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.label_outline,
                size: 18,
                color: context.colors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Танланган маҳсулотлар (${_selectedProducts.length})',
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        // ── Template selector ──
        _buildTemplateButton(),
        // Selected items
        Expanded(
          child: _selectedProducts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.qr_code,
                        size: 48,
                        color: context.colors.surfaceLight,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Чоп этиш учун маҳсулотларни танланг',
                        style: TextStyle(
                          color: context.colors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _selectedProducts.length,
                  itemBuilder: (context, index) {
                    final product = _selectedProducts[index];
                    return _LabelPreviewCard(
                      product: product,
                      onRemove: () => _removeProduct(index),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ── Search result card ────────────────────────────────────────
class _SearchResultCard extends StatelessWidget {
  final ProductModel product;
  final bool isSelected;
  final VoidCallback? onTap;

  const _SearchResultCard({
    required this.product,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isSelected
            ? context.colors.surfaceLight.withValues(alpha: 0.5)
            : context.colors.surface,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: TextStyle(
                          color: isSelected
                              ? context.colors.textMuted
                              : context.colors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${product.code}${product.barcode != null ? '  •  ${product.barcode}' : ''}',
                        style: TextStyle(
                          color: context.colors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatMoney(product.priceUzs),
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!isSelected) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.add_circle_outline,
                    size: 18,
                    color: AppColors.accent,
                  ),
                ] else ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.check_circle,
                    size: 18,
                    color: context.colors.textMuted,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Label preview card ────────────────────────────────────────
class _LabelPreviewCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onRemove;

  const _LabelPreviewCard({required this.product, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          children: [
            // Label preview icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: context.colors.surfaceLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.label_outline,
                color: context.colors.textMuted,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            // Product info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatMoney(product.priceUzs),
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.close,
                size: 16,
                color: context.colors.textMuted,
              ),
              onPressed: onRemove,
              splashRadius: 14,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Template chooser dialog ────────────────────────────────────
class _TemplateChooserDialog extends StatefulWidget {
  final int selectedId;
  final int defaultId;

  const _TemplateChooserDialog({
    required this.selectedId,
    required this.defaultId,
  });

  @override
  State<_TemplateChooserDialog> createState() => _TemplateChooserDialogState();
}

class _TemplateChooserDialogState extends State<_TemplateChooserDialog> {
  late int _selected;
  late int _defaultId;

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedId;
    _defaultId = widget.defaultId;
  }

  Future<void> _setAsDefault(int id) async {
    final storage = getIt<PrinterConfigStorage>();
    await storage.saveLabelConfig(
      storage.labelConfig.copyWith(defaultTemplateId: id),
    );
    setState(() => _defaultId = id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('«${kLabelTemplates[id].nameUz}» асосий шаблон'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 620,
        height: 520,
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
                    Icons.grid_view_rounded,
                    color: AppColors.accent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Шаблон танлаш',
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 18,
                      color: context.colors.textMuted,
                    ),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  childAspectRatio: 0.72,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: kLabelTemplates.length,
                itemBuilder: (context, index) {
                  final t = kLabelTemplates[index];
                  final isSelected = t.id == _selected;
                  final isDefault = t.id == _defaultId;
                  return _TemplateCard(
                    template: t,
                    isSelected: isSelected,
                    isDefault: isDefault,
                    onTap: () => setState(() => _selected = t.id),
                    onSetDefault: () => _setAsDefault(t.id),
                  );
                },
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: context.colors.border)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: context.colors.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Узоқ босиб асосий шаблон қилинг',
                    style: TextStyle(
                      color: context.colors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.colors.textSecondary,
                      side: BorderSide(color: context.colors.border),
                    ),
                    child: const Text('Бекор'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, _selected),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Танлаш'),
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

// ── Individual template card with mini-preview ────────────────
class _TemplateCard extends StatelessWidget {
  final LabelTemplate template;
  final bool isSelected;
  final bool isDefault;
  final VoidCallback onTap;
  final VoidCallback onSetDefault;

  const _TemplateCard({
    required this.template,
    required this.isSelected,
    required this.isDefault,
    required this.onTap,
    required this.onSetDefault,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onSetDefault,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accent.withValues(alpha: 0.12)
              : context.colors.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.accent : context.colors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            // Mini label preview
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                child: _buildMiniPreview(),
              ),
            ),
            // Name + info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isDefault) ...[
                        const Icon(
                          Icons.star,
                          size: 11,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 3),
                      ],
                      Flexible(
                        child: Text(
                          template.nameUz,
                          style: TextStyle(
                            color: isSelected
                                ? AppColors.accent
                                : context.colors.textPrimary,
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ном:${template.nameFontSize}  Нарх:${template.priceFontSize}',
                    style: TextStyle(
                      color: context.colors.textMuted,
                      fontSize: 9,
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

  /// Draws a schematic mini-preview of the label layout.
  Widget _buildMiniPreview() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.all(4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _layoutElements(),
      ),
    );
  }

  List<Widget> _layoutElements() {
    final nameW = _bar(
      template.showName ? 0.7 : 0,
      _nameH,
      const Color(0xFF555555),
    );
    final priceW = _bar(0.6, _priceH, const Color(0xFF000000));

    switch (template.layout) {
      case LabelLayout.priceTop:
        return [priceW, _gap, if (template.showName) nameW];
      case LabelLayout.priceOnly:
        return [priceW];
      case LabelLayout.withDividers:
        return [nameW, _divider, priceW];
      case LabelLayout.standard:
      case LabelLayout.balanced:
        return [
          if (template.showName) nameW,
          if (template.showName) _gap,
          priceW,
        ];
    }
  }

  double get _nameH => (template.nameFontSize / 32 * 6).clamp(3.0, 8.0);
  double get _priceH => (template.priceFontSize / 32 * 8).clamp(4.0, 10.0);

  static const _gap = SizedBox(height: 3);
  static final _divider = Container(
    height: 1,
    color: const Color(0xFFCCCCCC),
    margin: const EdgeInsets.symmetric(vertical: 2),
  );

  Widget _bar(double widthFraction, double height, Color color) {
    if (widthFraction <= 0) return const SizedBox.shrink();
    return FractionallySizedBox(
      widthFactor: widthFraction,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}
