import 'dart:async';

import '../core/cache/app_cache.dart';
import 'auth_service.dart';
import 'clientes_service.dart';
import 'proyectos_service.dart';
import 'dashboard_service.dart';
import 'recordatorios_service.dart';
import 'reportes_service.dart';

class PreloadService {
  static Future<void> precargarTodo() async {
    if (AppCache.preloadIniciado) return;

    AppCache.preloadIniciado = true;
    final generationAtStart = AppCache.sessionGeneration;

    final authService = AuthService();
    final clientesService = ClientesService();
    final proyectosService = ProyectosService();
    final dashboardService = DashboardService();
    final recordatoriosService = RecordatoriosService();
    final reportesService = ReportesService();

    Future<void> safe(Future<void> Function() task) async {
      try {
        if (generationAtStart != AppCache.sessionGeneration) return;
        await task();
      } catch (_) {
        // La precarga nunca debe bloquear el login ni la navegación.
      }
    }

    await Future.wait([
      safe(() async {
        if (generationAtStart != AppCache.sessionGeneration) return;
        AppCache.dashboard = await dashboardService.getDashboard();
      }),
      safe(() async {
        if (generationAtStart != AppCache.sessionGeneration) return;
        AppCache.clientes = await clientesService.getClientes();
      }),
      safe(() async {
        if (generationAtStart != AppCache.sessionGeneration) return;
        AppCache.proyectos = await proyectosService.getProyectos();
      }),
      safe(() async {
        if (generationAtStart != AppCache.sessionGeneration) return;
        AppCache.recordatorios = await recordatoriosService.getRecordatorios();
      }),
      safe(() async {
        if (generationAtStart != AppCache.sessionGeneration) return;
        final token = await authService.getToken();

        if (token == null || token.trim().isEmpty) return;

        final reporteMes = await reportesService.getGeneralReport(
          period: 'month',
        );

        AppCache.guardarReporteMes(token: token, data: reporteMes);
      }),
    ]);

    if (generationAtStart != AppCache.sessionGeneration) return;
  }
}
