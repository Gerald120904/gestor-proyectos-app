class BusinessValidationResult {
  final bool isValid;
  final String? message;

  const BusinessValidationResult._({
    required this.isValid,
    this.message,
  });

  factory BusinessValidationResult.ok() {
    return const BusinessValidationResult._(isValid: true);
  }

  factory BusinessValidationResult.error(String message) {
    return BusinessValidationResult._(
      isValid: false,
      message: message,
    );
  }
}

class BusinessRules {
  BusinessRules._();

  static const double _moneyTolerance = 0.01;

  static DateTime combinarFechaHora({
    required DateTime fecha,
    required int hora,
    required int minuto,
  }) {
    return DateTime(
      fecha.year,
      fecha.month,
      fecha.day,
      hora,
      minuto,
    );
  }

  static DateTime soloFecha(DateTime fecha) {
    return DateTime(fecha.year, fecha.month, fecha.day);
  }

  static String formatearColones(double monto) {
    return '₡${monto.toStringAsFixed(0)}';
  }

  static String normalizarTelefono(String telefono) {
    return telefono.replaceAll(RegExp(r'[^0-9]'), '');
  }

  static String normalizarTexto(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  static BusinessValidationResult validarMontoPago({
    required double montoPago,
    required double saldoPendiente,
    double montoOriginal = 0,
  }) {
    if (montoPago <= 0) {
      return BusinessValidationResult.error(
        'El monto del pago debe ser mayor a ₡0.',
      );
    }

    final saldoDisponible = saldoPendiente + montoOriginal;

    if (saldoDisponible <= _moneyTolerance && montoOriginal <= _moneyTolerance) {
      return BusinessValidationResult.error(
        'Este proyecto ya está completamente pagado. No se pueden registrar más pagos.',
      );
    }

    if (montoPago > saldoDisponible + _moneyTolerance) {
      return BusinessValidationResult.error(
        'El pago no puede ser mayor al saldo pendiente. Saldo disponible: ${formatearColones(saldoDisponible)}.',
      );
    }

    return BusinessValidationResult.ok();
  }

  static BusinessValidationResult validarFechaPago({
    required DateTime fechaPago,
  }) {
    final hoy = soloFecha(DateTime.now());
    final fecha = soloFecha(fechaPago);

    if (fecha.isAfter(hoy)) {
      return BusinessValidationResult.error(
        'La fecha del pago no puede ser posterior a la fecha actual.',
      );
    }

    return BusinessValidationResult.ok();
  }

  static BusinessValidationResult validarMontoProyecto({
    required double montoTotal,
    double totalPagado = 0,
    String estadoProyecto = '',
  }) {
    if (montoTotal <= 0) {
      return BusinessValidationResult.error(
        'El monto total del proyecto debe ser mayor a ₡0.',
      );
    }

    if (montoTotal < totalPagado - _moneyTolerance) {
      return BusinessValidationResult.error(
        'El monto total del proyecto no puede ser menor a lo que ya se pagó. Total pagado: ${formatearColones(totalPagado)}.',
      );
    }

    final estado = estadoProyecto.trim().toUpperCase();
    final pendiente = montoTotal - totalPagado;

    if (estado == 'FINALIZADO' && pendiente > _moneyTolerance) {
      return BusinessValidationResult.error(
        'No se puede finalizar el proyecto porque todavía tiene saldo pendiente: ${formatearColones(pendiente)}.',
      );
    }

    return BusinessValidationResult.ok();
  }

  static BusinessValidationResult validarRecordatorio({
    required DateTime fechaHora,
    required bool completado,
  }) {
    final ahoraReal = DateTime.now();
    final ahora = DateTime(
      ahoraReal.year,
      ahoraReal.month,
      ahoraReal.day,
      ahoraReal.hour,
      ahoraReal.minute,
    );

    if (!completado && fechaHora.isBefore(ahora)) {
      return BusinessValidationResult.error(
        'No se puede crear o dejar pendiente un recordatorio en una fecha u hora pasada.',
      );
    }

    if (completado && fechaHora.isAfter(ahora)) {
      return BusinessValidationResult.error(
        'No se puede marcar como completado un recordatorio programado para el futuro.',
      );
    }

    return BusinessValidationResult.ok();
  }

  static BusinessValidationResult validarVisita({
    required DateTime fechaHora,
    required String estado,
  }) {
    final estadoNormalizado = estado.trim().toUpperCase();
    final ahoraReal = DateTime.now();
    final ahora = DateTime(
      ahoraReal.year,
      ahoraReal.month,
      ahoraReal.day,
      ahoraReal.hour,
      ahoraReal.minute,
    );

    if (estadoNormalizado == 'PROGRAMADA' && fechaHora.isBefore(ahora)) {
      return BusinessValidationResult.error(
        'No se puede programar una visita en una fecha u hora pasada.',
      );
    }

    if (estadoNormalizado == 'REALIZADA' && fechaHora.isAfter(ahora)) {
      return BusinessValidationResult.error(
        'No se puede marcar como realizada una visita que todavía no ha ocurrido.',
      );
    }

    return BusinessValidationResult.ok();
  }

  static BusinessValidationResult validarProyectoDisponibleParaRecordatorio({
    required String estadoProyecto,
  }) {
    final estado = estadoProyecto.trim().toUpperCase();

    if (estado == 'FINALIZADO') {
      return BusinessValidationResult.error(
        'No se pueden crear recordatorios para un proyecto finalizado.',
      );
    }

    return BusinessValidationResult.ok();
  }

  static BusinessValidationResult validarClienteUnico({
    required List<Map<String, dynamic>> clientes,
    required String correo,
    required String telefonoPais,
    required String telefono,
    String? idActual,
  }) {
    final correoNormalizado = normalizarTexto(correo);
    final telefonoNormalizado = normalizarTelefono(telefono);
    final paisNormalizado = telefonoPais.trim().toUpperCase();

    for (final cliente in clientes) {
      final id = cliente['id']?.toString();

      if (idActual != null && id == idActual) {
        continue;
      }

      final correoExistente = normalizarTexto(
        cliente['correo']?.toString() ?? '',
      );

      if (correoExistente.isNotEmpty && correoExistente == correoNormalizado) {
        return BusinessValidationResult.error(
          'Ya existe otro cliente registrado con ese correo electrónico.',
        );
      }

      final telefonoExistente = normalizarTelefono(
        cliente['telefono']?.toString() ?? '',
      );

      final paisExistente = (cliente['telefonoPais']?.toString() ?? '')
          .trim()
          .toUpperCase();

      if (telefonoExistente.isNotEmpty &&
          telefonoNormalizado.isNotEmpty &&
          telefonoExistente == telefonoNormalizado &&
          (paisExistente.isEmpty || paisExistente == paisNormalizado)) {
        return BusinessValidationResult.error(
          'Ya existe otro cliente registrado con ese número de teléfono.',
        );
      }
    }

    return BusinessValidationResult.ok();
  }

  static BusinessValidationResult validarComentario({
    required String contenido,
  }) {
    final texto = contenido.trim();

    if (texto.isEmpty) {
      return BusinessValidationResult.error(
        'El comentario es obligatorio.',
      );
    }

    if (texto.length < 5) {
      return BusinessValidationResult.error(
        'Debe tener al menos 5 caracteres.',
      );
    }

    if (texto.length > 500) {
      return BusinessValidationResult.error(
        'No puede superar los 500 caracteres.',
      );
    }

    return BusinessValidationResult.ok();
  }

  static BusinessValidationResult validarComentarioUnico({
    required List<Map<String, dynamic>> comentarios,
    required String contenido,
    String? idActual,
  }) {
    final contenidoNormalizado = normalizarTexto(contenido);

    for (final comentario in comentarios) {
      final id = comentario['id']?.toString();

      if (idActual != null && id == idActual) {
        continue;
      }

      final contenidoExistente = normalizarTexto(
        comentario['contenido']?.toString() ?? '',
      );

      if (contenidoExistente == contenidoNormalizado) {
        return BusinessValidationResult.error(
          'Ya existe un comentario igual en este proyecto.',
        );
      }
    }

    return BusinessValidationResult.ok();
  }
}
