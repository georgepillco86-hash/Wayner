import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/services/cronograma_service.dart';
import '../../../usuarios/services/usuarios_service.dart';
import '../../../usuarios/models/usuario.dart';

class CronogramaFormScreen extends StatefulWidget {
  final VoidCallback onSaved;
  final String? proveedorInicial;
  final Map<String, dynamic>? secuenciaAEditar;

  const CronogramaFormScreen({
    super.key,
    required this.onSaved,
    this.proveedorInicial,
    this.secuenciaAEditar,
  });

  @override
  State<CronogramaFormScreen> createState() => _CronogramaFormScreenState();
}

class _CronogramaFormScreenState extends State<CronogramaFormScreen> {
  final _cronogramaService = CronogramaService();
  final _usuariosService = UsuariosService();

  final _proveedorController = TextEditingController();
  final _celularController = TextEditingController();
  String? _proveedorSeleccionado;

  String _frecuenciaSeleccionada = 'Semanal';
  final List<String> _opcionesFrecuencia = ['Semanal', 'Quincenal', 'Mensual'];

  // 🔥 CAMBIO: Por defecto 3 meses, y eliminamos la opción de 5 años
  int _repetirMeses = 3;
  final Map<int, String> _opcionesDuracion = {
    1: '1 Mes',
    3: '3 Meses (Ventana Móvil Recomendada)',
    6: 'Medio Año (6 meses)',
    12: '1 Año',
  };

  List<Map<String, DateTime>> _paresVisitaEntrega = [];

  List<Usuario> _usuariosDb = [];
  List<String> _proveedoresDb = [];
  final List<String> _usuariosVinculados = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _inicializarParVacio();
    _cargarDatosIniciales();
  }

  @override
  void dispose() {
    _proveedorController.dispose();
    _celularController.dispose();
    super.dispose();
  }

  void _inicializarParVacio() {
    final ahora = DateTime.now();
    _paresVisitaEntrega.add({
      'visita': DateTime(ahora.year, ahora.month, ahora.day, 9, 0),
      'entrega': DateTime(ahora.year, ahora.month, ahora.day + 2, 12, 0),
    });
  }

  void _agregarOtroPar() {
    setState(() {
      final ahora = DateTime.now();
      _paresVisitaEntrega.add({
        'visita': DateTime(ahora.year, ahora.month, ahora.day, 9, 0),
        'entrega': DateTime(ahora.year, ahora.month, ahora.day + 2, 12, 0),
      });
    });
  }

  void _eliminarPar(int index) {
    if (_paresVisitaEntrega.length > 1) {
      setState(() {
        _paresVisitaEntrega.removeAt(index);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Debe configurar al menos una secuencia de visita y entrega.',
          ),
        ),
      );
    }
  }

  Future<void> _cargarDatosIniciales() async {
    try {
      final usuarios = await _usuariosService.listarUsuarios();
      final proveedores = await _cronogramaService.obtenerProveedores();

      if (mounted) {
        setState(() {
          _usuariosDb = usuarios;
          _proveedoresDb = proveedores;

          if (widget.secuenciaAEditar != null) {
            final seq = widget.secuenciaAEditar!;

            // 1. Proveedor
            _proveedorController.text = seq['proveedor'] ?? '';
            if (_proveedoresDb.contains(seq['proveedor'])) {
              _proveedorSeleccionado = seq['proveedor'];
            }

            // 2. Celular (WhatsApp)
            _celularController.text = seq['contacto_celular']?.toString() ?? '';

            // 3. Frecuencia
            final frecDb = seq['frecuencia'];
            if (frecDb == 7)
              _frecuenciaSeleccionada = 'Semanal';
            else if (frecDb == 15)
              _frecuenciaSeleccionada = 'Quincenal';
            else if (frecDb == 30)
              _frecuenciaSeleccionada = 'Mensual';

            // 4. Usuarios Vinculados
            final usuariosJson = seq['usuarios_vinculados'];
            if (usuariosJson is List) {
              _usuariosVinculados.addAll(usuariosJson.map((e) => e.toString()));
            }

            // 5. FECHAS - Extraer la próxima visita y entrega REAL desde la tabla cronograma_visitas
            if (seq['proxima_visita'] != null) {
              try {
                final proximaVisita = DateTime.parse(
                  seq['proxima_visita'].toString(),
                );

                DateTime proximaEntrega;
                if (seq['proxima_entrega'] != null) {
                  proximaEntrega = DateTime.parse(
                    seq['proxima_entrega'].toString(),
                  );
                } else {
                  // Respaldo de seguridad por si la entrega viene nula
                  proximaEntrega = proximaVisita.add(const Duration(days: 2));
                }

                // Reemplazamos el par por defecto con los datos reales vigentes
                _paresVisitaEntrega = [
                  {'visita': proximaVisita, 'entrega': proximaEntrega},
                ];
              } catch (e) {
                debugPrint(
                  'Error al leer fechas de próxima visita/entrega: $e',
                );
              }
            }
          } else if (widget.proveedorInicial != null &&
              widget.proveedorInicial!.isNotEmpty) {
            _proveedorSeleccionado = widget.proveedorInicial;
            _proveedorController.text = widget.proveedorInicial!;
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al cargar datos: $e')));
      }
    }
  }

  Future<void> _seleccionarFechaHoraPar(int index, String tipoKey) async {
    final DateTime fechaBase = _paresVisitaEntrega[index][tipoKey]!;

    final fecha = await showDatePicker(
      context: context,
      initialDate: fechaBase,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(
        const Duration(days: 365 * 2),
      ), // Limitar a 2 años máximo
    );
    if (fecha == null) return;

    if (!mounted) return;
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(fechaBase),
    );
    if (hora == null) return;

    setState(() {
      _paresVisitaEntrega[index][tipoKey] = DateTime(
        fecha.year,
        fecha.month,
        fecha.day,
        hora.hour,
        hora.minute,
      );

      if (tipoKey == 'visita') {
        final entregaActual = _paresVisitaEntrega[index]['entrega']!;
        if (entregaActual.isBefore(_paresVisitaEntrega[index]['visita']!)) {
          _paresVisitaEntrega[index]['entrega'] =
              _paresVisitaEntrega[index]['visita']!.add(
                const Duration(days: 1),
              );
        }
      }
    });
  }

  Future<void> _guardar() async {
    final nombreProveedor = _proveedorController.text.trim();
    final numeroCelular = _celularController.text.trim();

    if (nombreProveedor.isEmpty || _usuariosVinculados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Por favor asigne un Proveedor y al menos un Usuario responsable.',
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _cronogramaService.crearProgramacion(
        proveedor: nombreProveedor,
        contactoCelular: numeroCelular,
        frecuencia: _frecuenciaSeleccionada,
        paresVisitaEntrega: _paresVisitaEntrega,
        repetirMeses: _repetirMeses,
        usuariosVinculados: _usuariosVinculados,
      );

      widget.onSaved();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cronograma guardado con éxito. Secuencias futuras generadas.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar el cronograma: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.secuenciaAEditar != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(esEdicion ? 'Editar Secuencia' : 'Programar Secuencia'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return DropdownMenu<String>(
                        width: constraints.maxWidth,
                        controller: _proveedorController,
                        enableFilter: true,
                        requestFocusOnTap: true,
                        label: const Text('Nombre del Proveedor'),
                        leadingIcon: const Icon(Icons.business),
                        inputDecorationTheme: const InputDecorationTheme(
                          border: OutlineInputBorder(),
                        ),
                        initialSelection: _proveedorSeleccionado,
                        dropdownMenuEntries: _proveedoresDb.map((prov) {
                          return DropdownMenuEntry<String>(
                            value: prov,
                            label: prov,
                          );
                        }).toList(),
                        onSelected: (val) =>
                            setState(() => _proveedorSeleccionado = val),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _celularController,
                    decoration: const InputDecoration(
                      labelText: "Contacto Celular (WhatsApp)",
                      prefixIcon: Icon(Icons.phone_android),
                      border: OutlineInputBorder(),
                      hintText: "Ej: 0991234567",
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _frecuenciaSeleccionada,
                          decoration: const InputDecoration(
                            labelText: 'Frecuencia de Ciclo',
                            border: OutlineInputBorder(),
                          ),
                          items: _opcionesFrecuencia.map((frec) {
                            String label = frec;
                            if (frec == 'Mensual') label = '1 vez al mes';
                            if (frec == 'Quincenal') label = '2 veces al mes';
                            if (frec == 'Semanal') label = '4 veces al mes';
                            return DropdownMenuItem(
                              value: frec,
                              child: Text(label),
                            );
                          }).toList(),
                          onChanged: (val) =>
                              setState(() => _frecuenciaSeleccionada = val!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _repetirMeses,
                          decoration: const InputDecoration(
                            labelText: 'Proyectar por:',
                            border: OutlineInputBorder(),
                          ),
                          items: _opcionesDuracion.entries.map((entry) {
                            return DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            );
                          }).toList(),
                          onChanged: (val) =>
                              setState(() => _repetirMeses = val!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      const Icon(Icons.link, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        'Configuración de Visitas y Entregas Conectadas:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _paresVisitaEntrega.length,
                    itemBuilder: (context, index) {
                      final par = _paresVisitaEntrega[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 14),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Punto de Conexión #${index + 1}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                  if (_paresVisitaEntrega.length > 1)
                                    IconButton(
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(
                                        Icons.delete_forever,
                                        color: Colors.redAccent,
                                      ),
                                      onPressed: () => _eliminarPar(index),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                  Icons.calendar_today,
                                  color: Colors.blue,
                                ),
                                title: const Text(
                                  'Día y Hora de Visita (Toma de Pedido)',
                                ),
                                subtitle: Text(
                                  DateFormat(
                                    'EEEE, dd/MM/yyyy - HH:mm',
                                  ).format(par['visita']!),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 14,
                                ),
                                onTap: () =>
                                    _seleccionarFechaHoraPar(index, 'visita'),
                              ),
                              const Divider(height: 8),
                              ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                  Icons.local_shipping,
                                  color: Colors.orange,
                                ),
                                title: const Text(
                                  'Día y Hora de Entrega (Llegada Física)',
                                ),
                                subtitle: Text(
                                  DateFormat(
                                    'EEEE, dd/MM/yyyy - HH:mm',
                                  ).format(par['entrega']!),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 14,
                                ),
                                onTap: () =>
                                    _seleccionarFechaHoraPar(index, 'entrega'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  OutlinedButton.icon(
                    onPressed: _agregarOtroPar,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text(
                      'Añadir otra visita/entrega semanal a este proveedor',
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'Usuarios Asignados para Alertas:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    constraints: const BoxConstraints(maxHeight: 160),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _usuariosDb.length,
                      itemBuilder: (context, index) {
                        final u = _usuariosDb[index];
                        final isSelected = _usuariosVinculados.contains(
                          u.nombreUsuario,
                        );
                        return CheckboxListTile(
                          dense: true,
                          title: Text(
                            u.nombreUsuario,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(u.rol),
                          value: isSelected,
                          onChanged: (bool? checked) {
                            setState(() {
                              if (checked == true) {
                                _usuariosVinculados.add(u.nombreUsuario);
                              } else {
                                _usuariosVinculados.remove(u.nombreUsuario);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 28),

                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                    onPressed: _guardar,
                    icon: Icon(esEdicion ? Icons.update : Icons.cloud_upload),
                    label: Text(
                      esEdicion
                          ? 'Actualizar y Re-proyectar Calendario'
                          : 'Proyectar y Generar Calendario',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
