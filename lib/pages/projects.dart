import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/proyectos_service.dart';
import '../services/clientes_service.dart';
import '../core/cache/app_cache.dart';
import '../ui/common.dart';
import '../core/ui/dialogs/app_feedback.dart';
import '../core/business/business_rules.dart';
import '../core/ui/widgets/app_search_input.dart';
import '../core/ui/widgets/app_pagination_controls.dart';
import '../core/ui/widgets/formal_form_grid.dart';
import '../core/ui/widgets/app_form_field.dart';
import '../core/ui/widgets/app_select_field.dart';
import '../core/ui/widgets/app_form_actions.dart';
import 'project_detail.dart';

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  final ProyectosService proyectosService = ProyectosService();
  final ClientesService clientesService = ClientesService();

  List<Map<String, dynamic>> proyectos = [];
  List<Map<String, dynamic>> clientes = [];

  bool loading = true;

  String busqueda = '';
  int paginaActual = 1;
  static const int proyectosPorPagina = 10;

  final Map<String, String> estadosProyecto = const {
    'PENDIENTE': 'Pendiente',
    'ACTIVO': 'Activo',
    'FINALIZADO': 'Finalizado',
    'PAUSADO': 'Pausado',
  };

  @override
  void initState() {
    super.initState();
    cargarDatos();
  }

  List<Map<String, dynamic>> get proyectosFiltrados {
    final texto = busqueda.trim().toLowerCase();

    if (texto.isEmpty) {
      return proyectos;
    }

    return proyectos.where((proyecto) {
      final nombre = proyecto['nombre']?.toString().toLowerCase() ?? '';
      final descripcion =
          proyecto['descripcion']?.toString().toLowerCase() ?? '';
      final estado = proyecto['estado']?.toString().toLowerCase() ?? '';
      final estadoTexto =
          estadosProyecto[proyecto['estado']]?.toLowerCase() ?? '';
      final cliente = obtenerNombreCliente(proyecto).toLowerCase();
      final monto = proyecto['montoTotal']?.toString().toLowerCase() ?? '';

      return nombre.contains(texto) ||
          descripcion.contains(texto) ||
          estado.contains(texto) ||
          estadoTexto.contains(texto) ||
          cliente.contains(texto) ||
          monto.contains(texto);
    }).toList();
  }

  List<Map<String, dynamic>> get proyectosPaginados {
    if (proyectosFiltrados.isEmpty) {
      return [];
    }

    final inicio = (paginaActual - 1) * proyectosPorPagina;
    final fin = math.min(
      inicio + proyectosPorPagina,
      proyectosFiltrados.length,
    );

    if (inicio >= proyectosFiltrados.length) {
      return [];
    }

    return proyectosFiltrados.sublist(inicio, fin);
  }

  Future<void> cargarDatos({bool silencioso = false}) async {
    if (AppCache.proyectos != null || AppCache.clientes != null) {
      setState(() {
        proyectos = AppCache.proyectos ?? proyectos;
        clientes = AppCache.clientes ?? clientes;
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
      final results = await Future.wait([
        proyectosService.getProyectos(),
        clientesService.getClientes(),
      ]);

      final proyectosData = results[0];
      final clientesData = results[1];

      if (!mounted) return;

      AppCache.guardarProyectos(proyectosData);
      AppCache.guardarClientes(clientesData);

      setState(() {
        proyectos = proyectosData;
        clientes = clientesData;
        loading = false;
        paginaActual = 1;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      if (AppCache.proyectos == null) {
        mostrarMensaje(error.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  void mostrarMensaje(String mensaje) {
    if (!mounted) return;

    AppFeedback.message(context: context, message: mensaje);
  }

  double obtenerMonto(dynamic value) {
    if (value == null) return 0;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0;
  }

  String formatearMonto(dynamic value) {
    final monto = obtenerMonto(value);

    return '₡${monto.toStringAsFixed(0)}';
  }

  double calcularTotalPagado(Map<String, dynamic> proyecto) {
    final pagos = proyecto['pagos'];

    if (pagos is! List) return 0;

    return pagos.fold<double>(0, (total, pago) {
      if (pago is Map) {
        return total + obtenerMonto(pago['monto']);
      }

      return total;
    });
  }

  Color colorEstado(String estado) {
    switch (estado) {
      case 'ACTIVO':
        return AppColors.success;
      case 'PENDIENTE':
        return AppColors.warning;
      case 'FINALIZADO':
        return AppColors.primary;
      case 'PAUSADO':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String obtenerNombreCliente(Map<String, dynamic> proyecto) {
    final cliente = proyecto['cliente'];

    if (cliente is Map && cliente['nombre'] != null) {
      return cliente['nombre'].toString();
    }

    final clienteId = proyecto['clienteId'];

    final encontrado = clientes.where((item) {
      return item['id']?.toString() == clienteId?.toString();
    }).toList();

    if (encontrado.isNotEmpty) {
      return encontrado.first['nombre']?.toString() ?? 'Sin cliente';
    }

    return 'Sin cliente';
  }

  int obtenerClienteSeleccionado(Map<String, dynamic>? proyecto) {
    if (clientes.isEmpty) return 0;

    final clienteIdProyecto = proyecto?['clienteId'];

    if (clienteIdProyecto != null) {
      final existe = clientes.any(
        (cliente) => cliente['id']?.toString() == clienteIdProyecto.toString(),
      );

      if (existe) {
        return int.parse(clienteIdProyecto.toString());
      }
    }

    final cliente = proyecto?['cliente'];

    if (cliente is Map && cliente['id'] != null) {
      final id = int.parse(cliente['id'].toString());

      final existe = clientes.any(
        (item) => item['id']?.toString() == id.toString(),
      );

      if (existe) {
        return id;
      }
    }

    return int.parse(clientes.first['id'].toString());
  }

  Future<void> abrirFormularioProyecto({Map<String, dynamic>? proyecto}) async {
    if (clientes.isEmpty) {
      mostrarMensaje('Primero debe registrar al menos un cliente.');
      return;
    }

    final formKey = GlobalKey<FormState>();

    final nombreController = TextEditingController(
      text: proyecto?['nombre']?.toString() ?? '',
    );

    final descripcionController = TextEditingController(
      text: proyecto?['descripcion']?.toString() ?? '',
    );

    final montoController = TextEditingController(
      text: proyecto == null
          ? ''
          : obtenerMonto(proyecto['montoTotal']).toStringAsFixed(0),
    );

    int clienteSeleccionado = obtenerClienteSeleccionado(proyecto);

    String estadoSeleccionado = proyecto?['estado']?.toString() ?? 'PENDIENTE';

    if (!estadosProyecto.containsKey(estadoSeleccionado)) {
      estadoSeleccionado = 'PENDIENTE';
    }

    final esEdicion = proyecto != null;

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
                title: esEdicion ? 'Editar proyecto' : 'Agregar proyecto',
                subtitle:
                    'Complete la información principal del proyecto de forma clara y ordenada.',
                icon: esEdicion
                    ? Icons.edit_note_outlined
                    : Icons.create_new_folder_outlined,
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
                            label: 'Nombre del proyecto',
                            hint: 'Ejemplo: Remodelación de cocina',
                            icon: Icons.folder_outlined,
                            requiredField: true,
                            textCapitalization: TextCapitalization.sentences,
                            maxLength: 100,
                            validator: (value) {
                              final text = value?.trim() ?? '';

                              if (text.isEmpty) {
                                return 'El nombre es obligatorio.';
                              }

                              if (text.length < 3 || text.length > 100) {
                                return 'Debe tener entre 3 y 100 caracteres.';
                              }

                              return null;
                            },
                          ),
                          AppSelectField<int>(
                            label: 'Cliente asociado',
                            value: clienteSeleccionado,
                            icon: Icons.person_outline,
                            requiredField: true,
                            items: clientes.map((cliente) {
                              final id = int.parse(cliente['id'].toString());
                              final nombre =
                                  cliente['nombre']?.toString() ?? 'Sin nombre';

                              return DropdownMenuItem<int>(
                                value: id,
                                child: Text(
                                  nombre,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: guardando
                                ? null
                                : (value) {
                                    if (value == null) return;

                                    setDialogState(() {
                                      clienteSeleccionado = value;
                                    });
                                  },
                            validator: (value) {
                              if (value == null || value <= 0) {
                                return 'Debe seleccionar un cliente.';
                              }

                              return null;
                            },
                          ),
                          AppFormField(
                            controller: montoController,
                            enabled: !guardando,
                            label: 'Monto total',
                            hint: 'Ejemplo: 250000',
                            icon: Icons.payments_outlined,
                            requiredField: true,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.,]'),
                              ),
                              LengthLimitingTextInputFormatter(15),
                            ],
                            validator: (value) {
                              final text =
                                  value?.trim().replaceAll(',', '.') ?? '';

                              if (text.isEmpty) {
                                return 'El monto es obligatorio.';
                              }

                              final monto = double.tryParse(text);

                              if (monto == null || monto <= 0) {
                                return 'Ingrese un monto válido.';
                              }

                              if (monto > 100000000) {
                                return 'El monto no puede superar 100,000,000.';
                              }

                              return null;
                            },
                          ),
                          AppSelectField<String>(
                            label: 'Estado del proyecto',
                            value: estadoSeleccionado,
                            icon: Icons.flag_outlined,
                            requiredField: true,
                            items: estadosProyecto.entries.map((entry) {
                              return DropdownMenuItem<String>(
                                value: entry.key,
                                child: Text(entry.value),
                              );
                            }).toList(),
                            onChanged: guardando
                                ? null
                                : (value) {
                                    if (value == null) return;

                                    setDialogState(() {
                                      estadoSeleccionado = value;
                                    });
                                  },
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      AppFormField(
                        controller: descripcionController,
                        enabled: !guardando,
                        label: 'Descripción del proyecto',
                        hint:
                            'Describa brevemente el trabajo que se realizará en este proyecto',
                        icon: Icons.description_outlined,
                        requiredField: true,
                        textCapitalization: TextCapitalization.sentences,
                        maxLength: 500,
                        maxLines: 4,
                        validator: (value) {
                          final text = value?.trim() ?? '';

                          if (text.isEmpty) {
                            return 'La descripción es obligatoria.';
                          }

                          if (text.length < 5 || text.length > 500) {
                            return 'Debe tener entre 5 y 500 caracteres.';
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
                      final descripcion = descripcionController.text.trim();

                      final montoTexto = montoController.text.trim().replaceAll(
                        ',',
                        '.',
                      );

                      final monto = double.parse(montoTexto);

                      final totalPagado = esEdicion
                          ? calcularTotalPagado(proyecto)
                          : 0.0;

                      final resultadoMonto = BusinessRules.validarMontoProyecto(
                        montoTotal: monto,
                        totalPagado: totalPagado,
                        estadoProyecto: estadoSeleccionado,
                      );

                      if (!resultadoMonto.isValid) {
                        mostrarMensaje(resultadoMonto.message!);
                        return;
                      }

                      final clienteExiste = clientes.any(
                        (cliente) =>
                            cliente['id']?.toString() ==
                            clienteSeleccionado.toString(),
                      );

                      if (!clienteExiste) {
                        mostrarMensaje(
                          'Debe seleccionar un cliente registrado.',
                        );
                        return;
                      }

                      setDialogState(() {
                        guardando = true;
                      });

                      try {
                        if (esEdicion) {
                          await proyectosService.actualizarProyecto(
                            id: int.parse(proyecto['id'].toString()),
                            nombre: nombre,
                            descripcion: descripcion,
                            montoTotal: monto,
                            estado: estadoSeleccionado,
                            clienteId: clienteSeleccionado,
                          );
                        } else {
                          await proyectosService.crearProyecto(
                            nombre: nombre,
                            descripcion: descripcion,
                            montoTotal: monto,
                            estado: estadoSeleccionado,
                            clienteId: clienteSeleccionado,
                          );
                        }

                        if (!mounted) return;

                        if (dialogContext.mounted) {
                          FocusManager.instance.primaryFocus?.unfocus();
                          Navigator.of(dialogContext).pop();
                        }

                        AppCache.proyectos = null;
                        AppCache.invalidarResumenes();

                        mostrarMensaje(
                          esEdicion
                              ? 'Proyecto actualizado correctamente.'
                              : 'Proyecto creado correctamente.',
                        );

                        await cargarDatos(silencioso: true);
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
    descripcionController.dispose();
    montoController.dispose();
  }

  Future<void> eliminarProyecto(Map<String, dynamic> proyecto) async {
    bool accionEjecutada = false;
    final proyectoId = int.parse(proyecto['id'].toString());

    await AppFeedback.confirmAndRun(
      context: context,
      confirmTitle: 'Eliminar proyecto',
      confirmMessage:
          '¿Está seguro de que desea eliminar "${proyecto['nombre']}"? También se eliminarán sus pagos, visitas, comentarios y recordatorios. Esta acción no se puede deshacer.',
      confirmText: 'Sí, eliminar',
      danger: true,
      loadingMessage: 'Eliminando proyecto...',
      successTitle: 'Proyecto eliminado',
      successMessage: 'El proyecto se eliminó correctamente.',
      action: () async {
        await proyectosService.eliminarProyecto(proyectoId);

        AppCache.invalidarDetalleProyecto(proyectoId);
        AppCache.proyectos = null;
        AppCache.invalidarResumenes();

        accionEjecutada = true;
      },
    );

    if (accionEjecutada && mounted) {
      await cargarDatos(silencioso: true);
    }
  }

  Widget construirEstadoChip(String estado) {
    final texto = estadosProyecto[estado] ?? estado;
    final color = colorEstado(estado);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withAlpha(31),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
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

  Widget construirTablaProyectos() {
    return PageContainer(
      maxWidth: 1150,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppGlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(22),
                  child: Row(
                    children: [
                      Icon(
                        Icons.folder_outlined,
                        color: AppColors.primary,
                        size: 30,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Proyectos registrados',
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                  child: construirBotonCrearSuperior(
                    texto: 'Agregar proyecto',
                    icono: Icons.add,
                    onPressed: () => abrirFormularioProyecto(),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                  child: AppSearchInput(
                    hintText:
                        'Buscar por proyecto, cliente, estado, descripción o monto...',
                    onChanged: (value) {
                      setState(() {
                        busqueda = value;
                        paginaActual = 1;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 16),
                if (proyectos.isEmpty)
                  Container(
                    margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
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
                          Icons.folder_outlined,
                          size: 42,
                          color: AppColors.textMuted,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'No hay proyectos registrados',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: AppColors.textDark,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Agregue el primer proyecto para comenzar a controlar montos, pagos, visitas, comentarios y recordatorios.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  )
                else if (proyectosFiltrados.isEmpty)
                  Container(
                    margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
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
                          'No se encontraron proyectos',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: AppColors.textDark,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Intente buscar con otro nombre, cliente, estado o monto.',
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
                      dataRowMinHeight: 64,
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
                        DataColumn(label: Text('Proyecto')),
                        DataColumn(label: Text('Cliente')),
                        DataColumn(label: Text('Monto total')),
                        DataColumn(label: Text('Pagado')),
                        DataColumn(label: Text('Pendiente')),
                        DataColumn(label: Text('Estado')),
                        DataColumn(label: Text('Acciones')),
                      ],
                      rows: proyectosPaginados.map((proyecto) {
                        final nombre =
                            proyecto['nombre']?.toString() ?? 'Sin nombre';

                        final cliente = obtenerNombreCliente(proyecto);
                        final estado =
                            proyecto['estado']?.toString() ?? 'PENDIENTE';

                        final montoTotal = obtenerMonto(proyecto['montoTotal']);
                        final pagado = calcularTotalPagado(proyecto);
                        final pendiente = montoTotal - pagado;

                        return DataRow(
                          cells: [
                            DataCell(
                              InkWell(
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ProjectDetailRealPage(
                                        proyecto: proyecto,
                                      ),
                                    ),
                                  );

                                  if (mounted) {
                                    await cargarDatos(silencioso: true);
                                  }
                                },
                                child: Row(
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
                                        Icons.folder_outlined,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 190,
                                      ),
                                      child: Text(
                                        nombre,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 160,
                                ),
                                child: Text(
                                  cliente,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(Text(formatearMonto(montoTotal))),
                            DataCell(Text(formatearMonto(pagado))),
                            DataCell(Text(formatearMonto(pendiente))),
                            DataCell(construirEstadoChip(estado)),
                            DataCell(
                              Row(
                                children: [
                                  IconButton(
                                    tooltip: 'Ver detalle',
                                    onPressed: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ProjectDetailRealPage(
                                            proyecto: proyecto,
                                          ),
                                        ),
                                      );

                                      if (mounted) {
                                        await cargarDatos(silencioso: true);
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.visibility_outlined,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Editar',
                                    onPressed: () => abrirFormularioProyecto(
                                      proyecto: proyecto,
                                    ),
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Eliminar',
                                    onPressed: () => eliminarProyecto(proyecto),
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                    child: AppPaginationControls(
                      currentPage: paginaActual,
                      totalItems: proyectosFiltrados.length,
                      pageSize: proyectosPorPagina,
                      onPageChanged: (page) {
                        setState(() {
                          paginaActual = page;
                        });
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const AppLoading(text: 'Cargando proyectos...');
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        padding: EdgeInsets.zero,
        child: RefreshIndicator(
          onRefresh: cargarDatos,
          child: construirTablaProyectos(),
        ),
      ),
    );
  }
}
