import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb; // 🔥 Importación necesaria para web

import '../../data/models/merma_model.dart';
import '../../data/services/merma_service.dart';
import '../widgets/merma_form_dialog.dart';
import 'merma_chat_screen.dart';
import '../widgets/despacho_dialog.dart';

// 🔥 IMPORTAMOS EL SERVICIO DE PEDIDOS QUE YA FUNCIONA PERFECTO 🔥
import 'package:ferrotienda_flutter_proyecto/features/pedidos/services/pedidos_service.dart';

class MermaScreen extends StatefulWidget {
  final String usuarioActual;
  final String rolUsuario;
  final bool esModoReporte;

  const MermaScreen({
    super.key,
    required this.usuarioActual,
    required this.rolUsuario,
    this.esModoReporte = false,
  });

  @override
  State<MermaScreen> createState() => _MermaScreenState();
}

class _MermaScreenState extends State<MermaScreen> {
  final MermaService _mermaService = MermaService();
  final TextEditingController _searchController = TextEditingController();

  List<Merma> _mermas = [];
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarMermas();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarMermas() async {
    setState(() => _isLoading = true);
    try {
      final mermas = await _mermaService.listarMermas();
      setState(() => _mermas = mermas);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al conectar con el servidor: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Merma> get _filteredMermas {
    if (_searchQuery.isEmpty) return _mermas;
    final query = _searchQuery.toLowerCase();
    return _mermas.where((merma) {
      return merma.codigo.toLowerCase().contains(query) ||
          merma.nombreProducto.toLowerCase().contains(query) ||
          merma.novedad.toLowerCase().contains(query) ||
          merma.estado.toLowerCase().contains(query) ||
          merma.usuario.toLowerCase().contains(query) ||
          (merma.proveedor?.toLowerCase().contains(query) ?? false) ||
          (merma.comentario?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  bool _puedeEditar(Merma merma) {
    if (widget.rolUsuario == 'ADMIN') return true;
    if (merma.usuario != widget.usuarioActual) return false;
    if (merma.fechaRegistro == null) return true;
    final diferencia = DateTime.now().difference(merma.fechaRegistro!);
    return diferencia.inDays < 3;
  }

  void _abrirFormulario({Merma? merma}) {
    showDialog(
      context: context,
      builder: (context) =>
          MermaFormDialog(merma: merma, onSave: () => _cargarMermas()),
    );
  }

  void _mostrarOpcionesSeguimiento(Merma merma) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            MermaChatScreen(merma: merma, onUpdate: _cargarMermas),
      ),
    );
  }

  Color _getColorEstado(String estado) {
    switch (estado.toUpperCase()) {
      case 'EN PROCESO':
      case 'NOTIFICADO':
        return Colors.orange;
      case 'RESUELTO':
        return Colors.green;
      default:
        return Colors.red;
    }
  }

  // =========================================================
  // 🔥 LÓGICA DE PRE-LLENADO, EXPORTACIÓN Y AUDITORÍA 🔥
  // =========================================================

  Future<void> _procesarAccion(Merma merma, bool isWhatsApp) async {
    // 1. Mostrar diálogo pidiendo Proveedor y Costo
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => DatosProveedorDialog(merma: merma),
    );

    if (result != null) {
      final proveedor = result['proveedor'] as String;
      final costo = result['costo'] as double;

      setState(() => _isLoading = true);

      try {
        // 2. Actualizar merma en la Base de Datos
        await _mermaService.actualizarMerma(merma.id!, {
          'cantidad': merma.cantidad,
          'novedad': merma.novedad,
          'comentario': merma.comentario,
          'proveedor': proveedor,
          'ultimo_costo': costo,
        });

        // 3. Recargar para obtener el contactoProveedor si se actualizó
        await _cargarMermas();
        final updatedMerma = _mermas.firstWhere(
          (m) => m.id == merma.id,
          orElse: () => merma,
        );

        // 4. Ejecutar la acción seleccionada
        if (isWhatsApp) {
          final enviado = await _enviarWhatsAppPlano(
            updatedMerma,
            proveedor,
            costo,
          );

          if (enviado) {
            // Generar auditoría en el chat y cambiar estado
            final fecha = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
            final msj =
                "Se ha notificado al proveedor $proveedor hoy $fecha el producto/s: ${merma.nombreProducto} en el estado ${merma.estado}";

            await _mermaService.cambiarEstado(
              id: merma.id!,
              estado: 'Notificado',
              comentario: msj,
            );
            await _cargarMermas();
          }
        } else {
          await _generarYCompartirPDF(updatedMerma, proveedor, costo);
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
  }

  Future<bool> _enviarWhatsAppPlano(
    Merma merma,
    String proveedor,
    double costo,
  ) async {
    final contacto = merma.contactoProveedor ?? '';
    if (contacto.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No hay contacto celular registrado para este proveedor.',
          ),
        ),
      );
      return false;
    }

    final id = merma.id.toString().padLeft(4, '0');
    final numNotaCredito = '001-001-$id';
    final cantidad = merma.cantidad.toInt();
    final subtotal = cantidad * costo;

    final mensaje =
        "Hola, le compartimos el reporte de merma (Nota de Crédito Nro: $numNotaCredito):\n\n"
        "📦 *Producto:* ${merma.nombreProducto}\n"
        "🏷️ *Código:* ${merma.codigo}\n"
        "⚠️ *Condición:* ${merma.novedad}\n"
        "🔢 *Cantidad:* $cantidad\n"
        "💲 *Costo Unitario:* \$${costo.toStringAsFixed(4)}\n"
        "💰 *Total a reconocer:* \$${subtotal.toStringAsFixed(2)}\n\n"
        "Por favor, su ayuda con la gestión correspondiente.";

    final numeroLimpio = contacto.replaceAll(RegExp(r'[^0-9]'), '');
    final url = Uri.parse(
      "https://wa.me/593$numeroLimpio?text=${Uri.encodeComponent(mensaje)}",
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      return true;
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir WhatsApp')),
        );
      }
      return false;
    }
  }

  Future<void> _generarYCompartirPDF(
    Merma merma,
    String proveedor,
    double costo,
  ) async {
    final pdf = pw.Document();

    final id = merma.id.toString().padLeft(4, '0');
    final numNotaCredito = '001-001-$id';
    final fecha = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    final cantidad = merma.cantidad.toInt();
    final subtotal = cantidad * costo;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'FERROTIENDA',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'NOTA DE CRÉDITO INTERNA',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Nro: $numNotaCredito',
                        style: const pw.TextStyle(color: PdfColors.red),
                      ),
                      pw.Text('Fecha: $fecha'),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Proveedor: $proveedor',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text('Condición del reporte: ${merma.novedad}'),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                headers: [
                  'Código',
                  'Descripción',
                  'Cant',
                  'Costo Unit.',
                  'Subtotal',
                ],
                data: [
                  [
                    merma.codigo,
                    merma.nombreProducto,
                    cantidad.toString(),
                    '\$${costo.toStringAsFixed(4)}',
                    '\$${subtotal.toStringAsFixed(2)}',
                  ],
                ],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.center,
                  3: pw.Alignment.centerRight,
                  4: pw.Alignment.centerRight,
                },
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text(
                    'TOTAL: \$${subtotal.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    // 🔥 SOLUCIÓN PARA FLUTTER WEB
    final bytes = await pdf.save();

    if (kIsWeb) {
      final xfile = XFile.fromData(
        bytes,
        mimeType: 'application/pdf',
        name: 'Nota_Credito_$id.pdf',
      );
      await Share.shareXFiles([
        xfile,
      ], text: 'Adjunto Nota de Crédito $numNotaCredito por merma.');
    } else {
      final output = await getTemporaryDirectory();
      final file = File("${output.path}/Nota_Credito_$id.pdf");
      await file.writeAsBytes(bytes);

      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Adjunto Nota de Crédito $numNotaCredito por merma.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool puedeAuditarChat =
        (widget.rolUsuario == 'ADMIN' || widget.rolUsuario == 'BODEGUERO') &&
        widget.esModoReporte;

    final listaFiltrada = _filteredMermas;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.esModoReporte ? 'Reporte de Mermas' : 'Ingreso de Mermas',
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargarMermas),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Buscar merma...',
                hintText: 'Código, producto, estado, usuario...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          FocusScope.of(context).unfocus();
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _cargarMermas,
                    child: listaFiltrada.isEmpty
                        ? const Center(
                            child: Text(
                              'No se encontraron mermas para mostrar',
                            ),
                          )
                        : ListView.builder(
                            itemCount: listaFiltrada.length,
                            itemBuilder: (context, index) {
                              final merma = listaFiltrada[index];
                              final puedeEditar = _puedeEditar(merma);

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  children: [
                                    ListTile(
                                      onTap: puedeAuditarChat
                                          ? () => _mostrarOpcionesSeguimiento(
                                              merma,
                                            )
                                          : null,
                                      title: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${merma.nombreProducto} (x${merma.cantidad})',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          if (merma.cantidadDespachada > 0)
                                            Text(
                                              ' (${merma.cantidadDespachada.toInt()}/${merma.cantidad.toInt()} Retirados)',
                                              style: TextStyle(
                                                color:
                                                    (merma.cantidadDespachada >=
                                                        merma.cantidad)
                                                    ? Colors.green
                                                    : Colors.red,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                        ],
                                      ),
                                      subtitle: Text(
                                        'Código: ${merma.codigo}\n'
                                        'Condición: ${merma.novedad}\n'
                                        'Proveedor: ${merma.proveedor ?? "Sin proveedor"}\n'
                                        'Registrado por: ${merma.usuario} (${merma.fechaRegistro != null ? DateFormat("dd/MM/yyyy HH:mm").format(merma.fechaRegistro!) : "-"})',
                                      ),
                                      trailing: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Chip(
                                            label: Text(
                                              merma.estado,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                              ),
                                            ),
                                            backgroundColor: _getColorEstado(
                                              merma.estado,
                                            ),
                                            padding: EdgeInsets.zero,
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                          Expanded(
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (puedeEditar &&
                                                    merma.estado
                                                            .toUpperCase() !=
                                                        'RESUELTO')
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.edit,
                                                      size: 20,
                                                      color: Colors.amber,
                                                    ),
                                                    onPressed: () =>
                                                        _abrirFormulario(
                                                          merma: merma,
                                                        ),
                                                  ),
                                                if (widget.rolUsuario ==
                                                        'ADMIN' ||
                                                    merma.usuario ==
                                                        widget.usuarioActual)
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.delete,
                                                      size: 20,
                                                      color: Colors.red,
                                                    ),
                                                    onPressed: () async {
                                                      final ok =
                                                          await _mermaService
                                                              .eliminarMerma(
                                                                merma.id!,
                                                              );
                                                      if (ok) _cargarMermas();
                                                    },
                                                  ),
                                                if (puedeAuditarChat)
                                                  const Icon(
                                                    Icons.chevron_right,
                                                    color: Colors.grey,
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // 🔥 BARRA DE BOTONES (Solo en Modo Reporte)
                                    if (widget.esModoReporte) ...[
                                      const Divider(height: 1),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8.0,
                                          vertical: 4.0,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            if (merma.cantidadDespachada <
                                                    merma.cantidad &&
                                                merma.estado.toUpperCase() !=
                                                    'RESUELTO')
                                              TextButton.icon(
                                                onPressed: () {
                                                  showDialog(
                                                    context: context,
                                                    barrierDismissible: false,
                                                    builder: (context) =>
                                                        DespachoDialog(
                                                          merma: merma,
                                                          usuarioActual: widget
                                                              .usuarioActual,
                                                          onSuccess:
                                                              _cargarMermas,
                                                        ),
                                                  );
                                                },
                                                icon: const Icon(
                                                  Icons.local_shipping,
                                                  size: 18,
                                                  color: Colors.blue,
                                                ),
                                                label: const Text(
                                                  'Despacho',
                                                  style: TextStyle(
                                                    color: Colors.blue,
                                                  ),
                                                ),
                                              ),
                                            if (merma.cantidadDespachada <
                                                merma.cantidad)
                                              const SizedBox(width: 8),

                                            if (merma.estado.toUpperCase() ==
                                                'PENDIENTE')
                                              TextButton.icon(
                                                onPressed: () =>
                                                    _procesarAccion(
                                                      merma,
                                                      true,
                                                    ),
                                                icon: const Icon(
                                                  Icons.message,
                                                  size: 18,
                                                  color: Colors.green,
                                                ),
                                                label: const Text(
                                                  'Notificar',
                                                  style: TextStyle(
                                                    color: Colors.green,
                                                  ),
                                                ),
                                              ),
                                            const SizedBox(width: 8),
                                            ElevatedButton.icon(
                                              onPressed: () =>
                                                  _procesarAccion(merma, false),
                                              icon: const Icon(
                                                Icons.picture_as_pdf,
                                                size: 18,
                                              ),
                                              label: const Text('PDF'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.blueGrey,
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: widget.esModoReporte
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _abrirFormulario(),
              label: const Text('Agregar Merma'),
              icon: const Icon(Icons.add),
            ),
    );
  }
}

// =========================================================================
// 🔥 CUADRO DE DIÁLOGO UTILIZANDO PEDIDOS_SERVICE 🔥
// =========================================================================
class DatosProveedorDialog extends StatefulWidget {
  final Merma merma;

  const DatosProveedorDialog({super.key, required this.merma});

  @override
  State<DatosProveedorDialog> createState() => _DatosProveedorDialogState();
}

class _DatosProveedorDialogState extends State<DatosProveedorDialog> {
  // Instanciamos el servicio de pedidos para reutilizar sus métodos
  final PedidosService _pedidosService = PedidosService();

  String? _proveedorSeleccionado;
  List<String> _proveedoresDisponibles = [];
  bool _isLoadingProveedores = true;

  double? _costoSeleccionado;
  List<double> _costosDisponibles = [];
  bool _isLoadingCostos = false;

  // Caché para almacenar todo el historial del producto
  List<dynamic> _historialCompleto = [];

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
  }

  Future<void> _cargarDatosIniciales() async {
    try {
      // Descargamos proveedores y el historial (24 meses) en paralelo
      final results = await Future.wait([
        _pedidosService.obtenerProveedoresProducto(widget.merma.codigo),
        _pedidosService.obtenerHistorialCostos(widget.merma.codigo, 24),
      ]);

      if (mounted) {
        setState(() {
          final provsData = results[0] as List<dynamic>;
          _historialCompleto = results[1] as List<dynamic>;

          // Mapear los proveedores
          _proveedoresDisponibles = provsData
              .map((p) => p["proveedor"]?.toString() ?? "")
              .where((p) => p.isNotEmpty)
              .toList();

          _isLoadingProveedores = false;

          if (_proveedoresDisponibles.isNotEmpty) {
            _proveedorSeleccionado =
                (widget.merma.proveedor != null &&
                    _proveedoresDisponibles.contains(widget.merma.proveedor))
                ? widget.merma.proveedor
                : _proveedoresDisponibles.first;
          } else if (widget.merma.proveedor != null &&
              widget.merma.proveedor!.isNotEmpty) {
            // Prevenir error si la API viene vacía pero ya había un proveedor asignado en BD
            _proveedoresDisponibles = [widget.merma.proveedor!];
            _proveedorSeleccionado = widget.merma.proveedor;
          }
        });

        // Una vez cargados, procesamos los costos del proveedor seleccionado
        if (_proveedorSeleccionado != null) {
          _procesarCostosParaProveedor(_proveedorSeleccionado!);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingProveedores = false;
          _isLoadingCostos = false;
        });
      }
    }
  }

  void _procesarCostosParaProveedor(String proveedor) {
    setState(() => _isLoadingCostos = true);

    // Filtramos localmente el historial completo para este proveedor específico
    final filtrado = _historialCompleto.where((h) {
      final p = h["proveedor"]?.toString().trim().toUpperCase() ?? "";
      return p == proveedor.trim().toUpperCase();
    }).toList();

    Set<double> costosSet = {};
    for (var h in filtrado) {
      double cost = double.tryParse(h["costo_final"]?.toString() ?? "0") ?? 0.0;
      if (cost > 0) costosSet.add(cost);
    }

    setState(() {
      _costosDisponibles = costosSet.toList()
        ..sort((a, b) => b.compareTo(a)); // Ordenar de mayor a menor

      _isLoadingCostos = false;

      if (_costosDisponibles.isNotEmpty) {
        _costoSeleccionado =
            (widget.merma.ultimoCosto != null &&
                _costosDisponibles.contains(widget.merma.ultimoCosto))
            ? widget.merma.ultimoCosto
            : _costosDisponibles.first;
      } else if (widget.merma.ultimoCosto != null) {
        // Prevenir error si no hay historial pero ya había un costo asignado
        _costosDisponibles = [widget.merma.ultimoCosto!];
        _costoSeleccionado = widget.merma.ultimoCosto;
      } else {
        _costoSeleccionado = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Completar Datos para Reporte'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Por favor, especifica el proveedor y el costo histórico a reconocer antes de exportar el reporte.',
          ),
          const SizedBox(height: 16),

          // 🔥 SELECTOR DESPLEGABLE DE PROVEEDOR
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: 'Proveedor',
              border: const OutlineInputBorder(),
              suffixIcon: _isLoadingProveedores
                  ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
            isExpanded: true,
            value: _proveedoresDisponibles.contains(_proveedorSeleccionado)
                ? _proveedorSeleccionado
                : null,
            items: _proveedoresDisponibles.isEmpty
                ? null
                : _proveedoresDisponibles.map((String prov) {
                    return DropdownMenuItem<String>(
                      value: prov,
                      child: Text(prov, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
            onChanged: (String? nuevoProveedor) {
              if (nuevoProveedor != null &&
                  nuevoProveedor != _proveedorSeleccionado) {
                setState(() => _proveedorSeleccionado = nuevoProveedor);
                // Recalculamos los costos locales cuando cambia el proveedor
                _procesarCostosParaProveedor(nuevoProveedor);
              }
            },
          ),

          const SizedBox(height: 16),

          // 🔥 SELECTOR DE COSTO HISTÓRICO
          DropdownButtonFormField<double>(
            decoration: InputDecoration(
              labelText: 'Costo a reconocer (Historial)',
              prefixText: '\$ ',
              border: const OutlineInputBorder(),
              suffixIcon: _isLoadingCostos
                  ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
            value: _costosDisponibles.contains(_costoSeleccionado)
                ? _costoSeleccionado
                : null,
            items: _costosDisponibles.isEmpty
                ? null
                : _costosDisponibles.map((double costo) {
                    return DropdownMenuItem<double>(
                      value: costo,
                      child: Text(costo.toStringAsFixed(4)),
                    );
                  }).toList(),
            onChanged: (double? nuevoCosto) {
              setState(() => _costoSeleccionado = nuevoCosto);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed:
              (_proveedorSeleccionado != null && _costoSeleccionado != null)
              ? () {
                  Navigator.pop(context, {
                    'proveedor': _proveedorSeleccionado,
                    'costo': _costoSeleccionado,
                  });
                }
              : null,
          child: const Text('Continuar'),
        ),
      ],
    );
  }
}
