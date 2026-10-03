import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../data/models/product_balance.dart';
import '../../data/services/saldos_api_service.dart';

class ProductSearchController extends ChangeNotifier {
  final SaldosApiService _service;

  ProductSearchController({SaldosApiService? service})
    : _service = service ?? SaldosApiService();

  bool isLoading = false;
  String? errorMessage;
  String? technicalError;

  String? selectedClass;
  String? selectedProvider;

  // Estado del Interruptor
  bool isDeepSearch = false;

  List<String> classes = [];
  List<String> providers = [];
  List<ProductBalance> products = [];

  // --- Lista maestra para filtrado local en memoria ---
  List<ProductBalance> _masterProductsList = [];

  String? _lastSearchText;
  String? _lastSearchClass;
  String? _lastSearchProvider;
  bool _initialDataLoaded = false;

  // 🔥 NUEVA FUNCIÓN: Filtro Anti-Clones 🔥
  // Elimina cualquier producto duplicado usando su código como identificador único
  List<ProductBalance> _eliminarDuplicados(List<ProductBalance> listaBruta) {
    final Map<String, ProductBalance> productosUnicos = {};
    for (var item in listaBruta) {
      if (item.codigo.isNotEmpty && !productosUnicos.containsKey(item.codigo)) {
        productosUnicos[item.codigo] = item;
      }
    }
    return productosUnicos.values.toList();
  }

  Future<void> toggleDeepSearch(bool value) async {
    isDeepSearch = value;
    notifyListeners();

    if (selectedProvider != null) {
      await filterByProvider(selectedProvider);
    } else if (selectedClass != null) {
      await filterByClass(selectedClass);
    } else {
      await loadDataset(forceRefresh: true, keepFilters: true);
    }

    if (_lastSearchText != null && _lastSearchText!.isNotEmpty) {
      await search(_lastSearchText!);
    }
  }

  Future<void> loadInitialData({bool forceRefresh = false}) async {
    if (_initialDataLoaded && !forceRefresh) return;

    _setLoading(true);
    try {
      final results = await Future.wait([
        _service.getClasses(),
        _service.getProviders(),
        isDeepSearch
            ? _service.getDataset(limit: 200)
            : _service.searchProducts(text: ''),
      ]);

      classes = results[0] as List<String>;
      providers = results[1] as List<String>;

      // 🔥 Pasamos los resultados por el filtro anti-clones
      final rawProducts = results[2] as List<ProductBalance>;
      products = _eliminarDuplicados(rawProducts);

      _masterProductsList = List.from(products);
      _initialDataLoaded = true;
      _clearError();
      notifyListeners();
    } catch (e) {
      print("❌ ERROR GENERAL EN LOAD INITIAL DATA: $e");
      products = [];
      _setError(e);
    } finally {
      _setLoading(false);
    }
  }

  void refresh() {
    if (_lastSearchText != null && _lastSearchText!.isNotEmpty) {
      search(_lastSearchText!);
    } else {
      loadInitialData(forceRefresh: true);
    }
  }

  Future<void> search(String text) async {
    if (isLoading) return;

    final cleanText = text.trim();
    final lowerQuery = cleanText.toLowerCase();

    // --- 1. FILTRADO LOCAL EN MEMORIA ---
    if (selectedProvider != null || selectedClass != null) {
      if (cleanText.isEmpty) {
        products = List.from(_masterProductsList);
      } else {
        _applyLocalSearchText(lowerQuery);
      }
      _lastSearchText = cleanText;
      notifyListeners();
      return;
    }

    // --- 2. BÚSQUEDA GLOBAL AL SERVIDOR ---
    if (cleanText.isEmpty) {
      await loadDataset(forceRefresh: true, keepFilters: true);
      return;
    }

    _setLoading(true);
    try {
      if (isDeepSearch) {
        final results = await _service.busquedaProfundaKardex(cleanText);
        final rawProducts = results
            .map((json) => ProductBalance.fromJson(json))
            .toList();
        // 🔥 Aplicamos el filtro
        products = _eliminarDuplicados(rawProducts);
      } else {
        final rawProducts = await _service.searchProducts(
          text: cleanText,
          proveedor: selectedProvider,
        );
        // 🔥 Aplicamos el filtro
        products = _eliminarDuplicados(rawProducts);
      }

      _lastSearchText = cleanText;
      _clearError();
      notifyListeners();
    } catch (e) {
      products = [];
      _setError(e);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadDataset({
    bool forceRefresh = false,
    bool keepFilters = false,
  }) async {
    if (isLoading && !forceRefresh) return;

    _setLoading(true);
    try {
      List<ProductBalance> rawProducts;
      if (isDeepSearch) {
        rawProducts = await _service.getDataset(
          limit: 200,
          proveedor: selectedProvider,
        );
      } else {
        rawProducts = await _service.searchProducts(
          text: '',
          proveedor: selectedProvider,
        );
      }

      // 🔥 Aplicamos el filtro
      products = _eliminarDuplicados(rawProducts);
      _masterProductsList = List.from(products);

      if (!keepFilters) {
        selectedClass = null;
        selectedProvider = null;
      }
      _clearError();
      notifyListeners();
    } catch (e) {
      products = [];
      _setError(e);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> filterByClass(String? clase) async {
    if (isLoading) return;

    selectedClass = clase;
    if (clase == null || clase.isEmpty) {
      await loadDataset(forceRefresh: true, keepFilters: true);
      return;
    }

    _setLoading(true);
    try {
      List<ProductBalance> rawProducts;
      if (isDeepSearch) {
        rawProducts = await _service.getProductsByClass(
          clase,
          limit: 5000,
          proveedor: selectedProvider,
        );
      } else {
        rawProducts = await _service.searchProducts(
          text: '',
          proveedor: selectedProvider,
          clase: clase,
        );
      }

      // 🔥 Aplicamos el filtro
      products = _eliminarDuplicados(rawProducts);
      _masterProductsList = List.from(products);

      if (_lastSearchText != null && _lastSearchText!.isNotEmpty) {
        _applyLocalSearchText(_lastSearchText!.toLowerCase());
      }

      notifyListeners();
    } catch (e) {
      _setError(e);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> filterByProvider(String? proveedor) async {
    if (isLoading) return;

    selectedProvider = proveedor;

    if (proveedor == null) {
      await loadDataset(forceRefresh: true, keepFilters: true);
      return;
    }

    _setLoading(true);
    try {
      List<ProductBalance> rawProducts;
      if (isDeepSearch) {
        rawProducts = await _service.getDataset(
          limit: 5000,
          proveedor: proveedor,
        );
      } else {
        rawProducts = await _service.searchProducts(
          text: '',
          proveedor: proveedor,
        );
      }

      // 🔥 Aplicamos el filtro
      products = _eliminarDuplicados(rawProducts);
      _masterProductsList = List.from(products);

      if (_lastSearchText != null && _lastSearchText!.isNotEmpty) {
        _applyLocalSearchText(_lastSearchText!.toLowerCase());
      }

      notifyListeners();
    } catch (e) {
      products = [];
      _setError(e);
    } finally {
      _setLoading(false);
    }
  }

  void _applyLocalSearchText(String lowerQuery) {
    products = _masterProductsList.where((p) {
      return p.nombre.toLowerCase().contains(lowerQuery) ||
          p.codigo.toLowerCase().contains(lowerQuery) ||
          (p.codigoBarra?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  void _setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }

  void _clearError() {
    errorMessage = null;
    technicalError = null;
  }

  void _setError(Object error) {
    if (error is ApiException) {
      errorMessage = error.message;
      technicalError = error.technicalMessage;
    } else {
      errorMessage = 'Error inesperado.';
      technicalError = error.toString();
    }
    notifyListeners();
  }
}
