import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_terminal/core/constants/app_colors.dart';
import 'package:pos_terminal/features/pos/data/models/cart_item_model.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/cart/cart_bloc.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/cart/cart_event.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/cart/cart_state.dart';
import 'package:pos_terminal/features/pos/presentation/pos_screen.dart';
import 'package:pos_terminal/features/pos/presentation/widgets/cart_item_edit_dialog.dart';
import 'package:pos_terminal/features/pos/presentation/widgets/pos_numeric_keyboard.dart';
import 'package:pos_terminal/core/constants/app_colors_extension.dart';

class PosCartPanel extends StatelessWidget {
  final ActiveInputController activeInput;

  const PosCartPanel({super.key, required this.activeInput});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartBloc, CartState>(
      builder: (context, state) {
        return Column(
          children: [
            // Header
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              color: context.colors.surface,
              child: Row(
                children: [
                  const Icon(
                    Icons.receipt_long,
                    color: AppColors.accent,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'САВАТ (${state.itemCount})',
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (state.isNotEmpty)
                    IconButton(
                      icon: const Icon(
                        Icons.delete_sweep_outlined,
                        color: AppColors.danger,
                        size: 18,
                      ),
                      iconSize: 18,
                      tooltip: 'Тозалаш',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        context.read<CartBloc>().add(const CartCleared());
                      },
                    ),
                ],
              ),
            ),

            // Cart items list
            Expanded(
              child: state.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shopping_cart_outlined,
                            color: context.colors.textMuted,
                            size: 40,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Сават бўш',
                            style: TextStyle(
                              color: context.colors.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      itemCount: state.items.length,
                      onReorder: (oldIndex, newIndex) {
                        context.read<CartBloc>().add(
                          CartItemReordered(
                            oldIndex: oldIndex,
                            newIndex: newIndex,
                          ),
                        );
                      },
                      itemBuilder: (context, index) {
                        return _CartItemTile(
                          key: ValueKey(state.items[index].cartKey),
                          item: state.items[index],
                          index: index,
                          activeInput: activeInput,
                        );
                      },
                    ),
            ),

            // Numeric keyboard
            PosNumericKeyboard(controller: activeInput),
          ],
        );
      },
    );
  }
}

class _CartItemTile extends StatelessWidget {
  final CartItemModel item;
  final int index;
  final ActiveInputController activeInput;

  const _CartItemTile({
    super.key,
    required this.item,
    required this.index,
    required this.activeInput,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final result = await CartItemEditDialog.show(
          context,
          item,
          activeInput: activeInput,
        );
        if (result != null && context.mounted) {
          context.read<CartBloc>().add(
            CartQuantityUpdated(cartKey: item.cartKey, quantity: result),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: context.colors.border, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Drag handle
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(
                  Icons.drag_indicator,
                  color: context.colors.textMuted,
                  size: 20,
                ),
              ),
            ),

            // Product info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${formatMoneyShort(item.priceUzs)} сўм × ${item.allowsDecimalQuantity ? item.quantity.toStringAsFixed(2) : item.quantity.toInt()}',
                    style: TextStyle(
                      color: context.colors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // Quantity controls
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _QtyButton(
                  icon: Icons.remove,
                  onPressed: () {
                    context.read<CartBloc>().add(
                      CartQuantityUpdated(
                        cartKey: item.cartKey,
                        quantity: item.quantity - 1,
                      ),
                    );
                  },
                ),
                Container(
                  width: 36,
                  alignment: Alignment.center,
                  child: Text(
                    item.allowsDecimalQuantity
                        ? item.quantity.toStringAsFixed(1)
                        : item.quantity.toInt().toString(),
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _QtyButton(
                  icon: Icons.add,
                  onPressed: () {
                    context.read<CartBloc>().add(
                      CartQuantityUpdated(
                        cartKey: item.cartKey,
                        quantity: item.quantity + 1,
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(width: 10),

            // Line total
            SizedBox(
              width: 90,
              child: Text(
                '${formatMoneyShort(item.lineTotal)} сўм',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // Delete button
            IconButton(
              icon: Icon(
                Icons.close,
                color: context.colors.textMuted,
                size: 18,
              ),
              iconSize: 18,
              padding: const EdgeInsets.only(left: 4),
              constraints: const BoxConstraints(),
              onPressed: () {
                context.read<CartBloc>().add(
                  CartItemRemoved(cartKey: item.cartKey),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _QtyButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        icon: Icon(icon, size: 16),
        padding: EdgeInsets.zero,
        color: context.colors.textSecondary,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: context.colors.surfaceLight,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
    );
  }
}
