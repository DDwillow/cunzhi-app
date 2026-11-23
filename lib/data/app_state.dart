import 'package:flutter/foundation.dart' hide Category;

import '../data/database_helper.dart';
import '../models/category.dart';
import '../models/record.dart';
import '../services/image_storage.dart';

/// 排序方式
enum SortMode { timeDesc, title }

/// 应用状态：分类、记录、搜索、当前选中分类。
class AppState extends ChangeNotifier {
  List<Category> _categories = [];
  List<Record> _records = [];
  List<Record> _filteredRecords = [];
  Category? _currentCategory;
  String _searchQuery = '';
  SortMode _sortMode = SortMode.timeDesc;
  bool _loading = true;

  List<Category> get categories => _categories;
  List<Record> get allRecords => _records;
  List<Record> get filteredRecords => _filteredRecords;
  Category? get currentCategory => _currentCategory;
  String get searchQuery => _searchQuery;
  SortMode get sortMode => _sortMode;
  bool get loading => _loading;

  Future<void> load() async {
    _loading = true;
    try {
      // 分类和记录并发加载，减少启动等待
      final categoriesFuture = DatabaseHelper.instance.getAllCategories();
      final recordsFuture = DatabaseHelper.instance.getAllRecords();
      _categories = await categoriesFuture;
      _records = await recordsFuture;
      _applyFilter();
    } catch (e) {
      // 加载失败也不至于卡死在转圈，保证 UI 可用
      _categories = [];
      _records = [];
      _filteredRecords = [];
      debugPrint('AppState.load 失败: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshCategories() async {
    _categories = await DatabaseHelper.instance.getAllCategories();
    notifyListeners();
  }

  Future<void> refreshRecords() async {
    _records = await DatabaseHelper.instance.getAllRecords();
    _applyFilter();
    notifyListeners();
  }

  void _applyFilter() {
    if (_searchQuery.isNotEmpty) {
      _filteredRecords = _records
          .where((r) =>
              r.title.contains(_searchQuery) ||
              r.description.contains(_searchQuery) ||
              r.tags.contains(_searchQuery) ||
              r.source.contains(_searchQuery))
          .toList();
    } else if (_currentCategory != null) {
      _filteredRecords = getRecordsInCategory(_currentCategory!.id!);
    } else {
      _filteredRecords = List.from(_records);
    }
    _sortRecords();
  }

  void _sortRecords() {
    if (_sortMode == SortMode.title) {
      _filteredRecords.sort((a, b) =>
          a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    } else {
      _filteredRecords.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
  }

  void setSortMode(SortMode mode) {
    _sortMode = mode;
    _sortRecords();
    notifyListeners();
  }

  /// 获取某个分类（含其所有子分类）下的记录。
  List<Record> getRecordsInCategory(int categoryId) {
    final ids = _collectCategoryIds(categoryId);
    return _records.where((r) => r.categoryId != null && ids.contains(r.categoryId)).toList();
  }

  /// 收集某个分类及其所有后代分类的 id。
  Set<int> _collectCategoryIds(int categoryId) {
    final ids = <int>{categoryId};
    final children = _categories.where((c) => c.parentId == categoryId).toList();
    for (final child in children) {
      ids.addAll(_collectCategoryIds(child.id!));
    }
    return ids;
  }

  /// 获取某分类下的直接子分类。
  List<Category> getSubCategories(int categoryId) {
    return _categories.where((c) => c.parentId == categoryId).toList();
  }

  /// 获取某分类下直接归类的记录（不含子分类的记录）。
  List<Record> getDirectRecords(int categoryId) {
    return _records.where((r) => r.categoryId == categoryId).toList();
  }

  /// 获取某分类下直接归类的记录数（不含子分类）。
  int getDirectRecordCount(int categoryId) {
    return _records.where((r) => r.categoryId == categoryId).length;
  }

  void selectCategory(Category? category) {
    _currentCategory = category;
    _searchQuery = '';
    _applyFilter();
    notifyListeners();
  }

  void search(String query) {
    _searchQuery = query;
    _applyFilter();
    notifyListeners();
  }

  // ===== 分类操作 =====
  Future<int> addCategory(String name, {int? parentId}) async {
    final id = await DatabaseHelper.instance
        .insertCategory(Category(name: name, parentId: parentId));
    await refreshCategories();
    return id;
  }

  Future<void> renameCategory(int id, String newName) async {
    final cats = _categories;
    final target = cats.firstWhere((c) => c.id == id);
    await DatabaseHelper.instance
        .updateCategory(target.copyWith(name: newName));
    await refreshCategories();
  }

  Future<void> deleteCategory(int id) async {
    // 递归删除子分类及其下记录
    final children =
        _categories.where((c) => c.parentId == id).map((c) => c.id!).toList();
    for (final childId in children) {
      await deleteCategory(childId);
    }
    final recordsInCat = _records.where((r) => r.categoryId == id).toList();
    for (final r in recordsInCat) {
      await ImageStorage.deleteMany(r.imageList);
      await DatabaseHelper.instance.deleteRecord(r.id!);
    }
    await DatabaseHelper.instance.deleteCategory(id);
    await refreshCategories();
    await refreshRecords();
  }

  // ===== 记录操作 =====
  Future<int> saveRecord(Record r) async {
    int id;
    if (r.id == null) {
      id = await DatabaseHelper.instance.insertRecord(r);
    } else {
      await DatabaseHelper.instance.updateRecord(r);
      id = r.id!;
    }
    await refreshRecords();
    return id;
  }

  Future<void> deleteRecord(int id) async {
    final r = _records.firstWhere((rec) => rec.id == id);
    await ImageStorage.deleteMany(r.imageList);
    await DatabaseHelper.instance.deleteRecord(id);
    await refreshRecords();
  }

  // 分类树辅助
  List<Category> getChildren(int? parentId) {
    return _categories.where((c) => c.parentId == parentId).toList();
  }

  /// 获取所有分类的完整路径名（用「父/子」表示层级），供 AI 参考。
  List<String> getCategoryNames() {
    return _categories.map((c) => categoryFullPath(c)).toList();
  }

  /// 根据 AI 返回的分类名（可能含「/」层级）匹配已有分类；匹配不到则自动新建。
  ///
  /// 返回最终归入的分类 id（新建则返回新分类 id）。
  Future<int?> resolveCategoryId(String categoryName) async {
    final name = categoryName.trim();
    if (name.isEmpty) return null;

    // 1. 先精确匹配完整路径名
    for (final c in _categories) {
      if (categoryFullPath(c) == name) return c.id;
    }

    // 2. 再按最后一个层级名做模糊匹配（如 AI 返回「火锅」，已有「美食/火锅」）
    final lastName = name.split('/').last.trim();
    if (lastName.isNotEmpty) {
      for (final c in _categories) {
        if (c.name == lastName) return c.id;
      }
    }

    // 3. 没有匹配到，按「/」拆成层级，自动创建分类
    final parts = name.split('/').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    int? parentId;
    int? lastId;
    for (final part in parts) {
      // 先在该层下找同名子分类
      Category? existing;
      for (final c in _categories) {
        if (c.name == part && c.parentId == parentId) {
          existing = c;
          break;
        }
      }
      if (existing != null) {
        parentId = existing.id;
        lastId = existing.id;
      } else {
        final id = await addCategory(part, parentId: parentId);
        parentId = id;
        lastId = id;
      }
    }
    return lastId;
  }

  /// 获取某个分类的完整路径名（用于显示）
  String categoryFullPath(Category? cat) {
    if (cat == null) return '';
    final parts = <String>[];
    Category? cur = cat;
    final visited = <int>{};
    while (cur != null && cur.id != null && !visited.contains(cur.id)) {
      visited.add(cur.id!);
      parts.insert(0, cur.name);
      if (cur.parentId == null) break;
      Category? next;
      for (final c in _categories) {
        if (c.id == cur.parentId) {
          next = c;
          break;
        }
      }
      cur = next;
    }
    return parts.join(' / ');
  }
}
