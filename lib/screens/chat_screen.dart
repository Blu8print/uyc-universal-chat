import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import '../services/auth_service.dart';
import '../services/audio_recording_service.dart';
import '../services/session_service.dart';
import '../services/storage_service.dart';
import '../services/attachment_service.dart';
import '../services/firebase_messaging_service.dart';
import '../services/api_service.dart';
import '../widgets/audio_message_widget.dart';
import '../widgets/image_message_widget.dart';
import '../widgets/document_message_widget.dart';
import 'package:image_picker/image_picker.dart';
import 'start_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:light_compressor/light_compressor.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kwaaijongens APP',
      theme: ThemeData(
        primarySwatch: Colors.red,
        primaryColor: const Color(0xFFCC0001),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFCC0001),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const ChatScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String? actionContext;
  
  const ChatScreen({super.key, this.actionContext});

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
  Timer? _bannerTimer;
  String _chatTitle = 'Chat';
  String? _chatType;

  final String _n8nChatUrl = 'https://automation.kwaaijongens.nl/webhook/46b0b5ec-132d-4aca-97ec-0d11d05f66bc/chat';
  final String _n8nImageUrl = 'https://automation.kwaaijongens.nl/webhook/media_image';
  final String _n8nDocumentUrl = 'https://automation.kwaaijongens.nl/webhook/media_document';
  final String _n8nVideoUrl = 'https://automation.kwaaijongens.nl/webhook/media_video';
  final String _n8nEmailUrl = 'https://automation.kwaaijongens.nl/webhook/send-email';
  final String _n8nSessionsUrl = 'https://automation.kwaaijongens.nl/webhook/sessions';

  // Basic Auth credentials
  static const String _basicAuth = 'SystemArchitect:A\$pp_S3cr3t';

  // Helper method to get Basic Auth header
  String _getBasicAuthHeader() {
    final authBytes = utf8.encode(_basicAuth);
    return 'Basic ${base64Encode(authBytes)}';
  }

  final List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }
  
  Future<void> _handleActionContext() async {
    if (widget.actionContext != null) {
      String contextMessage = '';
      switch (widget.actionContext) {
        case 'project':
          contextMessage = 'Ik wil een project doorgeven. ';
          _chatType = 'project_doorgeven';
          break;
        case 'knowledge':
          contextMessage = 'Ik wil mijn vakkennis delen voor een blog. ';
          _chatType = 'vakkennis_delen';
          break;
        case 'social':
          contextMessage = 'Ik wil content maken voor social media. ';
          _chatType = 'social_media';
          break;
      }

      if (contextMessage.isNotEmpty) {
        // Add context message as first user message
        final contextChatMessage = ChatMessage(
          text: contextMessage,
          isCustomer: true,
          timestamp: DateTime.now(),
        );

        await _addMessage(contextChatMessage);
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
    await SessionService.initializeWithSync();
    await _initializeFirebaseMessaging();
  }

  Future<void> _initializeFirebaseMessaging() async {
    try {
      await FirebaseMessagingService.initialize();
      
      // Set message handler for foreground notifications
      FirebaseMessagingService.setMessageHandler(_handleFCMMessage);
      
      // Register FCM token with n8n backend
      final tokenData = FirebaseMessagingService.getTokenData();
      if (tokenData != null) {
        final user = AuthService.currentUser;
        await ApiService.sendFCMToken(
          fcmToken: tokenData['fcmToken'],
          sessionId: tokenData['sessionId'],
          platform: tokenData['platform'],
          phoneNumber: user?.phone,
        );
      }
    } catch (e) {
      print('Firebase Messaging initialization failed: $e');
    }
  }

  Future<void> _requestInitialPermissions() async {
    print('DEBUG: Requesting initial permissions...');
    final result = await _audioService.requestPermission();
    print('DEBUG: Initial permission result: $result');
  }

  Future<void> _initializeWelcomeMessage() async {
    final user = AuthService.currentUser;
    final userName = user?.name ?? 'daar';
    final companyName = user?.companyName ?? 'je bedrijf';
    
    // Load existing messages for current session
    final sessionId = SessionService.currentSessionId;
    if (sessionId != null) {
      final savedMessages = await StorageService.loadMessages(sessionId);
      
      if (savedMessages.isNotEmpty) {
        // Load existing messages
        final messages = savedMessages
            .map((json) => ChatMessage.fromJson(json))
            .where((msg) => _isFileStillValid(msg)) // Filter out messages with missing files
            .toList();
        
        setState(() {
          _messages.addAll(messages);
        });
        _scrollToBottom();
        return;
      }
    }
    
    // No existing messages - add welcome message
    await _addMessage(ChatMessage(
      text: "Hallo $userName! Ik ben je AI-assistent van Kwaaijongens. Ik help $companyName graag met blog ideeën en content creatie. Waar kan ik je mee helpen?",
      isCustomer: false,
      timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
      status: MessageStatus.sent,
    ));
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

  // Save messages to storage
  Future<void> _saveMessages() async {
    final sessionId = SessionService.currentSessionId;
    if (sessionId != null) {
      final messagesJson = _messages.map((msg) => msg.toJson()).toList();
      await StorageService.saveMessages(sessionId, messagesJson);
      
      // Update session metadata after sending messages
      if (_messages.isNotEmpty) {
        await SessionService.updateCurrentSession();
      }
    }
  }

  // Add message and save to storage
  Future<void> _addMessage(ChatMessage message) async {
    setState(() {
      _messages.add(message);
    });
    await _saveMessages();
  }

  // Handle FCM messages received while app is in foreground
  void _handleFCMMessage(Map<String, dynamic> messageData) {
    try {
      // Extract message content from FCM data
      final String? messageText = messageData['message'] ?? messageData['body'] ?? messageData['content'];
      final String? sessionId = messageData['sessionId'];
      
      // Only process messages for current session
      if (sessionId != null && sessionId == SessionService.currentSessionId && messageText != null) {
        final fcmMessage = ChatMessage(
          text: messageText,
          isCustomer: false, // FCM messages are from the bot/system
          timestamp: DateTime.now(),
          status: MessageStatus.sent,
          fromFCM: true, // Mark this message as coming from FCM
        );
        
        _addMessage(fcmMessage);
        _scrollToBottom();
      }
    } catch (e) {
      print('Error handling FCM message: $e');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _audioService.dispose();
    _recordingTimer?.cancel();
    _bannerTimer?.cancel();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
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

  Future<void> _sendToN8n(String message) async {
    try {
      final response = await http.post(
        Uri.parse(_n8nChatUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': _getBasicAuthHeader(),
          'X-Session-ID': SessionService.currentSessionId ?? 'no-session',
        },
        body: jsonEncode({
          'action': 'sendMessage',
          'sessionId': SessionService.currentSessionId ?? 'no-session',
          'chatInput': message,
          'clientData': AuthService.getClientData(),
        }),
      ).timeout(const Duration(seconds: 30));
      
      // Log response details for debugging
      
      if (response.statusCode == 200) {
        String botResponse = _parseWebhookResponse(response.body, 'Geen reactie ontvangen');
        
        // Add bot response
        await _addMessage(ChatMessage(
          text: botResponse,
          isCustomer: false,
          timestamp: DateTime.now(),
        ));
        
        // Show send to team banner after AI response
        _displaySendToTeamBanner();
        
        // Fetch updated chat title
        _fetchChatTitle();
      } else {
        _addErrorMessage('Server error: ${response.statusCode}');
      }
    } catch (e) {
      // Error sending to n8n: $e
      await _addErrorMessage('Sorry, er ging iets mis. Controleer je internetverbinding en probeer het opnieuw.');
    }
  }

  Future<void> _addErrorMessage(String errorText) async {
    await _addMessage(ChatMessage(
      text: errorText,
      isCustomer: false,
      timestamp: DateTime.now(),
      status: MessageStatus.sent,
    ));
  }

  Future<void> _startRecording() async {
    // Hide banner temporarily during recording
    setState(() {
      _showSendToTeamBanner = false;
    });
    
    print('DEBUG: Starting recording...');
    final hasPermission = await _audioService.requestPermission();
    print('DEBUG: Recording permission granted: $hasPermission');
    
    if (!hasPermission) {
      print('DEBUG: Permission denied, showing snackbar');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microfoon toegang is vereist voor audio opnamen. Ga naar instellingen om dit toe te staan.'),
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
            content: Text('Kan opname niet starten. Controleer microfoon toegang.'),
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
        _showSendToTeamBanner = _bannerAvailable && _messageController.text.trim().isEmpty;
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

  Map<String, String> _getFileExtensionAndMimeType(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return {'extension': 'jpg', 'mimeType': 'image/jpeg'};
      case 'png':
        return {'extension': 'png', 'mimeType': 'image/png'};
      case 'heic':
        return {'extension': 'heic', 'mimeType': 'image/heic'};
      case 'webp':
        return {'extension': 'webp', 'mimeType': 'image/webp'};
      case 'gif':
        return {'extension': 'gif', 'mimeType': 'image/gif'};
      default:
        return {'extension': 'jpg', 'mimeType': 'image/jpeg'};
    }
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
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.description, color: Color(0xFFCC0001)),
                title: const Text('Document'),
                subtitle: const Text('PDF, Word, Excel, PowerPoint, ODT'),
                onTap: () {
                  Navigator.pop(context);
                  _pickDocument();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFFCC0001)),
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
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
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
                leading: const Icon(Icons.photo_library, color: Color(0xFFCC0001)),
                title: const Text('Foto kiezen'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_library, color: Color(0xFFCC0001)),
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
                content: Text('Galerij toegang is vereist om foto\'s te selecteren.'),
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
          _showSendToTeamBanner = _bannerAvailable && _messageController.text.trim().isEmpty;
        });
      }
    } catch (e) {
      // Error occurred - show banner again if available and text field empty
      setState(() {
        _showSendToTeamBanner = _bannerAvailable && _messageController.text.trim().isEmpty;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fout bij het selecteren van afbeelding: $e'),
          ),
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
                content: Text('Camera toegang is vereist om video\'s te maken.'),
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
                content: Text('Galerij toegang is vereist om video\'s te selecteren.'),
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
          _showSendToTeamBanner = _bannerAvailable && _messageController.text.trim().isEmpty;
        });
      }
    } catch (e) {
      // Error occurred - show banner again if available and text field empty
      setState(() {
        _showSendToTeamBanner = _bannerAvailable && _messageController.text.trim().isEmpty;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fout bij het selecteren van video: $e'),
          ),
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
              content: Text('Galerij toegang is vereist om foto\'s te selecteren.'),
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
        final imageFiles = limitedImages.map((xFile) => File(xFile.path)).toList();
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
          _messages.add(ChatMessage(
            text: 'Afbeelding ${i + 1} van ${imageFiles.length} wordt verzonden...',
            isCustomer: false,
            timestamp: DateTime.now(),
          ));
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
    
    // Create new image message with pending status
    final newMessage = ChatMessage(
      text: '📷 Afbeelding',
      isCustomer: true,
      timestamp: DateTime.now(),
      imageFile: imageFile,
      attachmentType: AttachmentType.image,
      status: MessageStatus.pending, // Start as pending
    );

    // Add message immediately
    await _addMessage(newMessage);
    _scrollToBottom();

    // Send in bulk with all pending messages
    await _sendBulkMessages(newMessage);
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
      _messages.add(compressingMessage);
    });
    _scrollToBottom();

    try {
      // Compress video
      final result = await LightCompressor().compressVideo(
        path: videoFile.path,
        videoQuality: VideoQuality.medium,
        isMinBitrateCheckEnabled: false,
        video: Video(videoName: 'compressed_${DateTime.now().millisecondsSinceEpoch}'),
        android: AndroidConfig(
          isSharedStorage: false,
        ),
        ios: IOSConfig(
          saveInGallery: false,
        ),
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
              content: Text('Compressie mislukt: ${result.message}. Originele video wordt verzonden.'),
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
            content: Text('Compressie fout: $e. Originele video wordt verzonden.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    // Create new video message with pending status
    final newMessage = ChatMessage(
      text: '🎥 Video',
      isCustomer: true,
      timestamp: DateTime.now(),
      videoFile: videoFile,
      attachmentType: AttachmentType.video,
      status: MessageStatus.pending,
    );

    // Add message immediately
    await _addMessage(newMessage);
    _scrollToBottom();

    // Send in bulk with all pending messages
    await _sendBulkMessages(newMessage);
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
          _showSendToTeamBanner = _bannerAvailable && _messageController.text.trim().isEmpty;
        });
      }
    } catch (e) {
      // Error occurred - show banner again if available and text field empty
      setState(() {
        _showSendToTeamBanner = _bannerAvailable && _messageController.text.trim().isEmpty;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fout bij het selecteren van document: $e'),
          ),
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
    
    // Create new document message with pending status
    final newMessage = ChatMessage(
      text: '📄 ${fileInfo['fileName']}',
      isCustomer: true,
      timestamp: DateTime.now(),
      documentFile: documentFile,
      attachmentType: AttachmentType.document,
      status: MessageStatus.pending, // Start as pending
    );

    // Add message immediately
    await _addMessage(newMessage);
    _scrollToBottom();

    // Send in bulk with all pending messages
    await _sendBulkMessages(newMessage);
  }


  void _onTextChanged(String text) {
    setState(() {
      _isTyping = text.trim().isNotEmpty;
    });
    
    // Show/hide banner based on text field state
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
      List<ChatMessage> textMessages = allMessagesToSend
          .where((msg) => msg.attachmentType == AttachmentType.none)
          .toList();
      List<ChatMessage> fileMessages = allMessagesToSend
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
      print('Bulk send failed: $e');
      _addErrorMessage('Sorry, er ging iets mis bij het versturen van berichten.');
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
    final requestBody = <String, dynamic>{
      'action': 'sendMessage',
    };

    // Add chatType right after action if available
    if (_chatType != null) {
      requestBody['chatType'] = _chatType!;
    }

    // Add remaining fields
    requestBody['sessionId'] = SessionService.currentSessionId ?? 'no-session';
    requestBody['chatInput'] = lastMessage.text;
    requestBody['clientData'] = AuthService.getClientData();

    final response = await http.post(
      Uri.parse(_n8nChatUrl),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': _getBasicAuthHeader(),
        'X-Session-ID': SessionService.currentSessionId ?? 'no-session',
      },
      body: jsonEncode(requestBody),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      String botResponse = _parseWebhookResponse(response.body, 'Bericht ontvangen en verwerkt');

      setState(() {
        _messages.add(ChatMessage(
          text: botResponse,
          isCustomer: false,
          timestamp: DateTime.now(),
          status: MessageStatus.sent,
        ));
      });
      
      // Show send to team banner after AI response
      _displaySendToTeamBanner();
      
      // Fetch updated chat title
      _fetchChatTitle();
    } else {
      throw Exception('Failed to send text messages: ${response.statusCode}');
    }
  }

  // Send individual file message
  Future<void> _sendIndividualFileMessage(ChatMessage fileMessage) async {
    if (fileMessage.attachmentType == AttachmentType.image && fileMessage.imageFile != null) {
      await _sendImageFileMessage(fileMessage);
    } else if (fileMessage.attachmentType == AttachmentType.audio && fileMessage.audioFile != null) {
      await _sendAudioFileMessage(fileMessage);
    } else if (fileMessage.attachmentType == AttachmentType.document && fileMessage.documentFile != null) {
      await _sendDocumentFileMessage(fileMessage);
    } else if (fileMessage.attachmentType == AttachmentType.video && fileMessage.videoFile != null) {
      await _sendVideoFileMessage(fileMessage);
    }
  }

  // Send image file message
  Future<void> _sendImageFileMessage(ChatMessage message) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse(_n8nImageUrl),
    );

    request.fields['action'] = 'sendImage';
    request.fields['sessionId'] = SessionService.currentSessionId ?? 'no-session';
    request.headers['Authorization'] = _getBasicAuthHeader();
    request.headers['X-Session-ID'] = SessionService.currentSessionId ?? 'no-session';

    // Add chatType if available
    if (_chatType != null) {
      request.fields['chatType'] = _chatType!;
    }

    final clientData = AuthService.getClientData();
    if (clientData != null) {
      request.fields['clientData'] = jsonEncode(clientData);
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
      String botResponse = _parseWebhookResponse(response.body, 'Afbeelding ontvangen en geanalyseerd');

      setState(() {
        _messages.add(ChatMessage(
          text: botResponse,
          isCustomer: false,
          timestamp: DateTime.now(),
          status: MessageStatus.sent,
        ));
      });
      
      // Show send to team banner after AI response
      _displaySendToTeamBanner();
      
      // Fetch updated chat title
      _fetchChatTitle();
    } else {
      throw Exception('Failed to send image: ${response.statusCode}');
    }
  }

  // Send audio file message (simplified version)
  Future<void> _sendAudioFileMessage(ChatMessage message) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse(_n8nChatUrl),
    );

    request.fields['action'] = 'sendAudio';
    request.fields['sessionId'] = SessionService.currentSessionId ?? 'no-session';
    request.headers['Authorization'] = _getBasicAuthHeader();
    request.headers['X-Session-ID'] = SessionService.currentSessionId ?? 'no-session';

    // Add chatType if available
    if (_chatType != null) {
      request.fields['chatType'] = _chatType!;
    }

    final clientData = AuthService.getClientData();
    if (clientData != null) {
      request.fields['clientData'] = jsonEncode(clientData);
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
      String botResponse = _parseWebhookResponse(response.body, 'Audio ontvangen en getranscribeerd');
      
      setState(() {
        _messages.add(ChatMessage(
          text: botResponse,
          isCustomer: false,
          timestamp: DateTime.now(),
          status: MessageStatus.sent,
        ));
      });
      
      // Show send to team banner after AI response
      _displaySendToTeamBanner();
      
      // Fetch updated chat title
      _fetchChatTitle();
    } else {
      throw Exception('Failed to send audio: ${response.statusCode}');
    }
  }

  // Send document file message (simplified version)
  Future<void> _sendDocumentFileMessage(ChatMessage message) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse(_n8nDocumentUrl),
    );

    request.fields['action'] = 'sendDocument';
    request.fields['sessionId'] = SessionService.currentSessionId ?? 'no-session';
    request.headers['Authorization'] = _getBasicAuthHeader();
    request.headers['X-Session-ID'] = SessionService.currentSessionId ?? 'no-session';

    // Add chatType if available
    if (_chatType != null) {
      request.fields['chatType'] = _chatType!;
    }

    final clientData = AuthService.getClientData();
    if (clientData != null) {
      request.fields['clientData'] = jsonEncode(clientData);
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
      String botResponse = _parseWebhookResponse(response.body, 'Document ontvangen en geanalyseerd');
      
      setState(() {
        _messages.add(ChatMessage(
          text: botResponse,
          isCustomer: false,
          timestamp: DateTime.now(),
          status: MessageStatus.sent,
        ));
      });
      
      // Show send to team banner after AI response
      _displaySendToTeamBanner();
      
      // Fetch updated chat title
      _fetchChatTitle();
    } else {
      throw Exception('Failed to send document: ${response.statusCode}');
    }
  }

  // Send video file message
  Future<void> _sendVideoFileMessage(ChatMessage message) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse(_n8nVideoUrl),
    );

    request.fields['action'] = 'sendVideo';
    request.fields['sessionId'] = SessionService.currentSessionId ?? 'no-session';
    request.headers['Authorization'] = _getBasicAuthHeader();
    request.headers['X-Session-ID'] = SessionService.currentSessionId ?? 'no-session';

    // Add chatType if available
    if (_chatType != null) {
      request.fields['chatType'] = _chatType!;
    }

    final clientData = AuthService.getClientData();
    if (clientData != null) {
      request.fields['clientData'] = jsonEncode(clientData);
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
      String botResponse = _parseWebhookResponse(response.body, 'Video ontvangen en geanalyseerd');

      setState(() {
        _messages.add(ChatMessage(
          text: botResponse,
          isCustomer: false,
          timestamp: DateTime.now(),
          status: MessageStatus.sent,
        ));
      });

      // Show send to team banner after AI response
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
    setState(() {
      _messages.add(ChatMessage(
        text: "Email wordt verzonden...",
        isCustomer: false,
        timestamp: DateTime.now(),
        status: MessageStatus.sent,
      ));
    });
    
    _scrollToBottom();
    
    try {
      // Prepare session data and messages for email
      final emailData = {
        'action': 'sendEmail',
        'sessionId': SessionService.currentSessionId ?? 'no-session',
        'messages': _messages.map((msg) => {
          'text': msg.text,
          'isCustomer': msg.isCustomer,
          'timestamp': msg.timestamp.toIso8601String(),
          'attachmentType': msg.attachmentType.toString(),
        }).toList(),
        'clientData': AuthService.getClientData(),
      };
      
      final response = await http.post(
        Uri.parse(_n8nEmailUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': _getBasicAuthHeader(),
          'X-Session-ID': SessionService.currentSessionId ?? 'no-session',
        },
        body: jsonEncode(emailData),
      ).timeout(const Duration(seconds: 120));
      
      if (response.statusCode == 200) {
        // Success - reset session and show webhook response
        await SessionService.resetSession();
        
        String emailResponse = '';
        
        emailResponse = _parseWebhookResponse(response.body, 'Email succesvol verzonden');
        
        setState(() {
          _messages.add(ChatMessage(
            text: emailResponse,
            isCustomer: false,
            timestamp: DateTime.now(),
            status: MessageStatus.sent,
          ));
        });
      } else {
        // Failure - show error message
        String errorMessage = 'Email verzenden mislukt';
        try {
          final data = jsonDecode(response.body);
          if (data is Map && data['error'] != null) {
            errorMessage = 'Email verzenden mislukt: ${data['error']}';
          } else {
            errorMessage = 'Email verzenden mislukt (Status: ${response.statusCode})';
          }
        } catch (e) {
          errorMessage = 'Email verzenden mislukt (Status: ${response.statusCode})';
        }
        
        setState(() {
          _messages.add(ChatMessage(
            text: errorMessage,
            isCustomer: false,
            timestamp: DateTime.now(),
            status: MessageStatus.sent,
          ));
        });
      }
    } catch (e) {
      // Error handling
      setState(() {
        _messages.add(ChatMessage(
          text: 'Email verzenden mislukt: Controleer je internetverbinding en probeer het opnieuw.',
          isCustomer: false,
          timestamp: DateTime.now(),
          status: MessageStatus.sent,
        ));
      });
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
      case 'clear_conversation':
        _clearConversation();
        break;
      case 'call_kwaaijongens':
        _callKwaaijongens();
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
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Chat wissen'),
          content: const Text('Weet je zeker dat je alle berichten wilt verwijderen?'),
          actions: [
            TextButton(
              onPressed: _isDeletingSession ? null : () => Navigator.pop(context),
              child: const Text('Annuleer'),
            ),
            TextButton(
              onPressed: _isDeletingSession ? null : () async {
                final currentSessionId = SessionService.currentSessionId;
                if (currentSessionId == null) {
                  Navigator.pop(context);
                  return;
                }

                setDialogState(() {
                  _isDeletingSession = true;
                });

                // Call webhook to delete session
                final success = await _deleteSessionOnWebhook(currentSessionId);

                if (success) {
                  // Clear stored messages for this session
                  await StorageService.clearMessages(currentSessionId);
                  
                  // Clear current session data
                  await SessionService.clearSession();
                  
                  // Close dialog and navigate to StartScreen
                  if (mounted) {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const StartScreen()),
                    );
                  }
                } else {
                  // Show error message
                  setDialogState(() {
                    _isDeletingSession = false;
                  });
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Kon sessie niet verwijderen. Probeer het opnieuw.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: _isDeletingSession
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Wissen'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchChatTitle() async {
    try {
      final clientData = AuthService.getClientData();
      final requestBody = {
        'method': 'get',
        'sessionId': SessionService.currentSessionId ?? 'no-session',
        'phoneNumber': clientData?['phone'] ?? '',
        'name': clientData?['name'] ?? '',
        'company': clientData?['companyName'] ?? '',
      };

      // Add chatType if available
      if (_chatType != null) {
        requestBody['chatType'] = _chatType!;
      }
      
      print('DEBUG: Fetching chat title with: ${jsonEncode(requestBody)}');

      final response = await http.post(
        Uri.parse(_n8nSessionsUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': _getBasicAuthHeader(),
          'X-Session-ID': SessionService.currentSessionId ?? 'no-session',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 10));

      print('DEBUG: Chat title API response: ${response.statusCode} - ${response.body}');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> session = jsonDecode(response.body);
        final sessionTitle = session['session_title']?.toString();
        print('DEBUG: Extracted session title: $sessionTitle');
        print('DEBUG: Current _chatTitle value: $_chatTitle');
        print('DEBUG: Widget mounted: $mounted');
        
        if (sessionTitle != null && sessionTitle.isNotEmpty) {
          print('DEBUG: Updating chat title to: $sessionTitle');
          if (mounted) {
            setState(() {
              _chatTitle = sessionTitle;
            });
            print('DEBUG: setState completed, new _chatTitle: $_chatTitle');
          } else {
            print('DEBUG: Widget not mounted, skipping setState');
          }
        } else {
          print('DEBUG: Session title is null or empty');
        }
      }
    } catch (e) {
      // Silently handle errors - keep existing title
      print('Error fetching chat title: $e');
    }
  }

  Future<bool> _deleteSessionOnWebhook(String sessionId) async {
    try {
      final clientData = AuthService.getClientData();
      final requestBody = {
        'method': 'delete',
        'sessionId': sessionId,
        'phoneNumber': clientData?['phone'] ?? '',
        'name': clientData?['name'] ?? '',
        'companyName': clientData?['companyName'] ?? '',
      };

      // Add chatType if available
      if (_chatType != null) {
        requestBody['chatType'] = _chatType!;
      }

      print('DEBUG: Deleting session with: ${jsonEncode(requestBody)}');

      final response = await http.post(
        Uri.parse(_n8nSessionsUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': _getBasicAuthHeader(),
          'X-Session-ID': sessionId,
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 10));

      print('DEBUG: Delete session API response: ${response.statusCode} - ${response.body}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['response'] == 'success') {
          print('DEBUG: Session deleted successfully');
          return true;
        } else {
          print('DEBUG: Unexpected response: $responseData');
          return false;
        }
      } else {
        print('DEBUG: Delete session failed with status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error deleting session: $e');
      return false;
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
                    child: const Center(
                      child: Text(
                        'K',
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
                    'Kwaaijongens APP',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Version
                  Text(
                    'Versie ${packageInfo.version}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Developer info
                  const Text(
                    'Kwaaijongens WordPress bureau',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final Uri websiteUri = Uri.parse('https://www.kwaaijongens.nl');
                      if (await canLaunchUrl(websiteUri)) {
                        await launchUrl(websiteUri, mode: LaunchMode.externalApplication);
                      }
                    },
                    child: const Text(
                      'www.kwaaijongens.nl',
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
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFF0F0F0), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const StartScreen()),
              );
            },
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Color(0xFF374151),
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
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
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
                    value: 'forward_conversation',
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: const Row(
                        children: [
                          Icon(Icons.mail, color: Colors.grey, size: 20),
                          SizedBox(width: 12),
                          Text(
                            'Gesprek doorsturen',
                            style: TextStyle(fontSize: 14, color: Colors.black87),
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
                            style: TextStyle(fontSize: 14, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ),
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
                  const PopupMenuDivider(),
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

  Widget _buildSendToTeamBanner() {
    if (!_showSendToTeamBanner) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.all(16),
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
            child: const Icon(
              Icons.check,
              color: Colors.white,
              size: 12,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Alles verteld wat we moeten weten? Mooi! Stuur maar door!',
              style: TextStyle(
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
              'Versturen',
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
    return Scaffold(
      body: SafeArea(
        child: Column(
        children: [
          // Custom Header
          _buildHeader(),
          
          // Chat messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isLoading) {
                  return TypingIndicator(isUploadingFile: _isUploadingFile);
                }
                return ChatBubble(message: _messages[index]);
              },
            ),
          ),
          
          // Send to Team Banner
          _buildSendToTeamBanner(),
          
          // Recording indicator
          if (_isRecording)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.red.shade50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.fiber_manual_record, color: Colors.red, size: 16),
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
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey, width: 0.5),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          // Attachment icon
                          IconButton(
                            onPressed: _isLoading ? null : _showAttachmentDialog,
                            icon: Icon(
                              Icons.attach_file,
                              color: _isLoading ? Colors.grey.shade400 : Colors.grey,
                              size: 20,
                            ),
                          ),
                          // Text input
                          Expanded(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                minHeight: 48.0, // Single line height (24px text + 24px padding)
                                maxHeight: 144.0, // 6 lines height (6 * 24px text + 24px padding)
                              ),
                              child: TextField(
                                controller: _messageController,
                                onChanged: _onTextChanged,
                                enabled: !_isLoading,
                                decoration: InputDecoration(
                                  hintText: _isLoading ? 'Even geduld...' : 'Deel je blog idee...',
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                maxLines: null,
                                textInputAction: TextInputAction.newline,
                                scrollPhysics: const BouncingScrollPhysics(),
                              ),
                            ),
                          ),
                          // Camera icon
                          IconButton(
                            onPressed: _isLoading ? null : _showImageSourceDialog,
                            icon: Icon(
                              Icons.camera_alt,
                              color: _isLoading ? Colors.grey.shade400 : Colors.grey,
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
                      color: _isLoading 
                          ? Colors.grey 
                          : (_isRecording ? Colors.red : const Color(0xFFCC0001)),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _isLoading ? null : (_isTyping 
                          ? _sendMessage 
                          : _isRecording
                              ? _stopRecording
                              : _startRecording),
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
          ),
        ],
      ),
      ),
    );
  }
}

enum AttachmentType {
  none,
  audio,
  image,
  document,
  video,
}

enum MessageStatus { pending, sent }

class ChatMessage {
  final String text;
  final bool isCustomer;
  final DateTime timestamp;
  final File? audioFile;
  final File? imageFile;
  final File? documentFile;
  final File? videoFile;
  final AttachmentType attachmentType;
  final MessageStatus status;
  final bool fromFCM;

  ChatMessage({
    required this.text,
    required this.isCustomer,
    required this.timestamp,
    this.audioFile,
    this.imageFile,
    this.documentFile,
    this.videoFile,
    this.attachmentType = AttachmentType.none,
    this.status = MessageStatus.pending,
    this.fromFCM = false,
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
      'attachmentType': attachmentType.toString(),
      'status': status.toString(),
      'fromFCM': fromFCM,
    };
  }

  // Create from JSON (recreate File objects from paths if they exist)
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      text: json['text'],
      isCustomer: json['isCustomer'],
      timestamp: DateTime.parse(json['timestamp']),
      audioFile: json['audioFilePath'] != null
          ? File(json['audioFilePath'])
          : null,
      imageFile: json['imageFilePath'] != null
          ? File(json['imageFilePath'])
          : null,
      documentFile: json['documentFilePath'] != null
          ? File(json['documentFilePath'])
          : null,
      videoFile: json['videoFilePath'] != null
          ? File(json['videoFilePath'])
          : null,
      attachmentType: _parseAttachmentType(json['attachmentType']),
      status: _parseMessageStatus(json['status']),
      fromFCM: json['fromFCM'] ?? false,
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
      case 'MessageStatus.pending':
      default:
        return MessageStatus.pending;
    }
  }
}

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: message.isCustomer 
            ? MainAxisAlignment.end 
            : MainAxisAlignment.start,
        children: [
          if (!message.isCustomer) ...[
            const CircleAvatar(
              backgroundColor: Color(0xFFCC0001),
              radius: 16,
              child: Icon(
                Icons.smart_toy,
                color: Colors.white,
                size: 18,
              ),
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
                    color: message.isCustomer 
                        ? const Color(0xFFCC0001) 
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.attachmentType == AttachmentType.audio && message.audioFile != null)
                        AudioMessageWidget(
                          audioFile: message.audioFile!,
                          isCustomer: message.isCustomer,
                          duration: message.text.replaceAll('🎤 Audio bericht (', '').replaceAll(')', ''),
                        )
                      else if (message.attachmentType == AttachmentType.image && message.imageFile != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ImageMessageWidget(
                              imageFile: message.imageFile!,
                              isCustomer: message.isCustomer,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTime(message.timestamp),
                              style: TextStyle(
                                color: message.isCustomer 
                                    ? Colors.white70 
                                    : Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        )
                      else if (message.attachmentType == AttachmentType.document && message.documentFile != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DocumentMessageWidget(
                              documentFile: message.documentFile!,
                              isCustomer: message.isCustomer,
                              fileName: AttachmentService.getFileInfo(message.documentFile!)['fileName'],
                              fileSize: AttachmentService.getFileInfo(message.documentFile!)['size'],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTime(message.timestamp),
                              style: TextStyle(
                                color: message.isCustomer 
                                    ? Colors.white70 
                                    : Colors.grey.shade600,
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
                                color: message.isCustomer 
                                    ? Colors.white 
                                    : Colors.black87,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTime(message.timestamp),
                              style: TextStyle(
                                color: message.isCustomer 
                                    ? Colors.white70 
                                    : Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                // Status icon for pending customer messages
                if (message.isCustomer && message.status == MessageStatus.pending)
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Icon(
                      Icons.access_time,
                      size: 14,
                      color: Colors.white70,
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
              child: Icon(
                Icons.person,
                color: Colors.white,
                size: 18,
              ),
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
          const CircleAvatar(
            backgroundColor: Color(0xFFCC0001),
            radius: 16,
            child: Icon(
              Icons.smart_toy,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.isUploadingFile ? 'Bestand uploaden' : 'Aan het typen',
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Row(
                      children: List.generate(3, (index) {
                        final delay = index * 0.2;
                        final animValue = (_animationController.value - delay).clamp(0.0, 1.0);
                        final opacity = (animValue < 0.5) 
                            ? animValue * 2 
                            : 2 - (animValue * 2);
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1),
                          child: Opacity(
                            opacity: opacity,
                            child: const Text(
                              '•',
                              style: TextStyle(
                                fontSize: 20,
                                color: Color(0xFFCC0001),
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

  const LinkableSelectableText({
    super.key,
    required this.text,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return SelectableText.rich(
      _buildTextSpan(),
      style: style,
    );
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
        children.add(TextSpan(
          text: text.substring(currentIndex, match.start),
          style: style,
        ));
      }

      // Add the clickable link
      final linkText = match.group(0)!;
      children.add(TextSpan(
        text: linkText,
        style: style?.copyWith(
          color: Colors.blue,
          decoration: TextDecoration.underline,
        ),
        recognizer: TapGestureRecognizer()..onTap = () => _launchUrl(linkText),
      ));

      currentIndex = match.end;
    }

    // Add remaining text after the last link
    if (currentIndex < text.length) {
      children.add(TextSpan(
        text: text.substring(currentIndex),
        style: style,
      ));
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