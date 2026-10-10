import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_models/tg_special_order.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';
import 'package:twoja_gastromania/tg_services/special_order_service.dart';

import 'helpers/tg_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TGSellerProfileService.instance.reset();
    TGSpecialOrderService.instance.reset();
  });

  test('special-order manufacturer directory excludes basic and inactive', () {
    final makers = TGSellerProfileService.instance.specialOrderManufacturers;
    expect(makers.length, 6);
    expect(makers.any((p) => p.name == 'Technica'), isFalse);
    expect(makers.any((p) => p.name == 'OldKitchen'), isFalse);
    expect(makers.any((p) => p.name == 'Gastrosilesia.pl'), isTrue);
    expect(makers.any((p) => p.name == 'RM'), isTrue);
    expect(makers.any((p) => p.name == 'Inoxline Silesia'), isTrue);
    expect(makers.any((p) => p.name == 'Stalbar Projekt'), isTrue);
    expect(makers.any((p) => p.name == 'Metalgast Katowice'), isTrue);
    expect(makers.any((p) => p.name == 'Nordinox Warszawa'), isTrue);
    final nordinox = makers.firstWhere((p) => p.name == 'Nordinox Warszawa');
    expect(nordinox.projects, isEmpty);
  });

  test('special-order service filters and sorts', () {
    final svc = TGSpecialOrderService.instance;
    final withHoods = svc.manufacturers(types: {TGStoreSpecialty.extractionHoods});
    expect(withHoods.every((p) => p.specialties.contains(TGStoreSpecialty.extractionHoods)), isTrue);
    final withProjects = svc.manufacturers(hasProjects: true);
    expect(withProjects.every((p) => p.projects.isNotEmpty), isTrue);
    final fastest = svc.manufacturers(sort: TGSpecialSort.fastestResponse);
    expect(fastest.first.responseHours, lessThanOrEqualTo(fastest.last.responseHours ?? 99));
  });

  testWidgets('hub page loads manufacturers and nav is active', (tester) async {
    final app = await pumpTgApp(tester, location: '/special-order', size: TGSizes.desktop);
    await tester.pump(const Duration(milliseconds: 1300));
    expect(find.text('Special Order'), findsWidgets);
    expect(find.textContaining('Custom stainless steel'), findsOneWidget);
    expect(find.text('How it works'), findsOneWidget);
    expect(find.text('Manufacturers'), findsOneWidget);
    expect(find.text('Gastrosilesia.pl'), findsWidgets);
    expect(find.text('Nordinox Warszawa'), findsOneWidget);
    expect(find.text('Technica'), findsNothing);
    expect(find.text('No projects added yet'), findsOneWidget);
    expect(app.location, '/special-order');
  });

  testWidgets('new wizard preselects seller and type from query', (tester) async {
    final app = await pumpTgApp(tester, location: '/', size: TGSizes.desktop);
    app.auth.actAsBuyer(BuyerDevPick.marek);
    await tester.pumpAndSettle();
    app.router.go('/special-order/new?seller=1847&type=worktops_tables');
    await tester.pumpAndSettle();
    expect(find.text('Request summary'), findsOneWidget);
    expect(find.textContaining('Gastrosilesia.pl'), findsWidgets);
    expect(find.textContaining('Worktops'), findsWidgets);
  });

  testWidgets('nav Special Order goes to hub', (tester) async {
    final app = await pumpTgApp(tester, location: '/', size: TGSizes.desktop);
    await tester.tap(find.text('Special Order').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1300));
    expect(app.location, '/special-order');
    expect(find.textContaining('Custom stainless steel'), findsOneWidget);
    // Hub is a full page — no legacy modal sheet.
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('Special Order nav pill is active on hub', (tester) async {
    await pumpTgApp(tester, location: '/special-order', size: TGSizes.desktop);
    await tester.pump(const Duration(milliseconds: 1300));
    final pill = find.ancestor(
      of: find.text('Special Order'),
      matching: find.byWidgetPredicate(
        (w) => w is Semantics && (w.properties.selected ?? false),
      ),
    );
    expect(pill, findsWidgets);
  });
}
