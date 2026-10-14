# I18N-1 audit report

**Scope:** read-only. No ARB files. Dictionaries live in Dart maps. App code was not modified.

CSV files in this folder:

| File | Check |
|---|---|
| `A_missing.csv` | TR/PL missing or empty in source |
| `B_suspicious.csv` | TR/PL identical to EN, or English function-words in TR/PL |
| `C_hardcoded_ui.csv` | Visible widget copy not going through `tg_l10n` |
| `D_services_models.csv` | Notifications, enum labels, returned English strings |
| `E_concat_plurals.csv` | Hand-built “N days / items” (excluding `DurationFormatter`) |
| `F_formatting.csv` | Dates/numbers/units not tied to UI locale |
| `G_seed_mock.csv` | Seed/mock **user content** counts (do not translate as chrome) |
| `summary_by_group.csv` | A–F counts per screen group |

---

## How translations work

### Where keys live

There is **no ARB**. Chrome copy is a Dart map:

1. **`lib/flutter_flow/tg_l10n.dart`** — `kUiTranslations` (plus `_kDurationIcu` spread into it). This is the source of truth. Helpers:
   - `_l(en:, pl:, tr:, de:, …)` — all 10 marketplace languages required.
   - `_d(en, {pl, tr})` — **if `pl` or `tr` is omitted, that locale is filled with English at map-build time** (`pl: pl ?? en`, `tr: tr ?? en`; DE/CS/SK/UK/BE/LT/RU always copy EN unless `_l` is used).
   - `_dd` / `_dLeft` / `_durAll` — ICU plural “N days” / “N days left” templates, formatted later by `DurationFormatter`.
2. **`lib/flutter_flow/internationalization.dart`** — leftover FlutterFlow hashes (`x5fioudz`, …) with typically **only `en` + `pl`**. `mergeTranslations()` overlays `kUiTranslations` on top, then copies a full `tg_l10n` row onto a FlutterFlow key **when the English strings match**.
3. **`lib/restaurants/restaurant_l10n.dart`** — no dictionary. It calls `context.t('resto_title_…')` / type keys that already exist in `kUiTranslations`.

Lookups: `context.t('ui_buy')` → `FFLocalizations.getText`.

### How the active language is chosen

- `MaterialApp.router` uses `locale: _locale` (starts **null**) and `localeResolutionCallback: resolveAppLocale`.
- **Device language** wins if its `languageCode` is in `kSupportedLocales` (`pl, en, tr, de, cs, sk, uk, be, lt, ru`). Otherwise **English**.
- Header language menu calls `setAppLanguage` → `MyApp.setLocale`. That is **in-memory for the session**. `FFLocalizations.storeLocale` / `getStoredLocale` exist but are **not wired** to the header, so the choice is not persisted across restarts.
- **Admin console** is independent: `AdminLocaleState` defaults to **`tr`**, supported `tr/pl/en`, applied via `Localizations.override` (`AdminL10nScope`).

### Missing key / missing locale — what the user sees

`getText` (`internationalization.dart`):

```
map[locale] ?? map[code] ?? map['en'] ?? map['pl'] ?? ''
```

| Situation | On-screen result |
|---|---|
| Unknown key (not in `kTranslationsMap`) | **Empty string** (not the key name) |
| Key exists, language missing | **English**, then Polish, then empty |
| `_d('Hello')` with no `pl`/`tr` | TR and PL are **already English** in the map |
| ICU template containing `, plural,` | `DurationFormatter.formatIcu` with the active language code |

Widgets that skip `context.t` and pass a Dart string (`Text('Renew')`) **always show that language**, regardless of locale.

---

## Headline counts

Parsed keys: **3694** (3554 `tg_l10n` + 167 FlutterFlow leftovers; a few duration rows shared).

| Check | Rows | Notes |
|---|---:|---|
| A missing TR/PL | 171 | **167 FlutterFlow without authored TR**; 1 real `_d` without PL/TR (`regulamin_photo_license_status`); 3 `_durAll` keys are **false positives** (generated for all locales) |
| B suspicious | 217 | 118 FlutterFlow `pl` copied from English; 99 in `tg_l10n` (plan names, formulas, some true identical copy) |
| C hardcoded UI | 144 | Heaviest: restaurants, special-order, dashboard |
| D services/models | 136 | **132 English literals**, 4 key-returning getters |
| E concat/plurals | 5 | Home listing counts; founder “spots taken”; restaurant live-until |
| F formatting | 41 | 34 `DateFormat` without locale; 7 hardcoded units (`PLN/day`, `/mies.` in source templates) |
| G seed/mock | ~200 titled strings across seed files | User/marketplace content — do not chrome-translate |

**Allow-list (identical EN=TR/PL ignored):** Twoja Gastromania, BLIK, Przelewy24, Faktura VAT, NIP, KRS, PLN.

**Noise in B:** templates containing `_dd('days'` / `_dd('free'` match the English-word list on the **source interpolator name**, not the rendered “gün/dni” text. Treat those 19 TR/PL “days/free” hits as low priority.

---

## A — Missing TR or PL

- **FlutterFlow leftovers (167):** no `tr:` in the generated map. After merge, TR appears only if English equals a `tg_l10n` string. Otherwise `getText` **falls back to EN**. Many of these hashes are unused if chrome already uses `ui_*` keys.
- **`regulamin_photo_license_status`:** `_d('DRAFT - legal review required')` — PL and TR are English at runtime. (There is a translated sibling: `ref_consent_draft`.)
- **`ui_days_left_n` / `ui_days_left_text` / `ui_n_days`:** `_durAll(...)` — **not actually missing**; ignore in A.

## B — Suspicious (same as EN / English words)

High-signal in `tg_l10n` (not formulas):

- Plan names left untranslated: `ui_plan_basic` = “Basic”, `ui_plan_pro` = “Pro”, `ui_plan_enterprise` = “Enterprise” in TR/PL.
- Shared tokens: `Admin`, `Spam`, `Banner`, `Net`, `3-D Secure`, `Visa, Mastercard`.
- Price templates that are structurally identical (`+{fee} PLN · {period}`) — often acceptable.

FlutterFlow `pl: 'For sale'` matching `en: 'For sale'` is a **PL gap** for any leftover FF widget still using those hashes (nav chrome already uses `ui_buy` / `ui_rent`).

## C — Hardcoded visible UI (not in `tg_l10n`)

**144** unique `Text` / `hintText` / `labelText` / `tooltip` / `semanticLabel` / toast / button / chip strings.

Top files (largest backlog):

1. `lib/restaurants/restaurant_details_editor.dart` (18)
2. `lib/special_order/founders_page.dart` (13)
3. `lib/restaurants/restaurant_listing_row.dart` (10)
4. `lib/restaurants/restaurant_transfer_sheet.dart` (10)
5. `lib/dashboard/bulk_add_page.dart` (8)
6. `lib/tg_components/tg_account_sheets.dart` (8)
7. `lib/tg_components/tg_product_card.dart` (6)
8. `lib/special_order/manufacturer_dashboard_page.dart` (6)
9. `lib/special_order/seller_leads_page.dart` (6)
10. `lib/special_order/special_review_composer.dart` (6)

User-visible English that never follows the language menu includes: restaurant **Renew / Promote / Mark as transferred / Send message**, founders **Apply / Under review**, favorites gate **Login required**, login **Forgot password?**, nav fallback **Page not found**. Brand string **Twoja Gastromania** is listed where hardcoded (allowed to stay).

No PDF `pw.Text` usage found.

## D — Services and models

| Kind | Count | Produces |
|---|---:|---|
| `NotificationService.add` title/body | 65 | Almost all **English literals** (`Confirm this purchase`, `Request expired`, `Sponsor slot`, …) |
| `return '…'` English sentences | 60 | English (sync hints, founder quota, inventory copy) |
| Enum `.label` getters | 7 | English (`Fraud`, `In review`, `Visitor`, billing types, restaurant editor classes) |
| `*Key` getters | 4 | **l10n key** (correct pattern, e.g. identity conflict titles) |

In-app notification centre and deal/moderation timelines will stay English until these call `context.t` (or store a key + params).

## E — Hand-built plurals (not `DurationFormatter`)

- Home category counts: `'1 listing'` / `'$count listings'` (`home_sections.dart`).
- Founder service: `'$n of ${cfg.quota} spots taken'`.
- Restaurant success/renew: `'Live until …'`, `'New end date: …'` plus a locale-less `DateFormat`.

## F — Formatting

- **34** `DateFormat('d MMM' | 'd MMM yyyy' | …)` **without** a locale argument → month names follow the isolate default, not the UI language.
- Several call sites already pass `FFLocalizations.of(context).languageCode` (settings, ads centre) — those are fine.
- Money: many product/restaurant surfaces correctly use `NumberFormat.decimalPattern('pl_PL')` + `PLN` (intentional marketplace currency).
- Default `perDayLabel(… unit: 'PLN/day')` in `PricingConfig` is English; l10n already has `ui_pln_per_day`.

## G — Seed / mock user content (do not translate as chrome)

Approximate `title:` / `name:` counts in seed files: product 23, restaurant 25, seller profiles 25, special order 36, deals 22, moderation 41, fake auth 21. These are listing titles and company names (Polish/English mix). Treat as **user-generated content**.

---

## Summary by screen group (A–F)

| Group | A | B | C | D | E | F | Total |
|---|---:|---:|---:|---:|---:|---:|---:|
| auth / header / nav / footer | 0 | 0 | 7 | 0 | 0 | 0 | **7** |
| home | 167 | 118 | 1 | 0 | 2 | 0 | **288** |
| products and cards | 3 | 33 | 8 | 0 | 0 | 0 | **44** |
| product-detail | 0 | 3 | 1 | 0 | 0 | 1 | **5** |
| add-product and checkout | 0 | 15 | 1 | 0 | 0 | 1 | **17** |
| dashboard (listings, messages, favorites, billing, notifications, settings, verification) | 0 | 14 | 18 | 65 | 0 | 2 | **99** |
| deals / reviews / reports | 0 | 0 | 1 | 0 | 0 | 7 | **8** |
| special-order | 0 | 11 | 32 | 6 | 0 | 0 | **49** |
| restaurants | 0 | 7 | 52 | 0 | 2 | 10 | **71** |
| seller pages | 0 | 0 | 7 | 0 | 0 | 0 | **7** |
| admin | 0 | 5 | 4 | 0 | 0 | 10 | **19** |
| other (services, growth, legal) | 1 | 11 | 12 | 65 | 1 | 10 | **100** |

Home’s A/B spike is **FlutterFlow hash leftovers**, not the live `ui_buy` / `ui_rent` pills. Live restaurant + special-order chrome is the real C spike.

---

## (1) Suggested fix order (most seen by users first)

1. **Restaurant public + owner chrome** (`restaurant_listing_row`, transfer/message/success/renew, details editor) — Renew / Promote / Call / transferred flows.
2. **Home category counts** (`1 listing` / `N listings`) and **product card** login-to-favorite gate.
3. **Auth/header:** Forgot password, Page not found; keep brand name untranslated.
4. **Special Order / founders / manufacturer dashboard / leads / review composer.**
5. **Dashboard bulk add + listings row actions**; then **in-app notifications** (`D`, English titles).
6. **DateFormat locale** on restaurant detail, deals, admin (F).
7. **Enum `.label`** used on admin/moderation/report chips — staff-only but high volume.
8. FlutterFlow leftover hashes: migrate any remaining `getText('x5fioudz')` to `ui_*`, then ignore the rest.
9. True B items: plan names (Basic/Pro/Enterprise) and legal DRAFT string PL/TR.
10. Growth/admin-only copy last.

## (2) Ten files with the most chrome still outside `tg_l10n`

See C counts above (details editor → founders → listing row → transfer sheet → bulk add → account sheets → product card → manufacturer dashboard → seller leads → special review composer).

## (3) Glossary proposal (product terms)

| EN (chrome) | TR | PL |
|---|---|---|
| Listing No. | İlan no. | Nr ogłoszenia |
| For sale / For rent | Satılık / Kiralık | Na sprzedaż / Na wynajem |
| Special Order | Özel sipariş | Zamówienie specjalne |
| Transfer fee / odstępne | Devir bedeli | Odstępne |
| Deposit / kaucja | Depozito | Kaucja |
| Renew | Yenile | Odnów |
| Promote | Öne çıkar | Wyróżnij |
| Showcase | Vitrin | Witryna |
| Spotlight / Glow / Bold | Spotlight / Glow / Bold (brand; do not translate) | same |
| Review check | İnceleme kontrolü | Weryfikacja opinii |
| Deal | Anlaşma / işlem | Transakcja |
| Mark as sold / transferred | Satıldı / Devredildi işaretle | Oznacz jako sprzedane / przeniesione |
| Basic / Pro / Enterprise Store | Basic / Pro / Enterprise Mağaza | Sklep Basic / Pro / Enterprise |
| Verified seller | Doğrulanmış satıcı | Zweryfikowany sprzedawca |
| Founder (manufacturer) | Kurucu üretici | Producent założyciel |
| Banner ad | Banner reklamı | Baner |
| Sponsor slot | Sponsor alanı | Slot sponsora |
| Free listing | Ücretsiz ilan | Darmowe ogłoszenie |
| Brutto / Netto | Brüt / Net | Brutto / Netto |
| Twoja Gastromania | Twoja Gastromania | Twoja Gastromania |

Keep **BLIK, Przelewy24, NIP, KRS, PLN, Faktura VAT** unchanged in all languages.
