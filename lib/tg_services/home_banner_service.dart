import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_images.dart';
import 'package:twoja_gastromania/tg_models/tg_home_banner.dart';

/// In-memory CMS for organic home-hero banners. Staff (admin / moderator) save
/// title, subtitle, image and CTA copy; visitors only see the published row.
class HomeBannerService extends ChangeNotifier {
  HomeBannerService._();
  static final HomeBannerService instance = HomeBannerService._();

  final List<TGHomeBanner> _banners = [];
  bool _seeded = false;

  List<TGHomeBanner> get all => List.unmodifiable(_banners);

  List<TGHomeBanner> get active {
    ensureSeeded();
    final live = _banners.where((b) => b.isActive).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return live;
  }

  TGHomeBanner? byId(String id) {
    ensureSeeded();
    for (final b in _banners) {
      if (b.id == id) return b;
    }
    return null;
  }

  void reset() {
    _banners.clear();
    _seeded = false;
    notifyListeners();
  }

  void ensureSeeded() {
    if (_seeded) return;
    _seeded = true;
    _banners.addAll(_seeds);
  }

  /// Returns an l10n error key, or null on success.
  String? save({required FakeAuthState actor, required TGHomeBanner banner}) {
    if (!actor.canModerate) return 'adm_err_staff';
    ensureSeeded();
    final i = _banners.indexWhere((b) => b.id == banner.id);
    if (i < 0) return 'ui_banner_missing';
    final current = _banners[i];
    final image = banner.imageUrl.trim().isEmpty ? current.imageUrl : banner.imageUrl.trim();
    _banners[i] = current.copyWith(
      title: banner.title.trim(),
      subtitle: banner.subtitle.trim(),
      imageUrl: image,
      buttonText: banner.buttonText.trim(),
      targetUrl: banner.targetUrl.trim().isEmpty ? current.targetUrl : banner.targetUrl.trim(),
      order: banner.order,
      isActive: banner.isActive,
    );
    notifyListeners();
    return null;
  }

  static final List<TGHomeBanner> _seeds = [
    TGHomeBanner(
      id: 'banner_eurogastro_2027',
      title: '',
      subtitle: '',
      imageUrl: TGListingImages.heroSlide(0),
      buttonText: '',
      targetUrl: '/birinciReklamSayfasi',
      order: 1,
      isActive: true,
      titleKey: 'i8m5wr2h',
      subtitleKey: '7d6qkq0f',
      routeName: 'BirinciReklamSayfasi',
    ),
    TGHomeBanner(
      id: 'banner_todays_offer',
      title: '',
      subtitle: '',
      imageUrl: TGListingImages.heroSlide(1),
      buttonText: '',
      targetUrl: '/ikinciReklamSayfasi',
      order: 2,
      isActive: true,
      titleKey: '0y0mdwe3',
      subtitleKey: 'gn0cgz8h',
      routeName: 'ikinciReklamSayfasi',
    ),
    TGHomeBanner(
      id: 'banner_kitchen_equipment',
      title: '',
      subtitle: '',
      imageUrl: TGListingImages.heroSlide(2),
      buttonText: '',
      targetUrl: '/ucuncuReklamSayfasi',
      order: 3,
      isActive: true,
      titleKey: 'z2t2enej',
      subtitleKey: 'yhrj1i0w',
      routeName: 'UcuncuReklamSayfasi',
    ),
    TGHomeBanner(
      id: 'banner_bar_setups',
      title: '',
      subtitle: '',
      imageUrl: TGListingImages.heroSlide(3),
      buttonText: '',
      targetUrl: '/dortuncuReklamSayfasi',
      order: 4,
      isActive: true,
      titleKey: 'fd2vmdbm',
      subtitleKey: 'ghe86x4x',
      routeName: 'DortuncuReklamSayfasi',
    ),
  ];
}
