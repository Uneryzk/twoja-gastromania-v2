import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';

/// Missing-key log + Language-audit flag (dev/profile only).
///
/// Release builds send [TGAnalytics] `i18n_missing_key` (hook Crashlytics via
/// [onMissing] when a tracker is added — no extra package today).
class TGI18nAudit extends ChangeNotifier {
  TGI18nAudit._();
  static final TGI18nAudit instance = TGI18nAudit._();

  static const markerPrefix = '⚠ ';

  /// Optional sink for release missing-key reports (Crashlytics/Sentry later).
  static void Function(String key, String locale)? onMissing;

  bool _requested = false;
  final Set<String> _logged = {};
  final List<String> missingKeys = [];
  final Set<String> resolvedThisFrame = {};

  bool get enabled =>
      _requested &&
      !TGRevenueConfigService.instance.productionMode &&
      (kDebugMode || kProfileMode);

  bool get requested => _requested;

  void setEnabled(bool value) {
    _requested = value;
    notifyListeners();
  }

  void reset() {
    _requested = false;
    _logged.clear();
    missingKeys.clear();
    resolvedThisFrame.clear();
    notifyListeners();
  }

  void beginFrame() => resolvedThisFrame.clear();

  void markResolved(String text) {
    if (text.isEmpty) return;
    resolvedThisFrame.add(text);
  }

  /// Logs once per key+locale. Debug/profile also keep [missingKeys] for the overlay.
  void reportMissing(String key, String locale) {
    final id = '$key@$locale';
    if (!_logged.add(id)) return;
    missingKeys.add(id);
    debugPrint('I18N missing: $key ($locale)');
    TGAnalytics.track('i18n_missing_key', {'key': key, 'locale': locale});
    onMissing?.call(key, locale);
    notifyListeners();
  }
}

/// Lookup used by [FFLocalizations.getText] and [DurationFormatter].
String resolveI18nText({
  required String key,
  required String languageCode,
  required Map<String, String>? map,
  required bool debugOrProfile,
}) {
  if (map == null || map.isEmpty) {
    TGI18nAudit.instance.reportMissing(key, languageCode);
    if (debugOrProfile) return '${TGI18nAudit.markerPrefix}$key';
    return '';
  }
  final localized = map[languageCode];
  if (localized != null && localized.isNotEmpty) return localized;
  TGI18nAudit.instance.reportMissing(key, languageCode);
  if (debugOrProfile) return '${TGI18nAudit.markerPrefix}$key';
  return map['en'] ?? map['pl'] ?? '';
}
