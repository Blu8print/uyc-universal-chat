import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/endpoint_model.dart';
import 'session_service.dart';
import 'storage_service.dart';

class EndpointService {
  static const String _endpointsKey = 'endpoints_list';
  static const String _currentEndpointKey = 'current_endpoint_id';

  static Endpoint? _currentEndpoint;
  static List<Endpoint> _endpointsList = [];

  // Get current endpoint
  static Endpoint? get currentEndpoint => _currentEndpoint;

  // Get endpoints list
  static List<Endpoint> get endpointsList => _endpointsList;

  // Initialize service
  static Future<void> initialize() async {
    await loadEndpoints();
    await loadCurrentEndpoint();
  }

  // Generate UUID-like ID
  static String generateId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp * 1000).toRadixString(36);
    return 'ep_$random';
  }

  // Save endpoints list
  static Future<bool> saveEndpoints(List<Endpoint> endpoints) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final endpointsJson = jsonEncode(
        endpoints.map((e) => e.toJson()).toList(),
      );
      await prefs.setString(_endpointsKey, endpointsJson);
      _endpointsList = endpoints;
      return true;
    } catch (e) {
      debugPrint('Error saving endpoints: $e');
      return false;
    }
  }

  // Load endpoints list
  static Future<List<Endpoint>> loadEndpoints() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final endpointsJson = prefs.getString(_endpointsKey);

      if (endpointsJson != null) {
        final List<dynamic> endpointsList = jsonDecode(endpointsJson);
        _endpointsList = endpointsList
            .map((json) => Endpoint.fromJson(json))
            .toList();
        return _endpointsList;
      }
      _endpointsList = [];
      return [];
    } catch (e) {
      debugPrint('Error loading endpoints: $e');
      _endpointsList = [];
      return [];
    }
  }

  // Add new endpoint
  static Future<bool> addEndpoint(Endpoint endpoint) async {
    try {
      await loadEndpoints();
      _endpointsList.add(endpoint);
      return await saveEndpoints(_endpointsList);
    } catch (e) {
      debugPrint('Error adding endpoint: $e');
      return false;
    }
  }

  // Update endpoint
  static Future<bool> updateEndpoint(Endpoint endpoint) async {
    try {
      await loadEndpoints();
      final index = _endpointsList.indexWhere((e) => e.id == endpoint.id);
      if (index != -1) {
        _endpointsList[index] = endpoint;

        // Update current endpoint if it's the one being edited
        if (_currentEndpoint?.id == endpoint.id) {
          _currentEndpoint = endpoint;
          await setCurrentEndpoint(endpoint);
        }

        return await saveEndpoints(_endpointsList);
      }
      return false;
    } catch (e) {
      debugPrint('Error updating endpoint: $e');
      return false;
    }
  }

  // Delete endpoint
  static Future<bool> deleteEndpoint(String endpointId) async {
    try {
      // Clear chat history first
      await clearEndpointHistory(endpointId);

      await loadEndpoints();
      _endpointsList.removeWhere((e) => e.id == endpointId);

      // Clear current endpoint if it's the one being deleted
      if (_currentEndpoint?.id == endpointId) {
        _currentEndpoint = null;
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_currentEndpointKey);
      }

      return await saveEndpoints(_endpointsList);
    } catch (e) {
      debugPrint('Error deleting endpoint: $e');
      return false;
    }
  }

  // Set current endpoint
  static Future<bool> setCurrentEndpoint(Endpoint endpoint) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currentEndpointKey, endpoint.id);
      _currentEndpoint = endpoint;
      return true;
    } catch (e) {
      debugPrint('Error setting current endpoint: $e');
      return false;
    }
  }

  // Load current endpoint
  static Future<Endpoint?> loadCurrentEndpoint() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentId = prefs.getString(_currentEndpointKey);

      if (currentId != null) {
        await loadEndpoints();
        _currentEndpoint = _endpointsList.firstWhere(
          (e) => e.id == currentId,
          orElse: () => _endpointsList.isNotEmpty ? _endpointsList.first : throw Exception(),
        );
        return _currentEndpoint;
      }
      return null;
    } catch (e) {
      debugPrint('Error loading current endpoint: $e');
      return null;
    }
  }

  // Get or create session for endpoint
  static Future<String> getOrCreateSessionForEndpoint(Endpoint endpoint) async {
    try {
      // Check if endpoint already has a session
      if (endpoint.sessionId != null) {
        // Load existing session via StorageService
        final session = await StorageService.loadSessionData(endpoint.sessionId!);
        if (session != null) {
          return endpoint.sessionId!;
        }
      }

      // Create new session using SessionService
      final sessionId = await SessionService.startNewSession();

      // Store session ID in endpoint
      final updatedEndpoint = endpoint.copyWith(sessionId: sessionId);
      await updateEndpoint(updatedEndpoint);

      return sessionId;
    } catch (e) {
      debugPrint('Error getting/creating session for endpoint: $e');
      // Return a new session ID as fallback
      return await SessionService.startNewSession();
    }
  }

  // Clear chat history for endpoint
  static Future<bool> clearEndpointHistory(String endpointId) async {
    try {
      await loadEndpoints();
      final endpoint = _endpointsList.firstWhere((e) => e.id == endpointId);

      if (endpoint.sessionId != null) {
        // Clear messages using existing StorageService
        await StorageService.clearMessages(endpoint.sessionId!);
        await StorageService.clearSessionData(endpoint.sessionId!);

        // Remove session ID from endpoint
        final updatedEndpoint = endpoint.copyWith(sessionId: null);
        await updateEndpoint(updatedEndpoint);
      }

      return true;
    } catch (e) {
      debugPrint('Error clearing endpoint history: $e');
      return false;
    }
  }

  // Clear all endpoints
  static Future<bool> clearAllEndpoints() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_endpointsKey);
      await prefs.remove(_currentEndpointKey);
      _endpointsList = [];
      _currentEndpoint = null;
      return true;
    } catch (e) {
      debugPrint('Error clearing endpoints: $e');
      return false;
    }
  }
}
