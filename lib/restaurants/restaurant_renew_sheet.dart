import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/add_product/add_product_fields.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/payment/payment_form.dart';
import 'package:twoja_gastromania/payment/payment_models.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
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
}) {
  TGAnalytics.track(
    promoteOnly ? 'resto_promote_selected' : 'renew_click',
    {'listingNo': listing.listingNo, 'kind': 'restaurant', 'early': early, 'promoteOnly': promoteOnly},
  );
  final body = _RestoRenewBody(listing: listing, early: early, promoteOnly: promoteOnly);
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
  const _RestoRenewBody({required this.listing, required this.early, this.promoteOnly = false});
  final RestaurantListing listing;
  final bool early;
  final bool promoteOnly;

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
    _promote = widget.promoteOnly ? 14 : 0;
  }

  RestaurantConfig get cfg => RestaurantConfigService.instance.config;

  bool _allow(int days) {
    final life = RestaurantLifecycleService.instance;
    if (!widget.promoteOnly && widget.listing.status == RestaurantListingStatus.expired) return true;
    return life.canPromote(widget.listing, days) || (!widget.promoteOnly && days == 0);
  }

  int get _total {
    if (widget.promoteOnly) {
      if (_promote == 14) return cfg.promote.pln14;
      if (_promote == 30) return cfg.promote.pln30;
      return 0;
    }
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
              expired
                  ? 'Expired ${(-r.daysUntilExpiry(TGClock.now())).clamp(0, 999)} days ago'
                  : '${r.daysUntilExpiry(TGClock.now())} days left',
              style: theme.bodySmall.override(color: TGColors.rating),
            ),
            const SizedBox(height: 14),
            if (promoteMode) ...[
              Text(
                'Shown at the top of Restaurants for Sale, in the homepage “Restaurants for Sale” strip, and labelled WYRÓŻNIONE.',
                style: theme.bodySmall,
              ),
              const SizedBox(height: 8),
              Tooltip(
                message: _allow(14) ? '' : 'Promote cannot exceed remaining listing days',
                child: Opacity(
                  opacity: _allow(14) ? 1 : 0.45,
                  child: WizardRadioCard(
                    selected: _promote == 14,
                    title: 'Promote · +${cfg.promote.pln14} PLN · 14 days',
                    onTap: () {
                      if (_allow(14)) setState(() => _promote = 14);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Tooltip(
                message: _allow(30) ? '' : 'Promote cannot exceed remaining listing days',
                child: Opacity(
                  opacity: _allow(30) ? 1 : 0.45,
                  child: WizardRadioCard(
                    selected: _promote == 30,
                    title: 'Promote · +${cfg.promote.pln30} PLN · 30 days',
                    onTap: () {
                      if (_allow(30)) setState(() => _promote = 30);
                    },
                  ),
                ),
              ),
            ] else ...[
              WizardRadioCard(
                selected: _promote == 0,
                title: 'Renew · ${cfg.paidPricePln} PLN',
                onTap: () => setState(() => _promote = 0),
              ),
              const SizedBox(height: 8),
              Tooltip(
                message: _allow(14) ? '' : 'Promote cannot exceed remaining listing days',
                child: Opacity(
                  opacity: _allow(14) ? 1 : 0.45,
                  child: WizardRadioCard(
                    selected: _promote == 14,
                    title: 'Renew + Promote 14 days · ${cfg.paidPricePln + cfg.promote.pln14} PLN',
                    onTap: () {
                      if (_allow(14)) setState(() => _promote = 14);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Tooltip(
                message: _allow(30) ? '' : 'Promote cannot exceed remaining listing days',
                child: Opacity(
                  opacity: _allow(30) ? 1 : 0.45,
                  child: WizardRadioCard(
                    selected: _promote == 30,
                    title: 'Renew + Promote 30 days · ${cfg.paidPricePln + cfg.promote.pln30} PLN',
                    onTap: () {
                      if (_allow(30)) setState(() => _promote = 30);
                    },
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text('Total (brutto, VAT 23% included): $_total,00 PLN', style: const TextStyle(fontWeight: FontWeight.w900)),
            if (!promoteMode && !expired && r.expiresAt != null)
              Text(
                'New end date: ${DateFormat('d MMM yyyy').format((widget.early ? r.expiresAt! : TGClock.now()).add(Duration(days: cfg.paidDays)))}',
                style: theme.bodySmall,
              ),
            const SizedBox(height: 16),
            PaymentForm(
              key: _formKey,
              amountPln: _total.toDouble(),
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
                      promoteFee: _promote == 14
                          ? cfg.promote.pln14
                          : _promote == 30
                              ? cfg.promote.pln30
                              : 0,
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
