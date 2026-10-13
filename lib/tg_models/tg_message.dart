import 'dart:typed_data';

enum TGMessageKind { text, listingLink, priceQuote }

/// Photo attached to a message. Bytes stay in memory (EXIF already removed);
/// only metadata is persisted.
class TGMessageAttachment {
  const TGMessageAttachment({
    required this.id,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    this.bytes,
    this.exifStripped = false,
  });

  final String id;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final Uint8List? bytes;
  final bool exifStripped;

  Map<String, Object?> toJson() => {
        'id': id,
        'fileName': fileName,
        'mimeType': mimeType,
        'sizeBytes': sizeBytes,
        'exifStripped': exifStripped,
      };

  static TGMessageAttachment fromJson(Map<String, dynamic> json) => TGMessageAttachment(
        id: (json['id'] ?? '').toString(),
        fileName: (json['fileName'] ?? '').toString(),
        mimeType: (json['mimeType'] ?? '').toString(),
        sizeBytes: json['sizeBytes'] is num ? (json['sizeBytes'] as num).toInt() : 0,
        exifStripped: json['exifStripped'] == true,
      );
}

/// Saved quick reply (max [MessagingLimits.maxTemplates] per user).
class TGMessageTemplate {
  const TGMessageTemplate({required this.id, required this.userId, required this.title, required this.body});

  final String id;
  final String userId;
  final String title;
  final String body;

  TGMessageTemplate copyWith({String? title, String? body}) =>
      TGMessageTemplate(id: id, userId: userId, title: title ?? this.title, body: body ?? this.body);
}

abstract final class MessagingLimits {
  static const maxAttachments = 3;
  static const maxAttachmentBytes = 5 * 1024 * 1024;
  static const allowedImageTypes = {'image/jpeg', 'image/png', 'image/webp'};
  static const maxTemplates = 10;
  static const maxNewConversationsPerDay = 20;
  static const duplicateWindow = Duration(hours: 1);
  static const duplicateSpamCount = 5;
}

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
    this.attachments = const [],
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
  final List<TGMessageAttachment> attachments;

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
        if (attachments.isNotEmpty) 'attachments': attachments.map((a) => a.toJson()).toList(),
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
        attachments: [
          for (final item in (json['attachments'] as List? ?? const []))
            if (item is Map<String, dynamic>) TGMessageAttachment.fromJson(item),
        ],
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
    Set<String>? archivedBy,
    this.isMock = false,
    this.buyerPhone,
    this.sellerPhone,
    this.listingCity = '',
    this.soldToBuyer = false,
    this.buyerSince,
    this.sellerSince,
  })  : messages = messages ?? [],
        archivedBy = archivedBy ?? {};

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
  final Set<String> archivedBy;
  final bool isMock;
  final String? buyerPhone;
  final String? sellerPhone;
  final String listingCity;
  bool soldToBuyer;
  final DateTime? buyerSince;
  final DateTime? sellerSince;

  String otherPartyId(String userId) => userId == buyerId ? sellerId : buyerId;
  String otherPartyName(String userId) => userId == buyerId ? sellerName : buyerName;
  String? otherPartyPhone(String userId) => userId == buyerId ? sellerPhone : buyerPhone;
  DateTime? otherPartySince(String userId) => userId == buyerId ? sellerSince : buyerSince;
  bool isArchivedFor(String userId) => archivedBy.contains(userId);

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
        'archivedBy': archivedBy.toList(),
        'isMock': isMock,
        'buyerPhone': buyerPhone,
        'sellerPhone': sellerPhone,
        'listingCity': listingCity,
        'soldToBuyer': soldToBuyer,
        'buyerSince': buyerSince?.toIso8601String(),
        'sellerSince': sellerSince?.toIso8601String(),
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
        archivedBy: {for (final id in (json['archivedBy'] as List? ?? const [])) id.toString()},
        isMock: json['isMock'] == true,
        buyerPhone: json['buyerPhone']?.toString(),
        sellerPhone: json['sellerPhone']?.toString(),
        listingCity: (json['listingCity'] ?? '').toString(),
        soldToBuyer: json['soldToBuyer'] == true,
        buyerSince: DateTime.tryParse((json['buyerSince'] ?? '').toString()),
        sellerSince: DateTime.tryParse((json['sellerSince'] ?? '').toString()),
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
  const TGSendResult({required this.ok, this.threadId, this.blocked = false, this.message, this.reason});
  final bool ok;
  final bool blocked;

  /// i18n key explaining a refusal (`ui_message_blocked`, `msg_err_*`).
  final String? reason;
  final String? threadId;
  final TGChatMessage? message;
}
