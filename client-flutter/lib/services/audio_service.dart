import 'package:audioplayers/audioplayers.dart';

import '../utils/resource_helper.dart';

/// 音频播放服务（封装 audioplayers，单例模式）
///
/// 播放服务器端预生成的 CosyVoice 音频文件。
/// 音频路径存储在 words.audio 字段（如 "audio/hello.mp3"），
/// 通过 ResourceHelper.resolveUrl 拼接为完整的服务器 URL。
class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  final AudioPlayer _player = AudioPlayer();

  /// 播放完成事件流（每次播放结束触发一次）
  Stream<void> get onPlayerComplete => _player.onPlayerComplete;

  /// 播放单词音频
  ///
  /// [audioPath] 是 words.audio 字段的值（如 "audio/hello.mp3"）。
  /// 为 null、空或 "no_audio" 时静默跳过。
  Future<void> play(String? audioPath) async {
    if (audioPath == null || audioPath.isEmpty || audioPath == 'no_audio') {
      return;
    }
    final url = ResourceHelper.resolveUrl(audioPath);
    if (url == null) return;
    try {
      await _player.stop();
      await _player.play(UrlSource(url));
    } catch (_) {
      // 静默失败，不影响主流程
    }
  }

  /// 停止播放
  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {
      // 静默失败
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    try {
      await _player.dispose();
    } catch (_) {
      // 静默失败
    }
  }
}
