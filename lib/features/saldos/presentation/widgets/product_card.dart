import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // 🔥 Importamos provider
import 'stock_health_bar.dart';
import '../../data/models/product_balance.dart';

import '../../../cronograma/presentation/screens/cronograma_form_screen.dart';

// 🔥 Asegúrate de ajustar esta ruta según dónde guardaste tu favorites_provider.dart
import 'package:ferrotienda_flutter_proyecto/features/favoritos/providers/favorites_provider.dart';

// 🔥 Importamos las ventanas flotantes
import 'kardex_flotante_dialog.dart';
import 'ventas_flotante_dialog.dart';
import 'cenefa_flotante_dialog.dart';
import 'historial_costos_flotante_dialog.dart';

class ProductCard extends StatelessWidget {
  final ProductBalance product;
  final bool esAdmin;

  const ProductCard({super.key, required this.product, this.esAdmin = false});

  @override
  Widget build(BuildContext context) {
    final double costoBase = product.costo;
    final double ivaPorcentaje = product.iva;

    final bool tieneIva = ivaPorcentaje > 0;

    final double costoCalculado = tieneIva
        ? costoBase * (1 + (ivaPorcentaje / 100.0))
        : costoBase;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // =====================================
          // 1. EL CONTENIDO PRINCIPAL DE LA CARTA
          // =====================================
          Padding(
            // Le damos un poco más de aire arriba (top: 12) para proteger contra las etiquetas
            padding: const EdgeInsets.only(top: 12.0, bottom: 4.0),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 4.0,
                  ),
                  child: Row(
                    // 🔥 Centramos verticalmente todo el bloque para que el precio baje 🔥
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // --- COLUMNA IZQUIERDA (Título, Subtítulo y Barra) ---
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 🔥 NUEVO: BOTÓN DE FAVORITOS (ESTRELLA) 🔥
                                Consumer<FavoritesProvider>(
                                  builder: (context, favProvider, child) {
                                    final isFav = favProvider.isFavorite(
                                      product.codigo,
                                    );
                                    return GestureDetector(
                                      onTap: () {
                                        favProvider.toggleFavorite(
                                          product.codigo,
                                          product.nombre,
                                          marca: product.marca ?? 'Sin Marca',
                                          clase: product.clase ?? 'Sin Clase',
                                        );
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8.0,
                                        ),
                                        child: Icon(
                                          isFav
                                              ? Icons.star_rounded
                                              : Icons.star_outline_rounded,
                                          color: isFav
                                              ? Colors.amber.shade600
                                              : Colors.grey.shade400,
                                          size: 26.0,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 25.0),
                                    child: Text(
                                      product.nombre,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ),
                                if (product.alertaLeadTime == true && esAdmin)
                                  Tooltip(
                                    message:
                                        product.mensajeAlerta ??
                                        'Falta cronograma. Toque para crear.',
                                    child: GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                CronogramaFormScreen(
                                                  onSaved: () {},
                                                ),
                                          ),
                                        );
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.only(left: 4.0),
                                        child: Icon(
                                          Icons.warning_rounded,
                                          color: Colors.red,
                                          size: 24.0,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Código: ${product.codigo}\nMarca: ${product.marca ?? '-'}\nClase: ${product.clase ?? '-'}',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 12),
                            StockHealthBar(product: product, diasCobertura: 7),
                          ],
                        ),
                      ),

                      const SizedBox(width: 12),

                      // --- COLUMNA DERECHA (Precios y Ventas) ---
                      Column(
                        mainAxisSize:
                            MainAxisSize.min, // Se adapta a su contenido
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${product.precio.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 20.4,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                              height: 1.0,
                            ),
                          ),

                          if (esAdmin) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Costo: \$${costoCalculado.toStringAsFixed(4)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              tieneIva
                                  ? 'Inc. IVA ($ivaPorcentaje%)'
                                  : 'Sin IVA',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],

                          const SizedBox(height: 12),
                          // 🔥 Ventas de Hoy 🔥
                          Text(
                            'Ventas (Hoy): ${product.ventasHoy.toInt()}',
                            style: TextStyle(
                              fontSize:
                                  12, // Un poco más grande para mejor lectura
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),
                const Divider(height: 1),

                Padding(
                  padding: const EdgeInsets.only(top: 4.0, bottom: 0.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => VentasFlotanteDialog(
                              codigoProducto: product.codigo,
                              nombreProducto: product.nombre,
                            ),
                          );
                        },
                        icon: Icon(
                          Icons.bar_chart,
                          size: 18,
                          color: Colors.blue.shade700,
                        ),
                        label: const Text(
                          'Ventas',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => KardexFlotanteDialog(
                              codigoProducto: product.codigo,
                              nombreProducto: product.nombre,
                            ),
                          );
                        },
                        icon: Icon(
                          Icons.table_chart,
                          size: 18,
                          color: Colors.teal.shade700,
                        ),
                        label: const Text(
                          'Kardex',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) =>
                                CenefaFlotanteDialog(product: product),
                          );
                        },
                        icon: Icon(
                          Icons.print,
                          size: 18,
                          color: Colors.deepPurple.shade700,
                        ),
                        label: const Text(
                          'Cenefa',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      if (esAdmin)
                        TextButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) =>
                                  HistorialCostosFlotanteDialog(
                                    codigoProducto: product.codigo,
                                    nombreProducto: product.nombre,
                                  ),
                            );
                          },
                          icon: Icon(
                            Icons.history,
                            size: 18,
                            color: Colors.orange.shade800,
                          ),
                          label: const Text(
                            'Historial',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // =====================================
          // 2. ETIQUETAS INTELIGENTES (TOP RIGHT)
          // =====================================
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(8)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (product.enPromocion)
                    Tooltip(
                      message: "Producto en Promoción",
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        color: Colors.purple.shade600,
                        child: const Text(
                          'P',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                  if (product.cambioPrecio)
                    Tooltip(
                      message: "Atención: Cambio de precio detectado",
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        color: Colors.orange.shade700,
                        child: const Text(
                          'C',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                  if (product.esNuevo)
                    Tooltip(
                      message:
                          "Producto Nuevo (Menos de 15 días en el sistema)",
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        color: Colors.green.shade600,
                        child: const Text(
                          'N',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                  if (product.enBodega)
                    Tooltip(
                      message: "Recién llegado a Bodega (Últimos 5 días)",
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        color: Colors.blue.shade600,
                        child: const Text(
                          'B',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
