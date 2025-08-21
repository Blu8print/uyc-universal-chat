import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Your production URLs
  static const String _sendSmsUrl = 'https://kwaaijongens.app.n8n.cloud/webhook/send-sms';
  static const String _verifySmsUrl = 'https://kwaaijongens.app.n8n.cloud/webhook/verify-sms';
  static const String _versionCheckUrl = 'https://kwaaijongens.app.n8n.cloud/webhook/version-check';
  static const String _fcmTokenUrl = 'https://kwaaijongens.app.n8n.cloud/webhook/fcm-token';
  
  // Send SMS verification code
  static Future<ApiResponse> sendSmsCode(String phoneNumber, String name, String email) async {
    try {
      final response = await http.post(
        Uri.parse(_sendSmsUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'phoneNumber': phoneNumber,
          'name': name,
          'email': email,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return ApiResponse(success: true, message: 'SMS-code verzonden');
      } else if (response.statusCode == 400) {
        return ApiResponse(success: false, message: 'Ongeldig telefoonnummer');
      } else if (response.statusCode == 429) {
        return ApiResponse(success: false, message: 'Te veel pogingen. Probeer later opnieuw.');
      } else {
        return ApiResponse(success: false, message: 'Kon SMS niet verzenden. Bel 085 - 330 7500');
      }
    } catch (e) {
      return ApiResponse(success: false, message: 'Netwerkfout. Controleer je internetverbinding.');
    }
  }

  // Verify SMS code and register user
  static Future<ApiResponse> verifySmsAndRegister({
    required String phoneNumber,
    required String name,
    required String email,
    required String smsCode,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_verifySmsUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'phoneNumber': phoneNumber,
          'name': name,
          'email': email,
          'smsCode': smsCode,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        // Handle array response format
        if (responseData is List && responseData.isNotEmpty) {
          final data = responseData[0];
          
          // Check the success field from the response data
          if (data['success'] == true) {
            return ApiResponse(
              success: true,
              message: data['message'] ?? 'Registratie succesvol',
              data: {
                'webhookUrl': data['webhookUrl'] ?? '',
                'name': data['name'] ?? '',
                'companyName': data['companyName'] ?? '',
                'email': data['email'] ?? '',
                'phone': data['phone'] ?? '',
                'website': data['website'] ?? '',
              },
            );
          } else {
            return ApiResponse(
              success: false, 
              message: data['message'] ?? 'Verificatie mislukt'
            );
          }
        } else {
          return ApiResponse(success: false, message: 'Ongeldig response format');
        }
      } else if (response.statusCode == 400) {
        return ApiResponse(success: false, message: 'Ongeldige verificatiecode');
      } else if (response.statusCode == 429) {
        return ApiResponse(success: false, message: 'Te veel pogingen. Bel 085 - 330 7500');
      } else {
        return ApiResponse(success: false, message: 'Registratie mislukt. Bel 085 - 330 7500');
      }
    } catch (e) {
      return ApiResponse(success: false, message: 'Netwerkfout. Controleer je internetverbinding.');
    }
  }

  // Send FCM token to n8n backend
  static Future<ApiResponse> sendFCMToken({
    required String fcmToken,
    required String sessionId,
    required String platform,
    String? phoneNumber,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_fcmTokenUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Session-ID': sessionId,
        },
        body: jsonEncode({
          'action': 'registerToken',
          'fcmToken': fcmToken,
          'sessionId': sessionId,
          'platform': platform,
          'phoneNumber': phoneNumber,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return ApiResponse(
          success: true, 
          message: 'FCM token registered successfully'
        );
      } else {
        return ApiResponse(
          success: false, 
          message: 'Failed to register FCM token: ${response.statusCode}'
        );
      }
    } catch (e) {
      return ApiResponse(
        success: false, 
        message: 'Network error registering FCM token: $e'
      );
    }
  }

  // Check app version and user status
  static Future<VersionCheckResponse> checkVersion(String version, String phoneNumber) async {
    try {
      final response = await http.post(
        Uri.parse(_versionCheckUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'version': version,
          'phoneNumber': phoneNumber,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        // Handle array response format
        if (responseData is List && responseData.isNotEmpty) {
          final data = responseData[0];
          
          return VersionCheckResponse(
            success: true,
            reset: data['Reset'] ?? false,
            message: data['message'] ?? '',
            appVersion: data['App-version'] ?? version,
          );
        } else {
          return VersionCheckResponse(success: false);
        }
      } else {
        return VersionCheckResponse(success: false);
      }
    } catch (e) {
      // Fail silently - return success=false so app continues normally
      return VersionCheckResponse(success: false);
    }
  }
}

// Response wrapper class
class ApiResponse {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
  });
}

// Version check response class
class VersionCheckResponse {
  final bool success;
  final bool reset;
  final String message;
  final String appVersion;

  VersionCheckResponse({
    required this.success,
    this.reset = false,
    this.message = '',
    this.appVersion = '',
  });
}