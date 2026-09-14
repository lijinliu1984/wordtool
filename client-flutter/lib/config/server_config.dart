import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 服务器配置（动态，可修改后持久化）
class ServerConfig {
  ServerConfig._();

  static final ServerConfig instance = ServerConfig._();

  static const _key = 'server_base_url';
  static const String _defaultBaseUrl = 'https://wt.fmcode.top';

  String _baseUrl = _defaultBaseUrl;

  final ValueNotifier<String> urlNotifier =
      ValueNotifier(_defaultBaseUrl);

  String get baseUrl => _baseUrl;

  String get versionUrl => '$baseUrl/api/version';

  String get downloadUrl => '$baseUrl/api/download';

  String get resourcesUrl => '$baseUrl/resources';

  String get wordImageUrl => '$baseUrl/api/word/image';

  /// 初始化：从本地加载已保存的服务器地址
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null && saved.isNotEmpty) {
      _baseUrl = saved;
      urlNotifier.value = saved;
    }
  }

  /// 修改服务器地址并持久化
  Future<void> setBaseUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty || trimmed == _baseUrl) return;
    // 去掉末尾的 /
    _baseUrl = trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _baseUrl);
    urlNotifier.value = _baseUrl;
  }
}
