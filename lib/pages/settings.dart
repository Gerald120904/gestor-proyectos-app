import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../ui/common.dart';
import '../core/ui/dialogs/app_feedback.dart';
import '../core/ui/widgets/app_form_field.dart';
import '../core/ui/widgets/app_form_actions.dart';

class SettingsPage extends StatefulWidget {
  final Map<String, dynamic>? perfil;
  final VoidCallback onLogout;

  const SettingsPage({
    super.key,
    required this.perfil,
    required this.onLogout,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final AuthService authService = AuthService();

  Map<String, dynamic>? perfilActual;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    perfilActual = widget.perfil;
    cargarPerfil();
  }

  Future<void> cargarPerfil() async {
    if (mounted) {
      setState(() {
        loading = true;
      });
    }

    try {
      final data = await authService.profile();

      if (!mounted) return;

      setState(() {
        perfilActual = data;
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      mostrarMensaje(error.toString().replaceAll('Exception: ', ''));
    }
  }

  void mostrarMensaje(String mensaje) {
    if (!mounted) return;

    AppFeedback.message(
      context: context,
      message: mensaje,
    );
  }

  String obtenerTexto(dynamic value, String fallback) {
    if (value == null) return fallback;

    final texto = value.toString().trim();

    if (texto.isEmpty) return fallback;

    return texto;
  }

  Future<void> abrirEditarNombre() async {
    final nombreController = TextEditingController(
      text: obtenerTexto(perfilActual?['nombre'], ''),
    );

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool guardando = false;

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AppFormDialog(
              title: 'Editar nombre',
              subtitle: 'Actualice el nombre completo mostrado en su cuenta.',
              icon: Icons.person_outline,
              desktopWidth: 560,
              desktopHeight: 360,
              child: Form(
                key: formKey,
                child: AppFormField(
                  controller: nombreController,
                  enabled: !guardando,
                  label: 'Nombre completo',
                  hint: 'Ejemplo: Juan Carlos Pérez Mora',
                  icon: Icons.person_outline,
                  requiredField: true,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 80,
                  validator: (value) {
                    final text = value?.trim() ?? '';

                    if (text.isEmpty) {
                      return 'El nombre es obligatorio.';
                    }

                    if (text.length < 3 || text.length > 80) {
                      return 'Debe tener entre 3 y 80 caracteres.';
                    }

                    return null;
                  },
                ),
              ),
              actions: [
                AppFormActions(
                  loading: guardando,
                  primaryText: 'Guardar',
                  primaryIcon: Icons.save_outlined,
                  onCancel: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    Navigator.of(dialogContext).pop();
                  },
                  onSubmit: () async {
                    if (!formKey.currentState!.validate()) return;

                    setDialogState(() {
                      guardando = true;
                    });

                    try {
                      final data = await authService.updateProfile(
                        nombre: nombreController.text.trim(),
                      );

                      if (!mounted) return;

                      final user = data['user'];

                      setState(() {
                        if (user is Map) {
                          perfilActual = Map<String, dynamic>.from(user);
                        }
                      });

                      if (dialogContext.mounted) {
                        FocusManager.instance.primaryFocus?.unfocus();
                        Navigator.of(dialogContext).pop();
                      }

                      if (!mounted) return;

                      mostrarMensaje(
                        data['message']?.toString() ??
                            'Perfil actualizado correctamente.',
                      );
                    } catch (error) {
                      if (dialogContext.mounted) {
                        setDialogState(() {
                          guardando = false;
                        });
                      }

                      mostrarMensaje(
                        error.toString().replaceAll('Exception: ', ''),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );

    nombreController.dispose();
  }

  Future<void> abrirCambiarPassword() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    final formKey = GlobalKey<FormState>();

    bool currentVisible = false;
    bool newVisible = false;
    bool confirmVisible = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool guardando = false;

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AppFormDialog(
              title: 'Cambiar contraseña',
              subtitle:
                  'Ingrese su contraseña actual y defina una nueva contraseña segura.',
              icon: Icons.lock_reset_outlined,
              desktopWidth: 620,
              desktopHeight: 540,
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppFormField(
                      controller: currentPasswordController,
                      enabled: !guardando,
                      label: 'Contraseña actual',
                      icon: Icons.lock_outline,
                      requiredField: true,
                      obscureText: !currentVisible,
                      suffixIcon: IconButton(
                        onPressed: guardando
                            ? null
                            : () {
                                setDialogState(() {
                                  currentVisible = !currentVisible;
                                });
                              },
                        icon: Icon(
                          currentVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';

                        if (text.isEmpty) {
                          return 'Ingrese la contraseña actual.';
                        }

                        if (text.length < 6) {
                          return 'Mínimo 6 caracteres.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 14),

                    AppFormField(
                      controller: newPasswordController,
                      enabled: !guardando,
                      label: 'Nueva contraseña',
                      icon: Icons.lock_reset_outlined,
                      requiredField: true,
                      obscureText: !newVisible,
                      suffixIcon: IconButton(
                        onPressed: guardando
                            ? null
                            : () {
                                setDialogState(() {
                                  newVisible = !newVisible;
                                });
                              },
                        icon: Icon(
                          newVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';

                        if (text.isEmpty) {
                          return 'Ingrese la nueva contraseña.';
                        }

                        if (text.length < 6) {
                          return 'Mínimo 6 caracteres.';
                        }

                        if (text == currentPasswordController.text.trim()) {
                          return 'Debe ser diferente a la contraseña actual.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 14),

                    AppFormField(
                      controller: confirmPasswordController,
                      enabled: !guardando,
                      label: 'Confirmar nueva contraseña',
                      icon: Icons.verified_user_outlined,
                      requiredField: true,
                      obscureText: !confirmVisible,
                      suffixIcon: IconButton(
                        onPressed: guardando
                            ? null
                            : () {
                                setDialogState(() {
                                  confirmVisible = !confirmVisible;
                                });
                              },
                        icon: Icon(
                          confirmVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';

                        if (text.isEmpty) {
                          return 'Confirme la nueva contraseña.';
                        }

                        if (text != newPasswordController.text.trim()) {
                          return 'Las contraseñas no coinciden.';
                        }

                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                AppFormActions(
                  loading: guardando,
                  primaryText: 'Cambiar',
                  primaryIcon: Icons.save_outlined,
                  onCancel: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    Navigator.of(dialogContext).pop();
                  },
                  onSubmit: () async {
                    if (!formKey.currentState!.validate()) return;

                    setDialogState(() {
                      guardando = true;
                    });

                    try {
                      final data = await authService.changePassword(
                        currentPassword: currentPasswordController.text.trim(),
                        newPassword: newPasswordController.text.trim(),
                      );

                      if (!mounted) return;

                      if (dialogContext.mounted) {
                        FocusManager.instance.primaryFocus?.unfocus();
                        Navigator.of(dialogContext).pop();
                      }

                      if (!mounted) return;

                      mostrarMensaje(
                        data['message']?.toString() ??
                            'Contraseña actualizada correctamente.',
                      );
                    } catch (error) {
                      if (dialogContext.mounted) {
                        setDialogState(() {
                          guardando = false;
                        });
                      }

                      mostrarMensaje(
                        error.toString().replaceAll('Exception: ', ''),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );

    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
  }

  Future<void> abrirSolicitarCambioCorreo() async {
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool guardando = false;

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AppFormDialog(
              title: 'Cambiar correo',
              subtitle:
                  'Digite el nuevo correo electrónico. Se enviará un código para confirmar el cambio.',
              icon: Icons.alternate_email_outlined,
              desktopWidth: 600,
              desktopHeight: 390,
              child: Form(
                key: formKey,
                child: AppFormField(
                  controller: emailController,
                  enabled: !guardando,
                  label: 'Nuevo correo electrónico',
                  hint: 'ejemplo@correo.com',
                  icon: Icons.alternate_email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  requiredField: true,
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    final regex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

                    if (text.isEmpty) {
                      return 'El nuevo correo es obligatorio.';
                    }

                    if (!regex.hasMatch(text)) {
                      return 'Ingrese un correo válido.';
                    }

                    if (text.toLowerCase() ==
                        obtenerTexto(perfilActual?['email'], '').toLowerCase()) {
                      return 'Debe ser diferente al correo actual.';
                    }

                    return null;
                  },
                ),
              ),
              actions: [
                AppFormActions(
                  loading: guardando,
                  primaryText: 'Enviar código',
                  primaryIcon: Icons.send_outlined,
                  onCancel: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    Navigator.of(dialogContext).pop();
                  },
                  onSubmit: () async {
                    if (!formKey.currentState!.validate()) return;

                    final nuevoCorreo =
                        emailController.text.trim().toLowerCase();

                    setDialogState(() {
                      guardando = true;
                    });

                    try {
                      final data = await authService.requestEmailChange(
                        newEmail: nuevoCorreo,
                      );

                      if (!mounted) return;

                      if (dialogContext.mounted) {
                        FocusManager.instance.primaryFocus?.unfocus();
                        Navigator.of(dialogContext).pop();
                      }

                      if (!mounted) return;

                      mostrarMensaje(
                        data['message']?.toString() ??
                            'Código enviado al nuevo correo.',
                      );

                      await abrirConfirmarCambioCorreo(nuevoCorreo);
                    } catch (error) {
                      if (dialogContext.mounted) {
                        setDialogState(() {
                          guardando = false;
                        });
                      }

                      mostrarMensaje(
                        error.toString().replaceAll('Exception: ', ''),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );

    emailController.dispose();
  }

  Future<void> abrirConfirmarCambioCorreo(String nuevoCorreo) async {
    final codeController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool guardando = false;

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AppFormDialog(
              title: 'Confirmar correo',
              subtitle: 'Te enviamos un código a tu correo actual para confirmar el cambio.',
              icon: Icons.verified_outlined,
              desktopWidth: 560,
              desktopHeight: 430,
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSoft,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        nuevoCorreo,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    AppFormField(
                      controller: codeController,
                      enabled: !guardando,
                      label: 'Código de verificación',
                      hint: '000000',
                      icon: Icons.pin_outlined,
                      keyboardType: TextInputType.number,
                      requiredField: true,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 5,
                        color: AppColors.textDark,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      validator: (value) {
                        final text = value?.trim() ?? '';

                        if (text.isEmpty) {
                          return 'Ingrese el código.';
                        }

                        if (text.length != 6) {
                          return 'El código debe tener 6 dígitos.';
                        }

                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                AppFormActions(
                  loading: guardando,
                  primaryText: 'Confirmar',
                  primaryIcon: Icons.verified_outlined,
                  onCancel: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    Navigator.of(dialogContext).pop();
                  },
                  onSubmit: () async {
                    if (!formKey.currentState!.validate()) return;

                    setDialogState(() {
                      guardando = true;
                    });

                    try {
                      final data = await authService.confirmEmailChange(
                        code: codeController.text.trim(),
                      );

                      if (!mounted) return;

                      final user = data['user'];

                      setState(() {
                        if (user is Map) {
                          perfilActual = Map<String, dynamic>.from(user);
                        }
                      });

                      if (dialogContext.mounted) {
                        FocusManager.instance.primaryFocus?.unfocus();
                        Navigator.of(dialogContext).pop();
                      }

                      if (!mounted) return;

                      mostrarMensaje(
                        data['message']?.toString() ??
                            'Correo actualizado correctamente.',
                      );
                    } catch (error) {
                      if (dialogContext.mounted) {
                        setDialogState(() {
                          guardando = false;
                        });
                      }

                      mostrarMensaje(
                        error.toString().replaceAll('Exception: ', ''),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );

    codeController.dispose();
  }

  Future<void> abrirSolicitarCambioTelefono() async {
    final phoneController = TextEditingController(
      text: obtenerTexto(perfilActual?['telefono'], ''),
    );

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool guardando = false;

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AppFormDialog(
              title: 'Cambiar teléfono',
              subtitle:
                  'Digite el nuevo número de teléfono. Se enviará un código al correo actual para confirmar el cambio.',
              icon: Icons.phone_android_outlined,
              desktopWidth: 600,
              desktopHeight: 390,
              child: Form(
                key: formKey,
                child: AppFormField(
                  controller: phoneController,
                  enabled: !guardando,
                  label: 'Nuevo teléfono',
                  hint: 'Ejemplo: 8888-8888',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  requiredField: true,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[0-9+\s()-]'),
                    ),
                    LengthLimitingTextInputFormatter(20),
                  ],
                  validator: (value) {
                    final text = value?.trim() ?? '';

                    if (text.isEmpty) {
                      return 'El teléfono es obligatorio.';
                    }

                    if (text.length < 4 || text.length > 20) {
                      return 'Debe tener entre 4 y 20 caracteres.';
                    }

                    if (text == obtenerTexto(perfilActual?['telefono'], '')) {
                      return 'Debe ser diferente al teléfono actual.';
                    }

                    return null;
                  },
                ),
              ),
              actions: [
                AppFormActions(
                  loading: guardando,
                  primaryText: 'Enviar código',
                  primaryIcon: Icons.send_outlined,
                  onCancel: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    Navigator.of(dialogContext).pop();
                  },
                  onSubmit: () async {
                    if (!formKey.currentState!.validate()) return;

                    final nuevoTelefono = phoneController.text.trim();

                    setDialogState(() {
                      guardando = true;
                    });

                    try {
                      final data = await authService.requestPhoneChange(
                        newPhone: nuevoTelefono,
                      );

                      if (!mounted) return;

                      if (dialogContext.mounted) {
                        FocusManager.instance.primaryFocus?.unfocus();
                        Navigator.of(dialogContext).pop();
                      }

                      if (!mounted) return;

                      mostrarMensaje(
                        data['message']?.toString() ??
                            'Código enviado al correo actual.',
                      );

                      await abrirConfirmarCambioTelefono(nuevoTelefono);
                    } catch (error) {
                      if (dialogContext.mounted) {
                        setDialogState(() {
                          guardando = false;
                        });
                      }

                      mostrarMensaje(
                        error.toString().replaceAll('Exception: ', ''),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );

    phoneController.dispose();
  }

  Future<void> abrirConfirmarCambioTelefono(String nuevoTelefono) async {
    final codeController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool guardando = false;

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AppFormDialog(
              title: 'Confirmar teléfono',
              subtitle:
                  'Ingrese el código de 6 dígitos enviado al correo actual.',
              icon: Icons.verified_user_outlined,
              desktopWidth: 560,
              desktopHeight: 430,
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSoft,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        nuevoTelefono,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    AppFormField(
                      controller: codeController,
                      enabled: !guardando,
                      label: 'Código de verificación',
                      hint: '000000',
                      icon: Icons.pin_outlined,
                      keyboardType: TextInputType.number,
                      requiredField: true,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 5,
                        color: AppColors.textDark,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      validator: (value) {
                        final text = value?.trim() ?? '';

                        if (text.isEmpty) {
                          return 'Ingrese el código.';
                        }

                        if (text.length != 6) {
                          return 'El código debe tener 6 dígitos.';
                        }

                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                AppFormActions(
                  loading: guardando,
                  primaryText: 'Confirmar',
                  primaryIcon: Icons.verified_outlined,
                  onCancel: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    Navigator.of(dialogContext).pop();
                  },
                  onSubmit: () async {
                    if (!formKey.currentState!.validate()) return;

                    setDialogState(() {
                      guardando = true;
                    });

                    try {
                      final data = await authService.confirmPhoneChange(
                        code: codeController.text.trim(),
                      );

                      if (!mounted) return;

                      final user = data['user'];

                      setState(() {
                        if (user is Map) {
                          perfilActual = Map<String, dynamic>.from(user);
                        }
                      });

                      if (dialogContext.mounted) {
                        FocusManager.instance.primaryFocus?.unfocus();
                        Navigator.of(dialogContext).pop();
                      }

                      if (!mounted) return;

                      mostrarMensaje(
                        data['message']?.toString() ??
                            'Teléfono actualizado correctamente.',
                      );
                    } catch (error) {
                      if (dialogContext.mounted) {
                        setDialogState(() {
                          guardando = false;
                        });
                      }

                      mostrarMensaje(
                        error.toString().replaceAll('Exception: ', ''),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );

    codeController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading && perfilActual == null) {
      return const Scaffold(
        body: AppLoading(
          text: 'Cargando configuración...',
        ),
      );
    }

    final nombre = obtenerTexto(perfilActual?['nombre'], 'Usuario');
    final email = obtenerTexto(perfilActual?['email'], 'correo@ejemplo.com');
    final telefono = obtenerTexto(perfilActual?['telefono'], 'Sin teléfono');
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        padding: EdgeInsets.zero,
        child: RefreshIndicator(
          onRefresh: cargarPerfil,
          child: PageContainer(
            maxWidth: 900,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                AppGlassCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
                        width: 86,
                        height: 86,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.accent,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withAlpha(65),
                              blurRadius: 22,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.person,
                          size: 46,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        nombre,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        email,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withAlpha(31),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              size: 15,
                              color: AppColors.success,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Cuenta verificada',
                              style: TextStyle(
                                color: AppColors.success,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                AppGlassCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Icon(
                              Icons.manage_accounts_outlined,
                              color: AppColors.primary,
                              size: 30,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Información de la cuenta',
                                style: TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: AppColors.border),
                      _InfoRow(
                        icon: Icons.person_outline,
                        title: 'Nombre',
                        value: nombre,
                      ),
                      _InfoRow(
                        icon: Icons.email_outlined,
                        title: 'Correo',
                        value: email,
                      ),
                      _InfoRow(
                        icon: Icons.phone_outlined,
                        title: 'Teléfono',
                        value: telefono,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                AppGlassCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Icon(
                              Icons.security_outlined,
                              color: AppColors.primary,
                              size: 30,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Acciones de seguridad',
                                style: TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: AppColors.border),
                      _ActionTile(
                        icon: Icons.edit_outlined,
                        title: 'Editar nombre',
                        subtitle: 'Actualizar el nombre mostrado en la cuenta.',
                        onTap: abrirEditarNombre,
                      ),
                      _ActionTile(
                        icon: Icons.lock_reset_outlined,
                        title: 'Cambiar contraseña',
                        subtitle:
                            'Actualizar la contraseña actual por una nueva.',
                        onTap: abrirCambiarPassword,
                      ),
                      _ActionTile(
                        icon: Icons.alternate_email_outlined,
                        title: 'Cambiar correo',
                        subtitle:
                            'Enviar un código al nuevo correo para confirmarlo.',
                        onTap: abrirSolicitarCambioCorreo,
                      ),
                      _ActionTile(
                        icon: Icons.phone_android_outlined,
                        title: 'Cambiar teléfono',
                        subtitle:
                            'Confirmar el cambio usando un código enviado al correo.',
                        onTap: abrirSolicitarCambioTelefono,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final confirmado = await AppFeedback.confirm(
                        context: context,
                        title: 'Cerrar sesión',
                        message:
                            '¿Está seguro de que desea cerrar la sesión actual?',
                        confirmText: 'Sí, cerrar sesión',
                        danger: true,
                      );

                      if (!confirmado) return;

                      widget.onLogout();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: const Icon(Icons.logout),
                    label: const Text(
                      'Cerrar sesión',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 16,
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.border),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 15.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}