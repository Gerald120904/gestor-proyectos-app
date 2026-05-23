import 'package:flutter/material.dart';

class AppFeedback {
  static Future<bool> confirm({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Confirmar',
    String cancelText = 'Cancelar',
    bool danger = false,
  }) async {
    if (!context.mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          title: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: danger
                      ? const Color(0xFFFFE4E6)
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  danger ? Icons.warning_rounded : Icons.help_rounded,
                  color: danger
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(
              fontSize: 15,
              height: 1.4,
              color: Color(0xFF475569),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext, rootNavigator: true).pop(false);
              },
              child: Text(cancelText),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext, rootNavigator: true).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: danger
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  static Future<void> loading(
    BuildContext context, {
    String message = 'Procesando solicitud...',
  }) {
    if (!context.mounted) return Future.value();

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) {
        return PopScope(
          canPop: false,
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static void closeLoading(BuildContext context) {
    if (!context.mounted) return;

    final navigator = Navigator.of(context, rootNavigator: true);

    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  static Future<void> success({
    required BuildContext context,
    required String title,
    required String message,
  }) {
    return _result(
      context: context,
      title: title,
      message: message,
      icon: Icons.check_circle_rounded,
      iconColor: const Color(0xFF16A34A),
      iconBackground: const Color(0xFFDCFCE7),
      buttonColor: const Color(0xFF16A34A),
    );
  }

  static Future<void> error({
    required BuildContext context,
    required String title,
    required String message,
  }) {
    return _result(
      context: context,
      title: title,
      message: cleanError(message),
      icon: Icons.error_rounded,
      iconColor: const Color(0xFFDC2626),
      iconBackground: const Color(0xFFFEE2E2),
      buttonColor: const Color(0xFFDC2626),
    );
  }

  static Future<void> info({
    required BuildContext context,
    required String title,
    required String message,
  }) {
    return _result(
      context: context,
      title: title,
      message: cleanError(message),
      icon: Icons.info_rounded,
      iconColor: const Color(0xFF2563EB),
      iconBackground: const Color(0xFFEFF6FF),
      buttonColor: const Color(0xFF2563EB),
    );
  }

  static Future<void> _result({
    required BuildContext context,
    required String title,
    required String message,
    required IconData icon,
    required Color iconColor,
    required Color iconBackground,
    required Color buttonColor,
  }) {
    if (!context.mounted) return Future.value();

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          title: Column(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 36,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          content: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              height: 1.4,
              color: Color(0xFF475569),
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext, rootNavigator: true).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Aceptar'),
              ),
            ),
          ],
        );
      },
    );
  }

  static void message({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;

    final cleanMessage = cleanError(message);
    final lower = cleanMessage.toLowerCase();

    final isSuccess = lower.contains('correctamente') ||
        lower.contains('exitos') ||
        lower.contains('creado') ||
        lower.contains('creada') ||
        lower.contains('actualizado') ||
        lower.contains('actualizada') ||
        lower.contains('eliminado') ||
        lower.contains('eliminada') ||
        lower.contains('registrado') ||
        lower.contains('registrada') ||
        lower.contains('agregado') ||
        lower.contains('agregada') ||
        lower.contains('enviado') ||
        lower.contains('enviada') ||
        lower.contains('programado') ||
        lower.contains('programada');

    final isError = lower.contains('error') ||
        lower.contains('incorrect') ||
        lower.contains('no se pudo') ||
        lower.contains('fall') ||
        lower.contains('expir') ||
        lower.contains('inválid') ||
        lower.contains('invalido') ||
        lower.contains('obligatorio') ||
        lower.contains('obligatoria') ||
        lower.contains('debe') ||
        lower.contains('no hay') ||
        lower.contains('mínimo') ||
        lower.contains('minimo');

    if (isSuccess) {
      success(
        context: context,
        title: 'Operación exitosa',
        message: cleanMessage,
      );
      return;
    }

    if (isError) {
      error(
        context: context,
        title: 'No se pudo completar',
        message: cleanMessage,
      );
      return;
    }

    info(
      context: context,
      title: 'Aviso',
      message: cleanMessage,
    );
  }

  static Future<void> confirmAndRun({
    required BuildContext context,
    required String confirmTitle,
    required String confirmMessage,
    String confirmText = 'Confirmar',
    bool danger = false,
    String loadingMessage = 'Procesando...',
    required String successTitle,
    required String successMessage,
    required Future<void> Function() action,
  }) async {
    final confirmado = await confirm(
      context: context,
      title: confirmTitle,
      message: confirmMessage,
      confirmText: confirmText,
      danger: danger,
    );

    if (!context.mounted) return;
    if (!confirmado) return;

    try {
      await action();

      if (!context.mounted) return;

      message(
        context: context,
        message: successMessage,
      );
    } catch (exception) {
      if (!context.mounted) return;

      message(
        context: context,
        message: cleanError(exception),
      );
    }
  }

  static String cleanError(Object error) {
    return error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('Error: ', '')
        .trim();
  }
}