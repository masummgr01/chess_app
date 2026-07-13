import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'login_screen.dart';
import 'chess_board_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ChessApp());
}

class ChessApp extends StatelessWidget {
  const ChessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Basic Chess',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.brown, useMaterial3: true),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _auth = AuthService();
  bool _checking = true;
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // 1. Check if we have an access token
    bool loggedIn = await _auth.isLoggedIn();
    
    // 2. If not, try to refresh if a refresh token exists
    if (!loggedIn) {
      final refreshResult = await _auth.refreshToken();
      if (refreshResult == AuthResult.success) {
        loggedIn = true;
      }
    }

    if (!mounted) return;
    setState(() {
      _loggedIn = loggedIn;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Restoring session...'),
            ],
          ),
        ),
      );
    }
    return _loggedIn ? const ChessBoardScreen() : const LoginScreen();
  }
}
