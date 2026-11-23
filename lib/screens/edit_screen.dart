import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../models/category.dart';
import '../models/record.dart';
import '../services/ai_service.dart';
import '../services/image_storage.dart';

/// 新建 / 编辑记录页。
class EditScreen extends StatefulWidget {
  final Record? record;

  const EditScreen({super.key, this.record});

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  final _picker = ImagePicker();

  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _tagsCtrl;
  late TextEditingController _sourceCtrl;
  int? _categoryId;
  List<String> _imagePaths = [];
  bool _saving = false;
  bool _aiWorking = false;

  bool get _isEdit => widget.record != null;

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    _titleCtrl = TextEditingController(text: r?.title ?? '');
    _descCtrl = TextEditingController(text: r?.description ?? '');
    _tagsCtrl = TextEditingController(text: r?.tagList.join(',') ?? '');
    _sourceCtrl = TextEditingController(text: r?.source ?? '');
    _categoryId = r?.categoryId;
    _imagePaths = List.from(r?.imageList ?? []);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _tagsCtrl.dispose();
    _sourceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final files = await _picker.pickMultiImage(imageQuality: 85);
    if (files.isEmpty) return;
    for (final f in files) {
      if (_imagePaths.length >= 9) break;
      final path = await ImageStorage.saveImageFile(File(f.path));
      setState(() => _imagePaths.add(path));
    }
  }

  Future<void> _takePhoto() async {
    final f = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (f == null) return;
    final path = await ImageStorage.saveImageFile(File(f.path));
    setState(() => _imagePaths.add(path));
  }

  /// AI 自动整理：上传图片时走「视觉模型看图 → DeepSeek 精修」，
  /// 只填文字时直接 DeepSeek 整理。生成标题、正文、分类、标签，并自动匹配/新建分类。
  Future<void> _aiOrganize() async {
    // 收集用户已输入的文字作为 AI 的补充输入
    final userText = [
      _titleCtrl.text.trim(),
      _descCtrl.text.trim(),
      _sourceCtrl.text.trim(),
    ].where((s) => s.isNotEmpty).join('\n');

    if (userText.isEmpty && _imagePaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先上传照片，或填写一些描述文字')),
      );
      return;
    }

    setState(() => _aiWorking = true);
    final appState = context.read<AppState>();

    try {
      final result = await AiService.organizeAuto(
        imagePaths: _imagePaths,
        userText: userText,
        categories: appState.getCategoryNames(),
      );

      // 填充标题、描述、标签、来源
      if (result['title']!.isNotEmpty) _titleCtrl.text = result['title']!;
      if (result['description']!.isNotEmpty) {
        _descCtrl.text = result['description']!;
      }
      if (result['tags']!.isNotEmpty) _tagsCtrl.text = result['tags']!;
      if (result['source']!.isNotEmpty) _sourceCtrl.text = result['source']!;

      // 匹配或新建分类
      final categoryName = result['category'] ?? '';
      if (categoryName.isNotEmpty) {
        final id = await appState.resolveCategoryId(categoryName);
        if (id != null) {
          setState(() => _categoryId = id);
        }
      }

      if (mounted) {
        setState(() => _aiWorking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI 已自动整理完成，可手动微调后保存')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _aiWorking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI 整理失败：${e.toString().replaceFirst('Exception: ', '')}')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写标题')),
      );
      return;
    }
    setState(() => _saving = true);
    final tags = _tagsCtrl.text
        .split(RegExp(r'[,，\s]'))
        .where((s) => s.isNotEmpty)
        .join(',');

    final record = Record(
      id: widget.record?.id,
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      categoryId: _categoryId,
      tags: tags,
      imagePaths: _imagePaths.join(','),
      source: _sourceCtrl.text.trim(),
      createdAt: widget.record?.createdAt,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    await context.read<AppState>().saveRecord(record);
    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? '编辑收藏' : '新建收藏'),
        actions: [
          IconButton(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // AI 自动整理按钮
          _AiOrganizeButton(
            working: _aiWorking,
            onTap: _aiWorking ? null : _aiOrganize,
          ),
          const SizedBox(height: 16),

          // 图片区
          _ImageSection(
            imagePaths: _imagePaths,
            onPick: _pickImages,
            onTakePhoto: _takePhoto,
            onRemove: (p) => setState(() => _imagePaths.remove(p)),
          ),
          const SizedBox(height: 20),

          // 标题
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: '标题 *',
              hintText: '一句话概括这条干货',
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),

          // 描述
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(
              labelText: '描述 / 正文',
              hintText: '记录具体方法、地址、心得等',
              alignLabelWithHint: true,
            ),
            maxLines: 6,
            minLines: 3,
          ),
          const SizedBox(height: 12),

          // 分类选择
          _CategorySelector(
            categories: appState.categories,
            selectedId: _categoryId,
            onChanged: (id) => setState(() => _categoryId = id),
          ),
          const SizedBox(height: 12),

          // 标签
          TextField(
            controller: _tagsCtrl,
            decoration: const InputDecoration(
              labelText: '标签',
              hintText: '用逗号或空格分隔，如：除水垢,厨房',
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),

          // 来源
          TextField(
            controller: _sourceCtrl,
            decoration: const InputDecoration(
              labelText: '来源（可选）',
              hintText: '来自哪里看到的？如：某公众号、某朋友',
            ),
          ),
        ],
      ),
    );
  }
}

/// AI 自动整理按钮
class _AiOrganizeButton extends StatelessWidget {
  final bool working;
  final VoidCallback? onTap;

  const _AiOrganizeButton({required this.working, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              working
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.auto_awesome, color: scheme.onSecondaryContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  working ? 'AI 正在整理…' : 'AI 自动整理（生成标题、正文、分类、标签）',
                  style: TextStyle(
                    color: scheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 图片选择区
class _ImageSection extends StatelessWidget {
  final List<String> imagePaths;
  final VoidCallback onPick;
  final VoidCallback onTakePhoto;
  final void Function(String) onRemove;

  const _ImageSection({
    required this.imagePaths,
    required this.onPick,
    required this.onTakePhoto,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('图片（${imagePaths.length}/9）',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final p in imagePaths)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(p),
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => onRemove(p),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.close,
                                size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (imagePaths.length < 9) ...[
                _AddButton(
                  icon: Icons.photo_library_outlined,
                  label: '选图',
                  onTap: onPick,
                ),
                const SizedBox(width: 8),
                _AddButton(
                  icon: Icons.camera_alt_outlined,
                  label: '拍照',
                  onTap: onTakePhoto,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AddButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          color: scheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(fontSize: 12, color: scheme.primary)),
          ],
        ),
      ),
    );
  }
}

/// 分类选择器：点击弹出树状分类列表（支持选任意层级的子分类）。
class _CategorySelector extends StatelessWidget {
  final List<Category> categories;
  final int? selectedId;
  final void Function(int?) onChanged;

  const _CategorySelector({
    required this.categories,
    required this.selectedId,
    required this.onChanged,
  });

  String get _selectedName {
    if (selectedId == null) return '';
    final cat = categories.where((c) => c.id == selectedId).toList();
    return cat.isEmpty ? '' : cat.first.name;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('分类', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _showCategoryPicker(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: scheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedId == null ? '未选择分类' : _selectedName,
                    style: TextStyle(
                      color: selectedId == null
                          ? scheme.onSurfaceVariant
                          : scheme.onSurface,
                    ),
                  ),
                ),
                if (selectedId != null)
                  GestureDetector(
                    onTap: () => onChanged(null),
                    child: Icon(Icons.close, size: 18, color: scheme.onSurfaceVariant),
                  )
                else
                  Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showCategoryPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return _CategoryPickerSheet(
          categories: categories,
          selectedId: selectedId,
          onSelect: (id) {
            onChanged(id);
            Navigator.pop(ctx);
          },
        );
      },
    );
  }
}

/// 底部弹出的分类树选择器
class _CategoryPickerSheet extends StatelessWidget {
  final List<Category> categories;
  final int? selectedId;
  final void Function(int?) onSelect;

  const _CategoryPickerSheet({
    required this.categories,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final topLevel = categories.where((c) => c.parentId == null).toList();
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          ListTile(
            leading: const Icon(Icons.label_off_outlined),
            title: const Text('未分类'),
            trailing: selectedId == null
                ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                : null,
            onTap: () => onSelect(null),
          ),
          const Divider(),
          for (final cat in topLevel)
            _buildCategoryNode(context, cat, 0),
        ],
      ),
    );
  }

  Widget _buildCategoryNode(BuildContext context, Category cat, int depth) {
    final children = categories.where((c) => c.parentId == cat.id).toList();
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.only(left: 16.0 + depth * 20.0, right: 16),
          leading: Icon(Icons.folder_outlined, color: scheme.primary),
          title: Text(cat.name),
          trailing: selectedId == cat.id
              ? Icon(Icons.check, color: scheme.primary)
              : null,
          onTap: () => onSelect(cat.id),
        ),
        for (final child in children) _buildCategoryNode(context, child, depth + 1),
      ],
    );
  }
}
