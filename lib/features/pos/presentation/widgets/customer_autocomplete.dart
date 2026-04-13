import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_terminal/core/constants/app_colors.dart';
import 'package:pos_terminal/features/pos/data/models/customer_model.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/customer/customer_bloc.dart';
import 'package:pos_terminal/features/pos/presentation/widgets/new_customer_dialog.dart';
import 'package:pos_terminal/core/constants/app_colors_extension.dart';

/// Inline customer autocomplete field.
///
/// Searches customers as the user types. If no match is found and Enter is
/// pressed, opens the [NewCustomerDialog] to create a new customer.
class CustomerAutocomplete extends StatefulWidget {
  const CustomerAutocomplete({super.key});

  @override
  State<CustomerAutocomplete> createState() => _CustomerAutocompleteState();
}

class _CustomerAutocompleteState extends State<CustomerAutocomplete> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  List<CustomerModel> _suggestions = [];
  bool _showDropdown = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    _debounce?.cancel();
    final query = _controller.text.trim();
    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
        _showDropdown = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () {
      context.read<CustomerBloc>().add(CustomerSearchRequested(query: query));
    });
  }

  void _selectCustomer(CustomerModel customer) {
    _controller.text = customer.displayName;
    setState(() {
      _showDropdown = false;
    });
    context.read<CustomerBloc>().add(CustomerSelected(customer: customer));
    _focusNode.unfocus();
  }

  void _clearCustomer() {
    _controller.clear();
    setState(() {
      _suggestions = [];
      _showDropdown = false;
    });
    context.read<CustomerBloc>().add(const CustomerCleared());
  }

  Future<void> _onSubmitted(String value) async {
    // If suggestions exist, select the first one
    if (_suggestions.isNotEmpty) {
      _selectCustomer(_suggestions.first);
      return;
    }
    // No match — open new customer dialog
    if (value.trim().isNotEmpty && mounted) {
      final created = await NewCustomerDialog.show(
        context,
        initialName: value.trim(),
      );
      if (created == true && mounted) {
        _controller.clear();
        setState(() {
          _showDropdown = false;
        });
      }
    }
  }

  Future<void> _openNewCustomerDialog() async {
    final created = await NewCustomerDialog.show(
      context,
      initialName: _controller.text.trim(),
    );
    if (created == true && mounted) {
      _controller.clear();
      setState(() {
        _showDropdown = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CustomerBloc, CustomerState>(
      listener: (context, state) {
        if (state is CustomerSearchLoaded) {
          setState(() {
            _suggestions = state.customers;
            _showDropdown = state.customers.isNotEmpty;
          });
        } else if (state is CustomerSelectedState) {
          _controller.text = state.customer.displayName;
          setState(() {
            _showDropdown = false;
          });
        } else if (state is CustomerInitial) {
          _controller.clear();
          setState(() {
            _suggestions = [];
            _showDropdown = false;
          });
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTextField(),
          if (_showDropdown) _buildSuggestionList(),
        ],
      ),
    );
  }

  Widget _buildTextField() {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      style: TextStyle(color: context.colors.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        hintText: 'Мижоз излаш...',
        hintStyle: TextStyle(color: context.colors.textMuted, fontSize: 15),
        prefixIcon: Icon(
          Icons.person_search,
          color: context.colors.textMuted,
          size: 20,
        ),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_controller.text.isNotEmpty) ...[
              IconButton(
                icon: const Icon(
                  Icons.person_add,
                  color: AppColors.accent,
                  size: 18,
                ),
                tooltip: 'Янги мижоз қўшиш',
                onPressed: _openNewCustomerDialog,
              ),
              IconButton(
                icon: Icon(
                  Icons.close,
                  color: context.colors.textMuted,
                  size: 18,
                ),
                onPressed: _clearCustomer,
              ),
            ],
          ],
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        filled: true,
        fillColor: context.colors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: context.colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: context.colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.accent),
        ),
      ),
      onSubmitted: _onSubmitted,
    );
  }

  Widget _buildSuggestionList() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      margin: const EdgeInsets.only(top: 2),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: context.colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: _suggestions.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: context.colors.border),
        itemBuilder: (context, index) {
          final customer = _suggestions[index];
          return InkWell(
            onTap: () => _selectCustomer(customer),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.person,
                    color: context.colors.textMuted,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.displayName,
                          style: TextStyle(
                            color: context.colors.textPrimary,
                            fontSize: 13,
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
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
