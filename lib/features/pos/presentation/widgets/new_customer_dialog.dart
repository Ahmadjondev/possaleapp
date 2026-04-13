import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_terminal/core/constants/app_colors.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/customer/customer_bloc.dart';
import 'package:pos_terminal/features/pos/presentation/widgets/pos_dialog.dart';
import 'package:pos_terminal/core/constants/app_colors_extension.dart';

/// Quick dialog to create a new customer.
///
/// Returns `true` if a customer was created, `null`/`false` otherwise.
class NewCustomerDialog extends StatefulWidget {
  final String? initialName;

  const NewCustomerDialog({super.key, this.initialName});

  static Future<bool?> show(BuildContext context, {String? initialName}) {
    return showDialog<bool>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<CustomerBloc>(),
        child: NewCustomerDialog(initialName: initialName),
      ),
    );
  }

  @override
  State<NewCustomerDialog> createState() => _NewCustomerDialogState();
}

class _NewCustomerDialogState extends State<NewCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameCtrl;
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _debtLimitCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _customerType = 'individual';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _firstNameCtrl = TextEditingController(text: widget.initialName ?? '');
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _debtLimitCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final debtLimit = double.tryParse(
      _debtLimitCtrl.text.trim().replaceAll(' ', ''),
    );

    context.read<CustomerBloc>().add(
      CustomerCreateRequested(
        firstName: _firstNameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim().isEmpty
            ? null
            : _lastNameCtrl.text.trim(),
        customerType: _customerType,
        address: _addressCtrl.text.trim().isEmpty
            ? null
            : _addressCtrl.text.trim(),
        debtLimitUzs: debtLimit,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      ),
    );

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return PosDialog(
      title: 'Янги мижоз',
      icon: Icons.person_add,
      width: 420,
      actions: [
        OutlinedButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            foregroundColor: context.colors.textSecondary,
            side: BorderSide(color: context.colors.border),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          child: const Text('Бекор қилиш'),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save, size: 16),
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
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Name row ──────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _buildField(
                      label: 'Исм *',
                      controller: _firstNameCtrl,
                      autofocus: true,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Исм киритинг'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildField(
                      label: 'Фамилия',
                      controller: _lastNameCtrl,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // ── Phone ─────────────────────────────────
              _buildField(
                label: 'Телефон *',
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d+\-() ]')),
                ],
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Телефон киритинг' : null,
              ),
              const SizedBox(height: 12),
              // ── Address ───────────────────────────────
              _buildField(label: 'Манзил', controller: _addressCtrl),
              const SizedBox(height: 12),
              // ── Type + Debt limit row ─────────────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Мижоз тури',
                          style: TextStyle(
                            color: context.colors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _customerType,
                          dropdownColor: context.colors.surface,
                          style: TextStyle(
                            color: context.colors.textPrimary,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            filled: true,
                            fillColor: context.colors.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                color: context.colors.border,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                color: context.colors.border,
                              ),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'individual',
                              child: Text('Жисмоний шахс'),
                            ),
                            DropdownMenuItem(
                              value: 'business',
                              child: Text('Юридик шахс'),
                            ),
                            DropdownMenuItem(
                              value: 'mechanic',
                              child: Text('Уста'),
                            ),
                            DropdownMenuItem(
                              value: 'shop',
                              child: Text('Дўкон'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _customerType = v);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildField(
                      label: 'Қарз лимити (сўм)',
                      controller: _debtLimitCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d. ]')),
                        LengthLimitingTextInputFormatter(kMaxMoneyInputDigits),
                      ],
                      hint: '0 — чексиз',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // ── Notes ─────────────────────────────────
              _buildField(label: 'Изоҳ', controller: _notesCtrl, maxLines: 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    bool autofocus = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    String? hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.colors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          autofocus: autofocus,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          maxLines: maxLines,
          style: TextStyle(color: context.colors.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: TextStyle(color: context.colors.textMuted, fontSize: 13),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
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
        ),
      ],
    );
  }
}
