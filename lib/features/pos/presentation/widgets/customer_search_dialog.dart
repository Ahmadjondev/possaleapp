import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_terminal/core/constants/app_colors.dart';
import 'package:pos_terminal/features/pos/data/models/customer_model.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/customer/customer_bloc.dart';
import 'package:pos_terminal/core/constants/app_colors_extension.dart';

class CustomerSearchDialog extends StatefulWidget {
  const CustomerSearchDialog({super.key});

  @override
  State<CustomerSearchDialog> createState() => _CustomerSearchDialogState();
}

class _CustomerSearchDialogState extends State<CustomerSearchDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 420,
        height: 480,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: context.colors.border)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        'Мижоз қидириш',
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        color: context.colors.textMuted,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Исм, телефон ёки компания',
                      hintStyle: TextStyle(
                        color: context.colors.textMuted,
                        fontSize: 13,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: context.colors.textSecondary,
                        size: 20,
                      ),
                      filled: true,
                      fillColor: context.colors.surfaceLight,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) {
                      context.read<CustomerBloc>().add(
                        CustomerSearchRequested(query: value),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Results
            Expanded(
              child: BlocBuilder<CustomerBloc, CustomerState>(
                builder: (context, state) {
                  if (state is CustomerSearching) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    );
                  }

                  if (state is CustomerSearchLoaded) {
                    if (state.customers.isEmpty) {
                      return Center(
                        child: Text(
                          'Мижоз топилмади',
                          style: TextStyle(
                            color: context.colors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: state.customers.length,
                      itemBuilder: (context, index) {
                        final customer = state.customers[index];
                        return _CustomerTile(
                          customer: customer,
                          onTap: () {
                            context.read<CustomerBloc>().add(
                              CustomerSelected(customer: customer),
                            );
                            Navigator.pop(context);
                          },
                        );
                      },
                    );
                  }

                  if (state is CustomerError) {
                    return Center(
                      child: Text(
                        state.message,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 13,
                        ),
                      ),
                    );
                  }

                  return Center(
                    child: Text(
                      'Мижоз номи ёки телефонини киритинг',
                      style: TextStyle(
                        color: context.colors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerTile extends StatelessWidget {
  final CustomerModel customer;
  final VoidCallback onTap;

  const _CustomerTile({required this.customer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: context.colors.border, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.accent.withValues(alpha: 0.2),
              child: Text(
                customer.displayName.isNotEmpty
                    ? customer.displayName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.displayName,
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (customer.displayPhone.isNotEmpty)
                    Text(
                      customer.displayPhone,
                      style: TextStyle(
                        color: context.colors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: context.colors.surfaceLight,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _customerTypeLabel(customer.customerType),
                style: TextStyle(
                  color: context.colors.textMuted,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _customerTypeLabel(String type) {
    switch (type) {
      case 'business':
        return 'Бизнес';
      case 'mechanic':
        return 'Механик';
      case 'shop':
        return 'Дўкон';
      default:
        return 'Шахс';
    }
  }
}
