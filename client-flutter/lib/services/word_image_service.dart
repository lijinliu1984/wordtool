import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../config/server_config.dart';

/// 单词图片上传服务
class WordImageService {
  WordImageService._();

  static final WordImageService instance = WordImageService._();

  final Dio _dio = Dio();

  /// 上传图片字节，返回服务器返回的新 pic 相对路径（如 pic/2_1699999999.png）
  Future<String> uploadImage(int wordId, Uint8List bytes) async {
    final form = FormData.fromMap({
      'word_id': wordId,
      'file': MultipartFile.fromBytes(bytes, filename: 'word.png'),
    });
    final response = await _dio.post(
      ServerConfig.instance.wordImageUrl,
      data: form,
    );
    return response.data['pic'] as String;
  }
}
