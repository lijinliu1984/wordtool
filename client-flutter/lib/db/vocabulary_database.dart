import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/category.dart';
import '../models/level.dart';
import '../models/word.dart';
import '../models/word_filter.dart';

/// 词库数据库（只读，内置在 assets 或从服务器下载）
///
/// 包含 words、word_level、categories、version_info 四张表。
class VocabularyDatabase {
  static final VocabularyDatabase instance = VocabularyDatabase._internal();
  static Database? _database;

  VocabularyDatabase._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    final dbPath = await getDbPath();
    return openDatabase(dbPath, readOnly: true);
  }

  /// 获取 vocabulary.db 文件路径（应用文档目录下）
  Future<String> getDbPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return join(dir.path, 'vocabulary.db');
  }

  /// 检查 vocabulary.db 是否存在（同步版本，启动时使用）
  Future<bool> exists() async {
    final dbPath = await getDbPath();
    return File(dbPath).existsSync();
  }

  /// 从 assets 复制词库到应用目录（首次启动，不联网）
  ///
  /// 若本地 vocabulary.db 不存在、为空或损坏（无 words 表），
  /// 则删除并从 assets 重新复制，避免残留坏文件导致查询报 no such table。
  static Future<void> copyFromAssets() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = join(dir.path, 'vocabulary.db');

    if (await _isValidVocabulary(dbPath)) return;

    final file = File(dbPath);
    if (await file.exists()) {
      await file.delete();
    }
    final data = await rootBundle.load('assets/vocabulary_study.db');
    await file.writeAsBytes(data.buffer.asUint8List());
  }

  /// 判断本地 vocabulary.db 是否为有效词库（文件非空且含 words 表）
  static Future<bool> _isValidVocabulary(String dbPath) async {
    final file = File(dbPath);
    if (!await file.exists()) return false;
    if (await file.length() == 0) return false;
    try {
      final db = await openDatabase(dbPath, readOnly: true);
      final result = await db.rawQuery(
        "SELECT COUNT(*) as c FROM sqlite_master WHERE type='table' AND name='words'",
      );
      await db.close();
      return result.isNotEmpty && (result.first['c'] as int) == 1;
    } catch (_) {
      return false;
    }
  }

  /// 读取本地词库的版本信息
  /// 返回 (version_code, version_name)
  Future<({int versionCode, String versionName})?> getVersionInfo() async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        'SELECT version_code, version_name FROM version_info ORDER BY version_code DESC LIMIT 1',
      );
      if (result.isEmpty) return null;
      return (
        versionCode: result.first['version_code'] as int,
        versionName: result.first['version_name'] as String,
      );
    } catch (_) {
      return null;
    }
  }

  /// 查询单词总数
  Future<int> getTotalWordCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM words');
    return result.first['count'] as int;
  }

  /// 查询所有学段及单词数（按等级排序）
  Future<List<Level>> getLevels() async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT id, name, level, words_count
      FROM word_level
      ORDER BY level ASC
    ''');
    return maps.map((e) => Level.fromMap(e)).toList();
  }

  /// 查询所有分类及单词数
  Future<List<Category>> getCategories() async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT c.id, c.name, c.cn_name, c.description, c.pic, c.audio,
        (SELECT COUNT(*) FROM words w WHERE w.categorie = c.id) as word_count
      FROM categories c
      ORDER BY c.name
    ''');
    return maps.map((e) => Category.fromMap(e)).toList();
  }

  /// 按筛选条件查询单词列表
  Future<List<Word>> getWords(WordFilter filter, {int? limit, int offset = 0}) async {
    final db = await database;

    final sql = StringBuffer('SELECT w.* FROM words w');
    final args = <dynamic>[];

    var hasWhere = false;
    if (filter.level != null) {
      sql.write(' WHERE w.level = ?');
      args.add(filter.level);
      hasWhere = true;
    }
    if (filter.categoryId != null) {
      sql.write(hasWhere ? ' AND' : ' WHERE');
      sql.write(' w.categorie = ?');
      args.add(filter.categoryId);
    }

    sql.write(' ORDER BY CASE WHEN w.bnc > 0 THEN w.bnc ELSE 999999 END ASC');

    if (limit != null) {
      sql.write(' LIMIT ? OFFSET ?');
      args.add(limit);
      args.add(offset);
    }

    final maps = await db.rawQuery(sql.toString(), args);
    return maps.map((e) => Word.fromMap(e)).toList();
  }

  /// 按筛选条件统计单词数
  Future<int> getWordCount(WordFilter filter) async {
    final db = await database;

    final sql = StringBuffer('SELECT COUNT(*) as count FROM words w');
    final args = <dynamic>[];

    var hasWhere = false;
    if (filter.level != null) {
      sql.write(' WHERE w.level = ?');
      args.add(filter.level);
      hasWhere = true;
    }
    if (filter.categoryId != null) {
      sql.write(hasWhere ? ' AND' : ' WHERE');
      sql.write(' w.categorie = ?');
      args.add(filter.categoryId);
    }

    final result = await db.rawQuery(sql.toString(), args);
    return result.first['count'] as int;
  }

  /// 关闭数据库连接（下载新 db 替换前需要先关闭）
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  /// 更新某单词的图片（另开可写连接，用完即关）
  ///
  /// 必须 `singleInstance: false`，否则 sqflite 会复用已打开的只读单例，
  /// 导致 UPDATE 报 SQLITE_READONLY。
  Future<void> updateWordPic(int wordId, String pic) async {
    final dbPath = await getDbPath();
    final db = await openDatabase(dbPath, singleInstance: false);
    try {
      await db.update('words', {'pic': pic},
          where: 'id = ?', whereArgs: [wordId]);
    } finally {
      await db.close();
    }
  }
}
