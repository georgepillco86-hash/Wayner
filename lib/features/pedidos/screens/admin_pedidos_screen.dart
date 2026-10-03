import 'package:flutter/material.dart';

import '../services/pedidos_service.dart';
import 'admin_pedido_detalle_screen.dart';
import '../widgets/generar_pedido_proveedor_dialog.dart';
import '../widgets/generar_pedido_consolidado_dialog.dart';

class AdminPedidosScreen extends StatefulWidget {
  const AdminPedidosScreen({super.key});

  @override
  State<AdminPedidosScreen> createState() => _AdminPedidosScreenState();
}

class _AdminPedidosScreenState extends State<AdminPedidosScreen> {
  final PedidosService service = PedidosService();

  bool isLoading = true;
  String? errorMessage;

  // MODO DE VISTA: 0 = Órdenes de pedido (clásico), 1 = Por proveedores (consolidado)
  int _modoVista = 0;

  // === DATOS PARA LA VISTA CLÁSICA ===
  List<dynamic> pedidos = [];
  List<dynamic> pedidosFiltrados = [];

  // === DATOS PARA LA VISTA CONSOLIDADA ===
  List<dynamic> borradoresConsolidados = [];
  List<dynamic> borradoresFiltrados = [];

  // Controladores para los filtros
  final TextEditingController searchController = TextEditingController();
  DateTime? fechaFiltro;

  @override
  void initState() {
    super.initState();
    cargarDatos();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> cargarDatos() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      if (_modoVista == 0) {
        await _cargarVistaClasica();
      } else {
        await _cargarVistaConsolidada();
      }
    } catch (e) {
      setState(() {
        errorMessage = "No se pudieron cargar los datos";
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _cargarVistaClasica() async {
    final data = await service.listarPedidosAdmin();

    setState(() {
      pedidos = data;
      pedidosFiltrados = data;
    });

    filtrarPedidos();
  }

  Future<void> _cargarVistaConsolidada() async {
    // 🔥 FORMATO DE FECHA PARA ENVIAR A PYTHON
    String? fStr;
    if (fechaFiltro != null) {
      fStr =
          "${fechaFiltro!.year}-${fechaFiltro!.month.toString().padLeft(2, '0')}-${fechaFiltro!.day.toString().padLeft(2, '0')}";
    }

    final data = await service.listarBorradoresAgrupadosPorProveedor(
      fechaInicio: fStr,
      fechaFin: fStr,
    );

    setState(() {
      borradoresConsolidados = data;
      borradoresFiltrados = data;
    });

    filtrarBorradores();
  }

  void filtrarPedidos() {
    final query = searchController.text.toLowerCase();

    setState(() {
      pedidosFiltrados = pedidos.where((pedido) {
        final id = pedido['id']?.toString().toLowerCase() ?? '';
        final usuario = pedido['usuario']?.toString().toLowerCase() ?? '';
        final estado = pedido['estado']?.toString().toLowerCase() ?? '';
        final items = pedido['total_items']?.toString().toLowerCase() ?? '';
        final fechaStrFormateada = formatearFecha(
          pedido['fecha_creacion'],
        ).toLowerCase();
        final proveedores =
            pedido['proveedores']?.toString().toLowerCase() ?? 'varios';

        final coincideTexto =
            id.contains(query) ||
            usuario.contains(query) ||
            estado.contains(query) ||
            items.contains(query) ||
            fechaStrFormateada.contains(query) ||
            proveedores.contains(query);

        bool coincideFecha = true;
        if (fechaFiltro != null) {
          final fechaOriginal = pedido['fecha_creacion']?.toString() ?? '';
          if (fechaOriginal.isNotEmpty) {
            try {
              final fechaPedido = DateTime.parse(fechaOriginal);
              coincideFecha =
                  fechaPedido.year == fechaFiltro!.year &&
                  fechaPedido.month == fechaFiltro!.month &&
                  fechaPedido.day == fechaFiltro!.day;
            } catch (e) {
              coincideFecha = false;
            }
          } else {
            coincideFecha = false;
          }
        }

        return coincideTexto && coincideFecha;
      }).toList();
    });
  }

  void filtrarBorradores() {
    final query = searchController.text.toLowerCase();

    setState(() {
      borradoresFiltrados = borradoresConsolidados.where((provData) {
        final proveedor = provData['proveedor']?.toString().toLowerCase() ?? '';
        final items = provData['total_items']?.toString().toLowerCase() ?? '';
        final cantidadTotal =
            provData['cantidad_total']?.toString().toLowerCase() ?? '';

        final coincideTexto =
            proveedor.contains(query) ||
            items.contains(query) ||
            cantidadTotal.contains(query);

        return coincideTexto;
      }).toList();
    });
  }

  String formatearFecha(dynamic fecha) {
    if (fecha == null) return "";
    return fecha.toString().replaceAll("T", " ").split(".").first;
  }

  Color colorEstado(String estado) {
    switch (estado.toUpperCase()) {
      case "ENVIADO":
        return Colors.blue;
      case "RECIBIDO":
        return Colors.green;
      case "CANCELADO":
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Administrar pedidos"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: cargarDatos),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12.0),
            color: Colors.white,
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text("Órdenes de pedido"),
                        selected: _modoVista == 0,
                        onSelected: (selected) {
                          if (selected && _modoVista != 0) {
                            setState(() => _modoVista = 0);
                            cargarDatos();
                          }
                        },
                      ),
                      const SizedBox(width: 10),
                      ChoiceChip(
                        label: const Text("Por proveedores (Borrador)"),
                        selected: _modoVista == 1,
                        onSelected: (selected) {
                          if (selected && _modoVista != 1) {
                            setState(() => _modoVista = 1);
                            cargarDatos();
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: _modoVista == 0
                        ? "Buscar por N°, usuario, proveedor..."
                        : "Buscar proveedor...",
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              searchController.clear();
                              _modoVista == 0
                                  ? filtrarPedidos()
                                  : filtrarBorradores();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (value) =>
                      _modoVista == 0 ? filtrarPedidos() : filtrarBorradores(),
                ),

                // 🔥 FILTRO DE FECHA AHORA ES VISIBLE PARA AMBAS VISTAS 🔥
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30.0),
                          ),
                        ),
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(
                          fechaFiltro == null
                              ? "Filtrar por fecha"
                              : "Fecha: ${fechaFiltro!.day.toString().padLeft(2, '0')}/${fechaFiltro!.month.toString().padLeft(2, '0')}/${fechaFiltro!.year}",
                        ),
                        onPressed: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: fechaFiltro ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() {
                              fechaFiltro = picked;
                            });
                            cargarDatos(); // 🔥 Recarga datos desde el servidor
                          }
                        },
                      ),
                    ),
                    if (fechaFiltro != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        tooltip: "Borrar fecha",
                        onPressed: () {
                          setState(() {
                            fechaFiltro = null;
                          });
                          cargarDatos(); // 🔥 Limpia el filtro en el servidor
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : errorMessage != null
                ? Center(child: Text(errorMessage!))
                : _modoVista == 0
                ? _buildListaClasica()
                : _buildListaConsolidada(),
          ),
        ],
      ),
    );
  }

  Widget _buildListaClasica() {
    if (pedidosFiltrados.isEmpty) {
      return const Center(child: Text("No se encontraron pedidos"));
    }

    return ListView.builder(
      itemCount: pedidosFiltrados.length,
      itemBuilder: (context, index) {
        final pedido = pedidosFiltrados[index];
        final estado = pedido["estado"]?.toString() ?? "SIN ESTADO";
        final pedidoId = int.tryParse(pedido["id"].toString()) ?? 0;

        final totalProv =
            int.tryParse(pedido["total_proveedores"]?.toString() ?? "0") ?? 0;
        final sentProv =
            int.tryParse(
              pedido["proveedores_notificados"]?.toString() ?? "0",
            ) ??
            0;
        final double progressValue = totalProv == 0
            ? 0.0
            : sentProv / totalProv;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: InkWell(
            onTap: () {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) =>
                    GenerarPedidoProveedorDialog(pedidoId: pedidoId),
              ).then((_) => cargarDatos());
            },
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: colorEstado(estado),
                    child: const Icon(Icons.assignment, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Orden de pedido #$pedidoId",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text("Usuario: ${pedido["usuario"] ?? ""}"),
                        Text("Estado: $estado"),
                        Text("Items: ${pedido["total_items"] ?? 0}"),
                        Text(
                          "Fecha: ${formatearFecha(pedido["fecha_creacion"])}",
                        ),
                        Text(
                          "Proveedores: ${pedido["proveedores"] ?? 'Varios'}",
                          style: const TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.blueGrey,
                            fontSize: 13,
                          ),
                        ),
                        if (estado == "BORRADOR" && totalProv > 0) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Progreso envíos:",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                "$sentProv/$totalProv provs.",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: progressValue,
                            backgroundColor: Colors.grey.shade300,
                            color: Colors.green,
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blueGrey),
                        tooltip: "Editar Pedido",
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AdminPedidoDetalleScreen(pedidoId: pedidoId),
                            ),
                          ).then((_) => cargarDatos());
                        },
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildListaConsolidada() {
    if (borradoresFiltrados.isEmpty) {
      return const Center(
        child: Text("No se encontraron consolidaciones en BORRADOR"),
      );
    }

    return ListView.builder(
      itemCount: borradoresFiltrados.length,
      itemBuilder: (context, index) {
        final provData = borradoresFiltrados[index];
        final proveedor = provData["proveedor"]?.toString() ?? "Desconocido";
        final totalItems =
            int.tryParse(provData["total_items"]?.toString() ?? "0") ?? 0;
        final cantidadTotal =
            double.tryParse(provData["cantidad_total"]?.toString() ?? "0") ??
            0.0;
        final cantOrdenes =
            int.tryParse(provData["cantidad_ordenes"]?.toString() ?? "0") ?? 0;

        // 🔥 OBTENEMOS EL ESTADO (Notificado o No) DESDE LA BD 🔥
        final bool todoNotificado =
            provData["todo_notificado"] == true ||
            provData["todo_notificado"] == "true" ||
            provData["todo_notificado"] == 1;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: todoNotificado ? Colors.blue.shade50 : Colors.white,
          shape: todoNotificado
              ? RoundedRectangleBorder(
                  side: BorderSide(color: Colors.blue.shade300, width: 1.5),
                  borderRadius: BorderRadius.circular(10),
                )
              : null,
          child: InkWell(
            onTap: () {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => GenerarPedidoConsolidadoDialog(
                  proveedor: proveedor,
                  isNotificado: todoNotificado, // 🔥 PASAMOS LA LLAVE MÁGICA
                ),
              ).then((_) => cargarDatos());
            },
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: todoNotificado
                        ? Colors.blue.shade100
                        : Colors.orange.shade50,
                    child: Icon(
                      todoNotificado ? Icons.check_circle : Icons.domain,
                      color: todoNotificado
                          ? Colors.blue.shade900
                          : Colors.orange.shade700,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          proveedor,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: todoNotificado
                                ? Colors.blue.shade900
                                : Colors.indigo.shade900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.format_list_numbered,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "Items únicos: $totalItems",
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.production_quantity_limits,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "Cantidad a pedir: ${cantidadTotal.toStringAsFixed(0)}",
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.file_copy,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "Extraído de $cantOrdenes orden(es)",
                              style: const TextStyle(
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
