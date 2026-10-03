import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart'
    as http; // 🔥 Añadido para hacer la consulta a la API

import '../models/promocion.dart';
import '../services/promocion_service.dart';
import 'promocion_form_screen.dart';
import '../../saldos/presentation/screens/barcode_scanner_screen.dart';

class PromocionesScreen extends StatefulWidget {
  const PromocionesScreen({super.key});

  @override
  State<PromocionesScreen> createState() => _PromocionesScreenState();
}

class _PromocionesScreenState extends State<PromocionesScreen> {
  final PromocionService _service = PromocionService();

  final TextEditingController _textoController = TextEditingController();
  final TextEditingController _codigoController = TextEditingController();

  String estadoSeleccionado = 'TODAS';
  DateTime? fechaDesde;
  DateTime? fechaHasta;

  final List<String> estados = const [
    'TODAS',
    'ACTIVA',
    'VENCIDA',
    'DESACTIVADA',
  ];

  List<Promocion> promociones = [];
  bool isLoading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    cargarPromociones();
  }

  @override
  void dispose() {
    _textoController.dispose();
    _codigoController.dispose();
    super.dispose();
  }

  Future<void> escanearCodigoFiltro() async {
    final codigo = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );

    if (codigo == null || codigo.trim().isEmpty) return;

    _codigoController.text = codigo.trim();
    cargarPromociones();
  }

  Future<void> cargarPromociones() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final result = await _service.listar(
        texto: _textoController.text.trim(),
        codigoBarra: _codigoController.text.trim(),
        estado: estadoSeleccionado,
        fechaDesde: fechaDesde,
        fechaHasta: fechaHasta,
      );

      if (!mounted) return;

      setState(() {
        promociones = result;
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

  Future<void> abrirFormulario({Promocion? promocion}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PromocionFormScreen(promocion: promocion),
      ),
    );

    if (result == true) {
      cargarPromociones();
    }
  }

  Future<void> seleccionarFechaDesde() async {
    final result = await showDatePicker(
      context: context,
      initialDate: fechaDesde ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (result == null) return;

    setState(() {
      fechaDesde = result;

      if (fechaHasta != null && fechaHasta!.isBefore(fechaDesde!)) {
        fechaHasta = fechaDesde;
      }
    });

    cargarPromociones();
  }

  Future<void> seleccionarFechaHasta() async {
    final result = await showDatePicker(
      context: context,
      initialDate: fechaHasta ?? fechaDesde ?? DateTime.now(),
      firstDate: fechaDesde ?? DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (result == null) return;

    setState(() {
      fechaHasta = result;
    });

    cargarPromociones();
  }

  void limpiarFiltros() {
    _textoController.clear();
    _codigoController.clear();

    setState(() {
      estadoSeleccionado = 'TODAS';
      fechaDesde = null;
      fechaHasta = null;
    });

    cargarPromociones();
  }

  String _fechaCorta(DateTime? value) {
    if (value == null) return '-';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year}';
  }

  // 🔥 ACTUALIZADO: Función para desactivar con Isla Dinámica
  Future<void> desactivarPromocion(Promocion promocion) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Desactivar promoción'),
        content: Text(
          '¿Deseas desactivar la promoción de "${promocion.nombreProducto}"? El precio regresará al valor base en BITS.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      final rootOverlay = Navigator.of(context, rootNavigator: true).overlay!;

      await _service.desactivar(promocion.id);

      if (!mounted) return;

      // 🔥 Quitamos _service de aquí y llamamos la nueva versión
      _iniciarRastreoRPA(
        rootOverlay,
        promocion.id,
        "RPA desactivando precio...",
      );

      cargarPromociones();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // 🔥 ACTUALIZADO: Función para eliminar con Isla Dinámica
  Future<void> eliminarPromocion(Promocion promocion) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar promoción'),
        content: Text(
          '¿Estás seguro de que deseas eliminar permanentemente "${promocion.nombreProducto}"? El precio regresará al valor base en BITS y esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      final rootOverlay = Navigator.of(context, rootNavigator: true).overlay!;

      await _service.eliminar(promocion.id);

      if (!mounted) return;

      // 🔥 Quitamos _service de aquí y llamamos la nueva versión
      _iniciarRastreoRPA(
        rootOverlay,
        promocion.id,
        "RPA eliminando promoción...",
      );

      cargarPromociones();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
    }
  }

  String _fecha(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year}';
  }

  Widget _buildPromocionCard(Promocion promocion) {
    final hoy = DateTime.now();
    final hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);
    final fechaFinSinHora = DateTime(
      promocion.fechaFin.year,
      promocion.fechaFin.month,
      promocion.fechaFin.day,
    );

    final bool estaVencida = fechaFinSinHora.isBefore(hoySinHora);

    Color color;
    IconData icon;
    String estadoTexto;

    if (!promocion.activa) {
      color = Colors.grey;
      icon = Icons.block;
      estadoTexto = 'DESACTIVADA';
    } else if (estaVencida) {
      color = Colors.orange;
      icon = Icons.schedule;
      estadoTexto = 'VENCIDA';
    } else {
      color = Colors.green;
      icon = Icons.check_circle;
      estadoTexto = 'ACTIVA';
    }

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color,
          foregroundColor: Colors.white,
          child: Icon(icon, size: 20),
        ),
        title: Text(
          promocion.nombreProducto,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Estado: $estadoTexto'),
              Text('Código: ${promocion.codigoBarra}'),
              Text(
                'Precio anterior: \$${promocion.precioAnterior.toStringAsFixed(2)}',
              ),
              Text(
                'Precio promo: \$${promocion.precioActualProm.toStringAsFixed(2)}',
              ),
              Text('Ahorro: \$${promocion.ahorro.toStringAsFixed(2)}'),
              Text('Mecánica: ${promocion.mecanica ?? '-'}'),
              Text(
                estaVencida
                    ? 'Venció el: ${_fecha(promocion.fechaFin)}'
                    : 'Vigente hasta: ${_fecha(promocion.fechaFin)}',
              ),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'editar') {
              abrirFormulario(promocion: promocion);
            }
            if (value == 'desactivar') {
              desactivarPromocion(promocion);
            }
            if (value == 'eliminar') {
              eliminarPromocion(promocion);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'editar',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(width: 8),
                  Text('Editar'),
                ],
              ),
            ),
            if (promocion.activa)
              const PopupMenuItem(
                value: 'desactivar',
                child: Row(
                  children: [
                    Icon(Icons.block, size: 20),
                    SizedBox(width: 8),
                    Text('Desactivar'),
                  ],
                ),
              ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'eliminar',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Text('Eliminar', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Promociones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: isLoading ? null : cargarPromociones,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => abrirFormulario(),
        icon: const Icon(Icons.add),
        label: const Text('Nueva'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextField(
                      controller: _textoController,
                      decoration: const InputDecoration(
                        labelText: 'Buscar por nombre, marca, mecánica o texto',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                      ),
                      onSubmitted: (_) => cargarPromociones(),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _codigoController,
                            decoration: const InputDecoration(
                              labelText: 'Código de barras',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.qr_code),
                            ),
                            onSubmitted: (_) => cargarPromociones(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 56,
                          child: IconButton.filled(
                            tooltip: 'Escanear código',
                            onPressed: isLoading ? null : escanearCodigoFiltro,
                            icon: const Icon(Icons.qr_code_scanner),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: estadoSeleccionado,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Estado',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.flag),
                      ),
                      items: estados
                          .map(
                            (estado) => DropdownMenuItem(
                              value: estado,
                              child: Text(estado),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          estadoSeleccionado = value ?? 'TODAS';
                        });
                        cargarPromociones();
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: seleccionarFechaDesde,
                            icon: const Icon(Icons.calendar_month),
                            label: Text('Desde: ${_fechaCorta(fechaDesde)}'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: seleccionarFechaHasta,
                            icon: const Icon(Icons.event),
                            label: Text('Hasta: ${_fechaCorta(fechaHasta)}'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: isLoading ? null : cargarPromociones,
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
                ),
              ),
            ),
          ),
          if (errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          if (isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (promociones.isEmpty)
            const Expanded(child: Center(child: Text('No existen promociones')))
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                itemCount: promociones.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, index) =>
                    _buildPromocionCard(promociones[index]),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// 🔥 WIDGET REUTILIZABLE: DYNAMIC ISLAND CONECTADO AL ENDPOINT RPA ORIGINAL 🔥
// ============================================================================
void _iniciarRastreoRPA(
  OverlayState overlay,
  int promoId,
  String initialMessage,
) async {
  late OverlayEntry entry;
  bool isPolling = true;
  bool isSuccess = false;
  String message = initialMessage;

  entry = OverlayEntry(
    builder: (context) => Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 0,
      right: 0,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.85,
            ),
            decoration: BoxDecoration(
              color: isPolling
                  ? Colors.indigo.shade800
                  : (isSuccess ? Colors.green.shade700 : Colors.red.shade700),
              borderRadius: BorderRadius.circular(40),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isPolling)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.0,
                    ),
                  )
                else
                  Icon(
                    isSuccess ? Icons.check_circle : Icons.cancel,
                    color: Colors.white,
                    size: 16,
                  ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  overlay.insert(entry);

  int intentos = 0;
  const int maxIntentos = 15; // 45 segundos máximo

  // 🔥 BUCLE DE MONITOREO APUNTANDO A TU ENDPOINT ORIGINAL
  while (isPolling && intentos < maxIntentos) {
    await Future.delayed(const Duration(seconds: 3));
    intentos++;

    try {
      // 🎯 HACEMOS LA MISMA LLAMADA QUE HACÍA TU ANTIGUO POP-UP
      final url = Uri.parse(
        'http://192.168.1.231:5000/api/promociones/rpa/estado/$promoId',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final estadoDb = data['estado']?.toString().toUpperCase() ?? '';

        if (estadoDb == 'COMPLETADO' || estadoDb == 'ERROR') {
          isPolling = false;
          isSuccess = (estadoDb == 'COMPLETADO');

          // Leemos el mensaje del backend o ponemos uno por defecto
          final msgBackend = data['mensaje']?.toString() ?? '';
          if (msgBackend.isNotEmpty) {
            message = isSuccess ? "✅ $msgBackend" : "❌ $msgBackend";
          } else {
            message = isSuccess
                ? "✅ Precio actualizado en BITS"
                : "❌ Error RPA ($estadoDb)";
          }

          entry.markNeedsBuild(); // Cambia color de la Isla Dinámica

          await Future.delayed(const Duration(seconds: 4));
          entry.remove();
          return;
        }
      }
    } catch (e) {
      debugPrint("⚠️ Error consultando estado RPA: $e");
    }
  }

  // Si se acaba el tiempo...
  if (isPolling) {
    message = "⚠️ El RPA tardó demasiado";
    isSuccess = false;
    entry.markNeedsBuild();
    await Future.delayed(const Duration(seconds: 4));
    entry.remove();
  }
}
