// UYC - Unlock Your Cloud
// Dynamic Endpoint List Screen

import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/endpoint_model.dart';
import '../services/endpoint_service.dart';
import '../services/session_service.dart';
import '../services/storage_service.dart';
import '../widgets/app_drawer.dart';
import 'chat_screen.dart';
import 'endpoint_editor_screen.dart';

class EndpointListScreen extends StatefulWidget {
  const EndpointListScreen({super.key});

  @override
  State<EndpointListScreen> createState() => _EndpointListScreenState();
}

class _EndpointListScreenState extends State<EndpointListScreen> {
  List<Endpoint> _endpoints = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEndpoints();
  }

  Future<void> _loadEndpoints() async {
    setState(() => _isLoading = true);
    final endpoints = await EndpointService.loadEndpoints();
    setState(() {
      _endpoints = endpoints;
      _isLoading = false;
    });
  }

  Future<void> _connectToEndpoint(Endpoint endpoint) async {
    // Set as current endpoint
    await EndpointService.setCurrentEndpoint(endpoint);

    // Get or create session for this endpoint
    final sessionId = await EndpointService.getOrCreateSessionForEndpoint(endpoint);

    // Load the session into SessionService
    final sessionData = await StorageService.loadSessionData(sessionId);
    if (sessionData != null) {
      // Set as current session
      await SessionService.loadSession(sessionData);
    } else {
      // If no session data exists, initialize a new one
      await SessionService.initialize();
    }

    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ChatScreen(endpoint: endpoint),
        ),
      );
    }
  }

  Future<void> _deleteEndpoint(Endpoint endpoint) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.primary,
        title: Text(
          'Delete Endpoint?',
          style: TextStyle(color: AppColors.textLight),
        ),
        content: Text(
          'Remove "${endpoint.name}"? This cannot be undone.',
          style: TextStyle(color: AppColors.textLight.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textLight),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Delete',
              style: TextStyle(color: AppColors.accent),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await EndpointService.deleteEndpoint(endpoint.id);
      _loadEndpoints();
    }
  }

  Future<void> _clearEndpointHistory(Endpoint endpoint) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.primary,
        title: Text(
          'Clear Chat History?',
          style: TextStyle(color: AppColors.textLight),
        ),
        content: Text(
          'Delete all messages for "${endpoint.name}"? This cannot be undone.',
          style: TextStyle(color: AppColors.textLight.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textLight),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Clear',
              style: TextStyle(color: AppColors.accent),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await EndpointService.clearEndpointHistory(endpoint.id);
      if (mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chat history cleared for ${endpoint.name}'),
            backgroundColor: AppColors.accent,
          ),
        );
        _loadEndpoints();
      }
    }
  }

  void _showEndpointOptions(Endpoint endpoint) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.primary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit, color: AppColors.textLight),
              title: Text(
                'Edit',
                style: TextStyle(color: AppColors.textLight),
              ),
              onTap: () async {
                Navigator.pop(context);
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => EndpointEditorScreen(
                      endpoint: endpoint,
                    ),
                  ),
                );
                if (result == true) {
                  _loadEndpoints(); // Reload list after save
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_sweep, color: AppColors.textLight),
              title: Text(
                'Clear Chat History',
                style: TextStyle(color: AppColors.textLight),
              ),
              onTap: () {
                Navigator.pop(context);
                _clearEndpointHistory(endpoint);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: AppColors.accent),
              title: Text(
                'Delete',
                style: TextStyle(color: AppColors.accent),
              ),
              onTap: () {
                Navigator.pop(context);
                _deleteEndpoint(endpoint);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      drawer: const AppDrawer(currentRoute: 'endpoints'),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0x1A000000), // 10% black overlay
                border: Border(
                  bottom: BorderSide(
                    color: Color(0x1AFFFFFF), // 10% white
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Menu button
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Builder(
                      builder: (context) => IconButton(
                        icon: Icon(Icons.menu, color: AppColors.textLight),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'ENDPOINTS',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                          color: AppColors.textLight,
                        ),
                      ),
                    ),
                  ),
                  // FAB (+) button
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.add, color: Colors.white),
                      onPressed: () async {
                        final result = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const EndpointEditorScreen(),
                          ),
                        );
                        if (result == true) {
                          _loadEndpoints(); // Reload list after save
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accent,
                      ),
                    )
                  : _endpoints.isEmpty
                      ? _buildEmptyState()
                      : _buildEndpointList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(50),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0x14FFFFFF), // 8% white
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.add,
                size: 32,
                color: AppColors.textLight.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No endpoints yet',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textLight.withValues(alpha: 0.4),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to connect a new\nn8n chat endpoint',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textLight.withValues(alpha: 0.4),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEndpointList() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Section label
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 14),
          child: Text(
            'SAVED CONNECTIONS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 3,
              color: AppColors.textLight.withValues(alpha: 0.4),
            ),
          ),
        ),

        // Endpoint cards
        ..._endpoints.map((endpoint) => _buildEndpointCard(endpoint)),
      ],
    );
  }

  Widget _buildEndpointCard(Endpoint endpoint) {
    // Determine icon emoji based on URL
    String iconEmoji = '⚡'; // default
    Color iconColor = const Color(0xFFea4b71); // n8n pink
    if (endpoint.url.contains('openai')) {
      iconEmoji = '🤖';
      iconColor = const Color(0xFF10a37f);
    } else if (endpoint.url.contains('python') || endpoint.url.contains('py')) {
      iconEmoji = '🐍';
      iconColor = const Color(0xFF3776ab);
    }

    return GestureDetector(
      onTap: () => _connectToEndpoint(endpoint),
      onLongPress: () => _showEndpointOptions(endpoint),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0x14FFFFFF), // 8% white
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: icon, name, URL, status
            Row(
              children: [
                // Icon
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        iconColor,
                        iconColor.withValues(alpha: 0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      iconEmoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Name and URL
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        endpoint.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        endpoint.url,
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: AppColors.textLight.withValues(alpha: 0.4),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Status indicator (placeholder - always online for now)
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4ade80), // green
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4ade80).withValues(alpha: 0.4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Bottom row: tags and metadata
            Row(
              children: [
                // n8n Chat tag
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'n8n Chat',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: AppColors.accent,
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // Auth type indicator
                if (endpoint.authType != 'none')
                  Icon(
                    Icons.lock,
                    size: 12,
                    color: AppColors.textLight.withValues(alpha: 0.4),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
