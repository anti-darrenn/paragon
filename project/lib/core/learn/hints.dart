/// Hints, Khan-style: the worked explanation, one step at a time, before
/// the student answers.
///
/// Both corpora already write explanations as paragraph steps — the
/// generators join steps with a blank line, and the scraped answers were
/// converted from `<p>`s to the same — so a hint is simply the next
/// paragraph. The **last** step is never offered: it is the one that
/// states the answer.
///
/// Where hints are allowed is a product rule, not this file's: drill and
/// lesson exercises offer them; the topic test and the WAEC exam never do
/// (no help in anything exam-like). A right answer after a hint is
/// recorded truthfully but does not count toward mastery or a first-try
/// score — that is what keeps hints from being a way to farm levels.
library;

/// The steps of [explanation] that may be shown as hints, in order.
///
/// Empty when there are fewer than two steps: a one-step explanation is
/// the answer, and hinting it would give the question away.
List<String> hintSteps(String explanation) {
  final steps = explanation
      .replaceAll('\r', '')
      .split(RegExp(r'\n[ \t]*\n'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  if (steps.length < 2) return const [];
  return steps.sublist(0, steps.length - 1);
}
