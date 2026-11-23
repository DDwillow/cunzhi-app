/// 一条生活干货记录。图片路径列表用逗号分隔存多个图片。
class Record {
  final int? id;
  final String title;
  final String description;
  final int? categoryId;
  final String tags; // 逗号分隔
  final String imagePaths; // 逗号分隔的本地图片绝对路径
  final String source; // 来源（可选）
  final int createdAt;
  final int updatedAt;

  Record({
    this.id,
    required this.title,
    this.description = '',
    this.categoryId,
    this.tags = '',
    this.imagePaths = '',
    this.source = '',
    int? createdAt,
    int? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
        updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  Record copyWith({
    int? id,
    String? title,
    String? description,
    int? categoryId,
    String? tags,
    String? imagePaths,
    String? source,
    int? createdAt,
    int? updatedAt,
  }) {
    return Record(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      tags: tags ?? this.tags,
      imagePaths: imagePaths ?? this.imagePaths,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  List<String> get imageList =>
      imagePaths.split(',').where((s) => s.trim().isNotEmpty).toList();

  List<String> get tagList =>
      tags.split(',').where((s) => s.trim().isNotEmpty).toList();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'categoryId': categoryId,
      'tags': tags,
      'imagePaths': imagePaths,
      'source': source,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory Record.fromMap(Map<String, dynamic> map) {
    return Record(
      id: map['id'] as int?,
      title: map['title'] as String,
      description: map['description'] as String? ?? '',
      categoryId: map['categoryId'] as int?,
      tags: map['tags'] as String? ?? '',
      imagePaths: map['imagePaths'] as String? ?? '',
      source: map['source'] as String? ?? '',
      createdAt: map['createdAt'] as int?,
      updatedAt: map['updatedAt'] as int?,
    );
  }
}
