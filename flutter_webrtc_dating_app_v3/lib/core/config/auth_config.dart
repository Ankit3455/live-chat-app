// lib/core/config/auth_config.dart

/// Sign-up switches.
class AuthConfig {
  /// Email sign-ups must verify their address before onboarding. Off while
  /// test accounts are created in bulk; set back to true before launch.
  /// When off, no verification email is sent and accounts created while it
  /// was on are not held at the verify screen either.
  static const bool requireEmailVerification = false;
}
