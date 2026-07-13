import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

/// Results for biometric authentication attempts.
enum BiometricResult {
  /// Authentication was successful.
  success,
  /// User cancelled the biometric prompt.
  cancelled,
  /// Biometrics are not enrolled on the device.
  notEnrolled,
  /// Biometrics are not supported on this device.
  notSupported,
  /// Too many failed attempts; biometrics are temporarily or permanently locked.
  lockedOut,
  /// An unexpected error occurred.
  failure,
}

class BiometricHelper {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Checks if the device is capable of biometric checks.
  static Future<bool> canCheckBiometrics() async {
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } catch (e) {
      debugPrint('Error checking biometrics capability: $e');
      return false;
    }
  }

  /// Returns a list of available biometric types (fingerprint, face, etc.).
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('Error getting available biometrics: $e');
      return [];
    }
  }

  /// Prompts the user for biometric authentication.
  /// Returns a [BiometricResult] indicating the outcome.
  static Future<BiometricResult> authenticate() async {
    try {
      final bool isDeviceSupported = await _auth.isDeviceSupported();
      final bool canCheckBiometrics = await _auth.canCheckBiometrics;
      final List<BiometricType> availableBiometrics = await _auth.getAvailableBiometrics();
      
      if (!isDeviceSupported && !canCheckBiometrics && availableBiometrics.isEmpty) {
        return BiometricResult.notSupported;
      }

      if (availableBiometrics.isEmpty) {
        return BiometricResult.notEnrolled;
      }

      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'Please authenticate to log in',
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'Chess App Login',
            biometricHint: 'Verify your identity',
            cancelButton: 'Use Password',
          ),
          IOSAuthMessages(
            cancelButton: 'Use Password',
          ),
        ],
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allows fallback to PIN/Pattern if configured
        ),
      );

      return didAuthenticate ? BiometricResult.success : BiometricResult.cancelled;
    } on PlatformException catch (e) {
      debugPrint('PlatformException during biometric auth: ${e.code} - ${e.message}');
      if (e.code == 'NotEnrolled') return BiometricResult.notEnrolled;
      if (e.code == 'LockedOut' || e.code == 'PermanentlyLockedOut') {
        return BiometricResult.lockedOut;
      }
      return BiometricResult.failure;
    } catch (e) {
      debugPrint('Unexpected error during biometric auth: $e');
      return BiometricResult.failure;
    }
  }
}
