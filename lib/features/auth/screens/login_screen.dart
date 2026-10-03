import 'package:flutter/material.dart';

import '../../../core/storage/session_storage.dart';
import '../../saldos/presentation/screens/product_search_screen.dart';
import '../../scanner/screens/scanner_price_screen.dart';
import '../models/auth_user.dart';
import '../services/auth_service.dart';
import '../services/biometric_auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService authService = AuthService();

  final TextEditingController usuarioController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;
  bool ocultarPassword = true;
  bool biometricAvailable = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _cargarEstadoBiometria();
  }

  Future<void> _cargarEstadoBiometria() async {
    final available = await BiometricAuthService.isAvailable();
    if (!mounted) return;
    setState(() {
      biometricAvailable = available;
    });
  }

  void _goToHome(AuthUser user) {
    if (user.rol.toUpperCase() == 'ESCANER') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ScannerPriceScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ProductSearchScreen()),
      );
    }
  }

  Future<void> login() async {
    final usuario = usuarioController.text.trim();
    final password = passwordController.text.trim();

    if (usuario.isEmpty || password.isEmpty) {
      setState(() {
        errorMessage = "Ingresa usuario y contraseña";
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    AuthUser? user;

    try {
      user = await authService.login(
        nombreUsuario: usuario,
        password: password,
      );

      await SessionStorage.saveUser(user);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = "Usuario o contraseña incorrectos";
        isLoading = false;
      });
      return;
    }

    if (!mounted) return;

    // Si la biometría está disponible en el hardware, ofrecemos activarla tras el login
    if (biometricAvailable) {
      final activar = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Activar ingreso con huella'),
            content: const Text(
              '¿Deseas activar el ingreso rápido con huella dactilar para esta cuenta?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Ahora no'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Activar'),
              ),
            ],
          );
        },
      );

      if (activar == true) {
        try {
          final authenticated = await BiometricAuthService.authenticate();
          if (authenticated) {
            await BiometricAuthService.enableBiometricLogin(
              userData: user.toJson(),
            );
          }
        } catch (e) {
          debugPrint('Error activando biometría: $e');
        }
      }
    }

    if (!mounted) return;
    setState(() {
      isLoading = false;
    });

    _goToHome(user);
  }

  @override
  void dispose() {
    usuarioController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1F6F8B);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Cabecera curva corporativa
            Container(
              width: double.infinity,
              height: MediaQuery.of(context).size.height * 0.35,
              decoration: const BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(50),
                  bottomRight: Radius.circular(50),
                ),
              ),
              child: SafeArea(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
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
                        child: Image.asset(
                          'assets/images/wyner_logo.png',
                          height: 80,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) {
                            return const Icon(
                              Icons.storefront,
                              size: 64,
                              color: primaryColor,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "WYNER",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Tarjeta de Login desplazada hacia arriba
            Transform.translate(
              offset: const Offset(0, -30),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Card(
                    elevation: 8,
                    shadowColor: Colors.black12,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "Loggin",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 32),

                          TextField(
                            controller: usuarioController,
                            decoration: InputDecoration(
                              labelText: "Nombre de usuario",
                              prefixIcon: const Icon(
                                Icons.person_outline,
                                color: primaryColor,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: primaryColor,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          TextField(
                            controller: passwordController,
                            obscureText: ocultarPassword,
                            decoration: InputDecoration(
                              labelText: "Contraseña",
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                color: primaryColor,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: primaryColor,
                                  width: 2,
                                ),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  ocultarPassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  setState(() {
                                    ocultarPassword = !ocultarPassword;
                                  });
                                },
                              ),
                            ),
                            onSubmitted: (_) => login(),
                          ),

                          if (errorMessage != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      errorMessage!,
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 28),

                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              onPressed: isLoading ? null : login,
                              child: isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      "Ingresar",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
