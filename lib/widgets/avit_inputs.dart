import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';

/// Themed text field with optional validation, obscure toggle and counter.
class AVITTextField extends StatefulWidget {
  const AVITTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.helper,
    this.initialValue,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.obscure = false,
    this.required = false,
    this.readOnly = false,
    this.enabled = true,
    this.autofocus = false,
    this.maxLines = 1,
    this.maxLength,
    this.prefixIcon,
    this.suffix,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.errorText,
    this.autocorrect = false,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? helper;
  final String? initialValue;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final bool obscure;
  final bool required;
  final bool readOnly;
  final bool enabled;
  final bool autofocus;
  final int maxLines;
  final int? maxLength;
  final IconData? prefixIcon;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? Function(String?)? validator;
  final String? errorText;
  final bool autocorrect;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<AVITTextField> createState() => _AVITTextFieldState();
}

class _AVITTextFieldState extends State<AVITTextField> {
  late bool _obscured = widget.obscure;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              widget.label,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            if (widget.required)
              Text(
                ' *',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.danger,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: widget.controller,
          initialValue: widget.initialValue,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          obscureText: _obscured,
          readOnly: widget.readOnly,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          maxLines: widget.maxLines,
          maxLength: widget.maxLength,
          autocorrect: widget.autocorrect,
          textCapitalization: widget.textCapitalization,
          inputFormatters: widget.inputFormatters,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: widget.hint,
            helperText: widget.helper,
            errorText: widget.errorText,
            prefixIcon: widget.prefixIcon == null
                ? null
                : Icon(widget.prefixIcon, size: 20),
            suffixIcon: widget.obscure
                ? IconButton(
                    tooltip: _obscured ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => _obscured = !_obscured),
                    icon: Icon(
                      _obscured
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                  )
                : widget.suffix,
          ),
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          validator: widget.validator ??
              (widget.required
                  ? (String? v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null
                  : null),
        ),
      ],
    );
  }
}

/// Primary / secondary / danger button with a built-in loading state.
class AVITButton extends StatefulWidget {
  const AVITButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = AVITButtonVariant.primary,
    this.loading = false,
    this.expand = true,
    this.compact = false,
    this.tooltip,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AVITButtonVariant variant;
  final bool loading;
  final bool expand;
  final bool compact;
  final String? tooltip;

  @override
  State<AVITButton> createState() => _AVITButtonState();
}

class _AVITButtonState extends State<AVITButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onPressed != null && !widget.loading;
    final ButtonStyle style = switch (widget.variant) {
      AVITButtonVariant.primary => ElevatedButton.styleFrom(),
      AVITButtonVariant.secondary => OutlinedButton.styleFrom(),
      AVITButtonVariant.ghost => TextButton.styleFrom(
        foregroundColor: AppColors.primaryBlue,
        minimumSize: const Size(0, 44),
      ),
      AVITButtonVariant.danger => ElevatedButton.styleFrom(
        backgroundColor: AppColors.danger,
        foregroundColor: AppColors.white,
      ),
      AVITButtonVariant.success => ElevatedButton.styleFrom(
        backgroundColor: AppColors.success,
        foregroundColor: AppColors.white,
      ),
    };

    final Widget button = switch (widget.variant) {
      AVITButtonVariant.secondary => OutlinedButton(
        onPressed: enabled ? widget.onPressed : null,
        style: style,
        child: _child(context),
      ),
      AVITButtonVariant.ghost => TextButton(
        onPressed: enabled ? widget.onPressed : null,
        style: style,
        child: _child(context),
      ),
      _ => ElevatedButton(
        onPressed: enabled ? widget.onPressed : null,
        style: style,
        child: _child(context),
      ),
    };

    final Widget scaled = GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled
          ? (_) => setState(() => _pressed = false)
          : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 100),
        child: button,
      ),
    );

    final Widget sized = widget.expand
        ? SizedBox(width: double.infinity, child: scaled)
        : scaled;

    if (widget.tooltip == null) return sized;
    return Tooltip(message: widget.tooltip!, child: sized);
  }

  Widget _child(BuildContext context) {
    if (widget.loading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          color: Colors.white,
        ),
      );
    }
    final List<Widget> children = <Widget>[
      if (widget.icon != null) ...<Widget>[
        Icon(widget.icon, size: widget.compact ? 16 : 18),
        const SizedBox(width: 8),
      ],
      Text(widget.label),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: children,
    );
  }
}

enum AVITButtonVariant { primary, secondary, ghost, danger, success }

/// Simple dropdown using the AVIT field shell.
class AVITDropdown<T> extends StatelessWidget {
  const AVITDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.required = false,
    this.hint,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final bool required;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            if (required)
              Text(
                ' *',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.danger,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<T>(
          initialValue: value,
          items: items,
          onChanged: onChanged,
          // Sizes to the available width instead of the widest option,
          // which would overflow narrow layouts.
          isExpanded: true,
          hint: hint == null ? null : Text(hint!),
          decoration: const InputDecoration(),
        ),
      ],
    );
  }
}

/// Search field used by campus map and service lists.
class AVITSearchField extends StatelessWidget {
  const AVITSearchField({
    super.key,
    required this.controller,
    this.hint = 'Search',
    this.onChanged,
    this.onClear,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  controller.clear();
                  onClear?.call();
                },
              ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),
    );
  }
}
