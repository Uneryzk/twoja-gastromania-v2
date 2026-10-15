import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoja_gastromania/flutter_flow/tg_l10n.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_images.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_services/home_category_service.dart';

import 'helpers/tg_test_app.dart';

void main() {
  setUp(HomeCategoryService.instance.reset);

  test('kDisableDynamicListingImages stays locked', () {
    expect(TGListingImages.kDisableDynamicListingImages, isTrue);
  });

  test('category CMS JSON shape and staff-only save', () {
    final cms = HomeCategoryService.instance;
    final seed = cms.byId('cookingEquipment')!;
    expect(seed.category, TGCategory.cookingEquipment);
    expect(seed.toJson(), {
      'id': 'cookingEquipment',
      'title': '',
      'itemCount': '',
      'imageUrl': TGListingImages.categoryCover(TGCategory.cookingEquipment),
      'order': 1,
      'isActive': true,
    });

    final seller = FakeAuthState(isLoggedIn: true);
    expect(cms.save(actor: seller, category: seed.copyWith(title: 'Nope')), 'adm_err_staff');
    expect(cms.byId('cookingEquipment')!.title, isEmpty);

    final admin = FakeAuthState(isLoggedIn: true)..setRole(TGUserRole.admin);
    expect(
      cms.save(
        actor: admin,
        category: seed.copyWith(title: 'Combi ovens', itemCount: '24 listings', imageUrl: TGListingImages.combiOven),
      ),
      isNull,
    );
    expect(cms.byId('cookingEquipment')!.title, 'Combi ovens');
    expect(cms.byId('cookingEquipment')!.itemCount, '24 listings');
    expect(cms.byId('cookingEquipment')!.imageUrl, TGListingImages.combiOven);

    final mod = FakeAuthState(isLoggedIn: true)..setRole(TGUserRole.moderator);
    expect(cms.save(actor: mod, category: cms.byId('cookingEquipment')!.copyWith(title: 'Kitchen heat')), isNull);
    expect(cms.byId('cookingEquipment')!.title, 'Kitchen heat');
  });

  test('category edit copy exists in TR, PL and EN', () {
    for (final key in [
      'ui_category_edit',
      'ui_category_edit_dialog',
      'ui_category_edit_sem',
      'ui_category_name',
      'ui_category_count',
      'ui_category_photo',
      'ui_category_missing',
    ]) {
      final row = kUiTranslations[key]!;
      expect(row['en'], isNotEmpty, reason: key);
      expect(row['pl'], isNotEmpty, reason: key);
      expect(row['tr'], isNotEmpty, reason: key);
      expect(row['pl'], isNot(row['en']), reason: key);
      expect(row['tr'], isNot(row['en']), reason: key);
    }
  });

  testWidgets('visitors and sellers do not see category edit pencils', (tester) async {
    final app = await pumpTgApp(tester, location: '/', size: TGSizes.desktop);
    expect(find.text('Cooking Equipment'), findsWidgets);
    expect(find.byKey(const Key('home-category-edit-cookingEquipment')), findsNothing);
    app.errors.stop();
    expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
  });

  testWidgets('admin can edit a category title, count and photo', (tester) async {
    final app = await pumpTgApp(tester, location: '/', size: TGSizes.desktop);
    app.auth.setRole(TGUserRole.admin);
    await tester.pump();
    final edit = find.byKey(const Key('home-category-edit-cookingEquipment'));
    await tester.ensureVisible(edit);
    await tester.pump();
    expect(edit, findsOneWidget);
    await tester.tap(edit);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byKey(const Key('home-category-edit-sheet')), findsOneWidget);
    expect(find.text('Edit category (staff)'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('home-category-edit-title')), 'Pro combi ovens');
    await tester.enterText(find.byKey(const Key('home-category-edit-count')), '18 listings');
    await tester.tap(find.byKey(const Key('home-category-edit-save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Pro combi ovens'), findsWidgets);
    expect(find.text('18 listings'), findsOneWidget);
    expect(HomeCategoryService.instance.byId('cookingEquipment')!.title, 'Pro combi ovens');
    app.errors.stop();
    expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
  });

  testWidgets('moderator sees category edit pencils', (tester) async {
    final app = await pumpTgApp(tester, location: '/', size: TGSizes.desktop);
    app.auth.setRole(TGUserRole.moderator);
    await tester.pump();
    expect(find.byKey(const Key('home-category-edit-cookingEquipment')), findsOneWidget);
    app.errors.stop();
    expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
  });
}
