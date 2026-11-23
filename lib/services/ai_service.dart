import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'ocr_service.dart';

/// AI 服务：图片理解 + 文字整理。
///
/// 识图方式有两种（可在设置页切换）：
/// 1. [ImageMode.vision] —— 视觉模型（默认智谱 GLM-4V-Flash），看图效果最好，需 key。
/// 2. [ImageMode.ocr] —— 本地 OCR（ML Kit），免费离线，但复杂表格效果弱。
///
/// 无论哪种识图方式，拿到的文字都会交给 DeepSeek 精修成结构化字段。
enum ImageMode { vision, ocr }

class AiService {
  // ===== 配置项 =====
  static const _keyDeepseekKey = 'ai_deepseek_key';
  static const _keyDeepseekUrl = 'ai_deepseek_url';
  static const _keyVisionKey = 'ai_vision_key';
  static const _keyVisionUrl = 'ai_vision_url';
  static const _keyVisionModel = 'ai_vision_model';
  static const _keyImageMode = 'ai_image_mode';

  static const deepseekDefaultUrl = 'https://api.deepseek.com';
  static const visionDefaultUrl = 'https://open.bigmodel.cn/api/paas/v4';
  static const visionDefaultModel = 'glm-4v-flash';

  /// DeepSeek Key。
  static Future<String> getDeepseekKey() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_keyDeepseekKey) ?? '';
  }

  static Future<String> getDeepseekUrl() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_keyDeepseekUrl) ?? deepseekDefaultUrl;
  }

  /// 视觉模型 Key。
  static Future<String> getVisionKey() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_keyVisionKey) ?? '';
  }

  static Future<String> getVisionUrl() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_keyVisionUrl) ?? visionDefaultUrl;
  }

  static Future<String> getVisionModel() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_keyVisionModel) ?? visionDefaultModel;
  }

  /// 识图方式（默认视觉模型）。
  static Future<ImageMode> getImageMode() async {
    final sp = await SharedPreferences.getInstance();
    final v = sp.getString(_keyImageMode);
    return v == 'ocr' ? ImageMode.ocr : ImageMode.vision;
  }

  static Future<void> saveConfig({
    required String deepseekKey,
    required String deepseekUrl,
    required String visionKey,
    required String visionUrl,
    required String visionModel,
    required ImageMode imageMode,
  }) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_keyDeepseekKey, deepseekKey.trim());
    await sp.setString(
        _keyDeepseekUrl, deepseekUrl.trim().isEmpty ? deepseekDefaultUrl : deepseekUrl.trim());
    await sp.setString(_keyVisionKey, visionKey.trim());
    await sp.setString(
        _keyVisionUrl, visionUrl.trim().isEmpty ? visionDefaultUrl : visionUrl.trim());
    await sp.setString(
        _keyVisionModel, visionModel.trim().isEmpty ? visionDefaultModel : visionModel.trim());
    await sp.setString(_keyImageMode, imageMode == ImageMode.ocr ? 'ocr' : 'vision');
  }

  /// 统一的系统提示词模板。
  static String _buildSystemPrompt(List<String> categories) {
    final catList = categories.isEmpty ? '（暂无分类）' : categories.join('、');
    return '''
你是一个生活干货整理助手。用户会把一张图片或一段文字交给你（图片里通常是生活信息：小妙招、美食店、景点、农村大集时间表、各种应对方法、优惠活动等），请你把它整理成一条结构化的收藏记录。

要求：
1. 用 JSON 格式输出，只输出 JSON，不要输出任何其他文字或解释。
2. 字段说明：
   - title：一句话标题，简洁准确。要能概括这条信息的核心内容（例如一张「王哥庄大集逢一逢六」的时间表，标题应为「王哥庄大集时间」之类）。10 字左右最佳，不超过 20 字。
   - description：正文，把图片/文字里的**关键信息完整、准确**地总结出来。如果是时间表/列表类，要逐条列清楚（如「农历逢一、逢六：王哥庄大集」「农历逢二、逢七：王戈庄大集」）；如果是方法步骤，写清步骤；如果是地址/店名，写清地址和推荐理由。不要遗漏重要信息，但也不要有废话，300 字以内。
   - category：归入的分类名。必须优先从下面「已有分类」列表里挑选最合适的一个（可含层级，如「美食/火锅」表示子分类）；如果没有合适的，就自己取一个简短的新分类名（2~6 字）。
   - tags：2~4 个标签，用中文逗号分隔，每个 2~4 字。
   - source：来源（如果用户提到了来源就填，否则填空字符串）。
3. 分类务必贴合「生活干货」场景（美食、景点、居家妙招、健康、购物、出行、集市等）。

已有分类：$catList

输出格式示例：
{"title":"白醋除水垢","description":"水壶加水和白醋 1:1，煮沸后静置 30 分钟，再用清水冲洗即可。","category":"居家妙招","tags":"厨房,清洁,水垢","source":""}
''';
  }

  /// 解析模型返回的 content 里的 JSON。
  static Map<String, String> _parseContent(String content) {
    final jsonStr = _extractJson(content);
    final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
    return {
      'title': (parsed['title'] ?? '').toString().trim(),
      'description': (parsed['description'] ?? '').toString().trim(),
      'category': (parsed['category'] ?? '').toString().trim(),
      'tags': (parsed['tags'] ?? '').toString().trim(),
      'source': (parsed['source'] ?? '').toString().trim(),
    };
  }

  // ===== 两段式入口：有图则「识图 → DeepSeek 精修」 =====
  /// 自动整理入口。根据是否有图片决定走哪条路：
  /// - 有图：按设置的「识图方式」先提取图片文字（视觉模型 或 本地 OCR），再交给 DeepSeek 精修。
  /// - 无图：直接走 DeepSeek 按文字描述整理。
  static Future<Map<String, String>> organizeAuto({
    required List<String> imagePaths,
    required String userText,
    required List<String> categories,
  }) async {
    if (imagePaths.isNotEmpty) {
      // 第一步：识图（视觉模型 或 OCR），得到图片文字
      final mode = await getImageMode();
      final String imageText;
      if (mode == ImageMode.ocr) {
        imageText = await OcrService.recognize(imagePaths.first);
        if (imageText.trim().isEmpty) {
          throw Exception('OCR 未识别到文字，请换用「视觉模型」识图方式，或换一张更清晰的图片');
        }
      } else {
        imageText = await _describeImage(
          imagePaths: imagePaths,
          userText: userText,
        );
      }
      // 第二步：交给 DeepSeek 精修
      return organize(
        userText: userText.trim().isEmpty
            ? imageText
            : '$imageText\n\n（用户补充：$userText）',
        categories: categories,
      );
    }
    // 无图，纯文字整理
    return organize(userText: userText, categories: categories);
  }

  /// 视觉模型看图，返回图片的纯文字描述（供后续 DeepSeek 精修）。
  static Future<String> _describeImage({
    required List<String> imagePaths,
    required String userText,
  }) async {
    final visionKey = await getVisionKey();
    if (visionKey.isEmpty) {
      throw Exception('尚未配置「图片识别」AI Key，请先到「AI 设置」填写');
    }
    final visionUrl = await getVisionUrl();
    final visionModel = await getVisionModel();

    final imgPath = imagePaths.first;
    final file = File(imgPath);
    if (!file.existsSync()) {
      throw Exception('图片文件不存在');
    }
    final bytes = await file.readAsBytes();
    final base64 = base64Encode(bytes);
    final mime = _mimeOf(imgPath);

    final prompt = StringBuffer();
    prompt.writeln('请仔细查看这张图片，把图片里的所有文字和重要信息**完整、逐条、原样**提取出来。');
    prompt.writeln('要求：');
    prompt.writeln('1. 不要总结、不要遗漏、不要编造，图片里有什么就写什么。');
    prompt.writeln('2. 如果是时间表/列表/表格类，请按「条件 → 内容」逐条列出，保留关键的对应关系（如「农历逢一逢六：王哥庄大集」）。');
    prompt.writeln('3. 只输出提取到的内容，不要任何解释。');
    if (userText.trim().isNotEmpty) {
      prompt.writeln('（用户另外补充：$userText）');
    }

    final url = '$visionUrl/chat/completions';
    final resp = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $visionKey',
      },
      body: jsonEncode({
        'model': visionModel,
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': prompt.toString()},
              {
                'type': 'image_url',
                'image_url': {'url': 'data:$mime;base64,$base64'},
              },
            ],
          },
        ],
        'temperature': 0.1,
        'max_tokens': 1500,
      }),
    ).timeout(const Duration(seconds: 120));

    if (resp.statusCode != 200) {
      throw Exception('图片识别失败（HTTP ${resp.statusCode}）：${_briefError(resp.body)}');
    }
    final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final choices = data['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw Exception('图片识别返回内容为空');
    }
    return (choices.first as Map<String, dynamic>)['message']['content'] as String;
  }

  // ===== 纯文字通道（DeepSeek） =====
  /// 传纯文字，走 DeepSeek 生成结构化字段（不上传图片时使用）。
  static Future<Map<String, String>> organize({
    required String userText,
    required List<String> categories,
  }) async {
    final apiKey = await getDeepseekKey();
    if (apiKey.isEmpty) {
      throw Exception('尚未配置 DeepSeek Key，请先到「AI 设置」填写');
    }
    final baseUrl = await getDeepseekUrl();

    final systemPrompt = _buildSystemPrompt(categories);
    final userPrompt = userText.trim().isEmpty
        ? '请整理下面这条信息（内容待用户补充，请根据常识给出一个通用整理）'
        : '请整理下面这条信息：\n$userText';

    final url = '$baseUrl/chat/completions';
    final resp = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'deepseek-chat',
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
        'temperature': 0.3,
        'response_format': {'type': 'json_object'},
      }),
    ).timeout(const Duration(seconds: 60));

    if (resp.statusCode != 200) {
      throw Exception('AI 调用失败（HTTP ${resp.statusCode}）：${_briefError(resp.body)}');
    }

    final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final choices = data['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw Exception('AI 返回内容为空');
    }
    final content = (choices.first as Map<String, dynamic>)['message']['content'] as String;
    return _parseContent(content);
  }

  /// 根据文件扩展名推断 MIME 类型。
  static String _mimeOf(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  /// 从可能带 ```json 包裹的内容里提取纯 JSON 字符串。
  static String _extractJson(String content) {
    var s = content.trim();
    final start = s.indexOf('{');
    final end = s.lastIndexOf('}');
    if (start >= 0 && end > start) {
      s = s.substring(start, end + 1);
    }
    return s;
  }

  static String _briefError(String body) {
    try {
      final j = jsonDecode(body) as Map<String, dynamic>;
      final err = j['error'];
      if (err is Map && err['message'] != null) return err['message'].toString();
    } catch (_) {}
    return body.length > 200 ? body.substring(0, 200) : body;
  }
}
