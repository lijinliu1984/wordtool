import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../config/server_config.dart';
import '../db/vocabulary_database.dart';

/// 词库同步服务
///
/// 检查服务器版本更新，下载新词库 db 文件。
class SyncService {
  SyncService._();

  static final SyncService instance = SyncService._();

  final Dio _dio = Dio();

  /// 检查是否有词库更新
  ///
  /// [localVersionCode] 本地词库的 version_code。
  /// 返回更新信息（若 has_update 为 true 则包含新版详情）。
  Future<Map<String, dynamic>?> checkUpdate(int localVersionCode) async {
    try {
      final response = await _dio.get(
        ServerConfig.instance.versionUrl,
        queryParameters: {'version_code': localVersionCode},
      );
      final data = response.data as Map<String, dynamic>;
      if (data['has_update'] == true) return data;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 下载词库 db 文件并替换本地
  Future<void> downloadDb({
    void Function(double progress)? onProgress,
  }) async {
    await VocabularyDatabase.instance.close();

    final dbPath = await VocabularyDatabase.instance.getDbPath();

    final tempPath = '$dbPath.tmp';
    await _dio.download(
      ServerConfig.instance.downloadUrl,
      tempPath,
      onReceiveProgress: (received, total) {
        if (total > 0 && onProgress != null) {
          onProgress(received / total);
        }
      },
    );

    final tempFile = File(tempPath);
    final dbFile = File(dbPath);
    if (await dbFile.exists()) {
      await dbFile.delete();
    }
    await tempFile.rename(dbPath);
  }
}
