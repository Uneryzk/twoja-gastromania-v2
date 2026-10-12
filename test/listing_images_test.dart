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
      expect(TGListingImages.categoryCover(TGCategory.cookingEquipment), TGListingImages.mutfakEquip);
      expect(TGListingImages.categoryCover(TGCategory.refrigerationEquipment), TGListingImages.fridge700);
      expect(TGListingImages.categoryCover(TGCategory.warewashing), TGListingImages.warewashing);
      expect(TGListingImages.categoryCover(TGCategory.foodPreparation), TGListingImages.foodPrep);
      expect(TGListingImages.categoryCover(TGCategory.stainlessSteelFurniture), TGListingImages.shelves);
      expect(TGListingImages.categoryCover(TGCategory.barAndBeverageEquipment), TGListingImages.coffeeEspresso);
    });

    test('dynamic title/theme matching is disabled; manual photos come from admin/seller panels', () {
      expect(TGListingImages.kDisableDynamicListingImages, isTrue);
      expect(TGListingImages.cover(id: 'x', category: TGCategory.cookingEquipment, title: 'Oven'), isEmpty);
      expect(TGListingImages.gallery(id: 'x', category: TGCategory.cookingEquipment, title: 'Oven', count: 5), isEmpty);
      // Inventory key → fixed library asset is not title matching and stays available.
      expect(TGListingImages.forEquipmentKey('resto_eq_dishwasher'), TGListingImages.warewashing);
    });

    test('galleryWithPrimary keeps only the stored primary', () {
      const primary = 'assets/images/mutfak-ekipmanlari.jpg';
      final g = TGListingImages.galleryWithPrimary(
        primary: primary,
        id: 'p001',
        category: TGCategory.cookingEquipment,
        title: 'Piec',
        count: 4,
      );
      expect(g, [primary]);
    });

    test('ensureBundled drops missing asset paths', () {
      expect(
        TGListingImages.ensureBundled('assets/images/does-not-exist.webp'),
        TGListingImages.mutfakEquip,
      );
      expect(
        TGListingImages.onlyBundled(const [
          'assets/images/missing.jpg',
          'assets/images/mutfak-ekipmanlari.jpg',
        ]),
        ['assets/images/mutfak-ekipmanlari.jpg'],
      );
    });

    test('hero slides stay local assets', () {
      for (var i = 0; i < 4; i++) {
        expect(TGListingImages.heroSlide(i), startsWith('assets/images/'));
      }
    });

    test('no remote URL constants remain', () {
      expect(TGListingImages.cooking, isNot(contains('http')));
      expect(TGListingImages.allFixed.every((u) => u.startsWith('assets/images/')), isTrue);
      expect(TGListingImages.listingPool.every((u) => u.startsWith('assets/images/')), isTrue);
    });
  });
}
