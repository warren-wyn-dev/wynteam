import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../profile/data/profile_repository.dart';
import '../../data/auth_repository.dart';
import '../../data/onboarding_state.dart';
import 'onboarding_scaffold.dart';
import 'steps/birthday_step.dart';
import 'steps/display_name_step.dart';
import 'steps/finish_step.dart';
import 'steps/password_step.dart';
import 'steps/profile_optional_step.dart';
import 'steps/username_step.dart';

enum _LocalStep {
  birthday,
  username,
  displayName,
  password,
  profileOptional,
  finish,
}

_LocalStep _localStepFor(OnboardingStep step) => switch (step) {
      OnboardingStep.birthday => _LocalStep.birthday,
      OnboardingStep.username => _LocalStep.username,
      OnboardingStep.displayName => _LocalStep.displayName,
      OnboardingStep.password => _LocalStep.password,
      OnboardingStep.profileOptional => _LocalStep.profileOptional,
    };

/// Rendered by AuthGate as its own route (same "not pushed on top of
/// AuthGate, IS AuthGate's own child" shape UsernameSetupScreen used
/// under the old WYN-002 flow -- see that screen's own doc comment for
/// why: AuthGate's sign-out popUntil/auth-subscription lifecycle depends
/// on it) whenever a signed-in user's onboarding isn't complete yet.
///
/// Sequences Birthday -> Username -> Display Name -> Password (skipped
/// entirely for an account that signed up with email+password directly,
/// or already completed it in a prior session) -> Profile Optional ->
/// Finish, resuming at [OnboardingState.resumeStep] rather than always
/// starting from Birthday -- closing the app mid-onboarding and coming
/// back must never repeat an already-saved step or create a second
/// account. Each step's own data is written to Supabase as soon as that
/// step is submitted (not held in memory until the very end), which is
/// exactly what makes that resume possible.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({
    super.key,
    required this.authRepository,
    required this.user,
    required this.initialState,
    required this.onCompleted,
    this.profileRepository,
  });

  final AuthRepository authRepository;
  final User user;
  final OnboardingState initialState;

  /// AuthGate re-checks onboarding state and swaps to RootShell once this
  /// fires -- same "rebuild the parent, don't navigate" shape as the old
  /// UsernameSetupScreen.onUsernameSet.
  final VoidCallback onCompleted;

  final ProfileRepository? profileRepository;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  late _LocalStep _step = _localStepFor(widget.initialState.resumeStep);
  late final ProfileRepository _profileRepository =
      widget.profileRepository ?? ProfileRepository(Supabase.instance.client);

  // Captured once at mount -- whether the Password step is needed at all
  // for this account. Doesn't change mid-flow (the only way it *could*
  // become true is by completing the Password step itself, which moves
  // _step past it anyway).
  late final bool _skipPassword = widget.initialState.hasPassword;

  // Carried across steps purely for prefill (Finish's greeting, Profile
  // Optional's avatar fallback initial) -- never re-read from the
  // network mid-flow.
  String? _username;
  String? _displayName;

  bool _isLoading = false;
  String? _errorText;

  int get _stepCount => _skipPassword ? 4 : 5;

  int get _stepIndex => switch (_step) {
        _LocalStep.birthday => 1,
        _LocalStep.username => 2,
        _LocalStep.displayName => 3,
        _LocalStep.password => 4,
        _LocalStep.profileOptional => _skipPassword ? 4 : 5,
        _LocalStep.finish => _skipPassword ? 4 : 5,
      };

  /// Runs a save call with a shared loading/error state, then advances to
  /// [next] on success. Every step but Finish (see [_enterWynos]) goes
  /// through this.
  Future<void> _run(Future<void> Function() action,
      {required _LocalStep next}) async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      await action();
      if (!mounted) return;
      setState(() {
        _step = next;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorText = _messageFor(e);
      });
    }
  }

  Future<void> _enterWynos() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      await widget.authRepository.completeOnboarding(widget.user.id);
      // Deliberately no local setState back to isLoading: false on
      // success -- AuthGate's own setState (triggered by onCompleted)
      // rebuilds it into RootShell shortly, unmounting this whole widget.
      // Keeping the spinner up until then reads as "entering WYNOS", not
      // as a stuck screen.
      widget.onCompleted();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorText = _messageFor(e);
      });
    }
  }

  String _messageFor(Object error) {
    if (error is UsernameTakenException || error is UsernameReservedException) {
      return 'ชื่อผู้ใช้นี้ถูกใช้แล้ว';
    }
    if (error is AuthWeakPasswordException) {
      return 'รหัสผ่านไม่ปลอดภัยพอ ลองใช้รหัสผ่านที่คาดเดายากขึ้น';
    }
    return 'เกิดข้อผิดพลาด ลองใหม่อีกครั้ง';
  }

  void _goBack(_LocalStep target) {
    setState(() {
      _step = target;
      _errorText = null;
    });
  }

  Widget _buildStep() {
    switch (_step) {
      case _LocalStep.birthday:
        return BirthdayStep(
          key: const ValueKey(_LocalStep.birthday),
          stepIndex: _stepIndex,
          stepCount: _stepCount,
          isLoading: _isLoading,
          errorText: _errorText,
          onSubmit: (dateOfBirth) => _run(
            () => widget.authRepository.setDateOfBirth(widget.user.id, dateOfBirth),
            next: _LocalStep.username,
          ),
        );

      case _LocalStep.username:
        return UsernameStep(
          key: const ValueKey(_LocalStep.username),
          stepIndex: _stepIndex,
          stepCount: _stepCount,
          isLoading: _isLoading,
          errorText: _errorText,
          onBack: () => _goBack(_LocalStep.birthday),
          checkAvailability: widget.authRepository.isUsernameAvailable,
          onSubmit: (username) => _run(() async {
            await widget.authRepository.setUsername(widget.user.id, username);
            _username = username;
          }, next: _LocalStep.displayName),
        );

      case _LocalStep.displayName:
        final googleName = widget.user.userMetadata?['full_name'] as String? ??
            widget.user.userMetadata?['name'] as String? ??
            '';
        return DisplayNameStep(
          key: const ValueKey(_LocalStep.displayName),
          stepIndex: _stepIndex,
          stepCount: _stepCount,
          isLoading: _isLoading,
          errorText: _errorText,
          initialValue: googleName,
          onBack: () => _goBack(_LocalStep.username),
          onSubmit: (displayName) => _run(() async {
            await widget.authRepository.setDisplayName(widget.user.id, displayName);
            _displayName = displayName;
          }, next: _skipPassword ? _LocalStep.profileOptional : _LocalStep.password),
        );

      case _LocalStep.password:
        return PasswordStep(
          key: const ValueKey(_LocalStep.password),
          stepIndex: _stepIndex,
          stepCount: _stepCount,
          isLoading: _isLoading,
          errorText: _errorText,
          onBack: () => _goBack(_LocalStep.displayName),
          onSubmit: (password) => _run(
            () => widget.authRepository.setPassword(widget.user.id, password),
            next: _LocalStep.profileOptional,
          ),
        );

      case _LocalStep.profileOptional:
        final googleAvatar = widget.user.userMetadata?['avatar_url'] as String? ??
            widget.user.userMetadata?['picture'] as String?;
        return ProfileOptionalStep(
          key: const ValueKey(_LocalStep.profileOptional),
          stepIndex: _stepIndex,
          stepCount: _stepCount,
          isLoading: _isLoading,
          errorText: _errorText,
          initialAvatarUrl: googleAvatar,
          fallbackAvatarText: _username ?? widget.user.email ?? 'W',
          onBack: () => _goBack(
              _skipPassword ? _LocalStep.displayName : _LocalStep.password),
          uploadAvatar: (bytes, extension) => _profileRepository.uploadAvatar(
            userId: widget.user.id,
            bytes: bytes,
            fileExtension: extension,
          ),
          onContinue: (avatarUrl, bio) => _run(
            () => widget.authRepository
                .saveOptionalProfile(widget.user.id, avatarUrl: avatarUrl, bio: bio),
            next: _LocalStep.finish,
          ),
        );

      case _LocalStep.finish:
        return FinishStep(
          key: const ValueKey(_LocalStep.finish),
          isLoading: _isLoading,
          errorText: _errorText,
          onEnter: _enterWynos,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: onboardingStepTransition,
      child: _buildStep(),
    );
  }
}
