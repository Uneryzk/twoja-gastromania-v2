import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/add_product/add_product_fields.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/payment/payment_form.dart';
import 'package:twoja_gastromania/payment/payment_models.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/duration_formatter.dart';
import 'package:twoja_gastromania/tg_core/duration_service.dart';
import 'package:twoja_gastromania/tg_core/restaurant_config.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_restaurant_listing.dart';
import 'package:twoja_gastromania/tg_services/restaurant_lifecycle_service.dart';

Future<void> showRestaurantRenewSheet(
  BuildContext context,
  RestaurantListing listing, {
  bool early = false,
  bool promoteOnly = false,
  int? initialPromoteDays,
}) {
  TGAnalytics.track(
    promoteOnly ? 'resto_promote_selected' : 'renew_click',
    {'listingNo': listing.listingNo, 'kind': 'restaurant', 'early': early, 'promoteOnly': promoteOnly},
  );
  final body = _RestoRenewBody(listing: listing, early: early, promoteOnly: promoteOnly, initialPromoteDays: initialPromoteDays);
  final wide = MediaQuery.sizeOf(context).width >= 700;
  if (wide) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Material(
            color: FlutterFlowTheme.of(ctx).secondaryBackground,
            borderRadius: BorderRadius.circular(TGRadius.modal),
            child: body,
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) => FractionallySizedBox(heightFactor: 0.9, child: body),
  );
}

class _RestoRenewBody extends StatefulWidget {
  const _RestoRenewBody({required this.listing, required this.early, this.promoteOnly = false, this.initialPromoteDays});
  final RestaurantListing listing;
  final bool early;
  final bool promoteOnly;
  final int? initialPromoteDays;

  @override
  State<_RestoRenewBody> createState() => _RestoRenewBodyState();
}

class _RestoRenewBodyState extends State<_RestoRenewBody> {
  late int _promote;
  bool _paying = false;
  final _formKey = GlobalKey<PaymentFormState>();

  @override
  void initState() {
    super.initState();
    _promote = widget.initialPromoteDays ?? (widget.promoteOnly ? cfg.promote.durations.first : 0);
  }

  RestaurantConfig get cfg => RestaurantConfigService.instance.config;

  bool _allow(int days) {
    final life = RestaurantLifecycleService.instance;
    if (!widget.promoteOnly && widget.listing.status == RestaurantListingStatus.expired) return true;
    return life.canPromote(widget.listing, days) || (!widget.promoteOnly && days == 0);
  }

  int get _total {
    if (widget.promoteOnly) return cfg.promote.pricePln(_promote);
    return RestaurantLifecycleService.instance.renewPlusPromoteTotal(_promote);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final r = widget.listing;
    final expired = r.status == RestaurantListingStatus.expired;
    final promoteMode = widget.promoteOnly;
    return PopScope(
      canPop: !_paying,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(r.title, style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
            Text(
              r.expiresAt == null
                  ? ''
                  : DurationFormatter.remaining(r.expiresAt!, FFLocalizations.of(context).languageCode, now: TGClock.now()),
              style: theme.bodySmall.override(color: TGColors.rating),
            ),
            const SizedBox(height: 14),
            if (promoteMode)
              Text(
                context.t('ui_wiz_promote_help', {'badge': context.t('ui_promoted_badge')}),
                style: theme.bodySmall,
              )
            else
              WizardRadioCard(
                selected: _promote == 0,
                title: '${context.t('ui_renew')} · ${cfg.paidPricePln} PLN',
                onTap: () => setState(() => _promote = 0),
              ),
            for (final d in cfg.promote.durations) ...[
              const SizedBox(height: 8),
              Tooltip(
                message: _allow(d) ? '' : context.t('err_promote_exceeds_days'),
                child: Opacity(
                  opacity: _allow(d) ? 1 : 0.45,
                  child: WizardRadioCard(
                    selected: _promote == d,
                    title: promoteMode
                        ? '${context.t('ui_promote_n_days', {'n': '$d'})} · +${cfg.promote.pricePln(d)} PLN'
                        : '${context.t('ui_renew')} + ${context.t('ui_promote_n_days', {'n': '$d'})} · ${cfg.paidPricePln + cfg.promote.pricePln(d)} PLN',
                    onTap: () {
                      if (_allow(d)) setState(() => _promote = d);
                    },
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text('Total (brutto, VAT 23% included): $_total,00 PLN', style: const TextStyle(fontWeight: FontWeight.w900)),
            if (!promoteMode && !expired && r.expiresAt != null)
              Text(
                'New end date: ${DateFormat('d MMM yyyy').format(DurationService.addDays(widget.early ? r.expiresAt! : TGClock.now(), cfg.paidDays))}',
                style: theme.bodySmall,
              ),
            const SizedBox(height: 16),
            PaymentForm(
              key: _formKey,
              amountPln: _total.toDouble(),
              billingKind: promoteMode ? TGPaymentKind.promotion : TGPaymentKind.restaurant,
              billingDescription: promoteMode ? 'Restaurant promotion · $_promote days' : 'Restaurant renew${_promote > 0 ? ' + promote $_promote days' : ''}',
              billingListingId: r.id,
              billingListingNo: r.listingNo,
              onWaitingChanged: (v) => setState(() => _paying = v),
              onPaid: () {
                final auth = context.read<FakeAuthState>();
                if (promoteMode) {
                  auth.beginCheckout(
                    TGCheckoutCart.restaurantListing(
                      listingId: r.id,
                      listingFee: 0,
                      promoteFee: _total,
                      promoteDays: _promote,
                      useFreeIntro: false,
                    ),
                  );
                  RestaurantLifecycleService.instance.promoteOnly(listingId: r.id, promoteDays: _promote);
                } else {
                  auth.beginCheckout(
                    TGCheckoutCart.restaurantRenew(
                      listingId: r.id,
                      listingFee: cfg.paidPricePln,
                      promoteFee: cfg.promote.pricePln(_promote),
                      promoteDays: _promote,
                      early: widget.early,
                    ),
                  );
                  RestaurantLifecycleService.instance.renew(listingId: r.id, promoteDays: _promote, early: widget.early);
                }
                auth.clearCheckout();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
