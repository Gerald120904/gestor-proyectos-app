import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../services/push_notification_service.dart';
import '../services/preload_service.dart';
import '../ui/common.dart';
import '../core/ui/dialogs/app_feedback.dart';
import 'auth.dart';
import 'home.dart';

class VerifyEmailPage extends StatefulWidget {
  final String email;

  const VerifyEmailPage({
    super.key,
    required this.email,
  });

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  final AuthService authService = AuthService();

  final TextEditingController codeController = TextEditingController();

  bool loading = false;
  bool resending = false;

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  void mostrarMensaje(String mensaje) {
    if (!mounted) return;

    AppFeedback.message(
      context: context,
      message: mensaje,
    );
  }

  Future<void> verificarCodigo() async {
    final code = codeController.text.trim();

    if (code.isEmpty) {
      mostrarMensaje('Ingrese el código enviado al correo.');
      return;
    }

    if (code.length < 4) {
      mostrarMensaje('El código ingresado no es válido.');
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      await authService.verifyEmail(
        email: widget.email,
        code: code,
      );

      if (!mounted) return;

      final tieneToken = await authService.hasToken();

      if (!mounted) return;

      if (tieneToken) {
        await PushNotificationService.instance.registrarTokenEnBackend();
        PreloadService.precargarTodo();

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (_) => false,
        );
      } else {
        mostrarMensaje('Correo verificado correctamente. Inicie sesión.');

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    } catch (error) {
      mostrarMensaje(
        error.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> reenviarCodigo() async {
    final confirmado = await AppFeedback.confirm(
      context: context,
      title: 'Reenviar código',
      message:
          '¿Desea enviar un nuevo código de verificación al correo registrado?',
      confirmText: 'Sí, reenviar',
    );

    if (!confirmado) return;

    setState(() {
      resending = true;
    });

    try {
      await authService.resendVerificationCode(
        email: widget.email,
      );

      mostrarMensaje('Se envió un nuevo código al correo.');
    } catch (error) {
      mostrarMensaje(
        error.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() {
          resending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        padding: const EdgeInsets.all(22),
        child: PageContainer(
          maxWidth: 500,
          child: Center(
            child: SingleChildScrollView(
              child: AppGlassCard(
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppHeaderBadge(
                      icon: Icons.mark_email_read_outlined,
                    ),

                    const SizedBox(height: 24),

                    const Text(
                      'Verificar correo',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textDark,
                        letterSpacing: -0.7,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Enviamos un código de verificación a:',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textMuted,
                        height: 1.45,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        widget.email,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    TextField(
                      controller: codeController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Código de verificación',
                        hintText: 'Ejemplo: 123456',
                        prefixIcon: Icon(Icons.password_outlined),
                      ),
                      onSubmitted: (_) {
                        if (!loading) {
                          verificarCodigo();
                        }
                      },
                    ),

                    const SizedBox(height: 24),

                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.accent,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withAlpha(70),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: loading ? null : verificarCodigo,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          icon: loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.verified_outlined),
                          label: Text(
                            loading ? 'Verificando...' : 'Verificar cuenta',
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    TextButton.icon(
                      onPressed: resending ? null : reenviarCodigo,
                      icon: resending
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_outlined),
                      label: Text(
                        resending
                            ? 'Reenviando código...'
                            : 'Reenviar código',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    TextButton(
                      onPressed: loading
                          ? null
                          : () {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                                (_) => false,
                              );
                            },
                      child: const Text(
                        'Volver al inicio de sesión',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
