class AppCache {
  static Map<String, dynamic>? perfil;
  static Map<String, dynamic>? dashboard;
  static Map<String, dynamic>? reporteMes;

  static List<Map<String, dynamic>>? clientes;
  static List<Map<String, dynamic>>? proyectos;
  static List<Map<String, dynamic>>? recordatorios;

  static final Map<int, Map<String, dynamic>> pagosPorProyecto = {};
  static final Map<int, List<Map<String, dynamic>>> visitasPorProyecto = {};
  static final Map<int, List<Map<String, dynamic>>> comentariosPorProyecto = {};
  static final Map<int, List<Map<String, dynamic>>> recordatoriosPorProyecto = {};

  static bool preloadIniciado = false;

  static void guardarPerfil(dynamic data) {
    if (data is Map) {
      perfil = Map<String, dynamic>.from(data);
    }
  }

  static void guardarClientes(dynamic data) {
    if (data is List) {
      clientes = data.map((item) => Map<String, dynamic>.from(item)).toList();
    }
  }

  static void guardarProyectos(dynamic data) {
    if (data is List) {
      proyectos = data.map((item) => Map<String, dynamic>.from(item)).toList();
    }
  }

  static void guardarDashboard(dynamic data) {
    if (data is Map) {
      dashboard = Map<String, dynamic>.from(data);
    }
  }

  static void guardarReporteMes(dynamic data) {
    if (data is Map) {
      reporteMes = Map<String, dynamic>.from(data);
    }
  }

  static void guardarRecordatorios(dynamic data) {
    if (data is List) {
      recordatorios = data.map((item) => Map<String, dynamic>.from(item)).toList();
    }
  }

  static void guardarPagosProyecto({
    required int proyectoId,
    required dynamic data,
  }) {
    if (data is Map) {
      pagosPorProyecto[proyectoId] = Map<String, dynamic>.from(data);
    }
  }

  static void guardarVisitasProyecto({
    required int proyectoId,
    required dynamic data,
  }) {
    if (data is List) {
      visitasPorProyecto[proyectoId] =
          data.map((item) => Map<String, dynamic>.from(item)).toList();
    }
  }

  static void guardarComentariosProyecto({
    required int proyectoId,
    required dynamic data,
  }) {
    if (data is List) {
      comentariosPorProyecto[proyectoId] =
          data.map((item) => Map<String, dynamic>.from(item)).toList();
    }
  }

  static void guardarRecordatoriosProyecto({
    required int proyectoId,
    required dynamic data,
  }) {
    if (data is List) {
      recordatoriosPorProyecto[proyectoId] =
          data.map((item) => Map<String, dynamic>.from(item)).toList();
    }
  }

  static void precargarDetalleDesdeProyecto({
    required int proyectoId,
    required Map<String, dynamic> proyecto,
  }) {
    final pagos = proyecto['pagos'];
    final visitas = proyecto['visitas'];
    final comentarios = proyecto['comentarios'];
    final recordatoriosProyecto = proyecto['recordatorios'];

    if (pagos is List) {
      pagosPorProyecto[proyectoId] = {
        'proyecto': proyecto,
        'pagos': pagos.map((item) => Map<String, dynamic>.from(item)).toList(),
      };
    }

    if (visitas is List) {
      visitasPorProyecto[proyectoId] =
          visitas.map((item) => Map<String, dynamic>.from(item)).toList();
    }

    if (comentarios is List) {
      comentariosPorProyecto[proyectoId] =
          comentarios.map((item) => Map<String, dynamic>.from(item)).toList();
    }

    if (recordatoriosProyecto is List) {
      recordatoriosPorProyecto[proyectoId] = recordatoriosProyecto
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
  }

  static void invalidarResumenes() {
    dashboard = null;
    reporteMes = null;
  }

  static void invalidarProyectos() {
    proyectos = null;
    invalidarResumenes();
  }

  static void invalidarDetalleProyecto(int proyectoId) {
    pagosPorProyecto.remove(proyectoId);
    visitasPorProyecto.remove(proyectoId);
    comentariosPorProyecto.remove(proyectoId);
    recordatoriosPorProyecto.remove(proyectoId);
  }

  static void invalidarTodoDespuesDeCambioEnProyecto(int proyectoId) {
    invalidarDetalleProyecto(proyectoId);
    proyectos = null;
    recordatorios = null;
    invalidarResumenes();
  }

  static void clear() {
    perfil = null;
    dashboard = null;
    reporteMes = null;
    clientes = null;
    proyectos = null;
    recordatorios = null;
    pagosPorProyecto.clear();
    visitasPorProyecto.clear();
    comentariosPorProyecto.clear();
    recordatoriosPorProyecto.clear();
    preloadIniciado = false;
  }
}
