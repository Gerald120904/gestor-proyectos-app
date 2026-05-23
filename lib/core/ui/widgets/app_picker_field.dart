import 'package:flutter/material.dart';

import '../../../ui/common.dart';
import 'app_field_shell.dart';

class AppPickerField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final IconData trailingIcon;
  final VoidCallback? onTap;
  final String? helperText;
  final bool requiredField;

  const AppPickerField({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.trailingIcon,
    this.onTap,
    this.helperText,
    this.requiredField = false,
  });

  InputDecoration _decoration() {
    return InputDecoration(
      prefixIcon: Icon(
        icon,
        size: 20,
        color: AppColors.primary,
      ),
      suffixIcon: Icon(
        trailingIcon,
        size: 20,
        color: AppColors.textMuted,
      ),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: AppColors.primary,
          width: 1.4,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppFieldShell(
      label: label,
      helperText: helperText,
      requiredField: requiredField,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: InputDecorator(
          decoration: _decoration(),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ),
      ),
    );
  }
}