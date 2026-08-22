import 'package:flutter/material.dart';

import 'legal_document_screen.dart';
import 'legal_documents.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) => const LegalDocumentScreen(document: termsOfServiceDocument);
}
