class ProductPrice {
  final String codigoBarra;
  final String codigo;
  final String nombreProducto;
  final double precio;
  final double iva;
  final double precioConIva;
  // 🔥 NUEVA VARIABLE: Atrapa la confirmación de Python
  final bool tieneVariacion;

  ProductPrice({
    required this.codigoBarra,
    required this.codigo,
    required this.nombreProducto,
    required this.precio,
    required this.iva,
    required this.precioConIva,
    this.tieneVariacion = false,
  });

  factory ProductPrice.fromJson(Map<String, dynamic> json) {
    bool variacion = false;
    if (json['variacion'] != null) variacion = json['variacion'] == true;
    if (json['tieneVariacion'] != null)
      variacion = json['tieneVariacion'] == true;

    return ProductPrice(
      codigoBarra: json['CodigoBarra']?.toString() ?? '',
      codigo: json['Codigo']?.toString() ?? '',
      nombreProducto: json['NombreProducto']?.toString() ?? '',
      precio: double.tryParse(json['Precio'].toString()) ?? 0,
      iva: double.tryParse(json['IVA'].toString()) ?? 0,
      precioConIva: double.tryParse(json['PrecioConIVA'].toString()) ?? 0,
      tieneVariacion: variacion,
    );
  }
}
