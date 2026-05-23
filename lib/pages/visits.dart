import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/visitas_service.dart';
import '../core/cache/app_cache.dart';
import '../ui/common.dart';
import '../core/ui/dialogs/app_feedback.dart';
import '../core/business/business_rules.dart';
import '../core/ui/widgets/app_search_input.dart';
import '../core/ui/widgets/app_pagination_controls.dart';
import '../core/ui/widgets/formal_form_grid.dart';
import '../core/ui/widgets/app_form_field.dart';
import '../core/ui/widgets/app_select_field.dart';
import '../core/ui/widgets/app_picker_field.dart';
import '../core/ui/widgets/app_form_actions.dart';

// =====================================================
// VISITAS REALES DESDE MYSQL
// =====================================================

class VisitsRealPage extends StatefulWidget {
  final int proyectoId;
  final String proyectoNombre;

  const VisitsRealPage({
    super.key,
    required this.proyectoId,
    required this.proyectoNombre,
  });

  @override
  State<VisitsRealPage> createState() => _VisitsRealPageState();
}

class _VisitsRealPageState extends State<VisitsRealPage> {
  final VisitasService visitasService = VisitasService();

  List<Map<String, dynamic>> visitas = [];
  bool loading = true;

  String busqueda = '';
  int paginaActual = 1;
  static const int visitasPorPagina = 10;

  final Map<String, String> estadosVisita = const {
    'PROGRAMADA': 'Programada',
    'REALIZADA': 'Realizada',
    'CANCELADA': 'Cancelada',
  };

  @override
  void initState() {
    super.initState();
    cargarVisitas();
  }

  List<Map<String, dynamic>> get visitasFiltradas {
    final texto = busqueda.trim().toLowerCase();

    if (texto.isEmpty) {
      return visitas;
    }

    return visitas.where((visita) {
      final fecha = formatearFecha(visita['fecha']).toLowerCase();
      final hora = formatearHora(visita['hora']).toLowerCase();
      final estado = visita['estado']?.toString().toLowerCase() ?? '';
      final estadoTexto = estadosVisita[visita['estado']]?.toLowerCase() ?? '';
      final direccion = visita['direccion']?.toString().toLowerCase() ?? '';
      final observacion = visita['observacion']?.toString().toLowerCase() ?? '';

      return fecha.contains(texto) ||
          hora.contains(texto) ||
          estado.contains(texto) ||
          estadoTexto.contains(texto) ||
          direccion.contains(texto) ||
          observacion.contains(texto);
    }).toList();
  }

  List<Map<String, dynamic>> get visitasPaginadas {
    if (visitasFiltradas.isEmpty) {
      return [];
    }

    final inicio = (paginaActual - 1) * visitasPorPagina;
    final fin = math.min(inicio + visitasPorPagina, visitasFiltradas.length);

    if (inicio >= visitasFiltradas.length) {
      return [];
    }

    return visitasFiltradas.sublist(inicio, fin);
  }

  Future<void> cargarVisitas({bool silencioso = false}) async {
    final cache = AppCache.visitasPorProyecto[widget.proyectoId];

    if (cache != null) {
      setState(() {
        visitas = cache;
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
      final data = await visitasService.getVisitasProyecto(widget.proyectoId);

      if (!mounted) return;

      AppCache.guardarVisitasProyecto(
        proyectoId: widget.proyectoId,
        data: data,
      );

      setState(() {
        visitas = data;
        loading = false;
        paginaActual = 1;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      if (cache == null) {
        mostrarMensaje(error.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  void mostrarMensaje(String mensaje) {
    if (!mounted) return;

    AppFeedback.message(context: context, message: mensaje);
  }

  String fechaInput(DateTime fecha) {
    final mes = fecha.month.toString().padLeft(2, '0');
    final dia = fecha.day.toString().padLeft(2, '0');

    return '${fecha.year}-$mes-$dia';
  }

  String horaInput(TimeOfDay hora) {
    final horas = hora.hour.toString().padLeft(2, '0');
    final minutos = hora.minute.toString().padLeft(2, '0');

    return '$horas:$minutos';
  }

  DateTime? parseFechaSoloLocal(dynamic value) {
    if (value == null) return null;

    final texto = value.toString();

    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(texto);

    if (match == null) return null;

    final year = int.tryParse(match.group(1) ?? '');
    final month = int.tryParse(match.group(2) ?? '');
    final day = int.tryParse(match.group(3) ?? '');

    if (year == null || month == null || day == null) {
      return null;
    }

    return DateTime(year, month, day);
  }

  String formatearFecha(dynamic value) {
    final fecha = parseFechaSoloLocal(value);

    if (fecha == null) return 'Sin fecha';

    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final anio = fecha.year.toString();

    return '$dia/$mes/$anio';
  }

  String formatearHora(dynamic value) {
    if (value == null) return 'Sin hora';

    final texto = value.toString();

    if (texto.length >= 5) {
      return texto.substring(0, 5);
    }

    return texto;
  }

  DateTime obtenerFechaVisita(Map<String, dynamic>? visita) {
    final fecha = parseFechaSoloLocal(visita?['fecha']);

    return fecha ?? DateTime.now();
  }

  TimeOfDay obtenerHoraVisita(Map<String, dynamic>? visita) {
    if (visita == null || visita['hora'] == null) {
      return const TimeOfDay(hour: 8, minute: 0);
    }

    final partes = visita['hora'].toString().split(':');

    if (partes.length < 2) {
      return const TimeOfDay(hour: 8, minute: 0);
    }

    final hora = int.tryParse(partes[0]) ?? 8;
    final minuto = int.tryParse(partes[1]) ?? 0;

    return TimeOfDay(hour: hora, minute: minuto);
  }

  Color colorEstado(String estado) {
    switch (estado) {
      case 'PROGRAMADA':
        return AppColors.warning;
      case 'REALIZADA':
        return AppColors.success;
      case 'CANCELADA':
        return AppColors.danger;
      default:
        return AppColors.textMuted;
    }
  }

  Widget construirChipEstado(String estado) {
    final color = colorEstado(estado);
    final texto = estadosVisita[estado] ?? estado;

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

  Future<void> abrirFormularioVisita({Map<String, dynamic>? visita}) async {
    final formKey = GlobalKey<FormState>();

    final direccionController = TextEditingController(
      text: visita?['direccion']?.toString() ?? '',
    );

    final observacionController = TextEditingController(
      text: visita?['observacion']?.toString() ?? '',
    );

    DateTime fechaSeleccionada = obtenerFechaVisita(visita);
    TimeOfDay horaSeleccionada = obtenerHoraVisita(visita);

    String estadoSeleccionado = visita?['estado']?.toString() ?? 'PROGRAMADA';

    if (!estadosVisita.containsKey(estadoSeleccionado)) {
      estadoSeleccionado = 'PROGRAMADA';
    }

    final esEdicion = visita != null;

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
                title: esEdicion ? 'Editar visita' : 'Programar visita',
                subtitle:
                    'Complete los datos de la visita asociada al proyecto de forma clara y ordenada.',
                icon: esEdicion ? Icons.edit_calendar_outlined : Icons.event,
                desktopWidth: 820,
                desktopHeight: 560,
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FormalFormGrid(
                        children: [
                          AppPickerField(
                            label: 'Fecha de la visita',
                            value: formatearFecha(fechaSeleccionada),
                            icon: Icons.calendar_month_outlined,
                            trailingIcon: Icons.edit_calendar_outlined,
                            requiredField: true,
                            onTap: guardando
                                ? null
                                : () async {
                                    final fecha = await showDatePicker(
                                      context: dialogContext,
                                      initialDate: fechaSeleccionada,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2035),
                                    );

                                    if (fecha != null) {
                                      setDialogState(() {
                                        fechaSeleccionada = fecha;
                                      });
                                    }
                                  },
                          ),
                          AppPickerField(
                            label: 'Hora de la visita',
                            value: horaInput(horaSeleccionada),
                            icon: Icons.access_time,
                            trailingIcon: Icons.edit,
                            requiredField: true,
                            onTap: guardando
                                ? null
                                : () async {
                                    final hora = await showTimePicker(
                                      context: dialogContext,
                                      initialTime: horaSeleccionada,
                                    );

                                    if (hora != null) {
                                      setDialogState(() {
                                        horaSeleccionada = hora;
                                      });
                                    }
                                  },
                          ),
                          AppSelectField<String>(
                            label: 'Estado de la visita',
                            value: estadoSeleccionado,
                            icon: Icons.flag_outlined,
                            requiredField: true,
                            items: estadosVisita.entries.map((entry) {
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
                        controller: direccionController,
                        enabled: !guardando,
                        label: 'Dirección de la visita',
                        hint: 'Ejemplo: 200 metros norte de la escuela',
                        icon: Icons.location_on_outlined,
                        requiredField: true,
                        maxLines: 3,
                        maxLength: 180,
                        textCapitalization: TextCapitalization.sentences,
                        validator: (value) {
                          final txt = value?.trim() ?? '';

                          if (txt.isEmpty) {
                            return 'La dirección es obligatoria.';
                          }

                          if (txt.length < 5 || txt.length > 180) {
                            return 'Debe tener entre 5 y 180 caracteres.';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      AppFormField(
                        controller: observacionController,
                        enabled: !guardando,
                        label: 'Observación',
                        hint:
                            'Ejemplo: Se revisará el avance del trabajo realizado',
                        icon: Icons.notes_outlined,
                        requiredField: true,
                        maxLines: 4,
                        maxLength: 500,
                        textCapitalization: TextCapitalization.sentences,
                        validator: (value) {
                          final txt = value?.trim() ?? '';

                          if (txt.isEmpty) {
                            return 'La observación es obligatoria.';
                          }

                          if (txt.length < 3 || txt.length > 500) {
                            return 'Debe tener entre 3 y 500 caracteres.';
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
                    primaryIcon: Icons.save_outlined,
                    onCancel: () {
                      if (guardando) return;

                      FocusManager.instance.primaryFocus?.unfocus();
                      Navigator.of(dialogContext).pop();
                    },
                    onSubmit: () async {
                      if (!formKey.currentState!.validate()) {
                        return;
                      }

                      final direccion = direccionController.text.trim();
                      final observacion = observacionController.text.trim();

                      final fechaHora = BusinessRules.combinarFechaHora(
                        fecha: fechaSeleccionada,
                        hora: horaSeleccionada.hour,
                        minuto: horaSeleccionada.minute,
                      );

                      final resultadoVisita = BusinessRules.validarVisita(
                        fechaHora: fechaHora,
                        estado: estadoSeleccionado,
                      );

                      if (!resultadoVisita.isValid) {
                        mostrarMensaje(resultadoVisita.message!);
                        return;
                      }

                      setDialogState(() {
                        guardando = true;
                      });

                      try {
                        if (esEdicion) {
                          await visitasService.actualizarVisita(
                            id: int.parse(visita['id'].toString()),
                            fecha: fechaInput(fechaSeleccionada),
                            hora: horaInput(horaSeleccionada),
                            direccion: direccion,
                            estado: estadoSeleccionado,
                            observacion: observacion,
                          );
                        } else {
                          await visitasService.crearVisita(
                            proyectoId: widget.proyectoId,
                            fecha: fechaInput(fechaSeleccionada),
                            hora: horaInput(horaSeleccionada),
                            direccion: direccion,
                            estado: estadoSeleccionado,
                            observacion: observacion,
                          );
                        }

                        if (!mounted) return;

                        if (dialogContext.mounted) {
                          FocusManager.instance.primaryFocus?.unfocus();
                          Navigator.of(dialogContext).pop();
                        }

                        AppCache.invalidarTodoDespuesDeCambioEnProyecto(
                          widget.proyectoId,
                        );

                        mostrarMensaje(
                          esEdicion
                              ? 'Visita actualizada correctamente.'
                              : 'Visita programada correctamente.',
                        );

                        await cargarVisitas(silencioso: true);
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

    direccionController.dispose();
    observacionController.dispose();
  }

  Future<void> eliminarVisita(Map<String, dynamic> visita) async {
    bool accionEjecutada = false;

    await AppFeedback.confirmAndRun(
      context: context,
      confirmTitle: 'Eliminar visita',
      confirmMessage:
          '¿Está seguro de que desea eliminar esta visita? Esta acción no se puede deshacer.',
      confirmText: 'Sí, eliminar',
      danger: true,
      loadingMessage: 'Eliminando visita...',
      successTitle: 'Visita eliminada',
      successMessage: 'La visita se eliminó correctamente.',
      action: () async {
        await visitasService.eliminarVisita(int.parse(visita['id'].toString()));

        AppCache.invalidarTodoDespuesDeCambioEnProyecto(widget.proyectoId);
        accionEjecutada = true;
      },
    );

    if (accionEjecutada && mounted) {
      await cargarVisitas(silencioso: true);
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

  Widget construirContenidoVisitas() {
    return PageContainer(
      maxWidth: 1100,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppGlassCard(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.proyectoNombre,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Total de visitas registradas: ${visitas.length}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
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
                        Icons.event_outlined,
                        color: AppColors.primary,
                        size: 30,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Listado de visitas',
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
                    texto: 'Agregar visita',
                    icono: Icons.add,
                    onPressed: () => abrirFormularioVisita(),
                  ),
                ),
                const SizedBox(height: 16),
                if (visitas.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.event_outlined,
                          size: 58,
                          color: AppColors.textMuted,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No hay visitas registradas',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textDark,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Agregue una visita para llevar el seguimiento del proyecto.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                    child: AppSearchInput(
                      hintText:
                          'Buscar por fecha, hora, estado, dirección u observación...',
                      onChanged: (value) {
                        setState(() {
                          busqueda = value;
                          paginaActual = 1;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (visitasFiltradas.isEmpty)
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
                            'No se encontraron visitas',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: AppColors.textDark,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Intente buscar con otra fecha, estado, dirección u observación.',
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
                          DataColumn(label: Text('Fecha')),
                          DataColumn(label: Text('Hora')),
                          DataColumn(label: Text('Estado')),
                          DataColumn(label: Text('Dirección')),
                          DataColumn(label: Text('Observación')),
                          DataColumn(label: Text('Acciones')),
                        ],
                        rows: visitasPaginadas.map((visita) {
                          final estado =
                              visita['estado']?.toString() ?? 'PROGRAMADA';

                          return DataRow(
                            cells: [
                              DataCell(Text(formatearFecha(visita['fecha']))),
                              DataCell(Text(formatearHora(visita['hora']))),
                              DataCell(construirChipEstado(estado)),
                              DataCell(
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 240,
                                  ),
                                  child: Text(
                                    visita['direccion']?.toString() ?? '',
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
                                    visita['observacion']?.toString() ?? '',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(
                                Row(
                                  children: [
                                    IconButton(
                                      tooltip: 'Editar',
                                      onPressed: () {
                                        abrirFormularioVisita(visita: visita);
                                      },
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Eliminar',
                                      onPressed: () {
                                        eliminarVisita(visita);
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
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                      child: AppPaginationControls(
                        currentPage: paginaActual,
                        totalItems: visitasFiltradas.length,
                        pageSize: visitasPorPagina,
                        onPageChanged: (page) {
                          setState(() {
                            paginaActual = page;
                          });
                        },
                      ),
                    ),
                  ],
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
      return const Scaffold(body: AppLoading(text: 'Cargando visitas...'));
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Visitas del proyecto')),
      body: AppBackground(
        padding: EdgeInsets.zero,
        child: RefreshIndicator(
          onRefresh: cargarVisitas,
          child: construirContenidoVisitas(),
        ),
      ),
    );
  }
}
