class Notificacion {
  final int id;
  final String titulo;
  final String mensaje;
  final bool leido;
  final DateTime fechaCreacion;

  Notificacion({
    required this.id,
    required this.titulo,
    required this.mensaje,
    required this.leido,
    required this.fechaCreacion,
  });

  factory Notificacion.fromJson(Map<String, dynamic> json) {
    return Notificacion(
      id: json['id'],
      titulo: json['titulo'],
      mensaje: json['mensaje'],
      leido: json['leido'],
      fechaCreacion: DateTime.parse(json['fecha_creacion']),
    );
  }
}
