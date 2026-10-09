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
import 'package:twoja_gastromania/tg_core/tg_theme.dart';
import 'package:twoja_gastromania/tg_services/deal_moderation_service.dart';
import 'package:twoja_gastromania/tg_services/deal_service.dart';
import 'package:twoja_gastromania/tg_services/moderation_service.dart';
import 'package:twoja_gastromania/tg_services/notification_service.dart';

import 'package:provider/provider.dart';

const _kStartupTimeout = Duration(seconds: 5);

/// The app has no backend yet, so the session is mocked. Starting signed in
/// shows the account pill ("2 free · 18 days left") in the global header; set
/// this to `false` to start as a logged-out visitor (header shows "Login").
const bool kMockSignedInByDefault = true;

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

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  // This widget is the root of your application.
  @override
  State<MyApp> createState() => _MyAppState();

  static _MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>()!;
}

class MyAppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}

class _MyAppState extends State<MyApp> {
  Locale? _locale;

  // Global dark theme per brand spec.
  ThemeMode _themeMode = ThemeMode.dark;

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

    _appStateNotifier = AppStateNotifier.instance;
    _router = createRouter(_appStateNotifier);
  }

  void setLocale(String language) {
    safeSetState(() => _locale = createLocale(language));
  }

  void setThemeMode(ThemeMode mode) => safeSetState(() {
        _themeMode = mode;
        FlutterFlowTheme.saveThemeMode(mode);
      });

  @override
  Widget build(BuildContext context) {
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
        theme: ThemeData(brightness: Brightness.light, useMaterial3: false),
        // Brand-styled Material widgets (inputs, sheets, snackbars, ...).
        darkTheme: buildTGDarkTheme(),
        themeMode: _themeMode,
        routerConfig: _router,
        builder: (context, child) => Scaffold(
          backgroundColor: DarkModeTheme().primaryBackground,
          body: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}
