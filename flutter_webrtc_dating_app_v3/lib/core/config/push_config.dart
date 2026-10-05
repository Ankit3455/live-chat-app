// lib/core/config/push_config.dart

/// Push notifications go through the Cloudflare Worker in
/// cloudflare/push-worker (Firebase Spark has no Cloud Functions).
class PushConfig {
  /// Worker URL printed by `wrangler deploy`, without a trailing slash, e.g.
  /// `https://destined-push.<your-subdomain>.workers.dev`.
  /// Empty = the worker is not used and the Cloud Functions callables are
  /// tried instead (they only work on the Blaze plan).
  static const String workerUrl = 'https://destined-push.beanbliss.workers.dev';

  static bool get enabled => workerUrl.isNotEmpty;
}
