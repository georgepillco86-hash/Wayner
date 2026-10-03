class ProductBalance {
  final String codigo;
  final String? codigoBarra;
  final String nombre;
  final double stock;
  final String? marca;
  final String? clase;

  // Quitamos la palabra "final" para poder actualizar los precios en vivo
  double precio;
  double iva;
  double costo;

  // --- PROPIEDADES PREDICTIVAS BÁSICAS ---
  final double vdp;
  final int leadTimeDias;

  // --- NUEVAS PROPIEDADES DEL CRONOGRAMA Y ESTADÍSTICA ---
  final bool alertaLeadTime;
  final String? mensajeAlerta;
  final String? proveedorObjetivo;

  // 🔥 ETIQUETAS INTELIGENTES (BADGES) 🔥
  final bool cambioPrecio;
  final bool esNuevo; // <-- Indicador de producto nuevo (menos de 15 días)
  final bool
  enBodega; // <-- Indicador de producto recién llegado a bodega (últimos 5 días)
  final bool enPromocion; // <-- Indicador de Promoción Activa

  // 🔥 NUEVO: Control de Ventas Diarias 🔥
  final double ventasHoy;

  // Datos matemáticos desde Python
  final double volatilidad;
  final double stockSeguridad;
  final double stockMinimoBackend;

  ProductBalance({
    required this.codigo,
    this.codigoBarra,
    required this.nombre,
    required this.stock,
    this.marca,
    this.clase,
    this.precio = 0.0,
    this.iva = 0.0,
    this.costo = 0.0,
    this.vdp = 0.0,
    this.leadTimeDias = 3,
    this.alertaLeadTime = false,
    this.mensajeAlerta,
    this.proveedorObjetivo,
    this.cambioPrecio = false,
    this.esNuevo = false,
    this.enBodega = false,
    this.enPromocion = false,
    this.ventasHoy = 0.0, // 🔥 NUEVO
    this.volatilidad = 0.0,
    this.stockSeguridad = 0.0,
    this.stockMinimoBackend = 0.0,
  });

  factory ProductBalance.fromJson(Map<String, dynamic> json) {
    return ProductBalance(
      codigo: json['Codigo']?.toString() ?? '',
      codigoBarra: json['CodigoBarra']?.toString(),
      nombre: json['Nombre']?.toString() ?? '',
      stock: double.tryParse(json['Stock']?.toString() ?? '0') ?? 0.0,
      marca: json['Marca']?.toString(),
      clase: json['Clase']?.toString(),
      precio: double.tryParse(json['Precio']?.toString() ?? '0') ?? 0.0,
      iva: double.tryParse(json['IVA']?.toString() ?? '0') ?? 0.0,
      costo: double.tryParse(json['Costo']?.toString() ?? '0') ?? 0.0,

      // Variables Base
      vdp:
          double.tryParse(
            json['vdp']?.toString() ?? json['VDP']?.toString() ?? '0',
          ) ??
          0.0,
      leadTimeDias:
          int.tryParse(
            json['lead_time_dias']?.toString() ??
                json['LeadTime']?.toString() ??
                '3',
          ) ??
          3,

      // --- NUEVOS CAMPOS MAPEADOS ---
      alertaLeadTime: json['alerta_lead_time'] == true,
      mensajeAlerta: json['mensaje_alerta']?.toString(),

      // Intentamos atrapar el proveedor objetivo
      proveedorObjetivo:
          json['proveedor_objetivo']?.toString() ??
          json['Proveedor']?.toString(),

      // 🔥 ETIQUETAS INTELIGENTES 🔥
      cambioPrecio: json['cambio_precio'] == true,
      esNuevo: json['es_nuevo'] == true,
      enBodega: json['en_bodega'] == true,
      enPromocion: json['en_promocion'] == true,

      // 🔥 NUEVO 🔥
      ventasHoy: double.tryParse(json['ventas_hoy']?.toString() ?? '0') ?? 0.0,

      // Variables Estadísticas
      volatilidad:
          double.tryParse(json['volatilidad']?.toString() ?? '0') ?? 0.0,
      stockSeguridad:
          double.tryParse(json['stock_seguridad']?.toString() ?? '0') ?? 0.0,
      stockMinimoBackend:
          double.tryParse(json['stock_minimo']?.toString() ?? '0') ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Codigo': codigo,
      'CodigoBarra': codigoBarra,
      'Nombre': nombre,
      'Stock': stock,
      'Marca': marca,
      'Clase': clase,
      'Precio': precio,
      'IVA': iva,
      'Costo': costo,
      'vdp': vdp,
      'lead_time_dias': leadTimeDias,
      'alerta_lead_time': alertaLeadTime,
      'mensaje_alerta': mensajeAlerta,
      'proveedor_objetivo': proveedorObjetivo,
      'cambio_precio': cambioPrecio,
      'es_nuevo': esNuevo,
      'en_bodega': enBodega,
      'en_promocion': enPromocion,
      'ventas_hoy': ventasHoy, // 🔥 NUEVO
      'volatilidad': volatilidad,
      'stock_seguridad': stockSeguridad,
      'stock_minimo': stockMinimoBackend,
    };
  }

  // ==========================================
  // LÓGICA DE INVENTARIO INTELIGENTE
  // ==========================================

  /// Calcula el stock mínimo matemático
  /// [diasCobertura] = Cuántos días quieres que te dure la mercadería exhibida (ej. 7, 14, 30)
  double calcularStockMinimo({int diasCobertura = 7}) {
    // Si no tiene historial de ventas (VDP = 0), su stock mínimo no se puede calcular
    if (vdp <= 0) return 0;

    // Si el backend ya nos envió el Mínimo Estadístico exacto (Punto de Reorden)
    if (stockMinimoBackend > 0) {
      // Usamos la matemática avanzada del backend (que ya incluye el Stock de Seguridad)
      // y le sumamos lo que deseas tener de exhibición (Cobertura)
      return stockMinimoBackend + (vdp * diasCobertura);
    }

    // Fórmula de respaldo (Fallback) en caso de que el backend falle
    return (vdp * diasCobertura) + (vdp * leadTimeDias);
  }

  /// Evalúa la salud actual del producto comparando el stock físico con el mínimo
  String calcularNivelStock({int diasCobertura = 7}) {
    if (stock <= 0) return 'Agotado';

    final stockMinimo = calcularStockMinimo(diasCobertura: diasCobertura);

    // Si es un producto nuevo o sin ventas recientes, lo marcamos como Normal
    if (stockMinimo == 0) return 'Normal';

    final ratio = stock / stockMinimo;

    if (ratio <= 0.5)
      return 'Bajo'; // Tiene menos de la mitad de lo que necesita
    if (ratio <= 1.0)
      return 'Medio'; // Tiene casi lo justo, debería pedir pronto
    if (ratio <= 2.0) return 'Normal'; // Tiene suficiente para cubrir la meta
    return 'Alto'; // Tiene más del doble de lo que necesita (Sobre-stock)
  }
}
