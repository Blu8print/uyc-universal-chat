import 'package:flutter/material.dart';
import 'dart:io';
import '../services/attachment_service.dart';

class DocumentMessageWidget extends StatelessWidget {
  final File documentFile;
  final bool isCustomer;
  final String fileName;
  final int fileSize;

  const DocumentMessageWidget({
    super.key,
    required this.documentFile,
    required this.isCustomer,
    required this.fileName,
    required this.fileSize,
  });

  @override
  Widget build(BuildContext context) {
    final fileInfo = AttachmentService.getFileInfo(documentFile);
    final fileIcon = AttachmentService.getFileIcon(fileInfo['extension']);
    final formattedSize = AttachmentService.formatFileSize(fileSize);

    return Container(
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
          Icon(
            Icons.description,
            color: isCustomer ? Colors.white70 : Colors.grey.shade600,
            size: 16,
          ),
        ],
      ),
    );
  }
}