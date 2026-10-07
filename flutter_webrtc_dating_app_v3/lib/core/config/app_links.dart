// lib/core/config/app_links.dart

/// Public legal and support links, in one place for Settings, signup and the
/// age gate. Privacy and Terms are static pages in web/ served by Firebase
/// Hosting. FAQ and web account deletion are still placeholders (O-11).
class AppLinks {
  AppLinks._();

  static const String privacyPolicy =
      'https://availchatproject.web.app/privacy.html';
  static const String terms = 'https://availchatproject.web.app/terms.html';

  /// Inbox for "Contact support" and the legal pages. Change it here and in
  /// web/privacy.html + web/terms.html.
  static const String supportEmail = 'test@gmail.com';

  static const String faq = 'https://example.com/destined/faq';
  static const String accountDeletion =
      'https://example.com/destined/delete-account';

  /// True until the owner replaces the placeholder with a real page.
  static bool isPlaceholder(String url) =>
      url.startsWith('https://example.com/');
}
