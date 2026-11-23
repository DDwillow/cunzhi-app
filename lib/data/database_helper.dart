import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/category.dart';
import '../models/record.dart';

/// 数据库管理：创建表、提供 CRUD 操作。
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'cunzhi.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE category (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        parentId INTEGER,
        sortOrder INTEGER DEFAULT 0,
        createdAt INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE record (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT DEFAULT '',
        categoryId INTEGER,
        tags TEXT DEFAULT '',
        imagePaths TEXT DEFAULT '',
        source TEXT DEFAULT '',
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_record_category ON record(categoryId)');
    await db.execute('CREATE INDEX idx_record_title ON record(title)');
  }

  // ===== 分类 =====
  Future<List<Category>> getAllCategories() async {
    final db = await database;
    final maps = await db.query('category', orderBy: 'sortOrder ASC, id ASC');
    return maps.map(Category.fromMap).toList();
  }

  Future<int> insertCategory(Category c) async {
    final db = await database;
    return db.insert('category', c.toMap());
  }

  Future<void> updateCategory(Category c) async {
    final db = await database;
    await db.update('category', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
  }

  Future<void> deleteCategory(int id) async {
    final db = await database;
    await db.delete('category', where: 'id = ?', whereArgs: [id]);
  }

  // ===== 记录 =====
  Future<List<Record>> getAllRecords() async {
    final db = await database;
    final maps = await db.query('record', orderBy: 'updatedAt DESC');
    return maps.map(Record.fromMap).toList();
  }

  Future<List<Record>> getRecordsByCategory(int categoryId) async {
    final db = await database;
    final maps = await db.query(
      'record',
      where: 'categoryId = ?',
      whereArgs: [categoryId],
      orderBy: 'updatedAt DESC',
    );
    return maps.map(Record.fromMap).toList();
  }

  Future<List<Record>> searchRecords(String query) async {
    final db = await database;
    final like = '%$query%';
    final maps = await db.query(
      'record',
      where:
          'title LIKE ? OR description LIKE ? OR tags LIKE ? OR source LIKE ?',
      whereArgs: [like, like, like, like],
      orderBy: 'updatedAt DESC',
    );
    return maps.map(Record.fromMap).toList();
  }

  Future<Record?> getRecord(int id) async {
    final db = await database;
    final maps = await db.query('record', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Record.fromMap(maps.first);
  }

  Future<int> insertRecord(Record r) async {
    final db = await database;
    return db.insert('record', r.toMap());
  }

  Future<void> updateRecord(Record r) async {
    final db = await database;
    await db.update('record', r.toMap(), where: 'id = ?', whereArgs: [r.id]);
  }

  Future<void> deleteRecord(int id) async {
    final db = await database;
    await db.delete('record', where: 'id = ?', whereArgs: [id]);
  }
}
