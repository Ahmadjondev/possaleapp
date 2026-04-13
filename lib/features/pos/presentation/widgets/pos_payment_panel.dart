import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_terminal/core/constants/app_colors.dart';
import 'package:pos_terminal/core/di/injection.dart';
import 'package:pos_terminal/core/printing/receipt_builder.dart';
import 'package:pos_terminal/core/printing/printer_config.dart';
import 'package:pos_terminal/core/printing/printer_service.dart';
import 'package:pos_terminal/features/pos/data/models/payment_model.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/cart/cart_bloc.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/cart/cart_event.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/cart/cart_state.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/customer/customer_bloc.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/draft/draft_bloc.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/payment/payment_bloc.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/payment/payment_event.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/payment/payment_state.dart';
import 'package:pos_terminal/features/pos/presentation/pos_screen.dart';
import 'package:pos_terminal/features/pos/presentation/widgets/customer_autocomplete.dart';
import 'package:pos_terminal/features/pos/presentation/widgets/pos_numeric_keyboard.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_terminal/core/constants/app_colors_extension.dart';

class PosPaymentPanel extends StatefulWidget {
  final int warehouseId;
  final ActiveInputController activeInput;
  final TextEditingController noteController;

  const PosPaymentPanel({
    super.key,
    required this.warehouseId,
    required this.activeInput,
    required this.noteController,
  });

  @override
  State<PosPaymentPanel> createState() => _PosPaymentPanelState();
}

class _PosPaymentPanelState extends State<PosPaymentPanel> {
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _discountController = TextEditingController();

  final _amountFocus = FocusNode();
  final _discountFocus = FocusNode();

  bool _isMixed = false;

  @override
  void initState() {
    super.initState();
    // Load drafts so badge count is available immediately
    context.read<DraftBloc>().add(const DraftsLoadRequested());

    // Register numeric fields with active input controller on focus
    _amountFocus.addListener(() {
      if (_amountFocus.hasFocus) {
        widget.activeInput.setActive(
          _amountController,
          maxDigits: kMaxMoneyInputDigits,
        );
      }
    });
    _discountFocus.addListener(() {
      if (_discountFocus.hasFocus) {
        widget.activeInput.setActive(
          _discountController,
          maxDigits: kMaxMoneyInputDigits,
        );
      }
    });

    // Sync amount changes from numpad to BLoC
    _amountController.addListener(_onAmountTextChanged);
    _discountController.addListener(_onDiscountTextChanged);
  }

  void _onAmountTextChanged() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    context.read<PaymentBloc>().add(PaymentAmountEntered(amount: amount));
  }

  void _onDiscountTextChanged() {
    final paymentState = context.read<PaymentBloc>().state;
    if (paymentState is! PaymentInProgress) return;
    final value = double.tryParse(_discountController.text) ?? 0;
    context.read<PaymentBloc>().add(
      PaymentDiscountChanged(type: paymentState.discountType, value: value),
    );
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountTextChanged);
    _discountController.removeListener(_onDiscountTextChanged);
    _amountController.dispose();
    _referenceController.dispose();
    _discountController.dispose();
    _amountFocus.dispose();
    _discountFocus.dispose();
    super.dispose();
  }

  void _syncCartToPayment(CartState cartState) {
    if (cartState.isNotEmpty) {
      context.read<PaymentBloc>().add(
        PaymentStarted(
          items: cartState.items,
          subtotalUzs: cartState.subtotalUzs,
        ),
      );

      // Sync customer if selected
      final customerState = context.read<CustomerBloc>().state;
      if (customerState is CustomerSelectedState) {
        context.read<PaymentBloc>().add(
          PaymentCustomerSelected(
            customer: customerState.customer,
            balance: customerState.balance,
          ),
        );
      }
    } else {
      context.read<PaymentBloc>().add(const PaymentCancelled());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        // Auto-sync cart data to PaymentBloc
        BlocListener<CartBloc, CartState>(
          listener: (context, cartState) => _syncCartToPayment(cartState),
        ),
        // Handle payment success — auto-print receipt if enabled
        BlocListener<PaymentBloc, PaymentState>(
          listener: (context, paymentState) async {
            if (paymentState is PaymentSuccess) {
              widget.noteController.clear();
              _amountController.clear();
              _discountController.clear();
              _referenceController.clear();
              // Re-read from SharedPreferences (sidebar may have toggled it)
              final prefs = await SharedPreferences.getInstance();
              final autoPrint = prefs.getBool('pos_auto_print') ?? false;
              if (autoPrint && paymentState.receipt != null) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Чек чоп этилмоқда...'),
                    duration: Duration(seconds: 2),
                    backgroundColor: AppColors.info,
                  ),
                );
                final result = await ReceiptBuilder.printReceipt(
                  paymentState.receipt!,
                  getIt<PrinterService>(),
                  getIt<PrinterConfigStorage>(),
                );
                if (!context.mounted) return;
                if (!result.success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Чек хатолиги: ${result.error}'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                }
              }
            }
          },
        ),
        // Auto-sync customer to PaymentBloc
        BlocListener<CustomerBloc, CustomerState>(
          listener: (context, customerState) {
            final paymentState = context.read<PaymentBloc>().state;
            if (paymentState is PaymentInProgress) {
              if (customerState is CustomerSelectedState) {
                context.read<PaymentBloc>().add(
                  PaymentCustomerSelected(
                    customer: customerState.customer,
                    balance: customerState.balance,
                  ),
                );
              } else if (customerState is CustomerInitial) {
                context.read<PaymentBloc>().add(const PaymentCustomerCleared());
              }
            }
          },
        ),
        // Draft save/error feedback
        BlocListener<DraftBloc, DraftState>(
          listener: (context, draftState) {
            if (draftState is DraftSaved) {
              context.read<CartBloc>().add(const CartCleared());
              widget.noteController.clear();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Қоралама сақланди'),
                  duration: Duration(seconds: 2),
                  backgroundColor: AppColors.success,
                ),
              );
            } else if (draftState is DraftError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(draftState.message),
                  backgroundColor: AppColors.danger,
                ),
              );
            }
          },
        ),
      ],
      child: BlocBuilder<PaymentBloc, PaymentState>(
        builder: (context, paymentState) {
          if (paymentState is PaymentProcessing) {
            return _buildProcessing();
          }
          if (paymentState is PaymentInProgress) {
            return _buildPanel(paymentState);
          }
          // Idle — either cart is empty or we need to auto-start
          return BlocBuilder<CartBloc, CartState>(
            builder: (context, cartState) {
              if (cartState.isNotEmpty) {
                // Auto-start will happen via listener, show loading briefly
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _syncCartToPayment(cartState);
                });
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                );
              }
              return _buildEmptyState();
            },
          );
        },
      ),
    );
  }

  // ── Processing ──────────────────────────────────────────────

  Widget _buildProcessing() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.accent),
          SizedBox(height: 16),
          Text(
            'Тўлов қабул қилинмоқда...',
            style: TextStyle(color: context.colors.textPrimary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ── Empty state ─────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Column(
      children: [
        _buildHeader('ТЎЛОВ'),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.point_of_sale_outlined,
                  color: context.colors.textMuted,
                  size: 40,
                ),
                SizedBox(height: 8),
                Text(
                  'Маҳсулот қўшинг',
                  style: TextStyle(
                    color: context.colors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Unified panel ───────────────────────────────────────────

  void _addMixedPayment(PaymentInProgress state) {
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) return;
    context.read<PaymentBloc>().add(
      PaymentItemAdded(
        paymentItem: PaymentItemModel(
          method: state.method,
          amountUzs: amount,
          reference: _referenceController.text,
        ),
      ),
    );
    _amountController.clear();
    _referenceController.clear();
    context.read<PaymentBloc>().add(const PaymentAmountEntered(amount: 0));
  }

  Widget _buildPanel(PaymentInProgress state) {
    return Column(
      children: [
        _buildHeader('ТЎЛОВ'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer
                _buildSectionLabel(Icons.person_outline, 'МИЖОЗ'),
                const SizedBox(height: 8),
                _buildCustomerSection(state),
                const SizedBox(height: 18),

                // Totals
                _buildSectionLabel(Icons.calculate_outlined, 'ҲИСОБ-КИТОБ'),
                const SizedBox(height: 8),
                _buildTotalSection(state),
                const SizedBox(height: 18),

                // Discount
                _buildDiscountSection(state),
                const SizedBox(height: 18),

                // Payment method
                _buildPaymentMethodSection(state),
                const SizedBox(height: 14),

                // Amount entry
                if (state.method != PaymentMethod.debt)
                  _buildAmountEntry(state),

                // Reference field
                if (state.method == PaymentMethod.p2p ||
                    state.method == PaymentMethod.bank) ...[
                  const SizedBox(height: 12),
                  _buildReferenceField(),
                ],

                // Mixed payment: added items list
                if (_isMixed && state.paymentItems.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _buildMixedPaymentsList(state),
                ],

                // Mixed payment summary
                if (_isMixed) ...[
                  const SizedBox(height: 12),
                  _buildMixedSummary(state),
                ],

                // Note
                const SizedBox(height: 12),
                _buildNoteField(),
              ],
            ),
          ),
        ),
        _buildFooter(state),
      ],
    );
  }

  Widget _buildTotalSection(PaymentInProgress state) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          _totalRow('Жами:', formatMoney(state.subtotalUzs)),
          if (state.discountAmountUzs > 0) ...[
            const SizedBox(height: 4),
            _totalRow(
              'Чегирма:',
              '-${formatMoney(state.discountAmountUzs)}',
              color: AppColors.danger,
            ),
          ],
          if (state.balanceAppliedUzs > 0) ...[
            const SizedBox(height: 4),
            _totalRow(
              'Баланс:',
              '-${formatMoney(state.balanceAppliedUzs)}',
              color: AppColors.success,
            ),
          ],
          Divider(color: context.colors.border, height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Тўлов суммаси:',
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                formatMoney(state.effectiveTotalUzs),
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color ?? context.colors.textSecondary,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color ?? context.colors.textPrimary,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildDiscountSection(PaymentInProgress state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Чегирма:',
          style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SegmentedButton<DiscountType>(
                segments: const [
                  ButtonSegment(value: DiscountType.none, label: Text('Йўқ')),
                  ButtonSegment(value: DiscountType.percent, label: Text('%')),
                  ButtonSegment(value: DiscountType.amount, label: Text('Сум')),
                ],
                selected: {state.discountType},
                onSelectionChanged: (set) {
                  final type = set.first;
                  final value = double.tryParse(_discountController.text) ?? 0;
                  context.read<PaymentBloc>().add(
                    PaymentDiscountChanged(type: type, value: value),
                  );
                },
                style: SegmentedButton.styleFrom(
                  foregroundColor: context.colors.textSecondary,
                  selectedForegroundColor: Colors.white,
                  selectedBackgroundColor: AppColors.accent,
                  textStyle: const TextStyle(fontSize: 11),
                ),
              ),
            ),
          ],
        ),
        if (state.discountType != DiscountType.none) ...[
          const SizedBox(height: 6),
          TextField(
            controller: _discountController,
            focusNode: _discountFocus,
            readOnly: true,
            showCursor: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              LengthLimitingTextInputFormatter(kMaxMoneyInputDigits),
            ],
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: state.discountType == DiscountType.percent ? '0%' : '0',
              hintStyle: TextStyle(
                color: context.colors.textMuted,
                fontSize: 16,
              ),
              filled: true,
              fillColor: context.colors.surfaceLight,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCustomerSection(PaymentInProgress state) {
    if (state.customer != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: context.colors.surfaceLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, color: AppColors.accent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.customer!.displayName,
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: context.colors.textMuted,
                  onPressed: () {
                    context.read<CustomerBloc>().add(const CustomerCleared());
                  },
                ),
              ],
            ),
            if (state.customerBalance != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (state.customerBalance!.debtUzs > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Қарз: ${formatMoneyShort(state.customerBalance!.debtUzs)}',
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (state.customerBalance!.creditUzs > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Баланс: ${formatMoneyShort(state.customerBalance!.creditUzs)}',
                        style: const TextStyle(
                          color: AppColors.success,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      height: 20,
                      child: Switch(
                        value: state.useBalance,
                        onChanged: (_) {
                          context.read<PaymentBloc>().add(
                            const PaymentUseBalanceToggled(),
                          );
                        },

                        activeTrackColor: AppColors.success,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                  if (state.customerBalance!.availableDebtUzs > 0) ...[
                    const Spacer(),
                    Text(
                      'Қарз лимит: ${formatMoneyShort(state.customerBalance!.availableDebtUzs)}',
                      style: TextStyle(
                        color: context.colors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      );
    }
    return const CustomerAutocomplete();
  }

  Widget _buildPaymentMethodSection(PaymentInProgress state) {
    return Row(
      children: PaymentMethod.values.map((method) {
        final isSelected = state.method == method;
        final isEnabled =
            method != PaymentMethod.debt || state.customer != null;
        return Expanded(
          child: GestureDetector(
            onTap: isEnabled
                ? () => context.read<PaymentBloc>().add(
                    PaymentMethodChanged(method: method),
                  )
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isSelected ? AppColors.accent : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                method.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? AppColors.accent
                      : isEnabled
                      ? context.colors.textSecondary
                      : context.colors.textMuted.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAmountEntry(PaymentInProgress state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _amountController,
                focusNode: _amountFocus,
                readOnly: true,
                showCursor: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  LengthLimitingTextInputFormatter(kMaxMoneyInputDigits),
                ],
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: _isMixed
                      ? '0'
                      : formatMoneyShort(state.effectiveTotalUzs),
                  hintStyle: TextStyle(
                    color: context.colors.textMuted,
                    fontSize: 18,
                  ),
                  filled: true,
                  fillColor: context.colors.surfaceLight,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  suffixText: 'сўм',
                  suffixStyle: TextStyle(
                    color: context.colors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
            if (_isMixed) ...[
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: (double.tryParse(_amountController.text) ?? 0) > 0
                      ? () => _addMixedPayment(state)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.accent.withValues(
                      alpha: 0.3,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text(
                    'Қўшиш',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            if (_isMixed)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: _QuickAmountChip(
                  label: 'Қолган',
                  onTap: () {
                    final remaining = state.remainingUzs;
                    if (remaining > 0) {
                      _amountController.text = remaining.toStringAsFixed(0);
                      context.read<PaymentBloc>().add(
                        PaymentAmountEntered(amount: remaining),
                      );
                    }
                  },
                ),
              )
            else
              _QuickAmountChip(
                label: 'Аниқ',
                onTap: () {
                  final exact = state.effectiveTotalUzs;
                  _amountController.text = exact.toStringAsFixed(0);
                  context.read<PaymentBloc>().add(
                    PaymentAmountEntered(amount: exact),
                  );
                },
              ),
            ...[1000, 5000, 10000, 50000, 100000].map(
              (v) => Padding(
                padding: const EdgeInsets.only(left: 4),
                child: _QuickAmountChip(
                  label: _formatQuick(v),
                  onTap: () {
                    final current =
                        double.tryParse(_amountController.text) ?? 0;
                    final newVal = current + v;
                    _amountController.text = newVal.toStringAsFixed(0);
                    context.read<PaymentBloc>().add(
                      PaymentAmountEntered(amount: newVal),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMixedPaymentsList(PaymentInProgress state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ТЎЛОВЛАР',
          style: TextStyle(
            color: context.colors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        ...state.paymentItems.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: context.colors.surfaceLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.colors.border),
            ),
            child: Row(
              children: [
                Text(
                  item.method.label,
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (item.reference.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(
                    '(${item.reference})',
                    style: TextStyle(
                      color: context.colors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  formatMoney(item.amountUzs),
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => context.read<PaymentBloc>().add(
                    PaymentItemRemoved(index: idx),
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 16,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMixedSummary(PaymentInProgress state) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Тўланган:',
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 13,
                ),
              ),
              Text(
                formatMoney(state.mixedPaidUzs),
                style: const TextStyle(
                  color: AppColors.success,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Қолган:',
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 13,
                ),
              ),
              Text(
                formatMoney(state.remainingUzs),
                style: TextStyle(
                  color: state.remainingUzs > 0
                      ? AppColors.danger
                      : AppColors.success,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReferenceField() {
    return TextField(
      controller: _referenceController,
      style: TextStyle(color: context.colors.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        hintText: 'Ишора / Реф. рақам',
        hintStyle: TextStyle(color: context.colors.textMuted, fontSize: 15),
        filled: true,
        fillColor: context.colors.surfaceLight,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: (value) {
        context.read<PaymentBloc>().add(
          PaymentReferenceChanged(reference: value),
        );
      },
    );
  }

  Widget _buildNoteField() {
    return TextField(
      controller: widget.noteController,
      style: TextStyle(color: context.colors.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        hintText: 'Изоҳ (ихтиёрий)',
        hintStyle: TextStyle(color: context.colors.textMuted, fontSize: 15),
        filled: true,
        fillColor: context.colors.surfaceLight,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildFooter(PaymentInProgress state) {
    if (state.changeDueUzs <= 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: context.colors.border)),
      ),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Қайтим:',
              style: TextStyle(
                color: AppColors.success,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              formatMoney(state.changeDueUzs),
              style: const TextStyle(
                color: AppColors.success,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Shared helpers ─────────────────────────────────────────

  Widget _buildHeader(String title) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      color: context.colors.surface,
      child: Row(
        children: [
          const Icon(Icons.payment, color: AppColors.accent, size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),

          GestureDetector(
            onTap: () {
              setState(() => _isMixed = !_isMixed);
              if (!_isMixed) {
                // Clear mixed payments when toggling off
                final paymentState = context.read<PaymentBloc>().state;
                if (paymentState is PaymentInProgress &&
                    paymentState.paymentItems.isNotEmpty) {
                  for (
                    var i = paymentState.paymentItems.length - 1;
                    i >= 0;
                    i--
                  ) {
                    context.read<PaymentBloc>().add(
                      PaymentItemRemoved(index: i),
                    );
                  }
                }
              }
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 18,
                  width: 18,
                  child: Checkbox(
                    value: _isMixed,
                    onChanged: (v) {
                      setState(() => _isMixed = v ?? false);
                      if (!_isMixed) {
                        final paymentState = context.read<PaymentBloc>().state;
                        if (paymentState is PaymentInProgress &&
                            paymentState.paymentItems.isNotEmpty) {
                          for (
                            var i = paymentState.paymentItems.length - 1;
                            i >= 0;
                            i--
                          ) {
                            context.read<PaymentBloc>().add(
                              PaymentItemRemoved(index: i),
                            );
                          }
                        }
                      }
                    },
                    activeColor: AppColors.accent,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Аралаш',
                  style: TextStyle(
                    color: _isMixed
                        ? AppColors.accent
                        : context.colors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: context.colors.textMuted, size: 16),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            color: context.colors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  String _formatQuick(int amount) {
    if (amount >= 1000) return '${amount ~/ 1000}к';
    return '$amount';
  }
}

class _QuickAmountChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickAmountChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: context.colors.surfaceLight,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
        ),
      ),
    );
  }
}
