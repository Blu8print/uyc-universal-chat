import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:mime/mime.dart';

class AttachmentService {
  static const int maxFileSizeBytes = 25 * 1024 * 1024; // 25MB

  // Document picking
  static Future<File?> pickDocument() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt'],
        allowMultiple: false,
        withData: false,
        withReadStream: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        
        // Check file size
        final fileSize = await file.length();
        if (fileSize > maxFileSizeBytes) {
          throw Exception('Bestand is te groot. Maximale grootte is 25MB.');
        }
        
        return file;
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // Get file info
  static Map<String, dynamic> getFileInfo(File file) {
    final fileName = file.path.split('/').last;
    final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
    final extension = fileName.split('.').last.toLowerCase();
    
    return {
      'fileName': fileName,
      'mimeType': mimeType,
      'extension': extension,
      'size': file.lengthSync(),
    };
  }

  // Format file size
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  // Get file icon based on extension
  static String getFileIcon(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return '📄';
      case 'doc':
      case 'docx':
        return '📝';
      case 'xls':
      case 'xlsx':
        return '📊';
      case 'ppt':
      case 'pptx':
        return '📈';
      case 'txt':
        return '📋';
      default:
        return '📎';
    }
  }

  // Location services
  static Future<bool> requestLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  static Future<Map<String, dynamic>?> getCurrentLocation() async {
    try {
      bool hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        throw Exception('Locatie toegang geweigerd');
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 30),
        ),
      );

      String address = await getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'address': address,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      rethrow;
    }
  }

  static Future<String> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        List<String> addressParts = [];

        if (place.street != null && place.street!.isNotEmpty) {
          addressParts.add(place.street!);
        }
        if (place.subThoroughfare != null && place.subThoroughfare!.isNotEmpty) {
          addressParts.add(place.subThoroughfare!);
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          addressParts.add(place.locality!);
        }
        if (place.country != null && place.country!.isNotEmpty) {
          addressParts.add(place.country!);
        }

        return addressParts.isNotEmpty 
            ? addressParts.join(', ')
            : 'Onbekende locatie';
      }
      return 'Onbekende locatie';
    } catch (e) {
      return 'Adres kon niet worden bepaald';
    }
  }

  // Generate Google Maps URL
  static String generateMapsUrl(double latitude, double longitude) {
    return 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
  }
}