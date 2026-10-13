import 'package:flutter/foundation.dart';

/// DASH-4 account, verification and admin console models.

enum TGVerifyStatus { none, pending, verified, rejected }

/// Phone or e-mail on the account. [pending] holds a new value awaiting a code.
class TGContactState {
  TGContactState({this.value, this.verifiedAt, this.pending, this.codeSentAt});
  String? value;
  DateTime? verifiedAt;
  String? pending;
  DateTime? codeSentAt;

  bool get verified => verifiedAt != null && value != null;
}

/// Public company register entry (KRS / CEIDG), from the mock lookup.
@immutable
class TGRegistryRecord {
  const TGRegistryRecord({
    required this.nip,
    required this.name,
    required this.address,
    required this.register,
    required this.active,
    this.representatives = const [],
  });

  final String nip;
  final String name;
  final String address;

  /// `KRS` or `CEIDG`.
  final String register;
  final bool active;
  final List<String> representatives;
}

/// Company (NIP) verification request reviewed by moderators.
class TGCompanyApplication {
  TGCompanyApplication({
    required this.id,
    required this.userId,
    required this.nip,
    required this.registry,
    required this.representativeName,
    required this.submittedAt,
    this.status = TGVerifyStatus.pending,
    this.decidedAt,
    this.decidedBy,
    this.decisionNote,
    this.isMock = false,
  });

  final String id;
  final String userId;
  final String nip;
  final TGRegistryRecord registry;
  final String representativeName;
  final DateTime submittedAt;
  TGVerifyStatus status;
  DateTime? decidedAt;
  String? decidedBy;
  String? decisionNote;
  final bool isMock;

  /// The named representative appears in the register.
  bool get representativeListed =>
      registry.representatives.any((r) => r.toLowerCase() == representativeName.trim().toLowerCase());
}

/// Append-only admin audit entry. There is no API to edit or delete entries.
@immutable
class TGAdminAuditEntry {
  const TGAdminAuditEntry({
    required this.id,
    required this.at,
    required this.actorId,
    required this.actorRole,
    required this.action,
    required this.targetId,
    this.reason,
    this.details = const {},
  });

  final String id;
  final DateTime at;
  final String actorId;
  final String actorRole;

  /// e.g. `reveal`, `refund`, `conversation_open`, `verification_decision`, `golive_switch`.
  final String action;
  final String targetId;
  final String? reason;
  final Map<String, String> details;
}

enum TGAdminUserKind { individual, store, buyer, restaurant }

enum TGAdminUserStatus { active, suspended, deletionPending }

/// Account record behind the admin "360°" view. Contact data is only shown
/// masked unless revealed with a logged reason.
@immutable
class TGAdminUser {
  const TGAdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.kind,
    required this.createdAt,
    this.status = TGAdminUserStatus.active,
    this.nip,
    this.isMock = false,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final TGAdminUserKind kind;
  final DateTime createdAt;
  final TGAdminUserStatus status;
  final String? nip;
  final bool isMock;
}

enum TGPiiField { email, phone }

enum TGConvReportStatus { open, actioned, dismissed }

@immutable
class TGConvMessage {
  const TGConvMessage({required this.fromId, required this.text, required this.at});
  final String fromId;
  final String text;
  final DateTime at;
}

/// A reported conversation. Moderators see only [reported]; the full thread
/// needs a logged reason ([TGAdminConsoleService.openFullConversation]).
class TGConversationReport {
  TGConversationReport({
    required this.id,
    required this.conversationId,
    required this.reporterId,
    required this.reportedUserId,
    required this.reason,
    required this.reported,
    required this.createdAt,
    this.status = TGConvReportStatus.open,
    this.isMock = false,
  });

  final String id;
  final String conversationId;
  final String reporterId;
  final String reportedUserId;

  /// i18n key suffix: `scam`, `abuse`, `spam`, `off_platform`.
  final String reason;
  final TGConvMessage reported;
  final DateTime createdAt;
  TGConvReportStatus status;
  final bool isMock;
}

enum TGRefundStatus { pending, approved, rejected }

class TGRefundRequest {
  TGRefundRequest({
    required this.id,
    required this.paymentId,
    required this.userId,
    required this.amountPln,
    required this.reason,
    required this.requestedAt,
    this.status = TGRefundStatus.pending,
    this.decidedAt,
    this.decidedBy,
    this.decisionNote,
    this.isMock = false,
  });

  final String id;
  final String paymentId;
  final String userId;
  final num amountPln;
  final String reason;
  final DateTime requestedAt;
  TGRefundStatus status;
  DateTime? decidedAt;
  String? decidedBy;
  String? decisionNote;
  final bool isMock;
}

/// One manual go-live confirmation (who ticked it and when).
@immutable
class TGManualCheck {
  const TGManualCheck({required this.id, required this.labelKey, this.doneBy, this.doneAt});
  final String id;
  final String labelKey;
  final String? doneBy;
  final DateTime? doneAt;
  bool get done => doneAt != null;
}

/// Account deletion scheduled after a 7-day grace period.
@immutable
class TGDeletionRequest {
  const TGDeletionRequest({required this.userId, required this.requestedAt, required this.effectiveAt, this.cancelledAt});
  final String userId;
  final DateTime requestedAt;
  final DateTime effectiveAt;
  final DateTime? cancelledAt;
  bool get active => cancelledAt == null;
}

@immutable
class TGDataExport {
  const TGDataExport({required this.id, required this.userId, required this.requestedAt, required this.json});
  final String id;
  final String userId;
  final DateTime requestedAt;
  final String json;
}

/// "Marek Kowalski" → "Marek K." (first name + initial of the last name).
String tgPublicName(String first, String last) {
  final f = first.trim();
  final l = last.trim();
  if (f.isEmpty) return '';
  if (l.isEmpty) return f;
  return '$f ${String.fromCharCode(l.runes.first)}.';
}

/// `hello@gastropl.pl` → `h••••@g••••••.pl`.
String tgMaskEmail(String email) {
  final at = email.indexOf('@');
  if (at <= 0) return '•••';
  final user = email.substring(0, at);
  final domain = email.substring(at + 1);
  final dot = domain.lastIndexOf('.');
  final host = dot > 0 ? domain.substring(0, dot) : domain;
  final tld = dot > 0 ? domain.substring(dot) : '';
  String m(String s) => s.isEmpty ? '' : '${s[0]}${'•' * (s.length - 1).clamp(2, 8)}';
  return '${m(user)}@${m(host)}$tld';
}

/// `+48 601 222 111` → `+48 ••• ••• 111` (last 3 digits stay visible).
String tgMaskPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 4) return '•••';
  final tail = digits.substring(digits.length - 3);
  final cc = phone.trim().startsWith('+') && digits.length > 9 ? '+${digits.substring(0, digits.length - 9)} ' : '';
  return '$cc••• ••• $tail';
}
