// Further Mathematics > Pure Mathematics (part A)
const L = require('./lib');
const { randInt, pick, shuffle, sample, nonZero, gcd, frac, fracTex, fracOpt,
        fmtNum, buildOptions, textOptions, round } = L;

const U_PURE = 'XeO4je16v5S8YFrJeG7y';
const mathOpt = (s) => `\\(${s}\\)`;

function fact(n) { let r = 1; for (let i = 2; i <= n; i++) r *= i; return r; }
function nCr(n, r) { if (r < 0 || r > n) return 0; let x = 1; for (let i = 0; i < r; i++) x = x * (n - i) / (i + 1); return Math.round(x); }
function nPr(n, r) { if (r < 0 || r > n) return 0; let x = 1; for (let i = 0; i < r; i++) x *= (n - i); return x; }

function polyTex(terms, v = 'x') {
  const t = terms.filter(([c]) => c !== 0);
  if (t.length === 0) return '0';
  let s = '';
  t.forEach(([c, p], i) => {
    const mag = Math.abs(c);
    let body = p === 0 ? String(mag) : p === 1 ? (mag === 1 ? v : `${mag}${v}`) : (mag === 1 ? `${v}^{${p}}` : `${mag}${v}^{${p}}`);
    if (i === 0) s += (c < 0 ? '-' : '') + body;
    else s += (c < 0 ? ' - ' : ' + ') + body;
  });
  return s;
}
const brk = (p, v = 'x') => p >= 0 ? `(${v} + ${p})` : `(${v} - ${-p})`;

// ======================= SETS AND VENN DIAGRAMS =======================
const setsVenn = [
  // three-set inclusion-exclusion
  () => {
    const abc = randInt(2, 8);
    const ab = abc + randInt(1, 8), ac = abc + randInt(1, 8), bc = abc + randInt(1, 8);
    const a = ab + ac - abc + randInt(2, 12), b = ab + bc - abc + randInt(2, 12), c = ac + bc - abc + randInt(2, 12);
    const union = a + b + c - ab - ac - bc + abc;
    const o = buildOptions(union, [a + b + c, a + b + c - ab - ac - bc, union + abc, union - abc], (v) => String(v));
    if (!o) return null;
    return {
      text: `Given \\(n(A) = ${a}\\), \\(n(B) = ${b}\\), \\(n(C) = ${c}\\), \\(n(A \\cap B) = ${ab}\\), \\(n(A \\cap C) = ${ac}\\), \\(n(B \\cap C) = ${bc}\\) and \\(n(A \\cap B \\cap C) = ${abc}\\), find \\(n(A \\cup B \\cup C)\\).`,
      ...o,
      explanation: `\\(n(A \\cup B \\cup C) = n(A) + n(B) + n(C) - n(A \\cap B) - n(A \\cap C) - n(B \\cap C) + n(A \\cap B \\cap C)\\)\n\n\\(= ${a} + ${b} + ${c} - ${ab} - ${ac} - ${bc} + ${abc}\\)\n\n\\(= ${union}\\)`,
    };
  },
  // three-set word problem: only one subject
  () => {
    const abc = randInt(2, 6);
    const abOnly = randInt(2, 9), acOnly = randInt(2, 9), bcOnly = randInt(2, 9);
    const aOnly = randInt(5, 20), bOnly = randInt(5, 20), cOnly = randInt(5, 20);
    const a = aOnly + abOnly + acOnly + abc;
    const total = aOnly + bOnly + cOnly + abOnly + acOnly + bcOnly + abc;
    const o = buildOptions(aOnly, [a, a - abc, aOnly + abc, total - a], (v) => String(v));
    if (!o) return null;
    return {
      text: `In a survey of ${total} students, ${a} offer Physics, ${abOnly + abc} offer both Physics and Chemistry, ${acOnly + abc} offer both Physics and Biology, and ${abc} offer all three subjects. How many offer Physics only?`,
      ...o,
      explanation: `Physics only \\(= n(P) - n(P \\cap C) - n(P \\cap B) + n(P \\cap C \\cap B)\\)\n\n\\(= ${a} - ${abOnly + abc} - ${acOnly + abc} + ${abc}\\)\n\n\\(= ${aOnly}\\)`,
    };
  },
  // De Morgan's law
  () => {
    const forms = [
      { q: '(A \\cup B)\'', a: 'A\' \\cap B\'', w: ['A\' \\cup B\'', 'A \\cap B', '(A \\cap B)\''] },
      { q: '(A \\cap B)\'', a: 'A\' \\cup B\'', w: ['A\' \\cap B\'', 'A \\cup B', '(A \\cup B)\''] },
    ];
    const f = pick(forms);
    const o = textOptions(mathOpt(f.a), f.w.map(mathOpt));
    if (!o) return null;
    return {
      text: `Simplify \\(${f.q}\\) using De Morgan's laws.`,
      ...o,
      explanation: `De Morgan's laws state that \\((A \\cup B)' = A' \\cap B'\\) and \\((A \\cap B)' = A' \\cup B'\\).\n\nSo \\(${f.q} = ${f.a}\\).`,
    };
  },
  // number of elements in a power set
  () => {
    const n = randInt(3, 12);
    const correct = Math.pow(2, n);
    const o = buildOptions(correct, [2 * n, correct - 1, n * n, Math.pow(2, n - 1)], (v) => String(v));
    if (!o) return null;
    return {
      text: `If a set \\(A\\) has ${n} elements, how many elements does its power set have?`,
      ...o,
      explanation: `The power set of a set with \\(n\\) elements has \\(2^{n}\\) elements.\n\n\\(2^{${n}} = ${correct}\\)`,
    };
  },
  // neither of two sets within a universal set
  () => {
    const a = randInt(15, 45), b = randInt(15, 45), both = randInt(3, 12), neither = randInt(2, 15);
    const total = a + b - both + neither;
    const o = buildOptions(neither, [total - a - b, both, neither + both, total - both], (v) => String(v));
    if (!o) return null;
    return {
      text: `In a universal set of ${total} elements, \\(n(A) = ${a}\\), \\(n(B) = ${b}\\) and \\(n(A \\cap B) = ${both}\\). Find \\(n(A \\cup B)'\\).`,
      ...o,
      explanation: `\\(n(A \\cup B) = ${a} + ${b} - ${both} = ${a + b - both}\\)\n\n\\(n(A \\cup B)' = n(U) - n(A \\cup B)\\)\n\n\\(= ${total} - ${a + b - both} = ${neither}\\)`,
    };
  },
];

// ========================== BINOMIAL THEOREM ==========================
const binomial = [
  // coefficient of x^r in (1+x)^n
  () => {
    const n = randInt(5, 20), r = randInt(2, Math.min(8, n - 1));
    const correct = nCr(n, r);
    const o = buildOptions(correct, [nCr(n, r + 1), nCr(n, r - 1), nPr(n, r), n * r], (v) => String(v));
    if (!o) return null;
    return {
      text: `Find the coefficient of \\(x^{${r}}\\) in the expansion of \\((1 + x)^{${n}}\\).`,
      ...o,
      explanation: `The coefficient of \\(x^{r}\\) in \\((1+x)^{n}\\) is \\(\\binom{n}{r}\\).\n\n\\(\\binom{${n}}{${r}} = \\frac{${n}!}{${r}!(${n}-${r})!} = ${correct}\\)`,
    };
  },
  // coefficient in (a + bx)^n
  () => {
    const n = randInt(3, 8), r = randInt(1, n - 1);
    const a = randInt(1, 5), b = randInt(1, 5);
    const correct = nCr(n, r) * Math.pow(a, n - r) * Math.pow(b, r);
    const o = buildOptions(correct, [nCr(n, r), nCr(n, r) * Math.pow(a, r) * Math.pow(b, n - r), correct * 2, correct + n], (v) => String(v));
    if (!o) return null;
    return {
      text: `Find the coefficient of \\(x^{${r}}\\) in the expansion of \\((${a} + ${b}x)^{${n}}\\).`,
      ...o,
      explanation: `The general term is \\(\\binom{${n}}{r}(${a})^{${n}-r}(${b}x)^{r}\\).\n\nFor \\(x^{${r}}\\), take \\(r = ${r}\\):\n\n\\(\\binom{${n}}{${r}} \\times ${a}^{${n - r}} \\times ${b}^{${r}} = ${nCr(n, r)} \\times ${Math.pow(a, n - r)} \\times ${Math.pow(b, r)} = ${correct}\\)`,
    };
  },
  // constant / middle term index
  () => {
    const n = 2 * randInt(2, 12);
    const correct = n / 2 + 1;
    const o = buildOptions(correct, [n / 2, n + 1, correct + 1], (v) => `${v}th term`);
    if (!o) return null;
    return {
      text: `How many terms are there before the middle term in the expansion of \\((a + b)^{${n}}\\), and which term is the middle one?`,
      ...o,
      explanation: `\\((a+b)^{n}\\) has \\(n + 1 = ${n + 1}\\) terms.\n\nSince ${n} is even, there is a single middle term, the \\(\\left(\\frac{${n}}{2} + 1\\right)\\)th \\(= ${correct}\\)th term.`,
    };
  },
  // evaluate a binomial coefficient
  () => {
    const n = randInt(4, 20), r = randInt(2, Math.min(7, n));
    const correct = nCr(n, r);
    const o = buildOptions(correct, [nPr(n, r), nCr(n, r - 1), nCr(n + 1, r), n * r], (v) => String(v));
    if (!o) return null;
    return {
      text: `Evaluate \\(\\binom{${n}}{${r}}\\).`,
      ...o,
      explanation: `\\(\\binom{n}{r} = \\frac{n!}{r!(n-r)!}\\)\n\n\\(\\binom{${n}}{${r}} = \\frac{${n}!}{${r}! \\times ${n - r}!} = ${correct}\\)`,
    };
  },
  // expansion of (1+x)^n first terms
  () => {
    const n = randInt(4, 22);
    const c1 = nCr(n, 1), c2 = nCr(n, 2);
    const correct = `1 + ${c1}x + ${c2}x^{2}`;
    const wrongs = [
      `1 + ${n}x + ${n}x^{2}`,
      `1 + ${c2}x + ${c1}x^{2}`,
      `1 + ${c1}x + ${nCr(n, 3)}x^{2}`,
    ];
    const o = textOptions(mathOpt(correct), wrongs.map(mathOpt));
    if (!o) return null;
    return {
      text: `Write down the first three terms of the expansion of \\((1 + x)^{${n}}\\) in ascending powers of \\(x\\).`,
      ...o,
      explanation: `\\((1+x)^{n} = 1 + \\binom{n}{1}x + \\binom{n}{2}x^{2} + \\dots\\)\n\n\\(\\binom{${n}}{1} = ${c1}\\), \\(\\binom{${n}}{2} = ${c2}\\)\n\nSo the first three terms are \\(${correct}\\).`,
    };
  },
  // sum of coefficients
  () => {
    const n = randInt(3, 10);
    const correct = Math.pow(2, n);
    const o = buildOptions(correct, [Math.pow(2, n) - 1, 2 * n, Math.pow(n, 2)], (v) => String(v));
    if (!o) return null;
    return {
      text: `Find the sum of the coefficients in the expansion of \\((1 + x)^{${n}}\\).`,
      ...o,
      explanation: `Setting \\(x = 1\\) gives the sum of the coefficients.\n\n\\((1 + 1)^{${n}} = 2^{${n}} = ${correct}\\)`,
    };
  },
];

// =========================== BINARY OPERATIONS ===========================
const binaryOps = [
  // evaluate a * b
  () => {
    const p = randInt(1, 5), q = randInt(1, 5), r = nonZero(-6, 6);
    const a = nonZero(-8, 8), b = nonZero(-8, 8);
    const correct = p * a + q * b + r;
    const o = buildOptions(correct, [p * b + q * a + r, p * a + q * b, a + b + r, correct + r], (v) => String(v));
    if (!o) return null;
    return {
      text: `A binary operation \\(*\\) is defined on the set of real numbers by \\(a * b = ${p}a + ${q}b ${r > 0 ? '+' : '-'} ${Math.abs(r)}\\). Evaluate \\(${a} * ${b}\\).`,
      ...o,
      explanation: `Substitute \\(a = ${a}\\) and \\(b = ${b}\\).\n\n\\(${a} * ${b} = ${p}(${a}) + ${q}(${b}) ${r > 0 ? '+' : '-'} ${Math.abs(r)}\\)\n\n\\(= ${p * a} + ${q * b} ${r > 0 ? '+' : '-'} ${Math.abs(r)} = ${correct}\\)`,
    };
  },
  // a * b = a + b + kab
  () => {
    const k = nonZero(-4, 4);
    const a = nonZero(-6, 6), b = nonZero(-6, 6);
    const correct = a + b + k * a * b;
    const o = buildOptions(correct, [a + b, a * b + k, a + b - k * a * b, correct + k], (v) => String(v));
    if (!o) return null;
    return {
      text: `If \\(a * b = a + b ${k > 0 ? '+' : '-'} ${Math.abs(k)}ab\\), evaluate \\(${a} * ${b}\\).`,
      ...o,
      explanation: `\\(${a} * ${b} = ${a} + ${b} ${k > 0 ? '+' : '-'} ${Math.abs(k)}(${a})(${b})\\)\n\n\\(= ${a + b} ${k * a * b >= 0 ? '+' : '-'} ${Math.abs(k * a * b)} = ${correct}\\)`,
    };
  },
  // identity element for a*b = a + b + c
  () => {
    const c = nonZero(-9, 9);
    const correct = -c;
    const o = buildOptions(correct, [c, 0, correct + 1], (v) => String(v));
    if (!o) return null;
    return {
      text: `A binary operation \\(*\\) is defined by \\(a * b = a + b ${c > 0 ? '+' : '-'} ${Math.abs(c)}\\). Find the identity element.`,
      ...o,
      explanation: `The identity element \\(e\\) satisfies \\(a * e = a\\).\n\n\\(a + e ${c > 0 ? '+' : '-'} ${Math.abs(c)} = a\\)\n\n\\(e ${c > 0 ? '+' : '-'} ${Math.abs(c)} = 0\\)\n\n\\(e = ${correct}\\)`,
    };
  },
  // inverse element
  () => {
    const c = nonZero(-9, 9);
    const a = nonZero(-9, 9);
    const e = -c;
    const correct = e - c - a;              // a * x = e  =>  a + x + c = -c
    const o = buildOptions(correct, [-a, a + c, e], (v) => String(v));
    if (!o) return null;
    return {
      text: `A binary operation \\(*\\) is defined by \\(a * b = a + b ${c > 0 ? '+' : '-'} ${Math.abs(c)}\\), with identity element ${e}. Find the inverse of ${a}.`,
      ...o,
      explanation: `Let the inverse of ${a} be \\(x\\), so \\(${a} * x = ${e}\\).\n\n\\(${a} + x ${c > 0 ? '+' : '-'} ${Math.abs(c)} = ${e}\\)\n\n\\(x = ${e} - ${a} ${c > 0 ? '-' : '+'} ${Math.abs(c)} = ${correct}\\)`,
    };
  },
  // is the operation commutative
  () => {
    const kind = pick([
      { d: 'a * b = a + b - ab', comm: true, why: 'Both \\(a + b\\) and \\(ab\\) are unchanged when \\(a\\) and \\(b\\) are interchanged.' },
      { d: 'a * b = ab + a + b', comm: true, why: 'Both \\(ab\\) and \\(a + b\\) are symmetric in \\(a\\) and \\(b\\).' },
      { d: 'a * b = 2a + 3b', comm: false, why: 'Interchanging gives \\(2b + 3a\\), which is not the same as \\(2a + 3b\\) in general.' },
      { d: 'a * b = a - b', comm: false, why: 'Interchanging gives \\(b - a = -(a - b)\\), which differs unless \\(a = b\\).' },
      { d: 'a * b = a^{2} + b^{2}', comm: true, why: 'Squaring and adding is symmetric in \\(a\\) and \\(b\\).' },
      { d: 'a * b = a^{2} - b', comm: false, why: 'Interchanging gives \\(b^{2} - a\\), which is generally different.' },
    ]);
    const correct = kind.comm ? 'Yes, it is commutative' : 'No, it is not commutative';
    const o = textOptions(correct, [
      kind.comm ? 'No, it is not commutative' : 'Yes, it is commutative',
      'Only when \\(a = 0\\)',
      'It cannot be determined',
    ]);
    if (!o) return null;
    return {
      text: `A binary operation is defined by \\(${kind.d}\\). Is the operation commutative?`,
      ...o,
      explanation: `An operation is commutative if \\(a * b = b * a\\) for all \\(a, b\\).\n\n${kind.why}\n\nSo the operation is ${kind.comm ? '' : 'not '}commutative.`,
    };
  },
];

// ============================== FUNCTIONS ==============================
const fmFunctions = [
  // composite function expression
  () => {
    const a = nonZero(-5, 6), b = nonZero(-8, 8), c = nonZero(-5, 6), d = nonZero(-8, 8);
    const A = a * c, B = a * d + b;
    const lin = (p, q) => {
      let s = p === 1 ? 'x' : p === -1 ? '-x' : `${p}x`;
      if (q !== 0) s += (q > 0 ? ' + ' : ' - ') + Math.abs(q);
      return s;
    };
    const o = buildOptions([A, B], [[A, c * b + d], [c * a, c * b + d], [A, B + 1]], (p) => mathOpt(lin(p[0], p[1])));
    if (!o) return null;
    return {
      text: `Given \\(f(x) = ${lin(a, b)}\\) and \\(g(x) = ${lin(c, d)}\\), find \\(f \\circ g(x)\\).`,
      ...o,
      explanation: `\\(f \\circ g(x) = f(g(x))\\)\n\n\\(= ${a}(${lin(c, d)}) ${b > 0 ? '+' : '-'} ${Math.abs(b)}\\)\n\n\\(= ${A}x ${a * d >= 0 ? '+' : '-'} ${Math.abs(a * d)} ${b > 0 ? '+' : '-'} ${Math.abs(b)}\\)\n\n\\(= ${lin(A, B)}\\)`,
    };
  },
  // domain exclusion of a rational function
  () => {
    const a = randInt(1, 6), b = nonZero(-12, 12);
    const excluded = frac(-b, a);
    const o = buildOptions(excluded, [frac(b, a), frac(a, b), frac(-a, b)], (f) => mathOpt(`x = ${fracTex(f)}`));
    if (!o) return null;
    return {
      text: `Find the value of \\(x\\) that must be excluded from the domain of \\(f(x) = \\frac{${randInt(1, 9)}}{${a}x ${b > 0 ? '+' : '-'} ${Math.abs(b)}}\\).`,
      ...o,
      explanation: `The function is undefined where the denominator is zero.\n\n\\(${a}x ${b > 0 ? '+' : '-'} ${Math.abs(b)} = 0\\)\n\n\\(x = ${fracTex(excluded)}\\)`,
    };
  },
  // inverse of a rational-linear function
  () => {
    const a = randInt(2, 9), b = nonZero(-12, 12);
    const correct = `\\frac{x ${b > 0 ? '-' : '+'} ${Math.abs(b)}}{${a}}`;
    const wrongs = [`\\frac{x ${b > 0 ? '+' : '-'} ${Math.abs(b)}}{${a}}`, `${a}x ${b > 0 ? '-' : '+'} ${Math.abs(b)}`, `\\frac{${a}}{x ${b > 0 ? '-' : '+'} ${Math.abs(b)}}`];
    const o = textOptions(mathOpt(correct), wrongs.map(mathOpt));
    if (!o) return null;
    return {
      text: `If \\(f(x) = ${a}x ${b > 0 ? '+' : '-'} ${Math.abs(b)}\\), find \\(f^{-1}(x)\\).`,
      ...o,
      explanation: `Let \\(y = ${a}x ${b > 0 ? '+' : '-'} ${Math.abs(b)}\\) and make \\(x\\) the subject.\n\n\\(x = \\frac{y ${b > 0 ? '-' : '+'} ${Math.abs(b)}}{${a}}\\)\n\nSo \\(f^{-1}(x) = ${correct}\\).`,
    };
  },
  // evaluate a composite at a point
  () => {
    const a = nonZero(-5, 5), b = nonZero(-7, 7), c = nonZero(-5, 5), d = nonZero(-7, 7), k = nonZero(-5, 5);
    const gk = c * k + d;
    const correct = a * gk + b;
    const o = buildOptions(correct, [c * (a * k + b) + d, gk, a * k + b], (v) => String(v));
    if (!o) return null;
    return {
      text: `Given \\(f(x) = ${a}x ${b > 0 ? '+' : '-'} ${Math.abs(b)}\\) and \\(g(x) = ${c}x ${d > 0 ? '+' : '-'} ${Math.abs(d)}\\), evaluate \\(fg(${k})\\).`,
      ...o,
      explanation: `\\(g(${k}) = ${c}(${k}) ${d > 0 ? '+' : '-'} ${Math.abs(d)} = ${gk}\\)\n\n\\(f(${gk}) = ${a}(${gk}) ${b > 0 ? '+' : '-'} ${Math.abs(b)} = ${correct}\\)`,
    };
  },
  // range of a quadratic
  () => {
    const a = pick([1, 2, 3]);
    const h = randInt(-5, 5), k = randInt(-10, 10);
    const b = -2 * a * h, c = a * h * h + k;
    const correct = `y \\geq ${k}`;
    const o = textOptions(mathOpt(correct), [mathOpt(`y \\leq ${k}`), mathOpt(`y \\geq ${h}`), mathOpt(`y \\geq ${c}`)]);
    if (!o) return null;
    return {
      text: `Find the range of the function \\(f(x) = ${polyTex([[a, 2], [b, 1], [c, 0]])}\\) for real values of \\(x\\).`,
      ...o,
      explanation: `Complete the square: \\(f(x) = ${a}(x ${-h >= 0 ? '+' : '-'} ${Math.abs(h)})^{2} ${k >= 0 ? '+' : '-'} ${Math.abs(k)}\\)\n\nSince \\(${a}(x ${-h >= 0 ? '+' : '-'} ${Math.abs(h)})^{2} \\geq 0\\), the least value of \\(f(x)\\) is ${k}.\n\nSo the range is \\(${correct}\\).`,
    };
  },
];

// ========================= POLYNOMIAL FUNCTIONS =========================
const polynomials = [
  // remainder theorem
  () => {
    const a = nonZero(-4, 5), b = nonZero(-6, 6), c = nonZero(-8, 8), d = nonZero(-9, 9), k = nonZero(-4, 4);
    const rem = a * k ** 3 + b * k ** 2 + c * k + d;
    const o = buildOptions(rem, [a * (-k) ** 3 + b * k ** 2 - c * k + d, rem + k, d, rem - d], (v) => String(v));
    if (!o) return null;
    return {
      text: `Find the remainder when \\(${polyTex([[a, 3], [b, 2], [c, 1], [d, 0]])}\\) is divided by \\(${brk(-k)}\\).`,
      ...o,
      explanation: `By the remainder theorem, the remainder when \\(f(x)\\) is divided by \\((x - k)\\) is \\(f(k)\\).\n\nHere \\(k = ${k}\\):\n\n\\(f(${k}) = ${a}(${k})^{3} ${b > 0 ? '+' : '-'} ${Math.abs(b)}(${k})^{2} ${c > 0 ? '+' : '-'} ${Math.abs(c)}(${k}) ${d > 0 ? '+' : '-'} ${Math.abs(d)}\\)\n\n\\(= ${rem}\\)`,
    };
  },
  // factor theorem: find the constant
  () => {
    const a = nonZero(-4, 5), b = nonZero(-6, 6), k = nonZero(-4, 4);
    // f(x) = a x^3 + b x^2 + c x + d, want f(k) = 0 -> solve for d
    const c = nonZero(-8, 8);
    const d = -(a * k ** 3 + b * k ** 2 + c * k);
    const o = buildOptions(d, [-d, d + k, a + b + c], (v) => String(v));
    if (!o) return null;
    return {
      text: `Find the value of \\(k\\) for which \\(${brk(-1 * k)}\\) is a factor of \\(${polyTex([[a, 3], [b, 2], [c, 1]])} + k\\).`,
      ...o,
      explanation: `By the factor theorem, \\(f(${k}) = 0\\).\n\n\\(${a}(${k})^{3} ${b > 0 ? '+' : '-'} ${Math.abs(b)}(${k})^{2} ${c > 0 ? '+' : '-'} ${Math.abs(c)}(${k}) + k = 0\\)\n\n\\(${a * k ** 3 + b * k ** 2 + c * k} + k = 0\\)\n\n\\(k = ${d}\\)`,
    };
  },
  // sum and product of roots of a cubic
  () => {
    const a = randInt(1, 4), b = nonZero(-9, 9), c = nonZero(-9, 9), d = nonZero(-9, 9);
    const ask = pick(['sum', 'product']);
    const correct = ask === 'sum' ? frac(-b, a) : frac(-d, a);
    const other = ask === 'sum' ? frac(-d, a) : frac(-b, a);
    const o = buildOptions(correct, [other, frac(b, a), frac(d, a)], (f) => fracOpt(f));
    if (!o) return null;
    return {
      text: `Find the ${ask} of the roots of the equation \\(${polyTex([[a, 3], [b, 2], [c, 1], [d, 0]])} = 0\\).`,
      ...o,
      explanation: `For \\(ax^{3} + bx^{2} + cx + d = 0\\), the sum of the roots is \\(-\\frac{b}{a}\\) and the product is \\(-\\frac{d}{a}\\).\n\n${ask === 'sum' ? `Sum \\(= -\\frac{${b}}{${a}} = ${fracTex(correct)}\\)` : `Product \\(= -\\frac{${d}}{${a}} = ${fracTex(correct)}\\)`}`,
    };
  },
  // evaluate a polynomial
  () => {
    const a = nonZero(-4, 5), b = nonZero(-7, 7), c = nonZero(-9, 9), k = nonZero(-4, 4);
    const val = a * k ** 2 + b * k + c;
    const o = buildOptions(val, [a * k ** 2 - b * k + c, val + k, -val], (v) => String(v));
    if (!o) return null;
    return {
      text: `If \\(f(x) = ${polyTex([[a, 2], [b, 1], [c, 0]])}\\), find \\(f(${k})\\).`,
      ...o,
      explanation: `Substitute \\(x = ${k}\\).\n\n\\(f(${k}) = ${a}(${k})^{2} ${b > 0 ? '+' : '-'} ${Math.abs(b)}(${k}) ${c > 0 ? '+' : '-'} ${Math.abs(c)}\\)\n\n\\(= ${a * k * k} ${b * k >= 0 ? '+' : '-'} ${Math.abs(b * k)} ${c > 0 ? '+' : '-'} ${Math.abs(c)} = ${val}\\)`,
    };
  },
  // is (x - k) a factor?
  () => {
    const a = nonZero(-3, 4), b = nonZero(-6, 6), c = nonZero(-8, 8), k = nonZero(-3, 3);
    const val = a * k ** 2 + b * k + c;
    const isFactor = val === 0;
    const correct = isFactor ? 'Yes, because the remainder is 0' : `No, because the remainder is ${val}`;
    const o = textOptions(correct, [
      isFactor ? `No, because the remainder is ${val + 1}` : 'Yes, because the remainder is 0',
      'It cannot be determined without long division',
      `No, because the remainder is ${val + 3}`,
    ]);
    if (!o) return null;
    return {
      text: `Is \\(${brk(-k)}\\) a factor of \\(${polyTex([[a, 2], [b, 1], [c, 0]])}\\)?`,
      ...o,
      explanation: `By the factor theorem, \\(${brk(-k)}\\) is a factor if \\(f(${k}) = 0\\).\n\n\\(f(${k}) = ${a}(${k})^{2} ${b > 0 ? '+' : '-'} ${Math.abs(b)}(${k}) ${c > 0 ? '+' : '-'} ${Math.abs(c)} = ${val}\\)\n\nSince the remainder is ${val}, it is ${isFactor ? '' : 'not '}a factor.`,
    };
  },
];

// ============= RATIONAL FUNCTIONS AND PARTIAL FRACTIONS =============
const partialFractions = [
  // decompose into two linear partial fractions
  () => {
    const A = nonZero(-5, 6), B = nonZero(-5, 6);
    let a = nonZero(-6, 6), b = nonZero(-6, 6);
    if (a === b) return null;
    const p = A + B;                       // coefficient of x
    const q = A * b + B * a;               // constant
    if (p === 0) return null;
    const numer = polyTex([[p, 1], [q, 0]]);
    const correct = `\\frac{${A}}{x ${a > 0 ? '+' : '-'} ${Math.abs(a)}} + \\frac{${B}}{x ${b > 0 ? '+' : '-'} ${Math.abs(b)}}`;
    const wrongs = [
      `\\frac{${B}}{x ${a > 0 ? '+' : '-'} ${Math.abs(a)}} + \\frac{${A}}{x ${b > 0 ? '+' : '-'} ${Math.abs(b)}}`,
      `\\frac{${A}}{x ${a > 0 ? '-' : '+'} ${Math.abs(a)}} + \\frac{${B}}{x ${b > 0 ? '-' : '+'} ${Math.abs(b)}}`,
      `\\frac{${-A}}{x ${a > 0 ? '+' : '-'} ${Math.abs(a)}} + \\frac{${-B}}{x ${b > 0 ? '+' : '-'} ${Math.abs(b)}}`,
    ];
    const o = textOptions(mathOpt(correct), wrongs.map(mathOpt));
    if (!o) return null;
    return {
      text: `Express \\(\\frac{${numer}}{${brk(a)}${brk(b)}}\\) in partial fractions.`,
      ...o,
      explanation: `Let \\(\\frac{${numer}}{${brk(a)}${brk(b)}} = \\frac{P}{x ${a > 0 ? '+' : '-'} ${Math.abs(a)}} + \\frac{Q}{x ${b > 0 ? '+' : '-'} ${Math.abs(b)}}\\).\n\nMultiplying through: \\(${numer} = P(x ${b > 0 ? '+' : '-'} ${Math.abs(b)}) + Q(x ${a > 0 ? '+' : '-'} ${Math.abs(a)})\\)\n\nPutting \\(x = ${-a}\\) gives \\(P = ${A}\\); putting \\(x = ${-b}\\) gives \\(Q = ${B}\\).\n\nSo the answer is \\(${correct}\\).`,
    };
  },
  // find just one numerator
  () => {
    const A = nonZero(-6, 7), B = nonZero(-6, 7);
    let a = nonZero(-6, 6), b = nonZero(-6, 6);
    if (a === b) return null;
    const p = A + B, q = A * b + B * a;
    if (p === 0) return null;
    const numer = polyTex([[p, 1], [q, 0]]);
    const o = buildOptions(A, [B, -A, A + 1], (v) => String(v));
    if (!o) return null;
    return {
      text: `If \\(\\frac{${numer}}{${brk(a)}${brk(b)}} \\equiv \\frac{P}{x ${a > 0 ? '+' : '-'} ${Math.abs(a)}} + \\frac{Q}{x ${b > 0 ? '+' : '-'} ${Math.abs(b)}}\\), find \\(P\\).`,
      ...o,
      explanation: `Multiply both sides by \\(${brk(a)}${brk(b)}\\):\n\n\\(${numer} = P(x ${b > 0 ? '+' : '-'} ${Math.abs(b)}) + Q(x ${a > 0 ? '+' : '-'} ${Math.abs(a)})\\)\n\nSubstitute \\(x = ${-a}\\) to eliminate \\(Q\\):\n\n\\(P = ${A}\\)`,
    };
  },
  // asymptote of a rational function
  () => {
    const a = randInt(1, 6), b = nonZero(-10, 10);
    const correct = frac(-b, a);
    const o = buildOptions(correct, [frac(b, a), frac(a, b), frac(0, 1)], (f) => mathOpt(`x = ${fracTex(f)}`));
    if (!o) return null;
    return {
      text: `Find the equation of the vertical asymptote of \\(y = \\frac{${randInt(1, 9)}}{${a}x ${b > 0 ? '+' : '-'} ${Math.abs(b)}}\\).`,
      ...o,
      explanation: `A vertical asymptote occurs where the denominator is zero.\n\n\\(${a}x ${b > 0 ? '+' : '-'} ${Math.abs(b)} = 0\\)\n\n\\(x = ${fracTex(correct)}\\)`,
    };
  },
  // simplify a rational expression
  () => {
    const a = randInt(2, 10);
    const correct = `\\frac{x ${a > 0 ? '-' : '+'} ${Math.abs(a)}}{x ${a > 0 ? '+' : '-'} ${Math.abs(a)}}`;
    const wrongs = [`\\frac{x ${a > 0 ? '+' : '-'} ${Math.abs(a)}}{x ${a > 0 ? '-' : '+'} ${Math.abs(a)}}`, `x ${a > 0 ? '-' : '+'} ${Math.abs(a)}`, `\\frac{1}{x ${a > 0 ? '+' : '-'} ${Math.abs(a)}}`];
    const o = textOptions(mathOpt(correct), wrongs.map(mathOpt));
    if (!o) return null;
    return {
      text: `Simplify \\(\\frac{x^{2} - ${a * a}}{(x + ${a})^{2}}\\).`,
      ...o,
      explanation: `Factorise the numerator as a difference of two squares.\n\n\\(x^{2} - ${a * a} = (x + ${a})(x - ${a})\\)\n\n\\(\\frac{(x + ${a})(x - ${a})}{(x + ${a})^{2}} = \\frac{x - ${a}}{x + ${a}}\\)`,
    };
  },
];

// ============================ FM SURDS ============================
function simplifySurd(N) {
  let c = 1, r = N;
  for (let f = Math.floor(Math.sqrt(N)); f >= 2; f--) if (r % (f * f) === 0) { c = f; r = r / (f * f); break; }
  return { c, r };
}
const surdTex = (c, r) => r === 1 ? String(c) : c === 1 ? `\\sqrt{${r}}` : `${c}\\sqrt{${r}}`;

const fmSurds = [
  // rationalise with a conjugate, general form
  () => {
    const p = pick([2, 3, 5, 6, 7, 10]);
    const a = randInt(1, 6), n = randInt(1, 9);
    const den = a * a - p;
    if (den === 0) return null;
    const numA = n * a, numB = n;
    const g = Math.abs(gcd(gcd(numA, numB), den)) || 1;
    const correct = `\\frac{${numA / g} + ${surdTex(numB / g, p)}}{${den / g}}`;
    const wrongs = [
      `\\frac{${numA / g} - ${surdTex(numB / g, p)}}{${den / g}}`,
      `\\frac{${numA / g} + ${surdTex(numB / g, p)}}{${(a * a + p) / 1}}`,
      `\\frac{${numA / g} + ${surdTex(numB / g, p)}}{${-den / g}}`,
    ];
    const o = textOptions(mathOpt(correct), wrongs.map(mathOpt));
    if (!o) return null;
    return {
      text: `Rationalise the denominator of \\(\\frac{${n}}{${a} - \\sqrt{${p}}}\\).`,
      ...o,
      explanation: `Multiply numerator and denominator by the conjugate \\(${a} + \\sqrt{${p}}\\).\n\nDenominator: \\((${a})^{2} - (\\sqrt{${p}})^{2} = ${a * a} - ${p} = ${den}\\)\n\nNumerator: \\(${n}(${a} + \\sqrt{${p}}) = ${numA} + ${surdTex(numB, p)}\\)\n\nSo the result is \\(${correct}\\).`,
    };
  },
  // simplify a sum of three surds
  () => {
    const r = pick([2, 3, 5, 6, 7]);
    const k1 = randInt(2, 6), k2 = randInt(2, 6), k3 = randInt(1, 5);
    const N1 = k1 * k1 * r, N2 = k2 * k2 * r;
    const total = k1 + k2 - k3;
    if (total <= 0) return null;
    const correct = { c: total, r };
    const o = buildOptions(correct, [{ c: k1 + k2 + k3, r }, { c: total, r: r * 2 }, { c: total + 1, r }],
      (s) => mathOpt(surdTex(s.c, s.r)));
    if (!o) return null;
    return {
      text: `Simplify \\(\\sqrt{${N1}} + \\sqrt{${N2}} - ${k3}\\sqrt{${r}}\\).`,
      ...o,
      explanation: `\\(\\sqrt{${N1}} = ${surdTex(k1, r)}\\) and \\(\\sqrt{${N2}} = ${surdTex(k2, r)}\\)\n\n\\(${surdTex(k1, r)} + ${surdTex(k2, r)} - ${k3}\\sqrt{${r}} = (${k1} + ${k2} - ${k3})\\sqrt{${r}}\\)\n\n\\(= ${surdTex(total, r)}\\)`,
    };
  },
  // expand a product of surd binomials
  () => {
    const p = pick([2, 3, 5, 7]);
    const a = randInt(1, 6), b = randInt(1, 6);
    const rational = a * b + p;
    const coef = a + b;
    const correct = `${rational} + ${surdTex(coef, p)}`;
    const wrongs = [`${a * b - p} + ${surdTex(coef, p)}`, `${rational} - ${surdTex(coef, p)}`, `${rational} + ${surdTex(a * b, p)}`];
    const o = textOptions(mathOpt(correct), wrongs.map(mathOpt));
    if (!o) return null;
    return {
      text: `Expand and simplify \\((${a} + \\sqrt{${p}})(${b} + \\sqrt{${p}})\\).`,
      ...o,
      explanation: `Expand term by term.\n\n\\(${a} \\times ${b} = ${a * b}\\)\n\n\\(${a}\\sqrt{${p}} + ${b}\\sqrt{${p}} = ${surdTex(coef, p)}\\)\n\n\\(\\sqrt{${p}} \\times \\sqrt{${p}} = ${p}\\)\n\nTotal: \\(${a * b} + ${p} + ${surdTex(coef, p)} = ${correct}\\)`,
    };
  },
  // evaluate a surd expression squared
  () => {
    const p = pick([2, 3, 5, 6, 7, 10]);
    const a = randInt(1, 6);
    const rational = a * a + p;
    const coef = 2 * a;
    const correct = `${rational} - ${surdTex(coef, p)}`;
    const wrongs = [`${rational} + ${surdTex(coef, p)}`, `${a * a - p} - ${surdTex(coef, p)}`, `${rational} - ${surdTex(a, p)}`];
    const o = textOptions(mathOpt(correct), wrongs.map(mathOpt));
    if (!o) return null;
    return {
      text: `Expand \\((${a} - \\sqrt{${p}})^{2}\\).`,
      ...o,
      explanation: `\\((a - b)^{2} = a^{2} - 2ab + b^{2}\\)\n\n\\(= ${a}^{2} - 2(${a})\\sqrt{${p}} + (\\sqrt{${p}})^{2}\\)\n\n\\(= ${a * a} - ${surdTex(coef, p)} + ${p} = ${correct}\\)`,
    };
  },
];

// ================== PERMUTATIONS AND COMBINATIONS ==================
const permComb = [
  // evaluate nPr
  () => {
    const n = randInt(4, 10), r = randInt(2, Math.min(4, n));
    const correct = nPr(n, r);
    const o = buildOptions(correct, [nCr(n, r), nPr(n, r - 1), n * r, fact(n)], (v) => String(v));
    if (!o) return null;
    return {
      text: `Evaluate \\(^{${n}}P_{${r}}\\).`,
      ...o,
      explanation: `\\(^{n}P_{r} = \\frac{n!}{(n-r)!}\\)\n\n\\(^{${n}}P_{${r}} = \\frac{${n}!}{${n - r}!} = ${Array.from({ length: r }, (_, i) => n - i).join(' \\times ')} = ${correct}\\)`,
    };
  },
  // evaluate nCr
  () => {
    const n = randInt(4, 12), r = randInt(2, Math.min(5, n));
    const correct = nCr(n, r);
    const o = buildOptions(correct, [nPr(n, r), nCr(n, r - 1), nCr(n + 1, r), n * r], (v) => String(v));
    if (!o) return null;
    return {
      text: `Evaluate \\(^{${n}}C_{${r}}\\).`,
      ...o,
      explanation: `\\(^{n}C_{r} = \\frac{n!}{r!(n-r)!}\\)\n\n\\(^{${n}}C_{${r}} = \\frac{${n}!}{${r}! \\times ${n - r}!} = ${correct}\\)`,
    };
  },
  // arrangements of distinct objects
  () => {
    const n = randInt(4, 8);
    const correct = fact(n);
    const o = buildOptions(correct, [Math.pow(n, 2), fact(n - 1), n * n * n], (v) => String(v));
    if (!o) return null;
    return {
      text: `In how many ways can ${n} different books be arranged on a shelf?`,
      ...o,
      explanation: `The number of arrangements of ${n} distinct objects is \\(${n}!\\).\n\n\\(${n}! = ${correct}\\)`,
    };
  },
  // committee selection
  () => {
    const n = randInt(6, 12), r = randInt(2, 4);
    const correct = nCr(n, r);
    const o = buildOptions(correct, [nPr(n, r), nCr(n, r + 1), n * r], (v) => String(v));
    if (!o) return null;
    return {
      text: `In how many ways can a committee of ${r} people be selected from ${n} people?`,
      ...o,
      explanation: `Order does not matter in a selection, so use combinations.\n\n\\(^{${n}}C_{${r}} = \\frac{${n}!}{${r}!(${n}-${r})!} = ${correct}\\)`,
    };
  },
  // selection from two groups
  () => {
    const m = randInt(4, 8), w = randInt(3, 7);
    const rm = randInt(1, 3), rw = randInt(1, 3);
    if (rm > m || rw > w) return null;
    const correct = nCr(m, rm) * nCr(w, rw);
    const o = buildOptions(correct, [nCr(m, rm) + nCr(w, rw), nCr(m + w, rm + rw), correct * 2], (v) => String(v));
    if (!o) return null;
    return {
      text: `A committee of ${rm} men and ${rw} women is to be formed from ${m} men and ${w} women. In how many ways can this be done?`,
      ...o,
      explanation: `Choose the men and the women independently, then multiply.\n\n\\(^{${m}}C_{${rm}} = ${nCr(m, rm)}\\) and \\(^{${w}}C_{${rw}} = ${nCr(w, rw)}\\)\n\nTotal \\(= ${nCr(m, rm)} \\times ${nCr(w, rw)} = ${correct}\\)`,
    };
  },
  // arrangements with a restriction (two together)
  () => {
    const n = randInt(4, 7);
    const correct = fact(n - 1) * 2;
    const o = buildOptions(correct, [fact(n), fact(n - 1), fact(n) * 2], (v) => String(v));
    if (!o) return null;
    return {
      text: `In how many ways can ${n} people be arranged in a row if two particular people must always sit together?`,
      ...o,
      explanation: `Treat the two people as a single unit, giving \\(${n - 1}\\) units to arrange.\n\n\\(${n - 1}! = ${fact(n - 1)}\\)\n\nThe two people can swap places within the unit in \\(2!\\) ways.\n\nTotal \\(= ${fact(n - 1)} \\times 2 = ${correct}\\)`,
    };
  },
  // circular arrangements
  () => {
    const n = randInt(4, 8);
    const correct = fact(n - 1);
    const o = buildOptions(correct, [fact(n), fact(n - 2), n * (n - 1)], (v) => String(v));
    if (!o) return null;
    return {
      text: `In how many ways can ${n} people be seated around a circular table?`,
      ...o,
      explanation: `For circular arrangements, fix one person and arrange the rest.\n\nNumber of ways \\(= (n - 1)! = ${n - 1}! = ${correct}\\)`,
    };
  },
];

// ====================== FM SEQUENCES AND SERIES ======================
const fmSequences = [
  // sigma notation sum
  () => {
    const a = randInt(1, 6), b = nonZero(-8, 8), n = randInt(3, 10);
    let total = 0;
    for (let r = 1; r <= n; r++) total += a * r + b;
    const o = buildOptions(total, [a * n + b, total + n, total - b, a * n * (n + 1) / 2], (v) => String(v));
    if (!o) return null;
    return {
      text: `Evaluate \\(\\sum_{r=1}^{${n}} (${a}r ${b > 0 ? '+' : '-'} ${Math.abs(b)})\\).`,
      ...o,
      explanation: `\\(\\sum_{r=1}^{${n}} (${a}r ${b > 0 ? '+' : '-'} ${Math.abs(b)}) = ${a}\\sum r ${b > 0 ? '+' : '-'} ${Math.abs(b)} \\times ${n}\\)\n\n\\(\\sum_{r=1}^{${n}} r = \\frac{${n}(${n}+1)}{2} = ${n * (n + 1) / 2}\\)\n\n\\(= ${a} \\times ${n * (n + 1) / 2} ${b > 0 ? '+' : '-'} ${Math.abs(b * n)} = ${total}\\)`,
    };
  },
  // sum to infinity with a fractional ratio
  () => {
    const a = randInt(2, 40);
    const rn = randInt(1, 4), rd = randInt(rn + 1, 7);
    if (gcd(rn, rd) !== 1) return null;
    const correct = frac(a * rd, rd - rn);
    const o = buildOptions(correct, [frac(a * rd, rd + rn), frac(a, rd - rn), frac(a * (rd - rn), rd)], (f) => fracOpt(f));
    if (!o) return null;
    return {
      text: `Find the sum to infinity of a G.P. whose first term is ${a} and whose common ratio is \\(\\frac{${rn}}{${rd}}\\).`,
      ...o,
      explanation: `\\(S_\\infty = \\frac{a}{1 - r}\\) for \\(|r| < 1\\).\n\n\\(1 - \\frac{${rn}}{${rd}} = \\frac{${rd - rn}}{${rd}}\\)\n\n\\(S_\\infty = ${a} \\div \\frac{${rd - rn}}{${rd}} = ${a} \\times \\frac{${rd}}{${rd - rn}} = ${fracTex(correct)}\\)`,
    };
  },
  // AP: find n given the last term
  () => {
    const a = randInt(1, 12), d = randInt(2, 9), n = randInt(6, 25);
    const last = a + (n - 1) * d;
    const o = buildOptions(n, [n + 1, n - 1, last], (v) => String(v));
    if (!o) return null;
    return {
      text: `How many terms are in the A.P. ${a}, ${a + d}, ${a + 2 * d}, ..., ${last}?`,
      ...o,
      explanation: `\\(T_n = a + (n-1)d\\)\n\n\\(${last} = ${a} + (n-1)(${d})\\)\n\n\\((n-1)(${d}) = ${last - a}\\)\n\n\\(n - 1 = ${(last - a) / d}\\), so \\(n = ${n}\\).`,
    };
  },
  // GP: find the common ratio from two terms
  () => {
    const a = randInt(1, 6), r = randInt(2, 4), n = randInt(3, 6);
    const t1 = a, tn = a * Math.pow(r, n - 1);
    const o = buildOptions(r, [r + 1, r - 1, tn / t1], (v) => String(v));
    if (!o) return null;
    return {
      text: `The first term of a G.P. is ${t1} and the ${n}th term is ${tn}. Find the common ratio.`,
      ...o,
      explanation: `\\(T_n = ar^{n-1}\\)\n\n\\(${tn} = ${t1} \\times r^{${n - 1}}\\)\n\n\\(r^{${n - 1}} = ${tn / t1}\\)\n\n\\(r = ${r}\\)`,
    };
  },
  // arithmetic mean / geometric mean
  () => {
    const a = randInt(1, 40), b = randInt(1, 40);
    if ((a + b) % 2 !== 0) return null;
    const correct = (a + b) / 2;
    const o = buildOptions(correct, [a * b, Math.abs(a - b) / 2, correct + 2], (v) => String(v));
    if (!o) return null;
    return {
      text: `Find the arithmetic mean of ${a} and ${b}.`,
      ...o,
      explanation: `The arithmetic mean of two numbers is half their sum.\n\n\\(\\frac{${a} + ${b}}{2} = \\frac{${a + b}}{2} = ${correct}\\)`,
    };
  },
  // sum of the first n terms of an AP given first and last
  () => {
    const n = randInt(5, 20), a = randInt(1, 15), d = randInt(1, 8);
    const last = a + (n - 1) * d;
    const sum = n * (a + last) / 2;
    const o = buildOptions(sum, [n * (a + last), (a + last) / 2, sum + n], (v) => String(v));
    if (!o) return null;
    return {
      text: `An A.P. has ${n} terms, first term ${a} and last term ${last}. Find the sum of the series.`,
      ...o,
      explanation: `\\(S_n = \\frac{n}{2}(a + l)\\)\n\n\\(= \\frac{${n}}{2}(${a} + ${last}) = \\frac{${n}}{2} \\times ${a + last} = ${sum}\\)`,
    };
  },
];

// ================= MATRICES AND LINEAR TRANSFORMATION =================
const matTex = (m) => `\\begin{pmatrix} ${m[0][0]} & ${m[0][1]} \\\\ ${m[1][0]} & ${m[1][1]} \\end{pmatrix}`;
const matOpt = (m) => mathOpt(matTex(m));
const randMat = (lo = -6, hi = 8) => [[randInt(lo, hi), randInt(lo, hi)], [randInt(lo, hi), randInt(lo, hi)]];

const fmMatrices = [
  // determinant
  () => {
    const M = randMat(-9, 9);
    const [[a, b], [c, d]] = M;
    const det = a * d - b * c;
    const o = buildOptions(det, [a * d + b * c, a * b - c * d, -det, a + d], (v) => String(v));
    if (!o) return null;
    return {
      text: `Find the determinant of \\(${matTex(M)}\\).`,
      ...o,
      explanation: `\\(\\det = ad - bc\\)\n\n\\(= (${a})(${d}) - (${b})(${c}) = ${a * d} - ${b * c} = ${det}\\)`,
    };
  },
  // inverse
  () => {
    const [[a, b], [c, d]] = randMat(1, 7);
    const det = a * d - b * c;
    if (det === 0 || Math.abs(det) === 1) return null;
    const correct = `\\frac{1}{${det}}${matTex([[d, -b], [-c, a]])}`;
    const wrongs = [
      `\\frac{1}{${det}}${matTex([[a, b], [c, d]])}`,
      `\\frac{1}{${-det}}${matTex([[d, -b], [-c, a]])}`,
      `\\frac{1}{${det}}${matTex([[d, b], [c, a]])}`,
    ];
    const o = textOptions(mathOpt(correct), wrongs.map(mathOpt));
    if (!o) return null;
    return {
      text: `Find the inverse of \\(${matTex([[a, b], [c, d]])}\\).`,
      ...o,
      explanation: `\\(A^{-1} = \\frac{1}{ad - bc}\\begin{pmatrix} d & -b \\\\ -c & a \\end{pmatrix}\\)\n\n\\(ad - bc = ${a * d} - ${b * c} = ${det}\\)\n\nSo \\(A^{-1} = ${correct}\\).`,
    };
  },
  // matrix product
  () => {
    const A = randMat(-4, 6), B = randMat(-4, 6);
    const P = [
      [A[0][0] * B[0][0] + A[0][1] * B[1][0], A[0][0] * B[0][1] + A[0][1] * B[1][1]],
      [A[1][0] * B[0][0] + A[1][1] * B[1][0], A[1][0] * B[0][1] + A[1][1] * B[1][1]],
    ];
    const o = buildOptions(P, [
      [[A[0][0] * B[0][0], A[0][1] * B[0][1]], [A[1][0] * B[1][0], A[1][1] * B[1][1]]],
      [[P[0][0] + 1, P[0][1]], [P[1][0], P[1][1] - 1]],
      [[P[1][1], P[0][1]], [P[1][0], P[0][0]]],
    ], matOpt);
    if (!o) return null;
    return {
      text: `Given \\(A = ${matTex(A)}\\) and \\(B = ${matTex(B)}\\), find \\(AB\\).`,
      ...o,
      explanation: `Multiply rows of \\(A\\) by columns of \\(B\\).\n\nTop-left: \\((${A[0][0]})(${B[0][0]}) + (${A[0][1]})(${B[1][0]}) = ${P[0][0]}\\)\n\nTop-right: \\((${A[0][0]})(${B[0][1]}) + (${A[0][1]})(${B[1][1]}) = ${P[0][1]}\\)\n\nBottom-left: \\((${A[1][0]})(${B[0][0]}) + (${A[1][1]})(${B[1][0]}) = ${P[1][0]}\\)\n\nBottom-right: \\((${A[1][0]})(${B[0][1]}) + (${A[1][1]})(${B[1][1]}) = ${P[1][1]}\\)\n\nSo \\(AB = ${matTex(P)}\\).`,
    };
  },
  // image of a point under a transformation matrix
  () => {
    const M = randMat(-4, 5);
    const x = nonZero(-7, 7), y = nonZero(-7, 7);
    const img = [M[0][0] * x + M[0][1] * y, M[1][0] * x + M[1][1] * y];
    const o = buildOptions(img, [[img[1], img[0]], [M[0][0] * x, M[1][1] * y], [-img[0], -img[1]]],
      (p) => mathOpt(`(${p[0]}, ${p[1]})`));
    if (!o) return null;
    return {
      text: `Find the image of the point \\((${x}, ${y})\\) under the linear transformation represented by \\(${matTex(M)}\\).`,
      ...o,
      explanation: `\\(${matTex(M)}\\begin{pmatrix} ${x} \\\\ ${y} \\end{pmatrix} = \\begin{pmatrix} (${M[0][0]})(${x}) + (${M[0][1]})(${y}) \\\\ (${M[1][0]})(${x}) + (${M[1][1]})(${y}) \\end{pmatrix}\\)\n\n\\(= \\begin{pmatrix} ${img[0]} \\\\ ${img[1]} \\end{pmatrix}\\)\n\nSo the image is \\((${img[0]}, ${img[1]})\\).`,
    };
  },
  // singular matrix
  () => {
    const b = randInt(1, 9), c = randInt(1, 9), d = randInt(1, 9);
    if ((b * c) % d !== 0) return null;
    const x = b * c / d;
    const o = buildOptions(x, [-x, b * c, x + 1], (v) => String(v));
    if (!o) return null;
    return {
      text: `For what value of \\(x\\) is the matrix \\(\\begin{pmatrix} x & ${b} \\\\ ${c} & ${d} \\end{pmatrix}\\) singular?`,
      ...o,
      explanation: `A matrix is singular when its determinant is zero.\n\n\\(${d}x - ${b * c} = 0\\)\n\n\\(x = \\frac{${b * c}}{${d}} = ${x}\\)`,
    };
  },
  // identify a transformation matrix
  () => {
    const kinds = [
      { d: 'a reflection in the x-axis', m: [[1, 0], [0, -1]] },
      { d: 'a reflection in the y-axis', m: [[-1, 0], [0, 1]] },
      { d: 'a rotation of 180° about the origin', m: [[-1, 0], [0, -1]] },
      { d: 'a rotation of 90° anticlockwise about the origin', m: [[0, -1], [1, 0]] },
      { d: 'a reflection in the line \\(y = x\\)', m: [[0, 1], [1, 0]] },
    ];
    const k = pick(kinds);
    const others = kinds.filter(x => x.d !== k.d).slice(0, 3);
    const o = buildOptions(k.m, others.map(x => x.m), matOpt);
    if (!o) return null;
    return {
      text: `Write down the matrix that represents ${k.d}.`,
      ...o,
      explanation: `Under ${k.d}, the image of \\((1, 0)\\) forms the first column and the image of \\((0, 1)\\) forms the second column.\n\nThis gives \\(${matTex(k.m)}\\).`,
    };
  },
];

// Logical Reasoning is shared with the Mathematics topic of the same name
const logicalGens = require('./math_num_b').find(t => t.topicName === 'Logical Reasoning').generators;

module.exports = [
  { topicId: 'Wh4JOzk9kGiN0znXUeK5', unitId: U_PURE, topicName: 'Sets and Venn Diagrams', generators: setsVenn },
  { topicId: '3dQXxI55T8JBhjpHyja8', unitId: U_PURE, topicName: 'Binomial Theorem', generators: binomial },
  { topicId: '2nNSUeNhkXWCUQMAvof8', unitId: U_PURE, topicName: 'Binary Operations', generators: binaryOps },
  { topicId: 'mAHZJnxbh1UbaHSM4ny8', unitId: U_PURE, topicName: 'Functions', generators: fmFunctions },
  { topicId: 'ZwlXi8nGluN5NIR6p3Q7', unitId: U_PURE, topicName: 'Polynomial Functions', generators: polynomials },
  { topicId: 'qKVAKY3XsJJY8SWlepCX', unitId: U_PURE, topicName: 'Rational Functions and Partial Fractions', generators: partialFractions },
  { topicId: 'SXyJTb0OIKsQnyAFffeI', unitId: U_PURE, topicName: 'Surds', generators: fmSurds },
  { topicId: '7zyEFCI8JOUTmp1C5bzS', unitId: U_PURE, topicName: 'Logical Reasoning', generators: logicalGens },
  { topicId: 'p12ek3SA5n3dXWivcEPw', unitId: U_PURE, topicName: 'Permutations and Combinations', generators: permComb },
  { topicId: 'Izf0gdgoJc1tTIBq3YQG', unitId: U_PURE, topicName: 'Sequences and Series', generators: fmSequences },
  { topicId: 'ilbjRjExKnno9THXioRh', unitId: U_PURE, topicName: 'Matrices and Linear Transformation', generators: fmMatrices },
];
