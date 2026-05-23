import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/push_notification_service.dart';
import '../services/preload_service.dart';
import '../ui/common.dart';
import '../core/ui/dialogs/app_feedback.dart';
import 'home.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService authService = AuthService();

  final formKey = GlobalKey<FormState>();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool loading = false;
  bool passwordVisible = false;
  bool recordarCorreo = true;

  @override
  void initState() {
    super.initState();
    cargarCorreoRecordado();
  }

  Future<void> cargarCorreoRecordado() async {
    final prefs = await SharedPreferences.getInstance();
    final correoGuardado = prefs.getString('remembered_email') ?? '';
    final recordar = prefs.getBool('remember_email') ?? true;

    if (!mounted) return;

    setState(() {
      recordarCorreo = recordar;
      emailController.text = correoGuardado;
    });
  }

  Future<void> guardarPreferenciaCorreo(String email) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('remember_email', recordarCorreo);

    if (recordarCorreo) {
      await prefs.setString('remembered_email', email);
    } else {
      await prefs.remove('remembered_email');
    }
  }

  void mostrarMensaje(String mensaje) {
    if (!mounted) return;

    AppFeedback.message(
      context: context,
      message: mensaje,
    );
  }

  Future<void> iniciarSesion() async {
    if (loading) return;
    if (!formKey.currentState!.validate()) return;

    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text;

    setState(() {
      loading = true;
    });

    try {
      final response = await authService.login(
        email: email,
        password: password,
      );

      final token =
          response['accessToken'] ?? response['access_token'] ?? response['token'];

      if (token == null || token.toString().trim().isEmpty) {
        throw Exception('El servidor no devolvió token.');
      }

      await guardarPreferenciaCorreo(email);

      passwordController.clear();

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );

      // Esto corre después, sin bloquear el login ni dejar la pantalla cargando.
      Future.delayed(const Duration(milliseconds: 700), () {
        unawaited(PushNotificationService.instance.registrarTokenEnBackend());
        unawaited(PreloadService.precargarTodo());
      });
    } catch (error) {
      final mensaje = error.toString().replaceAll('Exception: ', '');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: Colors.red,
        ),
      );

      if (mensaje.toLowerCase().contains('verificar')) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VerifyEmailScreen(email: email),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        padding: const EdgeInsets.all(22),
        child: PageContainer(
          maxWidth: 480,
          child: Center(
            child: SingleChildScrollView(
              child: AppGlassCard(
                padding: const EdgeInsets.all(30),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/logo_icono.png',
                        width: 90,
                        height: 90,
                        fit: BoxFit.contain,
                      ),

                      const SizedBox(height: 24),
                      const Text(
                        'Gestor de Proyectos',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 31,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Ingrese con su cuenta para administrar clientes, proyectos, pagos y recordatorios.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.textMuted,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 30),

                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !loading,
                        decoration: const InputDecoration(
                          labelText: 'Correo electrónico',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          final regex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

                          if (text.isEmpty) {
                            return 'El correo es obligatorio.';
                          }

                          if (!regex.hasMatch(text)) {
                            return 'Ingrese un correo válido.';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      TextFormField(
                        controller: passwordController,
                        enabled: !loading,
                        obscureText: !passwordVisible,
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: loading
                                ? null
                                : () {
                                    setState(() {
                                      passwordVisible = !passwordVisible;
                                    });
                                  },
                            icon: Icon(
                              passwordVisible
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';

                          if (text.isEmpty) {
                            return 'La contraseña es obligatoria.';
                          }

                          if (text.length < 6) {
                            return 'Mínimo 6 caracteres.';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: loading
                                  ? null
                                  : () {
                                      setState(() {
                                        recordarCorreo = !recordarCorreo;
                                      });
                                    },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value: recordarCorreo,
                                    onChanged: loading
                                        ? null
                                        : (value) {
                                            setState(() {
                                              recordarCorreo = value ?? true;
                                            });
                                          },
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  const Flexible(
                                    child: Text(
                                      'Recuérdame',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: loading
                                ? null
                                : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const ForgotPasswordScreen(),
                                      ),
                                    );
                                  },
                            child: const Text(
                              '¿Olvidó su contraseña?',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      _GradientButton(
                        text: 'Iniciar sesión',
                        loading: loading,
                        icon: Icons.login,
                        onPressed: iniciarSesion,
                      ),

                      const SizedBox(height: 18),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            '¿No tenés cuenta?',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextButton(
                            onPressed: loading
                                ? null
                                : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const RegisterScreen(),
                                      ),
                                    );
                                  },
                            child: const Text(
                              'Crear cuenta',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AuthService authService = AuthService();

  final formKey = GlobalKey<FormState>();

  final TextEditingController nombreController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  String selectedDialCode = '+506';
  String selectedCountryCode = 'CR';

  bool loading = false;
  bool passwordVisible = false;
  bool confirmPasswordVisible = false;

  void mostrarMensaje(String mensaje) {
    if (!mounted) return;

    AppFeedback.message(
      context: context,
      message: mensaje,
    );
  }

  String limpiarTelefono(String value) {
    return value
        .replaceAll(' ', '')
        .replaceAll('-', '')
        .replaceAll('(', '')
        .replaceAll(')', '')
        .trim();
  }

  String construirTelefonoCompleto() {
    final phone = limpiarTelefono(phoneController.text);

    if (phone.startsWith('+')) {
      return phone;
    }

    final onlyNumbers = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return '$selectedDialCode$onlyNumbers';
  }

  Future<void> registrarUsuario() async {
    if (loading) return;
    if (!formKey.currentState!.validate()) return;

    final nombre = nombreController.text.trim();
    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text;
    final telefonoCompleto = construirTelefonoCompleto();

    setState(() {
      loading = true;
    });

    try {
      await authService.register(
        nombre: nombre,
        email: email,
        password: password,
        telefono: telefonoCompleto,
        phoneCountryIso2: selectedCountryCode,
        phoneDialCode: selectedDialCode,
        platform: 'android',
      );

      if (!mounted) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_email', true);
      await prefs.setString('remembered_email', email);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cuenta creada correctamente. Inicia sesión.'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } catch (error) {
      final mensaje = error.toString().replaceAll('Exception: ', '');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    nombreController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear cuenta'),
      ),
      body: AppBackground(
        padding: const EdgeInsets.all(22),
        child: PageContainer(
          maxWidth: 520,
          child: Center(
            child: SingleChildScrollView(
              child: AppGlassCard(
                padding: const EdgeInsets.all(30),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppHeaderBadge(
                        icon: Icons.person_add_alt_1_outlined,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Registro de usuario',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 29,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Cree su cuenta ingresando sus datos personales. El teléfono se usará para recuperación y cambios de seguridad.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 28),

                      TextFormField(
                        controller: nombreController,
                        enabled: !loading,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Nombre completo',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
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

                      const SizedBox(height: 16),

                      TextFormField(
                        controller: emailController,
                        enabled: !loading,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Correo electrónico',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          final regex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

                          if (text.isEmpty) {
                            return 'El correo es obligatorio.';
                          }

                          if (!regex.hasMatch(text)) {
                            return 'Ingrese un correo válido.';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(180),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.black.withAlpha(35),
                              ),
                            ),
                            child: CountryCodePicker(
                              onChanged: (country) {
                                setState(() {
                                  selectedDialCode = country.dialCode ?? '+506';
                                  selectedCountryCode = country.code ?? 'CR';
                                });
                              },
                              initialSelection: selectedCountryCode,
                              favorite: const ['CR', 'US', 'MX', 'NI', 'PA'],
                              showCountryOnly: false,
                              showOnlyCountryWhenClosed: false,
                              alignLeft: false,
                              padding: EdgeInsets.zero,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: phoneController,
                              enabled: !loading,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9\s\-\+\(\)]'),
                                ),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Teléfono',
                                hintText: '8888 8888',
                                prefixIcon: Icon(Icons.phone_outlined),
                              ),
                              validator: (value) {
                                final text = limpiarTelefono(value ?? '');

                                if (text.isEmpty) {
                                  return 'El teléfono es obligatorio.';
                                }

                                final onlyNumbers = text.replaceAll(
                                  RegExp(r'[^0-9]'),
                                  '',
                                );

                                if (selectedCountryCode == 'CR' &&
                                    onlyNumbers.length != 8) {
                                  return 'En Costa Rica debe tener 8 dígitos.';
                                }

                                if (onlyNumbers.length < 7) {
                                  return 'El teléfono es demasiado corto.';
                                }

                                return null;
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Se guardará como: ${construirTelefonoCompleto()}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      TextFormField(
                        controller: passwordController,
                        enabled: !loading,
                        obscureText: !passwordVisible,
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: loading
                                ? null
                                : () {
                                    setState(() {
                                      passwordVisible = !passwordVisible;
                                    });
                                  },
                            icon: Icon(
                              passwordVisible
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';

                          if (text.isEmpty) {
                            return 'La contraseña es obligatoria.';
                          }

                          if (text.length < 6) {
                            return 'Mínimo 6 caracteres.';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      TextFormField(
                        controller: confirmPasswordController,
                        enabled: !loading,
                        obscureText: !confirmPasswordVisible,
                        decoration: InputDecoration(
                          labelText: 'Confirmar contraseña',
                          prefixIcon: const Icon(Icons.lock_reset_outlined),
                          suffixIcon: IconButton(
                            onPressed: loading
                                ? null
                                : () {
                                    setState(() {
                                      confirmPasswordVisible =
                                          !confirmPasswordVisible;
                                    });
                                  },
                            icon: Icon(
                              confirmPasswordVisible
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';

                          if (text.isEmpty) {
                            return 'Confirme la contraseña.';
                          }

                          if (text != passwordController.text.trim()) {
                            return 'Las contraseñas no coinciden.';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 24),

                      _GradientButton(
                        text: 'Registrarme',
                        loading: loading,
                        icon: Icons.person_add_alt_1,
                        onPressed: registrarUsuario,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class VerifyEmailScreen extends StatefulWidget {
  final String email;

  const VerifyEmailScreen({
    super.key,
    required this.email,
  });

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final AuthService authService = AuthService();

  final formKey = GlobalKey<FormState>();
  final TextEditingController codeController = TextEditingController();

  bool loading = false;
  bool resending = false;

  void mostrarMensaje(String mensaje) {
    if (!mounted) return;

    AppFeedback.message(
      context: context,
      message: mensaje,
    );
  }

  Future<void> verificarCorreo() async {
    if (!formKey.currentState!.validate()) return;

    setState(() {
      loading = true;
    });

    try {
      await authService.verifyEmail(
        email: widget.email,
        code: codeController.text.trim(),
      );

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } catch (error) {
      mostrarMensaje(error.toString().replaceAll('Exception: ', ''));
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
      final data = await authService.resendVerificationCode(
        email: widget.email,
      );

      mostrarMensaje(
        data['message']?.toString() ?? 'Código reenviado correctamente.',
      );
    } catch (error) {
      mostrarMensaje(error.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          resending = false;
        });
      }
    }
  }

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verificar correo'),
      ),
      body: AppBackground(
        padding: const EdgeInsets.all(22),
        child: PageContainer(
          maxWidth: 500,
          child: Center(
            child: SingleChildScrollView(
              child: AppGlassCard(
                padding: const EdgeInsets.all(30),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppHeaderBadge(
                        icon: Icons.mark_email_read_outlined,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Código de verificación',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ingrese el código de 6 dígitos enviado a:\n${widget.email}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 28),

                      TextFormField(
                        controller: codeController,
                        enabled: !loading,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 6,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Código',
                          prefixIcon: Icon(Icons.pin_outlined),
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';

                          if (text.isEmpty) {
                            return 'El código es obligatorio.';
                          }

                          if (text.length != 6) {
                            return 'El código debe tener 6 dígitos.';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 24),

                      _GradientButton(
                        text: 'Verificar y entrar',
                        loading: loading,
                        icon: Icons.verified_outlined,
                        onPressed: verificarCorreo,
                      ),

                      const SizedBox(height: 14),

                      TextButton.icon(
                        onPressed: loading || resending ? null : reenviarCodigo,
                        icon: resending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh),
                        label: const Text(
                          'Reenviar código',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final AuthService authService = AuthService();

  final emailFormKey = GlobalKey<FormState>();
  final resetFormKey = GlobalKey<FormState>();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController codeController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool codeSent = false;
  bool loading = false;
  bool passwordVisible = false;
  bool confirmPasswordVisible = false;

  void mostrarMensaje(String mensaje) {
    if (!mounted) return;

    AppFeedback.message(
      context: context,
      message: mensaje,
    );
  }

  Future<void> solicitarCodigo() async {
    if (!emailFormKey.currentState!.validate()) return;

    final confirmado = await AppFeedback.confirm(
      context: context,
      title: 'Enviar código',
      message: '¿Desea enviar un código de recuperación a este correo?',
      confirmText: 'Sí, enviar',
    );

    if (!confirmado) return;

    setState(() {
      loading = true;
    });

    try {
      final data = await authService.forgotPassword(
        email: emailController.text.trim().toLowerCase(),
      );

      if (!mounted) return;

      setState(() {
        codeSent = true;
      });

      mostrarMensaje(
        data['message']?.toString() ??
            'Si el correo está registrado, se enviará un código.',
      );
    } catch (error) {
      mostrarMensaje(error.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> cambiarPassword() async {
    if (!resetFormKey.currentState!.validate()) return;

    final confirmado = await AppFeedback.confirm(
      context: context,
      title: 'Cambiar contraseña',
      message: '¿Está seguro de que desea actualizar su contraseña?',
      confirmText: 'Sí, cambiar',
      danger: true,
    );

    if (!confirmado) return;

    setState(() {
      loading = true;
    });

    try {
      final data = await authService.resetPassword(
        email: emailController.text.trim().toLowerCase(),
        code: codeController.text.trim(),
        newPassword: newPasswordController.text.trim(),
      );

      if (!mounted) return;

      mostrarMensaje(
        data['message']?.toString() ?? 'Contraseña actualizada correctamente.',
      );

      Navigator.pop(context);
    } catch (error) {
      mostrarMensaje(error.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    codeController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recuperar contraseña'),
      ),
      body: AppBackground(
        padding: const EdgeInsets.all(22),
        child: PageContainer(
          maxWidth: 520,
          child: Center(
            child: SingleChildScrollView(
              child: AppGlassCard(
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppHeaderBadge(
                      icon: Icons.lock_reset_outlined,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Recuperar contraseña',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ingrese su correo. Si existe una cuenta registrada, recibirá un código para cambiar la contraseña.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 28),

                    Form(
                      key: emailFormKey,
                      child: TextFormField(
                        controller: emailController,
                        enabled: !loading && !codeSent,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Correo electrónico',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          final regex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

                          if (text.isEmpty) {
                            return 'El correo es obligatorio.';
                          }

                          if (!regex.hasMatch(text)) {
                            return 'Ingrese un correo válido.';
                          }

                          return null;
                        },
                      ),
                    ),

                    if (!codeSent) ...[
                      const SizedBox(height: 24),
                      _GradientButton(
                        text: 'Enviar código',
                        loading: loading,
                        icon: Icons.send_outlined,
                        onPressed: solicitarCodigo,
                      ),
                    ],

                    if (codeSent) ...[
                      const SizedBox(height: 18),
                      Form(
                        key: resetFormKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: codeController,
                              enabled: !loading,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(6),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Código de recuperación',
                                prefixIcon: Icon(Icons.pin_outlined),
                              ),
                              validator: (value) {
                                final text = value?.trim() ?? '';

                                if (text.isEmpty) {
                                  return 'El código es obligatorio.';
                                }

                                if (text.length != 6) {
                                  return 'El código debe tener 6 dígitos.';
                                }

                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            TextFormField(
                              controller: newPasswordController,
                              enabled: !loading,
                              obscureText: !passwordVisible,
                              decoration: InputDecoration(
                                labelText: 'Nueva contraseña',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  onPressed: loading
                                      ? null
                                      : () {
                                          setState(() {
                                            passwordVisible = !passwordVisible;
                                          });
                                        },
                                  icon: Icon(
                                    passwordVisible
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                final text = value?.trim() ?? '';

                                if (text.isEmpty) {
                                  return 'La nueva contraseña es obligatoria.';
                                }

                                if (text.length < 6) {
                                  return 'Mínimo 6 caracteres.';
                                }

                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            TextFormField(
                              controller: confirmPasswordController,
                              enabled: !loading,
                              obscureText: !confirmPasswordVisible,
                              decoration: InputDecoration(
                                labelText: 'Confirmar contraseña',
                                prefixIcon: const Icon(Icons.lock_reset_outlined),
                                suffixIcon: IconButton(
                                  onPressed: loading
                                      ? null
                                      : () {
                                          setState(() {
                                            confirmPasswordVisible =
                                                !confirmPasswordVisible;
                                          });
                                        },
                                  icon: Icon(
                                    confirmPasswordVisible
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                final text = value?.trim() ?? '';

                                if (text.isEmpty) {
                                  return 'Confirme la contraseña.';
                                }

                                if (text != newPasswordController.text.trim()) {
                                  return 'Las contraseñas no coinciden.';
                                }

                                return null;
                              },
                            ),

                            const SizedBox(height: 24),

                            _GradientButton(
                              text: 'Cambiar contraseña',
                              loading: loading,
                              icon: Icons.save_outlined,
                              onPressed: cambiarPassword,
                            ),

                            const SizedBox(height: 12),

                            TextButton.icon(
                              onPressed: loading ? null : solicitarCodigo,
                              icon: const Icon(Icons.refresh),
                              label: const Text(
                                'Reenviar código',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

class _GradientButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final bool loading;
  final VoidCallback onPressed;

  const _GradientButton({
    required this.text,
    required this.icon,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
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
          onPressed: loading ? null : onPressed,
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
              : Icon(icon),
          label: Text(
            loading ? 'Procesando...' : text,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}