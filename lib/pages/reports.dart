import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../services/reportes_service.dart';
import '../core/cache/app_cache.dart';
import '../ui/common.dart';
import '../core/ui/dialogs/app_feedback.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final ReportesService reportesService = ReportesService();

  Map<String, dynamic>? reporte;
  bool loading = true;
  bool exporting = false;

  String selectedPeriod = 'month';
  DateTime? customStartDate;
  DateTime? customEndDate;

  final List<Map<String, String>> periods = const [
    {'key': 'today', 'label': 'Hoy'},
    {'key': 'week', 'label': 'Semana'},
    {'key': 'month', 'label': 'Mes'},
    {'key': 'year', 'label': 'Año'},
    {'key': 'custom', 'label': 'Personalizado'},
  ];

  // Paleta formal y profesional
  final List<Color> chartColors = const [
    Color(0xFF2563EB), // Azul profundo
    Color(0xFF0891B2), // Cyan formal
    Color(0xFF059669), // Verde esmeralda
    Color(0xFF7C3AED), // Violeta
    Color(0xFFD97706), // Ámbar oscuro
    Color(0xFFDC2626), // Rojo formal
    Color(0xFF0F766E), // Teal oscuro
    Color(0xFF9333EA), // Púrpura
  ];

  @override
  void initState() {
    super.initState();
    cargarReporte();
  }

  Future<void> cargarReporte({bool silencioso = false}) async {
    final esReporteMesSinFechas =
        selectedPeriod == 'month' && customStartDate == null && customEndDate == null;

    if (esReporteMesSinFechas && AppCache.reporteMes != null) {
      setState(() {
        reporte = AppCache.reporteMes;
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
      final data = await reportesService.getGeneralReport(
        period: selectedPeriod,
        startDate: customStartDate,
        endDate: customEndDate,
      );

      if (!mounted) return;

      if (esReporteMesSinFechas) {
        AppCache.guardarReporteMes(data);
      }

      setState(() {
        reporte = data;
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      if (reporte == null) {
        mostrarMensaje(error.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  void mostrarMensaje(String mensaje) {
    if (!mounted) return;

    AppFeedback.message(
      context: context,
      message: mensaje,
    );
  }

  dynamic _summaryValue(String key) {
    final summary = reporte?['summary'];
    if (summary is Map) {
      return summary[key];
    }
    return null;
  }

  List<Map<String, dynamic>> _chartItems(String key) {
    final charts = reporte?['charts'];
    if (charts is! Map) return [];

    final value = charts[key];
    if (value is! List) return [];

    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) => item['label'] != null)
        .toList();
  }

  List<Map<String, dynamic>> _tableItems(String key) {
    final tables = reporte?['tables'];
    if (tables is! Map) return [];

    final value = tables[key];
    if (value is! List) return [];

    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  String get _rangeLabel {
    final range = reporte?['range'];
    if (range is Map && range['label'] != null) {
      return range['label'].toString();
    }

    switch (selectedPeriod) {
      case 'today':
        return 'Hoy';
      case 'week':
        return 'Esta semana';
      case 'month':
        return 'Este mes';
      case 'year':
        return 'Este año';
      case 'custom':
        return 'Personalizado';
      default:
        return 'Reporte actual';
    }
  }

  double _num(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  int _int(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  String _formatNumber(num value) {
    final text = value.round().toString();
    final buffer = StringBuffer();
    int count = 0;

    for (int i = text.length - 1; i >= 0; i--) {
      buffer.write(text[i]);
      count++;

      if (count == 3 && i != 0) {
        buffer.write(',');
        count = 0;
      }
    }

    return buffer.toString().split('').reversed.join();
  }

  String _money(dynamic value) {
    return '₡${_formatNumber(_num(value))}';
  }

  String _moneyPdf(dynamic value) {
    return 'CRC ${_formatNumber(_num(value))}';
  }

  String _date(dynamic value) {
    if (value == null) return '-';

    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return value.toString();

    return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  }

  String _shortLabel(String value, {int max = 12}) {
    final text = value.trim();
    if (text.length <= max) return text;
    return '${text.substring(0, max)}...';
  }

  String _estadoProyecto(String value) {
    switch (value.toUpperCase()) {
      case 'PENDIENTE':
        return 'Pendiente';
      case 'ACTIVO':
        return 'Activo';
      case 'FINALIZADO':
        return 'Finalizado';
      case 'PAUSADO':
        return 'Pausado';
      case 'CANCELADO':
        return 'Cancelado';
      default:
        return value;
    }
  }

  String _metodoPago(String value) {
    switch (value.toUpperCase()) {
      case 'EFECTIVO':
        return 'Efectivo';
      case 'TRANSFERENCIA':
        return 'Transferencia';
      case 'SINPE_MOVIL':
        return 'SINPE Móvil';
      case 'TARJETA':
        return 'Tarjeta';
      case 'OTRO':
        return 'Otro';
      default:
        return value;
    }
  }

  Future<void> seleccionarPeriodo(String period) async {
    if (period == selectedPeriod && period != 'custom') return;

    if (period == 'custom') {
      final now = DateTime.now();
      final initialStart = customStartDate ?? DateTime(now.year, now.month, 1);
      final initialEnd = customEndDate ?? now;

      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 5),
        lastDate: DateTime(now.year + 1),
        initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
        helpText: 'Seleccione el periodo del reporte',
        cancelText: 'Cancelar',
        confirmText: 'Aplicar',
      );

      if (picked == null) return;

      setState(() {
        selectedPeriod = period;
        customStartDate = picked.start;
        customEndDate = picked.end;
      });
    } else {
      setState(() {
        selectedPeriod = period;
        customStartDate = null;
        customEndDate = null;
      });
    }

    await cargarReporte();
  }

  Future<void> exportarPdf() async {
    if (reporte == null) {
      mostrarMensaje('Primero debe cargar un reporte para poder exportarlo.');
      return;
    }

    if (exporting) return;

    setState(() {
      exporting = true;
    });

    // Esto deja que Flutter pinte el overlay antes de iniciar el trabajo pesado.
    await Future<void>.delayed(const Duration(milliseconds: 120));

    try {
      final logoBytes = await _loadPdfLogoBytes();
      final payload = <String, dynamic>{
        'reporte': _sanitizeForIsolate(reporte),
        'rangeLabel': _rangeLabel,
        'rangeDetailedLabel': _rangeDetailedLabel,
        'generatedAtIso': DateTime.now().toIso8601String(),
        'logoBytes': logoBytes,
      };

      // El PDF se arma fuera del hilo visual para que la app no se congele.
      final bytes = await compute(_buildReportPdfInBackground, payload);

      if (!mounted) return;

      await Printing.layoutPdf(
        name: 'reporte_gestor_proyectos_$selectedPeriod.pdf',
        onLayout: (_) async => bytes,
      );
    } catch (error) {
      mostrarMensaje('No se pudo generar el PDF: ${error.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          exporting = false;
        });
      }
    }
  }

  Future<Uint8List?> _loadPdfLogoBytes() async {
    try {
      final data = await rootBundle.load('assets/images/logo_icono.png');
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  dynamic _sanitizeForIsolate(dynamic value) {
    if (value == null || value is num || value is bool || value is String) {
      return value;
    }

    if (value is DateTime) {
      return value.toIso8601String();
    }

    if (value is Map) {
      return value.map((key, item) {
        return MapEntry(key.toString(), _sanitizeForIsolate(item));
      });
    }

    if (value is Iterable) {
      return value.map(_sanitizeForIsolate).toList();
    }

    return value.toString();
  }

  Widget _buildPeriodFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withAlpha(10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 620;

          final filters = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: periods.map((period) {
              final key = period['key']!;
              final label = period['label']!;
              final selected = selectedPeriod == key;

              return ChoiceChip(
                selected: selected,
                label: Text(label),
                onSelected: loading || exporting ? null : (_) => seleccionarPeriodo(key),
                selectedColor: AppColors.primaryLight,
                labelStyle: TextStyle(
                  color: selected ? AppColors.primary : AppColors.textMuted,
                  fontWeight: FontWeight.w800,
                ),
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              );
            }).toList(),
          );

          final exportButton = SizedBox(
            height: 46,
            child: FilledButton.icon(
              onPressed: loading || exporting || reporte == null ? null : exportarPdf,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: exporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined),
              label: Text(
                exporting ? 'Generando...' : 'Exportar PDF',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          );

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: double.infinity, child: exportButton),
                const SizedBox(height: 14),
                filters,
                const SizedBox(height: 10),
                _buildRangeText(),
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    filters,
                    const SizedBox(height: 10),
                    _buildRangeText(),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              exportButton,
            ],
          );
        },
      ),
    );
  }

  Widget _buildRangeText() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.date_range_outlined,
          size: 18,
          color: AppColors.textMuted,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'Periodo: $_rangeLabel',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required double width,
  }) {
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
              color: AppColors.primaryDark.withAlpha(12),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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

  Widget _buildMetrics() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1180
            ? 4
            : width >= 760
                ? 2
                : 1;
        final gap = 14.0;
        final itemWidth = (width - (gap * (columns - 1))) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            _metricCard(
              width: itemWidth,
              title: 'Ingresos del periodo',
              value: _money(_summaryValue('totalIngresosPeriodo')),
              subtitle: 'Pagos registrados en $_rangeLabel',
              icon: Icons.payments_outlined,
              color: AppColors.success,
            ),
            _metricCard(
              width: itemWidth,
              title: 'Saldo pendiente',
              value: _money(_summaryValue('saldoPendienteTotal')),
              subtitle: 'Total por cobrar',
              icon: Icons.account_balance_wallet_outlined,
              color: AppColors.warning,
            ),
            _metricCard(
              width: itemWidth,
              title: 'Proyectos activos',
              value: _int(_summaryValue('proyectosActivos')).toString(),
              subtitle: '${_int(_summaryValue('totalProyectos'))} proyectos registrados',
              icon: Icons.folder_open_outlined,
              color: AppColors.primary,
            ),
            _metricCard(
              width: itemWidth,
              title: 'Clientes nuevos',
              value: _int(_summaryValue('clientesNuevosPeriodo')).toString(),
              subtitle: '${_int(_summaryValue('totalClientes'))} clientes en total',
              icon: Icons.people_alt_outlined,
              color: const Color(0xFF7C3AED),
            ),
            _metricCard(
              width: itemWidth,
              title: 'Visitas realizadas',
              value: _int(_summaryValue('visitasRealizadasPeriodo')).toString(),
              subtitle: '${_int(_summaryValue('visitasPeriodo'))} visitas en el periodo',
              icon: Icons.event_available_outlined,
              color: const Color(0xFF0891B2),
            ),
            _metricCard(
              width: itemWidth,
              title: 'Recordatorios vencidos',
              value: _int(_summaryValue('recordatoriosVencidos')).toString(),
              subtitle: '${_int(_summaryValue('recordatoriosPendientes'))} pendientes',
              icon: Icons.notification_important_outlined,
              color: AppColors.danger,
            ),
          ],
        );
      },
    );
  }

  Widget _chartCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withAlpha(12),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Divider(color: AppColors.border, thickness: 1, height: 18),
          child,
        ],
      ),
    );
  }

  Widget _emptyChart(String text) {
    return SizedBox(
      height: 230,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insert_chart_outlined,
              size: 44,
              color: AppColors.textMuted.withAlpha(120),
            ),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _barChart(
    List<Map<String, dynamic>> items, {
    bool money = false,
    int maxItems = 8,
  }) {
    final visibleItems = items
        .where((item) => _num(item['value']) > 0)
        .take(maxItems)
        .toList();

    if (visibleItems.isEmpty) {
      return _emptyChart('No hay datos suficientes para mostrar esta gráfica.');
    }

    final points = visibleItems.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;

      return _ReportChartPoint(
        label: item['label']?.toString() ?? '-',
        value: _num(item['value']),
        color: chartColors[index % chartColors.length],
      );
    }).toList();

    final maxValue = points.fold<double>(
      0,
      (max, point) => math.max(max, point.value),
    );

    if (maxValue <= 0) {
      return _emptyChart('No hay datos suficientes para mostrar esta gráfica.');
    }

    return SizedBox(
      height: 320,
      width: double.infinity,
      child: CustomPaint(
        painter: _ReportBarChartPainter(
          points: points,
          maxValue: maxValue,
          formatValue: money ? _shortMoney : _shortNumber,
        ),
      ),
    );
  }

  String _shortNumber(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }
    return value.toStringAsFixed(0);
  }

  String _shortMoney(double value) {
    return '₡${_shortNumber(value)}';
  }

  Widget _donutChart(List<Map<String, dynamic>> items, {bool money = false}) {
    final filtered = items.where((item) => _num(item['value']) > 0).toList();

    final total = filtered.fold<double>(
      0,
      (sum, item) => sum + _num(item['value']),
    );

    if (filtered.isEmpty || total <= 0) {
      return _emptyChart('No hay datos suficientes para mostrar esta gráfica.');
    }

    final slices = filtered.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      final value = _num(item['value']);

      return _ReportChartSlice(
        label: item['label']?.toString() ?? 'Sin nombre',
        value: value,
        percent: total <= 0 ? 0 : value / total,
        color: chartColors[index % chartColors.length],
      );
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;

        final chart = SizedBox(
          width: compact ? double.infinity : 220,
          height: 220,
          child: CustomPaint(
            painter: _ReportDonutChartPainter(
              slices: slices,
              totalLabel: money ? _money(total) : _formatNumber(total),
            ),
          ),
        );

        final legend = ListView.separated(
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: slices.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final slice = slices[index];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: slice.color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        slice.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textDark,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      money ? _money(slice.value) : _formatNumber(slice.value),
                      style: TextStyle(
                        color: slice.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: slice.color.withAlpha(20),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${(slice.percent * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: slice.color,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: slice.percent.clamp(0.0, 1.0),
                    minHeight: 7,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      slice.color.withAlpha(200),
                    ),
                  ),
                ),
              ],
            );
          },
        );

        if (compact) {
          return SizedBox(
            height: 430,
            child: Column(
              children: [
                chart,
                const SizedBox(height: 16),
                Expanded(child: legend),
              ],
            ),
          );
        }

        return SizedBox(
          height: 270,
          child: Row(
            children: [
              chart,
              const SizedBox(width: 22),
              Expanded(child: legend),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCharts() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 980;
        final spacing = 16.0;
        final cardWidth = isWide
            ? (constraints.maxWidth - spacing) / 2
            : constraints.maxWidth;

        final cards = [
          SizedBox(
            width: cardWidth,
            child: _chartCard(
              title: 'Ingresos del periodo',
              subtitle: 'Dinero recibido agrupado por fecha.',
              child: _barChart(
                _chartItems('ingresosPorPeriodo'),
                money: true,
                maxItems: 10,
              ),
            ),
          ),
          SizedBox(
            width: cardWidth,
            child: _chartCard(
              title: 'Cobrado vs pendiente',
              subtitle: 'Comparación entre dinero cobrado y saldo pendiente.',
              child: _donutChart(
                _chartItems('cobradoVsPendiente'),
                money: true,
              ),
            ),
          ),
          SizedBox(
            width: cardWidth,
            child: _chartCard(
              title: 'Proyectos por estado',
              subtitle: 'Distribución actual de los proyectos registrados.',
              child: _donutChart(_chartItems('proyectosPorEstado')),
            ),
          ),
          SizedBox(
            width: cardWidth,
            child: _chartCard(
              title: 'Pagos por método',
              subtitle: 'Monto recibido según el método de pago.',
              child: _donutChart(
                _chartItems('pagosPorMetodo'),
                money: true,
              ),
            ),
          ),
          SizedBox(
            width: cardWidth,
            child: _chartCard(
              title: 'Visitas por estado',
              subtitle: 'Seguimiento de visitas del periodo seleccionado.',
              child: _donutChart(_chartItems('visitasPorEstado')),
            ),
          ),
          SizedBox(
            width: cardWidth,
            child: _chartCard(
              title: 'Top proyectos por ingreso',
              subtitle: 'Proyectos que más dinero han generado.',
              child: _barChart(
                _chartItems('topProyectosPorIngreso'),
                money: true,
                maxItems: 5,
              ),
            ),
          ),
          SizedBox(
            width: cardWidth,
            child: _chartCard(
              title: 'Clientes nuevos',
              subtitle: 'Crecimiento de clientes dentro del periodo.',
              child: _barChart(
                _chartItems('clientesNuevosPorPeriodo'),
                maxItems: 10,
              ),
            ),
          ),
          SizedBox(
            width: cardWidth,
            child: _chartCard(
              title: 'Recordatorios',
              subtitle: 'Pendientes, completados y vencidos.',
              child: _donutChart(_chartItems('recordatoriosPorEstado')),
            ),
          ),
        ];

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards,
        );
      },
    );
  }

  Widget _buildDataTables() {
    final pagos = _tableItems('pagosRecientes');
    final pendientes = _tableItems('proyectosConSaldoPendiente');
    final top = _tableItems('topProyectosPorIngreso');

    return Column(
      children: [
        _tableCard(
          title: 'Pagos recientes',
          subtitle: 'Últimos pagos registrados en el periodo seleccionado.',
          headers: const ['Fecha', 'Proyecto', 'Cliente', 'Método', 'Monto'],
          rows: pagos.map((pago) {
            return [
              _date(pago['fecha']),
              pago['proyecto']?.toString() ?? '-',
              pago['cliente']?.toString() ?? '-',
              _metodoPago(pago['metodo']?.toString() ?? '-'),
              _money(pago['monto']),
            ];
          }).toList(),
        ),
        const SizedBox(height: 16),
        _tableCard(
          title: 'Proyectos con saldo pendiente',
          subtitle: 'Proyectos donde todavía existe dinero por cobrar.',
          headers: const ['Proyecto', 'Cliente', 'Estado', 'Pagado', 'Pendiente'],
          rows: pendientes.map((proyecto) {
            return [
              proyecto['nombre']?.toString() ?? '-',
              proyecto['cliente']?.toString() ?? '-',
              _estadoProyecto(proyecto['estado']?.toString() ?? '-'),
              _money(proyecto['totalPagado']),
              _money(proyecto['saldoPendiente']),
            ];
          }).toList(),
        ),
        const SizedBox(height: 16),
        _tableCard(
          title: 'Top proyectos por ingreso',
          subtitle: 'Proyectos con mayor cantidad de dinero recibido.',
          headers: const ['Proyecto', 'Cliente', 'Monto total', 'Cobrado', 'Pendiente'],
          rows: top.map((proyecto) {
            return [
              proyecto['nombre']?.toString() ?? '-',
              proyecto['cliente']?.toString() ?? '-',
              _money(proyecto['montoTotal']),
              _money(proyecto['totalPagado']),
              _money(proyecto['saldoPendiente']),
            ];
          }).toList(),
        ),
      ],
    );
  }

  Widget _tableCard({
    required String title,
    required String subtitle,
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withAlpha(12),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 17,
              fontWeight: FontWeight.w900,
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
          const SizedBox(height: 14),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  'No hay registros para mostrar.',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppColors.primaryLight),
                border: TableBorder.all(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(14),
                ),
                columns: headers.map((header) {
                  return DataColumn(
                    label: Text(
                      header,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  );
                }).toList(),
                rows: rows.map((row) {
                  return DataRow(
                    cells: row.map((cell) {
                      return DataCell(
                        Text(
                          cell,
                          style: const TextStyle(
                            color: AppColors.textDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  //  PDF BUILD
  // ─────────────────────────────────────────────────────

  String get _rangeDetailedLabel {
    final range = reporte?['range'];

    if (range is Map) {
      final start = range['start'];
      final end = range['end'];

      if (start != null && end != null) {
        return '$_rangeLabel · ${_date(start)} al ${_date(end)}';
      }
    }

    return _rangeLabel;
  }

  Future<Uint8List> _buildPdf() async {
    final pdf = pw.Document();
    final now = DateTime.now();

    pw.MemoryImage? logoImage;

    try {
      final logoBytes = await rootBundle.load('assets/images/logo_icono.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {
      logoImage = null;
    }

    final ingresos = _chartItems('ingresosPorPeriodo');
    final cobradoVsPendiente = _chartItems('cobradoVsPendiente');
    final proyectosEstado = _chartItems('proyectosPorEstado');
    final pagosMetodo = _chartItems('pagosPorMetodo');
    final visitasEstado = _chartItems('visitasPorEstado');
    final recordatoriosEstado = _chartItems('recordatoriosPorEstado');
    final clientesNuevos = _chartItems('clientesNuevosPorPeriodo');
    final topProyectosChart = _chartItems('topProyectosPorIngreso');

    final topProyectos = _tableItems('topProyectosPorIngreso');
    final pendientes = _tableItems('proyectosConSaldoPendiente');
    final pagosRecientes = _tableItems('pagosRecientes');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 26, 28, 28),
        footer: (context) => _pdfFooter(context),
        build: (context) {
          return [
            _pdfHeader(now, logoImage),
            pw.SizedBox(height: 16),

            _pdfSectionTitle('Resumen ejecutivo'),
            pw.SizedBox(height: 8),
            _pdfMetricGrid(),

            pw.SizedBox(height: 14),
            _pdfInfoBox(
              'Este reporte fue generado con base en los datos registrados para el periodo seleccionado: $_rangeDetailedLabel. Las gráficas y tablas reflejan únicamente la información devuelta por el sistema para ese filtro.',
            ),

            pw.NewPage(),
            _pdfSectionTitle('Análisis gráfico'),
            pw.SizedBox(height: 12),

            _pdfBarChart(
              title: 'Ingresos del periodo',
              subtitle: 'Dinero recibido agrupado por fecha.',
              items: ingresos,
              money: true,
            ),
            pw.SizedBox(height: 14),

            _pdfDonutChart(
              title: 'Cobrado vs pendiente',
              subtitle: 'Comparación general entre dinero recibido y saldo por cobrar.',
              items: cobradoVsPendiente,
              money: true,
            ),
            pw.SizedBox(height: 14),

            _pdfDonutChart(
              title: 'Proyectos por estado',
              subtitle: 'Distribución actual de los proyectos registrados.',
              items: proyectosEstado,
            ),
            pw.SizedBox(height: 14),

            _pdfDonutChart(
              title: 'Pagos por método',
              subtitle: 'Monto recibido según el método de pago.',
              items: pagosMetodo,
              money: true,
            ),
            pw.SizedBox(height: 14),

            _pdfDonutChart(
              title: 'Visitas por estado',
              subtitle: 'Seguimiento de visitas del periodo seleccionado.',
              items: visitasEstado,
            ),
            pw.SizedBox(height: 14),

            _pdfBarChart(
              title: 'Clientes nuevos',
              subtitle: 'Crecimiento de clientes dentro del periodo seleccionado.',
              items: clientesNuevos,
            ),
            pw.SizedBox(height: 14),

            _pdfDonutChart(
              title: 'Recordatorios',
              subtitle: 'Estado general de recordatorios.',
              items: recordatoriosEstado,
            ),
            pw.SizedBox(height: 14),

            _pdfBarChart(
              title: 'Top proyectos por ingreso',
              subtitle: 'Proyectos con mayor dinero recibido.',
              items: topProyectosChart,
              money: true,
            ),

            pw.SizedBox(height: 24),
            _pdfSectionTitle('Tablas de detalle'),
            pw.SizedBox(height: 12),

            _pdfTable(
              title: 'Pagos recientes',
              headers: const ['Fecha', 'Proyecto', 'Cliente', 'Método', 'Monto'],
              rows: pagosRecientes.map((pago) {
                return [
                  _date(pago['fecha']),
                  pago['proyecto']?.toString() ?? '-',
                  pago['cliente']?.toString() ?? '-',
                  _metodoPago(pago['metodo']?.toString() ?? '-'),
                  _moneyPdf(pago['monto']),
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 16),

            _pdfTable(
              title: 'Proyectos con saldo pendiente',
              headers: const ['Proyecto', 'Cliente', 'Estado', 'Pagado', 'Pendiente'],
              rows: pendientes.map((proyecto) {
                return [
                  proyecto['nombre']?.toString() ?? '-',
                  proyecto['cliente']?.toString() ?? '-',
                  _estadoProyecto(proyecto['estado']?.toString() ?? '-'),
                  _moneyPdf(proyecto['totalPagado']),
                  _moneyPdf(proyecto['saldoPendiente']),
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 16),

            _pdfTable(
              title: 'Top proyectos por ingreso',
              headers: const ['Proyecto', 'Cliente', 'Monto total', 'Cobrado', 'Pendiente'],
              rows: topProyectos.map((proyecto) {
                return [
                  proyecto['nombre']?.toString() ?? '-',
                  proyecto['cliente']?.toString() ?? '-',
                  _moneyPdf(proyecto['montoTotal']),
                  _moneyPdf(proyecto['totalPagado']),
                  _moneyPdf(proyecto['saldoPendiente']),
                ];
              }).toList(),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _pdfHeader(DateTime now, pw.MemoryImage? logoImage) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(16),
        border: pw.Border.all(color: PdfColors.blue100, width: 1),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            width: 58,
            height: 58,
            padding: const pw.EdgeInsets.all(7),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(14),
              border: pw.Border.all(color: PdfColors.blue200),
            ),
            child: logoImage == null
                ? pw.Center(
                    child: pw.Text(
                      'GP',
                      style: pw.TextStyle(
                        color: PdfColors.blue800,
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  )
                : pw.Image(logoImage, fit: pw.BoxFit.contain),
          ),
          pw.SizedBox(width: 16),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Gestor de Proyectos',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue700,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'Reporte general de gestión',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  'Periodo analizado: $_rangeDetailedLabel',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.blueGrey700),
                ),
                pw.Text(
                  'Generado el ${_date(now.toIso8601String())}',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.blueGrey700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfFooter(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Gestor de Proyectos · Reporte generado automáticamente',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
          pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfInfoBox(String text) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey200),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 3,
            height: 36,
            decoration: pw.BoxDecoration(
              color: PdfColors.blue400,
              borderRadius: pw.BorderRadius.circular(2),
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Text(
              text,
              style: const pw.TextStyle(
                fontSize: 9,
                color: PdfColors.blueGrey700,
                lineSpacing: 2.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfSectionTitle(String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue600,
            letterSpacing: 1.2,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Container(
          width: double.infinity,
          height: 2,
          decoration: pw.BoxDecoration(
            gradient: const pw.LinearGradient(
              colors: [PdfColors.blue700, PdfColors.blue100],
            ),
            borderRadius: pw.BorderRadius.circular(1),
          ),
        ),
      ],
    );
  }

  pw.Widget _pdfMetricGrid() {
    final items = [
      _PdfMetric('Ingresos del periodo', _moneyPdf(_summaryValue('totalIngresosPeriodo')), true),
      _PdfMetric('Saldo pendiente', _moneyPdf(_summaryValue('saldoPendienteTotal')), false),
      _PdfMetric('Monto total proyectos', _moneyPdf(_summaryValue('montoTotalProyectos')), true),
      _PdfMetric('Total pagado histórico', _moneyPdf(_summaryValue('totalPagadoHistorico')), true),
      _PdfMetric('Clientes nuevos', _int(_summaryValue('clientesNuevosPeriodo')).toString(), false),
      _PdfMetric('Proyectos activos', _int(_summaryValue('proyectosActivos')).toString(), false),
      _PdfMetric('Visitas realizadas', _int(_summaryValue('visitasRealizadasPeriodo')).toString(), false),
      _PdfMetric('Recordatorios vencidos', _int(_summaryValue('recordatoriosVencidos')).toString(), false),
    ];

    final rows = <pw.Widget>[];
    for (int i = 0; i < items.length; i += 4) {
      final rowItems = items.skip(i).take(4).toList();
      rows.add(
        pw.Row(
          children: List.generate(4, (j) {
            if (j >= rowItems.length) {
              return pw.Expanded(child: pw.SizedBox());
            }
            final metric = rowItems[j];
            return pw.Expanded(
              child: pw.Container(
                margin: pw.EdgeInsets.only(right: j < 3 ? 8 : 0),
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: pw.BoxDecoration(
                  color: metric.isMain ? PdfColors.blue50 : PdfColors.grey50,
                  borderRadius: pw.BorderRadius.circular(10),
                  border: pw.Border.all(
                    color: metric.isMain ? PdfColors.blue200 : PdfColors.grey200,
                    width: 0.8,
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      metric.label,
                      maxLines: 2,
                      style: const pw.TextStyle(
                        fontSize: 7.5,
                        color: PdfColors.blueGrey600,
                        lineSpacing: 1.2,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      metric.value,
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: metric.isMain ? PdfColors.blue800 : PdfColors.blueGrey800,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      );
      if (i + 4 < items.length) rows.add(pw.SizedBox(height: 8));
    }

    return pw.Column(children: rows);
  }

  // ─── PDF BAR CHART (mejorado) ────────────────────────────────────────────────

  /// Colores PDF formales paralelos a chartColors
  static const _pdfBarColors = [
    PdfColors.blue700,
    PdfColors.cyan700,
    PdfColors.green700,
    PdfColors.purple700,
    PdfColors.amber700,
    PdfColors.red700,
    PdfColors.teal700,
    PdfColors.deepPurple700,
  ];

  static const _pdfBarBgColors = [
    PdfColors.blue50,
    PdfColors.cyan50,
    PdfColors.green50,
    PdfColors.purple50,
    PdfColors.amber50,
    PdfColors.red50,
    PdfColors.teal50,
    PdfColors.deepPurple50,
  ];

  pw.Widget _pdfBarChart({
    required String title,
    required List<Map<String, dynamic>> items,
    String? subtitle,
    bool money = false,
  }) {
    final filtered = items
        .where((item) => _num(item['value']) > 0)
        .take(8)
        .toList();

    if (filtered.isEmpty) {
      return _pdfEmptyChart(title);
    }

    final maxValue = filtered.fold<double>(
      0,
      (prev, item) => math.max(prev, _num(item['value'])),
    );

    final total = filtered.fold<double>(0, (s, i) => s + _num(i['value']));

    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: PdfColors.grey200, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header del card
          pw.Container(
            padding: const pw.EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: const pw.BoxDecoration(
              color: PdfColors.grey50,
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        title,
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blueGrey900,
                        ),
                      ),
                      if (subtitle != null) ...[
                        pw.SizedBox(height: 2),
                        pw.Text(
                          subtitle,
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.blueGrey500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue700,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Text(
                    money ? _moneyPdf(total) : _formatNumber(total),
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Línea separadora
          pw.Container(height: 0.8, color: PdfColors.grey200),
          // Filas de barras
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: pw.Column(
              children: filtered.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final label = item['label']?.toString() ?? '-';
                final value = _num(item['value']);
                final percent = maxValue <= 0 ? 0.0 : value / maxValue;
                final barPct = money
                    ? (total <= 0 ? 0.0 : value / total)
                    : percent;

                final fgColor = _pdfBarColors[index % _pdfBarColors.length];
                final bgColor = _pdfBarBgColors[index % _pdfBarBgColors.length];

                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 9),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      // Índice
                      pw.Container(
                        width: 18,
                        height: 18,
                        decoration: pw.BoxDecoration(
                          color: bgColor,
                          borderRadius: pw.BorderRadius.circular(5),
                          border: pw.Border.all(color: fgColor, width: 0.5),
                        ),
                        child: pw.Center(
                          child: pw.Text(
                            '${index + 1}',
                            style: pw.TextStyle(
                              fontSize: 7,
                              fontWeight: pw.FontWeight.bold,
                              color: fgColor,
                            ),
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 7),
                      // Label
                      pw.SizedBox(
                        width: 95,
                        child: pw.Text(
                          _shortLabel(label, max: 19),
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.blueGrey700,
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 6),
                      // Barra de fondo
                      pw.Expanded(
                        child: pw.Stack(
                          children: [
                            pw.Container(
                              height: 13,
                              decoration: pw.BoxDecoration(
                                color: PdfColors.grey100,
                                borderRadius: pw.BorderRadius.circular(7),
                              ),
                            ),
                            pw.Container(
                              height: 13,
                              width: 200 * percent,
                              decoration: pw.BoxDecoration(
                                color: fgColor,
                                borderRadius: pw.BorderRadius.circular(7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 8),
                      // Valor
                      pw.SizedBox(
                        width: 68,
                        child: pw.Text(
                          money ? _moneyPdf(value) : _formatNumber(value),
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: fgColor,
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 6),
                      // Porcentaje
                      pw.SizedBox(
                        width: 32,
                        child: pw.Text(
                          '${(barPct * 100).toStringAsFixed(0)}%',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blueGrey400,
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
      ),
    );
  }

  // ─── PDF DONUT CHART (mejorado) ──────────────────────────────────────────────

  pw.Widget _pdfDonutChart({
    required String title,
    required List<Map<String, dynamic>> items,
    String? subtitle,
    bool money = false,
  }) {
    final filtered = items
        .where((item) => _num(item['value']) > 0)
        .take(6)
        .toList();

    if (filtered.isEmpty) {
      return _pdfEmptyChart(title);
    }

    final total = filtered.fold<double>(
      0,
      (sum, item) => sum + _num(item['value']),
    );

    final svg = _buildPdfDonutSvg(
      items: filtered,
      totalLabel: money ? _moneyPdf(total) : _formatNumber(total),
    );

    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: PdfColors.grey200, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header
          pw.Container(
            padding: const pw.EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: const pw.BoxDecoration(
              color: PdfColors.grey50,
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        title,
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blueGrey900,
                        ),
                      ),
                      if (subtitle != null) ...[
                        pw.SizedBox(height: 2),
                        pw.Text(
                          subtitle,
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.blueGrey500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                pw.Text(
                  '${filtered.length} categorías',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.blueGrey400,
                  ),
                ),
              ],
            ),
          ),
          // Línea separadora
          pw.Container(height: 0.8, color: PdfColors.grey200),
          // Contenido
          pw.Padding(
            padding: const pw.EdgeInsets.all(14),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Donut SVG
                pw.SizedBox(
                  width: 160,
                  height: 160,
                  child: pw.SvgImage(svg: svg),
                ),
                pw.SizedBox(width: 16),
                // Leyenda
                pw.Expanded(
                  child: pw.Column(
                    children: filtered.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      final value = _num(item['value']);
                      final percent = total <= 0 ? 0.0 : value / total;
                      final label = item['label']?.toString() ?? '-';
                      final colorHex = _colorToHex(chartColors[index % chartColors.length]);
                      final fgColor = PdfColor.fromHex(colorHex);
                      final bgColor = _pdfBarBgColors[index % _pdfBarBgColors.length];

                      return pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 10),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Row(
                              children: [
                                pw.Container(
                                  width: 10,
                                  height: 10,
                                  decoration: pw.BoxDecoration(
                                    color: fgColor,
                                    borderRadius: pw.BorderRadius.circular(3),
                                  ),
                                ),
                                pw.SizedBox(width: 7),
                                pw.Expanded(
                                  child: pw.Text(
                                    _shortLabel(label, max: 20),
                                    style: const pw.TextStyle(
                                      fontSize: 8.5,
                                      color: PdfColors.blueGrey800,
                                    ),
                                  ),
                                ),
                                pw.SizedBox(width: 6),
                                pw.Text(
                                  money ? _moneyPdf(value) : _formatNumber(value),
                                  style: pw.TextStyle(
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold,
                                    color: fgColor,
                                  ),
                                ),
                                pw.SizedBox(width: 6),
                                pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: pw.BoxDecoration(
                                    color: bgColor,
                                    borderRadius: pw.BorderRadius.circular(4),
                                  ),
                                  child: pw.Text(
                                    '${(percent * 100).toStringAsFixed(1)}%',
                                    style: pw.TextStyle(
                                      fontSize: 7.5,
                                      fontWeight: pw.FontWeight.bold,
                                      color: fgColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            pw.SizedBox(height: 4),
                            // Mini barra de progreso
                            pw.ClipRRect(
                              horizontalRadius: 2,
                              verticalRadius: 2,
                              child: pw.Row(
                                children: [
                                  if (percent > 0)
                                    pw.Flexible(
                                      flex: (percent * 1000).round().clamp(1, 999),
                                      child: pw.Container(
                                        height: 4,
                                        color: fgColor,
                                      ),
                                    ),
                                  if (percent < 1)
                                    pw.Flexible(
                                      flex: ((1 - percent) * 1000).round().clamp(1, 999),
                                      child: pw.Container(
                                        height: 4,
                                        color: PdfColors.grey100,
                                      ),
                                    ),
                                ],
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
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfEmptyChart(String title) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColors.grey200, width: 0.8),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: 3,
            height: 28,
            decoration: pw.BoxDecoration(
              color: PdfColors.grey300,
              borderRadius: pw.BorderRadius.circular(2),
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey600,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Sin datos para graficar en este periodo.',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── SVG DONUT (mejorado) ────────────────────────────────────────────────────

  String _buildPdfDonutSvg({
    required List<Map<String, dynamic>> items,
    required String totalLabel,
  }) {
    final total = items.fold<double>(
      0,
      (sum, item) => sum + _num(item['value']),
    );

    const size = 200.0;
    const center = 100.0;
    const radius = 56.0;
    const strokeWidth = 22.0;
    const gapAngle = 0.06; // gap entre segmentos en radianes

    final buffer = StringBuffer();

    buffer.writeln('<svg xmlns="http://www.w3.org/2000/svg" '
        'width="$size" height="$size" viewBox="0 0 $size $size">');

    // Fondo blanco
    buffer.writeln('<rect width="$size" height="$size" fill="white"/>');

    // Sombra suave del anillo
    buffer.writeln(
      '<circle cx="$center" cy="$center" r="${radius + strokeWidth / 2 + 2}" '
      'fill="none" stroke="#F1F5F9" stroke-width="2"/>',
    );

    // Track gris
    buffer.writeln(
      '<circle cx="$center" cy="$center" r="$radius" '
      'fill="none" stroke="#E2E8F0" stroke-width="$strokeWidth"/>',
    );

    // Segmentos
    double startAngle = -math.pi / 2;

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final value = _num(item['value']);
      if (value <= 0) continue;

      final percent = total <= 0 ? 0.0 : value / total;
      final sweepAngle = math.pi * 2 * percent - gapAngle;
      if (sweepAngle <= 0) {
        startAngle += math.pi * 2 * percent;
        continue;
      }

      final actualStart = startAngle + gapAngle / 2;
      final endAngle = actualStart + sweepAngle;

      final x1 = center + radius * math.cos(actualStart);
      final y1 = center + radius * math.sin(actualStart);
      final x2 = center + radius * math.cos(endAngle);
      final y2 = center + radius * math.sin(endAngle);

      final largeArc = sweepAngle > math.pi ? 1 : 0;
      final colorHex = _colorToHex(chartColors[i % chartColors.length]);

      buffer.writeln(
        '<path d="M $x1 $y1 A $radius $radius 0 $largeArc 1 $x2 $y2" '
        'fill="none" stroke="$colorHex" stroke-width="$strokeWidth" '
        'stroke-linecap="butt"/>',
      );

      startAngle += math.pi * 2 * percent;
    }

    // Círculo interior blanco para efecto donut limpio
    buffer.writeln(
      '<circle cx="$center" cy="$center" r="${radius - strokeWidth / 2}" '
      'fill="white"/>',
    );

    // Texto "TOTAL" pequeño
    buffer.writeln(
      '<text x="$center" y="${center - 12}" '
      'text-anchor="middle" font-size="9" font-family="Arial, Helvetica, sans-serif" '
      'font-weight="bold" fill="#94A3B8" letter-spacing="1">TOTAL</text>',
    );

    // Línea separadora sutil
    buffer.writeln(
      '<line x1="${center - 24}" y1="${center - 4}" '
      'x2="${center + 24}" y2="${center - 4}" '
      'stroke="#E2E8F0" stroke-width="0.8"/>',
    );

    // Valor total — si es largo, partirlo
    final labelShort = totalLabel.length > 14
        ? totalLabel.substring(0, 14)
        : totalLabel;

    buffer.writeln(
      '<text x="$center" y="${center + 10}" '
      'text-anchor="middle" font-size="11" font-family="Arial, Helvetica, sans-serif" '
      'font-weight="bold" fill="#0F172A">$labelShort</text>',
    );

    buffer.writeln('</svg>');

    return buffer.toString();
  }

  String _colorToHex(Color color) {
    final hex = color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2);
    return '#${hex.toUpperCase()}';
  }

  pw.Widget _pdfTable({
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    if (rows.isEmpty) {
      return _pdfEmptyChart(title);
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blueGrey900,
          ),
        ),
        pw.SizedBox(height: 7),
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: rows.take(10).toList(),
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
            fontSize: 8,
          ),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
          cellStyle: const pw.TextStyle(fontSize: 7.5),
          oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
          cellAlignment: pw.Alignment.centerLeft,
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          border: pw.TableBorder.all(color: PdfColors.grey200, width: 0.5),
        ),
      ],
    );
  }

  Widget _buildContent() {
    final content = loading
        ? const AppLoading(
            key: ValueKey('reports-loading'),
            text: 'Cargando reportes...',
          )
        : RefreshIndicator(
            key: const ValueKey('reports-content'),
            onRefresh: cargarReporte,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPeriodFilters(),
                  const SizedBox(height: 20),
                  RepaintBoundary(child: _buildMetrics()),
                  const SizedBox(height: 20),
                  RepaintBoundary(child: _buildCharts()),
                  const SizedBox(height: 20),
                  _buildDataTables(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          );

    return Stack(
      children: [
        AbsorbPointer(
          absorbing: exporting,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: content,
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !exporting,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: exporting ? _buildExportingOverlay() : const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExportingOverlay() {
    return Container(
      key: const ValueKey('exporting-overlay'),
      color: Colors.white.withAlpha(210),
      child: Center(
          child: Container(
            width: 280,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryDark.withAlpha(20),
                  blurRadius: 28,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                SizedBox(height: 16),
                Text(
                  'Generando PDF',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Preparando gráficas, porcentajes y tablas...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildContent();
  }
}

// ─────────────────────────────────────────────────────
//  PDF BUILD EN SEGUNDO HILO / ISOLATE
// ─────────────────────────────────────────────────────

Future<Uint8List> _buildReportPdfInBackground(Map<String, dynamic> payload) async {
  final reporte = Map<String, dynamic>.from(payload['reporte'] as Map);
  final rangeDetailedLabel = payload['rangeDetailedLabel']?.toString() ?? 'Reporte actual';
  final generatedAtIso = payload['generatedAtIso']?.toString() ?? DateTime.now().toIso8601String();
  final logoBytes = payload['logoBytes'] is Uint8List ? payload['logoBytes'] as Uint8List : null;

  final pdf = pw.Document();
  final now = DateTime.tryParse(generatedAtIso) ?? DateTime.now();
  final logoImage = logoBytes == null ? null : pw.MemoryImage(logoBytes);

  final ingresos = _isoChartItems(reporte, 'ingresosPorPeriodo');
  final cobradoVsPendiente = _isoChartItems(reporte, 'cobradoVsPendiente');
  final proyectosEstado = _isoChartItems(reporte, 'proyectosPorEstado');
  final pagosMetodo = _isoChartItems(reporte, 'pagosPorMetodo');
  final visitasEstado = _isoChartItems(reporte, 'visitasPorEstado');
  final recordatoriosEstado = _isoChartItems(reporte, 'recordatoriosPorEstado');
  final clientesNuevos = _isoChartItems(reporte, 'clientesNuevosPorPeriodo');
  final topProyectosChart = _isoChartItems(reporte, 'topProyectosPorIngreso');

  final topProyectos = _isoTableItems(reporte, 'topProyectosPorIngreso');
  final pendientes = _isoTableItems(reporte, 'proyectosConSaldoPendiente');
  final pagosRecientes = _isoTableItems(reporte, 'pagosRecientes');

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 26, 28, 28),
      footer: _isoPdfFooter,
      build: (context) {
        return [
          _isoPdfHeader(now, logoImage, rangeDetailedLabel),
          pw.SizedBox(height: 16),
          _isoPdfSectionTitle('Resumen ejecutivo'),
          pw.SizedBox(height: 8),
          _isoPdfMetricGrid(reporte),
          pw.SizedBox(height: 14),
          _isoPdfInfoBox(
            'Este reporte fue generado con base en los datos registrados para el periodo seleccionado: $rangeDetailedLabel. Las gráficas y tablas reflejan únicamente la información devuelta por el sistema para ese filtro.',
          ),
          pw.NewPage(),
          _isoPdfSectionTitle('Análisis gráfico'),
          pw.SizedBox(height: 12),
          _isoPdfBarChart(
            title: 'Ingresos del periodo',
            subtitle: 'Dinero recibido agrupado por fecha.',
            items: ingresos,
            money: true,
          ),
          pw.SizedBox(height: 14),
          _isoPdfDonutChart(
            title: 'Cobrado vs pendiente',
            subtitle: 'Comparación general entre dinero recibido y saldo por cobrar.',
            items: cobradoVsPendiente,
            money: true,
          ),
          pw.SizedBox(height: 14),
          _isoPdfDonutChart(
            title: 'Proyectos por estado',
            subtitle: 'Distribución actual de los proyectos registrados.',
            items: proyectosEstado,
          ),
          pw.SizedBox(height: 14),
          _isoPdfDonutChart(
            title: 'Pagos por método',
            subtitle: 'Monto recibido según el método de pago.',
            items: pagosMetodo,
            money: true,
          ),
          pw.SizedBox(height: 14),
          _isoPdfDonutChart(
            title: 'Visitas por estado',
            subtitle: 'Seguimiento de visitas del periodo seleccionado.',
            items: visitasEstado,
          ),
          pw.SizedBox(height: 14),
          _isoPdfBarChart(
            title: 'Clientes nuevos',
            subtitle: 'Crecimiento de clientes dentro del periodo seleccionado.',
            items: clientesNuevos,
          ),
          pw.SizedBox(height: 14),
          _isoPdfDonutChart(
            title: 'Recordatorios',
            subtitle: 'Estado general de recordatorios.',
            items: recordatoriosEstado,
          ),
          pw.SizedBox(height: 14),
          _isoPdfBarChart(
            title: 'Top proyectos por ingreso',
            subtitle: 'Proyectos con mayor dinero recibido.',
            items: topProyectosChart,
            money: true,
          ),
          pw.SizedBox(height: 24),
          _isoPdfSectionTitle('Tablas de detalle'),
          pw.SizedBox(height: 12),
          _isoPdfTable(
            title: 'Pagos recientes',
            headers: const ['Fecha', 'Proyecto', 'Cliente', 'Método', 'Monto'],
            rows: pagosRecientes.map((pago) {
              return [
                _isoDate(pago['fecha']),
                pago['proyecto']?.toString() ?? '-',
                pago['cliente']?.toString() ?? '-',
                _isoMetodoPago(pago['metodo']?.toString() ?? '-'),
                _isoMoneyPdf(pago['monto']),
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 16),
          _isoPdfTable(
            title: 'Proyectos con saldo pendiente',
            headers: const ['Proyecto', 'Cliente', 'Estado', 'Pagado', 'Pendiente'],
            rows: pendientes.map((proyecto) {
              return [
                proyecto['nombre']?.toString() ?? '-',
                proyecto['cliente']?.toString() ?? '-',
                _isoEstadoProyecto(proyecto['estado']?.toString() ?? '-'),
                _isoMoneyPdf(proyecto['totalPagado']),
                _isoMoneyPdf(proyecto['saldoPendiente']),
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 16),
          _isoPdfTable(
            title: 'Top proyectos por ingreso',
            headers: const ['Proyecto', 'Cliente', 'Monto total', 'Cobrado', 'Pendiente'],
            rows: topProyectos.map((proyecto) {
              return [
                proyecto['nombre']?.toString() ?? '-',
                proyecto['cliente']?.toString() ?? '-',
                _isoMoneyPdf(proyecto['montoTotal']),
                _isoMoneyPdf(proyecto['totalPagado']),
                _isoMoneyPdf(proyecto['saldoPendiente']),
              ];
            }).toList(),
          ),
        ];
      },
    ),
  );

  return pdf.save();
}

const List<String> _isoChartHexColors = [
  '#2563EB',
  '#0891B2',
  '#059669',
  '#7C3AED',
  '#D97706',
  '#DC2626',
  '#0F766E',
  '#9333EA',
];

const List<PdfColor> _isoPdfBarColors = [
  PdfColors.blue700,
  PdfColors.cyan700,
  PdfColors.green700,
  PdfColors.purple700,
  PdfColors.amber700,
  PdfColors.red700,
  PdfColors.teal700,
  PdfColors.deepPurple700,
];

const List<PdfColor> _isoPdfBarBgColors = [
  PdfColors.blue50,
  PdfColors.cyan50,
  PdfColors.green50,
  PdfColors.purple50,
  PdfColors.amber50,
  PdfColors.red50,
  PdfColors.teal50,
  PdfColors.deepPurple50,
];

double _isoNum(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

int _isoInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}

String _isoFormatNumber(num value) {
  final text = value.round().toString();
  final buffer = StringBuffer();
  int count = 0;

  for (int i = text.length - 1; i >= 0; i--) {
    buffer.write(text[i]);
    count++;

    if (count == 3 && i != 0) {
      buffer.write(',');
      count = 0;
    }
  }

  return buffer.toString().split('').reversed.join();
}

String _isoMoneyPdf(dynamic value) {
  return 'CRC ${_isoFormatNumber(_isoNum(value))}';
}

String _isoDate(dynamic value) {
  if (value == null) return '-';

  final parsed = DateTime.tryParse(value.toString());
  if (parsed == null) return value.toString();

  return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
}

String _isoShortLabel(String value, {int max = 12}) {
  final text = value.trim();
  if (text.length <= max) return text;
  return '${text.substring(0, max)}...';
}

String _isoEstadoProyecto(String value) {
  switch (value.toUpperCase()) {
    case 'PENDIENTE':
      return 'Pendiente';
    case 'ACTIVO':
      return 'Activo';
    case 'FINALIZADO':
      return 'Finalizado';
    case 'PAUSADO':
      return 'Pausado';
    case 'CANCELADO':
      return 'Cancelado';
    default:
      return value;
  }
}

String _isoMetodoPago(String value) {
  switch (value.toUpperCase()) {
    case 'EFECTIVO':
      return 'Efectivo';
    case 'TRANSFERENCIA':
      return 'Transferencia';
    case 'SINPE_MOVIL':
      return 'SINPE Móvil';
    case 'TARJETA':
      return 'Tarjeta';
    case 'OTRO':
      return 'Otro';
    default:
      return value;
  }
}

dynamic _isoSummaryValue(Map<String, dynamic> reporte, String key) {
  final summary = reporte['summary'];
  if (summary is Map) return summary[key];
  return null;
}

List<Map<String, dynamic>> _isoChartItems(Map<String, dynamic> reporte, String key) {
  final charts = reporte['charts'];
  if (charts is! Map) return [];

  final value = charts[key];
  if (value is! List) return [];

  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .where((item) => item['label'] != null)
      .toList();
}

List<Map<String, dynamic>> _isoTableItems(Map<String, dynamic> reporte, String key) {
  final tables = reporte['tables'];
  if (tables is! Map) return [];

  final value = tables[key];
  if (value is! List) return [];

  return value.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
}

pw.Widget _isoPdfHeader(DateTime now, pw.MemoryImage? logoImage, String rangeDetailedLabel) {
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(18),
    decoration: pw.BoxDecoration(
      color: PdfColors.blue50,
      borderRadius: pw.BorderRadius.circular(16),
      border: pw.Border.all(color: PdfColors.blue100, width: 1),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(
          width: 58,
          height: 58,
          padding: const pw.EdgeInsets.all(7),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            borderRadius: pw.BorderRadius.circular(14),
            border: pw.Border.all(color: PdfColors.blue200),
          ),
          child: logoImage == null
              ? pw.Center(
                  child: pw.Text(
                    'GP',
                    style: pw.TextStyle(
                      color: PdfColors.blue800,
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                )
              : pw.Image(logoImage, fit: pw.BoxFit.contain),
        ),
        pw.SizedBox(width: 16),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Gestor de Proyectos',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue700,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'Reporte general de gestión',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'Periodo analizado: $rangeDetailedLabel',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.blueGrey700),
              ),
              pw.Text(
                'Generado el ${_isoDate(now.toIso8601String())}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.blueGrey700),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

pw.Widget _isoPdfFooter(pw.Context context) {
  return pw.Container(
    padding: const pw.EdgeInsets.only(top: 8),
    decoration: const pw.BoxDecoration(
      border: pw.Border(
        top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
      ),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'Gestor de Proyectos · Reporte generado automáticamente',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
        pw.Text(
          'Página ${context.pageNumber} de ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
      ],
    ),
  );
}

pw.Widget _isoPdfInfoBox(String text) {
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: PdfColors.grey50,
      borderRadius: pw.BorderRadius.circular(8),
      border: pw.Border.all(color: PdfColors.grey200),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 3,
          height: 36,
          decoration: pw.BoxDecoration(
            color: PdfColors.blue400,
            borderRadius: pw.BorderRadius.circular(2),
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: pw.Text(
            text,
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.blueGrey700,
              lineSpacing: 2.5,
            ),
          ),
        ),
      ],
    ),
  );
}

pw.Widget _isoPdfSectionTitle(String title) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        title.toUpperCase(),
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blue600,
          letterSpacing: 1.2,
        ),
      ),
      pw.SizedBox(height: 4),
      pw.Container(
        width: double.infinity,
        height: 2,
        decoration: pw.BoxDecoration(
          gradient: const pw.LinearGradient(
            colors: [PdfColors.blue700, PdfColors.blue100],
          ),
          borderRadius: pw.BorderRadius.circular(1),
        ),
      ),
    ],
  );
}

pw.Widget _isoPdfMetricGrid(Map<String, dynamic> reporte) {
  final items = [
    _PdfMetric('Ingresos del periodo', _isoMoneyPdf(_isoSummaryValue(reporte, 'totalIngresosPeriodo')), true),
    _PdfMetric('Saldo pendiente', _isoMoneyPdf(_isoSummaryValue(reporte, 'saldoPendienteTotal')), false),
    _PdfMetric('Monto total proyectos', _isoMoneyPdf(_isoSummaryValue(reporte, 'montoTotalProyectos')), true),
    _PdfMetric('Total pagado histórico', _isoMoneyPdf(_isoSummaryValue(reporte, 'totalPagadoHistorico')), true),
    _PdfMetric('Clientes nuevos', _isoInt(_isoSummaryValue(reporte, 'clientesNuevosPeriodo')).toString(), false),
    _PdfMetric('Proyectos activos', _isoInt(_isoSummaryValue(reporte, 'proyectosActivos')).toString(), false),
    _PdfMetric('Visitas realizadas', _isoInt(_isoSummaryValue(reporte, 'visitasRealizadasPeriodo')).toString(), false),
    _PdfMetric('Recordatorios vencidos', _isoInt(_isoSummaryValue(reporte, 'recordatoriosVencidos')).toString(), false),
  ];

  final rows = <pw.Widget>[];
  for (int i = 0; i < items.length; i += 4) {
    final rowItems = items.skip(i).take(4).toList();
    rows.add(
      pw.Row(
        children: List.generate(4, (j) {
          if (j >= rowItems.length) {
            return pw.Expanded(child: pw.SizedBox());
          }
          final metric = rowItems[j];
          return pw.Expanded(
            child: pw.Container(
              margin: pw.EdgeInsets.only(right: j < 3 ? 8 : 0),
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: pw.BoxDecoration(
                color: metric.isMain ? PdfColors.blue50 : PdfColors.grey50,
                borderRadius: pw.BorderRadius.circular(10),
                border: pw.Border.all(
                  color: metric.isMain ? PdfColors.blue200 : PdfColors.grey200,
                  width: 0.8,
                ),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    metric.label,
                    maxLines: 2,
                    style: const pw.TextStyle(
                      fontSize: 7.5,
                      color: PdfColors.blueGrey600,
                      lineSpacing: 1.2,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    metric.value,
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: metric.isMain ? PdfColors.blue800 : PdfColors.blueGrey800,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
    if (i + 4 < items.length) rows.add(pw.SizedBox(height: 8));
  }

  return pw.Column(children: rows);
}

pw.Widget _isoPdfBarChart({
  required String title,
  required List<Map<String, dynamic>> items,
  String? subtitle,
  bool money = false,
}) {
  final filtered = items.where((item) => _isoNum(item['value']) > 0).take(8).toList();

  if (filtered.isEmpty) {
    return _isoPdfEmptyChart(title);
  }

  final maxValue = filtered.fold<double>(0, (prev, item) => math.max(prev, _isoNum(item['value'])));
  final total = filtered.fold<double>(0, (s, i) => s + _isoNum(i['value']));

  return pw.Container(
    width: double.infinity,
    decoration: pw.BoxDecoration(
      color: PdfColors.white,
      borderRadius: pw.BorderRadius.circular(12),
      border: pw.Border.all(color: PdfColors.grey200, width: 0.8),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: const pw.BoxDecoration(color: PdfColors.grey50),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      title,
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey900,
                      ),
                    ),
                    if (subtitle != null) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        subtitle,
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey500),
                      ),
                    ],
                  ],
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue700,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  money ? _isoMoneyPdf(total) : _isoFormatNumber(total),
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        pw.Container(height: 0.8, color: PdfColors.grey200),
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: pw.Column(
            children: filtered.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final label = item['label']?.toString() ?? '-';
              final value = _isoNum(item['value']);
              final percent = maxValue <= 0 ? 0.0 : value / maxValue;
              final barPct = money ? (total <= 0 ? 0.0 : value / total) : percent;
              final fgColor = _isoPdfBarColors[index % _isoPdfBarColors.length];
              final bgColor = _isoPdfBarBgColors[index % _isoPdfBarBgColors.length];

              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 9),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Container(
                      width: 18,
                      height: 18,
                      decoration: pw.BoxDecoration(
                        color: bgColor,
                        borderRadius: pw.BorderRadius.circular(5),
                        border: pw.Border.all(color: fgColor, width: 0.5),
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          '${index + 1}',
                          style: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                            color: fgColor,
                          ),
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 7),
                    pw.SizedBox(
                      width: 95,
                      child: pw.Text(
                        _isoShortLabel(label, max: 19),
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey700),
                      ),
                    ),
                    pw.SizedBox(width: 6),
                    pw.Expanded(
                      child: pw.Stack(
                        children: [
                          pw.Container(
                            height: 13,
                            decoration: pw.BoxDecoration(
                              color: PdfColors.grey100,
                              borderRadius: pw.BorderRadius.circular(7),
                            ),
                          ),
                          pw.Container(
                            height: 13,
                            width: 200 * percent,
                            decoration: pw.BoxDecoration(
                              color: fgColor,
                              borderRadius: pw.BorderRadius.circular(7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.SizedBox(
                      width: 68,
                      child: pw.Text(
                        money ? _isoMoneyPdf(value) : _isoFormatNumber(value),
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: fgColor,
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 6),
                    pw.SizedBox(
                      width: 32,
                      child: pw.Text(
                        '${(barPct * 100).toStringAsFixed(0)}%',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blueGrey400,
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
    ),
  );
}

pw.Widget _isoPdfDonutChart({
  required String title,
  required List<Map<String, dynamic>> items,
  String? subtitle,
  bool money = false,
}) {
  final filtered = items.where((item) => _isoNum(item['value']) > 0).take(6).toList();

  if (filtered.isEmpty) {
    return _isoPdfEmptyChart(title);
  }

  final total = filtered.fold<double>(0, (sum, item) => sum + _isoNum(item['value']));
  final svg = _isoBuildPdfDonutSvg(
    items: filtered,
    totalLabel: money ? _isoMoneyPdf(total) : _isoFormatNumber(total),
  );

  return pw.Container(
    width: double.infinity,
    decoration: pw.BoxDecoration(
      color: PdfColors.white,
      borderRadius: pw.BorderRadius.circular(12),
      border: pw.Border.all(color: PdfColors.grey200, width: 0.8),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: const pw.BoxDecoration(color: PdfColors.grey50),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      title,
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey900,
                      ),
                    ),
                    if (subtitle != null) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        subtitle,
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey500),
                      ),
                    ],
                  ],
                ),
              ),
              pw.Text(
                '${filtered.length} categorías',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey400),
              ),
            ],
          ),
        ),
        pw.Container(height: 0.8, color: PdfColors.grey200),
        pw.Padding(
          padding: const pw.EdgeInsets.all(14),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.SizedBox(
                width: 160,
                height: 160,
                child: pw.SvgImage(svg: svg),
              ),
              pw.SizedBox(width: 16),
              pw.Expanded(
                child: pw.Column(
                  children: filtered.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final value = _isoNum(item['value']);
                    final percent = total <= 0 ? 0.0 : value / total;
                    final label = item['label']?.toString() ?? '-';
                    final colorHex = _isoChartHexColors[index % _isoChartHexColors.length];
                    final fgColor = PdfColor.fromHex(colorHex);
                    final bgColor = _isoPdfBarBgColors[index % _isoPdfBarBgColors.length];

                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 10),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(
                            children: [
                              pw.Container(
                                width: 10,
                                height: 10,
                                decoration: pw.BoxDecoration(
                                  color: fgColor,
                                  borderRadius: pw.BorderRadius.circular(3),
                                ),
                              ),
                              pw.SizedBox(width: 7),
                              pw.Expanded(
                                child: pw.Text(
                                  _isoShortLabel(label, max: 20),
                                  style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.blueGrey800),
                                ),
                              ),
                              pw.SizedBox(width: 6),
                              pw.Text(
                                money ? _isoMoneyPdf(value) : _isoFormatNumber(value),
                                style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  color: fgColor,
                                ),
                              ),
                              pw.SizedBox(width: 6),
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: pw.BoxDecoration(
                                  color: bgColor,
                                  borderRadius: pw.BorderRadius.circular(4),
                                ),
                                child: pw.Text(
                                  '${(percent * 100).toStringAsFixed(1)}%',
                                  style: pw.TextStyle(
                                    fontSize: 7.5,
                                    fontWeight: pw.FontWeight.bold,
                                    color: fgColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 4),
                          pw.ClipRRect(
                            horizontalRadius: 2,
                            verticalRadius: 2,
                            child: pw.Row(
                              children: [
                                if (percent > 0)
                                  pw.Flexible(
                                    flex: (percent * 1000).round().clamp(1, 999),
                                    child: pw.Container(height: 4, color: fgColor),
                                  ),
                                if (percent < 1)
                                  pw.Flexible(
                                    flex: ((1 - percent) * 1000).round().clamp(1, 999),
                                    child: pw.Container(height: 4, color: PdfColors.grey100),
                                  ),
                              ],
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
        ),
      ],
    ),
  );
}

pw.Widget _isoPdfEmptyChart(String title) {
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(14),
    decoration: pw.BoxDecoration(
      color: PdfColors.grey50,
      borderRadius: pw.BorderRadius.circular(10),
      border: pw.Border.all(color: PdfColors.grey200, width: 0.8),
    ),
    child: pw.Row(
      children: [
        pw.Container(
          width: 3,
          height: 28,
          decoration: pw.BoxDecoration(
            color: PdfColors.grey300,
            borderRadius: pw.BorderRadius.circular(2),
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey600,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'Sin datos para graficar en este periodo.',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
            ),
          ],
        ),
      ],
    ),
  );
}

String _isoBuildPdfDonutSvg({
  required List<Map<String, dynamic>> items,
  required String totalLabel,
}) {
  final total = items.fold<double>(0, (sum, item) => sum + _isoNum(item['value']));

  const size = 200.0;
  const center = 100.0;
  const radius = 56.0;
  const strokeWidth = 22.0;
  const gapAngle = 0.06;

  final buffer = StringBuffer();

  buffer.writeln('<svg xmlns="http://www.w3.org/2000/svg" width="$size" height="$size" viewBox="0 0 $size $size">');
  buffer.writeln('<rect width="$size" height="$size" fill="white"/>');
  buffer.writeln('<circle cx="$center" cy="$center" r="${radius + strokeWidth / 2 + 2}" fill="none" stroke="#F1F5F9" stroke-width="2"/>');
  buffer.writeln('<circle cx="$center" cy="$center" r="$radius" fill="none" stroke="#E2E8F0" stroke-width="$strokeWidth"/>');

  double startAngle = -math.pi / 2;

  for (int i = 0; i < items.length; i++) {
    final item = items[i];
    final value = _isoNum(item['value']);
    if (value <= 0) continue;

    final percent = total <= 0 ? 0.0 : value / total;
    final sweepAngle = math.pi * 2 * percent - gapAngle;
    if (sweepAngle <= 0) {
      startAngle += math.pi * 2 * percent;
      continue;
    }

    final actualStart = startAngle + gapAngle / 2;
    final endAngle = actualStart + sweepAngle;

    final x1 = center + radius * math.cos(actualStart);
    final y1 = center + radius * math.sin(actualStart);
    final x2 = center + radius * math.cos(endAngle);
    final y2 = center + radius * math.sin(endAngle);

    final largeArc = sweepAngle > math.pi ? 1 : 0;
    final colorHex = _isoChartHexColors[i % _isoChartHexColors.length];

    buffer.writeln('<path d="M $x1 $y1 A $radius $radius 0 $largeArc 1 $x2 $y2" fill="none" stroke="$colorHex" stroke-width="$strokeWidth" stroke-linecap="butt"/>');
    startAngle += math.pi * 2 * percent;
  }

  buffer.writeln('<circle cx="$center" cy="$center" r="${radius - strokeWidth / 2}" fill="white"/>');
  buffer.writeln('<text x="$center" y="${center - 12}" text-anchor="middle" font-size="9" font-family="Arial, Helvetica, sans-serif" font-weight="bold" fill="#94A3B8" letter-spacing="1">TOTAL</text>');
  buffer.writeln('<line x1="${center - 24}" y1="${center - 4}" x2="${center + 24}" y2="${center - 4}" stroke="#E2E8F0" stroke-width="0.8"/>');

  final labelShort = totalLabel.length > 14 ? totalLabel.substring(0, 14) : totalLabel;
  buffer.writeln('<text x="$center" y="${center + 10}" text-anchor="middle" font-size="11" font-family="Arial, Helvetica, sans-serif" font-weight="bold" fill="#0F172A">$labelShort</text>');
  buffer.writeln('</svg>');

  return buffer.toString();
}

pw.Widget _isoPdfTable({
  required String title,
  required List<String> headers,
  required List<List<String>> rows,
}) {
  if (rows.isEmpty) {
    return _isoPdfEmptyChart(title);
  }

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blueGrey900,
        ),
      ),
      pw.SizedBox(height: 7),
      pw.TableHelper.fromTextArray(
        headers: headers,
        data: rows.take(10).toList(),
        headerStyle: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
          fontSize: 8,
        ),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
        cellStyle: const pw.TextStyle(fontSize: 7.5),
        oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
        cellAlignment: pw.Alignment.centerLeft,
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        border: pw.TableBorder.all(color: PdfColors.grey200, width: 0.5),
      ),
    ],
  );
}

// ─── DATA CLASSES ─────────────────────────────────────────────────────────────

class _PdfMetric {
  final String label;
  final String value;
  final bool isMain;
  const _PdfMetric(this.label, this.value, this.isMain);
}

class _ReportChartPoint {
  final String label;
  final double value;
  final Color color;

  const _ReportChartPoint({
    required this.label,
    required this.value,
    required this.color,
  });
}

class _ReportChartSlice {
  final String label;
  final double value;
  final double percent;
  final Color color;

  const _ReportChartSlice({
    required this.label,
    required this.value,
    required this.percent,
    required this.color,
  });
}

// ─── BAR CHART PAINTER (formal) ───────────────────────────────────────────────

class _ReportBarChartPainter extends CustomPainter {
  final List<_ReportChartPoint> points;
  final double maxValue;
  final String Function(double value) formatValue;

  const _ReportBarChartPainter({
    required this.points,
    required this.maxValue,
    required this.formatValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftPadding = 84.0;
    const rightPadding = 16.0;
    const topPadding = 30.0;
    const bottomPadding = 62.0;

    final chartLeft = leftPadding;
    final chartTop = topPadding;
    final chartRight = size.width - rightPadding;
    final chartBottom = size.height - bottomPadding;

    final chartWidth = math.max(1.0, chartRight - chartLeft);
    final chartHeight = math.max(1.0, chartBottom - chartTop);

    // ── Fondo del área de gráfica ──
    final bgPaint = Paint()..color = const Color(0xFFF8FAFC);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(chartLeft, chartTop, chartRight, chartBottom),
        const Radius.circular(6),
      ),
      bgPaint,
    );

    // ── Grid lines horizontales ──
    const gridCount = 5;
    for (int i = 0; i <= gridCount; i++) {
      final y = chartTop + (chartHeight / gridCount) * i;
      final value = maxValue * (1 - i / gridCount);

      final isBaseline = i == gridCount;

      final gridPaint = Paint()
        ..color = isBaseline ? const Color(0xFFCBD5E1) : const Color(0xFFE9EFF6)
        ..strokeWidth = isBaseline ? 1.5 : 0.8;

      canvas.drawLine(Offset(chartLeft, y), Offset(chartRight, y), gridPaint);

      // Label eje Y
      final tp = TextPainter(
        text: TextSpan(
          text: formatValue(value),
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: leftPadding - 10);

      tp.paint(
        canvas,
        Offset(chartLeft - tp.width - 8, y - tp.height / 2),
      );
    }

    // ── Eje Y vertical ──
    final axisPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(chartLeft, chartTop),
      Offset(chartLeft, chartBottom),
      axisPaint,
    );

    // ── Barras ──
    final groupWidth = chartWidth / points.length;
    final barWidth = math.min(44.0, math.max(14.0, groupWidth * 0.50));

    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final pct = maxValue <= 0 ? 0.0 : (point.value / maxValue).clamp(0.0, 1.0);
      final barHeight = math.max(3.0, chartHeight * pct);

      final centerX = chartLeft + groupWidth * i + groupWidth / 2;
      final barLeft = centerX - barWidth / 2;
      final barTop = chartBottom - barHeight;

      // Sombra suave
      final shadowPaint = Paint()
        ..color = point.color.withAlpha(35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawRRect(
        RRect.fromLTRBAndCorners(
          barLeft + 2, barTop + 6, barLeft + barWidth + 2, chartBottom,
          topLeft: Radius.circular(barWidth / 3),
          topRight: Radius.circular(barWidth / 3),
        ),
        shadowPaint,
      );

      // Barra con gradiente
      final barPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            point.color,
            point.color.withAlpha(195),
          ],
        ).createShader(Rect.fromLTWH(barLeft, barTop, barWidth, barHeight));

      canvas.drawRRect(
        RRect.fromLTRBAndCorners(
          barLeft, barTop, barLeft + barWidth, chartBottom,
          topLeft: Radius.circular(barWidth / 3),
          topRight: Radius.circular(barWidth / 3),
        ),
        barPaint,
      );

      // Pequeña línea superior de brillo
      if (barHeight > 12) {
        final shinePaint = Paint()
          ..color = Colors.white.withAlpha(80)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(barLeft + 3, barTop + 3),
          Offset(barLeft + barWidth - 3, barTop + 3),
          shinePaint,
        );
      }

      // Valor encima de la barra
      if (point.value > 0) {
        final vp = TextPainter(
          text: TextSpan(
            text: formatValue(point.value),
            style: TextStyle(
              color: point.color,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
          maxLines: 1,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: groupWidth);

        vp.paint(
          canvas,
          Offset(centerX - vp.width / 2, barTop - vp.height - 5),
        );
      }

      // Label eje X
      final truncated = point.label.length > 9
          ? '${point.label.substring(0, 9)}…'
          : point.label;

      final lp = TextPainter(
        text: TextSpan(
          text: truncated,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        maxLines: 2,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: groupWidth - 2);

      lp.paint(
        canvas,
        Offset(centerX - lp.width / 2, chartBottom + 10),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ReportBarChartPainter old) {
    return old.points != points || old.maxValue != maxValue;
  }
}

// ─── DONUT CHART PAINTER (formal) ────────────────────────────────────────────

class _ReportDonutChartPainter extends CustomPainter {
  final List<_ReportChartSlice> slices;
  final String totalLabel;

  const _ReportDonutChartPainter({
    required this.slices,
    required this.totalLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = side * 0.355;
    final strokeWidth = side * 0.125;
    const gapAngle = 0.05; // separación formal entre segmentos

    // Track de fondo
    final trackPaint = Paint()
      ..color = const Color(0xFFE9EFF6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    // Segmentos
    double startAngle = -math.pi / 2;

    for (final slice in slices) {
      if (slice.percent <= 0) continue;

      final sweep = math.pi * 2 * slice.percent - gapAngle;
      if (sweep <= 0) {
        startAngle += math.pi * 2 * slice.percent;
        continue;
      }

      final segPaint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + gapAngle / 2,
        sweep,
        false,
        segPaint,
      );

      startAngle += math.pi * 2 * slice.percent;
    }

    // Círculo blanco interior para efecto donut limpio
    final innerPaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, radius - strokeWidth / 2 - 1, innerPaint);

    // Etiqueta "TOTAL" en mayúsculas pequeñas
    final titlePainter = TextPainter(
      text: const TextSpan(
        text: 'TOTAL',
        style: TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: side * 0.6);

    titlePainter.paint(
      canvas,
      Offset(center.dx - titlePainter.width / 2, center.dy - 22),
    );

    // Línea divisora sutil
    final linePaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(center.dx - side * 0.22, center.dy - 8),
      Offset(center.dx + side * 0.22, center.dy - 8),
      linePaint,
    );

    // Valor total
    final totalPainter = TextPainter(
      text: TextSpan(
        text: totalLabel,
        style: const TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
      ),
      maxLines: 1,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: side * 0.58);

    totalPainter.paint(
      canvas,
      Offset(center.dx - totalPainter.width / 2, center.dy + 2),
    );
  }

  @override
  bool shouldRepaint(covariant _ReportDonutChartPainter old) {
    return old.slices != slices || old.totalLabel != totalLabel;
  }
}