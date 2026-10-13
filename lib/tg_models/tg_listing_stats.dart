import 'package:flutter/foundation.dart';

enum ListingStatKind { view, callTap, message, favorite }

DateTime tgStatsDay(DateTime t) => DateTime(t.year, t.month, t.day);

/// One listing, one calendar day. Counts follow the DASH-1 rules: views are
/// unique per visitor per day, owner and staff traffic is never counted,
/// favorites count new saves (removing a favorite does not subtract).
@immutable
class ListingStatsDaily {
  const ListingStatsDaily({
    required this.listingKey,
    required this.day,
    this.views = 0,
    this.callTaps = 0,
    this.messages = 0,
    this.favorites = 0,
    this.isMock = false,
  });

  final String listingKey;
  final DateTime day;
  final int views;
  final int callTaps;
  final int messages;
  final int favorites;
  final bool isMock;

  int of(ListingStatKind kind) => switch (kind) {
        ListingStatKind.view => views,
        ListingStatKind.callTap => callTaps,
        ListingStatKind.message => messages,
        ListingStatKind.favorite => favorites,
      };

  ListingStatsDaily bump(ListingStatKind kind, [int by = 1]) => ListingStatsDaily(
        listingKey: listingKey,
        day: day,
        views: views + (kind == ListingStatKind.view ? by : 0),
        callTaps: callTaps + (kind == ListingStatKind.callTap ? by : 0),
        messages: messages + (kind == ListingStatKind.message ? by : 0),
        favorites: favorites + (kind == ListingStatKind.favorite ? by : 0),
        isMock: isMock,
      );

  Map<String, Object?> toJson() => {
        'listingKey': listingKey,
        'day': day.toIso8601String().substring(0, 10),
        'views': views,
        'callTaps': callTaps,
        'messages': messages,
        'favorites': favorites,
      };
}

@immutable
class ListingStatsTotals {
  const ListingStatsTotals({this.views = 0, this.callTaps = 0, this.messages = 0, this.favorites = 0});

  static const zero = ListingStatsTotals();

  final int views;
  final int callTaps;
  final int messages;
  final int favorites;

  int of(ListingStatKind kind) => switch (kind) {
        ListingStatKind.view => views,
        ListingStatKind.callTap => callTaps,
        ListingStatKind.message => messages,
        ListingStatKind.favorite => favorites,
      };

  ListingStatsTotals operator +(ListingStatsDaily d) => ListingStatsTotals(
        views: views + d.views,
        callTaps: callTaps + d.callTaps,
        messages: messages + d.messages,
        favorites: favorites + d.favorites,
      );

  ListingStatsTotals plus(ListingStatsTotals o) => ListingStatsTotals(
        views: views + o.views,
        callTaps: callTaps + o.callTaps,
        messages: messages + o.messages,
        favorites: favorites + o.favorites,
      );
}

/// "During promotion vs the 14 days before" — per-day averages, never a forecast.
@immutable
class PromotionComparison {
  const PromotionComparison({
    required this.duringDays,
    required this.beforeDays,
    required this.during,
    required this.before,
    required this.enoughData,
  });

  final int duringDays;
  final int beforeDays;
  final ListingStatsTotals during;
  final ListingStatsTotals before;
  final bool enoughData;

  double perDay(ListingStatKind kind, {required bool promoted}) {
    final days = promoted ? duringDays : beforeDays;
    if (days <= 0) return 0;
    return (promoted ? during : before).of(kind) / days;
  }
}
