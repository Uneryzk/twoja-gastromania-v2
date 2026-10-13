import 'package:flutter/foundation.dart';

enum TGNotifCategory { messages, deals, listings, requests, advertising, billing, moderation, marketing }

enum TGNotifChannel { inApp, email, push }

extension TGNotifCategoryRules on TGNotifCategory {
  /// Moderation and billing notices are legally / operationally required.
  bool get locked => this == TGNotifCategory.moderation || this == TGNotifCategory.billing;

  /// Marketing is opt-in only; every change is stored with a timestamp.
  bool get optIn => this == TGNotifCategory.marketing;
}

/// Maps a [TGAppNotification.type] to its preference category.
TGNotifCategory tgNotifCategoryOf(String type) {
  if (type.startsWith('billing_') || type.startsWith('founder_') || type.startsWith('priority_') || type == 'slot_refund') {
    return TGNotifCategory.billing;
  }
  if (type.startsWith('moderation_') ||
      const {'resto_description_moderated', 'ad_rejected', 'ad_changes_requested', 'ad_ended_early', 'so_rejected', 'so_report_update', 'so_staff_message'}
          .contains(type)) {
    return TGNotifCategory.moderation;
  }
  if (type == 'new_message') return TGNotifCategory.messages;
  if (type.startsWith('deal_') || type.startsWith('project_')) return TGNotifCategory.deals;
  if (type.startsWith('so_')) return TGNotifCategory.requests;
  if (type.startsWith('ad_') || type.startsWith('slot_') || type.startsWith('promo_')) return TGNotifCategory.advertising;
  if (type.startsWith('marketing_')) return TGNotifCategory.marketing;
  return TGNotifCategory.listings;
}

/// Types the user has to act on; everything else is an update.
const Set<String> kTGActionRequiredTypes = {
  'deal_request',
  'deal_reminder',
  'deal_reminder_d3',
  'deal_reminder_d10',
  'deal_review_requested',
  'project_review_confirm',
  'project_completion_prompt',
  'project_review_remind',
  'so_quote_received',
  'so_new_lead',
  'so_nudge',
  'so_day10',
  'ad_changes_requested',
  'resto_details_reminder',
  'resto_inventory_sync_reminder',
  'billing_payment_failed',
  'founder_free_ending',
};

bool tgNotifNeedsAction(String type) => kTGActionRequiredTypes.contains(type);

/// Opt-in / opt-out audit trail for marketing consent.
@immutable
class TGConsentRecord {
  const TGConsentRecord({required this.userId, required this.channel, required this.granted, required this.at});
  final String userId;
  final TGNotifChannel channel;
  final bool granted;
  final DateTime at;
}
