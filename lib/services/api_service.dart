import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Your production URLs
  static const String _sendSmsUrl = 'https://kwaaijongens.app.n8n.cloud/webhook/send-sms';
  static const String _verifySmsUrl = 'https://kwaaijongens.app.n8n.cloud/webhook/verify-sms';
  
  // Send SMS verification code
  static Future<ApiResponse> sendSmsCode(String phoneNumber, String name) async {
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