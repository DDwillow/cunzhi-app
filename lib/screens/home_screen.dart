import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../models/category.dart';
import '../models/record.dart';
import 'category_manage_screen.dart';
import 'detail_screen.dart';
import 'edit_screen.dart';
import 'settings_screen.dart';

/// 主页面：底部两个 Tab ——「全部」（文档列表式）+「分类」（大类浏览）。
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;
  bool _searching = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '搜索标题、描述、标签…',
                  border: InputBorder.none,
                  isDense: true,
                ),
                onChanged: (v) => context.read<AppState>().search(v),
              )
            : Text(_tabIndex == 0 ? '全部' : '分类'),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _searching = !_searching;
                if (!_searching) {
                  context.read<AppState>().search('');
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.folder_outlined),
            tooltip: '分类管理',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CategoryManageScreen(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '设置',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SettingsScreen(),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          _AllListScreen(searching: _searching),
          const _CategoryScreen(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EditScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) {
          setState(() => _tabIndex = i);
          // 切换 Tab 时清空搜索和分类选中状态
          context.read<AppState>().search('');
          context.read<AppState>().selectCategory(null);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: '全部',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: '分类',
          ),
        ],
      ),
    );
  }
}

/// Tab 1：全部条目，文档列表式，支持按时间/首字母排序。
class _AllListScreen extends StatelessWidget {
  final bool searching;

  const _AllListScreen({required this.searching});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final records = appState.filteredRecords;

    return Column(
      children: [
        // 排序切换栏
        _SortBar(
          sortMode: appState.sortMode,
          onChanged: (m) => appState.setSortMode(m),
        ),
        const Divider(height: 1),
        Expanded(
          child: appState.loading
              ? const Center(child: CircularProgressIndicator())
              : records.isEmpty
                  ? _EmptyState(searching: searching)
                  : ListView.separated(
                      itemCount: records.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 16, endIndent: 16),
                      itemBuilder: (context, index) {
                        final r = records[index];
                        return _RecordListItem(
                          record: r,
                          categoryName: _categoryName(appState, r),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DetailScreen(recordId: r.id!),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  String? _categoryName(AppState appState, Record r) {
    if (r.categoryId == null) return null;
    final cat = appState.categories.where((c) => c.id == r.categoryId).toList();
    return cat.isEmpty ? null : cat.first.name;
  }
}

/// 排序切换栏
class _SortBar extends StatelessWidget {
  final SortMode sortMode;
  final void Function(SortMode) onChanged;

  const _SortBar({required this.sortMode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text('排序',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          const Spacer(),
          _SortChip(
            label: '时间',
            selected: sortMode == SortMode.timeDesc,
            onTap: () => onChanged(SortMode.timeDesc),
          ),
          const SizedBox(width: 8),
          _SortChip(
            label: '首字母',
            selected: sortMode == SortMode.title,
            onTap: () => onChanged(SortMode.title),
          ),
        ],
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : scheme.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? scheme.onPrimary : scheme.onSurface,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

/// 文档列表式条目（标题为主，缩略图 + 分类 + 标签 + 时间）
class _RecordListItem extends StatelessWidget {
  final Record record;
  final String? categoryName;
  final VoidCallback onTap;

  const _RecordListItem({
    required this.record,
    required this.categoryName,
    required this.onTap,
  });

  Widget _fallbackIcon(ColorScheme scheme) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: scheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.description_outlined,
          color: scheme.onSurfaceVariant),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final images = record.imageList;
    final hasImage = images.isNotEmpty;

    final date = DateTime.fromMillisecondsSinceEpoch(record.updatedAt);
    final dateStr =
        '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 缩略图（cacheWidth 缩小解码，减少内存和卡顿）
            if (hasImage)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(images.first),
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  cacheWidth: 168, // 3x 像素密度，够清晰且省内存
                  errorBuilder: (_, __, ___) => _fallbackIcon(scheme),
                ),
              )
            else
              _fallbackIcon(scheme),
            const SizedBox(width: 12),
            // 内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (record.description.isNotEmpty)
                    Text(
                      record.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 6),
                  // 分类 + 标签 + 时间
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (categoryName != null)
                        _MetaTag(
                          text: categoryName!,
                          color: scheme.primaryContainer,
                          textColor: scheme.onPrimaryContainer,
                        ),
                      ...record.tagList.take(2).map((t) => _MetaTag(
                            text: '#$t',
                            color: scheme.surfaceVariant,
                            textColor: scheme.onSurfaceVariant,
                          )),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.outline,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaTag extends StatelessWidget {
  final String text;
  final Color color;
  final Color textColor;

  const _MetaTag({
    required this.text,
    required this.color,
    required this.textColor,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: textColor),
      ),
    );
  }
}

/// Tab 2：分类浏览（大类列表，点开看内容）
class _CategoryScreen extends StatelessWidget {
  const _CategoryScreen();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final topLevel = appState.categories.where((c) => c.parentId == null).toList();

    if (topLevel.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open_outlined,
                size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            const Text('还没有分类\n点右上角文件夹图标新建分类',
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.5)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: topLevel.length,
      itemBuilder: (context, index) {
        final cat = topLevel[index];
        final totalCount = appState.getRecordsInCategory(cat.id!).length;
        final directCount = appState.getDirectRecordCount(cat.id!);
        final subCount = appState.getSubCategories(cat.id!).length;
        return _CategoryTile(
          category: cat,
          totalCount: totalCount,
          subCount: subCount,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CategoryContentScreen(category: cat),
            ),
          ),
        );
      },
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final Category category;
  final int totalCount;
  final int subCount;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.category,
    required this.totalCount,
    required this.subCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.folder, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$totalCount 条内容'
                      '${subCount > 0 ? ' · $subCount 个子分类' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool searching;

  const _EmptyState({required this.searching});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = searching
        ? '没有找到相关记录'
        : '还没有任何收藏\n点右下角 + 开始记录你的第一条干货';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: scheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// 分类内容页：展示该分类的子分类 + 该分类（含后代）下的记录列表。
class CategoryContentScreen extends StatelessWidget {
  final Category category;

  const CategoryContentScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final subCategories = appState.getSubCategories(category.id!);
    final records = appState.getRecordsInCategory(category.id!);

    return Scaffold(
      appBar: AppBar(title: Text(category.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 子分类区
          if (subCategories.isNotEmpty) ...[
            const Text('子分类',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            for (final sub in subCategories)
              _SubCategoryTile(
                category: sub,
                count: appState.getRecordsInCategory(sub.id!).length,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CategoryContentScreen(category: sub),
                  ),
                ),
              ),
            const SizedBox(height: 20),
          ],

          // 记录区
          Text('内容（${records.length}）',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 8),
          if (records.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('这个分类下还没有内容',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ),
            )
          else
            for (final r in records)
              _RecordListItem(
                record: r,
                categoryName: null,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DetailScreen(recordId: r.id!),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _SubCategoryTile extends StatelessWidget {
  final Category category;
  final int count;
  final VoidCallback onTap;

  const _SubCategoryTile({
    required this.category,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.folder_outlined,
                  size: 20, color: scheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  category.name,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              Text('$count',
                  style: TextStyle(
                      fontSize: 13, color: scheme.onSurfaceVariant)),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right,
                  size: 18, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
