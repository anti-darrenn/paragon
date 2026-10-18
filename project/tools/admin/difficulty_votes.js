/**
 * Students' "how hard was this?" ratings, added up. Pure, no Firestore:
 * `jobs.js --job=difficulty` reads `difficultyVotes` documents, calls
 * `tally`, and adds the result into each question's `crowdDifficulty`
 * with increments. `difficulty_votes.test.js` pins it.
 *
 * The app blends the tally with Paragon's estimate (`blendTier` in
 * lib/core/questions/difficulty.dart), so the estimate stays the baseline.
 */

/**
 * docs: [{userId, votes: {questionId: level}}], oldest first.
 * Returns Map questionId -> {n, sum}. A rating outside 1–5, or not a whole
 * number, is ignored; one student counts once per question in a run (their
 * latest rating).
 */
function tally(docs) {
  const latest = new Map(); // `${userId}|${questionId}` -> level
  for (const d of docs) {
    const votes = d && typeof d.votes === "object" && d.votes ? d.votes : {};
    for (const [qid, level] of Object.entries(votes)) {
      if (!qid || !Number.isInteger(level) || level < 1 || level > 5) continue;
      latest.set(`${d.userId}|${qid}`, level);
    }
  }
  const out = new Map();
  for (const [key, level] of latest) {
    const qid = key.slice(key.indexOf("|") + 1);
    const t = out.get(qid) || { n: 0, sum: 0 };
    t.n += 1;
    t.sum += level;
    out.set(qid, t);
  }
  return out;
}

/**
 * The oldest documents to process in one run, stopping before the
 * questions they touch pass [maxQuestions] — each touched question is one
 * write on the free plan's 20,000. A document is always taken whole.
 */
function takeWithin(docs, maxQuestions) {
  const seen = new Set();
  const taken = [];
  for (const d of docs) {
    const qids = Object.keys((d && d.votes) || {});
    const fresh = qids.filter((q) => !seen.has(q));
    if (taken.length && seen.size + fresh.length > maxQuestions) break;
    fresh.forEach((q) => seen.add(q));
    taken.push(d);
  }
  return taken;
}

module.exports = { tally, takeWithin };
