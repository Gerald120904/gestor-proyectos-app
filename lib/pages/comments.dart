import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/comentarios_service.dart';
import '../core/cache/app_cache.dart';
import '../ui/common.dart';
import '../core/ui/dialogs/app_feedback.dart';
import '../core/business/business_rules.dart';
import '../core/ui/widgets/app_search_input.dart';
import '../core/ui/widgets/app_pagination_controls.dart';
import '../core/ui/widgets/app_form_field.dart';
import '../core/ui/widgets/app_form_actions.dart';

class CommentsRealPage extends StatefulWidget {
  final int proyectoId;
  final String? proyectoNombre;

  const CommentsRealPage({
    super.key,
    required this.proyectoId,
    this.proyectoNombre,
  });

  @override
  State<CommentsRealPage> createState() => _CommentsRealPageState();
}

class _CommentsRealPageState extends State<CommentsRealPage> {
  final ComentariosService comentariosService = ComentariosService();

  List<Map<String, dynamic>> comentarios = [];
  bool loading = true;

  String busqueda = '';
  int paginaActual = 1;
  static const int comentariosPorPagina = 10;

  @override
  void initState() {
    super.initState();
    cargarComentarios();
  }

  List<Map<String, dynamic>> get comentariosFiltrados {
    final texto = busqueda.trim().toLowerCase();

    if (texto.isEmpty) {
      return comentarios;
    }

    return comentarios.where((comentario) {
      final titulo = comentario['titulo']?.toString().toLowerCase() ?? '';
      final contenido = comentario['contenido']?.toString().toLowerCase() ?? '';
      final fecha = formatearFecha(comentario['fecha']).toLowerCase();

      return titulo.contains(texto) ||
          contenido.contains(texto) ||
          fecha.contains(texto);
    }).toList();
  }

  List<Map<String, dynamic>> get comentariosPaginados {
    if (comentariosFiltrados.isEmpty) {
      return [];
    }

    final inicio = (paginaActual - 1) * comentariosPorPagina;
    final fin = math.min(
      inicio + comentariosPorPagina,
      comentariosFiltrados.length,
    );

    if (inicio >= comentariosFiltrados.length) {
      return [];
    }

    return comentariosFiltrados.sublist(inicio, fin);
  }

  Future<void> cargarComentarios({bool silencioso = false}) async {
    final cache = AppCache.comentariosPorProyecto[widget.proyectoId];

    if (cache != null) {
      setState(() {
        comentarios = cache;
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
      final data = await comentariosService.getComentariosProyecto(
        widget.proyectoId,
      );

      if (!mounted) return;

      AppCache.guardarComentariosProyecto(
        proyectoId: widget.proyectoId,
        data: data,
      );

      setState(() {
        comentarios = data;
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

  String generarTitulo(String contenido) {
    final texto = contenido.trim();

    if (texto.length <= 35) {
      return texto;
    }

    return '${texto.substring(0, 35)}...';
  }

  DateTime obtenerFechaComentario(Map<String, dynamic>? comentario) {
    final fecha = parseFechaSoloLocal(comentario?['fecha']);

    return fecha ?? DateTime.now();
  }

  Future<void> abrirFormularioComentario({
    Map<String, dynamic>? comentario,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _ComentarioFormDialog(
          comentario: comentario,
          comentarios: comentarios,
          obtenerFechaComentario: obtenerFechaComentario,
          fechaInput: fechaInput,
          generarTitulo: generarTitulo,
          onGuardar: (titulo, contenido, fecha) async {
            if (comentario != null) {
              await comentariosService.actualizarComentario(
                id: int.parse(comentario['id'].toString()),
                titulo: titulo,
                contenido: contenido,
                fecha: fecha,
              );
            } else {
              await comentariosService.crearComentario(
                proyectoId: widget.proyectoId,
                titulo: titulo,
                contenido: contenido,
                fecha: fecha,
              );
            }
          },
          onExito: () {
            if (!mounted) return;
            AppCache.invalidarTodoDespuesDeCambioEnProyecto(widget.proyectoId);
            mostrarMensaje(
              comentario != null
                  ? 'Comentario actualizado correctamente.'
                  : 'Comentario agregado correctamente.',
            );
            cargarComentarios(silencioso: true);
          },
          onError: (msg) {
            if (!mounted) return;
            mostrarMensaje(msg);
          },
        );
      },
    );
  }

  Future<void> eliminarComentario(Map<String, dynamic> comentario) async {
    bool accionEjecutada = false;

    await AppFeedback.confirmAndRun(
      context: context,
      confirmTitle: 'Eliminar comentario',
      confirmMessage:
          '¿Está seguro de que desea eliminar este comentario? Esta acción no se puede deshacer.',
      confirmText: 'Sí, eliminar',
      danger: true,
      loadingMessage: 'Eliminando comentario...',
      successTitle: 'Comentario eliminado',
      successMessage: 'El comentario se eliminó correctamente.',
      action: () async {
        await comentariosService.eliminarComentario(
          int.parse(comentario['id'].toString()),
        );

        AppCache.invalidarTodoDespuesDeCambioEnProyecto(widget.proyectoId);
        accionEjecutada = true;
      },
    );

    if (accionEjecutada && mounted) {
      await cargarComentarios(silencioso: true);
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

  Widget construirTablaComentarios() {
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
                  widget.proyectoNombre ?? 'Proyecto',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Total de comentarios registrados: ${comentarios.length}',
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
                        Icons.comment_outlined,
                        color: AppColors.primary,
                        size: 30,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Comentarios registrados',
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
                    texto: 'Agregar comentario',
                    icono: Icons.add_comment_outlined,
                    onPressed: () => abrirFormularioComentario(),
                  ),
                ),

                const SizedBox(height: 16),

                if (comentarios.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.comment_outlined,
                          size: 58,
                          color: AppColors.textMuted,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No hay comentarios registrados',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textDark,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Agregue el primer comentario para documentar observaciones importantes del proyecto.',
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
                      hintText: 'Buscar por título, comentario o fecha...',
                      onChanged: (value) {
                        setState(() {
                          busqueda = value;
                          paginaActual = 1;
                        });
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (comentariosFiltrados.isEmpty)
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
                            'No se encontraron comentarios',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: AppColors.textDark,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Intente buscar con otro título, comentario o fecha.',
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
                          DataColumn(label: Text('Título')),
                          DataColumn(label: Text('Comentario')),
                          DataColumn(label: Text('Fecha')),
                          DataColumn(label: Text('Acciones')),
                        ],
                        rows: comentariosPaginados.map((comentario) {
                          final titulo =
                              comentario['titulo']?.toString() ??
                              generarTitulo(
                                comentario['contenido']?.toString() ?? '',
                              );

                          final contenido =
                              comentario['contenido']?.toString() ?? '';

                          return DataRow(
                            cells: [
                              DataCell(
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 180,
                                  ),
                                  child: Text(
                                    titulo,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 380,
                                  ),
                                  child: Text(
                                    contenido,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(formatearFecha(comentario['fecha'])),
                              ),
                              DataCell(
                                Row(
                                  children: [
                                    IconButton(
                                      tooltip: 'Editar',
                                      onPressed: () {
                                        abrirFormularioComentario(
                                          comentario: comentario,
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
                                        eliminarComentario(comentario);
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
                        totalItems: comentariosFiltrados.length,
                        pageSize: comentariosPorPagina,
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
      return const Scaffold(body: AppLoading(text: 'Cargando comentarios...'));
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Comentarios del proyecto')),
      body: AppBackground(
        padding: EdgeInsets.zero,
        child: RefreshIndicator(
          onRefresh: cargarComentarios,
          child: construirTablaComentarios(),
        ),
      ),
    );
  }
}

// =====================================================
// DIÁLOGO DE COMENTARIO (StatefulWidget propio)
// =====================================================

class _ComentarioFormDialog extends StatefulWidget {
  final Map<String, dynamic>? comentario;
  final List<Map<String, dynamic>> comentarios;
  final DateTime Function(Map<String, dynamic>?) obtenerFechaComentario;
  final String Function(DateTime) fechaInput;
  final String Function(String) generarTitulo;
  final Future<void> Function(String, String, String) onGuardar;
  final void Function() onExito;
  final void Function(String) onError;

  const _ComentarioFormDialog({
    required this.comentario,
    required this.comentarios,
    required this.obtenerFechaComentario,
    required this.fechaInput,
    required this.generarTitulo,
    required this.onGuardar,
    required this.onExito,
    required this.onError,
  });

  @override
  State<_ComentarioFormDialog> createState() => _ComentarioFormDialogState();
}

class _ComentarioFormDialogState extends State<_ComentarioFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _contenidoController;
  bool _guardando = false;

  bool get esEdicion => widget.comentario != null;

  @override
  void initState() {
    super.initState();
    _contenidoController = TextEditingController(
      text: widget.comentario?['contenido']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _contenidoController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final contenido = _contenidoController.text.trim();
    final titulo = widget.generarTitulo(contenido);
    final fechaComentario = widget.obtenerFechaComentario(widget.comentario);
    final fecha = esEdicion
        ? widget.fechaInput(fechaComentario)
        : widget.fechaInput(DateTime.now());

    final resultadoUnico = BusinessRules.validarComentarioUnico(
      comentarios: widget.comentarios,
      idActual: widget.comentario == null
          ? null
          : widget.comentario!['id']?.toString(),
      contenido: contenido,
    );
    if (!resultadoUnico.isValid) {
      widget.onError(resultadoUnico.message!);
      return;
    }

    setState(() => _guardando = true);

    try {
      await widget.onGuardar(titulo, contenido, fecha);

      if (!mounted) return;
      FocusManager.instance.primaryFocus?.unfocus();
      Navigator.of(context).pop();
      widget.onExito();
    } catch (error) {
      if (!mounted) return;
      setState(() => _guardando = false);
      widget.onError(error.toString().replaceAll('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_guardando,
      child: AppFormDialog(
        title: esEdicion ? 'Editar comentario' : 'Agregar comentario',
        subtitle:
            'Registre una observación clara relacionada con el avance o detalle del proyecto.',
        icon: esEdicion ? Icons.edit_note_outlined : Icons.add_comment_outlined,
        desktopWidth: 760,
        desktopHeight: 420,
        child: Form(
          key: _formKey,
          child: AppFormField(
            controller: _contenidoController,
            enabled: !_guardando,
            label: 'Contenido del comentario',
            hint:
                'Escriba una observación clara sobre el avance, detalle o situación del proyecto',
            icon: Icons.notes_outlined,
            requiredField: true,
            maxLines: 7,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            validator: (value) {
              final resultado = BusinessRules.validarComentario(
                contenido: value ?? '',
              );
              return resultado.isValid ? null : resultado.message;
            },
          ),
        ),
        actions: [
          AppFormActions(
            loading: _guardando,
            primaryText: esEdicion ? 'Actualizar' : 'Guardar',
            primaryIcon: Icons.save_outlined,
            onCancel: () {
              if (_guardando) return;
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.of(context).pop();
            },
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }
}
