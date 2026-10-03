import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class AdministrarPublicidadScreen extends StatefulWidget {
  const AdministrarPublicidadScreen({super.key});

  @override
  State<AdministrarPublicidadScreen> createState() =>
      _AdministrarPublicidadScreenState();
}

class _AdministrarPublicidadScreenState
    extends State<AdministrarPublicidadScreen> {
  // 🔥 RUTA REAL A TU BACKEND ACTUALIZADA
  final String _apiUrl = 'http://192.168.1.231:5000/api/publicidad';

  List<Map<String, dynamic>> _anuncios = [];
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarAnunciosDesdeServidor();
  }

  // --- 1. LEER DESDE POSTGRESQL (CON CORRECCIÓN DE CARGA INFINITA) ---
  Future<void> _cargarAnunciosDesdeServidor() async {
    try {
      // Agregamos un timeout de 10 segundos para no esperar infinitamente
      final response = await http
          .get(Uri.parse(_apiUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _anuncios = List<Map<String, dynamic>>.from(
              json.decode(response.body),
            );
          });
        }
      } else {
        debugPrint("Error del servidor: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error de conexión con FastAPI: $e");
    } finally {
      // Esto asegura que el círculo de carga se detenga siempre, haya error o no
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- 2. SUBIR VIDEO REAL AL BACKEND ---
  Future<void> _subirAlServidor(XFile archivo, String tipo) async {
    setState(() => _isUploading = true);

    try {
      var request = http.MultipartRequest('POST', Uri.parse('$_apiUrl/upload'));
      request.fields['tipo'] = tipo;
      request.files.add(
        await http.MultipartFile.fromPath('file', archivo.path),
      );

      var streamedResponse = await request.send();

      if (streamedResponse.statusCode == 200) {
        await _cargarAnunciosDesdeServidor();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Archivo guardado en la Base de Datos'),
            ),
          );
        }
      } else {
        throw Exception('Error en el servidor al guardar');
      }
    } catch (e) {
      debugPrint("Error al subir: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Error al subir el archivo'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _validarYSubirArchivo(XFile? archivo, String tipo) async {
    if (archivo == null) return;

    final int bytes = await archivo.length();
    final double megabytes = bytes / (1024 * 1024);

    if (megabytes > 40.0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '⚠️ Archivo muy pesado (${megabytes.toStringAsFixed(1)} MB). Límite 40 MB.',
            ),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
      return;
    }

    final extension = archivo.name.split('.').last.toLowerCase();
    if (tipo == 'video' && extension != 'mp4') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Solo videos MP4.'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
      return;
    }

    if (tipo == 'imagen' && !['jpg', 'jpeg', 'png'].contains(extension)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Use JPG o PNG.'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
      return;
    }

    await _subirAlServidor(archivo, tipo);
  }

  Future<void> _seleccionarArchivo() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.videocam, color: Color(0xFF1F6F8B)),
                title: const Text('Subir Video (MP4)'),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? video = await _picker.pickVideo(
                    source: ImageSource.gallery,
                  );
                  await _validarYSubirArchivo(video, 'video');
                },
              ),
              ListTile(
                leading: const Icon(Icons.image, color: Color(0xFF1F6F8B)),
                title: const Text('Subir Imagen (JPG/PNG)'),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? image = await _picker.pickImage(
                    source: ImageSource.gallery,
                  );
                  await _validarYSubirArchivo(image, 'imagen');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _anuncios.removeAt(oldIndex);
      _anuncios.insert(newIndex, item);
    });

    try {
      final nuevoOrden = _anuncios.map((a) => {'id': a['id']}).toList();
      await http.put(
        Uri.parse('$_apiUrl/orden'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'orden': nuevoOrden}),
      );
    } catch (e) {
      debugPrint("Error guardando orden: $e");
    }
  }

  Future<void> _cambiarEstado(int id, bool valor, int index) async {
    setState(() => _anuncios[index]['activo'] = valor);
    try {
      await http.patch(
        Uri.parse('$_apiUrl/$id/estado'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'activo': valor}),
      );
    } catch (e) {
      setState(() => _anuncios[index]['activo'] = !valor);
    }
  }

  Future<void> _eliminarAnuncio(int id, int index) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Publicidad'),
        content: const Text(
          '¿Estás seguro de que deseas borrar este archivo permanentemente?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _anuncios.removeAt(index));

    try {
      await http.delete(Uri.parse('$_apiUrl/$id'));
    } catch (e) {
      debugPrint("Error al eliminar: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1F6F8B);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrar Publicidad'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isUploading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Subiendo archivo al servidor...',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey.shade100,
                  width: double.infinity,
                  child: const Text(
                    'Mantén presionado un elemento y arrástralo para cambiar el orden de reproducción en las pantallas de los Kioscos.',
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ),
                Expanded(
                  child: _anuncios.isEmpty
                      ? const Center(
                          child: Text("No hay publicidad subida aún."),
                        )
                      : ReorderableListView.builder(
                          itemCount: _anuncios.length,
                          onReorder: _onReorder,
                          itemBuilder: (context, index) {
                            final anuncio = _anuncios[index];
                            final isVideo = anuncio['tipo'] == 'video';

                            return Card(
                              key: ValueKey(anuncio['id']),
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              elevation: 2,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: isVideo
                                      ? Colors.blue.shade100
                                      : Colors.orange.shade100,
                                  child: Icon(
                                    isVideo
                                        ? Icons.play_circle_fill
                                        : Icons.image,
                                    color: isVideo
                                        ? Colors.blue.shade700
                                        : Colors.orange.shade700,
                                  ),
                                ),
                                title: Text(
                                  anuncio['nombre_archivo'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  isVideo ? 'Formato MP4' : 'Imagen estática',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Switch(
                                      value: anuncio['activo'],
                                      activeColor: primaryColor,
                                      onChanged: (valor) => _cambiarEstado(
                                        anuncio['id'],
                                        valor,
                                        index,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                      ),
                                      onPressed: () => _eliminarAnuncio(
                                        anuncio['id'],
                                        index,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.drag_handle,
                                      color: Colors.grey,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _seleccionarArchivo,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.cloud_upload),
        label: const Text('Subir Publicidad'),
      ),
    );
  }
}
