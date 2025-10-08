# Webhook Migration: New Domain and Basic Authentication

## Summary
Migrated all webhook endpoints from `kwaaijongens.app.n8n.cloud` to `automation.kwaaijongens.nl` and implemented Basic Authentication across all HTTP requests.

## Changes Made

### 1. Updated Webhook URLs

**New Domain:** `automation.kwaaijongens.nl`

| Endpoint | Old URL | New URL |
|----------|---------|---------|
| Chat | `kwaaijongens.app.n8n.cloud/webhook/46b0b5ec-132d-4aca-97ec-0d11d05f66bc/chat` | `automation.kwaaijongens.nl/webhook/46b0b5ec-132d-4aca-97ec-0d11d05f66bc/chat` |
| Images | `kwaaijongens.app.n8n.cloud/webhook/e54fbfea-e46e-4b21-9a05-48d75d568ae3` | `automation.kwaaijongens.nl/webhook/media_image` |
| Documents | `kwaaijongens.app.n8n.cloud/webhook/d64bd02a-38b7-4ea0-b408-218ecb907038` | `automation.kwaaijongens.nl/webhook/media_document` |
| Email | `kwaaijongens.app.n8n.cloud/webhook/69ffb2fc-518b-42a9-a490-a308c2e9a454` | `automation.kwaaijongens.nl/webhook/send-email` |
| Send SMS | `kwaaijongens.app.n8n.cloud/webhook/send-sms` | `automation.kwaaijongens.nl/webhook/send-sms` |
| Verify SMS | `kwaaijongens.app.n8n.cloud/webhook/verify-sms` | `automation.kwaaijongens.nl/webhook/verify-sms` |
| Version Check | `kwaaijongens.app.n8n.cloud/webhook/version-check` | `automation.kwaaijongens.nl/webhook/version-check` |
| FCM Token | `kwaaijongens.app.n8n.cloud/webhook/fcm-token` | `automation.kwaaijongens.nl/webhook/fcm-token` |
| Sessions | `kwaaijongens.app.n8n.cloud/webhook/sessions` | `automation.kwaaijongens.nl/webhook/sessions` |

### 2. Implemented Basic Authentication

Added Basic Auth headers to all webhook requests. Note: Sessions endpoint uses separate Basic Auth credentials (`kj-app:ar6e!GyXu`).

**Files Modified:**

#### lib/services/api_service.dart
- Added `_basicAuth` credential constant
- Added `_getBasicAuthHeader()` helper method
- Updated URLs for: sendSms, verifySms, versionCheck, fcmToken
- Added Basic Auth to: `sendSmsCode()`, `verifySmsAndRegister()`, `sendFCMToken()`, `checkVersion()`

#### lib/screens/chat_screen.dart
- Added `_basicAuth` credential constant
- Added `_getBasicAuthHeader()` helper method
- Updated URLs for: image, email endpoints
- Added Basic Auth to: `_sendToN8n()`, `_sendBulkTextMessages()`, `_sendImageFileMessage()`, `_sendAudioFileMessage()`, `_sendDocumentFileMessage()`, email sending

#### lib/services/document_routing_service.dart
- Added `_basicAuth` credential constant
- Added `_getBasicAuthHeader()` helper method
- Updated `_documentWebhookUrl` to media_document endpoint
- Added Basic Auth to: `sendDocument()`

#### lib/services/auth_service.dart
- Updated `_defaultWebhookUrl` (already done in previous task)

### 3. Updated Documentation

- **README.md**: Updated webhook endpoints list with all new URLs
- **tasks/todo.md**: Created this documentation file

## Impact

- All webhook communications now go through the new automation domain
- Basic Authentication secures all webhook endpoints
- Sessions endpoint now on new domain with its separate auth credentials
- Backward compatible - no breaking changes to request/response formats

## Testing Checklist

- [ ] SMS verification flow
- [ ] Chat message sending
- [ ] Image upload and analysis
- [ ] Document upload (PDF, Office files)
- [ ] Audio message transcription
- [ ] Email sending to team
- [ ] Version checking
- [ ] FCM token registration
- [ ] Session management (create, list, update, delete, get)

## Security Notes

- Basic Auth credentials are stored as constants in the codebase
- All requests use HTTPS for encryption
- Session endpoint uses separate authentication mechanism
