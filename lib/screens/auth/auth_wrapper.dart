import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../screens/chat_screen.dart';
import 'phone_input_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      // Initialize auth service and check if user is logged in
      final isLoggedIn = await AuthService.initialize();
      
      setState(() {
        _isAuthenticated = isLoggedIn;
        _isLoading = false;
      });
    } catch (e) {
      print('Error checking auth status: $e');
      setState(() {
        _isAuthenticated = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Color(0xFFCC0001),
              ),
              SizedBox(height: 16),
              Text(
                'Kwaaijongens App',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFCC0001),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Show chat if authenticated, otherwise show phone input
    if (_isAuthenticated) {
      return const ChatScreen();
    } else {
      return const PhoneInputScreen();
    }
  }
}