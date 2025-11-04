import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'storage_service.dart';
import 'api_service.dart';

class AuthService {
  static User? _currentUser;
  
  // Default webhook URL
  static const String _defaultWebhookUrl = 'https://automation.kwaaijongens.nl/webhook/46b0b5ec-132d-4aca-97ec-0d11d05f66bc/chat';
  
  // Get current user
  static User? get currentUser => _currentUser;
  
  // Initialize - load user from storage on app start
  static Future<bool> initialize() async {
    try {
      _currentUser = await StorageService.getUser();
      return _currentUser != null;
    } catch (e) {
      debugPrint('Error initializing auth: $e');
      return false;
    }
  }
  
  // Check if user is authenticated
  static Future<bool> isAuthenticated() async {
    if (_currentUser != null) return true;
    return await StorageService.isLoggedIn();
  }
  
  // Send SMS verification code
  static Future<ApiResponse> sendVerificationCode(String phoneNumber, String name, String email) async {
    return await ApiService.sendSmsCode(phoneNumber, name, email);
  }
  
  // Verify SMS code and complete registration
  static Future<ApiResponse> verifyAndRegister({
    required String phoneNumber,
    required String name,
    required String email,
    required String smsCode,
  }) async {
    final response = await ApiService.verifySmsAndRegister(
      phoneNumber: phoneNumber,
      name: name,
      email: email,
      smsCode: smsCode,
    );
    
    if (response.success && response.data != null) {
      // Create user with API response data
      _currentUser = User(
        phoneNumber: phoneNumber,
        name: response.data!['name'] ?? name,
        companyName: response.data!['companyName'] ?? '',
        webhookUrl: response.data!['webhookUrl']?.isNotEmpty == true 
                   ? response.data!['webhookUrl'] 
                   : _defaultWebhookUrl,
        email: response.data!['email'] ?? '',
        phone: response.data!['phone'] ?? phoneNumber,
        website: response.data!['website'] ?? '',
        lastLogin: DateTime.now(),
      );
      
      // Save to local storage
      final saved = await StorageService.saveUser(_currentUser!);
      if (!saved) {
        return ApiResponse(
          success: false, 
          message: 'Kon gebruikersgegevens niet opslaan'
        );
      }
    }
    
    return response;
  }
  
  // Logout user
  static Future<bool> logout() async {
    _currentUser = null;
    return await StorageService.clearUser();
  }
  
  // Get webhook URL for chat
  static String? getWebhookUrl() {
    return _currentUser?.webhookUrl;
  }
  
  // Get client data for webhook requests
  static Map<String, dynamic>? getClientData() {
    if (_currentUser == null) return null;
    
    return {
      'webhookUrl': _currentUser!.webhookUrl,
      'name': _currentUser!.name,
      'companyName': _currentUser!.companyName,
      'email': _currentUser!.email,
      'phone': _currentUser!.phone,
      'website': _currentUser!.website,
    };
  }
  
  // Check if client data is complete
  static bool isClientDataComplete() {
    final clientData = getClientData();
    if (clientData == null) return false;
    
    return clientData['webhookUrl'].isNotEmpty &&
           clientData['name'].isNotEmpty &&
           clientData['companyName'].isNotEmpty &&
           clientData['email'].isNotEmpty &&
           clientData['phone'].isNotEmpty;
  }
}