import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

class SessionService {
  static const String _sessionIdKey = 'current_session_id';
  static String? _currentSessionId;
  
  // Get current session ID
  static String? get currentSessionId => _currentSessionId;
  
  // Initialize session service - load or create session
  static Future<void> initialize() async {
    await _loadOrCreateSession();
  }
  
  // Generate new session ID with format: test_session_($name$)(timestamp)
  static String _generateSessionId() {
    final user = AuthService.currentUser;
    final name = user?.name ?? 'unknown';
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000; // epoch seconds
    
    return 'test_session_($name)($timestamp)';
  }
  
  // Start new session
  static Future<String> startNewSession() async {
    _currentSessionId = _generateSessionId();
    await _saveSessionId(_currentSessionId!);
    return _currentSessionId!;
  }
  
  // Load existing session or create new one
  static Future<void> _loadOrCreateSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentSessionId = prefs.getString(_sessionIdKey);
      
      // If no session exists, create a new one
      if (_currentSessionId == null) {
        await startNewSession();
      }
    } catch (e) {
      print('Error loading session: $e');
      // Fallback to new session
      await startNewSession();
    }
  }
  
  // Save session ID to storage
  static Future<void> _saveSessionId(String sessionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionIdKey, sessionId);
    } catch (e) {
      print('Error saving session ID: $e');
    }
  }
  
  // End current session and start new one
  static Future<String> resetSession() async {
    return await startNewSession();
  }
  
  // Clear session data
  static Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionIdKey);
      _currentSessionId = null;
    } catch (e) {
      print('Error clearing session: $e');
    }
  }
}