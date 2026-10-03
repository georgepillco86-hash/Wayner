import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Importamos el servicio de pedidos que ya tienes
import '../services/pedidos_service.dart';

class EventosCalendarioScreen extends StatefulWidget {
  const EventosCalendarioScreen({super.key});

  @override
  State<EventosCalendarioScreen> createState() =>
      _EventosCalendarioScreenState();
}

class _EventosCalendarioScreenState extends State<EventosCalendarioScreen> {
  final PedidosService _service = PedidosService();
  List<dynamic> _eventos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarEventos();
  }

  Future<void> _cargarEventos() async {
    setState(() => _isLoading = true);
    try {
      // Llamaremos a una función que crearemos en tu backend en el siguiente paso
      final data = await _service.obtenerEventosCalendario();
      setState(() {
        _eventos = data;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al cargar eventos: $e',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _eliminarEvento(int id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Evento'),
        content: const Text(
          '¿Estás seguro de que deseas eliminar este evento? La IA dejará de prepararse para esta fecha.',
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

    if (confirmar == true) {
      setState(() => _isLoading = true);
      try {
        await _service.eliminarEventoCalendario(id);
        _cargarEventos();
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Evento eliminado')));
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _toggleActivo(int id, bool estadoActual) async {
    try {
      await _service.actualizarEstadoEvento(id, !estadoActual);
      _cargarEventos();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _mostrarDialogoEvento({Map<String, dynamic>? eventoExistente}) {
    final bool esEdicion = eventoExistente != null;
    final id = esEdicion ? eventoExistente['id'] : null;

    final nombreCtrl = TextEditingController(
      text: esEdicion ? eventoExistente['nombre_evento'] : '',
    );
    final diasCtrl = TextEditingController(
      text: esEdicion ? eventoExistente['dias_anticipacion'].toString() : '60',
    );

    DateTime fechaSeleccionada = esEdicion
        ? DateTime.parse(eventoExistente['fecha_inicio'])
        : DateTime.now().add(const Duration(days: 30));

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    esEdicion ? Icons.edit : Icons.auto_awesome_mosaic,
                    color: Colors.purple,
                  ),
                  const SizedBox(width: 8),
                  Text(esEdicion ? 'Editar Evento' : 'Nuevo Evento IA'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Este evento activará el 'Modo Prophet' en los pedidos para alertar al equipo de compras.",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nombreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del Evento (Ej: Navidad)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.event_note),
                      ),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: fechaSeleccionada,
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setStateDialog(() {
                            fechaSeleccionada = picked;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Fecha del Evento',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_month),
                        ),
                        child: Text(
                          DateFormat('dd/MM/yyyy').format(fechaSeleccionada),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: diasCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Días de anticipación para avisar',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.timelapse),
                        helperText: 'Recomendado: 60 días',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.purple),
                  onPressed: () async {
                    if (nombreCtrl.text.trim().isEmpty) return;

                    final payload = {
                      "nombre_evento": nombreCtrl.text.trim(),
                      "fecha_inicio": DateFormat(
                        'yyyy-MM-dd',
                      ).format(fechaSeleccionada),
                      "dias_anticipacion": int.tryParse(diasCtrl.text) ?? 60,
                      "activo": true,
                    };

                    Navigator.pop(context);
                    setState(() => _isLoading = true);

                    try {
                      if (esEdicion) {
                        await _service.actualizarEventoCalendario(id, payload);
                      } else {
                        await _service.crearEventoCalendario(payload);
                      }
                      _cargarEventos();
                    } catch (e) {
                      setState(() => _isLoading = false);
                      if (context.mounted)
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                  child: const Text('Guardar Evento'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendario de IA (Prophet)'),
        backgroundColor: Colors.purple.shade50,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarEventos,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarDialogoEvento(),
        backgroundColor: Colors.purple,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "Nuevo Evento",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _eventos.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    "No hay eventos configurados",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _eventos.length,
              itemBuilder: (context, index) {
                final evento = _eventos[index];
                final bool activo = evento['activo'] == true;
                final DateTime fecha = DateTime.parse(evento['fecha_inicio']);
                final int dias = evento['dias_anticipacion'] ?? 60;

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: activo
                          ? Colors.purple.shade200
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: activo
                          ? Colors.purple.shade100
                          : Colors.grey.shade200,
                      child: Icon(
                        Icons.auto_awesome,
                        color: activo ? Colors.purple.shade700 : Colors.grey,
                      ),
                    ),
                    title: Text(
                      evento['nombre_evento'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        decoration: activo
                            ? TextDecoration.none
                            : TextDecoration.lineThrough,
                        color: activo ? Colors.black87 : Colors.grey,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          "📅 Fecha: ${DateFormat('dd MMM yyyy').format(fecha)}",
                        ),
                        Text(
                          "⏳ Empieza a avisar $dias días antes",
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: activo,
                          activeColor: Colors.purple,
                          onChanged: (val) =>
                              _toggleActivo(evento['id'], activo),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _mostrarDialogoEvento(eventoExistente: evento);
                            } else if (value == 'delete') {
                              _eliminarEvento(evento['id']);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 20),
                                  SizedBox(width: 8),
                                  Text('Editar'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Eliminar',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
