import 'dart:convert';

// ---------------------------------------------------------------------------
// Data models used throughout the app.
// HTTP methods have been removed — UYC uses user-configured endpoints only.
// ---------------------------------------------------------------------------

// Generic API response wrapper
class ApiResponse {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;

  ApiResponse({required this.success, required this.message, this.data});
}

// Session data model
class SessionData {
  final String sessionId;
  final String title;
  final String description;
  final String? thumbnail;
  final String? lastActivity;
  final int messageCount;
  final String? createdAt;
  final String? chatType;
  final bool emailSent;
  final String? userId;
  final String? companyName;
  final String? userName;
  final String? messages;
  final String? phoneNumber;
  final bool isOwner;
  final bool isPinned;

  SessionData({
    required this.sessionId,
    required this.title,
    required this.description,
    this.thumbnail,
    this.lastActivity,
    this.messageCount = 0,
    this.createdAt,
    this.chatType,
    this.emailSent = false,
    this.userId,
    this.companyName,
    this.userName,
    this.messages,
    this.phoneNumber,
    this.isOwner = false,
    this.isPinned = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'title': title,
      'description': description,
      'thumbnail': thumbnail,
      'lastActivity': lastActivity,
      'messageCount': messageCount,
      'createdAt': createdAt,
      'chatType': chatType,
      'emailSent': emailSent,
      'userId': userId,
      'companyName': companyName,
      'userName': userName,
      'messages': messages,
      'phoneNumber': phoneNumber,
      'isOwner': isOwner,
      'isPinned': isPinned,
    };
  }

  factory SessionData.fromJson(Map<String, dynamic> json) {
    return SessionData(
      sessionId: json['sessionId'] ?? '',
      title: json['title'] ?? 'Untitled Session',
      description: json['description'] ?? '',
      thumbnail: json['thumbnail'],
      lastActivity: json['lastActivity'],
      messageCount: json['messageCount'] ?? 0,
      createdAt: json['createdAt'],
      chatType: json['chatType'],
      emailSent: json['emailSent'] ?? false,
      userId: json['userId'],
      companyName: json['companyName'],
      userName: json['userName'],
      messages: json['messages'],
      phoneNumber: json['phoneNumber'],
      isOwner: json['isOwner'] ?? false,
      isPinned: json['isPinned'] ?? false,
    );
  }

  // Returns the last message preview text
  String? getLastMessagePreview() {
    if (messages == null || messages!.isEmpty) return null;
    try {
      final messagesData = jsonDecode(messages!);
      if (messagesData is List && messagesData.isNotEmpty) {
        final lastMessage = messagesData.last;
        return lastMessage['text'] ?? lastMessage['message'];
      }
    } catch (_) {}
    return null;
  }

  int getMessageCount() {
    if (messages == null || messages!.isEmpty) return 0;
    try {
      final messagesData = jsonDecode(messages!);
      if (messagesData is List) return messagesData.length;
    } catch (_) {}
    return 0;
  }

  DateTime? getLastMessageTimestamp() {
    if (messages == null || messages!.isEmpty) return null;
    try {
      final messagesData = jsonDecode(messages!);
      if (messagesData is List && messagesData.isNotEmpty) {
        final lastMessage = messagesData.last;
        final timestamp = lastMessage['timestamp'] ?? lastMessage['created_at'];
        if (timestamp != null) return DateTime.tryParse(timestamp.toString());
      }
    } catch (_) {}
    return null;
  }
}

// Session response class
class SessionResponse {
  final bool success;
  final String message;
  final SessionData? sessionData;

  SessionResponse({
    required this.success,
    required this.message,
    this.sessionData,
  });
}

// Session list response class
class SessionListResponse {
  final bool success;
  final String message;
  final List<SessionData> sessions;

  SessionListResponse({
    required this.success,
    required this.message,
    required this.sessions,
  });
}
