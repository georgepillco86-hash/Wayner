import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../data/models/merma_model.dart';
import '../../data/services/merma_service.dart';
import '../../../saldos/data/services/saldos_api_service.dart';
import '../../../saldos/data/models/product_balance.dart';
import '../../../saldos/presentation/screens/barcode_scanner_screen.dart';

class MermaFormDialog extends StatefulWidget {
  final Merma? merma;
  final VoidCallback onSave;

  const MermaFormDialog({super.key, this.merma, required this.onSave});

  @override
  State<MermaFormDialog> createState() => _MermaFormDialogState();
}

class _MermaFormDialogState extends State<MermaFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _mermaService = MermaService();
  final _saldosService = SaldosApiService();

  final _codigoController = TextEditingController();
  final _nombreController = TextEditingController();
  final _cantidadController = TextEditingController();
  final _comentarioController = TextEditingController();

  String? _novedadSeleccionada;
  final List<String> _opcionesNovedad = [
    'Producto Expirado',
    'Producto con envase comprometido',
    'Producto contaminado',
    'Producto no requerido',
    'Rebate',
  ];

  bool _isSaving = false;
  bool _isSearching = false;
  String _ultimaBusqueda = '';

  // 🔥 NUEVO: Lista para almacenar temporalmente las mermas antes de guardarlas
  List<Merma> _mermasAgregadas = [];

  // Usamos una Key para resetear el Autocomplete al agregar un ítem a la lista
  Key _autocompleteKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    if (widget.merma != null) {
      _codigoController.text = widget.merma!.codigo;
      _nombreController.text = widget.merma!.nombreProducto;
      _cantidadController.text = widget.merma!.cantidad.toString();
      _comentarioController.text = widget.merma!.comentario ?? '';

      _novedadSeleccionada = widget.merma!.novedad;
      if (!_opcionesNovedad.contains(_novedadSeleccionada)) {
        _opcionesNovedad.add(_novedadSeleccionada!);
      }
    }
  }

  Future<void> _abrirEscaner(
    TextEditingController autocompleteController,
  ) async {
    final status = await Permission.camera.request();

    if (status.isGranted) {
      if (!mounted) return;
      final code = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
      );

      if (code != null && code.isNotEmpty && mounted) {
        autocompleteController.text = code;
        _codigoController.text = code;

        setState(() => _isSearching = true);
        try {
          final producto = await _saldosService.getProductByCode(code);
          if (producto != null) {
            setState(() {
              _nombreController.text = producto.nombre;
            });
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Código escaneado no encontrado en el sistema'),
              ),
            );
          }
        } finally {
          if (mounted) setState(() => _isSearching = false);
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Se requiere permiso de cámara para escanear'),
        ),
      );
    }
  }

  // 🔥 NUEVO: Función para ir llenando la lista visual
  void _agregarALaLista() {
    if (!_formKey.currentState!.validate()) return;
    if (_codigoController.text.isEmpty) return;

    final nuevaMerma = Merma(
      codigo: _codigoController.text,
      nombreProducto: _nombreController.text,
      cantidad: double.parse(_cantidadController.text),
      novedad: _novedadSeleccionada!,
      comentario: _comentarioController.text,
      estado: 'Pendiente',
      usuario: '',
      activo: true,
    );

    setState(() {
      _mermasAgregadas.add(nuevaMerma);
      // Limpiamos los campos para el siguiente escaneo (mantenemos la novedad seleccionada por agilidad)
      _codigoController.clear();
      _nombreController.clear();
      _cantidadController.clear();
      _comentarioController.clear();
      _autocompleteKey = UniqueKey(); // Resetea la caja de búsqueda
    });
  }

  void _eliminarDeLaLista(int index) {
    setState(() {
      _mermasAgregadas.removeAt(index);
    });
  }

  Future<void> _guardarTodo() async {
    final esEdicion = widget.merma != null;

    if (esEdicion) {
      // Flujo normal si es EDICIÓN (sólo un ítem)
      if (!_formKey.currentState!.validate() || _codigoController.text.isEmpty)
        return;

      FocusScope.of(context).unfocus();
      setState(() => _isSaving = true);
      try {
        await _mermaService.actualizarMerma(widget.merma!.id!, {
          'cantidad': double.parse(_cantidadController.text),
          'novedad': _novedadSeleccionada,
          'comentario': _comentarioController.text,
        });
        widget.onSave();
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    } else {
      // 🔥 Flujo MULTIPLE si es CREACIÓN
      if (_mermasAgregadas.isEmpty) {
        // Por si escribió algo pero olvidó darle a "Agregar a la lista"
        if (_codigoController.text.isNotEmpty &&
            _formKey.currentState!.validate()) {
          _agregarALaLista();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No hay mermas en la lista para guardar'),
            ),
          );
          return;
        }
      }

      FocusScope.of(context).unfocus();
      setState(() => _isSaving = true);
      try {
        // Este es el método nuevo que deberemos crear en merma_service.dart
        await _mermaService.crearMermasEnLote(_mermasAgregadas);

        widget.onSave();
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.merma != null;

    return AlertDialog(
      title: Text(esEdicion ? 'Modificar Registro' : 'Registrar Mermas'),
      content: SizedBox(
        width: 600, // Lo hacemos un poco más ancho para acomodar la lista
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Autocomplete<ProductBalance>(
                      key: _autocompleteKey,
                      optionsBuilder:
                          (TextEditingValue textEditingValue) async {
                            final query = textEditingValue.text.trim();
                            if (query.length < 3)
                              return const Iterable<ProductBalance>.empty();

                            _ultimaBusqueda = query;
                            await Future.delayed(
                              const Duration(milliseconds: 500),
                            );
                            if (_ultimaBusqueda != query)
                              return const Iterable<ProductBalance>.empty();

                            try {
                              final results = await _saldosService
                                  .searchProducts(text: query, limit: 10);
                              final Map<String, ProductBalance> unicos = {};
                              for (var producto in results) {
                                unicos[producto.codigo] = producto;
                              }
                              return unicos.values.toList();
                            } catch (e) {
                              return const Iterable<ProductBalance>.empty();
                            }
                          },
                      displayStringForOption: (ProductBalance option) =>
                          option.codigo,
                      onSelected: (ProductBalance selection) {
                        _codigoController.text = selection.codigo;
                        _nombreController.text = selection.nombre;
                      },
                      fieldViewBuilder:
                          (context, controller, focusNode, onFieldSubmitted) {
                            if (esEdicion && controller.text.isEmpty) {
                              controller.text = widget.merma!.codigo;
                            }
                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                labelText: 'Código / Últimos dígitos',
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.qr_code_scanner),
                                  tooltip: 'Escanear con cámara',
                                  onPressed: esEdicion
                                      ? null
                                      : () => _abrirEscaner(controller),
                                ),
                              ),
                              enabled: !esEdicion,
                              onChanged: (val) => _codigoController.text = val,
                              validator: (v) {
                                if (_mermasAgregadas.isEmpty &&
                                    (v == null || v.isEmpty))
                                  return 'Requerido';
                                return null;
                              },
                            );
                          },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxHeight: 250,
                                maxWidth: 300,
                              ),
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                itemCount: options.length,
                                itemBuilder: (context, index) {
                                  final option = options.elementAt(index);
                                  return ListTile(
                                    title: Text(
                                      option.codigo,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(
                                      option.nombre,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onTap: () => onSelected(option),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nombreController,
                      decoration: InputDecoration(
                        labelText: 'Nombre del Producto',
                        suffixIcon: _isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      enabled: false,
                      validator: (v) {
                        if (_mermasAgregadas.isEmpty &&
                            (v == null || v.isEmpty))
                          return 'Seleccione un producto';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            controller: _cantidadController,
                            decoration: const InputDecoration(
                              labelText: 'Cantidad',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (_mermasAgregadas.isNotEmpty &&
                                  (v == null || v.isEmpty))
                                return null;
                              return double.tryParse(v ?? '') == null
                                  ? 'Inválido'
                                  : null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            value: _novedadSeleccionada,
                            decoration: const InputDecoration(
                              labelText: 'Condición (Novedad)',
                            ),
                            isExpanded: true,
                            items: _opcionesNovedad.map((String val) {
                              return DropdownMenuItem(
                                value: val,
                                child: Text(
                                  val,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) =>
                                setState(() => _novedadSeleccionada = val),
                            validator: (v) {
                              if (_mermasAgregadas.isNotEmpty &&
                                  _codigoController.text.isEmpty)
                                return null;
                              return v == null || v.isEmpty
                                  ? 'Requerido'
                                  : null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _comentarioController,
                      decoration: const InputDecoration(
                        labelText: 'Comentario Opcional',
                      ),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 16),

                    // Botón para ir armando la lista (Solo visible en Creación)
                    if (!esEdicion)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _agregarALaLista,
                          icon: const Icon(Icons.add_shopping_cart),
                          label: const Text('Agregar a la lista'),
                        ),
                      ),
                  ],
                ),
              ),

              // 🔥 SECCIÓN NUEVA: Previsualización de la lista de Mermas agregadas
              if (!esEdicion && _mermasAgregadas.isNotEmpty) ...[
                const Divider(height: 30, thickness: 1),
                Text(
                  'Mermas por registrar (${_mermasAgregadas.length}):',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _mermasAgregadas.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _mermasAgregadas[index];
                      return ListTile(
                        dense: true,
                        title: Text(
                          item.nombreProducto,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          '${item.cantidad}x | ${item.novedad}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.red,
                            size: 20,
                          ),
                          onPressed: () => _eliminarDeLaLista(index),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            FocusScope.of(context).unfocus();
            Navigator.pop(context);
          },
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _guardarTodo,
          child: _isSaving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(esEdicion ? 'Actualizar' : 'Guardar Todo'),
        ),
      ],
    );
  }
}
