import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pos_terminal/core/constants/app_colors.dart';
import 'package:pos_terminal/core/di/injection.dart';
import 'package:pos_terminal/features/pos/data/models/product_model.dart';
import 'package:pos_terminal/features/pos/data/pos_repository.dart';
import 'package:pos_terminal/features/pos/presentation/pos_screen.dart';
import 'package:pos_terminal/core/constants/app_colors_extension.dart';

class FeaturedProductsScreen extends StatefulWidget {
  const FeaturedProductsScreen({super.key});

  @override
  State<FeaturedProductsScreen> createState() => _FeaturedProductsScreenState();
}

class _FeaturedProductsScreenState extends State<FeaturedProductsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  PosRepository get _repo => getIt<PosRepository>();

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repo.getFeaturedItems();
      if (mounted)
        setState(() {
          _items = items;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  Future<void> _removeItem(int featuredItemId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: Text(
          'Ўчириш',
          style: TextStyle(color: context.colors.textPrimary, fontSize: 16),
        ),
        content: Text(
          'Тез сотув рўйхатидан ўчирилсинми?',
          style: TextStyle(color: context.colors.textSecondary, fontSize: 14),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.colors.textSecondary,
              side: BorderSide(color: context.colors.border),
            ),
            child: const Text('Бекор'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ўчириш'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _repo.removeFeaturedProduct(featuredItemId);
      _loadItems();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Хатолик: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _updateOrder(int featuredItemId, int newOrder) async {
    try {
      await _repo.updateFeaturedOrder(featuredItemId, newOrder);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Хатолик: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _showAddDialog() async {
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => _AddFeaturedDialog(
        repo: _repo,
        existingProductIds: _items
            .map(
              (e) =>
                  (e['product'] is Map
                      ? (e['product']['id'] as num?)?.toInt()
                      : (e['product'] as num?)?.toInt()) ??
                  0,
            )
            .toSet(),
        nextOrder: _items.isEmpty ? 1 : _items.length + 1,
      ),
    );
    if (added == true) _loadItems();
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
                const Icon(Icons.bolt, color: AppColors.warning, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Тез сотув бошқаруви',
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _showAddDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Маҳсулот қўшиш'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.warning),
                  )
                : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.danger,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: context.colors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _loadItems,
                          child: const Text('Қайта уриниш'),
                        ),
                      ],
                    ),
                  )
                : _items.isEmpty
                ? Center(
                    child: Text(
                      'Тез сотув маҳсулотлари йўқ',
                      style: TextStyle(
                        color: context.colors.textMuted,
                        fontSize: 14,
                      ),
                    ),
                  )
                : _buildTable(),
          ),
        ],
      ),
    );
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    if (oldIndex == newIndex) return;

    final movedItem = _items.removeAt(oldIndex);
    _items.insert(newIndex, movedItem);
    setState(() {});

    // Persist new display_order for every affected item
    for (var i = 0; i < _items.length; i++) {
      final id = (_items[i]['id'] as num).toInt();
      final oldOrder = (_items[i]['display_order'] as num?)?.toInt() ?? 0;
      final newOrder = i + 1;
      if (oldOrder != newOrder) {
        _items[i]['display_order'] = newOrder;
        _updateOrder(id, newOrder);
      }
    }
  }

  Widget _buildTable() {
    return Column(
      children: [
        // Header row
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: context.colors.surfaceLight,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              SizedBox(width: 40),
              SizedBox(
                width: 60,
                child: Text(
                  'Тартиб',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Маҳсулот',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Категория',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Нарх',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(width: 48),
            ],
          ),
        ),
        // Reorderable list
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            buildDefaultDragHandles: false,
            onReorder: _onReorder,
            itemCount: _items.length,
            itemBuilder: (context, index) {
              final item = _items[index];
              final id = (item['id'] as num).toInt();
              final order =
                  (item['display_order'] as num?)?.toInt() ?? (index + 1);
              final productData =
                  item['product'] as Map<String, dynamic>? ?? {};
              final product = ProductModel.fromJson(productData);

              return Container(
                key: ValueKey(id),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: context.colors.border,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    ReorderableDragStartListener(
                      index: index,
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.drag_indicator,
                          size: 20,
                          color: context.colors.textMuted,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 60,
                      child: Text(
                        '$order',
                        style: TextStyle(
                          color: context.colors.textMuted,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 8,
                        ),
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
                            ),
                            if (product.barcode != null &&
                                product.barcode!.isNotEmpty)
                              Text(
                                product.barcode!,
                                style: TextStyle(
                                  color: context.colors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 8,
                        ),
                        child: Text(
                          product.categoryName ?? '—',
                          style: TextStyle(
                            color: context.colors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 8,
                        ),
                        child: Text(
                          formatMoney(product.priceUzs),
                          style: TextStyle(
                            color: context.colors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: AppColors.danger,
                        ),
                        onPressed: () => _removeItem(id),
                        splashRadius: 16,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Add Featured Products Dialog ──────────────────────────────
class _AddFeaturedDialog extends StatefulWidget {
  final PosRepository repo;
  final Set<int> existingProductIds;
  final int nextOrder;

  const _AddFeaturedDialog({
    required this.repo,
    required this.existingProductIds,
    required this.nextOrder,
  });

  @override
  State<_AddFeaturedDialog> createState() => _AddFeaturedDialogState();
}

class _AddFeaturedDialogState extends State<_AddFeaturedDialog> {
  final _searchCtrl = TextEditingController();
  List<ProductModel> _results = [];
  final Set<int> _selected = {};
  bool _searching = false;
  bool _saving = false;

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
      final products = await widget.repo.searchAllProducts(query);
      if (mounted)
        setState(() {
          _results = products;
          _searching = false;
        });
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _addSelected() async {
    if (_selected.isEmpty) return;
    setState(() => _saving = true);

    try {
      var order = widget.nextOrder;
      for (final productId in _selected) {
        await widget.repo.addFeaturedProduct(productId, order);
        order++;
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Хатолик: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: SizedBox(
        width: 480,
        height: 500,
        child: Column(
          children: [
            // Title
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: context.colors.border),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    'Маҳсулот қўшиш',
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 14,
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
                    onPressed: () => Navigator.of(context).pop(false),
                    splashRadius: 14,
                  ),
                ],
              ),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 13,
                ),
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
                  : _results.isEmpty
                  ? Center(
                      child: Text(
                        'Қидирувни бошланг',
                        style: TextStyle(
                          color: context.colors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final product = _results[index];
                        final isExisting = widget.existingProductIds.contains(
                          product.id,
                        );
                        final isChecked = _selected.contains(product.id);

                        return ListTile(
                          dense: true,
                          leading: Checkbox(
                            value: isChecked || isExisting,
                            onChanged: isExisting
                                ? null
                                : (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selected.add(product.id);
                                      } else {
                                        _selected.remove(product.id);
                                      }
                                    });
                                  },
                            activeColor: isExisting
                                ? context.colors.textMuted
                                : AppColors.accent,
                          ),
                          title: Text(
                            product.name,
                            style: TextStyle(
                              color: isExisting
                                  ? context.colors.textMuted
                                  : context.colors.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            isExisting
                                ? 'Аллақачон қўшилган'
                                : formatMoney(product.priceUzs),
                            style: TextStyle(
                              color: isExisting
                                  ? context.colors.textMuted
                                  : context.colors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
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
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.colors.textSecondary,
                      side: BorderSide(color: context.colors.border),
                    ),
                    child: const Text('Бекор'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _selected.isNotEmpty && !_saving
                        ? _addSelected
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text('Қўшиш (${_selected.length})'),
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
