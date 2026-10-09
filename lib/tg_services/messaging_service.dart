import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_no.dart';
import 'package:twoja_gastromania/tg_models/tg_message.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_services/notification_service.dart';
import 'package:twoja_gastromania/tg_services/profanity_filter.dart';

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

  List<TGChatThread> inboxFor(String userId) {
    final list = threads.where((t) => t.buyerId == userId || t.sellerId == userId).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  int unreadTotal(String userId) => inboxFor(userId).fold(0, (n, t) => n + t.unreadFor(userId));

  TGChatThread? byId(String id) {
    for (final t in threads) {
      if (t.id == id) return t;
    }
    return null;
  }

  String threadIdFor(TGProduct product, String buyerId) => 't_${product.id}_$buyerId';

  TGSendResult send({
    required TGProduct product,
    required String senderId,
    required String senderName,
    required String body,
    TGMessageKind kind = TGMessageKind.text,
    String? listingPath,
    int? quotePln,
    String ipAddress = mockIp,
  }) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return const TGSendResult(ok: false);
    if (filter.isBlocked(trimmed)) {
      TGAnalytics.emit('message_blocked', {'listingId': product.id, 'reason': 'profanity'});
      return const TGSendResult(ok: false, blocked: true);
    }

    final thread = ensureThread(product: product, senderId: senderId, senderName: senderName);

    final receiverId = senderId == thread.buyerId ? thread.sellerId : thread.buyerId;
    final message = TGChatMessage(
      id: 'm_${DateTime.now().microsecondsSinceEpoch}',
      senderId: senderId,
      receiverId: receiverId,
      timestamp: DateTime.now(),
      ipAddress: ipAddress,
      body: trimmed,
      kind: kind,
      listingPath: listingPath,
      quotePln: quotePln,
    );
    thread.messages.add(message);
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
        body: trimmed,
        deepLink: '/dashboard/messages?thread=${thread.id}',
        params: {
          'title': thread.listingTitle,
          'name': senderName,
          'preview': trimmed,
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
        listingImageUrl: 'assets/images/bartscher_2002170.webp',
        listingPath: '/product-detail/10482137-piec-konwekcyjno-parowy-10x-gn-11-bartscher',
        listingPrice: 12500,
        listingNo: '10482137',
        buyerId: FakeAuthState.mockOwnerId,
        sellerId: 'seller_primegastro',
        buyerName: 'TG Demo',
        sellerName: 'PrimeGastro',
        updatedAt: now.subtract(const Duration(minutes: 18)),
        unreadBuyer: 1,
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
