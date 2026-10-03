import 'dart:convert';

class Visita {
  final int id;
  final String proveedor;
  final DateTime fechaProgramada;
  final DateTime fechaEntrega; // ---> NUEVA PROPIEDAD
  final String estado;
  final List<String> usuariosVinculados;

  Visita({
    required this.id,
    required this.proveedor,
    required this.fechaProgramada,
    required this.fechaEntrega, // ---> NUEVA PROPIEDAD
    required this.estado,
    required this.usuariosVinculados,
  });

  /// --- CÁLCULO EN TIEMPO REAL ---
  /// Retorna los días de demora calculados entre la fecha programada y la de entrega
  int get leadTimeDias => fechaEntrega.difference(fechaProgramada).inDays;

  factory Visita.fromJson(Map<String, dynamic> json) {
    // Manejo seguro del JSONB que viene de Postgres
    List<String> usuarios = [];
    if (json['usuarios_vinculados'] != null) {
      if (json['usuarios_vinculados'] is String) {
        usuarios = List<String>.from(jsonDecode(json['usuarios_vinculados']));
      } else {
        usuarios = List<String>.from(json['usuarios_vinculados']);
      }
    }

    // Parseamos primero la fecha programada de la visita
    final DateTime programada = DateTime.parse(json['fecha_programada']);

    // ---> CONTROL SEGURO DE CONVERSIÓN <---
    // Si la API devuelve 'fecha_entrega', la parseamos; si el registro es antiguo
    // y viene nulo, calculamos un valor por defecto (3 días después) para evitar crashes.
    final DateTime entrega = json['fecha_entrega'] != null
        ? DateTime.parse(json['fecha_entrega'])
        : programada.add(const Duration(days: 3));

    return Visita(
      id: json['id'] ?? 0,
      proveedor: json['proveedor'] ?? '',
      fechaProgramada: programada,
      fechaEntrega: entrega, // ---> ASIGNACIÓN DE LA NUEVA PROPIEDAD
      estado: json['estado'] ?? 'Pendiente',
      usuariosVinculados: usuarios,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'proveedor': proveedor,
      'fecha_programada': fechaProgramada.toIso8601String(),
      'fecha_entrega': fechaEntrega.toIso8601String(),
      'estado': estado,
      'usuarios_vinculados': usuariosVinculados,
    };
  }
}
