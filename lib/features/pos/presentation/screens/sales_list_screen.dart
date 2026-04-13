import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pos_terminal/core/constants/app_colors.dart';
import 'package:pos_terminal/core/di/injection.dart';
import 'package:pos_terminal/features/pos/data/models/sale_model.dart';
import 'package:pos_terminal/features/pos/data/pos_repository.dart';
import 'package:pos_terminal/features/pos/presentation/pos_screen.dart';
import 'package:pos_terminal/features/pos/presentation/widgets/receipt_preview.dart';
import 'package:pos_terminal/core/constants/app_colors_extension.dart';

class SalesListScreen extends StatefulWidget {
  const SalesListScreen({super.key});

  @override
  State<SalesListScreen> createState() => _SalesListScreenState();
}

class _SalesListScreenState extends State<SalesListScreen> {
  List<SaleModel> _sales = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  int _page = 1;
  static const _pageSize = 30;
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  // Filters
  String? _selectedStatus;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _loadSales();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore || !_hasMore) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= maxScroll * 0.8) {
      _loadMore();
    }
  }

  String? _formatDate(DateTime? dt) {
    if (dt == null) return null;
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadSales() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
    });
    try {
      final sales = await getIt<PosRepository>().getSalesList(
        pageSize: _pageSize,
        page: 1,
        dateFrom: _formatDate(_dateRange?.start),
        dateTo: _formatDate(_dateRange?.end),
        status: _selectedStatus,
        search: _searchController.text.isNotEmpty
            ? _searchController.text
            : null,
        forceRefresh: true,
      );
      if (mounted) {
        setState(() {
          _sales = sales;
          _loading = false;
          _hasMore = sales.length >= _pageSize;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final nextPage = _page + 1;
      final moreSales = await getIt<PosRepository>().getSalesList(
        pageSize: _pageSize,
        page: nextPage,
        dateFrom: _formatDate(_dateRange?.start),
        dateTo: _formatDate(_dateRange?.end),
        status: _selectedStatus,
        search: _searchController.text.isNotEmpty
            ? _searchController.text
            : null,
      );
      if (mounted) {
        setState(() {
          _sales.addAll(moreSales);
          _page = nextPage;
          _hasMore = moreSales.length >= _pageSize;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _viewReceipt(int saleId) async {
    try {
      final receipt = await getIt<PosRepository>().getReceipt(saleId);
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => ReceiptPreviewDialog(receipt: receipt),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Чекни юклашда хатолик: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: now,
      initialDateRange:
          _dateRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          ),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: (isDark ? ThemeData.dark() : ThemeData.light()).copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: AppColors.accent,
                    surface: context.colors.surface,
                  )
                : ColorScheme.light(
                    primary: AppColors.accent,
                    surface: context.colors.surface,
                  ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
      _loadSales();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: Column(
        children: [
          // ── Header ──
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
                const Icon(
                  Icons.receipt_long,
                  color: AppColors.accent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Барча савдолар',
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                // Search
                SizedBox(
                  width: 220,
                  height: 36,
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Қидириш...',
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
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 12,
                      ),
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
                    ),
                    onSubmitted: (_) => _loadSales(),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),

          // ── Filters bar ──
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: context.colors.surface,
              border: Border(bottom: BorderSide(color: context.colors.border)),
            ),
            child: Row(
              children: [
                // Status chips
                ..._buildStatusChips(),
                const Spacer(),
                // Date range
                _FilterButton(
                  icon: Icons.calendar_today,
                  label: _dateRange != null
                      ? '${_formatDate(_dateRange!.start)} — ${_formatDate(_dateRange!.end)}'
                      : 'Сана',
                  isActive: _dateRange != null,
                  onTap: _pickDateRange,
                ),
                if (_dateRange != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 16,
                      color: context.colors.textMuted,
                    ),
                    onPressed: () {
                      setState(() => _dateRange = null);
                      _loadSales();
                    },
                    splashRadius: 14,
                  ),
                ],
              ],
            ),
          ),

          // ── Content ──
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  )
                : _error != null
                ? _buildError()
                : _sales.isEmpty
                ? Center(
                    child: Text(
                      'Савдолар топилмади',
                      style: TextStyle(
                        color: context.colors.textMuted,
                        fontSize: 14,
                      ),
                    ),
                  )
                : _buildSalesList(),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStatusChips() {
    const statuses = [
      (null, 'Барчаси'),
      ('paid', 'Тўланган'),
      ('open', 'Очиқ'),
      ('voided', 'Бекор'),
      ('refunded', 'Қайтарилган'),
    ];
    return statuses.map((e) {
      final (value, label) = e;
      final isSelected = _selectedStatus == value;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          label: Text(label, style: const TextStyle(fontSize: 11)),
          selected: isSelected,
          onSelected: (_) {
            setState(() => _selectedStatus = value);
            _loadSales();
          },
          backgroundColor: context.colors.surfaceLight,
          selectedColor: AppColors.accent.withValues(alpha: 0.2),
          labelStyle: TextStyle(
            color: isSelected ? AppColors.accent : context.colors.textSecondary,
          ),
          side: BorderSide(
            color: isSelected ? AppColors.accent : context.colors.border,
          ),
          visualDensity: VisualDensity.compact,
        ),
      );
    }).toList();
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 32),
          const SizedBox(height: 8),
          Text(
            _error!,
            style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: _loadSales, child: const Text('Қайта уриниш')),
        ],
      ),
    );
  }

  Widget _buildSalesList() {
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _sales.length + (_loadingMore ? 1 : 0),
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: context.colors.border),
      itemBuilder: (context, index) {
        if (index >= _sales.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accent,
                ),
              ),
            ),
          );
        }
        final sale = _sales[index];
        return _SaleRow(sale: sale, onTap: () => _viewReceipt(sale.id));
      },
    );
  }
}

// ── Sale row ──────────────────────────────────────────────────
class _SaleRow extends StatelessWidget {
  final SaleModel sale;
  final VoidCallback onTap;

  const _SaleRow({required this.sale, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sale.saleNumber.isNotEmpty
                        ? '#${sale.saleNumber}'
                        : '#${sale.id}',
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (sale.createdAt != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _formatDateTime(sale.createdAt!),
                      style: TextStyle(
                        color: context.colors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                sale.customerName ?? '—',
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                formatMoney(sale.totalUzs),
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _StatusBadge(status: sale.status, isCredit: sale.isCreditSale),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final mo = dt.month.toString().padLeft(2, '0');
      return '$d.$mo.${dt.year}  $h:$m';
    } catch (_) {
      return isoDate;
    }
  }
}

// ── Status badge ──────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String status;
  final bool isCredit;

  const _StatusBadge({required this.status, required this.isCredit});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'paid' when isCredit => ('Қарз', AppColors.warning),
      'paid' => ('Тўланган', AppColors.success),
      'open' => ('Очиқ', AppColors.info),
      'voided' => ('Бекор', AppColors.danger),
      'refunded' => ('Қайтарилган', AppColors.danger),
      _ => (status, context.colors.textMuted),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Filter button ─────────────────────────────────────────────
class _FilterButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive
          ? AppColors.accent.withValues(alpha: 0.15)
          : context.colors.surfaceLight,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isActive ? AppColors.accent : context.colors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isActive
                      ? AppColors.accent
                      : context.colors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
