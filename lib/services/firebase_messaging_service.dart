import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'session_service.dart';

class FirebaseMessagingService {
  static const String _deviceTokenKey = 'fcm_device_token';
  static FirebaseMessaging? _messaging;
  static String? _deviceToken;
  static Function(Map<String, dynamic>)? _onMessageReceived;

  // Initialize Firebase Messaging
  static Future<void> initialize() async {
    try {
      _messaging = FirebaseMessaging.instance;
      await _requestPermissions();
      await _getDeviceToken();
      await _setupMessageHandlers();
    } catch (e) {
      if (kDebugMode) {
        print('Firebase Messaging initialization error: $e');
      }
    }
  }

  // Request notification permissions
  static Future<bool> _requestPermissions() async {
    if (_messaging == null) return false;

    try {
      NotificationSettings settings = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        announcement: false,
      );

      if (kDebugMode) {
        print('Permission granted: ${settings.authorizationStatus}');
      }

      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      if (kDebugMode) {
        print('Permission request error: $e');
      }
      return false;
    }
  }

  // Get and store device token
  static Future<String?> _getDeviceToken() async {
    if (_messaging == null) return null;

    try {
      _deviceToken = await _messaging!.getToken();
      if (_deviceToken != null) {
        await _saveTokenToStorage(_deviceToken!);
        if (kDebugMode) {
          print('FCM Token: $_deviceToken');
        }
      }
      return _deviceToken;
    } catch (e) {
      if (kDebugMode) {
        print('Get token error: $e');
      }
      return null;
    }
  }

  // Save token to local storage
  static Future<void> _saveTokenToStorage(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_deviceTokenKey, token);
    } catch (e) {
      if (kDebugMode) {
        print('Save token error: $e');
      }
    }
  }

  // Get stored token
  static Future<String?> getStoredToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_deviceTokenKey);
    } catch (e) {
      if (kDebugMode) {
        print('Get stored token error: $e');
      }
      return null;
    }
  }

  // Get current device token
  static String? get deviceToken => _deviceToken;

  // Set message handler for foreground messages
  static void setMessageHandler(Function(Map<String, dynamic>) handler) {
    _onMessageReceived = handler;
  }

  // Setup message handlers
  static Future<void> _setupMessageHandlers() async {
    if (_messaging == null) return;

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('Foreground message received: ${message.toMap()}');
      }
      
      if (_onMessageReceived != null && message.data.isNotEmpty) {
        _onMessageReceived!(message.data);
      }
    });

    // Handle background message taps
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('Message clicked: ${message.toMap()}');
      }
      
      if (_onMessageReceived != null && message.data.isNotEmpty) {
        _onMessageReceived!(message.data);
      }
    });

    // Check if app was opened from terminated state via notification
    RemoteMessage? initialMessage = await _messaging!.getInitialMessage();
    if (initialMessage != null) {
      if (kDebugMode) {
        print('App opened from terminated state: ${initialMessage.toMap()}');
      }
      
      if (_onMessageReceived != null && initialMessage.data.isNotEmpty) {
        _onMessageReceived!(initialMessage.data);
      }
    }

    // Handle token refresh
    _messaging!.onTokenRefresh.listen((String newToken) async {
      _deviceToken = newToken;
      await _saveTokenToStorage(newToken);
      if (kDebugMode) {
        print('FCM token refreshed: $newToken');
      }
    });
  }

  // Get token data for API calls
  static Map<String, dynamic>? getTokenData() {
    final sessionId = SessionService.currentSessionId;
    if (_deviceToken != null && sessionId != null) {
      return {
        'fcmToken': _deviceToken,
        'sessionId': sessionId,
        'platform': defaultTargetPlatform.name,
      };
    }
    return null;
  }

  // Refresh token and return it
  static Future<String?> refreshToken() async {
    return await _getDeviceToken();
  }
}

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print('Background message received: ${message.toMap()}');
  }
}