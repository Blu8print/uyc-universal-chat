// UYC - Unlock Your Cloud
// Sessions Screen - Main screen showing all chat sessions

import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/endpoint_model.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../services/endpoint_service.dart';
import '../widgets/app_drawer.dart';
import 'chat_screen.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  List<SessionData> _sessions = [];
  List<Endpoint> _endpoints = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);

    // Load sessions from cache
    await SessionService.loadSessionListFromCache();

    // Get session list
    _sessions = SessionService.sessionList;

    // Load endpoints
    await EndpointService.loadEndpoints();
    _endpoints = EndpointService.endpointsList;

    setState(() => _isLoading = false);

    // Background sync (don't await)
    SessionService.syncSessionList();
  }

  Endpoint? _getEndpointForSession(SessionData session) {
    try {
      // TODO Step 2: When supporting multiple sessions per endpoint,
      // match on session.endpointId instead of ep.sessionId == session.sessionId
      return _endpoints.firstWhere(
        (ep) => ep.sessionId == session.sessionId,
      );
    } catch (e) {
      return null;
    }
  }

  String _formatTimestamp(DateTime? dateTime) {
    if (dateTime == null) return '';

    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  Future<void> _openSession(SessionData session, Endpoint? endpoint) async {
    final success = await SessionService.switchToSession(session.sessionId);
    if (success) {
      // TODO Step 2: When supporting multiple sessions per endpoint,
      // endpoint should come from session.endpointId, not matched by sessionId
      if (endpoint != null) {
        await EndpointService.setCurrentEndpoint(endpoint);
      }
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(endpoint: endpoint),
          ),
        );
        // User returned from ChatScreen - refresh to show updated timestamps/counts
        _loadSessions();
      }
    }
  }

  void _showEndpointPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF155268),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'New Chat',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose an endpoint to start a conversation',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textLight.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
            // Endpoint list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: _endpoints.length,
                itemBuilder: (context, index) {
                  final endpoint = _endpoints[index];
                  return _buildEndpointCard(endpoint);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEndpointCard(Endpoint endpoint) {
    // Determine icon and color based on URL
    String icon = '⚡';
    Color iconColor = const Color(0xFFea4b71);

    if (endpoint.url.contains('openai')) {
      icon = '🤖';
      iconColor = const Color(0xFF10a37f);
    } else if (endpoint.url.contains('python')) {
      icon = '🐍';
      iconColor = const Color(0xFF3776ab);
    }

    return GestureDetector(
      onTap: () => _createNewSession(endpoint),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0x14FFFFFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.transparent, width: 2),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [iconColor, iconColor.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(icon, style: const TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 14),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    endpoint.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textLight,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    endpoint.url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: AppColors.textLight.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
            // Status indicator (online - green dot)
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFF4ade80),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4ade80).withValues(alpha: 0.4),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Arrow
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppColors.textLight.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createNewSession(Endpoint endpoint) async {
    Navigator.pop(context); // Close bottom sheet

    // Always start a fresh session
    await SessionService.startNewSession();

    // Set as current endpoint
    await EndpointService.setCurrentEndpoint(endpoint);

    // Navigate to ChatScreen
    if (mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(endpoint: endpoint),
        ),
      );
      // User returned from ChatScreen - refresh to show updated timestamps/counts
      _loadSessions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      drawer: const AppDrawer(currentRoute: 'sessions'),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        onPressed: _showEndpointPicker,
        child: Icon(
          Icons.add,
          color: AppColors.textLight,
          size: 28,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildFilterTabs(),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accent,
                      ),
                    )
                  : _sessions.isEmpty
                      ? _buildEmptyState()
                      : _buildSessionList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0x1A000000), // 10% black overlay
        border: Border(
          bottom: BorderSide(color: Color(0x1AFFFFFF)),
        ),
      ),
      child: Row(
        children: [
          // Menu button - opens drawer
          Builder(
            builder: (context) => IconButton(
              icon: Icon(Icons.menu, color: AppColors.textLight),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          // Title
          Expanded(
            child: Text(
              'SESSIONS',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
                color: AppColors.textLight,
              ),
            ),
          ),
          // Search button (placeholder)
          IconButton(
            icon: Icon(Icons.search, color: AppColors.textLight),
            onPressed: () {}, // TODO: Implement search
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      child: Row(
        children: ['All', 'Today', 'This Week', 'Archived'].map((filter) {
          final isActive = _selectedFilter == filter;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = filter),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.accent
                    : const Color(0x0DFFFFFF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive
                      ? AppColors.accent
                      : const Color(0x1AFFFFFF),
                ),
              ),
              child: Text(
                filter,
                style: TextStyle(
                  fontSize: 14,
                  color: isActive
                      ? AppColors.textLight
                      : AppColors.textLight.withValues(alpha: 0.7),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSessionList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _sessions.length,
      itemBuilder: (context, index) {
        final session = _sessions[index];
        final endpoint = _getEndpointForSession(session);
        return _buildSessionCard(session, endpoint);
      },
    );
  }

  Widget _buildSessionCard(SessionData session, Endpoint? endpoint) {
    final title = session.title.isNotEmpty ? session.title : 'New Chat';
    final preview = session.getLastMessagePreview() ?? 'No messages yet';
    final timestamp = _formatTimestamp(
      DateTime.tryParse(session.lastActivity ?? session.createdAt ?? ''),
    );
    final messageCount = session.messageCount;

    return GestureDetector(
      onTap: () => _openSession(session, endpoint),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0x14FFFFFF), // 8% white
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.transparent, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: title + timestamp
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textLight,
                        ),
                      ),
                      if (endpoint != null) ...[
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            endpoint.name,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  timestamp,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textLight.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
            // Preview
            const SizedBox(height: 8),
            Text(
              preview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textLight.withValues(alpha: 0.6),
              ),
            ),
            // Metadata: message count
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 14,
                  color: AppColors.textLight.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 5),
                Text(
                  '$messageCount messages',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textLight.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0x14FFFFFF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.add,
              size: 40,
              color: AppColors.textLight.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No sessions yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to start a new chat with an endpoint',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textLight.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
