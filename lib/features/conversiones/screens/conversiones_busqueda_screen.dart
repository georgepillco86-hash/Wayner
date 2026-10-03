import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../saldos/data/services/saldos_api_service.dart';
import '../services/conversiones_service.dart';
import '../../pedidos/services/pedidos_service.dart';
import '../../../core/storage/session_storage.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/auth_headers.dart';
import '../../saldos/presentation/screens/barcode_scanner_screen.dart';

// 🔥 IMPORTAMOS EL MODAL DE ETIQUETA 🔥
import '../widgets/etiqueta_dialog.dart';

class ConversionesBusquedaScreen extends StatefulWidget {
  // 🔥 NUEVO: Interruptor para saber en qué modo abrimos la pantalla
  final bool isModoEtiqueta;

  const ConversionesBusquedaScreen({
    super.key,
    this.isModoEtiqueta = false, // Por defecto es false (modo carrito normal)
  });

  @override
  State<ConversionesBusquedaScreen> createState() =>
      _ConversionesBusquedaScreenState();
}

class _ConversionesBusquedaScreenState
    extends State<ConversionesBusquedaScreen> {
  final SaldosApiService _saldosService = SaldosApiService();
  final ConversionesService _conversionesService = ConversionesService();
  final PedidosService _pedidosService = PedidosService();
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _resultados = [];
  bool _isLoading = false;

  List<String> _unidadesGlobales = ["UNIDADES"];
  String _nombreUsuario = "Desconocido";

  // 🔥 Lista de colaboradores para asignar
  List<dynamic> _colaboradores = [];
  String? _colaboradorAsignado;

  List<Map<String, dynamic>> _carrito = [];

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
  }

  Future<void> _cargarDatosIniciales() async {
    final user = await SessionStorage.getUser();
    if (mounted && user != null) {
      setState(() => _nombreUsuario = user.nombreUsuario);
    }

    try {
      final uni = await _pedidosService.obtenerUnidadesMedida();
      if (uni.isNotEmpty && mounted) {
        setState(() => _unidadesGlobales = uni);
      }

      // 🔥 OBTENEMOS LOS USUARIOS DIRECTAMENTE DE LA API PARA EVITAR ERRORES DE IMPORTACIÓN 🔥
      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/api/usuarios/"),
        headers: await AuthHeaders.plain(),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _colaboradores = json["data"] ?? [];
          });
        }
      }
    } catch (e) {
      debugPrint("Aviso al cargar datos iniciales: $e");
    }
  }

  Future<void> _buscar() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _isLoading = true;
      _resultados = [];
    });
    try {
      final data = await _saldosService.buscarRapido(termino: query);
      final Map<String, dynamic> productosUnicos = {};
      for (var item in data) {
        final codigo =
            item["Codigo"]?.toString() ?? item["codigo"]?.toString() ?? "";
        if (codigo.isNotEmpty && !productosUnicos.containsKey(codigo)) {
          productosUnicos[codigo] = item;
        }
      }
      setState(() => _resultados = productosUnicos.values.toList());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _escanearCodigo() async {
    if (kIsWeb) return;

    try {
      final code = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
      );
      if (code != null && code.isNotEmpty) {
        _searchController.text = code;
        _buscar();
      }
    } on PlatformException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No se pudo abrir la cámara")),
        );
      }
    }
  }

  void _seleccionarProducto(Map<String, dynamic> producto) {
    // 🔥 SI ESTAMOS EN MODO ETIQUETA, ABRIMOS EL MODAL DIRECTAMENTE 🔥
    if (widget.isModoEtiqueta) {
      showDialog(
        context: context,
        builder: (_) => EtiquetaDialog(
          codigoBarras:
              producto["Codigo"]?.toString() ??
              producto["codigo"]?.toString() ??
              '0000',
          nombreProducto:
              producto["Nombre"]?.toString() ??
              producto["nombre_producto"]?.toString() ??
              'Desconocido',
        ),
      );
      return; // Detenemos la ejecución aquí para que no abra el carrito
    }

    // LÓGICA ORIGINAL DEL CARRITO DE CONVERSIONES
    final TextEditingController cantController = TextEditingController(
      text: "1",
    );
    String unidadSeleccionada = _unidadesGlobales.first;

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Añadir a la Orden (Destino)"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    producto["Nombre"] ?? "",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: cantController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: "Cantidad a obtener",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _unidadesGlobales.contains(unidadSeleccionada)
                        ? unidadSeleccionada
                        : _unidadesGlobales.first,
                    decoration: const InputDecoration(
                      labelText: "Unidad de medida",
                      border: OutlineInputBorder(),
                    ),
                    isExpanded: true,
                    items: _unidadesGlobales.map((u) {
                      return DropdownMenuItem(
                        value: u,
                        child: Text(u, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => unidadSeleccionada = val);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancelar"),
                ),
                FilledButton(
                  onPressed: () {
                    final cant = int.tryParse(cantController.text) ?? 0;
                    if (cant > 0) {
                      setState(() {
                        _carrito.add({
                          "codigo_destino":
                              producto["Codigo"] ?? producto["codigo"],
                          "nombre_destino":
                              producto["Nombre"] ?? producto["nombre_producto"],
                          "cantidad_destino": cant,
                          "unidad_destino": unidadSeleccionada,
                        });
                      });
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Agregado a la orden"),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                  child: const Text("Añadir"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _verCarrito() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  "Orden de Trabajo",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Divider(),

                // 🔥 SELECCIÓN DEL COLABORADOR 🔥
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: "Asignar a colaborador (Opcional)",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_pin_circle_outlined),
                    isDense: true,
                  ),
                  value: _colaboradorAsignado,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text("Sin asignar"),
                    ),
                    ..._colaboradores
                        .map((c) {
                          final nombre =
                              c["nombre_usuario"]?.toString() ??
                              c["usuario"]?.toString() ??
                              "";
                          return DropdownMenuItem(
                            value: nombre,
                            child: Text(nombre),
                          );
                        })
                        .where((item) => item.value != ""),
                  ],
                  onChanged: (val) {
                    setModalState(() => _colaboradorAsignado = val);
                  },
                ),
                const SizedBox(height: 10),

                Expanded(
                  child: ListView.builder(
                    itemCount: _carrito.length,
                    itemBuilder: (_, i) {
                      final item = _carrito[i];
                      return ListTile(
                        leading: const Icon(
                          Icons.move_to_inbox,
                          color: Colors.indigo,
                        ),
                        title: Text(
                          item["nombre_destino"],
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          "Cant: ${item["cantidad_destino"]} ${item["unidad_destino"] ?? ''} | Cód: ${item["codigo_destino"]}",
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setModalState(() => _carrito.removeAt(i));
                            setState(() {}); // Actualiza la pantalla por detrás
                          },
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _carrito.isEmpty
                        ? null
                        : () async {
                            Navigator.pop(context);
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                            try {
                              // 🔥 PASAMOS EL COLABORADOR AL SERVICIO
                              await _conversionesService.crearOrdenTrabajo(
                                _carrito,
                                _nombreUsuario,
                                trabajadorAsignado: _colaboradorAsignado,
                              );
                              if (mounted) {
                                Navigator.pop(context);
                                Navigator.pop(context, true);
                              }
                            } catch (e) {
                              if (mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Error: $e"),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                    icon: const Icon(Icons.save),
                    label: const Text("Guardar Orden de Trabajo"),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // 🔥 CAMBIAMOS EL TÍTULO SEGÚN EL MODO 🔥
        title: Text(
          widget.isModoEtiqueta
              ? "Imprimir Etiqueta"
              : "Buscar producto (Destino)",
        ),
        actions: [
          // 🔥 OCULTAMOS EL CARRITO SI ESTAMOS EN MODO ETIQUETA 🔥
          if (!widget.isModoEtiqueta)
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart),
                  onPressed: _verCarrito,
                ),
                if (_carrito.isNotEmpty)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: CircleAvatar(
                      radius: 8,
                      backgroundColor: Colors.red,
                      child: Text(
                        '${_carrito.length}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: "Código o Nombre...",
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(vertical: 0),
                    ),
                    onSubmitted: (_) => _buscar(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _escanearCodigo,
                  icon: const Icon(Icons.qr_code_scanner),
                ),
              ],
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(),
          Expanded(
            child: _resultados.isEmpty && !_isLoading
                ? const Center(child: Text("Busca un producto para empezar"))
                : ListView.builder(
                    itemCount: _resultados.length,
                    itemBuilder: (_, index) {
                      final prod = _resultados[index];
                      return ListTile(
                        leading: const Icon(
                          Icons.inventory_2_outlined,
                          color: Colors.blueGrey,
                        ),
                        title: Text(
                          prod["Nombre"] ?? "",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          "Cód: ${prod["Codigo"]} | Stock: ${prod["Stock"] ?? 0}",
                        ),
                        // 🔥 CAMBIAMOS EL ICONO SEGÚN EL MODO 🔥
                        trailing: Icon(
                          widget.isModoEtiqueta
                              ? Icons.print
                              : Icons.add_circle,
                          color: widget.isModoEtiqueta
                              ? Colors.indigo
                              : Colors.green,
                        ),
                        onTap: () => _seleccionarProducto(prod),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
