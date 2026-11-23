/// 分类实体。支持父子层级（parentId 指向父分类），可无限嵌套。
class Category {
  final int? id;
  final String name;
  final int? parentId;
  final int sortOrder;
  final int createdAt;

  Category({
    this.id,
    required this.name,
    this.parentId,
    this.sortOrder = 0,
    int? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  Category copyWith({
    int? id,
    String? name,
    int? parentId,
    int? sortOrder,
    int? createdAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'parentId': parentId,
      'sortOrder': sortOrder,
      'createdAt': createdAt,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int?,
      name: map['name'] as String,
      parentId: map['parentId'] as int?,
      sortOrder: map['sortOrder'] as int? ?? 0,
      createdAt: map['createdAt'] as int?,
    );
  }
}
