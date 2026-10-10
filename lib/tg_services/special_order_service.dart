import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_models/tg_special_order.dart';
import 'package:twoja_gastromania/tg_models/tg_store_profile.dart';
import 'package:twoja_gastromania/tg_services/notification_service.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';

enum TGSpecialSort { recommended, highestRated, mostProjects, fastestResponse }

class TGSpecialOrderService extends ChangeNotifier {
  TGSpecialOrderService._();
  static final TGSpecialOrderService instance = TGSpecialOrderService._();

  final List<TGSpecialRequest> requests = [];
  final List<TGQuote> quotes = [];
  final List<TGLeadAccess> leadAccess = [];
  final List<TGQuoteTemplate> templates = [];
  final Map<String, TGLeadAlertSettings> leadAlerts = {};
  final List<String> teamQueue = [];
  final List<TGSoAdminAudit> adminAudit = [];
  final List<String> fileViewLog = [];
  final Set<String> _day10Sent = {};
  Duration undoWindow = const Duration(seconds: 10);
  TGSpecialRequest? _pendingReject;
  String? _pendingRejectId;
  bool _seeded = false;
  int _reqSeq = 123;
  int _quoteSeq = 1;
  int _auditSeq = 1;

  void reset() {
    requests.clear();
    quotes.clear();
    leadAccess.clear();
    templates.clear();
    leadAlerts.clear();
    teamQueue.clear();
    adminAudit.clear();
    fileViewLog.clear();
    _day10Sent.clear();
    _pendingReject = null;
    _pendingRejectId = null;
    _seeded = false;
    _reqSeq = 123;
    _quoteSeq = 1;
    _auditSeq = 1;
    notifyListeners();
  }

  void ensureSeeded() {
    if (_seeded) return;
    _seeded = true;
    _seedAll();
  }

  void onClockAdvanced() {
    ensureSeeded();
    final now = TGClock.now();
    for (var i = 0; i < requests.length; i++) {
      final r = requests[i];
      final ageDays = now.difference(r.createdAt).inDays;
      if ((r.status == TGSpecialRequestStatus.open || r.status == TGSpecialRequestStatus.quoted) && ageDays >= 10 && _day10Sent.add(r.id)) {
        NotificationService.instance.add(
          userId: r.buyerId,
          type: 'so_day10',
          dealId: r.requestNo,
          title: previewEmail('day10', r).subject,
          body: previewEmail('day10', r).body,
          deepLink: '/account/requests/${r.requestNo}',
        );
      }
      if ((r.status == TGSpecialRequestStatus.open || r.status == TGSpecialRequestStatus.quoted) && !now.isBefore(r.expiresAt)) {
        requests[i] = r.copyWith(status: TGSpecialRequestStatus.expired);
        NotificationService.instance.add(
          userId: r.buyerId,
          type: 'so_expired',
          dealId: r.requestNo,
          title: 'Request expired',
          body: '${r.requestNo} has expired.',
          deepLink: '/account/requests/${r.requestNo}',
        );
      }
      final daysLeft = r.daysUntilClose(now);
      if ((r.status == TGSpecialRequestStatus.open || r.status == TGSpecialRequestStatus.quoted) && daysLeft == 5) {
        NotificationService.instance.add(
          userId: r.buyerId,
          type: 'so_expiring',
          dealId: r.requestNo,
          title: 'Request closing soon',
          body: '${r.requestNo} closes in 5 days.',
          deepLink: '/account/requests/${r.requestNo}',
        );
      }
      if (r.status == TGSpecialRequestStatus.open && ageDays >= 5 && quotesFor(r.id).isEmpty) {
        NotificationService.instance.add(
          userId: r.buyerId,
          type: 'so_followup',
          dealId: r.requestNo,
          title: 'No quotes yet',
          body: 'Our team is following up on ${r.requestNo}.',
          deepLink: '/account/requests/${r.requestNo}',
        );
      }
    }
    notifyListeners();
  }

  // ---- directory (SPECIAL-1) ----

  List<TGStoreProfile> manufacturers({
    String? search,
    Set<TGStoreSpecialty> types = const {},
    String? region,
    bool installationOnly = false,
    bool hasProjects = false,
    bool ratedFourPlus = false,
    TGSpecialSort sort = TGSpecialSort.recommended,
  }) {
    ensureSeeded();
    var list = TGSellerProfileService.instance.specialOrderManufacturers;
    final q = search?.trim().toLowerCase();
    if (q != null && q.isNotEmpty) {
      list = list.where((p) => p.name.toLowerCase().contains(q) || p.city.toLowerCase().contains(q)).toList();
    }
    if (types.isNotEmpty) list = list.where((p) => p.specialties.any(types.contains)).toList();
    if (region != null && region.isNotEmpty) {
      final r = region.toLowerCase();
      list = list.where((p) => p.serviceRegions.any((s) => s.toLowerCase() == r || s.toLowerCase() == 'nationwide')).toList();
    }
    if (installationOnly) list = list.where((p) => p.installation).toList();
    if (hasProjects) list = list.where((p) => p.projects.isNotEmpty).toList();
    if (ratedFourPlus) list = list.where((p) => p.reviewsCount >= 3 && p.rating >= 4.0).toList();
    list = [...list];
    switch (sort) {
      case TGSpecialSort.recommended:
        list.sort((a, b) {
          final scoreA = a.projects.length * 10 + a.rating * 5 - (a.responseHours ?? 24);
          final scoreB = b.projects.length * 10 + b.rating * 5 - (b.responseHours ?? 24);
          return scoreB.compareTo(scoreA);
        });
      case TGSpecialSort.highestRated:
        list.sort((a, b) => b.rating.compareTo(a.rating));
      case TGSpecialSort.mostProjects:
        list.sort((a, b) => b.projects.length.compareTo(a.projects.length));
      case TGSpecialSort.fastestResponse:
        list.sort((a, b) => (a.responseHours ?? 99).compareTo(b.responseHours ?? 99));
    }
    return list;
  }

  int get manufacturerCount => TGSellerProfileService.instance.specialOrderManufacturers.length;
  int get projectCount => TGSellerProfileService.instance.specialOrderManufacturers.fold<int>(0, (a, p) => a + p.projects.length);

  List<({TGStoreProfile store, TGStoreProject project})> recentProjectEntries({int limit = 6}) {
    final all = <({TGStoreProfile store, TGStoreProject project})>[];
    for (final s in TGSellerProfileService.instance.specialOrderManufacturers) {
      for (final p in s.projects) {
        all.add((store: s, project: p));
      }
    }
    all.sort((a, b) => b.project.year.compareTo(a.project.year));
    return all.take(limit).toList();
  }

  TGStoreProfile? sponsoredManufacturer() {
    final enterprise = TGSellerProfileService.instance.specialOrderManufacturers.where((p) => p.plan == TGStorePlanKind.enterprise).toList();
    return enterprise.isEmpty ? null : enterprise.first;
  }

  // ---- requests ----

  TGSpecialRequest? byRequestNo(String no) {
    ensureSeeded();
    final n = no.trim().toUpperCase();
    return requests.where((r) => r.requestNo.toUpperCase() == n || r.id == no).firstOrNull;
  }

  TGSpecialRequest? byId(String id) {
    ensureSeeded();
    return requests.where((r) => r.id == id).firstOrNull;
  }

  List<TGSpecialRequest> forBuyer(String buyerId) {
    ensureSeeded();
    return requests.where((r) => r.buyerId == buyerId).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  int submittedToday(String buyerId) {
    ensureSeeded();
    final now = TGClock.now();
    final key = '${now.year}-${now.month}-${now.day}';
    return requests.where((r) {
      if (r.buyerId != buyerId) return false;
      if (r.status == TGSpecialRequestStatus.draft) return false;
      final c = r.createdAt;
      return '${c.year}-${c.month}-${c.day}' == key;
    }).length;
  }

  bool canSubmitToday(String buyerId) => submittedToday(buyerId) < 3;

  List<TGQuote> quotesFor(String requestId) {
    ensureSeeded();
    return quotes.where((q) => q.requestId == requestId && q.status != TGQuoteStatus.withdrawn).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  List<TGLeadAccess> accessFor(String requestId) {
    ensureSeeded();
    return leadAccess.where((a) => a.requestId == requestId).toList();
  }

  List<TGSpecialRequest> leadsForSeller(String sellerKey, {bool directedOnly = false}) {
    ensureSeeded();
    final profile = TGSellerProfileService.instance.bySellerKey(sellerKey);
    if (profile == null || !profile.isLive) return const [];
    if (profile.plan == TGStorePlanKind.basic || profile.plan == null) return const [];
    final ids = leadAccess.where((a) {
      if (a.sellerId != sellerKey) return false;
      if (profile.plan == TGStorePlanKind.pro) {
        return a.via == TGLeadAccessVia.selected || a.via == TGLeadAccessVia.matched;
      }
      if (directedOnly) return a.via == TGLeadAccessVia.selected || a.via == TGLeadAccessVia.matched;
      return true;
    }).map((a) => a.requestId).toSet();
    return requests.where((r) => ids.contains(r.id)).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  TGLeadAccessVia? viaFor(String requestId, String sellerId) =>
      leadAccess.where((a) => a.requestId == requestId && a.sellerId == sellerId).firstOrNull?.via;

  int activeQuoteCount(String requestId) => quotesFor(requestId).where((q) => q.status != TGQuoteStatus.declined && q.status != TGQuoteStatus.lost).length;

  int poolQuoteCount(String requestId) {
    final poolSellers = leadAccess.where((a) => a.requestId == requestId && a.via == TGLeadAccessVia.enterprisePool).map((a) => a.sellerId).toSet();
    return quotesFor(requestId).where((q) => poolSellers.contains(q.sellerId)).length;
  }

  bool canSubmitQuote(String requestId, String sellerId) {
    final r = byId(requestId);
    if (r == null) return false;
    if (r.status != TGSpecialRequestStatus.open && r.status != TGSpecialRequestStatus.quoted && r.status != TGSpecialRequestStatus.held) return false;
    final profile = TGSellerProfileService.instance.bySellerKey(sellerId);
    if (profile == null || !profile.isLive || !profile.isSpecialOrderManufacturer) return false;
    if (quotesFor(requestId).any((q) => q.sellerId == sellerId)) return false;
    if (activeQuoteCount(requestId) >= r.quoteLimit) return false;
    final via = viaFor(requestId, sellerId);
    if (via == TGLeadAccessVia.enterprisePool && poolQuoteCount(requestId) >= 3) return false;
    return true;
  }

  TGSpecialRequest submitRequest(TGSpecialRequest draft) {
    ensureSeeded();
    final now = TGClock.now();
    final no = 'SO-2026-${(_reqSeq++).toString().padLeft(6, '0')}';
    final held = draft.flags.contains('spam');
    final status = held ? TGSpecialRequestStatus.held : TGSpecialRequestStatus.open;
    final req = draft.copyWith(
      status: status,
      consentAt: now,
      expiresAt: now.add(const Duration(days: 30)),
      teamQueued: draft.routingMode != TGSpecialRoutingMode.selected,
    );
    final saved = TGSpecialRequest(
      id: 'so-req-${requests.length + 1}',
      requestNo: no,
      buyerId: req.buyerId,
      buyerName: req.buyerName,
      companyName: req.companyName,
      phone: req.phone,
      email: req.email,
      nip: req.nip,
      projectTypes: req.projectTypes,
      title: req.title,
      description: req.description,
      quantity: req.quantity,
      widthMm: req.widthMm,
      depthMm: req.depthMm,
      heightMm: req.heightMm,
      dimensionsText: req.dimensionsText,
      material: req.material,
      finish: req.finish,
      budgetMin: req.budgetMin,
      budgetMax: req.budgetMax,
      deadline: req.deadline,
      city: req.city,
      voivodeship: req.voivodeship,
      installationNeeded: req.installationNeeded,
      deliveryNeeded: req.deliveryNeeded,
      files: req.files,
      routingMode: req.routingMode,
      selectedSellerIds: req.selectedSellerIds,
      contactPref: req.contactPref,
      consentAt: req.consentAt,
      status: req.status,
      quoteLimit: req.quoteLimit,
      createdAt: now,
      expiresAt: req.expiresAt,
      flags: req.flags,
      teamQueued: req.teamQueued,
    );
    requests.insert(0, saved);
    _grantAccess(saved);
    if (saved.teamQueued) teamQueue.add(saved.id);

    NotificationService.instance.add(
      userId: saved.buyerId,
      type: 'so_received',
      dealId: saved.requestNo,
      title: 'Request received',
      body: '${saved.requestNo} was sent to manufacturers.',
      deepLink: '/account/requests/${saved.requestNo}',
    );
    NotificationService.instance.add(
      userId: 'staff_admin',
      type: 'so_team_new',
      dealId: saved.requestNo,
      title: 'New Special Order',
      body: saved.title,
      deepLink: '/admin/special-orders/${saved.requestNo}',
    );
    for (final a in accessFor(saved.id)) {
      final settings = leadAlerts[a.sellerId] ?? const TGLeadAlertSettings();
      if (settings.instantEmail || a.via != TGLeadAccessVia.enterprisePool) {
        NotificationService.instance.add(
          userId: a.sellerId,
          type: 'so_new_lead',
          dealId: saved.requestNo,
          title: 'New Special Order lead',
          body: saved.title,
          deepLink: '/dashboard/leads?id=${saved.requestNo}',
        );
      }
    }
    TGAnalytics.track('so_request_submit', {'requestNo': saved.requestNo, 'status': saved.status.name});
    notifyListeners();
    return saved;
  }

  void _grantAccess(TGSpecialRequest r) {
    final seen = <String>{};
    void add(String sellerId, TGLeadAccessVia via) {
      if (!seen.add(sellerId)) return;
      leadAccess.add(TGLeadAccess(requestId: r.id, sellerId: sellerId, via: via, viewedAt: null));
    }

    if (r.routingMode == TGSpecialRoutingMode.selected || r.routingMode == TGSpecialRoutingMode.both) {
      for (final id in r.selectedSellerIds) {
        add(id, TGLeadAccessVia.selected);
      }
    }
    for (final p in TGSellerProfileService.instance.specialOrderManufacturers.where((e) => e.plan == TGStorePlanKind.enterprise)) {
      add(p.sellerKey, TGLeadAccessVia.enterprisePool);
    }
  }

  void markLeadViewed(String requestId, String sellerId) {
    final i = leadAccess.indexWhere((a) => a.requestId == requestId && a.sellerId == sellerId);
    if (i < 0) return;
    leadAccess[i] = leadAccess[i].copyWith(viewedAt: TGClock.now());
    notifyListeners();
  }

  TGQuote submitQuote({
    required String requestId,
    required String sellerId,
    required int priceNet,
    required TGQuotePriceType priceType,
    required int leadTimeWeeks,
    required DateTime validUntil,
    required bool installationIncluded,
    required bool deliveryIncluded,
    required int warrantyMonths,
    required String paymentTerms,
    required String note,
    String? attachmentUrl,
  }) {
    ensureSeeded();
    if (!canSubmitQuote(requestId, sellerId)) {
      throw StateError('Cannot submit quote');
    }
    final q = TGQuote(
      id: 'so-q-${_quoteSeq++}',
      requestId: requestId,
      sellerId: sellerId,
      priceNet: priceNet,
      priceType: priceType,
      leadTimeWeeks: leadTimeWeeks,
      validUntil: validUntil,
      installationIncluded: installationIncluded,
      deliveryIncluded: deliveryIncluded,
      warrantyMonths: warrantyMonths,
      paymentTerms: paymentTerms,
      note: note,
      attachmentUrl: attachmentUrl,
      status: TGQuoteStatus.submitted,
      createdAt: TGClock.now(),
      isNew: true,
    );
    quotes.add(q);
    final ri = requests.indexWhere((r) => r.id == requestId);
    if (ri >= 0) {
      final r = requests[ri];
      if (r.status == TGSpecialRequestStatus.open) {
        requests[ri] = r.copyWith(status: TGSpecialRequestStatus.quoted);
      }
      NotificationService.instance.add(
        userId: r.buyerId,
        type: 'so_quote_received',
        dealId: r.requestNo,
        title: 'New quote',
        body: 'A manufacturer quoted on ${r.requestNo}.',
        deepLink: '/account/requests/${r.requestNo}',
      );
      TGAnalytics.track('so_quote_received', {'requestNo': r.requestNo, 'sellerId': sellerId});
    }
    TGAnalytics.track('so_quote_submit', {'requestId': requestId, 'sellerId': sellerId});
    notifyListeners();
    return q;
  }

  void withdrawQuote(String quoteId, String sellerId) {
    final i = quotes.indexWhere((q) => q.id == quoteId && q.sellerId == sellerId);
    if (i < 0) return;
    final q = quotes[i];
    final r = byId(q.requestId);
    if (r == null || r.status == TGSpecialRequestStatus.awarded) return;
    quotes[i] = q.copyWith(status: TGQuoteStatus.withdrawn);
    notifyListeners();
  }

  void shortlistQuote(String quoteId) => _setQuoteStatus(quoteId, TGQuoteStatus.shortlisted);
  void declineQuote(String quoteId) => _setQuoteStatus(quoteId, TGQuoteStatus.declined);

  void _setQuoteStatus(String quoteId, TGQuoteStatus status) {
    final i = quotes.indexWhere((q) => q.id == quoteId);
    if (i < 0) return;
    quotes[i] = quotes[i].copyWith(status: status, isNew: false);
    notifyListeners();
  }

  void clearQuoteNew(String quoteId) {
    final i = quotes.indexWhere((q) => q.id == quoteId);
    if (i < 0) return;
    quotes[i] = quotes[i].copyWith(isNew: false);
    notifyListeners();
  }

  void award(String requestId, String sellerId) {
    final ri = requests.indexWhere((r) => r.id == requestId);
    if (ri < 0) return;
    final r = requests[ri];
    requests[ri] = r.copyWith(status: TGSpecialRequestStatus.awarded, awardedSellerId: sellerId, closedAt: TGClock.now());
    for (var i = 0; i < quotes.length; i++) {
      final q = quotes[i];
      if (q.requestId != requestId) continue;
      quotes[i] = q.copyWith(status: q.sellerId == sellerId ? TGQuoteStatus.awarded : TGQuoteStatus.lost, isNew: false);
      if (q.sellerId != sellerId) {
        NotificationService.instance.add(
          userId: q.sellerId,
          type: 'so_not_selected',
          dealId: r.requestNo,
          title: 'Request closed',
          body: 'The buyer chose another offer.',
          deepLink: '/dashboard/leads?id=${r.requestNo}',
        );
      }
    }
    TGAnalytics.track('so_award', {'requestNo': r.requestNo, 'sellerId': sellerId});
    notifyListeners();
  }

  void closeRequest(String requestId) {
    final ri = requests.indexWhere((r) => r.id == requestId);
    if (ri < 0) return;
    final r = requests[ri];
    requests[ri] = r.copyWith(status: TGSpecialRequestStatus.closed, closedAt: TGClock.now());
    for (final a in accessFor(requestId)) {
      NotificationService.instance.add(
        userId: a.sellerId,
        type: 'so_closed',
        dealId: r.requestNo,
        title: 'Request closed',
        body: 'The buyer closed ${r.requestNo}.',
        deepLink: '/dashboard/leads?id=${r.requestNo}',
      );
    }
    TGAnalytics.track('so_request_close', {'requestNo': r.requestNo});
    notifyListeners();
  }

  void matchMore(String requestId) {
    final r = byId(requestId);
    if (r == null) return;
    for (final p in manufacturers().take(3)) {
      if (leadAccess.any((a) => a.requestId == requestId && a.sellerId == p.sellerKey)) continue;
      leadAccess.add(TGLeadAccess(requestId: requestId, sellerId: p.sellerKey, via: TGLeadAccessVia.matched, viewedAt: null));
      NotificationService.instance.add(
        userId: p.sellerKey,
        type: 'so_new_lead',
        dealId: r.requestNo,
        title: 'Matched Special Order',
        body: r.title,
        deepLink: '/dashboard/leads?id=${r.requestNo}',
      );
    }
    NotificationService.instance.add(
      userId: r.buyerId,
      type: 'so_team_matched',
      dealId: r.requestNo,
      title: 'More manufacturers matched',
      body: 'Our team matched more manufacturers to ${r.requestNo}.',
      deepLink: '/account/requests/${r.requestNo}',
    );
    notifyListeners();
  }

  TGLeadAlertSettings alertSettings(String sellerId) => leadAlerts[sellerId] ?? const TGLeadAlertSettings();

  void saveAlertSettings(String sellerId, TGLeadAlertSettings settings) {
    leadAlerts[sellerId] = settings;
    TGAnalytics.track('lead_alert_saved', {'sellerId': sellerId});
    notifyListeners();
  }

  void saveTemplate(TGQuoteTemplate t) {
    templates.removeWhere((e) => e.id == t.id);
    templates.add(t);
    notifyListeners();
  }

  List<TGQuoteTemplate> templatesFor(String sellerId) => templates.where((t) => t.sellerId == sellerId).toList();

  // ---- admin ----

  String? resolveAdminSearch(String raw) {
    final q = raw.trim().toUpperCase();
    if (q.isEmpty) return null;
    ensureSeeded();
    return requests.where((r) => r.requestNo.toUpperCase() == q || r.requestNo.toUpperCase().contains(q)).firstOrNull?.requestNo;
  }

  bool _isNeedsMatching(TGSpecialRequest r) {
    if (r.status != TGSpecialRequestStatus.open && r.status != TGSpecialRequestStatus.quoted) return false;
    if (!r.teamQueued && r.routingMode == TGSpecialRoutingMode.selected) return false;
    if (_isNoQuotes(r)) return false;
    final matched = leadAccess.any((a) => a.requestId == r.id && a.via == TGLeadAccessVia.matched);
    return !matched && quotesFor(r.id).isEmpty;
  }

  bool _isNoQuotes(TGSpecialRequest r) {
    if (r.status != TGSpecialRequestStatus.open && r.status != TGSpecialRequestStatus.quoted) return false;
    if (quotesFor(r.id).isNotEmpty) return false;
    return TGClock.now().difference(r.createdAt).inDays >= 5;
  }

  bool _isReported(TGSpecialRequest r) => r.reportedAt != null;

  List<TGSpecialRequest> adminQueue(TGSoAdminQueue queue, {String q = ''}) {
    ensureSeeded();
    Iterable<TGSpecialRequest> rows = switch (queue) {
      TGSoAdminQueue.needsMatching => requests.where(_isNeedsMatching),
      TGSoAdminQueue.held => requests.where((r) => r.status == TGSpecialRequestStatus.held),
      TGSoAdminQueue.noQuotes => requests.where(_isNoQuotes),
      TGSoAdminQueue.reported => requests.where(_isReported),
      TGSoAdminQueue.all => requests.where((r) => r.status != TGSpecialRequestStatus.draft),
    };
    final needle = q.trim().toLowerCase();
    if (needle.isNotEmpty) {
      rows = rows.where((r) =>
          '${r.requestNo} ${r.title} ${r.buyerName} ${r.city} ${r.voivodeship}'.toLowerCase().contains(needle));
    }
    return rows.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  int adminCount(TGSoAdminQueue queue) => adminQueue(queue).length;

  TGSoAdminQueue queueKindFor(TGSpecialRequest r) {
    if (r.status == TGSpecialRequestStatus.held) return TGSoAdminQueue.held;
    if (_isReported(r)) return TGSoAdminQueue.reported;
    if (_isNoQuotes(r)) return TGSoAdminQueue.noQuotes;
    if (_isNeedsMatching(r)) return TGSoAdminQueue.needsMatching;
    return TGSoAdminQueue.all;
  }

  /// SLA targets: matching/held 1 business day; no-quotes 5 days; reported 2 business days.
  (TGSoSlaTone tone, String label) slaFor(TGSpecialRequest r, {DateTime? now}) {
    final t = now ?? TGClock.now();
    final kind = queueKindFor(r);
    final ageHours = t.difference(r.reportedAt ?? r.createdAt).inHours;
    final targetHours = switch (kind) {
      TGSoAdminQueue.needsMatching || TGSoAdminQueue.held => 24,
      TGSoAdminQueue.reported => 48,
      TGSoAdminQueue.noQuotes => 5 * 24,
      TGSoAdminQueue.all => 24,
    };
    final ageLabel = ageHours < 24 ? '${ageHours}h' : '${ageHours ~/ 24}d';
    if (ageHours >= targetHours) return (TGSoSlaTone.overdue, '$ageLabel · overdue');
    if (ageHours >= (targetHours * 0.8).floor()) return (TGSoSlaTone.warning, '$ageLabel · at risk');
    return (TGSoSlaTone.ok, ageLabel);
  }

  List<String> spamFlagsFor(TGSpecialRequest r) {
    final now = TGClock.now();
    final dupText = requests.any((o) => o.id != r.id && o.description.trim() == r.description.trim());
    final fileNames = r.files.map((f) => f.name).toSet();
    final dupFiles = requests.any((o) => o.id != r.id && o.files.any((f) => fileNames.contains(f.name)));
    return r.autoSpamFlags(now, duplicateText: dupText, duplicateFiles: dupFiles);
  }

  void logFileView(String requestId, String fileId, {required String actorId}) {
    fileViewLog.add('$requestId|$fileId|$actorId|${TGClock.now().toIso8601String()}');
    _audit(requestId, actorId, 'staff', 'file_view', detail: fileId);
  }

  void assignAdmin(String requestId, String actorId) {
    final i = requests.indexWhere((r) => r.id == requestId);
    if (i < 0) return;
    requests[i] = requests[i].copyWith(assignedTo: actorId);
    _audit(requestId, actorId, 'staff', 'assign');
    notifyListeners();
  }

  void approveAndRoute(String requestId, {required String actorId, required String actorRole}) {
    final i = requests.indexWhere((r) => r.id == requestId);
    if (i < 0) return;
    var r = requests[i];
    if (r.status != TGSpecialRequestStatus.held) return;
    r = r.copyWith(status: TGSpecialRequestStatus.open, flags: r.flags.where((f) => f != 'spam').toList());
    requests[i] = r;
    _grantAccess(r);
    if (r.teamQueued && !teamQueue.contains(r.id)) teamQueue.add(r.id);
    _audit(requestId, actorId, actorRole, 'approve_route');
    TGAnalytics.track('so_admin_match', {'requestNo': r.requestNo, 'via': 'approve'});
    notifyListeners();
  }

  void matchManufacturers(String requestId, List<String> sellerIds, {required String actorId, required String actorRole}) {
    final r = byId(requestId);
    if (r == null) return;
    for (final sid in sellerIds) {
      if (leadAccess.any((a) => a.requestId == requestId && a.sellerId == sid)) continue;
      leadAccess.add(TGLeadAccess(requestId: requestId, sellerId: sid, via: TGLeadAccessVia.matched, viewedAt: null));
      NotificationService.instance.add(
        userId: sid,
        type: 'so_new_lead',
        dealId: r.requestNo,
        title: 'Matched Special Order lead',
        body: r.title,
        deepLink: '/dashboard/leads?id=${r.requestNo}',
      );
    }
    NotificationService.instance.add(
      userId: r.buyerId,
      type: 'so_team_matched',
      dealId: r.requestNo,
      title: 'More manufacturers matched',
      body: 'Our team matched manufacturers to ${r.requestNo}.',
      deepLink: '/account/requests/${r.requestNo}',
    );
    _audit(requestId, actorId, actorRole, 'match', detail: sellerIds.join(','));
    TGAnalytics.track('so_admin_match', {'requestNo': r.requestNo, 'n': sellerIds.length});
    notifyListeners();
  }

  void nudgeManufacturers(String requestId, {required String actorId, required String actorRole}) {
    final r = byId(requestId);
    if (r == null) return;
    for (final a in accessFor(requestId)) {
      NotificationService.instance.add(
        userId: a.sellerId,
        type: 'so_nudge',
        dealId: r.requestNo,
        title: 'Reminder: Special Order lead',
        body: 'A buyer is waiting for a quote on ${r.requestNo}.',
        deepLink: '/dashboard/leads?id=${r.requestNo}',
      );
    }
    _audit(requestId, actorId, actorRole, 'nudge');
    notifyListeners();
  }

  TGSoEmailPreview previewEmail(String action, TGSpecialRequest r, {String lang = 'en', String? reason}) {
    final pl = lang == 'pl';
    return switch (action) {
      'reject' => TGSoEmailPreview(
          lang: lang,
          subject: pl ? 'Aktualizacja zapytania ${r.requestNo}' : 'Update on your request ${r.requestNo}',
          body: pl
              ? 'Twoje zapytanie ${r.requestNo} zostało zamknięte. ${reason ?? ''}'.trim()
              : 'Your request ${r.requestNo} was closed. ${reason ?? 'We cannot process this request.'}'.trim(),
        ),
      'contact' => TGSoEmailPreview(
          lang: lang,
          subject: pl ? 'Wiadomość w sprawie ${r.requestNo}' : 'Message about ${r.requestNo}',
          body: pl
              ? 'Cześć ${r.buyerName}, piszemy w sprawie Twojego zapytania ${r.requestNo}.'
              : 'Hi ${r.buyerName}, we are writing about your request ${r.requestNo}.',
        ),
      'nudge' => TGSoEmailPreview(
          lang: lang,
          subject: pl ? 'Przypomnienie: zapytanie ${r.requestNo}' : 'Reminder: request ${r.requestNo}',
          body: pl ? 'Kupujący czeka na wycenę.' : 'The buyer is waiting for a quote.',
        ),
      'day10' => TGSoEmailPreview(
          lang: lang,
          subject: pl ? 'Czy otrzymałeś oferty?' : 'Did you receive offers?',
          body: pl
              ? 'Minęło 10 dni od ${r.requestNo}. Czy otrzymałeś oferty od producentów?'
              : 'It has been 10 days since ${r.requestNo}. Did you receive offers from manufacturers?',
        ),
      _ => TGSoEmailPreview(lang: lang, subject: r.requestNo, body: action),
    };
  }

  void contactBuyer(String requestId, {required String actorId, required String actorRole, String lang = 'en', String? body}) {
    final r = byId(requestId);
    if (r == null) return;
    final mail = previewEmail('contact', r, lang: lang);
    NotificationService.instance.add(
      userId: r.buyerId,
      type: 'so_staff_message',
      dealId: r.requestNo,
      title: mail.subject,
      body: body ?? mail.body,
      deepLink: '/account/requests/${r.requestNo}',
    );
    _audit(requestId, actorId, actorRole, 'contact_buyer', detail: lang);
    notifyListeners();
  }

  /// Schedules reject with 10s undo window.
  void rejectRequest(String requestId, {required String actorId, required String actorRole, required String reason}) {
    final i = requests.indexWhere((r) => r.id == requestId);
    if (i < 0) return;
    _pendingReject = requests[i];
    _pendingRejectId = requestId;
    requests[i] = requests[i].copyWith(
      status: TGSpecialRequestStatus.rejected,
      rejectReason: reason,
      closedAt: TGClock.now(),
    );
    _audit(requestId, actorId, actorRole, 'reject', reason: reason);
    TGAnalytics.track('so_admin_reject', {'requestNo': requests[i].requestNo});
    notifyListeners();
    Future<void>.delayed(undoWindow, () {
      if (_pendingRejectId != requestId) return;
      final cur = byId(requestId);
      if (cur == null || cur.status != TGSpecialRequestStatus.rejected) return;
      final mail = previewEmail('reject', cur, reason: reason);
      NotificationService.instance.add(
        userId: cur.buyerId,
        type: 'so_rejected',
        dealId: cur.requestNo,
        title: mail.subject,
        body: mail.body,
        deepLink: '/account/requests/${cur.requestNo}',
      );
      _pendingReject = null;
      _pendingRejectId = null;
      notifyListeners();
    });
  }

  bool undoReject({required String actorId, required String actorRole}) {
    if (_pendingReject == null || _pendingRejectId == null) return false;
    final id = _pendingRejectId!;
    final i = requests.indexWhere((r) => r.id == id);
    if (i < 0) return false;
    requests[i] = _pendingReject!;
    _audit(id, actorId, actorRole, 'undo_reject');
    TGAnalytics.track('so_admin_undo', {'requestNo': _pendingReject!.requestNo});
    _pendingReject = null;
    _pendingRejectId = null;
    notifyListeners();
    return true;
  }

  void closeAdmin(String requestId, {required String actorId, required String actorRole}) {
    closeRequest(requestId);
    _audit(requestId, actorId, actorRole, 'close');
  }

  void reopenAdmin(String requestId, {required String actorId, required String actorRole}) {
    final i = requests.indexWhere((r) => r.id == requestId);
    if (i < 0) return;
    requests[i] = requests[i].copyWith(
      status: TGSpecialRequestStatus.open,
      clearAwarded: true,
      clearClosed: true,
      clearReject: true,
    );
    _audit(requestId, actorId, actorRole, 'reopen');
    notifyListeners();
  }

  void deleteFiles(String requestId, {required String actorId, required String actorRole}) {
    final i = requests.indexWhere((r) => r.id == requestId);
    if (i < 0) return;
    requests[i] = requests[i].copyWith(files: const []);
    _audit(requestId, actorId, actorRole, 'files_deleted');
    TGAnalytics.track('so_files_deleted', {'requestNo': requests[i].requestNo});
    notifyListeners();
  }

  void dismissReport(String requestId, {required String actorId, required String actorRole}) {
    final i = requests.indexWhere((r) => r.id == requestId);
    if (i < 0) return;
    requests[i] = requests[i].copyWith(clearReported: true);
    _audit(requestId, actorId, actorRole, 'report_dismiss');
    notifyListeners();
  }

  void contactReporter(String requestId, {required String actorId, required String actorRole}) {
    final r = byId(requestId);
    if (r?.reporterSellerId == null) return;
    NotificationService.instance.add(
      userId: r!.reporterSellerId!,
      type: 'so_report_update',
      dealId: r.requestNo,
      title: 'Report update',
      body: 'We reviewed your report on ${r.requestNo}.',
      deepLink: '/dashboard/leads?id=${r.requestNo}',
    );
    _audit(requestId, actorId, actorRole, 'contact_reporter');
    notifyListeners();
  }

  List<TGSoAdminAudit> auditFor(String requestId) =>
      adminAudit.where((a) => a.requestId == requestId).toList()..sort((a, b) => b.at.compareTo(a.at));

  void _audit(String requestId, String actorId, String actorRole, String action, {String? reason, String? detail}) {
    adminAudit.insert(
      0,
      TGSoAdminAudit(
        id: 'so-audit-${_auditSeq++}',
        requestId: requestId,
        actorId: actorId,
        actorRole: actorRole,
        action: action,
        at: TGClock.now(),
        reason: reason,
        detail: detail,
      ),
    );
  }

  // ---- seed ----

  void _seedAll() {
    final now = TGClock.now();
    const phone = '+48 (532) 784-074';
    const buyer = 'buyer_marek';

    TGSpecialRequest mk({
      required String id,
      required String no,
      required TGSpecialRequestStatus status,
      required String title,
      required List<TGStoreSpecialty> types,
      required List<String> sellers,
      TGSpecialRoutingMode mode = TGSpecialRoutingMode.both,
      int? budgetMin,
      int? budgetMax,
      Duration createdAgo = const Duration(days: 2),
      Duration expiresIn = const Duration(days: 28),
      String? awarded,
      List<String> flags = const [],
      String? rejectReason,
      TGSpecialContactPref pref = TGSpecialContactPref.share,
      String city = 'Gliwice',
      String voiv = 'Śląskie',
      String buyerId = buyer,
      bool phoneVerified = true,
      Duration? accountAge,
      DateTime? reportedAt,
      String? reporterSellerId,
      String? reportReason,
      String? assignedTo,
      String? description,
    }) =>
        TGSpecialRequest(
          id: id,
          requestNo: no,
          buyerId: buyerId,
          buyerName: buyerId == 'buyer_anna' ? 'Anna W.' : 'Marek K.',
          companyName: 'Bistro Centrum',
          phone: phone,
          email: buyerId == 'buyer_anna' ? 'anna@example.com' : 'marek@example.com',
          nip: '5261040828',
          projectTypes: types,
          title: title,
          description: description ??
              'Need a custom stainless project for our kitchen. Dimensions and finish details in the brief. Looking for verified manufacturers who can install on site.',
          quantity: 2,
          widthMm: 2000,
          depthMm: 700,
          heightMm: 850,
          dimensionsText: '2000 x 700 x 850 mm',
          material: 'AISI 304',
          finish: 'Brushed',
          budgetMin: budgetMin,
          budgetMax: budgetMax,
          deadline: TGSpecialDeadline.oneMonth,
          city: city,
          voivodeship: voiv,
          installationNeeded: true,
          deliveryNeeded: true,
          files: const [
            TGSpecialFile(id: 'f1', name: 'layout.pdf', assetPath: 'assets/images/blog-26.jpg', bytes: 420000),
          ],
          routingMode: mode,
          selectedSellerIds: sellers,
          contactPref: pref,
          consentAt: now.subtract(createdAgo),
          status: status,
          createdAt: now.subtract(createdAgo),
          expiresAt: now.add(expiresIn),
          awardedSellerId: awarded,
          flags: flags,
          rejectReason: rejectReason,
          teamQueued: mode != TGSpecialRoutingMode.selected,
          phoneVerified: phoneVerified,
          buyerAccountCreatedAt: now.subtract(accountAge ?? const Duration(days: 60)),
          reportedAt: reportedAt,
          reporterSellerId: reporterSellerId,
          reportReason: reportReason,
          assignedTo: assignedTo,
        );

    final seeds = <TGSpecialRequest>[
      // Needs matching (2)
      mk(id: 'so-req-13', no: 'SO-2026-000135', status: TGSpecialRequestStatus.open, title: 'Team-match only hoods', types: const [TGStoreSpecialty.extractionHoods], sellers: const [], mode: TGSpecialRoutingMode.team, createdAgo: const Duration(days: 1), buyerId: 'buyer_anna', phoneVerified: false, accountAge: const Duration(days: 3)),
      mk(id: 'so-req-11', no: 'SO-2026-000133', status: TGSpecialRequestStatus.open, title: 'Washing station island', types: const [TGStoreSpecialty.sinksWashing, TGStoreSpecialty.worktopsTables], sellers: const [], mode: TGSpecialRoutingMode.team, pref: TGSpecialContactPref.platformOnly, city: 'Warszawa', voiv: 'Mazowieckie', createdAgo: const Duration(hours: 18)),
      // Held (2)
      mk(id: 'so-req-6', no: 'SO-2026-000128', status: TGSpecialRequestStatus.held, title: 'Suspicious bulk sinks request', types: const [TGStoreSpecialty.sinksWashing], sellers: const ['seller_nordinox'], flags: const ['spam'], createdAgo: const Duration(days: 1), accountAge: const Duration(days: 2), phoneVerified: false),
      mk(id: 'so-req-15', no: 'SO-2026-000137', status: TGSpecialRequestStatus.held, title: 'Duplicate text hold case', types: const [TGStoreSpecialty.worktopsTables], sellers: const [], mode: TGSpecialRoutingMode.team, flags: const ['spam'], createdAgo: const Duration(hours: 10), description: 'Need a custom stainless project for our kitchen. Dimensions and finish details in the brief. Looking for verified manufacturers who can install on site.'),
      // No quotes (1) — open ≥5 days, zero quotes
      mk(id: 'so-req-12', no: 'SO-2026-000134', status: TGSpecialRequestStatus.open, title: 'Nationwide bar rollout', types: const [TGStoreSpecialty.barCounters, TGStoreSpecialty.fullFitout], sellers: const ['seller_stalbar'], mode: TGSpecialRoutingMode.both, budgetMin: null, budgetMax: null, createdAgo: const Duration(days: 6)),
      // Reported (1)
      mk(id: 'so-req-16', no: 'SO-2026-000138', status: TGSpecialRequestStatus.open, title: 'Reported personal-data request', types: const [TGStoreSpecialty.coldRooms], sellers: const ['seller_rm'], createdAgo: const Duration(days: 2), reportedAt: now.subtract(const Duration(hours: 20)), reporterSellerId: 'seller_rm', reportReason: 'Contains personal data of others'),
      // Other admin-visible (2+)
      mk(id: 'so-req-1', no: 'SO-2026-000123', status: TGSpecialRequestStatus.open, title: 'Central prep table 2000 mm', types: const [TGStoreSpecialty.worktopsTables], sellers: const ['seller_gastropl', 'seller_inoxline'], budgetMin: 4000, budgetMax: 7000, assignedTo: 'mod_1'),
      mk(id: 'so-req-10', no: 'SO-2026-000132', status: TGSpecialRequestStatus.rejected, title: 'Rejected out-of-scope request', types: const [TGStoreSpecialty.other], sellers: const [], mode: TGSpecialRoutingMode.team, rejectReason: 'Out of scope for stainless kitchen projects.', createdAgo: const Duration(days: 8)),
      // Buyer / seller flow seeds
      mk(id: 'so-req-2', no: 'SO-2026-000124', status: TGSpecialRequestStatus.quoted, title: 'Bar counter for hotel lobby', types: const [TGStoreSpecialty.barCounters], sellers: const ['seller_stalbar', 'seller_rm'], budgetMin: 12000, budgetMax: 18000, createdAgo: const Duration(days: 4)),
      mk(id: 'so-req-3', no: 'SO-2026-000125', status: TGSpecialRequestStatus.quoted, title: 'Extraction hood line 4 m', types: const [TGStoreSpecialty.extractionHoods], sellers: const ['seller_gastropl', 'seller_stalbar', 'seller_metalgast'], budgetMin: 8000, budgetMax: 14000, createdAgo: const Duration(days: 6)),
      mk(id: 'so-req-4', no: 'SO-2026-000126', status: TGSpecialRequestStatus.quoted, title: 'Cold room shell 12 m²', types: const [TGStoreSpecialty.coldRooms], sellers: const ['seller_rm', 'seller_metalgast'], budgetMin: 20000, budgetMax: 32000, createdAgo: const Duration(days: 3)),
      mk(id: 'so-req-5', no: 'SO-2026-000127', status: TGSpecialRequestStatus.awarded, title: 'Full canteen fit-out', types: const [TGStoreSpecialty.fullFitout], sellers: const ['seller_rm', 'seller_gastropl'], budgetMin: 80000, budgetMax: 120000, awarded: 'seller_rm', createdAgo: const Duration(days: 12)),
      mk(id: 'so-req-7', no: 'SO-2026-000129', status: TGSpecialRequestStatus.draft, title: 'Draft shelving layout', types: const [TGStoreSpecialty.shelvingStorage], sellers: const [], mode: TGSpecialRoutingMode.team, createdAgo: const Duration(hours: 5)),
      mk(id: 'so-req-8', no: 'SO-2026-000130', status: TGSpecialRequestStatus.closed, title: 'Laser cut panels (closed)', types: const [TGStoreSpecialty.laserBending], sellers: const ['seller_metalgast'], createdAgo: const Duration(days: 20), expiresIn: const Duration(days: -2)),
      mk(id: 'so-req-9', no: 'SO-2026-000131', status: TGSpecialRequestStatus.expired, title: 'Expired worktop RFQ', types: const [TGStoreSpecialty.worktopsTables], sellers: const ['seller_inoxline'], createdAgo: const Duration(days: 35), expiresIn: const Duration(days: -5)),
      mk(id: 'so-req-14', no: 'SO-2026-000136', status: TGSpecialRequestStatus.quoted, title: 'Quote-limit demo (5 quotes)', types: const [TGStoreSpecialty.shelvingStorage, TGStoreSpecialty.laserBending], sellers: const ['seller_gastropl', 'seller_inoxline', 'seller_stalbar', 'seller_metalgast', 'seller_rm'], budgetMin: 5000, budgetMax: 9000, createdAgo: const Duration(days: 7)),
    ];
    requests.addAll(seeds);
    _reqSeq = 139;

    for (final r in seeds) {
      if (r.status == TGSpecialRequestStatus.draft) continue;
      _grantAccess(r);
      if (r.teamQueued) teamQueue.add(r.id);
    }

    void q(String reqId, String seller, int price, int weeks, {TGQuoteStatus st = TGQuoteStatus.submitted, bool isNew = false}) {
      quotes.add(TGQuote(
        id: 'so-q-${_quoteSeq++}',
        requestId: reqId,
        sellerId: seller,
        priceNet: price,
        priceType: TGQuotePriceType.fixed,
        leadTimeWeeks: weeks,
        validUntil: now.add(const Duration(days: 14)),
        installationIncluded: true,
        deliveryIncluded: true,
        warrantyMonths: 24,
        paymentTerms: '40% advance, balance on delivery',
        note: 'Offer valid for 14 days. Fabrication in our workshop.',
        status: st,
        createdAt: now.subtract(Duration(hours: 6 + _quoteSeq)),
        isNew: isNew,
      ));
    }

    // 2-5 quotes on three requests
    q('so-req-2', 'seller_stalbar', 14500, 6);
    q('so-req-2', 'seller_rm', 15200, 5, isNew: true);
    q('so-req-3', 'seller_gastropl', 9800, 4);
    q('so-req-3', 'seller_stalbar', 10200, 5);
    q('so-req-3', 'seller_metalgast', 9100, 7, isNew: true);
    q('so-req-4', 'seller_rm', 26500, 8);
    q('so-req-4', 'seller_metalgast', 24800, 9);

    // awarded
    q('so-req-5', 'seller_rm', 98000, 10, st: TGQuoteStatus.awarded);
    q('so-req-5', 'seller_gastropl', 105000, 12, st: TGQuoteStatus.lost);

    // quote limit (5)
    q('so-req-14', 'seller_gastropl', 6200, 3);
    q('so-req-14', 'seller_inoxline', 5800, 4);
    q('so-req-14', 'seller_stalbar', 6400, 3);
    q('so-req-14', 'seller_metalgast', 5600, 5);
    q('so-req-14', 'seller_rm', 7000, 4);

    templates.add(const TGQuoteTemplate(
      id: 'tpl-1',
      sellerId: 'seller_gastropl',
      name: 'Standard install quote',
      priceType: TGQuotePriceType.fixed,
      leadTimeWeeks: 5,
      warrantyMonths: 24,
      paymentTerms: '40% advance, balance on delivery',
      note: 'Includes delivery in Śląskie.',
      installationIncluded: true,
      deliveryIncluded: true,
    ));
  }
}
