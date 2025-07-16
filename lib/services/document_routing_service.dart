import 'dart:io';
import 'package:http/http.dart' as http;
import 'session_service.dart';

class DocumentRoutingService {
  static const String _documentWebhookUrl = 'https://kwaaijongens.app.n8n.cloud/webhook/d64bd02a-38b7-4ea0-b408-218ecb907038';
  static const String _chatWebhookUrl = 'https://kwaaijongens.app.n8n.cloud/webhook/46b0b5ec-132d-4aca-97ec-0d11d05f66bc/chat';
  
  static const Set<String> _routedDocumentTypes = {
    'pdf',
    'doc', 'docx', 'odt',
    'xls', 'xlsx',
    'ppt', 'pptx'
  };

  static bool shouldRouteToDocumentWebhook(String extension) {
    return _routedDocumentTypes.contains(extension.toLowerCase());
  }

  static Future<bool> sendDocument(File file, String fileName, String extension) async {
    try {
      final url = shouldRouteToDocumentWebhook(extension) 
          ? _documentWebhookUrl 
          : _chatWebhookUrl;
      
      final request = http.MultipartRequest('POST', Uri.parse(url));
      
      request.files.add(
        await http.MultipartFile.fromPath(
          'document',
          file.path,
          filename: fileName,
        ),
      );
      
      request.fields['action'] = 'sendDocument';
      request.fields['sessionId'] = SessionService.currentSessionId ?? '';
      request.fields['fileType'] = extension;
      request.fields['fileName'] = fileName;
      
      final response = await request.send();
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static String getWebhookUrl(String extension) {
    return shouldRouteToDocumentWebhook(extension) 
        ? _documentWebhookUrl 
        : _chatWebhookUrl;
  }
}