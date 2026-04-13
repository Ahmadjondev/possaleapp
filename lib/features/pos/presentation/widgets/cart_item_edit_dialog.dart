import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_terminal/core/constants/app_colors.dart';
import 'package:pos_terminal/features/pos/data/models/cart_item_model.dart';
import 'package:pos_terminal/features/pos/presentation/pos_screen.dart';
import 'package:pos_terminal/features/pos/presentation/widgets/pos_dialog.dart';
import 'package:pos_terminal/features/pos/presentation/widgets/pos_numeric_keyboard.dart';
import 'package:pos_terminal/core/constants/app_colors_extension.dart';

/// Dialog to edit a cart item's quantity.
/// Returns the new quantity, or null if cancelled.
class CartItemEditDialog extends StatefulWidget {
  final CartItemModel item;
  final ActiveInputController? activeInput;
  final bool _useDialogShell;

  const CartItemEditDialog({
    super.key,
    required this.item,
    this.activeInput,
    bool useDialogShell = true,
  }) : _useDialogShell = useDialogShell;

  static Future<double?> show(
    BuildContext context,
    CartItemModel item, {
    ActiveInputController? activeInput,
  }) {
    if (activeInput == null) {
      return showDialog<double>(
        context: context,
        builder: (_) => CartItemEditDialog(item: item),
      );
    }

    return showDialog<double>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Dialog panel — no Dialog wrapper, same size
                CartItemEditDialog(
                  item: item,
                  activeInput: activeInput,
                  useDialogShell: false,
                ),
                const SizedBox(width: 12),
                // Keyboard panel — separate floating panel
                Container(
                  width: 300,
                  decoration: BoxDecoration(
                    color: context.colors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.colors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: context.colors.surface,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                          border: Border(
                            bottom: BorderSide(color: context.colors.border),
                          ),
                        ),
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            Icon(
                              Icons.dialpad,
                              size: 14,
                              color: context.colors.textMuted,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Клавиатура',
                              style: TextStyle(
                                color: context.colors.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PosNumericKeyboard(controller: activeInput, large: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  State<CartItemEditDialog> createState() => _CartItemEditDialogState();
}

class _CartItemEditDialogState extends State<CartItemEditDialog> {
  late final bool _isDecimal;
  late final String _unitLabel;

  late final TextEditingController _qtyController;
  late final TextEditingController _priceController;

  final _qtyFocus = FocusNode();
  final _priceFocus = FocusNode();

  bool _updatingQty = false;
  bool _updatingPrice = false;

  String? _qtyError;

  double get _qty => double.tryParse(_qtyController.text) ?? 0;
  double get _unitPrice => widget.item.priceUzs;

  @override
  void initState() {
    super.initState();
    _isDecimal = widget.item.allowsDecimalQuantity;
    _unitLabel = unitLabelFor(widget.item.unitType);

    _qtyController = TextEditingController(
      text: _isDecimal
          ? widget.item.quantity.toStringAsFixed(2)
          : widget.item.quantity.toInt().toString(),
    );
    _priceController = TextEditingController(
      text: widget.item.lineTotal.toStringAsFixed(0),
    );

    _qtyController.addListener(_onQtyChanged);
    _priceController.addListener(_onPriceChanged);

    // Register focus nodes with active input controller
    _qtyFocus.addListener(() {
      if (_qtyFocus.hasFocus) {
        widget.activeInput?.setActive(_qtyController);
      }
    });
    _priceFocus.addListener(() {
      if (_priceFocus.hasFocus) {
        widget.activeInput?.setActive(
          _priceController,
          maxDigits: kMaxMoneyInputDigits,
        );
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _qtyFocus.requestFocus();
      _qtyController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _qtyController.text.length,
      );
    });
  }

  @override
  void dispose() {
    widget.activeInput?.clearActive();
    _qtyController.dispose();
    _priceController.dispose();
    _qtyFocus.dispose();
    _priceFocus.dispose();
    super.dispose();
  }

  void _onQtyChanged() {
    if (_updatingQty) return;
    if (_qtyError != null) setState(() => _qtyError = null);
    final qty = double.tryParse(_qtyController.text);
    if (qty == null || qty <= 0) return;
    _updatingPrice = true;
    _priceController.text = (qty * _unitPrice).toStringAsFixed(0);
    _updatingPrice = false;
  }

  void _onPriceChanged() {
    if (_updatingPrice) return;
    if (_qtyError != null) setState(() => _qtyError = null);
    final price = double.tryParse(_priceController.text);
    if (price == null || price <= 0 || _unitPrice <= 0) return;
    _updatingQty = true;
    final qty = price / _unitPrice;
    _qtyController.text = _isDecimal
        ? qty.toStringAsFixed(2)
        : qty.round().toString();
    _updatingQty = false;
  }

  void _increment() {
    final step = _isDecimal ? 0.1 : 1.0;
    var qty = _qty + step;
    if (widget.item.maxQuantity > 0 && qty > widget.item.maxQuantity) {
      qty = widget.item.maxQuantity;
    }
    _updatingQty = true;
    _qtyController.text = _isDecimal
        ? qty.toStringAsFixed(1)
        : qty.round().toString();
    _updatingQty = false;
    _onQtyChanged();
  }

  void _decrement() {
    final step = _isDecimal ? 0.1 : 1.0;
    final min = _isDecimal ? 0.1 : 1.0;
    var qty = _qty - step;
    if (qty < min) qty = min;
    _updatingQty = true;
    _qtyController.text = _isDecimal
        ? qty.toStringAsFixed(1)
        : qty.round().toString();
    _updatingQty = false;
    _onQtyChanged();
  }

  void _submit() {
    final qty = _qty;
    if (qty <= 0) {
      setState(() => _qtyError = 'Миқдорни киритинг');
      return;
    }
    final maxQty = widget.item.maxQuantity;
    if (maxQty > 0 && qty > maxQty) {
      final maxStr = _isDecimal
          ? maxQty.toStringAsFixed(1)
          : maxQty.round().toString();
      setState(
        () => _qtyError =
            'Қолдиқ: $maxStr $_unitLabel. $maxStr дан ортиқ киритиб бўлмайди',
      );
      return;
    }
    Navigator.of(context).pop(qty);
  }

  @override
  Widget build(BuildContext context) {
    return PosDialog(
      title: 'Таҳрирлаш',
      icon: Icons.edit,
      width: 380,
      useDialogShell: widget._useDialogShell,
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            foregroundColor: context.colors.textSecondary,
            side: BorderSide(color: context.colors.border),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          child: const Text('Бекор қилиш'),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.check, size: 16),
          label: const Text('Сақлаш'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProductHeader(),
            const SizedBox(height: 16),
            _buildQuantitySection(),
            const SizedBox(height: 12),
            _buildPriceSection(),
            const SizedBox(height: 16),
            _buildSummary(),
          ],
        ),
      ),
    );
  }

  Widget _buildProductHeader() {
    final item = widget.item;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2, color: AppColors.accent, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatMoney(item.priceUzs)} / $_unitLabel',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (item.maxQuantity > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${_isDecimal ? item.maxQuantity.toStringAsFixed(1) : item.maxQuantity.round()} $_unitLabel',
                style: const TextStyle(
                  color: AppColors.success,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuantitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isDecimal ? '⚖️ $_unitLabel киритиш:' : '🔢 Миқдор:',
          style: TextStyle(
            color: context.colors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _StepperButton(icon: Icons.remove, onTap: _decrement),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _qtyController,
                focusNode: _qtyFocus,
                readOnly: widget.activeInput != null,
                showCursor: true,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.numberWithOptions(
                  decimal: _isDecimal,
                ),
                inputFormatters: [
                  if (_isDecimal)
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
                  else
                    FilteringTextInputFormatter.digitsOnly,
                ],
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  hintText: _isDecimal ? '0.0' : '1',
                  hintStyle: TextStyle(
                    color: context.colors.textMuted,
                    fontSize: 22,
                  ),
                  filled: true,
                  fillColor: context.colors.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
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
                  suffixText: _unitLabel,
                  suffixStyle: TextStyle(
                    color: context.colors.textMuted,
                    fontSize: 13,
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(width: 8),
            _StepperButton(icon: Icons.add, onTap: _increment),
          ],
        ),
        if (_qtyError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 14,
                  color: AppColors.danger,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _qtyError!,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPriceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '💰 Сумма киритиш:',
          style: TextStyle(
            color: context.colors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _priceController,
          focusNode: _priceFocus,
          readOnly: widget.activeInput != null,
          showCursor: true,
          textAlign: TextAlign.center,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            LengthLimitingTextInputFormatter(kMaxMoneyInputDigits),
          ],
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: '0',
            hintStyle: TextStyle(color: context.colors.textMuted, fontSize: 22),
            filled: true,
            fillColor: context.colors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
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
            suffixText: 'сўм',
            suffixStyle: TextStyle(
              color: context.colors.textMuted,
              fontSize: 13,
            ),
          ),
          onSubmitted: (_) => _submit(),
        ),
      ],
    );
  }

  Widget _buildSummary() {
    return ListenableBuilder(
      listenable: _qtyController,
      builder: (context, _) {
        final q = double.tryParse(_qtyController.text) ?? 0;
        final t = q * _unitPrice;
        if (q <= 0) return const SizedBox.shrink();

        final qtyStr = _isDecimal ? q.toStringAsFixed(2) : q.round().toString();

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.calculate, color: AppColors.accent, size: 16),
              const SizedBox(width: 8),
              Text(
                '$qtyStr $_unitLabel × ${formatMoneyShort(_unitPrice)} = ${formatMoney(t)}',
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _StepperButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.colors.border),
          ),
          child: Icon(icon, color: context.colors.textSecondary, size: 20),
        ),
      ),
    );
  }
}
