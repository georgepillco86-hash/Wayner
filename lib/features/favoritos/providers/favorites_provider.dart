import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesProvider extends ChangeNotifier {
  List<Map<String, String>> _favorites = [];
  List<String> _grupos = [];

  List<Map<String, String>> get favorites => _favorites;
  List<String> get grupos => _grupos;

  FavoritesProvider() {
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    final String? favString = prefs.getString('favoritos_lista');
    if (favString != null) {
      final List<dynamic> decoded = jsonDecode(favString);
      _favorites = decoded
          .map(
            (item) => {
              'codigo': item['codigo']?.toString() ?? '',
              'nombre': item['nombre']?.toString() ?? '',
              'marca': item['marca']?.toString() ?? '',
              'clase': item['clase']?.toString() ?? '',
              'grupo': item['grupo']?.toString() ?? '',
            },
          )
          .toList();
    }

    final String? gruposString = prefs.getString('favoritos_grupos');
    if (gruposString != null) {
      _grupos = List<String>.from(jsonDecode(gruposString));
    }

    notifyListeners();
  }

  Future<void> toggleFavorite(
    String codigo,
    String nombre, {
    String marca = '',
    String clase = '',
  }) async {
    // Si ya existe (en uno o varios grupos), al presionar la estrella para quitarlo,
    // eliminamos TODAS las instancias de este producto para mantener limpia la base.
    final exists = _favorites.any((fav) => fav['codigo'] == codigo);
    if (exists) {
      _favorites.removeWhere((fav) => fav['codigo'] == codigo);
    } else {
      _favorites.add({
        'codigo': codigo,
        'nombre': nombre,
        'marca': marca,
        'clase': clase,
        'grupo': '',
      });
    }
    notifyListeners();
    await _saveFavorites();
  }

  // --- GESTIÓN DE GRUPOS ---

  Future<void> crearGrupo(String nombre) async {
    final nombreLimpio = nombre.trim();
    if (nombreLimpio.isNotEmpty && !_grupos.contains(nombreLimpio)) {
      _grupos.add(nombreLimpio);
      _grupos.sort();
      notifyListeners();
      await _saveGrupos();
    }
  }

  Future<void> editarGrupo(String nombreViejo, String nombreNuevo) async {
    final limpio = nombreNuevo.trim();
    if (limpio.isNotEmpty && !_grupos.contains(limpio)) {
      final index = _grupos.indexOf(nombreViejo);
      if (index >= 0) {
        _grupos[index] = limpio;
        _grupos.sort();
        for (var fav in _favorites) {
          if (fav['grupo'] == nombreViejo) {
            fav['grupo'] = limpio;
          }
        }
        notifyListeners();
        await _saveGrupos();
        await _saveFavorites();
      }
    }
  }

  Future<void> eliminarGrupo(String nombre) async {
    _grupos.remove(nombre);
    for (var fav in _favorites) {
      if (fav['grupo'] == nombre) {
        fav['grupo'] = '';
      }
    }
    notifyListeners();
    await _saveGrupos();
    await _saveFavorites();
  }

  Future<void> assignGroup(List<String> codigos, String nombreGrupo) async {
    for (var fav in _favorites) {
      if (codigos.contains(fav['codigo'])) {
        fav['grupo'] = nombreGrupo;
      }
    }
    notifyListeners();
    await _saveFavorites();
  }

  // --- EXPORTAR E IMPORTAR (FORMATO .TXT) ---

  String exportFavorites() {
    final data = {'grupos': _grupos, 'favorites': _favorites};
    return jsonEncode(data);
  }

  Future<Map<String, int>> importFavorites(String jsonString) async {
    int gruposAgregados = 0;
    int productosAgregados = 0;

    try {
      final data = jsonDecode(jsonString);
      final List<dynamic> importedGrupos = data['grupos'] ?? [];
      final List<dynamic> importedFavorites = data['favorites'] ?? [];

      // 1. Importar grupos validando duplicados
      for (var g in importedGrupos) {
        final String nombreLimpio = g.toString().trim();
        if (nombreLimpio.isNotEmpty && !_grupos.contains(nombreLimpio)) {
          _grupos.add(nombreLimpio);
          gruposAgregados++;
        }
      }
      _grupos.sort();

      // 2. Importar productos (Validación Código + Grupo)
      for (var item in importedFavorites) {
        final codigo = item['codigo']?.toString() ?? '';
        final grupo = item['grupo']?.toString() ?? '';

        if (codigo.isEmpty) continue;

        // Regla: Si existe el MISMO código en el MISMO grupo, lo salta.
        final existe = _favorites.any(
          (f) => f['codigo'] == codigo && f['grupo'] == grupo,
        );

        if (!existe) {
          _favorites.add({
            'codigo': codigo,
            'nombre': item['nombre']?.toString() ?? '',
            'marca': item['marca']?.toString() ?? '',
            'clase': item['clase']?.toString() ?? '',
            'grupo': grupo,
          });
          productosAgregados++;

          // Si el producto trae un grupo que no existía en la lista principal, lo creamos
          if (grupo.isNotEmpty && !_grupos.contains(grupo)) {
            _grupos.add(grupo);
            _grupos.sort();
            gruposAgregados++;
          }
        }
      }

      if (gruposAgregados > 0 || productosAgregados > 0) {
        notifyListeners();
        await _saveGrupos();
        await _saveFavorites();
      }

      return {'grupos': gruposAgregados, 'productos': productosAgregados};
    } catch (e) {
      throw Exception(
        "El archivo no tiene un formato válido para Ferrotienda.",
      );
    }
  }

  // --- PERSISTENCIA ---

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('favoritos_lista', jsonEncode(_favorites));
  }

  Future<void> _saveGrupos() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('favoritos_grupos', jsonEncode(_grupos));
  }

  bool isFavorite(String codigo) {
    return _favorites.any((fav) => fav['codigo'] == codigo);
  }
}
