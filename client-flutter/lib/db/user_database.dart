import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/daily_task.dart';
import '../models/task.dart';
import '../models/word.dart';

/// 任务单词信息（含练习计数及测试状态），用于单词列表分页展示
class TaskWordInfo {
  final Word word;
  final int date;
  final int audioCount;
  final int spellCount;
  final int readCount;
  final bool isTodayTestPassed;

  TaskWordInfo({
    required this.word,
    required this.date,
    required this.audioCount,
    required this.spellCount,
    required this.readCount,
    this.isTodayTestPassed = false,
  });

  TaskWordInfo copyWith({bool? isTodayTestPassed}) {
    return TaskWordInfo(
      word: word,
      date: date,
      audioCount: audioCount,
      spellCount: spellCount,
      readCount: readCount,
      isTodayTestPassed: isTodayTestPassed ?? this.isTodayTestPassed,
    );
  }

  factory TaskWordInfo.fromMap(Map<String, dynamic> m) {
    return TaskWordInfo(
      word: Word(
        id: m['word_id'] as int,
        word: m['word'] as String,
        translation: m['translation'] as String?,
        phonetic: m['phonetic'] as String?,
        pic: m['pic'] as String?,
        audio: m['audio'] as String?,
      ),
      date: m['date'] as int? ?? 0,
      audioCount: (m['audio_count'] as int?) ?? 0,
      spellCount: (m['spell_count'] as int?) ?? 0,
      readCount: (m['read_count'] as int?) ?? 0,
    );
  }
}

/// 用户数据库（本地创建，保存练习记录等用户数据）
///
/// 与 vocabulary.db 完全独立，词库更新不影响用户数据。
/// practice_detail 表存储单词文本（而非 word_id），
/// 即使词库重建导致 id 变化，练习记录依然有效。
class UserDatabase {
  static final UserDatabase instance = UserDatabase._internal();
  static Database? _database;

  UserDatabase._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'user.db');
    return openDatabase(path, version: 6, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createV1Tables(db);
    await _createV2Tables(db);
    await _createV3Tables(db);
    await _createV4Tables(db);
    await _createV5Tables(db);
    // V6 的 pic/audio 字段已在 V4 CREATE TABLE 中包含，不再重复执行
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 6) {
      await _createV6Tables(db);
    }
  }

  Future<void> _createV1Tables(Database db) async {
    await db.execute('''
      CREATE TABLE practice_result (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        total_count INTEGER NOT NULL,
        correct_count INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        task_id INTEGER,
        daily_task_id INTEGER,
        mode TEXT NOT NULL DEFAULT 'practice'
      )
    ''');

    await db.execute('''
      CREATE TABLE practice_detail (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        result_id INTEGER NOT NULL,
        word TEXT NOT NULL,
        is_correct INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _createV2Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  /// V3：增强 tasks 表、新建 daily_tasks 表、增强 practice_result 表
  Future<void> _createV3Tables(Database db) async {
    // tasks 表（V3 完整结构，用于全新安装）
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        level INTEGER,
        category_id INTEGER,
        total_words INTEGER NOT NULL,
        daily_goal INTEGER NOT NULL,
        start_date INTEGER NOT NULL,
        deadline INTEGER NOT NULL,
        status INTEGER NOT NULL DEFAULT 0,
        stars INTEGER,
        completed_at INTEGER,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id INTEGER NOT NULL,
        date INTEGER NOT NULL,
        target_count INTEGER NOT NULL,
        learned_count INTEGER NOT NULL DEFAULT 0,
        status INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
      )
    ''');

    // practice_result 的 task_id/daily_task_id/mode 已在 V1 CREATE TABLE 中包含
  }

  /// V4：新建 task_words 表（任务自定义单词列表，含日期分配和练习状态）
  Future<void> _createV4Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS task_words (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id INTEGER NOT NULL,
        word_id INTEGER NOT NULL,
        word TEXT NOT NULL,
        translation TEXT,
        phonetic TEXT,
        pic TEXT,
        audio TEXT,
        date INTEGER NOT NULL,
        is_practiced INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
      )
    ''');
  }

  /// V5：新建 word_practice_progress 表（单词练习日志）
  Future<void> _createV5Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS word_practice_progress (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id INTEGER NOT NULL,
        word_id INTEGER NOT NULL,
        word TEXT NOT NULL,
        date INTEGER NOT NULL,
        practice_type INTEGER NOT NULL,
        is_correct INTEGER NOT NULL DEFAULT 0,
        content TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
  }

  /// V6：task_words 表增加 pic 和 audio 字段（旧版本升级用）
  Future<void> _createV6Tables(Database db) async {
    try {
      await db.execute('ALTER TABLE task_words ADD COLUMN pic TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE task_words ADD COLUMN audio TEXT');
    } catch (_) {}
  }

  // ==================== Practice Result ====================

  /// 插入练习结果（含详情）
  ///
  /// [details] 中每项应包含 'word'（单词文本）和 'is_correct'（0 或 1）
  /// [taskId] / [dailyTaskId] 可选，关联任务时传入
  /// [mode] 练习模式：'practice' / 'test' / 'review'
  Future<int> insertPracticeResult({
    required String type,
    required int totalCount,
    required int correctCount,
    required List<Map<String, dynamic>> details,
    int? taskId,
    int? dailyTaskId,
    String mode = 'practice',
  }) async {
    final db = await database;
    final resultId = await db.insert('practice_result', {
      'type': type,
      'total_count': totalCount,
      'correct_count': correctCount,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'task_id': taskId,
      'daily_task_id': dailyTaskId,
      'mode': mode,
    });
    for (final detail in details) {
      await db.insert('practice_detail', {
        'result_id': resultId,
        'word': detail['word'],
        'is_correct': detail['is_correct'],
      });
    }
    return resultId;
  }

  /// 按练习类型查询练习记录（含任务名称）
  ///
  /// [date] 不为 null 时只返回该日期的记录
  Future<List<Map<String, dynamic>>> getPracticeResults(
    String type, {
    DateTime? date,
  }) async {
    final db = await database;
    if (date != null) {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      return db.rawQuery('''
        SELECT pr.*, t.name as task_name
        FROM practice_result pr
        LEFT JOIN tasks t ON pr.task_id = t.id
        WHERE pr.type = ? AND pr.created_at >= ? AND pr.created_at < ?
        ORDER BY pr.created_at DESC
      ''', [type, startOfDay.millisecondsSinceEpoch, endOfDay.millisecondsSinceEpoch]);
    }
    return db.rawQuery('''
      SELECT pr.*, t.name as task_name
      FROM practice_result pr
      LEFT JOIN tasks t ON pr.task_id = t.id
      WHERE pr.type = ?
      ORDER BY pr.created_at DESC
    ''', [type]);
  }

  /// 按多个练习类型查询练习记录（含任务名称）
  ///
  /// [date] 不为 null 时只返回该日期的记录
  Future<List<Map<String, dynamic>>> getPracticeResultsByTypes(
    List<String> types, {
    DateTime? date,
  }) async {
    final db = await database;
    if (types.isEmpty) return [];
    final placeholders = types.map((_) => '?').join(',');
    if (date != null) {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      return db.rawQuery('''
        SELECT pr.*, t.name as task_name
        FROM practice_result pr
        LEFT JOIN tasks t ON pr.task_id = t.id
        WHERE pr.type IN ($placeholders)
          AND pr.created_at >= ? AND pr.created_at < ?
        ORDER BY pr.created_at DESC
      ''', [...types, startOfDay.millisecondsSinceEpoch, endOfDay.millisecondsSinceEpoch]);
    }
    return db.rawQuery('''
      SELECT pr.*, t.name as task_name
      FROM practice_result pr
      LEFT JOIN tasks t ON pr.task_id = t.id
      WHERE pr.type IN ($placeholders)
      ORDER BY pr.created_at DESC
    ''', types);
  }

  /// 查询某次练习的详情
  Future<List<Map<String, dynamic>>> getPracticeDetails(int resultId) async {
    final db = await database;
    return db.query(
      'practice_detail',
      where: 'result_id = ?',
      whereArgs: [resultId],
    );
  }

  // ==================== Task ====================

  static const int maxWordsPerTask = 300;

  /// 创建任务并批量生成每日任务，同时按日期分配单词
  ///
  /// [words] 任务的全部单词列表，按 dailyGoal 切分到每天。
  /// 最多 [maxWordsPerTask] 个单词，超额抛出异常。
  /// [onProgress] 进度回调 (current, total)，用于大批量插入时更新 UI。
  Future<int> createTask(Task task, List<Word> words, {
    void Function(int current, int total)? onProgress,
  }) async {
    if (words.length > maxWordsPerTask) {
      throw Exception('任务最多 $maxWordsPerTask 个单词，当前 ${words.length} 个');
    }

    final db = await database;
    final taskId = await db.insert('tasks', task.toMap()..remove('id'));

    final totalDays = task.deadline.difference(task.startDate).inDays + 1;
    const chunkSize = 200;
    var wordIndex = 0;

    // 先插入每日任务
    for (var i = 0; i < totalDays; i++) {
      final date = task.startDate.add(Duration(days: i));
      final dateStart = DateTime(date.year, date.month, date.day);
      final dateMs = dateStart.millisecondsSinceEpoch;

      final isLastDay = i == totalDays - 1;
      final targetCount = isLastDay
          ? task.totalWords - task.dailyGoal * (totalDays - 1)
          : task.dailyGoal;
      final actualCount = targetCount > 0 ? targetCount : task.dailyGoal;

      await db.insert('daily_tasks', {
        'task_id': taskId,
        'date': dateMs,
        'target_count': actualCount,
        'learned_count': 0,
        'status': 0,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
    }

    // 分批插入 task_words，每批 chunkSize 个，报告进度
    while (wordIndex < words.length) {
      final batch = db.batch();
      final end = (wordIndex + chunkSize).clamp(0, words.length);
      for (var idx = wordIndex; idx < end; idx++) {
        final w = words[idx];
        final dayIndex = idx ~/ task.dailyGoal;
        final wordDate = task.startDate.add(Duration(days: dayIndex));
        final wordDateMs = DateTime(wordDate.year, wordDate.month, wordDate.day).millisecondsSinceEpoch;

        batch.insert('task_words', {
          'task_id': taskId,
          'word_id': w.id ?? 0,
          'word': w.word,
          'translation': w.translation,
          'phonetic': w.phonetic,
          'pic': w.pic,
          'audio': w.audio,
          'date': wordDateMs,
        });
      }
      await batch.commit(noResult: true);
      wordIndex = end;
      onProgress?.call(wordIndex, words.length);
    }

    return taskId;
  }

  /// 更新任务
  Future<void> updateTask(Task task) async {
    final db = await database;
    await db.update(
      'tasks',
      task.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  /// 查询进行中的任务（当前活跃任务）
  Future<Task?> getActiveTask() async {
    final db = await database;
    final maps = await db.query(
      'tasks',
      where: 'status = ?',
      whereArgs: [TaskStatus.active.index],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Task.fromMap(maps.first);
  }

  /// 按 ID 查询单个任务
  Future<Task?> getTask(int taskId) async {
    final db = await database;
    final maps = await db.query(
      'tasks',
      where: 'id = ?',
      whereArgs: [taskId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Task.fromMap(maps.first);
  }

  /// 查询所有任务（按创建时间倒序）
  Future<List<Task>> getAllTasks() async {
    final db = await database;
    final maps = await db.query('tasks', orderBy: 'created_at DESC');
    return maps.map((e) => Task.fromMap(e)).toList();
  }

  /// 查询已完成/已放弃的任务（历史）
  Future<List<Task>> getHistoryTasks() async {
    final db = await database;
    final maps = await db.query(
      'tasks',
      where: 'status != ?',
      whereArgs: [TaskStatus.active.index],
      orderBy: 'created_at DESC',
    );
    return maps.map((e) => Task.fromMap(e)).toList();
  }

  /// 删除任务（连同 daily_tasks 和 task_words 级联删除）
  Future<void> deleteTask(int id) async {
    final db = await database;
    await db.delete('task_words', where: 'task_id = ?', whereArgs: [id]);
    await db.delete('daily_tasks', where: 'task_id = ?', whereArgs: [id]);
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  /// 放弃任务（标记为已放弃，并评分）
  Future<void> abandonTask(int taskId) async {
    final db = await database;
    final stars = await _calculateStars(taskId);
    await db.update(
      'tasks',
      {
        'status': TaskStatus.abandoned.index,
        'stars': stars,
        'completed_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  /// 统计任务已学习单词数（去重，基于任务开始时间）
  Future<int> getTaskLearnedWordCount(Task task) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COUNT(DISTINCT pd.word) as count
      FROM practice_detail pd
      JOIN practice_result pr ON pd.result_id = pr.id
      WHERE pr.created_at >= ?
    ''', [task.startDate.millisecondsSinceEpoch]);
    return result.first['count'] as int;
  }

  // ==================== Task Words ====================

  /// 按日期分批插入任务单词（用于编辑任务时重新分配）
  Future<void> insertTaskWordsWithDates(
      int taskId, List<Word> words, int dailyGoal, DateTime startDate, {
    void Function(int current, int total)? onProgress,
  }) async {
    final db = await database;
    const chunkSize = 200;
    var wordIndex = 0;

    while (wordIndex < words.length) {
      final batch = db.batch();
      final end = (wordIndex + chunkSize).clamp(0, words.length);
      for (var idx = wordIndex; idx < end; idx++) {
        final w = words[idx];
        final dayIndex = idx ~/ dailyGoal;
        final date = startDate.add(Duration(days: dayIndex));
        final dateMs = DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
        batch.insert('task_words', {
          'task_id': taskId,
          'word_id': w.id ?? 0,
          'word': w.word,
          'translation': w.translation,
          'phonetic': w.phonetic,
          'pic': w.pic,
          'audio': w.audio,
          'date': dateMs,
        });
      }
      await batch.commit(noResult: true);
      wordIndex = end;
      onProgress?.call(wordIndex, words.length);
    }
  }

  /// 查询今日单词列表（优先今日日期，无则取最近未完成日期的单词）
  Future<List<Word>> getTodayTaskWords(int taskId) async {
    final db = await database;
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final todayMs = startOfToday.millisecondsSinceEpoch;

    // 先查今日日期的单词
    var maps = await db.query(
      'task_words',
      where: 'task_id = ? AND date = ?',
      whereArgs: [taskId, todayMs],
      orderBy: 'id ASC',
    );

    // 今日无单词分配时，查最近未完成日期的单词（逾期延续）
    if (maps.isEmpty) {
      final result = await db.rawQuery('''
        SELECT tw.* FROM task_words tw
        JOIN daily_tasks dt ON tw.task_id = dt.task_id AND tw.date = dt.date
        WHERE tw.task_id = ? AND dt.date < ? AND dt.status != 1
        ORDER BY dt.date ASC, tw.id ASC
      ''', [taskId, todayMs]);
      maps = result;
    }

    final words = maps.map((m) => Word(
      id: m['word_id'] as int,
      word: m['word'] as String,
      translation: m['translation'] as String?,
      phonetic: m['phonetic'] as String?,
      pic: m['pic'] as String?,
      audio: m['audio'] as String?,
    )).toList();

    return await _fillMissingMedia(words);
  }

  /// 查询今日目标词数（当日 task_words 数量）
  Future<int> getTodayTargetWordCount(int taskId) async {
    final db = await database;
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final todayMs = startOfToday.millisecondsSinceEpoch;

    // 先查今日
    var result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM task_words WHERE task_id = ? AND date = ?',
      [taskId, todayMs],
    );
    var count = result.first['count'] as int;

    // 今日无分配时，查逾期子任务的单词数
    if (count == 0) {
      result = await db.rawQuery('''
        SELECT COUNT(*) as count FROM task_words tw
        JOIN daily_tasks dt ON tw.task_id = dt.task_id AND tw.date = dt.date
        WHERE tw.task_id = ? AND dt.date < ? AND dt.status != 1
      ''', [taskId, todayMs]);
      count = result.first['count'] as int;
    }
    return count;
  }

  /// 查询任务的单词列表
  Future<List<Word>> getTaskWords(int taskId) async {
    final db = await database;
    final maps = await db.query(
      'task_words',
      where: 'task_id = ?',
      whereArgs: [taskId],
      orderBy: 'id ASC',
    );
    final words = maps.map((m) => Word(
      id: m['word_id'] as int,
      word: m['word'] as String,
      translation: m['translation'] as String?,
      phonetic: m['phonetic'] as String?,
      pic: m['pic'] as String?,
      audio: m['audio'] as String?,
    )).toList();
    return await _fillMissingMedia(words);
  }

  /// 查询任务的单词 ID 集合（用于快速判断是否已选）
  Future<Set<int>> getTaskWordIds(int taskId) async {
    final db = await database;
    final maps = await db.query(
      'task_words',
      columns: ['word_id'],
      where: 'task_id = ?',
      whereArgs: [taskId],
    );
    return maps.map((m) => m['word_id'] as int).toSet();
  }

  /// 查询所有任务中已分配的单词 ID（排除指定任务）
  ///
  /// [excludeTaskId] 当前正在编辑的任务 ID，避免排除自己的单词
  Future<Set<int>> getAllAssignedWordIds({int? excludeTaskId}) async {
    final db = await database;
    final sql = excludeTaskId != null
        ? 'SELECT DISTINCT word_id FROM task_words WHERE task_id != ?'
        : 'SELECT DISTINCT word_id FROM task_words';
    final args = excludeTaskId != null ? [excludeTaskId] : <dynamic>[];
    final maps = await db.rawQuery(sql, args);
    return maps.map((m) => m['word_id'] as int).toSet();
  }

  /// 移除任务中的某个单词
  Future<void> removeTaskWord(int taskId, int wordId) async {
    final db = await database;
    await db.delete('task_words',
      where: 'task_id = ? AND word_id = ?',
      whereArgs: [taskId, wordId]);
  }

  /// 更新所有任务中某单词的图片（按 word_id 全局更新）
  Future<void> updateTaskWordPic(int wordId, String pic) async {
    final db = await database;
    await db.update('task_words', {'pic': pic},
        where: 'word_id = ?', whereArgs: [wordId]);
  }

  /// 清空任务的单词列表
  Future<void> clearTaskWords(int taskId) async {
    final db = await database;
    await db.delete('task_words', where: 'task_id = ?', whereArgs: [taskId]);
  }

  /// 查询任务的单词数
  Future<int> getTaskWordCount(int taskId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM task_words WHERE task_id = ?',
      [taskId]);
    return result.first['count'] as int;
  }

  /// 分页查询任务单词列表（包含练习次数及今日测试通过状态）
  Future<List<TaskWordInfo>> getTaskWordsPage(
    int taskId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final words = await _queryTaskWordsWithProgress(
      taskId,
      limit: limit,
      offset: offset,
    );
    final isTodayPassed = await isTodayTestPassed(taskId);
    return words.map((w) => w.copyWith(isTodayTestPassed: isTodayPassed)).toList();
  }

  /// 内部方法：查询任务单词并连出练习次数（不含今日测试通过状态）
  Future<List<TaskWordInfo>> _queryTaskWordsWithProgress(
    int taskId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await database;

    final maps = await db.rawQuery('''
      SELECT tw.*,
        (SELECT COUNT(*) FROM word_practice_progress wpp
         WHERE wpp.task_id=tw.task_id AND wpp.word_id=tw.word_id AND wpp.practice_type=1) as audio_count,
        (SELECT COUNT(*) FROM word_practice_progress wpp
         WHERE wpp.task_id=tw.task_id AND wpp.word_id=tw.word_id AND wpp.practice_type=2 AND wpp.is_correct=1) as spell_count,
        (SELECT COUNT(*) FROM word_practice_progress wpp
         WHERE wpp.task_id=tw.task_id AND wpp.word_id=tw.word_id AND wpp.practice_type=3) as read_count
      FROM task_words tw
      WHERE tw.task_id = ?
      ORDER BY tw.id ASC
      LIMIT ? OFFSET ?
    ''', [taskId, limit, offset]);

    return maps.map((m) => TaskWordInfo.fromMap(m)).toList();
  }

  /// 从任务中随机取 N 个单词作为测试选项池
  Future<List<Word>> getTestOptionPool(int taskId, {int count = 20}) async {
    final db = await database;
    final total = await getTaskWordCount(taskId);
    if (total == 0) return [];

    final limit = count.clamp(0, total);
    final maps = await db.rawQuery(
      'SELECT DISTINCT word_id, word, translation, phonetic, pic, audio FROM task_words WHERE task_id = ? ORDER BY RANDOM() LIMIT ?',
      [taskId, limit],
    );
    final words = maps.map((m) => Word(
      id: m['word_id'] as int,
      word: m['word'] as String,
      translation: m['translation'] as String?,
      phonetic: m['phonetic'] as String?,
      pic: m['pic'] as String?,
      audio: m['audio'] as String?,
    )).toList();
    return await _fillMissingMedia(words);
  }

  /// 从词库补全单词的 pic 和 audio（兼容旧数据中 task_words 缺失的媒体字段）
  Future<List<Word>> _fillMissingMedia(List<Word> words) async {
    final missingIds = <int>[];
    for (final w in words) {
      if ((w.pic == null || w.audio == null) && w.id != null) {
        missingIds.add(w.id!);
      }
    }
    if (missingIds.isEmpty) return words;

    final vdb = await _getVocabDb();
    if (vdb == null) return words;

    final placeholders = missingIds.map((_) => '?').join(',');
    final rows = await vdb.rawQuery(
      'SELECT id, pic, audio FROM words WHERE id IN ($placeholders)',
      missingIds,
    );
    final mediaMap = <int, Map<String, String?>>{};
    for (final r in rows) {
      mediaMap[r['id'] as int] = {'pic': r['pic'] as String?, 'audio': r['audio'] as String?};
    }

    return words.map((w) {
      final media = mediaMap[w.id];
      if (media == null) return w;
      return w.copyWith(
        pic: w.pic ?? media['pic'],
        audio: w.audio ?? media['audio'],
      );
    }).toList();
  }

  Database? _vocabDb;
  Future<Database?> _getVocabDb() async {
    if (_vocabDb != null) return _vocabDb;
    try {
      final dir = await getApplicationDocumentsDirectory();
      _vocabDb = await openDatabase(p.join(dir.path, 'vocabulary.db'), readOnly: true);
      return _vocabDb;
    } catch (_) {
      return null;
    }
  }

  /// 向已有任务追加单词（去重后按日期分配到末尾）
  ///
  /// [onProgress] 进度回调 (current, total)。
  /// 返回实际新增的单词数。
  Future<int> addWordsToTask(int taskId, List<Word> newWords, {
    void Function(int current, int total)? onProgress,
  }) async {
    final db = await database;

    // 1. 查询任务信息
    final taskMaps = await db.query('tasks', where: 'id = ?', whereArgs: [taskId]);
    if (taskMaps.isEmpty) throw Exception('任务不存在');
    final task = Task.fromMap(taskMaps.first);

    // 2. 获取已有单词 ID，去重
    final existingIds = await getTaskWordIds(taskId);
    final toAdd = newWords.where((w) => !existingIds.contains(w.id)).toList();
    if (toAdd.isEmpty) return 0;

    // 3. 检查上限
    final currentCount = await getTaskWordCount(taskId);
    if (currentCount + toAdd.length > maxWordsPerTask) {
      final available = maxWordsPerTask - currentCount;
      throw Exception(
        '任务最多 $maxWordsPerTask 个单词，已有 $currentCount 个，还能添加 $available 个，当前尝试添加 ${toAdd.length} 个');
    }

    // 4. 找到最后一个 daily_task 的日期 + 剩余容量
    final lastDaily = await db.query(
      'daily_tasks',
      where: 'task_id = ?',
      whereArgs: [taskId],
      orderBy: 'date DESC',
      limit: 1,
    );
    int lastDateMs;
    int remainingCapacity;
    if (lastDaily.isEmpty) {
      lastDateMs = task.startDate.millisecondsSinceEpoch;
      remainingCapacity = 0;
    } else {
      lastDateMs = lastDaily.first['date'] as int;
      // 统计最后一天已有单词数
      final countResult = await db.rawQuery(
        'SELECT COUNT(*) as c FROM task_words WHERE task_id = ? AND date = ?',
        [taskId, lastDateMs],
      );
      final count = countResult.first['c'] as int;
      final target = lastDaily.first['target_count'] as int;
      remainingCapacity = (target - count).clamp(0, target);
    }

    // 5. 从最后一天开始，按 dailyGoal 分配新单词
    const chunkSize = 200;
    var wordIndex = 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    while (wordIndex < toAdd.length) {
      if (remainingCapacity <= 0) {
        // 需要新的一天
        lastDateMs += 86400000; // +1 day in ms
        final lastDate = DateTime.fromMillisecondsSinceEpoch(lastDateMs);
        final cleanDate = DateTime(lastDate.year, lastDate.month, lastDate.day);
        lastDateMs = cleanDate.millisecondsSinceEpoch;
        remainingCapacity = task.dailyGoal;

        await db.insert('daily_tasks', {
          'task_id': taskId,
          'date': lastDateMs,
          'target_count': task.dailyGoal,
          'learned_count': 0,
          'status': 0,
          'created_at': nowMs,
        });
      }

      final batchSize = chunkSize.clamp(0, remainingCapacity.clamp(0, toAdd.length - wordIndex));
      final batch = db.batch();
      for (var j = 0; j < batchSize && wordIndex < toAdd.length; j++) {
        final w = toAdd[wordIndex++];
        batch.insert('task_words', {
          'task_id': taskId,
          'word_id': w.id ?? 0,
          'word': w.word,
          'translation': w.translation,
          'phonetic': w.phonetic,
          'pic': w.pic,
          'audio': w.audio,
          'date': lastDateMs,
        });
      }
      await batch.commit(noResult: true);
      remainingCapacity -= batchSize;
      onProgress?.call(wordIndex, toAdd.length);
    }

    // 6. 更新 tasks.total_words
    final newTotal = currentCount + toAdd.length;
    await db.update('tasks', {'total_words': newTotal}, where: 'id = ?', whereArgs: [taskId]);

    return toAdd.length;
  }

  // ==================== Word Practice Progress ====================

  /// 插入一条练习日志，并自动检查是否需要更新 is_practiced
  ///
  /// [practiceType] 1=听音, 2=拼写, 3=跟读
  /// [isCorrect] 拼写时是否正确；听音/跟读传 true
  /// [content] type=2:用户输入文本; type=3:录音路径; type=1:null
  Future<void> insertPracticeLog({
    required int taskId,
    required int wordId,
    required String word,
    required int date,
    required int practiceType,
    bool isCorrect = false,
    String? content,
  }) async {
    final db = await database;
    await db.insert('word_practice_progress', {
      'task_id': taskId,
      'word_id': wordId,
      'word': word,
      'date': date,
      'practice_type': practiceType,
      'is_correct': isCorrect ? 1 : 0,
      'content': content,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    await _checkAndUpdateIsPracticed(db, taskId, wordId, date);
  }

  static const int _practiceTarget = 10;

  /// 检查单词三项练习是否都达标（各≥10次），达标则更新 task_words.is_practiced=1
  Future<void> _checkAndUpdateIsPracticed(
      Database db, int taskId, int wordId, int date) async {
    final result = await db.rawQuery('''
      SELECT
        SUM(CASE WHEN practice_type=1 THEN 1 ELSE 0 END) as audio_count,
        SUM(CASE WHEN practice_type=2 AND is_correct=1 THEN 1 ELSE 0 END) as spell_count,
        SUM(CASE WHEN practice_type=3 THEN 1 ELSE 0 END) as read_count
      FROM word_practice_progress
      WHERE task_id=? AND word_id=? AND date=?
    ''', [taskId, wordId, date]);

    final row = result.first;
    final audioCount = (row['audio_count'] as int?) ?? 0;
    final spellCount = (row['spell_count'] as int?) ?? 0;
    final readCount = (row['read_count'] as int?) ?? 0;

    if (audioCount >= _practiceTarget &&
        spellCount >= _practiceTarget &&
        readCount >= _practiceTarget) {
      await db.update(
        'task_words',
        {'is_practiced': 1},
        where: 'task_id=? AND word_id=? AND date=?',
        whereArgs: [taskId, wordId, date],
      );
    }
  }

  /// 查询单个单词的三项练习计数
  Future<({int audio, int spell, int read})> getWordPracticeCounts(
      int taskId, int wordId, int date) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT
        SUM(CASE WHEN practice_type=1 THEN 1 ELSE 0 END) as audio_count,
        SUM(CASE WHEN practice_type=2 AND is_correct=1 THEN 1 ELSE 0 END) as spell_count,
        SUM(CASE WHEN practice_type=3 THEN 1 ELSE 0 END) as read_count
      FROM word_practice_progress
      WHERE task_id=? AND word_id=? AND date=?
    ''', [taskId, wordId, date]);

    final row = result.first;
    return (
      audio: (row['audio_count'] as int?) ?? 0,
      spell: (row['spell_count'] as int?) ?? 0,
      read: (row['read_count'] as int?) ?? 0,
    );
  }

  /// 查询今日单词列表（含练习进度和 is_practiced 状态）
  Future<List<Map<String, dynamic>>> getTodayWordsWithProgress(int taskId) async {
    final db = await database;
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final todayMs = startOfToday.millisecondsSinceEpoch;

    var maps = await db.rawQuery('''
      SELECT tw.*, 
        (SELECT COUNT(*) FROM word_practice_progress wpp 
         WHERE wpp.task_id=tw.task_id AND wpp.word_id=tw.word_id AND wpp.date=tw.date AND wpp.practice_type=1) as audio_count,
        (SELECT COUNT(*) FROM word_practice_progress wpp 
         WHERE wpp.task_id=tw.task_id AND wpp.word_id=tw.word_id AND wpp.date=tw.date AND wpp.practice_type=2 AND wpp.is_correct=1) as spell_count,
        (SELECT COUNT(*) FROM word_practice_progress wpp 
         WHERE wpp.task_id=tw.task_id AND wpp.word_id=tw.word_id AND wpp.date=tw.date AND wpp.practice_type=3) as read_count
      FROM task_words tw
      WHERE tw.task_id=? AND tw.date=?
      ORDER BY tw.id ASC
    ''', [taskId, todayMs]);

    if (maps.isEmpty) {
      maps = await db.rawQuery('''
        SELECT tw.*, 
          (SELECT COUNT(*) FROM word_practice_progress wpp 
           WHERE wpp.task_id=tw.task_id AND wpp.word_id=tw.word_id AND wpp.date=tw.date AND wpp.practice_type=1) as audio_count,
          (SELECT COUNT(*) FROM word_practice_progress wpp 
           WHERE wpp.task_id=tw.task_id AND wpp.word_id=tw.word_id AND wpp.date=tw.date AND wpp.practice_type=2 AND wpp.is_correct=1) as spell_count,
          (SELECT COUNT(*) FROM word_practice_progress wpp 
           WHERE wpp.task_id=tw.task_id AND wpp.word_id=tw.word_id AND wpp.date=tw.date AND wpp.practice_type=3) as read_count
        FROM task_words tw
        JOIN daily_tasks dt ON tw.task_id=dt.task_id AND tw.date=dt.date
        WHERE tw.task_id=? AND dt.date < ? AND dt.status != 1
        ORDER BY dt.date ASC, tw.id ASC
      ''', [taskId, todayMs]);
    }

    return maps;
  }

  /// 统计今日已练习完成的单词数（is_practiced=1）
  Future<int> getTodayPracticedCount(int taskId) async {
    final db = await database;
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final todayMs = startOfToday.millisecondsSinceEpoch;

    var result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM task_words WHERE task_id=? AND date=? AND is_practiced=1',
      [taskId, todayMs],
    );
    var count = result.first['count'] as int;

    if (count == 0) {
      result = await db.rawQuery('''
        SELECT COUNT(*) as count FROM task_words tw
        JOIN daily_tasks dt ON tw.task_id=dt.task_id AND tw.date=dt.date
        WHERE tw.task_id=? AND dt.date < ? AND dt.status != 1 AND tw.is_practiced=1
      ''', [taskId, todayMs]);
      count = result.first['count'] as int;
    }
    return count;
  }

  /// 检查今日测试是否全部通过
  Future<bool> isTodayTestPassed(int taskId) async {
    final db = await database;
    final todayWords = await getTodayTaskWords(taskId);
    if (todayWords.isEmpty) return false;

    final wordTexts = todayWords.map((w) => w.word).toList();

    final results = await db.query(
      'practice_result',
      where: 'task_id=? AND mode=?',
      whereArgs: [taskId, 'test'],
      orderBy: 'created_at DESC',
    );

    for (final pr in results) {
      final resultId = pr['id'] as int;
      final placeholders = wordTexts.map((_) => '?').join(',');
      final details = await db.rawQuery('''
        SELECT word, is_correct FROM practice_detail
        WHERE result_id=? AND word IN ($placeholders)
      ''', [resultId, ...wordTexts]);

      if (details.length == wordTexts.length &&
          details.every((d) => (d['is_correct'] as int) == 1)) {
        return true;
      }
    }
    return false;
  }

  // ==================== Daily Task ====================

  /// 查询某任务的所有每日任务
  Future<List<DailyTask>> getDailyTasks(int taskId) async {
    final db = await database;
    final maps = await db.query(
      'daily_tasks',
      where: 'task_id = ?',
      whereArgs: [taskId],
      orderBy: 'date ASC',
    );
    return maps.map((e) => DailyTask.fromMap(e)).toList();
  }

  /// 查询今日每日任务（含逾期延续：今日无任务时取最近未完成的）
  Future<DailyTask?> getTodayDailyTask(int taskId) async {
    final db = await database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final startMs = startOfDay.millisecondsSinceEpoch;
    final endMs = startOfDay.add(const Duration(days: 1)).millisecondsSinceEpoch;

    // 先查今日日期的任务
    var maps = await db.query(
      'daily_tasks',
      where: 'task_id = ? AND date >= ? AND date < ?',
      whereArgs: [taskId, startMs, endMs],
      limit: 1,
    );
    if (maps.isNotEmpty) return DailyTask.fromMap(maps.first);

    // 今日无任务时，查最近未完成的（逾期延续）
    maps = await db.query(
      'daily_tasks',
      where: 'task_id = ? AND date < ? AND status != ?',
      whereArgs: [taskId, startMs, DailyTaskStatus.completed.index],
      orderBy: 'date ASC',
      limit: 1,
    );
    if (maps.isNotEmpty) return DailyTask.fromMap(maps.first);
    return null;
  }

  /// 更新每日任务的已学词数（基于今日单词全对判定）
  Future<void> updateDailyTaskLearnedCount(int dailyTaskId, int learnedCount) async {
    final db = await database;
    final rows = await db.query(
      'daily_tasks',
      columns: ['target_count'],
      where: 'id = ?',
      whereArgs: [dailyTaskId],
    );
    if (rows.isEmpty) return;
    final targetCount = rows.first['target_count'] as int;
    final status = learnedCount >= targetCount
        ? DailyTaskStatus.completed.index
        : DailyTaskStatus.pending.index;
    await db.update(
      'daily_tasks',
      {'learned_count': learnedCount, 'status': status},
      where: 'id = ?',
      whereArgs: [dailyTaskId],
    );
  }

  /// 检查今日单词是否全部答对（基于 practice_detail 的 is_correct）
  ///
  /// 返回今日词池中已全部答对的单词数
  Future<int> getTodayMasteredWordCount(int taskId) async {
    final db = await database;
    // 获取今日单词文本列表
    final todayWords = await getTodayTaskWords(taskId);
    if (todayWords.isEmpty) return 0;

    final wordTexts = todayWords.map((w) => w.word).toList();
    final placeholders = wordTexts.map((_) => '?').join(',');

    // 查询这些单词中全部答对过的（在 practice_detail 中有 is_correct=1 记录）
    final result = await db.rawQuery('''
      SELECT COUNT(DISTINCT pd.word) as count
      FROM practice_detail pd
      JOIN practice_result pr ON pd.result_id = pr.id
      WHERE pr.task_id = ? AND pd.word IN ($placeholders) AND pd.is_correct = 1
    ''', [taskId, ...wordTexts]);
    return result.first['count'] as int;
  }

  /// 检查并标记逾期每日任务（日期已过但未完成）
  Future<void> checkOverdueDailyTasks(int taskId) async {
    final db = await database;
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    await db.update(
      'daily_tasks',
      {'status': DailyTaskStatus.overdue.index},
      where: 'task_id = ? AND date < ? AND status = ?',
      whereArgs: [taskId, startOfToday.millisecondsSinceEpoch, DailyTaskStatus.pending.index],
    );
  }

  /// 统计今日已学单词数（去重）
  Future<int> getTodayLearnedCount(int taskId) async {
    final db = await database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final result = await db.rawQuery('''
      SELECT COUNT(DISTINCT pd.word) as count
      FROM practice_detail pd
      JOIN practice_result pr ON pd.result_id = pr.id
      WHERE pr.task_id = ? AND pr.created_at >= ? AND pr.created_at < ?
    ''', [taskId, startOfDay.millisecondsSinceEpoch, endOfDay.millisecondsSinceEpoch]);
    return result.first['count'] as int;
  }

  /// 检查任务是否全部完成，若完成则标记并评分
  Future<void> checkTaskCompletion(int taskId) async {
    final db = await database;
    // 检查是否所有 daily_tasks 都已完成
    final result = await db.rawQuery('''
      SELECT COUNT(*) as total,
        SUM(CASE WHEN status = 1 THEN 1 ELSE 0 END) as completed
      FROM daily_tasks
      WHERE task_id = ?
    ''', [taskId]);
    final total = result.first['total'] as int;
    final completed = result.first['completed'] as int;
    if (total > 0 && total == completed) {
      final stars = await _calculateStars(taskId);
      await db.update(
        'tasks',
        {
          'status': TaskStatus.completed.index,
          'stars': stars,
          'completed_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [taskId],
      );
    }
  }

  // ==================== Stars Calculation ====================

  /// 计算任务星级评分
  ///
  /// 5星：完成率100%且逾期0天
  /// 4星：完成率>=90%且逾期<=2天
  /// 3星：完成率>=70%且逾期<=5天
  /// 2星：完成率>=50%且逾期<=10天
  /// 1星：完成率>=30%或逾期>10天
  /// 0星：完成率<30%
  Future<int> _calculateStars(int taskId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT
        COUNT(*) as total,
        SUM(CASE WHEN status = 1 THEN 1 ELSE 0 END) as completed,
        SUM(CASE WHEN status = 2 THEN 1 ELSE 0 END) as overdue
      FROM daily_tasks
      WHERE task_id = ?
    ''', [taskId]);

    final total = (result.first['total'] as int?) ?? 0;
    final completed = (result.first['completed'] as int?) ?? 0;
    final overdue = (result.first['overdue'] as int?) ?? 0;

    if (total == 0) return 0;

    final completionRate = completed / total;

    if (completionRate >= 1.0 && overdue == 0) return 5;
    if (completionRate >= 0.9 && overdue <= 2) return 4;
    if (completionRate >= 0.7 && overdue <= 5) return 3;
    if (completionRate >= 0.5 && overdue <= 10) return 2;
    if (completionRate >= 0.3 || overdue > 10) return 1;
    return 0;
  }

  /// 今日各类型练习次数
  Future<({int translation, int listening, int dictation})>
      getTodayPracticeCounts() async {
    final db = await database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final result = await db.rawQuery('''
      SELECT type, COUNT(*) as count
      FROM practice_result
      WHERE created_at >= ? AND created_at < ?
      GROUP BY type
    ''', [startOfDay.millisecondsSinceEpoch, endOfDay.millisecondsSinceEpoch]);
    int translation = 0;
    int listening = 0;
    int dictation = 0;
    for (final row in result) {
      final type = row['type'] as String;
      final count = row['count'] as int;
      if (type == 'translation') {
        translation += count;
      } else if (type.startsWith('listening')) {
        listening += count;
      } else if (type.startsWith('dictation')) {
        dictation += count;
      }
    }
    return (
      translation: translation,
      listening: listening,
      dictation: dictation,
    );
  }

  /// 每日练习统计列表（按日期倒序）
  ///
  /// 返回每个日期的翻译/听力/默写次数及总词数、正确词数。
  Future<List<Map<String, dynamic>>> getDailyPracticeStats() async {
    final db = await database;
    return db.rawQuery('''
      SELECT
        DATE(created_at / 1000, 'unixepoch', 'localtime') as day,
        COUNT(*) as session_count,
        SUM(CASE WHEN type = 'translation' THEN 1 ELSE 0 END) as translation_count,
        SUM(CASE WHEN type LIKE 'listening%' THEN 1 ELSE 0 END) as listening_count,
        SUM(CASE WHEN type LIKE 'dictation%' THEN 1 ELSE 0 END) as dictation_count,
        SUM(total_count) as total_words,
        SUM(correct_count) as correct_words
      FROM practice_result
      GROUP BY day
      ORDER BY day DESC
    ''');
  }

  // ==================== Statistics ====================

  /// 今日学习统计：练习单词数、正确数
  Future<({int total, int correct})> getTodayStats() async {
    final db = await database;
    final start = DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0);
    final result = await db.rawQuery('''
      SELECT 
        COUNT(*) as total,
        SUM(CASE WHEN pd.is_correct = 1 THEN 1 ELSE 0 END) as correct
      FROM practice_detail pd
      JOIN practice_result pr ON pd.result_id = pr.id
      WHERE pr.created_at >= ?
    ''', [start.millisecondsSinceEpoch]);
    final map = result.first;
    return (
      total: map['total'] as int? ?? 0,
      correct: map['correct'] as int? ?? 0,
    );
  }

  /// 本周每日练习单词数（最近 7 天，包含今天）
  /// 返回 {日期字符串: 数量}
  Future<Map<String, int>> getWeeklyStats() async {
    final db = await database;
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 6));
    final startOfDay = DateTime(start.year, start.month, start.day);

    final result = await db.rawQuery('''
      SELECT 
        DATE(pr.created_at / 1000, 'unixepoch', 'localtime') as day,
        COUNT(*) as count
      FROM practice_detail pd
      JOIN practice_result pr ON pd.result_id = pr.id
      WHERE pr.created_at >= ?
      GROUP BY day
      ORDER BY day
    ''', [startOfDay.millisecondsSinceEpoch]);

    final stats = <String, int>{};
    for (var i = 0; i < 7; i++) {
      final d = startOfDay.add(Duration(days: i));
      final key = '${d.month}/${d.day}';
      stats[key] = 0;
    }

    for (final row in result) {
      final dayStr = row['day'] as String;
      final parts = dayStr.split('-');
      final key = '${int.parse(parts[1])}/${int.parse(parts[2])}';
      stats[key] = row['count'] as int;
    }

    return stats;
  }

  /// 本月总结
  Future<({
    int checkInDays,
    int practiceWords,
    int testWords,
    double accuracy,
  })> getMonthlyStats() async {
    final db = await database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);

    // 打卡天数
    final checkInResult = await db.rawQuery('''
      SELECT COUNT(DISTINCT DATE(created_at / 1000, 'unixepoch', 'localtime')) as days
      FROM practice_result
      WHERE created_at >= ?
    ''', [start.millisecondsSinceEpoch]);
    final checkInDays = checkInResult.first['days'] as int? ?? 0;

    // 练习单词数（所有练习）
    final practiceResult = await db.rawQuery('''
      SELECT COUNT(*) as count
      FROM practice_detail pd
      JOIN practice_result pr ON pd.result_id = pr.id
      WHERE pr.created_at >= ?
    ''', [start.millisecondsSinceEpoch]);
    final practiceWords = practiceResult.first['count'] as int? ?? 0;

    // 测试单词数（type = 'dictation' 视为测试）
    final testResult = await db.rawQuery('''
      SELECT COUNT(*) as count
      FROM practice_detail pd
      JOIN practice_result pr ON pd.result_id = pr.id
      WHERE pr.created_at >= ? AND pr.type = 'dictation'
    ''', [start.millisecondsSinceEpoch]);
    final testWords = testResult.first['count'] as int? ?? 0;

    // 正确率
    final accuracyResult = await db.rawQuery('''
      SELECT 
        COUNT(*) as total,
        SUM(CASE WHEN pd.is_correct = 1 THEN 1 ELSE 0 END) as correct
      FROM practice_detail pd
      JOIN practice_result pr ON pd.result_id = pr.id
      WHERE pr.created_at >= ?
    ''', [start.millisecondsSinceEpoch]);
    final total = accuracyResult.first['total'] as int? ?? 0;
    final correct = accuracyResult.first['correct'] as int? ?? 0;
    final accuracy = total == 0 ? 0.0 : correct / total;

    return (
      checkInDays: checkInDays,
      practiceWords: practiceWords,
      testWords: testWords,
      accuracy: accuracy,
    );
  }

  // ==================== Close ====================

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

}
