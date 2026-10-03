import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // 🔥 IMPORT PARA LEER EL ESTADO

import '../models/pedido_item.dart';
import '../services/pedidos_service.dart';
import 'pedido_carrito_screen.dart';
import '../../../screens/scanner/scanner_screen.dart';
import '../../../core/storage/pedido_draft_storage.dart';
import '../../../core/storage/session_storage.dart';

import '../../saldos/data/services/saldos_api_service.dart';
import '../../cronograma/presentation/screens/cronograma_form_screen.dart';

import '../../pedidos/widgets/selector_unidad_medida.dart';
import '../../saldos/presentation/widgets/kardex_flotante_dialog.dart';

// 🔥 IMPORT DE TU CEREBRO DE FAVORITOS 🔥
import '../../favoritos/providers/favorites_provider.dart';

class PedidoBusquedaScreen extends StatefulWidget {
  final String? proveedorInicial;

  const PedidoBusquedaScreen({super.key, this.proveedorInicial});

  @override
  State<PedidoBusquedaScreen> createState() => _PedidoBusquedaScreenState();
}

class _PedidoBusquedaScreenState extends State<PedidoBusquedaScreen> {
  final PedidosService service = PedidosService();
  final SaldosApiService saldosService = SaldosApiService();

  final TextEditingController searchController = TextEditingController();
  final TextEditingController marcaController = TextEditingController();

  List<String> proveedores = [];
  List<String> marcasGlobales = [];

  // 🔥 SE AÑADE LA OPCIÓN ESPECIAL AL INICIO 🔥
  List<String> clasesDisponibles = [
    'Todas las clases',
    'Mis favoritos',
    'BAZAR',
    'COMISARIATO',
    'FERRETERIA',
  ];

  String? proveedorSeleccionado;
  String claseSeleccionada = 'Todas las clases';

  bool esAdmin = false;
  bool busquedaProfunda = false;

  List<String> unidadesMedida = ['UNIDADES'];
  List<dynamic> resultados = [];
  List<PedidoItem> carrito = [];

  bool isLoading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();

    proveedorSeleccionado = widget.proveedorInicial;

    cargarUnidadesMedida();
    cargarBorradorCarrito();
    cargarSesionYFiltros().then((_) {
      if (proveedorSeleccionado != null && proveedorSeleccionado!.isNotEmpty) {
        buscar("");
      }
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    marcaController.dispose();
    super.dispose();
  }

  Future<void> cargarSesionYFiltros() async {
    final user = await SessionStorage.getUser();
    final rol = user?.rol.trim().toUpperCase() ?? "";

    if (!mounted) return;
    setState(() => esAdmin = rol == "ADMIN" || rol == "SUPERADMIN");

    try {
      final marcasBD = await saldosService.obtenerMarcasGlobales();
      if (mounted) setState(() => marcasGlobales = marcasBD);
    } catch (_) {}

    if (!esAdmin) return;
    try {
      final provBD = await service.obtenerProveedores();
      if (mounted) setState(() => proveedores = provBD);
    } catch (_) {}
  }

  Future<void> cargarUnidadesMedida() async {
    try {
      final unidades = await service.obtenerUnidadesMedida();
      if (mounted) {
        setState(
          () => unidadesMedida = unidades.isEmpty ? ['UNIDADES'] : unidades,
        );
      }
    } catch (_) {
      if (mounted) setState(() => unidadesMedida = ['UNIDADES']);
    }
  }

  List<dynamic> get resultadosFiltrados {
    final filtroMarca = marcaController.text.trim().toLowerCase();
    if (filtroMarca.isEmpty) return resultados;

    return resultados.where((item) {
      final m = (item["Marca"] ?? item["marca"] ?? "").toString().toLowerCase();
      return m.contains(filtroMarca);
    }).toList();
  }

  Future<void> buscar(String query) async {
    if (query.trim().isEmpty &&
        proveedorSeleccionado == null &&
        claseSeleccionada == 'Todas las clases') {
      if (!mounted) return;
      setState(() {
        resultados = [];
        errorMessage = null;
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final prov =
          (proveedorSeleccionado != null && proveedorSeleccionado!.isNotEmpty)
          ? proveedorSeleccionado
          : null;

      // 🔥 INTERCEPCIÓN: Si seleccionan favoritos, al backend le decimos "Todas" (null) 🔥
      final bool esFiltroFavoritos = claseSeleccionada == 'Mis favoritos';
      final clase =
          (claseSeleccionada == 'Todas las clases' || esFiltroFavoritos)
          ? null
          : claseSeleccionada;

      List<dynamic> data = [];
      if (busquedaProfunda) {
        data = await saldosService.buscarEnKardex(query.trim());
      } else {
        data = await saldosService.buscarRapido(
          termino: query.trim(),
          proveedor: prov,
          clase: clase,
        );
      }

      final Map<String, dynamic> productosUnicos = {};
      for (var item in data) {
        final codigo =
            item["Codigo"]?.toString() ?? item["codigo"]?.toString() ?? "";

        if (codigo.isNotEmpty && !productosUnicos.containsKey(codigo)) {
          productosUnicos[codigo] = item;
        }
      }

      List<dynamic> listaLimpia = productosUnicos.values.toList();

      // =========================================================
      // 🔥 FILTRO LOCAL DE FAVORITOS (Cruza lo que trajo el backend con tu memoria) 🔥
      // =========================================================
      if (esFiltroFavoritos && mounted) {
        final favProvider = context.read<FavoritesProvider>();
        listaLimpia = listaLimpia.where((item) {
          final codigo =
              item["Codigo"]?.toString() ?? item["codigo"]?.toString() ?? "";
          return favProvider.isFavorite(codigo);
        }).toList();
      }

      // Ordenamiento por rotación (VDP)
      listaLimpia.sort((a, b) {
        final vdpA = double.tryParse((a["vdp"] ?? 0).toString()) ?? 0.0;
        final vdpB = double.tryParse((b["vdp"] ?? 0).toString()) ?? 0.0;
        return vdpB.compareTo(vdpA);
      });

      if (!mounted) return;
      setState(() => resultados = listaLimpia);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        errorMessage = "No se pudieron cargar productos.";
        resultados = [];
      });
    } finally {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  void abrirScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScannerScreen(
          onDetect: (codigo) async {
            searchController.text = codigo;
            await buscar(codigo);
          },
        ),
      ),
    );
  }

  Future<void> abrirCarrito() async {
    final enviado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PedidoCarritoScreen(carrito: carrito)),
    );
    if (enviado == true) {
      await PedidoDraftStorage.clear();
      setState(() {
        carrito.clear();
        resultados.clear();
        searchController.clear();
        if (esAdmin) proveedorSeleccionado = null;
        marcaController.clear();
      });
    } else {
      await PedidoDraftStorage.save(carrito);
      setState(() {});
    }
  }

  Future<void> cargarBorradorCarrito() async {
    final borrador = await PedidoDraftStorage.load();
    if (!mounted || borrador.isEmpty) return;
    setState(() => carrito = borrador);
  }

  void _fijarCantidad(dynamic item, dynamic nuevaCantidad) {
    final codigo =
        item["Codigo"]?.toString() ?? item["codigo"]?.toString() ?? "";
    if (codigo.isEmpty) return;

    setState(() {
      final index = carrito.indexWhere((c) => c.codigo == codigo);
      if (index >= 0) {
        if (nuevaCantidad.toString() == "0" ||
            nuevaCantidad.toString().isEmpty) {
          carrito.removeAt(index);
        } else {
          carrito[index].cantidad = nuevaCantidad;
        }
      } else if (nuevaCantidad.toString() != "0" &&
          nuevaCantidad.toString().isNotEmpty) {
        final nombreCorregido =
            item["Nombre"]?.toString() ??
            item["NombreProducto"]?.toString() ??
            item["nombre"]?.toString() ??
            "Sin nombre";
        final stockActual =
            double.tryParse(
              (item["Stock"] ?? item["stock_actual"] ?? 0).toString(),
            ) ??
            0;

        carrito.add(
          PedidoItem(
            codigo: codigo,
            nombre: nombreCorregido,
            marca: item["Marca"]?.toString() ?? item["marca"]?.toString() ?? "",
            clase: item["Clase"]?.toString() ?? item["clase"]?.toString(),
            stockActual: stockActual,
            cantidad: nuevaCantidad,
            proveedor:
                item["Proveedor"]?.toString() ?? item["proveedor"]?.toString(),
            unidad: unidadesMedida.isNotEmpty
                ? unidadesMedida.first
                : 'UNIDADES',
            tipoDestino: "VENTA",
          ),
        );
      }
    });
    PedidoDraftStorage.save(carrito);
  }

  void _actualizarCantidad(dynamic item, int delta) {
    final codigo =
        item["Codigo"]?.toString() ?? item["codigo"]?.toString() ?? "";
    if (codigo.isEmpty) return;

    setState(() {
      final index = carrito.indexWhere((c) => c.codigo == codigo);
      if (index >= 0) {
        dynamic current = carrito[index].cantidad;
        double numValue = 0.0;

        if (current is num) {
          numValue = current.toDouble();
        } else if (current is String) {
          if (current.contains('/')) {
            var parts = current.split('/');
            if (parts.length == 2) {
              numValue =
                  (double.tryParse(parts[0]) ?? 0) /
                  (double.tryParse(parts[1]) ?? 1);
            }
          } else {
            numValue = double.tryParse(current) ?? 0.0;
          }
        }

        numValue += delta;

        if (numValue <= 0) {
          carrito.removeAt(index);
        } else {
          if (numValue == numValue.toInt()) {
            carrito[index].cantidad = numValue.toInt();
          } else {
            carrito[index].cantidad = double.parse(numValue.toStringAsFixed(2));
          }
        }
      } else if (delta > 0) {
        _fijarCantidad(item, delta);
      }
    });
    PedidoDraftStorage.save(carrito);
  }

  Future<void> _editarCantidadManual(
    dynamic item,
    PedidoItem? pedidoActual,
  ) async {
    final TextEditingController controller = TextEditingController(
      text: pedidoActual != null ? pedidoActual.cantidad.toString() : "",
    );

    final val = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Ingresar Cantidad", style: TextStyle(fontSize: 16)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.text,
          decoration: const InputDecoration(
            hintText: "Ej: 1, 1.5, 1/2",
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.edit),
          ),
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text("Aceptar"),
          ),
        ],
      ),
    );

    if (val != null) {
      _fijarCantidad(item, val);
    }
  }

  void _cambiarUnidad(dynamic item, String nuevaUnidad) {
    final codigo =
        item["Codigo"]?.toString() ?? item["codigo"]?.toString() ?? "";
    setState(() {
      final index = carrito.indexWhere((c) => c.codigo == codigo);
      if (index >= 0) {
        carrito[index].unidad = nuevaUnidad;
      } else {
        _fijarCantidad(item, 1);
        final newIndex = carrito.indexWhere((c) => c.codigo == codigo);
        if (newIndex >= 0) carrito[newIndex].unidad = nuevaUnidad;
      }
    });
    PedidoDraftStorage.save(carrito);
  }

  void _cambiarDestino(dynamic item, String destino) {
    final codigo =
        item["Codigo"]?.toString() ?? item["codigo"]?.toString() ?? "";
    setState(() {
      final index = carrito.indexWhere((c) => c.codigo == codigo);
      if (index >= 0) {
        carrito[index].tipoDestino = destino;
      } else {
        _fijarCantidad(item, 1);
        final newIndex = carrito.indexWhere((c) => c.codigo == codigo);
        if (newIndex >= 0) carrito[newIndex].tipoDestino = destino;
      }
    });
    PedidoDraftStorage.save(carrito);
  }

  Future<void> _agregarNota(dynamic item) async {
    final codigo =
        item["Codigo"]?.toString() ?? item["codigo"]?.toString() ?? "";
    int index = carrito.indexWhere((c) => c.codigo == codigo);

    if (index < 0) {
      _fijarCantidad(item, 1);
      index = carrito.indexWhere((c) => c.codigo == codigo);
    }

    final currentItem = carrito[index];
    final notaController = TextEditingController(
      text: currentItem.notaCompra ?? "",
    );

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          "Nota para ${currentItem.nombre}",
          style: const TextStyle(fontSize: 16),
        ),
        content: TextField(
          controller: notaController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: "Escriba una observación...",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Guardar Nota"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        final nuevaNota = notaController.text.trim().isEmpty
            ? null
            : notaController.text.trim();
        carrito[index] = PedidoItem(
          codigo: currentItem.codigo,
          nombre: currentItem.nombre,
          marca: currentItem.marca,
          clase: currentItem.clase,
          stockActual: currentItem.stockActual,
          cantidad: currentItem.cantidad,
          proveedor: currentItem.proveedor,
          unidad: currentItem.unidad,
          tipoDestino: currentItem.tipoDestino,
          notaCompra: nuevaNota,
        );
      });
      PedidoDraftStorage.save(carrito);
    }
  }

  Future<void> autoSugerirCompras() async {
    if (resultadosFiltrados.isEmpty) return;
    int agregados = 0;

    setState(() {
      for (var item in resultadosFiltrados) {
        final double stockActual =
            double.tryParse(
              (item["Stock"] ?? item["stock_actual"] ?? 0).toString(),
            ) ??
            0;
        final double stockMinimo =
            double.tryParse((item["stock_minimo"] ?? 0).toString()) ?? 0;

        if (stockMinimo > 0 && stockActual <= stockMinimo) {
          final codigo =
              item["Codigo"]?.toString() ?? item["codigo"]?.toString() ?? "";
          if (carrito.indexWhere((c) => c.codigo == codigo) == -1 &&
              codigo.isNotEmpty) {
            int sugerencia =
                (stockMinimo - stockActual).ceil() + (stockMinimo * 0.2).ceil();
            _fijarCantidad(item, sugerencia < 1 ? 1 : sugerencia);
            agregados++;
          }
        }
      }
    });

    if (agregados > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🤖 Se auto-agregaron $agregados productos críticos.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay nuevos productos críticos para sugerir.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentList = resultadosFiltrados;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(
          widget.proveedorInicial != null
              ? "Pedido: ${widget.proveedorInicial}"
              : "Realizar Pedido Inteligente",
          style: const TextStyle(fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: abrirScanner,
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: abrirCarrito,
              ),
              if (carrito.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${carrito.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      // 🔥 SOLUCIÓN: Usamos CustomScrollView con Slivers para eliminar el Overflow por completo 🔥
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: "Buscar producto...",
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: () => buscar(searchController.text),
                      ),
                    ),
                    onSubmitted: buscar,
                  ),
                  const SizedBox(height: 8),

                  Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textValue) {
                      final q = textValue.text.trim().toLowerCase();
                      if (q.isEmpty) return marcasGlobales.take(20);
                      return marcasGlobales.where(
                        (m) => m.toLowerCase().contains(q),
                      );
                    },
                    onSelected: (val) {
                      marcaController.text = val;
                      setState(() {});
                    },
                    fieldViewBuilder:
                        (context, controller, focus, onSubmitted) {
                          if (controller.text != marcaController.text &&
                              !focus.hasFocus) {
                            controller.text = marcaController.text;
                          }
                          return TextField(
                            controller: controller,
                            focusNode: focus,
                            decoration: InputDecoration(
                              labelText: 'Refinar por Marca',
                              isDense: true,
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.filter_alt_outlined),
                              suffixIcon: controller.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        controller.clear();
                                        marcaController.clear();
                                        setState(() {});
                                      },
                                    )
                                  : null,
                            ),
                            onChanged: (val) {
                              marcaController.text = val;
                              setState(() {});
                            },
                          );
                        },
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      const Text('Búsqueda Profunda (Kardex):'),
                      Switch(
                        value: busquedaProfunda,
                        onChanged: (val) {
                          setState(() => busquedaProfunda = val);
                          if (searchController.text.length >= 2) {
                            buscar(searchController.text);
                          }
                        },
                      ),
                    ],
                  ),

                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Clase',
                            isDense: true,
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                          value: claseSeleccionada,
                          items: clasesDisponibles
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c,
                                  child: Row(
                                    children: [
                                      if (c == 'Mis favoritos')
                                        const Icon(
                                          Icons.star_rounded,
                                          color: Colors.amber,
                                          size: 20,
                                        ),
                                      if (c == 'Mis favoritos')
                                        const SizedBox(width: 8),
                                      Text(
                                        c,
                                        style: TextStyle(
                                          fontWeight: c == 'Mis favoritos'
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            setState(() => claseSeleccionada = val!);
                            buscar(searchController.text);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (esAdmin)
                    Autocomplete<String>(
                      optionsBuilder: (TextEditingValue textValue) {
                        final q = textValue.text.trim().toLowerCase();
                        if (q.isEmpty) return proveedores.take(20);
                        return proveedores.where(
                          (p) => p.toLowerCase().contains(q),
                        );
                      },
                      onSelected: (val) {
                        setState(() => proveedorSeleccionado = val);
                        buscar(searchController.text);
                      },
                      fieldViewBuilder:
                          (context, controller, focus, onSubmitted) {
                            if (proveedorSeleccionado != null &&
                                controller.text.isEmpty) {
                              controller.text = proveedorSeleccionado!;
                            }

                            return TextField(
                              controller: controller,
                              focusNode: focus,
                              decoration: InputDecoration(
                                labelText: 'Filtrar por Proveedor',
                                isDense: true,
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(
                                  Icons.local_shipping_outlined,
                                ),
                                suffixIcon: controller.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          controller.clear();
                                          setState(
                                            () => proveedorSeleccionado = null,
                                          );
                                          buscar(searchController.text);
                                        },
                                      )
                                    : null,
                              ),
                              onChanged: (val) {
                                proveedorSeleccionado = val.trim();
                              },
                              onSubmitted: (val) {
                                setState(
                                  () => proveedorSeleccionado = val.trim(),
                                );
                                buscar(searchController.text);
                              },
                            );
                          },
                    ),

                  if (currentList.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green.shade700,
                          side: BorderSide(color: Colors.green.shade700),
                        ),
                        onPressed: autoSugerirCompras,
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text(
                          'Auto-sugerir pedido (Cruzar con Mínimo)',
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          if (isLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),

          if (errorMessage != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),

          if (resultados.isEmpty && !isLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text("Busca o selecciona un proveedor para empezar"),
              ),
            )
          else if (currentList.isEmpty && !isLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  "Ningun producto coincide con los filtros aplicados",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((_, i) {
                  final item = currentList[i];

                  final codigo =
                      item["Codigo"]?.toString() ??
                      item["codigo"]?.toString() ??
                      "";
                  final proveedor =
                      item["Proveedor"]?.toString().trim() ??
                      item["proveedor"]?.toString().trim() ??
                      "";
                  final marca = item["Marca"]?.toString().trim() ?? "-";
                  final nombreCorregido =
                      item["Nombre"]?.toString() ??
                      item["NombreProducto"]?.toString() ??
                      item["nombre"]?.toString() ??
                      "Sin nombre";

                  final stockActual =
                      double.tryParse(
                        (item["Stock"] ?? item["stock_actual"] ?? 0).toString(),
                      ) ??
                      0;
                  final stockMinimo =
                      double.tryParse((item["stock_minimo"] ?? 0).toString()) ??
                      0;
                  final alertaActiva = item["alerta_lead_time"] == true;
                  final bool estaEnPeligro =
                      stockMinimo > 0 && stockActual <= stockMinimo;

                  final indexCarrito = carrito.indexWhere(
                    (c) => c.codigo == codigo,
                  );
                  final PedidoItem? pedidoActual = indexCarrito >= 0
                      ? carrito[indexCarrito]
                      : null;

                  final dynamic cantidadPedida = pedidoActual?.cantidad ?? 0;
                  final bool estaEnCarrito =
                      cantidadPedida.toString() != "0" &&
                      cantidadPedida.toString() != "";

                  final String destino = pedidoActual?.tipoDestino ?? "VENTA";
                  final bool tieneNota =
                      pedidoActual?.notaCompra != null &&
                      pedidoActual!.notaCompra!.isNotEmpty;
                  final String unidadActual =
                      pedidoActual?.unidad ??
                      (unidadesMedida.isNotEmpty
                          ? unidadesMedida.first
                          : 'UNIDADES');

                  return Card(
                    elevation: estaEnPeligro ? 3 : 1,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        color: estaEnPeligro
                            ? Colors.red.shade300
                            : Colors.grey.shade300,
                        width: estaEnPeligro ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  nombreCorregido,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              if (alertaActiva && esAdmin)
                                InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            CronogramaFormScreen(
                                              proveedorInicial:
                                                  item["proveedor_objetivo"] ??
                                                  proveedor,
                                              onSaved: () =>
                                                  buscar(searchController.text),
                                            ),
                                      ),
                                    );
                                  },
                                  child: const Icon(
                                    Icons.warning_amber_rounded,
                                    color: Colors.red,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          Text(
                            "Código: $codigo",
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            "Stock: $stockActual (Mínimo: $stockMinimo)",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: estaEnPeligro
                                  ? Colors.red.shade700
                                  : Colors.green.shade700,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            "Marca: $marca",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.blueGrey,
                            ),
                          ),
                          if (item["vdp"] != null && item["vdp"] > 0)
                            Text(
                              "Venta Diaria (VDP): ${item["vdp"]} unid.  |  Llega en: ${item["lead_time_dias"] ?? 2} días",
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.deepPurple,
                              ),
                            ),

                          const Divider(height: 10),

                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                height: 32,
                                decoration: BoxDecoration(
                                  color: estaEnCarrito
                                      ? Colors.blue.shade50
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: estaEnCarrito
                                        ? Colors.blue.shade200
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.remove,
                                        color: estaEnCarrito
                                            ? Colors.red
                                            : Colors.grey,
                                        size: 18,
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                      padding: EdgeInsets.zero,
                                      onPressed: estaEnCarrito
                                          ? () => _actualizarCantidad(item, -1)
                                          : null,
                                    ),

                                    InkWell(
                                      onTap: () => _editarCantidadManual(
                                        item,
                                        pedidoActual,
                                      ),
                                      child: Container(
                                        constraints: const BoxConstraints(
                                          minWidth: 24,
                                        ),
                                        alignment: Alignment.center,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        child: Text(
                                          '$cantidadPedida',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: estaEnCarrito
                                                ? Colors.blue.shade900
                                                : Colors.grey,
                                            decoration:
                                                TextDecoration.underline,
                                            decorationStyle:
                                                TextDecorationStyle.dotted,
                                          ),
                                        ),
                                      ),
                                    ),

                                    IconButton(
                                      icon: Icon(
                                        Icons.add,
                                        color: Colors.blue.shade700,
                                        size: 18,
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                      padding: EdgeInsets.zero,
                                      onPressed: () =>
                                          _actualizarCantidad(item, 1),
                                    ),
                                  ],
                                ),
                              ),

                              if (unidadesMedida.isNotEmpty)
                                SelectorUnidadMedida(
                                  unidadInicial: unidadActual,
                                  unidadesDisponibles: unidadesMedida,
                                  onChanged: (nuevaUnidad) =>
                                      _cambiarUnidad(item, nuevaUnidad),
                                ),

                              ChoiceChip(
                                label: const Text(
                                  'Venta',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                selected: destino == 'VENTA',
                                padding: EdgeInsets.zero,
                                labelPadding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                selectedColor: Colors.green.shade100,
                                onSelected: (_) =>
                                    _cambiarDestino(item, 'VENTA'),
                              ),
                              ChoiceChip(
                                label: const Text(
                                  'Gasto',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                selected: destino == 'GASTO',
                                padding: EdgeInsets.zero,
                                labelPadding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                selectedColor: Colors.orange.shade100,
                                onSelected: (_) =>
                                    _cambiarDestino(item, 'GASTO'),
                              ),

                              InkWell(
                                onTap: () => _agregarNota(item),
                                child: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: tieneNota
                                      ? Colors.blue.shade100
                                      : Colors.grey.shade200,
                                  child: Icon(
                                    tieneNota
                                        ? Icons.comment
                                        : Icons.comment_outlined,
                                    size: 14,
                                    color: tieneNota
                                        ? Colors.blue.shade800
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ),

                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(
                                    Icons.history_edu,
                                    size: 18,
                                    color: Colors.black87,
                                  ),
                                  tooltip: "Ver Kardex",
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) =>
                                          KardexFlotanteDialog(
                                            codigoProducto: codigo,
                                            nombreProducto: nombreCorregido,
                                          ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }, childCount: currentList.length),
              ),
            ),
        ],
      ),
    );
  }
}
