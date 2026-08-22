import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Vela/core/providers/settings_providers.dart';
import 'package:Vela/features/auth/presentation/auth_controller.dart';
import 'package:Vela/features/auth/presentation/auth_state.dart';
import 'package:Vela/features/statements/domain/statement.dart';
import 'package:Vela/features/statements/presentation/period_providers.dart';
import 'package:Vela/main.dart';

/// Resolves immediately to unauthenticated instead of hitting TokenStorage
/// (flutter_secure_storage's platform channel isn't backed by anything
/// under `flutter test`) and the real backend.
class _FakeAuthController extends AuthController {
  @override
  Future<AuthState> build() async => const AuthState.unauthenticated();
}

void main() {
  // google_fonts otherwise attempts a real HTTP fetch for missing font
  // assets, which leaves a background Timer running past test teardown.
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('VelaApp boots to the splash screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authControllerProvider.overrideWith(_FakeAuthController.new),
          // The router's refresh listener taps this provider unconditionally
          // (see app_router.dart's _RouterRefreshNotifier), so it must be
          // stubbed too or it fires a real Dio request with no backend to
          // answer it - leaving a pending connectTimeout Timer at teardown.
          periodsProvider.overrideWith((ref) async => const <Statement>[]),
        ],
        child: const VelaApp(),
      ),
    );

    // The auth check is in flight for this first frame, so the app should
    // render the splash/loading screen rather than crash.
    expect(find.text('Vela'), findsOneWidget);
  });
}
