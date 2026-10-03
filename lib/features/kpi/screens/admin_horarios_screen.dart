import 'package:flutter/material.dart';
import '../services/horarios_mapa_service.dart';

class AdminHorariosScreen extends StatefulWidget {
  const AdminHorariosScreen({super.key});

  @override
  State<AdminHorariosScreen> createState() => _AdminHorariosScreenState();
}

class _AdminHorariosScreenState extends State<AdminHorariosScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final HorariosMapaService _horariosService = HorariosMapaService();

  bool _isLoading = false;

  // Datos del Mapa
  List<dynamic> _zonas = [];
  Map<String, int> _cuadricula = {}; // Clave: "fila_columna", Valor: zona_id
  int? _zonaSeleccionadaParaPintar; // La brocha actual

  // Cuadrícula de 10x10 para simular el local
  final int _filas = 10;
  final int _columnas = 10;

  @override
  void initState() {
    super.initState();
    // Tenemos 3 pestañas: Mapa del Local, Horarios, Asignaciones
    _tabController = TabController(length: 3, vsync: this);
    _cargarDatosMapa();
  }

  Future<void> _cargarDatosMapa() async {
    setState(() => _isLoading = true);
    try {
      final zonas = await _horariosService.obtenerZonas();
      final celdas = await _horariosService.obtenerCuadricula();

      Map<String, int> mapaTemp = {};
      for (var c in celdas) {
        if (c['zona_id'] != null) {
          mapaTemp["${c['fila']}_${c['columna']}"] = c['zona_id'];
        }
      }

      setState(() {
        _zonas = zonas;
        _cuadricula = mapaTemp;
      });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _guardarMapa() async {
    setState(() => _isLoading = true);
    try {
      List<Map<String, dynamic>> celdasAguardar = [];
      _cuadricula.forEach((key, zonaId) {
        var partes = key.split('_');
        celdasAguardar.add({
          "fila": int.parse(partes[0]),
          "columna": int.parse(partes[1]),
          "zona_id": zonaId,
        });
      });

      await _horariosService.guardarCuadricula(celdasAguardar);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Mapa guardado correctamente"),
            backgroundColor: Colors.green,
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _colorFromHex(String hexColor) {
    hexColor = hexColor.toUpperCase().replaceAll("#", "");
    if (hexColor.length == 6) hexColor = "FF$hexColor";
    return Color(int.parse(hexColor, radix: 16));
  }

  // --- UI DEL DIBUJO DEL LOCAL ---
  Widget _buildMapaTab() {
    return Column(
      children: [
        // 1. PALETA DE COLORES (ZONAS)
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "1. Selecciona una Zona para pintar:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.blue),
                    tooltip: "Crear Nueva Zona",
                    onPressed: _mostrarDialogoCrearZona,
                  ),
                ],
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Botón para borrar pintura (Borrador)
                    GestureDetector(
                      onTap: () =>
                          setState(() => _zonaSeleccionadaParaPintar = null),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _zonaSeleccionadaParaPintar == null
                              ? Colors.grey.shade300
                              : Colors.white,
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.cleaning_services, size: 16),
                            SizedBox(width: 4),
                            Text("Borrador"),
                          ],
                        ),
                      ),
                    ),
                    // Lista de Zonas creadas
                    ..._zonas.map((z) {
                      bool isSelected = _zonaSeleccionadaParaPintar == z['id'];
                      return GestureDetector(
                        onTap: () => setState(
                          () => _zonaSeleccionadaParaPintar = z['id'],
                        ),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _colorFromHex(
                              z['color_hex'],
                            ).withOpacity(isSelected ? 1.0 : 0.4),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.black
                                  : Colors.transparent,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            z['nombre'],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),

        const Divider(),
        const Text(
          "2. Toca la cuadrícula para diseñar tu local",
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 8),

        // 2. LA CUADRÍCULA (EL MAPA 2D)
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1.0, // Cuadrado perfecto
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400, width: 2),
                ),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _columnas,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: _filas * _columnas,
                  itemBuilder: (context, index) {
                    int fila = index ~/ _columnas;
                    int col = index % _columnas;
                    String key = "${fila}_${col}";

                    // Buscar si esta celda tiene una zona asignada
                    int? zonaId = _cuadricula[key];
                    Color colorCelda = Colors.grey.shade100;

                    if (zonaId != null) {
                      var zonaMatch = _zonas.firstWhere(
                        (z) => z['id'] == zonaId,
                        orElse: () => null,
                      );
                      if (zonaMatch != null) {
                        colorCelda = _colorFromHex(zonaMatch['color_hex']);
                      }
                    }

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (_zonaSeleccionadaParaPintar == null) {
                            _cuadricula.remove(key); // Borrar
                          } else {
                            _cuadricula[key] =
                                _zonaSeleccionadaParaPintar!; // Pintar
                          }
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: colorCelda,
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),

        // 3. BOTÓN GUARDAR MAPA
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _guardarMapa,
              icon: const Icon(Icons.save),
              label: const Text("Guardar Distribución del Local"),
            ),
          ),
        ),
      ],
    );
  }

  // --- DIÁLOGO PARA CREAR NUEVAS ZONAS ---
  void _mostrarDialogoCrearZona() {
    final nombreCtrl = TextEditingController();
    String colorElegido = "#4CAF50"; // Verde por defecto

    // Algunos colores fijos para no complicarnos con una paleta infinita
    final colores = [
      "#F44336",
      "#4CAF50",
      "#2196F3",
      "#FFEB3B",
      "#9C27B0",
      "#795548",
      "#FF9800",
      "#795548",
      "#607D8B",
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Nueva Zona Física"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: "Nombre (Ej: Cajas, Pasillo 1)",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text("Color:"),
                Wrap(
                  spacing: 8,
                  children: colores.map((c) {
                    bool seleccionado = colorElegido == c;
                    return GestureDetector(
                      onTap: () => setDialogState(() => colorElegido = c),
                      child: CircleAvatar(
                        backgroundColor: _colorFromHex(c),
                        radius: 16,
                        child: seleccionado
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancelar"),
              ),
              FilledButton(
                onPressed: () async {
                  if (nombreCtrl.text.isEmpty) return;
                  Navigator.pop(context);
                  setState(() => _isLoading = true);
                  try {
                    await _horariosService.crearZona(
                      nombreCtrl.text.trim(),
                      colorElegido,
                    );
                    await _cargarDatosMapa();
                  } catch (e) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text("Error: $e")));
                    setState(() => _isLoading = false);
                  }
                },
                child: const Text("Crear"),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Horarios y Mapa 2D"),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true, // 🔥 PERMITE DESLIZAR LAS PESTAÑAS 🔥
          tabs: const [
            Tab(icon: Icon(Icons.map), text: "1. Mapa Físico"),
            Tab(icon: Icon(Icons.schedule), text: "2. Horarios Fijos"),
            Tab(
              icon: Icon(Icons.person_pin_circle),
              text: "3. Asignación de Puestos",
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              // Por ahora dejamos las pestañas 2 y 3 en construcción
              children: [
                _buildMapaTab(),
                const Center(
                  child: Text(
                    "Próximamente: Configurar horas de entrada y salida...",
                  ),
                ),
                const Center(
                  child: Text(
                    "Próximamente: Asignar trabajadores a zonas en tiempo real...",
                  ),
                ),
              ],
            ),
    );
  }
}
