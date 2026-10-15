/// The few facts the About and Support pages print, in one place so the
/// owner can change them without touching a screen (launch plan phase 4).
library;

/// Where a donation would go. **Null hides the donate button** everywhere;
/// the owner adds the details when there is somewhere honest to send them.
const String? donateUrl = null;

/// People thanked on About. The owner confirms each line with the person
/// before it ships; an empty list hides the section.
const List<({String name, String forWhat})> kAcknowledgements = [
  (name: 'Acacia', forWhat: 'ideas that shaped this release'),
  (name: 'Anjola', forWhat: 'support and feedback along the way'),
];

/// For schools, tutors and partners. Plain text as well as `mailto:`.
const String partnerSubject = 'Paragon for schools';
