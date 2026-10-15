import 'package:twoja_gastromania/tg_models/tg_product.dart';

/// CMS row for a home-page gastronomy category tile (staff-editable).
class TGHomeCategory {
  const TGHomeCategory({
    required this.id,
    required this.category,
    required this.title,
    required this.itemCount,
    required this.imageUrl,
    required this.order,
    required this.isActive,
    this.titleKey = '',
  });

  final String id;
  final TGCategory category;
  final String title;
  final String itemCount;
  final String imageUrl;
  final int order;
  final bool isActive;

  /// l10n fallback when [title] is empty.
  final String titleKey;

  bool get hasTitleOverride => title.trim().isNotEmpty;
  bool get hasCountOverride => itemCount.trim().isNotEmpty;

  TGHomeCategory copyWith({
    String? title,
    String? itemCount,
    String? imageUrl,
    int? order,
    bool? isActive,
  }) {
    return TGHomeCategory(
      id: id,
      category: category,
      title: title ?? this.title,
      itemCount: itemCount ?? this.itemCount,
      imageUrl: imageUrl ?? this.imageUrl,
      order: order ?? this.order,
      isActive: isActive ?? this.isActive,
      titleKey: titleKey,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'itemCount': itemCount,
        'imageUrl': imageUrl,
        'order': order,
        'isActive': isActive,
      };

  factory TGHomeCategory.fromJson(Map<String, dynamic> json, {TGHomeCategory? seed}) {
    final id = json['id'] as String? ?? seed?.id ?? '';
    return TGHomeCategory(
      id: id,
      category: seed?.category ?? _categoryFromId(id),
      title: json['title'] as String? ?? seed?.title ?? '',
      itemCount: json['itemCount'] as String? ?? seed?.itemCount ?? '',
      imageUrl: json['imageUrl'] as String? ?? seed?.imageUrl ?? '',
      order: json['order'] as int? ?? seed?.order ?? 0,
      isActive: json['isActive'] as bool? ?? seed?.isActive ?? true,
      titleKey: seed?.titleKey ?? '',
    );
  }

  static TGCategory _categoryFromId(String id) {
    for (final c in TGCategory.values) {
      if (c.name == id) return c;
    }
    return TGCategory.cookingEquipment;
  }
}
