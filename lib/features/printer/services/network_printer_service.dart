import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;
import 'package:qr_flutter/qr_flutter.dart';

import 'package:ferrotienda_flutter_proyecto/features/products/data/models/product_price.dart';
import 'package:ferrotienda_flutter_proyecto/features/promociones/models/promocion.dart';

class NetworkPrinterService {
  final String ipAddress;
  final int port;

  NetworkPrinterService({this.ipAddress = '192.168.3.247', this.port = 9100});

  Future<void> printBulkLabels(
    List<Map<String, dynamic>> itemsToPrint,
    String nombreUsuario,
  ) async {
    Socket? socket;
    bool connected = false;
    int retryCount = 0;
    const int maxRetries = 6; // Intentará por 18 segundos si hay fila

    try {
      debugPrint("🖨️ [EPSON] Preparando trabajo para $nombreUsuario...");
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);

      // ==========================================
      // LÓGICA DE FILA DE ESPERA (REINTENTOS)
      // ==========================================
      while (!connected && retryCount < maxRetries) {
        try {
          socket = await Socket.connect(
            ipAddress,
            port,
            timeout: const Duration(seconds: 4),
          );
          connected = true;
          debugPrint("🖨️ [EPSON] ¡Conectado! Turno concedido.");
        } catch (e) {
          retryCount++;
          debugPrint(
            "🖨️ [EPSON] Impresora ocupada. En fila de espera... Intento $retryCount de $maxRetries",
          );
          if (retryCount >= maxRetries) {
            throw Exception(
              "La impresora está siendo usada por otro compañero y la fila está llena. Intenta en unos segundos.",
            );
          }
          await Future.delayed(
            const Duration(seconds: 3),
          ); // Espera 3 seg antes de volver a tocar la puerta
        }
      }

      if (socket == null) return;

      // ==========================================
      // 1. IMPRIMIR ENCABEZADO Y ESPERAR
      // ==========================================
      debugPrint("🖨️ [EPSON] Imprimiendo Encabezado...");
      final img.Image headerImage = await _buildHeaderImage(nombreUsuario);
      List<int> headerBytes = [];
      headerBytes.addAll(generator.reset());
      headerBytes.addAll(generator.feed(1));
      headerBytes.addAll(
        generator.imageRaster(
          headerImage,
          align: PosAlign.center,
          highDensityHorizontal: true,
          highDensityVertical: true,
        ),
      );
      headerBytes.addAll(generator.feed(2));

      socket.add(headerBytes);
      await socket.flush();
      await Future.delayed(const Duration(milliseconds: 2000));

      // ==========================================
      // 2. IMPRIMIR CENEFAS UNA A UNA
      // ==========================================
      for (int i = 0; i < itemsToPrint.length; i++) {
        var item = itemsToPrint[i];
        final productPrice = item['productPrice'] as ProductPrice;
        final promocion = item['promocion'] as Promocion?;

        debugPrint("🖨️ [EPSON] Imprimiendo cenefa ${i + 1}...");
        final img.Image labelImage = promocion == null
            ? await _buildNormalLabelImage(productPrice)
            : await _buildPromoLabelImage(productPrice, promocion);

        List<int> bytes = [];
        bytes.addAll(
          generator.imageRaster(
            labelImage,
            align: PosAlign.center,
            highDensityHorizontal: true,
            highDensityVertical: true,
          ),
        );
        bytes.addAll(generator.feed(2));

        socket.add(bytes);
        await socket.flush();

        await Future.delayed(const Duration(milliseconds: 2000));
      }

      // ==========================================
      // 3. IMPRIMIR PIE DE PÁGINA (SIN GUILLOTINA)
      // ==========================================
      debugPrint(
        "🖨️ [EPSON] Imprimiendo Pie de página (Sin corte automático)...",
      );
      final img.Image footerImage = await _buildFooterImage();
      List<int> footerBytes = [];
      footerBytes.addAll(
        generator.imageRaster(
          footerImage,
          align: PosAlign.center,
          highDensityHorizontal: true,
          highDensityVertical: true,
        ),
      );

      // 🔥 AUMENTADO A 15 para darte 3 a 4 cm extras para el corte manual
      footerBytes.addAll(generator.feed(15));

      // ¡ELIMINADO EL COMANDO DE CORTE!

      socket.add(footerBytes);
      await socket.flush();
      await Future.delayed(const Duration(milliseconds: 1000));

      debugPrint(
        "🖨️ [EPSON] Trabajo finalizado. Liberando impresora para el siguiente...",
      );
    } catch (e) {
      debugPrint("🚨 [EPSON] ERROR: $e");
      rethrow; // Pasa el error a la ventana flotante para mostrar el SnackBar
    } finally {
      await socket?.close();
    }
  }

  // ==============================================================
  // GENERADORES DE ENCABEZADO Y PIE DE PÁGINA
  // ==============================================================
  Future<img.Image> _buildHeaderImage(String userName) async {
    const width = 384;
    const height = 120;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    _drawWhiteBackground(canvas, width, height);

    _drawText(
      canvas,
      'USUARIO:',
      x: 0,
      y: 10,
      width: width.toDouble(),
      fontSize: 22,
      fontWeight: FontWeight.bold,
      textAlign: TextAlign.center,
    );
    _drawText(
      canvas,
      userName.toUpperCase(),
      x: 0,
      y: 35,
      width: width.toDouble(),
      fontSize: 32,
      fontWeight: FontWeight.w900,
      textAlign: TextAlign.center,
    );
    _drawText(
      canvas,
      'INICIO \u2193',
      x: 0,
      y: 75,
      width: width.toDouble(),
      fontSize: 32,
      fontWeight: FontWeight.w900,
      textAlign: TextAlign.center,
    );

    return _canvasToImage(recorder, width, height);
  }

  Future<img.Image> _buildFooterImage() async {
    const width = 384;
    const height = 70;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    _drawWhiteBackground(canvas, width, height);

    _drawText(
      canvas,
      '\u2191 FIN \u2191',
      x: 0,
      y: 20,
      width: width.toDouble(),
      fontSize: 32,
      fontWeight: FontWeight.w900,
      textAlign: TextAlign.center,
    );

    return _canvasToImage(recorder, width, height);
  }

  // ==============================================================
  // RECICLAJE DE GENERADORES DE IMAGEN
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

    _drawText(
      canvas,
      nombre.toUpperCase(),
      x: 10,
      y: 10,
      width: 364,
      fontSize: 30,
      fontWeight: FontWeight.w900,
      maxLines: 2,
    );
    _drawText(
      canvas,
      'PRECIO ESPECIAL',
      x: 10,
      y: 85,
      width: 230,
      fontSize: 25,
      fontWeight: FontWeight.w800,
    );
    _drawText(
      canvas,
      precio,
      x: 10,
      y: 115,
      width: 240,
      fontSize: 56,
      fontWeight: FontWeight.w900,
    );
    _drawQr(canvas, data: codigo, x: 260, y: 68, size: 112);
    _drawText(
      canvas,
      codigo,
      x: 245,
      y: 190,
      width: 140,
      fontSize: 20,
      fontWeight: FontWeight.w900,
      textAlign: TextAlign.center,
    );

    return _canvasToImage(recorder, width, height);
  }

  Future<img.Image> _buildPromoLabelImage(
    ProductPrice productPrice,
    Promocion promocion,
  ) async {
    const width = 384;
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
    } else if (mecanicaStr.isEmpty)
      mecanicaStr = 'PROMOCION';

    final fInicio = _formatDate(promocion.fechaInicio);
    final fFin = _formatDate(promocion.fechaFin);
    final codigo = productPrice.codigoBarra.trim();

    double currentY = 20;
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
    );
    currentY += 120;
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
    );
    currentY += 105;
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

    final qrSize = 130.0;
    _drawQr(
      canvas,
      data: codigo,
      x: (width - qrSize) / 2,
      y: currentY,
      size: qrSize,
    );
    currentY += qrSize + 10;
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

  void _drawWhiteBackground(Canvas canvas, int width, int height) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = Colors.white,
    );
  }

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
      errorCorrectionLevel: QrErrorCorrectLevel.L,
      gapless: false,
      color: Colors.black,
      emptyColor: Colors.white,
    );
    qrPainter.paint(canvas, Size(size, size));
    canvas.restore();
  }

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
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _cleanText(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();
}
