import 'package:flutter/widgets.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';

/// Lightweight in-memory event log for listing, checkout and PDP flows.
abstract final class TGAnalytics {
  static final List<(String, Map<String, Object?>)> events = [];
  static bool offline = false;

  static void track(String name, [Map<String, Object?> props = const {}]) {
    events.add((name, props));
  }

  static void emit(String name, [Map<String, Object?> props = const {}]) => track(name, props);

  static void clear() {
    events.clear();
  }

  static void reset() {
    events.clear();
    offline = false;
  }

  static bool has(String name) => events.any((e) => e.$1 == name);

  static Map<String, Object?> listingProps(TGProduct product) => {
        'id': product.id,
        'listingNo': product.listingNo,
        'status': product.status.name,
      };
}

bool tgInWidgetTest() {
  final name = WidgetsBinding.instance.runtimeType.toString();
  return name.contains('Test');
}

bool tgReduceMotion(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;

Duration tgAnim(BuildContext context, Duration d) => tgReduceMotion(context) ? Duration.zero : d;
