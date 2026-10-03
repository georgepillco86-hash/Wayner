class AuditLog {
  final int id;
  final int? usuarioId;
  final String? nombreUsuario;
  final String? rol;
  final String accion;
  final String modulo;
  final String? metodo;
  final String? ruta;
  final int? estadoHttp;
  final String? detalle;
  final String? ip;
  final int? duracionMs;
  final DateTime? fechaCreacion;

  AuditLog({
    required this.id,
    required this.accion,
    required this.modulo,
    this.usuarioId,
    this.nombreUsuario,
    this.rol,
    this.metodo,
    this.ruta,
    this.estadoHttp,
    this.detalle,
    this.ip,
    this.duracionMs,
    this.fechaCreacion,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: int.tryParse(json['id'].toString()) ?? 0,
      usuarioId: json['usuario_id'] == null
          ? null
          : int.tryParse(json['usuario_id'].toString()),
      nombreUsuario: json['nombre_usuario']?.toString(),
      rol: json['rol']?.toString(),
      accion: json['accion']?.toString() ?? '',
      modulo: json['modulo']?.toString() ?? '',
      metodo: json['metodo']?.toString(),
      ruta: json['ruta']?.toString(),
      estadoHttp: json['estado_http'] == null
          ? null
          : int.tryParse(json['estado_http'].toString()),
      detalle: json['detalle']?.toString(),
      ip: json['ip']?.toString(),
      duracionMs: json['duracion_ms'] == null
          ? null
          : int.tryParse(json['duracion_ms'].toString()),
      fechaCreacion: json['fecha_creacion'] == null
          ? null
          : DateTime.tryParse(json['fecha_creacion'].toString()),
    );
  }
}
