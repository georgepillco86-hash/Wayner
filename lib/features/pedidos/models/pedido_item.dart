class PedidoItem {
  final String codigo;
  final String nombre;
  final String marca;
  final String? clase;
  final double stockActual;

  dynamic cantidad; // 🔥 CAMBIADO: Ahora acepta 1, 1.5 o "1/2"
  bool seleccionado;

  final String? proveedor;
  String? notaCompra;

  String? unidad;
  String tipoDestino;

  PedidoItem({
    required this.codigo,
    required this.nombre,
    required this.marca,
    this.clase,
    required this.stockActual,
    required this.cantidad,
    this.seleccionado = false,
    this.proveedor,
    this.notaCompra,
    this.unidad,
    this.tipoDestino = "VENTA",
  });

  factory PedidoItem.fromJson(Map<String, dynamic> json) {
    return PedidoItem(
      codigo: json["codigo"]?.toString() ?? "",
      nombre: json["nombre"]?.toString() ?? "",
      marca: json["marca"]?.toString() ?? "",
      clase: json["clase"]?.toString(),
      stockActual: double.tryParse((json["stock_actual"] ?? 0).toString()) ?? 0,
      cantidad: json["cantidad"] ?? 1, // 🔥 Recibe cualquier formato
      seleccionado: json["seleccionado"] == true,
      proveedor: json["proveedor"]?.toString(),
      notaCompra: json["nota_compra"]?.toString(),
      unidad: json["unidad"]?.toString(),
      tipoDestino: json["tipo_destino"]?.toString() ?? "VENTA",
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "codigo": codigo,
      "nombre": nombre,
      "marca": marca,
      "clase": clase,
      "stock_actual": stockActual,
      "cantidad": cantidad,
      "seleccionado": seleccionado,
      "proveedor": proveedor,
      "unidad": unidad,
      "nota_compra": notaCompra,
      "tipo_destino": tipoDestino,
    };
  }
}
