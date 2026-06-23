import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/pagos_service.dart';
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
// PAGOS
// =====================================================

class PaymentsRealPage extends StatefulWidget {
  final int proyectoId;
  final String proyectoNombre;

  const PaymentsRealPage({
    super.key,
    required this.proyectoId,
    required this.proyectoNombre,
  });

  @override
  State<PaymentsRealPage> createState() => _PaymentsRealPageState();
}

class _PaymentsRealPageState extends State<PaymentsRealPage> {
  final PagosService pagosService = PagosService();

  Map<String, dynamic>? resumenProyecto;
  List<Map<String, dynamic>> pagos = [];
  bool loading = true;

  String busqueda = '';
  int paginaActual = 1;
  static const int pagosPorPagina = 10;

  final Map<String, String> metodosPago = const {
    'EFECTIVO': 'Efectivo',
    'TRANSFERENCIA': 'Transferencia',
    'SINPE_MOVIL': 'SINPE Móvil',
    'TARJETA': 'Tarjeta',
    'OTRO': 'Otro',
  };

  @override
  void initState() {
    super.initState();
    cargarPagos();
  }

  List<Map<String, dynamic>> get pagosFiltrados {
    final texto = busqueda.trim().toLowerCase();

    if (texto.isEmpty) {
      return pagos;
    }

    return pagos.where((pago) {
      final monto = pago['monto']?.toString().toLowerCase() ?? '';
      final metodo = pago['metodo']?.toString().toLowerCase() ?? '';
      final metodoTexto = metodosPago[pago['metodo']]?.toLowerCase() ?? '';
      final fecha = formatearFecha(pago['fecha']).toLowerCase();
      final observacion = pago['observacion']?.toString().toLowerCase() ?? '';

      return monto.contains(texto) ||
          metodo.contains(texto) ||
          metodoTexto.contains(texto) ||
          fecha.contains(texto) ||
          observacion.contains(texto);
    }).toList();
  }

  List<Map<String, dynamic>> get pagosPaginados {
    if (pagosFiltrados.isEmpty) {
      return [];
    }

    final inicio = (paginaActual - 1) * pagosPorPagina;
    final fin = math.min(inicio + pagosPorPagina, pagosFiltrados.length);

    if (inicio >= pagosFiltrados.length) {
      return [];
    }

    return pagosFiltrados.sublist(inicio, fin);
  }

  Future<void> cargarPagos({bool silencioso = false}) async {
    final cache = AppCache.pagosPorProyecto[widget.proyectoId];

    if (cache != null) {
      final proyectoCache = cache['proyecto'];
      final pagosCache = cache['pagos'];

      setState(() {
        resumenProyecto = proyectoCache is Map
            ? Map<String, dynamic>.from(proyectoCache)
            : resumenProyecto;

        pagos = pagosCache is List
            ? pagosCache.map((item) => Map<String, dynamic>.from(item)).toList()
            : pagos;

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
      final data = await pagosService.getPagosProyecto(widget.proyectoId);

      final proyecto = data['proyecto'];
      final pagosData = data['pagos'];

      if (!mounted) return;

      AppCache.guardarPagosProyecto(proyectoId: widget.proyectoId, data: data);

      setState(() {
        resumenProyecto = proyecto is Map
            ? Map<String, dynamic>.from(proyecto)
            : null;

        pagos = pagosData is List
            ? pagosData.map((item) => Map<String, dynamic>.from(item)).toList()
            : [];

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

  double obtenerMonto(dynamic value) {
    if (value == null) return 0;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0;
  }

  double obtenerMontoPendienteActual() {
    final pendienteResumen = resumenProyecto?['montoPendiente'];

    if (pendienteResumen != null) {
      return obtenerMonto(pendienteResumen);
    }

    final montoTotal = obtenerMonto(resumenProyecto?['montoTotal']);

    final totalPagado = pagos.fold<double>(0, (total, pago) {
      return total + obtenerMonto(pago['monto']);
    });

    return montoTotal - totalPagado;
  }

  String formatearMonto(dynamic value) {
    final monto = obtenerMonto(value);

    return '₡${monto.toStringAsFixed(0)}';
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

  String fechaInput(DateTime fecha) {
    final mes = fecha.month.toString().padLeft(2, '0');
    final dia = fecha.day.toString().padLeft(2, '0');

    return '${fecha.year}-$mes-$dia';
  }

  DateTime obtenerFechaPago(Map<String, dynamic>? pago) {
    final fecha = parseFechaSoloLocal(pago?['fecha']);

    return fecha ?? DateTime.now();
  }

  Widget construirMetodoChip(String metodo) {
    final texto = metodosPago[metodo] ?? metodo;

    Color color;

    switch (metodo) {
      case 'EFECTIVO':
        color = AppColors.success;
        break;
      case 'TRANSFERENCIA':
        color = AppColors.primary;
        break;
      case 'SINPE_MOVIL':
        color = AppColors.accent;
        break;
      case 'TARJETA':
        color = AppColors.warning;
        break;
      default:
        color = AppColors.textMuted;
    }

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

  Future<void> abrirFormularioPago({Map<String, dynamic>? pago}) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _PagoFormDialog(
          pago: pago,
          metodosPago: metodosPago,
          obtenerMontoPendienteActual: obtenerMontoPendienteActual,
          formatearFecha: formatearFecha,
          fechaInput: fechaInput,
          obtenerFechaPago: obtenerFechaPago,
          obtenerMonto: obtenerMonto,
          onGuardar: (monto, fecha, metodo, observacion) async {
            if (pago != null) {
              await pagosService.actualizarPago(
                id: int.parse(pago['id'].toString()),
                monto: monto,
                fecha: fecha,
                metodo: metodo,
                observacion: observacion,
              );
            } else {
              await pagosService.crearPago(
                proyectoId: widget.proyectoId,
                monto: monto,
                fecha: fecha,
                metodo: metodo,
                observacion: observacion,
              );
            }
          },
          onExito: () {
            if (!mounted) return;
            AppCache.invalidarTodoDespuesDeCambioEnProyecto(widget.proyectoId);
            mostrarMensaje(
              pago != null
                  ? 'Pago actualizado correctamente.'
                  : 'Pago registrado correctamente.',
            );
            cargarPagos(silencioso: true);
          },
          onError: (msg) {
            if (!mounted) return;
            mostrarMensaje(msg);
          },
        );
      },
    );
  }

  Future<void> eliminarPago(Map<String, dynamic> pago) async {
    bool accionEjecutada = false;

    await AppFeedback.confirmAndRun(
      context: context,
      confirmTitle: 'Eliminar pago',
      confirmMessage:
          '¿Está seguro de que desea eliminar el pago de ${formatearMonto(pago['monto'])}? Esta acción no se puede deshacer.',
      confirmText: 'Sí, eliminar',
      danger: true,
      loadingMessage: 'Eliminando pago...',
      successTitle: 'Pago eliminado',
      successMessage: 'El pago se eliminó correctamente.',
      action: () async {
        await pagosService.eliminarPago(int.parse(pago['id'].toString()));

        AppCache.invalidarTodoDespuesDeCambioEnProyecto(widget.proyectoId);
        accionEjecutada = true;
      },
    );

    if (accionEjecutada && mounted) {
      await cargarPagos(silencioso: true);
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

  Widget construirContenidoPagos({
    required String nombreProyecto,
    required dynamic montoTotal,
    required dynamic totalPagado,
    required dynamic montoPendiente,
  }) {
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
                  nombreProyecto,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 16),
                PaymentSummaryRealRow(
                  title: 'Monto total',
                  value: formatearMonto(montoTotal),
                  icon: Icons.account_balance_wallet_outlined,
                  color: AppColors.primary,
                ),
                PaymentSummaryRealRow(
                  title: 'Total pagado',
                  value: formatearMonto(totalPagado),
                  icon: Icons.check_circle_outline,
                  color: AppColors.success,
                ),
                PaymentSummaryRealRow(
                  title: 'Monto pendiente',
                  value: formatearMonto(montoPendiente),
                  icon: Icons.pending_actions,
                  color: AppColors.warning,
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
                        Icons.payments_outlined,
                        color: AppColors.primary,
                        size: 30,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Historial de pagos',
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
                    texto: 'Agregar pago',
                    icono: Icons.add,
                    onPressed: () => abrirFormularioPago(),
                  ),
                ),
                const SizedBox(height: 16),
                if (pagos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.payments_outlined,
                          size: 58,
                          color: AppColors.textMuted,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No hay pagos registrados',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textDark,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Agregue el primer pago para llevar el control financiero del proyecto.',
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
                          'Buscar por monto, método, fecha u observación...',
                      onChanged: (value) {
                        setState(() {
                          busqueda = value;
                          paginaActual = 1;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (pagosFiltrados.isEmpty)
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
                            'No se encontraron pagos',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: AppColors.textDark,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Intente buscar con otro monto, método, fecha u observación.',
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
                          DataColumn(label: Text('Monto')),
                          DataColumn(label: Text('Método')),
                          DataColumn(label: Text('Fecha')),
                          DataColumn(label: Text('Observación')),
                          DataColumn(label: Text('Acciones')),
                        ],
                        rows: pagosPaginados.map((pago) {
                          final metodo = pago['metodo']?.toString() ?? 'OTRO';

                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  formatearMonto(pago['monto']),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              DataCell(construirMetodoChip(metodo)),
                              DataCell(Text(formatearFecha(pago['fecha']))),
                              DataCell(
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 280,
                                  ),
                                  child: Text(
                                    pago['observacion']?.toString() ?? '',
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
                                        abrirFormularioPago(pago: pago);
                                      },
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Eliminar',
                                      onPressed: () {
                                        eliminarPago(pago);
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
                        totalItems: pagosFiltrados.length,
                        pageSize: pagosPorPagina,
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
      return const Scaffold(body: AppLoading(text: 'Cargando pagos...'));
    }

    final proyecto = resumenProyecto;
    final nombreProyecto =
        proyecto?['nombre']?.toString() ?? widget.proyectoNombre;

    final montoTotal = proyecto?['montoTotal'] ?? 0;
    final totalPagado = proyecto?['totalPagado'] ?? 0;
    final montoPendiente = proyecto?['montoPendiente'] ?? 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Pagos del proyecto')),
      body: AppBackground(
        padding: EdgeInsets.zero,
        child: RefreshIndicator(
          onRefresh: cargarPagos,
          child: construirContenidoPagos(
            nombreProyecto: nombreProyecto,
            montoTotal: montoTotal,
            totalPagado: totalPagado,
            montoPendiente: montoPendiente,
          ),
        ),
      ),
    );
  }
}

class PaymentSummaryRealRow extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const PaymentSummaryRealRow({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withAlpha(31),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: color, size: 23),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: AppColors.textDark,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// DIÁLOGO DE PAGO (StatefulWidget propio para manejo
// correcto del ciclo de vida de los controllers)
// =====================================================

class _PagoFormDialog extends StatefulWidget {
  final Map<String, dynamic>? pago;
  final Map<String, String> metodosPago;
  final double Function() obtenerMontoPendienteActual;
  final String Function(dynamic) formatearFecha;
  final String Function(DateTime) fechaInput;
  final DateTime Function(Map<String, dynamic>?) obtenerFechaPago;
  final double Function(dynamic) obtenerMonto;
  final Future<void> Function(double, String, String, String) onGuardar;
  final void Function() onExito;
  final void Function(String) onError;

  const _PagoFormDialog({
    required this.pago,
    required this.metodosPago,
    required this.obtenerMontoPendienteActual,
    required this.formatearFecha,
    required this.fechaInput,
    required this.obtenerFechaPago,
    required this.obtenerMonto,
    required this.onGuardar,
    required this.onExito,
    required this.onError,
  });

  @override
  State<_PagoFormDialog> createState() => _PagoFormDialogState();
}

class _PagoFormDialogState extends State<_PagoFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _montoController;
  late final TextEditingController _observacionController;

  late DateTime _fechaSeleccionada;
  late String _metodoSeleccionado;
  bool _guardando = false;

  bool get esEdicion => widget.pago != null;

  @override
  void initState() {
    super.initState();
    final pago = widget.pago;
    _montoController = TextEditingController(
      text: pago == null
          ? ''
          : widget.obtenerMonto(pago['monto']).toStringAsFixed(0),
    );
    _observacionController = TextEditingController(
      text: pago?['observacion']?.toString() ?? '',
    );
    _fechaSeleccionada = widget.obtenerFechaPago(pago);
    _metodoSeleccionado = pago?['metodo']?.toString() ?? 'EFECTIVO';
    if (!widget.metodosPago.containsKey(_metodoSeleccionado)) {
      _metodoSeleccionado = 'EFECTIVO';
    }
  }

  @override
  void dispose() {
    // Flutter llama dispose() en el momento correcto al retirar
    // el widget del árbol — sin condiciones de carrera.
    _montoController.dispose();
    _observacionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final montoTexto = _montoController.text.trim().replaceAll(',', '.');
    final observacion = _observacionController.text.trim();
    final monto = double.parse(montoTexto);
    final montoOriginal =
        esEdicion ? widget.obtenerMonto(widget.pago!['monto']) : 0.0;

    final resultadoMonto = BusinessRules.validarMontoPago(
      montoPago: monto,
      saldoPendiente: widget.obtenerMontoPendienteActual(),
      montoOriginal: montoOriginal,
    );
    if (!resultadoMonto.isValid) {
      widget.onError(resultadoMonto.message!);
      return;
    }

    final resultadoFecha = BusinessRules.validarFechaPago(
      fechaPago: _fechaSeleccionada,
    );
    if (!resultadoFecha.isValid) {
      widget.onError(resultadoFecha.message!);
      return;
    }

    setState(() => _guardando = true);

    try {
      await widget.onGuardar(
        monto,
        widget.fechaInput(_fechaSeleccionada),
        _metodoSeleccionado,
        observacion,
      );

      if (!mounted) return;

      FocusManager.instance.primaryFocus?.unfocus();
      Navigator.of(context).pop();

      // Notificamos el éxito después de que el diálogo se haya cerrado
      // para evitar cualquier interacción con el árbol desmontado.
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
        title: esEdicion ? 'Editar pago' : 'Registrar pago',
        subtitle: 'Complete la información del pago asociado a este proyecto.',
        icon: esEdicion ? Icons.edit_outlined : Icons.payments_outlined,
        desktopWidth: 820,
        desktopHeight: 500,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FormalFormGrid(
                children: [
                  AppFormField(
                    controller: _montoController,
                    enabled: !_guardando,
                    label: 'Monto del pago',
                    hint: 'Ejemplo: 50000',
                    icon: Icons.payments_outlined,
                    requiredField: true,
                    keyboardType: TextInputType.number,
                    maxLength: 12,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      LengthLimitingTextInputFormatter(12),
                    ],
                    validator: (value) {
                      final txt = value?.trim().replaceAll(',', '.') ?? '';
                      if (txt.isEmpty) return 'El monto es obligatorio.';
                      final monto = double.tryParse(txt);
                      if (monto == null || monto <= 0) return 'Ingrese un monto válido.';
                      if (monto > 999999999) return 'El monto es demasiado alto.';
                      return null;
                    },
                  ),
                  AppSelectField<String>(
                    label: 'Método de pago',
                    value: _metodoSeleccionado,
                    icon: Icons.account_balance_wallet_outlined,
                    requiredField: true,
                    items: widget.metodosPago.entries.map((entry) {
                      return DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(entry.value),
                      );
                    }).toList(),
                    onChanged: _guardando
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() => _metodoSeleccionado = value);
                          },
                  ),
                  AppPickerField(
                    label: 'Fecha del pago',
                    value: widget.formatearFecha(_fechaSeleccionada),
                    icon: Icons.calendar_month_outlined,
                    trailingIcon: Icons.edit_calendar_outlined,
                    requiredField: true,
                    onTap: _guardando
                        ? null
                        : () async {
                            final fecha = await showDatePicker(
                              context: context,
                              initialDate: _fechaSeleccionada,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (fecha != null) {
                              setState(() => _fechaSeleccionada = fecha);
                            }
                          },
                  ),
                ],
              ),
              const SizedBox(height: 18),
              AppFormField(
                controller: _observacionController,
                enabled: !_guardando,
                label: 'Observación',
                hint: 'Ejemplo: Pago inicial del proyecto',
                icon: Icons.notes_outlined,
                requiredField: true,
                maxLines: 4,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                validator: (value) {
                  final txt = value?.trim() ?? '';
                  if (txt.isEmpty) return 'La observación es obligatoria.';
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
