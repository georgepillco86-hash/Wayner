import 'dart:ui' as ui;

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../../logs/services/audit_log_service.dart';
import '../../products/data/models/product_price.dart';
import '../../promociones/models/promocion.dart';

class BluetoothPrinterService {
  static const String _printerMacKey = 'selected_printer_mac';
  static const String _printerNameKey = 'selected_printer_name';

  final AuditLogService _auditLogService = AuditLogService();
  final ApiClient _apiClient = ApiClient();

  Future<List<BluetoothInfo>> getPairedDevices() async {
    if (kIsWeb) {
      debugPrint(
        "Web detectada: Retornando lista vacía de dispositivos Bluetooth.",
      );
      return [];
    }

    final enabled = await PrintBluetoothThermal.bluetoothEnabled;
    if (!enabled) {
      await _registrarLogImpresion(
        accion: 'BLUETOOTH_DESCONECTADO',
        detalle: 'Bluetooth apagado al consultar impresoras vinculadas',
      );
      throw Exception('Bluetooth está apagado');
    }
    return PrintBluetoothThermal.pairedBluetooths;
  }

  Future<void> saveSelectedPrinter({
    required String macAddress,
    required String name,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_printerMacKey, macAddress);
    await prefs.setString(_printerNameKey, name);
  }

  Future<String?> getSavedPrinterMac() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_printerMacKey);
  }

  Future<String?> getSavedPrinterName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_printerNameKey);
  }

  Future<void> clearSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_printerMacKey);
    await prefs.remove(_printerNameKey);
  }

  Future<bool> connect(String macAddress) async {
    if (kIsWeb) {
      debugPrint(
        "Web detectada: Simulando conexión a impresora Bluetooth ($macAddress).",
      );
      return true;
    }

    final isConnected = await PrintBluetoothThermal.connectionStatus;
    if (isConnected) return true;

    await PrintBluetoothThermal.disconnect;
    await Future.delayed(const Duration(milliseconds: 800));

    return PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
  }

  Future<void> disconnect() async {
    if (kIsWeb) return;
    await PrintBluetoothThermal.disconnect;
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<bool> printPriceLabel({required ProductPrice productPrice}) async {
    if (kIsWeb) {
      debugPrint(
        "Web detectada: Simulando impresión exitosa de ${productPrice.nombreProducto}",
      );
      return true;
    }

    final printerName = await getSavedPrinterName();
    final printerMac = await getSavedPrinterMac();

    try {
      final connected = await PrintBluetoothThermal.connectionStatus;

      if (!connected) {
        await _registrarLogImpresion(
          accion: 'BLUETOOTH_DESCONECTADO',
          detalle:
              'Intento de impresión sin conexión. Producto: ${productPrice.nombreProducto}, Código: ${productPrice.codigoBarra}, Impresora: ${printerName ?? '-'}',
        );
        throw Exception('La impresora no está conectada');
      }

      final promocion = await _obtenerPromocionActiva(productPrice.codigoBarra);

      final bytes = await _buildPriceLabel(
        productPrice: productPrice,
        promocion: promocion,
      );

      final result = await PrintBluetoothThermal.writeBytes(bytes);

      await Future.delayed(const Duration(milliseconds: 1200));
      await PrintBluetoothThermal.disconnect;
      await Future.delayed(const Duration(milliseconds: 800));

      await _registrarLogImpresion(
        accion: result ? 'IMPRESION_EXITOSA' : 'ERROR_IMPRESION',
        detalle:
            'Cenefa ${result ? 'impresa correctamente' : 'rechazada por impresora'}. '
            'Tipo: ${promocion == null ? 'NORMAL' : 'PROMOCION'}, '
            'Producto: ${productPrice.nombreProducto}, '
            'Código: ${productPrice.codigoBarra}, '
            'Precio: \$${_precioFinal(productPrice, promocion).toStringAsFixed(2)}, '
            'Impresora: ${printerName ?? '-'}, MAC: ${printerMac ?? '-'}',
      );

      return result;
    } catch (e) {
      await _registrarLogImpresion(
        accion: 'ERROR_IMPRESION',
        detalle:
            'Error imprimiendo cenefa. Producto: ${productPrice.nombreProducto}, Código: ${productPrice.codigoBarra}, Error: $e',
      );
      rethrow;
    }
  }

  Future<Promocion?> _obtenerPromocionActiva(String codigoBarra) async {
    try {
      final response = await _apiClient.get(
        '/api/promociones/activa/$codigoBarra',
      );

      final data = response['data'];

      if (data is Map<String, dynamic>) {
        return Promocion.fromJson(data);
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<int>> _buildPriceLabel({
    required ProductPrice productPrice,
    required Promocion? promocion,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);

    final bytes = <int>[];
    bytes.addAll(generator.reset());
    bytes.addAll(generator.feed(3));

    // Decidimos qué imagen generar en base a si existe una promoción
    final img.Image labelImage = promocion == null
        ? await _buildNormalLabelImage(productPrice)
        : await _buildPromoLabelImage(productPrice, promocion);

    bytes.addAll(
      generator.imageRaster(
        labelImage,
        align: PosAlign.center,
        highDensityHorizontal: true,
        highDensityVertical: true,
      ),
    );

    bytes.addAll(generator.feed(4));
    return bytes;
  }

  // ==============================================================
  // GENERADOR 1: ETIQUETA PROMOCIONAL (3X LARGO Y ALTO IMPACTO)
  // ==============================================================
  Future<img.Image> _buildPromoLabelImage(
    ProductPrice productPrice,
    Promocion promocion,
  ) async {
    const width = 384;
    // 🔥 Aumentamos la altura a 800 para dar espacio a los textos divididos en 2 líneas
    const height = 800;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    _drawWhiteBackground(canvas, width, height);

    final encabezado = _cleanText(
      promocion.encabezado?.isNotEmpty == true
          ? promocion.encabezado!
          : 'OFERTA',
    );
    final nombre = _cleanText(
      promocion.nombreProducto.isNotEmpty
          ? promocion.nombreProducto
          : productPrice.nombreProducto,
    );
    final oldPrice = '\$${promocion.precioAnterior.toStringAsFixed(2)}';
    final newPrice = '\$${promocion.precioActualProm.toStringAsFixed(2)}';
    final ahorro = '\$${promocion.ahorro.toStringAsFixed(2)}';

    String mecanicaStr = promocion.mecanica?.toUpperCase() ?? '';
    if (mecanicaStr.isEmpty && promocion.precioAnterior > 0) {
      final pct = ((promocion.ahorro / promocion.precioAnterior) * 100).round();
      mecanicaStr = 'DESCUENTO ($pct%)';
    } else if (mecanicaStr.isEmpty) {
      mecanicaStr = 'PROMOCION';
    }

    final fInicio = _formatDate(promocion.fechaInicio);
    final fFin = _formatDate(promocion.fechaFin);
    final codigo = productPrice.codigoBarra.trim();

    double currentY = 20;

    // 1. Encabezado (GIGANTE - maxLines 2)
    _drawText(
      canvas,
      encabezado.toUpperCase(),
      x: 0,
      y: currentY,
      width: width.toDouble(),
      fontSize: 55,
      fontWeight: FontWeight.w900,
      maxLines: 2,
      textAlign: TextAlign.center,
      height: 1.0,
    );
    currentY += 120; // Damos espacio para 2 líneas

    // 2. Nombre del producto (GIGANTE - maxLines 3)
    _drawText(
      canvas,
      nombre.toUpperCase(),
      x: 10,
      y: currentY,
      width: width.toDouble() - 20,
      fontSize: 40,
      fontWeight: FontWeight.w900,
      maxLines: 3,
      textAlign: TextAlign.center,
      height: 1.0,
    );
    currentY += 105; // Damos espacio para múltiples líneas

    // 3. Título Precio Anterior
    _drawText(
      canvas,
      'PRECIO ANTERIOR:',
      x: 0,
      y: currentY,
      width: width.toDouble(),
      fontSize: 20,
      fontWeight: FontWeight.w700,
      textAlign: TextAlign.center,
    );
    currentY += 25;

    // 4. Valor Precio Anterior (Tachado y GIGANTE)
    _drawText(
      canvas,
      oldPrice,
      x: 0,
      y: currentY,
      width: width.toDouble(),
      fontSize: 40,
      fontWeight: FontWeight.w700,
      textAlign: TextAlign.center,
      strikethrough: true,
    );
    currentY += 50;

    // 5. Precio Actual (SÚPER GIGANTE)
    _drawText(
      canvas,
      newPrice,
      x: 0,
      y: currentY,
      width: width.toDouble(),
      fontSize: 95,
      fontWeight: FontWeight.w900,
      textAlign: TextAlign.center,
    );
    currentY += 105;

    // 6. Título Ahorro
    _drawText(
      canvas,
      'AHORRO:',
      x: 0,
      y: currentY,
      width: width.toDouble(),
      fontSize: 22,
      fontWeight: FontWeight.w700,
      textAlign: TextAlign.center,
    );
    currentY += 30;

    // 7. Valor Ahorro (GIGANTE)
    _drawText(
      canvas,
      ahorro,
      x: 0,
      y: currentY,
      width: width.toDouble(),
      fontSize: 44,
      fontWeight: FontWeight.w900,
      textAlign: TextAlign.center,
    );
    currentY += 55;

    // 8. Título Mecánica
    _drawText(
      canvas,
      'MECANICA:',
      x: 0,
      y: currentY,
      width: width.toDouble(),
      fontSize: 20,
      fontWeight: FontWeight.w800,
      textAlign: TextAlign.center,
    );
    currentY += 28;

    // 9. Valor Mecánica (GIGANTE)
    _drawText(
      canvas,
      mecanicaStr,
      x: 0,
      y: currentY,
      width: width.toDouble(),
      fontSize: 40,
      fontWeight: FontWeight.w900,
      textAlign: TextAlign.center,
    );
    currentY += 50;

    // 10. Título Vigencia
    _drawText(
      canvas,
      'VIGENCIA:',
      x: 0,
      y: currentY,
      width: width.toDouble(),
      fontSize: 18,
      fontWeight: FontWeight.w800,
      textAlign: TextAlign.center,
    );
    currentY += 25;

    // 11. Valor Vigencia (GIGANTE)
    _drawText(
      canvas,
      '$fInicio AL $fFin',
      x: 0,
      y: currentY,
      width: width.toDouble(),
      fontSize: 32,
      fontWeight: FontWeight.w900,
      textAlign: TextAlign.center,
    );
    currentY += 50;

    // 12. QR Code
    final qrData = codigo;
    final qrSize = 130.0;
    final qrX = (width - qrSize) / 2;
    _drawQr(canvas, data: qrData, x: qrX, y: currentY, size: qrSize);
    currentY += qrSize + 10;

    // 13. Codigo de barra
    _drawText(
      canvas,
      codigo,
      x: 0,
      y: currentY,
      width: width.toDouble(),
      fontSize: 28,
      fontWeight: FontWeight.w900,
      textAlign: TextAlign.center,
    );

    return _canvasToImage(recorder, width, height);
  }

  // ==============================================================
  // GENERADOR 2: ETIQUETA NORMAL (OPTIMIZADA)
  // ==============================================================
  Future<img.Image> _buildNormalLabelImage(ProductPrice productPrice) async {
    const width = 384;
    const height = 213;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    _drawWhiteBackground(canvas, width, height);

    final nombre = _cleanText(productPrice.nombreProducto);
    final codigo = productPrice.codigoBarra.trim();
    final precio = '\$${productPrice.precioConIva.toStringAsFixed(2)}';

    // 🔥 QR Code (Solo con el código de barras numérico)
    final qrData = codigo;

    // NOMBRE DEL PRODUCTO
    _drawText(
      canvas,
      nombre.toUpperCase(),
      x: 10,
      y: 10,
      width: 364,
      fontSize: 30,
      fontWeight: FontWeight.w900,
      maxLines: 2,
      height: 1.0,
    );

    // TEXTO "PRECIO ESPECIAL"
    _drawText(
      canvas,
      'PRECIO ESPECIAL',
      x: 10,
      y: 85,
      width: 230,
      fontSize: 25,
      fontWeight: FontWeight.w800,
      maxLines: 1,
    );

    // PRECIO GIGANTE
    _drawText(
      canvas,
      precio,
      x: 10,
      y: 115,
      width: 240,
      fontSize: 56,
      fontWeight: FontWeight.w900,
      maxLines: 1,
    );

    // QR ubicado a la derecha
    _drawQr(canvas, data: qrData, x: 260, y: 68, size: 112);

    // CÓDIGO NUMÉRICO
    _drawText(
      canvas,
      codigo,
      x: 245,
      y: 190,
      width: 140,
      fontSize: 20,
      fontWeight: FontWeight.w900,
      maxLines: 1,
      textAlign: TextAlign.center,
    );

    return _canvasToImage(recorder, width, height);
  }

  void _drawWhiteBackground(Canvas canvas, int width, int height) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = Colors.white,
    );
  }

  // 🔥 QR OPTIMIZADO PARA IMPRESORAS TÉRMICAS (ANTI-BLOQUEO / ANTI-SANGRADO)
  void _drawQr(
    Canvas canvas, {
    required String data,
    required double x,
    required double y,
    required double size,
  }) {
    canvas.save();
    canvas.translate(x, y);

    final qrPainter = QrPainter(
      data: data,
      version: QrVersions.auto,
      // Nivel de corrección 'L' (Low) genera cuadros más grandes
      errorCorrectionLevel: QrErrorCorrectLevel.L,
      // 🔥 gapless en false evita que la impresora junte los bloques de tinta
      gapless: false,
      color: Colors.black,
      emptyColor: Colors.white,
    );

    qrPainter.paint(canvas, Size(size, size));
    canvas.restore();
  }

  // Soporta alineación estricta y tachado (strikethrough)
  void _drawText(
    Canvas canvas,
    String text, {
    required double x,
    required double y,
    required double width,
    required double fontSize,
    required FontWeight fontWeight,
    int maxLines = 1,
    TextAlign textAlign = TextAlign.left,
    double height = 1.0,
    bool strikethrough = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.black,
          fontSize: fontSize,
          fontWeight: fontWeight,
          height: height,
          decoration: strikethrough
              ? TextDecoration.lineThrough
              : TextDecoration.none,
          decorationThickness: strikethrough ? 2.5 : 0.0,
          decorationColor: Colors.black,
        ),
      ),
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: '...',
    );

    painter.layout(minWidth: width, maxWidth: width);
    painter.paint(canvas, Offset(x, y));
  }

  Future<img.Image> _canvasToImage(
    ui.PictureRecorder recorder,
    int width,
    int height,
  ) async {
    final picture = recorder.endRecording();
    final uiImage = await picture.toImage(width, height);
    final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
    return img.decodeImage(byteData!.buffer.asUint8List())!;
  }

  String _formatDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year}';
  }

  double _precioFinal(ProductPrice productPrice, Promocion? promocion) {
    return promocion?.precioActualProm ?? productPrice.precioConIva;
  }

  Future<void> _registrarLogImpresion({
    required String accion,
    required String detalle,
  }) async {
    try {
      await _auditLogService.registrarEvento(
        accion: accion,
        modulo: 'IMPRESION',
        detalle: detalle,
      );
    } catch (_) {}
  }

  String _cleanText(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
