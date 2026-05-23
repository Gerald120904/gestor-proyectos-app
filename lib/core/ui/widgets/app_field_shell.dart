import 'package:flutter/material.dart';

import '../../../ui/common.dart';

class AppFieldShell extends StatelessWidget {
  final String label;
  final String? helperText;
  final Widget child;
  final bool requiredField;

  const AppFieldShell({
    super.key,
    required this.label,
    required this.child,
    this.helperText,
    this.requiredField = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          requiredField ? '$label *' : label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(height: 8),
        child,
        if (helperText != null && helperText!.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            helperText!,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              height: 1.25,
            ),
          ),
        ],
      ],
    );
  }
}