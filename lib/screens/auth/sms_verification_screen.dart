import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';
import '../start_screen.dart';

class SmsVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String name;
  final String email;

  const SmsVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.name,
    required this.email,
  });

  @override
  State<SmsVerificationScreen> createState() => _SmsVerificationScreenState();
}

class _SmsVerificationScreenState extends State<SmsVerificationScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  int _failedAttempts = 0;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  bool _isValidInput() {
    return _codeController.text.trim().length >= 4;
  }

  Future<void> _verifyCode() async {
    if (!_isValidInput()) {
      setState(() {
        _errorMessage = 'Vul de verificatiecode in';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await AuthService.verifyAndRegister(
      phoneNumber: widget.phoneNumber,
      name: widget.name,
      email: widget.email,
      smsCode: _codeController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (response.success) {
        // Registration successful - navigate to start screen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const StartScreen()),
          (route) => false,
        );
      } else {
        _failedAttempts++;
        
        if (_failedAttempts >= 3) {
          setState(() {
            _errorMessage = 'Te veel ongeldige pogingen. Bel 085 - 330 7500 voor ondersteuning.';
          });
        } else {
          setState(() {
            _errorMessage = response.message;
          });
        }
      }
    }
  }

  Future<void> _resendCode() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await AuthService.sendVerificationCode(widget.phoneNumber, widget.name, widget.email);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (response.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nieuwe SMS-code verzonden'),
            backgroundColor: Color(0xFFCC0001),
          ),
        );
        // Reset failed attempts on successful resend
        _failedAttempts = 0;
      } else {
        setState(() {
          _errorMessage = response.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Verificatie'),
        backgroundColor: const Color(0xFFCC0001),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(  // Make it scrollable
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - 
                         MediaQuery.of(context).padding.top - 
                         kToolbarHeight - 48, // Account for padding and app bar
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                
                // Instructions
                const Icon(
                  Icons.sms,
                  size: 60,
                  color: Color(0xFFCC0001),
                ),
                const SizedBox(height: 24),
                Text(
                  'SMS-code verzonden naar',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.phoneNumber,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFCC0001),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Hallo ${widget.name}!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 32),
                
                // SMS code input
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: MediaQuery.of(context).size.width < 360 ? 4 : 8,
                  ),
                  maxLines: 1,
                  decoration: const InputDecoration(
                    labelText: 'Verificatiecode',
                    hintText: '123456',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  onChanged: (value) {
                    if (_errorMessage != null) {
                      setState(() {
                        _errorMessage = null;
                      });
                    }
                  },
                ),
                
                // Error message
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                
                const SizedBox(height: 32),
                
                // Verify button
                ElevatedButton(
                  onPressed: _isLoading ? null : _verifyCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCC0001),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Verifiëren en Registreren',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                
                const SizedBox(height: 16),
                
                // Resend button
                TextButton(
                  onPressed: _isLoading ? null : _resendCode,
                  child: const Text(
                    'Nieuwe code verzenden',
                    style: TextStyle(
                      color: Color(0xFFCC0001),
                      fontSize: 14,
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Help text
                Text(
                  'De SMS-code is 10 minuten geldig',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}