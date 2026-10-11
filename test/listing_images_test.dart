import 'package:flutter_test/flutter_test.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_images.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';

void main() {
  group('TGListingImages — local assets only', () {
    test('category covers are assets/images paths', () {
      for (final url in TGListingImages.categoryCoverUrls.values) {
        expect(url, startsWith('assets/images/'));
        expect(url, isNot(contains('unsplash')));
        expect(url, isNot(contains('picsum')));
        expect(url, isNot(contains('http')));
      }
      expect(TGListingImages.categoryCover(TGCategory.cookingEquipment), TGListingImages.cooking);
      expect(TGListingImages.categoryCover(TGCategory.refrigerationEquipment), TGListingImages.refrigeration);
      expect(TGListingImages.categoryCover(TGCategory.warewashing), TGListingImages.warewashing);
      expect(TGListingImages.categoryCover(TGCategory.foodPreparation), TGListingImages.foodPrep);
      expect(TGListingImages.categoryCover(TGCategory.stainlessSteelFurniture), TGListingImages.stainless);
      expect(TGListingImages.categoryCover(TGCategory.barAndBeverageEquipment), TGListingImages.barCafe);
    });

    test('cover / gallery / hero never leave assets/images', () {
      for (final cat in TGCategory.values) {
        final cover = TGListingImages.cover(id: 'x', category: cat, title: 'test');
        expect(cover, startsWith('assets/images/'));
        final gallery = TGListingImages.gallery(id: 'x', category: cat, title: 'test', count: 5);
        expect(gallery.every((u) => u.startsWith('assets/images/')), isTrue);
      }
      for (var i = 0; i < 4; i++) {
        expect(TGListingImages.heroSlide(i), startsWith('assets/images/'));
      }
    });

    test('galleryWithPrimary keeps seed cover first', () {
      const primary = 'assets/images/bartscher_2002170.webp';
      final g = TGListingImages.galleryWithPrimary(
        primary: primary,
        id: 'p001',
        category: TGCategory.cookingEquipment,
        title: 'Piec',
        count: 4,
      );
      expect(g.first, primary);
      expect(g, hasLength(4));
      expect(g.every((u) => u.startsWith('assets/images/')), isTrue);
    });

    test('no remote URL constants remain', () {
      expect(TGListingImages.cooking, isNot(contains('http')));
      expect(TGListingImages.allFixed.every((u) => u.startsWith('assets/images/')), isTrue);
      expect(TGListingImages.listingPool.every((u) => u.startsWith('assets/images/')), isTrue);
    });
  });
}
