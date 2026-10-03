import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/services/cronograma_service.dart';
import '../../data/models/notificacion_model.dart';

class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key});

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  final _cronogramaService = CronogramaService();
  List<Notificacion> _notificaciones = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarAlertas();
  }

  Future<void> _cargarAlertas() async {
    setState(() => _isLoading = true);
    try {
      final data = await _cronogramaService.misNotificaciones();
      setState(() => _notificaciones = data);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _leerNotificacion(Notificacion notif) async {
    if (notif.leido) return; // Si ya está leída no hace nada

    // Marcar como leída visualmente inmediato
    setState(() {
      _notificaciones = _notificaciones
          .map(
            (n) => n.id == notif.id
                ? Notificacion(
                    id: n.id,
                    titulo: n.titulo,
                    mensaje: n.mensaje,
                    leido: true,
                    fechaCreacion: n.fechaCreacion,
                  )
                : n,
          )
          .toList();
    });

    // Enviar a la BD
    try {
      await _cronogramaService.marcarComoLeida(notif.id);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis Alertas')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notificaciones.isEmpty
          ? const Center(
              child: Text(
                'No tienes notificaciones nuevas',
                style: TextStyle(fontSize: 16),
              ),
            )
          : ListView.builder(
              itemCount: _notificaciones.length,
              itemBuilder: (context, index) {
                final notif = _notificaciones[index];
                return Container(
                  color: notif.leido
                      ? Colors.transparent
                      : Colors.blue.withOpacity(0.08),
                  child: ListTile(
                    onTap: () => _leerNotificacion(notif),
                    leading: Stack(
                      children: [
                        const Icon(Icons.notifications, size: 30),
                        if (!notif.leido) // Puntito rojo si no está leída
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: Text(
                      notif.titulo,
                      style: TextStyle(
                        fontWeight: notif.leido
                            ? FontWeight.normal
                            : FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(notif.mensaje),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat(
                            'dd/MM/yyyy HH:mm',
                          ).format(notif.fechaCreacion),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
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
