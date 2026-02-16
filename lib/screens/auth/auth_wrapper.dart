// ===========================================================================
// DEPRECATED: SMS Authentication has been removed in UYC rebrand
// This file is kept for reference only and is no longer used in the app.
// Entry point is now EndpointListScreen (lib/screens/endpoint_list_screen.dart)
// ===========================================================================

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../start_screen.dart';
import '../../widgets/message_dialog.dart';
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

      if (isLoggedIn) {
        // User is logged in, perform version check
        await _performVersionCheck();
      } else {
        // User not logged in, go to phone input
        setState(() {
          _isAuthenticated = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking auth status: $e');
      setState(() {
        _isAuthenticated = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _performVersionCheck() async {
    try {
      // Get app version and user phone number
      final packageInfo = await PackageInfo.fromPlatform();
      final appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      final user = AuthService.currentUser;

      if (user?.phoneNumber != null) {
        // Call version check API
        final versionResponse = await ApiService.checkVersion(
          appVersion,
          user!.phoneNumber,
        );

        if (versionResponse.success) {
          if (versionResponse.reset) {
            // Reset = true: clear all data, logout, show message, go to phone input
            await StorageService.clearAllData();
            await AuthService.logout();

            if (mounted) {
              setState(() {
                _isAuthenticated = false;
                _isLoading = false;
              });

              // Show custom message if provided
              if (versionResponse.message.isNotEmpty) {
                await showCustomMessageDialog(context, versionResponse.message);
              }
            }
          } else {
            // Reset = false: show message (if any), continue to chat
            setState(() {
              _isAuthenticated = true;
              _isLoading = false;
            });

            // Show custom message if provided
            if (mounted && versionResponse.message.isNotEmpty) {
              // Use Future.delayed to show dialog after build completes
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) {
                  showCustomMessageDialog(context, versionResponse.message);
                }
              });
            }
          }
        } else {
          // API call failed: continue to chat silently (fail gracefully)
          setState(() {
            _isAuthenticated = true;
            _isLoading = false;
          });
        }
      } else {
        // No phone number available, logout
        await AuthService.logout();
        setState(() {
          _isAuthenticated = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error during version check: $e');
      // On error, continue to chat (fail gracefully)
      setState(() {
        _isAuthenticated = true;
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
              CircularProgressIndicator(color: Color(0xFFCC0001)),
              SizedBox(height: 16),
              Text(
                'kwaaijongens APP',
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

    // Show start screen if authenticated, otherwise show phone input
    if (_isAuthenticated) {
      return const StartScreen();
    } else {
      return const PhoneInputScreen();
    }
  }
}
