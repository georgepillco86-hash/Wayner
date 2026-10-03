import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/pedidos/models/pedido_item.dart';

class PedidoDraftStorage {
  static const String _key = "pedido_carrito_borrador";

  static Future<void> save(List<PedidoItem> items) async {
    final prefs = await SharedPreferences.getInstance();

    if (items.isEmpty) {
      await prefs.remove(_key);
      return;
    }

    final data = items.map((item) => item.toJson()).toList();
    await prefs.setString(_key, jsonEncode(data));
  }

  static Future<List<PedidoItem>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);

    if (raw == null || raw.isEmpty) return [];

    try {
      final List data = jsonDecode(raw);

      return data
          .map((item) => PedidoItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      await clear();
      return [];
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}