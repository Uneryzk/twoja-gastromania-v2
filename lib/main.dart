import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:twoja_gastromania/backend/firebase/firebase_config.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_util.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/flutter_flow/nav/nav.dart';
import 'package:twoja_gastromania/state/admin_locale_state.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_i18n_audit_overlay.dart';
import 'package:twoja_gastromania/tg_core/tg_i18n_audit.dart';
import 'package:twoja_gastromania/tg_core/tg_theme.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_services/deal_moderation_service.dart';
import 'package:twoja_gastromania/tg_services/deal_service.dart';
import 'package:twoja_gastromania/tg_services/moderation_service.dart';
import 'package:twoja_gastromania/tg_services/notification_service.dart';

import 'package:provider/provider.dart';

const _kStartupTimeout = Duration(seconds: 5);

/// The app has no backend yet, so the session is mocked. Default is a logged-out
/// visitor (header shows "Login"). Long-press the login/account control for the
/// Turkish Dev Switcher. Set `true` only if you want a signed-in demo by default.
const bool kMockSignedInByDefault = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoRouter.optionURLReflectsImperativeAPIs = true;
  usePathUrlStrategy();

  // IMPORTANT: Neither of these must be allowed to hang forever, otherwise
  // runApp() below never executes and the preview shows a permanent black
  // screen with nothing rendered at all (no error, since it's stuck pre-paint).
  try {
    await initFirebase().timeout(_kStartupTimeout);
  } catch (e) {
    debugPrint('initFirebase failed or timed out, continuing without it: $e');
  }

  try {
    await FlutterFlowTheme.initialize().timeout(_kStartupTimeout);
  } catch (e) {
    debugPrint('FlutterFlowTheme.initialize failed or timed out: $e');
  }

  try {
    await FFLocalizations.initialize().timeout(_kStartupTimeout);
  } catch (e) {
    debugPrint('FFLocalizations.initialize failed or timed out: $e');
  }

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  // This widget is the root of your application.
  @override
  State<MyApp> createState() => _MyAppState();

  static _MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>()!;

  /// Like [setAppLanguage] but a no-op outside [MyApp] (e.g. widget tests).
  static void trySetLocale(BuildContext context, String language) =>
      context.findAncestorStateOfType<_MyAppState>()?.setLocale(language);

  /// Like [setThemeMode] but a no-op outside [MyApp] (e.g. widget tests).
  static void trySetThemeMode(BuildContext context, ThemeMode mode) =>
      context.findAncestorStateOfType<_MyAppState>()?.setThemeMode(mode);
}

class MyAppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  Locale? _locale;

  ThemeMode _themeMode = ThemeMode.light;

  late AppStateNotifier _appStateNotifier;
  late GoRouter _router;
  String getRoute([RouteMatch? routeMatch]) {
    final RouteMatch lastMatch =
        routeMatch ?? _router.routerDelegate.currentConfiguration.last;
    final RouteMatchList matchList = lastMatch is ImperativeRouteMatch
        ? lastMatch.matches
        : _router.routerDelegate.currentConfiguration;
    return matchList.uri.path;
  }

  List<String> getRouteStack() =>
      _router.routerDelegate.currentConfiguration.matches
          .map((e) => getRoute(e))
          .toList();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _themeMode = FlutterFlowTheme.themeMode;
    TGThemeController.instance
      ..bindPlatformBrightness(WidgetsBinding.instance.platformDispatcher.platformBrightness)
      ..setMode(_themeMode);

    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    final stored = FFLocalizations.getStoredLocale();
    if (stored != null) {
      _locale = stored;
    } else {
      _locale = detectAppLocale(preferred: [dispatcher.locale, ...dispatcher.locales]);
      FFLocalizations.storeLocale(_locale!.languageCode);
    }

    _appStateNotifier = AppStateNotifier.instance;
    _router = createRouter(_appStateNotifier);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    TGThemeController.instance.bindPlatformBrightness(
      WidgetsBinding.instance.platformDispatcher.platformBrightness,
    );
    if (_themeMode == ThemeMode.system) safeSetState(() {});
  }

  void setLocale(String language) {
    safeSetState(() => _locale = createLocale(language));
    FFLocalizations.storeLocale(language);
  }

  void setThemeMode(ThemeMode mode) => safeSetState(() {
        _themeMode = mode;
        TGThemeController.instance.setMode(mode);
        FlutterFlowTheme.saveThemeMode(mode);
      });

  @override
  Widget build(BuildContext context) {
    final resolved = switch (_themeMode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => WidgetsBinding.instance.platformDispatcher.platformBrightness,
    };
    TGThemeController.instance.syncFromTheme(resolved);
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FakeAuthState(isLoggedIn: kMockSignedInByDefault)),
        ChangeNotifierProvider<ModerationService>.value(value: ModerationService.instance),
        ChangeNotifierProvider<AdminLocaleState>.value(value: AdminLocaleState.instance),
        ChangeNotifierProvider<DealService>.value(value: DealService.instance),
        ChangeNotifierProvider<DealModerationService>.value(value: DealModerationService.instance),
        ChangeNotifierProvider<NotificationService>.value(value: NotificationService.instance),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'Twoja Gastromania',
        scrollBehavior: MyAppScrollBehavior(),
        localizationsDelegates: [
          FFLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          FallbackMaterialLocalizationDelegate(),
          FallbackCupertinoLocalizationDelegate(),
        ],
        locale: _locale,
        supportedLocales: kSupportedLocales,
        localeResolutionCallback: resolveAppLocale,
        theme: buildTGLightTheme(),
        darkTheme: buildTGDarkTheme(),
        themeMode: _themeMode,
        themeAnimationDuration: Duration.zero,
        routerConfig: _router,
        builder: (context, child) {
          TGThemeController.instance.syncFromTheme(Theme.of(context).brightness);
          return ListenableBuilder(
            listenable: Listenable.merge([TGI18nAudit.instance, TGThemeController.instance]),
            builder: (context, _) => TGI18nAuditOverlay(
              child: Scaffold(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                body: child ?? const SizedBox.shrink(),
              ),
            ),
          );
        },
      ),
    );
  }
}
