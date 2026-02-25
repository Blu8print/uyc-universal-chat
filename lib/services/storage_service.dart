import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class StorageService {
  static const String _sessionDataKey = 'session_data_';
  static const String _sessionListKey = 'session_list';

  // Clear ALL app data (for reset functionality)
  static Future<bool> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      return true;
    } catch (e) {
      debugPrint('Error clearing all data: $e');
      return false;
    }
  }

  // Save messages for a session
  static Future<bool> saveMessages(
    String sessionId,
    List<Map<String, dynamic>> messages,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final messagesJson = jsonEncode(messages);
      await prefs.setString('messages_$sessionId', messagesJson);
      return true;
    } catch (e) {
      debugPrint('Error saving messages: $e');
      return false;
    }
  }

  // Load messages for a session
  static Future<List<Map<String, dynamic>>> loadMessages(
    String sessionId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final messagesJson = prefs.getString('messages_$sessionId');

      if (messagesJson != null) {
        final List<dynamic> messagesList = jsonDecode(messagesJson);
        return messagesList.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('Error loading messages: $e');
      return [];
    }
  }

  // Clear messages for a session
  static Future<bool> clearMessages(String sessionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('messages_$sessionId');
      return true;
    } catch (e) {
      debugPrint('Error clearing messages: $e');
      return false;
    }
  }

  // Save session metadata
  static Future<bool> saveSessionData(SessionData sessionData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionJson = jsonEncode(sessionData.toJson());
      await prefs.setString(
        '$_sessionDataKey${sessionData.sessionId}',
        sessionJson,
      );
      return true;
    } catch (e) {
      debugPrint('Error saving session data: $e');
      return false;
    }
  }

  // Load session metadata
  static Future<SessionData?> loadSessionData(String sessionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionJson = prefs.getString('$_sessionDataKey$sessionId');

      if (sessionJson != null) {
        final sessionMap = jsonDecode(sessionJson);
        return SessionData.fromJson(sessionMap);
      }
      return null;
    } catch (e) {
      debugPrint('Error loading session data: $e');
      return null;
    }
  }

  // Save session list
  static Future<bool> saveSessionList(List<SessionData> sessions) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionsJson = jsonEncode(sessions.map((s) => s.toJson()).toList());
      await prefs.setString(_sessionListKey, sessionsJson);
      return true;
    } catch (e) {
      debugPrint('Error saving session list: $e');
      return false;
    }
  }

  // Load session list
  static Future<List<SessionData>> loadSessionList() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionsJson = prefs.getString(_sessionListKey);

      if (sessionsJson != null) {
        final List<dynamic> sessionsList = jsonDecode(sessionsJson);
        return sessionsList
            .map((sessionMap) => SessionData.fromJson(sessionMap))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error loading session list: $e');
      return [];
    }
  }

  // Clear session metadata
  static Future<bool> clearSessionData(String sessionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_sessionDataKey$sessionId');
      return true;
    } catch (e) {
      debugPrint('Error clearing session data: $e');
      return false;
    }
  }

  // Clear all session data (sessions and messages)
  static Future<bool> clearAllSessionData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      // Remove all session-related keys
      for (String key in keys) {
        if (key.startsWith('messages_') ||
            key.startsWith(_sessionDataKey) ||
            key == _sessionListKey) {
          await prefs.remove(key);
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error clearing all session data: $e');
      return false;
    }
  }

  // Storage monitoring for optimization
  static Future<Map<String, dynamic>> getStorageStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      int sessionCount = 0;
      int messageKeys = 0;
      int totalMessageSize = 0;
      int sessionDataSize = 0;

      for (String key in keys) {
        if (key.startsWith('messages_')) {
          messageKeys++;
          final messagesJson = prefs.getString(key) ?? '';
          totalMessageSize += messagesJson.length;
        } else if (key.startsWith(_sessionDataKey)) {
          sessionCount++;
          final sessionJson = prefs.getString(key) ?? '';
          sessionDataSize += sessionJson.length;
        }
      }

      return {
        'sessionCount': sessionCount,
        'messageSessionCount': messageKeys,
        'totalMessageSizeBytes': totalMessageSize,
        'sessionDataSizeBytes': sessionDataSize,
        'totalSizeBytes': totalMessageSize + sessionDataSize,
        'averageMessageSizePerSession':
            messageKeys > 0 ? totalMessageSize / messageKeys : 0,
      };
    } catch (e) {
      debugPrint('Error getting storage stats: $e');
      return {
        'sessionCount': 0,
        'messageSessionCount': 0,
        'totalMessageSizeBytes': 0,
        'sessionDataSizeBytes': 0,
        'totalSizeBytes': 0,
        'averageMessageSizePerSession': 0,
      };
    }
  }
}
