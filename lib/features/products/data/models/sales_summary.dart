class SalesSummary {
  final DateTime fecha;
  final double cantidadVendida;

  SalesSummary({
    required this.fecha,
    required this.cantidadVendida,
  });

  factory SalesSummary.fromJson(Map<String, dynamic> json) {
    return SalesSummary(
      fecha: DateTime.parse(json['Fecha'].toString()),
      cantidadVendida: double.tryParse(json['cantidad_vendida'].toString()) ?? 0,
    );
  }
}