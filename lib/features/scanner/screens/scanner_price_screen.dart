import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

import '../../../core/storage/session_storage.dart';
import '../../../features/auth/screens/login_screen.dart';
import '../services/scanner_service.dart';

class ScannerPriceScreen extends StatefulWidget {
  const ScannerPriceScreen({super.key});

  @override
  State<ScannerPriceScreen> createState() => _ScannerPriceScreenState();
}

class _ScannerPriceScreenState extends State<ScannerPriceScreen> {
  static const Color primaryColor = Color(0xFF1F6F8B);

  final ScannerService _scannerService = ScannerService();

  // 🔥 CORRECCIÓN FINAL: CÁMARA FRONTAL POR DEFECTO
  final MobileScannerController _cameraController = MobileScannerController(
    facing: CameraFacing.front,
  );

  final AudioPlayer _audioPlayer = AudioPlayer();

  // 🔥 CONFIGURACIÓN DE PUBLICIDAD
  final String _apiUrlPublicidad = 'http://192.168.1.231:5000/api/publicidad';
  List<Map<String, dynamic>> _anuncios = [];
  int _currentAdIndex = 0;

  VideoPlayerController? _videoController;
  Timer? _imageTimer;

  // 🔥 TEMPORIZADOR PARA LIMPIAR PANTALLA EN 4 SEGUNDOS
  Timer? _clearTimer;

  bool _isProcessing = false;
  String? _codigo;
  String? _nombreProducto;
  double? _precioFinal;
  String? _errorMessage;
  String? _mensajePromocion;

  Timer? _idleTimer;
  bool _isSleeping = false;
  final int _inactivitySeconds = 30;

  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'es_EC',
    symbol: '\$',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _audioPlayer.setSource(AssetSource('sounds/beep.mp3'));
    _cargarPublicidadBackend();
    _resetIdleTimer();
  }

  // --- LÓGICA DE SEGURIDAD (PIN) ---
  Future<void> _solicitarPinSeguridad(VoidCallback onAccesoConcedido) async {
    final TextEditingController pinController = TextEditingController();
    bool pinIncorrecto = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text(
                'Acceso Restringido',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Ingrese el PIN de administrador para continuar:'),
                  const SizedBox(height: 15),
                  TextField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    autofocus: true,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: 'PIN',
                      errorText: pinIncorrecto ? 'Contraseña incorrecta' : null,
                      prefixIcon: const Icon(Icons.lock_outline),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: primaryColor),
                  onPressed: () {
                    if (pinController.text == '1234') {
                      Navigator.pop(context);
                      onAccesoConcedido();
                    } else {
                      setState(() => pinIncorrecto = true);
                    }
                  },
                  child: const Text('Autorizar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- LÓGICA DE PUBLICIDAD ---
  Future<void> _cargarPublicidadBackend() async {
    try {
      final response = await http
          .get(Uri.parse(_apiUrlPublicidad))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _anuncios = data
                .where((ad) => ad['activo'] == true || ad['activo'] == 'True')
                .cast<Map<String, dynamic>>()
                .toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Error cargando publicidad: $e');
    }
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    _clearTimer?.cancel();
    _detenerPublicidad();

    if (_isSleeping) {
      setState(() => _isSleeping = false);
    }

    _idleTimer = Timer(Duration(seconds: _inactivitySeconds), () {
      if (mounted) {
        setState(() {
          _isSleeping = true;
          _codigo = null;
          _nombreProducto = null;
          _precioFinal = null;
          _mensajePromocion = null;
          _errorMessage = null;
          _currentAdIndex = 0;
        });
        _reproducirAnuncioActual();
      }
    });
  }

  Future<void> _reproducirAnuncioActual() async {
    if (_anuncios.isEmpty || !_isSleeping || !mounted) return;

    final anuncio = _anuncios[_currentAdIndex];
    final esVideo = anuncio['tipo'] == 'video';
    final url = anuncio['url_archivo'];

    if (esVideo) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
      await _videoController!.initialize();
      await _videoController!.setVolume(1.0);

      if (!mounted || !_isSleeping) return;

      setState(() {});
      _videoController!.play();

      _videoController!.addListener(() {
        if (_videoController!.value.position >=
            _videoController!.value.duration) {
          _videoController!.removeListener(() {});
          _avanzarSiguienteAnuncio();
        }
      });
    } else {
      setState(() {});
      _imageTimer = Timer(const Duration(seconds: 7), _avanzarSiguienteAnuncio);
    }
  }

  void _avanzarSiguienteAnuncio() {
    if (!mounted || !_isSleeping) return;

    _detenerPublicidad();
    setState(() {
      _currentAdIndex = (_currentAdIndex + 1) % _anuncios.length;
    });
    _reproducirAnuncioActual();
  }

  void _detenerPublicidad() {
    _imageTimer?.cancel();
    if (_videoController != null) {
      _videoController!.pause();
      _videoController!.dispose();
      _videoController = null;
    }
  }

  // --- LÓGICA DE PROMOCIONES ---
  Future<void> _verificarPromocion(String codigo) async {
    try {
      final url = Uri.parse(
        'http://192.168.1.231:5000/api/promociones/verificar/$codigo',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data['tiene_promocion'] == true) {
          if (mounted) {
            setState(() {
              _mensajePromocion = data['descripcion'];
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error verificando promoción: $e');
    }
  }

  // --- ESCANEO ---
  Future<void> _onDetect(BarcodeCapture capture) async {
    _resetIdleTimer();
    if (_isProcessing) return;

    final barcode = capture.barcodes.firstOrNull;
    final code = barcode?.rawValue;

    if (code == null || code.trim().isEmpty) return;
    if (code.trim() == _codigo && _precioFinal != null) return;

    _clearTimer?.cancel();
    HapticFeedback.vibrate();

    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sounds/beep.mp3'));
    } catch (e) {
      debugPrint('Error de audio: $e');
    }

    setState(() {
      _isProcessing = true;
      _codigo = code.trim();
      _errorMessage = null;
      _mensajePromocion = null;
      _nombreProducto = null;
      _precioFinal = null;
    });

    try {
      _verificarPromocion(code.trim());
      final producto = await _scannerService.buscarProductoPorCodigo(
        code.trim(),
      );

      if (!mounted) return;
      setState(() {
        _nombreProducto = producto.nombreProducto;
        _precioFinal = producto.precioConIva;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _nombreProducto = null;
        _precioFinal = null;
        _errorMessage = 'Producto no encontrado';
      });
    } finally {
      if (mounted) setState(() => _isProcessing = false);

      _clearTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() {
            _codigo = null;
            _nombreProducto = null;
            _precioFinal = null;
            _mensajePromocion = null;
            _errorMessage = null;
          });
        }
      });
    }
  }

  Future<void> _logout() async {
    _idleTimer?.cancel();
    _clearTimer?.cancel();
    _detenerPublicidad();
    await SessionStorage.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _clearTimer?.cancel();
    _detenerPublicidad();
    _cameraController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    final double holeWidth = 340;
    final double holeHeight = 180;
    final double topOffset = screenSize.height * 0.22;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _isSleeping
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
              title: const Text(
                'VERIFICADOR DE PRECIOS',
                style: TextStyle(
                  fontFamily: 'Impact',
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      offset: Offset(2, 2),
                      blurRadius: 8.0,
                      color: Colors.black,
                    ),
                  ],
                ),
              ),
              iconTheme: const IconThemeData(color: Colors.white),
              actions: [
                GestureDetector(
                  onDoubleTap: () {
                    _solicitarPinSeguridad(() async {
                      _resetIdleTimer();
                      try {
                        await _cameraController.switchCamera();
                      } catch (e) {}
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.cameraswitch_outlined,
                      size: 28,
                      color: Colors.white,
                    ),
                  ),
                ),
                GestureDetector(
                  onDoubleTap: () {
                    _solicitarPinSeguridad(() => _logout());
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.logout,
                      size: 28,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. CÁMARA SIEMPRE AL FONDO
          MobileScanner(controller: _cameraController, onDetect: _onDetect),

          // 2. PUBLICIDAD CON 98% DE OPACIDAD
          if (_isSleeping)
            Opacity(opacity: 0.98, child: _buildDigitalSignage()),

          // 3. CAPA INTERACTIVA (EFECTO VISOR Y RESULTADOS)
          if (!_isSleeping) ...[
            if (_codigo != null)
              ClipPath(
                clipper: ScannerHoleClipper(
                  width: holeWidth,
                  height: holeHeight,
                  topOffset: topOffset,
                ),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                  child: Container(color: Colors.black.withOpacity(0.15)),
                ),
              ),

            // Marco del Visor
            Positioned(
              top: topOffset,
              left: (screenSize.width - holeWidth) / 2,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: holeWidth,
                height: holeHeight,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _codigo != null ? Colors.white : Colors.white54,
                    width: _codigo != null ? 4 : 2,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),

            // Información del Producto
            if (_codigo != null)
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: _buildInfoPanel(),
                    ),
                  ),
                ),
              ),
          ],

          // 4. DESPERTAR KIOSCO MANUALMENTE
          if (_isSleeping)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _resetIdleTimer,
              onPanDown: (_) => _resetIdleTimer(),
              child: Container(color: Colors.transparent),
            ),
        ],
      ),
    );
  }

  // --- PANEL DE RESULTADOS FLOTANTE ---
  Widget _buildInfoPanel() {
    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isProcessing)
              const CircularProgressIndicator(color: primaryColor)
            else if (_errorMessage != null) ...[
              const Icon(Icons.error_outline, size: 40, color: Colors.red),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ] else ...[
              Text(
                _currencyFormatter.format(_precioFinal ?? 0),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 6),

              if (_mensajePromocion != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade400, width: 2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.local_offer,
                        color: Colors.orange.shade800,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _mensajePromocion!,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),

              Text(
                _nombreProducto ?? '',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),

              Text(
                _codigo ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- DIGITAL SIGNAGE UI ---
  Widget _buildDigitalSignage() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: _anuncios.isEmpty ? _buildFallbackAd() : _buildAdContent(),
    );
  }

  Widget _buildAdContent() {
    final anuncio = _anuncios[_currentAdIndex];
    final esVideo = anuncio['tipo'] == 'video';

    return Stack(
      fit: StackFit.expand,
      children: [
        if (esVideo &&
            _videoController != null &&
            _videoController!.value.isInitialized)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _videoController!.value.size.width,
              height: _videoController!.value.size.height,
              child: VideoPlayer(_videoController!),
            ),
          )
        else if (!esVideo)
          Image.network(
            anuncio['url_archivo'],
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallbackAd(),
          )
        else
          const Center(child: CircularProgressIndicator(color: Colors.white)),

        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: Colors.white24, width: 2),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.qr_code_scanner, color: Colors.white, size: 45),
                  SizedBox(width: 20),
                  Text(
                    'PASE EL PRODUCTO PARA VER EL PRECIO',
                    style: TextStyle(
                      fontSize: 28,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFallbackAd() {
    return Container(
      color: primaryColor,
      alignment: Alignment.center,
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/wyner_logo.png', height: 100),
            const SizedBox(height: 20),
            const Text(
              '¡Bienvenidos a Ferrotienda!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 30),
            const Icon(Icons.qr_code_scanner, color: Colors.white, size: 70),
            const SizedBox(height: 15),
            const Text(
              'PASE EL PRODUCTO PARA VER EL PRECIO',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 🔥 RECORTE TRANSPARENTE EN EL CENTRO
class ScannerHoleClipper extends CustomClipper<Path> {
  final double width;
  final double height;
  final double topOffset;

  ScannerHoleClipper({
    required this.width,
    required this.height,
    required this.topOffset,
  });

  @override
  Path getClip(Size size) {
    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    path.addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH((size.width - width) / 2, topOffset, width, height),
        const Radius.circular(16),
      ),
    );
    path.fillType = PathFillType.evenOdd;
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;
}
