import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/recordatorios_service.dart';
import '../services/proyectos_service.dart';
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
// RECORDATORIOS REALES
// =====================================================

class RemindersRealPage extends StatefulWidget {
  final int? proyectoId;
  final String? proyectoNombre;
  final int refreshToken;

  const RemindersRealPage({
    super.key,
    this.proyectoId,
    this.proyectoNombre,
    this.refreshToken = 0,
  });

  @override
  State<RemindersRealPage> createState() => _RemindersRealPageState();
}

class _RemindersRealPageState extends State<RemindersRealPage> {
  final RecordatoriosService recordatoriosService = RecordatoriosService();
  final ProyectosService proyectosService = ProyectosService();

  List<Map<String, dynamic>> recordatorios = [];
  List<Map<String, dynamic>> proyectos = [];

  List<Map<String, dynamic>> get proyectosDisponibles =>
      AppCache.proyectos ?? proyectos;

  bool loading = true;

  String busqueda = '';
  int paginaActual = 1;
  static const int recordatoriosPorPagina = 10;

  final Map<String, String> prioridades = const {
    'ALTA': 'Alta',
    'MEDIA': 'Media',
    'BAJA': 'Baja',
  };

  bool get esModoProyecto => widget.proyectoId != null;

  @override
  void initState() {
    super.initState();
    cargarDatos();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant RemindersRealPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.refreshToken != oldWidget.refreshToken) {
      cargarDatos(silencioso: true);
    }
  }

  List<Map<String, dynamic>> get recordatoriosFiltrados {
    final texto = busqueda.trim().toLowerCase();

    if (texto.isEmpty) {
      return recordatorios;
    }

    return recordatorios.where((recordatorio) {
      final titulo = recordatorio['titulo']?.toString().toLowerCase() ?? '';
      final descripcion =
          recordatorio['descripcion']?.toString().toLowerCase() ?? '';
      final proyecto = obtenerNombreProyecto(recordatorio).toLowerCase();
      final fecha = formatearFecha(recordatorio['fecha']).toLowerCase();
      final hora = formatearHora(recordatorio['hora']).toLowerCase();
      final prioridad =
          recordatorio['prioridad']?.toString().toLowerCase() ?? '';
      final prioridadTexto =
          prioridades[recordatorio['prioridad']]?.toLowerCase() ?? '';
      final completado = recordatorio['completado'] == true
          ? 'completado'
          : 'pendiente';

      return titulo.contains(texto) ||
          descripcion.contains(texto) ||
          proyecto.contains(texto) ||
          fecha.contains(texto) ||
          hora.contains(texto) ||
          prioridad.contains(texto) ||
          prioridadTexto.contains(texto) ||
          completado.contains(texto);
    }).toList();
  }

  List<Map<String, dynamic>> get recordatoriosPaginados {
    if (recordatoriosFiltrados.isEmpty) {
      return [];
    }

    final inicio = (paginaActual - 1) * recordatoriosPorPagina;
    final fin = math.min(
      inicio + recordatoriosPorPagina,
      recordatoriosFiltrados.length,
    );

    if (inicio >= recordatoriosFiltrados.length) {
      return [];
    }

    return recordatoriosFiltrados.sublist(inicio, fin);
  }

  Future<void> cargarDatos({bool silencioso = false}) async {
    if (esModoProyecto) {
      final cacheProyecto =
          AppCache.recordatoriosPorProyecto[widget.proyectoId!];

      if (cacheProyecto != null || AppCache.proyectos != null) {
        setState(() {
          recordatorios = cacheProyecto ?? recordatorios;
          proyectos = AppCache.proyectos ?? proyectos;
          loading = false;
        });

        silencioso = true;
      }
    } else {
      if (AppCache.recordatorios != null || AppCache.proyectos != null) {
        setState(() {
          recordatorios = AppCache.recordatorios ?? recordatorios;
          proyectos = AppCache.proyectos ?? proyectos;
          loading = false;
        });

        silencioso = true;
      }
    }

    if (!silencioso && mounted) {
      setState(() {
        loading = true;
      });
    }

    try {
      final recordatoriosFuture = esModoProyecto
          ? recordatoriosService.getRecordatoriosProyecto(widget.proyectoId!)
          : recordatoriosService.getRecordatorios();
      final proyectosFuture = proyectosService.getProyectos();

      final results = await Future.wait([recordatoriosFuture, proyectosFuture]);
      final recordatoriosData = results[0] as List<Map<String, dynamic>>;
      final proyectosData = results[1] as List<Map<String, dynamic>>;

      if (!mounted) return;

      if (esModoProyecto) {
        AppCache.guardarRecordatoriosProyecto(
          proyectoId: widget.proyectoId!,
          data: recordatoriosData,
        );
      } else {
        AppCache.guardarRecordatorios(recordatoriosData);
      }

      AppCache.guardarProyectos(proyectosData);

      setState(() {
        recordatorios = recordatoriosData;
        proyectos = proyectosData;
        loading = false;
        paginaActual = 1;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      final hayCache = esModoProyecto
          ? AppCache.recordatoriosPorProyecto.containsKey(widget.proyectoId!)
          : AppCache.recordatorios != null;

      if (!hayCache) {
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

  DateTime obtenerFechaRecordatorio(Map<String, dynamic>? recordatorio) {
    final fecha = parseFechaSoloLocal(recordatorio?['fecha']);

    return fecha ?? DateTime.now();
  }

  TimeOfDay obtenerHoraRecordatorio(Map<String, dynamic>? recordatorio) {
    if (recordatorio == null || recordatorio['hora'] == null) {
      return const TimeOfDay(hour: 8, minute: 0);
    }

    final partes = recordatorio['hora'].toString().split(':');

    if (partes.length < 2) {
      return const TimeOfDay(hour: 8, minute: 0);
    }

    final hora = int.tryParse(partes[0]) ?? 8;
    final minuto = int.tryParse(partes[1]) ?? 0;

    return TimeOfDay(hour: hora, minute: minuto);
  }

  int obtenerProyectoSeleccionado(Map<String, dynamic>? recordatorio) {
    if (esModoProyecto) {
      return widget.proyectoId!;
    }

    if (proyectosDisponibles.isEmpty) {
      return 0;
    }

    final proyectoIdDirecto = recordatorio?['proyectoId'];

    if (proyectoIdDirecto != null) {
      final existe = proyectosDisponibles.any((proyecto) {
        return proyecto['id']?.toString() == proyectoIdDirecto.toString();
      });

      if (existe) {
        return int.parse(proyectoIdDirecto.toString());
      }
    }

    final proyecto = recordatorio?['proyecto'];

    if (proyecto is Map && proyecto['id'] != null) {
      final id = int.parse(proyecto['id'].toString());

      final existe = proyectosDisponibles.any((item) {
        return item['id']?.toString() == id.toString();
      });

      if (existe) return id;
    }

    return int.parse(proyectosDisponibles.first['id'].toString());
  }

  String obtenerNombreProyecto(Map<String, dynamic> recordatorio) {
    if (esModoProyecto) {
      return widget.proyectoNombre ?? 'Proyecto';
    }

    final proyecto = recordatorio['proyecto'];

    if (proyecto is Map && proyecto['nombre'] != null) {
      return proyecto['nombre'].toString();
    }

    final proyectoId = recordatorio['proyectoId'];

    final encontrados = proyectosDisponibles.where((item) {
      return item['id']?.toString() == proyectoId?.toString();
    }).toList();

    if (encontrados.isNotEmpty) {
      return encontrados.first['nombre']?.toString() ?? 'Sin proyecto';
    }

    return 'Sin proyecto';
  }

  Map<String, dynamic>? obtenerProyectoPorId(int proyectoId) {
    for (final proyecto in proyectosDisponibles) {
      if (proyecto['id']?.toString() == proyectoId.toString()) {
        return proyecto;
      }
    }

    return null;
  }

  Color colorPrioridad(String prioridad) {
    switch (prioridad) {
      case 'ALTA':
        return AppColors.danger;
      case 'MEDIA':
        return AppColors.warning;
      case 'BAJA':
        return AppColors.success;
      default:
        return AppColors.textMuted;
    }
  }

  Widget construirChip({
    required String texto,
    required Color color,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withAlpha(31),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            texto,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> abrirFormularioRecordatorio({
    Map<String, dynamic>? recordatorio,
  }) async {
    if (!esModoProyecto && proyectosDisponibles.isEmpty) {
      mostrarMensaje('Primero debe registrar al menos un proyecto.');
      return;
    }

    final formKey = GlobalKey<FormState>();

    final tituloController = TextEditingController(
      text: recordatorio?['titulo']?.toString() ?? '',
    );

    final descripcionController = TextEditingController(
      text: recordatorio?['descripcion']?.toString() ?? '',
    );

    DateTime fechaSeleccionada = obtenerFechaRecordatorio(recordatorio);
    TimeOfDay horaSeleccionada = obtenerHoraRecordatorio(recordatorio);

    String prioridadSeleccionada =
        recordatorio?['prioridad']?.toString() ?? 'MEDIA';

    if (!prioridades.containsKey(prioridadSeleccionada)) {
      prioridadSeleccionada = 'MEDIA';
    }

    bool completadoSeleccionado = recordatorio?['completado'] == true;

    int proyectoSeleccionado = obtenerProyectoSeleccionado(recordatorio);

    final esEdicion = recordatorio != null;

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
                title: esEdicion
                    ? 'Editar recordatorio'
                    : 'Agregar recordatorio',
                subtitle:
                    'Complete los datos del recordatorio de forma clara y ordenada.',
                icon: esEdicion
                    ? Icons.edit_notifications_outlined
                    : Icons.add_alert_outlined,
                desktopWidth: 900,
                desktopHeight: 590,
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FormalFormGrid(
                        children: [
                          if (!esModoProyecto && !esEdicion)
                            AppSelectField<int>(
                              label: 'Proyecto asociado',
                              value: proyectoSeleccionado,
                              icon: Icons.folder_outlined,
                              requiredField: true,
                              items: proyectosDisponibles.map((proyecto) {
                                final id = int.parse(proyecto['id'].toString());

                                final nombre =
                                    proyecto['nombre']?.toString() ??
                                    'Sin nombre';

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
                                        proyectoSeleccionado = value;
                                      });
                                    },
                              validator: (value) {
                                if (value == null || value <= 0) {
                                  return 'Debe seleccionar un proyecto.';
                                }

                                return null;
                              },
                            ),
                          AppFormField(
                            controller: tituloController,
                            enabled: !guardando,
                            label: 'Título del recordatorio',
                            hint: 'Ejemplo: Revisar avance del proyecto',
                            icon: Icons.notifications_outlined,
                            requiredField: true,
                            maxLength: 100,
                            textCapitalization: TextCapitalization.sentences,
                            validator: (value) {
                              final text = value?.trim() ?? '';

                              if (text.isEmpty) {
                                return 'El título es obligatorio.';
                              }

                              if (text.length < 3 || text.length > 100) {
                                return 'Debe tener entre 3 y 100 caracteres.';
                              }

                              return null;
                            },
                          ),
                          AppPickerField(
                            label: 'Fecha del recordatorio',
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
                            label: 'Hora del recordatorio',
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
                            label: 'Prioridad',
                            value: prioridadSeleccionada,
                            icon: Icons.priority_high_outlined,
                            requiredField: true,
                            items: prioridades.entries.map((entry) {
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
                                      prioridadSeleccionada = value;
                                    });
                                  },
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      AppFormField(
                        controller: descripcionController,
                        enabled: !guardando,
                        label: 'Descripción',
                        hint:
                            'Describa el pendiente, tarea o situación que se debe recordar',
                        icon: Icons.notes_outlined,
                        requiredField: true,
                        maxLines: 4,
                        maxLength: 500,
                        textCapitalization: TextCapitalization.sentences,
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
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSoft,
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: CheckboxListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 2,
                          ),
                          value: completadoSeleccionado,
                          title: const Text(
                            'Marcar como completado',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                          subtitle: const Text(
                            'Active esta opción solo si la tarea ya fue realizada.',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: guardando
                              ? null
                              : (value) {
                                  setDialogState(() {
                                    completadoSeleccionado = value ?? false;
                                  });
                                },
                        ),
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

                      final titulo = tituloController.text.trim();
                      final descripcion = descripcionController.text.trim();

                      final fechaHora = BusinessRules.combinarFechaHora(
                        fecha: fechaSeleccionada,
                        hora: horaSeleccionada.hour,
                        minuto: horaSeleccionada.minute,
                      );

                      final resultadoFecha = BusinessRules.validarRecordatorio(
                        fechaHora: fechaHora,
                        completado: completadoSeleccionado,
                      );

                      if (!resultadoFecha.isValid) {
                        mostrarMensaje(resultadoFecha.message!);
                        return;
                      }

                      final proyectoActual = obtenerProyectoPorId(
                        proyectoSeleccionado,
                      );

                      final resultadoProyecto =
                          BusinessRules.validarProyectoDisponibleParaRecordatorio(
                            estadoProyecto:
                                proyectoActual?['estado']?.toString() ?? '',
                          );

                      if (!resultadoProyecto.isValid) {
                        mostrarMensaje(resultadoProyecto.message!);
                        return;
                      }

                      setDialogState(() {
                        guardando = true;
                      });

                      try {
                        if (esEdicion) {
                          await recordatoriosService.actualizarRecordatorio(
                            id: int.parse(recordatorio['id'].toString()),
                            titulo: titulo,
                            descripcion: descripcion,
                            fecha: fechaInput(fechaSeleccionada),
                            hora: horaInput(horaSeleccionada),
                            prioridad: prioridadSeleccionada,
                            completado: completadoSeleccionado,
                          );
                        } else {
                          await recordatoriosService.crearRecordatorio(
                            proyectoId: proyectoSeleccionado,
                            titulo: titulo,
                            descripcion: descripcion,
                            fecha: fechaInput(fechaSeleccionada),
                            hora: horaInput(horaSeleccionada),
                            prioridad: prioridadSeleccionada,
                            completado: completadoSeleccionado,
                          );
                        }

                        if (!mounted) return;

                        if (dialogContext.mounted) {
                          FocusManager.instance.primaryFocus?.unfocus();
                          Navigator.of(dialogContext).pop();
                        }

                        if (esModoProyecto) {
                          AppCache.invalidarTodoDespuesDeCambioEnProyecto(
                            widget.proyectoId!,
                          );
                        } else {
                          AppCache.recordatorios = null;
                          AppCache.invalidarResumenes();
                        }

                        mostrarMensaje(
                          esEdicion
                              ? 'Recordatorio actualizado correctamente.'
                              : 'Recordatorio agregado correctamente.',
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

    tituloController.dispose();
    descripcionController.dispose();
  }

  Future<void> alternarCompletado(Map<String, dynamic> recordatorio) async {
    final completado = recordatorio['completado'] == true;
    bool accionEjecutada = false;

    await AppFeedback.confirmAndRun(
      context: context,
      confirmTitle: completado
          ? 'Marcar como pendiente'
          : 'Marcar como completado',
      confirmMessage: completado
          ? '¿Está seguro de que desea marcar este recordatorio como pendiente?'
          : '¿Está seguro de que desea marcar este recordatorio como completado?',
      confirmText: 'Sí, actualizar',
      loadingMessage: 'Actualizando recordatorio...',
      successTitle: 'Recordatorio actualizado',
      successMessage: 'El estado del recordatorio se actualizó correctamente.',
      action: () async {
        await recordatoriosService.alternarCompletado(
          int.parse(recordatorio['id'].toString()),
        );

        if (esModoProyecto) {
          AppCache.invalidarTodoDespuesDeCambioEnProyecto(widget.proyectoId!);
        } else {
          AppCache.recordatorios = null;
          AppCache.invalidarResumenes();
        }

        accionEjecutada = true;
      },
    );

    if (accionEjecutada && mounted) {
      await cargarDatos(silencioso: true);
    }
  }

  Future<void> eliminarRecordatorio(Map<String, dynamic> recordatorio) async {
    bool accionEjecutada = false;

    await AppFeedback.confirmAndRun(
      context: context,
      confirmTitle: 'Eliminar recordatorio',
      confirmMessage:
          '¿Está seguro de que desea eliminar este recordatorio? Esta acción no se puede deshacer.',
      confirmText: 'Sí, eliminar',
      danger: true,
      loadingMessage: 'Eliminando recordatorio...',
      successTitle: 'Recordatorio eliminado',
      successMessage: 'El recordatorio se eliminó correctamente.',
      action: () async {
        await recordatoriosService.eliminarRecordatorio(
          int.parse(recordatorio['id'].toString()),
        );

        if (esModoProyecto) {
          AppCache.invalidarTodoDespuesDeCambioEnProyecto(widget.proyectoId!);
        } else {
          AppCache.recordatorios = null;
          AppCache.invalidarResumenes();
        }

        accionEjecutada = true;
      },
    );

    if (accionEjecutada && mounted) {
      await cargarDatos(silencioso: true);
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

  Widget construirTablaRecordatorios() {
    final pendientes = recordatorios.where((item) {
      return item['completado'] != true;
    }).length;

    return PageContainer(
      maxWidth: 1200,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppGlassCard(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  esModoProyecto
                      ? widget.proyectoNombre ?? 'Proyecto'
                      : 'Control de recordatorios',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pendientes: $pendientes • Total registrados: ${recordatorios.length}',
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
                        Icons.notifications_outlined,
                        color: AppColors.primary,
                        size: 30,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Recordatorios registrados',
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
                    texto: 'Agregar recordatorio',
                    icono: Icons.add_alert_outlined,
                    onPressed: () => abrirFormularioRecordatorio(),
                  ),
                ),
                const SizedBox(height: 16),
                if (recordatorios.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.notifications_outlined,
                          size: 58,
                          color: AppColors.textMuted,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No hay recordatorios registrados',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textDark,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Agregue el primer recordatorio para dar seguimiento a tareas, fechas o pendientes del proyecto.',
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
                          'Buscar por título, proyecto, fecha, prioridad, estado o descripción...',
                      onChanged: (value) {
                        setState(() {
                          busqueda = value;
                          paginaActual = 1;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (recordatoriosFiltrados.isEmpty)
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
                            'No se encontraron recordatorios',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: AppColors.textDark,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Intente buscar con otro título, proyecto, fecha, prioridad o estado.',
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
                        dataRowMaxHeight: 86,
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
                          DataColumn(label: Text('Listo')),
                          DataColumn(label: Text('Título')),
                          DataColumn(label: Text('Proyecto')),
                          DataColumn(label: Text('Fecha')),
                          DataColumn(label: Text('Hora')),
                          DataColumn(label: Text('Prioridad')),
                          DataColumn(label: Text('Estado')),
                          DataColumn(label: Text('Descripción')),
                          DataColumn(label: Text('Acciones')),
                        ],
                        rows: recordatoriosPaginados.map((recordatorio) {
                          final titulo =
                              recordatorio['titulo']?.toString() ??
                              'Sin título';

                          final descripcion =
                              recordatorio['descripcion']?.toString() ?? '';

                          final prioridad =
                              recordatorio['prioridad']?.toString() ?? 'MEDIA';

                          final prioridadTexto =
                              prioridades[prioridad] ?? prioridad;

                          final completado = recordatorio['completado'] == true;

                          return DataRow(
                            cells: [
                              DataCell(
                                Checkbox(
                                  value: completado,
                                  onChanged: (_) {
                                    alternarCompletado(recordatorio);
                                  },
                                ),
                              ),
                              DataCell(
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 180,
                                  ),
                                  child: Text(
                                    titulo,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      decoration: completado
                                          ? TextDecoration.lineThrough
                                          : TextDecoration.none,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 170,
                                  ),
                                  child: Text(
                                    obtenerNombreProyecto(recordatorio),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(formatearFecha(recordatorio['fecha'])),
                              ),
                              DataCell(
                                Text(formatearHora(recordatorio['hora'])),
                              ),
                              DataCell(
                                construirChip(
                                  texto: prioridadTexto,
                                  color: colorPrioridad(prioridad),
                                  icon: Icons.priority_high_outlined,
                                ),
                              ),
                              DataCell(
                                construirChip(
                                  texto: completado
                                      ? 'Completado'
                                      : 'Pendiente',
                                  color: completado
                                      ? AppColors.success
                                      : AppColors.warning,
                                  icon: completado
                                      ? Icons.check_circle_outline
                                      : Icons.pending_actions,
                                ),
                              ),
                              DataCell(
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 300,
                                  ),
                                  child: Text(
                                    descripcion,
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
                                        abrirFormularioRecordatorio(
                                          recordatorio: recordatorio,
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Eliminar',
                                      onPressed: () {
                                        eliminarRecordatorio(recordatorio);
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
                        totalItems: recordatoriosFiltrados.length,
                        pageSize: recordatoriosPorPagina,
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
      return const Scaffold(
        body: AppLoading(text: 'Cargando recordatorios...'),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: esModoProyecto
          ? AppBar(title: const Text('Recordatorios del proyecto'))
          : null,
      body: AppBackground(
        padding: EdgeInsets.zero,
        child: RefreshIndicator(
          onRefresh: cargarDatos,
          child: construirTablaRecordatorios(),
        ),
      ),
    );
  }
}
