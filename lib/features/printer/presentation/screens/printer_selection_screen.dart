import 'package:flutter/foundation.dart' show kIsWeb; // <-- 1. Importado kIsWeb
import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/bluetooth_printer_service.dart';

class PrinterSelectionScreen extends StatefulWidget {
  const PrinterSelectionScreen({super.key});

  @override
  State<PrinterSelectionScreen> createState() => _PrinterSelectionScreenState();
}

class _PrinterSelectionScreenState extends State<PrinterSelectionScreen> {
  final BluetoothPrinterService _service = BluetoothPrinterService();

  bool _loading = true;
  String? _error;
  List<BluetoothInfo> _devices = [];

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // <-- 2. Protección para Web: no pedir permisos ni escanear
      if (kIsWeb) {
        setState(() {
          _devices = [];
        });
        return;
      }

      final bluetoothConnect = await Permission.bluetoothConnect.request();
      final bluetoothScan = await Permission.bluetoothScan.request();
      final location = await Permission.location.request();

      if (!location.isGranted) {
        throw Exception('Debes activar la ubicación para usar Bluetooth.');
      }

      if (!bluetoothConnect.isGranted || !bluetoothScan.isGranted) {
        throw Exception(
          'Debes activar el permiso de Dispositivos cercanos / Bluetooth para buscar la impresora.',
        );
      }

      final devices = await _service.getPairedDevices();

      if (!mounted) return;

      setState(() {
        _devices = devices;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _connect(BluetoothInfo device) async {
    final connected = await _service.connect(device.macAdress);

    if (!mounted) return;

    if (connected) {
      await _service.saveSelectedPrinter(
        macAddress: device.macAdress,
        name: device.name,
      );

      if (!mounted) return;

      Navigator.pop(context, device);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo conectar la impresora')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar impresora'),
        actions: [
          IconButton(onPressed: _loadDevices, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Builder(
        builder: (_) {
          if (_loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_error != null) {
            return Center(child: Text(_error!));
          }

          if (_devices.isEmpty) {
            return const Center(
              child: Text(
                'No hay impresoras emparejadas.\nPrimero vincula la impresora desde Bluetooth del teléfono.',
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView.builder(
            itemCount: _devices.length,
            itemBuilder: (context, index) {
              final device = _devices[index];

              return ListTile(
                leading: const Icon(Icons.print),
                title: Text(device.name),
                subtitle: Text(device.macAdress),
                onTap: () => _connect(device),
              );
            },
          );
        },
      ),
    );
  }
}
