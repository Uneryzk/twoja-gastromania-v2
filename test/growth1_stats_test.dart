import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/tg_core/tg_theme.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';
import 'package:twoja_gastromania/tm_sayfalar/home_page/home_sections.dart';

const _pl = Locale('pl', 'PL');
const _style = TextStyle(fontSize: 22, fontWeight: FontWeight.w900);

int _digits(WidgetTester tester, String id) {
  final text = tester.widget<Text>(find.byKey(Key('home-stat-number-$id')));
  return int.parse(text.data!.replaceAll(RegExp(r'\D'), ''));
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  bool reduce = false,
  Size size = const Size(800, 600),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: _pl,
      supportedLocales: kSupportedLocales,
      localizationsDelegates: const [
        FFLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildTGDarkTheme(),
      home: MediaQuery(
        data: MediaQueryData(size: size, disableAnimations: reduce),
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUp(() {
    HomeStatCountUp.resetPlayed();
    TGRevenueConfigService.instance.reset();
  });

  tearDown(TGRevenueConfigService.instance.reset);

  test('pl-PL groups thousands with a space', () {
    expect(homeStatNumber(1426, _pl).replaceAll(RegExp(r'\s'), ' '), '1 426');
    expect(homeStatNumber(76, _pl), '76');
    expect(homeStatNumber(0, _pl), '0');
  });

  testWidgets('visible card counts 0 → target over 2s and holds the target', (tester) async {
    await _pump(
      tester,
      const HomeStatCountUp(id: 'n', target: 76, revealed: true, textStyle: _style),
    );
    expect(_digits(tester, 'n'), 0);

    await tester.pump(const Duration(milliseconds: 800));
    final mid = _digits(tester, 'n');
    expect(mid, greaterThan(0));
    expect(mid, lessThan(76));

    await tester.pump(const Duration(milliseconds: 1400));
    expect(_digits(tester, 'n'), 76);
  });

  testWidgets('second visibility does not replay the 2s count-up', (tester) async {
    Widget counter() => const HomeStatCountUp(id: 'once', target: 1426, revealed: true, textStyle: _style);

    await _pump(tester, counter());
    await tester.pump(HomeStatCountUp.firstDuration);
    expect(_digits(tester, 'once'), 1426);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await _pump(tester, counter());
    expect(_digits(tester, 'once'), 1426);

    await tester.pump(const Duration(milliseconds: 400));
    expect(_digits(tester, 'once'), 1426);
  });

  testWidgets('reduced motion writes the final value immediately', (tester) async {
    await _pump(
      tester,
      const HomeStatCountUp(id: 'rm', target: 465, revealed: true, textStyle: _style),
      reduce: true,
    );
    expect(_digits(tester, 'rm'), 465);
    await tester.pump(const Duration(milliseconds: 300));
    expect(_digits(tester, 'rm'), 465);
  });

  testWidgets('missing data shows a skeleton; animation starts when the value arrives', (tester) async {
    int? target;
    await _pump(
      tester,
      StatefulBuilder(
        builder: (context, setState) {
          return GestureDetector(
            onTap: () => setState(() => target = 181),
            child: HomeStatCountUp(id: 'sk', target: target, revealed: true, textStyle: _style),
          );
        },
      ),
    );
    expect(find.byKey(const Key('home-stat-skeleton')), findsOneWidget);
    expect(find.byKey(const Key('home-stat-number-sk')), findsNothing);

    await tester.tap(find.byType(GestureDetector));
    await tester.pump();
    expect(find.byKey(const Key('home-stat-skeleton')), findsNothing);
    expect(_digits(tester, 'sk'), 0);
    await tester.pump(HomeStatCountUp.firstDuration);
    expect(_digits(tester, 'sk'), 181);
  });

  testWidgets('value 0 snaps to 0 without a count-up', (tester) async {
    await _pump(
      tester,
      const HomeStatCountUp(id: 'z', target: 0, revealed: true, textStyle: _style),
    );
    expect(_digits(tester, 'z'), 0);
    await tester.pump(const Duration(milliseconds: 400));
    expect(_digits(tester, 'z'), 0);
  });

  testWidgets('live update tweens from the current value in 600ms', (tester) async {
    var target = 76;
    await _pump(
      tester,
      StatefulBuilder(
        builder: (context, setState) {
          return GestureDetector(
            onTap: () => setState(() => target = 120),
            child: HomeStatCountUp(id: 'live', target: target, revealed: true, textStyle: _style),
          );
        },
      ),
    );
    await tester.pump(HomeStatCountUp.firstDuration);
    expect(_digits(tester, 'live'), 76);

    await tester.tap(find.byType(GestureDetector));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final mid = _digits(tester, 'live');
    expect(mid, greaterThan(76));
    expect(mid, lessThan(120));

    await tester.pump(HomeStatCountUp.liveDuration);
    expect(_digits(tester, 'live'), 120);
  });

  testWidgets('off-screen card stays at 0 until ≥50% visible', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    tester.view.physicalSize = const Size(400, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: _pl,
        localizationsDelegates: const [
          FFLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: MediaQuery(
          data: const MediaQueryData(size: Size(400, 400)),
          child: Scaffold(
            body: SingleChildScrollView(
              controller: controller,
              child: const Column(
                children: [
                  SizedBox(height: 500),
                  Center(
                    child: HomeStatCountUp(id: 'off', target: 76, textStyle: _style),
                  ),
                  SizedBox(height: 500),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(_digits(tester, 'off'), 0);
    await tester.pump(const Duration(milliseconds: 400));
    expect(_digits(tester, 'off'), 0);

    controller.jumpTo(420);
    await tester.pump();
    await tester.pump();
    expect(_digits(tester, 'off'), 0);
    await tester.pump(HomeStatCountUp.firstDuration);
    expect(_digits(tester, 'off'), 76);
  });

  testWidgets('production mode hides tiles under 5 and skips their animation', (tester) async {
    TGRevenueConfigService.instance.setProductionMode(true, actorId: 't', reason: 'test');
    await _pump(
      tester,
      const HomeStatsSection(debugValues: [3, 80, 90, 2]),
      size: const Size(1100, 800),
    );
    await tester.pump();

    expect(find.byKey(const Key('home-stat-dkz7hccx')), findsNothing);
    expect(find.byKey(const Key('home-stat-eio1zib0')), findsNothing);
    expect(find.byKey(const Key('home-stat-p15aunky')), findsOneWidget);
    expect(find.byKey(const Key('home-stat-b81eez74')), findsOneWidget);
    expect(find.byType(HomeStatCountUp), findsNWidgets(2));
  });

  testWidgets('production mode hides the strip when fewer than 2 tiles remain', (tester) async {
    TGRevenueConfigService.instance.setProductionMode(true, actorId: 't', reason: 'test');
    await _pump(
      tester,
      const HomeStatsSection(debugValues: [1, 2, 3, 9]),
      size: const Size(1100, 800),
    );
    expect(find.byType(HomeStatCard), findsNothing);
    expect(find.byType(HomeStatCountUp), findsNothing);
  });

  testWidgets('production mode keeps the real four tiles (all ≥5)', (tester) async {
    TGRevenueConfigService.instance.setProductionMode(true, actorId: 't', reason: 'test');
    await _pump(tester, const HomeStatsSection(), size: const Size(1100, 800));
    expect(find.byType(HomeStatCard), findsNWidgets(4));
    expect(find.byKey(const Key('home-stat-dkz7hccx')), findsOneWidget);
    expect(find.byKey(const Key('home-stat-p15aunky')), findsOneWidget);
    expect(find.byKey(const Key('home-stat-b81eez74')), findsOneWidget);
    expect(find.byKey(const Key('home-stat-eio1zib0')), findsOneWidget);
  });

  testWidgets('Semantics exposes the final value, never the ticking intermediates', (tester) async {
    final handle = tester.ensureSemantics();

    const title = 'Aktywni użytkownicy teraz';
    await _pump(
      tester,
      const HomeStatCard(
        key: Key('home-stat-sem'),
        imageAsset: 'assets/images/24_saat.png',
        title: title,
        playId: 'sem',
        targetValue: 1426,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final mid = _digits(tester, 'sem');
    expect(mid, greaterThan(0));
    expect(mid, lessThan(1426));

    final formattedFinal = homeStatNumber(1426, _pl);
    final formattedMid = homeStatNumber(mid, _pl);
    expect(
      find.bySemanticsLabel(RegExp(RegExp.escape(formattedFinal))),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp('^${RegExp.escape(formattedMid)}\$')), findsNothing);

    final data = tester.getSemantics(find.bySemanticsLabel(RegExp(RegExp.escape(formattedFinal))));
    expect(data.label, contains(title));
    expect(data.label, contains(formattedFinal));
    expect(data.label.contains(formattedMid) && formattedMid != formattedFinal, isFalse);

    await tester.pump(HomeStatCountUp.firstDuration);
    expect(_digits(tester, 'sem'), 1426);
    expect(
      tester.getSemantics(find.bySemanticsLabel(RegExp(RegExp.escape(formattedFinal)))).label,
      contains(formattedFinal),
    );
    handle.dispose();
  });
}
