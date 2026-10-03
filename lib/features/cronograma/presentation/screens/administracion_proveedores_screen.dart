import 'package:flutter/material.dart';
import '../../data/services/cronograma_service.dart';
import 'cronograma_form_screen.dart';

class AdministracionProveedoresScreen extends StatefulWidget {
  final VoidCallback onChanged;

  const AdministracionProveedoresScreen({super.key, required this.onChanged});

  @override
  State<AdministracionProveedoresScreen> createState() =>
      _AdministracionProveedoresScreenState();
}

class _AdministracionProveedoresScreenState
    extends State<AdministracionProveedoresScreen> {
  final _cronogramaService = CronogramaService();
  List<dynamic> _secuencias = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarSecuencias();
  }

  Future<void> _cargarSecuencias() async {
    setState(() => _isLoading = true);
    try {
      final data = await _cronogramaService.obtenerSecuenciasProgramadas();
      if (mounted) setState(() => _secuencias = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _eliminar(int id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Secuencia'),
        content: const Text(
          '¿Estás seguro? Se borrarán todas las visitas futuras programadas para este proveedor.',
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
        await _cronogramaService.eliminarSecuencia(id);
        widget.onChanged(); // Actualiza el calendario de fondo
        _cargarSecuencias(); // Recarga la lista
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _editarSecuencia(Map<String, dynamic> secuencia) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CronogramaFormScreen(
          // Pasamos los datos iniciales para editar
          proveedorInicial: secuencia['proveedor'],
          secuenciaAEditar: secuencia,
          onSaved: () {
            widget.onChanged();
            _cargarSecuencias();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Administración de Proveedores')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _secuencias.isEmpty
          ? const Center(child: Text('No hay secuencias programadas.'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _secuencias.length,
              itemBuilder: (context, index) {
                final seq = _secuencias[index];

                // Procesar Usuarios
                final jsonUsuarios = seq['usuarios_vinculados'];
                final usuariosStr = (jsonUsuarios is List)
                    ? jsonUsuarios.join(', ')
                    : jsonUsuarios.toString();

                // Procesar Frecuencia (Traducción de BD a Vista)
                String textoFrecuencia;
                if (seq['frecuencia'] == 7) {
                  textoFrecuencia = 'Semanal';
                } else if (seq['frecuencia'] == 15) {
                  textoFrecuencia = 'Quincenal';
                } else if (seq['frecuencia'] == 30) {
                  textoFrecuencia = 'Mensual';
                } else {
                  textoFrecuencia = 'Cada ${seq['frecuencia']} días';
                }

                // Procesar WhatsApp (Manejo de nulos y vacíos)
                final celularRaw = seq['contacto_celular']?.toString() ?? '';
                final celularTexto = celularRaw.trim().isEmpty
                    ? 'No registrado'
                    : celularRaw;

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                seq['proveedor'] ?? 'Desconocido',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueGrey,
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () => _editarSecuencia(seq),
                                  tooltip: 'Editar',
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _eliminar(seq['id']),
                                  tooltip: 'Eliminar',
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Divider(),
                        _buildInfoRow(
                          Icons.phone_android,
                          'WhatsApp:',
                          celularTexto,
                        ),
                        const SizedBox(height: 6),
                        _buildInfoRow(
                          Icons.autorenew,
                          'Frecuencia:',
                          textoFrecuencia,
                        ),
                        const SizedBox(height: 6),
                        _buildInfoRow(
                          Icons.group,
                          'Usuarios Asignados:',
                          usuariosStr,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(width: 4),
        Expanded(child: Text(value)),
      ],
    );
  }
}
