# UYC - Unlock Your Cloud

<div align="center">
  <img src="UYC-logo.png" alt="UYC Logo" height="120">

  **Universal cloud communication platform for seamless collaboration**

  [![Flutter](https://img.shields.io/badge/Flutter-3.7.1+-02569B.svg?logo=flutter)](https://flutter.dev)
  [![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2.svg?logo=dart)](https://dart.dev)
  [![Version](https://img.shields.io/badge/Version-1.0.6+19-blue.svg)]()
</div>

## 📱 About UYC

UYC (Unlock Your Cloud) is a modern cloud communication platform built with Flutter. The app provides a seamless chat interface for cloud-based conversations, file sharing, and real-time collaboration.

### 🎯 Key Features

- **💬 Cloud Conversations**: Intelligent chat interface for cloud-based communication
- **📎 File Sharing**: Upload and share images, videos, documents, and audio
- **📍 Location Sharing**: Share your location with integrated maps
- **💾 Session Management**: Save, restore, and manage conversation sessions
- **🔄 Real-time Sync**: Seamless synchronization across devices
- **📱 Cross-platform**: Native experience on Android, iOS, Windows, and Web

## 🎨 Design & Branding

- **Primary Color**: Blue-green (#1a6b8a) - Trust and innovation
- **Accent Color**: Orange (#d98324) - Energy and warmth
- **Text Color**: Cream (#f2e8cf) - Clarity and comfort
- **Package Name**: `cloud.unlockyour.chat`

## 🚀 Current Status

**Version**: 1.0.6+19 (Rebranded from Kwaaijongens APP)

⚠️ **Configuration Required**: This app requires backend configuration before production use.

### What's Working
✅ Chat UI and message display
✅ Session management and persistence
✅ File upload interface (images, videos, documents, audio)
✅ Location sharing
✅ Cross-platform builds (Android, iOS, Windows, Web)

### What Needs Configuration
⚠️ API endpoints (currently disabled via feature flag)
⚠️ Firebase Cloud Messaging (config files need updating)
⚠️ Backend webhook integration
⚠️ Support contact information

See `docs/FIREBASE_MIGRATION_NOTES.md` and `docs/REBRAND_COMPLETION_STATUS.md` for details.

## 📞 Support & Contact

> ⚠️ **TODO**: Update with actual UYC support information

- **Phone**: [To be configured]
- **Email**: [To be configured]
- **Website**: [To be configured]

---

## 🛠️ Technical Documentation

### Architecture Overview

UYC is built using Flutter and follows a modern mobile app architecture:

- **Frontend**: Flutter (Dart) with Material Design 3
- **Backend Integration**: RESTful APIs with webhook architecture (requires configuration)
- **Authentication**: Direct launch (SMS auth removed)
- **Data Storage**: Local storage with SharedPreferences and file system
- **Push Notifications**: Firebase Cloud Messaging (requires setup)
- **State Management**: Flutter setState with custom service layer

### 🏗️ Project Structure

```
lib/
├── config/              # Configuration files
│   └── api_config.dart  # API endpoints (feature-flagged)
├── constants/           # App constants
│   ├── app_colors.dart  # Color scheme
│   └── app_constants.dart # App identity
├── models/              # Data models
│   └── user_model.dart
├── screens/             # UI screens
│   ├── auth/           # Authentication screens (deprecated)
│   ├── endpoint_list_screen.dart # Entry point
│   ├── chat_screen.dart
│   └── start_screen.dart
├── services/            # Business logic
│   ├── api_service.dart
│   ├── auth_service.dart (deprecated)
│   ├── session_service.dart
│   ├── storage_service.dart
│   ├── attachment_service.dart
│   └── audio_recording_service.dart
├── widgets/             # Reusable components
│   ├── message_dialog.dart
│   ├── audio_message_widget.dart
│   ├── document_message_widget.dart
│   └── location_message_widget.dart
└── main.dart           # App entry point
```

### 🔧 Core Services

#### Session Service
- Chat session lifecycle management
- Backend synchronization (when configured)
- Session persistence and restoration
- Local storage integration

#### API Service (Feature-Flagged)
- Webhook integrations (commented out - requires configuration)
- File upload handling (images, audio, documents, video)
- Session management APIs
- Feature flag: `ApiConfig.enableApiCalls = false` (disabled by default)

#### Storage Service
- Local message persistence
- User data caching
- File system management
- Session data storage

#### Attachment Service
- Image, video, and document handling
- File type detection and validation
- Location/maps URL generation
- MIME type management

### 📡 API Integration

⚠️ **Configuration Required**: All API endpoints are currently commented out in `lib/config/api_config.dart`.

Before enabling API calls:
1. Configure your backend webhook URLs in `ApiConfig`
2. Set up authentication if needed
3. Enable the feature flag: `ApiConfig.enableApiCalls = true`
4. Test endpoints thoroughly

See `docs/REBRAND_COMPLETION_STATUS.md` for post-implementation tasks.

### 🔒 Security Considerations

- **Data Encryption**: Implement encryption for sensitive data in transit
- **Authentication**: Configure authentication system as needed
- **Session Management**: Secure session handling with appropriate timeout
- **Input Validation**: Comprehensive input sanitization included
- **API Security**: Configure API authentication before production

### 📱 Platform Support

- **Android**: Minimum API level 21 (Android 5.0)
  - Package: `cloud.unlockyour.chat`
  - Launcher icons: ✅ Updated with UYC branding
- **iOS**: Minimum iOS 12.0
  - Bundle ID: `cloud.unlockyour.chat`
  - App Store icon: ✅ Updated (other sizes: see `docs/IOS_ICONS_TODO.md`)
- **macOS**: Minimum macOS 10.14
  - Bundle ID: `cloud.unlockyour.chat`
- **Windows**: Windows 10+
  - App name: "UYC"
  - ⚠️ Requires CMake 3.23+ for builds
- **Web**: Modern browsers
  - Chrome, Safari, Firefox, Edge

### 🎨 UI/UX Features

- **Material Design 3**: Modern Material Design components
- **Custom Color Scheme**: Blue-green primary with orange accents
- **Responsive Layout**: Adaptive layouts for different screen sizes
- **Accessibility**: Full accessibility support with screen readers
- **Localization**: Dutch language support

## 🚀 Getting Started (Development)

### Prerequisites
- Flutter SDK 3.7.1+
- Dart SDK 3.0+
- Android Studio / VS Code
- **iOS development**: Xcode (macOS only)
- **Android development**: Android SDK
- **Windows development**: CMake 3.23+, Visual Studio 2022

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/Blu8print/uyc-universal-chat.git
   cd uyc
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   # List available devices
   flutter devices

   # Run on specific device
   flutter run -d chrome        # Web (recommended for testing)
   flutter run -d android       # Android device/emulator
   flutter run -d ios           # iOS device/simulator (macOS only)
   flutter run -d windows       # Windows (requires CMake 3.23+)
   ```

### Development Commands

```bash
# Clean build files
flutter clean

# Analyze code
flutter analyze

# Format code
dart format .

# Build for production
flutter build apk --release      # Android APK
flutter build appbundle --release # Android App Bundle
flutter build ios --release      # iOS (macOS only)
flutter build web --release      # Web
```

### 📋 Configuration Steps

#### 1. API Configuration
Edit `lib/config/api_config.dart`:
```dart
class ApiConfig {
  // Add your webhook URLs
  static const String chatWebhook = 'https://your-backend.com/webhook/chat';
  // ... add other endpoints

  // Enable API calls when ready
  static const bool enableApiCalls = true;
}
```

#### 2. Firebase Setup (for Push Notifications)
See `docs/FIREBASE_MIGRATION_NOTES.md` for complete guide:
1. Create Firebase project for `cloud.unlockyour.chat`
2. Replace `android/app/google-services.json`
3. Replace `ios/Runner/GoogleService-Info.plist`
4. Configure FCM in Firebase Console

#### 3. Support Information
Edit `lib/constants/app_constants.dart`:
```dart
class AppConstants {
  static const String supportPhone = '+31 XX XXX XXXX';
  static const String supportEmail = 'support@example.com';
  static const String supportWebsite = 'https://example.com';
}
```

#### 4. Complete iOS Icons (Optional)
See `docs/IOS_ICONS_TODO.md` for generating remaining icon sizes.

## 📦 Dependencies

### Core Dependencies
- **http** (1.1.0): HTTP client for API requests
- **shared_preferences** (2.2.2): Local data persistence
- **path_provider** (2.1.2): File system access
- **image_picker** (1.0.7): Camera and gallery access
- **file_picker** (8.0.0): Document picker
- **permission_handler** (11.3.0): Device permissions
- **record** (6.0.0): Audio recording
- **audioplayers** (6.0.0): Audio playback
- **video_player** (2.8.0): Video playback
- **geolocator** (13.0.1): Location services
- **geocoding** (3.0.0): Address lookup
- **url_launcher** (6.2.5): Open URLs and maps
- **firebase_messaging** (15.1.3): Push notifications
- **flutter_svg** (2.0.10): SVG rendering
- **connectivity_plus** (6.1.0): Network status
- **package_info_plus** (8.0.0): App version info

### Development Dependencies
- **flutter_test**: Testing framework
- **flutter_lints** (5.0.0): Linting rules

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Standards
- Follow Dart/Flutter style guidelines
- Run `flutter analyze` before committing
- Format code with `dart format .`
- Document public APIs
- Follow Material Design principles

## 📄 License

This project is proprietary software. All rights reserved.

## 📈 Changelog

### Version 1.0.6+19 (Current - February 2026)
- **Complete Rebrand**: Kwaaijongens APP → UYC (Unlock Your Cloud)
- **Package Rename**: com.app.kwaaijongens → cloud.unlockyour.chat
- **Color Scheme**: New blue-green (#1a6b8a) primary with orange (#d98324) accent
- **Authentication**: Removed SMS auth, direct launch to endpoint screen
- **Architecture**: Centralized API config with feature flags
- **Assets**: New UYC launcher icons and branding across all platforms
- **Code Quality**: 0 errors, clean flutter analyze
- **Documentation**: Comprehensive migration guides and setup instructions

### Version 1.0.5+10 (Pre-rebrand)
- UI improvements with enhanced header navigation
- Dynamic chat titles from backend API
- Improved session management with webhook integration
- Better UX with three dots menu styling

### Previous Versions
- **1.0.4+9**: Session refresh system and sorting improvements
- **1.0.3**: Firebase push notification integration
- **1.0.2**: Initial app store release

---

## 📚 Additional Documentation

- **Firebase Migration**: `docs/FIREBASE_MIGRATION_NOTES.md`
- **iOS Icons Setup**: `docs/IOS_ICONS_TODO.md`
- **Implementation Status**: `docs/REBRAND_COMPLETION_STATUS.md`
- **Technical Details**: `docs/TECHNICAL_DOCUMENTATION.md`
- **Session Management**: `docs/session_management.md`
- **TestFlight Setup**: `docs/TESTFLIGHT_SETUP.md`

---

<div align="center">
  <p><strong>UYC - Unlock Your Cloud</strong></p>
  <p>Modern cloud communication, simplified</p>
  <p>
    <a href="https://github.com/Blu8print/uyc-universal-chat">🔗 GitHub Repository</a>
  </p>
</div>
