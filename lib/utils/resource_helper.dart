import 'dart:io';

class ResourceHelper {
  ResourceHelper._();

  static bool isUrl(String? value) {
    if (value == null || value.isEmpty) return false;
    final trimmed = value.trim();
    return trimmed.startsWith('http://') || trimmed.startsWith('https://');
  }

  /// URL 直接视为可用，文件路径检查文件是否存在
  static bool sourceExists(String? value) {
    if (value == null || value.isEmpty) return false;
    if (isUrl(value)) return true;
    return File(value).existsSync();
  }
}
