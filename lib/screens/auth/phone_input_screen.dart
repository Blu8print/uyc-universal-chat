import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';
import 'sms_verification_screen.dart';

class PhoneInputScreen extends StatefulWidget {
  const PhoneInputScreen({super.key});

  @override
  State<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends State<PhoneInputScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _countryCodeController = TextEditingController(text: '+31');
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _countryCodeController.dispose();
    super.dispose();
  }

  String _getFullPhoneNumber() {
    final countryCode = _countryCodeController.text.trim();
    final phoneNumber = _phoneController.text.trim();
    
    // Remove any leading zeros from phone number
    final cleanPhone = phoneNumber.startsWith('0') ? phoneNumber.substring(1) : phoneNumber;
    
    return '$countryCode$cleanPhone';
  }

  bool _isValidEmail() {
    final email = _emailController.text.trim();
    return email.isNotEmpty && email.contains('@') && email.contains('.');
  }

  bool _isValidPhoneNumber() {
    final phone = _phoneController.text.trim();
    // Dutch mobile numbers: 06xxxxxxxx or 6xxxxxxxx
    return phone.length >= 8 && phone.length <= 10 && 
           (phone.startsWith('06') || phone.startsWith('6'));
  }

  bool _isValidInput() {
    return _nameController.text.trim().isNotEmpty && 
           _isValidEmail() && 
           _isValidPhoneNumber();
  }

  Future<void> _sendSmsCode() async {
    if (!_isValidInput()) {
      setState(() {
        if (_nameController.text.trim().isEmpty) {
          _errorMessage = 'Voer je naam in';
        } else if (!_isValidEmail()) {
          _errorMessage = 'Voer een geldig e-mailadres in';
        } else if (!_isValidPhoneNumber()) {
          _errorMessage = 'Voer een geldig Nederlands mobiel nummer in (06xxxxxxxx of 6xxxxxxxx)';
        }
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final fullPhoneNumber = _getFullPhoneNumber();
    final response = await AuthService.sendVerificationCode(
      fullPhoneNumber, 
      _nameController.text.trim(),
      _emailController.text.trim()
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (response.success) {
        // Navigate to SMS verification screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SmsVerificationScreen(
              phoneNumber: fullPhoneNumber,
              name: _nameController.text.trim(),
              email: _emailController.text.trim(),
            ),
          ),
        );
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
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height - 
                           MediaQuery.of(context).padding.top - 
                           MediaQuery.of(context).padding.bottom - 48 > 0 
                           ? MediaQuery.of(context).size.height - 
                             MediaQuery.of(context).padding.top - 
                             MediaQuery.of(context).padding.bottom - 48
                           : 400, // Fallback minimum height
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              // Logo/Title
              const Icon(
                Icons.phone_android,
                size: 80,
                color: Color(0xFFCC0001),
              ),
              const SizedBox(height: 24),
              const Text(
                'kwaaijongens APP',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFCC0001),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Voer je gegevens in om te beginnen',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 48),
              
              // Name input
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(fontSize: 16),
                maxLines: 1,
                decoration: const InputDecoration(
                  labelText: 'Je naam',
                  hintText: 'Voor- en achternaam',
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
              const SizedBox(height: 16),
              
              // Email input
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(fontSize: 16),
                maxLines: 1,
                decoration: const InputDecoration(
                  labelText: 'E-mailadres',
                  hintText: 'jouw@email.nl',
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
              const SizedBox(height: 16),
              
              // Phone number input
              Row(
                children: [
                  // Country code
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: _countryCodeController,
                      keyboardType: TextInputType.phone,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                      maxLines: 1,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Phone number
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      style: const TextStyle(fontSize: 16),
                      maxLines: 1,
                      decoration: const InputDecoration(
                        hintText: '06 12345678',
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
                      onSubmitted: (_) => _sendSmsCode(),
                    ),
                  ),
                ],
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
              
              // Send SMS button
              ElevatedButton(
                onPressed: _isLoading ? null : _sendSmsCode,
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
                        'Verstuur SMS-code',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              
              const SizedBox(height: 24),
              
              // Help text
              Text(
                'Je ontvangt een SMS met een verificatiecode\nDe code is 10 minuten geldig',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Support info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.support_agent,
                      color: Colors.grey.shade600,
                      size: 24,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Problemen met inloggen?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bel 085 - 330 7500',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);
  }
}