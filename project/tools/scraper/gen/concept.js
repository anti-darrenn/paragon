// Helpers for concept-driven (non-numeric) topics.
// The WAEC "I. II. III." list style embeds the statements in the question TEXT,
// so the wording varies with the statements chosen - this is what gives these
// topics a large enough unique-question space.

const { randInt, pick, shuffle, sample, textOptions } = require('./lib');

const ROMAN = ['I', 'II', 'III'];

// exactly one of the three listed statements is correct
function oneCorrectOfThree(subject, trues, falses) {
  return () => {
    if (trues.length < 1 || falses.length < 2) return null;
    const t = pick(trues);
    const f = sample(falses, 2);
    const items = shuffle([{ s: t, ok: true }, { s: f[0], ok: false }, { s: f[1], ok: false }]);
    const idx = items.findIndex(i => i.ok);
    const correct = `${ROMAN[idx]} only`;
    const others = ROMAN.filter((_, i) => i !== idx).map(r => `${r} only`);
    const o = textOptions(correct, [others[0], others[1], 'I, II and III']);
    if (!o) return null;
    return {
      text: `Which of the following statements about ${subject} is correct? ${items.map((it, i) => `${ROMAN[i]}. ${it.s}`).join(' ')}`,
      ...o,
      explanation: `${t} — this is correct.\n\nThe other two statements are not true: "${f[0]}" and "${f[1]}" both misstate the physics.\n\nSo only ${ROMAN[idx]} is correct.`,
    };
  };
}

// exactly one of the three listed statements is wrong
function oneWrongOfThree(subject, trues, falses) {
  return () => {
    if (trues.length < 2 || falses.length < 1) return null;
    const f = pick(falses);
    const t = sample(trues, 2);
    const items = shuffle([{ s: f, ok: false }, { s: t[0], ok: true }, { s: t[1], ok: true }]);
    const idx = items.findIndex(i => !i.ok);
    const correct = `${ROMAN[idx]} only`;
    const others = ROMAN.filter((_, i) => i !== idx).map(r => `${r} only`);
    const o = textOptions(correct, [others[0], others[1], 'I, II and III']);
    if (!o) return null;
    return {
      text: `Which of the following statements about ${subject} is NOT correct? ${items.map((it, i) => `${ROMAN[i]}. ${it.s}`).join(' ')}`,
      ...o,
      explanation: `"${f}" is the incorrect statement.\n\nThe other two are true statements about ${subject}.\n\nSo ${ROMAN[idx]} is the one that is not correct.`,
    };
  };
}

// two of the three listed statements are correct
function twoCorrectOfThree(subject, trues, falses) {
  return () => {
    if (trues.length < 2 || falses.length < 1) return null;
    const t = sample(trues, 2);
    const f = pick(falses);
    const items = shuffle([{ s: t[0], ok: true }, { s: t[1], ok: true }, { s: f, ok: false }]);
    const good = items.map((it, i) => it.ok ? ROMAN[i] : null).filter(Boolean);
    const correct = `${good.join(' and ')} only`;
    const bad = items.findIndex(i => !i.ok);
    const o = textOptions(correct, [
      `${ROMAN[bad]} only`,
      `${good[0]} only`,
      'I, II and III',
    ]);
    if (!o) return null;
    return {
      text: `Which of the following statements about ${subject} are correct? ${items.map((it, i) => `${ROMAN[i]}. ${it.s}`).join(' ')}`,
      ...o,
      explanation: `${good.join(' and ')} are correct statements.\n\n"${f}" is false, so ${ROMAN[bad]} must be excluded.\n\nThe answer is ${correct}.`,
    };
  };
}

// direct question/answer bank: each entry has its own unique wording
function qaBank(items) {
  return () => {
    const it = pick(items);
    const o = textOptions(it.a, it.w);
    if (!o) return null;
    return { text: it.q, ...o, explanation: it.e };
  };
}

// builds the standard concept generator set for a topic
function conceptGens(subject, trues, falses, bank = []) {
  const gens = [
    oneCorrectOfThree(subject, trues, falses),
    oneWrongOfThree(subject, trues, falses),
    twoCorrectOfThree(subject, trues, falses),
  ];
  if (bank.length) gens.push(qaBank(bank));
  return gens;
}

module.exports = { conceptGens, oneCorrectOfThree, oneWrongOfThree, twoCorrectOfThree, qaBank, ROMAN };
