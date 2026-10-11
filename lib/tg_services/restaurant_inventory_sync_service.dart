import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:twoja_gastromania/tg_core/pl_business_days.dart';
import 'package:twoja_gastromania/tg_core/restaurant_config.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_restaurant_listing.dart';
import 'package:twoja_gastromania/tg_services/moderation_service.dart';
import 'package:twoja_gastromania/tg_services/notification_service.dart';
import 'package:twoja_gastromania/tg_services/product_service.dart';
import 'package:twoja_gastromania/tg_services/restaurant_service.dart';

/// Separate-listing sold → restaurant inventory sync + description-check cases.
class RestaurantInventorySyncService extends ChangeNotifier {
  RestaurantInventorySyncService._();
  static final RestaurantInventorySyncService instance = RestaurantInventorySyncService._();

  RestaurantConfig get cfg => RestaurantConfigService.instance.config;

  final List<RestoDescriptionCheckCase> descriptionCases = [];
  final Map<String, _SyncUndo> _undos = {};
  final Map<String, Set<String>> _notified = {};

  List<RestoSyncCard> syncCardsFor(String ownerId) {
    final out = <RestoSyncCard>[];
    for (final r in RestaurantService.instance.ownedBy(ownerId)) {
      for (final item in r.inventory) {
        if (item.status == RestaurantInventoryStatus.soldSeparatelyPending) {
          out.add(RestoSyncCard(listing: r, item: item));
        }
      }
    }
    return out;
  }

  /// Called when an equipment listing is marked sold (not expired / removed).
  void onSeparateListingSold(TGProduct product) {
    final no = product.listingNo;
    if (no == null || no.isEmpty) return;
    for (final r in [...RestaurantService.instance.all]) {
      final idx = r.inventory.indexWhere((i) => i.linkedListingNo == no);
      if (idx < 0) continue;
      final item = r.inventory[idx];
      if (item.status == RestaurantInventoryStatus.archived) continue;
      final due = PLBusinessDays.addBusinessDays(TGClock.now(), cfg.soldItemReviewBusinessDays);
      final nextInv = [...r.inventory];
      nextInv[idx] = item.copyWith(
        status: RestaurantInventoryStatus.soldSeparatelyPending,
        statusChangedAt: TGClock.now(),
        reviewDueAt: due,
      );
      RestaurantService.instance.replace(r.copyWith(inventory: nextInv));
      TGAnalytics.track('inventory_sold_sync', {
        'listingNo': r.listingNo,
        'itemId': item.id,
        'linkedListingNo': no,
      });
      NotificationService.instance.add(
        userId: r.ownerId,
        type: 'resto_inventory_sold_sync',
        dealId: r.id,
        title: 'You marked ${item.name} as sold',
        body: 'Is it still part of your restaurant listing? Please update the description.',
        deepLink: '/dashboard/listings?sync=${r.id}&item=${item.id}',
      );
      notifyListeners();
      return;
    }
  }

  bool isLinkedSeparateListing(TGProduct product) {
    final no = product.listingNo;
    if (no == null) return false;
    return RestaurantService.instance.all.any((r) => r.inventory.any((i) => i.linkedListingNo == no));
  }

  void removeFromTransfer({required String listingId, required String itemId, required String actorId}) {
    _act(listingId, itemId, actorId, 'remove', (item) {
      return item.copyWith(status: RestaurantInventoryStatus.archived, statusChangedAt: TGClock.now());
    });
  }

  void stillIncluded({
    required String listingId,
    required String itemId,
    required String actorId,
    int? qtyLeft,
  }) {
    _act(listingId, itemId, actorId, 'still_included', (item) {
      return item.copyWith(
        status: RestaurantInventoryStatus.active,
        statusChangedAt: TGClock.now(),
        clearReviewDue: true,
        qty: qtyLeft ?? item.qty,
        availability: RestaurantInventoryAvailability.included,
      );
    });
  }

  void _act(
    String listingId,
    String itemId,
    String actorId,
    String action,
    RestaurantInventoryItem Function(RestaurantInventoryItem) map,
  ) {
    final r = RestaurantService.instance.byId(listingId);
    if (r == null) return;
    final snap = r;
    final nextInv = [
      for (final i in r.inventory)
        if (i.id == itemId) map(i) else i,
    ];
    RestaurantService.instance.replace(r.copyWith(inventory: nextInv, updatedAt: TGClock.now()));
    _undos['$listingId|$itemId'] = _SyncUndo(snapshot: snap, until: DateTime.now().add(const Duration(seconds: 10)));
    TGAnalytics.track('inventory_sync_action', {'action': action, 'listingNo': r.listingNo, 'itemId': itemId, 'actor': actorId});
    notifyListeners();
  }

  bool undo(String listingId, String itemId) {
    final u = _undos.remove('$listingId|$itemId');
    if (u == null || !u.until.isAfter(DateTime.now())) return false;
    RestaurantService.instance.replace(u.snapshot);
    notifyListeners();
    return true;
  }

  /// When seller tries to set availability=included on a previously sold item.
  bool needsSoldConfirm(RestaurantInventoryItem item) {
    return item.status == RestaurantInventoryStatus.archived ||
        item.status == RestaurantInventoryStatus.soldSeparatelyPending ||
        (item.statusChangedAt != null && item.linkedListingNo != null);
  }

  String soldConfirmMessage(RestaurantInventoryItem item) {
    final d = item.statusChangedAt;
    final when = d == null ? 'recently' : DateFormat('d MMM').format(d);
    return 'This item was sold separately on $when. Is another unit available?';
  }

  void onClockAdvanced() {
    final now = TGClock.now();
    for (final r in [...RestaurantService.instance.all]) {
      var changed = false;
      final nextInv = <RestaurantInventoryItem>[];
      for (final item in r.inventory) {
        if (item.status == RestaurantInventoryStatus.soldSeparatelyPending && item.reviewDueAt != null) {
          final daysLeft = PLBusinessDays.businessDaysBetween(now, item.reviewDueAt!);
          // Day-3 reminder (2 business days before a 5-day deadline).
          if (daysLeft == 2) {
            final key = 'sync_d3_${item.id}';
            final seen = _notified.putIfAbsent(r.id, () => {});
            if (seen.add(key)) {
              NotificationService.instance.add(
                userId: r.ownerId,
                type: 'resto_inventory_sync_reminder',
                dealId: r.id,
                title: 'Update ${item.name} on your restaurant listing',
                body: 'Review deadline in 2 business days.',
                deepLink: '/dashboard/listings?sync=${r.id}&item=${item.id}',
              );
            }
          }
          if (!item.reviewDueAt!.isAfter(now)) {
            nextInv.add(item.copyWith(status: RestaurantInventoryStatus.archived, statusChangedAt: now));
            changed = true;
            NotificationService.instance.add(
              userId: r.ownerId,
              type: 'resto_inventory_auto_archived',
              dealId: r.id,
              title: '${item.name} removed from transfer list',
              body: 'No update received by the deadline. The item was archived.',
              deepLink: r.detailPath,
            );
            _maybeOpenDescriptionCheck(r, item);
            continue;
          }
        }
        nextInv.add(item);
      }
      if (changed) {
        RestaurantService.instance.replace(r.copyWith(inventory: nextInv));
      }
    }

    // Clear "Also listed separately" when linked listing is gone/expired.
    for (final r in [...RestaurantService.instance.all]) {
      var touched = false;
      final next = <RestaurantInventoryItem>[];
      for (final item in r.inventory) {
        final no = item.linkedListingNo;
        if (no == null || item.status != RestaurantInventoryStatus.active) {
          next.add(item);
          continue;
        }
        final p = TGProductService.instance.cachedByNo(no);
        final dead = p != null &&
            (p.status == TGListingStatus.expired || p.status == TGListingStatus.removed);
        if (dead) {
          next.add(item.copyWith(clearLinked: true, availability: RestaurantInventoryAvailability.included));
          touched = true;
        } else {
          next.add(item);
        }
      }
      if (touched) RestaurantService.instance.replace(r.copyWith(inventory: next));
    }
    notifyListeners();
  }

  void _maybeOpenDescriptionCheck(RestaurantListing r, RestaurantInventoryItem item) {
    final hits = matchDescriptionSentences(r.description, item.name);
    if (hits.isEmpty) return;
    if (descriptionCases.any((c) => c.listingNo == r.listingNo && c.itemId == item.id && !c.resolved)) return;
    final kase = RestoDescriptionCheckCase(
      id: 'dc_${r.listingNo}_${item.id}',
      listingNo: r.listingNo,
      restaurantId: r.id,
      itemId: item.id,
      itemName: item.name,
      matchedSentences: hits,
      openedAt: TGClock.now(),
      slaDeadline: PLBusinessDays.addBusinessDays(TGClock.now(), 2),
    );
    descriptionCases.insert(0, kase);
    TGAnalytics.track('description_check_open', {'listingNo': r.listingNo, 'itemId': item.id});
    ModerationService.instance.ensureSeeded();
    // Soft flag on moderation case if present.
    final mc = ModerationService.instance.caseFor(r.listingNo);
    if (mc != null && !mc.flags.contains('Description check')) {
      mc.flags = [...mc.flags, 'Description check'];
    }
    notifyListeners();
  }

  /// Dictionary match including simple Polish inflection stems.
  static List<String> matchDescriptionSentences(String description, String itemName) {
    final stems = _stems(itemName);
    final sentences = description.split(RegExp(r'(?<=[.!?])\s+'));
    return [
      for (final s in sentences)
        if (stems.any((st) => s.toLowerCase().contains(st))) s.trim(),
    ].where((s) => s.isNotEmpty).toList();
  }

  static List<String> _stems(String name) {
    final lower = name.toLowerCase().trim();
    final parts = lower.split(RegExp(r'\s+'));
    final out = <String>{lower};
    for (final p in parts) {
      if (p.length < 4) continue;
      out.add(p);
      // crude PL stem: drop trailing vowels / common endings
      out.add(p.replaceAll(RegExp(r'(em|ami|ach|ów|y|a|e|i)$'), ''));
      // EN: fryer/fryers
      if (p.endsWith('s') && p.length > 4) out.add(p.substring(0, p.length - 1));
    }
    // PL dictionary aliases
    if (lower.contains('fryer') || lower.contains('frytkown')) {
      out.addAll(['fryer', 'frytkownic', 'frytkownica']);
    }
    if (lower.contains('dishwasher') || lower.contains('zmywark')) {
      out.addAll(['dishwasher', 'zmywark']);
    }
    if (lower.contains('combi') || lower.contains('piec')) {
      out.addAll(['combi', 'piec', 'konwekcyjno']);
    }
    return out.where((s) => s.length >= 3).toList();
  }

  String? applyDescriptionAction({
    required String caseId,
    required RestoDescriptionCheckAction action,
    required String actorId,
    required String actorRole,
    String? sentence,
    String? minimalEdit,
  }) {
    final kase = descriptionCases.where((c) => c.id == caseId).firstOrNull;
    if (kase == null || kase.resolved) return 'Case not found';
    final r = RestaurantService.instance.byId(kase.restaurantId);
    if (r == null) return 'Listing missing';
    final before = r.description;
    var after = before;
    switch (action) {
      case RestoDescriptionCheckAction.removeSentence:
        if (sentence == null || sentence.isEmpty) return 'Select a sentence';
        after = before.replaceFirst(sentence, '').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
      case RestoDescriptionCheckAction.editMinimally:
        if (minimalEdit == null) return 'Provide edit';
        after = minimalEdit;
      case RestoDescriptionCheckAction.dismiss:
        after = before;
    }
    final undoSnap = r;
    RestaurantService.instance.replace(r.copyWith(description: after, updatedAt: TGClock.now()));
    kase.resolved = true;
    kase.resolvedAction = action;
    kase.resolvedAt = TGClock.now();
    _undos[caseId] = _SyncUndo(snapshot: undoSnap, until: DateTime.now().add(const Duration(seconds: 10)), caseId: caseId);
    TGAnalytics.track('description_check_action', {
      'caseId': caseId,
      'action': action.name,
      'actor': actorId,
    });
    ModerationService.instance.recordRestoDescriptionAudit(
      listingNo: kase.listingNo,
      actorId: actorId,
      actorRole: actorRole,
      summary: '${action.label} · ${kase.itemName}',
      reason: 'Description still mentioned sold item',
    );
    NotificationService.instance.add(
      userId: r.ownerId,
      type: 'resto_description_moderated',
      dealId: r.id,
      title: 'Your listing description was updated',
      body: action == RestoDescriptionCheckAction.dismiss
          ? 'A moderator reviewed the description check and found no conflict.'
          : 'A moderator edited your description (sold equipment mention). You can edit it afterwards.',
      deepLink: r.detailPath,
    );
    notifyListeners();
    return null;
  }

  bool undoDescriptionCase(String caseId) {
    final u = _undos.remove(caseId);
    if (u == null || !u.until.isAfter(DateTime.now())) return false;
    RestaurantService.instance.replace(u.snapshot);
    final kase = descriptionCases.where((c) => c.id == caseId).firstOrNull;
    if (kase != null) {
      kase.resolved = false;
      kase.resolvedAction = null;
      kase.resolvedAt = null;
    }
    notifyListeners();
    return true;
  }

  EmailPreview previewDescriptionEmail({
    required RestaurantListing listing,
    required String before,
    required String after,
    required RestoDescriptionCheckAction action,
  }) {
    return EmailPreview(
      to: 'seller@example.com',
      subject: 'Update about your restaurant listing ${listing.listingNo}',
      body: '''
Hello ${listing.seller.name},

A moderator reviewed your listing description after a separately sold item.

Action: ${action.label}
Reason: Description still mentioned equipment that was sold separately.

Before:
$before

After:
$after

Edit your description: https://twojagastromania.pl${listing.detailPath}

— Twoja Gastromania
''',
    );
  }

  void ensureSeeded() {
    if (descriptionCases.isNotEmpty) return;
    final r014 = RestaurantService.instance.byId('r014');
    if (r014 == null) return;
    // Expired description-check case (SLA passed).
    descriptionCases.add(
      RestoDescriptionCheckCase(
        id: 'dc_seed_expired',
        listingNo: r014.listingNo,
        restaurantId: r014.id,
        itemId: 'r014-inv-0',
        itemName: 'Combi oven 1',
        matchedSentences: matchDescriptionSentences(
          '${r014.description} The combi oven is included in the transfer.',
          'Combi oven 1',
        ),
        openedAt: TGClock.now().subtract(const Duration(days: 5)),
        slaDeadline: TGClock.now().subtract(const Duration(days: 1)),
      ),
    );
  }

  void reset() {
    descriptionCases.clear();
    _undos.clear();
    _notified.clear();
    notifyListeners();
  }
}

class RestoSyncCard {
  const RestoSyncCard({required this.listing, required this.item});
  final RestaurantListing listing;
  final RestaurantInventoryItem item;
}

enum RestoDescriptionCheckAction { removeSentence, editMinimally, dismiss }

extension on RestoDescriptionCheckAction {
  String get label => switch (this) {
        RestoDescriptionCheckAction.removeSentence => 'Remove sentence',
        RestoDescriptionCheckAction.editMinimally => 'Edit minimally',
        RestoDescriptionCheckAction.dismiss => 'Dismiss (no conflict)',
      };
}

class RestoDescriptionCheckCase {
  RestoDescriptionCheckCase({
    required this.id,
    required this.listingNo,
    required this.restaurantId,
    required this.itemId,
    required this.itemName,
    required this.matchedSentences,
    required this.openedAt,
    required this.slaDeadline,
    this.resolved = false,
    this.resolvedAction,
    this.resolvedAt,
  });

  final String id;
  final String listingNo;
  final String restaurantId;
  final String itemId;
  final String itemName;
  final List<String> matchedSentences;
  final DateTime openedAt;
  final DateTime slaDeadline;
  bool resolved;
  RestoDescriptionCheckAction? resolvedAction;
  DateTime? resolvedAt;
}

class EmailPreview {
  const EmailPreview({required this.to, required this.subject, required this.body});
  final String to;
  final String subject;
  final String body;
}

class _SyncUndo {
  _SyncUndo({required this.snapshot, required this.until, this.caseId});
  final RestaurantListing snapshot;
  final DateTime until;
  final String? caseId;
}
