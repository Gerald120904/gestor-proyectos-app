import 'package:flutter/material.dart';

import '../pages/payments.dart';
import '../pages/visits.dart';
import '../pages/comments.dart';
import '../pages/reminders.dart';
import '../ui/common.dart';
import '../core/cache/app_cache.dart';
import '../services/proyectos_service.dart';

class ProjectDetailRealPage extends StatefulWidget {
  final Map<String, dynamic> proyecto;

  const ProjectDetailRealPage({
    super.key,
    required this.proyecto,
  });

  @override
  State<ProjectDetailRealPage> createState() => _ProjectDetailRealPageState();
}

class _ProjectDetailRealPageState extends State<ProjectDetailRealPage> {
  final ProyectosService _proyectosService = ProyectosService();

  late Map<String, dynamic> _proyecto;
  bool _recargando = false;

  @override
  void initState() {
    super.initState();
    _proyecto = widget.proyecto;
  }

  int obtenerProyectoId() {
    return int.tryParse(_proyecto['id']?.toString() ?? '') ?? 0;
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

  double calcularTotalPagado() {
    final pagos = _proyecto['pagos'];

    if (pagos is! List) return 0;

    return pagos.fold<double>(0, (total, pago) {
      if (pago is Map) {
        return total + obtenerMonto(pago['monto']);
      }

      return total;
    });
  }

  Future<void> _recargarProyecto() async {
    final proyectoId = obtenerProyectoId();
    if (proyectoId == 0) return;

    setState(() {
      _recargando = true;
    });

    try {
      // Invalidar caché para forzar datos frescos
      AppCache.invalidarDetalleProyecto(proyectoId);
      AppCache.proyectos = null;
      AppCache.invalidarResumenes();

      final proyectoActualizado = await _proyectosService.getProyecto(proyectoId);

      if (!mounted) return;

      setState(() {
        _proyecto = proyectoActualizado;
        _recargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _recargando = false;
      });
    }
  }

  Future<void> _navegarYRecargar(Widget destino) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => destino),
    );

    if (mounted) {
      await _recargarProyecto();
    }
  }

  String estadoTexto(String estado) {
    switch (estado) {
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
    switch (estado) {
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

  Widget construirChipEstado(String estado) {
    final color = colorEstado(estado);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(31),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        estadoTexto(estado),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final proyectoId = obtenerProyectoId();

    final nombreProyecto = _proyecto['nombre']?.toString() ?? 'Sin nombre';
    final descripcion = _proyecto['descripcion']?.toString() ?? 'Sin descripción';

    final cliente = _proyecto['cliente'];
    final nombreCliente = cliente is Map
        ? cliente['nombre']?.toString() ?? 'Sin cliente'
        : 'Sin cliente';

    final montoTotal = obtenerMonto(_proyecto['montoTotal']);
    final totalPagado = calcularTotalPagado();
    final pendiente = montoTotal - totalPagado;
    final estado = _proyecto['estado']?.toString() ?? 'PENDIENTE';

    final pagos = _proyecto['pagos'];
    final visitas = _proyecto['visitas'];
    final comentarios = _proyecto['comentarios'];
    final recordatorios = _proyecto['recordatorios'];

    final totalPagos = pagos is List ? pagos.length : 0;
    final totalVisitas = visitas is List ? visitas.length : 0;
    final totalComentarios = comentarios is List ? comentarios.length : 0;
    final totalRecordatorios = recordatorios is List ? recordatorios.length : 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Detalle del proyecto'),
        actions: [
          if (_recargando)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: AppBackground(
        padding: EdgeInsets.zero,
        child: PageContainer(
          maxWidth: 1050,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              AppGlassCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.accent,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withAlpha(65),
                                blurRadius: 18,
                                offset: const Offset(0, 9),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.folder_outlined,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nombreProyecto,
                                style: const TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textDark,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                descripcion,
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 12),
                              construirChipEstado(estado),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    ProjectDetailInfo(
                      icon: Icons.person_outline,
                      title: 'Cliente',
                      value: nombreCliente,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;

                  final cardWidth = width >= 780
                      ? (width - 24) / 3
                      : width >= 540
                          ? (width - 12) / 2
                          : width;

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ProjectMetricCard(
                        width: cardWidth,
                        title: 'Monto total',
                        value: formatearMonto(montoTotal),
                        icon: Icons.account_balance_wallet_outlined,
                        color: AppColors.primary,
                      ),
                      ProjectMetricCard(
                        width: cardWidth,
                        title: 'Monto pagado',
                        value: formatearMonto(totalPagado),
                        icon: Icons.check_circle_outline,
                        color: AppColors.success,
                      ),
                      ProjectMetricCard(
                        width: cardWidth,
                        title: 'Monto pendiente',
                        value: formatearMonto(pendiente),
                        icon: Icons.pending_actions,
                        color: AppColors.warning,
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 22),

              const AppSectionTitle(
                title: 'Acciones del proyecto',
                subtitle:
                    'Seleccione una sección para administrar la información relacionada.',
              ),

              ProjectDetailActionTile(
                icon: Icons.payments_outlined,
                title: 'Pagos',
                subtitle: '$totalPagos pagos registrados',
                color: AppColors.success,
                onTap: () {
                  if (proyectoId == 0) return;

                  AppCache.precargarDetalleDesdeProyecto(
                    proyectoId: proyectoId,
                    proyecto: _proyecto,
                  );

                  _navegarYRecargar(
                    PaymentsRealPage(
                      proyectoId: proyectoId,
                      proyectoNombre: nombreProyecto,
                    ),
                  );
                },
              ),

              ProjectDetailActionTile(
                icon: Icons.event_outlined,
                title: 'Visitas',
                subtitle: '$totalVisitas visitas registradas',
                color: AppColors.primary,
                onTap: () {
                  if (proyectoId == 0) return;

                  AppCache.precargarDetalleDesdeProyecto(
                    proyectoId: proyectoId,
                    proyecto: _proyecto,
                  );

                  _navegarYRecargar(
                    VisitsRealPage(
                      proyectoId: proyectoId,
                      proyectoNombre: nombreProyecto,
                    ),
                  );
                },
              ),

              ProjectDetailActionTile(
                icon: Icons.comment_outlined,
                title: 'Comentarios',
                subtitle: '$totalComentarios comentarios registrados',
                color: AppColors.accent,
                onTap: () {
                  if (proyectoId == 0) return;

                  AppCache.precargarDetalleDesdeProyecto(
                    proyectoId: proyectoId,
                    proyecto: _proyecto,
                  );

                  _navegarYRecargar(
                    CommentsRealPage(
                      proyectoId: proyectoId,
                      proyectoNombre: nombreProyecto,
                    ),
                  );
                },
              ),

              ProjectDetailActionTile(
                icon: Icons.notifications_outlined,
                title: 'Recordatorios',
                subtitle: '$totalRecordatorios recordatorios registrados',
                color: AppColors.warning,
                onTap: () {
                  if (proyectoId == 0) return;

                  AppCache.precargarDetalleDesdeProyecto(
                    proyectoId: proyectoId,
                    proyecto: _proyecto,
                  );

                  _navegarYRecargar(
                    RemindersRealPage(
                      proyectoId: proyectoId,
                      proyectoNombre: nombreProyecto,
                    ),
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

class ProjectMetricCard extends StatelessWidget {
  final double width;
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const ProjectMetricCard({
    super.key,
    required this.width,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
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
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withAlpha(31),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                icon,
                color: color,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
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
}

class ProjectDetailInfo extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const ProjectDetailInfo({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textDark,
                  height: 1.35,
                ),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProjectDetailActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const ProjectDetailActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withAlpha(14),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: color.withAlpha(31),
                    borderRadius: BorderRadius.circular(19),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 28,
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
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}