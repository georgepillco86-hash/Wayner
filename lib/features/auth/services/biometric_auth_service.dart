import 'dart:convert';
import 'package:flutter/foundation.dart'
    show kIsWeb; // <-- 1. Importación para detectar Web
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class BiometricAuthService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _enabledKey = 'biometric_enabled';
  static const String _userDataKey = 'biometric_user_data';

  static Future<bool> isAvailable() async {
    // <-- 2. Protección Web: Retorna falso inmediatamente si estamos en el navegador
    if (kIsWeb) return false;

    try {
      final canCheckBiometrics = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();

      return canCheckBiometrics && isDeviceSupported;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> isEnabled() async {
    final value = await _storage.read(key: _enabledKey);
    return value == 'true';
  }

  static Future<bool> authenticate() async {
    // <-- 3. Protección Web: Evita ejecutar la interfaz nativa de huella/rostro
    if (kIsWeb) return false;

    try {
      final available = await isAvailable();

      if (!available) return false;

      return await _auth.authenticate(
        localizedReason:
            'Confirma tu identidad para activar el ingreso con huella',
      );
    } on PlatformException catch (e) {
      debugPrint('Error biométrico: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Error inesperado biométrico: $e');
      return false;
    }
  }

  static Future<void> enableBiometricLogin({
    required Map<String, dynamic> userData,
  }) async {
    await _storage.write(key: _enabledKey, value: 'true');
    await _storage.write(key: _userDataKey, value: jsonEncode(userData));
  }

  static Future<Map<String, dynamic>?> getSavedUserData() async {
    final rawData = await _storage.read(key: _userDataKey);

    if (rawData == null || rawData.isEmpty) return null;

    return jsonDecode(rawData) as Map<String, dynamic>;
  }

  static Future<void> disableBiometricLogin() async {
    await _storage.delete(key: _enabledKey);
    await _storage.delete(key: _userDataKey);
  }
}
