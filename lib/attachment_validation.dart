const int skylinkDefaultMaxUploadBytes = 2 * 1024 * 1024 * 1024;

const Set<String> skylinkSupportedAttachmentExtensions = {
  'jpg',
  'jpeg',
  'png',
  'webp',
  'pdf',
  'doc',
  'docx',
  'xls',
  'xlsx',
  'txt',
  'zip',
};

bool isSupportedAttachmentName(String name) {
  return skylinkSupportedAttachmentExtensions.contains(_fileExtension(name));
}

String? validateAttachmentCandidate({
  required String name,
  required int size,
  int maxUploadBytes = skylinkDefaultMaxUploadBytes,
}) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) {
    return 'Attachment name is missing.';
  }
  if (!isSupportedAttachmentName(trimmed)) {
    return 'Unsupported file type for $trimmed.';
  }
  if (size <= 0) {
    return 'Attachment is empty.';
  }
  if (size > maxUploadBytes) {
    return 'Attachment is too large. Maximum allowed is ${_formatBytes(maxUploadBytes)}.';
  }
  return null;
}

String _fileExtension(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) return '';
  return name.substring(dot + 1).toLowerCase();
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(1)} MB';
}
