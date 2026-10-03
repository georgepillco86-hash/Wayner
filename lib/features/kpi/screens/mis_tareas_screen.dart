import 'package:flutter/material.dart';
import '../services/kpi_service.dart';
import '../../../core/storage/session_storage.dart';

// 🔥 NUEVO IMPORT: Asegúrate de que la ruta coincida con la ubicación de tu buscador de pedidos 🔥
// RUTA CORRECTA
import '../../pedidos/screens/pedido_busqueda_screen.dart';

class MisTareasScreen extends StatefulWidget {
  const MisTareasScreen({super.key});

  @override
  State<MisTareasScreen> createState() => _MisTareasScreenState();
}

class _MisTareasScreenState extends State<MisTareasScreen> {
  final KpiService _kpiService = KpiService();
  List<dynamic> _tareas = [];
  bool _isLoading = true;
  String _nombreUsuario = "";

  // 🔥 VARIABLE PARA EL FILTRO DE FECHAS (Inicia en hoy) 🔥
  DateTime _fechaSeleccionada = DateTime.now();

  // 🔥 VARIABLES PARA PREMIOS Y CASTIGOS 🔥
  String _premioMes = "Cargando...";
  String _castigoMes = "Cargando...";

  @override
  void initState() {
    super.initState();
    _cargarTareasYRecompensas();
  }

  // 🔥 Se carga todo en una sola función para mayor velocidad 🔥
  Future<void> _cargarTareasYRecompensas() async {
    setState(() => _isLoading = true);
    try {
      final user = await SessionStorage.getUser();
      if (user != null) {
        _nombreUsuario = user.nombreUsuario;

        // Convertimos la fecha seleccionada a YYYY-MM-DD
        final fechaStr =
            "${_fechaSeleccionada.year}-${_fechaSeleccionada.month.toString().padLeft(2, '0')}-${_fechaSeleccionada.day.toString().padLeft(2, '0')}";

        // Disparamos ambas peticiones (tareas y recompensas) de forma paralela
        final results = await Future.wait([
          _kpiService.obtenerMisTareas(_nombreUsuario, fechaStr),
          _kpiService
              .obtenerPremioMes(
                _fechaSeleccionada.month,
                _fechaSeleccionada.year,
              )
              .catchError(
                (e) => {
                  "premio": "Aún no definido",
                  "castigo": "Aún no definido",
                },
              ),
        ]);

        setState(() {
          _tareas = results[0] as List<dynamic>;

          final recompensas = results[1] as Map<String, dynamic>;
          _premioMes = recompensas['premio'] ?? "Aún no definido";
          _castigoMes = recompensas['castigo'] ?? "Aún no definido";
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🔥 FUNCIÓN PARA QUE EL TRABAJADOR VEA DÍAS ANTERIORES 🔥
  Future<void> _seleccionarFecha() async {
    final DateTime? seleccion = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(
        const Duration(days: 7),
      ), // Puede ver hasta 1 semana al futuro si hay programadas
      helpText: "VER TAREAS DE OTRA FECHA",
    );
    if (seleccion != null && seleccion != _fechaSeleccionada) {
      setState(() {
        _fechaSeleccionada = seleccion;
      });
      _cargarTareasYRecompensas();
    }
  }

  Future<void> _marcarParaRevision(int tareaId, String nombreTarea) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmar Tarea"),
        content: Text(
          "¿Estás seguro de que terminaste la tarea '$nombreTarea' y está lista para que el Administrador la evalúe?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Aún no"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Sí, está lista"),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      setState(() => _isLoading = true);
      try {
        await _kpiService.marcarTareaRevision(tareaId, nombreTarea);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ Tarea enviada a revisión."),
              backgroundColor: Colors.green,
            ),
          );
        }
        _cargarTareasYRecompensas();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
          );
        }
        setState(() => _isLoading = false);
      }
    }
  }

  Color _getColorPorEstado(String estado) {
    switch (estado.toUpperCase()) {
      case 'PENDIENTE':
        return Colors.orange;
      case 'REVISION':
        return Colors.blue;
      case 'EVALUADO':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  // 🔥 NUEVA FUNCIÓN INTELIGENTE: Detecta si la tarea es de un proveedor 🔥
  String? _extraerProveedor(String nombreTarea) {
    final nombreLower = nombreTarea.toLowerCase();
    if (nombreLower.startsWith("atender a ")) {
      // Extrae el texto después de "Atender a " (10 caracteres)
      return nombreTarea.substring(10).trim();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    String tituloFecha =
        _fechaSeleccionada.day == DateTime.now().day &&
            _fechaSeleccionada.month == DateTime.now().month
        ? "Mis Tareas de Hoy"
        : "Tareas: ${_fechaSeleccionada.day}/${_fechaSeleccionada.month}/${_fechaSeleccionada.year}";

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(tituloFecha),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month, color: Colors.blueAccent),
            onPressed: _seleccionarFecha,
            tooltip: "Cambiar fecha",
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarTareasYRecompensas,
            tooltip: "Actualizar",
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 🔥 BANNER DE PREMIO Y CASTIGO 🔥
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.amber.shade100, Colors.orange.shade50],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.amber.shade400,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "OBJETIVO DEL MES",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey,
                              ),
                            ),
                            Text(
                              "🏆 $_premioMes",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "⚠️ $_castigoMes",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.red.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 🔥 LISTA DE TAREAS 🔥
                Expanded(
                  child: _tareas.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.celebration,
                                size: 64,
                                color: Colors.amber.shade400,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                "¡Genial!",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                "No tienes tareas asignadas en esta fecha\no ya las completaste todas.",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          itemCount: _tareas.length,
                          itemBuilder: (context, index) {
                            final tarea = _tareas[index];
                            final estado = (tarea['estado'] ?? 'PENDIENTE')
                                .toString()
                                .toUpperCase();
                            final isPendiente = estado == 'PENDIENTE';
                            final isEvaluado = estado == 'EVALUADO';

                            // Analizamos si la tarea es de un proveedor
                            final nombreTarea =
                                tarea['nombre_tarea'] ?? 'Sin nombre';
                            final proveedorAAtender = _extraerProveedor(
                              nombreTarea,
                            );

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: _getColorPorEstado(
                                    estado,
                                  ).withOpacity(0.5),
                                  width: 1.5,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            nombreTarea,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getColorPorEstado(
                                              estado,
                                            ).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: _getColorPorEstado(estado),
                                            ),
                                          ),
                                          child: Text(
                                            estado,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: _getColorPorEstado(estado),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      tarea['descripcion_tarea'] ??
                                          'Sin instrucciones adicionales.',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    Text(
                                      "📅 Fecha: ${tarea['fecha']}   ⭐ Vale: ${tarea['peso'] ?? 1.0} pts",
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),

                                    const Divider(height: 24),

                                    if (isPendiente) ...[
                                      // 🔥 BOTÓN INTELIGENTE: IR AL PEDIDO 🔥
                                      if (proveedorAAtender != null) ...[
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.indigo.shade600,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                            ),
                                            icon: const Icon(
                                              Icons.shopping_cart_checkout,
                                            ),
                                            label: Text(
                                              "🛒 Hacer Pedido a $proveedorAAtender",
                                            ),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      PedidoBusquedaScreen(
                                                        proveedorInicial:
                                                            proveedorAAtender,
                                                      ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                      ],

                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.blue.shade700,
                                            foregroundColor: Colors.white,
                                          ),
                                          icon: const Icon(
                                            Icons.check_circle_outline,
                                          ),
                                          label: const Text(
                                            "Marcar como Terminada",
                                          ),
                                          onPressed: () => _marcarParaRevision(
                                            tarea['id'],
                                            tarea['nombre_tarea'],
                                          ),
                                        ),
                                      ),
                                    ],

                                    if (estado == 'REVISION')
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.hourglass_empty,
                                            color: Colors.blue,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            "Esperando calificación del Admin...",
                                            style: TextStyle(
                                              color: Colors.blue.shade700,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ],
                                      ),

                                    if (isEvaluado)
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Icon(
                                              Icons.star,
                                              color: Colors.amber,
                                              size: 24,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    "Calificación: ${tarea['calificacion']} / 1.00",
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          Colors.green.shade800,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    "Comentario: ${tarea['comentario_admin'] ?? 'Buen trabajo'}",
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          Colors.green.shade900,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
