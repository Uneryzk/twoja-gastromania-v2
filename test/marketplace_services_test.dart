import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoja_gastromania/payment/payment_models.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_invoice.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_services/invoicing_service.dart';
import 'package:twoja_gastromania/tg_services/messaging_service.dart';
import 'package:twoja_gastromania/tg_services/product_service.dart';
import 'package:twoja_gastromania/tg_services/profanity_filter.dart';
import 'package:twoja_gastromania/tg_services/translation_service.dart';

import 'helpers/tg_test_app.dart';

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() async {
    await TGProductService.instance.resetToSeed();
    MessagingService.instance.reset();
    InvoicingService.instance.reset();
  });

  test('VAT 23% invoice payload is webhook-ready', () {
    final invoice = InvoicingService.instance.onPaymentSuccess(
      grossAmount: 123,
      transactionId: 'txn_test',
      buyer: const TGInvoiceBuyer(nip: '1111111111', companyName: 'Gastro Sp. z o.o.', address: 'ul. Test 1, Katowice'),
      listingId: 'pay_me',
    );
    expect(invoice.vatRate, TGPricing.vatRate);
    expect(invoice.netAmount + invoice.vatAmount, closeTo(invoice.grossAmount, 0.02));
    expect(invoice.nip, '1111111111');
    expect(invoice.toJson()['webhookReady'], isTrue);
    expect(InvoicingService.instance.webhookQueue, isNotEmpty);
  });

  test('profanity filter blocks PL/EN/TR/DE slurs', () {
    const f = TGProfanityFilter();
    expect(f.isBlocked('Hello kurwa there'), isTrue);
    expect(f.isBlocked('this is fucking rude'), isTrue);
    expect(f.isBlocked('siktir git'), isTrue);
    expect(f.isBlocked('du Hurensohn'), isTrue);
    expect(f.isBlocked('Is this still available?'), isFalse);
  });

  test('messaging persists legal log fields and reports', () {
    final product = TGProduct(
      id: 'p001',
      title: 'Test oven',
      price: 100,
      priceUnit: TGPriceUnit.oneTime,
      priceBasis: TGPriceBasis.brutto,
      negotiable: false,
      oldPrice: null,
      condition: TGCondition.used,
      listingType: TGListingType.buy,
      category: TGCategory.cookingEquipment,
      powerType: TGPowerType.electric,
      warrantyMonths: 0,
      delivery: true,
      pickup: true,
      seller: const TGSeller(id: 'seller_primegastro', name: 'PrimeGastro', type: TGSellerType.store, verified: true, rating: 4.9),
      city: 'Katowice',
      voivodeship: 'Śląskie',
      phone: '',
      imageUrl: '',
      photoCount: 1,
      isPromoted: false,
      createdAt: DateTime.now(),
    );
    final blocked = MessagingService.instance.send(
      product: product,
      senderId: FakeAuthState.mockOwnerId,
      senderName: 'TG Demo',
      body: 'kurwa',
    );
    expect(blocked.blocked, isTrue);

    final ok = MessagingService.instance.send(
      product: product,
      senderId: FakeAuthState.mockOwnerId,
      senderName: 'TG Demo',
      body: 'Ask seller about shipping cost',
    );
    expect(ok.ok, isTrue);
    final thread = MessagingService.instance.byId(ok.threadId!);
    expect(thread, isNotNull);
    final log = thread!.messages.last.toLegalLog();
    expect(log['sender_id'], FakeAuthState.mockOwnerId);
    expect(log['receiver_id'], 'seller_primegastro');
    expect(log['ip_address'], MessagingService.mockIp);
    expect(log['is_reported'], isFalse);
    MessagingService.instance.reportThread(thread.id, FakeAuthState.mockOwnerId);
    expect(thread.reported, isTrue);
    expect(thread.messages.last.isReported, isTrue);
    expect(MessagingService.instance.moderationFlags, isNotEmpty);
  });

  test('DeepL stub always translates into English, including PL and TR', () async {
    final pl = await TranslationService.instance.translate('Krajalnica chleba – wygasła');
    expect(pl.toLowerCase(), contains('bread'));
    expect(pl.toLowerCase(), contains('expired'));
    expect(pl, isNot(contains('[tr]')));
    expect(TranslationService.instance.detectLanguage('Krajalnica chleba – wygasła'), 'pl');
    expect(TranslationService.instance.needsEnglish('Satılık fırın, çalışır durumda'), isTrue);
    final tr = await TranslationService.instance.translate('Satılık fırın, çalışır durumda');
    expect(tr.toLowerCase(), contains('for sale'));
    expect(TranslationService.instance.detectLanguage('Combi steamer ready for use'), 'en');
    final toTr = await TranslationService.instance.translate('Sprzedający poprosił o przelew BLIK na prywatny numer.', targetLang: 'tr');
    expect(toTr, contains('BLIK'));
    expect(toTr, isNot(contains('Sprzedający')));
  });

  testWidgets('checkout queues an invoice on payment_success', (tester) async {
    final app = await pumpTgApp(tester, location: '/add-product/checkout');
    final pending = app.auth.ownedListings.first.copyWith(status: TGListingStatus.paymentPending, id: 'pay_me');
    app.auth.upsertOwned(pending);
    app.auth.beginCheckout(TGCheckoutCart.listing(listingId: 'pay_me', listingFee: 49, promoteFee: 0, promoteDays: 0));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('payment-blik-0')), '777123');
    await tester.pump();
    tester.widget<InkWell>(find.byKey(const Key('payment-terms'))).onTap?.call();
    await tester.pump();
    tester.widget<TGButton>(find.byKey(const Key('payment-pay'))).onPressed?.call();
    await pumpFor(tester, const Duration(milliseconds: 1600));
    expect(InvoicingService.instance.issued, isNotEmpty);
    expect(InvoicingService.instance.issued.last.grossAmount, 49);
    _expectNoErrors(app);
  });

  testWidgets('PDP message opens a bottom-right chat dock on desktop', (tester) async {
    final app = await pumpTgApp(tester, location: '/product-detail/p001', size: TGSizes.desktop);
    await tester.tap(find.text('Message').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(app.location, contains('/product-detail/'));
    expect(find.byKey(const Key('chat-dock')), findsOneWidget);
    expect(find.byKey(const Key('messages-composer')), findsOneWidget);
    expect(find.text('Ask seller about shipping cost'), findsWidgets);
    await tester.enterText(find.byKey(const Key('messages-composer')), 'Is this still available?');
    await tester.tap(find.byKey(const Key('messages-send')));
    await tester.pump();
    expect(app.location, contains('/product-detail/'));
    expect(find.text('Is this still available?'), findsWidgets);
    _expectNoErrors(app);
  });

  testWidgets('PDP shipping listing shows not-included copy and English translate', (tester) async {
    final app = await pumpTgApp(tester, location: '/product-detail/p003', size: TGSizes.desktop);
    expect(find.text('Shipping available (not included in price)'), findsOneWidget);
    expect(find.text('Shipping cost and transport details are arranged between buyer and seller.'), findsOneWidget);
    expect(find.byKey(const Key('pdp-ask-shipping')), findsOneWidget);
    expect(find.byKey(const Key('pdp-translate')), findsOneWidget);
    expect(find.text('Translate to English').evaluate().isNotEmpty || find.text('Show original').evaluate().isNotEmpty, isTrue);
    _expectNoErrors(app);
  });

  testWidgets('messages page reports a conversation', (tester) async {
    final app = await pumpTgApp(tester, location: '/dashboard/messages', size: TGSizes.desktop);
    await MessagingService.instance.ensureLoaded();
    await tester.pump();
    expect(find.byKey(const Key('messages-thread-list')), findsOneWidget);
    await tester.tap(find.byKey(const Key('messages-thread-t_p001_${FakeAuthState.mockOwnerId}')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('messages-report')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('messages-report-confirm')));
    await tester.pump();
    expect(MessagingService.instance.moderationFlags, isNotEmpty);
    _expectNoErrors(app);
  });
}

void _expectNoErrors(TGApp app) {
  app.errors.stop();
  expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
}
