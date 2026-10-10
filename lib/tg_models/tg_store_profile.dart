import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_special_order.dart';

enum TGStoreStatus { active, inactive, suspended }

enum TGStoreService {
  delivery,
  installation,
  service,
  leasing,
  fakturaVat,
  warrantyService,
}

const kStoreDayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

@immutable
class TGStoreHours {
  const TGStoreHours(this.byDay);
  final Map<String, String> byDay;

  String of(String day) => byDay[day] ?? 'closed';

  static String dayKey(int weekday) => kStoreDayKeys[(weekday - 1).clamp(0, 6)];

  TGStoreHours withDay(String day, String value) => TGStoreHours({...byDay, day: value});
}

/// Europe/Warsaw wall clock from UTC (CET/CEST).
DateTime warsawNow([DateTime? now]) {
  final utc = (now ?? DateTime.now()).toUtc();
  final offset = _warsawIsCest(utc) ? 2 : 1;
  return utc.add(Duration(hours: offset));
}

bool _warsawIsCest(DateTime utc) {
  DateTime lastSunday(int year, int month) {
    final last = DateTime.utc(year, month + 1, 0);
    return last.subtract(Duration(days: last.weekday % 7));
  }

  final start = lastSunday(utc.year, 3).add(const Duration(hours: 1));
  final end = lastSunday(utc.year, 10).add(const Duration(hours: 1));
  return !utc.isBefore(start) && utc.isBefore(end);
}

@immutable
class TGStoreOpenState {
  const TGStoreOpenState({required this.open, required this.labelEn, required this.nextDayKey, required this.nextTime});
  final bool open;
  final String labelEn;
  final String nextDayKey;
  final String nextTime;
}

TGStoreOpenState storeOpenState(TGStoreHours hours, [DateTime? now]) {
  final local = warsawNow(now);
  final todayKey = TGStoreHours.dayKey(local.weekday);
  final today = hours.of(todayKey);
  final mins = local.hour * 60 + local.minute;

  (int start, int end)? parseRange(String raw) {
    if (raw == 'closed' || raw.trim().isEmpty) return null;
    final parts = raw.split('-');
    if (parts.length != 2) return null;
    int toMin(String s) {
      final bits = s.trim().split(':');
      if (bits.length < 2) return 0;
      return (int.tryParse(bits[0]) ?? 0) * 60 + (int.tryParse(bits[1]) ?? 0);
    }
    return (toMin(parts[0]), toMin(parts[1]));
  }

  String fmt(int m) {
    final h = m ~/ 60;
    final mm = m % 60;
    if (mm == 0) return '$h:00';
    return '${h.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
  }

  final range = parseRange(today);
  if (range != null && mins >= range.$1 && mins < range.$2) {
    return TGStoreOpenState(open: true, labelEn: 'Open now · closes ${fmt(range.$2)}', nextDayKey: todayKey, nextTime: fmt(range.$2));
  }

  for (var i = 0; i < 7; i++) {
    final weekday = ((local.weekday - 1 + i) % 7) + 1;
    final key = TGStoreHours.dayKey(weekday);
    final r = parseRange(hours.of(key));
    if (r == null) continue;
    if (i == 0 && mins >= r.$2) continue;
    final dayLabel = i == 0 ? '' : '${key[0].toUpperCase()}${key.substring(1)} ';
    final openAt = fmt(r.$1);
    return TGStoreOpenState(
      open: false,
      labelEn: i == 0 ? 'Closed · opens $openAt' : 'Closed · opens ${dayLabel.trim()} $openAt'.replaceAll('  ', ' '),
      nextDayKey: key,
      nextTime: openAt,
    );
  }
  return const TGStoreOpenState(open: false, labelEn: 'Closed', nextDayKey: 'mon', nextTime: '8:00');
}

@immutable
class TGStoreProject {
  const TGStoreProject({
    required this.title,
    required this.city,
    required this.year,
    required this.photos,
    required this.description,
  });

  final String title;
  final String city;
  final int year;
  final List<String> photos;
  final String description;

  TGStoreProject copyWith({String? title, String? city, int? year, List<String>? photos, String? description}) =>
      TGStoreProject(
        title: title ?? this.title,
        city: city ?? this.city,
        year: year ?? this.year,
        photos: photos ?? this.photos,
        description: description ?? this.description,
      );
}

@immutable
class TGStoreSocial {
  const TGStoreSocial({this.facebook, this.instagram, this.linkedin, this.youtube});
  final String? facebook;
  final String? instagram;
  final String? linkedin;
  final String? youtube;

  bool get isEmpty => facebook == null && instagram == null && linkedin == null && youtube == null;

  TGStoreSocial copyWith({String? facebook, String? instagram, String? linkedin, String? youtube, bool clearFacebook = false, bool clearInstagram = false, bool clearLinkedin = false, bool clearYoutube = false}) =>
      TGStoreSocial(
        facebook: clearFacebook ? null : (facebook ?? this.facebook),
        instagram: clearInstagram ? null : (instagram ?? this.instagram),
        linkedin: clearLinkedin ? null : (linkedin ?? this.linkedin),
        youtube: clearYoutube ? null : (youtube ?? this.youtube),
      );
}

@immutable
class TGStoreProfile {
  const TGStoreProfile({
    required this.publicId,
    required this.slug,
    required this.sellerKey,
    required this.type,
    required this.name,
    required this.verified,
    required this.status,
    required this.phone,
    required this.city,
    required this.voivodeship,
    required this.memberSince,
    required this.rating,
    required this.reviewsCount,
    this.legalName,
    this.nip,
    this.nipVerifiedAt,
    this.plan,
    this.coverUrl,
    this.logoUrl,
    this.description = '',
    this.categories = const [],
    this.brands = const [],
    this.services = const [],
    this.hours = const TGStoreHours({}),
    this.address,
    this.website,
    this.social = const TGStoreSocial(),
    this.acceptsSpecialOrder = false,
    this.projects = const [],
    this.managedByAdmin = false,
    this.lat = 50.2649,
    this.lng = 19.0238,
    this.specialties = const [],
    this.serviceRegions = const [],
    this.installation = false,
    this.leadTimeWeeks,
    this.responseHours,
  });

  final int publicId;
  final String slug;
  final String sellerKey;
  final TGSellerType type;
  final String name;
  final String? legalName;
  final String? nip;
  final DateTime? nipVerifiedAt;
  final bool verified;
  final TGStorePlanKind? plan;
  final TGStoreStatus status;
  final String? coverUrl;
  final String? logoUrl;
  final String description;
  final List<TGCategory> categories;
  final List<String> brands;
  final List<TGStoreService> services;
  final TGStoreHours hours;
  final String? address;
  final String city;
  final String voivodeship;
  final String phone;
  final String? website;
  final TGStoreSocial social;
  final DateTime memberSince;
  final double rating;
  final int reviewsCount;
  final bool acceptsSpecialOrder;
  final List<TGStoreProject> projects;
  final bool managedByAdmin;
  final double lat;
  final double lng;
  final List<TGStoreSpecialty> specialties;
  final List<String> serviceRegions;
  final bool installation;
  final TGLeadTimeWeeks? leadTimeWeeks;
  final int? responseHours;

  String get path => '/seller/$publicId-$slug';

  bool get isStore => type == TGSellerType.store;
  bool get isPrivate => type == TGSellerType.private;
  bool get isLive => status == TGStoreStatus.active;
  bool get showAbout => description.trim().isNotEmpty || projects.isNotEmpty;
  bool get incompleteSetup => isStore && (description.trim().isEmpty || logoUrl == null);
  bool get showQuote => isLive && acceptsSpecialOrder && (plan == TGStorePlanKind.pro || plan == TGStorePlanKind.enterprise);
  bool get isSpecialOrderManufacturer =>
      isStore && isLive && acceptsSpecialOrder && (plan == TGStorePlanKind.pro || plan == TGStorePlanKind.enterprise);

  TGStoreProfile copyWith({
    String? description,
    String? logoUrl,
    String? coverUrl,
    String? nip,
    List<TGStoreProject>? projects,
    double? rating,
    int? reviewsCount,
    TGStoreStatus? status,
    List<TGCategory>? categories,
    List<String>? brands,
    List<TGStoreService>? services,
    TGStoreHours? hours,
    String? address,
    String? city,
    String? voivodeship,
    String? website,
    TGStoreSocial? social,
    bool? acceptsSpecialOrder,
    double? lat,
    double? lng,
    List<TGStoreSpecialty>? specialties,
    List<String>? serviceRegions,
    bool? installation,
    TGLeadTimeWeeks? leadTimeWeeks,
    int? responseHours,
  }) =>
      TGStoreProfile(
        publicId: publicId,
        slug: slug,
        sellerKey: sellerKey,
        type: type,
        name: name,
        legalName: legalName,
        nip: nip ?? this.nip,
        nipVerifiedAt: nipVerifiedAt,
        verified: verified,
        plan: plan,
        status: status ?? this.status,
        coverUrl: coverUrl ?? this.coverUrl,
        logoUrl: logoUrl ?? this.logoUrl,
        description: description ?? this.description,
        categories: categories ?? this.categories,
        brands: brands ?? this.brands,
        services: services ?? this.services,
        hours: hours ?? this.hours,
        address: address ?? this.address,
        city: city ?? this.city,
        voivodeship: voivodeship ?? this.voivodeship,
        phone: phone,
        website: website ?? this.website,
        social: social ?? this.social,
        memberSince: memberSince,
        rating: rating ?? this.rating,
        reviewsCount: reviewsCount ?? this.reviewsCount,
        acceptsSpecialOrder: acceptsSpecialOrder ?? this.acceptsSpecialOrder,
        projects: projects ?? this.projects,
        managedByAdmin: managedByAdmin,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        specialties: specialties ?? this.specialties,
        serviceRegions: serviceRegions ?? this.serviceRegions,
        installation: installation ?? this.installation,
        leadTimeWeeks: leadTimeWeeks ?? this.leadTimeWeeks,
        responseHours: responseHours ?? this.responseHours,
      );
}
