import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:velar/features/auth/presentation/login_screen.dart';

import '../../support/fake_secure_storage_platform.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  setUp(() {
    FlutterSecureStoragePlatform.instance = FakeSecureStoragePlatform();
  });

  Future<void> pumpLogin(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: LoginScreen()),
      ),
    );
    // Let AuthController.build()'s hasSession() check settle before asserting
    // on the form - it's what the FakeSecureStoragePlatform above unblocks.
    await tester.pumpAndSettle();
  }

  // A field's client-side validator only runs (and shows its error text)
  // once the Form has been submitted at least once - Flutter's default
  // AutovalidateMode is `disabled`.
  Future<void> tapSignIn(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in').hitTestable());
    await tester.pumpAndSettle();
  }

  testWidgets('rejects an empty email', (tester) async {
    await pumpLogin(tester);

    await tester.enterText(find.byType(TextFormField).first, '');
    await tester.enterText(find.byType(TextFormField).last, 'TestPass123!');
    await tapSignIn(tester);

    expect(find.text('Enter your email'), findsOneWidget);
  });

  testWidgets('rejects an email missing an @', (tester) async {
    await pumpLogin(tester);

    await tester.enterText(find.byType(TextFormField).first, 'not-an-email');
    await tester.enterText(find.byType(TextFormField).last, 'TestPass123!');
    await tapSignIn(tester);

    expect(find.text('Enter a valid email'), findsOneWidget);
  });

  testWidgets('rejects an empty password', (tester) async {
    await pumpLogin(tester);

    await tester.enterText(find.byType(TextFormField).first, 'test@velar.dev');
    await tester.enterText(find.byType(TextFormField).last, '');
    await tapSignIn(tester);

    expect(find.text('Enter your password'), findsOneWidget);
  });

  testWidgets('never reaches the loading state for an invalid form', (tester) async {
    // _submit() returns immediately when validate() fails, before touching
    // authControllerProvider - the real ApiClient behind the screen has no
    // fake adapter here, so a login attempt reaching the network would hang
    // pumpAndSettle on a live socket instead of the app itself timing out.
    await pumpLogin(tester);

    await tester.enterText(find.byType(TextFormField).first, '');
    await tester.enterText(find.byType(TextFormField).last, '');
    await tapSignIn(tester);

    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
