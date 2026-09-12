import 'package:wyn/core/typography/browser_system_text.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_repository.dart';
import '../data/pending_referral_code.dart';
import 'email_auth_screen.dart';
import 'phone_entry_screen.dart';
import 'redeem_invite_code_screen.dart';
import '../../../core/design/wyn_spacing.dart';

/// Screen 2 — Auth Method Selection.
/// See .wyn/docs/design/wyn-002-authentication-onboarding.md
class AuthMethodScreen extends StatefulWidget {
  const AuthMethodScreen({
    super.key,
    this.authRepository,
    this.isAddingAccount = false,
  });

  /// Optional/defaulted, same shape as every other repository this app
  /// threads through optionally -- added so AccountSwitcherSheet can push
  /// this screen directly (`isAddingAccount: true`) without needing an
  /// AuthRepository instance of its own; WelcomeScreen's own call site
  /// still always passes one explicitly.
  final AuthRepository? authRepository;

  /// True when reached from AccountSwitcherSheet's "เพิ่มบัญชี" row
  /// instead of from WelcomeScreen -- an already-signed-in user adding a
  /// *second* account. Signing in successfully here still goes through
  /// the exact same AuthGate-driven flow as any other sign-in (the new
  /// session simply becomes the active one, and AuthGate's own listener
  /// pops back to itself) -- this flag only changes what's shown on
  /// screen: a title that matches the actual action, and no guest
  /// option (browsing as a guest isn't a meaningful "account" to add to
  /// the switcher).
  final bool isAddingAccount;

  @override
  State<AuthMethodScreen> createState() => _AuthMethodScreenState();
}

class _AuthMethodScreenState extends State<AuthMethodScreen> {
  late final AuthRepository _authRepository =
      widget.authRepository ?? AuthRepository(Supabase.instance.client);

  // Temporarily hidden -- Phone/OTP sign-in is a real, supported auth
  // method (approved by Founder, 2026-08-13) but the Supabase project's
  // phone provider isn't enabled and no SMS provider (Twilio) is
  // configured yet, so tapping through to PhoneEntryScreen and sending
  // an OTP always fails server-side. Flip back to true once Twilio is
  // set up -- see .wyn/company/DECISIONS.md, 2026-08-24 ("Phone Login
  // ซ่อนชั่วคราว").
  static const _phoneLoginEnabled = false;

  // WYN-072: paused for the same reason -- Sign in with Apple requires
  // an Apple Developer Program membership to actually work (Apple OAuth
  // provider config, capability entitlement), and Founder confirmed
  // (2026-08-30) that hasn't been purchased yet ("แพงจ่ายไม่ไหว"). The
  // button was reachable and tappable but every tap failed silently
  // server-side -- worse than not offering it at all. Flip back to true
  // once the Apple Developer Program is set up -- signInWithApple()
  // itself is untouched in AuthRepository, ready to go.
  static const _appleLoginEnabled = false;

  // Guest Browsing (WYN-072) paused -- Founder asked to turn this off
  // (2026-09-08, screenshot of this exact button circled) after WYN-131
  // surfaced repeated gaps where an anonymous guest session reached
  // write paths (Club join/create) that were never meant to allow it --
  // pausing the entry point itself removes that whole class of risk
  // while guest-gate coverage gets audited, instead of patching each
  // gap as it's found. Flip back to true once that audit is done --
  // signInAnonymously() itself is untouched in AuthRepository, ready to
  // go. See .wyn/company/DECISIONS.md, 2026-09-08.
  static const _guestBrowsingEnabled = false;

  bool _isLoading = false;
  String? _errorMessage;

  // WYN-113 (Invite-Only Access Gate): true while the Founder's gate is
  // on and this visitor hasn't redeemed a code yet this app session --
  // shows a "กรอกโค้ดเชิญ" prompt in place of the real sign-in buttons
  // below. Never true when adding a second account (`isAddingAccount`)
  // -- that's an existing, already-onboarded user, not one of the new
  // users this gate exists to throttle. Both start true (not false, and
  // set for real in initState -- a field initializer can't read
  // `widget` yet) so the real sign-in buttons never flash on screen for
  // an instant before the gate check below resolves.
  late bool _inviteGateBlocking;
  late bool _checkingInviteGate;

  @override
  void initState() {
    super.initState();
    _inviteGateBlocking = !widget.isAddingAccount;
    _checkingInviteGate = !widget.isAddingAccount;
    if (!widget.isAddingAccount) _checkInviteGate();
  }

  Future<void> _checkInviteGate() async {
    bool enabled;
    try {
      enabled = await _authRepository.isInviteGateEnabled();
    } catch (_) {
      // Fail open -- same posture as AuthGate's own moderation-status/
      // document-acceptance checks: a network hiccup checking this must
      // never itself become a way to lock every visitor out of signing
      // up at all.
      enabled = false;
    }
    if (!mounted) return;
    setState(() {
      _inviteGateBlocking = enabled && !PendingReferralCode.hasValidatedCode;
      _checkingInviteGate = false;
    });
  }

  Future<void> _redeemInviteCode() async {
    final redeemed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RedeemInviteCodeScreen(authRepository: _authRepository),
      ),
    );
    if (redeemed == true && mounted) {
      setState(() => _inviteGateBlocking = false);
    }
  }

  Future<void> _handle(Future<void> Function() action) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await action();
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'เข้าสู่ระบบไม่สำเร็จ ลองใหม่อีกครั้ง');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: WynSpacing.space6),
              BrowserSystemText(
                widget.isAddingAccount ? 'เพิ่มบัญชี WYNOS' : 'เข้าสู่ระบบ WYNOS',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: WynSpacing.space8),
              // WYN-113 (Invite-Only Access Gate): while the gate is on
              // and this visitor hasn't redeemed a code yet, the real
              // sign-in buttons below are replaced with a "กรอกโค้ดเชิญ"
              // prompt entirely -- there is no way to reach Google/
              // Apple/Email/Phone sign-in without one. The guest-browse
              // button further down is deliberately NOT behind this
              // check (see RedeemInviteCodeScreen's own doc comment).
              if (_checkingInviteGate) ...[
                const Center(child: CircularProgressIndicator()),
              ] else if (_inviteGateBlocking) ...[
                BrowserSystemText(
                  'ตอนนี้ WYNOS เปิดให้เข้าใช้งานเฉพาะผู้ที่มีโค้ดเชิญจากเพื่อนเท่านั้น',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: WynSpacing.space4),
                FilledButton(
                  onPressed: _redeemInviteCode,
                  child: const BrowserSystemText('กรอกโค้ดเชิญ'),
                ),
              ] else ...[
                FilledButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () => _handle(_authRepository.signInWithGoogle),
                  icon: const Icon(Icons.g_mobiledata),
                  label: const BrowserSystemText('เข้าสู่ระบบด้วย Google'),
                ),
                if (_appleLoginEnabled) ...[
                  const SizedBox(height: WynSpacing.space3),
                  FilledButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () => _handle(_authRepository.signInWithApple),
                    icon: const Icon(Icons.apple),
                    label: const BrowserSystemText('เข้าสู่ระบบด้วย Apple'),
                  ),
                ],
                const SizedBox(height: WynSpacing.space3),
                // Any email + any number of accounts (Founder,
                // 2026-08-24) -- not tied to a single Google/Apple
                // identity, so a tester can sign up with whatever
                // address they want. See email_auth_screen.dart's own
                // doc comment.
                OutlinedButton(
                  onPressed: _isLoading
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => EmailAuthScreen(
                                authRepository: _authRepository,
                              ),
                            ),
                          ),
                  child: const BrowserSystemText('เข้าสู่ระบบด้วยอีเมล'),
                ),
                if (_phoneLoginEnabled) ...[
                  const SizedBox(height: WynSpacing.space3),
                  OutlinedButton(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PhoneEntryScreen(
                                  authRepository: _authRepository,
                                ),
                              ),
                            ),
                    child: const BrowserSystemText('ใช้เบอร์โทรศัพท์แทน'),
                  ),
                ],
              ],
              // WYN-072 (Guest Browsing): a lighter, secondary path --
              // graphite text on a plain TextButton, not paired visually
              // with Google/อีเมล above as an equal CTA -- deliberately
              // not "ข้าม" (skip), since this isn't skipping a step in
              // the same flow, it's a separate path that goes straight
              // to Home. Uses signInAnonymously() (approved 2026-08-16
              // for internal testing, never wired into UI until now) --
              // the RLS on every core table requires an `authenticated`
              // session to read anything at all, so there is no way to
              // browse with literally no session; anonymous sign-in is
              // the one already-approved mechanism that satisfies that
              // without touching RLS/Auth architecture.
              //
              // Hidden entirely when adding a second account (multi-
              // account switching) -- an anonymous session isn't a real
              // account there's any point adding to the switcher, and
              // signing into one here would silently replace whatever
              // account this screen was reached from instead of adding
              // to it.
              if (_guestBrowsingEnabled && !widget.isAddingAccount) ...[
                const SizedBox(height: WynSpacing.space6),
                Center(
                  child: Semantics(
                    label: 'เข้าชม WYNOS โดยไม่ต้องเข้าสู่ระบบ',
                    button: true,
                    child: TextButton(
                      // Graphite/onSurfaceVariant, not the theme's primary
                      // color -- a deliberately lighter-weight CTA than
                      // Google/อีเมล above, per the design spec's own "ทาง
                      // เลือกที่เบา กว่า" note. Semantic token (not a
                      // hardcoded WynColors.graphite) so it still adapts
                      // correctly in dark mode, same convention every other
                      // screen in this app already follows.
                      style: TextButton.styleFrom(
                        foregroundColor:
                            Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      onPressed: _isLoading
                          ? null
                          : () => _handle(
                                () => _authRepository.signInAnonymously(),
                              ),
                      child: const BrowserSystemText('เข้าชม WYNOS ได้เลย'),
                    ),
                  ),
                ),
              ],
              if (_isLoading) ...[
                const SizedBox(height: WynSpacing.space6),
                const Center(child: CircularProgressIndicator()),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: WynSpacing.space4),
                BrowserSystemText(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
