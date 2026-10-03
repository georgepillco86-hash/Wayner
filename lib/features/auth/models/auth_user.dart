class AuthUser {
  final int id;
  final String nombreUsuario;
  final String? nombreCompleto;
  final String rol;
  final bool activo;

  AuthUser({
    required this.id,
    required this.nombreUsuario,
    required this.rol,
    required this.activo,
    this.nombreCompleto,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: int.tryParse(json["id"].toString()) ?? 0,
      nombreUsuario: json["nombre_usuario"]?.toString() ?? "",
      nombreCompleto: json["nombre_completo"]?.toString(),
      rol: json["rol"]?.toString() ?? "",
      activo: json["activo"] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "nombre_usuario": nombreUsuario,
      "nombre_completo": nombreCompleto,
      "rol": rol,
      "activo": activo,
    };
  }
}