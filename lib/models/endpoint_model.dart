import 'dart:convert';

class Endpoint {
  final String id;
  final String name;
  final String url;
  final String authType; // "none", "basic", "bearer", "header"
  final String? authValue;
  final String? username;
  final bool loadHistory;
  final String? initialMessage;
  final int timeout;
  final DateTime createdAt;
  final String? sessionId;
  final String? mediaUrl;
  final String mediaAuthType;
  final String? mediaAuthValue;
  final String? mediaUsername;
  final String imageAction;
  final String videoAction;
  final String documentAction;
  final String audioAction;
  final bool mediaUseSameEndpoint;
  final bool imageEnabled;
  final bool videoEnabled;
  final bool documentEnabled;
  final bool audioEnabled;

  Endpoint({
    required this.id,
    required this.name,
    required this.url,
    this.authType = 'none',
    this.authValue,
    this.username,
    this.loadHistory = true,
    this.initialMessage,
    this.timeout = 30,
    DateTime? createdAt,
    this.sessionId,
    this.mediaUrl,
    this.mediaAuthType = 'none',
    this.mediaAuthValue,
    this.mediaUsername,
    this.imageAction = 'sendImage',
    this.videoAction = 'sendVideo',
    this.documentAction = 'sendDocument',
    this.audioAction = 'sendAudio',
    this.mediaUseSameEndpoint = true,
    this.imageEnabled = true,
    this.videoEnabled = true,
    this.documentEnabled = true,
    this.audioEnabled = true,
  }) : createdAt = createdAt ?? DateTime.now();

  String get effectiveMediaUrl =>
      mediaUseSameEndpoint ? url : (mediaUrl ?? url);

  // JSON serialization methods
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'authType': authType,
      'authValue': authValue,
      'username': username,
      'loadHistory': loadHistory,
      'initialMessage': initialMessage,
      'timeout': timeout,
      'createdAt': createdAt.toIso8601String(),
      'sessionId': sessionId,
      'mediaUrl': mediaUrl,
      'mediaAuthType': mediaAuthType,
      'mediaAuthValue': mediaAuthValue,
      'mediaUsername': mediaUsername,
      'imageAction': imageAction,
      'videoAction': videoAction,
      'documentAction': documentAction,
      'audioAction': audioAction,
      'mediaUseSameEndpoint': mediaUseSameEndpoint,
      'imageEnabled': imageEnabled,
      'videoEnabled': videoEnabled,
      'documentEnabled': documentEnabled,
      'audioEnabled': audioEnabled,
    };
  }

  factory Endpoint.fromJson(Map<String, dynamic> json) {
    return Endpoint(
      id: json['id'] as String,
      name: json['name'] as String,
      url: json['url'] as String,
      authType: json['authType'] as String? ?? 'none',
      authValue: json['authValue'] as String?,
      username: json['username'] as String?,
      loadHistory: json['loadHistory'] as bool? ?? true,
      initialMessage: json['initialMessage'] as String?,
      timeout: json['timeout'] as int? ?? 30,
      createdAt: DateTime.parse(json['createdAt'] as String),
      sessionId: json['sessionId'] as String?,
      mediaUrl: json['mediaUrl'] as String?,
      mediaAuthType: json['mediaAuthType'] as String? ?? 'none',
      mediaAuthValue: json['mediaAuthValue'] as String?,
      mediaUsername: json['mediaUsername'] as String?,
      imageAction: json['imageAction'] as String? ?? 'sendImage',
      videoAction: json['videoAction'] as String? ?? 'sendVideo',
      documentAction: json['documentAction'] as String? ?? 'sendDocument',
      audioAction: json['audioAction'] as String? ?? 'sendAudio',
      mediaUseSameEndpoint: json['mediaUseSameEndpoint'] as bool? ?? true,
      imageEnabled: json['imageEnabled'] as bool? ?? true,
      videoEnabled: json['videoEnabled'] as bool? ?? true,
      documentEnabled: json['documentEnabled'] as bool? ?? true,
      audioEnabled: json['audioEnabled'] as bool? ?? true,
    );
  }

  // Generate authorization header for media endpoint
  String? getMediaAuthHeader() {
    switch (mediaAuthType) {
      case 'basic':
        if (mediaUsername != null && mediaAuthValue != null) {
          final credentials = '$mediaUsername:$mediaAuthValue';
          final encoded = base64Encode(utf8.encode(credentials));
          return 'Basic $encoded';
        }
        return null;
      case 'bearer':
        return mediaAuthValue != null ? 'Bearer $mediaAuthValue' : null;
      case 'header':
        return mediaAuthValue;
      case 'none':
      default:
        return null;
    }
  }

  // Generate authorization header based on authType
  String? getAuthHeader() {
    switch (authType) {
      case 'basic':
        if (username != null && authValue != null) {
          final credentials = '$username:$authValue';
          final encoded = base64Encode(utf8.encode(credentials));
          return 'Basic $encoded';
        }
        return null;
      case 'bearer':
        return authValue != null ? 'Bearer $authValue' : null;
      case 'header':
        // authValue should be in format "HeaderName: HeaderValue"
        return authValue;
      case 'none':
      default:
        return null;
    }
  }

  // Copy with method for editing
  Endpoint copyWith({
    String? id,
    String? name,
    String? url,
    String? authType,
    String? authValue,
    String? username,
    bool? loadHistory,
    String? initialMessage,
    int? timeout,
    DateTime? createdAt,
    String? sessionId,
    String? mediaUrl,
    String? mediaAuthType,
    String? mediaAuthValue,
    String? mediaUsername,
    String? imageAction,
    String? videoAction,
    String? documentAction,
    String? audioAction,
    bool? mediaUseSameEndpoint,
    bool? imageEnabled,
    bool? videoEnabled,
    bool? documentEnabled,
    bool? audioEnabled,
  }) {
    return Endpoint(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      authType: authType ?? this.authType,
      authValue: authValue ?? this.authValue,
      username: username ?? this.username,
      loadHistory: loadHistory ?? this.loadHistory,
      initialMessage: initialMessage ?? this.initialMessage,
      timeout: timeout ?? this.timeout,
      createdAt: createdAt ?? this.createdAt,
      sessionId: sessionId ?? this.sessionId,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaAuthType: mediaAuthType ?? this.mediaAuthType,
      mediaAuthValue: mediaAuthValue ?? this.mediaAuthValue,
      mediaUsername: mediaUsername ?? this.mediaUsername,
      imageAction: imageAction ?? this.imageAction,
      videoAction: videoAction ?? this.videoAction,
      documentAction: documentAction ?? this.documentAction,
      audioAction: audioAction ?? this.audioAction,
      mediaUseSameEndpoint: mediaUseSameEndpoint ?? this.mediaUseSameEndpoint,
      imageEnabled: imageEnabled ?? this.imageEnabled,
      videoEnabled: videoEnabled ?? this.videoEnabled,
      documentEnabled: documentEnabled ?? this.documentEnabled,
      audioEnabled: audioEnabled ?? this.audioEnabled,
    );
  }
}
