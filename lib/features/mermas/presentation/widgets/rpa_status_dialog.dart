import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Llama a esto pasando el ID de la promoción recién creada.
// Ahora retorna un Future para poder usar 'await' en el formulario.
Future<void> mostrarMonitoreoRPA(BuildContext context, int promocionId) {
  return showDialog(
    context: context,
    barrierDismissible: false, // El usuario no puede cerrarlo tocando afuera
    builder: (context) => _RpaStatusDialog(promocionId: promocionId),
  );
}

class _RpaStatusDialog extends StatefulWidget {
  final int promocionId;
  const _RpaStatusDialog({required this.promocionId});

  @override
  State<_RpaStatusDialog> createState() => _RpaStatusDialogState();
}

class _RpaStatusDialogState extends State<_RpaStatusDialog> {
  String estado = 'PROCESANDO';
  String mensaje = 'El agente RPA está cambiando el precio en BITS...';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Consultamos al backend cada 2 segundos
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _verificarEstado();
    });
  }

  Future<void> _verificarEstado() async {
    try {
      // Ajusta tu IP del backend aquí
      final url = Uri.parse(
        'http://192.168.1.231:5000/api/promociones/rpa/estado/${widget.promocionId}',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final estadoDb = data['estado'];

        if (estadoDb == 'COMPLETADO' || estadoDb == 'ERROR') {
          _timer?.cancel();
          setState(() {
            estado = estadoDb;
            mensaje =
                data['mensaje'] ??
                (estadoDb == 'COMPLETADO'
                    ? '¡Precio actualizado con éxito!'
                    : 'Ocurrió un error en el RPA.');
          });

          // Cerramos el pop-up automáticamente después de 3 segundos para que el usuario siga trabajando
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) Navigator.of(context).pop();
          });
        }
      }
    } catch (e) {
      // Ignorar errores de red temporales
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (estado == 'PROCESANDO') ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ] else if (estado == 'COMPLETADO') ...[
            const Icon(Icons.check_circle, color: Colors.green, size: 60),
            const SizedBox(height: 20),
            const Text(
              '¡Éxito!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            Text(mensaje, textAlign: TextAlign.center),
          ] else if (estado == 'ERROR') ...[
            const Icon(Icons.cancel, color: Colors.red, size: 60),
            const SizedBox(height: 20),
            const Text(
              'Error',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(mensaje, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}
