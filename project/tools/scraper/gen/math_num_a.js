// Mathematics > Number and Numeration (part A)
const L = require('./lib');
const { randInt, pick, shuffle, sample, nonZero, gcd, frac, fracAdd, fracMul, fracTex, fracOpt,
        fmtNum, fixed, money, buildOptions, numericDistractors, textOptions, round } = L;

const UNIT = '1tP6EvGOVehoTzIfHSf3';

function powTex(e, v = 'x') {
  if (e === 0) return '1';
  if (e === 1) return v;
  return `${v}^{${e}}`;
}
const mathOpt = (s) => `\\(${s}\\)`;

// ============================= INDICES =============================
const indices = [
  // x^a * x^b
  () => {
    const a = randInt(2, 12), b = randInt(2, 12);
    const correct = a + b;
    const o = buildOptions(correct, [a * b, Math.abs(a - b), a + b + 1, a + b - 1],
      (e) => mathOpt(powTex(e)));
    if (!o) return null;
    return {
      text: `Simplify \\(x^{${a}} \\times x^{${b}}\\).`,
      ...o,
      explanation: `When multiplying powers of the same base, add the indices.\n\n\\(x^{${a}} \\times x^{${b}} = x^{${a}+${b}} = ${powTex(correct)}\\)`,
    };
  },
  // x^a / x^b
  () => {
    const a = randInt(6, 15), b = randInt(2, 5);
    const correct = a - b;
    const o = buildOptions(correct, [a + b, a * b, correct + 1, correct - 1],
      (e) => mathOpt(powTex(e)));
    if (!o) return null;
    return {
      text: `Simplify \\(\\frac{x^{${a}}}{x^{${b}}}\\).`,
      ...o,
      explanation: `When dividing powers of the same base, subtract the indices.\n\n\\(\\frac{x^{${a}}}{x^{${b}}} = x^{${a}-${b}} = ${powTex(correct)}\\)`,
    };
  },
  // (x^a)^b
  () => {
    const a = randInt(2, 9), b = randInt(2, 7);
    const correct = a * b;
    const o = buildOptions(correct, [a + b, correct + a, correct - b, Math.pow(a, b)],
      (e) => mathOpt(powTex(e)));
    if (!o) return null;
    return {
      text: `Simplify \\((x^{${a}})^{${b}}\\).`,
      ...o,
      explanation: `When a power is raised to another power, multiply the indices.\n\n\\((x^{${a}})^{${b}} = x^{${a} \\times ${b}} = ${powTex(correct)}\\)`,
    };
  },
  // coefficient multiply
  () => {
    const c1 = randInt(2, 9), c2 = randInt(2, 9), a = randInt(2, 6), b = randInt(2, 6);
    const cc = c1 * c2, ee = a + b;
    const o = buildOptions(`${cc}|${ee}`, [`${c1 + c2}|${ee}`, `${cc}|${a * b}`, `${cc}|${ee + 1}`, `${c1 + c2}|${a * b}`],
      (k) => { const [c, e] = k.split('|').map(Number); return mathOpt(`${c}${powTex(e)}`); });
    if (!o) return null;
    return {
      text: `Simplify \\(${c1}x^{${a}} \\times ${c2}x^{${b}}\\).`,
      ...o,
      explanation: `Multiply the coefficients and add the indices.\n\nCoefficients: \\(${c1} \\times ${c2} = ${cc}\\)\n\nIndices: \\(${a} + ${b} = ${ee}\\)\n\nSo the answer is \\(${cc}${powTex(ee)}\\).`,
    };
  },
  // numeric evaluation of a^n
  () => {
    const base = randInt(2, 7), n = randInt(2, 5);
    const correct = Math.pow(base, n);
    const o = buildOptions(correct, [base * n, Math.pow(base, n - 1), Math.pow(base, n + 1), correct + base],
      (v) => String(v));
    if (!o) return null;
    return {
      text: `Evaluate \\(${base}^{${n}}\\).`,
      ...o,
      explanation: `\\(${base}^{${n}}\\) means ${base} multiplied by itself ${n} times.\n\n\\(${base}^{${n}} = ${Array(n).fill(base).join(' \\times ')} = ${correct}\\)`,
    };
  },
  // negative index -> fraction
  () => {
    const base = randInt(2, 9), n = randInt(2, 3);
    const den = Math.pow(base, n);
    const correct = frac(1, den);
    const o = buildOptions(correct, [frac(1, base * n), frac(-1, den), frac(1, Math.pow(base, n + 1)), frac(den, 1)],
      (f) => fracOpt(f));
    if (!o) return null;
    return {
      text: `Evaluate \\(${base}^{-${n}}\\).`,
      ...o,
      explanation: `A negative index means the reciprocal: \\(a^{-n} = \\frac{1}{a^{n}}\\).\n\n\\(${base}^{-${n}} = \\frac{1}{${base}^{${n}}} = \\frac{1}{${den}}\\)`,
    };
  },
  // fractional index on a perfect power
  () => {
    const root = randInt(2, 3);
    const b = randInt(2, 6);
    const num = randInt(2, 3);
    const base = Math.pow(b, root);          // perfect power so the root is exact
    const correct = Math.pow(b, num);
    const o = buildOptions(correct, [b * num, Math.pow(b, num + 1), base * num / root, b + num],
      (v) => String(v));
    if (!o) return null;
    return {
      text: `Evaluate \\(${base}^{\\frac{${num}}{${root}}}\\).`,
      ...o,
      explanation: `\\(a^{\\frac{m}{n}} = (\\sqrt[n]{a})^{m}\\).\n\nThe ${root === 2 ? 'square' : 'cube'} root of ${base} is ${b}, since \\(${b}^{${root}} = ${base}\\).\n\nSo \\(${base}^{\\frac{${num}}{${root}}} = ${b}^{${num}} = ${correct}\\)`,
    };
  },
  // solve a^x = a^k
  () => {
    const base = randInt(2, 6), k = randInt(2, 6);
    const value = Math.pow(base, k);
    const o = buildOptions(k, [value, k + 1, k - 1, base * k], (v) => String(v));
    if (!o) return null;
    return {
      text: `If \\(${base}^{x} = ${value}\\), find the value of \\(x\\).`,
      ...o,
      explanation: `Express ${value} as a power of ${base}.\n\n\\(${value} = ${base}^{${k}}\\)\n\nSo \\(${base}^{x} = ${base}^{${k}}\\), and since the bases are equal, \\(x = ${k}\\).`,
    };
  },
  // zero index
  () => {
    const c = randInt(2, 19), a = randInt(2, 9);
    const correct = c;
    const o = buildOptions(correct, [0, 1, c * a, c + a], (v) => String(v));
    if (!o) return null;
    return {
      text: `Evaluate \\(${c} \\times ${a}^{0}\\).`,
      ...o,
      explanation: `Any non-zero number raised to the power 0 equals 1.\n\n\\(${a}^{0} = 1\\)\n\nSo \\(${c} \\times 1 = ${c}\\)`,
    };
  },
];

// ============================= LOGARITHMS =============================
const logarithms = [
  // log_b(b^k)
  () => {
    const b = randInt(2, 9), k = randInt(2, 6);
    const value = Math.pow(b, k);
    const o = buildOptions(k, [value, k + 1, b * k, k - 1], (v) => String(v));
    if (!o) return null;
    return {
      text: `Evaluate \\(\\log_{${b}} ${value}\\).`,
      ...o,
      explanation: `Let \\(\\log_{${b}} ${value} = x\\), so \\(${b}^{x} = ${value}\\).\n\nSince \\(${value} = ${b}^{${k}}\\), we get \\(x = ${k}\\).`,
    };
  },
  // log_10 of a power of 10
  () => {
    const k = randInt(2, 6);
    const value = Math.pow(10, k);
    const o = buildOptions(k, [value, k + 1, k - 1, 10 * k], (v) => String(v));
    if (!o) return null;
    return {
      text: `Evaluate \\(\\log_{10} ${value}\\).`,
      ...o,
      explanation: `\\(${value} = 10^{${k}}\\)\n\nSo \\(\\log_{10} 10^{${k}} = ${k}\\).`,
    };
  },
  // solve log_x N = k
  () => {
    const x = randInt(2, 9), k = randInt(2, 4);
    const N = Math.pow(x, k);
    const o = buildOptions(x, [N, k, x + 1, N / k], (v) => String(v));
    if (!o) return null;
    return {
      text: `If \\(\\log_{x} ${N} = ${k}\\), find \\(x\\).`,
      ...o,
      explanation: `\\(\\log_{x} ${N} = ${k}\\) means \\(x^{${k}} = ${N}\\).\n\nTaking the ${k === 2 ? 'square' : k === 3 ? 'cube' : `${k}th`} root of both sides: \\(x = ${x}\\), since \\(${x}^{${k}} = ${N}\\).`,
    };
  },
  // sum of two logs, same base
  () => {
    const b = randInt(2, 7);
    const k1 = randInt(1, 4), k2 = randInt(1, 4);
    const v1 = Math.pow(b, k1), v2 = Math.pow(b, k2);
    const correct = k1 + k2;
    const o = buildOptions(correct, [k1 * k2, Math.abs(k1 - k2), correct + 1, v1 + v2], (v) => String(v));
    if (!o) return null;
    return {
      text: `Evaluate \\(\\log_{${b}} ${v1} + \\log_{${b}} ${v2}\\).`,
      ...o,
      explanation: `Use \\(\\log a + \\log b = \\log(ab)\\).\n\n\\(\\log_{${b}} ${v1} + \\log_{${b}} ${v2} = \\log_{${b}} (${v1} \\times ${v2}) = \\log_{${b}} ${v1 * v2}\\)\n\nSince \\(${v1 * v2} = ${b}^{${correct}}\\), the value is ${correct}.`,
    };
  },
  // difference of two logs
  () => {
    const b = randInt(2, 7);
    const k1 = randInt(3, 6), k2 = randInt(1, 2);
    const v1 = Math.pow(b, k1), v2 = Math.pow(b, k2);
    const correct = k1 - k2;
    const o = buildOptions(correct, [k1 + k2, k1 * k2, correct + 1, v1 / v2], (v) => String(v));
    if (!o) return null;
    return {
      text: `Evaluate \\(\\log_{${b}} ${v1} - \\log_{${b}} ${v2}\\).`,
      ...o,
      explanation: `Use \\(\\log a - \\log b = \\log\\left(\\frac{a}{b}\\right)\\).\n\n\\(\\log_{${b}} ${v1} - \\log_{${b}} ${v2} = \\log_{${b}} \\frac{${v1}}{${v2}} = \\log_{${b}} ${v1 / v2}\\)\n\nSince \\(${v1 / v2} = ${b}^{${correct}}\\), the value is ${correct}.`,
    };
  },
  // given log 2, find log of a power of 2
  () => {
    const k = randInt(2, 5);
    const value = Math.pow(2, k);
    const log2 = 0.3010;
    const correct = round(k * log2, 4);
    const o = buildOptions(correct, [round(log2 * (k + 1), 4), round(log2 / k, 4), round(log2 * k + 0.1, 4), round(log2 * (k - 1), 4)],
      (v) => fixed(v, 4));
    if (!o) return null;
    return {
      text: `Given that \\(\\log_{10} 2 = 0.3010\\), evaluate \\(\\log_{10} ${value}\\).`,
      ...o,
      explanation: `\\(${value} = 2^{${k}}\\)\n\n\\(\\log_{10} 2^{${k}} = ${k} \\log_{10} 2\\)\n\n\\(= ${k} \\times 0.3010 = ${fixed(correct, 4)}\\)`,
    };
  },
  // log of 1
  () => {
    const b = randInt(2, 9);
    const o = buildOptions(0, [1, b, -1, 10], (v) => String(v));
    if (!o) return null;
    return {
      text: `Evaluate \\(\\log_{${b}} 1\\).`,
      ...o,
      explanation: `Any base raised to the power 0 gives 1, so \\(${b}^{0} = 1\\).\n\nTherefore \\(\\log_{${b}} 1 = 0\\).`,
    };
  },
  // log_b(b) = 1
  () => {
    const b = randInt(2, 15);
    const o = buildOptions(1, [0, b, -1, b - 1], (v) => String(v));
    if (!o) return null;
    return {
      text: `Evaluate \\(\\log_{${b}} ${b}\\).`,
      ...o,
      explanation: `\\(\\log_{b} b = 1\\) because \\(${b}^{1} = ${b}\\).\n\nSo \\(\\log_{${b}} ${b} = 1\\).`,
    };
  },
  // log of a reciprocal power -> negative
  () => {
    const b = randInt(2, 7), k = randInt(2, 4);
    const v = Math.pow(b, k);
    const o = buildOptions(-k, [k, -k - 1, -1 / k, v], (x) => String(x));
    if (!o) return null;
    return {
      text: `Evaluate \\(\\log_{${b}} \\frac{1}{${v}}\\).`,
      ...o,
      explanation: `\\(\\frac{1}{${v}} = ${b}^{-${k}}\\)\n\nSo \\(\\log_{${b}} ${b}^{-${k}} = -${k}\\).`,
    };
  },
  // solve log_b x = k
  () => {
    const b = randInt(2, 7), k = randInt(2, 5);
    const x = Math.pow(b, k);
    const o = buildOptions(x, [b * k, Math.pow(k, b), x / b, x * b], (v) => String(v));
    if (!o) return null;
    return {
      text: `If \\(\\log_{${b}} x = ${k}\\), find \\(x\\).`,
      ...o,
      explanation: `\\(\\log_{${b}} x = ${k}\\) means \\(x = ${b}^{${k}}\\).\n\n\\(x = ${x}\\)`,
    };
  },
  // index form <-> log form
  () => {
    const b = randInt(2, 9), k = randInt(2, 5);
    const v = Math.pow(b, k);
    const correct = `\\log_{${b}} ${v} = ${k}`;
    const wrongs = [`\\log_{${k}} ${v} = ${b}`, `\\log_{${v}} ${b} = ${k}`, `\\log_{${b}} ${k} = ${v}`];
    const o = textOptions(mathOpt(correct), wrongs.map(mathOpt));
    if (!o) return null;
    return {
      text: `Express \\(${b}^{${k}} = ${v}\\) in logarithmic form.`,
      ...o,
      explanation: `The statement \\(a^{n} = b\\) is written in logarithmic form as \\(\\log_{a} b = n\\).\n\nHere \\(a = ${b}\\), \\(n = ${k}\\) and \\(b = ${v}\\).\n\nSo \\(${correct}\\).`,
    };
  },
  // combined evaluation: log_a A + log_b B
  () => {
    const b1 = randInt(2, 6), k1 = randInt(2, 4);
    const b2 = randInt(2, 6), k2 = randInt(2, 4);
    const v1 = Math.pow(b1, k1), v2 = Math.pow(b2, k2);
    const correct = k1 + k2;
    const o = buildOptions(correct, [k1 * k2, Math.abs(k1 - k2), correct + 1, v1 + v2], (v) => String(v));
    if (!o) return null;
    return {
      text: `Evaluate \\(\\log_{${b1}} ${v1} + \\log_{${b2}} ${v2}\\).`,
      ...o,
      explanation: `Evaluate each logarithm separately.\n\n\\(\\log_{${b1}} ${v1} = ${k1}\\) since \\(${b1}^{${k1}} = ${v1}\\).\n\n\\(\\log_{${b2}} ${v2} = ${k2}\\) since \\(${b2}^{${k2}} = ${v2}\\).\n\nSum \\(= ${k1} + ${k2} = ${correct}\\)`,
    };
  },
  // given log 2 and log 3
  () => {
    const pairs = [[6, 1, 1], [12, 2, 1], [18, 1, 2], [24, 3, 1], [36, 2, 2], [48, 4, 1], [54, 1, 3], [72, 3, 2], [96, 5, 1], [108, 2, 3]];
    const [value, a2, a3] = pick(pairs);
    const log2 = 0.3010, log3 = 0.4771;
    const correct = round(a2 * log2 + a3 * log3, 4);
    const o = buildOptions(correct, [round(a2 * log2 - a3 * log3, 4), round(log2 + log3, 4), round(a2 * log3 + a3 * log2, 4), round(correct + 0.1, 4)],
      (v) => fixed(v, 4));
    if (!o) return null;
    return {
      text: `Given that \\(\\log_{10} 2 = 0.3010\\) and \\(\\log_{10} 3 = 0.4771\\), evaluate \\(\\log_{10} ${value}\\).`,
      ...o,
      explanation: `Express ${value} in terms of 2 and 3: \\(${value} = 2^{${a2}} \\times 3^{${a3}}\\).\n\n\\(\\log_{10} ${value} = ${a2}\\log_{10} 2 + ${a3}\\log_{10} 3\\)\n\n\\(= ${a2}(0.3010) + ${a3}(0.4771) = ${fixed(correct, 4)}\\)`,
    };
  },
  // symbolic combination
  () => {
    const forms = [
      { q: '\\log a + \\log b - \\log c', ans: '\\log\\left(\\frac{ab}{c}\\right)', wrong: ['\\log\\left(\\frac{a+b}{c}\\right)', '\\log(abc)', '\\log\\left(\\frac{ac}{b}\\right)'] },
      { q: '\\log a - \\log b + \\log c', ans: '\\log\\left(\\frac{ac}{b}\\right)', wrong: ['\\log\\left(\\frac{ab}{c}\\right)', '\\log(abc)', '\\log\\left(\\frac{a}{bc}\\right)'] },
      { q: '2\\log a + \\log b', ans: '\\log(a^{2}b)', wrong: ['\\log(2ab)', '\\log(a^{2}+b)', '2\\log(ab)'] },
      { q: '3\\log a - \\log b', ans: '\\log\\left(\\frac{a^{3}}{b}\\right)', wrong: ['\\log\\left(\\frac{3a}{b}\\right)', '3\\log\\left(\\frac{a}{b}\\right)', '\\log(a^{3}b)'] },
      { q: '\\frac{1}{2}\\log a', ans: '\\log \\sqrt{a}', wrong: ['\\frac{\\log a}{2}\\log 2', '\\log \\frac{a}{2}', '2 \\log a'] },
    ];
    const f = pick(forms);
    const o = textOptions(mathOpt(f.ans), f.wrong.map(mathOpt));
    if (!o) return null;
    return {
      text: `Express \\(${f.q}\\) as a single logarithm.`,
      ...o,
      explanation: `Apply the laws of logarithms: \\(\\log a + \\log b = \\log(ab)\\), \\(\\log a - \\log b = \\log\\frac{a}{b}\\) and \\(n\\log a = \\log a^{n}\\).\n\nThis gives \\(${f.q} = ${f.ans}\\).`,
    };
  },
];

// ================= FRACTIONS / DECIMALS / APPROXIMATIONS =================
function toSigFig(x, n) {
  if (x === 0) return 0;
  const d = Math.ceil(Math.log10(Math.abs(x)));
  const p = n - d;
  const m = Math.pow(10, p);
  return Math.round(x * m) / m;
}

const fractions = [
  // add / subtract fractions
  () => {
    const d1 = randInt(2, 12), d2 = randInt(2, 12);
    if (d1 === d2) return null;
    const n1 = randInt(1, d1 - 1), n2 = randInt(1, d2 - 1);
    const op = pick(['+', '-']);
    const a = frac(n1, d1), b = frac(n2, d2);
    const correct = op === '+' ? fracAdd(a, b) : fracAdd(a, frac(-b.n, b.d));
    if (correct.n <= 0) return null;
    const wrongNaive = frac(op === '+' ? n1 + n2 : n1 - n2, op === '+' ? d1 + d2 : Math.abs(d1 - d2) || 1);
    const o = buildOptions(correct, [wrongNaive, fracAdd(correct, frac(1, d1 * d2)), fracMul(correct, frac(2, 1)), frac(n1 * n2, d1 * d2)],
      (f) => fracOpt(f));
    if (!o) return null;
    return {
      text: `Simplify \\(\\frac{${n1}}{${d1}} ${op} \\frac{${n2}}{${d2}}\\).`,
      ...o,
      explanation: `Use a common denominator of ${d1 * d2}.\n\n\\(\\frac{${n1}}{${d1}} ${op} \\frac{${n2}}{${d2}} = \\frac{${n1 * d2} ${op} ${n2 * d1}}{${d1 * d2}} = \\frac{${op === '+' ? n1 * d2 + n2 * d1 : n1 * d2 - n2 * d1}}{${d1 * d2}}\\)\n\nIn lowest terms this is \\(${fracTex(correct)}\\).`,
    };
  },
  // multiply / divide fractions
  () => {
    const d1 = randInt(2, 11), d2 = randInt(2, 11);
    const n1 = randInt(1, d1 - 1), n2 = randInt(1, d2 - 1);
    const op = pick(['\\times', '\\div']);
    const a = frac(n1, d1), b = frac(n2, d2);
    const correct = op === '\\times' ? fracMul(a, b) : fracMul(a, frac(b.d, b.n));
    const o = buildOptions(correct, [fracMul(a, b), fracMul(a, frac(b.d, b.n)), fracAdd(a, b), frac(n1 * n2, d1 + d2)],
      (f) => fracOpt(f));
    if (!o) return null;
    const step = op === '\\times'
      ? `\\(\\frac{${n1}}{${d1}} \\times \\frac{${n2}}{${d2}} = \\frac{${n1 * n2}}{${d1 * d2}}\\)`
      : `\\(\\frac{${n1}}{${d1}} \\div \\frac{${n2}}{${d2}} = \\frac{${n1}}{${d1}} \\times \\frac{${d2}}{${n2}} = \\frac{${n1 * d2}}{${d1 * n2}}\\)`;
    return {
      text: `Simplify \\(\\frac{${n1}}{${d1}} ${op} \\frac{${n2}}{${d2}}\\).`,
      ...o,
      explanation: `${op === '\\div' ? 'To divide by a fraction, multiply by its reciprocal.' : 'Multiply the numerators and the denominators.'}\n\n${step}\n\nIn lowest terms this is \\(${fracTex(correct)}\\).`,
    };
  },
  // significant figures
  () => {
    const whole = randInt(1000, 99999);
    const dec = randInt(10, 99);
    const value = Number(`${whole}.${dec}`);
    const sf = randInt(2, 4);
    const correct = toSigFig(value, sf);
    const o = buildOptions(correct, [toSigFig(value, sf + 1), toSigFig(value, sf - 1), correct + Math.pow(10, String(whole).length - sf), correct - Math.pow(10, String(whole).length - sf)],
      (v) => fmtNum(v, 4));
    if (!o) return null;
    return {
      text: `Express ${value} correct to ${sf} significant figures.`,
      ...o,
      explanation: `Count ${sf} significant figures from the first non-zero digit of ${value}, then look at the next digit to decide whether to round up.\n\nThis gives ${fmtNum(correct, 4)}.`,
    };
  },
  // decimal places
  () => {
    const value = round(randInt(100, 9999) / 100 + Math.random(), 4);
    const dp = randInt(1, 2);
    const correct = round(value, dp);
    const o = buildOptions(correct, [round(value, dp + 1), correct + Math.pow(10, -dp), correct - Math.pow(10, -dp), Math.trunc(value)],
      (v) => fixed(v, dp));
    if (!o) return null;
    return {
      text: `Express ${fixed(value, 4)} correct to ${dp} decimal place${dp > 1 ? 's' : ''}.`,
      ...o,
      explanation: `Keep ${dp} digit${dp > 1 ? 's' : ''} after the decimal point and use the next digit to round.\n\n\\(${fixed(value, 4)} \\approx ${fixed(correct, dp)}\\) to ${dp} decimal place${dp > 1 ? 's' : ''}.`,
    };
  },
  // standard form
  () => {
    const digits = randInt(100, 999);
    const mant = digits / 100;                 // e.g. 4.56
    const exp = pick([-4, -3, -2, 2, 3, 4, 5]);
    const value = mant * Math.pow(10, exp);
    const valueStr = exp < 0 ? value.toFixed(Math.abs(exp) + 2) : String(round(value, 6));
    const o = buildOptions(exp, [exp + 1, exp - 1, -exp, exp + 2],
      (e) => mathOpt(`${mant} \\times 10^{${e}}`));
    if (!o) return null;
    return {
      text: `Express ${valueStr} in standard form.`,
      ...o,
      explanation: `Standard form is \\(a \\times 10^{n}\\) where \\(1 \\leq a < 10\\).\n\nMoving the decimal point in ${valueStr} to just after the first non-zero digit gives \\(${mant}\\), and the point moved ${Math.abs(exp)} place${Math.abs(exp) > 1 ? 's' : ''} ${exp < 0 ? 'right' : 'left'}.\n\nSo ${valueStr} \\(= ${mant} \\times 10^{${exp}}\\).`,
    };
  },
  // fraction of a quantity
  () => {
    const d = randInt(3, 12);
    const n = randInt(1, d - 1);
    const total = d * randInt(3, 30);
    const correct = total * n / d;
    const o = buildOptions(correct, numericDistractors(correct, { scale: total / d }), (v) => fmtNum(v, 2));
    if (!o) return null;
    return {
      text: `Find \\(\\frac{${n}}{${d}}\\) of ${total}.`,
      ...o,
      explanation: `\\(\\frac{${n}}{${d}} \\times ${total} = \\frac{${n} \\times ${total}}{${d}} = \\frac{${n * total}}{${d}} = ${correct}\\)`,
    };
  },
  // convert fraction to decimal
  () => {
    const d = pick([2, 4, 5, 8, 10, 16, 20, 25, 40, 50]);
    const n = randInt(1, d - 1);
    if (gcd(n, d) !== 1) return null;
    const correct = n / d;
    const o = buildOptions(correct, [d / n, correct * 10, correct / 10, correct + 0.1], (v) => fmtNum(v, 4));
    if (!o) return null;
    return {
      text: `Express \\(\\frac{${n}}{${d}}\\) as a decimal.`,
      ...o,
      explanation: `Divide the numerator by the denominator.\n\n\\(${n} \\div ${d} = ${fmtNum(correct, 4)}\\)`,
    };
  },
];

// ========================= SEQUENCE AND SERIES =========================
const sequences = [
  // AP nth term
  () => {
    const a = randInt(-9, 15), d = nonZero(-8, 9), n = randInt(5, 25);
    const correct = a + (n - 1) * d;
    const o = buildOptions(correct, [a + n * d, a + (n - 1) * d + d, a - (n - 1) * d, a * n], (v) => String(v));
    if (!o) return null;
    return {
      text: `The first term of an Arithmetic Progression (A.P.) is ${a} and the common difference is ${d}. Find the ${n}th term.`,
      ...o,
      explanation: `For an A.P., \\(T_n = a + (n-1)d\\).\n\n\\(T_{${n}} = ${a} + (${n}-1)(${d})\\)\n\n\\(= ${a} + ${n - 1} \\times ${d} = ${a} + ${(n - 1) * d} = ${correct}\\)`,
    };
  },
  // AP sum
  () => {
    const a = randInt(1, 12), d = randInt(1, 9), n = randInt(6, 20);
    const correct = n * (2 * a + (n - 1) * d) / 2;
    const o = buildOptions(correct, [n * (2 * a + n * d) / 2, n * (a + (n - 1) * d), correct + n, correct - n], (v) => String(v));
    if (!o) return null;
    return {
      text: `Find the sum of the first ${n} terms of an A.P. whose first term is ${a} and common difference is ${d}.`,
      ...o,
      explanation: `\\(S_n = \\frac{n}{2}[2a + (n-1)d]\\)\n\n\\(S_{${n}} = \\frac{${n}}{2}[2(${a}) + (${n}-1)(${d})]\\)\n\n\\(= \\frac{${n}}{2}[${2 * a} + ${(n - 1) * d}] = \\frac{${n}}{2} \\times ${2 * a + (n - 1) * d} = ${correct}\\)`,
    };
  },
  // find common difference from two terms
  () => {
    const a = randInt(1, 15), d = nonZero(-7, 9);
    let p = randInt(2, 6), q = randInt(7, 14);
    const Tp = a + (p - 1) * d, Tq = a + (q - 1) * d;
    const o = buildOptions(d, [-d, d + 1, d - 1, (Tq - Tp) / q], (v) => String(v));
    if (!o) return null;
    return {
      text: `In an A.P., the ${p}th term is ${Tp} and the ${q}th term is ${Tq}. Find the common difference.`,
      ...o,
      explanation: `\\(T_{${q}} - T_{${p}} = (${q}-${p})d\\)\n\n\\(${Tq} - (${Tp}) = ${q - p}d\\)\n\n\\(${Tq - Tp} = ${q - p}d\\)\n\n\\(d = \\frac{${Tq - Tp}}{${q - p}} = ${d}\\)`,
    };
  },
  // GP nth term
  () => {
    const a = randInt(1, 8), r = randInt(2, 4), n = randInt(3, 7);
    const correct = a * Math.pow(r, n - 1);
    const o = buildOptions(correct, [a * Math.pow(r, n), a * r * (n - 1), correct * r, correct / r], (v) => String(v));
    if (!o) return null;
    return {
      text: `The first term of a Geometric Progression (G.P.) is ${a} and the common ratio is ${r}. Find the ${n}th term.`,
      ...o,
      explanation: `For a G.P., \\(T_n = ar^{n-1}\\).\n\n\\(T_{${n}} = ${a} \\times ${r}^{${n}-1} = ${a} \\times ${r}^{${n - 1}}\\)\n\n\\(= ${a} \\times ${Math.pow(r, n - 1)} = ${correct}\\)`,
    };
  },
  // GP sum
  () => {
    const a = randInt(1, 6), r = randInt(2, 4), n = randInt(3, 6);
    const correct = a * (Math.pow(r, n) - 1) / (r - 1);
    const o = buildOptions(correct, [a * (Math.pow(r, n) + 1) / (r - 1), a * Math.pow(r, n - 1), correct + a, correct - a], (v) => String(v));
    if (!o) return null;
    return {
      text: `Find the sum of the first ${n} terms of a G.P. with first term ${a} and common ratio ${r}.`,
      ...o,
      explanation: `\\(S_n = \\frac{a(r^{n} - 1)}{r - 1}\\) for \\(r > 1\\).\n\n\\(S_{${n}} = \\frac{${a}(${r}^{${n}} - 1)}{${r} - 1} = \\frac{${a}(${Math.pow(r, n)} - 1)}{${r - 1}}\\)\n\n\\(= \\frac{${a} \\times ${Math.pow(r, n) - 1}}{${r - 1}} = ${correct}\\)`,
    };
  },
  // sum to infinity
  () => {
    const a = randInt(2, 30);
    const rd = randInt(2, 6);
    const rn = 1;
    const r = frac(rn, rd);                  // 1/rd, so |r| < 1
    const correct = frac(a * rd, rd - 1);
    const o = buildOptions(correct, [frac(a * rd, rd + 1), frac(a, rd - 1), frac(a * (rd - 1), rd), frac(a, rd)],
      (f) => fracOpt(f));
    if (!o) return null;
    return {
      text: `Find the sum to infinity of the G.P. with first term ${a} and common ratio \\(\\frac{1}{${rd}}\\).`,
      ...o,
      explanation: `\\(S_\\infty = \\frac{a}{1 - r}\\) when \\(|r| < 1\\).\n\n\\(S_\\infty = \\frac{${a}}{1 - \\frac{1}{${rd}}} = \\frac{${a}}{\\frac{${rd - 1}}{${rd}}}\\)\n\n\\(= ${a} \\times \\frac{${rd}}{${rd - 1}} = ${fracTex(correct)}\\)`,
    };
  },
  // next term of a listed sequence (AP)
  () => {
    const a = randInt(-8, 14), d = nonZero(-7, 9);
    const terms = [0, 1, 2, 3].map(i => a + i * d);
    const correct = a + 4 * d;
    const o = buildOptions(correct, [correct + d, correct - d, a + 5 * d, terms[3] + terms[0]], (v) => String(v));
    if (!o) return null;
    return {
      text: `Find the next term of the sequence ${terms.join(', ')}, ...`,
      ...o,
      explanation: `The difference between consecutive terms is constant: \\(${terms[1]} - (${terms[0]}) = ${d}\\).\n\nSo the next term is \\(${terms[3]} + (${d}) = ${correct}\\).`,
    };
  },
];

// ============================= PERCENTAGES =============================
const percentages = [
  // p% of N
  () => {
    const p = pick([5, 10, 12, 15, 20, 25, 30, 35, 40, 45, 50, 60, 75, 80]);
    const N = randInt(2, 60) * 20;
    const correct = N * p / 100;
    const o = buildOptions(correct, numericDistractors(correct, { scale: Math.max(1, correct * 0.2) }), (v) => fmtNum(v, 2));
    if (!o) return null;
    return {
      text: `Find ${p}% of ${N}.`,
      ...o,
      explanation: `\\(${p}\\% \\text{ of } ${N} = \\frac{${p}}{100} \\times ${N} = ${correct}\\)`,
    };
  },
  // express a as a percentage of b
  () => {
    const b = pick([20, 25, 40, 50, 80, 125, 200, 250, 400, 500]);
    const a = randInt(1, b - 1);
    const correct = a / b * 100;
    if (!Number.isInteger(round(correct, 2))) return null;
    const o = buildOptions(correct, [b / a * 100, correct + 10, correct / 2, correct * 2], (v) => `${fmtNum(v, 2)}%`);
    if (!o) return null;
    return {
      text: `Express ${a} as a percentage of ${b}.`,
      ...o,
      explanation: `\\(\\frac{${a}}{${b}} \\times 100\\% = ${fmtNum(correct, 2)}\\%\\)`,
    };
  },
  // percentage increase / decrease of a value
  () => {
    const N = randInt(10, 120) * 10;
    const p = pick([5, 10, 15, 20, 25, 40, 50]);
    const up = Math.random() < 0.5;
    const correct = up ? N * (100 + p) / 100 : N * (100 - p) / 100;
    const o = buildOptions(correct, [up ? N * (100 - p) / 100 : N * (100 + p) / 100, N + p, N - p, correct + N * p / 100],
      (v) => fmtNum(v, 2));
    if (!o) return null;
    return {
      text: `The price of an article is N${N}. If the price is ${up ? 'increased' : 'decreased'} by ${p}%, find the new price.`,
      ...o,
      explanation: `${up ? 'Increase' : 'Decrease'} \\(= \\frac{${p}}{100} \\times ${N} = ${N * p / 100}\\)\n\nNew price \\(= ${N} ${up ? '+' : '-'} ${N * p / 100} = ${correct}\\)\n\nSo the new price is N${correct}.`,
    };
  },
  // percentage profit
  () => {
    const cp = randInt(10, 90) * 10;
    const p = pick([10, 15, 20, 25, 30, 40, 50]);
    const profit = cp * p / 100;
    const sp = cp + profit;
    const o = buildOptions(p, [p + 5, p - 5, round(profit / sp * 100, 2), p * 2], (v) => `${fmtNum(v, 2)}%`);
    if (!o) return null;
    return {
      text: `An article bought for N${cp} was sold for N${sp}. Find the percentage profit.`,
      ...o,
      explanation: `Profit \\(= ${sp} - ${cp} = ${profit}\\)\n\nPercentage profit \\(= \\frac{\\text{profit}}{\\text{cost price}} \\times 100\\%\\)\n\n\\(= \\frac{${profit}}{${cp}} \\times 100\\% = ${p}\\%\\)`,
    };
  },
  // reverse percentage
  () => {
    const original = randInt(10, 80) * 10;
    const p = pick([10, 20, 25, 50]);
    const newVal = original * (100 + p) / 100;
    const o = buildOptions(original, [newVal * (100 - p) / 100, newVal - p, newVal / p * 100, original + p], (v) => fmtNum(v, 2));
    if (!o) return null;
    return {
      text: `After a ${p}% increase, the price of an item became N${newVal}. Find the original price.`,
      ...o,
      explanation: `Let the original price be \\(x\\).\n\n\\(x \\times \\frac{${100 + p}}{100} = ${newVal}\\)\n\n\\(x = \\frac{${newVal} \\times 100}{${100 + p}} = ${original}\\)\n\nSo the original price was N${original}.`,
    };
  },
  // percentage error
  () => {
    const actual = randInt(20, 200);
    const err = pick([1, 2, 4, 5]);
    const measured = actual + err;
    const correct = err / actual * 100;
    const o = buildOptions(correct, [err / measured * 100, correct * 2, correct / 2, err], (v) => `${fmtNum(v, 2)}%`);
    if (!o) return null;
    return {
      text: `The actual length of a rod is ${actual}cm but it was measured as ${measured}cm. Find the percentage error.`,
      ...o,
      explanation: `Error \\(= ${measured} - ${actual} = ${err}\\)cm\n\nPercentage error \\(= \\frac{\\text{error}}{\\text{actual value}} \\times 100\\%\\)\n\n\\(= \\frac{${err}}{${actual}} \\times 100\\% = ${fmtNum(correct, 2)}\\%\\)`,
    };
  },
  // percentage of students / word form
  () => {
    const total = pick([40, 50, 60, 80, 100, 120, 150, 200, 250]);
    const p = pick([10, 15, 20, 25, 30, 40, 60]);
    const correct = total * p / 100;
    if (!Number.isInteger(correct)) return null;
    const o = buildOptions(correct, [total - correct, correct + 5, correct * 2, correct / 2], (v) => fmtNum(v, 0));
    if (!o) return null;
    return {
      text: `In a class of ${total} students, ${p}% offer Mathematics. How many students offer Mathematics?`,
      ...o,
      explanation: `\\(\\frac{${p}}{100} \\times ${total} = ${correct}\\)\n\nSo ${correct} students offer Mathematics.`,
    };
  },
];

// ============================== VARIATION ==============================
const variation = [
  // direct variation
  () => {
    const k = randInt(2, 12);
    const x1 = randInt(2, 12), x2 = randInt(2, 20);
    if (x1 === x2) return null;
    const y1 = k * x1, y2 = k * x2;
    const o = buildOptions(y2, [x2 * y1 / (x1 * 2), y1 + x2, k + x2, y1 * x2], (v) => fmtNum(v, 2));
    if (!o) return null;
    return {
      text: `\\(y\\) varies directly as \\(x\\). If \\(y = ${y1}\\) when \\(x = ${x1}\\), find \\(y\\) when \\(x = ${x2}\\).`,
      ...o,
      explanation: `Direct variation: \\(y = kx\\).\n\n\\(${y1} = k \\times ${x1}\\), so \\(k = ${k}\\).\n\nWhen \\(x = ${x2}\\): \\(y = ${k} \\times ${x2} = ${y2}\\).`,
    };
  },
  // inverse variation
  () => {
    const k = randInt(2, 15) * 12;
    const x1 = pick([2, 3, 4, 6, 12]), x2 = pick([2, 3, 4, 6, 8, 12]);
    if (x1 === x2) return null;
    const y1 = k / x1, y2 = k / x2;
    if (!Number.isInteger(y1) || !Number.isInteger(y2)) return null;
    const o = buildOptions(y2, [y1 * x2 / x1, y1 + x2, k * x2, y1 - x2], (v) => fmtNum(v, 2));
    if (!o) return null;
    return {
      text: `\\(y\\) varies inversely as \\(x\\). If \\(y = ${y1}\\) when \\(x = ${x1}\\), find \\(y\\) when \\(x = ${x2}\\).`,
      ...o,
      explanation: `Inverse variation: \\(y = \\frac{k}{x}\\).\n\n\\(${y1} = \\frac{k}{${x1}}\\), so \\(k = ${y1} \\times ${x1} = ${k}\\).\n\nWhen \\(x = ${x2}\\): \\(y = \\frac{${k}}{${x2}} = ${y2}\\).`,
    };
  },
  // variation as the square
  () => {
    const k = randInt(2, 9);
    const x1 = randInt(2, 6), x2 = randInt(2, 8);
    if (x1 === x2) return null;
    const y1 = k * x1 * x1, y2 = k * x2 * x2;
    const o = buildOptions(y2, [k * x2, y1 * x2 / x1, y1 + x2 * x2, k * (x2 + 1) * (x2 + 1)], (v) => fmtNum(v, 2));
    if (!o) return null;
    return {
      text: `\\(y\\) varies directly as the square of \\(x\\). If \\(y = ${y1}\\) when \\(x = ${x1}\\), find \\(y\\) when \\(x = ${x2}\\).`,
      ...o,
      explanation: `\\(y = kx^{2}\\)\n\n\\(${y1} = k \\times ${x1}^{2} = ${x1 * x1}k\\), so \\(k = ${k}\\).\n\nWhen \\(x = ${x2}\\): \\(y = ${k} \\times ${x2}^{2} = ${k} \\times ${x2 * x2} = ${y2}\\).`,
    };
  },
  // joint variation
  () => {
    const k = randInt(2, 8);
    const x1 = randInt(2, 6), z1 = randInt(2, 6), x2 = randInt(2, 8), z2 = randInt(2, 8);
    const y1 = k * x1 * z1, y2 = k * x2 * z2;
    if (y1 === y2) return null;
    const o = buildOptions(y2, [k * x2 + z2, y1 * x2 * z2, k * (x2 + z2), y1 + x2 * z2], (v) => fmtNum(v, 2));
    if (!o) return null;
    return {
      text: `\\(y\\) varies jointly as \\(x\\) and \\(z\\). If \\(y = ${y1}\\) when \\(x = ${x1}\\) and \\(z = ${z1}\\), find \\(y\\) when \\(x = ${x2}\\) and \\(z = ${z2}\\).`,
      ...o,
      explanation: `Joint variation: \\(y = kxz\\).\n\n\\(${y1} = k \\times ${x1} \\times ${z1} = ${x1 * z1}k\\), so \\(k = ${k}\\).\n\nWhen \\(x = ${x2}\\) and \\(z = ${z2}\\): \\(y = ${k} \\times ${x2} \\times ${z2} = ${y2}\\).`,
    };
  },
  // find the constant of variation
  () => {
    const k = randInt(2, 15);
    const x1 = randInt(2, 12);
    const y1 = k * x1;
    const o = buildOptions(k, [y1 * x1, x1 / y1, k + 1, y1 + x1], (v) => fmtNum(v, 2));
    if (!o) return null;
    return {
      text: `If \\(y \\propto x\\) and \\(y = ${y1}\\) when \\(x = ${x1}\\), find the constant of variation.`,
      ...o,
      explanation: `\\(y = kx\\)\n\n\\(${y1} = k \\times ${x1}\\)\n\n\\(k = \\frac{${y1}}{${x1}} = ${k}\\)`,
    };
  },
  // inverse square variation
  () => {
    const x1 = pick([2, 3, 4, 5]), x2 = pick([2, 3, 4, 6]);
    if (x1 === x2) return null;
    const k = randInt(2, 10) * x1 * x1 * x2 * x2;
    const y1 = k / (x1 * x1), y2 = k / (x2 * x2);
    if (!Number.isInteger(y1) || !Number.isInteger(y2)) return null;
    const o = buildOptions(y2, [k / x2, y1 * x1 / x2, y1 / (x2 * x2), y1 + x2], (v) => fmtNum(v, 2));
    if (!o) return null;
    return {
      text: `\\(y\\) varies inversely as the square of \\(x\\). If \\(y = ${y1}\\) when \\(x = ${x1}\\), find \\(y\\) when \\(x = ${x2}\\).`,
      ...o,
      explanation: `\\(y = \\frac{k}{x^{2}}\\)\n\n\\(${y1} = \\frac{k}{${x1}^{2}}\\), so \\(k = ${y1} \\times ${x1 * x1} = ${k}\\).\n\nWhen \\(x = ${x2}\\): \\(y = \\frac{${k}}{${x2 * x2}} = ${y2}\\).`,
    };
  },
];

// ========================= FINANCIAL ARITHMETIC =========================
const financial = [
  // simple interest
  () => {
    const P = randInt(5, 60) * 1000;
    const R = pick([2, 2.5, 3, 4, 5, 6, 7.5, 8, 10, 12]);
    const T = randInt(2, 6);
    const correct = P * R * T / 100;
    const o = buildOptions(correct, [P * R / 100, correct + P, P * R * T / 1000, correct / T], (v) => fmtNum(v, 2));
    if (!o) return null;
    return {
      text: `Find the simple interest on N${P} for ${T} years at ${R}% per annum.`,
      ...o,
      explanation: `\\(I = \\frac{PRT}{100}\\)\n\n\\(I = \\frac{${P} \\times ${R} \\times ${T}}{100} = ${correct}\\)\n\nSo the simple interest is N${fmtNum(correct, 2)}.`,
    };
  },
  // amount after simple interest
  () => {
    const P = randInt(4, 50) * 1000;
    const R = pick([3, 4, 5, 6, 8, 10]);
    const T = randInt(2, 5);
    const I = P * R * T / 100;
    const correct = P + I;
    const o = buildOptions(correct, [I, P - I, P + I / T, P + P * R / 100], (v) => fmtNum(v, 2));
    if (!o) return null;
    return {
      text: `Find the amount that N${P} becomes after ${T} years at ${R}% per annum simple interest.`,
      ...o,
      explanation: `\\(I = \\frac{PRT}{100} = \\frac{${P} \\times ${R} \\times ${T}}{100} = ${I}\\)\n\nAmount \\(= P + I = ${P} + ${I} = ${correct}\\)\n\nSo the amount is N${fmtNum(correct, 2)}.`,
    };
  },
  // compound interest amount
  () => {
    const P = randInt(1, 20) * 10000;
    const R = pick([5, 10, 20]);
    const T = randInt(2, 3);
    const correct = round(P * Math.pow(1 + R / 100, T), 2);
    const simple = P + P * R * T / 100;
    const o = buildOptions(correct, [simple, round(P * Math.pow(1 + R / 100, T + 1), 2), round(correct - P, 2), P * R * T / 100],
      (v) => fmtNum(v, 2));
    if (!o) return null;
    return {
      text: `Find the amount on N${P} for ${T} years at ${R}% per annum compound interest.`,
      ...o,
      explanation: `\\(A = P\\left(1 + \\frac{R}{100}\\right)^{T}\\)\n\n\\(A = ${P}\\left(1 + \\frac{${R}}{100}\\right)^{${T}} = ${P}(${1 + R / 100})^{${T}}\\)\n\n\\(= ${fmtNum(correct, 2)}\\)\n\nSo the amount is N${fmtNum(correct, 2)}.`,
    };
  },
  // discount
  () => {
    const marked = randInt(10, 90) * 100;
    const d = pick([5, 10, 12.5, 15, 20, 25, 30]);
    const discount = marked * d / 100;
    const correct = marked - discount;
    const o = buildOptions(correct, [discount, marked + discount, marked - d, correct - discount], (v) => fmtNum(v, 2));
    if (!o) return null;
    return {
      text: `A shirt marked N${marked} is sold at a discount of ${d}%. Find the selling price.`,
      ...o,
      explanation: `Discount \\(= \\frac{${d}}{100} \\times ${marked} = ${discount}\\)\n\nSelling price \\(= ${marked} - ${discount} = ${correct}\\)\n\nSo the selling price is N${fmtNum(correct, 2)}.`,
    };
  },
  // commission
  () => {
    const sales = randInt(20, 200) * 1000;
    const rate = pick([2, 2.5, 3, 4, 5, 7.5, 10]);
    const correct = sales * rate / 100;
    const o = buildOptions(correct, [sales - correct, correct * 2, sales * rate / 1000, correct / 2], (v) => fmtNum(v, 2));
    if (!o) return null;
    return {
      text: `A salesman earns ${rate}% commission on sales. Find his commission on sales worth N${sales}.`,
      ...o,
      explanation: `Commission \\(= \\frac{${rate}}{100} \\times ${sales} = ${correct}\\)\n\nSo his commission is N${fmtNum(correct, 2)}.`,
    };
  },
  // depreciation
  () => {
    const P = randInt(10, 60) * 10000;
    const r = pick([10, 20, 25]);
    const T = randInt(2, 3);
    const correct = round(P * Math.pow(1 - r / 100, T), 2);
    const o = buildOptions(correct, [round(P * (1 - r * T / 100), 2), round(P * Math.pow(1 + r / 100, T), 2), round(P - r, 2), round(P * (1 - r / 100), 2)],
      (v) => fmtNum(v, 2));
    if (!o) return null;
    return {
      text: `A machine bought for N${P} depreciates at ${r}% per annum. Find its value after ${T} years.`,
      ...o,
      explanation: `\\(V = P\\left(1 - \\frac{r}{100}\\right)^{T}\\)\n\n\\(V = ${P}\\left(1 - \\frac{${r}}{100}\\right)^{${T}} = ${P}(${1 - r / 100})^{${T}}\\)\n\n\\(= ${fmtNum(correct, 2)}\\)\n\nSo its value is N${fmtNum(correct, 2)}.`,
    };
  },
  // find the rate given simple interest
  () => {
    const P = randInt(5, 40) * 1000;
    const R = pick([4, 5, 6, 8, 10]);
    const T = randInt(2, 5);
    const I = P * R * T / 100;
    const o = buildOptions(R, [R + 2, R - 2, round(I / P * 100, 2), R * T], (v) => `${fmtNum(v, 2)}%`);
    if (!o) return null;
    return {
      text: `The simple interest on N${P} for ${T} years is N${I}. Find the rate per annum.`,
      ...o,
      explanation: `\\(I = \\frac{PRT}{100}\\), so \\(R = \\frac{100I}{PT}\\).\n\n\\(R = \\frac{100 \\times ${I}}{${P} \\times ${T}} = ${R}\\)\n\nSo the rate is ${R}% per annum.`,
    };
  },
];

module.exports = [
  { topicId: 'sGeqO2FDw79otnkz3tz6', unitId: UNIT, topicName: 'Indices', generators: indices },
  { topicId: 'QaB0cznXJrMcrVjbCNb0', unitId: UNIT, topicName: 'Logarithms', generators: logarithms },
  { topicId: 'NjfU0QdBKJPAWpKSCjOX', unitId: UNIT, topicName: 'Fractions Decimals Approximations', generators: fractions },
  { topicId: 'pHB44xoytpLUReaJJnJd', unitId: UNIT, topicName: 'Sequence and Series', generators: sequences },
  { topicId: 'Gf8rPR6ODDduCSCzrFkQ', unitId: UNIT, topicName: 'Percentages', generators: percentages },
  { topicId: 'oM2AcopzHcWiTOriKncX', unitId: UNIT, topicName: 'Variation', generators: variation },
  { topicId: 'FezrgxGf71d05adRGcKu', unitId: UNIT, topicName: 'Financial Arithmetic', generators: financial },
];
