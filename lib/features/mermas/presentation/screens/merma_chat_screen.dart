import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/merma_model.dart';
import '../../data/models/merma_historial_model.dart';
import '../../data/services/merma_service.dart';

class MermaChatScreen extends StatefulWidget {
  final Merma merma;
  final VoidCallback onUpdate;

  const MermaChatScreen({
    super.key,
    required this.merma,
    required this.onUpdate,
  });

  @override
  State<MermaChatScreen> createState() => _MermaChatScreenState();
}

class _MermaChatScreenState extends State<MermaChatScreen> {
  final MermaService _mermaService = MermaService();
  final TextEditingController _comentarioController = TextEditingController();
  final TextEditingController _notaCreditoController = TextEditingController();

  List<MermaHistorial> _historial = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _nuevoEstado;

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  Future<void> _cargarHistorial() async {
    try {
      final data = await _mermaService.obtenerHistorial(widget.merma.id!);
      setState(() {
        _historial = data;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getColorEstado(String estado) {
    switch (estado.toUpperCase()) {
      case 'PENDIENTE':
        return Colors.red;
      case 'NOTIFICADO':
        return Colors.orange;
      case 'RESUELTO':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Future<void> _guardarCambio() async {
    if (_nuevoEstado == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Seleccione un estado')));
      return;
    }
    if (_comentarioController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El comentario es obligatorio')),
      );
      return;
    }
    if (_nuevoEstado == 'Resuelto' &&
        _notaCreditoController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingrese la Nota de Crédito o justificación'),
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    try {
      await _mermaService.cambiarEstado(
        id: widget.merma.id!,
        estado: _nuevoEstado!,
        comentario: _comentarioController.text.trim(),
        notaCredito: _nuevoEstado == 'Resuelto'
            ? _notaCreditoController.text.trim()
            : null,
      );

      widget.onUpdate(); // Refresca la lista principal
      if (mounted) Navigator.pop(context); // Cierra el chat y vuelve
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool estaResuelto = widget.merma.estado.toUpperCase() == 'RESUELTO';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Auditoría de Merma'),
        backgroundColor: _getColorEstado(widget.merma.estado),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // CABECERA DE LA MERMA
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surfaceVariant,
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.merma.nombreProducto,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Código: ${widget.merma.codigo} | Cantidad: ${widget.merma.cantidad}',
                ),
                Text('Condición: ${widget.merma.novedad}'),
              ],
            ),
          ),

          // ZONA DE CHAT (HISTORIAL)
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _historial.length,
                    itemBuilder: (context, index) {
                      final item = _historial[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            color: _getColorEstado(item.estadoNuevo),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    item.usuario,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    DateFormat(
                                      'dd/MM/yyyy HH:mm',
                                    ).format(item.fechaRegistro),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(),
                              Text(
                                item.comentario,
                                style: const TextStyle(fontSize: 15),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Chip(
                                  label: Text(
                                    item.estadoNuevo,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                    ),
                                  ),
                                  backgroundColor: _getColorEstado(
                                    item.estadoNuevo,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // ZONA DE RESPUESTA (Solo visible si NO está resuelto)
          if (!estaResuelto)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    value: _nuevoEstado,
                    decoration: const InputDecoration(
                      labelText: 'Cambiar Estado a:',
                      border: OutlineInputBorder(),
                    ),
                    items: ['Pendiente', 'Notificado', 'Resuelto'].map((
                      String val,
                    ) {
                      return DropdownMenuItem(
                        value: val,
                        child: Row(
                          children: [
                            Icon(
                              Icons.circle,
                              color: _getColorEstado(val),
                              size: 14,
                            ),
                            const SizedBox(width: 8),
                            Text(val),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _nuevoEstado = val),
                  ),
                  const SizedBox(height: 12),

                  if (_nuevoEstado == 'Resuelto') ...[
                    TextField(
                      controller: _notaCreditoController,
                      decoration: const InputDecoration(
                        labelText:
                            'Nota de Crédito / Justificación (Obligatorio)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  TextField(
                    controller: _comentarioController,
                    decoration: const InputDecoration(
                      labelText: 'Razón del cambio (Obligatorio)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),

                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: _nuevoEstado != null
                          ? _getColorEstado(_nuevoEstado!)
                          : Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isSaving ? null : _guardarCambio,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send),
                    label: const Text(
                      'Registrar Auditoría',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),

          if (estaResuelto)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.green.shade50,
              width: double.infinity,
              child: const Text(
                '✅ Este proceso de merma ha sido finalizado y resuelto.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
