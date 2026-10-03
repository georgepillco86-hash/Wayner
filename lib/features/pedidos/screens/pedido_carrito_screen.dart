import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/pedido_item.dart';
import '../../auth/models/auth_user.dart';
import '../../../core/storage/session_storage.dart';
import '../services/pedidos_service.dart';
import '../../../core/storage/pedido_draft_storage.dart';

class PedidoCarritoScreen extends StatefulWidget {
  final List<PedidoItem> carrito;

  const PedidoCarritoScreen({
    super.key,
    required this.carrito,
  });

  @override
  State<PedidoCarritoScreen> createState() => _PedidoCarritoScreenState();
}

class _PedidoCarritoScreenState extends State<PedidoCarritoScreen> {
  late List<PedidoItem> carrito;

  @override
  void initState() {
    super.initState();
    carrito = widget.carrito;
  }

  bool get todosSeleccionados =>
      carrito.isNotEmpty && carrito.every((e) => e.seleccionado);

  void toggleSeleccionarTodos() {
    final nuevoValor = !todosSeleccionados;

    setState(() {
      for (var item in carrito) {
        item.seleccionado = nuevoValor;
      }
    });
    PedidoDraftStorage.save(carrito);
  }

  void eliminarItem(int index) {
    setState(() {
      carrito.removeAt(index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Producto eliminado del carrito")),
    );
    PedidoDraftStorage.save(carrito);
  }

  Future<void> enviarPedido() async {
    final seleccionados = carrito.where((item) => item.seleccionado).toList();

    if (seleccionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecciona al menos un producto")),
      );
      return;
    }

    try {
      final AuthUser? user = await SessionStorage.getUser();

      final payload = {
        "usuario_creacion": user?.nombreUsuario ?? "SIN USUARIO",
        "observacion": "Pedido creado desde app, pendiente de aprobación",
        "items": seleccionados.map((item) {
          return {
            "codigo_producto": item.codigo,
            "cantidad_pedida": item.cantidad,
            "unidad": item.unidad,
            "nota_compra": item.notaCompra,
            "tipo_destino": item.tipoDestino,
          };
        }).toList(),
      };

      await PedidosService().crearPedido(payload);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pedido creado como borrador")),
      );

      setState(() {
        carrito.clear();
      });

      await PedidoDraftStorage.clear();

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error al enviar pedido")),
      );
    }
  }

  void mostrarSelectorProveedor(
    List<String> proveedores,
    List<PedidoItem> seleccionados,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    "Selecciona el proveedor",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: proveedores.length,
                    itemBuilder: (context, index) {
                      final proveedor = proveedores[index];

                      final productosProveedor = seleccionados.where((item) {
                        final proveedorItem = item.proveedor == null ||
                                item.proveedor!.trim().isEmpty
                            ? "SIN PROVEEDOR"
                            : item.proveedor!.trim();

                        return proveedorItem == proveedor;
                      }).toList();

                      return ListTile(
                        leading: const Icon(Icons.business),
                        title: Text(
                          proveedor,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          "${productosProveedor.length} producto(s) seleccionado(s)",
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.pop(context);

                          final texto = construirTextoPedido(
                            proveedor,
                            productosProveedor,
                          );

                          mostrarVistaPrevia(texto);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String construirTextoPedido(String proveedor, List<PedidoItem> productos) {
    final productosVenta = productos
        .where((item) => item.tipoDestino.toUpperCase() == "VENTA")
        .toList();

    final productosGasto = productos
        .where((item) => item.tipoDestino.toUpperCase() == "GASTO")
        .toList();

    String texto = "Hola, por favor ayudarme con el siguiente pedido:\n\n";
    texto += "Proveedor: $proveedor\n\n";

    if (productosVenta.isNotEmpty) {
      texto += "🛒 PRODUCTOS PARA VENTA\n\n";

      for (int i = 0; i < productosVenta.length; i++) {
        final item = productosVenta[i];

        texto += "${i + 1}. ${item.nombre}\n";
        texto += "Código: ${item.codigo}\n";
        texto += "Marca: ${item.marca}\n";
        texto += "Cantidad: ${item.cantidad} ${item.unidad ?? 'UNIDADES'}\n";

        if (item.notaCompra != null && item.notaCompra!.trim().isNotEmpty) {
          texto += "Nota: ${item.notaCompra}\n";
        }

        texto += "\n";
      }
    }

    if (productosGasto.isNotEmpty) {
      texto += "🔥 PRODUCTOS PARA GASTO / CONSUMO INTERNO\n\n";

      for (int i = 0; i < productosGasto.length; i++) {
        final item = productosGasto[i];

        texto += "${i + 1}. ${item.nombre}\n";
        texto += "Código: ${item.codigo}\n";
        texto += "Marca: ${item.marca}\n";
        texto += "Cantidad: ${item.cantidad} ${item.unidad ?? 'UNIDADES'}\n";

        if (item.notaCompra != null && item.notaCompra!.trim().isNotEmpty) {
          texto += "Nota: ${item.notaCompra}\n";
        }

        texto += "\n";
      }
    }

    texto += "Gracias.";

    return texto;
  }

  void mostrarVistaPrevia(String texto) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Vista previa del pedido"),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Text(texto),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cerrar"),
          ),
          ElevatedButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: texto));
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Pedido copiado")),
              );
            },
            child: const Text("Copiar"),
          ),
        ],
      ),
    );
  }

  Widget _buildTipoDestinoBadge(PedidoItem producto) {
    final esGasto = producto.tipoDestino.toUpperCase() == "GASTO";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: esGasto ? Colors.orange.shade100 : Colors.blue.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: esGasto ? Colors.orange.shade700 : Colors.blue.shade700,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            esGasto ? Icons.local_fire_department : Icons.shopping_cart,
            size: 14,
            color: esGasto ? Colors.orange.shade900 : Colors.blue.shade900,
          ),
          const SizedBox(width: 4),
          Text(
            esGasto ? "GASTO" : "VENTA",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: esGasto ? Colors.orange.shade900 : Colors.blue.shade900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(PedidoItem producto, int index) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: producto.seleccionado,
              onChanged: (value) {
                setState(() {
                  producto.seleccionado = value ?? false;
                });

                PedidoDraftStorage.save(carrito);
              },
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    producto.nombre,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  _buildTipoDestinoBadge(producto),
                  const SizedBox(height: 6),
                  Text(
                    "Código: ${producto.codigo}",
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "Marca: ${producto.marca}",
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "Proveedor: ${producto.proveedor == null || producto.proveedor!.trim().isEmpty ? "SIN PROVEEDOR" : producto.proveedor}",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text("Stock: ${producto.stockActual}"),
                  Text(
                    "Cantidad: ${producto.cantidad} ${producto.unidad ?? 'UNIDADES'}",
                  ),
                  if (producto.notaCompra != null &&
                      producto.notaCompra!.trim().isNotEmpty)
                    Text(
                      "Nota de compra: ${producto.notaCompra}",
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () {
                    setState(() {
                      if (producto.cantidad > 1) {
                        producto.cantidad--;
                      }
                    });
                    PedidoDraftStorage.save(carrito);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    setState(() {
                      producto.cantidad++;
                    });
                    PedidoDraftStorage.save(carrito);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => eliminarItem(index),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final seleccionados = carrito.where((e) => e.seleccionado).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Carrito de pedido"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "Productos seleccionados: $seleccionados/${carrito.length}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: toggleSeleccionarTodos,
                  child: Text(
                    todosSeleccionados
                        ? "Deseleccionar todos"
                        : "Seleccionar todos",
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: carrito.isEmpty
                ? const Center(
                    child: Text("No hay productos en el carrito"),
                  )
                : ListView.builder(
                    itemCount: carrito.length,
                    itemBuilder: (context, index) {
                      return _buildItem(carrito[index], index);
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: enviarPedido,
                icon: const Icon(Icons.send),
                label: const Text("Enviar pedido"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}