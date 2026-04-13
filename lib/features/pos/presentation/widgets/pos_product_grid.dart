import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_terminal/core/constants/app_colors.dart';
import 'package:pos_terminal/features/pos/data/models/product_model.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/cart/cart_bloc.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/cart/cart_event.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/product/product_bloc.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/product/product_event.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/product/product_state.dart';
import 'package:pos_terminal/features/pos/presentation/pos_screen.dart';
import 'package:pos_terminal/features/pos/presentation/widgets/pos_numeric_keyboard.dart';
import 'package:pos_terminal/features/pos/presentation/widgets/product_quantity_dialog.dart';
import 'package:pos_terminal/core/constants/app_colors_extension.dart';

class PosProductGrid extends StatelessWidget {
  final ActiveInputController? activeInput;

  const PosProductGrid({super.key, this.activeInput});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar at top
        const _SearchBar(),
        // Product grid
        Expanded(
          child: BlocBuilder<ProductBloc, ProductState>(
            builder: (context, state) {
              if (state is ProductLoading) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                );
              }

              if (state is ProductError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppColors.danger,
                        size: 48,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        state.message,
                        style: TextStyle(color: context.colors.textSecondary),
                      ),
                    ],
                  ),
                );
              }

              if (state is ProductLoaded) {
                if (state.products.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          color: context.colors.textMuted,
                          size: 48,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Маҳсулот топилмади',
                          style: TextStyle(
                            color: context.colors.textMuted,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth > 900
                        ? 3
                        : constraints.maxWidth > 600
                        ? 3
                        : 2;

                    return GridView.builder(
                      padding: const EdgeInsets.all(10),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: 1.0,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: state.products.length,
                      itemBuilder: (context, index) {
                        return _ProductCard(
                          product: state.products[index],
                          activeInput: activeInput,
                        );
                      },
                    );
                  },
                );
              }

              // Initial state
              return Center(
                child: Text(
                  'Маҳсулотларни юклаш...',
                  style: TextStyle(color: context.colors.textMuted),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ProductModel product;
  final ActiveInputController? activeInput;

  const _ProductCard({required this.product, this.activeInput});

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
          onTap: isOutOfStock
              ? null
              : () async {
                  final qty = await ProductQuantityDialog.show(
                    context,
                    product,
                    activeInput: activeInput,
                  );
                  if (qty != null && context.mounted) {
                    context.read<CartBloc>().add(
                      CartItemAddedWithQuantity(
                        product: product,
                        quantity: qty,
                      ),
                    );
                  }
                },
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                Expanded(
                  child: Text(
                    product.name,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                // Code
                if (product.code.isNotEmpty)
                  Text(
                    product.code,
                    style: TextStyle(
                      color: context.colors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                const SizedBox(height: 4),
                // Price + Stock row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${formatMoneyShort(product.priceUzs)} сўм',
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    // Stock badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: isOutOfStock
                            ? AppColors.danger.withValues(alpha: 0.2)
                            : product.quantity <= 5
                            ? AppColors.warning.withValues(alpha: 0.2)
                            : AppColors.success.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isOutOfStock
                            ? 'Йўқ'
                            : '${product.quantity.round()} ${unitLabelFor(product.unitType)}',
                        style: TextStyle(
                          color: isOutOfStock
                              ? AppColors.danger
                              : product.quantity <= 5
                              ? AppColors.warning
                              : AppColors.success,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                // Item type badge
                if (product.itemType != 'product') ...[
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: product.itemType == 'part'
                          ? AppColors.info.withValues(alpha: 0.2)
                          : AppColors.warning.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      product.itemType == 'part'
                          ? 'Қисм'
                          : unitLabelFor(product.unitType).toUpperCase(),
                      style: TextStyle(
                        color: product.itemType == 'part'
                            ? AppColors.info
                            : AppColors.warning,
                        fontSize: 10,
                      ),
                    ),
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

class _SearchBar extends StatefulWidget {
  const _SearchBar();

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: context.colors.surface,
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _controller,
        builder: (context, value, _) {
          return TextField(
            controller: _controller,
            style: TextStyle(color: context.colors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Қидириш (Номи / Баркод / OEM)',
              hintStyle: TextStyle(
                color: context.colors.textMuted,
                fontSize: 14,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: context.colors.textSecondary,
                size: 20,
              ),
              suffixIcon: value.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear,
                        color: context.colors.textMuted,
                        size: 18,
                      ),
                      onPressed: () {
                        _controller.clear();
                        context.read<ProductBloc>().add(
                          const ProductSearchRequested(query: ''),
                        );
                      },
                    )
                  : null,
              filled: true,
              fillColor: context.colors.surfaceLight,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) {
              context.read<ProductBloc>().add(
                ProductSearchRequested(query: value),
              );
            },
          );
        },
      ),
    );
  }
}
