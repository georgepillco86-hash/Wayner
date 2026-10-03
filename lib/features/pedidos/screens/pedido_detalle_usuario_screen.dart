import 'package:flutter/material.dart';
import '../services/pedidos_service.dart';
import 'pedido_agregar_item_screen.dart';

class PedidoDetalleUsuarioScreen extends StatefulWidget {
  final int pedidoId;

  const PedidoDetalleUsuarioScreen({super.key, required this.pedidoId});

  @override
  State<PedidoDetalleUsuarioScreen> createState() =>
      _PedidoDetalleUsuarioScreenState();
}

class _PedidoDetalleUsuarioScreenState
    extends State<PedidoDetalleUsuarioScreen> {
  final PedidosService service = PedidosService();

  bool isLoading = true;
  String? errorMessage;
  Map<String, dynamic>? pedido;

  @override
  void initState() {
    super.initState();
    cargarDetalle();
  }

  Future<void> cargarDetalle() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final data = await service.obtenerDetallePedidoUsuario(widget.pedidoId);
      setState(() {
        pedido = data;
      });
    } catch (e) {
      setState(() {
        errorMessage = "Error al cargar los detalles del pedido";
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  String formatearFecha(dynamic fecha) {
    if (fecha == null) return "";
    return fecha.toString().replaceAll("T", " ").split(".").first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text("Orden de pedido #${widget.pedidoId}"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: cargarDetalle),
          if (pedido != null && pedido!["estado"] == "BORRADOR")
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () async {
                // 🔥 Redirige al NUEVO buscador inteligente 🔥
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        PedidoAgregarItemScreen(pedidoId: widget.pedidoId),
                  ),
                );
                if (result == true) {
                  cargarDetalle();
                }
              },
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(
              child: Text(
                errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            )
          : pedido == null
          ? const Center(child: Text("Pedido no encontrado"))
          : _buildContenido(),
    );
  }

  Widget _buildContenido() {
    final items = pedido!["items"] as List<dynamic>? ?? [];

    // 🔥 Calculamos los proveedores dinámicamente desde los items 🔥
    final List<String> listaProveedores = items
        .map((i) => i['proveedor']?.toString() ?? 'SIN PROVEEDOR')
        .toSet()
        .where((p) => p.trim().isNotEmpty)
        .toList();
    final String proveedoresTexto = listaProveedores.isNotEmpty
        ? listaProveedores.join(', ')
        : 'Varios';
    final String usuario = pedido!["usuario"]?.toString() ?? "Desconocido";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🔥 CABECERA ACTUALIZADA 🔥
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Orden de pedido #${pedido!['id']}",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text("Estado: ${pedido!['estado'] ?? 'SIN ESTADO'}"),
              Text("Fecha: ${formatearFecha(pedido!['fecha_creacion'])}"),
              if (pedido!['observacion'] != null &&
                  pedido!['observacion'].toString().isNotEmpty)
                Text("Observación: ${pedido!['observacion']}"),
              const SizedBox(height: 8),
              Text(
                "Generado por: $usuario",
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                "Proveedores: $proveedoresTexto",
                style: const TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: Colors.blueGrey,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            "Productos enviados",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final numItem = index + 1;
              final String destino =
                  item['tipo_destino']?.toString() ?? 'VENTA';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.lightBlue.shade100,
                    child: Text(
                      '$numItem',
                      style: TextStyle(
                        color: Colors.blue.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    item['nombre_producto']?.toString() ?? 'Sin nombre',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: destino == 'VENTA'
                              ? Colors.blue.shade50
                              : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: destino == 'VENTA'
                                ? Colors.blue.shade200
                                : Colors.orange.shade200,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.shopping_cart_outlined,
                              size: 12,
                              color: destino == 'VENTA'
                                  ? Colors.blue.shade700
                                  : Colors.orange.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              destino,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: destino == 'VENTA'
                                    ? Colors.blue.shade700
                                    : Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text("Código: ${item['codigo_producto']}"),
                      Text("Marca: ${item['marca'] ?? '-'}"),
                      Text(
                        "Cantidad: ${item['cantidad_pedida']} ${item['unidad'] ?? 'UNIDADES'}",
                      ),
                    ],
                  ),
                  trailing: pedido!["estado"] == "BORRADOR"
                      ? PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'eliminar') {
                              await service.eliminarItemPedido(
                                pedidoId: widget.pedidoId,
                                itemId: item['id'],
                              );
                              cargarDetalle();
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'eliminar',
                              child: Text(
                                'Eliminar',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        )
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
