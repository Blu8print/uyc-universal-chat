// UYC - Unlock Your Cloud
// Centralized API Configuration

// ===========================================================================
// MIGRATION NOTE: All webhook URLs are from the legacy Kwaaijongens system
// These are COMMENTED OUT and need to be replaced with new UYC endpoints
// ===========================================================================

class ApiConfig {
  // Legacy Kwaaijongens webhooks (DISABLED - for reference only)
  /*
  static const String chatWebhook =
      'https://automation.kwaaijongens.nl/webhook/46b0b5ec-132d-4aca-97ec-0d11d05f66bc/chat';
  static const String imageWebhook =
      'https://automation.kwaaijongens.nl/webhook/media_image';
  static const String documentWebhook =
      'https://automation.kwaaijongens.nl/webhook/media_document';
  static const String videoWebhook =
      'https://automation.kwaaijongens.nl/webhook/media_video';
  static const String emailWebhook =
      'https://automation.kwaaijongens.nl/webhook/send-email';
  static const String sessionsWebhook =
      'https://automation.kwaaijongens.nl/webhook/sessions';
  static const String smsWebhook =
      'https://automation.kwaaijongens.nl/webhook/send-sms';
  static const String verifySmsWebhook =
      'https://automation.kwaaijongens.nl/webhook/verify-sms';
  static const String versionCheckWebhook =
      'https://automation.kwaaijongens.nl/webhook/version-check';
  static const String fcmTokenWebhook =
      'https://automation.kwaaijongens.nl/webhook/fcm-token';
  static const String audioWebhook =
      'https://automation.kwaaijongens.nl/webhook/generate_audio';
  static const String deleteMediaWebhook =
      'https://automation.kwaaijongens.nl/webhook/delete_media';
  */

  // TODO: Configure UYC endpoints when backend is ready
  static const String chatWebhook = '';
  static const String imageWebhook = '';
  static const String documentWebhook = '';
  static const String videoWebhook = '';
  static const String emailWebhook = '';
  static const String sessionsWebhook = '';
  static const String smsWebhook = '';
  static const String verifySmsWebhook = '';
  static const String versionCheckWebhook = '';
  static const String fcmTokenWebhook = '';
  static const String audioWebhook = '';
  static const String deleteMediaWebhook = '';

  // Basic Auth credentials (TODO: Update for UYC system)
  // Legacy: 'SystemArchitect:A$pp_S3cr3t'
  static const String basicAuth = '';

  // Feature flag - Set to true when endpoints are configured
  static const bool enableApiCalls = false;
}
