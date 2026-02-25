import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'storage_service.dart';

class SessionService {
  static const String _sessionIdKey = 'current_session_id';
  static String? _currentSessionId;
  static SessionData? _currentSessionData;
  static List<SessionData> _sessionList = [];

  static String? get currentSessionId => _currentSessionId;
  static SessionData? get currentSessionData => _currentSessionData;
  static List<SessionData> get sessionList => _sessionList;

  static Future<void> initialize() async {
    await _loadOrCreateSession();
  }

  static String _generateSessionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'session_$timestamp';
  }

  static Future<String> startNewSession({String? chatType}) async {
    _currentSessionId = _generateSessionId();
    debugPrint('[SessionService] Creating new session: $_currentSessionId');
    await _saveSessionId(_currentSessionId!);
    return _currentSessionId!;
  }

  static Future<void> loadSession(SessionData sessionData) async {
    _currentSessionId = sessionData.sessionId;
    _currentSessionData = sessionData;
    await _saveSessionId(_currentSessionId!);
    debugPrint('[SessionService] Loaded session: $_currentSessionId');
  }

  static Future<void> _loadOrCreateSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentSessionId = prefs.getString(_sessionIdKey);

      if (_currentSessionId == null) {
        await startNewSession();
      } else {
        _currentSessionData = await StorageService.loadSessionData(_currentSessionId!);
      }
    } catch (e) {
      debugPrint('Error loading session: $e');
      await startNewSession();
    }
  }

  static Future<void> _saveSessionId(String sessionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionIdKey, sessionId);
    } catch (e) {
      debugPrint('Error saving session ID: $e');
    }
  }

  static Future<String> resetSession({String? chatType}) async {
    return await startNewSession(chatType: chatType);
  }

  static Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionIdKey);
      _currentSessionId = null;
      _currentSessionData = null;
    } catch (e) {
      debugPrint('Error clearing session: $e');
    }
  }

  // Stubbed — will be replaced by Drift implementation
  static Future<bool> syncSessionList() async => false;

  static Future<void> loadSessionListFromCache() async {
    try {
      _sessionList = await StorageService.loadSessionList();
      _sortSessionsByDate(_sessionList);
    } catch (e) {
      debugPrint('Error loading session list from cache: $e');
      _sessionList = [];
    }
  }

  // Stubbed — will be replaced by Drift implementation
  static Future<bool> updateCurrentSession({
    String? title,
    String? description,
    List<Map<String, dynamic>>? messages,
  }) async => false;

  // Stubbed — will be replaced by Drift implementation
  static Future<void> markCurrentSessionEmailSent() async {}

  // Stubbed — will be replaced by Drift implementation
  static Future<bool> deleteSession(String sessionId) async {
    _sessionList.removeWhere((s) => s.sessionId == sessionId);
    await StorageService.saveSessionList(_sessionList);
    await StorageService.clearMessages(sessionId);
    await StorageService.clearSessionData(sessionId);
    if (_currentSessionId == sessionId) {
      _currentSessionId = null;
      _currentSessionData = null;
    }
    return true;
  }

  // Stubbed — will be replaced by Drift implementation
  static Future<bool> pinSession(String sessionId) async => false;

  // Stubbed — will be replaced by Drift implementation
  static Future<bool> unpinSession(String sessionId) async => false;

  static Future<bool> switchToSession(String sessionId) async {
    try {
      _currentSessionId = sessionId;
      await _saveSessionId(sessionId);

      final sessionData = _sessionList.firstWhere(
        (s) => s.sessionId == sessionId,
        orElse: () => SessionData(sessionId: sessionId, title: 'Session', description: ''),
      );

      _currentSessionData = sessionData;
      await StorageService.saveSessionData(sessionData);
      return true;
    } catch (e) {
      debugPrint('Error switching session: $e');
      return false;
    }
  }

  static Future<void> initializeWithSync() async {
    await initialize();
    await loadSessionListFromCache();
  }

  static void _sortSessionsByDate(List<SessionData> sessions) {
    sessions.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      final aDate = DateTime.tryParse(a.lastActivity ?? a.createdAt ?? '');
      final bDate = DateTime.tryParse(b.lastActivity ?? b.createdAt ?? '');
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
  }
}
