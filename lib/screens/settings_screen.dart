import 'package:flutter/material.dart';

import '../services/ai_service.dart';

/// 设置页：AI 接口配置。
///
/// 识图方式二选一：
/// 1. 视觉模型（智谱 GLM-4V）——看图效果最好，需 key。
/// 2. 本地 OCR（ML Kit）——免费离线，复杂表格效果弱。
/// 无论哪种，拿到的文字都交给 DeepSeek 精修。
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _visionKeyCtrl;
  late TextEditingController _visionUrlCtrl;
  late TextEditingController _visionModelCtrl;
  late TextEditingController _deepseekKeyCtrl;
  late TextEditingController _deepseekUrlCtrl;
  ImageMode _imageMode = ImageMode.vision;

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _visionKeyCtrl = TextEditingController();
    _visionUrlCtrl = TextEditingController();
    _visionModelCtrl = TextEditingController();
    _deepseekKeyCtrl = TextEditingController();
    _deepseekUrlCtrl = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    _visionKeyCtrl.text = await AiService.getVisionKey();
    _visionUrlCtrl.text = await AiService.getVisionUrl();
    _visionModelCtrl.text = await AiService.getVisionModel();
    _deepseekKeyCtrl.text = await AiService.getDeepseekKey();
    _deepseekUrlCtrl.text = await AiService.getDeepseekUrl();
    _imageMode = await AiService.getImageMode();
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _visionKeyCtrl.dispose();
    _visionUrlCtrl.dispose();
    _visionModelCtrl.dispose();
    _deepseekKeyCtrl.dispose();
    _deepseekUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await AiService.saveConfig(
      visionKey: _visionKeyCtrl.text,
      visionUrl: _visionUrlCtrl.text,
      visionModel: _visionModelCtrl.text,
      deepseekKey: _deepseekKeyCtrl.text,
      deepseekUrl: _deepseekUrlCtrl.text,
      imageMode: _imageMode,
    );
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI 设置已保存')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 设置'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 说明
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.auto_awesome, color: scheme.onPrimaryContainer),
                          const SizedBox(width: 8),
                          Text('AI 自动整理',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onPrimaryContainer)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '上传图片时：先按下方「识图方式」提取图片文字，再交给 DeepSeek 精修成标题、正文、分类、标签。只填文字不传图时，直接用 DeepSeek 整理。',
                        style: TextStyle(
                            fontSize: 13,
                            color: scheme.onPrimaryContainer,
                            height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 识图方式
                _SectionTitle('识图方式'),
                const SizedBox(height: 8),
                _ImageModeSelector(
                  mode: _imageMode,
                  onChanged: (m) => setState(() => _imageMode = m),
                ),
                const SizedBox(height: 24),

                // 视觉模型配置
                _SectionTitle('视觉模型（识图方式选「视觉模型」时用）'),
                const SizedBox(height: 8),
                TextField(
                  controller: _visionKeyCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'API Key',
                    hintText: '智谱开放平台的 API Key',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _visionUrlCtrl,
                  decoration: const InputDecoration(
                    labelText: '接口地址',
                    hintText: AiService.visionDefaultUrl,
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _visionModelCtrl,
                  decoration: const InputDecoration(
                    labelText: '模型名',
                    hintText: AiService.visionDefaultModel,
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '默认对接智谱 GLM-4V-Flash（国产、便宜、中文图片理解好）。去 bigmodel.cn 注册并创建 API Key。',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, height: 1.5),
                ),
                const SizedBox(height: 28),

                // DeepSeek 配置
                _SectionTitle('文字整理（DeepSeek）'),
                const SizedBox(height: 8),
                TextField(
                  controller: _deepseekKeyCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'API Key',
                    hintText: 'sk-...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _deepseekUrlCtrl,
                  decoration: const InputDecoration(
                    labelText: '接口地址',
                    hintText: AiService.deepseekDefaultUrl,
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '用于「精修文案」和「纯文字整理」。识图方式无论选视觉模型还是 OCR，最终都交给 DeepSeek 整理成结构化字段。',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, height: 1.5),
                ),
              ],
            ),
    );
  }
}

/// 识图方式选择器
class _ImageModeSelector extends StatelessWidget {
  final ImageMode mode;
  final void Function(ImageMode) onChanged;

  const _ImageModeSelector({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        _ModeTile(
          selected: mode == ImageMode.vision,
          title: '视觉模型识图',
          subtitle: '看图效果最好，适合表格/复杂排版，需配置上面的 API Key',
          onTap: () => onChanged(ImageMode.vision),
        ),
        const SizedBox(height: 8),
        _ModeTile(
          selected: mode == ImageMode.ocr,
          title: '本地 OCR 识图',
          subtitle: '免费、离线，适合规整文字；复杂表格效果较弱',
          onTap: () => onChanged(ImageMode.ocr),
        ),
      ],
    );
  }
}

class _ModeTile extends StatelessWidget {
  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ModeTile({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : scheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: selected ? scheme.onPrimaryContainer : scheme.onSurface)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12,
                          color: selected
                              ? scheme.onPrimaryContainer.withOpacity(0.8)
                              : scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      ],
    );
  }
}
