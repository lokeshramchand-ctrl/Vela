import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:velar/features/auth/presentation/register_screen.dart';

import '../../support/fake_secure_storage_platform.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  setUp(() {
    FlutterSecureStoragePlatform.instance = FakeSecureStoragePlatform();
  });

  Future<void> pumpRegister(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: RegisterScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapCreateAccount(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create account').hitTestable());
    await tester.pumpAndSettle();
  }

  final fields = find.byType(TextFormField); // [0] email, [1] password, [2] confirm

  testWidgets('rejects a password under 8 characters', (tester) async {
    await pumpRegister(tester);

    await tester.enterText(fields.at(0), 'test@velar.dev');
    await tester.enterText(fields.at(1), 'short1');
    await tester.enterText(fields.at(2), 'short1');
    await tapCreateAccount(tester);

    expect(find.text('Use at least 8 characters'), findsOneWidget);
  });

  testWidgets('rejects a password over 128 characters', (tester) async {
    await pumpRegister(tester);
    final tooLong = 'a' * 129;

    await tester.enterText(fields.at(0), 'test@velar.dev');
    await tester.enterText(fields.at(1), tooLong);
    await tester.enterText(fields.at(2), tooLong);
    await tapCreateAccount(tester);

    expect(find.text('Password is too long'), findsOneWidget);
  });

  testWidgets('rejects a confirm-password mismatch', (tester) async {
    await pumpRegister(tester);

    await tester.enterText(fields.at(0), 'test@velar.dev');
    await tester.enterText(fields.at(1), 'TestPass123!');
    await tester.enterText(fields.at(2), 'DoesNotMatch1');
    await tapCreateAccount(tester);

    expect(find.text("Passwords don't match"), findsOneWidget);
  });

  testWidgets('rejects an invalid email', (tester) async {
    await pumpRegister(tester);

    await tester.enterText(fields.at(0), 'not-an-email');
    await tester.enterText(fields.at(1), 'TestPass123!');
    await tester.enterText(fields.at(2), 'TestPass123!');
    await tapCreateAccount(tester);

    expect(find.text('Enter a valid email'), findsOneWidget);
  });
}
