import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_terminal/core/constants/app_colors.dart';
import 'package:pos_terminal/features/pos/data/models/payment_model.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/customer/customer_bloc.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/payment/payment_bloc.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/payment/payment_event.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/payment/payment_state.dart';
import 'package:pos_terminal/features/pos/presentation/pos_screen.dart';
import 'package:pos_terminal/features/pos/presentation/widgets/customer_search_dialog.dart';
import 'package:pos_terminal/core/constants/app_colors_extension.dart';

class PaymentDialog extends StatefulWidget {
  final int warehouseId;

  const PaymentDialog({super.key, required this.warehouseId});

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _referenceController = TextEditingController();
  final _discountController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _referenceController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PaymentBloc, PaymentState>(
      builder: (context, state) {
        if (state is PaymentProcessing) {
          return Dialog(
            backgroundColor: context.colors.surface,
            child: SizedBox(
              width: 500,
              height: 300,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: AppColors.accent),
                    const SizedBox(height: 16),
                    Text(
                      'Тўлов қабул қилинмоқда...',
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (state is! PaymentInProgress) return const SizedBox.shrink();

        return Dialog(
          backgroundColor: context.colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: SizedBox(
            width: 600,
            height: 580,
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Total info
                        _buildTotalSection(state),
                        const SizedBox(height: 20),

                        // Discount section
                        _buildDiscountSection(context, state),
                        const SizedBox(height: 16),

                        // Customer section
                        _buildCustomerSection(context, state),
                        const SizedBox(height: 20),

                        // Payment method
                        _buildPaymentMethodSection(context, state),
                        const SizedBox(height: 16),

                        // Amount entry
                        if (state.method != PaymentMethod.debt)
                          _buildAmountEntry(context, state),

                        // Reference field for bank/p2p
                        if (state.method == PaymentMethod.p2p ||
                            state.method == PaymentMethod.bank) ...[
                          const SizedBox(height: 12),
                          _buildReferenceField(context),
                        ],

                        // Note
                        const SizedBox(height: 12),
                        _buildNoteField(),
                      ],
                    ),
                  ),
                ),

                // Footer with change and submit
                _buildFooter(context, state),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.colors.border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.payment, color: AppColors.accent, size: 20),
          const SizedBox(width: 8),
          Text(
            'Тўлов қабул қилиш',
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            color: context.colors.textMuted,
            onPressed: () {
              context.read<PaymentBloc>().add(const PaymentCancelled());
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTotalSection(PaymentInProgress state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Жами:',
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 14,
                ),
              ),
              Text(
                formatMoney(state.subtotalUzs),
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          if (state.discountAmountUzs > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Чегирма:',
                  style: TextStyle(color: AppColors.danger, fontSize: 14),
                ),
                Text(
                  '-${formatMoney(state.discountAmountUzs)}',
                  style: const TextStyle(color: AppColors.danger, fontSize: 14),
                ),
              ],
            ),
          ],
          if (state.balanceAppliedUzs > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Баланс:',
                  style: TextStyle(color: AppColors.success, fontSize: 14),
                ),
                Text(
                  '-${formatMoney(state.balanceAppliedUzs)}',
                  style: const TextStyle(
                    color: AppColors.success,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
          Divider(color: context.colors.border, height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Тўлов суммаси:',
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                formatMoney(state.effectiveTotalUzs),
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountSection(BuildContext context, PaymentInProgress state) {
    return Row(
      children: [
        Text(
          'Чегирма:',
          style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
        ),
        const SizedBox(width: 8),
        // Discount type toggle
        SegmentedButton<DiscountType>(
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
            textStyle: const TextStyle(fontSize: 12),
          ),
        ),
        const SizedBox(width: 8),
        if (state.discountType != DiscountType.none)
          SizedBox(
            width: 100,
            child: TextField(
              controller: _discountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                LengthLimitingTextInputFormatter(kMaxMoneyInputDigits),
              ],
              style: TextStyle(color: context.colors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: state.discountType == DiscountType.percent
                    ? '0%'
                    : '0',
                hintStyle: TextStyle(
                  color: context.colors.textMuted,
                  fontSize: 13,
                ),
                filled: true,
                fillColor: context.colors.surfaceLight,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) {
                final value = double.tryParse(val) ?? 0;
                context.read<PaymentBloc>().add(
                  PaymentDiscountChanged(
                    type: state.discountType,
                    value: value,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildCustomerSection(BuildContext context, PaymentInProgress state) {
    return Row(
      children: [
        Text(
          'Мижоз:',
          style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
        ),
        const SizedBox(width: 8),
        if (state.customer != null) ...[
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: context.colors.surfaceLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, color: AppColors.accent, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    state.customer!.displayName,
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  // Use balance toggle
                  if (state.customerBalance != null &&
                      state.customerBalance!.creditUzs > 0) ...[
                    Text(
                      'Баланс: ${formatMoneyShort(state.customerBalance!.creditUzs)}',
                      style: const TextStyle(
                        color: AppColors.success,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 4),
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
                  IconButton(
                    icon: const Icon(Icons.close, size: 14),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: context.colors.textMuted,
                    onPressed: () {
                      context.read<PaymentBloc>().add(
                        const PaymentCustomerCleared(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ] else
          TextButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => BlocProvider.value(
                  value: context.read<CustomerBloc>(),
                  child: const CustomerSearchDialog(),
                ),
              ).then((_) {
                // After dialog closes, check if customer was selected
                final customerState = context.read<CustomerBloc>().state;
                if (customerState is CustomerSelectedState) {
                  context.read<PaymentBloc>().add(
                    PaymentCustomerSelected(
                      customer: customerState.customer,
                      balance: customerState.balance,
                    ),
                  );
                }
              });
            },
            icon: const Icon(Icons.search, size: 14),
            label: const Text('Танлаш', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
          ),
      ],
    );
  }

  Widget _buildPaymentMethodSection(
    BuildContext context,
    PaymentInProgress state,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Тўлов усули:',
          style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: PaymentMethod.values.map((method) {
            final isSelected = state.method == method;
            // Debt requires customer
            final isEnabled =
                method != PaymentMethod.debt || state.customer != null;

            return ChoiceChip(
              label: Text(
                method.label,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected
                      ? Colors.white
                      : isEnabled
                      ? context.colors.textSecondary
                      : context.colors.textMuted,
                ),
              ),
              selected: isSelected,
              onSelected: isEnabled
                  ? (_) {
                      context.read<PaymentBloc>().add(
                        PaymentMethodChanged(method: method),
                      );
                    }
                  : null,
              selectedColor: AppColors.accent,
              backgroundColor: context.colors.surfaceLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              showCheckmark: false,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAmountEntry(BuildContext context, PaymentInProgress state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Тўлов суммаси:',
          style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _amountController,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            LengthLimitingTextInputFormatter(kMaxMoneyInputDigits),
          ],
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: formatMoneyShort(state.effectiveTotalUzs),
            hintStyle: TextStyle(color: context.colors.textMuted, fontSize: 20),
            filled: true,
            fillColor: context.colors.surfaceLight,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            suffixText: 'сўм',
            suffixStyle: TextStyle(
              color: context.colors.textMuted,
              fontSize: 14,
            ),
          ),
          onChanged: (value) {
            final amount = double.tryParse(value) ?? 0;
            context.read<PaymentBloc>().add(
              PaymentAmountEntered(amount: amount),
            );
          },
        ),
        const SizedBox(height: 8),
        // Quick amount buttons
        Wrap(
          spacing: 6,
          children: [
            _QuickAmountButton(
              label: 'Аниқ сумма',
              onTap: () {
                final exact = state.effectiveTotalUzs;
                _amountController.text = exact.toStringAsFixed(0);
                context.read<PaymentBloc>().add(
                  PaymentAmountEntered(amount: exact),
                );
              },
            ),
            ...[1000, 5000, 10000, 50000, 100000].map(
              (v) => _QuickAmountButton(
                label: _formatQuick(v),
                onTap: () {
                  final current = double.tryParse(_amountController.text) ?? 0;
                  final newVal = current + v;
                  _amountController.text = newVal.toStringAsFixed(0);
                  context.read<PaymentBloc>().add(
                    PaymentAmountEntered(amount: newVal),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReferenceField(BuildContext context) {
    return TextField(
      controller: _referenceController,
      style: TextStyle(color: context.colors.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        hintText: 'Ишора / Реф. рақам',
        hintStyle: TextStyle(color: context.colors.textMuted, fontSize: 13),
        filled: true,
        fillColor: context.colors.surfaceLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
      controller: _noteController,
      style: TextStyle(color: context.colors.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        hintText: 'Изоҳ (ихтиёрий)',
        hintStyle: TextStyle(color: context.colors.textMuted, fontSize: 13),
        filled: true,
        fillColor: context.colors.surfaceLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, PaymentInProgress state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.colors.border)),
      ),
      child: Column(
        children: [
          // Change row
          if (state.changeDueUzs > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
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
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    formatMoney(state.changeDueUzs),
                    style: const TextStyle(
                      color: AppColors.success,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

          // Submit button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: state.isValid
                  ? () {
                      context.read<PaymentBloc>().add(
                        PaymentSubmitted(
                          warehouseId: widget.warehouseId,
                          note: _noteController.text,
                        ),
                      );
                    }
                  : null,
              icon: const Icon(Icons.check_circle, size: 20),
              label: Text(
                state.method == PaymentMethod.debt
                    ? 'Қарзга бериш'
                    : 'Тўловни тасдиқлаш',
                style: const TextStyle(fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.success.withValues(
                  alpha: 0.3,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatQuick(int amount) {
    if (amount >= 1000) return '${amount ~/ 1000}к';
    return '$amount';
  }
}

class _QuickAmountButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickAmountButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(
        label,
        style: TextStyle(color: context.colors.textSecondary, fontSize: 11),
      ),
      onPressed: onTap,
      backgroundColor: context.colors.surfaceLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    );
  }
}
