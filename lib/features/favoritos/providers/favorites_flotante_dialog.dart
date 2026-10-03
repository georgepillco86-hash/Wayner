import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'package:ferrotienda_flutter_proyecto/core/storage/session_storage.dart';
import 'package:ferrotienda_flutter_proyecto/features/favoritos/providers/favorites_provider.dart';
import 'package:ferrotienda_flutter_proyecto/features/saldos/data/services/saldos_api_service.dart';
import 'package:ferrotienda_flutter_proyecto/features/promociones/services/promocion_service.dart';
import 'package:ferrotienda_flutter_proyecto/features/printer/services/network_printer_service.dart';

class FavoritesFlotanteDialog extends StatefulWidget {
  const FavoritesFlotanteDialog({super.key});

  @override
  State<FavoritesFlotanteDialog> createState() =>
      _FavoritesFlotanteDialogState();
}

class _FavoritesFlotanteDialogState extends State<FavoritesFlotanteDialog> {
  String _searchQuery = '';
  String? _selectedMarca;
  String? _selectedClase;
  String? _selectedGrupo;

  final Set<String> _selectedCodigos = {};
  bool get _inSelectionMode => _selectedCodigos.isNotEmpty;

  bool _isPrinting = false;

  Future<void> _ejecutarImpresionMasiva() async {
    if (_selectedCodigos.isEmpty) return;

    setState(() => _isPrinting = true);

    final apiService = SaldosApiService();
    final promoService = PromocionService();
    final networkPrinter = NetworkPrinterService();

    final user = await SessionStorage.getUser();
    final nombreCrudo = user?.nombreUsuario ?? 'COLABORADOR';
    final nombreUsuario = nombreCrudo.toUpperCase();

    List<Map<String, dynamic>> itemsToPrint = [];
    int errores = 0;

    try {
      for (String codigo in _selectedCodigos) {
        try {
          final price = await apiService.getProductPrice(codigo);

          dynamic promoActiva;
          try {
            final promos = await promoService.listar(codigoBarra: codigo);
            promoActiva = promos.firstWhere(
              (p) => p.activa == true,
              orElse: () => throw Exception('No promo'),
            );
          } catch (_) {
            promoActiva = null;
          }

          itemsToPrint.add({'productPrice': price, 'promocion': promoActiva});
        } catch (e) {
          errores++;
        }
      }

      if (itemsToPrint.isEmpty) {
        throw Exception(
          "No se pudo obtener información de precios para imprimir.",
        );
      }

      await networkPrinter.printBulkLabels(itemsToPrint, nombreUsuario);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Se imprimieron ${itemsToPrint.length} cenefas. ${errores > 0 ? "Faltaron $errores por error de datos." : ""}',
            ),
            backgroundColor: Colors.green,
          ),
        );
        setState(() => _selectedCodigos.clear());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error de impresión: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<void> _ejecutarImpresionVariaciones() async {
    if (_selectedCodigos.isEmpty) return;

    setState(() => _isPrinting = true);

    final apiService = SaldosApiService();
    final promoService = PromocionService();
    final networkPrinter = NetworkPrinterService();

    final user = await SessionStorage.getUser();
    final nombreCrudo = user?.nombreUsuario ?? 'COLABORADOR';
    final nombreUsuario = nombreCrudo.toUpperCase();

    List<Map<String, dynamic>> itemsToPrint = [];
    int errores = 0;
    int omitidos = 0;

    try {
      for (String codigo in _selectedCodigos) {
        try {
          final price = await apiService.getProductPrice(codigo);

          if (price.tieneVariacion) {
            dynamic promoActiva;
            try {
              final promos = await promoService.listar(codigoBarra: codigo);
              promoActiva = promos.firstWhere(
                (p) => p.activa == true,
                orElse: () => throw Exception('No promo'),
              );
            } catch (_) {
              promoActiva = null;
            }

            itemsToPrint.add({'productPrice': price, 'promocion': promoActiva});
          } else {
            omitidos++;
          }
        } catch (e) {
          errores++;
        }
      }

      if (itemsToPrint.isEmpty) {
        throw Exception(
          "Ninguno de los productos seleccionados tiene variación de precio. (Se omitieron $omitidos iguales).",
        );
      }

      await networkPrinter.printBulkLabels(itemsToPrint, nombreUsuario);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Se imprimieron ${itemsToPrint.length} cenefas actualizadas. Se omitieron $omitidos sin cambios.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        setState(() => _selectedCodigos.clear());
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange.shade800),
                const SizedBox(width: 8),
                const Text('Aviso de Impresión'),
              ],
            ),
            content: Text(
              e.toString().replaceAll('Exception: ', ''),
              style: const TextStyle(fontSize: 16),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.orange.shade800,
                ),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  // --- LÓGICA DE EXPORTAR E IMPORTAR ---

  Future<void> _exportarFavoritos() async {
    try {
      final provider = context.read<FavoritesProvider>();
      final jsonString = provider.exportFavorites();

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/favoritos_ferrotienda.txt');
      await file.writeAsString(jsonString);

      if (mounted) {
        await Share.shareXFiles([
          XFile(file.path),
        ], text: 'Respaldo de Favoritos y Grupos - Ferrotienda');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _importarFavoritos() async {
    try {
      // 🔥 NUEVA API DE FILE_PICKER v13 🔥
      List<PlatformFile> result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );

      if (result.isNotEmpty && result.first.path != null) {
        final file = File(result.first.path!);
        final jsonString = await file.readAsString();

        if (mounted) {
          final provider = context.read<FavoritesProvider>();
          final resumen = await provider.importFavorites(jsonString);

          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Importación Exitosa'),
                ],
              ),
              content: Text(
                'Se validaron e importaron correctamente:\n\n'
                '📦 ${resumen['productos']} Productos nuevos.\n'
                '📂 ${resumen['grupos']} Grupos nuevos.\n\n'
                '(Se omitieron los duplicados exactos).',
                style: const TextStyle(fontSize: 16),
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: FilledButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('Aceptar'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Error: El archivo seleccionado no tiene un formato válido.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _mostrarDialogoCrearGrupo() {
    String nuevoGrupo = '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Crear nuevo grupo'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Ej: Urgentes...',
            labelText: 'Nombre del Grupo',
            border: OutlineInputBorder(),
          ),
          onChanged: (val) => nuevoGrupo = val,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (nuevoGrupo.trim().isNotEmpty) {
                context.read<FavoritesProvider>().crearGrupo(nuevoGrupo);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoEditarGrupo(String grupoActual) {
    String nuevoGrupo = grupoActual;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar grupo'),
        content: TextFormField(
          initialValue: grupoActual,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          onChanged: (val) => nuevoGrupo = val,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (nuevoGrupo.trim().isNotEmpty && nuevoGrupo != grupoActual) {
                context.read<FavoritesProvider>().editarGrupo(
                  grupoActual,
                  nuevoGrupo,
                );
                if (_selectedGrupo == grupoActual) {
                  setState(() => _selectedGrupo = nuevoGrupo);
                }
              }
              Navigator.pop(ctx);
            },
            child: const Text('Actualizar'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoAdministrarGrupos() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Administrar Grupos'),
          contentPadding: const EdgeInsets.only(top: 10),
          content: SizedBox(
            width: double.maxFinite,
            child: Consumer<FavoritesProvider>(
              builder: (context, provider, child) {
                if (provider.grupos.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text(
                      'No has creado ningún grupo aún.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: provider.grupos.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final grupo = provider.grupos[index];
                    return ListTile(
                      title: Text(
                        grupo,
                        style: const TextStyle(fontWeight: FontWeight.w600),
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
                            onPressed: () => _mostrarDialogoEditarGrupo(grupo),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.red,
                              size: 20,
                            ),
                            onPressed: () {
                              provider.eliminarGrupo(grupo);
                              if (_selectedGrupo == grupo) {
                                setState(() => _selectedGrupo = null);
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  void _mostrarMenuCabecera() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  'Opciones de Grupos',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(
                  Icons.create_new_folder,
                  color: Colors.blue,
                ),
                title: const Text('Crear un nuevo grupo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _mostrarDialogoCrearGrupo();
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings, color: Colors.grey),
                title: const Text('Administrar grupos'),
                onTap: () {
                  Navigator.pop(ctx);
                  _mostrarDialogoAdministrarGrupos();
                },
              ),
              const Divider(height: 1),
              // 🔥 BOTONES DE EXPORTACIÓN E IMPORTACIÓN 🔥
              ListTile(
                leading: const Icon(Icons.file_upload, color: Colors.green),
                title: const Text('Exportar favoritos (.txt)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportarFavoritos();
                },
              ),
              ListTile(
                leading: const Icon(Icons.file_download, color: Colors.orange),
                title: const Text('Importar favoritos (.txt)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _importarFavoritos();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _mostrarDialogoAsignarGrupo(List<String> codigos) {
    final gruposExistentes = context.read<FavoritesProvider>().grupos;
    if (gruposExistentes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No tienes grupos creados. Mantén presionada la cabecera para crear uno.',
          ),
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          codigos.length == 1
              ? 'Asignar a grupo'
              : 'Asignar ${codigos.length} productos',
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: gruposExistentes.length,
            itemBuilder: (context, index) {
              final grupo = gruposExistentes[index];
              return ListTile(
                leading: const Icon(Icons.folder, color: Colors.amber),
                title: Text(grupo),
                onTap: () {
                  context.read<FavoritesProvider>().assignGroup(codigos, grupo);
                  Navigator.pop(ctx);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  void _mostrarMenuProducto(
    BuildContext context,
    Map<String, String> fav,
    List<Map<String, String>> filteredFavs,
  ) {
    final provider = context.read<FavoritesProvider>();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  fav['nombre']!,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  Icons.folder_special,
                  color: Colors.amber.shade700,
                ),
                title: const Text('Asignar a un grupo existente'),
                onTap: () {
                  Navigator.pop(ctx);
                  _mostrarDialogoAsignarGrupo([fav['codigo']!]);
                },
              ),
              if (fav['grupo'] != null && fav['grupo']!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.folder_off, color: Colors.grey),
                  title: const Text('Quitar del grupo actual'),
                  onTap: () {
                    provider.assignGroup([fav['codigo']!], '');
                    Navigator.pop(ctx);
                  },
                ),
              ListTile(
                leading: const Icon(
                  Icons.check_box_outlined,
                  color: Colors.blue,
                ),
                title: const Text('Seleccionar'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _selectedCodigos.add(fav['codigo']!));
                },
              ),
              ListTile(
                leading: const Icon(Icons.checklist, color: Colors.blue),
                title: Text(
                  'Seleccionar todo (${filteredFavs.length} visibles)',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(
                    () => _selectedCodigos.addAll(
                      filteredFavs.map((f) => f['codigo']!),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text(
                  'Eliminar de favoritos',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  provider.toggleFavorite(fav['codigo']!, fav['nombre']!);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _mostrarMenuImpresion(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.print,
                  color: Colors.deepPurple,
                  size: 28,
                ),
                title: Text(
                  '${_selectedCodigos.length} productos seleccionados',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: const Text(
                  'Epson TM-T20III en Red Local (192.168.3.247)',
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(
                  Icons.print_outlined,
                  color: Colors.deepPurple,
                ),
                title: const Text('Imprimir todas las cenefas'),
                onTap: () {
                  Navigator.pop(ctx);
                  _ejecutarImpresionMasiva();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.price_change_outlined,
                  color: Colors.orange,
                ),
                title: const Text('Imprimir únicamente las que varían'),
                onTap: () {
                  Navigator.pop(ctx);
                  _ejecutarImpresionVariaciones();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final favProvider = context.watch<FavoritesProvider>();
    final favorites = favProvider.favorites;
    final gruposReales = favProvider.grupos;

    final marcas =
        favorites
            .map((f) => f['marca']!)
            .where((m) => m.isNotEmpty && m != 'Sin Marca')
            .toSet()
            .toList()
          ..sort();
    final clases =
        favorites
            .map((f) => f['clase']!)
            .where((c) => c.isNotEmpty && c != 'Sin Clase')
            .toSet()
            .toList()
          ..sort();

    final filteredFavs = favorites.where((fav) {
      final matchesSearch =
          fav['nombre']!.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          fav['codigo']!.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesMarca =
          _selectedMarca == null || fav['marca'] == _selectedMarca;
      final matchesClase =
          _selectedClase == null || fav['clase'] == _selectedClase;
      final matchesGrupo =
          _selectedGrupo == null ||
          (_selectedGrupo == 'Sin Grupo'
              ? (fav['grupo'] == null || fav['grupo'] == '')
              : fav['grupo'] == _selectedGrupo);
      return matchesSearch && matchesMarca && matchesClase && matchesGrupo;
    }).toList();

    return Stack(
      children: [
        Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.95,
            height: MediaQuery.of(context).size.height * 0.92,
            color: Colors.white,
            child: Column(
              children: [
                GestureDetector(
                  onLongPress: _mostrarMenuCabecera,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    color: _inSelectionMode
                        ? Colors.deepPurple.shade50
                        : Theme.of(context).colorScheme.primaryContainer,
                    child: Row(
                      children: [
                        Icon(
                          _inSelectionMode
                              ? Icons.check_circle
                              : Icons.star_rounded,
                          color: _inSelectionMode
                              ? Colors.deepPurple
                              : Colors.amber,
                          size: 28,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _inSelectionMode
                                ? '${_selectedCodigos.length} Seleccionados'
                                : 'Mis Favoritos',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _inSelectionMode
                                  ? Colors.deepPurple.shade900
                                  : Colors.black,
                            ),
                          ),
                        ),
                        if (_inSelectionMode)
                          TextButton(
                            onPressed: () =>
                                setState(() => _selectedCodigos.clear()),
                            child: const Text('Cancelar'),
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.close),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => Navigator.pop(context),
                          ),
                      ],
                    ),
                  ),
                ),
                if (!_inSelectionMode) ...[
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        TextField(
                          decoration: const InputDecoration(
                            labelText: 'Buscar en favoritos',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(vertical: 0),
                          ),
                          onChanged: (value) =>
                              setState(() => _searchQuery = value),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Marca',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 0,
                                  ),
                                ),
                                value: _selectedMarca,
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('Todas'),
                                  ),
                                  ...marcas.map(
                                    (m) => DropdownMenuItem(
                                      value: m,
                                      child: Text(
                                        m,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: (value) =>
                                    setState(() => _selectedMarca = value),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Clase',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 0,
                                  ),
                                ),
                                value: _selectedClase,
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('Todas'),
                                  ),
                                  ...clases.map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(
                                        c,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: (value) =>
                                    setState(() => _selectedClase = value),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Filtrar por Grupo',
                            prefixIcon: Icon(Icons.folder_open),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 0,
                            ),
                          ),
                          value: _selectedGrupo,
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Todos los grupos'),
                            ),
                            const DropdownMenuItem(
                              value: 'Sin Grupo',
                              child: Text('Sin Grupo (Desagrupados)'),
                            ),
                            ...gruposReales.map(
                              (g) => DropdownMenuItem(
                                value: g,
                                child: Text(g, overflow: TextOverflow.ellipsis),
                              ),
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => _selectedGrupo = value),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Colors.blue),
                ],
                Expanded(
                  child: filteredFavs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.star_border_rounded,
                                size: 60,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                favorites.isEmpty
                                    ? 'No tienes productos'
                                    : 'Ninguno coincide',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: filteredFavs.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final fav = filteredFavs[index];
                            final tieneGrupo =
                                fav['grupo'] != null &&
                                fav['grupo']!.isNotEmpty;
                            final isSelected = _selectedCodigos.contains(
                              fav['codigo'],
                            );

                            return GestureDetector(
                              onDoubleTap: () {
                                if (_inSelectionMode)
                                  setState(() => _selectedCodigos.clear());
                              },
                              child: Material(
                                color: Colors.transparent,
                                child: ListTile(
                                  selected: isSelected,
                                  selectedTileColor: Colors.deepPurple.shade50,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 2,
                                  ),
                                  leading: _inSelectionMode
                                      ? Icon(
                                          isSelected
                                              ? Icons.check_circle
                                              : Icons.radio_button_unchecked,
                                          color: isSelected
                                              ? Colors.deepPurple
                                              : Colors.grey.shade400,
                                        )
                                      : null,
                                  onTap: () {
                                    if (_inSelectionMode) {
                                      setState(() {
                                        if (isSelected)
                                          _selectedCodigos.remove(
                                            fav['codigo']!,
                                          );
                                        else
                                          _selectedCodigos.add(fav['codigo']!);
                                      });
                                    }
                                  },
                                  onLongPress: () {
                                    if (_inSelectionMode)
                                      _mostrarMenuImpresion(context);
                                    else
                                      _mostrarMenuProducto(
                                        context,
                                        fav,
                                        filteredFavs,
                                      );
                                  },
                                  title: Text(
                                    fav['nombre']!,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Cód: ${fav['codigo']}  |  Marca: ${fav['marca']}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                        if (tieneGrupo) ...[
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.amber.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              border: Border.all(
                                                color: Colors.amber.shade300,
                                              ),
                                            ),
                                            child: Text(
                                              '📂 ${fav['grupo']}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.amber.shade900,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),

        if (_isPrinting)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 20),
                      Text(
                        'Enviando a impresora Epson...',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
