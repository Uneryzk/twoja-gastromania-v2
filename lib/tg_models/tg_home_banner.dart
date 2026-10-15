/// CMS row for an organic home-hero banner (staff-editable).
class TGHomeBanner {
  const TGHomeBanner({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.buttonText,
    required this.targetUrl,
    required this.order,
    required this.isActive,
    this.titleKey = '',
    this.subtitleKey = '',
    this.routeName = '',
  });

  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String buttonText;
  final String targetUrl;
  final int order;
  final bool isActive;

  /// l10n fallback when [title] is empty.
  final String titleKey;

  /// l10n fallback when [subtitle] is empty.
  final String subtitleKey;

  /// go_router named route when [targetUrl] is empty.
  final String routeName;

  bool get hasTitleOverride => title.trim().isNotEmpty;
  bool get hasSubtitleOverride => subtitle.trim().isNotEmpty;
  bool get hasButtonOverride => buttonText.trim().isNotEmpty;

  TGHomeBanner copyWith({
    String? title,
    String? subtitle,
    String? imageUrl,
    String? buttonText,
    String? targetUrl,
    int? order,
    bool? isActive,
  }) {
    return TGHomeBanner(
      id: id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      imageUrl: imageUrl ?? this.imageUrl,
      buttonText: buttonText ?? this.buttonText,
      targetUrl: targetUrl ?? this.targetUrl,
      order: order ?? this.order,
      isActive: isActive ?? this.isActive,
      titleKey: titleKey,
      subtitleKey: subtitleKey,
      routeName: routeName,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'imageUrl': imageUrl,
        'buttonText': buttonText,
        'targetUrl': targetUrl,
        'order': order,
        'isActive': isActive,
      };

  factory TGHomeBanner.fromJson(Map<String, dynamic> json, {TGHomeBanner? seed}) {
    return TGHomeBanner(
      id: json['id'] as String? ?? seed?.id ?? '',
      title: json['title'] as String? ?? seed?.title ?? '',
      subtitle: json['subtitle'] as String? ?? seed?.subtitle ?? '',
      imageUrl: json['imageUrl'] as String? ?? seed?.imageUrl ?? '',
      buttonText: json['buttonText'] as String? ?? seed?.buttonText ?? '',
      targetUrl: json['targetUrl'] as String? ?? seed?.targetUrl ?? '',
      order: json['order'] as int? ?? seed?.order ?? 0,
      isActive: json['isActive'] as bool? ?? seed?.isActive ?? true,
      titleKey: seed?.titleKey ?? '',
      subtitleKey: seed?.subtitleKey ?? '',
      routeName: seed?.routeName ?? '',
    );
  }
}
