class Merma {
  final int? id;
  final String codigo;
  final String nombreProducto;
  final double cantidad;
  final String? proveedor;
  final String novedad;
  final String? comentario;
  final DateTime? fechaRegistro;
  final String estado;
  final String usuario;
  final bool activo;
  final String?
  contactoProveedor; // 🔥 NUEVO: Celular del proveedor extraído de cronograma_pedidos
  final double?
  ultimoCosto; // 🔥 NUEVO: Costo histórico real obtenido de pedido_items
  final double
  cantidadDespachada; // 🔥 NUEVO: Progreso de los productos retirados

  Merma({
    this.id,
    required this.codigo,
    required this.nombreProducto,
    required this.cantidad,
    this.proveedor,
    required this.novedad,
    this.comentario,
    this.fechaRegistro,
    required this.estado,
    required this.usuario,
    required this.activo,
    this.contactoProveedor,
    this.ultimoCosto,
    this.cantidadDespachada = 0.0, // 🔥 NUEVO: Por defecto inicia en 0
  });

  factory Merma.fromJson(Map<String, dynamic> json) {
    return Merma(
      id: json['id'],
      codigo: json['codigo'] ?? '',
      nombreProducto: json['nombre_producto'] ?? '',
      cantidad: double.tryParse(json['cantidad']?.toString() ?? '0') ?? 0.0,
      proveedor: json['proveedor'],
      novedad: json['novedad'] ?? '',
      comentario: json['comentario'],
      fechaRegistro: json['fecha_registro'] != null
          ? DateTime.parse(json['fecha_registro'])
          : null,
      estado: json['estado'] ?? 'Pendiente',
      usuario: json['usuario'] ?? '',
      activo: json['activo'] ?? true,
      contactoProveedor: json['contacto_proveedor']?.toString(),
      ultimoCosto: json['ultimo_costo'] != null
          ? double.tryParse(json['ultimo_costo'].toString())
          : null,
      // 🔥 NUEVO: Extrae de la base de datos lo que ya se ha despachado
      cantidadDespachada:
          double.tryParse(json['cantidad_despachada']?.toString() ?? '0') ??
          0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'codigo': codigo,
      'nombre_producto': nombreProducto,
      'cantidad': cantidad,
      'proveedor': proveedor,
      'novedad': novedad,
      'comentario': comentario,
      'ultimo_costo': ultimoCosto,
      'cantidad_despachada': cantidadDespachada, // 🔥 NUEVO
    };
  }
}
