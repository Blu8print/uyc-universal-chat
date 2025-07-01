import '../models/user_model.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';

class AuthService {
  static User? _currentUser;
  
  // Get current user
  static User? get currentUser => _currentUser;
  
  // Initialize - load user from storage on app start
  static Future<bool> initialize() async {
    try {
      _currentUser = await StorageService.getUser();
      return _currentUser != null;
    } catch (e) {
      print('Error initializing auth: $e');
      return false;
    }
  }
  
  // Check if user is authenticated
  static Future<bool> isAuthenticated() async {
    if (_currentUser != null) return true;
    return await StorageService.isLoggedIn();
  }
  
  // Send SMS verification code
  static Future<ApiResponse> sendVerificationCode(String phoneNumber) async {
    return await ApiService.sendSmsCode(phoneNumber);
  }
  
  // Verify SMS code and complete registration
  static Future<ApiResponse> verifyAndRegister({
    required String phoneNumber,
    required String name,
    required String smsCode,
  }) async {
    final response = await ApiService.verifySmsAndRegister(
      phoneNumber: phoneNumber,
      name: name,
      smsCode: smsCode,
    );
    
    if (response.success && response.data != null) {
      // Create user with API response data
      _currentUser = User(
        phoneNumber: phoneNumber,
        name: name,
        companyName: response.data!['companyName'],
        webhookUrl: response.data!['webhookUrl'],
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
}