import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/flutter_flow/tg_l10n.dart';
import 'package:twoja_gastromania/tg_models/tg_deal_moderation.dart';
import 'package:twoja_gastromania/tg_services/deal_moderation_service.dart';
import 'package:twoja_gastromania/tg_services/notification_service.dart';

const _notifTypes = [
  'deal_request',
  'deal_buyer_confirmed',
  'deal_buyer_declined',
  'deal_reminder',
  'deal_reminder_d10',
  'deal_expired',
  'deal_review_requested',
  'new_message',
  'founder_tier_up',
  'founder_applied',
  'founder_approved',
  'founder_rejected',
  'founder_waitlisted',
  'founder_ended',
  'founder_ending',
  'ad_waitlist_open',
  'ad_approved',
  'slot_refund',
  'priority_active',
  'resto_expired',
  'resto_still_selling',
  'so_received',
  'so_quote_received',
];

const _timelineKeys = [
  'tl_buyer_posted_review',
  'tl_seller_question_sent',
  'tl_seller_disputed',
  'tl_evidence_opened',
  'tl_buyer_uploaded_video',
  'tl_requested_more_evidence',
  'tl_contacted_seller',
  'tl_decision',
];

void main() {
  test('h) notification templates exist for TR and PL', () {
    final missing = <String>[];
    for (final type in _notifTypes) {
      for (final suffix in ['title', 'body']) {
        final key = 'notif_${type}_$suffix';
        for (final lang in ['tr', 'pl']) {
          final v = kUiTranslations[key]?[lang];
          if (v == null || v.trim().isEmpty) missing.add('$key@$lang');
        }
      }
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
  });

  test('h) timeline templates exist for TR and PL', () {
    final missing = <String>[];
    for (final key in _timelineKeys) {
      for (final lang in ['tr', 'pl']) {
        final v = kUiTranslations[key]?[lang];
        if (v == null || v.trim().isEmpty) missing.add('$key@$lang');
      }
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
  });

  test('NotificationService stores keys, not English sentences', () {
    NotificationService.instance.reset();
    final n = NotificationService.instance.add(
      userId: 'u1',
      type: 'deal_expired',
      dealId: 'D-1',
      params: {'title': 'Mixer'},
    );
    expect(n.titleKey, 'notif_deal_expired_title');
    expect(n.bodyKey, 'notif_deal_expired_body');
    expect(FFLocalizations(const Locale('tr')).getText(n.titleKey), isNot(contains('Request expired')));
    expect(FFLocalizations(const Locale('pl')).getText(n.titleKey), isNotEmpty);
  });

  test('mock timeline rows migrate onto messageKey', () {
    DealModerationService.instance.reset();
    final withKey = DealModerationService.instance.cases.expand((c) => c.timeline).where((e) => (e.messageKey ?? '').isNotEmpty);
    expect(withKey, isNotEmpty);
    final sample = withKey.first;
    expect(kUiTranslations[sample.messageKey!]?['tr'], isNotEmpty);
    expect(kUiTranslations[sample.messageKey!]?['pl'], isNotEmpty);
  });

  test('migrateDealTimelineEvent maps English seed labels', () {
    final e = migrateDealTimelineEvent(
      TGDealTimelineEvent(at: DateTime(2026, 1, 1), actor: 'Buyer', label: 'Buyer posted review for No. 38705142'),
    );
    expect(e.messageKey, 'tl_buyer_posted_review');
    expect(e.args['n'], '38705142');
    expect(e.actorKey, 'tl_actor_buyer');
  });
}
