import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioRecordingService {
  final AudioRecorder _recorder = AudioRecorder();
  String? _currentRecordingPath;
  bool _isRecording = false;
  DateTime? _recordingStartTime;

  bool get isRecording => _isRecording;
  Duration get recordingDuration => _recordingStartTime != null 
      ? DateTime.now().difference(_recordingStartTime!)
      : Duration.zero;

  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status == PermissionStatus.granted;
  }

  Future<bool> startRecording() async {
    try {
      if (!(await requestPermission())) {
        return false;
      }

      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
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
      _isRecording = false;
      _recordingStartTime = null;

      if (path != null) {
        return File(path);
      }
      return null;
    } catch (e) {
      // Error stopping recording: $e
      _isRecording = false;
      _recordingStartTime = null;
      return null;
    }
  }

  Future<void> cancelRecording() async {
    try {
      if (_isRecording) {
        await _recorder.stop();
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
      _isRecording = false;
      _recordingStartTime = null;
      _currentRecordingPath = null;
    }
  }

  void dispose() {
    _recorder.dispose();
  }
}