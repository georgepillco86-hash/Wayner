import 'package:flutter/material.dart';

import '../services/pedidos_service.dart';

class UnidadesMedidaAdminScreen extends StatefulWidget {
  const UnidadesMedidaAdminScreen({super.key});

  @override
  State<UnidadesMedidaAdminScreen> createState() =>
      _UnidadesMedidaAdminScreenState();
}

class _UnidadesMedidaAdminScreenState extends State<UnidadesMedidaAdminScreen> {
  final PedidosService service = PedidosService();

  bool isLoading = true;
  String? errorMessage;
  List<dynamic> unidades = [];

  @override
  void initState() {
    super.initState();
    cargarUnidades();
  }

  Future<void> cargarUnidades() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final data = await service.listarUnidadesMedidaAdmin();

      if (!mounted) return;

      setState(() {
        unidades = data;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = "No se pudieron cargar las unidades de medida";
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> crearUnidad() async {
    final controller = TextEditingController();

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Nueva unidad de medida"),
          content: TextField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: "Nombre",
              hintText: "Ej: DOCENAS",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Guardar"),
            ),
          ],
        );
      },
    );

    if (confirmado != true) return;

    final nombre = controller.text.trim();

    if (nombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ingresa el nombre de la unidad")),
      );
      return;
    }

    try {
      await service.crearUnidadMedida(nombre: nombre);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unidad creada correctamente")),
      );

      await cargarUnidades();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No se pudo crear la unidad")),
      );
    }
  }

  Future<void> editarUnidad(dynamic unidad) async {
    final id = int.tryParse(unidad["id"].toString()) ?? 0;
    final nombreActual = unidad["nombre"]?.toString() ?? "";
    final activoActual = unidad["activo"] == true;

    final controller = TextEditingController(text: nombreActual);
    bool activo = activoActual;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Editar unidad de medida"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: "Nombre",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Activo"),
                    value: activo,
                    onChanged: (value) {
                      setDialogState(() {
                        activo = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Cancelar"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text("Guardar"),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmado != true) return;

    final nuevoNombre = controller.text.trim();

    if (id <= 0 || nuevoNombre.isEmpty) return;

    try {
      await service.actualizarUnidadMedida(
        unidadId: id,
        nombre: nuevoNombre,
        activo: activo,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Unidad actualizada")));

      await cargarUnidades();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No se pudo actualizar la unidad")),
      );
    }
  }

  Future<void> desactivarUnidad(dynamic unidad) async {
    final id = int.tryParse(unidad["id"].toString()) ?? 0;
    final nombre = unidad["nombre"]?.toString() ?? "";

    if (id <= 0) return;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Desactivar unidad"),
          content: Text("¿Seguro que deseas desactivar la unidad $nombre?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Desactivar"),
            ),
          ],
        );
      },
    );

    if (confirmado != true) return;

    try {
      await service.desactivarUnidadMedida(unidadId: id);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Unidad desactivada")));

      await cargarUnidades();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No se pudo desactivar la unidad")),
      );
    }
  }

  // 🔥 FUNCIÓN CORREGIDA: Evita el rebote y guarda en la BD
  void _onReorder(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = unidades.removeAt(oldIndex);
      unidades.insert(newIndex, item);
    });

    // Extraemos los IDs en el nuevo orden
    List<int> idsOrdenados = unidades.map((u) {
      return int.tryParse(u["id"]?.toString() ?? '0') ?? 0;
    }).toList();

    try {
      // Llamamos al servicio para guardar (Asegúrate de agregar este método en tu PedidosService)
      await service.actualizarOrdenUnidades(idsOrdenados);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error al guardar el nuevo orden")),
      );
      // Si falla, recargamos la lista para deshacer el cambio visual erróneo
      cargarUnidades();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Unidades de medida"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Actualizar",
            onPressed: cargarUnidades,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: "Nueva unidad",
            onPressed: crearUnidad,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(child: Text(errorMessage!))
          : unidades.isEmpty
          ? const Center(child: Text("No hay unidades registradas"))
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: unidades.length,
              onReorder: _onReorder,
              itemBuilder: (_, index) {
                final unidad = unidades[index];
                final activo = unidad["activo"] == true;

                // 🔥 CORRECCIÓN: Usamos el ID o el NOMBRE (que sabemos que es único) para evitar el rebote visual
                final String keyString =
                    unidad["id"]?.toString() ??
                    unidad["nombre"]?.toString() ??
                    index.toString();

                return Card(
                  key: ValueKey(
                    keyString,
                  ), // Esto le dice a Flutter exactamente qué tarjeta se movió
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(child: Text("${index + 1}")),
                    title: Text(
                      unidad["nombre"]?.toString() ?? "",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      activo ? "Activo" : "Inactivo",
                      style: TextStyle(
                        color: activo ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == "editar") {
                              editarUnidad(unidad);
                            } else if (value == "desactivar") {
                              desactivarUnidad(unidad);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: "editar",
                              child: Text("Editar"),
                            ),
                            PopupMenuItem(
                              value: "desactivar",
                              child: Text("Desactivar"),
                            ),
                          ],
                        ),
                        const Icon(Icons.drag_handle, color: Colors.grey),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
