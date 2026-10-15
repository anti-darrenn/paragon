// Prints the privacy policy, terms and About text as JSON, for the static
// /privacy/, /terms/ and /about/ pages. `tools/site/build_static_site.js`
// runs it on every build, so those pages cannot drift from the app's:
//
//   dart run tool/export_legal.dart
//
// Imports only pure-Dart files, so it runs without Flutter.
import 'dart:convert';
import 'dart:io';

import 'package:paragon/core/legal/about_content.dart';
import 'package:paragon/core/legal/legal_documents.dart';

Map<String, Object?> _section(LegalSection s) => {
  'heading': s.heading,
  'paragraphs': s.paragraphs,
  'bullets': s.bullets,
};

Map<String, Object?> _document(LegalDocument d) => {
  'title': d.title,
  'intro': d.intro,
  'sections': [for (final s in d.sections) _section(s)],
};

void main() {
  stdout.write(
    jsonEncode({
      'lastUpdated': legalLastUpdated,
      'publisher': publisher,
      'contactEmail': contactEmail,
      'contactEmailCc': contactEmailCc,
      'placeholdersRemain': legalPlaceholdersRemain,
      'privacy': _document(privacyPolicy),
      'terms': _document(termsOfService),
      'about': {
        'sections': [
          for (final s in kAboutSections) _section(s),
          if (aboutThanks case final thanks?) _section(thanks),
        ],
        'contactText': kAboutContactText,
      },
    }),
  );
}
