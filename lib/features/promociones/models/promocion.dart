class Promocion {
  final int id;
  final String codigoBarra;
  final String nombreProducto;
  final double precioBase;
  final double precioAnterior;
  final double precioActualProm;
  final double ahorro;
  final String? encabezado;
  final String? mecanica;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final bool activa;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // 🔥 1. AGREGA LA VARIABLE AQUÍ
  final String estado;

  Promocion({
    required this.id,
    required this.codigoBarra,
    required this.nombreProducto,
    required this.precioBase,
    required this.precioAnterior,
    required this.precioActualProm,
    required this.ahorro,
    required this.encabezado,
    required this.mecanica,
    required this.fechaInicio,
    required this.fechaFin,
    required this.activa,
    this.createdAt,
    this.updatedAt,
    // 🔥 2. VALOR POR DEFECTO EN EL CONSTRUCTOR
    this.estado = 'PENDIENTE',
  });

  factory Promocion.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0;
    }

    return Promocion(
      id: json['id'] ?? 0,
      codigoBarra: json['codigo_barra']?.toString() ?? '',
      nombreProducto: json['nombre_producto']?.toString() ?? '',
      precioBase: toDouble(json['precio_base']),
      precioAnterior: toDouble(json['precio_anterior']),
      precioActualProm: toDouble(json['precio_actual_prom']),
      ahorro: toDouble(json['ahorro']),
      encabezado: json['encabezado']?.toString(),
      mecanica: json['mecanica']?.toString(),
      fechaInicio: DateTime.parse(json['fecha_inicio']),
      fechaFin: DateTime.parse(json['fecha_fin']),
      activa: json['activa'] == true,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.tryParse(json['updated_at'].toString()),

      // 🔥 3. MAPEADO DESDE EL JSON (Si viene nulo, asume 'PENDIENTE')
      estado: json['estado']?.toString() ?? 'PENDIENTE',
    );
  }
}
