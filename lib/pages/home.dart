import 'dart:async';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/dashboard_service.dart';
import '../ui/common.dart';
import '../core/ui/dialogs/app_feedback.dart';
import '../core/ui/widgets/app_shell_header.dart';
import '../core/cache/app_cache.dart';
import '../services/preload_service.dart';

import 'auth.dart';
import '../pages/dashboard.dart';
import '../pages/clients.dart';
import '../pages/projects.dart';
import '../pages/reminders.dart';
import '../pages/reports.dart';
import '../pages/settings.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService authService = AuthService();

  final List<Widget?> _screenCache = List<Widget?>.filled(6, null);

  int selectedIndex = 0;
  int dashboardRefreshToken = 0;
  int projectsRefreshToken = 0;
  int remindersRefreshToken = 0;
  int reportsRefreshToken = 0;
  Map<String, dynamic>? perfil;
  bool loading = true;

  final List<String> titles = const [
    'Tablero',
    'Clientes',
    'Proyectos',
    'Recordatorios',
    'Reportes',
    'Configuración',
  ];

  String get currentTitle {
    return titles[selectedIndex];
  }

  String get currentSubtitle {
    switch (selectedIndex) {
      case 0:
        return 'Visualice el resumen general del sistema y sus principales métricas.';
      case 1:
        return 'Administre los clientes registrados y su información de contacto.';
      case 2:
        return 'Controle proyectos, montos, pagos, visitas, comentarios y recordatorios.';
      case 3:
        return 'Dé seguimiento a tareas, fechas importantes y pendientes del sistema.';
      case 4:
        return 'Analice ingresos, proyectos, clientes, visitas y saldos con reportes visuales.';
      case 5:
        return 'Gestione su cuenta, seguridad, correo, teléfono y contraseña.';
      default:
        return 'Panel principal del sistema.';
    }
  }

  IconData get currentHeaderIcon {
    switch (selectedIndex) {
      case 0:
        return Icons.dashboard_outlined;
      case 1:
        return Icons.people_alt_outlined;
      case 2:
        return Icons.folder_open_outlined;
      case 3:
        return Icons.notifications_active_outlined;
      case 4:
        return Icons.analytics_outlined;
      case 5:
        return Icons.settings_outlined;
      default:
        return Icons.apps_outlined;
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(cargarPerfil());
  }

  Widget _buildScreenForIndex(int index) {
    switch (index) {
      case 0:
        return DashboardRealPage(
          key: ValueKey('dashboard_$dashboardRefreshToken'),
          perfil: perfil,
          refreshToken: dashboardRefreshToken,
        );
      case 1:
        return const ClientsPage();
      case 2:
        return ProjectsPage(
          key: ValueKey('projects_$projectsRefreshToken'),
          refreshToken: projectsRefreshToken,
        );
      case 3:
        return RemindersRealPage(
          key: ValueKey('reminders_$remindersRefreshToken'),
          refreshToken: remindersRefreshToken,
        );
      case 4:
        return ReportsPage(
          key: ValueKey('reports_$reportsRefreshToken'),
          refreshToken: reportsRefreshToken,
        );
      case 5:
        return SettingsPage(perfil: perfil, onLogout: cerrarSesion);
      default:
        return DashboardRealPage(
          key: ValueKey('dashboard_$dashboardRefreshToken'),
          perfil: perfil,
          refreshToken: dashboardRefreshToken,
        );
    }
  }

  Widget _screenForIndex(int index) {
    final cached = _screenCache[index];

    if (cached != null) {
      return cached;
    }

    final screen = _buildScreenForIndex(index);
    _screenCache[index] = screen;
    return screen;
  }

  void _rebuildProfileDependentScreens() {
    _screenCache[0] = DashboardRealPage(
      key: ValueKey('dashboard_$dashboardRefreshToken'),
      perfil: perfil,
      refreshToken: dashboardRefreshToken,
    );
    _screenCache[5] = SettingsPage(perfil: perfil, onLogout: cerrarSesion);
  }

  void _refreshScreenForIndex(int index) {
    switch (index) {
      case 0:
        dashboardRefreshToken++;
        _screenCache[0] = DashboardRealPage(
          key: ValueKey('dashboard_$dashboardRefreshToken'),
          perfil: perfil,
          refreshToken: dashboardRefreshToken,
        );
        break;
      case 2:
        projectsRefreshToken++;
        _screenCache[2] = ProjectsPage(
          key: ValueKey('projects_$projectsRefreshToken'),
          refreshToken: projectsRefreshToken,
        );
        break;
      case 3:
        remindersRefreshToken++;
        _screenCache[3] = RemindersRealPage(
          key: ValueKey('reminders_$remindersRefreshToken'),
          refreshToken: remindersRefreshToken,
        );
        break;
      case 4:
        reportsRefreshToken++;
        _screenCache[4] = ReportsPage(
          key: ValueKey('reports_$reportsRefreshToken'),
          refreshToken: reportsRefreshToken,
        );
        break;
      default:
        _screenForIndex(index);
    }
  }

  Future<void> cargarPerfil() async {
    if (AppCache.perfil != null) {
      setState(() {
        perfil = AppCache.perfil;
        loading = false;
      });

      _rebuildProfileDependentScreens();
      unawaited(PreloadService.precargarTodo());

      return;
    }

    try {
      final data = await authService.profile();

      if (!mounted) return;

      AppCache.guardarPerfil(data);

      setState(() {
        perfil = data;
        loading = false;
      });

      _rebuildProfileDependentScreens();
      unawaited(PreloadService.precargarTodo());
    } catch (_) {
      await authService.logout();
      DashboardService.clearCache();
      AppCache.clear();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  Future<void> cerrarSesion() async {
    await authService.logout();
    DashboardService.clearCache();
    AppCache.clear();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> confirmarCerrarSesion() async {
    final confirmado = await AppFeedback.confirm(
      context: context,
      title: 'Cerrar sesión',
      message: '¿Está seguro de que desea cerrar la sesión actual?',
      confirmText: 'Sí, cerrar sesión',
      danger: true,
    );

    if (!confirmado) return;

    await cerrarSesion();
  }

  Widget getScreen() {
    return _screenForIndex(selectedIndex);
  }

  Widget getScreenStack() {
    _screenForIndex(selectedIndex);

    return IndexedStack(
      index: selectedIndex,
      children: List.generate(titles.length, (index) {
        return _screenCache[index] ?? const SizedBox.shrink();
      }),
    );
  }

  NavigationDestination _destination({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
  }) {
    return NavigationDestination(
      icon: Icon(icon),
      selectedIcon: Icon(selectedIcon),
      label: label,
    );
  }

  NavigationRailDestination _railDestination({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
  }) {
    return NavigationRailDestination(
      icon: Icon(icon),
      selectedIcon: Icon(selectedIcon),
      label: Text(label),
    );
  }

  Widget _buildMobileShell() {
    return Scaffold(
      appBar: _buildAppBar(isMobile: true),
      body: getScreenStack(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _refreshScreenForIndex(index);
            selectedIndex = index;
          });
        },
        destinations: [
          _destination(
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard,
            label: 'Tablero',
          ),
          _destination(
            icon: Icons.people_outline,
            selectedIcon: Icons.people,
            label: 'Clientes',
          ),
          _destination(
            icon: Icons.folder_outlined,
            selectedIcon: Icons.folder,
            label: 'Proyectos',
          ),
          _destination(
            icon: Icons.notifications_outlined,
            selectedIcon: Icons.notifications,
            label: 'Recordatorios',
          ),
          _destination(
            icon: Icons.analytics_outlined,
            selectedIcon: Icons.analytics,
            label: 'Reportes',
          ),
          _destination(
            icon: Icons.settings_outlined,
            selectedIcon: Icons.settings,
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopShell() {
    final nombre = perfil?['nombre']?.toString() ?? 'Usuario';
    final email = perfil?['email']?.toString() ?? '';

    return Scaffold(
      appBar: _buildAppBar(isMobile: false),
      body: Row(
        children: [
          Container(
            width: 260,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.asset(
                          'assets/images/logo_icono.png',
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Gestor',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textDark,
                              ),
                            ),
                            Text(
                              nombre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, color: AppColors.border),

                Expanded(
                  child: NavigationRail(
                    selectedIndex: selectedIndex,
                    extended: true,
                    backgroundColor: Colors.white,
                    indicatorColor: AppColors.primaryLight,
                    selectedIconTheme: const IconThemeData(
                      color: AppColors.primary,
                    ),
                    unselectedIconTheme: const IconThemeData(
                      color: AppColors.textMuted,
                    ),
                    selectedLabelTextStyle: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                    unselectedLabelTextStyle: const TextStyle(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                    onDestinationSelected: (index) {
                      setState(() {
                        _refreshScreenForIndex(index);
                        selectedIndex = index;
                      });
                    },
                    destinations: [
                      _railDestination(
                        icon: Icons.dashboard_outlined,
                        selectedIcon: Icons.dashboard,
                        label: 'Tablero',
                      ),
                      _railDestination(
                        icon: Icons.people_outline,
                        selectedIcon: Icons.people,
                        label: 'Clientes',
                      ),
                      _railDestination(
                        icon: Icons.folder_outlined,
                        selectedIcon: Icons.folder,
                        label: 'Proyectos',
                      ),
                      _railDestination(
                        icon: Icons.notifications_outlined,
                        selectedIcon: Icons.notifications,
                        label: 'Recordatorios',
                      ),
                      _railDestination(
                        icon: Icons.analytics_outlined,
                        selectedIcon: Icons.analytics,
                        label: 'Reportes',
                      ),
                      _railDestination(
                        icon: Icons.settings_outlined,
                        selectedIcon: Icons.settings,
                        label: 'Configuración',
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, color: AppColors.border),

                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      if (email.isNotEmpty)
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed: confirmarCerrarSesion,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.logout, size: 20),
                          label: const Text(
                            'Cerrar sesión',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(child: getScreenStack()),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar({required bool isMobile}) {
    final nombre = perfil?['nombre']?.toString() ?? 'Usuario';
    final email = perfil?['email']?.toString() ?? '';

    return AppShellHeader(
      title: currentTitle,
      subtitle: currentSubtitle,
      icon: currentHeaderIcon,
      headerHeight: 86,
      breadcrumb: 'Inicio / $currentTitle',
      userName: nombre,
      userEmail: email,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: AppLoading(text: 'Cargando sesión...'));
    }

    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900;

    if (isDesktop) {
      return _buildDesktopShell();
    }

    return _buildMobileShell();
  }
}
