import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:Vela/features/legal/presentation/legal_document_screen.dart';
import 'package:Vela/features/legal/presentation/legal_documents.dart';
import 'package:Vela/features/legal/presentation/privacy_policy_screen.dart';
import 'package:Vela/features/legal/presentation/terms_of_service_screen.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  group('legal document content', () {
    test('Privacy Policy names the developer, contact, and has every expected section', () {
      expect(privacyPolicyDocument.title, 'Privacy Policy');
      expect(privacyPolicyDocument.intro, contains('draft'));
      final headings = privacyPolicyDocument.sections.map((s) => s.heading);
      expect(
        headings,
        containsAll(<String>[
          'Who this is',
          'What data we collect',
          'How your data is processed',
          'Data retention and deletion',
          'Security',
          'Your rights',
        ]),
      );
      final whoThisIs = privacyPolicyDocument.sections.firstWhere((s) => s.heading == 'Who this is');
      expect(whoThisIs.body, contains('Lokesh Ram Chand'));
      expect(whoThisIs.body, contains('lokeshramchand@gmail'));
    });

    test('Terms of Service has every expected section', () {
      expect(termsOfServiceDocument.title, 'Terms of Service');
      final headings = termsOfServiceDocument.sections.map((s) => s.heading);
      expect(
        headings,
        containsAll(<String>[
          'Who this is',
          "What Vela is (and isn't)",
          'Your account',
          'Acceptable use',
          'Disclaimer and liability',
          'Governing law',
        ]),
      );
    });
  });

  group('rendering', () {
    testWidgets('PrivacyPolicyScreen renders the title and first section without scrolling', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PrivacyPolicyScreen()));

      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.textContaining(privacyPolicyDocument.lastUpdated), findsOneWidget);
      expect(find.text(privacyPolicyDocument.sections.first.heading), findsOneWidget);
    });

    testWidgets('TermsOfServiceScreen renders the title', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: TermsOfServiceScreen()));

      expect(find.text('Terms of Service'), findsOneWidget);
    });

    testWidgets('scrolls to the last section with no render errors', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PrivacyPolicyScreen()));

      // Drag the list up repeatedly - a plain fixed-step scroll, rather than
      // scrollUntilVisible's per-target element lookups, which proved flaky
      // against this ListView across CI/local runs.
      for (var i = 0; i < 15; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(find.text(privacyPolicyDocument.sections.last.heading), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('LegalDocumentScreen renders a minimal document with no sections', (tester) async {
      const empty = LegalDocument(title: 'Empty', lastUpdated: '2026-01-01', intro: 'intro text', sections: []);
      await tester.pumpWidget(const MaterialApp(home: LegalDocumentScreen(document: empty)));

      expect(find.text('Empty'), findsOneWidget);
      expect(find.text('intro text'), findsOneWidget);
    });
  });
}
