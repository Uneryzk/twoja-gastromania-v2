enum TGMessageKind { text, listingLink, priceQuote }

class TGChatMessage {
  TGChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.timestamp,
    required this.ipAddress,
    required this.body,
    this.isReported = false,
    this.kind = TGMessageKind.text,
    this.listingPath,
    this.quotePln,
  });

  final String id;
  final String senderId;
  final String receiverId;
  final DateTime timestamp;
  final String ipAddress;
  bool isReported;
  final String body;
  final TGMessageKind kind;
  final String? listingPath;
  final int? quotePln;

  Map<String, Object?> toLegalLog() => {
        'sender_id': senderId,
        'receiver_id': receiverId,
        'timestamp': timestamp.toIso8601String(),
        'ip_address': ipAddress,
        'is_reported': isReported,
        'body': body,
        'kind': kind.name,
      };

  Map<String, Object?> toJson() => {
        'id': id,
        'sender_id': senderId,
        'receiver_id': receiverId,
        'timestamp': timestamp.toIso8601String(),
        'ip_address': ipAddress,
        'is_reported': isReported,
        'body': body,
        'kind': kind.name,
        'listingPath': listingPath,
        'quotePln': quotePln,
      };

  static TGChatMessage fromJson(Map<String, dynamic> json) => TGChatMessage(
        id: (json['id'] ?? '').toString(),
        senderId: (json['sender_id'] ?? json['senderId'] ?? '').toString(),
        receiverId: (json['receiver_id'] ?? json['receiverId'] ?? '').toString(),
        timestamp: DateTime.tryParse((json['timestamp'] ?? '').toString()) ?? DateTime.now(),
        ipAddress: (json['ip_address'] ?? json['ipAddress'] ?? '').toString(),
        isReported: json['is_reported'] == true || json['isReported'] == true,
        body: (json['body'] ?? '').toString(),
        kind: switch ((json['kind'] ?? 'text').toString()) {
          'listingLink' => TGMessageKind.listingLink,
          'priceQuote' => TGMessageKind.priceQuote,
          _ => TGMessageKind.text,
        },
        listingPath: json['listingPath']?.toString(),
        quotePln: json['quotePln'] is num ? (json['quotePln'] as num).toInt() : null,
      );
}

class TGChatThread {
  TGChatThread({
    required this.id,
    required this.listingId,
    required this.listingTitle,
    required this.listingImageUrl,
    required this.listingPath,
    required this.buyerId,
    required this.sellerId,
    required this.buyerName,
    required this.sellerName,
    required this.updatedAt,
    this.listingPrice,
    this.listingNo,
    List<TGChatMessage>? messages,
    this.reported = false,
    this.unreadBuyer = 0,
    this.unreadSeller = 0,
  }) : messages = messages ?? [];

  final String id;
  final String listingId;
  final String listingTitle;
  final String listingImageUrl;
  final String listingPath;
  final int? listingPrice;
  final String? listingNo;
  final String buyerId;
  final String sellerId;
  final String buyerName;
  final String sellerName;
  DateTime updatedAt;
  final List<TGChatMessage> messages;
  bool reported;
  int unreadBuyer;
  int unreadSeller;

  String otherPartyId(String userId) => userId == buyerId ? sellerId : buyerId;
  String otherPartyName(String userId) => userId == buyerId ? sellerName : buyerName;

  int unreadFor(String userId) => userId == buyerId ? unreadBuyer : unreadSeller;

  TGChatMessage? get lastMessage => messages.isEmpty ? null : messages.last;

  Map<String, Object?> toJson() => {
        'id': id,
        'listingId': listingId,
        'listingTitle': listingTitle,
        'listingImageUrl': listingImageUrl,
        'listingPath': listingPath,
        'listingPrice': listingPrice,
        'listingNo': listingNo,
        'buyerId': buyerId,
        'sellerId': sellerId,
        'buyerName': buyerName,
        'sellerName': sellerName,
        'updatedAt': updatedAt.toIso8601String(),
        'reported': reported,
        'unreadBuyer': unreadBuyer,
        'unreadSeller': unreadSeller,
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  static TGChatThread fromJson(Map<String, dynamic> json) => TGChatThread(
        id: (json['id'] ?? '').toString(),
        listingId: (json['listingId'] ?? '').toString(),
        listingTitle: (json['listingTitle'] ?? '').toString(),
        listingImageUrl: (json['listingImageUrl'] ?? '').toString(),
        listingPath: (json['listingPath'] ?? '').toString(),
        listingPrice: json['listingPrice'] is num ? (json['listingPrice'] as num).toInt() : null,
        listingNo: json['listingNo']?.toString(),
        buyerId: (json['buyerId'] ?? '').toString(),
        sellerId: (json['sellerId'] ?? '').toString(),
        buyerName: (json['buyerName'] ?? '').toString(),
        sellerName: (json['sellerName'] ?? '').toString(),
        updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString()) ?? DateTime.now(),
        reported: json['reported'] == true,
        unreadBuyer: json['unreadBuyer'] is num ? (json['unreadBuyer'] as num).toInt() : 0,
        unreadSeller: json['unreadSeller'] is num ? (json['unreadSeller'] as num).toInt() : 0,
        messages: [
          for (final item in (json['messages'] as List? ?? const []))
            if (item is Map<String, dynamic>) TGChatMessage.fromJson(item),
        ],
      );
}

class TGModerationFlag {
  const TGModerationFlag({
    required this.threadId,
    required this.reporterId,
    required this.createdAt,
    required this.reason,
  });

  final String threadId;
  final String reporterId;
  final DateTime createdAt;
  final String reason;
}

class TGSendResult {
  const TGSendResult({required this.ok, this.threadId, this.blocked = false, this.message});
  final bool ok;
  final bool blocked;
  final String? threadId;
  final TGChatMessage? message;
}
