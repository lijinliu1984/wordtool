import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// 录音服务（单例模式）
///
/// 使用 record 包录制用户跟读音频，保存到本地文件。
/// 录音文件存储路径：app_docs/recordings/{taskId}/{wordId}_{timestamp}.m4a
class RecordingService {
  RecordingService._();
  static final RecordingService instance = RecordingService._();

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  /// 开始录音
  ///
  /// 返回录音文件保存路径
  Future<String> startRecording(int taskId, int wordId) async {
    final dir = await getApplicationDocumentsDirectory();
    final recordingsDir = p.join(dir.path, 'recordings', '$taskId');
    final fileName = '${wordId}_${DateTime.now().millisecondsSinceEpoch}.wav';
    final filePath = p.join(recordingsDir, fileName);

    // 确保录音目录存在
    await Directory(recordingsDir).create(recursive: true);

    if (await _recorder.hasPermission()) {
      await _recorder.start(
        RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: filePath,
      );
      _isRecording = true;
    }
    return filePath;
  }

  /// 停止录音，返回文件路径（null 表示录音失败）
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;
    _isRecording = false;
    try {
      return await _recorder.stop();
    } catch (_) {
      return null;
    }
  }

  /// 播放本地录音文件
  Future<void> playLocalFile(String path) async {
    try {
      await _player.stop();
      await _player.play(DeviceFileSource(path));
    } catch (_) {
      // 静默失败
    }
  }

  /// 停止播放
  Future<void> stopPlayback() async {
    try {
      await _player.stop();
    } catch (_) {
      // 静默失败
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    try {
      await _recorder.dispose();
      await _player.dispose();
    } catch (_) {
      // 静默失败
    }
  }
}
