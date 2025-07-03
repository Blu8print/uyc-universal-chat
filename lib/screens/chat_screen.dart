import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import '../services/auth_service.dart';
import '../services/audio_recording_service.dart';
import '../widgets/audio_message_widget.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'kwaaijongens APP',
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
  Timer? _recordingTimer;
  
  bool _isTyping = false;
  bool _isLoading = false;
  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  
  final String _n8nChatUrl = 'https://kwaaijongens.app.n8n.cloud/webhook/46b0b5ec-132d-4aca-97ec-0d11d05f66bc/chat';
  
  final List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _initializeWelcomeMessage();
    _requestInitialPermissions();
  }

  Future<void> _requestInitialPermissions() async {
    print('DEBUG: Requesting initial permissions...');
    final result = await _audioService.requestPermission();
    print('DEBUG: Initial permission result: $result');
  }

  void _initializeWelcomeMessage() {
    final user = AuthService.currentUser;
    final userName = user?.name ?? 'daar';
    final companyName = user?.companyName ?? 'je bedrijf';
    
    setState(() {
      _messages.add(ChatMessage(
        text: "Hallo $userName! Ik ben je AI-assistent van Kwaaijongens. Ik help $companyName graag met blog ideeën en content creatie. Waar kan ik je mee helpen?",
        isCustomer: false,
        timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
      ));
    });
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
      setState(() {
        _messages.add(
          ChatMessage(
            text: userMessage,
            isCustomer: true,
            timestamp: DateTime.now(),
          ),
        );
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
        },
        body: jsonEncode({
          'action': 'sendMessage',
          'sessionId': 'flutter_chat_${DateTime.now().millisecondsSinceEpoch ~/ 100000}', // Session per ~day
          'chatInput': message,
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
      // Error sending to n8n: $e
      _addErrorMessage('Sorry, er ging iets mis. Controleer je internetverbinding en probeer het opnieuw.');
    }
  }

  void _addErrorMessage(String errorText) {
    setState(() {
      _messages.add(ChatMessage(
        text: errorText,
        isCustomer: false,
        timestamp: DateTime.now(),
      ));
    });
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
      request.fields['sessionId'] = 'flutter_chat_${DateTime.now().millisecondsSinceEpoch ~/ 100000}';
      
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

  void _onTextChanged(String text) {
    setState(() {
      _isTyping = text.trim().isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'kwaaijongens APP',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
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
                      onPressed: () {
                        setState(() {
                          _messages.clear();
                          _messages.add(ChatMessage(
                            text: "Hallo! Ik ben je AI-assistent van kwaaijongens APP. Ik help je graag met je blog ideeën en content creatie. Waar kan ik je mee helpen?",
                            isCustomer: false,
                            timestamp: DateTime.now(),
                          ));
                        });
                        Navigator.pop(context);
                      },
                      child: const Text('Wissen'),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.refresh),
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
                            onPressed: _isLoading ? null : () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Bijlagen nog niet beschikbaar')),
                              );
                            },
                            icon: Icon(
                              Icons.attach_file,
                              color: _isLoading ? Colors.grey.shade400 : Colors.grey,
                              size: 20,
                            ),
                          ),
                          // Text input
                          Expanded(
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
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          // Camera icon
                          IconButton(
                            onPressed: _isLoading ? null : () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Camera nog niet beschikbaar')),
                              );
                            },
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

class ChatMessage {
  final String text;
  final bool isCustomer;
  final DateTime timestamp;
  final File? audioFile;

  ChatMessage({
    required this.text,
    required this.isCustomer,
    required this.timestamp,
    this.audioFile,
  });
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
                  if (message.audioFile != null)
                    AudioMessageWidget(
                      audioFile: message.audioFile!,
                      isCustomer: message.isCustomer,
                      duration: message.text.replaceAll('🎤 Audio bericht (', '').replaceAll(')', ''),
                    )
                  else
                    Text(
                      message.text,
                      style: TextStyle(
                        color: message.isCustomer 
                            ? Colors.white 
                            : Colors.black87,
                        fontSize: 16,
                      ),
                    ),
                  if (message.audioFile == null) ...[  
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