import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/payment/payment_form.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_components/tg_header.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_images.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_no.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_price.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_services/pricing_config_service.dart';
import 'package:twoja_gastromania/tg_services/product_service.dart';
import 'package:twoja_gastromania/payment/payment_models.dart';

class BulkAddRow {
  BulkAddRow({required this.id, required this.photos});
  final String id;
  final List<String> photos;
  String title = '';
  TGCategory category = TGCategory.cookingEquipment;
  TGCondition condition = TGCondition.used;
  String priceText = '';
  TGPriceBasis basis = TGPriceBasis.brutto;
  bool selected = true;

  String? get blockReason {
    if (photos.isEmpty) return 'Needs 1 photo';
    if (title.trim().length < 5) return 'Needs title';
    if (!TGListingPrice.isValid(TGListingPrice.parse(priceText))) return 'Needs price';
    return null;
  }

  double get completeness {
    var n = 0;
    if (photos.isNotEmpty) n++;
    if (title.trim().length >= 5) n++;
    if (priceText.isNotEmpty) n++;
    n++; // condition always set
    return n / 4;
  }
}

/// Bulk photo → draft rows → publish with free slots then paid basket.
class BulkAddPage extends StatefulWidget {
  const BulkAddPage({super.key});

  static const routeName = 'BulkAdd';
  static const routePath = '/dashboard/bulk-add';

  @override
  State<BulkAddPage> createState() => _BulkAddPageState();
}

class _BulkAddPageState extends State<BulkAddPage> {
  final List<BulkAddRow> _rows = [];
  bool _publishing = false;

  void _uploadMockPhotos() {
    // Fixed library assets only — no AI/theme matching.
    final pool = TGListingImages.listingPool.take(6).toList();
    for (final url in pool) {
      _rows.add(BulkAddRow(id: 'bulk_${DateTime.now().microsecondsSinceEpoch}_${_rows.length}', photos: [url]));
    }
    TGAnalytics.track('inventory_item_add', {'mode': 'bulk', 'n': pool.length});
    setState(() {});
  }

  Future<void> _saveDrafts() async {
    final auth = context.read<FakeAuthState>();
    for (final row in _rows) {
      final p = _toProduct(auth, row, status: TGListingStatus.draft);
      await TGProductService.instance.upsert(p);
      auth.upsertOwned(p);
    }
    showTGToast(context, 'Saved ${_rows.length} drafts');
  }

  TGProduct _toProduct(FakeAuthState auth, BulkAddRow row, {required TGListingStatus status}) {
    final no = status == TGListingStatus.draft ? null : TGListingNo.allocate();
    final now = DateTime.now();
    return TGProduct(
      id: row.id,
      listingNo: no,
      title: row.title.trim().isEmpty ? 'Untitled equipment' : row.title.trim(),
      category: row.category,
      condition: row.condition,
      price: TGListingPrice.parse(row.priceText),
      priceUnit: TGPriceUnit.oneTime,
      priceBasis: row.basis,
      negotiable: false,
      oldPrice: null,
      listingType: TGListingType.buy,
      powerType: TGPowerType.electric,
      warrantyMonths: 0,
      delivery: false,
      pickup: true,
      status: status,
      city: 'Katowice',
      voivodeship: 'Śląskie',
      phone: '+48 500 000 000',
      seller: TGSeller(
        id: auth.userId,
        name: auth.displayName,
        type: auth.sellerType,
        verified: auth.sellerType == TGSellerType.store,
        rating: 4.5,
      ),
      imageUrls: row.photos,
      imageUrl: row.photos.isNotEmpty ? row.photos.first : '',
      photoCount: row.photos.length,
      isPromoted: false,
      createdAt: now,
      publishedAt: status == TGListingStatus.active ? now : null,
      ownerId: auth.userId,
    );
  }

  Future<void> _publishSelected() async {
    final auth = context.read<FakeAuthState>();
    final ready = _rows.where((r) => r.selected && r.blockReason == null).toList();
    if (ready.isEmpty) {
      showTGToast(context, 'No complete rows selected');
      return;
    }
    setState(() => _publishing = true);
    var freeLeft = auth.freeListingsLeft;
    final paid = <BulkAddRow>[];
    for (final row in ready) {
      if (auth.storePlan != null || freeLeft <= 0) {
        paid.add(row);
        continue;
      }
      final p = auth.publishOwned(_toProduct(auth, row, status: TGListingStatus.draft));
      await TGProductService.instance.upsert(p);
      freeLeft = auth.freeListingsLeft;
    }
    if (paid.isNotEmpty && mounted) {
      final cfg = PricingConfigService.instance.config;
      final days = cfg.defaultListingDays;
      final fee = cfg.listingFeePln(days);
      final total = paid.length * fee;
      final nudge = cfg.shouldNudgeBasicStore(
        paidBasket30dEqPln: total,
        listingCount: auth.freeSlotsUsed + paid.length,
      );
      if (nudge) {
        TGAnalytics.track('basic_store_nudge_view', {'n': paid.length});
      }
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                ctx.t('uyum_bulk_line', {'days': '$days', 'fee': '$fee', 'n': '${paid.length}'}),
                key: const Key('bulk-pay-line'),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              Text(ctx.t('ui_total_brutto_vat', {'n': '$total'})),
              if (nudge)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    ctx.t('ui_basic_store_nudge', {
                      'n': '${cfg.storeNudgeMinListings}',
                      'fee': '$fee',
                      'sum': '${cfg.storeNudgeMinListings * fee}',
                      'store': '${cfg.basicStoreMonthlyPln}',
                    }),
                    style: FlutterFlowTheme.of(ctx).bodySmall,
                  ),
                ),
              const SizedBox(height: 12),
              PaymentForm(
                amountPln: total.toDouble(),
                billingKind: TGPaymentKind.listing,
                billingDescription: 'Listing fee · ${paid.length} listings',
                onPaid: () async {
                  for (final row in paid) {
                    final p = _toProduct(auth, row, status: TGListingStatus.active);
                    await TGProductService.instance.upsert(p);
                    auth.upsertOwned(p);
                  }
                  TGAnalytics.track('bulk_publish', {'free': ready.length - paid.length, 'paid': paid.length});
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    showTGToast(context, 'Published ${ready.length} listings');
                    context.go('/dashboard/listings');
                  }
                },
              ),
              TextButton(onPressed: () => context.go('/plans'), child: Text(ctx.t('uyum_see_basic_store'))),
            ],
          ),
        ),
      );
    } else {
      TGAnalytics.track('bulk_publish', {'free': ready.length, 'paid': 0});
      if (mounted) {
        showTGToast(context, 'Published ${ready.length} free listings');
        context.go('/dashboard/listings');
      }
    }
    if (mounted) setState(() => _publishing = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final auth = context.watch<FakeAuthState>();
    final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
    final avg = _rows.isEmpty ? 0.0 : _rows.map((r) => r.completeness).reduce((a, b) => a + b) / _rows.length;

    return TGPageScaffold(
      header: const TGHeader(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(context.t('ui_bulk_add_equipment'), style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
                Text('Location, phone and seller are automatic from your account.', style: theme.bodySmall),
                Text('Completeness ${(avg * 100).round()}%', style: theme.bodySmall.override(fontWeight: FontWeight.w800)),
                Text(context.t('dash_quota_free', {'left': '${auth.freeListingsLeft}', 'total': '${auth.freeListingsTotal}'}), style: theme.bodySmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    TGButton(
                      onPressed: _uploadMockPhotos,
                      label: 'Upload photos',
                      height: 40,
                      borderRadius: BorderRadius.circular(TGRadius.pill),
                    ),
                    OutlinedButton(onPressed: _rows.isEmpty ? null : _saveDrafts, child: const Text('Save all as drafts')),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _rows.isEmpty
                ? const Center(child: Text('Upload photos to create draft rows'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: _rows.length,
                    itemBuilder: (ctx, i) {
                      final row = _rows[i];
                      return AnimatedScale(
                        scale: 1,
                        duration: tgAnim(context, const Duration(milliseconds: 120)),
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: phone
                                ? _mobileRow(row, theme)
                                : _desktopRow(row, theme),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Material(
            elevation: 8,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: TGButton(
                  onPressed: _publishing ? null : _publishSelected,
                  label: _publishing ? 'Publishing…' : 'Publish selected',
                  height: 48,
                  borderRadius: BorderRadius.circular(TGRadius.pill),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopRow(BulkAddRow row, FlutterFlowTheme theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(value: row.selected, onChanged: (v) => setState(() => row.selected = v ?? false)),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(row.photos.first, width: 72, height: 72, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(width: 72, height: 72)),
        ),
        const SizedBox(width: 12),
        Expanded(child: _fields(row, theme)),
      ],
    );
  }

  Widget _mobileRow(BulkAddRow row, FlutterFlowTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Checkbox(value: row.selected, onChanged: (v) => setState(() => row.selected = v ?? false)),
            Expanded(child: Text(row.blockReason ?? 'Ready', style: TextStyle(fontWeight: FontWeight.w800, color: row.blockReason == null ? TGColors.cta : TGColors.rating))),
          ],
        ),
        if (row.photos.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(row.photos.first, height: 140, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(height: 140)),
          ),
        _fields(row, theme),
      ],
    );
  }

  Widget _fields(BulkAddRow row, FlutterFlowTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          decoration: const InputDecoration(labelText: 'Title', isDense: true, border: OutlineInputBorder()),
          onChanged: (v) => setState(() => row.title = v),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<TGCategory>(
          value: row.category,
          decoration: const InputDecoration(labelText: 'Category', isDense: true, border: OutlineInputBorder()),
          items: TGCategory.values.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
          onChanged: (v) => setState(() => row.category = v ?? row.category),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          children: [
            ChoiceChip(label: const Text('NOWY'), selected: row.condition == TGCondition.newItem, onSelected: (_) => setState(() => row.condition = TGCondition.newItem)),
            ChoiceChip(label: const Text('UŻYWANY'), selected: row.condition == TGCondition.used, onSelected: (_) => setState(() => row.condition = TGCondition.used)),
          ],
        ),
        TextField(
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Price PLN', isDense: true, border: OutlineInputBorder()),
          onChanged: (v) => setState(() => row.priceText = v),
        ),
        Wrap(
          spacing: 6,
          children: [
            for (final b in TGPriceBasis.values)
              ChoiceChip(label: Text(b.name), selected: row.basis == b, onSelected: (_) => setState(() => row.basis = b)),
          ],
        ),
        if (row.blockReason != null)
          Text(row.blockReason!, style: const TextStyle(color: TGColors.rating, fontWeight: FontWeight.w700, fontSize: 12)),
      ],
    );
  }
}
