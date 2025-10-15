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
  static const String _n8nSessionsUrl = 'https://automation.kwaaijongens.nl/webhook/sessions';

  List<SessionData> _sessions = [];
  bool _isLoadingSessions = true;
  bool _isRefreshing = false;
  String _userName = '';
  DateTime? _lastRefresh;

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
          _sessions = SessionService.sessionList; // Overwrite with server data (could be empty)
          _lastRefresh = DateTime.now();
        });
      }
    } catch (e) {
      print('Error loading sessions: $e');
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
      print('Error refreshing sessions: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _navigateToAction(String actionType) async {
    // Always start a new session for action buttons
    await SessionService.resetSession();
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatScreen(actionContext: actionType),
      ),
    );
  }

  Future<void> _openSession(SessionData session) async {
    // Switch to the selected session
    final success = await SessionService.switchToSession(session.sessionId);
    if (success && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const ChatScreen(),
        ),
      );
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

      final response = await http.post(
        Uri.parse(_n8nSessionsUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': _getBasicAuthHeader(),
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // Remove from local list
        setState(() {
          _sessions.removeWhere((s) => s.sessionId == session.sessionId);
        });
        // Update SessionService cache
        await SessionService.syncSessionList();
        return true;
      } else {
        print('Failed to delete session: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error deleting session: $e');
      return false;
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
        border: Border(
          bottom: BorderSide(color: Color(0xFFF0F0F0), width: 1),
        ),
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
            itemBuilder: (BuildContext context) => [
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
                        style: TextStyle(fontSize: 14, color: Colors.black87),
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
                        style: TextStyle(fontSize: 14, color: Colors.black87),
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
                        style: TextStyle(fontSize: 14, color: Colors.black87),
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
                        style: TextStyle(fontSize: 14, color: Colors.black87),
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
              child: Icon(
                icon,
                color: Colors.white,
                size: 24,
              ),
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
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
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
          
          // Sessions List
          Container(
            constraints: const BoxConstraints(maxHeight: 400),
            child: _isLoadingSessions
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    ),
                  )
                : _sessions.isEmpty
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
                          itemCount: _sessions.length,
                          itemBuilder: (context, index) {
                            final session = _sessions[index];
                            return _buildSessionItem(session);
                          },
                        ),
                      ),
          ),
        ],
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
        child: const Icon(
          Icons.delete,
          color: Colors.white,
          size: 32,
        ),
      ),
      confirmDismiss: (direction) async {
        // Show confirmation dialog before deleting
        return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Sessie verwijderen'),
              content: const Text('Weet je zeker dat je deze sessie wilt verwijderen?'),
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
        ) ?? false;
      },
      onDismissed: (direction) async {
        final success = await _deleteSession(session);
        if (!success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kan sessie niet verwijderen. Probeer het opnieuw.'),
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
                  bottom: BorderSide(
                    color: Colors.white24,
                    width: 1,
                  ),
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
                    child: const Icon(
                      Icons.folder_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),

                  const SizedBox(width: 15),

                  // Session content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (session.lastActivity != null)
                          Text(
                            'Aangeleverd: ${_formatDate(session.lastActivity!)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          session.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Open de aangeleverde input >',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
          const SnackBar(
            content: Text('Kan telefoon app niet openen'),
          ),
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
          const SnackBar(
            content: Text('Kan browser niet openen'),
          ),
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
          const SnackBar(
            content: Text('Kan browser niet openen'),
          ),
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
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Description
                  const Text(
                    'De officiële app voor het delen van projecten, vakkennis en social media content.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
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
                      final Uri emailUri = Uri.parse('mailto:app@kwaaijongens.nl');
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