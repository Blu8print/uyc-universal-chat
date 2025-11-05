import 'package:flutter/material.dart';
import 'dart:io';

class VideoMessageWidget extends StatelessWidget {
  final File? thumbnailFile;  // Local temp thumbnail during upload
  final String? thumbnailUrl;  // Nextcloud thumbnail URL after upload
  final bool isCustomer;
  final bool isUploading;  // Show spinner overlay
  final String? title;  // Filename/title to display on thumbnail
  final VoidCallback? onTap;  // Play video callback
  final VoidCallback? onLongPress;  // Delete callback

  const VideoMessageWidget({
    super.key,
    this.thumbnailFile,
    this.thumbnailUrl,
    required this.isCustomer,
    this.isUploading = false,
    this.title,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 250,
          maxHeight: 300,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCustomer ? Colors.white24 : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // Show thumbnail from URL if available (after upload)
              if (thumbnailUrl != null)
                Image.network(
                  thumbnailUrl!,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      width: 250,
                      height: 200,
                      color: Colors.grey.shade200,
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return _buildErrorPlaceholder();
                  },
                )
              // Otherwise show from temp file (during upload)
              else if (thumbnailFile != null && thumbnailFile!.existsSync())
                Image.file(
                  thumbnailFile!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildErrorPlaceholder();
                  },
                )
              else
                _buildErrorPlaceholder(),

              // Show play button in center
              Positioned.fill(
                child: Container(
                  color: Colors.black26,
                  child: const Center(
                    child: Icon(
                      Icons.play_circle_filled,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              // Show spinner overlay while uploading
              if (isUploading)
                Positioned.fill(
                  child: Container(
                    color: Colors.black38,
                    child: const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                ),

              // Show title overlay at bottom if available
              if (title != null && title!.isNotEmpty)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black87, Colors.transparent],
                      ),
                    ),
                    child: Text(
                      title!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      width: 250,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.videocam,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 8),
          Text(
            'Video kan niet laden',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
