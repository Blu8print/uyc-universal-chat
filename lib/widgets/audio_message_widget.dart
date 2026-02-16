import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';
import '../constants/app_colors.dart';

class AudioMessageWidget extends StatefulWidget {
  final File audioFile;
  final bool isCustomer;
  final String duration;
  final bool autoPlay;
  final VoidCallback? onAutoPlayTriggered;

  const AudioMessageWidget({
    super.key,
    required this.audioFile,
    required this.isCustomer,
    required this.duration,
    this.autoPlay = false,
    this.onAutoPlayTriggered,
  });

  @override
  State<AudioMessageWidget> createState() => _AudioMessageWidgetState();
}

class _AudioMessageWidgetState extends State<AudioMessageWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
    });

    _audioPlayer.onDurationChanged.listen((duration) {
      setState(() {
        _duration = duration;
      });
    });

    _audioPlayer.onPositionChanged.listen((position) {
      setState(() {
        _position = position;
      });
    });

    // Auto-play if requested
    if (widget.autoPlay) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _togglePlayback();
        // Notify parent that auto-play has been triggered
        widget.onAutoPlayTriggered?.call();
      });
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(DeviceFileSource(widget.audioFile.path));
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: _togglePlayback,
            icon: Icon(
              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
              size: 36,
              color: widget.isCustomer ? Colors.white : AppColors.primary,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Audio bericht',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Text(
                _duration > Duration.zero
                    ? '${_formatDuration(_position)} / ${_formatDuration(_duration)}'
                    : widget.duration,
                style: TextStyle(
                  fontSize: 12,
                  color:
                      widget.isCustomer ? Colors.white70 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.mic,
            size: 20,
            color: widget.isCustomer ? Colors.white70 : Colors.grey.shade600,
          ),
        ],
      ),
    );
  }
}
