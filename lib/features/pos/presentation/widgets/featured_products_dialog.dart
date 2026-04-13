import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_terminal/core/constants/app_colors.dart';
import 'package:pos_terminal/core/di/injection.dart';
import 'package:pos_terminal/features/pos/data/models/product_model.dart';
import 'package:pos_terminal/features/pos/data/pos_repository.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/cart/cart_bloc.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/cart/cart_event.dart';
import 'package:pos_terminal/features/pos/presentation/pos_screen.dart';
import 'package:pos_terminal/features/pos/presentation/widgets/pos_numeric_keyboard.dart';
import 'package:pos_terminal/features/pos/presentation/widgets/product_quantity_dialog.dart';
import 'package:pos_terminal/core/constants/app_colors_extension.dart';

class FeaturedProductsDialog extends StatefulWidget {
  const FeaturedProductsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, anim, secondAnim) => BlocProvider.value(
        value: context.read<CartBloc>(),
        child: const FeaturedProductsDialog(),
      ),
      transitionBuilder: (ctx, anim, secondAnim, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child,
        );
      },
    );
  }

  @override
  State<FeaturedProductsDialog> createState() => _FeaturedProductsDialogState();
}

class _FeaturedProductsDialogState extends State<FeaturedProductsDialog> {
  List<ProductModel> _products = [];
  bool _loading = true;
  String? _error;
  final _activeInput = ActiveInputController();

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _activeInput.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final products = await getIt<PosRepository>().getFeaturedProducts();
      if (mounted) {
        setState(() {
          _products = products;
          _loading = false;
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

  Future<void> _addToCart(ProductModel product) async {
    final qty = await ProductQuantityDialog.show(
      context,
      product,
      activeInput: _activeInput,
    );
    if (qty != null && mounted) {
      context.read<CartBloc>().add(
        CartItemAddedWithQuantity(product: product, quantity: qty),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Align(
      alignment: Alignment.bottomLeft,
      child: Container(
        width: 520,
        height: screenHeight * 0.75,
        margin: const EdgeInsets.only(left: 16, bottom: 16),
        decoration: BoxDecoration(
          color: context.colors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.colors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Column(
            children: [
              // Title bar
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                  border: Border(bottom: BorderSide(color: context.colors.border)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bolt, color: AppColors.warning, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Тез сотув',
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      color: context.colors.textMuted,
                      onPressed: () => Navigator.of(context).pop(),
                      splashRadius: 16,
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.warning,
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
                                  _loadProducts();
                                },
                                child: const Text('Қайта уриниш'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _products.isEmpty
                    ? Center(
                        child: Text(
                          'Тез сотув маҳсулотлари топилмади',
                          style: TextStyle(
                            color: context.colors.textMuted,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 1.3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                        itemCount: _products.length,
                        itemBuilder: (context, index) {
                          final product = _products[index];
                          return _FeaturedCard(
                            product: product,
                            onTap: product.inStock
                                ? () => _addToCart(product)
                                : null,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback? onTap;

  const _FeaturedCard({required this.product, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isOutOfStock = !product.inStock;
    return Opacity(
      opacity: isOutOfStock ? 0.4 : 1.0,
      child: Material(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                Expanded(
                  child: Text(
                    product.name,
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 4),
                // Price
                Text(
                  formatMoney(product.priceUzs),
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                // Stock
                Row(
                  children: [
                    Icon(
                      isOutOfStock ? Icons.block : Icons.inventory_2_outlined,
                      size: 11,
                      color: isOutOfStock
                          ? AppColors.danger
                          : context.colors.textMuted,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      isOutOfStock
                          ? 'Йўқ'
                          : '${product.quantity} ${unitLabelFor(product.unitType)}',
                      style: TextStyle(
                        color: isOutOfStock
                            ? AppColors.danger
                            : context.colors.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
