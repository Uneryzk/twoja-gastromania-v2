import 'package:twoja_gastromania/tg_core/duration_formatter.dart';
import 'package:twoja_gastromania/tg_core/tg_i18n_audit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tg_l10n.dart';

const _kLocaleStorageKey = '__locale_key__';

/// Languages the marketplace ships with. English is the fallback for every
/// other device locale (see [resolveAppLocale]).
const kSupportedLocales = <Locale>[
  Locale('pl'), // Polish
  Locale('en'), // English (default)
  Locale('tr'), // Turkish
  Locale('de'), // German
  Locale('cs'), // Czech
  Locale('sk'), // Slovak
  Locale('uk'), // Ukrainian
  Locale('be'), // Belarusian
  Locale('lt'), // Lithuanian
  Locale('ru'), // Russian
];

/// Picks a supported language from the device locale, otherwise English.
Locale resolveAppLocale(Locale? deviceLocale, Iterable<Locale> supportedLocales) {
  if (deviceLocale != null) {
    for (final supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == deviceLocale.languageCode) {
        return supportedLocale;
      }
    }
  }
  return const Locale('en');
}

class FFLocalizations {
  FFLocalizations(this.locale);

  final Locale locale;

  static FFLocalizations of(BuildContext context) =>
      Localizations.of<FFLocalizations>(context, FFLocalizations)!;

  static List<String> languages() =>
      kSupportedLocales.map((l) => l.languageCode).toList(growable: false);

  static late SharedPreferences _prefs;
  static Future initialize() async =>
      _prefs = await SharedPreferences.getInstance();
  static Future storeLocale(String locale) =>
      _prefs.setString(_kLocaleStorageKey, locale);
  static Locale? getStoredLocale() {
    final locale = _prefs.getString(_kLocaleStorageKey);
    return locale != null && locale.isNotEmpty ? createLocale(locale) : null;
  }

  String get languageCode => locale.toString();
  String? get languageShortCode =>
      _languagesWithShortCode.contains(locale.toString())
          ? '${locale.toString()}_short'
          : null;
  int get languageIndex => languages().contains(languageCode)
      ? languages().indexOf(languageCode)
      : 0;

  /// True when [key] has a non-empty value for this locale (no EN fallback).
  bool hasText(String key) {
    final map = kTranslationsMap[key];
    if (map == null) return false;
    final raw = map[locale.toString()] ?? map[locale.languageCode];
    return raw != null && raw.isNotEmpty;
  }

  /// Like [getText] but `null` when the active language has no row (no ⚠, no EN).
  String? tryText(String key, [Map<String, String>? params]) {
    if (!hasText(key)) return null;
    return getText(key, params);
  }

  String getText(String key, [Map<String, String>? params]) {
    final map = kTranslationsMap[key];
    final code = locale.languageCode;
    final debugOrProfile = kDebugMode || kProfileMode;
    var text = resolveI18nText(
      key: key,
      languageCode: code,
      map: map == null
          ? null
          : {
              code: map[locale.toString()] ?? map[code] ?? '',
              if (map['en'] != null) 'en': map['en']!,
              if (map['pl'] != null) 'pl': map['pl']!,
            },
      debugOrProfile: debugOrProfile,
    );
    if (text.startsWith(TGI18nAudit.markerPrefix)) return text;
    if (text.contains(', plural,')) {
      text = DurationFormatter.formatIcu(text, code, {...?params});
    } else if (params != null) {
      params.forEach((name, value) {
        text = text.replaceAll('{$name}', value);
      });
    }
    TGI18nAudit.instance.markResolved(text);
    return text;
  }

  String getVariableText({
    String? plText = '',
    String? enText = '',
  }) {
    switch (locale.languageCode) {
      case 'pl':
        return plText ?? '';
      default:
        return enText ?? '';
    }
  }

  static const Set<String> _languagesWithShortCode = {
    'ar',
    'az',
    'ca',
    'cs',
    'da',
    'de',
    'dv',
    'en',
    'es',
    'et',
    'fi',
    'fr',
    'gr',
    'he',
    'hi',
    'hu',
    'it',
    'km',
    'ku',
    'mn',
    'ms',
    'no',
    'pt',
    'ro',
    'ru',
    'rw',
    'sk',
    'sv',
    'th',
    'tr',
    'uk',
    'vi',
    'be',
    'lt',
  };
}

/// Used if the locale is not supported by GlobalMaterialLocalizations.
class FallbackMaterialLocalizationDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const FallbackMaterialLocalizationDelegate();

  @override
  bool isSupported(Locale locale) => _isSupportedLocale(locale);

  @override
  Future<MaterialLocalizations> load(Locale locale) async =>
      SynchronousFuture<MaterialLocalizations>(
        const DefaultMaterialLocalizations(),
      );

  @override
  bool shouldReload(FallbackMaterialLocalizationDelegate old) => false;
}

/// Used if the locale is not supported by GlobalCupertinoLocalizations.
class FallbackCupertinoLocalizationDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const FallbackCupertinoLocalizationDelegate();

  @override
  bool isSupported(Locale locale) => _isSupportedLocale(locale);

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      SynchronousFuture<CupertinoLocalizations>(
        const DefaultCupertinoLocalizations(),
      );

  @override
  bool shouldReload(FallbackCupertinoLocalizationDelegate old) => false;
}

class FFLocalizationsDelegate extends LocalizationsDelegate<FFLocalizations> {
  const FFLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => _isSupportedLocale(locale);

  @override
  Future<FFLocalizations> load(Locale locale) =>
      SynchronousFuture<FFLocalizations>(FFLocalizations(locale));

  @override
  bool shouldReload(FFLocalizationsDelegate old) => false;
}

Locale createLocale(String language) => language.contains('_')
    ? Locale.fromSubtags(
        languageCode: language.split('_').first,
        scriptCode: language.split('_').last,
      )
    : Locale(language);

bool _isSupportedLocale(Locale locale) =>
    FFLocalizations.languages().contains(locale.languageCode);

/// `context.t('ui_buy')` — chrome copy from [kUiTranslations] / FlutterFlow keys.
extension FFLocalizationsContext on BuildContext {
  String t(String key, [Map<String, String>? params]) =>
      FFLocalizations.of(this).getText(key, params);

  String? tryT(String key, [Map<String, String>? params]) =>
      FFLocalizations.of(this).tryText(key, params);
}

String localizedResultsCount(BuildContext context, int n) =>
    n == 1 ? context.t('ui_result_one') : context.t('ui_result_other', {'n': '$n'});

final kTranslationsMap = mergeTranslations(<Map<String, Map<String, String>>>[
  // HomePage
  {
    'nrljftmk': {
      'pl': 'Equipment name ',
      'en': 'Equipment name',
    },
    '5303zvt8': {
      'pl': 'Log in',
      'en': 'Log in',
    },
    'iq4uz3b3': {
      'pl': 'Add Product\n',
      'en': 'Add Product',
    },
    'x5fioudz': {
      'pl': 'For sale',
      'en': 'For sale',
    },
    '0loae64d': {
      'pl': 'For sale',
      'en': 'For sale',
    },
    'uyxzh0mp': {
      'pl': 'For rent',
      'en': 'For rent',
    },
    '9db86pnc': {
      'pl': '=',
      'en': '=',
    },
    '46ywvsmm': {
      'pl': 'Search...',
      'en': 'Search...',
    },
    'iunpzsdr': {
      'pl': 'Rest. for Sale',
      'en': 'Rest. for Sale',
    },
    'sye4ck7e': {
      'pl': 'Special Order',
      'en': 'Special Order',
    },
    'khghgwp2': {
      'pl': 'Commercial Kitchen Costs',
      'en': 'Commercial Kitchen Costs',
    },
    'kakjdyeu': {
      'pl':
          'What factors contribute to the profitability of a food and beverage business?',
      'en':
          'What factors contribute to the profitability of a food and beverage business?',
    },
    'dmckn6aq': {
      'pl': 'Today\'s Special Offer',
      'en': 'Today\'s Special Offer',
    },
    'uempq43k': {
      'pl':
          'Running a profitable restaurant business requires not only delicious food, but also good management, financial control, and meeting customer expectations.',
      'en':
          'Running a profitable restaurant business requires not only delicious food, but also good management, financial control, and meeting customer expectations.',
    },
    'oteusqk7': {
      'pl': 'Kitchen Equipment',
      'en': 'Kitchen Equipment',
    },
    'c9w49cnd': {
      'pl': 'to offer a unique product or serviceess?',
      'en': 'to offer a unique product or serviceess?',
    },
    '2pfq6uxe': {
      'pl': 'Golden Tips For Bar Setups',
      'en': 'Golden Tips For Bar Setups',
    },
    'ha3jf9ll': {
      'pl':
          'What factors contribute to the profitability of a food and beverage business?',
      'en':
          'What factors contribute to the profitability of a food and beverage business?',
    },
    '76kthqx7': {
      'pl': 'For sale',
      'en': 'For sale',
    },
    'xnqnc4k5': {
      'pl': 'Add Product\n',
      'en': 'Add Product',
    },
    'ay1m6ate': {
      'pl': 'For rent',
      'en': 'For rent',
    },
    'sijfpcvb': {
      'pl': 'Restaurants for Sale',
      'en': 'Restaurants for Sale',
    },
    'j7ebtgo7': {
      'pl': 'Special Order\n',
      'en': 'Special Order',
    },
    'i8m5wr2h': {
      'pl': 'Commercial Kitchen Costs',
      'en': 'Commercial Kitchen Costs',
    },
    '7d6qkq0f': {
      'pl':
          'What factors contribute to the profitability of a food and beverage business?',
      'en':
          'What factors contribute to the profitability of a food and beverage business?',
    },
    '0y0mdwe3': {
      'pl': 'Today\'s Special Offer',
      'en': 'Today\'s Special Offer',
    },
    'gn0cgz8h': {
      'pl':
          'Running a profitable restaurant business requires not only delicious food, but also good management, financial control, and meeting customer expectations.',
      'en':
          'Running a profitable restaurant business requires not only delicious food, but also good management, financial control, and meeting customer expectations.',
    },
    'z2t2enej': {
      'pl': 'Kitchen Equipment',
      'en': 'Kitchen Equipment',
    },
    'yhrj1i0w': {
      'pl': 'to offer a unique product or servicess?',
      'en': 'to offer a unique product or services?',
    },
    'fd2vmdbm': {
      'pl': 'Golden Tips For Bar Setups',
      'en': 'Golden Tips For Bar Setups',
    },
    'ghe86x4x': {
      'pl':
          'What factors contribute to the profitability of a food and beverage business?',
      'en':
          'What factors contribute to the profitability of a food and beverage business?',
    },
    'aqgybebk': {
      'pl': 'REFRIGERATED PREPARATION STATION',
      'en': 'REFRIGERATED PREPARATION STATION',
    },
    't55ke7l3': {
      'pl': '12',
      'en': '12',
    },
    '88dfqvdt': {
      'pl': 'Rybnik',
      'en': 'Rybnik',
    },
    'tyqvfdlg': {
      'pl': 'Electric',
      'en': 'Electric',
    },
    'ppbzaye2': {
      'pl': ' +48 (532) 784-074',
      'en': '+48 (532) 784-074',
    },
    '5l4h3wu9': {
      'pl': 'Electric Deck Pizza Oven Ideal for pizzerias, \nrestaurants, ',
      'en': 'Electric Deck Pizza Oven Ideal for pizzerias, \nrestaurants,',
    },
    'umjsrm15': {
      'pl': '12',
      'en': '12',
    },
    'qp384ho7': {
      'pl': 'Katowice',
      'en': 'Katowice',
    },
    'xwirrqt8': {
      'pl': 'Electric',
      'en': 'Electric',
    },
    '9cgbzuxc': {
      'pl': ' +48 (532) 784-074',
      'en': '+48 (532) 784-074',
    },
    'yzc25hk4': {
      'pl':
          'Refrigerated Bar Station Integrated \nrefrigeration for ingredients and beverages.',
      'en':
          'Refrigerated Bar Station Integrated \nrefrigeration for ingredients and beverages.',
    },
    'tnyfuoqm': {
      'pl': '12',
      'en': '12',
    },
    'x6jpa9tr': {
      'pl': 'Warsowa',
      'en': 'Warsowa',
    },
    's7g9syzg': {
      'pl': 'Electric',
      'en': 'Electric',
    },
    'd782wr2l': {
      'pl': ' +48 (532) 784-074',
      'en': '+48 (532) 784-074',
    },
    '47njv3h2': {
      'pl': 'Professional 2-group espresso machine with\nsteam wand, 230 V',
      'en': 'Professional 2-group espresso machine with\nsteam wand, 230 V',
    },
    'zgxiwgzo': {
      'pl': '12',
      'en': '12',
    },
    'yxejlic0': {
      'pl': 'Wroclow',
      'en': 'Wroclaw',
    },
    '9rrf1elm': {
      'pl': 'Electric',
      'en': 'Electric',
    },
    'bg7wx26t': {
      'pl': ' +48 (532) 784-074',
      'en': '+48 (532) 784-074',
    },
    'l2bcp2lt': {
      'pl': 'REFRIGERATED PREPARATION STATION',
      'en': 'REFRIGERATED PREPARATION STATION',
    },
    'a1cuff63': {
      'pl': '12',
      'en': '12',
    },
    't6s4ztvh': {
      'pl': 'RYBNIK',
      'en': 'Rybnik',
    },
    'qavnhw0p': {
      'pl': 'Gas',
      'en': 'Gas',
    },
    'a4y5cxzk': {
      'pl': ' +48 (532) 784-074',
      'en': '+48 (532) 784-074',
    },
    '5w70mdov': {
      'pl': 'Featured Offers',
      'en': 'Featured Offers',
    },
    '3u75e0ef': {
      'pl': 'The best deals on new and used food service equipment.',
      'en': 'The best deals on new and used food service equipment.',
    },
    'yaxeeep1': {
      'pl': 'Featured Offers',
      'en': 'Featured Offers',
    },
    '83vfx3yz': {
      'pl': 'The best deals on new and\n used food service equipment.',
      'en': 'The best deals on new and\n used food service equipment.',
    },
    'jcoz0j60': {
      'pl': 'Featured Offers',
      'en': 'Featured Offers',
    },
    '32tshi4e': {
      'pl': 'The best deals on new and\n used food service equipment.',
      'en': 'The best deals on new and\n used food service equipment.',
    },
    'ji98dehm': {
      'pl': 'Cooking Equipment',
      'en': 'Cooking Equipment',
    },
    'swrjjpbp': {
      'pl': 'Refrigeration Equipment',
      'en': 'Refrigeration Equipment',
    },
    'lcx4dovc': {
      'pl': 'Warewashing',
      'en': 'Warewashing',
    },
    '71nup2wm': {
      'pl': 'Food Preparation',
      'en': 'Food Preparation',
    },
    '56pbhr1s': {
      'pl': 'Stainless Steel Furniture',
      'en': 'Stainless Steel Furniture',
    },
    'viy2skiv': {
      'pl': 'Bar & Beverage Equipment',
      'en': 'Bar & Beverage Equipment',
    },
    '88t2wvuj': {
      'pl': 'Best Sellers',
      'en': 'Best Sellers',
    },
    '21twf2jq': {
      'pl':
          'The most trusted names in gastronomy. \nDiscover high-rated sellers verified by our community for secure and seamless deals.',
      'en':
          'The most trusted names in gastronomy. \nDiscover high-rated sellers verified by our community for secure and seamless deals.',
    },
    'iudua9mi': {
      'pl': 'Verified Seller',
      'en': 'Verified Seller',
    },
    'g89e8jcq': {
      'pl': 'Products',
      'en': 'Products',
    },
    '67iyx99z': {
      'pl': '5',
      'en': '5',
    },
    '7gubhem3': {
      'pl': 'Verified Seller',
      'en': 'Verified Seller',
    },
    '59oi91um': {
      'pl': 'Products',
      'en': 'Products',
    },
    'zocd7hsh': {
      'pl': '3',
      'en': '3',
    },
    'l2ozfxa6': {
      'pl': 'Verified Seller',
      'en': 'Verified Seller',
    },
    '07sg5qrr': {
      'pl': 'Products',
      'en': 'Products',
    },
    'r4e3jewk': {
      'pl': '8',
      'en': '8',
    },
    'jjq4vbsg': {
      'pl': 'Verified Seller',
      'en': 'Verified Seller',
    },
    '4ty1zusx': {
      'pl': 'Products',
      'en': 'Products',
    },
    'dlos29c5': {
      'pl': '2',
      'en': '2',
    },
    'lpytiz0d': {
      'pl': 'Verified Seller',
      'en': 'Verified Seller',
    },
    's08tmskc': {
      'pl': 'Products',
      'en': 'Products',
    },
    'qnfbxx21': {
      'pl': '2',
      'en': '2',
    },
    'fyq8srxv': {
      'pl': 'Verified Seller',
      'en': 'Verified Seller',
    },
    'qovk7g7v': {
      'pl': 'Products',
      'en': 'Products',
    },
    'vw6p1k65': {
      'pl': '5',
      'en': '5',
    },
    '6z9sh9z6': {
      'pl': 'Verified Seller',
      'en': 'Verified Seller',
    },
    'wfr70oun': {
      'pl': 'Products',
      'en': 'Products',
    },
    's9885ajm': {
      'pl': '5',
      'en': '5',
    },
    'dkz7hccx': {
      'pl': 'Active Users  Right Now',
      'en': 'Active Users Right Now',
    },
    'p15aunky': {
      'pl': 'Total Registered Businesses',
      'en': 'Total Registered Businesses',
    },
    'z9mxi2df': {
      'pl': '650',
      'en': '650',
    },
    'b81eez74': {
      'pl': 'Products & Equipment Listed',
      'en': 'Products & Equipment Listed',
    },
    '38ja0yke': {
      'pl': '1426',
      'en': '1426',
    },
    'eio1zib0': {
      'pl': '24h \nPage Visits',
      'en': '24h\nPage Visits',
    },
    'yyxm78jg': {
      'pl': '281',
      'en': '281',
    },
    'cbffymcc': {
      'pl': 'Twoja Gastromonia',
      'en': 'Your Gastronomy',
    },
    '4u93q9h1': {
      'pl': 'Equipment name - Brand',
      'en': 'Equipment name - Brand',
    },
    'jjbaftm6': {
      'pl': 'Log in',
      'en': 'Log in',
    },
    '63ofn1a4': {
      'pl': 'Home',
      'en': 'Home',
    },
  },
  // BirinciReklamSayfasi
  {
    'o7xd1sjn': {
      'pl': 'For sale',
      'en': 'For sale',
    },
    'au4lv5on': {
      'pl': 'Add Product\n',
      'en': 'Add Product',
    },
    'vxngjlo2': {
      'pl': 'For rent',
      'en': 'For rent',
    },
    '25fyjd0b': {
      'pl': 'Restaurants for Sale',
      'en': 'Restaurants for Sale',
    },
    'mlw53iyj': {
      'pl': 'Special Order\n',
      'en': 'Special Order',
    },
    '7qu6uj5f': {
      'pl': 'Equipment name ',
      'en': 'Equipment name',
    },
    'w2dwtd94': {
      'pl': 'Log in',
      'en': 'Log in',
    },
    '5mtqglf8': {
      'pl': 'Add Product\n',
      'en': 'Add Product',
    },
    'vrnvrzc2': {
      'pl': 'For sale',
      'en': 'For sale',
    },
    't8itc4zt': {
      'pl': 'For sale',
      'en': 'For sale',
    },
    'e471tjoy': {
      'pl': 'For rent',
      'en': 'For rent',
    },
    'w4z01j2y': {
      'pl': '=',
      'en': '=',
    },
    '6bqlf0br': {
      'pl': 'Search...',
      'en': 'Search...',
    },
    'ez9byhwt': {
      'pl': 'Rest. for Sale',
      'en': 'Rest. for Sale',
    },
    'kwg92828': {
      'pl': 'Special Order',
      'en': 'Special Order',
    },
    'dlqzxlbc': {
      'pl': '\"This advertising page will be active soon!\"',
      'en': '\"This advertising page will be active soon!\"',
    },
    '20976tzx': {
      'pl': 'Home',
      'en': 'Home',
    },
  },
  // ikinciReklamSayfasi
  {
    'tnokr5xa': {
      'pl': 'Twoja Gastromonia',
      'en': 'Your Gastronomy',
    },
    '8yl5pps4': {
      'pl': 'For sale',
      'en': 'For sale',
    },
    'oxuc635r': {
      'pl': 'Add Product\n',
      'en': 'Add Product',
    },
    'cpih39gi': {
      'pl': 'For rent',
      'en': 'For rent',
    },
    'q4sa20zm': {
      'pl': 'Restaurants for Sale',
      'en': 'Restaurants for Sale',
    },
    '1wlzqmd4': {
      'pl': 'Special Order\n',
      'en': 'Special Order',
    },
    'pujmtcid': {
      'pl': 'Equipment name ',
      'en': 'Equipment name',
    },
    'rnzlc76f': {
      'pl': 'Log in',
      'en': 'Log in',
    },
    'zdgqeclk': {
      'pl': 'Add Product\n',
      'en': 'Add Product',
    },
    'm0r15zel': {
      'pl': 'For sale',
      'en': 'For sale',
    },
    'juy1o8vy': {
      'pl': 'For sale',
      'en': 'For sale',
    },
    'bt6xvzwo': {
      'pl': 'For rent',
      'en': 'For rent',
    },
    '8ososa0n': {
      'pl': '=',
      'en': '=',
    },
    '26gk2tw0': {
      'pl': 'Search...',
      'en': 'Search...',
    },
    'o0m6z84m': {
      'pl': 'Rest. for Sale',
      'en': 'Rest. for Sale',
    },
    'gi9u2us2': {
      'pl': 'Special Order',
      'en': 'Special Order',
    },
    '12y5ugqc': {
      'pl': '\"This advertising page will be active soon!\"',
      'en': '\"This advertising page will be active soon!\"',
    },
    'vtsxlyrl': {
      'pl': 'Home',
      'en': 'Home',
    },
  },
  // UcuncuReklamSayfasi
  {
    '6etf37ml': {
      'pl': 'For sale',
      'en': 'For sale',
    },
    '27crp9jm': {
      'pl': 'Add Product\n',
      'en': 'Add Product',
    },
    '1dj4026m': {
      'pl': 'For rent',
      'en': 'For rent',
    },
    'dse9kwrm': {
      'pl': 'Restaurants for Sale',
      'en': 'Restaurants for Sale',
    },
    'xni8isgr': {
      'pl': 'Special Order\n',
      'en': 'Special Order',
    },
    'jarfuz0t': {
      'pl': 'Equipment name ',
      'en': 'Equipment name',
    },
    'yrbrz1jd': {
      'pl': 'Log in',
      'en': 'Log in',
    },
    'o05vvawl': {
      'pl': 'Add Product\n',
      'en': 'Add Product',
    },
    'bgh1mx16': {
      'pl': 'For sale',
      'en': 'For sale',
    },
    'e3amhf7n': {
      'pl': 'For sale',
      'en': 'For sale',
    },
    '23nhkzhd': {
      'pl': 'For rent',
      'en': 'For rent',
    },
    'axkruyym': {
      'pl': '=',
      'en': '=',
    },
    '23qc5i3e': {
      'pl': 'Search...',
      'en': 'Search...',
    },
    '0ea2dpwc': {
      'pl': 'Rest. for Sale',
      'en': 'Rest. for Sale',
    },
    '9me9cojr': {
      'pl': 'Special Order',
      'en': 'Special Order',
    },
    'oib93k7r': {
      'pl': '\"This advertising page will be active soon!\"',
      'en': '\"This advertising page will be active soon!\"',
    },
    '8v7hhhsu': {
      'pl': 'Twoja Gastromonia',
      'en': 'Your Gastronomy',
    },
    '6re77w1s': {
      'pl': 'Home',
      'en': 'Home',
    },
  },
  // DortuncuReklamSayfasi
  {
    'pv0lisaf': {
      'pl': 'For sale',
      'en': 'For sale',
    },
    'udbfvg3a': {
      'pl': 'Add Product\n',
      'en': 'Add Product',
    },
    'i0r5mu12': {
      'pl': 'For rent',
      'en': 'For rent',
    },
    'f5p5n0cp': {
      'pl': 'Restaurants for Sale',
      'en': 'Restaurants for Sale',
    },
    'kby504r4': {
      'pl': 'Special Order\n',
      'en': 'Special Order',
    },
    'm8a9s7qf': {
      'pl': 'Equipment name ',
      'en': 'Equipment name',
    },
    'inx41xc2': {
      'pl': 'Log in',
      'en': 'Log in',
    },
    'n82svq5m': {
      'pl': 'Add Product\n',
      'en': 'Add Product',
    },
    'seysxujz': {
      'pl': 'For sale',
      'en': 'For sale',
    },
    '5ar55al9': {
      'pl': 'For sale',
      'en': 'For sale',
    },
    'kuhwqpgw': {
      'pl': 'For rent',
      'en': 'For rent',
    },
    'khg7r2xk': {
      'pl': '=',
      'en': '=',
    },
    'bzn0a3mp': {
      'pl': 'Search...',
      'en': 'Search...',
    },
    '8ftowg17': {
      'pl': 'Rest. for Sale',
      'en': 'Rest. for Sale',
    },
    'hfv8t9st': {
      'pl': 'Special Order',
      'en': 'Special Order',
    },
    '48nowz7l': {
      'pl': '\"This advertising page will be active soon!\"',
      'en': '\"This advertising page will be active soon!\"',
    },
    '0z2fv7bx': {
      'pl': 'Twoja Gastromonia',
      'en': 'Your Gastronomy',
    },
    '1c6hbmjq': {
      'pl': 'Home',
      'en': 'Home',
    },
  },
  // Miscellaneous
  {
    'z3im3x1a': {
      'pl': '',
      'en': '',
    },
    'unks9890': {
      'pl': '',
      'en': '',
    },
    '567wb5xd': {
      'pl': '',
      'en': '',
    },
    'amg4i2nj': {
      'pl': '',
      'en': '',
    },
    'hfx1r4d7': {
      'pl': '',
      'en': '',
    },
    'eidncq08': {
      'pl': '',
      'en': '',
    },
    'dll7yphp': {
      'pl': '',
      'en': '',
    },
    'qs56u1ws': {
      'pl': '',
      'en': '',
    },
    'i2o5rdtm': {
      'pl': '',
      'en': '',
    },
    'ngrtlgp1': {
      'pl': '',
      'en': '',
    },
    'mwg94zfd': {
      'pl': '',
      'en': '',
    },
    '2jd991ai': {
      'pl': '',
      'en': '',
    },
    'm2eito7z': {
      'pl': '',
      'en': '',
    },
    'nkz1ozv3': {
      'pl': '',
      'en': '',
    },
    '4yyvv51e': {
      'pl': '',
      'en': '',
    },
    's9jezhqj': {
      'pl': '',
      'en': '',
    },
    'ffw5gkb7': {
      'pl': '',
      'en': '',
    },
    'd74runx0': {
      'pl': '',
      'en': '',
    },
    'yzz66u4c': {
      'pl': '',
      'en': '',
    },
    'n96b7o7s': {
      'pl': '',
      'en': '',
    },
    'wqldmbll': {
      'pl': '',
      'en': '',
    },
    '0ddi3qsq': {
      'pl': '',
      'en': '',
    },
    '43w8czrp': {
      'pl': '',
      'en': '',
    },
    'out7cfxl': {
      'pl': '',
      'en': '',
    },
    'vfz6pfyg': {
      'pl': '',
      'en': '',
    },
    '8phsikap': {
      'pl': '',
      'en': '',
    },
  },
]);
