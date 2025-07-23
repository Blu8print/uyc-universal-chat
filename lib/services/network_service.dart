import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkService {
  static final Connectivity _connectivity = Connectivity();
  
  static Future<bool> isOnline() async {
    try {
      // First check connectivity status
      final List<ConnectivityResult> connectivityResult = await _connectivity.checkConnectivity();
      
      // If no connectivity, return false immediately
      if (connectivityResult.contains(ConnectivityResult.none)) {
        return false;
      }
      
      // Test actual internet connectivity by pinging a reliable host
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      // If any error occurs, assume offline
      return false;
    }
  }
}