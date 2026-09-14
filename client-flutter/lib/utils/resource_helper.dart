import 'dart:io';

import '../config/server_config.dart';

class ResourceHelper {
  ResourceHelper._();

  /// 判断字符串是否为 URL
  static bool isUrl(String? value) {
    if (value == null || value.isEmpty) return false;
    final trimmed = value.trim();
    return trimmed.startsWith('http://') || trimmed.startsWith('https://');
  }

  /// 判断字符串是否为 emoji 字符
  /// emoji 的 Unicode 码点通常 >= U+1F000
  static bool isEmoji(String? value) {
    if (value == null || value.isEmpty) return false;
    final trimmed = value.trim();
    final runes = trimmed.runes;
    if (runes.isEmpty) return false;
    // 取第一个码点判断
    final first = runes.first;
    // 常见 emoji 范围：U+1F000 以上，以及部分杂项符号区
    return first >= 0x1F000 ||
        (0x2600 <= first && first <= 0x27BF) ||
        (0x2190 <= first && first <= 0x21FF) ||
        first == 0x2705 ||
        first == 0x2728;
  }

  /// URL 直接视为可用，文件路径检查文件是否存在，emoji 直接可用
  static bool sourceExists(String? value) {
    if (value == null || value.isEmpty) return false;
    if (isUrl(value)) return true;
    if (isEmoji(value)) return true;
    return File(value).existsSync();
  }

  /// 解析资源 URL
  ///
  /// - emoji 字符 → 直接返回（客户端用 Text 渲染）
  /// - 完整 URL → 直接返回
  /// - 文件名 → 拼接服务器资源地址
  static String? resolveUrl(String? value) {
    if (value == null || value.isEmpty) return null;
    if (isEmoji(value)) return value;
    if (isUrl(value)) return value;
    return '${ServerConfig.instance.resourcesUrl}/$value';
  }
}
