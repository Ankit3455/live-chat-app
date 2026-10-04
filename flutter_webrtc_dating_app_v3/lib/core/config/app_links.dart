// lib/core/config/app_links.dart

/// Public legal and support URLs, in one place for Settings, signup and the
/// age gate. Placeholders: the owner must publish these pages and replace the
/// values before release (O-11). Play also requires the web deletion page.
class AppLinks {
  AppLinks._();

  static const String privacyPolicy = 'https://example.com/destined/privacy';
  static const String terms = 'https://example.com/destined/terms';
  static const String support = 'https://example.com/destined/support';
  static const String faq = 'https://example.com/destined/faq';
  static const String accountDeletion =
      'https://example.com/destined/delete-account';

  /// True until the owner replaces the placeholder with a real page.
  static bool isPlaceholder(String url) =>
      url.startsWith('https://example.com/');
}
