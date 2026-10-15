import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/dashboard/dash3_widgets.dart';
import 'package:twoja_gastromania/dashboard/dashboard_shell.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/main.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_account.dart';
import 'package:twoja_gastromania/tg_models/tg_referral.dart';
import 'package:twoja_gastromania/tg_services/account_settings_service.dart';
import 'package:twoja_gastromania/tg_services/messaging_service.dart';
import 'package:twoja_gastromania/tg_services/referral_repository.dart';
import 'package:twoja_gastromania/tg_services/verification_service.dart';

/// `/dashboard/settings?tab=profile|security|language|blocked|privacy`.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.tab});

  static const routeName = 'DashboardSettings';
  static const routePath = '/dashboard/settings';
  static const tabs = ['profile', 'security', 'language', 'blocked', 'privacy'];

  final String? tab;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String get _tab => SettingsPage.tabs.contains(widget.tab) ? widget.tab! : 'profile';

  @override
  void initState() {
    super.initState();
    TGAnalytics.track('settings_view', {'tab': _tab});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) TGAccountSettingsService.instance.seedMocks(context.read<FakeAuthState>().userId);
    });
  }

  @override
  void didUpdateWidget(covariant SettingsPage old) {
    super.didUpdateWidget(old);
    if (old.tab != widget.tab) TGAnalytics.track('settings_view', {'tab': _tab});
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return DashboardShell(
      current: 'settings',
      child: ListenableBuilder(
        listenable: Listenable.merge([TGAccountSettingsService.instance, MessagingService.instance, TGVerificationService.instance]),
        builder: (context, _) {
          final auth = context.watch<FakeAuthState>();
          return Column(
            key: const Key('settings-page'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(context.t('set_title'), style: theme.headlineMedium.override(fontWeight: FontWeight.w900)),
              ),
              const SizedBox(height: 12),
              DashTabBar(
                keyPrefix: 'settings',
                semanticsLabel: context.t('set_title'),
                current: _tab,
                tabs: [for (final t in SettingsPage.tabs) (t, context.t('set_tab_$t'))],
                onSelect: (t) => context.go('${SettingsPage.routePath}?tab=$t'),
              ),
              const SizedBox(height: 16),
              switch (_tab) {
                'security' => _SecurityTab(auth: auth),
                'language' => _LanguageTab(auth: auth),
                'blocked' => _BlockedTab(auth: auth),
                'privacy' => _PrivacyTab(auth: auth),
                _ => _ProfileTab(key: ValueKey('profile-${auth.userId}'), auth: auth),
              },
            ],
          );
        },
      ),
    );
  }
}

String _fmt(BuildContext context, DateTime d) => DateFormat('d MMM y, HH:mm', FFLocalizations.of(context).languageCode).format(d);

ButtonStyle get _cta => FilledButton.styleFrom(backgroundColor: TGColors.cta, foregroundColor: Colors.black);

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, super.key, this.subtitle});
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DashBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(header: true, child: Text(title, style: theme.titleMedium.override(fontWeight: FontWeight.w900))),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: theme.bodySmall.override(color: theme.secondaryText)),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ThemePreferenceSection extends StatelessWidget {
  const _ThemePreferenceSection();

  static const _options = <(ThemeMode, String, String)>[
    (ThemeMode.light, 'light', 'set_theme_light'),
    (ThemeMode.dark, 'dark', 'set_theme_dark'),
    (ThemeMode.system, 'system', 'set_theme_system'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TGThemeController.instance,
      builder: (context, _) {
        final current = TGThemeController.instance.mode;
        return _Section(
          key: const Key('set-theme-section'),
          title: context.t('set_theme_title'),
          subtitle: context.t('set_theme_sub'),
          child: Semantics(
            container: true,
            label: context.t('set_theme_title'),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final opt in _options)
                  Semantics(
                    button: true,
                    selected: current == opt.$1,
                    label: context.t(opt.$3),
                    child: ChoiceChip(
                      key: Key('set-theme-${opt.$2}'),
                      label: Text(context.t(opt.$3)),
                      selected: current == opt.$1,
                      onSelected: (_) {
                        FlutterFlowTheme.saveThemeMode(opt.$1);
                        TGThemeController.instance.setMode(opt.$1);
                        MyApp.trySetThemeMode(context, opt.$1);
                        showTGToast(context, context.t('set_saved'));
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Err extends StatelessWidget {
  const _Err(this.keyName);
  final String keyName;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Semantics(
          liveRegion: true,
          child: Text(context.t(keyName),
              key: const Key('set-error'), style: FlutterFlowTheme.of(context).bodySmall.override(color: TGColors.error, fontWeight: FontWeight.w700)),
        ),
      );
}

// -----------------------------------------------------------------------------
// Profile
// -----------------------------------------------------------------------------

class _ProfileTab extends StatefulWidget {
  const _ProfileTab({required this.auth, super.key});
  final FakeAuthState auth;

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  late final TGAccountProfile _p = TGAccountSettingsService.instance.profileOf(widget.auth);
  late final _first = TextEditingController(text: _p.firstName);
  late final _last = TextEditingController(text: _p.lastName);
  late final _city = TextEditingController(text: _p.city);
  String? _error;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _city.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final ver = TGVerificationService.instance;
    final preview = tgPublicName(_first.text, _last.text);
    final phone = ver.phoneOf(widget.auth.userId);
    final email = ver.emailOf(widget.auth.userId, fallback: widget.auth.mockEmail);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ThemePreferenceSection(),
        _Section(
          title: context.t('set_profile_title'),
          subtitle: context.t('set_profile_sub'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('set-first'),
                controller: _first,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: context.t('set_first')),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('set-last'),
                controller: _last,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: context.t('set_last')),
              ),
              const SizedBox(height: 8),
              TextField(key: const Key('set-city'), controller: _city, decoration: InputDecoration(labelText: context.t('set_city'))),
              const SizedBox(height: 12),
              Semantics(
                container: true,
                label: '${context.t('set_public_name')}: $preview',
                excludeSemantics: true,
                child: Row(
                  children: [
                    Text('${context.t('set_public_name')}: ', style: theme.bodyMedium.override(color: theme.secondaryText)),
                    Flexible(child: Text(preview, key: const Key('set-public-name'), style: theme.bodyLarge.override(fontWeight: FontWeight.w900))),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(context.t('set_public_name_note'), style: theme.bodySmall.override(color: theme.secondaryText)),
              if (_error != null) _Err(_error!),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  key: const Key('set-profile-save'),
                  style: _cta,
                  onPressed: () {
                    final err = TGAccountSettingsService.instance.saveProfile(widget.auth, first: _first.text, last: _last.text, city: _city.text);
                    setState(() => _error = err);
                    if (err == null) showTGToast(context, context.t('set_saved'));
                  },
                  child: Text(context.t('set_save')),
                ),
              ),
            ],
          ),
        ),
        _Section(
          title: context.t('set_contact_title'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${context.t('vc_phone_title')}: ${phone.value ?? context.t('vc_phone_empty')}', key: const Key('set-contact-phone')),
              const SizedBox(height: 4),
              Text('${context.t('vc_email_title')}: ${email.value ?? '—'}'),
              const SizedBox(height: 8),
              TextButton(
                key: const Key('set-go-verification'),
                onPressed: () => context.go('/dashboard/verification'),
                child: Text(context.t('set_contact_manage')),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Security
// -----------------------------------------------------------------------------

class _SecurityTab extends StatefulWidget {
  const _SecurityTab({required this.auth});
  final FakeAuthState auth;

  @override
  State<_SecurityTab> createState() => _SecurityTabState();
}

class _SecurityTabState extends State<_SecurityTab> {
  final _cur = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _cur.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _save() {
    final err = TGAccountSettingsService.instance.changePassword(widget.auth.userId, current: _cur.text, next: _next.text, confirm: _confirm.text);
    setState(() => _error = err);
    if (err == null) {
      _cur.clear();
      _next.clear();
      _confirm.clear();
      showTGToast(context, context.t('set_pw_done'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final svc = TGAccountSettingsService.instance;
    final uid = widget.auth.userId;
    final changed = svc.passwordChangedAt(uid);
    final on = svc.twoFaEnabled(uid);
    final codes = svc.backupCodes(uid);
    final sessions = svc.sessionsOf(uid);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(
          key: const Key('set-pw-section'),
          title: context.t('set_pw_title'),
          subtitle: changed == null ? context.t('set_pw_demo') : context.t('set_pw_changed', {'date': _fmt(context, changed)}),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(key: const Key('set-pw-current'), controller: _cur, obscureText: true, decoration: InputDecoration(labelText: context.t('set_pw_current'))),
              const SizedBox(height: 8),
              TextField(key: const Key('set-pw-new'), controller: _next, obscureText: true, decoration: InputDecoration(labelText: context.t('set_pw_new'), helperText: context.t('set_pw_rules'))),
              const SizedBox(height: 8),
              TextField(key: const Key('set-pw-confirm'), controller: _confirm, obscureText: true, decoration: InputDecoration(labelText: context.t('set_pw_confirm'))),
              if (_error != null) _Err(_error!),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(key: const Key('set-pw-save'), style: _cta, onPressed: _save, child: Text(context.t('set_pw_save'))),
              ),
            ],
          ),
        ),
        _Section(
          key: const Key('set-2fa-section'),
          title: context.t('set_2fa_title'),
          subtitle: context.t('set_2fa_sub'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DashPill(label: context.t(on ? 'set_2fa_on' : 'set_2fa_off'), color: on ? theme.success : theme.secondaryText),
              const SizedBox(height: 10),
              if (on) ...[
                Text(context.t('set_2fa_backup'), style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                SelectableText(codes.join('   '), key: const Key('set-2fa-backup'), style: const TextStyle(fontFamily: 'monospace')),
                const SizedBox(height: 4),
                Text(context.t('set_2fa_backup_note'), style: theme.bodySmall.override(color: theme.secondaryText)),
                const SizedBox(height: 8),
                OutlinedButton(
                  key: const Key('set-2fa-disable'),
                  onPressed: () => showDashSheet<void>(context, title: context.t('set_2fa_disable'), builder: (_) => _TwoFaDisable(userId: uid)),
                  child: Text(context.t('set_2fa_disable')),
                ),
              ] else
                FilledButton(
                  key: const Key('set-2fa-enable'),
                  style: _cta,
                  onPressed: () {
                    svc.startTwoFa(uid);
                    showDashSheet<void>(context, key: const Key('set-2fa-sheet'), title: context.t('set_2fa_title'), builder: (_) => _TwoFaSetup(userId: uid));
                  },
                  child: Text(context.t('set_2fa_enable')),
                ),
            ],
          ),
        ),
        _Section(
          title: context.t('set_sessions_title'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final s in sessions)
                ListTile(
                  key: Key('set-session-${s.id}'),
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(s.device.contains('iPhone') ? Icons.phone_iphone : Icons.laptop),
                  title: Text(s.device),
                  subtitle: Text('${s.city} · ${s.current ? context.t('set_session_current') : _fmt(context, s.lastSeen)}'),
                ),
              if (sessions.length > 1)
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    key: const Key('set-sessions-signout'),
                    onPressed: () => svc.signOutOthers(uid),
                    child: Text(context.t('set_sessions_signout')),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TwoFaSetup extends StatefulWidget {
  const _TwoFaSetup({required this.userId});
  final String userId;

  @override
  State<_TwoFaSetup> createState() => _TwoFaSetupState();
}

class _TwoFaSetupState extends State<_TwoFaSetup> {
  final _code = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final key = TGAccountSettingsService.instance.twoFaSetupKey(widget.userId) ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.t('set_2fa_step1'), style: theme.bodyMedium),
        const SizedBox(height: 6),
        SelectableText(key, key: const Key('set-2fa-key'), style: const TextStyle(fontFamily: 'monospace', fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Text(context.t('set_2fa_step2'), style: theme.bodyMedium),
        const SizedBox(height: 6),
        TextField(
          key: const Key('set-2fa-code'),
          controller: _code,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: InputDecoration(labelText: context.t('vc_code_label'), helperText: context.t('vc_code_demo')),
        ),
        if (_error != null) _Err(_error!),
        const SizedBox(height: 8),
        FilledButton(
          key: const Key('set-2fa-confirm'),
          style: _cta,
          onPressed: () {
            final err = TGAccountSettingsService.instance.confirmTwoFa(widget.userId, _code.text);
            if (err != null) {
              setState(() => _error = err);
              return;
            }
            Navigator.pop(context);
            showTGToast(context, context.t('set_2fa_done'));
          },
          child: Text(context.t('vc_confirm')),
        ),
      ],
    );
  }
}

class _TwoFaDisable extends StatefulWidget {
  const _TwoFaDisable({required this.userId});
  final String userId;

  @override
  State<_TwoFaDisable> createState() => _TwoFaDisableState();
}

class _TwoFaDisableState extends State<_TwoFaDisable> {
  final _pw = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(key: const Key('set-2fa-disable-pw'), controller: _pw, obscureText: true, decoration: InputDecoration(labelText: context.t('set_pw_current'))),
          if (_error != null) _Err(_error!),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('set-2fa-disable-confirm'),
            style: FilledButton.styleFrom(backgroundColor: TGColors.error, foregroundColor: Colors.white),
            onPressed: () {
              final err = TGAccountSettingsService.instance.disableTwoFa(widget.userId, _pw.text);
              if (err != null) {
                setState(() => _error = err);
                return;
              }
              Navigator.pop(context);
            },
            child: Text(context.t('set_2fa_disable')),
          ),
        ],
      );
}

// -----------------------------------------------------------------------------
// Language
// -----------------------------------------------------------------------------

class _LanguageTab extends StatelessWidget {
  const _LanguageTab({required this.auth});
  final FakeAuthState auth;

  static const _langs = [('pl', 'Polski'), ('en', 'English'), ('tr', 'Türkçe')];

  @override
  Widget build(BuildContext context) {
    final current = FFLocalizations.of(context).languageCode;
    return _Section(
      title: context.t('set_lang_title'),
      subtitle: context.t('set_lang_sub'),
      child: RadioGroup<String>(
        groupValue: current,
        onChanged: (code) {
          if (code == null) return;
          TGAccountSettingsService.instance.setLanguage(auth, code);
          MyApp.trySetLocale(context, code);
          showTGToast(context, context.t('set_saved'));
        },
        child: Column(
          children: [
            for (final (code, name) in _langs)
              RadioListTile<String>(
                key: Key('set-lang-$code'),
                contentPadding: EdgeInsets.zero,
                value: code,
                title: Text(name),
              ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Blocked users
// -----------------------------------------------------------------------------

class _BlockedTab extends StatelessWidget {
  const _BlockedTab({required this.auth});
  final FakeAuthState auth;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final list = TGAccountSettingsService.instance.blockedUsers(auth.userId);
    return _Section(
      title: context.t('set_blocked_title'),
      subtitle: context.t('set_blocked_sub'),
      child: list.isEmpty
          ? Text(context.t('set_blocked_empty'), key: const Key('set-blocked-empty'), style: theme.bodyMedium.override(color: theme.secondaryText))
          : Column(
              children: [
                for (final u in list)
                  ListTile(
                    key: Key('set-blocked-${u.id}'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.block),
                    title: Text(u.name),
                    trailing: TextButton(
                      key: Key('set-unblock-${u.id}'),
                      onPressed: () {
                        TGAccountSettingsService.instance.unblock(auth.userId, u.id);
                        showTGToast(context, context.t('set_unblocked', {'name': u.name}));
                      },
                      child: Text(context.t('set_unblock')),
                    ),
                  ),
              ],
            ),
    );
  }
}

// -----------------------------------------------------------------------------
// Privacy & data
// -----------------------------------------------------------------------------

class _PrivacyTab extends StatelessWidget {
  const _PrivacyTab({required this.auth});
  final FakeAuthState auth;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final svc = TGAccountSettingsService.instance;
    final next = svc.nextExportAt(auth.userId);
    final cooling = next != null && TGClock.now().isBefore(next);
    final last = svc.exportsOf(auth.userId).lastOrNull;
    final del = svc.deletionOf(auth.userId);
    return ListenableBuilder(
      listenable: ReferralRepository.instance,
      builder: (context, _) {
        final referred = ReferralRepository.instance.accountOf(auth.userId);
        return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (referred != null)
          _Section(
            key: const Key('set-referral-visibility'),
            title: context.t('ref_privacy_title'),
            subtitle: context.t('ref_privacy_sub'),
            child: SwitchListTile(
              key: const Key('set-referral-visibility-switch'),
              value: referred.referralVisibility == TGReferralVisibility.on,
              contentPadding: EdgeInsets.zero,
              title: Text(context.t('ref_privacy_toggle')),
              onChanged: (on) {
                ReferralRepository.instance.setVisibility(auth.userId, on ? TGReferralVisibility.on : TGReferralVisibility.withdrawn);
                auth.applyReferralMirror(ReferralRepository.instance.accountOf(auth.userId));
              },
            ),
          ),
        _Section(
          key: const Key('set-export-section'),
          title: context.t('set_export_title'),
          subtitle: context.t('set_export_sub'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (cooling)
                Text(context.t('set_export_next', {'date': _fmt(context, next)}), key: const Key('set-export-next'), style: theme.bodySmall.override(color: theme.secondaryText)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    key: const Key('set-export'),
                    style: _cta,
                    onPressed: cooling
                        ? null
                        : () {
                            final r = svc.requestExport(auth);
                            if (r.export != null) {
                              showDashTextExport(context, title: context.t('set_export_title'), fileName: 'twoja-gastromania-${auth.userId}.json', content: r.export!.json);
                            }
                          },
                    icon: const Icon(Icons.download, size: 18),
                    label: Text(context.t('set_export_btn')),
                  ),
                  if (last != null)
                    OutlinedButton(
                      key: const Key('set-export-open'),
                      onPressed: () => showDashTextExport(context, title: context.t('set_export_title'), fileName: 'twoja-gastromania-${auth.userId}.json', content: last.json),
                      child: Text(context.t('set_export_open')),
                    ),
                ],
              ),
            ],
          ),
        ),
        _Section(
          key: const Key('set-delete-section'),
          title: context.t('set_del_title'),
          subtitle: context.t('set_del_sub'),
          child: del != null
              ? Column(
                  key: const Key('set-del-pending'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.t('set_del_pending', {'date': _fmt(context, del.effectiveAt)}),
                        style: theme.bodyMedium.override(color: TGColors.slaAmber, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      key: const Key('set-del-cancel'),
                      onPressed: () {
                        svc.cancelDeletion(auth.userId);
                        showTGToast(context, context.t('set_del_cancelled'));
                      },
                      child: Text(context.t('set_del_cancel')),
                    ),
                  ],
                )
              : Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    key: const Key('set-del-start'),
                    style: OutlinedButton.styleFrom(foregroundColor: TGColors.error, side: const BorderSide(color: TGColors.error)),
                    onPressed: () => showDashSheet<void>(
                      context,
                      key: const Key('set-del-sheet'),
                      title: context.t('set_del_title'),
                      builder: (_) => _DeleteFlow(auth: auth),
                    ),
                    child: Text(context.t('set_del_start')),
                  ),
                ),
        ),
      ],
        );
      },
    );
  }
}

class _DeleteFlow extends StatefulWidget {
  const _DeleteFlow({required this.auth});
  final FakeAuthState auth;

  @override
  State<_DeleteFlow> createState() => _DeleteFlowState();
}

class _DeleteFlowState extends State<_DeleteFlow> {
  final _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final svc = TGAccountSettingsService.instance;
    final checks = svc.deleteChecks(widget.auth);
    final blocked = checks.any((c) => !c.ok);
    final word = context.t('set_del_word');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.t('set_del_checks'), style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        for (final c in checks)
          Semantics(
            container: true,
            label: '${context.t(c.ok ? 'ver_met' : 'ver_not_met')}: ${context.t(c.labelKey, {'n': '${c.count}'})}',
            excludeSemantics: true,
            child: Padding(
              key: Key('set-del-check-${c.id}'),
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Icon(c.ok ? Icons.check_circle : Icons.error_outline, size: 18, color: c.ok ? theme.success : TGColors.error),
                const SizedBox(width: 8),
                Expanded(child: Text(context.t(c.labelKey, {'n': '${c.count}'}), style: theme.bodyMedium)),
              ]),
            ),
          ),
        const SizedBox(height: 12),
        Text(context.t('set_del_what'), style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(context.t('set_del_what_body', {'days': '${TGAccountSettingsService.deletionGrace.inDays}'}), style: theme.bodyMedium),
        const SizedBox(height: 12),
        Container(
          key: const Key('set-del-legal'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: TGColors.background, borderRadius: BorderRadius.circular(TGRadius.card), border: Border.all(color: TGColors.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.t('set_del_legal_title'), style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('• ${context.t('set_del_legal_invoices')}', style: theme.bodySmall),
              Text('• ${context.t('set_del_legal_moderation')}', style: theme.bodySmall),
              Text('• ${context.t('set_del_legal_cases')}', style: theme.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (blocked)
          Text(context.t('set_del_blocked'), key: const Key('set-del-blocked'), style: theme.bodyMedium.override(color: TGColors.error, fontWeight: FontWeight.w700))
        else ...[
          TextField(
            key: const Key('set-del-confirm'),
            controller: _confirm,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: context.t('set_del_type', {'word': word})),
          ),
          if (_error != null) _Err(_error!),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('set-del-submit'),
            style: FilledButton.styleFrom(backgroundColor: TGColors.error, foregroundColor: Colors.white),
            onPressed: _confirm.text.trim() == word
                ? () {
                    final err = svc.requestDeletion(widget.auth, confirmText: _confirm.text);
                    if (err != null) {
                      setState(() => _error = err);
                      return;
                    }
                    Navigator.pop(context);
                    showTGToast(context, context.t('set_del_requested'));
                  }
                : null,
            child: Text(context.t('set_del_submit')),
          ),
        ],
      ],
    );
  }
}
