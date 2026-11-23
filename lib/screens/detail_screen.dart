import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../models/record.dart';
import 'edit_screen.dart';

class DetailScreen extends StatelessWidget {
  final int recordId;

  const DetailScreen({super.key, required this.recordId});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final record = appState.allRecords.where((r) => r.id == recordId).toList();

    if (record.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('详情')),
        body: const Center(child: Text('记录不存在或已删除')),
      );
    }

    final r = record.first;
    final scheme = Theme.of(context).colorScheme;
    final images = r.imageList.where((p) => File(p).existsSync()).toList();
    final tags = r.tagList;
    final categoryName =
        appState.categories.where((c) => c.id == r.categoryId).toList();

    final date = DateTime.fromMillisecondsSinceEpoch(r.createdAt);
    final dateStr =
        '${date.year}年${date.month}月${date.day}日 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EditScreen(record: r)),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context, r),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            r.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (categoryName.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    categoryName.first.name,
                    style: TextStyle(
                        fontSize: 13, color: scheme.onPrimaryContainer),
                  ),
                ),
              const SizedBox(width: 12),
              Text(
                dateStr,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 图片
          if (images.isNotEmpty) ...[
            for (final p in images)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(File(p), fit: BoxFit.contain),
                ),
              ),
            const SizedBox(height: 8),
          ],

          // 描述
          if (r.description.isNotEmpty) ...[
            Text(
              r.description,
              style: const TextStyle(fontSize: 15, height: 1.6),
            ),
            const SizedBox(height: 16),
          ],

          // 标签
          if (tags.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags
                  .map((t) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: scheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('#$t',
                            style: TextStyle(
                                fontSize: 13, color: scheme.onSurfaceVariant)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
          ],

          // 来源
          if (r.source.isNotEmpty)
            Text(
              '来源：${r.source}',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Record r) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除收藏'),
        content: Text('确定要删除「${r.title}」吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<AppState>().deleteRecord(r.id!);
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(
              '删除',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
