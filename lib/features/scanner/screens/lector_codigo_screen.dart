import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class LectorCodigoScreen extends StatefulWidget {
  const LectorCodigoScreen({super.key});

  @override
  State<LectorCodigoScreen> createState() => _LectorCodigoScreenState();
}

class _LectorCodigoScreenState extends State<LectorCodigoScreen> {
  // Controlador para manejar el ciclo de vida de la cámara
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _isScanned = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear Código'),
        backgroundColor: const Color(0xFF1F6F8B),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _scannerController,
              builder: (context, state, child) {
                switch (state.torchState) {
                  case TorchState.on:
                    return const Icon(Icons.flash_on, color: Colors.yellow);
                  case TorchState.auto:
                    return const Icon(Icons.flash_auto, color: Colors.yellow);
                  case TorchState.off:
                  case TorchState.unavailable:
                  default:
                    return const Icon(Icons.flash_off, color: Colors.grey);
                }
              },
            ),
            iconSize: 28,
            onPressed: () => _scannerController.toggleTorch(),
          ),
        ],
      ),
      body: MobileScanner(
        controller: _scannerController,
        onDetect: (BarcodeCapture capture) {
          if (_isScanned) return; // Evita lecturas múltiples

          final List<Barcode> barcodes = capture.barcodes;
          if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
            _isScanned = true;
            final String codigo = barcodes.first.rawValue!;

            // Cierra la cámara antes de regresar
            _scannerController.stop();

            // Retorna el código a la pantalla anterior
            Navigator.pop(context, codigo);
          }
        },
      ),
    );
  }
}
