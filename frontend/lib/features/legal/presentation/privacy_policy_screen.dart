import 'package:flutter/material.dart';

import 'legal_document_screen.dart';
import 'legal_documents.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) => const LegalDocumentScreen(document: privacyPolicyDocument);
}
