import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;

// --- IMPORTS PARA LA EPSON Y PROMOCIONES ---
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/services/saldos_api_service.dart';
import '../../data/models/product_balance.dart';
import '../../../products/data/models/product_price.dart';
import '../../../products/presentation/widgets/price_label_preview.dart';
import '../../../printer/services/bluetooth_printer_service.dart';
import '../../../printer/presentation/screens/printer_selection_screen.dart';

// 🔥 IMPORTAMOS SERVICIOS DE PROMOCIONES
import '../../../promociones/models/promocion.dart';
import '../../../promociones/services/promocion_service.dart';

// 🔥 IMPORTES PARA LA EPSON EN RED Y USUARIO 🔥
import 'package:ferrotienda_flutter_proyecto/core/storage/session_storage.dart';
import 'package:ferrotienda_flutter_proyecto/features/printer/services/network_printer_service.dart';

class CenefaFlotanteDialog extends StatefulWidget {
  final ProductBalance product;

  const CenefaFlotanteDialog({super.key, required this.product});

  @override
  State<CenefaFlotanteDialog> createState() => _CenefaFlotanteDialogState();
}

class _CenefaFlotanteDialogState extends State<CenefaFlotanteDialog> {
  final SaldosApiService _service = SaldosApiService();
  final BluetoothPrinterService _printerService = BluetoothPrinterService();
  final PromocionService _promocionService = PromocionService();

  bool _isLoading = true;
  ProductPrice? _productPrice;
  Promocion? _promocionActiva;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final price = await _service.getProductPrice(widget.product.codigo);

      Promocion? promo;
      try {
        final listaPromos = await _promocionService.listar(
          codigoBarra: widget.product.codigo,
        );
        promo = listaPromos.firstWhere(
          (p) => p.activa == true,
          orElse: () => throw Exception('No promo'),
        );
      } catch (_) {
        promo = null;
      }

      if (mounted) {
        setState(() {
          _productPrice = price;
          _promocionActiva = promo;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _printCenefaBluetooth() async {
    if (_productPrice == null && _promocionActiva == null) return;

    try {
      final savedMac = await _printerService.getSavedPrinterMac();

      if (savedMac != null && savedMac.isNotEmpty) {
        final connected = await _printerService.connect(savedMac);
        if (!connected) {
          await _printerService.clearSavedPrinter();
          throw Exception(
            'No se pudo conectar a la impresora. Selecciónala nuevamente.',
          );
        }
      } else {
        final selectedPrinter = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PrinterSelectionScreen()),
        );
        if (selectedPrinter == null) return;
      }

      final printed = await _printerService.printPriceLabel(
        productPrice: _productPrice!,
      );
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            printed ? 'Cenefa enviada a térmica' : 'No se pudo imprimir',
          ),
          backgroundColor: printed ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _printCenefaEpson() async {
    if (_productPrice == null) return;

    setState(() => _isLoading = true);

    try {
      final networkPrinter = NetworkPrinterService();

      final user = await SessionStorage.getUser();
      final nombreCrudo = user?.nombreUsuario ?? 'COLABORADOR';
      final nombreUsuario = nombreCrudo.toUpperCase();

      List<Map<String, dynamic>> itemsToPrint = [
        {'productPrice': _productPrice!, 'promocion': _promocionActiva},
      ];

      await networkPrinter.printBulkLabels(itemsToPrint, nombreUsuario);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Cenefa enviada a la impresora Epson (Red)'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarOpcionesCartela() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Tamaño de Cartela',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          '¿En qué tamaño de hoja deseas imprimir esta cartela?',
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _imprimirCartelaEpson(PdfPageFormat.a5);
            },
            icon: const Icon(Icons.note_outlined),
            label: const Text('A5 (Mitad)'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _imprimirCartelaEpson(PdfPageFormat.a4);
            },
            icon: const Icon(Icons.insert_page_break_outlined),
            label: const Text('A4 (Completa)'),
          ),
        ],
      ),
    );
  }

  String _formatPdfDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  // ⭐ FUNCIÓN PINTORA DE LA ESTRELLA VECTORIAL CORREGIDA ⭐
  void _paintStar(PdfGraphics canvas, PdfPoint size) {
    final cx = size.x / 2;
    final cy = size.y / 2;
    final outerR = math.min(cx, cy) * 0.95;
    final innerR = outerR * 0.60;
    const points = 12;

    canvas.setFillColor(PdfColors.yellow);
    canvas.setStrokeColor(PdfColors.red900);
    canvas.setLineWidth(4);

    bool first = true;

    for (int i = 0; i < points * 2; i++) {
      final r = (i % 2 == 0) ? outerR : innerR;
      final angle = (i * math.pi / points) - (math.pi / 2);

      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);

      if (first) {
        canvas.moveTo(x, y);
        first = false;
      } else {
        canvas.lineTo(x, y);
      }
    }

    canvas.closePath();
    // pdf 3.13.0
    canvas.fillPath();
    canvas.strokePath();
  }

  Future<void> _imprimirCartelaEpson(PdfPageFormat format) async {
    final bool isPromo = _promocionActiva != null;

    final name = isPromo
        ? (_promocionActiva!.nombreProducto ?? widget.product.nombre)
        : (_productPrice?.nombreProducto ?? widget.product.nombre);
    final code = isPromo
        ? (_promocionActiva!.codigoBarra ?? widget.product.codigo)
        : (_productPrice?.codigoBarra ?? widget.product.codigo);
    final price = isPromo
        ? (_promocionActiva!.precioActualProm ?? 0.0)
        : (_productPrice?.precioConIva ?? 0.0);

    final oldPrice = isPromo ? (_promocionActiva!.precioAnterior ?? 0.0) : 0.0;
    final encabezado = isPromo
        ? (_promocionActiva!.encabezado ?? 'OFERTA')
        : '';
    final ahorro = isPromo ? (_promocionActiva!.ahorro ?? 0.0) : 0.0;
    final mecanica = isPromo ? (_promocionActiva!.mecanica ?? '') : '';
    final fInicio = isPromo
        ? _formatPdfDate(_promocionActiva!.fechaInicio)
        : '';
    final fFin = isPromo ? _formatPdfDate(_promocionActiva!.fechaFin) : '';

    final qrData =
        '''Producto: $name\nCódigo: $code\nPrecio venta: \$${price.toStringAsFixed(2)}\n${isPromo ? 'Mecánica: $mecanica\nVálido: $fInicio al $fFin' : ''}''';

    final doc = pw.Document();
    final bool isA4 = format == PdfPageFormat.a4;
    final pageFormat = isA4 ? PdfPageFormat.a4.landscape : PdfPageFormat.a5;

    // --- BLOQUE DINÁMICO DE TÍTULO ---
    pw.Widget buildHeaderBlock(bool isA4Size) {
      if (isPromo) {
        return pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.FittedBox(
              fit: pw.BoxFit.scaleDown,
              child: pw.Text(
                encabezado.toUpperCase(),
                style: pw.TextStyle(
                  color: PdfColors.red,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: isA4Size ? 60 : 50,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.FittedBox(
              fit: pw.BoxFit.scaleDown,
              child: pw.Text(
                name.toUpperCase(),
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  color: PdfColors.blue900,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: isA4Size ? 45 : 35,
                ),
              ),
            ),
          ],
        );
      } else {
        return pw.FittedBox(
          fit: pw.BoxFit.scaleDown,
          child: pw.Text(
            name.toUpperCase(),
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              color: PdfColors.blue900,
              fontWeight: pw.FontWeight.bold,
              fontSize: isA4Size ? 65 : 60,
            ),
          ),
        );
      }
    }

    // --- BLOQUE DINÁMICO DE PRECIOS CON ESTRELLA DE FONDO EN PROMO ---
    pw.Widget buildPriceBlock(bool isA4Size) {
      if (isPromo) {
        return pw.Stack(
          alignment: pw.Alignment.center,
          children: [
            // ⭐ ESTRELLA VECTORIAL DE FONDO EN OFERTA ⭐
            pw.Center(
              child: pw.AspectRatio(
                aspectRatio: 1.2,
                child: pw.CustomPaint(painter: _paintStar),
              ),
            ),
            // CONTENIDO DE PRECIOS SUPERPUESTO
            pw.Padding(
              padding: const pw.EdgeInsets.all(12),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.FittedBox(
                    fit: pw.BoxFit.scaleDown,
                    child: pw.Text(
                      'ANTERIOR: \$${oldPrice.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        color: PdfColors.grey800,
                        decoration: pw.TextDecoration.lineThrough,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: isA4Size ? 22 : 18,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.FittedBox(
                    fit: pw.BoxFit.scaleDown,
                    child: pw.Text(
                      '\$${price.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        color: PdfColors.black,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: isA4Size ? 85 : 65,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.FittedBox(
                    fit: pw.BoxFit.scaleDown,
                    child: pw.Text(
                      '¡AHORRA \$${ahorro.toStringAsFixed(2)}!',
                      style: pw.TextStyle(
                        color: PdfColors.green900,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: isA4Size ? 24 : 18,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.FittedBox(
                    fit: pw.BoxFit.scaleDown,
                    child: pw.Text(
                      mecanica.toUpperCase(),
                      style: pw.TextStyle(
                        color: PdfColors.red900,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: isA4Size ? 20 : 16,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.FittedBox(
                    fit: pw.BoxFit.scaleDown,
                    child: pw.Text(
                      'VÁLIDO: $fInicio AL $fFin',
                      style: pw.TextStyle(
                        color: PdfColors.grey900,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: isA4Size ? 16 : 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      } else {
        return pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.FittedBox(
              fit: pw.BoxFit.scaleDown,
              child: pw.Text(
                'PRECIO ESPECIAL',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: isA4Size ? 45 : 40,
                ),
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Expanded(
              child: pw.FittedBox(
                fit: pw.BoxFit.contain,
                child: pw.Text(
                  '\$${price.toStringAsFixed(2)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ),
            ),
          ],
        );
      }
    }

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          if (isA4) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(30),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Expanded(
                    flex: isPromo ? 35 : 30,
                    child: pw.Align(
                      alignment: pw.Alignment.topCenter,
                      child: buildHeaderBlock(true),
                    ),
                  ),
                  pw.Expanded(
                    flex: isPromo ? 65 : 70,
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Expanded(flex: 65, child: buildPriceBlock(true)),
                        pw.SizedBox(width: 40),
                        pw.Expanded(
                          flex: 35,
                          child: pw.Column(
                            mainAxisAlignment: pw.MainAxisAlignment.end,
                            children: [
                              pw.Expanded(
                                child: pw.Center(
                                  child: pw.AspectRatio(
                                    aspectRatio: 1,
                                    child: pw.BarcodeWidget(
                                      barcode: pw.Barcode.qrCode(),
                                      data: qrData,
                                      drawText: false,
                                    ),
                                  ),
                                ),
                              ),
                              pw.SizedBox(height: 15),
                              pw.FittedBox(
                                fit: pw.BoxFit.scaleDown,
                                child: pw.Text(
                                  code,
                                  style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 45,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          } else {
            return pw.Container(
              width: double.infinity,
              height: double.infinity,
              child: pw.Column(
                children: [
                  pw.Expanded(
                    flex: 1,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(15),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                        children: [
                          pw.Expanded(
                            flex: isPromo ? 40 : 35,
                            child: pw.Align(
                              alignment: pw.Alignment.center,
                              child: buildHeaderBlock(false),
                            ),
                          ),
                          pw.Expanded(
                            flex: isPromo ? 60 : 65,
                            child: pw.Row(
                              crossAxisAlignment: pw.CrossAxisAlignment.end,
                              children: [
                                pw.Expanded(
                                  flex: 65,
                                  child: buildPriceBlock(false),
                                ),
                                pw.SizedBox(width: 25),
                                pw.Expanded(
                                  flex: 35,
                                  child: pw.Column(
                                    mainAxisAlignment: pw.MainAxisAlignment.end,
                                    children: [
                                      pw.Expanded(
                                        child: pw.Center(
                                          child: pw.AspectRatio(
                                            aspectRatio: 1,
                                            child: pw.BarcodeWidget(
                                              barcode: pw.Barcode.qrCode(),
                                              data: qrData,
                                              drawText: false,
                                            ),
                                          ),
                                        ),
                                      ),
                                      pw.SizedBox(height: 10),
                                      pw.FittedBox(
                                        fit: pw.BoxFit.scaleDown,
                                        child: pw.Text(
                                          code,
                                          style: pw.TextStyle(
                                            fontWeight: pw.FontWeight.bold,
                                            fontSize: 35,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  pw.Expanded(flex: 1, child: pw.SizedBox()),
                ],
              ),
            );
          }
        },
      ),
    );

    try {
      if (kIsWeb ||
          defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat f) async => doc.save(),
          name: 'Cartela_Ferrotienda',
        );
      } else {
        final printers = await Printing.listPrinters();
        Printer? targetPrinter;
        try {
          targetPrinter = printers.firstWhere(
            (p) => p.name.contains("AnyDesk v4 Printer Driver"),
          );
        } catch (e) {
          targetPrinter = null;
        }

        if (targetPrinter != null) {
          await Printing.directPrintPdf(
            printer: targetPrinter,
            onLayout: (PdfPageFormat f) async => doc.save(),
            usePrinterSettings: true,
          );
        } else {
          await Printing.layoutPdf(
            onLayout: (PdfPageFormat f) async => doc.save(),
            usePrinterSettings: true,
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al procesar cartela: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        width: MediaQuery.of(context).size.width * 0.9,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Vista previa de etiqueta",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : Flexible(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: PriceLabelPreview(
                        productPrice: _productPrice,
                        promocion: _promocionActiva,
                        fallbackName: widget.product.nombre,
                        fallbackCode: widget.product.codigo,
                      ),
                    ),
                  ),
            const SizedBox(height: 16),
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed:
                            (_productPrice == null && _promocionActiva == null)
                            ? null
                            : _printCenefaBluetooth,
                        icon: const Icon(Icons.bluetooth, size: 18),
                        label: const Text(
                          'Cenefa BT',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed:
                            (_productPrice == null && _promocionActiva == null)
                            ? null
                            : _printCenefaEpson,
                        icon: const Icon(Icons.wifi, size: 18),
                        label: const Text(
                          'Cenefa Epson',
                          style: TextStyle(fontSize: 13),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.deepPurple.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed:
                        (_productPrice == null && _promocionActiva == null)
                        ? null
                        : _mostrarOpcionesCartela,
                    icon: const Icon(Icons.print, size: 18),
                    label: const Text(
                      'Imprimir Cartela (Papel A4/A5)',
                      style: TextStyle(fontSize: 13),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.indigo.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
