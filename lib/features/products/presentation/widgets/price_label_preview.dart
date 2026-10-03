import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/models/product_price.dart';
import '../../../promociones/models/promocion.dart';

class PriceLabelPreview extends StatelessWidget {
  final ProductPrice? productPrice;
  final Promocion? promocion;
  final String fallbackName;
  final String fallbackCode;

  const PriceLabelPreview({
    super.key,
    required this.productPrice,
    this.promocion,
    required this.fallbackName,
    required this.fallbackCode,
  });

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final bool isPromo = promocion != null;

    final name = isPromo
        ? (promocion!.nombreProducto ?? fallbackName)
        : (productPrice?.nombreProducto ?? fallbackName);
    final code = isPromo
        ? (promocion!.codigoBarra ?? fallbackCode)
        : (productPrice?.codigoBarra ?? fallbackCode);
    final price = isPromo
        ? (promocion!.precioActualProm ?? 0.0)
        : (productPrice?.precioConIva ?? 0.0);

    // --- DATOS EXCLUSIVOS DE PROMOCIÓN ---
    final oldPrice = isPromo ? (promocion!.precioAnterior ?? 0.0) : 0.0;
    final encabezado = isPromo
        ? (promocion!.encabezado ?? 'OFERTA')
        : 'PRECIO ESPECIAL';
    final ahorro = isPromo ? (promocion!.ahorro ?? 0.0) : 0.0;
    final mecanica = isPromo ? (promocion!.mecanica ?? '') : '';
    final fInicio = isPromo ? _formatDate(promocion!.fechaInicio) : '';
    final fFin = isPromo ? _formatDate(promocion!.fechaFin) : '';

    final qrData =
        '''
Producto: $name
Código: $code
Precio venta: \$${price.toStringAsFixed(2)}
${isPromo && mecanica.isNotEmpty ? 'Mecánica: $mecanica\nVálido: $fInicio al $fFin' : ''}
''';

    // ==============================================================
    // DISEÑO 1: ETIQUETA PROMOCIONAL (VERTICAL 3X MÁS LARGO Y ALTO IMPACTO)
    // ==============================================================
    if (isPromo) {
      return Container(
        width: double.infinity,
        // 🔥 Mayor padding para alcanzar la proporción 3X
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 36),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black, width: 4),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 🔥 SIN FITTEDBOX: Encabezado GIGANTE (Rompe en 2 líneas)
            Text(
              encabezado.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 55, // Aumentado al 100%
                fontWeight: FontWeight.w900,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 12),

            // 🔥 SIN FITTEDBOX: Nombre del Producto GIGANTE (Rompe en hasta 3 líneas)
            Text(
              name.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 3,
              style: TextStyle(
                color: Colors.blue.shade900,
                fontSize: 42, // Aumentado al 100%
                fontWeight: FontWeight.w900,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 24),

            // 🔥 Título Precio Anterior
            const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'PRECIO ANTERIOR:',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // 🔥 Valor Precio Anterior (Tachado y 100% más grande)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '\$${oldPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            ),

            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '\$${price.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 95,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -2.0,
                  height: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 🔥 Título Ahorro
            const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'AHORRO:',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            // 🔥 Valor Ahorro (100% más grande)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '\$${ahorro.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 🔥 Título Mecánica
            const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'MECÁNICA:',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // 🔥 Valor Mecánica (200% más grande)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                mecanica.toUpperCase(),
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 🔥 Título Vigencia
            const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'VIGENCIA:',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // 🔥 Valor Vigencia (200% más grande)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$fInicio AL $fFin',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),

            const SizedBox(height: 24),
            // 🔥 El QR ahora es de solo el código
            QrImageView(
              data: code,
              version: QrVersions.auto,
              size: 140,
              backgroundColor: Colors.white,
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                code,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ==============================================================
    // DISEÑO 2: ETIQUETA NORMAL (HORIZONTAL CLÁSICA)
    // ==============================================================
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 4),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Text(
                name.toUpperCase(),
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  color: Colors.blue.shade900,
                  letterSpacing: -0.8,
                  height: 1.0,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 55,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'PRECIO ESPECIAL',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '\$${price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 90,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -2.0,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 45,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    QrImageView(
                      data: code,
                      version: QrVersions.auto,
                      size: 110,
                      backgroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 5),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        code,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
