import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/product/product_bloc.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/product/product_event.dart';
import 'package:pos_terminal/core/constants/app_colors_extension.dart';

class PosSearchBar extends StatefulWidget {
  const PosSearchBar({super.key});

  @override
  State<PosSearchBar> createState() => _PosSearchBarState();
}

class _PosSearchBarState extends State<PosSearchBar> {
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
      child: TextField(
        controller: _controller,
        style: TextStyle(color: context.colors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Қидириш (Номи / Баркод / OEM)',
          hintStyle: TextStyle(color: context.colors.textMuted, fontSize: 14),
          prefixIcon: Icon(
            Icons.search,
            color: context.colors.textSecondary,
            size: 20,
          ),
          suffixIcon: _controller.text.isNotEmpty
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
                    setState(() {});
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
          context.read<ProductBloc>().add(ProductSearchRequested(query: value));
          setState(() {});
        },
      ),
    );
  }
}
