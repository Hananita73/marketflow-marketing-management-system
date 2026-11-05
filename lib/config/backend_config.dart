// ─────────────────────────────────────────────────────────────────────────────
// BackendConfig
//
// Connection settings for the MarkFlow backend (backend/), the small Express
// service that turns reported events into admin notification emails.
//
// HOW TO CONFIGURE:
//   Default values work for local development (`npm start` in backend/).
//   Override at build/run time with dart-define:
//
//     flutter run \
//       --dart-define=MARKFLOW_BACKEND_URL=https://api.example.com \
//       --dart-define=MARKFLOW_ALERT_TOKEN=<ALERTS_API_TOKEN>
//
// SECURITY NOTE: ALERTS_API_TOKEN is embedded in the client by design, so it
// is a *scoped* token — it can only trigger pre-templated alert emails to the
// admin mailbox (rate limited), it cannot send arbitrary mail. That is why it
// is separate from ADMIN_API_TOKEN, which must only ever live on the server.
// Change the token for anything beyond local development.
// ─────────────────────────────────────────────────────────────────────────────

class BackendConfig {
  BackendConfig._();

  /// Base URL of the Express backend.
  static const String url = String.fromEnvironment(
    'MARKFLOW_BACKEND_URL',
    defaultValue: 'http://localhost:8080',
  );

  /// Must match ALERTS_API_TOKEN on the server. When empty, event reporting
  /// is disabled and [AdminAlertService] silently does nothing.
  static const String alertToken = String.fromEnvironment(
    'MARKFLOW_ALERT_TOKEN',
    defaultValue: 'markflow-dev-alerts-token',
  );

  /// [url] without a trailing slash, safe to join paths onto.
  static String get normalizedUrl =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  /// True when the app is able to report events at all.
  static bool get alertsConfigured =>
      normalizedUrl.isNotEmpty && alertToken.isNotEmpty;
}
