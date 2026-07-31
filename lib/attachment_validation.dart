const int skylinkDefaultMaxUploadBytes = 50 * 1024 * 1024;

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
  final trimmed = name.trim();
  if (trimmed.isEmpty) return false;
  // Flow supports any business file type; size and server-side security checks
  // decide whether the upload can proceed.
  return true;
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
  if (!isSupportedAttachmentName(trimmed)) return 'Attachment name is missing.';
  if (size <= 0) {
    return 'Attachment is empty.';
  }
  if (size > maxUploadBytes) {
    return 'Attachment is too large. Maximum allowed is ${_formatBytes(maxUploadBytes)}.';
  }
  return null;
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(1)} MB';
}
