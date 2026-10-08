import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/flutter_flow/nav/nav.dart';
import 'package:twoja_gastromania/state/admin_locale_state.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_theme.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_services/account_identity_service.dart';
import 'package:twoja_gastromania/tg_services/invoicing_service.dart';
import 'package:twoja_gastromania/tg_services/messaging_service.dart';
import 'package:twoja_gastromania/tg_services/moderation_service.dart';
import 'package:url_launcher_platform_interface/link.dart' show LinkDelegate;
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// Common viewport sizes used across the suite.
abstract final class TGSizes {
  static const desktop = Size(1440, 900);
  static const laptop = Size(1100, 800);
  static const tablet = Size(820, 1100);
  static const phone = Size(390, 844);
  static const smallPhone = Size(320, 640);
}

bool _fontsLoaded = false;

/// `flutter test` renders text with the "Ahem" font where every glyph is a full
/// em wide, which makes layouts look ~2x wider than they are and produces bogus
/// overflow errors. We register Roboto (shipped with the Flutter SDK) under the
/// family names google_fonts would use for Inter / Inter Tight, so text
/// metrics are realistic.
Future<void> loadRealisticFonts() async {
  if (_fontsLoaded) return;

  GoogleFonts.config.allowRuntimeFetching = false;

  Directory? dir;
  var probe = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 6 && dir == null; i++) {
    final candidate = Directory('${probe.path}/material_fonts');
    if (candidate.existsSync()) dir = candidate;
    probe = probe.parent;
  }
  final root = Platform.environment['FLUTTER_ROOT'];
  if (dir == null && root != null) {
    final candidate = Directory('$root/bin/cache/artifacts/material_fonts');
    if (candidate.existsSync()) dir = candidate;
  }
  if (dir == null) {
    debugPrint('material_fonts not found; falling back to the Ahem test font.');
    _fontsLoaded = true;
    return;
  }

  Future<ByteData> bytes(String file) async {
    final b = File('${dir!.path}/$file').readAsBytesSync();
    return ByteData.view(Uint8List.fromList(b).buffer);
  }

  const weightToRoboto = {
    'regular': 'Roboto-Regular.ttf',
    '100': 'Roboto-Thin.ttf',
    '200': 'Roboto-Light.ttf',
    '300': 'Roboto-Light.ttf',
    '400': 'Roboto-Regular.ttf',
    '500': 'Roboto-Medium.ttf',
    '600': 'Roboto-Bold.ttf',
    '700': 'Roboto-Bold.ttf',
    '800': 'Roboto-Black.ttf',
    '900': 'Roboto-Black.ttf',
  };
  for (final family in const ['Inter', 'InterTight']) {
    for (final e in weightToRoboto.entries) {
      final loader = FontLoader('${family}_${e.key}')..addFont(bytes(e.value));
      await loader.load();
    }
  }
  _fontsLoaded = true;
}

/// Records everything the framework reports as an error while [body] runs.
class ErrorCollector {
  final List<String> errors = [];
  FlutterExceptionHandler? _previous;

  void start() {
    _previous = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.exceptionAsString().split('\n').first;
      // Follow-on noise caused by a layout error that was already recorded.
      if (text.startsWith('RenderBox was not laid out') ||
          text.contains('_needsLayout') ||
          text.contains('parentDataDirty')) {
        return;
      }
      final locs = RegExp(r'lib/[A-Za-z0-9_/]+\.dart:\d+:\d+').allMatches(details.toString()).map((m) => m.group(0)!).toSet().take(2).join(', ');
      errors.add('$text${locs.isEmpty ? '' : '  @ $locs'}');
      // Forward so a failed expect() while this override is active does not
      // trip the test binding's "_pendingExceptionDetails != null" assert.
      _previous?.call(details);
    };
  }

  /// Restores the test binding's handler. Must be called before the test ends.
  void stop() => FlutterError.onError = _previous;

  List<String> get distinct => errors.toSet().toList();
}

/// A recorded interaction with the (mocked) platform.
class TGPlatformLog {
  final List<String> clipboard = [];
  final List<String> launchedUrls = [];
}

class _FakeUrlLauncher extends UrlLauncherPlatform with MockPlatformInterfaceMixin {
  _FakeUrlLauncher(this.log);
  final TGPlatformLog log;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    log.launchedUrls.add(url);
    return true;
  }
}

/// Everything a test needs after [pumpTgApp].
class TGApp {
  TGApp({required this.router, required this.auth, required this.log, required this.errors});

  final GoRouter router;
  final FakeAuthState auth;
  final TGPlatformLog log;
  final ErrorCollector errors;

  String get location => router.routerDelegate.currentConfiguration.uri.toString();
}

/// Boots the real router + theme at [size] on [location].
///
/// * clipboard writes and URL launches are captured in [TGApp.log];
/// * all framework errors are collected in [TGApp.errors] (call
///   `app.errors.stop()` at the end of the test).
Future<TGApp> pumpTgApp(
  WidgetTester tester, {
  Size size = TGSizes.desktop,
  String location = '/',
  bool signedIn = true,
  double textScale = 1.0,
  Map<String, Object> prefs = const {},
  Duration settle = const Duration(milliseconds: 900),
  Locale locale = const Locale('en'),
}) async {
  // Engine font loading completes outside of fake-async time.
  await tester.runAsync(loadRealisticFonts);
  SharedPreferences.setMockInitialValues(prefs);

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final log = TGPlatformLog();
  UrlLauncherPlatform.instance = _FakeUrlLauncher(log);
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.setData') {
      log.clipboard.add((call.arguments as Map)['text'] as String);
    }
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

  final errors = ErrorCollector()..start();
  addTearDown(errors.stop);
  MessagingService.instance.reset();
  InvoicingService.instance.reset();
  ModerationService.instance.reset();
  AccountIdentityService.instance.reset();
  AdminLocaleState.instance.reset(to: locale.languageCode);
  final auth = FakeAuthState(isLoggedIn: signedIn);
  final router = createRouter(AppStateNotifier.instance, initialLocation: location);

  // Drop any previous router so the shared navigator key can be reused
  // (tests that call pumpTgApp twice otherwise trip go_router's page registry).
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<FakeAuthState>.value(value: auth),
        ChangeNotifierProvider<ModerationService>.value(value: ModerationService.instance),
        ChangeNotifierProvider<AdminLocaleState>.value(value: AdminLocaleState.instance),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          FFLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          FallbackMaterialLocalizationDelegate(),
          FallbackCupertinoLocalizationDelegate(),
        ],
        locale: locale,
        supportedLocales: kSupportedLocales,
        localeResolutionCallback: resolveAppLocale,
        theme: buildTGDarkTheme(),
        darkTheme: buildTGDarkTheme(),
        themeMode: ThemeMode.dark,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            accessibleNavigation: false,
          ),
          child: Scaffold(
            backgroundColor: TGColors.background,
            body: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  // Let async work (catalogue load, prefs) finish without waiting for the
  // endless animations (shimmer, carousel) to "settle".
  for (var elapsed = Duration.zero; elapsed < settle; elapsed += const Duration(milliseconds: 100)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return TGApp(router: router, auth: auth, log: log, errors: errors);
}

/// Pumps [duration] of fake time in small steps.
Future<void> pumpFor(WidgetTester tester, Duration duration) async {
  const step = Duration(milliseconds: 50);
  for (var t = Duration.zero; t < duration; t += step) {
    await tester.pump(step);
  }
}
