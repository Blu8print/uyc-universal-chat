import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import '../services/audio_recording_service.dart';
import '../services/session_service.dart';
import '../services/storage_service.dart';
import '../services/attachment_service.dart';
import '../services/firebase_messaging_service.dart';
import '../services/api_service.dart';
import '../services/endpoint_service.dart';
import '../constants/app_colors.dart';
import '../models/endpoint_model.dart';
import '../widgets/audio_message_widget.dart';
import '../widgets/image_message_widget.dart';
import 'image_viewer_screen.dart';
import '../widgets/document_message_widget.dart';
import '../widgets/video_message_widget.dart';
import 'package:image_picker/image_picker.dart';
import 'sessions_screen.dart';
import 'video_player_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:light_compressor/light_compressor.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class ChatScreen extends StatefulWidget {
  final String? actionContext;
  final Endpoint? endpoint;

  const ChatScreen({super.key, this.actionContext, this.endpoint});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AudioRecordingService _audioService = AudioRecordingService();
  final ImagePicker _imagePicker = ImagePicker();
  Timer? _recordingTimer;

  bool _isTyping = false;
  bool _isLoading = false;
  bool _isUploadingFile = false;
  bool _isRecording = false;
  bool _isEmailSending = false;
  bool _isDeletingSession = false;
  Duration _recordingDuration = Duration.zero;
  bool _showSendToTeamBanner = false;
  bool _bannerAvailable = false;
  bool _userTypedAfterEmailSent = false;
  Timer? _bannerTimer;
  String _chatTitle = 'Chat';
  String? _chatType;
  bool _audioEnabled = false;
  AudioPlayer? _audioPlayer;
  Endpoint? _endpoint;

  // Chat URL comes from the configured endpoint
  String get _n8nChatUrl => _endpoint?.url ?? '';

  // Helper method to get auth header (from endpoint only)
  String? _getAuthHeader() {
    return _endpoint?.getAuthHeader();
  }

  // Helper method to get media auth header
  String? _getMediaAuthHeader() {
    return _endpoint?.getMediaAuthHeader();
  }

  // Apply media auth headers to a multipart request
  void _applyMediaAuth(http.MultipartRequest request) {
    final authHeader = _getMediaAuthHeader();
    if (authHeader != null) {
      if (_endpoint?.mediaAuthType == 'header') {
        final parts = authHeader.split(':');
        if (parts.length == 2) {
          request.headers[parts[0].trim()] = parts[1].trim();
        }
      } else {
        request.headers['Authorization'] = authHeader;
      }
    }
    request.headers['X-Session-ID'] = SessionService.currentSessionId ?? 'no-session';
  }

  // Helper to build headers with optional auth
  Map<String, String> _buildHeaders({Map<String, String>? additional}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      ...?additional,
    };

    final authHeader = _getAuthHeader();
    if (authHeader != null) {
      if (_endpoint?.authType == 'header') {
        // Custom header format: "HeaderName: HeaderValue"
        final parts = authHeader.split(':');
        if (parts.length == 2) {
          headers[parts[0].trim()] = parts[1].trim();
        }
      } else {
        headers['Authorization'] = authHeader;
      }
    }

    return headers;
  }

  final List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _endpoint = widget.endpoint;
    _loadEndpointIfNeeded();
    _initializeApp();
  }

  Future<void> _loadEndpointIfNeeded() async {
    // If no endpoint provided, try to load current endpoint from service
    if (_endpoint == null) {
      _endpoint = await EndpointService.loadCurrentEndpoint();
    }
  }

  Future<void> _handleActionContext() async {
    if (widget.actionContext != null) {
      String contextMessage = '';
      switch (widget.actionContext) {
        case 'project':
          contextMessage = 'ik wil een project doorgeven';
          _chatType = 'project_doorgeven';
          break;
        case 'knowledge':
          contextMessage = 'ik wil vakkennis delen';
          _chatType = 'vakkennis_delen';
          break;
        case 'social':
          contextMessage = 'Ik wil content maken voor social media';
          _chatType = 'social_media';
          break;
      }

      if (contextMessage.isNotEmpty) {
        // Create message with pending status
        final contextChatMessage = ChatMessage(
          text: contextMessage,
          isCustomer: true,
          timestamp: DateTime.now(),
          status: MessageStatus.pending,
        );

        // Add message to UI
        await _addMessage(contextChatMessage);
        _scrollToBottom();

        // Send message to backend
        await _sendBulkMessages(contextChatMessage);
      }
    }
  }

  Future<void> _initializeApp() async {
    await _initializeServices();
    await _initializeWelcomeMessage();
    _requestInitialPermissions();

    // Handle action context after welcome message
    await _handleActionContext();

    // Fetch chat title after everything is initialized
    if (mounted) {
      _fetchChatTitle();
    }
  }

  Future<void> _initializeServices() async {
    // Session should already be initialized before navigation
    // Only initialize Firebase messaging here
    await _initializeFirebaseMessaging();
  }

  Future<void> _initializeFirebaseMessaging() async {
    try {
      await FirebaseMessagingService.initialize();
      FirebaseMessagingService.setMessageHandler(_handleFCMMessage);
    } catch (e) {
      debugPrint('Firebase Messaging initialization failed: $e');
    }
  }

  Future<void> _requestInitialPermissions() async {
    debugPrint('DEBUG: Requesting initial permissions...');
    final result = await _audioService.requestPermission();
    debugPrint('DEBUG: Initial permission result: $result');
  }

  Future<void> _initializeWelcomeMessage() async {
    // Load existing messages for current session
    final sessionId = SessionService.currentSessionId;
    if (sessionId != null) {
      final savedMessages = await StorageService.loadMessages(sessionId);

      if (savedMessages.isNotEmpty) {
        // Load existing messages
        final messages =
            savedMessages
                .map((json) => ChatMessage.fromJson(json))
                // No longer filter - messages with mediaMetadata load from Nextcloud
                .toList();

        // Load chatType from SessionData if available
        final sessionData = SessionService.currentSessionData;
        if (sessionData != null && sessionData.chatType != null) {
          _chatType = sessionData.chatType;
          debugPrint('DEBUG: Loaded chatType from SessionData: $_chatType');
        }

        setState(() {
          _messages.addAll(
            messages,
          ); // ListView reverse: true handles the display order
        });
        _scrollToBottom();

        return;
      }

      // No local messages - try to load from SessionData (API)
      final sessionData = SessionService.currentSessionData;
      if (sessionData != null &&
          sessionData.messages != null &&
          sessionData.messages!.isNotEmpty) {
        debugPrint('DEBUG: Loading messages from SessionData API...');

        final messages = _parseMessagesFromSessionData(sessionData);

        if (messages.isNotEmpty) {
          debugPrint('DEBUG: Loaded ${messages.length} messages from API');

          // Load chatType from SessionData
          if (sessionData.chatType != null) {
            _chatType = sessionData.chatType;
            debugPrint('DEBUG: Loaded chatType from SessionData: $_chatType');
          }

          // Save to local storage for next time
          final messagesJson = messages.map((msg) => msg.toJson()).toList();
          await StorageService.saveMessages(sessionId, messagesJson);

          setState(() {
            _messages.addAll(messages);
          });
          _scrollToBottom();

          return;
        }
      }
    }

    // No existing messages - no welcome message needed
    // The action context will handle sending the initial message
  }

  // Parse messages from SessionData API response
  List<ChatMessage> _parseMessagesFromSessionData(SessionData sessionData) {
    final List<ChatMessage> parsedMessages = [];

    if (sessionData.messages == null || sessionData.messages!.isEmpty) {
      return parsedMessages;
    }

    try {
      final messagesData = jsonDecode(sessionData.messages!);

      // Check if messages are nested under "messages" key
      final messagesList =
          messagesData is Map && messagesData.containsKey('messages')
              ? messagesData['messages']
              : messagesData;

      if (messagesList is List) {
        for (var msgJson in messagesList) {
          try {
            // Parse attachmentType
            AttachmentType attachmentType = AttachmentType.none;
            if (msgJson['attachmentType'] != null) {
              final attachmentTypeStr = msgJson['attachmentType'].toString();
              if (attachmentTypeStr.contains('audio')) {
                attachmentType = AttachmentType.audio;
              } else if (attachmentTypeStr.contains('image')) {
                attachmentType = AttachmentType.image;
              } else if (attachmentTypeStr.contains('document')) {
                attachmentType = AttachmentType.document;
              } else if (attachmentTypeStr.contains('video')) {
                attachmentType = AttachmentType.video;
              }
            }

            // Parse mediaMetadata if present
            MediaMetadata? mediaMetadata;
            if (msgJson['mediaMetadata'] != null) {
              final metaJson = msgJson['mediaMetadata'];
              mediaMetadata = MediaMetadata(
                id: metaJson['id'] ?? '',
                filename: metaJson['filename'] ?? '',
                seoTitle: metaJson['seo_title'] ?? metaJson['filename'] ?? '',
                createdAt:
                    metaJson['created_at'] != null
                        ? DateTime.parse(metaJson['created_at'])
                        : DateTime.now(),
                sessionId: metaJson['session_id'] ?? sessionData.sessionId,
                description: metaJson['description'],
                storageUrl: metaJson['storage_url'] ?? '',
              );
            }

            // Parse timestamp
            DateTime timestamp = DateTime.now();
            if (msgJson['timestamp'] != null) {
              timestamp = DateTime.parse(msgJson['timestamp']);
            }

            // Create ChatMessage
            final message = ChatMessage(
              text: msgJson['text'] ?? '',
              isCustomer: msgJson['isCustomer'] ?? false,
              timestamp: timestamp,
              attachmentType: attachmentType,
              status: MessageStatus.sent,
              fromFCM: false,
              autoPlay: false,
              mediaMetadata: mediaMetadata,
            );

            parsedMessages.add(message);
          } catch (e) {
            debugPrint('Error parsing individual message: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error parsing messages from SessionData: $e');
    }

    return parsedMessages;
  }

  // Check if message files still exist
  bool _isFileStillValid(ChatMessage message) {
    if (message.audioFile != null && !message.audioFile!.existsSync()) {
      return false;
    }
    if (message.imageFile != null && !message.imageFile!.existsSync()) {
      return false;
    }
    if (message.documentFile != null && !message.documentFile!.existsSync()) {
      return false;
    }
    return true;
  }

  // Detect and strip {show_banner} tag from AI response text
  // Returns cleaned text and flag indicating if banner should be shown
  Map<String, dynamic> _detectAndStripBannerTag(String text) {
    final hasBannerTag = text.contains('{show_banner}');
    final cleanText = text.replaceAll('{show_banner}', '').trim();
    return {'text': cleanText, 'shouldShowBanner': hasBannerTag};
  }

  // Convert ChatMessage to server-friendly format for webhook
  // Includes: text, isCustomer, timestamp, attachmentType, mediaMetadata
  // Excludes: local file paths, status, fromFCM (not needed for server restoration)
  List<Map<String, dynamic>> _convertMessagesToServerFormat() {
    return _messages
        .map(
          (msg) => {
            'text': msg.text,
            'isCustomer': msg.isCustomer,
            'timestamp': msg.timestamp.toIso8601String(),
            'attachmentType': msg.attachmentType.toString(),
            if (msg.mediaMetadata != null)
              'mediaMetadata': msg.mediaMetadata!.toJson(),
          },
        )
        .toList();
  }

  // Save messages to storage
  Future<void> _saveMessages() async {
    final sessionId = SessionService.currentSessionId;
    if (sessionId != null) {
      final messagesJson = _messages.map((msg) => msg.toJson()).toList();
      await StorageService.saveMessages(sessionId, messagesJson);

      // Update session metadata with messages for webhook
      if (_messages.isNotEmpty) {
        final serverMessages = _convertMessagesToServerFormat();
        await SessionService.updateCurrentSession(messages: serverMessages);
      }
    }
  }

  // Add message and save to storage
  Future<void> _addMessage(ChatMessage message) async {
    setState(() {
      _messages.insert(0, message);
    });
    await _saveMessages();
  }

  // Handle FCM messages received while app is in foreground
  void _handleFCMMessage(Map<String, dynamic> messageData) {
    try {
      // Extract message content from FCM data
      final String? messageText =
          messageData['message'] ??
          messageData['body'] ??
          messageData['content'];
      final String? sessionId = messageData['sessionId'];

      // Only process messages for current session
      if (sessionId != null &&
          sessionId == SessionService.currentSessionId &&
          messageText != null) {
        // Detect and strip banner tag
        final result = _detectAndStripBannerTag(messageText);
        final cleanText = result['text'];
        final shouldShowBanner = result['shouldShowBanner'];

        final fcmMessage = ChatMessage(
          text: cleanText,
          isCustomer: false, // FCM messages are from the bot/system
          timestamp: DateTime.now(),
          status: MessageStatus.sent,
          fromFCM: true, // Mark this message as coming from FCM
        );

        _addMessage(fcmMessage);
        _scrollToBottom();

        // Show banner if tag was detected
        if (shouldShowBanner) {
          _displaySendToTeamBanner();
        }
      }
    } catch (e) {
      debugPrint('Error handling FCM message: $e');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _audioService.dispose();
    _audioPlayer?.dispose();
    _recordingTimer?.cancel();
    // DISABLED: Banner timer cleanup
    // _bannerTimer?.cancel();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0, // With reverse: true, position 0 = bottom (newest messages)
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    // Disable banner availability when user sends a message
    setState(() {
      _bannerAvailable = false;
      _showSendToTeamBanner = false;
    });

    if (_messageController.text.trim().isNotEmpty && !_isLoading) {
      final userMessage = _messageController.text.trim();

      // Create new message with pending status
      final newMessage = ChatMessage(
        text: userMessage,
        isCustomer: true,
        timestamp: DateTime.now(),
        status: MessageStatus.pending, // Start as pending
      );

      // Add user message immediately
      await _addMessage(newMessage);

      _messageController.clear();
      setState(() {
        _isTyping = false;
      });
      _scrollToBottom();

      // Send in bulk with all pending messages
      await _sendBulkMessages(newMessage);
    }
  }

  Future<void> _addErrorMessage(String errorText) async {
    await _addMessage(
      ChatMessage(
        text: errorText,
        isCustomer: false,
        timestamp: DateTime.now(),
        status: MessageStatus.sent,
      ),
    );
  }

  Future<void> _generateAndPlayAudio() async {
    if (!_audioEnabled) return;

    try {
      final response = await http
          .post(
            Uri.parse(_endpoint?.url ?? ''),
            headers: _buildHeaders(),
            body: jsonEncode({
              'sessionId': SessionService.currentSessionId ?? 'no-session',
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        // Debug logging
        debugPrint('Audio response headers: ${response.headers}');
        debugPrint(
          'Audio response content-type: ${response.headers['content-type']}',
        );
        debugPrint('Audio response body length: ${response.bodyBytes.length}');
        debugPrint(
          'Audio response first 100 bytes: ${response.bodyBytes.take(100).toList()}',
        );

        // Save MP3 to temp file
        final tempDir = await getTemporaryDirectory();
        final audioFile = File(
          '${tempDir.path}/response_${DateTime.now().millisecondsSinceEpoch}.mp3',
        );
        await audioFile.writeAsBytes(response.bodyBytes);

        // Verify file was written
        final fileExists = await audioFile.exists();
        final fileSize = await audioFile.length();
        debugPrint(
          'Audio file saved: $fileExists, size: $fileSize bytes, path: ${audioFile.path}',
        );

        // Add audio message with autoPlay flag
        await _addMessage(
          ChatMessage(
            text: '🔊 Audio reactie',
            isCustomer: false,
            timestamp: DateTime.now(),
            audioFile: audioFile,
            attachmentType: AttachmentType.audio,
            status: MessageStatus.sent,
            autoPlay: true,
          ),
        );

        debugPrint('Audio message added with autoPlay: true');
      } else {
        debugPrint(
          'Audio generation failed with status: ${response.statusCode}',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Error generating audio: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  Future<void> _startRecording() async {
    // Hide banner temporarily during recording
    setState(() {
      _showSendToTeamBanner = false;
    });

    debugPrint('DEBUG: Starting recording...');
    final hasPermission = await _audioService.requestPermission();
    debugPrint('DEBUG: Recording permission granted: $hasPermission');

    if (!hasPermission) {
      debugPrint('DEBUG: Permission denied, showing snackbar');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Microfoon toegang is vereist voor audio opnamen. Ga naar instellingen om dit toe te staan.',
            ),
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    final success = await _audioService.startRecording();
    if (success) {
      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero;
      });

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordingDuration = Duration(seconds: timer.tick);
        });
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Kan opname niet starten. Controleer microfoon toegang.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();

    final audioFile = await _audioService.stopRecording();

    setState(() {
      _isRecording = false;
      _recordingDuration = Duration.zero;
    });

    if (audioFile != null) {
      await _sendAudioMessage(audioFile);
    } else {
      // Recording cancelled - show banner again if available and text field empty
      setState(() {
        _showSendToTeamBanner =
            _bannerAvailable && _messageController.text.trim().isEmpty;
      });
    }
  }

  Future<void> _sendAudioMessage(File audioFile) async {
    // Disable banner availability when sending audio
    setState(() {
      _bannerAvailable = false;
      _showSendToTeamBanner = false;
    });

    // Create new audio message with pending status
    final newMessage = ChatMessage(
      text: '🎤 Audio bericht (${_formatDuration(_recordingDuration)})',
      isCustomer: true,
      timestamp: DateTime.now(),
      audioFile: audioFile,
      attachmentType: AttachmentType.audio,
      status: MessageStatus.pending, // Start as pending
    );

    // Add message immediately
    await _addMessage(newMessage);
    _scrollToBottom();

    // Send in bulk with all pending messages
    await _sendBulkMessages(newMessage);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  // Standardized webhook response parsing
  String _parseWebhookResponse(String responseBody, String defaultMessage) {
    if (responseBody.isEmpty) {
      return defaultMessage;
    }

    // Check if response contains HTML iframe with srcdoc attribute
    if (responseBody.contains('<iframe') && responseBody.contains('srcdoc=')) {
      final RegExp iframeRegex = RegExp(r'srcdoc="([^"]*)"');
      final Match? match = iframeRegex.firstMatch(responseBody);
      if (match != null && match.group(1) != null) {
        return match.group(1)!;
      }
    }

    try {
      final data = jsonDecode(responseBody);
      if (data is Map) {
        return data['output'] ??
            data['response'] ??
            data['message'] ??
            data['reply'] ??
            data['text'] ??
            data['analysis'] ??
            defaultMessage;
      } else if (data is String) {
        return data;
      } else {
        return defaultMessage;
      }
    } catch (e) {
      // If JSON parsing fails, use the raw response if it's not empty
      return responseBody.isNotEmpty ? responseBody : defaultMessage;
    }
  }

  // Parse media webhook response (can be array or single object)
  MediaMetadata? _parseMediaResponse(String responseBody) {
    debugPrint('DEBUG: Parsing media response: $responseBody');
    try {
      final data = jsonDecode(responseBody);
      debugPrint('DEBUG: Decoded data type: ${data.runtimeType}');

      // Handle array format
      if (data is List && data.isNotEmpty) {
        debugPrint('DEBUG: Found ${data.length} items in array');
        final metadata = MediaMetadata.fromJson(data[0]);
        debugPrint(
          'DEBUG: Parsed metadata - storage_url: ${metadata.storageUrl}',
        );
        return metadata;
      }
      // Handle single object format
      else if (data is Map<String, dynamic>) {
        debugPrint('DEBUG: Response is a single object (Map)');
        final metadata = MediaMetadata.fromJson(data);
        debugPrint(
          'DEBUG: Parsed metadata - storage_url: ${metadata.storageUrl}',
        );
        return metadata;
      } else {
        debugPrint('DEBUG: Data is neither a List nor a Map');
      }
    } catch (e) {
      debugPrint('Error parsing media response: $e');
      debugPrint('DEBUG: Response body was: $responseBody');
    }
    return null;
  }

  Future<void> _showAttachmentDialog() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Bijlage selecteren',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(
                  Icons.description,
                  color: Color(0xFFCC0001),
                ),
                title: const Text('Document'),
                subtitle: const Text('PDF, Word, Excel, PowerPoint, ODT'),
                onTap: () {
                  Navigator.pop(context);
                  _pickDocument();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                  color: Color(0xFFCC0001),
                ),
                title: const Text('Galerij'),
                subtitle: const Text('Meerdere foto\'s en afbeeldingen'),
                onTap: () {
                  Navigator.pop(context);
                  _pickMultipleImages();
                },
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuleren'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showImageSourceDialog() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Media selecteren',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFFCC0001)),
                title: const Text('Foto maken'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam, color: Color(0xFFCC0001)),
                title: const Text('Video opnemen'),
                onTap: () {
                  Navigator.pop(context);
                  _pickVideo(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                  color: Color(0xFFCC0001),
                ),
                title: const Text('Foto kiezen'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.video_library,
                  color: Color(0xFFCC0001),
                ),
                title: const Text('Video kiezen'),
                onTap: () {
                  Navigator.pop(context);
                  _pickVideo(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuleren'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    // Hide banner temporarily during image picking
    setState(() {
      _showSendToTeamBanner = false;
    });

    try {
      // Request permissions
      if (source == ImageSource.camera) {
        final cameraStatus = await Permission.camera.request();
        if (cameraStatus.isDenied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Camera toegang is vereist om foto\'s te maken.'),
              ),
            );
          }
          return;
        }
      } else {
        final photosStatus = await Permission.photos.request();
        if (photosStatus.isDenied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Galerij toegang is vereist om foto\'s te selecteren.',
                ),
              ),
            );
          }
          return;
        }
      }

      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        final imageFile = File(image.path);
        await _sendImageMessage(imageFile);
      } else {
        // Image picking cancelled - show banner again if available and text field empty
        setState(() {
          _showSendToTeamBanner =
              _bannerAvailable && _messageController.text.trim().isEmpty;
        });
      }
    } catch (e) {
      // Error occurred - show banner again if available and text field empty
      setState(() {
        _showSendToTeamBanner =
            _bannerAvailable && _messageController.text.trim().isEmpty;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fout bij het selecteren van afbeelding: $e')),
        );
      }
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    // Hide banner temporarily during video picking
    setState(() {
      _showSendToTeamBanner = false;
    });

    try {
      // Request permissions
      if (source == ImageSource.camera) {
        final cameraStatus = await Permission.camera.request();
        if (cameraStatus.isDenied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Camera toegang is vereist om video\'s te maken.',
                ),
              ),
            );
          }
          return;
        }
      } else {
        final photosStatus = await Permission.photos.request();
        if (photosStatus.isDenied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Galerij toegang is vereist om video\'s te selecteren.',
                ),
              ),
            );
          }
          return;
        }
      }

      final XFile? video = await _imagePicker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 5),
      );

      if (video != null) {
        final videoFile = File(video.path);
        await _sendVideoMessage(videoFile);
      } else {
        // Video picking cancelled - show banner again if available and text field empty
        setState(() {
          _showSendToTeamBanner =
              _bannerAvailable && _messageController.text.trim().isEmpty;
        });
      }
    } catch (e) {
      // Error occurred - show banner again if available and text field empty
      setState(() {
        _showSendToTeamBanner =
            _bannerAvailable && _messageController.text.trim().isEmpty;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fout bij het selecteren van video: $e')),
        );
      }
    }
  }

  Future<void> _pickMultipleImages() async {
    try {
      // Request gallery permission
      final photosStatus = await Permission.photos.request();
      if (photosStatus.isDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Galerij toegang is vereist om foto\'s te selecteren.',
              ),
            ),
          );
        }
        return;
      }

      final List<XFile> images = await _imagePicker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        // Limit to maximum 10 images
        final limitedImages = images.take(10).toList();
        final imageFiles =
            limitedImages.map((xFile) => File(xFile.path)).toList();
        await _sendMultipleImages(imageFiles);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fout bij het selecteren van afbeeldingen: $e'),
          ),
        );
      }
    }
  }

  Future<void> _sendMultipleImages(List<File> imageFiles) async {
    for (int i = 0; i < imageFiles.length; i++) {
      final imageFile = imageFiles[i];

      // Add progress message
      if (imageFiles.length > 1) {
        setState(() {
          _messages.insert(
            0,
            ChatMessage(
              text:
                  'Afbeelding ${i + 1} van ${imageFiles.length} wordt verzonden...',
              isCustomer: false,
              timestamp: DateTime.now(),
            ),
          );
        });
        _scrollToBottom();
      }

      // Send individual image
      await _sendImageMessage(imageFile);

      // Small delay between uploads to avoid overwhelming the server
      if (i < imageFiles.length - 1) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  Future<void> _sendImageMessage(File imageFile) async {
    // Disable banner availability when sending image
    setState(() {
      _bannerAvailable = false;
      _showSendToTeamBanner = false;
    });

    // Create new image message with uploading status
    final newMessage = ChatMessage(
      text: '📷 Afbeelding',
      isCustomer: true,
      timestamp: DateTime.now(),
      imageFile:
          imageFile, // Temp file - will be replaced with URL after upload
      attachmentType: AttachmentType.image,
      status: MessageStatus.uploading, // Show as uploading with spinner
    );

    // Add message immediately (shows temp preview with spinner)
    await _addMessage(newMessage);
    _scrollToBottom();

    // Upload in background - user can continue typing
    _uploadImageInBackground(newMessage, imageFile);
  }

  Future<void> _uploadImageInBackground(
    ChatMessage message,
    File imageFile,
  ) async {
    try {
      if (_endpoint == null) return;

      final mediaUrl = _endpoint?.mediaUrl ?? _endpoint?.url ?? '';
      final request = http.MultipartRequest('POST', Uri.parse(mediaUrl));

      _applyMediaAuth(request);
      request.fields['action'] = _endpoint?.imageAction ?? 'sendImage';
      request.fields['sessionId'] = SessionService.currentSessionId ?? 'no-session';
      request.fields['chatInput'] = 'Image send';

      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        debugPrint(
          'DEBUG: Image upload successful, status: ${response.statusCode}',
        );
        debugPrint('DEBUG: Response body: ${response.body}');

        // Parse Nextcloud metadata from webhook response
        final metadata = _parseMediaResponse(response.body);
        debugPrint('DEBUG: Metadata parsed: ${metadata != null}');

        if (metadata != null) {
          debugPrint('DEBUG: Updating message with metadata...');
          debugPrint(
            'DEBUG: Looking for message with timestamp: ${message.timestamp}',
          );

          // Update message: replace temp file with Nextcloud metadata
          setState(() {
            final index = _messages.indexWhere(
              (m) =>
                  m.timestamp == message.timestamp &&
                  m.attachmentType == AttachmentType.image,
            );
            debugPrint('DEBUG: Found message at index: $index');

            if (index != -1) {
              _messages[index] = ChatMessage(
                text: message.text,
                isCustomer: message.isCustomer,
                timestamp: message.timestamp,
                imageFile: null, // Remove temp file
                attachmentType: AttachmentType.image,
                status: MessageStatus.sent, // Mark as sent
                mediaMetadata: metadata, // Add Nextcloud data
              );
              debugPrint(
                'DEBUG: Message updated with storage_url: ${metadata.storageUrl}',
              );
            }
          });

          // Save updated message to storage
          await _saveMessages();
          debugPrint('DEBUG: Messages saved to storage');

          // Show "Team inlichten" banner after successful upload
          _displaySendToTeamBanner();

          // Description stored in metadata but not displayed as separate message
        } else {
          debugPrint(
            'DEBUG: Metadata was null - response not parsed correctly',
          );
        }
      } else {
        debugPrint('DEBUG: Upload failed with status: ${response.statusCode}');
        debugPrint('DEBUG: Response body: ${response.body}');
        // Mark upload as failed
        setState(() {
          final index = _messages.indexWhere(
            (m) =>
                m.timestamp == message.timestamp &&
                m.attachmentType == AttachmentType.image,
          );
          if (index != -1) {
            _messages[index] = ChatMessage(
              text: message.text,
              isCustomer: message.isCustomer,
              timestamp: message.timestamp,
              imageFile: message.imageFile,
              attachmentType: AttachmentType.image,
              status: MessageStatus.failed,
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Error uploading image: $e');
      // Mark as failed
      setState(() {
        final index = _messages.indexWhere(
          (m) =>
              m.timestamp == message.timestamp &&
              m.attachmentType == AttachmentType.image,
        );
        if (index != -1) {
          _messages[index] = ChatMessage(
            text: message.text,
            isCustomer: message.isCustomer,
            timestamp: message.timestamp,
            imageFile: message.imageFile,
            attachmentType: AttachmentType.image,
            status: MessageStatus.failed,
          );
        }
      });
    }
  }

  Future<void> _showImageDeleteDialog(ChatMessage message) async {
    if (message.mediaMetadata == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Afbeelding verwijderen'),
            content: const Text(
              'Weet je zeker dat je deze afbeelding wilt verwijderen?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuleer'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Verwijder',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await _deleteImage(message);
    }
  }

  Future<void> _deleteImage(ChatMessage message) async {
    if (message.mediaMetadata == null) return;

    try {
      debugPrint('DEBUG: Deleting image: ${message.mediaMetadata!.filename}');

      // Remove from chat and save (local only)
      setState(() {
        _messages.removeWhere(
          (m) =>
              m.timestamp == message.timestamp &&
              m.attachmentType == AttachmentType.image,
        );
      });
      await _saveMessages();
      debugPrint('DEBUG: Image deleted and history saved');
    } catch (e) {
      debugPrint('Error deleting image: $e');
    }
  }

  Future<void> _openDocument(ChatMessage message) async {
    if (message.mediaMetadata == null) return;

    try {
      final Uri documentUri = Uri.parse(message.mediaMetadata!.storageUrl);
      if (await canLaunchUrl(documentUri)) {
        await launchUrl(documentUri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kan document niet openen')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error opening document: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error bij openen document: $e')),
        );
      }
    }
  }

  Future<void> _playVideo(ChatMessage message) async {
    if (message.mediaMetadata == null) return;

    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (context) => VideoPlayerScreen(
                videoUrl: '${message.mediaMetadata!.storageUrl}/download',
                title: message.mediaMetadata!.filename,
              ),
        ),
      );
    } catch (e) {
      debugPrint('Error playing video: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error bij afspelen video: $e')));
      }
    }
  }

  Future<void> _viewImage(ChatMessage message) async {
    // Get image URL from mediaMetadata
    if (message.mediaMetadata == null) return;

    final imageUrl = '${message.mediaMetadata!.storageUrl}/preview';

    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (context) => ImageViewerScreen(
                imageUrl: imageUrl,
                title: message.mediaMetadata!.filename,
              ),
        ),
      );
    } catch (e) {
      debugPrint('Error viewing image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error bij weergeven afbeelding: $e')),
        );
      }
    }
  }

  Future<void> _showDocumentDeleteDialog(ChatMessage message) async {
    if (message.mediaMetadata == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Document verwijderen'),
            content: const Text(
              'Weet je zeker dat je dit document wilt verwijderen?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuleer'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Verwijder',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await _deleteDocument(message);
    }
  }

  Future<void> _deleteDocument(ChatMessage message) async {
    if (message.mediaMetadata == null) return;

    try {
      debugPrint(
        'DEBUG: Deleting document: ${message.mediaMetadata!.filename}',
      );

      // Remove from chat and save (local only)
      setState(() {
        _messages.removeWhere(
          (m) =>
              m.timestamp == message.timestamp &&
              m.attachmentType == AttachmentType.document,
        );
      });
      await _saveMessages();
      debugPrint('DEBUG: Document deleted and history saved');
    } catch (e) {
      debugPrint('Error deleting document: $e');
    }
  }

  Future<void> _showVideoDeleteDialog(ChatMessage message) async {
    if (message.mediaMetadata == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Video verwijderen'),
            content: const Text(
              'Weet je zeker dat je deze video wilt verwijderen?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuleer'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Verwijder',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await _deleteVideo(message);
    }
  }

  Future<void> _deleteVideo(ChatMessage message) async {
    if (message.mediaMetadata == null) return;

    try {
      debugPrint('DEBUG: Deleting video: ${message.mediaMetadata!.filename}');

      // Remove from chat and save (local only)
      setState(() {
        _messages.removeWhere(
          (m) =>
              m.timestamp == message.timestamp &&
              m.attachmentType == AttachmentType.video,
        );
      });
      await _saveMessages();
      debugPrint('DEBUG: Video deleted and history saved');
    } catch (e) {
      debugPrint('Error deleting video: $e');
    }
  }

  Future<void> _sendVideoMessage(File videoFile) async {
    // Check file size (200MB limit)
    final fileSize = await videoFile.length();
    const maxSize = 200 * 1024 * 1024; // 200MB in bytes

    if (fileSize > maxSize) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video is te groot (max 200MB)'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Disable banner availability when sending video
    setState(() {
      _bannerAvailable = false;
      _showSendToTeamBanner = false;
    });

    // Show compressing message
    final compressingMessage = ChatMessage(
      text: "🎬 Video wordt gecomprimeerd...",
      isCustomer: false,
      timestamp: DateTime.now(),
      status: MessageStatus.sent,
    );
    setState(() {
      _messages.insert(0, compressingMessage);
    });
    _scrollToBottom();

    try {
      // Compress video
      final result = await LightCompressor().compressVideo(
        path: videoFile.path,
        videoQuality: VideoQuality.medium,
        isMinBitrateCheckEnabled: false,
        video: Video(
          videoName: 'compressed_${DateTime.now().millisecondsSinceEpoch}',
        ),
        android: AndroidConfig(isSharedStorage: false),
        ios: IOSConfig(saveInGallery: false),
      );

      // Remove compressing message
      setState(() {
        _messages.remove(compressingMessage);
      });

      if (result is OnSuccess) {
        // Use compressed video
        videoFile = File(result.destinationPath);

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Video gecomprimeerd en klaar om te verzenden'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else if (result is OnFailure) {
        // Compression failed, show error but continue with original
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Compressie mislukt: ${result.message}. Originele video wordt verzonden.',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else if (result is OnCancelled) {
        // Compression cancelled
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Compressie geannuleerd'),
              backgroundColor: Colors.grey,
            ),
          );
        }
        return;
      }
    } catch (e) {
      // Remove compressing message
      setState(() {
        _messages.remove(compressingMessage);
      });

      // Handle compression error, continue with original video
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Compressie fout: $e. Originele video wordt verzonden.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    // Generate thumbnail for display during upload
    final thumbnailPath = await _generateVideoThumbnail(videoFile);
    final thumbnailFile = thumbnailPath != null ? File(thumbnailPath) : null;

    // Create new video message with uploading status
    final newMessage = ChatMessage(
      text: '🎥 Video',
      isCustomer: true,
      timestamp: DateTime.now(),
      videoFile: videoFile, // Compressed file - will be replaced with URL
      videoThumbnailFile: thumbnailFile, // Temp thumbnail during upload
      attachmentType: AttachmentType.video,
      status: MessageStatus.uploading, // Show as uploading with spinner
    );

    // Add message immediately (shows temp preview with spinner)
    await _addMessage(newMessage);
    _scrollToBottom();

    // Upload in background - user can continue typing
    _uploadVideoInBackground(newMessage, videoFile);
  }

  /// Generate and save video thumbnail locally
  Future<String?> _generateVideoThumbnail(File videoFile) async {
    try {
      final uint8list = await VideoThumbnail.thumbnailData(
        video: videoFile.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 250,
        quality: 75,
      );

      if (uint8list != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final thumbnailDir = Directory('${appDir.path}/video_thumbnails');
        if (!thumbnailDir.existsSync()) {
          thumbnailDir.createSync(recursive: true);
        }

        final thumbnailFile = File(
          '${thumbnailDir.path}/thumbnail_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await thumbnailFile.writeAsBytes(uint8list);
        debugPrint('DEBUG: Thumbnail saved at: ${thumbnailFile.path}');
        return thumbnailFile.path;
      }
    } catch (e) {
      debugPrint('Error generating thumbnail: $e');
    }
    return null;
  }

  Future<void> _uploadVideoInBackground(
    ChatMessage message,
    File videoFile,
  ) async {
    try {
      if (_endpoint == null) return;

      // Generate thumbnail before upload
      final thumbnailPath = await _generateVideoThumbnail(videoFile);

      final mediaUrl = _endpoint?.mediaUrl ?? _endpoint?.url ?? '';
      final request = http.MultipartRequest('POST', Uri.parse(mediaUrl));

      _applyMediaAuth(request);
      request.fields['action'] = _endpoint?.videoAction ?? 'sendVideo';
      request.fields['sessionId'] = SessionService.currentSessionId ?? 'no-session';
      request.fields['chatInput'] = 'Video send';

      request.files.add(
        await http.MultipartFile.fromPath('video', videoFile.path),
      );

      // Add thumbnail file if generated successfully
      if (thumbnailPath != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'thumbnail',
            thumbnailPath,
            filename: 'thumbnail.jpg',
          ),
        );
        request.fields['hasThumbnail'] = 'true';
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        debugPrint(
          'DEBUG: Video upload successful, status: ${response.statusCode}',
        );
        debugPrint('DEBUG: Response body: ${response.body}');

        // Parse Nextcloud metadata from webhook response
        final metadata = _parseMediaResponse(response.body);
        debugPrint('DEBUG: Metadata parsed: ${metadata != null}');

        if (metadata != null) {
          debugPrint('DEBUG: Updating video message with metadata...');

          // Update message: replace temp file with Nextcloud metadata
          setState(() {
            final index = _messages.indexWhere(
              (m) =>
                  m.timestamp == message.timestamp &&
                  m.attachmentType == AttachmentType.video,
            );
            debugPrint('DEBUG: Found message at index: $index');

            if (index != -1) {
              _messages[index] = ChatMessage(
                text: message.text,
                isCustomer: message.isCustomer,
                timestamp: message.timestamp,
                videoFile: null, // Remove temp video file
                videoThumbnailFile:
                    null, // Remove temp thumbnail file (will use mediaMetadata.thumbnailPreviewUrl)
                attachmentType: AttachmentType.video,
                status: MessageStatus.sent, // Mark as sent
                mediaMetadata:
                    metadata, // Add Nextcloud data with thumbnail URL
              );
              debugPrint(
                'DEBUG: Video updated with storage_url: ${metadata.storageUrl}',
              );
            }
          });

          // Save updated message to storage
          await _saveMessages();
          debugPrint('DEBUG: Messages saved to storage');

          // Show "Team inlichten" banner after successful upload
          _displaySendToTeamBanner();
        } else {
          debugPrint(
            'DEBUG: Metadata was null - response not parsed correctly',
          );
        }
      } else {
        debugPrint('DEBUG: Upload failed with status: ${response.statusCode}');
        // Mark upload as failed
        setState(() {
          final index = _messages.indexWhere(
            (m) =>
                m.timestamp == message.timestamp &&
                m.attachmentType == AttachmentType.video,
          );
          if (index != -1) {
            _messages[index] = ChatMessage(
              text: message.text,
              isCustomer: message.isCustomer,
              timestamp: message.timestamp,
              videoFile: message.videoFile,
              attachmentType: AttachmentType.video,
              status: MessageStatus.failed,
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Error uploading video: $e');
      // Mark as failed
      setState(() {
        final index = _messages.indexWhere(
          (m) =>
              m.timestamp == message.timestamp &&
              m.attachmentType == AttachmentType.video,
        );
        if (index != -1) {
          _messages[index] = ChatMessage(
            text: message.text,
            isCustomer: message.isCustomer,
            timestamp: message.timestamp,
            videoFile: message.videoFile,
            attachmentType: AttachmentType.video,
            status: MessageStatus.failed,
          );
        }
      });
    }
  }

  Future<void> _pickDocument() async {
    // Hide banner temporarily during document picking
    setState(() {
      _showSendToTeamBanner = false;
    });

    try {
      final documentFile = await AttachmentService.pickDocument();
      if (documentFile != null) {
        await _sendDocumentMessage(documentFile);
      } else {
        // Document picking cancelled - show banner again if available and text field empty
        setState(() {
          _showSendToTeamBanner =
              _bannerAvailable && _messageController.text.trim().isEmpty;
        });
      }
    } catch (e) {
      // Error occurred - show banner again if available and text field empty
      setState(() {
        _showSendToTeamBanner =
            _bannerAvailable && _messageController.text.trim().isEmpty;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fout bij het selecteren van document: $e')),
        );
      }
    }
  }

  Future<void> _sendDocumentMessage(File documentFile) async {
    // Disable banner availability when sending document
    setState(() {
      _bannerAvailable = false;
      _showSendToTeamBanner = false;
    });

    final fileInfo = AttachmentService.getFileInfo(documentFile);

    // Create new document message with uploading status
    final newMessage = ChatMessage(
      text: '📄 ${fileInfo['fileName']}',
      isCustomer: true,
      timestamp: DateTime.now(),
      documentFile: documentFile, // Temp file - will be replaced with URL
      attachmentType: AttachmentType.document,
      status: MessageStatus.uploading, // Show as uploading with spinner
    );

    // Add message immediately (shows temp preview with spinner)
    await _addMessage(newMessage);
    _scrollToBottom();

    // Upload in background - user can continue typing
    _uploadDocumentInBackground(newMessage, documentFile);
  }

  Future<void> _uploadDocumentInBackground(
    ChatMessage message,
    File documentFile,
  ) async {
    try {
      if (_endpoint == null) return;

      final mediaUrl = _endpoint?.mediaUrl ?? _endpoint?.url ?? '';
      final request = http.MultipartRequest('POST', Uri.parse(mediaUrl));

      _applyMediaAuth(request);
      request.fields['action'] = _endpoint?.documentAction ?? 'sendDocument';
      request.fields['sessionId'] = SessionService.currentSessionId ?? 'no-session';
      request.fields['chatInput'] = 'Document send';

      request.files.add(
        await http.MultipartFile.fromPath('document', documentFile.path),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        debugPrint(
          'DEBUG: Document upload successful, status: ${response.statusCode}',
        );
        debugPrint('DEBUG: Response body: ${response.body}');

        // Parse Nextcloud metadata from webhook response
        final metadata = _parseMediaResponse(response.body);
        debugPrint('DEBUG: Metadata parsed: ${metadata != null}');

        if (metadata != null) {
          debugPrint('DEBUG: Updating document message with metadata...');

          // Update message: replace temp file with Nextcloud metadata
          setState(() {
            final index = _messages.indexWhere(
              (m) =>
                  m.timestamp == message.timestamp &&
                  m.attachmentType == AttachmentType.document,
            );
            debugPrint('DEBUG: Found message at index: $index');

            if (index != -1) {
              _messages[index] = ChatMessage(
                text: message.text,
                isCustomer: message.isCustomer,
                timestamp: message.timestamp,
                documentFile: null, // Remove temp file
                attachmentType: AttachmentType.document,
                status: MessageStatus.sent, // Mark as sent
                mediaMetadata: metadata, // Add Nextcloud data
              );
              debugPrint(
                'DEBUG: Document updated with storage_url: ${metadata.storageUrl}',
              );
            }
          });

          // Save updated message to storage
          await _saveMessages();
          debugPrint('DEBUG: Messages saved to storage');

          // Show "Team inlichten" banner after successful upload
          _displaySendToTeamBanner();
        } else {
          debugPrint(
            'DEBUG: Metadata was null - response not parsed correctly',
          );
        }
      } else {
        debugPrint('DEBUG: Upload failed with status: ${response.statusCode}');
        // Mark upload as failed
        setState(() {
          final index = _messages.indexWhere(
            (m) =>
                m.timestamp == message.timestamp &&
                m.attachmentType == AttachmentType.document,
          );
          if (index != -1) {
            _messages[index] = ChatMessage(
              text: message.text,
              isCustomer: message.isCustomer,
              timestamp: message.timestamp,
              documentFile: message.documentFile,
              attachmentType: AttachmentType.document,
              status: MessageStatus.failed,
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Error uploading document: $e');
      // Mark as failed
      setState(() {
        final index = _messages.indexWhere(
          (m) =>
              m.timestamp == message.timestamp &&
              m.attachmentType == AttachmentType.document,
        );
        if (index != -1) {
          _messages[index] = ChatMessage(
            text: message.text,
            isCustomer: message.isCustomer,
            timestamp: message.timestamp,
            documentFile: message.documentFile,
            attachmentType: AttachmentType.document,
            status: MessageStatus.failed,
          );
        }
      });
    }
  }

  void _onTextChanged(String text) {
    setState(() {
      _isTyping = text.trim().isNotEmpty;
      // When user types, mark that they've typed after email was sent
      if (text.trim().isNotEmpty) {
        _userTypedAfterEmailSent = true;
      }
    });

    if (text.trim().isEmpty && _bannerAvailable) {
      setState(() {
        _showSendToTeamBanner = true;
      });
    } else {
      setState(() {
        _showSendToTeamBanner = false;
      });
    }
  }

  void _onTextFieldTapped() {
    if (_showSendToTeamBanner) {
      setState(() {
        _showSendToTeamBanner = false;
      });
    }
    // Scroll to bottom when input is tapped
    _scrollToBottom();
  }

  // Get all pending messages in chronological order
  List<ChatMessage> _getPendingMessages() {
    return _messages
        .where((msg) => msg.isCustomer && msg.status == MessageStatus.pending)
        .toList();
  }

  // Mark messages as sent
  void _markMessagesAsSent(List<ChatMessage> messages) {
    setState(() {
      for (int i = 0; i < _messages.length; i++) {
        for (var sentMessage in messages) {
          if (_messages[i].timestamp == sentMessage.timestamp &&
              _messages[i].text == sentMessage.text) {
            _messages[i] = ChatMessage(
              text: _messages[i].text,
              isCustomer: _messages[i].isCustomer,
              timestamp: _messages[i].timestamp,
              audioFile: _messages[i].audioFile,
              imageFile: _messages[i].imageFile,
              documentFile: _messages[i].documentFile,
              attachmentType: _messages[i].attachmentType,
              status: MessageStatus.sent,
              fromFCM: _messages[i].fromFCM,
            );
            break;
          }
        }
      }
    });
    _saveMessages();
  }

  // Bulk send all pending messages plus new message
  Future<void> _sendBulkMessages(ChatMessage newMessage) async {
    try {
      // Get all pending messages (which already includes the new message)
      List<ChatMessage> allMessagesToSend = _getPendingMessages();

      // Separate text messages from file messages
      List<ChatMessage> textMessages =
          allMessagesToSend
              .where((msg) => msg.attachmentType == AttachmentType.none)
              .toList();
      List<ChatMessage> fileMessages =
          allMessagesToSend
              .where((msg) => msg.attachmentType != AttachmentType.none)
              .toList();

      setState(() {
        _isLoading = true;
        _isUploadingFile = fileMessages.isNotEmpty;
      });

      // Send text messages in bulk if any exist
      if (textMessages.isNotEmpty) {
        await _sendBulkTextMessages(textMessages);
      }

      // Send file messages individually
      for (var fileMessage in fileMessages) {
        await _sendIndividualFileMessage(fileMessage);
      }

      // Mark all messages as sent after successful bulk operation
      _markMessagesAsSent(allMessagesToSend);
    } catch (e) {
      debugPrint('Bulk send failed: $e');
      _addErrorMessage(
        'Sorry, er ging iets mis bij het versturen van berichten.',
      );
    } finally {
      setState(() {
        _isLoading = false;
        _isUploadingFile = false;
      });
      _scrollToBottom();
    }
  }

  // Send text messages individually (but in sequence)
  Future<void> _sendBulkTextMessages(List<ChatMessage> textMessages) async {
    if (textMessages.isEmpty) return;

    // Send the last (newest) text message to get a bot response
    final lastMessage = textMessages.last;

    // Build request body with correct field order
    final requestBody = <String, dynamic>{'action': 'sendMessage'};

    // Add chatType right after action if available
    if (_chatType != null) {
      requestBody['chatType'] = _chatType!;
    }

    // Add remaining fields
    requestBody['sessionId'] = SessionService.currentSessionId ?? 'no-session';
    requestBody['chatInput'] = lastMessage.text;

    final response = await http
        .post(
          Uri.parse(_n8nChatUrl),
          headers: _buildHeaders(additional: {
            'Accept': 'application/json',
            'X-Session-ID': SessionService.currentSessionId ?? 'no-session',
          }),
          body: jsonEncode(requestBody),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      String botResponse = _parseWebhookResponse(
        response.body,
        'Bericht ontvangen en verwerkt',
      );

      // Detect and strip banner tag from response
      final result = _detectAndStripBannerTag(botResponse);
      final cleanText = result['text'];
      final shouldShowBanner = result['shouldShowBanner'];

      setState(() {
        _messages.insert(
          0,
          ChatMessage(
            text: cleanText,
            isCustomer: false,
            timestamp: DateTime.now(),
            status: MessageStatus.sent,
          ),
        );
      });

      // Generate and play audio if enabled
      await _generateAndPlayAudio();

      // Show banner only if tag was detected
      if (shouldShowBanner) {
        _displaySendToTeamBanner();
      }

      // Fetch updated chat title
      _fetchChatTitle();
    } else {
      throw Exception('Failed to send text messages: ${response.statusCode}');
    }
  }

  // Send individual file message
  Future<void> _sendIndividualFileMessage(ChatMessage fileMessage) async {
    if (fileMessage.attachmentType == AttachmentType.image &&
        fileMessage.imageFile != null) {
      await _sendImageFileMessage(fileMessage);
    } else if (fileMessage.attachmentType == AttachmentType.audio &&
        fileMessage.audioFile != null) {
      await _sendAudioFileMessage(fileMessage);
    } else if (fileMessage.attachmentType == AttachmentType.document &&
        fileMessage.documentFile != null) {
      await _sendDocumentFileMessage(fileMessage);
    } else if (fileMessage.attachmentType == AttachmentType.video &&
        fileMessage.videoFile != null) {
      await _sendVideoFileMessage(fileMessage);
    }
  }

  // Send image file message
  Future<void> _sendImageFileMessage(ChatMessage message) async {
    final mediaUrl = _endpoint?.mediaUrl ?? _endpoint?.url ?? '';
    var request = http.MultipartRequest('POST', Uri.parse(mediaUrl));

    request.fields['action'] = _endpoint?.imageAction ?? 'sendImage';
    request.fields['sessionId'] = SessionService.currentSessionId ?? 'no-session';
    request.fields['chatInput'] = 'Image send';
    _applyMediaAuth(request);

    // Add chatType if available
    if (_chatType != null) {
      request.fields['chatType'] = _chatType!;
    }


    request.files.add(
      await http.MultipartFile.fromPath(
        'image',
        message.imageFile!.path,
        filename: 'image.jpg',
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      String botResponse = _parseWebhookResponse(
        response.body,
        'Afbeelding ontvangen en geanalyseerd',
      );

      setState(() {
        _messages.insert(
          0,
          ChatMessage(
            text: botResponse,
            isCustomer: false,
            timestamp: DateTime.now(),
            status: MessageStatus.sent,
          ),
        );
      });

      _displaySendToTeamBanner();

      // Fetch updated chat title
      _fetchChatTitle();
    } else {
      throw Exception('Failed to send image: ${response.statusCode}');
    }
  }

  // Send audio file message (simplified version)
  Future<void> _sendAudioFileMessage(ChatMessage message) async {
    final mediaUrl = _endpoint?.mediaUrl ?? _endpoint?.url ?? '';
    var request = http.MultipartRequest('POST', Uri.parse(mediaUrl));

    request.fields['action'] = _endpoint?.audioAction ?? 'sendAudio';
    request.fields['sessionId'] = SessionService.currentSessionId ?? 'no-session';
    request.fields['chatInput'] = 'Audio send';
    _applyMediaAuth(request);

    // Add chatType if available
    if (_chatType != null) {
      request.fields['chatType'] = _chatType!;
    }


    request.files.add(
      await http.MultipartFile.fromPath(
        'audio',
        message.audioFile!.path,
        filename: 'audio.m4a',
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      String botResponse = _parseWebhookResponse(
        response.body,
        'Audio ontvangen en getranscribeerd',
      );

      setState(() {
        _messages.insert(
          0,
          ChatMessage(
            text: botResponse,
            isCustomer: false,
            timestamp: DateTime.now(),
            status: MessageStatus.sent,
          ),
        );
      });

      // Generate and play audio if enabled
      await _generateAndPlayAudio();

      _displaySendToTeamBanner();

      // Fetch updated chat title
      _fetchChatTitle();
    } else {
      throw Exception('Failed to send audio: ${response.statusCode}');
    }
  }

  // Send document file message (simplified version)
  Future<void> _sendDocumentFileMessage(ChatMessage message) async {
    final mediaUrl = _endpoint?.mediaUrl ?? _endpoint?.url ?? '';
    var request = http.MultipartRequest('POST', Uri.parse(mediaUrl));

    request.fields['action'] = _endpoint?.documentAction ?? 'sendDocument';
    request.fields['sessionId'] = SessionService.currentSessionId ?? 'no-session';
    request.fields['chatInput'] = 'Document send';
    _applyMediaAuth(request);

    // Add chatType if available
    if (_chatType != null) {
      request.fields['chatType'] = _chatType!;
    }


    final fileInfo = AttachmentService.getFileInfo(message.documentFile!);
    request.files.add(
      await http.MultipartFile.fromPath(
        'document',
        message.documentFile!.path,
        filename: fileInfo['fileName'],
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      String botResponse = _parseWebhookResponse(
        response.body,
        'Document ontvangen en geanalyseerd',
      );

      setState(() {
        _messages.insert(
          0,
          ChatMessage(
            text: botResponse,
            isCustomer: false,
            timestamp: DateTime.now(),
            status: MessageStatus.sent,
          ),
        );
      });

      _displaySendToTeamBanner();

      // Fetch updated chat title
      _fetchChatTitle();
    } else {
      throw Exception('Failed to send document: ${response.statusCode}');
    }
  }

  // Send video file message
  Future<void> _sendVideoFileMessage(ChatMessage message) async {
    final mediaUrl = _endpoint?.mediaUrl ?? _endpoint?.url ?? '';
    var request = http.MultipartRequest('POST', Uri.parse(mediaUrl));

    request.fields['action'] = _endpoint?.videoAction ?? 'sendVideo';
    request.fields['sessionId'] = SessionService.currentSessionId ?? 'no-session';
    request.fields['chatInput'] = 'Video send';
    _applyMediaAuth(request);

    // Add chatType if available
    if (_chatType != null) {
      request.fields['chatType'] = _chatType!;
    }


    // Get video filename
    final videoPath = message.videoFile!.path;
    final filename = videoPath.split('/').last;

    request.files.add(
      await http.MultipartFile.fromPath(
        'video',
        message.videoFile!.path,
        filename: filename,
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      String botResponse = _parseWebhookResponse(
        response.body,
        'Video ontvangen en geanalyseerd',
      );

      setState(() {
        _messages.insert(
          0,
          ChatMessage(
            text: botResponse,
            isCustomer: false,
            timestamp: DateTime.now(),
            status: MessageStatus.sent,
          ),
        );
      });

      _displaySendToTeamBanner();

      // Fetch updated chat title
      _fetchChatTitle();
    } else {
      throw Exception('Failed to send video: ${response.statusCode}');
    }
  }

  Future<void> _sendEmail() async {
    if (_isEmailSending) return;

    setState(() {
      _isEmailSending = true;
    });

    // Show loading message in chat
    await _addMessage(
      ChatMessage(
        text: "Email wordt verzonden...",
        isCustomer: false,
        timestamp: DateTime.now(),
        status: MessageStatus.sent,
      ),
    );

    _scrollToBottom();

    try {
      // Prepare session data and messages for email
      final emailData = {
        'action': 'sendEmail',
        'sessionId': SessionService.currentSessionId ?? 'no-session',
        'messages':
            _messages
                .map(
                  (msg) => {
                    'text': msg.text,
                    'isCustomer': msg.isCustomer,
                    'timestamp': msg.timestamp.toIso8601String(),
                    'attachmentType': msg.attachmentType.toString(),
                  },
                )
                .toList(),
      };

      final response = await http
          .post(
            Uri.parse(_endpoint?.url ?? ''),
            headers: _buildHeaders(additional: {
              'Accept': 'application/json',
              'X-Session-ID': SessionService.currentSessionId ?? 'no-session',
            }),
            body: jsonEncode(emailData),
          )
          .timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        // Success - show webhook response (keep same session)
        String emailResponse = '';

        emailResponse = _parseWebhookResponse(
          response.body,
          'Email succesvol verzonden',
        );

        await _addMessage(
          ChatMessage(
            text: emailResponse,
            isCustomer: false,
            timestamp: DateTime.now(),
            status: MessageStatus.sent,
          ),
        );

        // Mark session as email sent
        await SessionService.markCurrentSessionEmailSent();

        // Reset typing flag to show the new banner message
        setState(() {
          _userTypedAfterEmailSent = false;
        });
      } else {
        // Failure - show error message
        String errorMessage = 'Email verzenden mislukt';
        try {
          final data = jsonDecode(response.body);
          if (data is Map && data['error'] != null) {
            errorMessage = 'Email verzenden mislukt: ${data['error']}';
          } else {
            errorMessage =
                'Email verzenden mislukt (Status: ${response.statusCode})';
          }
        } catch (e) {
          errorMessage =
              'Email verzenden mislukt (Status: ${response.statusCode})';
        }

        await _addMessage(
          ChatMessage(
            text: errorMessage,
            isCustomer: false,
            timestamp: DateTime.now(),
            status: MessageStatus.sent,
          ),
        );
      }
    } catch (e) {
      // Error handling
      await _addMessage(
        ChatMessage(
          text:
              'Email verzenden mislukt: Controleer je internetverbinding en probeer het opnieuw.',
          isCustomer: false,
          timestamp: DateTime.now(),
          status: MessageStatus.sent,
        ),
      );
    } finally {
      setState(() {
        _isEmailSending = false;
      });
      _scrollToBottom();
    }
  }

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'forward_conversation':
        _sendEmail();
        break;
      case 'conversation_info':
        _showConversationInfo();
        break;
      case 'clear_conversation':
        _clearConversation();
        break;
      case 'privacy_policy':
        _openPrivacyPolicy();
        break;
      case 'help_support':
        _openHelpSupport();
        break;
      case 'about_app':
        _showAboutDialog();
        break;
    }
  }

  Future<void> _clearConversation() async {
    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('Chat wissen'),
                  content: const Text(
                    'Weet je zeker dat je alle berichten wilt verwijderen?',
                  ),
                  actions: [
                    TextButton(
                      onPressed:
                          _isDeletingSession
                              ? null
                              : () => Navigator.pop(context),
                      child: const Text('Annuleer'),
                    ),
                    TextButton(
                      onPressed:
                          _isDeletingSession
                              ? null
                              : () async {
                                final currentSessionId =
                                    SessionService.currentSessionId;
                                if (currentSessionId == null) {
                                  Navigator.pop(context);
                                  return;
                                }

                                // Capture context before async gap
                                final dialogContext = context;
                                final scaffoldContext = this.context;

                                setDialogState(() {
                                  _isDeletingSession = true;
                                });

                                // Call webhook to delete session
                                final success = await _deleteSessionOnWebhook(
                                  currentSessionId,
                                );

                                if (success) {
                                  // Clear stored messages for this session
                                  await StorageService.clearMessages(
                                    currentSessionId,
                                  );

                                  // Clear current session data
                                  await SessionService.clearSession();

                                  // Close dialog and navigate to SessionsScreen
                                  if (mounted) {
                                    // ignore: use_build_context_synchronously
                                    Navigator.pop(dialogContext);
                                    // ignore: use_build_context_synchronously
                                    Navigator.pushReplacement(
                                      // ignore: use_build_context_synchronously
                                      scaffoldContext,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => const SessionsScreen(),
                                      ),
                                    );
                                  }
                                } else {
                                  // Show error message
                                  setDialogState(() {
                                    _isDeletingSession = false;
                                  });

                                  if (mounted) {
                                    // ignore: use_build_context_synchronously
                                    ScaffoldMessenger.of(
                                      scaffoldContext,
                                    ).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Kon sessie niet verwijderen. Probeer het opnieuw.',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                      child:
                          _isDeletingSession
                              ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text('Wissen'),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<void> _showConversationInfo() async {
    final sessionData = SessionService.currentSessionData;

    if (sessionData == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Geen sessie informatie beschikbaar'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    String formatDate(String? isoDate) {
      if (isoDate == null || isoDate.isEmpty) return 'Onbekend';
      try {
        final date = DateTime.parse(isoDate);
        return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
      } catch (e) {
        return 'Onbekende datum';
      }
    }

    if (mounted) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text(
                'Gesprek Informatie',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Sessie ID', sessionData.sessionId),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      'Titel',
                      sessionData.title.isNotEmpty
                          ? sessionData.title
                          : 'Geen titel',
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      'Omschrijving',
                      sessionData.description.isNotEmpty
                          ? sessionData.description
                          : 'Geen omschrijving',
                      maxLines: null,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      'Chattype',
                      sessionData.chatType ?? 'Onbekend',
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      'Aangemaakt op',
                      formatDate(sessionData.createdAt),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      'Laatst gewijzigd',
                      formatDate(sessionData.lastActivity),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Sluiten'),
                ),
              ],
            ),
      );
    }
  }

  Widget _buildInfoRow(String label, String value, {int? maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
          maxLines: maxLines,
          overflow:
              maxLines != null ? TextOverflow.ellipsis : TextOverflow.visible,
        ),
      ],
    );
  }

  // Title is set from the endpoint name — no backend needed
  Future<void> _fetchChatTitle() async {
    if (_endpoint != null && mounted) {
      setState(() => _chatTitle = _endpoint!.name);
      await SessionService.updateCurrentSession(title: _endpoint!.name);
    }
  }

  // Deletes session locally — no backend call needed
  Future<bool> _deleteSessionOnWebhook(String sessionId) async {
    return true;
  }

  Future<void> _openPrivacyPolicy() async {
    final Uri privacyUri = Uri.parse('https://unlockyourcloud.com/privacy');
    if (await canLaunchUrl(privacyUri)) {
      await launchUrl(privacyUri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open browser')),
        );
      }
    }
  }

  Future<void> _openHelpSupport() async {
    final Uri supportUri = Uri.parse('https://unlockyourcloud.com/support');
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
                      color: Color(0xFF1a6b8a),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        'U',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // App name
                  const Text(
                    'UYC',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Unlock Your Cloud',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  // Version
                  Text(
                    'Versie ${packageInfo.version}',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  // Close button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1a6b8a),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Sluiten',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: const BoxDecoration(
        color: Color(0x1A000000), // 10% black overlay
        border: Border(bottom: BorderSide(color: Color(0x1AFFFFFF), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: Icon(
              Icons.arrow_back_ios,
              color: AppColors.textLight,
              size: 24,
            ),
            padding: const EdgeInsets.all(8.0),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                _chatTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textLight,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _audioEnabled = !_audioEnabled;
              });
            },
            icon: Icon(
              _audioEnabled ? Icons.volume_up : Icons.volume_off,
              color:
                  _audioEnabled
                      ? AppColors.accent
                      : AppColors.textLight.withValues(alpha: 0.6),
              size: 24,
            ),
            padding: const EdgeInsets.all(8.0),
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuSelection,
            icon: Container(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                '⋮',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textLight,
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
                    value: 'conversation_info',
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.grey,
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Gesprek Informatie',
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
                    value: 'forward_conversation',
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: const Row(
                        children: [
                          Icon(Icons.mail, color: Colors.grey, size: 20),
                          SizedBox(width: 12),
                          Text(
                            'Gesprek doorsturen',
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
                    value: 'clear_conversation',
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: const Row(
                        children: [
                          Icon(Icons.delete, color: Colors.grey, size: 20),
                          SizedBox(width: 12),
                          Text(
                            'Gesprek wissen',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const PopupMenuDivider(),
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
                  const PopupMenuDivider(),
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

  Widget _buildEmailSentBanner() {
    // Show banner if email was already sent when chat was opened
    if (SessionService.currentSessionData?.emailSent != true) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC6F6D5), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: Color(0xFF22C55E),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 12),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dit gesprek is al doorgestuurd',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF15803D),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Wil je nog iets toevoegen? Dat kan, typ het hieronder!',
                  style: TextStyle(fontSize: 13, color: Color(0xFF166534)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendToTeamBanner() {
    if (!_showSendToTeamBanner) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: Color(0xFFCC0001),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 12),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Alle info compleet? Klik op verstuur, dan gaan wij aan de slag!',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF374151),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: () {
              setState(() {
                _showSendToTeamBanner = false;
              });
              _bannerTimer?.cancel();
              _sendEmail();
            },
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFCC0001),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text(
              'Klaar -> verstuur',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  void _displaySendToTeamBanner() {
    // Cancel any existing timer
    _bannerTimer?.cancel();

    // Make banner available and show if text field is empty
    setState(() {
      _bannerAvailable = true;
      _showSendToTeamBanner = _messageController.text.trim().isEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final homeIndicatorHeight = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.primary,
      resizeToAvoidBottomInset: false,
      body: Padding(
        padding: EdgeInsets.only(bottom: keyboardHeight),
        child: Column(
          children: [
            // Custom Header
            Container(
              padding: EdgeInsets.only(top: statusBarHeight),
              child: _buildHeader(),
            ),

            // Chat messages
            Expanded(
              child: Align(
                alignment:
                    Alignment.topCenter, // CRITICAL for keyboard response
                child: GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  behavior: HitTestBehavior.opaque,
                  child: ListView.builder(
                    reverse: true, // Build from bottom - chat standard
                    shrinkWrap:
                        true, // Takes only needed space - responds to keyboard
                    controller: _scrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Show typing indicator at bottom (first item in reverse list) when loading
                      if (index == 0 && _isLoading) {
                        return TypingIndicator(
                          isUploadingFile: _isUploadingFile,
                        );
                      }
                      // Adjust message index to account for typing indicator
                      final messageIndex = _isLoading ? index - 1 : index;
                      return ChatBubble(
                        message: _messages[messageIndex],
                        onImageLongPress: _showImageDeleteDialog,
                        onImageTap: _viewImage,
                        onDocumentLongPress: _showDocumentDeleteDialog,
                        onDocumentTap: _openDocument,
                        onVideoLongPress: _showVideoDeleteDialog,
                        onVideoTap: _playVideo,
                      );
                    },
                  ),
                ),
              ),
            ),

            _buildEmailSentBanner(),

            _buildSendToTeamBanner(),

            // Recording indicator
            if (_isRecording)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: Colors.red.shade50,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.fiber_manual_record,
                      color: Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Opnemen... ${_formatDuration(_recordingDuration)}',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            // Message input
            Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 16 + homeIndicatorHeight,
              ),
              decoration: const BoxDecoration(
                color: Color(0x1A000000), // 10% black overlay
                border: Border(top: BorderSide(color: Color(0x1AFFFFFF), width: 1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0x1AFFFFFF), // 10% white background
                        border: Border.all(color: const Color(0x1AFFFFFF)),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          // Attachment icon (only shown when media URL is configured)
                          if (_endpoint?.mediaUrl?.isNotEmpty == true)
                            IconButton(
                              onPressed:
                                  _isLoading ? null : _showAttachmentDialog,
                              icon: Icon(
                                Icons.attach_file,
                                color:
                                    _isLoading
                                        ? AppColors.textLight.withValues(alpha: 0.3)
                                        : AppColors.textLight.withValues(alpha: 0.7),
                                size: 20,
                              ),
                            ),
                          // Text input
                          Expanded(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                minHeight:
                                    48.0, // Single line height (24px text + 24px padding)
                                maxHeight:
                                    144.0, // 6 lines height (6 * 24px text + 24px padding)
                              ),
                              child: TextField(
                                controller: _messageController,
                                onChanged: _onTextChanged,
                                onTap: _onTextFieldTapped,
                                enabled: !_isLoading,
                                style: TextStyle(color: AppColors.textLight),
                                decoration: InputDecoration(
                                  hintText:
                                      _isLoading
                                          ? 'Even geduld...'
                                          : 'Deel je blog idee...',
                                  hintStyle: TextStyle(
                                    color: AppColors.textLight.withValues(alpha: 0.4),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                maxLines: null,
                                textInputAction: TextInputAction.newline,
                                scrollPhysics: const BouncingScrollPhysics(),
                              ),
                            ),
                          ),
                          // Camera icon
                          IconButton(
                            onPressed:
                                _isLoading ? null : _showImageSourceDialog,
                            icon: Icon(
                              Icons.camera_alt,
                              color:
                                  _isLoading
                                      ? AppColors.textLight.withValues(alpha: 0.3)
                                      : AppColors.textLight.withValues(alpha: 0.7),
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Voice or Send button
                  Container(
                    decoration: BoxDecoration(
                      color:
                          _isLoading
                              ? AppColors.accent.withValues(alpha: 0.5)
                              : (_isRecording
                                  ? Colors.red
                                  : AppColors.accent),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed:
                          _isLoading
                              ? null
                              : (_isTyping
                                  ? _sendMessage
                                  : _isRecording
                                  ? _stopRecording
                                  : _startRecording),
                      icon:
                          _isLoading
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                              : Icon(
                                _isTyping
                                    ? Icons.send
                                    : (_isRecording ? Icons.stop : Icons.mic),
                                color: Colors.white,
                              ),
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
}

enum AttachmentType { none, audio, image, document, video }

class MediaMetadata {
  final String id;
  final String sessionId;
  final String filename;
  final String? description; // Only for images
  final String? seoTitle; // Only for images
  final String? mimeType; // Only for documents/videos
  final String storageUrl;
  final String? thumbnailUrl; // Only for videos
  final DateTime createdAt;

  MediaMetadata({
    required this.id,
    required this.sessionId,
    required this.filename,
    this.description,
    this.seoTitle,
    this.mimeType,
    required this.storageUrl,
    this.thumbnailUrl,
    required this.createdAt,
  });

  String get previewUrl => '$storageUrl/preview';

  // For videos: use thumbnail_url + '/preview' to show video thumbnail
  String? get thumbnailPreviewUrl =>
      thumbnailUrl != null ? '$thumbnailUrl/preview' : null;

  factory MediaMetadata.fromJson(Map<String, dynamic> json) {
    return MediaMetadata(
      id: json['id'] ?? '',
      sessionId: json['session_id'] ?? '',
      filename: json['filename'] ?? '',
      description: json['description'], // Optional - only for images
      seoTitle: json['seo_title'], // Optional - only for images
      mimeType: json['mime_type'], // Optional - only for docs/videos
      storageUrl: json['storage_url'] ?? '',
      thumbnailUrl: json['thumbnail_url'], // Optional - only for videos
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      'filename': filename,
      if (description != null) 'description': description,
      if (seoTitle != null) 'seo_title': seoTitle,
      if (mimeType != null) 'mime_type': mimeType,
      'storage_url': storageUrl,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

enum MessageStatus { pending, uploading, sent, failed }

class ChatMessage {
  final String text;
  final bool isCustomer;
  final DateTime timestamp;
  final File? audioFile;
  final File? imageFile;
  final File? documentFile;
  final File? videoFile;
  final File? videoThumbnailFile; // Local temp thumbnail during upload
  final AttachmentType attachmentType;
  final MessageStatus status;
  final bool fromFCM;
  final bool autoPlay;
  final MediaMetadata?
  mediaMetadata; // Nextcloud storage metadata for images/videos/documents

  ChatMessage({
    required this.text,
    required this.isCustomer,
    required this.timestamp,
    this.audioFile,
    this.imageFile,
    this.documentFile,
    this.videoFile,
    this.videoThumbnailFile,
    this.attachmentType = AttachmentType.none,
    this.status = MessageStatus.pending,
    this.fromFCM = false,
    this.autoPlay = false,
    this.mediaMetadata,
  });

  // Convert to JSON for storage (files stored as paths)
  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'isCustomer': isCustomer,
      'timestamp': timestamp.toIso8601String(),
      'audioFilePath': audioFile?.path,
      'imageFilePath': imageFile?.path,
      'documentFilePath': documentFile?.path,
      'videoFilePath': videoFile?.path,
      'videoThumbnailFilePath': videoThumbnailFile?.path,
      'attachmentType': attachmentType.toString(),
      'status': status.toString(),
      'fromFCM': fromFCM,
      'mediaMetadata': mediaMetadata?.toJson(),
    };
  }

  // Create from JSON (recreate File objects from paths if they exist)
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      text: json['text'],
      isCustomer: json['isCustomer'],
      timestamp: DateTime.parse(json['timestamp']),
      audioFile:
          json['audioFilePath'] != null ? File(json['audioFilePath']) : null,
      imageFile:
          json['imageFilePath'] != null ? File(json['imageFilePath']) : null,
      documentFile:
          json['documentFilePath'] != null
              ? File(json['documentFilePath'])
              : null,
      videoFile:
          json['videoFilePath'] != null ? File(json['videoFilePath']) : null,
      videoThumbnailFile:
          json['videoThumbnailFilePath'] != null
              ? File(json['videoThumbnailFilePath'])
              : null,
      attachmentType: _parseAttachmentType(json['attachmentType']),
      status: _parseMessageStatus(json['status']),
      fromFCM: json['fromFCM'] ?? false,
      mediaMetadata:
          json['mediaMetadata'] != null
              ? MediaMetadata.fromJson(json['mediaMetadata'])
              : null,
    );
  }

  // Helper to parse attachment type from string
  static AttachmentType _parseAttachmentType(String? typeString) {
    switch (typeString) {
      case 'AttachmentType.audio':
        return AttachmentType.audio;
      case 'AttachmentType.image':
        return AttachmentType.image;
      case 'AttachmentType.document':
        return AttachmentType.document;
      case 'AttachmentType.video':
        return AttachmentType.video;
      default:
        return AttachmentType.none;
    }
  }

  // Helper to parse message status from string
  static MessageStatus _parseMessageStatus(String? statusString) {
    switch (statusString) {
      case 'MessageStatus.sent':
        return MessageStatus.sent;
      case 'MessageStatus.uploading':
        return MessageStatus.uploading;
      case 'MessageStatus.failed':
        return MessageStatus.failed;
      case 'MessageStatus.pending':
      default:
        return MessageStatus.pending;
    }
  }
}

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final Function(ChatMessage)? onImageLongPress;
  final Function(ChatMessage)? onImageTap;
  final Function(ChatMessage)? onDocumentLongPress;
  final Function(ChatMessage)? onDocumentTap;
  final Function(ChatMessage)? onVideoLongPress;
  final Function(ChatMessage)? onVideoTap;

  const ChatBubble({
    super.key,
    required this.message,
    this.onImageLongPress,
    this.onImageTap,
    this.onDocumentLongPress,
    this.onDocumentTap,
    this.onVideoLongPress,
    this.onVideoTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            message.isCustomer
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
        children: [
          if (!message.isCustomer) ...[
            CircleAvatar(
              backgroundColor: AppColors.accent,
              radius: 16,
              child: Icon(Icons.smart_toy, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color:
                        message.isCustomer
                            ? AppColors.accent // Orange for user messages
                            : const Color(0x1FFFFFFF), // 12% white for bot messages
                    borderRadius: BorderRadius.circular(18).copyWith(
                      // Speech bubble tail
                      bottomRight: message.isCustomer ? const Radius.circular(4) : null,
                      bottomLeft: !message.isCustomer ? const Radius.circular(4) : null,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.attachmentType == AttachmentType.audio &&
                          message.audioFile != null)
                        AudioMessageWidget(
                          audioFile: message.audioFile!,
                          isCustomer: message.isCustomer,
                          duration: message.text
                              .replaceAll('🎤 Audio bericht (', '')
                              .replaceAll(')', ''),
                          autoPlay: message.autoPlay,
                        )
                      else if (message.attachmentType == AttachmentType.image &&
                          (message.imageFile != null ||
                              message.mediaMetadata != null))
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ImageMessageWidget(
                              imageFile: message.imageFile,
                              imageUrl: message.mediaMetadata?.previewUrl,
                              isCustomer: message.isCustomer,
                              isUploading:
                                  message.status == MessageStatus.uploading,
                              title: message.mediaMetadata?.filename,
                              onTap:
                                  onImageTap != null
                                      ? () => onImageTap!(message)
                                      : null,
                              onLongPress:
                                  onImageLongPress != null
                                      ? () => onImageLongPress!(message)
                                      : null,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTime(message.timestamp),
                              style: TextStyle(
                                color: AppColors.textLight.withValues(alpha: 0.5),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        )
                      else if (message.attachmentType ==
                              AttachmentType.document &&
                          (message.documentFile != null ||
                              message.mediaMetadata != null))
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DocumentMessageWidget(
                              documentFile: message.documentFile,
                              documentUrl: message.mediaMetadata?.previewUrl,
                              isCustomer: message.isCustomer,
                              fileName:
                                  message.mediaMetadata?.filename ??
                                  (message.documentFile != null &&
                                          message.documentFile!.existsSync()
                                      ? AttachmentService.getFileInfo(
                                        message.documentFile!,
                                      )['fileName']
                                      : 'Document'),
                              fileSize:
                                  message.documentFile != null &&
                                          message.documentFile!.existsSync()
                                      ? AttachmentService.getFileInfo(
                                        message.documentFile!,
                                      )['size']
                                      : 0,
                              isUploading:
                                  message.status == MessageStatus.uploading,
                              onTap:
                                  onDocumentTap != null
                                      ? () => onDocumentTap!(message)
                                      : null,
                              onLongPress:
                                  onDocumentLongPress != null
                                      ? () => onDocumentLongPress!(message)
                                      : null,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTime(message.timestamp),
                              style: TextStyle(
                                color: AppColors.textLight.withValues(alpha: 0.5),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        )
                      else if (message.attachmentType == AttachmentType.video &&
                          message.mediaMetadata != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            VideoMessageWidget(
                              thumbnailFile: message.videoThumbnailFile,
                              thumbnailUrl:
                                  message.mediaMetadata?.thumbnailPreviewUrl,
                              isCustomer: message.isCustomer,
                              isUploading:
                                  message.status == MessageStatus.uploading,
                              title: message.mediaMetadata!.filename,
                              onTap:
                                  onVideoTap != null
                                      ? () => onVideoTap!(message)
                                      : null,
                              onLongPress:
                                  onVideoLongPress != null
                                      ? () => onVideoLongPress!(message)
                                      : null,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTime(message.timestamp),
                              style: TextStyle(
                                color: AppColors.textLight.withValues(alpha: 0.5),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LinkableSelectableText(
                              text: message.text,
                              style: TextStyle(
                                color: AppColors.textLight,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTime(message.timestamp),
                              style: TextStyle(
                                color: AppColors.textLight.withValues(alpha: 0.5),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                // Status icon for pending customer messages
                if (message.isCustomer &&
                    message.status == MessageStatus.pending)
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Icon(
                      Icons.access_time,
                      size: 14,
                      color: AppColors.textLight.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
          ),
          if (message.isCustomer) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              backgroundColor: Colors.grey,
              radius: 16,
              child: Icon(Icons.person, color: Colors.white, size: 18),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }
}

class TypingIndicator extends StatefulWidget {
  final bool isUploadingFile;

  const TypingIndicator({super.key, required this.isUploadingFile});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppColors.accent,
            radius: 16,
            child: Icon(Icons.smart_toy, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0x1FFFFFFF), // 12% white
              borderRadius: BorderRadius.circular(18).copyWith(
                bottomLeft: const Radius.circular(4), // Speech bubble tail
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.isUploadingFile ? 'Bestand uploaden' : 'Aan het typen',
                  style: TextStyle(color: AppColors.textLight, fontSize: 16),
                ),
                const SizedBox(width: 8),
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Row(
                      children: List.generate(3, (index) {
                        final delay = index * 0.2;
                        final animValue = (_animationController.value - delay)
                            .clamp(0.0, 1.0);
                        final opacity =
                            (animValue < 0.5)
                                ? animValue * 2
                                : 2 - (animValue * 2);

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1),
                          child: Opacity(
                            opacity: opacity,
                            child: Text(
                              '•',
                              style: TextStyle(
                                fontSize: 20,
                                color: AppColors.textLight.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LinkableSelectableText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const LinkableSelectableText({super.key, required this.text, this.style});

  @override
  Widget build(BuildContext context) {
    return SelectableText.rich(_buildTextSpan(), style: style);
  }

  TextSpan _buildTextSpan() {
    final List<TextSpan> children = [];
    final RegExp linkRegExp = RegExp(
      r'(https?://[^\s]+|www\.[^\s]+|[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}|\+?[\d\s\-\(\)]+(?:\d{3,}))',
      caseSensitive: false,
    );

    int currentIndex = 0;
    final matches = linkRegExp.allMatches(text);

    for (final match in matches) {
      // Add text before the link
      if (match.start > currentIndex) {
        children.add(
          TextSpan(
            text: text.substring(currentIndex, match.start),
            style: style,
          ),
        );
      }

      // Add the clickable link
      final linkText = match.group(0)!;
      children.add(
        TextSpan(
          text: linkText,
          style: style?.copyWith(
            color: Colors.blue,
            decoration: TextDecoration.underline,
          ),
          recognizer:
              TapGestureRecognizer()..onTap = () => _launchUrl(linkText),
        ),
      );

      currentIndex = match.end;
    }

    // Add remaining text after the last link
    if (currentIndex < text.length) {
      children.add(TextSpan(text: text.substring(currentIndex), style: style));
    }

    // If no links found, return the entire text as a single span
    if (children.isEmpty) {
      return TextSpan(text: text, style: style);
    }

    return TextSpan(children: children);
  }

  Future<void> _launchUrl(String urlString) async {
    Uri? uri;

    // Handle different URL formats
    if (urlString.contains('@')) {
      // Email address
      uri = Uri.parse('mailto:$urlString');
    } else if (urlString.startsWith(RegExp(r'\+?[\d\s\-\(\)]'))) {
      // Phone number
      final cleanPhone = urlString.replaceAll(RegExp(r'[\s\-\(\)]'), '');
      uri = Uri.parse('tel:$cleanPhone');
    } else if (urlString.startsWith('www.')) {
      // www links
      uri = Uri.parse('https://$urlString');
    } else if (urlString.startsWith(RegExp(r'https?://'))) {
      // Full URLs
      uri = Uri.parse(urlString);
    }

    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
