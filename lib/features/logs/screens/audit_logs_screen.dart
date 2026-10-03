import 'package:flutter/material.dart';

import '../models/audit_log.dart';
import '../services/audit_log_service.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  final AuditLogService _service = AuditLogService();
  final TextEditingController _usuarioController = TextEditingController();
  final TextEditingController _moduloController = TextEditingController();

  List<AuditLog> logs = [];
  bool isLoading = false;
  String? errorMessage;
  String? accionSeleccionada;
  String periodoSeleccionado = 'HOY';

  final List<String> periodos = const [
    'HOY',
    'ULTIMOS_7_DIAS',
    'ULTIMOS_30_DIAS',
    'TODOS',
  ];

  final List<String> acciones = const [
    'CONSULTA',
    'CREACION',
    'ACTUALIZACION',
    'ELIMINACION',
    'LOGIN_EXITOSO',
    'LOGIN_FALLIDO',
    'PEDIDO_CREADO',
    'PEDIDO_ENVIADO',
    'PEDIDO_RECIBIDO',
    'PEDIDO_CANCELADO',
    'ITEM_AGREGADO',
    'ITEM_ELIMINADO',
    'PROVEEDOR_CAMBIADO',
    'ESCANEO_PRODUCTO',
    'PASSWORD_CAMBIADO',
    'USUARIO_CREADO',
    'USUARIO_DESACTIVADO',
    'IMPRESION_EXITOSA',
    'ERROR_IMPRESION',
    'BLUETOOTH_DESCONECTADO',
  ];

  @override
  void initState() {
    super.initState();
    cargarLogs();
  }

  @override
  void dispose() {
    _usuarioController.dispose();
    _moduloController.dispose();
    super.dispose();
  }

  Future<void> cargarLogs() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final fechas = _rangoFechas();

      final result = await _service.listarLogs(
        accion: accionSeleccionada,
        modulo: _moduloController.text,
        nombreUsuario: _usuarioController.text,
        desde: fechas['desde'],
        hasta: fechas['hasta'],
      );

      if (!mounted) return;

      setState(() {
        logs = result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void limpiarFiltros() {
    _usuarioController.clear();
    _moduloController.clear();

    setState(() {
      accionSeleccionada = null;
      periodoSeleccionado = 'HOY';
    });

    cargarLogs();
  }

  Map<String, String?> _rangoFechas() {
    final now = DateTime.now();

    String format(DateTime date) {
      String two(int n) => n.toString().padLeft(2, '0');
      return '${date.year}-${two(date.month)}-${two(date.day)}';
    }

    if (periodoSeleccionado == 'HOY') {
      return {
        'desde': format(now),
        'hasta': format(now),
      };
    }

    if (periodoSeleccionado == 'ULTIMOS_7_DIAS') {
      return {
        'desde': format(now.subtract(const Duration(days: 7))),
        'hasta': format(now),
      };
    }

    if (periodoSeleccionado == 'ULTIMOS_30_DIAS') {
      return {
        'desde': format(now.subtract(const Duration(days: 30))),
        'hasta': format(now),
      };
    }

    return {
      'desde': null,
      'hasta': null,
    };
  }

  String _periodoLabel(String periodo) {
    if (periodo == 'HOY') return 'Hoy';
    if (periodo == 'ULTIMOS_7_DIAS') return 'Últimos 7 días';
    if (periodo == 'ULTIMOS_30_DIAS') return 'Últimos 30 días';
    return 'Todos';
  }

  String _formatFecha(DateTime? value) {
    if (value == null) return '-';

    String two(int number) => number.toString().padLeft(2, '0');

    return '${two(value.day)}/${two(value.month)}/${value.year} '
        '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }

  Color _statusColor(AuditLog log) {
    final accion = log.accion.toUpperCase();

    if (accion.contains('ERROR') ||
        accion.contains('FALLIDO') ||
        accion.contains('DESCONECTADO') ||
        accion.contains('ELIMINACION') ||
        accion.contains('CANCELADO') ||
        (log.estadoHttp != null && log.estadoHttp! >= 500)) {
      return Colors.red;
    }

    if (accion.contains('LOGIN') ||
        accion.contains('PASSWORD') ||
        accion.contains('USUARIO')) {
      return Colors.purple;
    }

    if (accion.contains('ACTUALIZACION') ||
        accion.contains('CAMBIADO') ||
        accion.contains('ENVIADO') ||
        accion.contains('RECIBIDO')) {
      return Colors.orange;
    }

    if (accion.contains('CONSULTA') || accion.contains('ESCANEO')) {
      return Colors.blue;
    }

    if (accion.contains('CREACION') ||
        accion.contains('CREADO') ||
        accion.contains('AGREGADO') ||
        accion.contains('EXITOSO') ||
        accion.contains('IMPRESION_EXITOSA')) {
      return Colors.green;
    }

    return Colors.blueGrey;
  }

  IconData _statusIcon(AuditLog log) {
    final accion = log.accion.toUpperCase();

    if (accion.contains('ERROR') ||
        accion.contains('FALLIDO') ||
        accion.contains('DESCONECTADO')) {
      return Icons.error_outline;
    }

    if (accion.contains('LOGIN') ||
        accion.contains('PASSWORD') ||
        accion.contains('USUARIO')) {
      return Icons.security;
    }

    if (accion.contains('PEDIDO')) {
      return Icons.receipt_long;
    }

    if (accion.contains('ITEM') || accion.contains('PROVEEDOR')) {
      return Icons.shopping_cart;
    }

    if (accion.contains('ESCANEO')) {
      return Icons.qr_code_scanner;
    }

    if (accion.contains('IMPRESION')) {
      return Icons.print;
    }

    return Icons.event_note;
  }

  Widget _buildFiltros() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _usuarioController,
                      decoration: const InputDecoration(
                        labelText: 'Usuario',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_search),
                      ),
                      onSubmitted: (_) => cargarLogs(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _moduloController,
                      decoration: const InputDecoration(
                        labelText: 'Módulo',
                        hintText: 'PEDIDOS, CARRITO, PRODUCTOS...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                      onSubmitted: (_) => cargarLogs(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              LayoutBuilder(
                builder: (context, constraints) {

                  final isMobile = constraints.maxWidth < 700;

                  if (isMobile) {

                    return Column(
                      children: [

                        DropdownButtonFormField<String>(
                          value: accionSeleccionada,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Acción',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.filter_alt),
                          ),
                          items: acciones
                              .map(
                                (accion) => DropdownMenuItem(
                                  value: accion,
                                  child: Text(
                                    accion,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              accionSeleccionada = value;
                            });
                          },
                        ),

                        const SizedBox(height: 10),

                        DropdownButtonFormField<String>(
                          value: periodoSeleccionado,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Periodo',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.date_range),
                          ),
                          items: periodos
                              .map(
                                (periodo) => DropdownMenuItem(
                                  value: periodo,
                                  child: Text(_periodoLabel(periodo)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              periodoSeleccionado = value ?? 'HOY';
                            });
                          },
                        ),

                        const SizedBox(height: 10),

                        Row(
                          children: [

                            Expanded(
                              child: FilledButton.icon(
                                onPressed: isLoading ? null : cargarLogs,
                                icon: const Icon(Icons.search),
                                label: const Text('Buscar'),
                              ),
                            ),

                            const SizedBox(width: 8),

                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: isLoading ? null : limpiarFiltros,
                                icon: const Icon(Icons.clear),
                                label: const Text('Limpiar'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [

                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: accionSeleccionada,
                          decoration: const InputDecoration(
                            labelText: 'Acción',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.filter_alt),
                          ),
                          items: acciones
                              .map(
                                (accion) => DropdownMenuItem(
                                  value: accion,
                                  child: Text(accion),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              accionSeleccionada = value;
                            });
                          },
                        ),
                      ),

                      const SizedBox(width: 8),

                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: periodoSeleccionado,
                          decoration: const InputDecoration(
                            labelText: 'Periodo',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.date_range),
                          ),
                          items: periodos
                              .map(
                                (periodo) => DropdownMenuItem(
                                  value: periodo,
                                  child: Text(_periodoLabel(periodo)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              periodoSeleccionado = value ?? 'HOY';
                            });
                          },
                        ),
                      ),

                      const SizedBox(width: 8),

                      IconButton.filled(
                        tooltip: 'Buscar',
                        onPressed: isLoading ? null : cargarLogs,
                        icon: const Icon(Icons.search),
                      ),

                      const SizedBox(width: 4),

                      IconButton.outlined(
                        tooltip: 'Limpiar filtros',
                        onPressed: isLoading ? null : limpiarFiltros,
                        icon: const Icon(Icons.clear),
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

  Widget _buildResumen() {
    if (logs.isEmpty || isLoading) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Mostrando ${logs.length} logs · ${_periodoLabel(periodoSeleccionado)}',
          style: TextStyle(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildLogCard(AuditLog log) {
    final color = _statusColor(log);

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color,
          foregroundColor: Colors.white,
          child: Icon(_statusIcon(log), size: 20),
        ),
        title: Text(
          '${log.accion} · ${log.modulo}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        trailing: log.estadoHttp == null
            ? null
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.35)),
                ),
                child: Text(
                  'HTTP ${log.estadoHttp}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Usuario: ${log.nombreUsuario ?? 'Sin usuario'} (${log.rol ?? '-'})'),
              Text('Ruta: ${log.metodo ?? '-'} ${log.ruta ?? '-'}'),
              Text('Fecha: ${_formatFecha(log.fechaCreacion)}'),
              if (log.duracionMs != null) Text('Duración: ${log.duracionMs} ms'),
              if (log.ip != null) Text('IP: ${log.ip}'),
              if (log.detalle != null && log.detalle!.isNotEmpty)
                Text('Detalle: ${log.detalle}'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContenido() {
    if (errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          errorMessage!,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    if (isLoading) {
      return const Expanded(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (logs.isEmpty) {
      return const Expanded(
        child: Center(child: Text('No existen logs para mostrar')),
      );
    }

    return Expanded(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        itemCount: logs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) => _buildLogCard(logs[index]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs del sistema'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: isLoading ? null : cargarLogs,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFiltros(),
          _buildResumen(),
          _buildContenido(),
        ],
      ),
    );
  }
}