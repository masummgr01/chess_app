import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Represents the possible outcomes of authentication operations.
enum AuthResult {
  /// Operation completed successfully.
  success,
  /// Invalid username or password provided.
  invalidCredentials,
  /// No refresh token available in storage.
  noRefreshToken,
  /// Refresh token is expired or revoked.
  sessionExpired,
  /// Unable to reach the server.
  networkError,
  /// The operation was cancelled.
  cancelled,
  /// An unknown error occurred.
  failure,
}

class AuthService {
  /// The base URL for the API, configured via --dart-define.
  /// Defaults to localhost/LAN IP if not provided.
  static String get baseUrl {
    const String defineUrl = String.fromEnvironment('API_BASE_URL');
    if (defineUrl.isNotEmpty) return defineUrl;
    
    if (kReleaseMode) {
      return 'https://api.example.com/api'; // Production default
    }
    
    // Check platform in a web-safe way. Platform.isAndroid crashes on Web.
    if (!kIsWeb && Platform.isAndroid) {
      // Use 10.0.2.2 for Android emulator to reach host's localhost
      return 'http://10.0.2.2:8000/api';
    }
    return 'http://localhost:8000/api';
  }

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  /// Performs a login with [username] and [password].
  /// Returns [AuthResult.success] on success, or an appropriate error result.
  Future<AuthResult> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/token/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final access = data['access'] as String?;
        final refresh = data['refresh'] as String?;

        if (access != null && refresh != null) {
          await _storage.write(key: 'access_token', value: access);
          await _storage.write(key: 'refresh_token', value: refresh);
          await _storage.write(key: 'username', value: username);
          return AuthResult.success;
        }
      } else if (response.statusCode == 401) {
        return AuthResult.invalidCredentials;
      }
      debugPrint('Login failed: ${response.statusCode} - ${response.body}');
      return AuthResult.failure;
    } on SocketException catch (e) {
      debugPrint('Network error during login: $e');
      return AuthResult.networkError;
    } catch (e) {
      debugPrint('Unexpected error during login: $e');
      return AuthResult.failure;
    }
  }

  /// Refreshes the access token using the stored refresh token.
  /// Returns [AuthResult.success] on success, or an appropriate error result.
  Future<AuthResult> refreshToken() async {
    final refresh = await _storage.read(key: 'refresh_token');
    if (refresh == null) return AuthResult.noRefreshToken;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/token/refresh/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': refresh}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final access = data['access'] as String?;
        final newRefresh = data['refresh'] as String?;

        if (access != null) {
          await _storage.write(key: 'access_token', value: access);
          if (newRefresh != null) {
            await _storage.write(key: 'refresh_token', value: newRefresh);
          }
          return AuthResult.success;
        }
      }
      debugPrint('Token refresh failed: ${response.statusCode} - ${response.body}');
      return AuthResult.sessionExpired;
    } on SocketException catch (e) {
      debugPrint('Network error during token refresh: $e');
      return AuthResult.networkError;
    } catch (e) {
      debugPrint('Unexpected error during token refresh: $e');
      return AuthResult.failure;
    }
  }

  /// Checks if an access token exists and is still valid.
  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: 'access_token');
    if (token == null) return false;

    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))) as Map<String, dynamic>;
      final exp = payload['exp'] as int?;
      if (exp == null) return false;

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return exp > (now + 10);
    } catch (e) {
      debugPrint('Error decoding token: $e');
      return false;
    }
  }

  /// Registers a new user.
  Future<AuthResult> register(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 201) return AuthResult.success;
      debugPrint('Registration failed: ${response.statusCode} - ${response.body}');
      return AuthResult.failure;
    } on SocketException catch (e) {
      debugPrint('Network error during registration: $e');
      return AuthResult.networkError;
    } catch (e) {
      debugPrint('Unexpected error during registration: $e');
      return AuthResult.failure;
    }
  }

  /// Toggles whether biometric login is allowed.
  Future<void> setBiometricsEnabled(bool enabled) async {
    await _storage.write(key: 'biometrics_enabled', value: enabled.toString());
  }

  /// Returns true if the user has enabled biometric login.
  Future<bool> isBiometricsEnabled() async {
    return (await _storage.read(key: 'biometrics_enabled')) == 'true';
  }

  /// Returns the stored username, if any.
  Future<String?> getUsername() => _storage.read(key: 'username');

  /// Clears current access token. 
  /// Deletes refresh token ONLY if biometrics are NOT enabled.
  Future<void> logout() async {
    await _storage.delete(key: 'access_token');
    
    // If biometrics are enabled, we keep the refresh token so 
    // the user can "Quick Login" back in using biometrics.
    final bioEnabled = await isBiometricsEnabled();
    if (!bioEnabled) {
      await _storage.delete(key: 'refresh_token');
      await _storage.delete(key: 'username');
    }
  }

  /// Completely forgets the user, clearing all tokens and settings.
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
