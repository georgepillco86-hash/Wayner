import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerScreen extends StatefulWidget {
  final Function(String) onDetect;

  const ScannerScreen({
    Key? key,
    required this.onDetect,
  }) : super(key: key);

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  bool _isScanned = false; // 👈 evita múltiples lecturas

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Escanear código"),
      ),
      body: MobileScanner(
        onDetect: (capture) {
          if (_isScanned) return;

          final List<Barcode> barcodes = capture.barcodes;

          for (final barcode in barcodes) {
            final String? code = barcode.rawValue;

            if (code != null) {
              _isScanned = true;

              widget.onDetect(code);

              Navigator.pop(context);
              break;
            }
          }
        },
      ),
    );
  }
}