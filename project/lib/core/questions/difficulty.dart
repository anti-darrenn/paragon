/// How hard a question is, from "Easy peasy" to "Unnecessarily hard"
/// (owner's decision, 2026-10-17).
///
/// Most questions carry no stored difficulty, so it is **estimated** here
/// from the question itself: how much maths it holds and of what kind
/// (fractions, negative or fractional powers, roots, logs, calculus,
/// matrices), whether an unknown has to be solved for, how long the stem
/// is, and whether it needs a diagram. A reviewer can set a question's tier
/// by hand in the studio (`questions.difficulty`, 1–5), and that always wins.
///
/// Pure: no Flutter, no Firestore. `difficulty_test.dart` pins the tiers on
/// real questions and checks the whole bank spreads across all five.
library;

enum DifficultyTier {
  easyPeasy(1, 'Easy peasy', 'One quick step. You have got this.'),
  warmingUp(2, 'Warming up', 'A couple of moves. Stretch those brain muscles.'),
  brainStretch(3, 'Brain stretch', 'A few steps. Take your time.'),
  spicy(4, 'Spicy', 'Proper exam-hard. Bring snacks.'),
  unnecessarilyHard(
    5,
    'Unnecessarily hard',
    'Harder than it needs to be. Respect if you get it.',
  );

  const DifficultyTier(this.level, this.label, this.blurb);

  /// 1 (easiest) to 5, as stored in `questions.difficulty`.
  final int level;
  final String label;
  final String blurb;

  static DifficultyTier? fromLevel(int? level) => level == null
      ? null
      : DifficultyTier.values.where((t) => t.level == level).firstOrNull;
}

/// Score boundaries between tiers, set from the whole bank (64,800
/// practice and 4,206 past questions, 2026-10-17) so each tier holds a
/// sensible share; `difficulty_test.dart` fails if the bank stops
/// spreading across all five.
const _thresholds = [0.4, 1.6, 2.95, 4.6];

final _math = RegExp(
  r'\\\((.*?)\\\)|\\\[(.*?)\\\]|\$\$(.*?)\$\$',
  dotAll: true,
);

/// The estimate's raw score: higher is harder. Exposed for tests and the
/// studio, which shows why a question landed where it did.
double difficultyScore(
  String text,
  List<String> options, {
  bool hasDiagram = false,
}) {
  final maths = _math
      .allMatches(text)
      .map((m) => m.group(1) ?? m.group(2) ?? m.group(3) ?? '')
      .join(' ');
  final prose = text.replaceAll(_math, ' ').toLowerCase();
  final all = '$maths ${options.join(' ')}';
  double s = 0;
  int count(Pattern p, String in_) => p.allMatches(in_).length;

  // The amount of maths: operators and relations, in maths and in plain
  // text alike (older past questions type "2x^2 + x - 6" without \( \)).
  s +=
      0.35 *
      count(
        RegExp(
          r'(?<=[\w)}\s])[+\-=<>×÷](?=[\s\w(\\])|\\times|\\div|\\cdot|\\le|\\ge|\\neq',
        ),
        '$maths $prose',
      );
  s += 0.5 * count(RegExp(r'[a-z0-9)]\^[({]?[0-9a-z-]'), prose);
  // Numbers to juggle: each distinct value beyond the first two.
  final numbers = RegExp(
    r'\d+(?:\.\d+)?',
  ).allMatches(text).map((m) => m.group(0)).toSet();
  if (numbers.length > 2) s += 0.15 * (numbers.length - 2).clamp(0, 8);
  // Physical quantities with units mean a formula to choose and apply.
  s +=
      0.2 *
      count(
        RegExp(r'\\mathrm\{|\b(?:m/s|ms-1|kg|cm|mm|km|N|J|W|V|Hz|°C)\b'),
        text,
      ).clamp(0, 3);
  // Word problems: the maths has to be set up from the story first.
  if (RegExp(
    r'\b(twice|thrice|how many|probability|ratio|respectively|remaining|years? (?:old|time|ago))\b',
  ).hasMatch(prose)) {
    s += 0.9;
  }
  // Statement questions (I, II, III) need each one weighed.
  if (RegExp(
        r'\b(i{1,3}|iv)\b[.)]?\s',
        caseSensitive: false,
      ).allMatches(text).length >=
      2) {
    s += 1.0;
  }
  // What kind of maths.
  s += 0.8 * count(r'\frac', maths);
  s += 0.5 * count(RegExp(r'\^\{?[0-9a-z]'), maths);
  s += 1.4 * count(RegExp(r'\^\{-|\^\{\\frac|\^\{[0-9]+/'), maths);
  s += 1.0 * count(r'\sqrt', maths);
  s += 1.4 * count(RegExp(r'\\log|\\ln\b'), maths);
  s += 1.0 * count(RegExp(r'\\(sin|cos|tan|sec|cosec|cot)\b'), maths);
  s += 2.5 * count(RegExp(r'\\int|\\sum|\\lim|\\frac\{d'), maths);
  s += 2.0 * count(RegExp(r'\\begin\{[pbvBV]?matrix\}'), maths);
  // Unknowns: one is normal; several mean simultaneous or multi-variable work.
  final letters = RegExp(
    r'(?<![\\a-zA-Z])[a-zA-Z](?![a-zA-Z])',
  ).allMatches(maths).map((m) => m.group(0)).toSet()..removeAll(['d', 'e']);
  if (letters.length >= 2) s += 0.6 * (letters.length - 1);
  // What the stem asks for.
  if (RegExp(
    r'\b(solve|find the value|find the values|find \S+ if|if .* find)\b',
  ).hasMatch(prose)) {
    s += 0.8;
  }
  if (RegExp(
    r'\b(simultaneous|hence|show that|prove|deduce|maximum|minimum|range of values|roots of)\b',
  ).hasMatch(prose)) {
    s += 1.6;
  }
  if (RegExp(
        r'\b(simplify|evaluate|express|convert|correct to)\b',
      ).hasMatch(prose) &&
      maths.length < 30) {
    s -= 0.4;
  }
  // Long stems carry more to read and hold in mind.
  final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  if (words > 30) s += 0.8;
  if (words > 60) s += 1.0;
  if (hasDiagram) s += 1.0;
  // Answers that are expressions, not numbers, ask for more working.
  // ("I and II only" is a choice of statements, not algebra.)
  bool algebraic(String o) {
    final t = o.replaceAll(RegExp(r'\\[a-zA-Z]+'), '');
    if (RegExp(
      r'^[\sIV,]*(and|only|,|\s)*[\sIV,]*$|\b(I{1,3}|IV)\b',
    ).hasMatch(t)) {
      return false;
    }
    // An expression has a variable: a letter standing alone ("2x + y"),
    // not a word ("density", "boiling point").
    return RegExp(r'(?<![a-zA-Z])[a-z](?![a-zA-Z])').hasMatch(t);
  }

  if (options.isNotEmpty &&
      options.where(algebraic).length >= options.length - 1) {
    s += 0.6;
  }
  if (count(r'\frac', all) > 4) s += 0.4;
  return s < 0 ? 0 : s;
}

/// The estimated tier for a question's text and options.
DifficultyTier estimateDifficulty(
  String text,
  List<String> options, {
  bool hasDiagram = false,
}) {
  final s = difficultyScore(text, options, hasDiagram: hasDiagram);
  var i = 0;
  while (i < _thresholds.length && s >= _thresholds[i]) {
    i++;
  }
  return DifficultyTier.values[i];
}
