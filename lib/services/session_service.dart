import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'storage_service.dart';

class SessionService {
  static const String _sessionIdKey = 'current_session_id';
  static String? _currentSessionId;
  static SessionData? _currentSessionData;
  static List<SessionData> _sessionList = [];
  
  // Get current session ID
  static String? get currentSessionId => _currentSessionId;
  
  // Get current session data
  static SessionData? get currentSessionData => _currentSessionData;
  
  // Get session list
  static List<SessionData> get sessionList => _sessionList;
  
  // Initialize session service - load or create session
  static Future<void> initialize() async {
    await _loadOrCreateSession();
  }
  
  // Generate new session ID 
  static String _generateSessionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'session_$timestamp';
  }
  
  // Start new session with backend sync
  static Future<String> startNewSession() async {
    _currentSessionId = _generateSessionId();
    await _saveSessionId(_currentSessionId!);
    
    // Try to create session on backend
    await _createSessionOnBackend(_currentSessionId!);
    
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
      } else {
        // Load session data for existing session
        _currentSessionData = await StorageService.loadSessionData(_currentSessionId!);
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
      _currentSessionData = null;
    } catch (e) {
      print('Error clearing session: $e');
    }
  }
  
  // Create session on backend
  static Future<void> _createSessionOnBackend(String sessionId) async {
    try {
      final user = await StorageService.getUser();
      if (user != null) {
        final response = await ApiService.createSession(
          sessionId: sessionId,
          phoneNumber: user.phoneNumber,
          name: user.name,
          companyName: user.companyName,
        );
        
        if (response.success && response.sessionData != null) {
          _currentSessionData = response.sessionData;
          await StorageService.saveSessionData(response.sessionData!);
        } else {
          print('Failed to create session on backend: ${response.message}');
        }
      }
    } catch (e) {
      print('Error creating session on backend: $e');
    }
  }
  
  // Sync session list from backend
  static Future<bool> syncSessionList() async {
    try {
      final user = await StorageService.getUser();
      if (user != null) {
        final response = await ApiService.listSessions(
          phoneNumber: user.phoneNumber,
          name: user.name,
          companyName: user.companyName,
        );
        
        if (response.success) {
          _sessionList = response.sessions;
          await StorageService.saveSessionList(_sessionList);
          return true;
        } else {
          print('Failed to sync session list: ${response.message}');
          return false;
        }
      }
      return false;
    } catch (e) {
      print('Error syncing session list: $e');
      return false;
    }
  }
  
  // Load session list from cache
  static Future<void> loadSessionListFromCache() async {
    try {
      _sessionList = await StorageService.loadSessionList();
      // Sort cached sessions by date (most recent first)
      _sortSessionsByDate(_sessionList);
    } catch (e) {
      print('Error loading session list from cache: $e');
      _sessionList = [];
    }
  }
  
  // Update current session metadata
  static Future<bool> updateCurrentSession({String? title, String? description}) async {
    if (_currentSessionId == null) return false;
    
    try {
      final user = await StorageService.getUser();
      if (user != null) {
        final response = await ApiService.updateSession(
          sessionId: _currentSessionId!,
          phoneNumber: user.phoneNumber,
          name: user.name,
          companyName: user.companyName,
          title: title,
          description: description,
        );
        
        if (response.success && response.sessionData != null) {
          _currentSessionData = response.sessionData;
          await StorageService.saveSessionData(response.sessionData!);
          return true;
        } else {
          print('Failed to update session: ${response.message}');
          return false;
        }
      }
      return false;
    } catch (e) {
      print('Error updating session: $e');
      return false;
    }
  }
  
  // Delete session
  static Future<bool> deleteSession(String sessionId) async {
    try {
      final user = await StorageService.getUser();
      if (user != null) {
        final response = await ApiService.deleteSession(
          sessionId: sessionId,
          phoneNumber: user.phoneNumber,
          name: user.name,
          companyName: user.companyName,
        );
        
        if (response.success) {
          // Remove from local list
          _sessionList.removeWhere((session) => session.sessionId == sessionId);
          await StorageService.saveSessionList(_sessionList);
          
          // Clear all chat messages for this session from device
          await StorageService.clearMessages(sessionId);
          
          // Clear session metadata from device
          await StorageService.clearSessionData(sessionId);
          
          // If deleting current session, clear it
          if (_currentSessionId == sessionId) {
            _currentSessionId = null;
            _currentSessionData = null;
          }
          
          return true;
        } else {
          print('Failed to delete session: ${response.message}');
          return false;
        }
      }
      return false;
    } catch (e) {
      print('Error deleting session: $e');
      return false;
    }
  }
  
  // Switch to different session
  static Future<bool> switchToSession(String sessionId) async {
    try {
      // Save current session ID
      _currentSessionId = sessionId;
      await _saveSessionId(sessionId);
      
      // Load session data for this session
      final sessionData = _sessionList.firstWhere(
        (session) => session.sessionId == sessionId,
        orElse: () => SessionData(
          sessionId: sessionId,
          title: 'Session',
          description: '',
        ),
      );
      
      _currentSessionData = sessionData;
      await StorageService.saveSessionData(sessionData);
      
      return true;
    } catch (e) {
      print('Error switching session: $e');
      return false;
    }
  }
  
  // Initialize with session sync
  static Future<void> initializeWithSync() async {
    await initialize();
    await loadSessionListFromCache();
    
    // Try to sync with backend in background
    syncSessionList().then((success) {
      if (success) {
        print('Session list synced successfully');
      }
    });
  }

  // Helper method to sort sessions by date (most recent first)
  static void _sortSessionsByDate(List<SessionData> sessions) {
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
}