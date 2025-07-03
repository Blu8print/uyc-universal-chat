import 'dart:io';
import 'dart:async';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

class AudioRecordingService {
  final AudioRecorder _recorder = AudioRecorder();
  String? _currentRecordingPath;
  bool _isRecording = false;
  DateTime? _recordingStartTime;
  Timer? _fileSizeCheckTimer;
  
  static const int maxFileSizeBytes = 23 * 1024 * 1024; // 23MB in bytes

  bool get isRecording => _isRecording;
  Duration get recordingDuration => _recordingStartTime != null 
      ? DateTime.now().difference(_recordingStartTime!)
      : Duration.zero;
  
  Future<int> get currentFileSize async {
    if (_currentRecordingPath == null) return 0;
    try {
      final file = File(_currentRecordingPath!);
      if (await file.exists()) {
        return await file.length();
      }
    } catch (e) {
      // Error getting file size: $e
    }
    return 0;
  }

  Future<bool> requestPermission() async {
    print('DEBUG: Checking microphone permission with record package...');
    
    final hasPermission = await _recorder.hasPermission();
    print('DEBUG: Record package permission result: $hasPermission');
    
    return hasPermission;
  }

  Future<bool> startRecording() async {
    try {
      if (!(await requestPermission())) {
        return false;
      }

      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${directory.path}/audio_$timestamp.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _currentRecordingPath!,
      );

      _isRecording = true;
      _recordingStartTime = DateTime.now();
      
      // Start monitoring file size
      _startFileSizeMonitoring();
      
      return true;
    } catch (e) {
      // Error starting recording: $e
      _isRecording = false;
      _recordingStartTime = null;
      return false;
    }
  }

  Future<File?> stopRecording() async {
    try {
      if (!_isRecording || _currentRecordingPath == null) {
        return null;
      }

      final path = await _recorder.stop();
      _stopFileSizeMonitoring();
      _isRecording = false;
      _recordingStartTime = null;

      if (path != null) {
        return File(path);
      }
      return null;
    } catch (e) {
      // Error stopping recording: $e
      _stopFileSizeMonitoring();
      _isRecording = false;
      _recordingStartTime = null;
      return null;
    }
  }

  Future<void> cancelRecording() async {
    try {
      if (_isRecording) {
        await _recorder.stop();
        _stopFileSizeMonitoring();
        _isRecording = false;
        _recordingStartTime = null;
        
        if (_currentRecordingPath != null) {
          final file = File(_currentRecordingPath!);
          if (await file.exists()) {
            await file.delete();
          }
        }
      }
    } catch (e) {
      // Error cancelling recording: $e
    } finally {
      _stopFileSizeMonitoring();
      _isRecording = false;
      _recordingStartTime = null;
      _currentRecordingPath = null;
    }
  }

  void _startFileSizeMonitoring() {
    _fileSizeCheckTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!_isRecording || _currentRecordingPath == null) {
        timer.cancel();
        return;
      }
      
      try {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          final fileSize = await file.length();
          if (fileSize >= maxFileSizeBytes) {
            // Stop recording automatically when size limit is reached
            await stopRecording();
          }
        }
      } catch (e) {
        // Error checking file size: $e
      }
    });
  }
  
  void _stopFileSizeMonitoring() {
    _fileSizeCheckTimer?.cancel();
    _fileSizeCheckTimer = null;
  }

  void dispose() {
    _stopFileSizeMonitoring();
    _recorder.dispose();
  }
}