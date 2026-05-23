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

    final authService = AuthService();
    final clientesService = ClientesService();
    final proyectosService = ProyectosService();
    final dashboardService = DashboardService();
    final recordatoriosService = RecordatoriosService();
    final reportesService = ReportesService();

    Future<void> safe(Future<void> Function() task) async {
      try {
        await task();
      } catch (_) {
        // La precarga nunca debe bloquear el login ni la navegación.
      }
    }

    await Future.wait([
      safe(() async {
        AppCache.perfil = await authService.profile();
      }),
      safe(() async {
        AppCache.dashboard = await dashboardService.getDashboard();
      }),
      safe(() async {
        AppCache.clientes = await clientesService.getClientes();
      }),
      safe(() async {
        AppCache.proyectos = await proyectosService.getProyectos();
      }),
      safe(() async {
        AppCache.recordatorios = await recordatoriosService.getRecordatorios();
      }),
      safe(() async {
        AppCache.reporteMes = await reportesService.getGeneralReport(
          period: 'month',
        );
      }),
    ]);
  }
}
