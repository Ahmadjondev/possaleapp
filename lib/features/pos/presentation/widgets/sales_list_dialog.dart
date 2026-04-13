import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_terminal/core/constants/app_colors.dart';
import 'package:pos_terminal/core/di/injection.dart';
import 'package:pos_terminal/features/pos/data/models/sale_model.dart';
import 'package:pos_terminal/features/pos/data/pos_repository.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/payment/payment_bloc.dart';
import 'package:pos_terminal/features/pos/presentation/pos_screen.dart';
import 'package:pos_terminal/features/pos/presentation/widgets/pos_dialog.dart';
import 'package:pos_terminal/features/pos/presentation/widgets/receipt_preview.dart';
import 'package:pos_terminal/core/constants/app_colors_extension.dart';

class SalesListDialog extends StatefulWidget {
  const SalesListDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<PaymentBloc>(),
        child: const SalesListDialog(),
      ),
    );
  }

  @override
  State<SalesListDialog> createState() => _SalesListDialogState();
}

class _SalesListDialogState extends State<SalesListDialog> {
  List<SaleModel> _sales = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  int _page = 1;
  static const _pageSize = 30;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadSales();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
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

  Future<void> _loadSales() async {
    try {
      final sales = await getIt<PosRepository>().getSalesList(
        pageSize: _pageSize,
        page: 1,
      );
      if (mounted) {
        setState(() {
          _sales = sales;
          _loading = false;
          _page = 1;
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

  @override
  Widget build(BuildContext context) {
    return PosDialog(
      title: 'Барча савдолар',
      icon: Icons.receipt_long,
      width: 600,
      child: _loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
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
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _loading = true;
                          _error = null;
                        });
                        _loadSales();
                      },
                      child: const Text('Қайта уриниш'),
                    ),
                  ],
                ),
              ),
            )
          : _sales.isEmpty
          ? Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Савдолар топилмади',
                  style: TextStyle(color: context.colors.textMuted, fontSize: 14),
                ),
              ),
            )
          : ListView.separated(
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
            ),
    );
  }
}

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
            // Sale number + date
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
                      _formatDate(sale.createdAt!),
                      style: TextStyle(
                        color: context.colors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Customer
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
            // Total
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
            // Status badge
            _StatusBadge(status: sale.status, isCredit: sale.isCreditSale),
          ],
        ),
      ),
    );
  }

  String _formatDate(String isoDate) {
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
