/// The few facts the About and Support pages print, in one place so the
/// owner can change them without touching a screen (launch plan phase 4).
library;

/// The donate card on `/support`, laid out like Khan Academy's: one-time or
/// monthly, a few amounts and "Other". Each choice opens a payment page
/// the owner made at the payment provider (Paystack), where the donor pays;
/// Paragon never sees card details. See LAUNCH_CHECKLIST.md, "Donations".
///
/// **Leave a link null and that choice is hidden.** With every link null
/// the card disappears, which is how it ships.
const DonateLinks kDonateLinks = DonateLinks(
  oneTime: [
    (amount: 1000, url: null),
    (amount: 2500, url: null),
    (amount: 5000, url: null),
    (amount: 10000, url: null),
  ],
  // A page where the donor types the amount.
  oneTimeOther: null,
  monthly: [
    (amount: 1000, url: null),
    (amount: 2500, url: null),
    (amount: 5000, url: null),
  ],
);

typedef DonateTier = ({int amount, String? url});

class DonateLinks {
  const DonateLinks({
    required this.oneTime,
    required this.oneTimeOther,
    required this.monthly,
  });

  final List<DonateTier> oneTime;
  final String? oneTimeOther;
  final List<DonateTier> monthly;

  /// Only the tiers that have a page to open.
  List<DonateTier> tiers({required bool monthly}) => [
    for (final t in monthly ? this.monthly : oneTime)
      if (t.url != null) t,
  ];

  bool get hasOneTime =>
      tiers(monthly: false).isNotEmpty || oneTimeOther != null;
  bool get hasMonthly => tiers(monthly: true).isNotEmpty;
  bool get isEmpty => !hasOneTime && !hasMonthly;
}

/// ₦2500 → "₦2,500".
String formatNaira(int amount) {
  final digits = amount.toString();
  final out = StringBuffer('₦');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

/// People thanked on About. The owner confirms each line with the person
/// before it ships; an empty list hides the section.
const List<({String name, String forWhat})> kAcknowledgements = [
  (name: 'Acacia', forWhat: 'ideas that shaped this release'),
  (name: 'Anjola', forWhat: 'support and feedback along the way'),
];

/// For schools, tutors and partners. Plain text as well as `mailto:`.
const String partnerSubject = 'Paragon for schools';
