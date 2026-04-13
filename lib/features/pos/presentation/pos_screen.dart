import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:pos_terminal/core/constants/app_colors.dart';
import 'package:pos_terminal/core/di/injection.dart';
import 'package:pos_terminal/features/auth/data/auth_local_storage.dart';
import 'package:pos_terminal/features/auth/domain/user_model.dart';
import 'package:pos_terminal/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:pos_terminal/features/auth/presentation/bloc/auth_event.dart';
import 'package:pos_terminal/features/pos/data/customer_repository.dart';
import 'package:pos_terminal/features/pos/data/pos_repository.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/cart/cart_bloc.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/cart/cart_event.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/category/category_bloc.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/customer/customer_bloc.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/draft/draft_bloc.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/payment/payment_bloc.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/payment/payment_event.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/payment/payment_state.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/product/product_bloc.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/product/product_event.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/product/product_state.dart';
import 'package:pos_terminal/features/pos/presentation/widgets/draft_list_dialog.dart';
import 'package:pos_terminal/features/pos/presentation/widgets/pos_cart_panel.dart';
import 'package:pos_terminal/features/pos/presentation/widgets/pos_category_bar.dart';
import 'package:pos_terminal/features/pos/presentation/widgets/pos_payment_panel.dart';
import 'package:pos_terminal/features/pos/presentation/widgets/pos_numeric_keyboard.dart';
import 'package:pos_terminal/features/pos/presentation/widgets/pos_product_grid.dart';
import 'package:pos_terminal/features/pos/presentation/widgets/pos_right_sidebar.dart';
import 'package:pos_terminal/core/constants/app_colors_extension.dart';

final _moneyFormat = NumberFormat('#,###', 'uz');

String formatMoney(double amount) {
  return '${_moneyFormat.format(amount.round())} сўм';
}

String formatMoneyShort(double amount) {
  return _moneyFormat.format(amount.round());
}

String unitLabelFor(String unitType) {
  return switch (unitType) {
    'kg' => 'кг',
    'g' => 'г',
    'l' => 'л',
    'm' => 'м',
    'set' => 'тўплам',
    _ => 'дона',
  };
}

class PosScreen extends StatelessWidget {
  final UserModel user;

  const PosScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final warehouseId =
        getIt<AuthLocalStorage>().getWarehouseId() ??
        user.defaultWarehouseId ??
        1;

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => CartBloc()),
        BlocProvider.value(value: getIt<ProductBloc>()),
        BlocProvider.value(value: getIt<CategoryBloc>()),
        BlocProvider(
          create: (_) => PaymentBloc(
            posRepository: getIt<PosRepository>(),
            customerRepository: getIt<CustomerRepository>(),
          ),
        ),
        BlocProvider(
          create: (_) =>
              CustomerBloc(customerRepository: getIt<CustomerRepository>()),
        ),
        BlocProvider(
          create: (_) => DraftBloc(posRepository: getIt<PosRepository>()),
        ),
      ],
      child: _PosScreenBody(user: user, warehouseId: warehouseId),
    );
  }
}

class _PosScreenBody extends StatefulWidget {
  final UserModel user;
  final int warehouseId;

  const _PosScreenBody({required this.user, required this.warehouseId});

  @override
  State<_PosScreenBody> createState() => _PosScreenBodyState();
}

class _PosScreenBodyState extends State<_PosScreenBody> {
  final FocusNode _keyboardFocusNode = FocusNode();
  final ActiveInputController _activeInput = ActiveInputController();
  final TextEditingController _noteController = TextEditingController();
  final StringBuffer _barcodeBuffer = StringBuffer();
  DateTime? _lastKeyTime;

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    _activeInput.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    // F2 → Open payment
    if (event.logicalKey == LogicalKeyboardKey.f2) {
      _openPayment();
      return;
    }

    // Escape → Close modals (handled by individual dialogs)
    // F5 → Save draft
    if (event.logicalKey == LogicalKeyboardKey.f5) {
      _saveDraft();
      return;
    }

    // F3 → Open drafts list
    if (event.logicalKey == LogicalKeyboardKey.f3) {
      DraftListDialog.show(context);
      return;
    }

    // Barcode scanner detection: rapid keystrokes ending with Enter
    final now = DateTime.now();
    if (_lastKeyTime != null &&
        now.difference(_lastKeyTime!).inMilliseconds > 150) {
      _barcodeBuffer.clear();
    }
    _lastKeyTime = now;

    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_barcodeBuffer.length >= 3) {
        final barcode = _barcodeBuffer.toString();
        _barcodeBuffer.clear();
        context.read<ProductBloc>().add(
          ProductBarcodeScanned(barcode: barcode),
        );
      }
      return;
    }

    final char = event.character;
    if (char != null && char.isNotEmpty) {
      _barcodeBuffer.write(char);
    }
  }

  void _openPayment() {
    final paymentState = context.read<PaymentBloc>().state;
    if (paymentState is PaymentInProgress && paymentState.isValid) {
      context.read<PaymentBloc>().add(
        PaymentSubmitted(
          warehouseId: widget.warehouseId,
          note: _noteController.text,
        ),
      );
    }
  }

  void _saveDraft() {
    final cartState = context.read<CartBloc>().state;
    if (cartState.isEmpty) return;

    final payload = <String, dynamic>{
      'items': cartState.items.map((i) => i.toCheckoutJson()).toList(),
      'warehouse_id': widget.warehouseId,
    };

    final customerState = context.read<CustomerBloc>().state;
    if (customerState is CustomerSelectedState) {
      payload['customer_id'] = customerState.customer.id;
    }

    if (_noteController.text.isNotEmpty) {
      payload['note'] = _noteController.text;
    }

    context.read<DraftBloc>().add(DraftSaveRequested(payload: payload));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProductBloc, ProductState>(
      listener: (context, state) {
        // Auto-add scanned product to cart
        if (state is ProductScanned) {
          context.read<CartBloc>().add(CartItemAdded(product: state.product));
        }
      },
      child: BlocListener<PaymentBloc, PaymentState>(
        listener: (context, state) {
          if (state is PaymentSuccess) {
            // Clear cart
            context.read<CartBloc>().add(const CartCleared());
            // Receipt/print handled by PosPaymentPanel
          } else if (state is PaymentFailed) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.danger,
              ),
            );
          }
        },
        child: BlocListener<DraftBloc, DraftState>(
          listener: (context, draftState) {
            if (draftState is DraftSaved) {
              context.read<CartBloc>().add(const CartCleared());
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
          child: KeyboardListener(
            focusNode: _keyboardFocusNode,
            autofocus: true,
            onKeyEvent: _handleKeyEvent,
            child: Scaffold(
              backgroundColor: context.colors.background,
              body: Column(
                children: [
                  // Top bar
                  _buildTopBar(),
                  // Main content
                  Expanded(
                    child: Row(
                      children: [
                        // Left: Categories + Products
                        Expanded(
                          flex: 4,
                          child: Column(
                            children: [
                              const PosCategoryBar(),
                              Expanded(
                                child: PosProductGrid(
                                  activeInput: _activeInput,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Divider
                        Container(width: 1, color: context.colors.border),
                        // Center: Cart
                        Expanded(
                          flex: 3,
                          child: PosCartPanel(activeInput: _activeInput),
                        ),
                        // Divider
                        Container(width: 1, color: context.colors.border),
                        // Right: Payment info
                        Expanded(
                          flex: 3,
                          child: PosPaymentPanel(
                            warehouseId: widget.warehouseId,
                            activeInput: _activeInput,
                            noteController: _noteController,
                          ),
                        ),
                        // Divider
                        Container(width: 1, color: context.colors.border),
                        // Far right: Sidebar
                        PosRightSidebar(
                          warehouseId: widget.warehouseId,
                          noteController: _noteController,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: context.colors.surface,
      child: Row(
        children: [
          const Icon(
            Icons.point_of_sale_rounded,
            color: AppColors.accent,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'POS Terminal',
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 16),
          // Keyboard shortcuts hint
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: context.colors.surfaceLight,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'F2 Тўлов  •  F3 Қораламалар  •  F5 Сақлаш',
              style: TextStyle(color: context.colors.textMuted, fontSize: 10),
            ),
          ),
          const Spacer(),
          if (widget.user.defaultWarehouseName != null) ...[
            Icon(
              Icons.warehouse_outlined,
              color: context.colors.textSecondary,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              widget.user.defaultWarehouseName!,
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 16),
          ],
          Icon(
            Icons.person_outline,
            color: context.colors.textSecondary,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            widget.user.displayName,
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              Icons.settings_outlined,
              color: context.colors.textSecondary,
              size: 20,
            ),
            iconSize: 20,
            tooltip: 'Созламалар',
            onPressed: () => context.push('/settings'),
          ),
          IconButton(
            icon: Icon(
              Icons.lock_outline,
              color: context.colors.textSecondary,
              size: 20,
            ),
            iconSize: 20,
            tooltip: 'Қулфлаш',
            onPressed: () {
              context.read<AuthBloc>().add(const AuthLockRequested());
            },
          ),
          IconButton(
            icon: Icon(
              Icons.logout,
              color: context.colors.textSecondary,
              size: 20,
            ),
            iconSize: 20,
            tooltip: 'Чиқиш',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: context.colors.surface,
                  title: Text(
                    'Чиқиш',
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  content: Text(
                    'Ҳақиқатан ҳам тизимдан чиқмоқчимисиз?',
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text(
                        'Бекор қилиш',
                        style: TextStyle(color: context.colors.textSecondary),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Чиқиш'),
                    ),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                context.read<AuthBloc>().add(const AuthLogoutRequested());
              }
            },
          ),
        ],
      ),
    );
  }
}
