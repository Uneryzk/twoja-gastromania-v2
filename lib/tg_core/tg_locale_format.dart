import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';

/// Locale tags for `intl` formatters (pl-PL, tr-TR, en).
///
/// [TGFormat] is the name used in I18N-3 copy; it is this class, not a second system.
typedef TGFormat = TGLocaleFormat;

abstract final class TGLocaleFormat {
  static String tag(Locale locale) {
    switch (locale.languageCode) {
      case 'pl':
        return 'pl_PL';
      case 'tr':
        return 'tr_TR';
      default:
        return locale.countryCode == null || locale.countryCode!.isEmpty
            ? locale.languageCode
            : '${locale.languageCode}_${locale.countryCode}';
    }
  }

  static String tagOf(BuildContext context) => tag(Localizations.localeOf(context));

  static String date(DateTime d, Locale locale, {String pattern = 'd MMM y'}) =>
      DateFormat(pattern, tag(locale)).format(d);

  static String dateOf(BuildContext context, DateTime d, {String pattern = 'd MMM y'}) =>
      date(d, Localizations.localeOf(context), pattern: pattern);

  static String number(num n, Locale locale) => NumberFormat.decimalPattern(tag(locale)).format(n);

  static String numberOf(BuildContext context, num n) => number(n, Localizations.localeOf(context));

  /// Marketplace currency stays PLN; grouping/decimal follow [locale].
  static String moneyPln(num n, Locale locale) => '${number(n, locale)} PLN';

  static String moneyPlnOf(BuildContext context, num n) => moneyPln(n, Localizations.localeOf(context));

  /// `/ ay` · `/ mo` · `/ mies.` from `ui_slash_mo`.
  static String perMonthUnit(Locale locale) => FFLocalizations(locale).getText('ui_slash_mo');

  static String perMonthUnitOf(BuildContext context) => context.t('ui_slash_mo');

  /// `PLN/day` · `PLN/dzień` · `PLN/gün` from `ui_pln_per_day`.
  static String perDayUnit(Locale locale) => FFLocalizations(locale).getText('ui_pln_per_day');

  static String perDayUnitOf(BuildContext context) => context.t('ui_pln_per_day');
}
