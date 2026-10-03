import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  bool _detected = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear código')),
      body: MobileScanner(
        onDetect: (capture) {
          if (_detected) return;
          final barcode = capture.barcodes.firstOrNull;
          final code = barcode?.rawValue;
          if (code == null || code.isEmpty) return;

          _detected = true;
          Navigator.pop(context, code);
        },
      ),
    );
  }
}
