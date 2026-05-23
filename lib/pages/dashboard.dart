import 'package:flutter/material.dart';

import '../services/dashboard_service.dart';
import '../core/cache/app_cache.dart';
import '../ui/common.dart';
import '../core/ui/dialogs/app_feedback.dart';
import '../core/ui/widgets/app_search_input.dart';

// =====================================================
// DASHBOARD REAL DESDE MYSQL - CARGA PROGRESIVA
// =====================================================

class DashboardRealPage extends StatefulWidget {
  final Map<String, dynamic>? perfil;

  const DashboardRealPage({super.key, required this.perfil});

  @override
  State<DashboardRealPage> createState() => _DashboardRealPageState();
}

class _DashboardRealPageState extends State<DashboardRealPage> {
  final DashboardService dashboardService = DashboardService();
  final ScrollController _scrollController = ScrollController();

  Map<String, dynamic>? resumenDashboard;
  Map<String, dynamic>? estadosDashboard;
  List<Map<String, dynamic>> ultimosProyectosDashboard = [];

  bool loadingResumen = false;
  bool loadingEstados = false;
  bool loadingUltimosProyectos = false;
  bool refreshing = false;
  bool initialLoadDone = false;
  bool ultimosProyectosSolicitados = false;

  String busquedaUltimosProyectos = '';

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(_detectarCargaPorScroll);

    final cachedDashboard = AppCache.dashboard;

    if (cachedDashboard != null) {
      _hidratarDesdeCache(cachedDashboard);
      initialLoadDone = true;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      cargarResumenDashboard(silencioso: cachedDashboard != null);
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_detectarCargaPorScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _detectarCargaPorScroll() {
    if (!_scrollController.hasClients) return;
    if (ultimosProyectosSolicitados || loadingUltimosProyectos) return;

    final position = _scrollController.position;
    final cercaDelFinal = position.pixels >= position.maxScrollExtent - 260;

    if (cercaDelFinal) {
      cargarUltimosProyectosDashboard();
    }
  }

  void _hidratarDesdeCache(Map<String, dynamic> data) {
    resumenDashboard = {
      'totalClientes': data['totalClientes'],
      'totalProyectos': data['totalProyectos'],
      'montoTotalProyectos': data['montoTotalProyectos'],
      'montoPagado': data['montoPagado'],
      'montoPendiente': data['montoPendiente'],
      'visitasProximas': data['visitasProximas'],
      'recordatoriosPendientes': data['recordatoriosPendientes'],
    };

    final proyectosPorEstado = data['proyectosPorEstado'];
    if (proyectosPorEstado is Map) {
      estadosDashboard = {
        'proyectosPorEstado': Map<String, dynamic>.from(proyectosPorEstado),
      };
    }

    final ultimosProyectos = data['ultimosProyectos'];
    if (ultimosProyectos is List) {
      ultimosProyectosDashboard = ultimosProyectos
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      ultimosProyectosSolicitados = ultimosProyectosDashboard.isNotEmpty;
    }
  }

  void _guardarCacheCombinado() {
    final resumen = resumenDashboard ?? <String, dynamic>{};

    final proyectosPorEstado = estadosDashboard?['proyectosPorEstado'];

    final data = <String, dynamic>{
      ...resumen,
      'proyectosPorEstado': proyectosPorEstado is Map
          ? Map<String, dynamic>.from(proyectosPorEstado)
          : <String, dynamic>{},
      'ultimosProyectos': ultimosProyectosDashboard,
    };

    AppCache.guardarDashboard(data);
  }

  Future<void> cargarResumenDashboard({bool silencioso = false}) async {
    if (!mounted) return;

    setState(() {
      loadingResumen = resumenDashboard == null && !silencioso;
      refreshing = resumenDashboard != null || silencioso;
    });

    try {
      final data = await dashboardService.getResumenDashboard();

      if (!mounted) return;

      setState(() {
        resumenDashboard = data;
        loadingResumen = false;
        refreshing = false;
        initialLoadDone = true;
      });

      _guardarCacheCombinado();

      // Después de pintar lo principal, cargamos estadísticas en segundo plano.
      cargarEstadosDashboard();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        loadingResumen = false;
        refreshing = false;
        initialLoadDone = true;
      });

      if (resumenDashboard == null && AppCache.dashboard == null) {
        mostrarMensaje(error.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Future<void> cargarEstadosDashboard() async {
    if (!mounted || loadingEstados) return;

    setState(() {
      loadingEstados = true;
    });

    try {
      final data = await dashboardService.getEstadosDashboard();

      if (!mounted) return;

      setState(() {
        estadosDashboard = data;
        loadingEstados = false;
      });

      _guardarCacheCombinado();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        loadingEstados = false;
      });
    }
  }

  Future<void> cargarUltimosProyectosDashboard() async {
    if (!mounted || loadingUltimosProyectos) return;

    setState(() {
      ultimosProyectosSolicitados = true;
      loadingUltimosProyectos = true;
    });

    try {
      final data = await dashboardService.getUltimosProyectosDashboard(
        page: 1,
        limit: 5,
      );

      if (!mounted) return;

      setState(() {
        ultimosProyectosDashboard = data;
        loadingUltimosProyectos = false;
      });

      _guardarCacheCombinado();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        loadingUltimosProyectos = false;
      });

      mostrarMensaje(error.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> refrescarDashboard() async {
    if (!mounted) return;

    setState(() {
      refreshing = true;
    });

    try {
      final resumen = await dashboardService.getResumenDashboard();

      if (!mounted) return;

      setState(() {
        resumenDashboard = resumen;
        initialLoadDone = true;
      });

      final estados = await dashboardService.getEstadosDashboard();

      if (!mounted) return;

      setState(() {
        estadosDashboard = estados;
      });

      if (ultimosProyectosSolicitados) {
        final proyectos = await dashboardService.getUltimosProyectosDashboard(
          page: 1,
          limit: 5,
        );

        if (!mounted) return;

        setState(() {
          ultimosProyectosDashboard = proyectos;
        });
      }

      _guardarCacheCombinado();
    } catch (error) {
      if (!mounted) return;
      mostrarMensaje(error.toString().replaceAll('Exception: ', ''));
    } finally {
      if (!mounted) return;

      setState(() {
        refreshing = false;
        loadingResumen = false;
        loadingEstados = false;
        loadingUltimosProyectos = false;
      });
    }
  }

  void mostrarMensaje(String mensaje) {
    if (!mounted) return;

    AppFeedback.message(context: context, message: mensaje);
  }

  double obtenerMonto(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  String formatearMonto(dynamic value) {
    final monto = obtenerMonto(value);
    return '₡${monto.toStringAsFixed(0)}';
  }

  int obtenerEntero(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  List<Map<String, dynamic>> filtrarUltimosProyectos(
    List<Map<String, dynamic>> proyectos,
  ) {
    final texto = busquedaUltimosProyectos.trim().toLowerCase();

    if (texto.isEmpty) {
      return proyectos;
    }

    return proyectos.where((proyecto) {
      final nombre = proyecto['nombre']?.toString().toLowerCase() ?? '';
      final estado = proyecto['estado']?.toString().toLowerCase() ?? '';
      final montoTotal = proyecto['montoTotal']?.toString().toLowerCase() ?? '';
      final totalPagado =
          proyecto['totalPagado']?.toString().toLowerCase() ?? '';
      final montoPendiente =
          proyecto['montoPendiente']?.toString().toLowerCase() ?? '';

      return nombre.contains(texto) ||
          estado.contains(texto) ||
          montoTotal.contains(texto) ||
          totalPagado.contains(texto) ||
          montoPendiente.contains(texto);
    }).toList();
  }

  String estadoTexto(String estado) {
    final key = estado.toUpperCase();

    switch (key) {
      case 'PENDIENTE':
        return 'Pendientes';
      case 'ACTIVO':
        return 'Activos';
      case 'FINALIZADO':
        return 'Finalizados';
      case 'PAUSADO':
        return 'Pausados';
      default:
        return estado;
    }
  }

  String estadoTextoSingular(String estado) {
    final key = estado.toUpperCase();

    switch (key) {
      case 'PENDIENTE':
        return 'Pendiente';
      case 'ACTIVO':
        return 'Activo';
      case 'FINALIZADO':
        return 'Finalizado';
      case 'PAUSADO':
        return 'Pausado';
      default:
        return estado;
    }
  }

  Color colorEstado(String estado) {
    final key = estado.toUpperCase();

    switch (key) {
      case 'PENDIENTE':
        return AppColors.warning;
      case 'ACTIVO':
        return AppColors.success;
      case 'FINALIZADO':
        return AppColors.primary;
      case 'PAUSADO':
        return AppColors.textMuted;
      default:
        return AppColors.textMuted;
    }
  }

  Widget construirBarraActualizando() {
    if (!refreshing) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withAlpha(45)),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Actualizando información del tablero...',
              style: TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget construirMetrica({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required double width,
    bool cargando = false,
  }) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withAlpha(14),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: color.withAlpha(31),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (cargando)
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  else
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        letterSpacing: -0.5,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget construirPanelEstados(
    Map<String, dynamic> estados, {
    required bool cargando,
  }) {
    return AppGlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(22),
            child: Row(
              children: [
                Icon(Icons.flag_outlined, color: AppColors.primary, size: 30),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Proyectos por estado',
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
          if (cargando && estados.isEmpty)
            const Padding(
              padding: EdgeInsets.all(22),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Cargando estados de proyectos...',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (estados.isEmpty)
            const Padding(
              padding: EdgeInsets.all(22),
              child: Text(
                'No hay datos de estados disponibles.',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: estados.entries.map((entry) {
                  final estado = entry.key;
                  final cantidad = obtenerEntero(entry.value);
                  final color = colorEstado(estado);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: color.withAlpha(31),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.flag_outlined,
                            color: color,
                            size: 23,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            estadoTexto(estado),
                            style: const TextStyle(
                              color: AppColors.textDark,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Text(
                          '$cantidad',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget construirPanelUltimosProyectos(
    List<Map<String, dynamic>> proyectos, {
    required bool cargando,
  }) {
    final proyectosFiltrados = filtrarUltimosProyectos(proyectos);

    return AppGlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(22),
            child: Row(
              children: [
                Icon(Icons.folder_outlined, color: AppColors.primary, size: 30),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Últimos proyectos',
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
          if (!ultimosProyectosSolicitados && proyectos.isEmpty && !cargando)
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Esta sección se carga solo cuando la necesitas para que el dashboard abra más rápido.',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: cargarUltimosProyectosDashboard,
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Ver últimos proyectos'),
                  ),
                ],
              ),
            )
          else if (cargando && proyectos.isEmpty)
            const Padding(
              padding: EdgeInsets.all(22),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Cargando últimos proyectos...',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            if (proyectos.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                child: AppSearchInput(
                  hintText: 'Buscar proyecto por nombre, estado o monto...',
                  onChanged: (value) {
                    setState(() {
                      busquedaUltimosProyectos = value;
                    });
                  },
                ),
              ),
            if (proyectos.isNotEmpty) const SizedBox(height: 16),
            if (proyectos.isEmpty)
              const Padding(
                padding: EdgeInsets.all(22),
                child: Text(
                  'Todavía no hay proyectos registrados.',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
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
                      'Intente buscar con otro nombre, estado o monto.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                child: Column(
                  children: proyectosFiltrados.map((proyecto) {
                    final nombre =
                        proyecto['nombre']?.toString() ?? 'Sin nombre';
                    final estado =
                        proyecto['estado']?.toString() ?? 'PENDIENTE';

                    final color = colorEstado(estado);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.primary, AppColors.accent],
                              ),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(
                              Icons.folder_outlined,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nombre,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textDark,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Total: ${formatearMonto(proyecto['montoTotal'])}',
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Pagado: ${formatearMonto(proyecto['totalPagado'])}',
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Pendiente: ${formatearMonto(proyecto['montoPendiente'])}',
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: color.withAlpha(31),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              estadoTextoSingular(estado),
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nombre = widget.perfil?['nombre']?.toString() ?? 'Usuario';

    final resumen = resumenDashboard ?? <String, dynamic>{};

    final totalClientes = obtenerEntero(resumen['totalClientes']);
    final totalProyectos = obtenerEntero(resumen['totalProyectos']);
    final montoTotalProyectos = obtenerMonto(resumen['montoTotalProyectos']);
    final montoPagado = obtenerMonto(resumen['montoPagado']);
    final montoPendiente = obtenerMonto(resumen['montoPendiente']);
    final visitasProximas = obtenerEntero(resumen['visitasProximas']);
    final recordatoriosPendientes = obtenerEntero(
      resumen['recordatoriosPendientes'],
    );

    final proyectosPorEstado = estadosDashboard?['proyectosPorEstado'];
    final estados = proyectosPorEstado is Map
        ? Map<String, dynamic>.from(proyectosPorEstado)
        : <String, dynamic>{};

    final cargandoMetricas = loadingResumen && resumenDashboard == null;

    return AppBackground(
      padding: EdgeInsets.zero,
      child: PageContainer(
        maxWidth: 1180,
        child: RefreshIndicator(
          onRefresh: refrescarDashboard,
          child: ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              construirBarraActualizando(),
              AppGlassCard(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.accent],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withAlpha(65),
                            blurRadius: 18,
                            offset: const Offset(0, 9),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.dashboard_outlined,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bienvenido, $nombre',
                            style: const TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textDark,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            cargandoMetricas
                                ? 'Cargando primero la información principal...'
                                : 'Resumen general del sistema.',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;

                  final cardWidth = width >= 920
                      ? (width - 32) / 3
                      : width >= 620
                      ? (width - 16) / 2
                      : width;

                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      construirMetrica(
                        title: 'Clientes registrados',
                        value: '$totalClientes',
                        icon: Icons.people_outline,
                        color: AppColors.primary,
                        width: cardWidth,
                        cargando: cargandoMetricas,
                      ),
                      construirMetrica(
                        title: 'Proyectos registrados',
                        value: '$totalProyectos',
                        icon: Icons.folder_outlined,
                        color: AppColors.accent,
                        width: cardWidth,
                        cargando: cargandoMetricas,
                      ),
                      construirMetrica(
                        title: 'Monto total en proyectos',
                        value: formatearMonto(montoTotalProyectos),
                        icon: Icons.account_balance_wallet_outlined,
                        color: AppColors.primaryDark,
                        width: cardWidth,
                        cargando: cargandoMetricas,
                      ),
                      construirMetrica(
                        title: 'Monto pagado',
                        value: formatearMonto(montoPagado),
                        icon: Icons.check_circle_outline,
                        color: AppColors.success,
                        width: cardWidth,
                        cargando: cargandoMetricas,
                      ),
                      construirMetrica(
                        title: 'Monto pendiente',
                        value: formatearMonto(montoPendiente),
                        icon: Icons.pending_actions,
                        color: AppColors.warning,
                        width: cardWidth,
                        cargando: cargandoMetricas,
                      ),
                      construirMetrica(
                        title: 'Visitas próximas',
                        value: '$visitasProximas',
                        icon: Icons.event_outlined,
                        color: AppColors.accent,
                        width: cardWidth,
                        cargando: cargandoMetricas,
                      ),
                      construirMetrica(
                        title: 'Recordatorios pendientes',
                        value: '$recordatoriosPendientes',
                        icon: Icons.notifications_active_outlined,
                        color: AppColors.danger,
                        width: cardWidth,
                        cargando: cargandoMetricas,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 22),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 900;

                  if (!isWide) {
                    return Column(
                      children: [
                        construirPanelEstados(
                          estados,
                          cargando: loadingEstados,
                        ),
                        const SizedBox(height: 18),
                        construirPanelUltimosProyectos(
                          ultimosProyectosDashboard,
                          cargando: loadingUltimosProyectos,
                        ),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 4,
                        child: construirPanelEstados(
                          estados,
                          cargando: loadingEstados,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        flex: 6,
                        child: construirPanelUltimosProyectos(
                          ultimosProyectosDashboard,
                          cargando: loadingUltimosProyectos,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
