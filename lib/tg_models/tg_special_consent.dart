import 'package:flutter/foundation.dart';

/// Immutable proof that a buyer accepted the Special Order consent text.
@immutable
class TGSpecialRequestConsent {
  const TGSpecialRequestConsent({
    required this.id,
    required this.requestId,
    required this.requestNo,
    required this.userId,
    required this.version,
    required this.locale,
    required this.textHash,
    required this.text,
    required this.approvedAt,
  });

  final String id;
  final String requestId;
  final String requestNo;
  final String userId;

  /// Consent text version (`kSoConsentTextVersion` at approval time).
  final String version;

  /// Language the text was shown and accepted in.
  final String locale;

  /// SHA-256 of [text] (hex).
  final String textHash;

  /// Exact text the buyer saw; the stored copy is rendered from this.
  final String text;
  final DateTime approvedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'requestId': requestId,
        'requestNo': requestNo,
        'userId': userId,
        'version': version,
        'locale': locale,
        'textHash': textHash,
        'text': text,
        'approvedAt': approvedAt.toUtc().toIso8601String(),
      };
}

enum TGConsentChannel { email, sms }

enum TGConsentDeliveryStatus { pending, sent, failed }

/// One proof message (e-mail or SMS) and its retry state.
class TGConsentDelivery {
  TGConsentDelivery({
    required this.id,
    required this.consentId,
    required this.requestId,
    required this.requestNo,
    required this.channel,
    required this.to,
    required this.subject,
    required this.body,
    this.status = TGConsentDeliveryStatus.pending,
    this.attempts = 0,
    this.lastError,
    this.lastAttemptAt,
    this.sentAt,
  });

  final String id;
  final String consentId;
  final String requestId;
  final String requestNo;
  final TGConsentChannel channel;
  final String to;
  final String subject;
  final String body;
  TGConsentDeliveryStatus status;
  int attempts;
  String? lastError;
  DateTime? lastAttemptAt;
  DateTime? sentAt;

  bool get failed => status == TGConsentDeliveryStatus.failed;
}
