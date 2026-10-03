class MermaHistorial {
  final int id;
  final int mermaId;
  final String usuario;
  final String? estadoAnterior;
  final String estadoNuevo;
  final String comentario;
  final String? notaCredito;
  final DateTime fechaRegistro;

  MermaHistorial({
    required this.id,
    required this.mermaId,
    required this.usuario,
    this.estadoAnterior,
    required this.estadoNuevo,
    required this.comentario,
    this.notaCredito,
    required this.fechaRegistro,
  });

  factory MermaHistorial.fromJson(Map<String, dynamic> json) {
    return MermaHistorial(
      id: json['id'],
      mermaId: json['merma_id'],
      usuario: json['usuario'] ?? 'Desconocido',
      estadoAnterior: json['estado_anterior'],
      estadoNuevo: json['estado_nuevo'] ?? 'Pendiente',
      comentario: json['comentario'] ?? '',
      notaCredito: json['nota_credito'],
      fechaRegistro: DateTime.parse(json['fecha_registro']),
    );
  }
}
