import 'package:flutter/material.dart';
import '../../data/models/product_balance.dart';

class StockHealthBar extends StatelessWidget {
  final ProductBalance product;
  final int diasCobertura; // 7, 14, 30, 60...

  const StockHealthBar({
    Key? key,
    required this.product,
    this.diasCobertura = 7, // Por defecto 1 semana
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final nivel = product.calcularNivelStock(diasCobertura: diasCobertura);
    final stockMinimo = product.calcularStockMinimo(
      diasCobertura: diasCobertura,
    );

    Color barColor;
    double fillPercentage;

    switch (nivel) {
      case 'Agotado':
        barColor = Colors.red;
        fillPercentage = 0.05; // Un poco de color para que se vea
        break;
      case 'Bajo':
        barColor = Colors.orange;
        fillPercentage = 0.3;
        break;
      case 'Medio':
        barColor = Colors.yellow.shade700;
        fillPercentage = 0.6;
        break;
      case 'Normal':
        barColor = Colors.green;
        fillPercentage = 0.9;
        break;
      case 'Alto':
      default:
        barColor = Colors.blue;
        fillPercentage = 1.0;
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Stock: ${product.stock.toInt()} (Mín: ${stockMinimo.toInt()})',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            Text(
              nivel,
              style: TextStyle(
                fontSize: 12,
                color: barColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 8,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: fillPercentage,
            child: Container(
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
