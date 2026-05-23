import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:country_code_picker/country_code_picker.dart';

import '../services/clientes_service.dart';
import '../core/cache/app_cache.dart';
import '../ui/common.dart';
import '../core/ui/dialogs/app_feedback.dart';
import '../core/business/business_rules.dart';
import '../core/ui/widgets/app_search_input.dart';
import '../core/ui/widgets/app_pagination_controls.dart';
import '../core/ui/widgets/formal_form_grid.dart';
import '../core/ui/widgets/app_form_field.dart';
import '../core/ui/widgets/app_field_shell.dart';
import '../core/ui/widgets/app_form_actions.dart';

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  final ClientesService clientesService = ClientesService();

  List<Map<String, dynamic>> clientes = [];
  bool loading = true;

  String busqueda = '';
  int paginaActual = 1;
  static const int clientesPorPagina = 10;

  @override
  void initState() {
    super.initState();
    cargarClientes();
  }

  List<Map<String, dynamic>> get clientesFiltrados {
    final texto = busqueda.trim().toLowerCase();

    if (texto.isEmpty) {
      return clientes;
    }

    return clientes.where((cliente) {
      final nombre = cliente['nombre']?.toString().toLowerCase() ?? '';
      final telefono = cliente['telefono']?.toString().toLowerCase() ?? '';
      final telefonoInternacional =
          cliente['telefonoInternacional']?.toString().toLowerCase() ?? '';
      final telefonoPais =
          cliente['telefonoPais']?.toString().toLowerCase() ?? '';
      final correo = cliente['correo']?.toString().toLowerCase() ?? '';
      final direccion = cliente['direccion']?.toString().toLowerCase() ?? '';

      return nombre.contains(texto) ||
          telefono.contains(texto) ||
          telefonoInternacional.contains(texto) ||
          telefonoPais.contains(texto) ||
          correo.contains(texto) ||
          direccion.contains(texto);
    }).toList();
  }

  List<Map<String, dynamic>> get clientesPaginados {
    if (clientesFiltrados.isEmpty) {
      return [];
    }

    final inicio = (paginaActual - 1) * clientesPorPagina;
    final fin = math.min(inicio + clientesPorPagina, clientesFiltrados.length);

    if (inicio >= clientesFiltrados.length) {
      return [];
    }

    return clientesFiltrados.sublist(inicio, fin);
  }

  Future<void> cargarClientes({bool silencioso = false}) async {
    if (AppCache.clientes != null) {
      setState(() {
        clientes = AppCache.clientes!;
        loading = false;
      });

      silencioso = true;
    }

    if (!silencioso && mounted) {
      setState(() {
        loading = true;
      });
    }

    try {
      final data = await clientesService.getClientes();

      if (!mounted) return;

      AppCache.guardarClientes(data);

      setState(() {
        clientes = data;
        loading = false;
        paginaActual = 1;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      if (AppCache.clientes == null) {
        mostrarMensaje(error.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  void mostrarMensaje(String mensaje) {
    if (!mounted) return;

    AppFeedback.message(context: context, message: mensaje);
  }

  bool correoValido(String correo) {
    final regex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return regex.hasMatch(correo);
  }

  Future<void> abrirFormularioCliente({Map<String, dynamic>? cliente}) async {
    final formKey = GlobalKey<FormState>();

    final nombreController = TextEditingController(
      text: cliente?['nombre']?.toString() ?? '',
    );

    final telefonoController = TextEditingController(
      text: cliente?['telefono']?.toString() ?? '',
    );

    final correoController = TextEditingController(
      text: cliente?['correo']?.toString() ?? '',
    );

    final direccionController = TextEditingController(
      text: cliente?['direccion']?.toString() ?? '',
    );

    final esEdicion = cliente != null;

    String telefonoPaisSeleccionado =
        cliente?['telefonoPais']?.toString().toUpperCase() ?? 'CR';

    String telefonoPrefijoSeleccionado = '+506';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool guardando = false;

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return PopScope(
              canPop: !guardando,
              child: AppFormDialog(
                title: esEdicion ? 'Editar cliente' : 'Agregar cliente',
                subtitle:
                    'Complete la información principal del cliente de forma clara y ordenada.',
                icon: esEdicion
                    ? Icons.edit_note_outlined
                    : Icons.person_add_alt_outlined,
                desktopWidth: 860,
                desktopHeight: 520,
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FormalFormGrid(
                        children: [
                          AppFormField(
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

                              final regex = RegExp(
                                r"^[A-Za-zÁÉÍÓÚáéíóúÑñ\s'.-]+$",
                              );

                              if (!regex.hasMatch(text)) {
                                return 'Solo use letras, espacios y signos básicos.';
                              }

                              return null;
                            },
                          ),
                          AppFieldShell(
                            label: 'País del teléfono',
                            requiredField: true,
                            child: Container(
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: AppColors.border),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: CountryCodePicker(
                                onInit: (countryCode) {
                                  if (countryCode == null) return;

                                  telefonoPaisSeleccionado =
                                      countryCode.code?.toUpperCase() ?? 'CR';
                                  telefonoPrefijoSeleccionado =
                                      countryCode.dialCode ?? '+506';
                                },
                                onChanged: guardando
                                    ? null
                                    : (countryCode) {
                                        setDialogState(() {
                                          telefonoPaisSeleccionado =
                                              countryCode.code?.toUpperCase() ??
                                              'CR';
                                          telefonoPrefijoSeleccionado =
                                              countryCode.dialCode ?? '+506';
                                        });
                                      },
                                initialSelection: telefonoPaisSeleccionado,
                                favorite: const [
                                  'CR',
                                  'US',
                                  'MX',
                                  'CO',
                                  'PA',
                                  'NI',
                                ],
                                showCountryOnly: false,
                                showOnlyCountryWhenClosed: false,
                                showDropDownButton: true,
                                alignLeft: true,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textDark,
                                ),
                                searchDecoration: const InputDecoration(
                                  labelText: 'Buscar país',
                                  prefixIcon: Icon(Icons.search),
                                ),
                              ),
                            ),
                          ),
                          AppFormField(
                            controller: telefonoController,
                            enabled: !guardando,
                            label: 'Número de teléfono',
                            hint: 'Ejemplo: 8888-8888',
                            helperText:
                                'País seleccionado: $telefonoPaisSeleccionado $telefonoPrefijoSeleccionado',
                            icon: Icons.phone_outlined,
                            requiredField: true,
                            keyboardType: TextInputType.phone,
                            maxLength: 20,
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

                              final regex = RegExp(r'^[0-9+\s()-]+$');

                              if (!regex.hasMatch(text)) {
                                return 'Use solo números, +, espacios, guiones o paréntesis.';
                              }

                              return null;
                            },
                          ),
                          AppFormField(
                            controller: correoController,
                            enabled: !guardando,
                            label: 'Correo electrónico',
                            hint: 'cliente@correo.com',
                            icon: Icons.email_outlined,
                            requiredField: true,
                            keyboardType: TextInputType.emailAddress,
                            maxLength: 120,
                            validator: (value) {
                              final text = value?.trim().toLowerCase() ?? '';

                              if (text.isEmpty) {
                                return 'El correo es obligatorio.';
                              }

                              if (!correoValido(text)) {
                                return 'Ingrese un correo electrónico válido.';
                              }

                              if (text.length > 120) {
                                return 'No puede superar los 120 caracteres.';
                              }

                              return null;
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      AppFormField(
                        controller: direccionController,
                        enabled: !guardando,
                        label: 'Dirección',
                        hint:
                            'Ejemplo: Barrio El Carmen, 200 metros norte de la escuela',
                        icon: Icons.location_on_outlined,
                        requiredField: true,
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: 3,
                        maxLength: 150,
                        validator: (value) {
                          final text = value?.trim() ?? '';

                          if (text.isEmpty) {
                            return 'La dirección es obligatoria.';
                          }

                          if (text.length < 5 || text.length > 150) {
                            return 'Debe tener entre 5 y 150 caracteres.';
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
                    primaryText: esEdicion ? 'Actualizar' : 'Guardar',
                    onCancel: () {
                      if (guardando) return;

                      FocusManager.instance.primaryFocus?.unfocus();
                      Navigator.of(dialogContext).pop();
                    },
                    onSubmit: () async {
                      if (!formKey.currentState!.validate()) {
                        return;
                      }

                      final nombre = nombreController.text.trim();
                      final telefono = telefonoController.text.trim();
                      final correo = correoController.text.trim().toLowerCase();
                      final direccion = direccionController.text.trim();

                      final resultadoUnico = BusinessRules.validarClienteUnico(
                        clientes: clientes,
                        idActual: cliente == null
                            ? null
                            : cliente['id']?.toString(),
                        correo: correo,
                        telefonoPais: telefonoPaisSeleccionado,
                        telefono: telefono,
                      );

                      if (!resultadoUnico.isValid) {
                        mostrarMensaje(resultadoUnico.message!);
                        return;
                      }

                      setDialogState(() {
                        guardando = true;
                      });

                      try {
                        if (esEdicion) {
                          await clientesService.actualizarCliente(
                            id: int.parse(cliente['id'].toString()),
                            nombre: nombre,
                            telefonoPais: telefonoPaisSeleccionado,
                            telefono: telefono,
                            correo: correo,
                            direccion: direccion,
                          );
                        } else {
                          await clientesService.crearCliente(
                            nombre: nombre,
                            telefonoPais: telefonoPaisSeleccionado,
                            telefono: telefono,
                            correo: correo,
                            direccion: direccion,
                          );
                        }

                        if (!mounted) return;

                        if (dialogContext.mounted) {
                          FocusManager.instance.primaryFocus?.unfocus();
                          Navigator.of(dialogContext).pop();
                        }

                        AppCache.clientes = null;
                        AppCache.invalidarResumenes();

                        mostrarMensaje(
                          esEdicion
                              ? 'Cliente actualizado correctamente.'
                              : 'Cliente creado correctamente.',
                        );

                        await cargarClientes(silencioso: true);
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
              ),
            );
          },
        );
      },
    );

    nombreController.dispose();
    telefonoController.dispose();
    correoController.dispose();
    direccionController.dispose();
  }

  Future<void> eliminarCliente(Map<String, dynamic> cliente) async {
    bool accionEjecutada = false;

    await AppFeedback.confirmAndRun(
      context: context,
      confirmTitle: 'Eliminar cliente',
      confirmMessage:
          '¿Está seguro de que desea eliminar a ${cliente['nombre']}? También se eliminarán sus proyectos asociados. Esta acción no se puede deshacer.',
      confirmText: 'Sí, eliminar',
      danger: true,
      loadingMessage: 'Eliminando cliente...',
      successTitle: 'Cliente eliminado',
      successMessage: 'El cliente se eliminó correctamente.',
      action: () async {
        await clientesService.eliminarCliente(
          int.parse(cliente['id'].toString()),
        );

        AppCache.clientes = null;
        AppCache.invalidarResumenes();
        accionEjecutada = true;
      },
    );

    if (accionEjecutada && mounted) {
      await cargarClientes(silencioso: true);
    }
  }

  Widget construirBotonCrearSuperior({
    required String texto,
    required IconData icono,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icono, size: 20),
        label: Text(texto, style: const TextStyle(fontWeight: FontWeight.w900)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget construirTablaClientes() {
    return PageContainer(
      maxWidth: 1150,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppTablePanel(
            title: 'Clientes registrados',
            subtitle:
                'Listado general de clientes con información de contacto y proyectos asociados.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                construirBotonCrearSuperior(
                  texto: 'Agregar cliente',
                  icono: Icons.person_add_alt_outlined,
                  onPressed: () => abrirFormularioCliente(),
                ),
                const SizedBox(height: 12),
                AppSearchInput(
                  hintText:
                      'Buscar por nombre, teléfono, correo o dirección...',
                  onChanged: (value) {
                    setState(() {
                      busqueda = value;
                      paginaActual = 1;
                    });
                  },
                ),
                const SizedBox(height: 16),
                if (clientes.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 26,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 42,
                          color: AppColors.textMuted,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'No hay clientes registrados',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: AppColors.textDark,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Agregue el primer cliente para comenzar a organizar proyectos, pagos, visitas y recordatorios.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  )
                else if (clientesFiltrados.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 26,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.search_off_outlined,
                          size: 42,
                          color: AppColors.textMuted,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'No se encontraron clientes',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: AppColors.textDark,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Intente buscar con otro nombre, teléfono, correo o dirección.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  )
                else ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 58,
                      dataRowMinHeight: 62,
                      dataRowMaxHeight: 82,
                      columnSpacing: 34,
                      horizontalMargin: 22,
                      headingTextStyle: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppColors.textDark,
                        fontSize: 13,
                      ),
                      dataTextStyle: const TextStyle(
                        color: AppColors.textDark,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                      ),
                      columns: const [
                        DataColumn(label: Text('Cliente')),
                        DataColumn(label: Text('Teléfono')),
                        DataColumn(label: Text('Correo')),
                        DataColumn(label: Text('Dirección')),
                        DataColumn(label: Text('Proyectos')),
                        DataColumn(label: Text('Acciones')),
                      ],
                      rows: clientesPaginados.map((cliente) {
                        final cantidadProyectos =
                            cliente['_count']?['proyectos']?.toString() ?? '0';

                        final telefonoMostrado =
                            cliente['telefonoInternacional']?.toString() ??
                            '${cliente['telefonoPais'] ?? ''} ${cliente['telefono'] ?? ''}';

                        return DataRow(
                          cells: [
                            DataCell(
                              Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          AppColors.primary,
                                          AppColors.accent,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                      Icons.person_outline,
                                      size: 22,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 170,
                                    ),
                                    child: Text(
                                      cliente['nombre']?.toString() ??
                                          'Sin nombre',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 150,
                                ),
                                child: Text(
                                  telefonoMostrado,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 210,
                                ),
                                child: Text(
                                  cliente['correo']?.toString() ?? '',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 260,
                                ),
                                child: Text(
                                  cliente['direccion']?.toString() ?? '',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  cantidadProyectos,
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                children: [
                                  IconButton(
                                    tooltip: 'Editar',
                                    onPressed: () {
                                      abrirFormularioCliente(cliente: cliente);
                                    },
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Eliminar',
                                    onPressed: () {
                                      eliminarCliente(cliente);
                                    },
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: AppColors.danger,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppPaginationControls(
                    currentPage: paginaActual,
                    totalItems: clientesFiltrados.length,
                    pageSize: clientesPorPagina,
                    onPageChanged: (page) {
                      setState(() {
                        paginaActual = page;
                      });
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget construirEmptyState() {
    return const AppEmptyState(
      icon: Icons.people_outline,
      title: 'No hay clientes registrados',
      subtitle:
          'Agregue el primer cliente para comenzar a organizar proyectos, pagos, visitas y recordatorios.',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: AppLoading(text: 'Cargando clientes...'));
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        padding: EdgeInsets.zero,
        child: RefreshIndicator(
          onRefresh: cargarClientes,
          child: construirTablaClientes(),
        ),
      ),
    );
  }
}
