import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

import '../models/folder.dart';
import '../models/word.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'wordtool.db');

    return openDatabase(path, version: 1, onCreate: _onCreate, onUpgrade: null);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE folder (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        parent_id TEXT,
        has_child INTEGER NOT NULL DEFAULT 0,
        path TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE word (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fold_id TEXT NOT NULL,
        abbreviation TEXT,
        learn_word TEXT NOT NULL,
        my_word TEXT NOT NULL,
        description TEXT,
        audio TEXT,
        gif TEXT,
        net_audio TEXT,
        net_image TEXT,
        net_gif TEXT,
        image TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE practice_result (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        total_count INTEGER NOT NULL,
        correct_count INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE practice_detail (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        result_id INTEGER NOT NULL,
        word_id INTEGER NOT NULL,
        is_correct INTEGER NOT NULL
      )
    ''');
  }

  // _onUpgrade 已移除：项目未发布过版本，所有表在 _onCreate 中一次性创建

  // ==================== Folder CRUD ====================

  Future<String> insertFolder(Folder folder) async {
    final db = await database;
    final id = folder.id.isEmpty ? const Uuid().v4() : folder.id;
    final newFolder = folder.copyWith(id: id);
    await db.insert('folder', newFolder.toMap());
    return id;
  }

  Future<List<Folder>> getAllFolders() async {
    final db = await database;
    final maps = await db.query('folder');
    return maps.map((e) => Folder.fromMap(e)).toList();
  }

  Future<List<Folder>> getFoldersByParentId(String? parentId) async {
    final db = await database;
    final maps = await db.query(
      'folder',
      where: parentId == null ? 'parent_id IS NULL' : 'parent_id = ?',
      whereArgs: parentId == null ? [] : [parentId],
    );
    return maps.map((e) => Folder.fromMap(e)).toList();
  }

  Future<Folder?> getFolderById(String id) async {
    final db = await database;
    final maps = await db.query(
      'folder',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Folder.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateFolder(Folder folder) async {
    final db = await database;
    return db.update(
      'folder',
      folder.toMap(),
      where: 'id = ?',
      whereArgs: [folder.id],
    );
  }

  Future<int> deleteFolder(String id) async {
    final db = await database;
    return db.delete('folder', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteFolderCascade(String folderId) async {
    final db = await database;

    // 1. 递归删除所有子目录及其数据
    final children = await db.query(
      'folder',
      where: 'parent_id = ?',
      whereArgs: [folderId],
    );
    for (final child in children) {
      await deleteFolderCascade(child['id'] as String);
    }

    // 2. 删除该目录下的所有单词
    await db.delete('word', where: 'fold_id = ?', whereArgs: [folderId]);

    // 3. 删除该目录本身
    await db.delete('folder', where: 'id = ?', whereArgs: [folderId]);
  }

  // ==================== Word CRUD ====================

  Future<int> insertWord(Word word) async {
    final db = await database;
    return db.insert('word', word.toMap());
  }

  Future<List<Word>> getAllWords() async {
    final db = await database;
    final maps = await db.query('word');
    return maps.map((e) => Word.fromMap(e)).toList();
  }

  Future<List<Word>> getWordsByFolderId(String foldId) async {
    final db = await database;
    final maps = await db.query(
      'word',
      where: 'fold_id = ?',
      whereArgs: [foldId],
    );
    return maps.map((e) => Word.fromMap(e)).toList();
  }

  Future<Word?> getWordById(int id) async {
    final db = await database;
    final maps = await db.query(
      'word',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Word.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateWord(Word word) async {
    final db = await database;
    return db.update(
      'word',
      word.toMap(),
      where: 'id = ?',
      whereArgs: [word.id],
    );
  }

  Future<int> deleteWord(int id) async {
    final db = await database;
    return db.delete('word', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== Practice Result ====================

  Future<int> insertPracticeResult({
    required String type,
    required int totalCount,
    required int correctCount,
    required List<Map<String, dynamic>> details,
  }) async {
    final db = await database;
    final resultId = await db.insert('practice_result', {
      'type': type,
      'total_count': totalCount,
      'correct_count': correctCount,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    for (final detail in details) {
      await db.insert('practice_detail', {
        'result_id': resultId,
        'word_id': detail['word_id'],
        'is_correct': detail['is_correct'],
      });
    }
    return resultId;
  }

  Future<List<Map<String, dynamic>>> getPracticeResults(String type) async {
    final db = await database;
    return db.query(
      'practice_result',
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'created_at DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getPracticeResultsByTypes(
    List<String> types,
  ) async {
    final db = await database;
    final placeholders = types.map((_) => '?').join(',');
    return db.query(
      'practice_result',
      where: 'type IN ($placeholders)',
      whereArgs: types,
      orderBy: 'created_at DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getPracticeDetails(int resultId) async {
    final db = await database;
    return db.query(
      'practice_detail',
      where: 'result_id = ?',
      whereArgs: [resultId],
    );
  }

  // ==================== Close ====================

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
