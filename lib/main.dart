import 'package:ferrotienda_flutter_proyecto/features/pedidos/widgets/generar_pedido_proveedor_dialog.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import 'core/storage/session_storage.dart';
import 'features/auth/models/auth_user.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/services/biometric_auth_service.dart';
import 'features/saldos/presentation/screens/product_search_screen.dart';
import 'features/saldos/presentation/screens/product_search_controller.dart';
import 'features/scanner/screens/scanner_price_screen.dart';

// 🔥 NUEVOS IMPORTS PARA LA REDIRECCIÓN DE NOTIFICACIONES 🔥
import 'features/pedidos/screens/pedido_busqueda_screen.dart';
import 'features/cronograma/presentation/screens/notificaciones_screen.dart';

// 🔥 NUEVO IMPORT DEL PROVIDER DE FAVORITOS 🔥
import 'package:ferrotienda_flutter_proyecto/features/favoritos/providers/favorites_provider.dart';

// ==========================================================
// 🔥 1. CREAMOS EL NAVEGADOR GLOBAL (Fuera de las clases) 🔥
// ==========================================================
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ==========================================================
  // 🔥 2. INICIALIZACIÓN DE ONESIGNAL Y DEEP LINKING 🔥
  // ==========================================================
  if (!kIsWeb) {
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    OneSignal.initialize("f4a9679d-f7e7-47bf-8ad4-c633fa0a439d");
    OneSignal.Notifications.requestPermission(true);

    OneSignal.Notifications.addClickListener((event) {
      final data = event.notification.additionalData;

      if (data != null) {
        final String accion = data['accion'] ?? '';

        // 1. Lógica antigua: Abrir el diálogo del pedido (Borradores/Admin)
        if ((accion == 'APROBAR_PEDIDO' || accion == '') &&
            data.containsKey('pedido_id')) {
          final int pedidoId = data['pedido_id'];
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => GenerarPedidoProveedorDialog(pedidoId: pedidoId),
            ),
          );
        }
        // 2. 🔥 NUEVA LÓGICA: Redirigir a hacer pedido con el proveedor cargado 🔥
        else if (accion == 'HACER_PEDIDO' && data.containsKey('proveedor')) {
          final String proveedor = data['proveedor'];
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => PedidoBusquedaScreen(proveedorInicial: proveedor),
            ),
          );
        }
        // 3. 🔥 LÓGICA SECUNDARIA: Redirigir a la pantalla de Mis Alertas 🔥
        else if (accion == 'VER_NOTIFICACIONES') {
          navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (_) => const NotificacionesScreen()),
          );
        }
      }
    });
  }
  // ==========================================================

  await _requestInitialPermissions();

  bool isBiometricEnabled = await BiometricAuthService.isEnabled();
  AuthUser? user = await SessionStorage.getUser();

  if (user == null && isBiometricEnabled) {
    final savedData = await BiometricAuthService.getSavedUserData();
    if (savedData != null) {
      user = AuthUser.fromJson(savedData);
      await SessionStorage.saveUser(user);
    } else {
      isBiometricEnabled = false;
    }
  }

  // ==========================================================
  // 🔥 3. ETIQUETAMOS EL CELULAR CON EL NOMBRE DEL USUARIO 🔥
  // ==========================================================
  if (!kIsWeb && user != null) {
    OneSignal.login(user.nombreUsuario);
  }

  runApp(FerrotiendaApp(user: user, isBiometricEnabled: isBiometricEnabled));
}

Future<void> _requestInitialPermissions() async {
  if (kIsWeb) {
    debugPrint("Ejecutando en Web: Saltando petición de permisos nativos.");
    return;
  }

  await [
    Permission.camera,
    Permission.bluetoothConnect,
    Permission.bluetoothScan,
    Permission.location,
  ].request();
}

class FerrotiendaApp extends StatefulWidget {
  final AuthUser? user;
  final bool isBiometricEnabled;

  const FerrotiendaApp({
    super.key,
    required this.user,
    required this.isBiometricEnabled,
  });

  @override
  State<FerrotiendaApp> createState() => _FerrotiendaAppState();
}

class _FerrotiendaAppState extends State<FerrotiendaApp>
    with WidgetsBindingObserver {
  late bool _isLocked;
  bool _isAuthenticating = false;

  DateTime? _pausedTime;
  final Duration _lockTimeout = const Duration(minutes: 2);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isLocked = widget.isBiometricEnabled && widget.user != null;

    if (_isLocked) {
      _promptBiometric();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (widget.isBiometricEnabled && !_isLocked) {
        _pausedTime = DateTime.now();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (widget.isBiometricEnabled && !_isLocked && _pausedTime != null) {
        final inactivityDuration = DateTime.now().difference(_pausedTime!);

        if (inactivityDuration > _lockTimeout) {
          setState(() => _isLocked = true);
        }

        _pausedTime = null;
      }

      if (_isLocked) {
        _promptBiometric();
      }
    }
  }

  Future<void> _promptBiometric() async {
    if (_isAuthenticating || kIsWeb) return;

    _isAuthenticating = true;
    final authenticated = await BiometricAuthService.authenticate();
    _isAuthenticating = false;

    if (authenticated && mounted) {
      setState(() => _isLocked = false);
    }
  }

  Widget _buildHome(AuthUser user) {
    if (user.rol.toUpperCase() == 'ESCANER') {
      return const ScannerPriceScreen();
    }
    return const ProductSearchScreen();
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 CORRECCIÓN: Usamos MultiProvider para soportar varios controladores globales 🔥
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ProductSearchController()..loadInitialData(),
        ),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'Ferrotienda',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1F6F8B)),
          useMaterial3: true,
        ),
        home: _isLocked
            ? AppLockScreen(onUnlockTap: _promptBiometric)
            : (widget.user == null
                  ? const LoginScreen()
                  : _buildHome(widget.user!)),
      ),
    );
  }
}

class AppLockScreen extends StatelessWidget {
  final VoidCallback onUnlockTap;

  const AppLockScreen({super.key, required this.onUnlockTap});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock_person_rounded,
              size: 80,
              color: Color(0xFF1F6F8B),
            ),
            const SizedBox(height: 24),
            const Text(
              'Aplicación Bloqueada',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F6F8B),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Desbloquea para continuar trabajando',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 40),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: onUnlockTap,
              icon: const Icon(Icons.fingerprint, size: 28),
              label: const Text('Desbloquear', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () async {
                await BiometricAuthService.disableBiometricLogin();
                await SessionStorage.clear();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
              child: const Text(
                "Ingresar con contraseña",
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
