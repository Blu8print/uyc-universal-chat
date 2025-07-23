import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http_parser/http_parser.dart';
import '../services/auth_service.dart';
import '../services/audio_recording_service.dart';
import '../services/session_service.dart';
import '../services/storage_service.dart';
import '../services/attachment_service.dart';
import '../services/document_routing_service.dart';
import '../widgets/audio_message_widget.dart';
import '../widgets/image_message_widget.dart';
import '../widgets/document_message_widget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

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
  const ChatScreen({super.key});

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
  bool _isRecording = false;
  bool _isEmailSending = false;
  Duration _recordingDuration = Duration.zero;
  
  final String _n8nChatUrl = 'https://kwaaijongens.app.n8n.cloud/webhook/46b0b5ec-132d-4aca-97ec-0d11d05f66bc/chat';
  final String _n8nImageUrl = 'https://kwaaijongens.app.n8n.cloud/webhook/e54fbfea-e46e-4b21-9a05-48d75d568ae3';
  final String _n8nEmailUrl = 'https://kwaaijongens.app.n8n.cloud/webhook/69ffb2fc-518b-42a9-a490-a308c2e9a454';
  
  final List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _initializeServices();
    await _initializeWelcomeMessage();
    _requestInitialPermissions();
  }

  Future<void> _initializeServices() async {
    await SessionService.initialize();
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
        return;
      }
    }
    
    // No existing messages - add welcome message
    await _addMessage(ChatMessage(
      text: "Hallo $userName! Ik ben je AI-assistent van Kwaaijongens. Ik help $companyName graag met blog ideeën en content creatie. Waar kan ik je mee helpen?",
      isCustomer: false,
      timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
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
    }
  }

  // Add message and save to storage
  Future<void> _addMessage(ChatMessage message) async {
    setState(() {
      _messages.add(message);
    });
    await _saveMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _audioService.dispose();
    _recordingTimer?.cancel();
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
    if (_messageController.text.trim().isNotEmpty && !_isLoading) {
      final userMessage = _messageController.text.trim();
      
      // Add user message immediately
      await _addMessage(ChatMessage(
        text: userMessage,
        isCustomer: true,
        timestamp: DateTime.now(),
      ));
      
      setState(() {
        _isLoading = true;
      });
      
      _messageController.clear();
      _scrollToBottom();
      
      // Send to n8n and get response
      await _sendToN8n(userMessage);
      
      setState(() {
        _isTyping = false;
        _isLoading = false;
      });
      
      _scrollToBottom();
    }
  }

  Future<void> _sendToN8n(String message) async {
    try {
      final response = await http.post(
        Uri.parse(_n8nChatUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
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
        String botResponse = '';
        
        // Check if response body is empty
        if (response.body.isEmpty) {
          botResponse = 'Lege reactie ontvangen van server';
        } else {
          try {
            final data = jsonDecode(response.body);
            // Handle n8n chat trigger response format
            if (data is Map) {
              botResponse = data['output'] ?? 
                           data['response'] ?? 
                           data['message'] ?? 
                           data['reply'] ?? 
                           data['text'] ??
                           'Geen reactie ontvangen';
            } else if (data is String) {
              botResponse = data;
            } else {
              botResponse = 'Onverwacht response format';
            }
          } catch (e) {
            // If JSON parsing fails, use the raw response
            botResponse = response.body.isNotEmpty ? response.body : 'Ongeldige server reactie';
          }
        }
        
        // Add bot response
        await _addMessage(ChatMessage(
          text: botResponse,
          isCustomer: false,
          timestamp: DateTime.now(),
        ));
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
    ));
  }

  Future<void> _startRecording() async {
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
    }
  }

  Future<void> _sendAudioMessage(File audioFile) async {
    setState(() {
      _messages.add(
        ChatMessage(
          text: '🎤 Audio bericht (${_formatDuration(_recordingDuration)})',
          isCustomer: true,
          timestamp: DateTime.now(),
          audioFile: audioFile,
          attachmentType: AttachmentType.audio,
        ),
      );
      _isLoading = true;
    });
    
    _scrollToBottom();
    
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(_n8nChatUrl),
      );
      
      request.fields['action'] = 'sendAudio';
      request.fields['sessionId'] = SessionService.currentSessionId ?? 'no-session';
      request.headers['X-Session-ID'] = SessionService.currentSessionId ?? 'no-session';
      
      // Add client data to form fields
      final clientData = AuthService.getClientData();
      if (clientData != null) {
        request.fields['clientData'] = jsonEncode(clientData);
      }
      
      request.files.add(
        await http.MultipartFile.fromPath(
          'audio',
          audioFile.path,
          filename: 'audio_message.m4a',
        ),
      );
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        String botResponse = '';
        
        if (response.body.isEmpty) {
          botResponse = 'Lege reactie ontvangen van server';
        } else {
          try {
            final data = jsonDecode(response.body);
            if (data is Map) {
              botResponse = data['transcription'] ??
                           data['output'] ??
                           data['response'] ??
                           data['message'] ??
                           data['text'] ??
                           'Audio ontvangen, maar geen transcriptie beschikbaar';
            } else if (data is String) {
              botResponse = data;
            } else {
              botResponse = 'Onverwacht response format';
            }
          } catch (e) {
            botResponse = response.body.isNotEmpty ? response.body : 'Ongeldige server reactie';
          }
        }
        
        setState(() {
          _messages.add(ChatMessage(
            text: botResponse,
            isCustomer: false,
            timestamp: DateTime.now(),
          ));
        });
      } else {
        _addErrorMessage('Server error: ${response.statusCode}');
      }
    } catch (e) {
      // Error sending audio: $e
      _addErrorMessage('Sorry, er ging iets mis bij het versturen van het audio bericht.');
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
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
                'Afbeelding selecteren',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFFCC0001)),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFFCC0001)),
                title: const Text('Galerij'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
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
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fout bij het selecteren van afbeelding: $e'),
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
    setState(() {
      _messages.add(
        ChatMessage(
          text: '📷 Afbeelding',
          isCustomer: true,
          timestamp: DateTime.now(),
          imageFile: imageFile,
          attachmentType: AttachmentType.image,
        ),
      );
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(_n8nImageUrl),
      );

      request.fields['action'] = 'sendImage';
      request.fields['sessionId'] = SessionService.currentSessionId ?? 'no-session';
      request.headers['X-Session-ID'] = SessionService.currentSessionId ?? 'no-session';
      
      // Add client data to form fields
      final clientData = AuthService.getClientData();
      if (clientData != null) {
        request.fields['clientData'] = jsonEncode(clientData);
      }

      final fileInfo = _getFileExtensionAndMimeType(imageFile.path);
      
      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
          filename: 'image_message.${fileInfo['extension']}',
          contentType: MediaType.parse(fileInfo['mimeType']!),
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        String botResponse = '';

        if (response.body.isEmpty) {
          botResponse = 'Afbeelding ontvangen, maar geen reactie van server';
        } else {
          try {
            final data = jsonDecode(response.body);
            if (data is Map) {
              botResponse = data['description'] ??
                           data['output'] ??
                           data['response'] ??
                           data['message'] ??
                           data['text'] ??
                           'Afbeelding ontvangen en geanalyseerd';
            } else if (data is String) {
              botResponse = data;
            } else {
              botResponse = 'Onverwacht response format';
            }
          } catch (e) {
            botResponse = response.body.isNotEmpty ? response.body : 'Ongeldige server reactie';
          }
        }

        setState(() {
          _messages.add(ChatMessage(
            text: botResponse,
            isCustomer: false,
            timestamp: DateTime.now(),
          ));
        });
      } else {
        _addErrorMessage('Server error: ${response.statusCode}');
      }
    } catch (e) {
      _addErrorMessage('Sorry, er ging iets mis bij het versturen van de afbeelding.');
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _pickDocument() async {
    try {
      final documentFile = await AttachmentService.pickDocument();
      if (documentFile != null) {
        await _sendDocumentMessage(documentFile);
      }
    } catch (e) {
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
    final fileInfo = AttachmentService.getFileInfo(documentFile);
    
    setState(() {
      _messages.add(
        ChatMessage(
          text: '📄 ${fileInfo['fileName']}',
          isCustomer: true,
          timestamp: DateTime.now(),
          documentFile: documentFile,
          attachmentType: AttachmentType.document,
        ),
      );
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      final webhookUrl = DocumentRoutingService.getWebhookUrl(fileInfo['extension']);
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(webhookUrl),
      );

      request.fields['action'] = 'sendDocument';
      request.fields['sessionId'] = SessionService.currentSessionId ?? 'no-session';
      request.fields['fileType'] = fileInfo['extension'];
      request.fields['fileName'] = fileInfo['fileName'];
      request.headers['X-Session-ID'] = SessionService.currentSessionId ?? 'no-session';
      
      // Add client data to form fields
      final clientData = AuthService.getClientData();
      if (clientData != null) {
        request.fields['clientData'] = jsonEncode(clientData);
      }

      request.files.add(
        await http.MultipartFile.fromPath(
          'document',
          documentFile.path,
          filename: fileInfo['fileName'],
          contentType: MediaType.parse(fileInfo['mimeType']),
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        String botResponse = '';

        if (response.body.isEmpty) {
          botResponse = 'Document ontvangen, maar geen reactie van server';
        } else {
          try {
            final data = jsonDecode(response.body);
            if (data is Map) {
              botResponse = data['analysis'] ??
                           data['output'] ??
                           data['response'] ??
                           data['message'] ??
                           data['text'] ??
                           'Document ontvangen en geanalyseerd';
            } else if (data is String) {
              botResponse = data;
            } else {
              botResponse = 'Onverwacht response format';
            }
          } catch (e) {
            botResponse = response.body.isNotEmpty ? response.body : 'Ongeldige server reactie';
          }
        }

        setState(() {
          _messages.add(ChatMessage(
            text: botResponse,
            isCustomer: false,
            timestamp: DateTime.now(),
          ));
        });
      } else {
        _addErrorMessage('Server error: ${response.statusCode}');
      }
    } catch (e) {
      _addErrorMessage('Sorry, er ging iets mis bij het versturen van het document.');
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }


  void _onTextChanged(String text) {
    setState(() {
      _isTyping = text.trim().isNotEmpty;
    });
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
          'X-Session-ID': SessionService.currentSessionId ?? 'no-session',
        },
        body: jsonEncode(emailData),
      ).timeout(const Duration(seconds: 120));
      
      if (response.statusCode == 200) {
        // Success - reset session and show webhook response
        await SessionService.resetSession();
        
        String emailResponse = '';
        
        // Check if response body is empty
        if (response.body.isEmpty) {
          emailResponse = 'Email succesvol verzonden';
        } else {
          try {
            final data = jsonDecode(response.body);
            // Handle webhook response format - check for common response fields
            if (data is Map) {
              emailResponse = data['output'] ?? 
                           data['response'] ?? 
                           data['message'] ?? 
                           data['reply'] ?? 
                           data['text'] ??
                           'Email succesvol verzonden';
            } else if (data is String) {
              emailResponse = data;
            } else {
              emailResponse = 'Email succesvol verzonden';
            }
          } catch (e) {
            // If JSON parsing fails, use the raw response or default message
            emailResponse = response.body.isNotEmpty ? response.body : 'Email succesvol verzonden';
          }
        }
        
        setState(() {
          _messages.add(ChatMessage(
            text: emailResponse,
            isCustomer: false,
            timestamp: DateTime.now(),
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
        ));
      });
    } finally {
      setState(() {
        _isEmailSending = false;
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Kwaaijongens APP',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          onPressed: () {
            // Clear chat
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Chat wissen'),
                content: const Text('Weet je zeker dat je alle berichten wilt verwijderen?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuleer'),
                  ),
                  TextButton(
                    onPressed: () async {
                      final oldSessionId = SessionService.currentSessionId;
                      await SessionService.resetSession();
                      
                      // Clear stored messages for old session
                      if (oldSessionId != null) {
                        await StorageService.clearMessages(oldSessionId);
                      }
                      
                      // Clear current messages and add welcome message
                      setState(() {
                        _messages.clear();
                      });
                      
                      await _addMessage(ChatMessage(
                        text: "Hallo! Ik ben je AI-assistent van kwaaijongens APP. Ik help je graag met je blog ideeën en content creatie. Waar kan ik je mee helpen?",
                        isCustomer: false,
                        timestamp: DateTime.now(),
                      ));
                      
                      if (mounted) Navigator.pop(context);
                    },
                    child: const Text('Wissen'),
                  ),
                ],
              ),
            );
          },
          icon: const Icon(Icons.refresh),
        ),
        actions: [
          IconButton(
            onPressed: _isEmailSending ? null : _sendEmail,
            icon: _isEmailSending 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.email),
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isLoading) {
                  return const TypingIndicator();
                }
                return ChatBubble(message: _messages[index]);
              },
            ),
          ),
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
                      icon: Icon(
                        _isLoading 
                            ? Icons.hourglass_empty 
                            : (_isTyping 
                                ? Icons.send 
                                : (_isRecording ? Icons.stop : Icons.mic)),
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
    );
  }
}

enum AttachmentType {
  none,
  audio,
  image,
  document,
}

class ChatMessage {
  final String text;
  final bool isCustomer;
  final DateTime timestamp;
  final File? audioFile;
  final File? imageFile;
  final File? documentFile;
  final AttachmentType attachmentType;

  ChatMessage({
    required this.text,
    required this.isCustomer,
    required this.timestamp,
    this.audioFile,
    this.imageFile,
    this.documentFile,
    this.attachmentType = AttachmentType.none,
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
      'attachmentType': attachmentType.toString(),
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
      attachmentType: _parseAttachmentType(json['attachmentType']),
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
      default:
        return AttachmentType.none;
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
            child: Container(
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
  const TypingIndicator({super.key});

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
                const Text(
                  'Aan het typen',
                  style: TextStyle(
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