import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/legal/legal_documents.dart';

/// The publisher and contact details, and the guard that warns while they
/// are unfilled.
///
/// That guard used to scan the rendered text for the literal placeholder
/// strings. It worked only while the values *were* placeholders: filling
/// them in turned the check inside out, because every paragraph naming the
/// publisher then matched, and the warning would have shown permanently on
/// a document with nothing left to fill. It now asks the values
/// themselves, which is why both directions are pinned below.
void main() {
  Iterable<String> allText(LegalDocument doc) sync* {
    for (final section in doc.sections) {
      yield* section.paragraphs;
      yield* section.bullets;
    }
  }

  group('contact details', () {
    test('both documents name a real address, not a placeholder', () {
      for (final doc in [privacyPolicy, termsOfService]) {
        final text = allText(doc).join(' ');
        expect(text, contains(contactEmail), reason: doc.title);
        expect(
          text.contains(unconfirmedMarker),
          isFalse,
          reason: '${doc.title} still carries an unfilled placeholder',
        );
      }
    });

    test('the contact section names the copied address too', () {
      // Inline mentions give one address to write to; the contact section
      // is where the cc is stated, so a request cannot be lost if the
      // primary inbox is missed.
      for (final doc in [privacyPolicy, termsOfService]) {
        final contact = doc.sections.where((s) => s.heading == 'Contact');
        expect(contact, isNotEmpty, reason: '${doc.title} has no Contact');
        expect(contact.first.paragraphs.join(' '), contains(contactEmailCc));
      }
    });

    test('the two addresses are different', () {
      // A copy to the same inbox is not a copy.
      expect(contactEmail, isNot(contactEmailCc));
    });

    test('the privacy policy names who operates Paragon', () {
      expect(allText(privacyPolicy).join(' '), contains(publisher));
    });
  });

  group('legalPlaceholdersRemain', () {
    test('is false now that the details are filled in', () {
      expect(legalPlaceholdersRemain, isFalse);
    });

    test('the marker it looks for is not in any real value', () {
      // The control. If a real value happened to contain the marker text,
      // the warning would show forever; if the marker were empty or
      // absent, it would never show. Both are silent failures.
      expect(unconfirmedMarker, isNotEmpty);
      for (final value in [publisher, contactEmail, contactEmailCc]) {
        expect(value.contains(unconfirmedMarker), isFalse, reason: value);
      }
      expect(
        '[SOMETHING — $unconfirmedMarker]'.contains(unconfirmedMarker),
        isTrue,
      );
    });
  });
}
