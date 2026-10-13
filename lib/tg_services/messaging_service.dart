import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_exif.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_no.dart';
import 'package:twoja_gastromania/tg_models/tg_listing_stats.dart';
import 'package:twoja_gastromania/tg_models/tg_message.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_services/listing_stats_service.dart';
import 'package:twoja_gastromania/tg_services/notification_service.dart';
import 'package:twoja_gastromania/tg_services/profanity_filter.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';

class MessagingService extends ChangeNotifier {
  MessagingService._();
  static final MessagingService instance = MessagingService._();

  static const _storageKey = '__tg_messages_v1__';
  static const mockIp = '192.0.2.10';

  final TGProfanityFilter filter = const TGProfanityFilter();
  final List<TGChatThread> threads = [];
  final List<TGModerationFlag> moderationFlags = [];
  bool _loaded = false;

  String? dockThreadId;
  bool dockInboxOpen = false;
  bool dockMinimized = false;
  String dockDraft = '';

  bool get dockVisible => dockThreadId != null || dockInboxOpen || dockMinimized;

  void reset() {
    threads.clear();
    moderationFlags.clear();
    _blocked.clear();
    _templates.clear();
    _loaded = false;
    dockThreadId = null;
    dockInboxOpen = false;
    dockMinimized = false;
    dockDraft = '';
    notifyListeners();
  }

  void openDock({String? threadId, bool inbox = false, String? draft, String? readerId}) {
    dockThreadId = threadId;
    dockInboxOpen = inbox || threadId == null;
    dockMinimized = false;
    if (draft != null) dockDraft = draft;
    if (threadId != null && readerId != null) markRead(threadId, readerId);
    notifyListeners();
  }

  void closeChat() {
    dockThreadId = null;
    if (!dockInboxOpen) dockMinimized = false;
    notifyListeners();
  }

  void closeDock() {
    dockThreadId = null;
    dockInboxOpen = false;
    dockMinimized = false;
    dockDraft = '';
    notifyListeners();
  }

  void minimizeDock() {
    dockMinimized = true;
    notifyListeners();
  }

  void restoreDock() {
    dockMinimized = false;
    if (dockThreadId == null) dockInboxOpen = true;
    notifyListeners();
  }

  TGChatThread ensureThread({
    required TGProduct product,
    required String senderId,
    required String senderName,
  }) {
    final sellerId = product.seller.id;
    final isSeller = senderId == sellerId;
    final buyerId = isSeller ? (_existingBuyer(product, sellerId) ?? senderId) : senderId;
    final id = threadIdFor(product, buyerId);
    var thread = byId(id);
    if (thread != null) return thread;
    thread = TGChatThread(
      id: id,
      listingId: product.id,
      listingTitle: product.title,
      listingImageUrl: product.imageUrl,
      listingPath: product.detailPath,
      listingPrice: product.price,
      listingNo: product.listingNo,
      buyerId: buyerId,
      sellerId: sellerId,
      buyerName: isSeller ? FakeAuthState.mockOwnerSeller.name : senderName,
      sellerName: product.seller.name,
      updatedAt: DateTime.now(),
      sellerPhone: product.phone.isEmpty ? null : product.phone,
      listingCity: product.city,
    );
    threads.insert(0, thread);
    _persist();
    notifyListeners();
    return thread;
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          threads
            ..clear()
            ..addAll([
              for (final item in decoded)
                if (item is Map<String, dynamic>) TGChatThread.fromJson(item),
            ]);
        }
      }
    } catch (e) {
      debugPrint('MessagingService load failed: $e');
    }
    if (threads.isEmpty) _seedDemo();
    notifyListeners();
  }

  /// Production Mode hides seeded mock conversations. Archived threads are
  /// listed only with [archived] = true.
  List<TGChatThread> inboxFor(String userId, {bool archived = false}) {
    final hideMock = TGRevenueConfigService.instance.productionMode;
    final list = threads
        .where((t) =>
            (t.buyerId == userId || t.sellerId == userId) &&
            !(hideMock && t.isMock) &&
            t.isArchivedFor(userId) == archived)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  void setArchived(String threadId, String userId, bool archived) {
    final t = byId(threadId);
    if (t == null) return;
    if (archived ? !t.archivedBy.add(userId) : !t.archivedBy.remove(userId)) return;
    TGAnalytics.track('msg_archive', {'threadId': threadId, 'archived': archived});
    _persist();
    notifyListeners();
  }

  final Map<String, Set<String>> _blocked = {};

  bool hasBlocked(String userId, String otherId) => _blocked[userId]?.contains(otherId) ?? false;

  Set<String> blockedOf(String userId) => Set.unmodifiable(_blocked[userId] ?? const <String>{});

  bool isBlockedBetween(String a, String b) => hasBlocked(a, b) || hasBlocked(b, a);

  void setBlocked(String userId, String otherId, bool blocked) {
    final set = _blocked.putIfAbsent(userId, () => {});
    if (blocked ? !set.add(otherId) : !set.remove(otherId)) return;
    TGAnalytics.track('msg_block', {'blocked': blocked});
    notifyListeners();
  }

  void markSoldTo(String threadId) {
    final t = byId(threadId);
    if (t == null || t.soldToBuyer) return;
    t.soldToBuyer = true;
    _persist();
    notifyListeners();
  }

  final List<TGMessageTemplate> _templates = [];

  List<TGMessageTemplate> templatesFor(String userId) =>
      _templates.where((t) => t.userId == userId).toList(growable: false);

  /// Returns an i18n error key, or null when saved.
  String? addTemplate(String userId, {required String title, required String body}) {
    if (title.trim().isEmpty || body.trim().isEmpty) return 'msg_err_template_empty';
    if (templatesFor(userId).length >= MessagingLimits.maxTemplates) return 'msg_err_template_limit';
    _templates.add(TGMessageTemplate(
      id: 'tpl_${DateTime.now().microsecondsSinceEpoch}_${_templates.length}',
      userId: userId,
      title: title.trim(),
      body: body.trim(),
    ));
    notifyListeners();
    return null;
  }

  void removeTemplate(String id) {
    _templates.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  void addMockThread(TGChatThread thread) {
    if (byId(thread.id) != null) return;
    threads.add(thread);
    notifyListeners();
  }

  int unreadTotal(String userId) => inboxFor(userId).fold(0, (n, t) => n + t.unreadFor(userId));

  TGChatThread? byId(String id) {
    for (final t in threads) {
      if (t.id == id) return t;
    }
    return null;
  }

  String threadIdFor(TGProduct product, String buyerId) => 't_${product.id}_$buyerId';

  /// Conversations [senderId] opened (sent the first message of) today.
  int newConversationsToday(String senderId, {DateTime? now}) {
    final t = now ?? TGClock.now();
    return threads.where((th) {
      if (th.messages.isEmpty) return false;
      final first = th.messages.first;
      return first.senderId == senderId &&
          first.timestamp.year == t.year &&
          first.timestamp.month == t.month &&
          first.timestamp.day == t.day;
    }).length;
  }

  static String _normalize(String s) => s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Identical messages [senderId] sent in the last hour, across all threads.
  int duplicatesInWindow(String senderId, String body, {DateTime? now}) {
    final t = now ?? TGClock.now();
    final since = t.subtract(MessagingLimits.duplicateWindow);
    final norm = _normalize(body);
    if (norm.isEmpty) return 0;
    var n = 0;
    for (final th in threads) {
      for (final m in th.messages) {
        if (m.senderId == senderId && m.timestamp.isAfter(since) && _normalize(m.body) == norm) n++;
      }
    }
    return n;
  }

  /// Validates and cleans photos: max 3, ≤ 5 MB each, JPEG / PNG / WebP only,
  /// EXIF removed. Returns the cleaned list or an i18n error key.
  ({List<TGMessageAttachment> files, String? error}) prepareAttachments(List<TGMessageAttachment> raw) {
    if (raw.length > MessagingLimits.maxAttachments) return (files: const [], error: 'msg_err_attach_count');
    final out = <TGMessageAttachment>[];
    for (final a in raw) {
      final size = a.bytes?.length ?? a.sizeBytes;
      if (size > MessagingLimits.maxAttachmentBytes) return (files: const [], error: 'msg_err_attach_size');
      final mime = a.bytes == null ? a.mimeType : (TGExif.sniffMime(a.bytes!) ?? a.mimeType);
      if (!MessagingLimits.allowedImageTypes.contains(mime)) return (files: const [], error: 'msg_err_attach_type');
      final clean = a.bytes == null ? null : TGExif.strip(a.bytes!);
      out.add(TGMessageAttachment(
        id: a.id,
        fileName: a.fileName,
        mimeType: mime,
        sizeBytes: clean?.length ?? a.sizeBytes,
        bytes: clean,
        exifStripped: clean != null,
      ));
    }
    return (files: out, error: null);
  }

  TGSendResult send({
    required TGProduct product,
    required String senderId,
    required String senderName,
    required String body,
    TGMessageKind kind = TGMessageKind.text,
    String? listingPath,
    int? quotePln,
    String ipAddress = mockIp,
    List<TGMessageAttachment> attachments = const [],
  }) {
    final trimmed = body.trim();
    if (trimmed.isEmpty && attachments.isEmpty) return const TGSendResult(ok: false);
    if (trimmed.isNotEmpty && filter.isBlocked(trimmed)) {
      TGAnalytics.emit('message_blocked', {'listingId': product.id, 'reason': 'profanity'});
      return const TGSendResult(ok: false, blocked: true, reason: 'ui_message_blocked');
    }
    final now = TGClock.now();
    final sellerId = product.seller.id;
    final existingBuyer = senderId == sellerId ? (_existingBuyer(product, sellerId) ?? senderId) : senderId;
    final existing = byId(threadIdFor(product, existingBuyer));
    final receiverGuess = senderId == sellerId ? existingBuyer : sellerId;
    if (isBlockedBetween(senderId, receiverGuess)) {
      TGAnalytics.emit('message_blocked', {'listingId': product.id, 'reason': 'blocked_user'});
      return TGSendResult(ok: false, blocked: true, threadId: existing?.id, reason: 'msg_err_blocked');
    }
    final opening = existing == null || existing.messages.isEmpty;
    if (opening && newConversationsToday(senderId, now: now) >= MessagingLimits.maxNewConversationsPerDay) {
      TGAnalytics.emit('message_blocked', {'listingId': product.id, 'reason': 'daily_new_limit'});
      return const TGSendResult(ok: false, blocked: true, reason: 'msg_err_daily_limit');
    }
    if (trimmed.isNotEmpty && duplicatesInWindow(senderId, trimmed, now: now) >= MessagingLimits.duplicateSpamCount - 1) {
      final flagged = existing?.id ?? threadIdFor(product, existingBuyer);
      moderationFlags.add(TGModerationFlag(threadId: flagged, reporterId: 'system', createdAt: now, reason: 'spam_duplicate'));
      TGAnalytics.emit('message_blocked', {'listingId': product.id, 'reason': 'spam_duplicate'});
      notifyListeners();
      return TGSendResult(ok: false, blocked: true, threadId: existing?.id, reason: 'msg_err_spam');
    }
    final prepared = prepareAttachments(attachments);
    if (prepared.error != null) return TGSendResult(ok: false, threadId: existing?.id, reason: prepared.error);

    final thread = ensureThread(product: product, senderId: senderId, senderName: senderName);

    final receiverId = senderId == thread.buyerId ? thread.sellerId : thread.buyerId;
    final message = TGChatMessage(
      id: 'm_${DateTime.now().microsecondsSinceEpoch}',
      senderId: senderId,
      receiverId: receiverId,
      timestamp: now,
      ipAddress: ipAddress,
      body: trimmed,
      kind: kind,
      listingPath: listingPath,
      quotePln: quotePln,
      attachments: prepared.files,
    );
    thread.messages.add(message);
    thread.archivedBy.remove(receiverId);
    if (opening && senderId == thread.buyerId) {
      TGListingStatsService.instance.record(
        listingKey: TGListingStatsService.productKey(thread.listingId),
        kind: ListingStatKind.message,
        visitorKey: senderId,
        count: senderId != thread.sellerId,
        at: now,
      );
    }
    TGAnalytics.track('msg_send', {
      'threadId': thread.id,
      'kind': kind.name,
      'attachments': prepared.files.length,
      'opening': opening,
    });
    thread.updatedAt = message.timestamp;
    if (senderId == thread.buyerId) {
      thread.unreadSeller += 1;
    } else {
      thread.unreadBuyer += 1;
    }
    threads
      ..remove(thread)
      ..insert(0, thread);
    TGAnalytics.emit('message_sent', {'listingId': product.id, 'threadId': thread.id, 'kind': kind.name});
    if (receiverId.isNotEmpty && receiverId != senderId) {
      NotificationService.instance.add(
        userId: receiverId,
        type: 'new_message',
        dealId: thread.id,
        title: 'new_message',
        body: trimmed.isEmpty ? '📷 ${prepared.files.length}' : trimmed,
        deepLink: '/dashboard/messages?thread=${thread.id}',
        params: {
          'title': thread.listingTitle,
          'name': senderName,
          'preview': trimmed.isEmpty ? '📷 ${prepared.files.length}' : trimmed,
        },
      );
    }
    _persist();
    notifyListeners();
    return TGSendResult(ok: true, threadId: thread.id, message: message);
  }

  String? _existingBuyer(TGProduct product, String sellerId) {
    for (final t in threads) {
      if (t.listingId == product.id && t.sellerId == sellerId) return t.buyerId;
    }
    return null;
  }

  void markRead(String threadId, String userId) {
    final thread = byId(threadId);
    if (thread == null) return;
    if (userId == thread.buyerId) {
      if (thread.unreadBuyer == 0) return;
      thread.unreadBuyer = 0;
    } else {
      if (thread.unreadSeller == 0) return;
      thread.unreadSeller = 0;
    }
    notifyListeners();
    _persist();
  }

  void reportThread(String threadId, String reporterId, {String reason = 'user_report'}) {
    final thread = byId(threadId);
    if (thread == null) return;
    thread.reported = true;
    for (final m in thread.messages) {
      m.isReported = true;
    }
    moderationFlags.add(TGModerationFlag(
      threadId: threadId,
      reporterId: reporterId,
      createdAt: DateTime.now(),
      reason: reason,
    ));
    TGAnalytics.emit('conversation_reported', {'threadId': threadId, 'reporterId': reporterId});
    TGAnalytics.track('msg_report', {'threadId': threadId, 'reason': reason});
    notifyListeners();
    _persist();
  }

  void _seedDemo() {
    final now = DateTime.now();
    threads.add(
      TGChatThread(
        id: 't_p001_${FakeAuthState.mockOwnerId}',
        listingId: 'p001',
        listingTitle: 'Piec konwekcyjno-parowy 10x GN 1/1 – Bartscher',
        listingImageUrl: 'assets/images/mutfak-ekipmanlari.jpg',
        listingPath: '/product-detail/10482137-piec-konwekcyjno-parowy-10x-gn-11-bartscher',
        listingPrice: 12500,
        listingNo: '10482137',
        buyerId: FakeAuthState.mockOwnerId,
        sellerId: 'seller_primegastro',
        buyerName: 'TG Demo',
        sellerName: 'PrimeGastro',
        updatedAt: now.subtract(const Duration(minutes: 18)),
        unreadBuyer: 1,
        isMock: true,
        sellerPhone: '+48 (532) 784-074',
        listingCity: 'Katowice',
        messages: [
          TGChatMessage(
            id: 'm_seed_1',
            senderId: FakeAuthState.mockOwnerId,
            receiverId: 'seller_primegastro',
            timestamp: now.subtract(const Duration(minutes: 40)),
            ipAddress: mockIp,
            body: 'Czy to ogłoszenie jest jeszcze dostępne?',
          ),
          TGChatMessage(
            id: 'm_seed_2',
            senderId: 'seller_primegastro',
            receiverId: FakeAuthState.mockOwnerId,
            timestamp: now.subtract(const Duration(minutes: 18)),
            ipAddress: mockIp,
            body: 'Tak — odbiór osobisty w Katowicach.',
          ),
        ],
      ),
    );
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(threads.map((t) => t.toJson()).toList()));
    } catch (e) {
      debugPrint('MessagingService persist failed: $e');
    }
  }
}
