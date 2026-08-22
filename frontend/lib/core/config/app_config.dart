/// Runtime config, supplied via --dart-define (see frontend/README.md).
///
/// VELAR_API_KEY has no client-facing issuance endpoint (see
/// docs/API_REFERENCE.md §0) - it's a static value the app ships/configures
/// with, the same way the backend operator holds it.
abstract final class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'VELAR_API_BASE_URL',
    // Verified 2026-08-13: the deployed host only serves /auth/*, /memory/*,
    // and health/metrics - /users/me, /statements, /jobs, /analytics/* etc.
    // all 404 there (stale build; redeploy is a Coolify action outside this
    // repo, see docs/14-deployment-operations.md). Login/register work
    // end-to-end; every screen past login does not. Override with
    // --dart-define=VELAR_API_BASE_URL=http://localhost:9850/ to develop
    // against a backend that has the full route set.
    defaultValue: 'https://velar.deploy.lokeshrc.me/',
  );

  static const String apiKey = String.fromEnvironment(
    'VELAR_API_KEY',
    defaultValue:
        'velar_test_key_123', // or remove if you don't want a fallback
  );

  /// Pre-fills the login form with a seeded local test account
  /// (test@velar.dev) so sign-in during development is one tap. Debug-only:
  /// kDebugMode is compiled out of release builds, so this never ships.
  static const String devEmail = 'test@velar.dev';
  static const String devPassword = 'TestPass123!';
}
