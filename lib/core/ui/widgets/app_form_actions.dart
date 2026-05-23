import 'package:flutter/material.dart';

import '../../../ui/common.dart';

class AppFormActions extends StatelessWidget {
  final bool loading;
  final String primaryText;
  final VoidCallback? onCancel;
  final VoidCallback? onSubmit;
  final IconData primaryIcon;

  const AppFormActions({
    super.key,
    required this.loading,
    required this.primaryText,
    required this.onCancel,
    required this.onSubmit,
    this.primaryIcon = Icons.save_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 12,
      runSpacing: 10,
      children: [
        SizedBox(
          width: 128,
          height: 48,
          child: OutlinedButton(
            onPressed: loading ? null : onCancel,
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.textDark,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: EdgeInsets.zero,
            ),
            child: const Text(
              'Cancelar',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        SizedBox(
          width: 150,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: loading ? null : onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: EdgeInsets.zero,
            ),
            icon: loading
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(primaryIcon, size: 18),
            label: Text(
              loading ? 'Guardando...' : primaryText,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }
}