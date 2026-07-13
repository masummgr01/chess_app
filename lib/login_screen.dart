import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'chess_board_screen.dart';
import 'biometric_helper.dart';
import 'package:local_auth/local_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isRegisterMode = false;
  bool _isLoading = false;
  String? _errorMessage;
  List<BiometricType> _availableBiometrics = [];
  bool _canCheckBiometrics = false;
  String? _storedUsername;
  bool _biometricsEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final canCheck = await BiometricHelper.canCheckBiometrics();
    final available = await BiometricHelper.getAvailableBiometrics();
    final enabled = await _auth.isBiometricsEnabled();
    final username = await _auth.getUsername();

    if (mounted) {
      setState(() {
        _canCheckBiometrics = canCheck;
        _availableBiometrics = available;
        _biometricsEnabled = enabled;
        _storedUsername = username;
      });
    }
  }

  /// Detects Fingerprint support
  bool get _hasFingerprintSupport =>
      _availableBiometrics.contains(BiometricType.fingerprint);

  /// Returns the appropriate label based on available hardware (focusing on Fingerprint)
  String get _biometricLabel {
    if (_hasFingerprintSupport) return 'Fingerprint';
    return 'Biometrics';
  }

  /// Use fingerprint icon as the primary biometric visual
  IconData get _biometricIcon => Icons.fingerprint;

  Future<void> _submit() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please fill in both fields');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    AuthResult result;
    if (_isRegisterMode) {
      result = await _auth.register(username, password);
      if (result == AuthResult.success) {
        result = await _auth.login(username, password);
      }
    } else {
      result = await _auth.login(username, password);
    }

    if (!mounted) return;

    if (result == AuthResult.success) {
      // Refresh biometric state after successful login
      await _checkBiometrics();

      if (!mounted) return;
      if (!_biometricsEnabled && (_availableBiometrics.isNotEmpty || _canCheckBiometrics)) {
        bool? wantBiometrics = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Enable $_biometricLabel?'),
            content: Text(
              'Would you like to use $_biometricLabel for faster login next time?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Not Now'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Yes, Enable'),
              ),
            ],
          ),
        );

        if (wantBiometrics == true) {
          await _auth.setBiometricsEnabled(true);
          await _checkBiometrics();
        }
      }

      if (!mounted) return;
      setState(() => _isLoading = false);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ChessBoardScreen()),
      );
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = switch (result) {
          AuthResult.invalidCredentials => 'Invalid username or password',
          AuthResult.networkError => "Can't reach the server. Check your connection.",
          _ => _isRegisterMode ? 'Registration failed' : 'Login failed',
        };
      });
    }
  }

  Future<void> _handleBiometricLogin() async {
    if (!_biometricsEnabled) {
      setState(() => _errorMessage = "Biometric login is not enabled. Please login with password first.");
      return;
    }

    BiometricResult bioResult = await BiometricHelper.authenticate();
    
    if (!mounted) return;

    if (bioResult == BiometricResult.success) {
      setState(() => _isLoading = true);
      
      bool loggedIn = await _auth.isLoggedIn();
      if (!loggedIn) {
        AuthResult refreshResult = await _auth.refreshToken();
        if (!mounted) return;
        
        if (refreshResult != AuthResult.success) {
          setState(() {
            _isLoading = false;
            _errorMessage = switch (refreshResult) {
              AuthResult.networkError => "Can't reach the server. Check your connection.",
              AuthResult.noRefreshToken => "Biometrics enabled but session not found. Please log in with your password once.",
              _ => "Session expired. Please log in with your password again.",
            };
          });
          return;
        }
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ChessBoardScreen()),
      );
    } else if (bioResult != BiometricResult.cancelled) {
      setState(() {
        _errorMessage = switch (bioResult) {
          BiometricResult.notEnrolled => "Biometrics not enrolled on this device.",
          BiometricResult.notSupported => "Biometrics not supported on this device.",
          BiometricResult.lockedOut => "Too many attempts. Please use your password.",
          _ => "Authentication failed. Please try again.",
        };
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isRegisterMode ? 'Create Account' : 'Log In')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.castle, size: 64, color: Colors.brown),
                const SizedBox(height: 8),
                Text(
                  'Basic Chess',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(14)),
                  child: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : Text(_isRegisterMode ? 'Register' : 'Log In'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => setState(() {
                    _isRegisterMode = !_isRegisterMode;
                    _errorMessage = null;
                  }),
                  child: Text(_isRegisterMode
                      ? 'Already have an account? Log in'
                      : "Don't have an account? Register"),
                ),
                if (!_isRegisterMode && (_availableBiometrics.isNotEmpty || _canCheckBiometrics)) ...[
                  const Divider(height: 32),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.brown.shade50,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      elevation: 0,
                      side: BorderSide(color: Colors.brown.shade200),
                    ),
                    onPressed: _isLoading ? null : _handleBiometricLogin,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _biometricIcon,
                              size: 24,
                              color: Colors.brown,
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                _storedUsername != null && _biometricsEnabled
                                    ? "Login as $_storedUsername"
                                    : "Login with $_biometricLabel",
                                style: const TextStyle(
                                  color: Colors.brown,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (_storedUsername != null && _biometricsEnabled)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              "using $_biometricLabel",
                              style: TextStyle(
                                color: Colors.brown.shade400,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
