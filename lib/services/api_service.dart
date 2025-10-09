import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Your production URLs
  static const String _sendSmsUrl = 'https://automation.kwaaijongens.nl/webhook/send-sms';
  static const String _verifySmsUrl = 'https://automation.kwaaijongens.nl/webhook/verify-sms';
  static const String _versionCheckUrl = 'https://automation.kwaaijongens.nl/webhook/version-check';
  static const String _fcmTokenUrl = 'https://automation.kwaaijongens.nl/webhook/fcm-token';
  static const String _sessionsUrl = 'https://automation.kwaaijongens.nl/webhook/sessions';

  // Authentication credentials
  static const String _basicAuth = 'SystemArchitect:A\$pp_S3cr3t';
  static const String _sessionAuth = 'SystemArchitect:A\$pp_S3cr3t';

  // Helper method to get Basic Auth header
  static String _getBasicAuthHeader() {
    final authBytes = utf8.encode(_basicAuth);
    return 'Basic ${base64Encode(authBytes)}';
  }
  
  // Send SMS verification code
  static Future<ApiResponse> sendSmsCode(String phoneNumber, String name, String email) async {
    try {
      final response = await http.post(
        Uri.parse(_sendSmsUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': _getBasicAuthHeader(),
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
          'Authorization': _getBasicAuthHeader(),
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
          'Authorization': _getBasicAuthHeader(),
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

  // Create session on backend
  static Future<SessionResponse> createSession({
    required String sessionId,
    required String phoneNumber,
    required String name,
    required String companyName,
  }) async {
    try {
      final authBytes = utf8.encode(_sessionAuth);
      final authHeader = 'Basic ${base64Encode(authBytes)}';
      
      final response = await http.post(
        Uri.parse(_sessionsUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': authHeader,
        },
        body: jsonEncode({
          'method': 'create',
          'sessionId': sessionId,
          'phoneNumber': phoneNumber,
          'name': name,
          'companyName': companyName,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (responseData['success'] == true) {
          final data = responseData['data'] ?? {};
          return SessionResponse(
            success: true,
            message: responseData['message'] ?? 'Session created successfully',
            sessionData: SessionData(
              sessionId: sessionId,
              title: data['title'] ?? 'New Chat',
              description: data['description'] ?? '',
              thumbnail: data['thumbnail'],
            ),
          );
        } else {
          return SessionResponse(
            success: false,
            message: responseData['message'] ?? 'Failed to create session',
          );
        }
      } else {
        return SessionResponse(
          success: false,
          message: 'Failed to create session: ${response.statusCode}',
        );
      }
    } catch (e) {
      return SessionResponse(
        success: false,
        message: 'Network error creating session: $e',
      );
    }
  }

  // List user sessions
  static Future<SessionListResponse> listSessions({
    required String phoneNumber,
    required String name,
    required String companyName,
  }) async {
    try {
      final authBytes = utf8.encode(_sessionAuth);
      final authHeader = 'Basic ${base64Encode(authBytes)}';
      
      final response = await http.post(
        Uri.parse(_sessionsUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': authHeader,
        },
        body: jsonEncode({
          'method': 'list',
          'phoneNumber': phoneNumber,
          'name': name,
          'companyName': companyName,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        // Handle direct array response from server
        if (responseData is List) {
          final List<dynamic> sessionsData = responseData;
          final sessions = sessionsData.map((sessionJson) => SessionData(
            sessionId: sessionJson['session_id'] ?? '',
            title: sessionJson['session_title'] ?? 'Untitled Session',
            description: sessionJson['session_description'] ?? '',
            thumbnail: sessionJson['session_thumbnail'],
            lastActivity: sessionJson['last_modified'] ?? sessionJson['created_at'],
            messageCount: 0, // Not provided by server
            createdAt: sessionJson['created_at'],
          )).toList();
          
          // Sort sessions by lastActivity (most recent first)
          _sortSessionsByDate(sessions);
          
          return SessionListResponse(
            success: true,
            message: 'Sessions retrieved successfully',
            sessions: sessions,
          );
        }
        // Handle wrapped response format (fallback)
        else if (responseData is Map && responseData['success'] == true) {
          final List<dynamic> sessionsData = responseData['data'] ?? [];
          final sessions = sessionsData.map((sessionJson) => SessionData(
            sessionId: sessionJson['session_id'] ?? sessionJson['sessionId'] ?? '',
            title: sessionJson['session_title'] ?? sessionJson['title'] ?? 'Untitled Session',
            description: sessionJson['session_description'] ?? sessionJson['description'] ?? '',
            thumbnail: sessionJson['session_thumbnail'] ?? sessionJson['thumbnail'],
            lastActivity: sessionJson['last_modified'] ?? sessionJson['lastActivity'] ?? sessionJson['created_at'],
            messageCount: sessionJson['messageCount'] ?? 0,
            createdAt: sessionJson['created_at'] ?? sessionJson['createdAt'],
          )).toList();
          
          // Sort sessions by lastActivity (most recent first)
          _sortSessionsByDate(sessions);
          
          return SessionListResponse(
            success: true,
            message: 'Sessions retrieved successfully',
            sessions: sessions,
          );
        } else {
          return SessionListResponse(
            success: false,
            message: responseData is Map ? (responseData['message'] ?? 'Failed to retrieve sessions') : 'Invalid response format',
            sessions: [],
          );
        }
      } else {
        return SessionListResponse(
          success: false,
          message: 'Failed to retrieve sessions: ${response.statusCode}',
          sessions: [],
        );
      }
    } catch (e) {
      return SessionListResponse(
        success: false,
        message: 'Network error retrieving sessions: $e',
        sessions: [],
      );
    }
  }

  // Update session metadata
  static Future<SessionResponse> updateSession({
    required String sessionId,
    required String phoneNumber,
    required String name,
    required String companyName,
    String? title,
    String? description,
  }) async {
    try {
      final authBytes = utf8.encode(_sessionAuth);
      final authHeader = 'Basic ${base64Encode(authBytes)}';
      
      final requestBody = {
        'method': 'update',
        'sessionId': sessionId,
        'phoneNumber': phoneNumber,
        'name': name,
        'companyName': companyName,
      };
      
      if (title != null) requestBody['title'] = title;
      if (description != null) requestBody['description'] = description;
      
      final response = await http.post(
        Uri.parse(_sessionsUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': authHeader,
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        // Handle direct session data response from server
        if (responseData is Map && (responseData.containsKey('session_id') || responseData.containsKey('session_title'))) {
          return SessionResponse(
            success: true,
            message: 'Session updated successfully',
            sessionData: SessionData(
              sessionId: responseData['session_id'] ?? sessionId,
              title: responseData['session_title'] ?? title ?? 'Updated Session',
              description: responseData['session_description'] ?? description ?? '',
              thumbnail: responseData['session_thumbnail'],
              lastActivity: responseData['last_modified'] ?? responseData['created_at'],
              messageCount: 0,
              createdAt: responseData['created_at'],
            ),
          );
        }
        // Handle wrapped response format (fallback)
        else if (responseData is Map && responseData['success'] == true) {
          final data = responseData['data'] ?? {};
          return SessionResponse(
            success: true,
            message: responseData['message'] ?? 'Session updated successfully',
            sessionData: SessionData(
              sessionId: data['session_id'] ?? data['sessionId'] ?? sessionId,
              title: data['session_title'] ?? data['title'] ?? title ?? 'Updated Session',
              description: data['session_description'] ?? data['description'] ?? description ?? '',
              thumbnail: data['session_thumbnail'] ?? data['thumbnail'],
              lastActivity: data['last_modified'] ?? data['lastActivity'] ?? data['created_at'],
              messageCount: data['messageCount'] ?? 0,
              createdAt: data['created_at'] ?? data['createdAt'],
            ),
          );
        } else {
          return SessionResponse(
            success: false,
            message: responseData['message'] ?? 'Failed to update session',
          );
        }
      } else {
        return SessionResponse(
          success: false,
          message: 'Failed to update session: ${response.statusCode}',
        );
      }
    } catch (e) {
      return SessionResponse(
        success: false,
        message: 'Network error updating session: $e',
      );
    }
  }

  // Delete session
  static Future<ApiResponse> deleteSession({
    required String sessionId,
    required String phoneNumber,
    required String name,
    required String companyName,
  }) async {
    try {
      final authBytes = utf8.encode(_sessionAuth);
      final authHeader = 'Basic ${base64Encode(authBytes)}';
      
      final response = await http.post(
        Uri.parse(_sessionsUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': authHeader,
        },
        body: jsonEncode({
          'method': 'delete',
          'sessionId': sessionId,
          'phoneNumber': phoneNumber,
          'name': name,
          'companyName': companyName,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        return ApiResponse(
          success: responseData['success'] ?? true,
          message: responseData['message'] ?? 'Session deleted successfully',
        );
      } else {
        return ApiResponse(
          success: false,
          message: 'Failed to delete session: ${response.statusCode}',
        );
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Network error deleting session: $e',
      );
    }
  }

  // Get session details
  static Future<SessionResponse> getSessionDetails({
    required String sessionId,
    required String phoneNumber,
    required String name,
    required String companyName,
  }) async {
    try {
      final authBytes = utf8.encode(_sessionAuth);
      final authHeader = 'Basic ${base64Encode(authBytes)}';
      
      final response = await http.post(
        Uri.parse(_sessionsUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': authHeader,
        },
        body: jsonEncode({
          'method': 'get',
          'sessionId': sessionId,
          'phoneNumber': phoneNumber,
          'name': name,
          'companyName': companyName,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        // Handle direct session data response from server
        if (responseData is Map && (responseData.containsKey('session_id') || responseData.containsKey('session_title'))) {
          return SessionResponse(
            success: true,
            message: 'Session details retrieved successfully',
            sessionData: SessionData(
              sessionId: responseData['session_id'] ?? sessionId,
              title: responseData['session_title'] ?? 'Session',
              description: responseData['session_description'] ?? '',
              thumbnail: responseData['session_thumbnail'],
              lastActivity: responseData['last_modified'] ?? responseData['created_at'],
              messageCount: 0, // Not provided by server
              createdAt: responseData['created_at'],
            ),
          );
        }
        // Handle wrapped response format (fallback)
        else if (responseData is Map && responseData['success'] == true) {
          final data = responseData['data'] ?? {};
          return SessionResponse(
            success: true,
            message: 'Session details retrieved successfully',
            sessionData: SessionData(
              sessionId: data['session_id'] ?? data['sessionId'] ?? sessionId,
              title: data['session_title'] ?? data['title'] ?? 'Session',
              description: data['session_description'] ?? data['description'] ?? '',
              thumbnail: data['session_thumbnail'] ?? data['thumbnail'],
              lastActivity: data['last_modified'] ?? data['lastActivity'] ?? data['created_at'],
              messageCount: data['messageCount'] ?? 0,
              createdAt: data['created_at'] ?? data['createdAt'],
            ),
          );
        } else {
          return SessionResponse(
            success: false,
            message: responseData['message'] ?? 'Failed to get session details',
          );
        }
      } else {
        return SessionResponse(
          success: false,
          message: 'Failed to get session details: ${response.statusCode}',
        );
      }
    } catch (e) {
      return SessionResponse(
        success: false,
        message: 'Network error getting session details: $e',
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
          'Authorization': _getBasicAuthHeader(),
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

// Session data model
class SessionData {
  final String sessionId;
  final String title;
  final String description;
  final String? thumbnail;
  final String? lastActivity;
  final int messageCount;
  final String? createdAt;

  SessionData({
    required this.sessionId,
    required this.title,
    required this.description,
    this.thumbnail,
    this.lastActivity,
    this.messageCount = 0,
    this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'title': title,
      'description': description,
      'thumbnail': thumbnail,
      'lastActivity': lastActivity,
      'messageCount': messageCount,
      'createdAt': createdAt,
    };
  }

  factory SessionData.fromJson(Map<String, dynamic> json) {
    return SessionData(
      sessionId: json['sessionId'] ?? '',
      title: json['title'] ?? 'Untitled Session',
      description: json['description'] ?? '',
      thumbnail: json['thumbnail'],
      lastActivity: json['lastActivity'],
      messageCount: json['messageCount'] ?? 0,
      createdAt: json['createdAt'],
    );
  }
}

// Session response class
class SessionResponse {
  final bool success;
  final String message;
  final SessionData? sessionData;

  SessionResponse({
    required this.success,
    required this.message,
    this.sessionData,
  });
}

// Session list response class
class SessionListResponse {
  final bool success;
  final String message;
  final List<SessionData> sessions;

  SessionListResponse({
    required this.success,
    required this.message,
    required this.sessions,
  });
}

// Helper method to sort sessions by date (most recent first)
void _sortSessionsByDate(List<SessionData> sessions) {
  sessions.sort((a, b) {
    final aDate = DateTime.tryParse(a.lastActivity ?? a.createdAt ?? '');
    final bDate = DateTime.tryParse(b.lastActivity ?? b.createdAt ?? '');
    
    // Handle null dates
    if (aDate == null && bDate == null) return 0;
    if (aDate == null) return 1; // Put null dates at the end
    if (bDate == null) return -1; // Put null dates at the end
    
    // Sort in descending order (newest first)
    return bDate.compareTo(aDate);
  });
}