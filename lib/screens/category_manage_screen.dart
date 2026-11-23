import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../models/category.dart';

/// 分类管理页：支持无限层级，可新建、重命名、删除分类。
class CategoryManageScreen extends StatelessWidget {
  const CategoryManageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('分类管理'),
      ),
      body: appState.categories.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.folder_open_outlined, size: 64),
                  const SizedBox(height: 12),
                  const Text('还没有分类，点右下角新建'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _showAddDialog(context, appState, null),
                    icon: const Icon(Icons.add),
                    label: const Text('新建分类'),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: _buildTree(context, appState, null, 0),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, appState, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  List<Widget> _buildTree(
    BuildContext context,
    AppState appState,
    int? parentId,
    int depth,
  ) {
    final children = appState.getChildren(parentId);
    final widgets = <Widget>[];

    for (final cat in children) {
      widgets.add(
        Padding(
          padding: EdgeInsets.only(left: depth * 20.0),
          child: ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: Text(cat.name),
            trailing: PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'add') {
                  _showAddDialog(context, appState, cat.id);
                } else if (v == 'rename') {
                  _showRenameDialog(context, appState, cat);
                } else if (v == 'delete') {
                  _confirmDelete(context, appState, cat);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'add', child: Text('新建子分类')),
                const PopupMenuItem(value: 'rename', child: Text('重命名')),
                const PopupMenuItem(value: 'delete', child: Text('删除')),
              ],
            ),
          ),
        ),
      );
      widgets.addAll(_buildTree(context, appState, cat.id, depth + 1));
    }
    return widgets;
  }

  void _showAddDialog(
      BuildContext context, AppState appState, int? parentId) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(parentId == null ? '新建分类' : '新建子分类'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '分类名称'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              appState.addCategory(name, parentId: parentId);
              Navigator.pop(ctx);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(
      BuildContext context, AppState appState, Category cat) {
    final ctrl = TextEditingController(text: cat.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名分类'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '分类名称'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              appState.renameCategory(cat.id!, name);
              Navigator.pop(ctx);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, AppState appState, Category cat) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除分类'),
        content: Text(
            '确定要删除「${cat.name}」吗？\n该分类下的子分类和所有记录都会被删除。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              appState.deleteCategory(cat.id!);
              Navigator.pop(ctx);
            },
            child: Text('删除',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }
}
