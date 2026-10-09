import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/admin/admin_chrome.dart';
import 'package:twoja_gastromania/admin/admin_modals.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_moderation.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_review.dart';
import 'package:twoja_gastromania/tg_models/tg_store_profile.dart';
import 'package:twoja_gastromania/tg_services/moderation_service.dart';
import 'package:twoja_gastromania/tg_services/product_service.dart';
import 'package:twoja_gastromania/tg_services/review_service.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';

class AdminSellerCasePage extends StatefulWidget {
  const AdminSellerCasePage({super.key, required this.sellerId});
  final String sellerId;

  @override
  State<AdminSellerCasePage> createState() => _AdminSellerCasePageState();
}

class _AdminSellerCasePageState extends State<AdminSellerCasePage> {
  List<TGProduct> _all = const [];

  @override
  void initState() {
    super.initState();
    ModerationService.instance.ensureSeeded();
    TGReviewService.instance.ensureSeeded();
    TGProductService.instance.getAll().then((all) {
      if (mounted) setState(() => _all = all);
    });
  }

  @override
  Widget build(BuildContext context) {
    final mod = context.watch<ModerationService>();
    final auth = context.watch<FakeAuthState>();
    final store = TGSellerProfileService.instance.bySellerKey(widget.sellerId);
    final profile = mod.sellerById(widget.sellerId);
    final key = ModerationService.caseKeyFor(TGReportTarget.seller, widget.sellerId);
    final reports = mod.reportsFor(key);
    final listings = _all.where((p) => p.seller.id == widget.sellerId).toList();
    final extras = TGSellerProfileService.instance.extraListings.where((p) => p.seller.id == widget.sellerId);
    final fmt = DateFormat('d MMM yyyy · HH:mm');
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              Text(store?.name ?? profile?.seller.name ?? widget.sellerId, style: FlutterFlowTheme.of(context).titleMedium.override(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              AdminCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${profile?.phone ?? store?.phone ?? '—'} · NIP ${store?.nip ?? profile?.nip ?? '—'}'),
                    Text(profile?.email ?? '', style: const TextStyle(color: TGColors.textSecondary, fontSize: 12)),
                    if (store != null) Text('${store.city} · ${context.t('ui_reviews_n', {'n': '${store.reviewsCount}'})}'),
                    if (store?.status == TGStoreStatus.suspended || profile?.suspended == true)
                      Text(context.t('ui_suspended'), style: const TextStyle(color: TGColors.error, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(context.t('ui_listings'), style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              for (final p in [...listings, ...extras])
                ListTile(
                  dense: true,
                  title: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(p.listingNo ?? p.id),
                  onTap: () => TGAdminNav.openCase(context, p.listingNo ?? p.id),
                ),
              const SizedBox(height: 12),
              Text(context.t('ui_reports'), style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              for (final r in reports)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AdminCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [AdminReasonChip(reason: r.reason), const SizedBox(width: 8), Text(r.reportNo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)), const Spacer(), Text(fmt.format(r.createdAt), style: const TextStyle(fontSize: 11, color: TGColors.textSecondary))]),
                        const SizedBox(height: 6),
                        Text(r.text),
                        Text(r.reporterEmail, style: const TextStyle(fontSize: 12, color: TGColors.textSecondary)),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TGButton(onPressed: () => showAdminDismiss(context, key), label: context.t('ui_dismiss'), height: 40, variant: TGButtonVariant.outline),
                  TGButton(onPressed: () => showAdminRequestInfo(context, key), label: context.t('ui_request_info'), height: 40, variant: TGButtonVariant.outline),
                  if (auth.isAdmin) ...[
                    TGButton(onPressed: () => showAdminWarnSuspend(context, sellerId: widget.sellerId, listingNo: key, suspend: false), label: context.t('ui_warn'), height: 40, variant: TGButtonVariant.outline),
                    TGButton(key: const Key('admin-seller-suspend'), onPressed: () => showAdminWarnSuspend(context, sellerId: widget.sellerId, listingNo: key, suspend: true), label: context.t('ui_suspend'), height: 40),
                  ],
                ],
              ),
            ],
          ),
        ),
        const AdminPrinciplesFooter(),
      ],
    );
  }
}

class AdminReviewCasePage extends StatelessWidget {
  const AdminReviewCasePage({super.key, required this.reviewId});
  final String reviewId;

  @override
  Widget build(BuildContext context) {
    context.watch<ModerationService>();
    TGReviewService.instance.ensureSeeded();
    final review = TGReviewService.instance.byId(reviewId);
    final key = ModerationService.caseKeyFor(TGReportTarget.review, reviewId);
    final reports = ModerationService.instance.reportsFor(key);
    final others = review == null ? const <TGStoreReview>[] : TGReviewService.instance.byAuthor(review.authorId, exceptId: review.id).take(8).toList();
    final signals = review == null
        ? const <TGStoreReview>[]
        : TGReviewService.instance.sameSignal(ip: review.authorIp, phone: review.authorPhone, exceptId: review.id).take(8).toList();
    final store = review == null ? null : TGSellerProfileService.instance.bySellerKey(review.sellerId);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              Text(context.t('ui_review'), style: FlutterFlowTheme.of(context).titleMedium.override(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TGButton(onPressed: () => showAdminDismiss(context, key), label: context.t('ui_dismiss'), height: 40, variant: TGButtonVariant.outline),
                  TGButton(key: const Key('admin-remove-review'), onPressed: () => showAdminRemoveReview(context, reviewId), label: context.t('ui_remove_review'), height: 40),
                  TGButton(onPressed: () => showAdminHideReview(context, reviewId), label: context.t('ui_hide_temporarily'), height: 40, variant: TGButtonVariant.outline),
                  TGButton(onPressed: () => showAdminContact(context, key, seller: false), label: context.t('ui_contact_reporter'), height: 40, variant: TGButtonVariant.ghost),
                ],
              ),
              const SizedBox(height: 16),
              if (review == null)
                Text(context.t('ui_store_not_found'))
              else
                AdminCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${review.authorName} · ${review.rating}/5', style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(review.text, style: const TextStyle(height: 1.4)),
                      const SizedBox(height: 6),
                      Text('${context.t('ui_seller')}: ${store?.name ?? review.sellerId}', style: const TextStyle(fontSize: 12, color: TGColors.textSecondary)),
                      Text('${review.authorEmail} · ${review.authorPhone} · ${review.authorIp}', style: const TextStyle(fontSize: 12, color: TGColors.textSecondary)),
                      Text(review.status.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    ],
                  ),
                ),
              const SizedBox(height: 14),
              Text(context.t('ui_other_reviews_author'), style: const TextStyle(fontWeight: FontWeight.w800)),
              for (final o in others)
                ListTile(
                  dense: true,
                  title: Text('${o.authorName} · ${o.rating}/5'),
                  subtitle: Text(o.text, maxLines: 2, overflow: TextOverflow.ellipsis),
                  onTap: () => context.go(TGAdminNav.reviewCasePath(o.id)),
                ),
              const SizedBox(height: 8),
              Text(context.t('ui_same_signal'), style: const TextStyle(fontWeight: FontWeight.w800)),
              for (final s in signals)
                ListTile(dense: true, title: Text('${s.authorName} · ${s.authorIp} · ${s.authorPhone}'), onTap: () => context.go(TGAdminNav.reviewCasePath(s.id))),
              const SizedBox(height: 12),
              Text(context.t('ui_reports'), style: const TextStyle(fontWeight: FontWeight.w800)),
              for (final r in reports)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: AdminCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [AdminReasonChip(reason: r.reason), const SizedBox(width: 8), Text(r.reportNo)]),
                        Text(r.text),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const AdminPrinciplesFooter(),
      ],
    );
  }
}

class AdminSellerCaseHost extends StatelessWidget {
  const AdminSellerCaseHost({super.key, required this.sellerId});
  final String sellerId;
  @override
  Widget build(BuildContext context) => AdminShell(section: 'queue', child: AdminSellerCasePage(sellerId: sellerId));
}

class AdminReviewCaseHost extends StatelessWidget {
  const AdminReviewCaseHost({super.key, required this.reviewId});
  final String reviewId;
  @override
  Widget build(BuildContext context) => AdminShell(section: 'queue', child: AdminReviewCasePage(reviewId: reviewId));
}
