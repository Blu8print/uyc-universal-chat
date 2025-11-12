import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/auth_service.dart';
import '../services/session_service.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> with WidgetsBindingObserver {
  static const String _basicAuth = 'SystemArchitect:A\$pp_S3cr3t';
  static const String _n8nSessionsUrl =
      'https://automation.kwaaijongens.nl/webhook/sessions';

  List<SessionData> _sessions = [];
  bool _isLoadingSessions = true;
  bool _isRefreshing = false;
  String _userName = '';
  DateTime? _lastRefresh;
  String _selectedFilter = 'persoonlijk'; // 'persoonlijk' or 'alle'

  // Getter for filtered sessions
  List<SessionData> get _filteredSessions {
    if (_selectedFilter == 'persoonlijk') {
      final currentUser = AuthService.currentUser;
      if (currentUser != null) {
        return _sessions
            .where((session) => session.phoneNumber == currentUser.phoneNumber)
            .toList();
      }
    }
    return _sessions;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _configureStatusBar();
    _initializeScreen();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _refreshSessionsIfNeeded();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh sessions when returning to this screen
    _refreshSessionsIfNeeded();
  }

  void _configureStatusBar() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  Future<void> _initializeScreen() async {
    // Get user name
    final user = AuthService.currentUser;
    if (user != null) {
      setState(() {
        _userName = user.name;
      });
    }

    // Load sessions
    await _loadSessions();
  }

  Future<void> _loadSessions() async {
    try {
      setState(() {
        _isLoadingSessions = true;
      });

      // Load sessions from cache first (for immediate display)
      await SessionService.loadSessionListFromCache();
      if (mounted) {
        setState(() {
          _sessions = SessionService.sessionList;
          _isLoadingSessions = false; // Show cached data immediately
        });
      }

      // Try to sync with backend and update with fresh data
      if (mounted) {
        setState(() {
          _isRefreshing = true;
        });
      }

      final success = await SessionService.syncSessionList();
      if (success && mounted) {
        setState(() {
          _sessions =
              SessionService
                  .sessionList; // Overwrite with server data (could be empty)
          _lastRefresh = DateTime.now();
        });
      }
    } catch (e) {
      debugPrint('Error loading sessions: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSessions = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _refreshSessionsIfNeeded() async {
    // Don't refresh too frequently (minimum 30 seconds between refreshes)
    if (_lastRefresh != null &&
        DateTime.now().difference(_lastRefresh!).inSeconds < 30) {
      return;
    }

    // Don't refresh if already loading or refreshing
    if (_isLoadingSessions || _isRefreshing) {
      return;
    }

    await _refreshSessions();
  }

  Future<void> _refreshSessions() async {
    try {
      if (mounted) {
        setState(() {
          _isRefreshing = true;
        });
      }

      // Try to sync with backend
      final success = await SessionService.syncSessionList();
      if (success && mounted) {
        setState(() {
          _sessions = SessionService.sessionList;
          _lastRefresh = DateTime.now();
        });
      }
    } catch (e) {
      debugPrint('Error refreshing sessions: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _navigateToAction(String actionType) async {
    // Map actionType to chatType
    String? chatType;
    switch (actionType) {
      case 'project':
        chatType = 'project_doorgeven';
        break;
      case 'knowledge':
        chatType = 'vakkennis_delen';
        break;
      case 'social':
        chatType = 'social_media';
        break;
    }

    // Always start a new session for action buttons with the chatType
    final sessionId = await SessionService.resetSession(chatType: chatType);

    // Validate session was created before navigating
    if (sessionId.isNotEmpty && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ChatScreen(actionContext: actionType),
        ),
      );
    }
  }

  Future<void> _openSession(SessionData session) async {
    // Switch to the selected session
    final success = await SessionService.switchToSession(session.sessionId);
    if (success && mounted) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (context) => const ChatScreen()));
    }
  }

  String _getBasicAuthHeader() {
    final authBytes = utf8.encode(_basicAuth);
    return 'Basic ${base64Encode(authBytes)}';
  }

  Future<bool> _deleteSession(SessionData session) async {
    try {
      final user = AuthService.currentUser;
      final requestBody = {
        'method': 'delete',
        'sessionId': session.sessionId,
        'phoneNumber': user?.phone ?? '',
        'name': user?.name ?? '',
        'companyName': user?.companyName ?? '',
      };

      // Add chatType if available
      if (session.chatType != null) {
        requestBody['chatType'] = session.chatType!;
      }

      final response = await http
          .post(
            Uri.parse(_n8nSessionsUrl),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': _getBasicAuthHeader(),
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // Remove from local list
        setState(() {
          _sessions.removeWhere((s) => s.sessionId == session.sessionId);
        });
        // Update SessionService cache
        await SessionService.syncSessionList();
        return true;
      } else {
        debugPrint('Failed to delete session: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('Error deleting session: $e');
      return false;
    }
  }

  Future<void> _togglePin(SessionData session) async {
    try {
      final success =
          session.isPinned
              ? await SessionService.unpinSession(session.sessionId)
              : await SessionService.pinSession(session.sessionId);

      if (success) {
        // Refresh the session list to reflect the changes
        await _refreshSessions();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                session.isPinned
                    ? 'Kan sessie niet losmaken. Probeer het opnieuw.'
                    : 'Kan sessie niet vastmaken. Probeer het opnieuw.',
              ),
              backgroundColor: const Color(0xFFCC0001),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error toggling pin: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Er is een fout opgetreden. Probeer het opnieuw.'),
            backgroundColor: Color(0xFFCC0001),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        extendBodyBehindAppBar: true,
        body: SafeArea(
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Custom Header
                _buildHeader(),

                // Content Area
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Greeting
                        _buildGreeting(),

                        const SizedBox(height: 25),

                        // Action Buttons
                        _buildActionButtons(),

                        const SizedBox(height: 30),

                        // Updates Section
                        _buildUpdatesSection(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SvgPicture.asset(
            'logo.svg',
            height: 40,
            fit: BoxFit.contain,
            allowDrawingOutsideViewBox: true,
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuSelection,
            icon: Container(
              padding: const EdgeInsets.all(8.0),
              child: const Text(
                '⋮',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF374151),
                  height: 1.0,
                ),
              ),
            ),
            offset: const Offset(0, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            color: Colors.white,
            elevation: 8,
            itemBuilder:
                (BuildContext context) => [
                  PopupMenuItem<String>(
                    value: 'help_support',
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: const Row(
                        children: [
                          Icon(Icons.help_center, color: Colors.grey, size: 20),
                          SizedBox(width: 12),
                          Text(
                            'Helpdesk (FAQ\'s)',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'call_kwaaijongens',
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: const Row(
                        children: [
                          Icon(Icons.phone, color: Colors.grey, size: 20),
                          SizedBox(width: 12),
                          Text(
                            'Bel Kwaaijongens',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'privacy_policy',
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: const Row(
                        children: [
                          Icon(Icons.shield, color: Colors.grey, size: 20),
                          SizedBox(width: 12),
                          Text(
                            'Privacyverklaring',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'about_app',
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: const Row(
                        children: [
                          Icon(Icons.info, color: Colors.grey, size: 20),
                          SizedBox(width: 12),
                          Text(
                            'Over deze app',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
          ),
        ],
      ),
    );
  }

  Widget _buildGreeting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hallo ${_userName.isNotEmpty ? _userName : 'daar'}!',
          style: const TextStyle(
            fontSize: 22,
            color: Color(0xFFCC0001),
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Wat wil je vandaag doen?',
          style: TextStyle(
            fontSize: 28,
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        _buildActionButton(
          icon: Icons.check_circle_outline,
          title: 'Project doorgeven',
          description: 'Mooi project gerealiseerd? Vertel meer!',
          onTap: () => _navigateToAction('project'),
        ),
        const SizedBox(height: 15),
        _buildActionButton(
          icon: Icons.code,
          title: 'Vakkennis delen',
          description: 'Jij deelt je kennis, wij maken de blog!',
          onTap: () => _navigateToAction('knowledge'),
        ),
        const SizedBox(height: 15),
        _buildActionButton(
          icon: Icons.play_arrow,
          title: 'Social media',
          description: 'Foto + tekst, wij maken je post!',
          onTap: () => _navigateToAction('social'),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF0F0F0)),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon container
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFCC0001),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),

            const SizedBox(width: 15),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdatesSection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFCC0001),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Wijzig of vul aan',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Nieuwe inzichten, informatie of beelden?\nVoeg ze toe aan je eerdere inzending.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),

          // Filter Tabs
          _buildFilterTabs(),

          // Sessions List
          Container(
            constraints: const BoxConstraints(maxHeight: 400),
            child:
                _isLoadingSessions
                    ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    )
                    : _filteredSessions.isEmpty
                    ? Container(
                      padding: const EdgeInsets.all(40),
                      child: RefreshIndicator(
                        onRefresh: _refreshSessions,
                        color: const Color(0xFFCC0001),
                        backgroundColor: Colors.white,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Container(
                            height: 200,
                            alignment: Alignment.center,
                            child: Text(
                              'Nog geen eerdere inzendingen.\nMaak je eerste project, blog of social media post!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    : RefreshIndicator(
                      onRefresh: _refreshSessions,
                      color: const Color(0xFFCC0001),
                      backgroundColor: Colors.white,
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(
                          left: 20,
                          right: 10,
                          bottom: 20,
                        ),
                        itemCount: _filteredSessions.length,
                        itemBuilder: (context, index) {
                          final session = _filteredSessions[index];
                          return _buildSessionItem(session);
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
      child: Row(
        children: [
          _buildTabButton('Persoonlijk', 'persoonlijk'),
          const SizedBox(width: 10),
          _buildTabButton('Alle', 'alle'),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, String filterValue) {
    final bool isActive = _selectedFilter == filterValue;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filterValue;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          border: Border.all(
            color:
                isActive ? Colors.white : Colors.white.withValues(alpha: 0.3),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color:
                isActive
                    ? const Color(0xFFCC0001)
                    : Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ),
    );
  }

  Widget _buildSessionItem(SessionData session) {
    return Dismissible(
      key: Key(session.sessionId),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 20),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFCC0001),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.delete, color: Colors.white, size: 32),
      ),
      confirmDismiss: (direction) async {
        // Show confirmation dialog before deleting
        return await showDialog<bool>(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Sessie verwijderen'),
                  content: const Text(
                    'Weet je zeker dat je deze sessie wilt verwijderen?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Annuleren'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFCC0001),
                      ),
                      child: const Text('Verwijderen'),
                    ),
                  ],
                );
              },
            ) ??
            false;
      },
      onDismissed: (direction) async {
        final success = await _deleteSession(session);
        if (!success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Kan sessie niet verwijderen. Probeer het opnieuw.',
              ),
              backgroundColor: Color(0xFFCC0001),
            ),
          );
          // Refresh the list to restore the item
          await _refreshSessions();
        }
      },
      child: GestureDetector(
        onTap: () => _openSession(session),
        child: Stack(
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.only(bottom: 20),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white24, width: 1),
                ),
              ),
              child: Row(
                children: [
                  // Session thumbnail/icon
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child:
                        session.thumbnail != null &&
                                session.thumbnail!.isNotEmpty
                            ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                session.thumbnail!,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.folder_outlined,
                                    color: Colors.white,
                                    size: 24,
                                  );
                                },
                              ),
                            )
                            : const Icon(
                              Icons.folder_outlined,
                              color: Colors.white,
                              size: 24,
                            ),
                  ),

                  const SizedBox(width: 15),

                  // Session content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (session.lastActivity != null)
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    session.emailSent
                                        ? 'Aangeleverd: ${_formatDate(session.lastActivity!)}'
                                        : 'Gestart: ${_formatDate(session.lastActivity!)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                                  ),
                                ),
                                if (session.emailSent) ...[
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ],
                              ],
                            ),
                          const SizedBox(height: 4),
                          Text(
                            (session.title.startsWith('newsession_') ||
                                    session.title.startsWith('session_'))
                                ? _formatChatType(session.chatType)
                                : session.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            session.emailSent
                                ? 'Open de aangeleverde input >'
                                : 'In behandeling - open chat >',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Pin icon in top-right corner (only show if email not sent)
            if (!session.emailSent)
              Positioned(
                top: 0,
                right: 4,
                child: GestureDetector(
                  onTap: () => _togglePin(session),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child: CustomPaint(
                      size: const Size(16, 16),
                      painter: PinIconPainter(isPinned: session.isPinned),
                    ),
                  ),
                ),
              ),

            // Hourglass indicator when refreshing
            if (_isRefreshing)
              const Positioned(
                bottom: 24, // Positioned above the border line
                right: 4,
                child: Icon(
                  Icons.hourglass_empty,
                  size: 14,
                  color: Colors.white70,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
    } catch (e) {
      return 'Onbekende datum';
    }
  }

  String _formatChatType(String? chatType) {
    if (chatType == null) return 'Chat';

    switch (chatType) {
      case 'project_doorgeven':
        return 'Project doorgeven';
      case 'vakkennis_delen':
        return 'Vakkennis delen';
      case 'social_media':
        return 'Social media';
      default:
        // Fallback: capitalize and replace underscores with spaces
        return chatType.replaceAll('_', ' ');
    }
  }

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'help_support':
        _openHelpSupport();
        break;
      case 'call_kwaaijongens':
        _callKwaaijongens();
        break;
      case 'privacy_policy':
        _openPrivacyPolicy();
        break;
      case 'about_app':
        _showAboutDialog();
        break;
    }
  }

  Future<void> _callKwaaijongens() async {
    final Uri phoneUri = Uri.parse('tel:+31853307500');
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kan telefoon app niet openen')),
        );
      }
    }
  }

  Future<void> _openPrivacyPolicy() async {
    final Uri privacyUri = Uri.parse('https://kwaaijongens.nl/privacy-app');
    if (await canLaunchUrl(privacyUri)) {
      await launchUrl(privacyUri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kan browser niet openen')),
        );
      }
    }
  }

  Future<void> _openHelpSupport() async {
    final Uri supportUri = Uri.parse('https://kwaaijongens.nl/app-support');
    if (await canLaunchUrl(supportUri)) {
      await launchUrl(supportUri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kan browser niet openen')),
        );
      }
    }
  }

  Future<void> _showAboutDialog() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();

    if (mounted) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: Color(0xFFCC0001),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.build,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // App name
                  const Text(
                    'Kwaaijongens App',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFCC0001),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Version
                  Text(
                    'Versie ${packageInfo.version} (${packageInfo.buildNumber})',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  const Text(
                    'De officiële app voor het delen van projecten, vakkennis en social media content.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                  const SizedBox(height: 24),

                  // Contact details
                  GestureDetector(
                    onTap: () => _callKwaaijongens(),
                    child: const Text(
                      '085 - 330 7500',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFFCC0001),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final Uri emailUri = Uri.parse(
                        'mailto:app@kwaaijongens.nl',
                      );
                      if (await canLaunchUrl(emailUri)) {
                        await launchUrl(emailUri);
                      }
                    },
                    child: const Text(
                      'app@kwaaijongens.nl',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFFCC0001),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Close button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCC0001),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Sluiten'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
  }
}

// Custom painter for pin icon
class PinIconPainter extends CustomPainter {
  final bool isPinned;

  PinIconPainter({required this.isPinned});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..style = PaintingStyle.fill
          ..color =
              isPinned
                  ? Colors.white.withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.3);

    final path = Path();

    // Scale the SVG path to fit the size
    final scaleX = size.width / 24;
    final scaleY = size.height / 24;

    // SVG path: M16,12V4H17V2H7V4H8V12L6,14V16H11.2V22H12.8V16H18V14L16,12Z
    path.moveTo(16 * scaleX, 12 * scaleY);
    path.lineTo(16 * scaleX, 4 * scaleY);
    path.lineTo(17 * scaleX, 4 * scaleY);
    path.lineTo(17 * scaleX, 2 * scaleY);
    path.lineTo(7 * scaleX, 2 * scaleY);
    path.lineTo(7 * scaleX, 4 * scaleY);
    path.lineTo(8 * scaleX, 4 * scaleY);
    path.lineTo(8 * scaleX, 12 * scaleY);
    path.lineTo(6 * scaleX, 14 * scaleY);
    path.lineTo(6 * scaleX, 16 * scaleY);
    path.lineTo(11.2 * scaleX, 16 * scaleY);
    path.lineTo(11.2 * scaleX, 22 * scaleY);
    path.lineTo(12.8 * scaleX, 22 * scaleY);
    path.lineTo(12.8 * scaleX, 16 * scaleY);
    path.lineTo(18 * scaleX, 16 * scaleY);
    path.lineTo(18 * scaleX, 14 * scaleY);
    path.lineTo(16 * scaleX, 12 * scaleY);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(PinIconPainter oldDelegate) {
    return oldDelegate.isPinned != isPinned;
  }
}
