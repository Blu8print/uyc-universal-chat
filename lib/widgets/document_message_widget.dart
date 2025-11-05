import 'package:flutter/material.dart';
import 'dart:io';
import '../services/attachment_service.dart';

class DocumentMessageWidget extends StatelessWidget {
  final File? documentFile;  // Temp file (for uploading state)
  final String? documentUrl;  // Nextcloud URL (after upload)
  final bool isCustomer;
  final String fileName;
  final int fileSize;
  final bool isUploading;  // Show spinner overlay
  final VoidCallback? onTap;  // Open document callback
  final VoidCallback? onLongPress;  // Delete callback

  const DocumentMessageWidget({
    super.key,
    this.documentFile,
    this.documentUrl,
    required this.isCustomer,
    required this.fileName,
    required this.fileSize,
    this.isUploading = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    // Get file info from temp file if available, otherwise use fileName
    final fileExtension = documentFile != null
        ? AttachmentService.getFileInfo(documentFile!)['extension']
        : fileName.split('.').last;
    final fileIcon = AttachmentService.getFileIcon(fileExtension);
    final formattedSize = AttachmentService.formatFileSize(fileSize);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCustomer ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCustomer ? Colors.white24 : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isCustomer ? Colors.white24 : const Color(0xFFCC0001).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                fileIcon,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fileName,
                  style: TextStyle(
                    color: isCustomer ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  formattedSize,
                  style: TextStyle(
                    color: isCustomer ? Colors.white70 : Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Show spinner if uploading, otherwise icon
          isUploading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                Icons.description,
                color: isCustomer ? Colors.white70 : Colors.grey.shade600,
                size: 16,
              ),
        ],
      ),
      ),
    );
  }
}