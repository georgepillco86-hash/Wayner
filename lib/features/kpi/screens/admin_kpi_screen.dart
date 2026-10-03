import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../services/kpi_service.dart';
import '../services/horarios_mapa_service.dart';

class AdminKpiScreen extends StatefulWidget {
  const AdminKpiScreen({super.key});

  @override
  State<AdminKpiScreen> createState() => _AdminKpiScreenState();
}

class _AdminKpiScreenState extends State<AdminKpiScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final KpiService _kpiService = KpiService();
  final HorariosMapaService _horariosService = HorariosMapaService();

  // --- Variables KPI ---
  List<dynamic> _bancoTareas = [];
  List<dynamic> _tareasRevision = [];
  List<dynamic> _ranking = [];
  List<dynamic> _usuarios = [];
  bool _isLoading = false;

  DateTime _fechaSeleccionada = DateTime.now();

  // 🔥 Variables para el Premio/Castigo 🔥
  String _premioMes = "Aún no definido";
  String _castigoMes = "Aún no definido";

  // --- Variables para el Catálogo (Resumen vs Actividades) ---
  bool _verResumenCat = true;
  List<Map<String, dynamic>> _actividadesPlantillas = [];

  // --- Variables Horarios y Mapa ---
  List<dynamic> _horarios = [];
  List<dynamic> _zonas = [];
  List<dynamic> _asignaciones = [];
  Map<String, int> _cuadricula = {};

  int _filas = 10;
  int _columnas = 10;
  int? _zonaSeleccionadaParaPintar;
  bool _modoDiseno = true;

  String _filtroJornada = 'General';
  bool _vistaCalendario = true;
  double _horaSeleccionada = 7.0;

  int _diaMapa = 1;
  String _jornadaMapa = 'General';

  final TransformationController _mapController = TransformationController();
  final GlobalKey _mapaKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // 🔥 6 pestañas para incluir Expo Datos 🔥
    _tabController = TabController(length: 6, vsync: this);
    _cargarDatosIniciales();
  }

  @override
  void dispose() {
    _mapController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosIniciales() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _kpiService.obtenerBancoTareas(),
        _kpiService.obtenerTareasEnRevision(),
        _kpiService.obtenerRankingMes(
          _fechaSeleccionada.month,
          _fechaSeleccionada.year,
        ),
        _kpiService.obtenerUsuarios(),
        _horariosService.obtenerHorarios(),
        _horariosService.obtenerZonas(),
        _horariosService.obtenerCuadricula(),
        _horariosService.obtenerAsignaciones(),
        _kpiService.obtenerPlantillas().catchError((e) => []),
        _kpiService
            .obtenerPremioMes(_fechaSeleccionada.month, _fechaSeleccionada.year)
            .catchError(
              (e) => {
                "premio": "Aún no definido",
                "castigo": "Aún no definido",
              },
            ),
      ]);

      Map<String, int> mapaTemp = {};
      int maxFila = 10;
      int maxCol = 10;

      for (var c in results[6] as List<dynamic>) {
        if (c['fila'] >= maxFila) maxFila = c['fila'] + 1;
        if (c['columna'] >= maxCol) maxCol = c['columna'] + 1;

        if (c['zona_id'] != null) {
          mapaTemp["${c['fila']}_${c['columna']}"] = c['zona_id'];
        }
      }

      setState(() {
        _bancoTareas = results[0] as List<dynamic>;
        _tareasRevision = results[1] as List<dynamic>;
        _ranking = results[2] as List<dynamic>;
        _usuarios = results[3] as List<dynamic>;
        _horarios = results[4] as List<dynamic>;
        _zonas = results[5] as List<dynamic>;
        _cuadricula = mapaTemp;
        _asignaciones = results[7] as List<dynamic>;
        _actividadesPlantillas = List<Map<String, dynamic>>.from(
          results[8] as List<dynamic>,
        );

        final premioData = results[9] as Map<String, dynamic>;
        _premioMes = premioData['premio'] ?? "Aún no definido";
        _castigoMes = premioData['castigo'] ?? "Aún no definido";

        _filas = maxFila;
        _columnas = maxCol;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _seleccionarFechaFiltro() async {
    final DateTime? seleccion = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      helpText: "FILTRAR GESTIÓN DE RENDIMIENTO",
    );
    if (seleccion != null && seleccion != _fechaSeleccionada) {
      setState(() => _fechaSeleccionada = seleccion);
      _cargarDatosIniciales();
    }
  }

  Future<void> _ejecutarRobotGuardian() async {
    setState(() => _isLoading = true);
    try {
      await _kpiService.forzarGuardianRutinas();
      await _cargarDatosIniciales();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("🤖 Robot ejecutado: Tareas actualizadas."),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al ejecutar el robot: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // =========================================================================
  // 1. LÓGICA DE KPI Y CATÁLOGO
  // =========================================================================

  void _mostrarFormularioPlantillaSimple([
    Map<String, dynamic>? plantillaActual,
  ]) {
    final bool esEdicion = plantillaActual != null;
    final tareaInfo = esEdicion ? plantillaActual['tareas'][0] : null;

    final nombreCtrl = TextEditingController(
      text: esEdicion ? tareaInfo['nombre'] : "",
    );
    final descCtrl = TextEditingController(
      text: esEdicion ? (tareaInfo['descripcion'] ?? "") : "",
    );
    final pesoCtrl = TextEditingController(
      text: esEdicion ? tareaInfo['peso'].toString() : "1.0",
    );
    String tipo = esEdicion ? tareaInfo['tipo'] : 'RUTINA';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
              esEdicion
                  ? "Editar Plantilla Tarea"
                  : "Nueva Tarea Suelta (Plantilla)",
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Crea una tarea rápida para asignarla después.",
                    style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nombreCtrl,
                    decoration: const InputDecoration(
                      labelText: "Nombre de la Tarea",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: "Descripción (Opcional)",
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: tipo,
                    decoration: const InputDecoration(
                      labelText: "Tipo de Tarea",
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'RUTINA',
                        child: Text("Rutina (Se repite)"),
                      ),
                      DropdownMenuItem(
                        value: 'EVENTUAL',
                        child: Text("Eventual"),
                      ),
                    ],
                    onChanged: (val) => setDialogState(() => tipo = val!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pesoCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: "Peso (Puntos base)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
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
                    final payload = {
                      "nombre_plantilla": nombreCtrl.text.trim(),
                      "es_bloque": false,
                      "tareas": [
                        {
                          "nombre": nombreCtrl.text.trim(),
                          "descripcion": descCtrl.text.trim(),
                          "tipo": tipo,
                          "peso": double.tryParse(pesoCtrl.text) ?? 1.0,
                        },
                      ],
                    };

                    if (esEdicion) {
                      await _kpiService.editarPlantilla(
                        plantillaActual['id'],
                        payload,
                      );
                    } else {
                      await _kpiService.crearPlantilla(payload);
                    }

                    await _cargarDatosIniciales();
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("✅ Plantilla guardada"),
                          backgroundColor: Colors.green,
                        ),
                      );
                  } catch (e) {
                    if (mounted)
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text("Error: $e")));
                    setState(() => _isLoading = false);
                  }
                },
                child: Text(esEdicion ? "Actualizar" : "Guardar en BD"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _mostrarFormularioPlantillaBloque([
    Map<String, dynamic>? plantillaActual,
  ]) {
    final bool esEdicion = plantillaActual != null;

    final nombreBloqueCtrl = TextEditingController(
      text: esEdicion ? plantillaActual['nombre_plantilla'] : "",
    );
    final nombreTareaCtrl = TextEditingController();
    final descTareaCtrl = TextEditingController();
    final pesoTareaCtrl = TextEditingController(text: "1.0");
    String tipoTarea = 'RUTINA';

    List<Map<String, dynamic>> tareasDelBloque = esEdicion
        ? List<Map<String, dynamic>>.from(plantillaActual['tareas'])
        : [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
              esEdicion ? "Editar Bloque de Tareas" : "Crear Bloque de Tareas",
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Agrupa varias tareas bajo un mismo nombre para asignarlas de golpe.",
                      style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nombreBloqueCtrl,
                      decoration: const InputDecoration(
                        labelText: "Nombre del Grupo (Ej: Apertura Local)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const Divider(height: 32),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Agregar Tarea al Bloque:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nombreTareaCtrl,
                      decoration: const InputDecoration(
                        labelText: "Nombre de la Tarea",
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descTareaCtrl,
                      decoration: const InputDecoration(
                        labelText: "Descripción (Opcional)",
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: tipoTarea,
                            decoration: const InputDecoration(isDense: true),
                            items: const [
                              DropdownMenuItem(
                                value: 'RUTINA',
                                child: Text("Rutina"),
                              ),
                              DropdownMenuItem(
                                value: 'EVENTUAL',
                                child: Text("Eventual"),
                              ),
                            ],
                            onChanged: (val) =>
                                setDialogState(() => tipoTarea = val!),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: pesoTareaCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Peso",
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () {
                        if (nombreTareaCtrl.text.isEmpty) return;
                        setDialogState(() {
                          tareasDelBloque.add({
                            "nombre": nombreTareaCtrl.text.trim(),
                            "descripcion": descTareaCtrl.text.trim(),
                            "tipo": tipoTarea,
                            "peso": double.tryParse(pesoTareaCtrl.text) ?? 1.0,
                          });
                          nombreTareaCtrl.clear();
                          descTareaCtrl.clear();
                          pesoTareaCtrl.text = "1.0";
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text("Añadir al Grupo"),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.blueGrey,
                      ),
                    ),

                    if (tareasDelBloque.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Tareas incluidas en este bloque:",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: tareasDelBloque.length,
                        itemBuilder: (ctx, i) {
                          final t = tareasDelBloque[i];
                          return Card(
                            elevation: 1,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              dense: true,
                              title: Text(
                                t['nombre'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                "${t['tipo']} • Peso: ${t['peso']}",
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.remove_circle,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () => setDialogState(
                                  () => tareasDelBloque.removeAt(i),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancelar"),
              ),
              FilledButton(
                onPressed: () async {
                  if (nombreBloqueCtrl.text.isEmpty ||
                      tareasDelBloque.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Debes dar un nombre al bloque y agregar al menos una tarea.",
                        ),
                      ),
                    );
                    return;
                  }

                  Navigator.pop(context);
                  setState(() => _isLoading = true);

                  try {
                    final payload = {
                      "nombre_plantilla": nombreBloqueCtrl.text.trim(),
                      "es_bloque": true,
                      "tareas": tareasDelBloque,
                    };

                    if (esEdicion) {
                      await _kpiService.editarPlantilla(
                        plantillaActual['id'],
                        payload,
                      );
                    } else {
                      await _kpiService.crearPlantilla(payload);
                    }

                    await _cargarDatosIniciales();
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("✅ Bloque guardado en BD"),
                          backgroundColor: Colors.green,
                        ),
                      );
                  } catch (e) {
                    if (mounted)
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text("Error: $e")));
                    setState(() => _isLoading = false);
                  }
                },
                child: Text(esEdicion ? "Actualizar" : "Guardar en BD"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _mostrarFormularioTarea([Map<String, dynamic>? tareaActual]) {
    final bool esEdicion = tareaActual != null;

    final nombreCtrl = TextEditingController(
      text: esEdicion ? tareaActual['nombre'] : "",
    );
    final descCtrl = TextEditingController(
      text: esEdicion ? (tareaActual['descripcion'] ?? "") : "",
    );
    final pesoCtrl = TextEditingController(
      text: esEdicion ? tareaActual['peso'].toString() : "1.0",
    );

    String tipo = esEdicion ? tareaActual['tipo'] : 'RUTINA';
    String? usuarioSeleccionado = esEdicion
        ? tareaActual['usuario_asignado']
        : null;

    Map<String, dynamic>? plantillaSeleccionada;

    DateTime? fechaCaducidad =
        esEdicion && tareaActual['fecha_caducidad'] != null
        ? DateTime.tryParse(tareaActual['fecha_caducidad'])
        : null;

    Map<int, bool> diasSeleccionados = {
      1: false,
      2: false,
      3: false,
      4: false,
      5: false,
      6: false,
      7: false,
    };
    final mapDias = {1: "L", 2: "M", 3: "X", 4: "J", 5: "V", 6: "S", 7: "D"};

    // 🔥 NUEVO: Frecuencia de repetición mensual (Por defecto 4 = todas las semanas)
    int frecuenciaSeleccionada = 4;

    if (esEdicion && tareaActual['dias_repeticion'] != null) {
      final parts = tareaActual['dias_repeticion'].toString().split('|');
      final diasConfigurados = parts[0].split(',');

      for (var d in diasConfigurados) {
        if (d.trim().isNotEmpty) diasSeleccionados[int.parse(d)] = true;
      }

      if (parts.length > 1) {
        frecuenciaSeleccionada = int.tryParse(parts[1]) ?? 4;
      }
    }

    final trabajadores = _usuarios.where((u) => u['activo'] == true).toList();
    if (usuarioSeleccionado != null &&
        !trabajadores.any((t) => t['nombre_usuario'] == usuarioSeleccionado)) {
      usuarioSeleccionado = null;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
              esEdicion ? "Editar Tarea Asignada" : "Asignar Tarea / KPI",
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!esEdicion && _actividadesPlantillas.isNotEmpty) ...[
                    DropdownButtonFormField<Map<String, dynamic>>(
                      isExpanded: true,
                      value: plantillaSeleccionada,
                      decoration: const InputDecoration(
                        labelText: "📌 Asignar Plantilla / Bloque",
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Color(0xFFE3F2FD),
                      ),
                      items: [
                        const DropdownMenuItem<Map<String, dynamic>>(
                          value: null,
                          child: Text(
                            "Ninguno (Crear tarea manual)",
                            style: TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ),
                        ..._actividadesPlantillas.map((plantilla) {
                          return DropdownMenuItem<Map<String, dynamic>>(
                            value: plantilla,
                            child: Text(
                              plantilla['nombre_plantilla'],
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setDialogState(() {
                          plantillaSeleccionada = val;
                          if (val != null && val['es_bloque'] == false) {
                            var t = val['tareas'][0];
                            nombreCtrl.text = t['nombre'];
                            descCtrl.text = t['descripcion'] ?? '';
                            tipo = t['tipo'];
                            pesoCtrl.text = t['peso'].toString();
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (plantillaSeleccionada != null &&
                      plantillaSeleccionada!['es_bloque'] == true) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.library_add_check,
                            color: Colors.amber,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Se crearán ${plantillaSeleccionada!['tareas'].length} tareas para este colaborador de forma automática.",
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    TextField(
                      controller: nombreCtrl,
                      decoration: const InputDecoration(
                        labelText: "Nombre de la Tarea",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: "Descripción",
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: tipo,
                      decoration: const InputDecoration(
                        labelText: "Tipo de Tarea",
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'RUTINA',
                          child: Text("Rutina (Se repite)"),
                        ),
                        DropdownMenuItem(
                          value: 'EVENTUAL',
                          child: Text("Eventual (Una sola vez)"),
                        ),
                      ],
                      onChanged: (val) => setDialogState(() => tipo = val!),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: pesoCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: "Peso (Puntos)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: usuarioSeleccionado,
                    decoration: const InputDecoration(
                      labelText: "Asignar a Colaborador",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    items: trabajadores
                        .map(
                          (u) => DropdownMenuItem<String>(
                            value: u['nombre_usuario'],
                            child: Text(
                              u['nombre_usuario'],
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      setDialogState(() {
                        usuarioSeleccionado = val;
                        // Auto-marcamos los días que el usuario ya tiene horario configurado
                        diasSeleccionados.updateAll((key, value) => false);
                        for (var h in _horarios) {
                          if (h['usuario'] == val) {
                            diasSeleccionados[h['dia_semana']] = true;
                          }
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  if (tipo == 'RUTINA') ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Días de repetición (Para Rutinas):",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Wrap(
                      spacing: 4,
                      children: diasSeleccionados.keys.map((dia) {
                        return FilterChip(
                          label: Text(mapDias[dia]!),
                          selected: diasSeleccionados[dia]!,
                          onSelected: (bool selected) => setDialogState(
                            () => diasSeleccionados[dia] = selected,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // 🔥 Frecuencia Mensual 🔥
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      value: frecuenciaSeleccionada,
                      decoration: const InputDecoration(
                        labelText: "Frecuencia al Mes",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.repeat),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 4,
                          child: Text("4 Veces (Todas las semanas)"),
                        ),
                        DropdownMenuItem(
                          value: 2,
                          child: Text("2 Veces (Semanas saltadas)"),
                        ),
                        DropdownMenuItem(value: 1, child: Text("1 Vez al mes")),
                      ],
                      onChanged: (val) =>
                          setDialogState(() => frecuenciaSeleccionada = val!),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (tipo == 'EVENTUAL')
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        "Fecha Límite (Para Eventuales):",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        fechaCaducidad == null
                            ? "Toca para seleccionar fecha"
                            : "${fechaCaducidad!.day}/${fechaCaducidad!.month}/${fechaCaducidad!.year}",
                        style: TextStyle(
                          color: fechaCaducidad == null
                              ? Colors.red
                              : Colors.blue,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.calendar_today,
                        color: Colors.blue,
                      ),
                      onTap: () async {
                        final seleccion = await showDatePicker(
                          context: context,
                          initialDate: fechaCaducidad ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2030),
                        );
                        if (seleccion != null)
                          setDialogState(() => fechaCaducidad = seleccion);
                      },
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancelar"),
              ),
              FilledButton(
                onPressed: () async {
                  if (usuarioSeleccionado == null) return;
                  if (plantillaSeleccionada == null && nombreCtrl.text.isEmpty)
                    return;

                  Navigator.pop(context);
                  setState(() => _isLoading = true);

                  List<int> dias = [];
                  diasSeleccionados.forEach((key, value) {
                    if (value) dias.add(key);
                  });

                  // 🔥 EMPAQUETAMOS LA FRECUENCIA JUNTO CON LOS DÍAS 🔥
                  String diasRep = "${dias.join(',')}|$frecuenciaSeleccionada";

                  String fechaStr = fechaCaducidad != null
                      ? "${fechaCaducidad!.year}-${fechaCaducidad!.month.toString().padLeft(2, '0')}-${fechaCaducidad!.day.toString().padLeft(2, '0')}"
                      : "";

                  try {
                    if (plantillaSeleccionada != null &&
                        plantillaSeleccionada!['es_bloque'] == true) {
                      List<dynamic> tareasDelBloque =
                          plantillaSeleccionada!['tareas'];
                      for (var t in tareasDelBloque) {
                        final datosGuardar = {
                          "nombre": t['nombre'],
                          "descripcion": t['descripcion'],
                          "tipo": t['tipo'],
                          "peso": t['peso'],
                          "usuario_asignado": usuarioSeleccionado,
                          "dias_repeticion": t['tipo'] == 'RUTINA'
                              ? diasRep
                              : null,
                          "fecha_caducidad":
                              t['tipo'] == 'EVENTUAL' && fechaStr.isNotEmpty
                              ? fechaStr
                              : null,
                        };
                        await _kpiService.crearTareaBanco(datosGuardar);
                      }
                      if (mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "✅ ${tareasDelBloque.length} tareas asignadas",
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                    } else {
                      if (tipo == 'EVENTUAL' && fechaStr.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Debes seleccionar una fecha."),
                          ),
                        );
                        setState(() => _isLoading = false);
                        return;
                      }

                      final datosGuardar = {
                        "nombre": nombreCtrl.text.trim(),
                        "descripcion": descCtrl.text.trim(),
                        "tipo": tipo,
                        "peso": double.tryParse(pesoCtrl.text) ?? 1.0,
                        "usuario_asignado": usuarioSeleccionado,
                        "dias_repeticion": tipo == 'RUTINA' ? diasRep : null,
                        "fecha_caducidad": tipo == 'EVENTUAL' ? fechaStr : null,
                      };

                      if (esEdicion) {
                        await _kpiService.editarTareaBanco(
                          tareaActual['id'],
                          datosGuardar,
                        );
                      } else {
                        await _kpiService.crearTareaBanco(datosGuardar);
                      }
                    }
                    _cargarDatosIniciales();
                  } catch (e) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text("Error: $e")));
                    setState(() => _isLoading = false);
                  }
                },
                child: Text(
                  plantillaSeleccionada != null &&
                          plantillaSeleccionada!['es_bloque'] == true
                      ? "Asignar Bloque"
                      : "Guardar Tarea",
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _eliminarTarea(int tareaId) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Eliminar Tarea Asignada"),
        content: const Text(
          "¿Estás seguro de que deseas eliminar esta tarea de este colaborador?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      setState(() => _isLoading = true);
      try {
        await _kpiService.eliminarTareaBanco(tareaId);
        _cargarDatosIniciales();
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Error: $e")));
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildResumenList(Map<String, List<dynamic>> tareasPorColaborador) {
    if (_bancoTareas.isEmpty)
      return const Center(
        child: Text("No hay tareas asignadas a colaboradores."),
      );

    return ListView(
      padding: const EdgeInsets.all(8),
      children: tareasPorColaborador.entries.map((entry) {
        String colaborador = entry.key;
        List<dynamic> tareasDelColaborador = entry.value;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      colaborador.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      "${tareasDelColaborador.length} tareas",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              ...tareasDelColaborador.map((tarea) {
                // 🔥 DESEMPAQUETADO VISUAL DE LA FRECUENCIA 🔥
                String repVisual = tarea['dias_repeticion'] ?? 'Ninguno';
                if (repVisual.contains('|')) {
                  var parts = repVisual.split('|');
                  repVisual = "${parts[0]} (Frec: ${parts[1]}/mes)";
                }

                return Column(
                  children: [
                    ListTile(
                      title: Text(
                        tarea['nombre'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (tarea['descripcion'] != null &&
                              tarea['descripcion'].toString().isNotEmpty)
                            Text(tarea['descripcion']),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: tarea['tipo'] == 'RUTINA'
                                      ? Colors.blue.shade50
                                      : Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  tarea['tipo'],
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: tarea['tipo'] == 'RUTINA'
                                        ? Colors.blue
                                        : Colors.orange,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Peso: ${tarea['peso']}",
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  tarea['tipo'] == 'RUTINA'
                                      ? "Días: $repVisual"
                                      : "Vence: ${tarea['fecha_caducidad'] ?? 'Sin fecha'}",
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: tarea['tipo'] == 'RUTINA'
                                        ? Colors.grey
                                        : Colors.redAccent,
                                    fontWeight: tarea['tipo'] == 'EVENTUAL'
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.edit,
                              color: Colors.blue,
                              size: 20,
                            ),
                            onPressed: () => _mostrarFormularioTarea(tarea),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.red,
                              size: 20,
                            ),
                            onPressed: () => _eliminarTarea(tarea['id']),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                  ],
                );
              }),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActividadesList() {
    if (_actividadesPlantillas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.library_books, size: 60, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              "No hay Plantillas ni Bloques en la Base de Datos.",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _actividadesPlantillas.length,
      itemBuilder: (context, index) {
        final plantilla = _actividadesPlantillas[index];
        bool esBloque = plantilla['es_bloque'] == true;

        if (esBloque) {
          List<dynamic> tareasInside = plantilla['tareas'];
          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.indigo,
                child: Icon(Icons.layers, color: Colors.white),
              ),
              title: Text(
                plantilla['nombre_plantilla'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                "${tareasInside.length} tareas incluidas en este bloque",
                style: const TextStyle(color: Colors.blueGrey),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blueGrey),
                    onPressed: () =>
                        _mostrarFormularioPlantillaBloque(plantilla),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () async {
                      setState(() => _isLoading = true);
                      try {
                        await _kpiService.eliminarPlantilla(plantilla['id']);
                        await _cargarDatosIniciales();
                        if (mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Bloque eliminado de la BD"),
                            ),
                          );
                      } catch (e) {
                        if (mounted)
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text("Error: $e")));
                      } finally {
                        setState(() => _isLoading = false);
                      }
                    },
                  ),
                ],
              ),
              children: tareasInside.map((t) {
                return ListTile(
                  title: Text(t['nombre']),
                  subtitle: Text(
                    "${t['tipo']} • Peso: ${t['peso']} ${t['descripcion'] != '' ? '• ' + t['descripcion'] : ''}",
                  ),
                );
              }).toList(),
            ),
          );
        } else {
          var t = plantilla['tareas'][0];
          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: t['tipo'] == 'RUTINA'
                    ? Colors.blue.shade100
                    : Colors.orange.shade100,
                child: Icon(
                  t['tipo'] == 'RUTINA' ? Icons.loop : Icons.event,
                  color: t['tipo'] == 'RUTINA' ? Colors.blue : Colors.orange,
                ),
              ),
              title: Text(
                plantilla['nombre_plantilla'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (t['descripcion'] != null &&
                      t['descripcion'].toString().isNotEmpty)
                    Text(t['descripcion']),
                  const SizedBox(height: 4),
                  Text(
                    "Tarea Suelta • ${t['tipo']} • Puntos: ${t['peso']}",
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blueGrey),
                    onPressed: () =>
                        _mostrarFormularioPlantillaSimple(plantilla),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () async {
                      setState(() => _isLoading = true);
                      try {
                        await _kpiService.eliminarPlantilla(plantilla['id']);
                        await _cargarDatosIniciales();
                        if (mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Plantilla eliminada de la BD"),
                            ),
                          );
                      } catch (e) {
                        if (mounted)
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text("Error: $e")));
                      } finally {
                        setState(() => _isLoading = false);
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildBancoTareasTab() {
    Map<String, List<dynamic>> tareasPorColaborador = {};
    for (var tarea in _bancoTareas) {
      String usuario = tarea['usuario_asignado'] ?? 'Sin Asignar';
      if (!tareasPorColaborador.containsKey(usuario)) {
        tareasPorColaborador[usuario] = [];
      }
      tareasPorColaborador[usuario]!.add(tarea);
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_verResumenCat) {
            _mostrarFormularioTarea();
          } else {
            showModalBottomSheet(
              context: context,
              builder: (ctx) => SafeArea(
                child: Wrap(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        "¿Qué deseas crear en la Base de Datos?",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.task, color: Colors.blue),
                      title: const Text("Tarea Suelta (Plantilla)"),
                      subtitle: const Text(
                        "Crea una plantilla rápida de una sola tarea.",
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        _mostrarFormularioPlantillaSimple();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.layers, color: Colors.orange),
                      title: const Text("Bloque de Tareas"),
                      subtitle: const Text(
                        "Agrupa varias tareas para asignarlas de golpe.",
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        _mostrarFormularioPlantillaBloque();
                      },
                    ),
                  ],
                ),
              ),
            );
          }
        },
        icon: const Icon(Icons.add),
        label: Text(_verResumenCat ? "Asignar Tarea" : "Nueva Plantilla"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  ChoiceChip(
                    label: const Text('📋 Resumen de Colaboradores'),
                    selected: _verResumenCat,
                    onSelected: (val) => setState(() => _verResumenCat = true),
                  ),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: const Text('📚 Actividades (Plantillas)'),
                    selected: !_verResumenCat,
                    onSelected: (val) => setState(() => _verResumenCat = false),
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: _verResumenCat
                ? _buildResumenList(tareasPorColaborador)
                : _buildActividadesList(),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // FUNCIONES DE AUDITORÍA Y RANKING
  // =========================================================================

  Widget _buildAuditoriaTab() {
    final fechaStr =
        "${_fechaSeleccionada.year}-${_fechaSeleccionada.month.toString().padLeft(2, '0')}-${_fechaSeleccionada.day.toString().padLeft(2, '0')}";
    final tareasFiltradas = _tareasRevision
        .where((t) => t['fecha'] == fechaStr)
        .toList();

    if (tareasFiltradas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            Text(
              "Todo al día el $fechaStr.\nNo hay tareas pendientes por auditar.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: tareasFiltradas.length,
      itemBuilder: (context, index) {
        final tarea = tareasFiltradas[index];
        return Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.blue, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "De: ${tarea['usuario']}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.blue,
                      ),
                    ),
                    const Chip(
                      label: Text(
                        "EN REVISIÓN",
                        style: TextStyle(fontSize: 10, color: Colors.white),
                      ),
                      backgroundColor: Colors.blue,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  tarea['nombre_tarea'],
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  "📅 Fecha: ${tarea['fecha']}   ⭐ Vale: ${tarea['peso']} puntos",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const Divider(),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () => _mostrarDialogoEvaluar(tarea),
                    icon: const Icon(Icons.rule),
                    label: const Text("Evaluar Trabajo"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _mostrarDialogoEvaluar(Map<String, dynamic> tarea) {
    double calificacion = 1.0;
    final comentarioCtrl = TextEditingController(text: "Excelente trabajo.");

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Evaluar Tarea"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tarea['nombre_tarea'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text("Calificación (0.0 a 1.0)"),
                Slider(
                  value: calificacion,
                  min: 0.0,
                  max: 1.0,
                  divisions: 10,
                  label: calificacion.toString(),
                  onChanged: (val) => setDialogState(() => calificacion = val),
                ),
                Text(
                  "Nota seleccionada: $calificacion",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: comentarioCtrl,
                  decoration: const InputDecoration(
                    labelText: "Comentario/Retroalimentación",
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
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
                  Navigator.pop(context);
                  setState(() => _isLoading = true);
                  try {
                    await _kpiService.evaluarTarea(
                      tarea['id'],
                      calificacion,
                      comentarioCtrl.text,
                      tarea['usuario'],
                      tarea['nombre_tarea'],
                    );
                    _cargarDatosIniciales();
                  } catch (e) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text("Error: $e")));
                    setState(() => _isLoading = false);
                  }
                },
                child: const Text("Guardar Evaluación"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _mostrarDialogoPremioCastigo() {
    final premioCtrl = TextEditingController(
      text: _premioMes != "Aún no definido" ? _premioMes : "",
    );
    final castigoCtrl = TextEditingController(
      text: _castigoMes != "Aún no definido" ? _castigoMes : "",
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("🏆 Definir Recompensas"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Define qué ganará el mejor empleado y qué hará el peor. Todos recibirán una notificación.",
              style: TextStyle(fontSize: 12, color: Colors.blueGrey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: premioCtrl,
              decoration: const InputDecoration(
                labelText: "Premio al 1er Lugar (Ej: Bono \$50, Pizza)",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.star, color: Colors.amber),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: castigoCtrl,
              decoration: const InputDecoration(
                labelText:
                    "Castigo al último (Ej: Limpiar el baño, Pagar colas)",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.warning, color: Colors.red),
              ),
              maxLines: 2,
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
              if (premioCtrl.text.isEmpty || castigoCtrl.text.isEmpty) return;
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                await _kpiService.guardarPremioMes(
                  _fechaSeleccionada.month,
                  _fechaSeleccionada.year,
                  premioCtrl.text.trim(),
                  castigoCtrl.text.trim(),
                );
                await _cargarDatosIniciales();
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "✅ Recompensas guardadas. Notificando a colaboradores...",
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
              } catch (e) {
                if (mounted)
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text("Error: $e")));
                setState(() => _isLoading = false);
              }
            },
            child: const Text("Guardar y Notificar"),
          ),
        ],
      ),
    );
  }

  Widget _buildRankingTab() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.amber.shade100, Colors.orange.shade50],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amber.shade300),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.emoji_events, color: Colors.orange, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "MES: ${_fechaSeleccionada.month}/${_fechaSeleccionada.year}",
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "🏆 Premio: $_premioMes",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "⚠️ Castigo: $_castigoMes",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade900,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blueGrey),
                onPressed: _mostrarDialogoPremioCastigo,
                tooltip: "Editar Recompensas",
              ),
            ],
          ),
        ),
        Expanded(
          child: _ranking.isEmpty
              ? Center(
                  child: Text(
                    "Aún no hay evaluaciones en el mes de ${_fechaSeleccionada.month}.",
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _ranking.length,
                  itemBuilder: (context, index) {
                    final item = _ranking[index];
                    final bool esLider = index == 0;
                    return Card(
                      elevation: esLider ? 4 : 1,
                      color: esLider ? Colors.amber.shade50 : Colors.white,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: esLider
                              ? Colors.amber
                              : Colors.blueGrey,
                          child: esLider
                              ? const Icon(
                                  Icons.emoji_events,
                                  color: Colors.white,
                                )
                              : Text("${index + 1}"),
                        ),
                        title: Text(
                          item['usuario'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          "${item['total_tareas_evaluadas']} tareas evaluadas",
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "${item['total_puntos']}",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: esLider
                                    ? Colors.amber.shade800
                                    : Colors.black87,
                              ),
                            ),
                            const Text(
                              "Puntos",
                              style: TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // =========================================================================
  // 2. MÓDULO HORARIOS DE TRABAJO
  // =========================================================================
  String _formatTime(TimeOfDay time) =>
      "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00";
  TimeOfDay _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  void _eliminarHorarioDia(String usuario, int diaSemana) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Eliminar Horario"),
        content: Text(
          "¿Deseas eliminar el horario de $usuario para el día $diaSemana?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      setState(() => _isLoading = true);
      try {
        await _horariosService.eliminarHorarioDia(usuario, diaSemana);
        await _cargarDatosIniciales();
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Día eliminado"),
              backgroundColor: Colors.green,
            ),
          );
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Error: $e")));
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _mostrarDialogoHorario([Map<String, dynamic>? horarioExistente]) {
    final bool esEdicion = horarioExistente != null;
    String? usuarioSeleccionado = esEdicion
        ? horarioExistente['usuario']
        : null;
    String jornadaSeleccionada = esEdicion
        ? horarioExistente['jornada']
        : 'Matutino';
    Map<int, bool> diasSeleccionados = {
      1: false,
      2: false,
      3: false,
      4: false,
      5: false,
      6: false,
      7: false,
    };
    final mapDias = {1: "L", 2: "M", 3: "X", 4: "J", 5: "V", 6: "S", 7: "D"};
    List<int> diasOriginales = [];

    if (esEdicion) {
      for (var h in _horarios) {
        if (h['usuario'] == horarioExistente['usuario'] &&
            h['jornada'] == horarioExistente['jornada']) {
          diasSeleccionados[h['dia_semana']] = true;
          diasOriginales.add(h['dia_semana']);
        }
      }
    }

    TimeOfDay horaIngreso = esEdicion
        ? _parseTime(horarioExistente['hora_ingreso'])
        : const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay horaSalida = esEdicion
        ? _parseTime(horarioExistente['hora_salida'])
        : const TimeOfDay(hour: 18, minute: 0);
    TimeOfDay recesoInicio = esEdicion
        ? _parseTime(horarioExistente['receso_inicio'])
        : const TimeOfDay(hour: 13, minute: 0);
    TimeOfDay recesoFin = esEdicion
        ? _parseTime(horarioExistente['receso_fin'])
        : const TimeOfDay(hour: 14, minute: 0);
    final trabajadores = _usuarios.where((u) => u['activo'] == true).toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
              esEdicion
                  ? "Editar Horario ($jornadaSeleccionada)"
                  : "Crear Horarios",
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: usuarioSeleccionado,
                    decoration: const InputDecoration(
                      labelText: "Colaborador",
                      border: OutlineInputBorder(),
                    ),
                    items: trabajadores
                        .map(
                          (u) => DropdownMenuItem<String>(
                            value: u['nombre_usuario'],
                            child: Text(u['nombre_usuario']),
                          ),
                        )
                        .toList(),
                    onChanged: esEdicion
                        ? null
                        : (val) =>
                              setDialogState(() => usuarioSeleccionado = val),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: jornadaSeleccionada,
                    decoration: const InputDecoration(
                      labelText: "Jornada",
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Matutino',
                        child: Text("Matutino (Mañana)"),
                      ),
                      DropdownMenuItem(
                        value: 'Vespertino',
                        child: Text("Vespertino (Tarde/Noche)"),
                      ),
                    ],
                    onChanged: (val) =>
                        setDialogState(() => jornadaSeleccionada = val!),
                  ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Días de la semana:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    children: diasSeleccionados.keys.map((dia) {
                      return FilterChip(
                        label: Text(mapDias[dia]!),
                        selected: diasSeleccionados[dia]!,
                        onSelected: (bool selected) => setDialogState(
                          () => diasSeleccionados[dia] = selected,
                        ),
                      );
                    }).toList(),
                  ),
                  const Divider(height: 24),
                  ListTile(
                    title: const Text("Hora de Ingreso"),
                    trailing: Text(
                      horaIngreso.format(context),
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: horaIngreso,
                      );
                      if (t != null) setDialogState(() => horaIngreso = t);
                    },
                  ),
                  ListTile(
                    title: const Text("Hora de Salida"),
                    trailing: Text(
                      horaSalida.format(context),
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: horaSalida,
                      );
                      if (t != null) setDialogState(() => horaSalida = t);
                    },
                  ),
                  const Divider(),
                  const Text(
                    "Receso / Almuerzo",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ListTile(
                    title: const Text("Inicio Receso"),
                    trailing: Text(
                      recesoInicio.format(context),
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: recesoInicio,
                      );
                      if (t != null) setDialogState(() => recesoInicio = t);
                    },
                  ),
                  ListTile(
                    title: const Text("Fin Receso"),
                    trailing: Text(
                      recesoFin.format(context),
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: recesoFin,
                      );
                      if (t != null) setDialogState(() => recesoFin = t);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancelar"),
              ),
              FilledButton(
                onPressed: () async {
                  if (usuarioSeleccionado == null) return;
                  if (!diasSeleccionados.values.any((v) => v == true)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Debes seleccionar al menos un día."),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context);
                  setState(() => _isLoading = true);
                  try {
                    for (var entry in diasSeleccionados.entries) {
                      int dia = entry.key;
                      bool isSelected = entry.value;
                      if (isSelected) {
                        await _horariosService.crearHorario({
                          "usuario": usuarioSeleccionado,
                          "dia_semana": dia,
                          "hora_ingreso": _formatTime(horaIngreso),
                          "hora_salida": _formatTime(horaSalida),
                          "receso_inicio": _formatTime(recesoInicio),
                          "receso_fin": _formatTime(recesoFin),
                          "jornada": jornadaSeleccionada,
                        });
                      } else if (esEdicion && diasOriginales.contains(dia)) {
                        await _horariosService.eliminarHorarioDia(
                          usuarioSeleccionado!,
                          dia,
                        );
                      }
                    }
                    await _cargarDatosIniciales();
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("✅ Horarios guardados"),
                          backgroundColor: Colors.green,
                        ),
                      );
                  } catch (e) {
                    if (mounted)
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text("Error: $e")));
                  } finally {
                    setState(() => _isLoading = false);
                  }
                },
                child: const Text("Guardar"),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCalendarioSemanas(List<dynamic> horariosFiltrados) {
    const int horaInicio = 7;
    const int horaFin = 22;
    final dias = [
      "Lunes",
      "Martes",
      "Miércoles",
      "Jueves",
      "Viernes",
      "Sábado",
      "Domingo",
    ];

    return Expanded(
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 16,
            headingRowHeight: 45,
            dataRowMaxHeight: double.infinity,
            dataRowMinHeight: 60,
            border: TableBorder.all(color: Colors.grey.shade300, width: 1),
            columns: [
              const DataColumn(
                label: Text(
                  "Hora",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ...dias.map(
                (d) => DataColumn(
                  label: Text(
                    d,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
            rows: List.generate(horaFin - horaInicio + 1, (index) {
              int horaActual = horaInicio + index;
              String horaStr = "${horaActual.toString().padLeft(2, '0')}:00";
              return DataRow(
                cells: [
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        horaStr,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  ...List.generate(7, (diaIndex) {
                    int diaSemana = diaIndex + 1;
                    var trabajadoresActivos = horariosFiltrados.where((h) {
                      if (h['dia_semana'] != diaSemana) return false;
                      int hIn = int.parse(h['hora_ingreso'].split(':')[0]);
                      int hOut = int.parse(h['hora_salida'].split(':')[0]);
                      return horaActual >= hIn && horaActual < hOut;
                    }).toList();

                    return DataCell(
                      Container(
                        width: 110,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        alignment: Alignment.topLeft,
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: trabajadoresActivos.map((t) {
                            int rIn = int.parse(
                              t['receso_inicio'].split(':')[0],
                            );
                            int rOut = int.parse(t['receso_fin'].split(':')[0]);
                            bool enReceso =
                                (horaActual >= rIn && horaActual < rOut);
                            String primerNombre = t['usuario'].toString().split(
                              ' ',
                            )[0];
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: enReceso
                                    ? Colors.orange.shade100
                                    : Colors.blue.shade100,
                                border: Border.all(
                                  color: enReceso ? Colors.orange : Colors.blue,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    enReceso ? Icons.restaurant : Icons.work,
                                    size: 10,
                                    color: enReceso
                                        ? Colors.orange.shade900
                                        : Colors.blue.shade900,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    primerNombre,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: enReceso
                                          ? Colors.orange.shade900
                                          : Colors.blue.shade900,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  }),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildHorariosTab() {
    final horariosFiltrados = _horarios.where((h) {
      if (_filtroJornada == 'General') return true;
      if (_filtroJornada == 'Por Hora') {
        int hIn = int.parse(h['hora_ingreso'].toString().split(':')[0]);
        int hOut = int.parse(h['hora_salida'].toString().split(':')[0]);
        return _horaSeleccionada >= hIn && _horaSeleccionada < hOut;
      }
      return h['jornada'] == _filtroJornada;
    }).toList();

    Map<String, List<dynamic>> horariosPorColaborador = {};
    for (var h in horariosFiltrados) {
      String usuario = h['usuario'];
      if (!horariosPorColaborador.containsKey(usuario)) {
        horariosPorColaborador[usuario] = [];
      }
      horariosPorColaborador[usuario]!.add(h);
    }
    final mapDiasFull = {
      1: "Lunes",
      2: "Martes",
      3: "Miércoles",
      4: "Jueves",
      5: "Viernes",
      6: "Sábado",
      7: "Domingo",
    };

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarDialogoHorario,
        icon: const Icon(Icons.add),
        label: const Text("Crear Horario"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('General'),
                          selected: _filtroJornada == 'General',
                          onSelected: (val) =>
                              setState(() => _filtroJornada = 'General'),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Matutino'),
                          selected: _filtroJornada == 'Matutino',
                          onSelected: (val) =>
                              setState(() => _filtroJornada = 'Matutino'),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Vespertino'),
                          selected: _filtroJornada == 'Vespertino',
                          onSelected: (val) =>
                              setState(() => _filtroJornada = 'Vespertino'),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Por Hora'),
                          selected: _filtroJornada == 'Por Hora',
                          onSelected: (val) =>
                              setState(() => _filtroJornada = 'Por Hora'),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      setState(() => _vistaCalendario = !_vistaCalendario),
                  icon: Icon(
                    _vistaCalendario ? Icons.view_list : Icons.calendar_month,
                    color: Colors.blueGrey,
                    size: 28,
                  ),
                  tooltip: _vistaCalendario
                      ? "Ver en Lista"
                      : "Ver Calendario Semanal",
                ),
              ],
            ),
          ),
          if (_filtroJornada == 'Por Hora')
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Column(
                children: [
                  Text(
                    "Línea de tiempo: ${_horaSeleccionada.toInt().toString().padLeft(2, '0')}:00",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                  Slider(
                    value: _horaSeleccionada,
                    min: 7,
                    max: 22,
                    divisions: 15,
                    label:
                        "${_horaSeleccionada.toInt().toString().padLeft(2, '0')}:00",
                    activeColor: Colors.blue,
                    inactiveColor: Colors.blue.shade100,
                    onChanged: (val) {
                      setState(() {
                        _horaSeleccionada = val;
                      });
                    },
                  ),
                ],
              ),
            ),
          if (_vistaCalendario)
            _buildCalendarioSemanas(horariosFiltrados)
          else
            Expanded(
              child: horariosFiltrados.isEmpty
                  ? const Center(
                      child: Text("No hay horarios para esta jornada."),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      children: horariosPorColaborador.entries.map((entry) {
                        String colaborador = entry.key;
                        List<dynamic> horarios = entry.value;
                        horarios.sort(
                          (a, b) => a['dia_semana'].compareTo(b['dia_semana']),
                        );

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          child: ExpansionTile(
                            shape: const Border(),
                            leading: const CircleAvatar(
                              backgroundColor: Colors.blueGrey,
                              child: Icon(Icons.person, color: Colors.white),
                            ),
                            title: Text(
                              colaborador.toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey.shade900,
                              ),
                            ),
                            subtitle: Text(
                              "${horarios.length} días configurados en esta jornada",
                            ),
                            children: horarios.map((h) {
                              return Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                ),
                                child: ListTile(
                                  title: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        mapDiasFull[h['dia_semana']] ??
                                            'Día ${h['dia_semana']}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Chip(
                                        label: Text(
                                          h['jornada'] ?? 'Matutino',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.white,
                                          ),
                                        ),
                                        backgroundColor:
                                            (h['jornada'] == 'Vespertino')
                                            ? Colors.indigo
                                            : Colors.orange,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        "Trabajo: ${h['hora_ingreso']} a ${h['hora_salida']}",
                                        style: TextStyle(
                                          color: Colors.blue.shade700,
                                        ),
                                      ),
                                      Text(
                                        "Receso: ${h['receso_inicio']} a ${h['receso_fin']}",
                                        style: TextStyle(
                                          color: Colors.orange.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit,
                                          color: Colors.blueGrey,
                                        ),
                                        tooltip: "Editar día",
                                        onPressed: () =>
                                            _mostrarDialogoHorario(h),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.redAccent,
                                        ),
                                        tooltip: "Eliminar día",
                                        onPressed: () => _eliminarHorarioDia(
                                          h['usuario'],
                                          h['dia_semana'],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      }).toList(),
                    ),
            ),
        ],
      ),
    );
  }

  // =========================================================================
  // 3. MAPA 2D
  // =========================================================================

  Color _colorFromHex(String hexColor) {
    hexColor = hexColor.toUpperCase().replaceAll("#", "");
    if (hexColor.length == 6) hexColor = "FF$hexColor";
    return Color(int.parse(hexColor, radix: 16));
  }

  void _zoomIn() =>
      _mapController.value = _mapController.value.clone()..scale(1.5);
  void _zoomOut() =>
      _mapController.value = _mapController.value.clone()..scale(0.66);

  void _guardarMapa() async {
    setState(() => _isLoading = true);
    try {
      List<Map<String, dynamic>> celdasAguardar = [];
      _cuadricula.forEach((key, zonaId) {
        var partes = key.split('_');
        int f = int.parse(partes[0]);
        int c = int.parse(partes[1]);

        if (f < _filas && c < _columnas) {
          celdasAguardar.add({"fila": f, "columna": c, "zona_id": zonaId});
        }
      });

      celdasAguardar.add({
        "fila": _filas - 1,
        "columna": _columnas - 1,
        "zona_id": null,
      });

      await _horariosService.guardarCuadricula(celdasAguardar);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Mapa guardado"),
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

  void _mostrarOpcionesZona(Map<String, dynamic> zona) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: _colorFromHex(zona['color_hex']),
              radius: 10,
            ),
            const SizedBox(width: 8),
            Text(zona['nombre']),
          ],
        ),
        content: const Text(
          "¿Deseas eliminar permanentemente esta zona? (Se borrará del mapa).",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              try {
                await _horariosService.eliminarZona(zona['id']);
                await _cargarDatosIniciales();
              } catch (e) {
                if (mounted)
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text("Error: $e")));
                setState(() => _isLoading = false);
              }
            },
            child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoCuadricula() {
    final filasCtrl = TextEditingController(text: _filas.toString());
    final colsCtrl = TextEditingController(text: _columnas.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Tamaño del Local (Grid)"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: filasCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Filas"),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: colsCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Columnas"),
            ),
            const SizedBox(height: 16),
            const Text(
              "⚠️ Nota: Esta vista te permite hacer Zoom o Deslizar el mapa si es muy grande.",
              style: TextStyle(fontSize: 10, color: Colors.blueGrey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _filas = int.tryParse(filasCtrl.text) ?? 10;
                _columnas = int.tryParse(colsCtrl.text) ?? 10;
              });
            },
            child: const Text("Actualizar"),
          ),
        ],
      ),
    );
  }

  void _gestionarAsignacionesZona(
    int zonaId,
    String zonaNombre,
    Color zonaColor,
  ) {
    String? usuarioSeleccionado;
    final mapDias = {1: "L", 2: "M", 3: "X", 4: "J", 5: "V", 6: "S", 7: "D"};
    final trabajadores = _usuarios.where((u) => u['activo'] == true).toList();
    Map<int, bool> diasSeleccionados = {
      1: false,
      2: false,
      3: false,
      4: false,
      5: false,
      6: false,
      7: false,
    };

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          var asignadosActuales = _asignaciones
              .where((a) => a['zona_id'].toString() == zonaId.toString())
              .toList();
          var usuariosUnicosEnZona = asignadosActuales
              .map((a) => a['usuario'])
              .toSet()
              .toList();

          return AlertDialog(
            title: Row(
              children: [
                CircleAvatar(backgroundColor: zonaColor, radius: 10),
                const SizedBox(width: 8),
                Text(zonaNombre),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (usuariosUnicosEnZona.isNotEmpty) ...[
                    const Text(
                      "👥 Colaboradores en esta zona:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...usuariosUnicosEnZona.map(
                      (u) => Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        margin: const EdgeInsets.only(bottom: 4),
                        child: ListTile(
                          dense: true,
                          title: Text(
                            u,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              setState(() => _isLoading = true);
                              var aBorrar = asignadosActuales
                                  .where((a) => a['usuario'] == u)
                                  .toList();
                              for (var a in aBorrar) {
                                await _horariosService.eliminarAsignacion(
                                  a['id'],
                                );
                              }
                              await _cargarDatosIniciales();
                              setDialogState(() {});
                              setState(() => _isLoading = false);
                            },
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 24),
                  ],

                  const Text(
                    "➕ Agregar Nuevo Colaborador:",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Selecciona al empleado y los días que cubrirá este puesto. El horario se extraerá automáticamente.",
                    style: TextStyle(fontSize: 11, color: Colors.blueGrey),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: usuarioSeleccionado,
                    decoration: const InputDecoration(
                      labelText: "Colaborador",
                      border: OutlineInputBorder(),
                    ),
                    items: trabajadores
                        .map(
                          (u) => DropdownMenuItem<String>(
                            value: u['nombre_usuario'],
                            child: Text(u['nombre_usuario']),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      setDialogState(() {
                        usuarioSeleccionado = val;
                        diasSeleccionados.updateAll((key, value) => false);
                        for (var h in _horarios) {
                          if (h['usuario'] == val) {
                            diasSeleccionados[h['dia_semana']] = true;
                          }
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 4,
                    children: diasSeleccionados.keys.map((dia) {
                      return FilterChip(
                        label: Text(mapDias[dia]!),
                        selected: diasSeleccionados[dia]!,
                        onSelected: (bool selected) => setDialogState(
                          () => diasSeleccionados[dia] = selected,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cerrar"),
              ),
              FilledButton(
                onPressed: () async {
                  if (usuarioSeleccionado == null) return;
                  setState(() => _isLoading = true);

                  int asignadosCount = 0;
                  try {
                    for (var entry in diasSeleccionados.entries) {
                      if (entry.value) {
                        int dia = entry.key;
                        var horariosDia = _horarios
                            .where(
                              (h) =>
                                  h['usuario'] == usuarioSeleccionado &&
                                  h['dia_semana'] == dia,
                            )
                            .toList();

                        if (horariosDia.isNotEmpty) {
                          await _horariosService.crearAsignacion({
                            "usuario": usuarioSeleccionado,
                            "zona_id": zonaId,
                            "dia_semana": dia,
                            "hora_inicio": horariosDia[0]['hora_ingreso'],
                            "hora_fin": horariosDia[0]['hora_salida'],
                          });
                          asignadosCount++;
                        }
                      }
                    }

                    await _cargarDatosIniciales();
                    if (mounted && asignadosCount > 0)
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "✅ $usuarioSeleccionado agregado a la zona",
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );

                    setDialogState(() {
                      usuarioSeleccionado = null;
                      diasSeleccionados.updateAll((key, value) => false);
                    });
                  } catch (e) {
                    if (mounted)
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text("Error: $e")));
                  } finally {
                    setState(() => _isLoading = false);
                  }
                },
                child: const Text("Agregar a la Zona"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _mostrarOpcionesAsignacion(String usuario, int zonaId, Color zonaColor) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(backgroundColor: zonaColor, radius: 10),
            const SizedBox(width: 8),
            const Text("Desvincular Colaborador"),
          ],
        ),
        content: Text(
          "¿Deseas quitar a $usuario de esta zona en todos sus turnos?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              try {
                var asignacionesBorrar = _asignaciones
                    .where(
                      (a) => a['usuario'] == usuario && a['zona_id'] == zonaId,
                    )
                    .toList();
                for (var a in asignacionesBorrar) {
                  await _horariosService.eliminarAsignacion(a['id']);
                }
                await _cargarDatosIniciales();
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Colaborador desvinculado"),
                      backgroundColor: Colors.green,
                    ),
                  );
              } catch (e) {
                if (mounted)
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text("Error: $e")));
                setState(() => _isLoading = false);
              }
            },
            child: const Text("Quitar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoCrearZona() {
    final nombreCtrl = TextEditingController();
    String colorElegido = "#4CAF50";
    final colores = [
      "#F44336",
      "#E91E63",
      "#9C27B0",
      "#673AB7",
      "#3F51B5",
      "#2196F3",
      "#03A9F4",
      "#00BCD4",
      "#009688",
      "#4CAF50",
      "#8BC34A",
      "#CDDC39",
      "#FFEB3B",
      "#FFC107",
      "#FF9800",
      "#FF5722",
      "#795548",
      "#9E9E9E",
      "#607D8B",
      "#000000",
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Nueva Zona Física"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nombreCtrl,
                    decoration: const InputDecoration(
                      labelText: "Nombre (Ej: Cajas, Pasillo)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Color:"),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
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
                    await _cargarDatosIniciales();
                  } catch (e) {
                    if (mounted)
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

  Widget _buildMapaTab() {
    final mapDias = {1: "L", 2: "M", 3: "X", 4: "J", 5: "V", 6: "S", 7: "D"};

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text("🖌️ Diseñar Local"),
                    selected: _modoDiseno,
                    onSelected: (val) => setState(() => _modoDiseno = true),
                  ),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: const Text("🧑‍🤝‍🧑 Asignar Zonas"),
                    selected: !_modoDiseno,
                    onSelected: (val) => setState(() => _modoDiseno = false),
                  ),
                ],
              ),

              if (_modoDiseno) ...[
                const SizedBox(height: 8),
                const Text(
                  "Toca una zona abajo y pinta en la cuadrícula:",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.blue),
                        onPressed: _mostrarDialogoCrearZona,
                      ),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _zonaSeleccionadaParaPintar = null),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text("Borrador"),
                        ),
                      ),
                      ..._zonas.map((z) {
                        bool isSelected =
                            _zonaSeleccionadaParaPintar == z['id'];
                        return GestureDetector(
                          onTap: () => setState(
                            () => _zonaSeleccionadaParaPintar = z['id'],
                          ),
                          onLongPress: () => _mostrarOpcionesZona(z),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _colorFromHex(z['color_hex']),
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
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ] else ...[
                const Divider(),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text(
                          "Día: ",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ...mapDias.keys.map((dia) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 4.0),
                          child: ChoiceChip(
                            label: Text(
                              mapDias[dia]!,
                              style: const TextStyle(fontSize: 12),
                            ),
                            selected: _diaMapa == dia,
                            onSelected: (val) => setState(() => _diaMapa = dia),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        "Jornada: ",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('General'),
                        selected: _jornadaMapa == 'General',
                        onSelected: (val) =>
                            setState(() => _jornadaMapa = 'General'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Matutino'),
                        selected: _jornadaMapa == 'Matutino',
                        onSelected: (val) =>
                            setState(() => _jornadaMapa = 'Matutino'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Vespertino'),
                        selected: _filtroJornada == 'Vespertino',
                        onSelected: (val) =>
                            setState(() => _filtroJornada = 'Vespertino'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Por Hora'),
                        selected: _filtroJornada == 'Por Hora',
                        onSelected: (val) =>
                            setState(() => _filtroJornada = 'Por Hora'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        Expanded(
          child: Stack(
            children: [
              Container(
                color: Colors.grey.shade300,
                child: InteractiveViewer(
                  transformationController: _mapController,
                  constrained: false,
                  boundaryMargin: const EdgeInsets.all(1000.0),
                  minScale: 0.1,
                  maxScale: 5.0,
                  // 🔥 SOLUCIÓN PDF: Envuelto en RepaintBoundary con la GlobalKey
                  child: RepaintBoundary(
                    key: _mapaKey,
                    child: Container(
                      width: _columnas * 70.0,
                      height: _filas * 70.0,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _columnas,
                        ),
                        itemCount: _filas * _columnas,
                        itemBuilder: (context, index) {
                          int fila = index ~/ _columnas;
                          int col = index % _columnas;
                          String key = "${fila}_${col}";

                          int? zonaId = _cuadricula[key];
                          Color colorCelda = Colors.transparent;
                          String zonaNombre = "";

                          if (zonaId != null) {
                            var zonaMatch = _zonas.firstWhere(
                              (z) => z['id'] == zonaId,
                              orElse: () => null,
                            );
                            if (zonaMatch != null) {
                              colorCelda = _colorFromHex(
                                zonaMatch['color_hex'],
                              );
                              zonaNombre = zonaMatch['nombre'];
                            }
                          }

                          bool isTopSame =
                              fila > 0 &&
                              _cuadricula["${fila - 1}_$col"] == zonaId;
                          bool isBottomSame =
                              fila < _filas - 1 &&
                              _cuadricula["${fila + 1}_$col"] == zonaId;
                          bool isLeftSame =
                              col > 0 &&
                              _cuadricula["${fila}_${col - 1}"] == zonaId;
                          bool isRightSame =
                              col < _columnas - 1 &&
                              _cuadricula["${fila}_${col + 1}"] == zonaId;

                          bool isMainCell = !isTopSame && !isLeftSame;

                          BorderSide defaultBorder = BorderSide(
                            color: Colors.grey.shade200,
                            width: 1,
                          );
                          BorderSide fusedBorder = zonaId != null
                              ? BorderSide(color: colorCelda, width: 1)
                              : defaultBorder;

                          Widget celdaContenido = const SizedBox();

                          if (!_modoDiseno && zonaId != null && isMainCell) {
                            var asignadosAqui = _asignaciones.where((a) {
                              if (a['zona_id'].toString() != zonaId.toString())
                                return false;
                              if (a['dia_semana'].toString() !=
                                  _diaMapa.toString())
                                return false;
                              if (_jornadaMapa != 'General') {
                                String j = a['jornada'] ?? 'Matutino';
                                if (j != _jornadaMapa) return false;
                              }
                              return true;
                            }).toList();

                            var nombresUnicos = asignadosAqui
                                .map(
                                  (e) => e['usuario'].toString().split(' ')[0],
                                )
                                .toSet()
                                .toList();

                            if (nombresUnicos.isNotEmpty) {
                              celdaContenido = Center(
                                child: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: nombresUnicos.map((n) {
                                      return Container(
                                        margin: const EdgeInsets.symmetric(
                                          vertical: 1,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 2,
                                          vertical: 1,
                                        ),
                                        color: Colors.white.withOpacity(0.9),
                                        child: Text(
                                          n,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              );
                            } else {
                              celdaContenido = const Center(
                                child: Icon(
                                  Icons.person_add,
                                  color: Colors.black45,
                                  size: 24,
                                ),
                              );
                            }
                          }

                          return GestureDetector(
                            onTap: () {
                              if (_modoDiseno) {
                                setState(() {
                                  if (_zonaSeleccionadaParaPintar == null) {
                                    _cuadricula.remove(key);
                                  } else {
                                    _cuadricula[key] =
                                        _zonaSeleccionadaParaPintar!;
                                  }
                                });
                              } else {
                                if (zonaId != null) {
                                  _gestionarAsignacionesZona(
                                    zonaId,
                                    zonaNombre,
                                    colorCelda,
                                  );
                                }
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: colorCelda,
                                border: Border(
                                  top: isTopSame ? fusedBorder : defaultBorder,
                                  bottom: isBottomSame
                                      ? fusedBorder
                                      : defaultBorder,
                                  left: isLeftSame
                                      ? fusedBorder
                                      : defaultBorder,
                                  right: isRightSame
                                      ? fusedBorder
                                      : defaultBorder,
                                ),
                              ),
                              child: celdaContenido,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),

              Positioned(
                right: 16,
                bottom: 16,
                child: Column(
                  children: [
                    FloatingActionButton(
                      heroTag: "btnZoomIn",
                      mini: true,
                      onPressed: _zoomIn,
                      backgroundColor: Colors.white,
                      child: const Icon(Icons.add, color: Colors.blueGrey),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton(
                      heroTag: "btnZoomOut",
                      mini: true,
                      onPressed: _zoomOut,
                      backgroundColor: Colors.white,
                      child: const Icon(Icons.remove, color: Colors.blueGrey),
                    ),
                  ],
                ),
              ),

              if (_modoDiseno)
                Positioned(
                  left: 16,
                  bottom: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 4),
                      ],
                      border: Border.all(color: Colors.blueGrey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Tamaño del Local",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.blueGrey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text(
                              "Filas: ",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => setState(() {
                                if (_filas > 1) _filas--;
                              }),
                              child: const Icon(
                                Icons.remove_circle,
                                color: Colors.redAccent,
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 20,
                              child: Text(
                                "$_filas",
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => setState(() => _filas++),
                              child: const Icon(
                                Icons.add_circle,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text(
                              "Cols:  ",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => setState(() {
                                if (_columnas > 1) _columnas--;
                              }),
                              child: const Icon(
                                Icons.remove_circle,
                                color: Colors.redAccent,
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 20,
                              child: Text(
                                "$_columnas",
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => setState(() => _columnas++),
                              child: const Icon(
                                Icons.add_circle,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        if (_modoDiseno)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _guardarMapa,
                icon: const Icon(Icons.save),
                label: const Text("Guardar Diseño del Local"),
              ),
            ),
          ),
      ],
    );
  }

  // =========================================================================
  // 4. 🔥 EXPO DATOS Y REPORTES PDF 🔥
  // =========================================================================

  Future<Uint8List?> _capturarMapaComoImagen() async {
    try {
      RenderRepaintBoundary boundary =
          _mapaKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint("Error capturando mapa: $e");
      return null;
    }
  }

  Future<void> _generarPdfHorarios() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text(
                "Diagrama de Gantt - Horarios",
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Text("Generado el: ${DateTime.now().toString().split('.')[0]}"),
            pw.SizedBox(height: 20),
            pw.Text(
              "Resumen por Colaborador:",
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: [
                'Colaborador',
                'Día',
                'Ingreso',
                'Salida',
                'Receso In',
                'Receso Fin',
                'Jornada',
              ],
              data: _horarios
                  .map(
                    (h) => [
                      h['usuario'],
                      h['dia_semana'].toString(),
                      h['hora_ingreso'],
                      h['hora_salida'],
                      h['receso_inicio'],
                      h['receso_fin'],
                      h['jornada'],
                    ],
                  )
                  .toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blue800,
              ),
              cellAlignment: pw.Alignment.center,
            ),
          ];
        },
      ),
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Horarios_Ferrotienda.pdf',
    );
  }

  Future<void> _generarPdfMapa() async {
    final mapImageBytes = await _capturarMapaComoImagen();
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text(
                "Mapa 2D y Asignación de Zonas",
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            if (mapImageBytes != null)
              pw.Center(
                child: pw.Image(pw.MemoryImage(mapImageBytes), height: 300),
              )
            else
              pw.Text(
                "No se pudo capturar el mapa visual. Asegúrate de abrir la pestaña de Mapa 2D antes de exportar.",
                style: const pw.TextStyle(color: PdfColors.red),
              ),

            pw.SizedBox(height: 20),
            pw.Text(
              "Resumen de Áreas Asignadas:",
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: [
                'Zona / Área',
                'Día Semana',
                'Horario',
                'Colaborador Asignado',
              ],
              data: _asignaciones.map((a) {
                String nomZona = _zonas.firstWhere(
                  (z) => z['id'] == a['zona_id'],
                  orElse: () => {'nombre': 'Desconocida'},
                )['nombre'];
                return [
                  nomZona,
                  a['dia_semana'].toString(),
                  "${a['hora_inicio']} - ${a['hora_fin']}",
                  a['usuario'],
                ];
              }).toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.teal800,
              ),
            ),
          ];
        },
      ),
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Mapa_Zonas_Ferrotienda.pdf',
    );
  }

  // 🔥 NUEVO: Función para dibujar un semáforo visual sin usar Emojis en el PDF 🔥
  pw.Widget _buildIndicadorSemaforo(double efectividad) {
    PdfColor color = PdfColors.green500;
    String label = "Estrella";

    if (efectividad < 85 && efectividad >= 60) {
      color = PdfColors.orange500;
      label = "Desarrollo";
    } else if (efectividad < 60) {
      color = PdfColors.red500;
      label = "En Riesgo";
    }

    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      mainAxisAlignment: pw.MainAxisAlignment.center,
      children: [
        pw.Container(
          width: 8,
          height: 8,
          decoration: pw.BoxDecoration(shape: pw.BoxShape.circle, color: color),
        ),
        pw.SizedBox(width: 4),
        pw.Text(
          label,
          style: pw.TextStyle(color: color, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  // 🔥 MEJORA: Reporte Analítico 2.0 (Selector Inteligente, Sin Emojis, Resumen Individual) 🔥
  Future<void> _generarPdfRankingInteligente() async {
    int selectedMonth = _fechaSeleccionada.month;
    int selectedYear = _fechaSeleccionada.year;
    bool confirmado = false;

    // 1. Diálogo Selector Cómodo (Mes y Año)
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Seleccionar Mes de Análisis"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Selecciona el mes y año que deseas exportar.",
                  style: TextStyle(color: Colors.blueGrey, fontSize: 12),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: "Mes",
                    border: OutlineInputBorder(),
                  ),
                  value: selectedMonth,
                  items: List.generate(
                    12,
                    (i) => DropdownMenuItem(
                      value: i + 1,
                      child: Text("Mes ${i + 1}"),
                    ),
                  ),
                  onChanged: (v) => setDialogState(() => selectedMonth = v!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: "Año",
                    border: OutlineInputBorder(),
                  ),
                  value: selectedYear,
                  items: List.generate(
                    7,
                    (i) => DropdownMenuItem(
                      value: 2024 + i,
                      child: Text("${2024 + i}"),
                    ),
                  ),
                  onChanged: (v) => setDialogState(() => selectedYear = v!),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancelar"),
              ),
              FilledButton.icon(
                onPressed: () {
                  confirmado = true;
                  Navigator.pop(ctx);
                },
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text("Generar Informe"),
              ),
            ],
          );
        },
      ),
    );

    if (!confirmado) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Procesando Inteligencia de Negocios..."),
          duration: Duration(seconds: 2),
        ),
      );
    }

    try {
      final rankingData = await _kpiService.obtenerRankingMes(
        selectedMonth,
        selectedYear,
      );
      final evaluacionesData = await _kpiService.obtenerEvaluacionesMes(
        selectedMonth,
        selectedYear,
      );
      final premiosData = await _kpiService.obtenerPremioMes(
        selectedMonth,
        selectedYear,
      );

      // Cuellos de Botella
      Map<String, List<double>> puntajesPorTarea = {};
      for (var eval in evaluacionesData) {
        String tarea = eval['nombre_tarea'];
        double nota = double.tryParse(eval['calificacion'].toString()) ?? 0.0;
        if (!puntajesPorTarea.containsKey(tarea)) puntajesPorTarea[tarea] = [];
        puntajesPorTarea[tarea]!.add(nota);
      }

      List<Map<String, dynamic>> promedioTareas = [];
      puntajesPorTarea.forEach((tarea, notas) {
        double prom = notas.reduce((a, b) => a + b) / notas.length;
        promedioTareas.add({
          "tarea": tarea,
          "promedio": prom,
          "total_veces": notas.length,
        });
      });

      promedioTareas.sort((a, b) => a['promedio'].compareTo(b['promedio']));
      final peoresTareas = promedioTareas.take(3).toList();

      // Agrupamos por Empleado
      Map<String, List<dynamic>> evalPorUsuario = {};
      for (var eval in evaluacionesData) {
        String usu = eval['usuario'];
        if (!evalPorUsuario.containsKey(usu)) evalPorUsuario[usu] = [];
        evalPorUsuario[usu]!.add(eval);
      }

      final pdf = pw.Document();

      // --- PÁGINA 1: SEMÁFORO GLOBAL ---
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text(
                  "Reporte de Rendimiento - Mes $selectedMonth/$selectedYear",
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Text(
                "Premio Alcanzado: ${premiosData['premio']}",
                style: pw.TextStyle(
                  color: PdfColors.green800,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                "Sanción del Mes: ${premiosData['castigo']}",
                style: pw.TextStyle(
                  color: PdfColors.red800,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),

              pw.Text(
                "1. Semáforo de Talento (Rendimiento Global)",
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                "Clasificación de empleados basada en su porcentaje de efectividad.",
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
              ),
              pw.SizedBox(height: 10),

              // Tabla Manual para soportar Widgets Visuales (Semáforo)
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.blueGrey800,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          'Estado',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          'Colaborador',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          'Efectividad (%)',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          'Puntos',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  ...rankingData.map((r) {
                    double efectividad =
                        double.tryParse(
                          r['efectividad_porcentaje'].toString(),
                        ) ??
                        0;
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Center(
                            child: _buildIndicadorSemaforo(efectividad),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            r['usuario'],
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            "${efectividad.toStringAsFixed(1)}%",
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            r['total_puntos'].toString(),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 30),
              pw.Text(
                "2. Alerta de Cuellos de Botella (Fugas de Calidad)",
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.red800,
                ),
              ),
              pw.Text(
                "Las tareas con PEOR calificación promedio en todo el local.",
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
              ),
              pw.SizedBox(height: 10),
              if (peoresTareas.isEmpty)
                pw.Text(
                  "No hay suficientes datos evaluados aún.",
                  style: const pw.TextStyle(fontStyle: pw.FontStyle.italic),
                )
              else
                ...peoresTareas
                    .map(
                      (p) => pw.Container(
                        margin: const pw.EdgeInsets.only(bottom: 5),
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.red300),
                        ),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              "ATENCIÓN - Tarea: ${p['tarea']}",
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              "Promedio: ${(p['promedio'] * 100).toStringAsFixed(1)}% (Hecha ${p['total_veces']} veces)",
                              style: const pw.TextStyle(color: PdfColors.red),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
            ];
          },
        ),
      );

      // --- PÁGINA 2+: DESGLOSE INDIVIDUAL ---
      if (evalPorUsuario.isNotEmpty) {
        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              List<pw.Widget> widgetsUsuario = [
                pw.Header(
                  level: 1,
                  child: pw.Text(
                    "3. Detalle Analítico por Colaborador",
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ];

              evalPorUsuario.forEach((usuario, tareas) {
                // Cálculo de métricas individuales
                int totalTareas = tareas.length;
                int tareasCaducadas = tareas
                    .where(
                      (t) => t['comentario_admin']
                          .toString()
                          .toLowerCase()
                          .contains('caducada'),
                    )
                    .length;
                int tareasATiempo = totalTareas - tareasCaducadas;
                double puntajeTotal = tareas.fold(
                  0.0,
                  (sum, item) =>
                      sum +
                      (double.tryParse(item['calificacion'].toString()) ?? 0.0),
                );

                widgetsUsuario.add(pw.SizedBox(height: 20));

                // Cabecera Individual
                widgetsUsuario.add(
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue50,
                      border: pw.Border.all(color: PdfColors.blue200),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "Colaborador: $usuario",
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              "Total Asignadas: $totalTareas",
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                            pw.Text(
                              "Cumplidas: $tareasATiempo",
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.green700,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              "Caducadas: $tareasCaducadas",
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.red700,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              "Puntos Obtenidos: $puntajeTotal",
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );

                widgetsUsuario.add(pw.SizedBox(height: 5));

                // Tabla de Tareas
                widgetsUsuario.add(
                  pw.TableHelper.fromTextArray(
                    headers: [
                      'Fecha',
                      'Actividad',
                      'Nota',
                      'Comentario / Estado',
                    ],
                    data: tareas.map((t) {
                      String nombreT =
                          t['nombre_tarea']?.toString() ?? 'Tarea eliminada';
                      if (nombreT.trim().isEmpty)
                        nombreT = 'Actividad Genérica';

                      return [
                        t['fecha'].toString(),
                        nombreT,
                        t['calificacion'].toString(),
                        t['comentario_admin'].toString(),
                      ];
                    }).toList(),
                    headerStyle: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                      color: PdfColors.white,
                    ),
                    cellStyle: const pw.TextStyle(fontSize: 9),
                    headerDecoration: const pw.BoxDecoration(
                      color: PdfColors.blueGrey500,
                    ),
                    rowDecoration: const pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(
                          color: PdfColors.grey300,
                          width: 0.5,
                        ),
                      ),
                    ),
                    cellPadding: const pw.EdgeInsets.all(6),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(2),
                      1: const pw.FlexColumnWidth(4),
                      2: const pw.FlexColumnWidth(1),
                      3: const pw.FlexColumnWidth(5),
                    },
                  ),
                );
              });

              return widgetsUsuario;
            },
          ),
        );
      }

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Reporte_Analitico_$selectedMonth.pdf',
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error al generar PDF: $e")));
    }
  }

  Widget _buildExpoDatosTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Exportación de Datos y Reportes (PDF)",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Selecciona el módulo que deseas exportar. Se generará un documento PDF listo para imprimir o enviar por WhatsApp.",
          ),
          const SizedBox(height: 24),

          _buildExportCard(
            title: "Horarios y Diagrama de Gantt",
            subtitle:
                "Exporta el resumen de ingresos, salidas, recesos y el diagrama general.",
            icon: Icons.schedule,
            color: Colors.blue,
            onTap: _generarPdfHorarios,
          ),
          const SizedBox(height: 16),

          _buildExportCard(
            title: "Mapa 2D y Áreas Designadas",
            subtitle:
                "Toma una captura visual del plano del local y lista los responsables.",
            icon: Icons.map,
            color: Colors.teal,
            onTap: _generarPdfMapa,
          ),
          const SizedBox(height: 16),

          _buildExportCard(
            title: "Análisis Inteligente de Rendimiento",
            subtitle:
                "Elige un mes para exportar el Semáforo de Talento, Fugas de Calidad y el detalle métrico de cada empleado.",
            icon: Icons.auto_graph,
            color: Colors.amber.shade700,
            onTap: _generarPdfRankingInteligente,
          ),
        ],
      ),
    );
  }

  Widget _buildExportCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 40, color: color),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.picture_as_pdf,
                color: Colors.redAccent,
                size: 32,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String fechaFormateada =
        "${_fechaSeleccionada.day}/${_fechaSeleccionada.month}/${_fechaSeleccionada.year}";

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Gestión de Rendimiento",
              style: TextStyle(fontSize: 18),
            ),
            Text(
              "Filtrando: $fechaFormateada",
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: "Ejecutar Robot (Distribuir tareas hoy)",
            icon: const Icon(Icons.smart_toy, color: Colors.orangeAccent),
            onPressed: _ejecutarRobotGuardian,
          ),
          IconButton(
            tooltip: "Cambiar Fecha",
            icon: const Icon(Icons.calendar_month, color: Colors.blueAccent),
            onPressed: _seleccionarFechaFiltro,
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.list_alt), text: "Catálogo"),
            Tab(icon: Icon(Icons.fact_check), text: "Auditoría"),
            Tab(icon: Icon(Icons.leaderboard), text: "Ranking"),
            Tab(icon: Icon(Icons.schedule), text: "Horarios"),
            Tab(icon: Icon(Icons.map), text: "Mapa 2D"),
            Tab(
              icon: Icon(Icons.picture_as_pdf, color: Colors.red),
              text: "Expo Datos",
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              physics: const NeverScrollableScrollPhysics(),
              controller: _tabController,
              children: [
                _buildBancoTareasTab(),
                _buildAuditoriaTab(),
                _buildRankingTab(),
                _buildHorariosTab(),
                _buildMapaTab(),
                _buildExpoDatosTab(),
              ],
            ),
    );
  }
}
