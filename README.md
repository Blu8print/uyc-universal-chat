# Kwaaijongens APP

<div align="center">
  <img src="logo.svg" alt="Kwaaijongens Logo" height="80">
  
  **The official mobile app for sharing projects, expertise, and social media content**
  
  [![Flutter](https://img.shields.io/badge/Flutter-3.7.1+-02569B.svg?logo=flutter)](https://flutter.dev)
  [![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2.svg?logo=dart)](https://dart.dev)
  [![Version](https://img.shields.io/badge/Version-1.0.5+10-green.svg)]()
</div>

## 📱 About the App

Kwaaijongens APP is a mobile application that empowers professionals to easily share their projects, expertise, and social media content with our team. The app streamlines the content creation process by allowing users to submit information directly through an intuitive chat interface powered by AI assistance.

### 🎯 Key Features

- **📝 Project Sharing**: Share completed projects with details and insights
- **🧠 Knowledge Sharing**: Contribute your expertise for blog creation
- **📱 Social Media Content**: Submit photos and ideas for social media posts
- **🤖 AI Assistant**: Get help and guidance through intelligent chat
- **📧 Content Forwarding**: Send conversations directly to the team
- **📂 Session Management**: Access and continue previous submissions
- **🔄 Real-time Sync**: Seamless synchronization across devices

## 🚀 What You Can Do

### Project Submission
Share your successful projects and implementations. Our team will help create compelling case studies and portfolio content.

### Knowledge Sharing
Contribute your professional expertise and insights. We transform your knowledge into engaging blog posts and thought leadership content.

### Social Media Content
Upload photos and ideas for social media posts. Our team creates professional social media content based on your submissions.

### AI-Powered Assistance
Get instant help and guidance through our intelligent chat assistant that understands your content creation needs.

## 📞 Support & Contact

- **Phone**: [085 - 330 7500](tel:+31853307500)
- **Email**: [app@kwaaijongens.nl](mailto:app@kwaaijongens.nl)
- **Helpdesk**: [kwaaijongens.nl/app-support](https://kwaaijongens.nl/app-support)
- **Privacy Policy**: [kwaaijongens.nl/privacy-app](https://kwaaijongens.nl/privacy-app)

---

## 🛠️ Technical Documentation

### Architecture Overview

The Kwaaijongens APP is built using Flutter and follows a modern mobile app architecture with the following key components:

- **Frontend**: Flutter (Dart) with Material Design
- **Backend Integration**: RESTful APIs with webhook architecture
- **Authentication**: JWT-based authentication with SMS verification
- **Data Storage**: Local storage with SharedPreferences and file system
- **Push Notifications**: Firebase Cloud Messaging (FCM)
- **State Management**: Flutter setState with custom service layer

### 🏗️ Project Structure

```
lib/
├── models/              # Data models and DTOs
│   └── user_model.dart
├── screens/             # UI screens and pages
│   ├── auth/           # Authentication screens
│   ├── chat_screen.dart
│   └── start_screen.dart
├── services/            # Business logic and API services
│   ├── api_service.dart
│   ├── auth_service.dart
│   ├── session_service.dart
│   ├── storage_service.dart
│   └── audio_recording_service.dart
├── widgets/             # Reusable UI components
└── main.dart           # App entry point
```

### 🔧 Core Services

#### Authentication Service
- SMS-based verification system
- User session management
- Secure token handling

#### Session Service  
- Chat session lifecycle management
- Backend synchronization
- Session persistence and restoration

#### API Service
- Webhook integrations for content submission
- File upload handling (images, audio, documents)
- Session management APIs

#### Storage Service
- Local message persistence
- User data caching
- File system management

### 📡 API Integration

#### Webhook Endpoints
- **Chat**: `https://automation.kwaaijongens.nl/webhook/46b0b5ec-132d-4aca-97ec-0d11d05f66bc/chat`
- **Images**: `https://automation.kwaaijongens.nl/webhook/media_image`
- **Documents**: `https://automation.kwaaijongens.nl/webhook/media_document`
- **Email**: `https://automation.kwaaijongens.nl/webhook/send-email`
- **Send SMS**: `https://automation.kwaaijongens.nl/webhook/send-sms`
- **Verify SMS**: `https://automation.kwaaijongens.nl/webhook/verify-sms`
- **Version Check**: `https://automation.kwaaijongens.nl/webhook/version-check`
- **FCM Token**: `https://automation.kwaaijongens.nl/webhook/fcm-token`
- **Sessions**: `https://automation.kwaaijongens.nl/webhook/sessions`

#### Authentication
- Basic Authentication with credentials
- Session-based request authentication
- Secure headers and token management

### 🔒 Security Features

- **Data Encryption**: Sensitive data encryption in transit and at rest
- **Authentication**: Multi-factor authentication with SMS verification
- **Session Management**: Secure session handling with timeout
- **Input Validation**: Comprehensive input sanitization
- **Privacy**: GDPR-compliant data handling

### 📱 Platform Support

- **iOS**: Minimum iOS 12.0
- **Android**: Minimum API level 21 (Android 5.0)
- **Cross-platform**: Single codebase for both platforms

### 🎨 UI/UX Features

- **Material Design**: Modern Material Design 3 components
- **Responsive Layout**: Adaptive layouts for different screen sizes
- **Dark/Light Mode**: System-aware theme switching
- **Accessibility**: Full accessibility support with screen readers
- **Internationalization**: Dutch language support with localization framework

## 🚀 Getting Started (Development)

### Prerequisites
- Flutter SDK 3.7.1+
- Dart SDK 3.0+
- Android Studio / VS Code
- iOS development: Xcode (macOS only)
- Android development: Android SDK

### Installation

1. **Clone the repository**
   ```bash
   git clone [repository-url]
   cd my_flutter_app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure environment**
   - Set up Firebase configuration files
   - Configure API endpoints and credentials
   - Set up development certificates

4. **Run the app**
   ```bash
   flutter run
   ```

### Development Commands

```bash
# Run in debug mode
flutter run --debug

# Build for production
flutter build apk --release
flutter build ios --release

# Run tests
flutter test

# Analyze code
flutter analyze

# Format code
dart format .
```

### 📋 Environment Setup

#### Firebase Configuration
1. Add `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
2. Configure Firebase Console for FCM
3. Set up push notification certificates

#### API Configuration
- Configure webhook URLs in service files
- Set up authentication credentials
- Configure session management endpoints

## 📦 Dependencies

### Core Dependencies
- **flutter**: Framework core
- **http**: HTTP client for API requests
- **shared_preferences**: Local data persistence
- **path_provider**: File system access
- **image_picker**: Camera and gallery access
- **permission_handler**: Device permissions
- **firebase_messaging**: Push notifications
- **flutter_svg**: SVG asset rendering

### Development Dependencies
- **flutter_test**: Testing framework
- **build_runner**: Code generation
- **flutter_launcher_icons**: App icon generation

## 🔄 CI/CD Pipeline

### Build Process
1. **Code Analysis**: Automated code quality checks
2. **Testing**: Unit and integration tests
3. **Building**: Platform-specific builds
4. **Distribution**: App store deployment

### Version Management
- **Semantic Versioning**: Following semver standards
- **Build Numbers**: Automated increment for app stores
- **Release Notes**: Automated changelog generation

## 📊 Monitoring & Analytics

- **Crash Reporting**: Integrated crash analytics
- **Performance Monitoring**: App performance metrics
- **User Analytics**: Privacy-compliant usage analytics
- **Error Tracking**: Comprehensive error logging

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Standards
- Follow Dart/Flutter style guidelines
- Maintain test coverage above 80%
- Document public APIs
- Follow Material Design principles

## 📄 License

This project is proprietary software owned by Kwaaijongens. All rights reserved.

## 📈 Changelog

### Version 1.0.5+10 (Latest)
- **UI Improvements**: Enhanced header navigation with back arrow
- **Chat Title**: Dynamic chat titles from backend API
- **Session Management**: Improved session deletion with webhook integration
- **UX**: Better three dots menu styling and consistency
- **API**: Fixed chat title API integration and error handling

### Previous Versions
- **1.0.4+9**: Session refresh system and sorting improvements
- **1.0.3**: Firebase push notification integration
- **1.0.2**: Initial app store release with core functionality

---

<div align="center">
  <p><strong>Kwaaijongens APP</strong> - Empowering content creation through technology</p>
  <p>
    <a href="tel:+31853307500">📞 085 - 330 7500</a> • 
    <a href="mailto:app@kwaaijongens.nl">✉️ app@kwaaijongens.nl</a>
  </p>
</div>
