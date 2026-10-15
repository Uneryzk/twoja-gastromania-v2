import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_images.dart';
import 'package:twoja_gastromania/tg_models/tg_home_category.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';

/// In-memory CMS for home gastronomy category tiles (`categories` collection).
class HomeCategoryService extends ChangeNotifier {
  HomeCategoryService._();
  static final HomeCategoryService instance = HomeCategoryService._();

  final List<TGHomeCategory> _rows = [];
  bool _seeded = false;

  List<TGHomeCategory> get all => List.unmodifiable(_rows);

  List<TGHomeCategory> get active {
    ensureSeeded();
    final live = _rows.where((r) => r.isActive).toList()..sort((a, b) => a.order.compareTo(b.order));
    return live;
  }

  TGHomeCategory? byId(String id) {
    ensureSeeded();
    for (final r in _rows) {
      if (r.id == id) return r;
    }
    return null;
  }

  void reset() {
    _rows.clear();
    _seeded = false;
    notifyListeners();
  }

  void ensureSeeded() {
    if (_seeded) return;
    _seeded = true;
    _rows.addAll(_seeds);
  }

  /// Returns an l10n error key, or null on success.
  String? save({required FakeAuthState actor, required TGHomeCategory category}) {
    if (!actor.canModerate) return 'adm_err_staff';
    ensureSeeded();
    final i = _rows.indexWhere((r) => r.id == category.id);
    if (i < 0) return 'ui_category_missing';
    final current = _rows[i];
    final image = category.imageUrl.trim().isEmpty ? current.imageUrl : category.imageUrl.trim();
    _rows[i] = current.copyWith(
      title: category.title.trim(),
      itemCount: category.itemCount.trim(),
      imageUrl: image,
      order: category.order,
      isActive: category.isActive,
    );
    notifyListeners();
    return null;
  }

  static String titleKeyFor(TGCategory category) => switch (category) {
        TGCategory.cookingEquipment => 'ji98dehm',
        TGCategory.refrigerationEquipment => 'swrjjpbp',
        TGCategory.warewashing => 'lcx4dovc',
        TGCategory.foodPreparation => '71nup2wm',
        TGCategory.stainlessSteelFurniture => '56pbhr1s',
        TGCategory.barAndBeverageEquipment => 'viy2skiv',
      };

  static List<TGHomeCategory> get _seeds {
    var order = 1;
    return [
      for (final e in TGListingImages.categoryCoverUrls.entries)
        TGHomeCategory(
          id: e.key.name,
          category: e.key,
          title: '',
          itemCount: '',
          imageUrl: e.value,
          order: order++,
          isActive: true,
          titleKey: titleKeyFor(e.key),
        ),
    ];
  }
}
