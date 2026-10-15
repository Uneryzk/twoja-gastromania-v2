import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_images.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';

import 'helpers/tg_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('kDisableDynamicListingImages stays locked', () {
    expect(TGListingImages.kDisableDynamicListingImages, isTrue);
  });

  test('theme preference persists light, dark and system', () async {
    SharedPreferences.setMockInitialValues({});
    await FlutterFlowTheme.initialize();
    expect(FlutterFlowTheme.themeMode, ThemeMode.dark);

    FlutterFlowTheme.saveThemeMode(ThemeMode.light);
    expect(FlutterFlowTheme.themeMode, ThemeMode.light);

    FlutterFlowTheme.saveThemeMode(ThemeMode.system);
    expect(FlutterFlowTheme.themeMode, ThemeMode.system);

    FlutterFlowTheme.saveThemeMode(ThemeMode.dark);
    expect(FlutterFlowTheme.themeMode, ThemeMode.dark);
  });

  test('saved light preference is what the next launch reads', () async {
    SharedPreferences.setMockInitialValues({kThemePreferenceKey: 'light'});
    await FlutterFlowTheme.initialize();
    expect(FlutterFlowTheme.themeMode, ThemeMode.light);
    TGThemeController.instance.reset(mode: FlutterFlowTheme.themeMode);
    expect(TGColors.background, const Color(0xFFF8F9FA));
    expect(TGColors.surface, const Color(0xFFFFFFFF));
    expect(TGColors.textPrimary, const Color(0xFF101828));
    TGThemeController.instance.reset();
  });

  testWidgets('settings profile has theme chips; light applies without reboot', (tester) async {
    final app = await pumpTgApp(tester, location: '/dashboard/settings', size: TGSizes.desktop);
    expect(find.byKey(const Key('set-theme-section')), findsOneWidget);
    expect(find.byKey(const Key('set-theme-light')), findsOneWidget);
    expect(find.byKey(const Key('set-theme-dark')), findsOneWidget);
    expect(find.byKey(const Key('set-theme-system')), findsOneWidget);

    expect(TGThemeController.instance.mode, ThemeMode.dark);
    expect(tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor, const Color(0xFF252525));

    await tester.tap(find.byKey(const Key('set-theme-light')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(TGThemeController.instance.mode, ThemeMode.light);
    expect(TGColors.background, const Color(0xFFF8F9FA));
    expect(TGColors.surface, const Color(0xFFFFFFFF));
    expect(TGColors.textPrimary, const Color(0xFF101828));
    expect(tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor, const Color(0xFFF8F9FA));
    expect(FlutterFlowTheme.themeMode, ThemeMode.light);

    await tester.tap(find.byKey(const Key('set-theme-dark')));
    await tester.pump();
    expect(TGThemeController.instance.mode, ThemeMode.dark);
    expect(TGColors.background, const Color(0xFF252525));
    expect(find.byKey(const Key('settings-page')), findsOneWidget);
    expect(app.errors.distinct, isEmpty);
  });

  testWidgets('light mode paints the requested page and card colours', (tester) async {
    final app = await pumpTgApp(tester, location: '/products', themeMode: ThemeMode.light);
    expect(tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor, const Color(0xFFF8F9FA));
    expect(Theme.of(tester.element(find.byType(Scaffold).first)).brightness, Brightness.light);
    expect(FlutterFlowTheme.of(tester.element(find.byType(Scaffold).first)).primaryBackground, const Color(0xFFF8F9FA));
    expect(app.errors.distinct, isEmpty);
  });
}
