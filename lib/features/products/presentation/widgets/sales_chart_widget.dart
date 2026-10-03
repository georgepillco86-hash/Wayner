import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../data/models/sales_summary.dart';

class SalesChartWidget extends StatelessWidget {
  final List<SalesSummary> sales;

  const SalesChartWidget({
    super.key,
    required this.sales,
  });

  @override
  Widget build(BuildContext context) {
    if (sales.isEmpty) {
      return const Center(
        child: Text('No hay datos de ventas para graficar'),
      );
    }

    final spots = sales.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        entry.value.cantidadVendida,
      );
    }).toList();

    final maxY = sales
        .map((e) => e.cantidadVendida)
        .reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY + 2,
          gridData: const FlGridData(show: true),
          borderData: FlBorderData(show: true),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 3,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();

                  if (index < 0 || index >= sales.length) {
                    return const SizedBox.shrink();
                  }

                  final fecha = sales[index].fecha;

                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${fecha.day}/${fecha.month}',
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}