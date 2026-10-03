import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../../data/models/merma_model.dart';
import '../../data/services/merma_service.dart';

class DespachoDialog extends StatefulWidget {
  final Merma merma;
  final String usuarioActual;
  final VoidCallback onSuccess;

  const DespachoDialog({
    Key? key,
    required this.merma,
    required this.usuarioActual,
    required this.onSuccess,
  }) : super(key: key);

  @override
  State<DespachoDialog> createState() => _DespachoDialogState();
}

class _DespachoDialogState extends State<DespachoDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _notaCreditoController = TextEditingController();
  final TextEditingController _personaController = TextEditingController();
  final TextEditingController _cedulaController = TextEditingController();
  final TextEditingController _cantidadController = TextEditingController();

  final MermaService _mermaService = MermaService();

  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  bool _isLoading = false;
  late double cantidadDisponible;

  @override
  void initState() {
    super.initState();
    cantidadDisponible =
        widget.merma.cantidad - widget.merma.cantidadDespachada;

    // Autocompletar la Nota de Crédito con formato 001-001-00000X
    final idStr = widget.merma.id?.toString().padLeft(6, '0') ?? '000000';
    _notaCreditoController.text = '001-001-$idStr';

    // Pre-llenar la cantidad disponible por defecto
    _cantidadController.text = cantidadDisponible.toString();
  }

  Future<void> _guardarDespacho() async {
    if (!_formKey.currentState!.validate()) return;

    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingrese la firma digital.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final signatureBytes = await _signatureController.toPngBytes();
      final base64Firma = base64Encode(signatureBytes!);

      final double cantidadRetirada = double.parse(_cantidadController.text);
      final String fechaHora = DateFormat(
        'dd/MM/yyyy HH:mm',
      ).format(DateTime.now());

      // Petición al backend
      final url = Uri.parse(
        'http://192.168.1.231:5000/api/mermas/${widget.merma.id}/despacho',
      );
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'x-usuario': widget.usuarioActual,
          'x-rol': 'ADMIN',
        },
        body: jsonEncode({
          "nota_credito": _notaCreditoController.text,
          "persona_retira": _personaController.text,
          "cedula_retira": _cedulaController.text,
          "cantidad_retirada": cantidadRetirada,
          "firma_base64": base64Firma,
        }),
      );

      if (response.statusCode == 200) {
        // Notificación por WhatsApp
        final numero = widget.merma.contactoProveedor ?? "";
        if (numero.isNotEmpty) {
          final mensajeWs =
              "*FERROTIENDA - CONSTANCIA DE DESPACHO*\n"
              "Fecha y hora: $fechaHora\n"
              "Retira: ${_personaController.text} (CI: ${_cedulaController.text})\n"
              "Nota de Crédito: ${_notaCreditoController.text}\n"
              "Productos retirados: ${widget.merma.nombreProducto} (x$cantidadRetirada)\n\n"
              "_(Firma digital registrada exitosamente en el sistema)_";

          final numeroLimpio = numero.replaceAll(RegExp(r'[^0-9]'), '');
          final whatsappUrl = Uri.parse(
            "https://wa.me/593$numeroLimpio?text=${Uri.encodeComponent(mensajeWs)}",
          );

          if (await canLaunchUrl(whatsappUrl)) {
            await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
          }
        }

        widget.onSuccess();
        if (mounted) Navigator.of(context).pop();
      } else {
        throw Exception("Error al guardar el despacho en el servidor");
      }
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Registrar Despacho'),
      content: Container(
        width: MediaQuery.of(context).size.width * 0.55,
        constraints: const BoxConstraints(minWidth: 500, maxWidth: 650),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    "Disponible para retirar en total: $cantidadDisponible",
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                TextFormField(
                  controller: _notaCreditoController,
                  decoration: const InputDecoration(
                    labelText: 'N° Nota de Crédito / Guía',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => val!.isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _personaController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre de quien retira',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) => val!.isEmpty ? 'Requerido' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _cedulaController,
                        decoration: const InputDecoration(
                          labelText: 'N° Cédula',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (val) => val!.isEmpty ? 'Requerido' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                const Text(
                  'Productos a retirar:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.inventory_2_outlined,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.merma.nombreProducto,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      SizedBox(
                        width: 100,
                        child: TextFormField(
                          controller: _cantidadController,
                          // 🔥 NUEVO: Validación en tiempo real
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          decoration: const InputDecoration(
                            labelText: 'Cant.',
                            border: OutlineInputBorder(),
                            isDense: true,
                            fillColor: Colors.white,
                            filled: true,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) return 'Req.';
                            final cant = double.tryParse(val);
                            if (cant == null || cant <= 0) return 'Inválido';

                            // 🔥 NUEVO: Bloqueo explícito si excede la cantidad disponible
                            if (cant > cantidadDisponible) {
                              return 'Máx: $cantidadDisponible';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                const Text(
                  'Firma de quien retira:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                Center(
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        height: 180,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                        ),
                        child: Signature(
                          controller: _signatureController,
                          backgroundColor: Colors.white,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => _signatureController.clear(),
                          child: const Text(
                            'Limpiar Firma',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _guardarDespacho,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Guardar y Notificar'),
        ),
      ],
    );
  }
}
