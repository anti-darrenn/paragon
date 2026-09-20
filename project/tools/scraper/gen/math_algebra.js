// Mathematics > Algebraic Processes
const L = require('./lib');
const { randInt, pick, shuffle, sample, nonZero, gcd, frac, fracTex, fracOpt,
        fmtNum, buildOptions, textOptions, round } = L;

const UNIT = 'VuzmbREuIrsItHNmU4Mt';
const mathOpt = (s) => `\\(${s}\\)`;

// renders ax^2 + bx + c
function quadTex(a, b, c, v = 'x') {
  let s = a === 1 ? `${v}^{2}` : a === -1 ? `-${v}^{2}` : `${a}${v}^{2}`;
  if (b !== 0) s += (b > 0 ? ' + ' : ' - ') + (Math.abs(b) === 1 ? v : `${Math.abs(b)}${v}`);
  if (c !== 0) s += (c > 0 ? ' + ' : ' - ') + Math.abs(c);
  return s;
}
// renders ax + b
function linTex(a, b, v = 'x') {
  let s = a === 1 ? v : a === -1 ? `-${v}` : `${a}${v}`;
  if (b !== 0) s += (b > 0 ? ' + ' : ' - ') + Math.abs(b);
  return s;
}
// (x + p) with correct sign
const bracket = (p, v = 'x') => p >= 0 ? `(${v} + ${p})` : `(${v} - ${-p})`;
const rootsStr = (r1, r2) => { const [a, b] = [r1, r2].sort((x, y) => x - y); return `${a} or ${b}`; };

// ======================== QUADRATIC EQUATIONS ========================
const quadratics = [
  // solve by factorisation (monic)
  () => {
    const r1 = nonZero(-9, 9), r2 = nonZero(-9, 9);
    if (r1 === r2) return null;
    const b = -(r1 + r2), c = r1 * r2;
    const o = buildOptions(rootsStr(r1, r2), [rootsStr(-r1, -r2), rootsStr(r1, -r2), rootsStr(-r1, r2)], (s) => s);
    if (!o) return null;
    return {
      text: `Solve the equation \\(${quadTex(1, b, c)} = 0\\).`,
      ...o,
      explanation: `Find two numbers whose product is ${c} and whose sum is ${b}.\n\nThese are ${-r1} and ${-r2}.\n\nSo \\(${quadTex(1, b, c)} = ${bracket(-r1)}${bracket(-r2)} = 0\\)\n\nTherefore \\(x = ${r1}\\) or \\(x = ${r2}\\).`,
    };
  },
  // sum and product of roots
  () => {
    const a = randInt(1, 5), b = nonZero(-12, 12), c = nonZero(-12, 12);
    const ask = pick(['sum', 'product']);
    const correct = ask === 'sum' ? frac(-b, a) : frac(c, a);
    const other = ask === 'sum' ? frac(c, a) : frac(-b, a);
    const o = buildOptions(correct, [other, frac(b, a), frac(-c, a)], (f) => fracOpt(f));
    if (!o) return null;
    return {
      text: `Find the ${ask} of the roots of the equation \\(${quadTex(a, b, c)} = 0\\).`,
      ...o,
      explanation: `For \\(ax^{2} + bx + c = 0\\), the sum of the roots is \\(-\\frac{b}{a}\\) and the product is \\(\\frac{c}{a}\\).\n\nHere \\(a = ${a}\\), \\(b = ${b}\\), \\(c = ${c}\\).\n\n${ask === 'sum' ? `Sum \\(= -\\frac{${b}}{${a}} = ${fracTex(correct)}\\)` : `Product \\(= \\frac{${c}}{${a}} = ${fracTex(correct)}\\)`}`,
    };
  },
  // form the equation from given roots
  () => {
    const r1 = nonZero(-8, 8), r2 = nonZero(-8, 8);
    if (r1 === r2) return null;
    const b = -(r1 + r2), c = r1 * r2;
    const correct = `${quadTex(1, b, c)} = 0`;
    const wrongs = [
      `${quadTex(1, -b, c)} = 0`,
      `${quadTex(1, b, -c)} = 0`,
      `${quadTex(1, -b, -c)} = 0`,
    ];
    const o = textOptions(mathOpt(correct), wrongs.map(mathOpt));
    if (!o) return null;
    return {
      text: `Find the quadratic equation whose roots are ${r1} and ${r2}.`,
      ...o,
      explanation: `If the roots are \\(\\alpha\\) and \\(\\beta\\), the equation is \\(x^{2} - (\\alpha + \\beta)x + \\alpha\\beta = 0\\).\n\nSum \\(= ${r1} + (${r2}) = ${r1 + r2}\\)\n\nProduct \\(= ${r1} \\times ${r2} = ${c}\\)\n\nSo the equation is \\(${correct}\\).`,
    };
  },
  // discriminant / nature of roots
  () => {
    const a = randInt(1, 4), b = nonZero(-10, 10), c = nonZero(-8, 10);
    const D = b * b - 4 * a * c;
    const nature = D > 0 ? 'Real and distinct' : D === 0 ? 'Real and equal' : 'No real roots';
    const o = textOptions(nature, ['Real and distinct', 'Real and equal', 'No real roots', 'Equal and imaginary'].filter(x => x !== nature).slice(0, 3));
    if (!o) return null;
    return {
      text: `Determine the nature of the roots of \\(${quadTex(a, b, c)} = 0\\).`,
      ...o,
      explanation: `The discriminant is \\(b^{2} - 4ac\\).\n\n\\(= (${b})^{2} - 4(${a})(${c}) = ${b * b} ${4 * a * c < 0 ? `+ ${-4 * a * c}` : `- ${4 * a * c}`} = ${D}\\)\n\nSince the discriminant is ${D > 0 ? 'positive' : D === 0 ? 'zero' : 'negative'}, the roots are ${D > 0 ? 'real and distinct' : D === 0 ? 'real and equal' : 'not real'}.`,
    };
  },
  // solve a non-monic quadratic with integer roots
  () => {
    const a = randInt(2, 4);
    const r1 = nonZero(-6, 6);
    const p = randInt(1, 5);                     // second root = p/a form avoided: use integer roots
    const r2 = nonZero(-6, 6);
    if (r1 === r2) return null;
    const b = -a * (r1 + r2), c = a * r1 * r2;
    const o = buildOptions(rootsStr(r1, r2), [rootsStr(-r1, -r2), rootsStr(r1, -r2), rootsStr(-r1, r2)], (s) => s);
    if (!o) return null;
    return {
      text: `Solve the equation \\(${quadTex(a, b, c)} = 0\\).`,
      ...o,
      explanation: `Divide through by ${a}: \\(${quadTex(1, b / a, c / a)} = 0\\)\n\nFactorising: \\(${bracket(-r1)}${bracket(-r2)} = 0\\)\n\nSo \\(x = ${r1}\\) or \\(x = ${r2}\\).`,
    };
  },
  // one root given, find the other
  () => {
    const r1 = nonZero(-8, 8), r2 = nonZero(-8, 8);
    if (r1 === r2) return null;
    const b = -(r1 + r2), c = r1 * r2;
    const o = buildOptions(r2, [-r2, r2 + 1, r2 - 1, c], (v) => String(v));
    if (!o) return null;
    return {
      text: `If \\(x = ${r1}\\) is one root of \\(${quadTex(1, b, c)} = 0\\), find the other root.`,
      ...o,
      explanation: `The product of the roots is \\(\\frac{c}{a} = ${c}\\).\n\nIf one root is ${r1}, the other root is \\(\\frac{${c}}{${r1}} = ${r2}\\).`,
    };
  },
];

// ============ GRAPHS OF LINEAR AND QUADRATIC FUNCTIONS ============
const graphs = [
  // gradient from y = mx + c
  () => {
    const m = nonZero(-9, 9), c = randInt(-12, 12);
    const o = buildOptions(m, [c, -m, m + 1, 1 / m], (v) => fmtNum(v, 2));
    if (!o) return null;
    return {
      text: `Find the gradient of the line \\(y = ${linTex(m, c)}\\).`,
      ...o,
      explanation: `A straight line written as \\(y = mx + c\\) has gradient \\(m\\).\n\nComparing \\(y = ${linTex(m, c)}\\) with \\(y = mx + c\\), the gradient is ${m}.`,
    };
  },
  // y-intercept
  () => {
    const m = nonZero(-9, 9), c = nonZero(-14, 14);
    const o = buildOptions(c, [m, -c, c + m, 0], (v) => fmtNum(v, 2));
    if (!o) return null;
    return {
      text: `Find the y-intercept of the line \\(y = ${linTex(m, c)}\\).`,
      ...o,
      explanation: `The y-intercept is the value of \\(y\\) when \\(x = 0\\).\n\n\\(y = ${m}(0) ${c > 0 ? '+' : '-'} ${Math.abs(c)} = ${c}\\)\n\nSo the y-intercept is ${c}.`,
    };
  },
  // gradient from ax + by + c = 0
  () => {
    const a = nonZero(-8, 8), b = nonZero(-8, 8), c = randInt(-10, 10);
    const grad = frac(-a, b);
    const o = buildOptions(grad, [frac(a, b), frac(b, a), frac(-b, a)], (f) => fracOpt(f));
    if (!o) return null;
    return {
      text: `Find the gradient of the line \\(${linTex(a, 0)} ${b > 0 ? '+' : '-'} ${Math.abs(b) === 1 ? 'y' : `${Math.abs(b)}y`} ${c >= 0 ? '+' : '-'} ${Math.abs(c)} = 0\\).`,
      ...o,
      explanation: `Rearrange into the form \\(y = mx + c\\).\n\n\\(${b}y = ${-a}x ${-c >= 0 ? '+' : '-'} ${Math.abs(c)}\\)\n\n\\(y = \\frac{${-a}}{${b}}x + \\dots\\)\n\nSo the gradient is \\(${fracTex(grad)}\\).`,
    };
  },
  // axis of symmetry / turning point x-value
  () => {
    const a = pick([1, 1, 2, -1, 3]);
    const b = nonZero(-12, 12);
    const c = randInt(-10, 10);
    const x = frac(-b, 2 * a);
    const o = buildOptions(x, [frac(b, 2 * a), frac(-b, a), frac(b, a)], (f) => fracOpt(f));
    if (!o) return null;
    return {
      text: `Find the equation of the axis of symmetry of the curve \\(y = ${quadTex(a, b, c)}\\).`,
      ...o,
      explanation: `The axis of symmetry of \\(y = ax^{2} + bx + c\\) is \\(x = -\\frac{b}{2a}\\).\n\n\\(x = -\\frac{${b}}{2(${a})} = ${fracTex(x)}\\)`,
    };
  },
  // minimum / maximum value
  () => {
    const a = pick([1, 2, -1, -2]);
    const h = randInt(-6, 6), k = randInt(-12, 12);
    // y = a(x-h)^2 + k  ->  expand
    const b = -2 * a * h, c = a * h * h + k;
    const isMin = a > 0;
    const o = buildOptions(k, [-k, h, k + a, c], (v) => String(v));
    if (!o) return null;
    return {
      text: `Find the ${isMin ? 'minimum' : 'maximum'} value of \\(y = ${quadTex(a, b, c)}\\).`,
      ...o,
      explanation: `Complete the square: \\(y = ${a}(x ${-h >= 0 ? '+' : '-'} ${Math.abs(h)})^{2} ${k >= 0 ? '+' : '-'} ${Math.abs(k)}\\)\n\nSince \\(a = ${a}\\) is ${a > 0 ? 'positive' : 'negative'}, the curve has a ${isMin ? 'minimum' : 'maximum'} at the turning point.\n\nThe ${isMin ? 'minimum' : 'maximum'} value of \\(y\\) is ${k}.`,
    };
  },
  // roots from a factorised graph
  () => {
    const r1 = nonZero(-7, 7), r2 = nonZero(-7, 7);
    if (r1 === r2) return null;
    const o = buildOptions(rootsStr(r1, r2), [rootsStr(-r1, -r2), rootsStr(r1, -r2), rootsStr(-r1, r2)], (s) => s);
    if (!o) return null;
    return {
      text: `Find the values of \\(x\\) where the curve \\(y = ${bracket(-r1)}${bracket(-r2)}\\) crosses the x-axis.`,
      ...o,
      explanation: `The curve crosses the x-axis where \\(y = 0\\).\n\n\\(${bracket(-r1)}${bracket(-r2)} = 0\\)\n\nSo \\(x = ${r1}\\) or \\(x = ${r2}\\).`,
    };
  },
];

// ====================== CHANGE OF SUBJECT ======================
const FORMULA_BANK = [
  { f: 'A = \\pi r^{2}', v: 'r', ans: 'r = \\sqrt{\\frac{A}{\\pi}}', w: ['r = \\frac{A}{\\pi}', 'r = \\frac{\\sqrt{A}}{\\pi}', 'r = \\pi\\sqrt{A}'], how: 'Divide both sides by \\(\\pi\\), then take the square root.' },
  { f: 'V = \\frac{1}{3}\\pi r^{2} h', v: 'h', ans: 'h = \\frac{3V}{\\pi r^{2}}', w: ['h = \\frac{V}{3\\pi r^{2}}', 'h = \\frac{3V}{\\pi r}', 'h = \\frac{\\pi r^{2}}{3V}'], how: 'Multiply both sides by 3, then divide by \\(\\pi r^{2}\\).' },
  { f: 'E = mc^{2}', v: 'c', ans: 'c = \\sqrt{\\frac{E}{m}}', w: ['c = \\frac{E}{m}', 'c = \\frac{\\sqrt{E}}{m}', 'c = \\frac{E^{2}}{m}'], how: 'Divide both sides by \\(m\\), then take the square root.' },
  { f: 'v = u + at', v: 't', ans: 't = \\frac{v - u}{a}', w: ['t = \\frac{v + u}{a}', 't = \\frac{u - v}{a}', 't = a(v - u)'], how: 'Subtract \\(u\\) from both sides, then divide by \\(a\\).' },
  { f: 'v^{2} = u^{2} + 2as', v: 's', ans: 's = \\frac{v^{2} - u^{2}}{2a}', w: ['s = \\frac{v^{2} + u^{2}}{2a}', 's = \\frac{v - u}{2a}', 's = 2a(v^{2} - u^{2})'], how: 'Subtract \\(u^{2}\\), then divide by \\(2a\\).' },
  { f: 'A = \\frac{1}{2}bh', v: 'h', ans: 'h = \\frac{2A}{b}', w: ['h = \\frac{A}{2b}', 'h = \\frac{b}{2A}', 'h = 2Ab'], how: 'Multiply both sides by 2, then divide by \\(b\\).' },
  { f: 'S = \\frac{n}{2}(a + l)', v: 'l', ans: 'l = \\frac{2S}{n} - a', w: ['l = \\frac{2S}{n} + a', 'l = \\frac{S}{2n} - a', 'l = \\frac{2S - a}{n}'], how: 'Multiply by 2, divide by \\(n\\), then subtract \\(a\\).' },
  { f: 'T = 2\\pi\\sqrt{\\frac{l}{g}}', v: 'l', ans: 'l = \\frac{gT^{2}}{4\\pi^{2}}', w: ['l = \\frac{T^{2}}{4\\pi^{2}g}', 'l = \\frac{gT}{2\\pi}', 'l = \\frac{4\\pi^{2}}{gT^{2}}'], how: 'Divide by \\(2\\pi\\), square both sides, then multiply by \\(g\\).' },
  { f: 'I = \\frac{PRT}{100}', v: 'R', ans: 'R = \\frac{100I}{PT}', w: ['R = \\frac{I}{100PT}', 'R = \\frac{PT}{100I}', 'R = \\frac{100PT}{I}'], how: 'Multiply both sides by 100, then divide by \\(PT\\).' },
  { f: '\\frac{1}{f} = \\frac{1}{u} + \\frac{1}{v}', v: 'v', ans: 'v = \\frac{uf}{u - f}', w: ['v = \\frac{uf}{u + f}', 'v = \\frac{u - f}{uf}', 'v = u - f'], how: 'Make \\(\\frac{1}{v}\\) the subject, combine the fractions, then invert.' },
  { f: 'C = \\frac{5}{9}(F - 32)', v: 'F', ans: 'F = \\frac{9C}{5} + 32', w: ['F = \\frac{5C}{9} + 32', 'F = \\frac{9C}{5} - 32', 'F = \\frac{9(C + 32)}{5}'], how: 'Multiply by \\(\\frac{9}{5}\\), then add 32.' },
  { f: 'P = 2(l + b)', v: 'b', ans: 'b = \\frac{P}{2} - l', w: ['b = \\frac{P - l}{2}', 'b = \\frac{P}{2} + l', 'b = 2P - l'], how: 'Divide both sides by 2, then subtract \\(l\\).' },
  { f: 'A = P\\left(1 + \\frac{r}{100}\\right)', v: 'r', ans: 'r = 100\\left(\\frac{A}{P} - 1\\right)', w: ['r = \\frac{100A}{P}', 'r = \\frac{A - P}{100}', 'r = 100\\left(\\frac{P}{A} - 1\\right)'], how: 'Divide by \\(P\\), subtract 1, then multiply by 100.' },
  { f: 'y = \\frac{a}{x} + b', v: 'x', ans: 'x = \\frac{a}{y - b}', w: ['x = \\frac{a}{y + b}', 'x = \\frac{y - b}{a}', 'x = a(y - b)'], how: 'Subtract \\(b\\), then take the reciprocal and multiply by \\(a\\).' },
];

const changeSubject = [
  // symbolic bank
  () => {
    const x = pick(FORMULA_BANK);
    const o = textOptions(mathOpt(x.ans), x.w.map(mathOpt));
    if (!o) return null;
    return {
      text: `Make \\(${x.v}\\) the subject of the formula \\(${x.f}\\).`,
      ...o,
      explanation: `${x.how}\n\nThis gives \\(${x.ans}\\).`,
    };
  },
  // parameterised: y = ax + b
  () => {
    const a = randInt(2, 15), b = nonZero(-20, 20);
    const correct = `x = \\frac{y ${b > 0 ? '-' : '+'} ${Math.abs(b)}}{${a}}`;
    const wrongs = [
      `x = \\frac{y ${b > 0 ? '+' : '-'} ${Math.abs(b)}}{${a}}`,
      `x = ${a}y ${b > 0 ? '-' : '+'} ${Math.abs(b)}`,
      `x = \\frac{${a}}{y ${b > 0 ? '-' : '+'} ${Math.abs(b)}}`,
    ];
    const o = textOptions(mathOpt(correct), wrongs.map(mathOpt));
    if (!o) return null;
    return {
      text: `Make \\(x\\) the subject of the formula \\(y = ${linTex(a, b)}\\).`,
      ...o,
      explanation: `\\(y = ${linTex(a, b)}\\)\n\n${b > 0 ? 'Subtract' : 'Add'} ${Math.abs(b)} ${b > 0 ? 'from' : 'to'} both sides: \\(y ${b > 0 ? '-' : '+'} ${Math.abs(b)} = ${a}x\\)\n\nDivide both sides by ${a}: \\(${correct}\\)`,
    };
  },
  // parameterised: y = (x + b)/a
  () => {
    const a = randInt(2, 12), b = nonZero(-15, 15);
    const correct = `x = ${a}y ${b > 0 ? '-' : '+'} ${Math.abs(b)}`;
    const wrongs = [
      `x = ${a}y ${b > 0 ? '+' : '-'} ${Math.abs(b)}`,
      `x = \\frac{y ${b > 0 ? '-' : '+'} ${Math.abs(b)}}{${a}}`,
      `x = \\frac{${a}}{y} ${b > 0 ? '-' : '+'} ${Math.abs(b)}`,
    ];
    const o = textOptions(mathOpt(correct), wrongs.map(mathOpt));
    if (!o) return null;
    return {
      text: `Make \\(x\\) the subject of the formula \\(y = \\frac{x ${b > 0 ? '+' : '-'} ${Math.abs(b)}}{${a}}\\).`,
      ...o,
      explanation: `Multiply both sides by ${a}: \\(${a}y = x ${b > 0 ? '+' : '-'} ${Math.abs(b)}\\)\n\n${b > 0 ? 'Subtract' : 'Add'} ${Math.abs(b)}: \\(${correct}\\)`,
    };
  },
];

// ====================== ALGEBRAIC EXPRESSIONS ======================
const expressions = [
  // evaluate an expression
  () => {
    const x = nonZero(-6, 6), y = nonZero(-6, 6);
    const a = randInt(2, 6), b = randInt(2, 6);
    const correct = a * x * x - b * y;
    const o = buildOptions(correct, [a * x * x + b * y, -correct, a * x - b * y, correct + a], (v) => String(v));
    if (!o) return null;
    return {
      text: `If \\(x = ${x}\\) and \\(y = ${y}\\), evaluate \\(${a}x^{2} - ${b}y\\).`,
      ...o,
      explanation: `Substitute \\(x = ${x}\\) and \\(y = ${y}\\).\n\n\\(${a}(${x})^{2} - ${b}(${y})\\)\n\n\\(= ${a}(${x * x}) - (${b * y})\\)\n\n\\(= ${a * x * x} - (${b * y}) = ${correct}\\)`,
    };
  },
  // simplify by collecting like terms
  () => {
    const a1 = nonZero(-9, 9), a2 = nonZero(-9, 9), b1 = nonZero(-9, 9), b2 = nonZero(-9, 9);
    const ca = a1 + a2, cb = b1 + b2;
    if (ca === 0 || cb === 0) return null;
    const fmt = (p) => {
      const [A, B] = p;
      let s = A === 1 ? 'x' : A === -1 ? '-x' : `${A}x`;
      s += (B > 0 ? ' + ' : ' - ') + (Math.abs(B) === 1 ? 'y' : `${Math.abs(B)}y`);
      return mathOpt(s);
    };
    const o = buildOptions([ca, cb], [[ca, -cb], [a1 - a2, cb], [ca + 1, cb], [ca, cb + 1]], fmt);
    if (!o) return null;
    const t = (c, v) => (c === 1 ? v : c === -1 ? `-${v}` : `${c}${v}`);
    return {
      text: `Simplify \\(${t(a1, 'x')} ${b1 > 0 ? '+' : '-'} ${Math.abs(b1) === 1 ? 'y' : `${Math.abs(b1)}y`} ${a2 > 0 ? '+' : '-'} ${Math.abs(a2) === 1 ? 'x' : `${Math.abs(a2)}x`} ${b2 > 0 ? '+' : '-'} ${Math.abs(b2) === 1 ? 'y' : `${Math.abs(b2)}y`}\\).`,
      ...o,
      explanation: `Collect the \\(x\\) terms and the \\(y\\) terms separately.\n\n\\(x\\) terms: \\(${a1} + (${a2}) = ${ca}\\)\n\n\\(y\\) terms: \\(${b1} + (${b2}) = ${cb}\\)\n\nSo the expression simplifies to \\(${t(ca, 'x')} ${cb > 0 ? '+' : '-'} ${Math.abs(cb) === 1 ? 'y' : `${Math.abs(cb)}y`}\\).`,
    };
  },
  // substitute into a fraction
  () => {
    const x = randInt(2, 10), a = randInt(1, 9), b = randInt(1, 9);
    const den = x + b;
    if (den === 0) return null;
    const correct = frac(a * x, den);
    const o = buildOptions(correct, [frac(a * x, x - b), frac(x, a * b), frac(a + x, den)], (f) => fracOpt(f));
    if (!o) return null;
    return {
      text: `If \\(x = ${x}\\), evaluate \\(\\frac{${a}x}{x + ${b}}\\).`,
      ...o,
      explanation: `Substitute \\(x = ${x}\\).\n\n\\(\\frac{${a}(${x})}{${x} + ${b}} = \\frac{${a * x}}{${den}}\\)\n\n\\(= ${fracTex(correct)}\\)`,
    };
  },
  // expand and simplify a bracket expression
  () => {
    const a = randInt(2, 8), b = nonZero(-9, 9), c = randInt(2, 8);
    // a(x + b) + cx
    const cx = a + c, con = a * b;
    const o = buildOptions([cx, con], [[a * c, con], [cx, a + b], [cx + 1, con], [cx, con + 1]],
      (p) => mathOpt(linTex(p[0], p[1])));
    if (!o) return null;
    return {
      text: `Simplify \\(${a}(x ${b > 0 ? '+' : '-'} ${Math.abs(b)}) + ${c}x\\).`,
      ...o,
      explanation: `Expand the bracket: \\(${a}x ${con > 0 ? '+' : '-'} ${Math.abs(con)} + ${c}x\\)\n\nCollect the \\(x\\) terms: \\(${a}x + ${c}x = ${cx}x\\)\n\nSo the answer is \\(${linTex(cx, con)}\\).`,
    };
  },
];

// ==================== EXPANSION AND FACTORISATION ====================
const expansion = [
  // expand (x + a)(x + b)
  () => {
    const a = nonZero(-9, 9), b = nonZero(-9, 9);
    const B = a + b, C = a * b;
    const o = buildOptions([B, C], [[B, -C], [a * b, a + b], [B + 1, C], [-B, C]],
      (p) => mathOpt(quadTex(1, p[0], p[1])));
    if (!o) return null;
    return {
      text: `Expand \\(${bracket(a)}${bracket(b)}\\).`,
      ...o,
      explanation: `Multiply each term in the first bracket by each term in the second.\n\n\\(x \\times x = x^{2}\\)\n\n\\(x \\times (${b}) + (${a}) \\times x = ${B}x\\)\n\n\\((${a}) \\times (${b}) = ${C}\\)\n\nSo the expansion is \\(${quadTex(1, B, C)}\\).`,
    };
  },
  // factorise a monic quadratic
  () => {
    const a = nonZero(-9, 9), b = nonZero(-9, 9);
    const B = a + b, C = a * b;
    const correct = `${bracket(a)}${bracket(b)}`;
    const wrongs = [
      `${bracket(-a)}${bracket(-b)}`,
      `${bracket(a)}${bracket(-b)}`,
      `${bracket(-a)}${bracket(b)}`,
    ];
    const o = textOptions(mathOpt(correct), wrongs.map(mathOpt));
    if (!o) return null;
    return {
      text: `Factorise \\(${quadTex(1, B, C)}\\).`,
      ...o,
      explanation: `Find two numbers whose product is ${C} and whose sum is ${B}.\n\nThese are ${a} and ${b}.\n\nSo \\(${quadTex(1, B, C)} = ${correct}\\).`,
    };
  },
  // difference of two squares
  () => {
    const a = randInt(2, 12);
    const k = randInt(1, 6);
    const sq = a * a, ksq = k * k;
    const correct = `(${k === 1 ? 'x' : `${k}x`} + ${a})(${k === 1 ? 'x' : `${k}x`} - ${a})`;
    const wrongs = [
      `(${k === 1 ? 'x' : `${k}x`} + ${a})^{2}`,
      `(${k === 1 ? 'x' : `${k}x`} - ${a})^{2}`,
      `(${k === 1 ? 'x' : `${k}x`} + ${a * a})(${k === 1 ? 'x' : `${k}x`} - ${a * a})`,
    ];
    const o = textOptions(mathOpt(correct), wrongs.map(mathOpt));
    if (!o) return null;
    return {
      text: `Factorise \\(${ksq === 1 ? 'x^{2}' : `${ksq}x^{2}`} - ${sq}\\).`,
      ...o,
      explanation: `This is a difference of two squares: \\(a^{2} - b^{2} = (a+b)(a-b)\\).\n\n\\(${ksq === 1 ? 'x^{2}' : `${ksq}x^{2}`} = (${k === 1 ? 'x' : `${k}x`})^{2}\\) and \\(${sq} = ${a}^{2}\\)\n\nSo the factorisation is \\(${correct}\\).`,
    };
  },
  // factorise by common factor
  () => {
    const k = randInt(2, 9), a = randInt(2, 9), b = nonZero(-9, 9);
    const correct = `${k}(${a === 1 ? 'x' : `${a}x`} ${b > 0 ? '+' : '-'} ${Math.abs(b)})`;
    const wrongs = [
      `${k}(${a === 1 ? 'x' : `${a}x`} ${b > 0 ? '-' : '+'} ${Math.abs(b)})`,
      `${k * a}(x ${b > 0 ? '+' : '-'} ${Math.abs(b)})`,
      `${k}x(${a} ${b > 0 ? '+' : '-'} ${Math.abs(b)})`,
    ];
    const o = textOptions(mathOpt(correct), wrongs.map(mathOpt));
    if (!o) return null;
    return {
      text: `Factorise \\(${k * a}x ${k * b > 0 ? '+' : '-'} ${Math.abs(k * b)}\\).`,
      ...o,
      explanation: `The highest common factor of ${k * a} and ${Math.abs(k * b)} is ${k}.\n\nTaking ${k} outside the bracket: \\(${correct}\\).`,
    };
  },
  // expand (ax + b)(cx + d)
  () => {
    const a = randInt(2, 5), b = nonZero(-7, 7), c = randInt(2, 5), d = nonZero(-7, 7);
    const A = a * c, B = a * d + b * c, C = b * d;
    const o = buildOptions([A, B, C], [[A, B, -C], [A, a * d - b * c, C], [A + 1, B, C], [A, B + 1, C]],
      (p) => mathOpt(quadTex(p[0], p[1], p[2])));
    if (!o) return null;
    return {
      text: `Expand \\((${linTex(a, b)})(${linTex(c, d)})\\).`,
      ...o,
      explanation: `Multiply term by term.\n\n\\(${a}x \\times ${c}x = ${A}x^{2}\\)\n\n\\(${a}x \\times (${d}) + (${b}) \\times ${c}x = ${a * d}x + ${b * c}x = ${B}x\\)\n\n\\((${b}) \\times (${d}) = ${C}\\)\n\nSo the expansion is \\(${quadTex(A, B, C)}\\).`,
    };
  },
  // expand a perfect square
  () => {
    const a = randInt(1, 6), b = nonZero(-9, 9);
    const A = a * a, B = 2 * a * b, C = b * b;
    const o = buildOptions([A, B, C], [[A, B / 2, C], [A, -B, C], [A, B, -C], [A, B + 1, C]],
      (p) => mathOpt(quadTex(p[0], p[1], p[2])));
    if (!o) return null;
    return {
      text: `Expand \\((${linTex(a, b)})^{2}\\).`,
      ...o,
      explanation: `\\((p + q)^{2} = p^{2} + 2pq + q^{2}\\)\n\n\\((${a}x)^{2} = ${A}x^{2}\\)\n\n\\(2 \\times ${a}x \\times (${b}) = ${B}x\\)\n\n\\((${b})^{2} = ${C}\\)\n\nSo the expansion is \\(${quadTex(A, B, C)}\\).`,
    };
  },
];

// ========================= LINEAR EQUATIONS =========================
const linear = [
  // solve ax + b = c
  () => {
    const a = nonZero(-12, 12), x = nonZero(-12, 12), b = nonZero(-20, 20);
    if (Math.abs(a) === 1 && Math.random() < 0.5) return null;
    const c = a * x + b;
    const o = buildOptions(x, [-x, x + 1, x - 1, frac(c + b, a).n / frac(c + b, a).d], (v) => fmtNum(v, 2));
    if (!o) return null;
    return {
      text: `Solve the equation \\(${linTex(a, b)} = ${c}\\).`,
      ...o,
      explanation: `\\(${linTex(a, b)} = ${c}\\)\n\n${b > 0 ? 'Subtract' : 'Add'} ${Math.abs(b)} ${b > 0 ? 'from' : 'to'} both sides: \\(${a}x = ${c - b}\\)\n\nDivide both sides by ${a}: \\(x = \\frac{${c - b}}{${a}} = ${x}\\)`,
    };
  },
  // solve with brackets
  () => {
    const a = randInt(2, 9), b = nonZero(-9, 9), x = nonZero(-9, 9), c = randInt(2, 9);
    const rhs = a * (x + b) + c * x;
    const total = a + c;
    const o = buildOptions(x, [-x, x + 1, x - 2, rhs], (v) => fmtNum(v, 2));
    if (!o) return null;
    return {
      text: `Solve the equation \\(${a}(x ${b > 0 ? '+' : '-'} ${Math.abs(b)}) + ${c}x = ${rhs}\\).`,
      ...o,
      explanation: `Expand the bracket: \\(${a}x ${a * b > 0 ? '+' : '-'} ${Math.abs(a * b)} + ${c}x = ${rhs}\\)\n\nCollect like terms: \\(${total}x ${a * b > 0 ? '+' : '-'} ${Math.abs(a * b)} = ${rhs}\\)\n\n\\(${total}x = ${rhs - a * b}\\)\n\n\\(x = \\frac{${rhs - a * b}}{${total}} = ${x}\\)`,
    };
  },
  // simultaneous equations
  () => {
    const x = nonZero(-8, 8), y = nonZero(-8, 8);
    const a1 = nonZero(-6, 6), b1 = nonZero(-6, 6), a2 = nonZero(-6, 6), b2 = nonZero(-6, 6);
    const det = a1 * b2 - a2 * b1;
    if (det === 0) return null;
    const c1 = a1 * x + b1 * y, c2 = a2 * x + b2 * y;
    const fmtPair = (p) => mathOpt(`x = ${p[0]}, y = ${p[1]}`);
    const o = buildOptions([x, y], [[y, x], [-x, -y], [x + 1, y - 1]], fmtPair);
    if (!o) return null;
    return {
      text: `Solve the simultaneous equations: \\(${linTex(a1, 0)} ${b1 > 0 ? '+' : '-'} ${Math.abs(b1) === 1 ? 'y' : `${Math.abs(b1)}y`} = ${c1}\\) and \\(${linTex(a2, 0)} ${b2 > 0 ? '+' : '-'} ${Math.abs(b2) === 1 ? 'y' : `${Math.abs(b2)}y`} = ${c2}\\).`,
      ...o,
      explanation: `Use elimination. Multiply the first equation by ${a2} and the second by ${a1} to match the \\(x\\) coefficients.\n\nSubtracting eliminates \\(x\\) and gives \\(y = ${y}\\).\n\nSubstituting \\(y = ${y}\\) into the first equation: \\(${a1}x ${b1 * y > 0 ? '+' : '-'} ${Math.abs(b1 * y)} = ${c1}\\), so \\(x = ${x}\\).`,
    };
  },
  // word problem: consecutive numbers
  () => {
    const n = randInt(5, 60);
    const total = n + (n + 1) + (n + 2);
    const o = buildOptions(n, [n + 1, n - 1, total / 3 + 1, n + 2], (v) => String(v));
    if (!o) return null;
    return {
      text: `The sum of three consecutive whole numbers is ${total}. Find the smallest of the numbers.`,
      ...o,
      explanation: `Let the numbers be \\(n\\), \\(n+1\\) and \\(n+2\\).\n\n\\(n + (n+1) + (n+2) = ${total}\\)\n\n\\(3n + 3 = ${total}\\)\n\n\\(3n = ${total - 3}\\), so \\(n = ${n}\\).`,
    };
  },
  // solve equation with fractions
  () => {
    const d = randInt(2, 6), x = nonZero(-10, 10), b = nonZero(-10, 10);
    const rhs = x / d + b;
    if (!Number.isInteger(rhs)) return null;
    const o = buildOptions(x, [-x, x + d, x * d, rhs], (v) => fmtNum(v, 2));
    if (!o) return null;
    return {
      text: `Solve the equation \\(\\frac{x}{${d}} ${b > 0 ? '+' : '-'} ${Math.abs(b)} = ${rhs}\\).`,
      ...o,
      explanation: `${b > 0 ? 'Subtract' : 'Add'} ${Math.abs(b)}: \\(\\frac{x}{${d}} = ${rhs - b}\\)\n\nMultiply both sides by ${d}: \\(x = ${d} \\times ${rhs - b} = ${x}\\)`,
    };
  },
  // age word problem
  () => {
    const childAge = randInt(5, 20), k = randInt(2, 4);
    const parentAge = childAge * k;
    const total = childAge + parentAge;
    const o = buildOptions(childAge, [parentAge, total / 2, childAge + k, parentAge - childAge], (v) => `${v} years`);
    if (!o) return null;
    return {
      text: `A father is ${k} times as old as his son. If the sum of their ages is ${total} years, how old is the son?`,
      ...o,
      explanation: `Let the son's age be \\(x\\).\n\nThe father's age is \\(${k}x\\).\n\n\\(x + ${k}x = ${total}\\)\n\n\\(${k + 1}x = ${total}\\), so \\(x = ${childAge}\\) years.`,
    };
  },
];

// ====================== FUNCTIONS AND RELATIONS ======================
const functions = [
  // evaluate a linear function
  () => {
    const a = nonZero(-9, 9), b = nonZero(-12, 12), k = nonZero(-8, 8);
    const correct = a * k + b;
    const o = buildOptions(correct, [a * k - b, -correct, a + b * k, correct + a], (v) => String(v));
    if (!o) return null;
    return {
      text: `If \\(f(x) = ${linTex(a, b)}\\), find \\(f(${k})\\).`,
      ...o,
      explanation: `Substitute \\(x = ${k}\\).\n\n\\(f(${k}) = ${a}(${k}) ${b > 0 ? '+' : '-'} ${Math.abs(b)}\\)\n\n\\(= ${a * k} ${b > 0 ? '+' : '-'} ${Math.abs(b)} = ${correct}\\)`,
    };
  },
  // evaluate a quadratic function
  () => {
    const a = randInt(1, 5), b = nonZero(-8, 8), c = nonZero(-10, 10), k = nonZero(-5, 5);
    const correct = a * k * k + b * k + c;
    const o = buildOptions(correct, [a * k * k - b * k + c, correct + a, -correct, a * k + b * k + c], (v) => String(v));
    if (!o) return null;
    return {
      text: `Given \\(f(x) = ${quadTex(a, b, c)}\\), evaluate \\(f(${k})\\).`,
      ...o,
      explanation: `Substitute \\(x = ${k}\\).\n\n\\(f(${k}) = ${a}(${k})^{2} ${b > 0 ? '+' : '-'} ${Math.abs(b)}(${k}) ${c > 0 ? '+' : '-'} ${Math.abs(c)}\\)\n\n\\(= ${a * k * k} ${b * k >= 0 ? '+' : '-'} ${Math.abs(b * k)} ${c > 0 ? '+' : '-'} ${Math.abs(c)} = ${correct}\\)`,
    };
  },
  // inverse of a linear function
  () => {
    const a = randInt(2, 10), b = nonZero(-15, 15);
    const correct = `\\frac{x ${b > 0 ? '-' : '+'} ${Math.abs(b)}}{${a}}`;
    const wrongs = [
      `\\frac{x ${b > 0 ? '+' : '-'} ${Math.abs(b)}}{${a}}`,
      `${a}x ${b > 0 ? '-' : '+'} ${Math.abs(b)}`,
      `\\frac{${a}}{x ${b > 0 ? '-' : '+'} ${Math.abs(b)}}`,
    ];
    const o = textOptions(mathOpt(correct), wrongs.map(mathOpt));
    if (!o) return null;
    return {
      text: `If \\(f(x) = ${linTex(a, b)}\\), find \\(f^{-1}(x)\\).`,
      ...o,
      explanation: `Let \\(y = ${linTex(a, b)}\\).\n\nInterchange \\(x\\) and \\(y\\): \\(x = ${a}y ${b > 0 ? '+' : '-'} ${Math.abs(b)}\\)\n\nMake \\(y\\) the subject: \\(y = ${correct}\\)\n\nSo \\(f^{-1}(x) = ${correct}\\).`,
    };
  },
  // composite function value
  () => {
    const a = nonZero(-5, 6), b = nonZero(-8, 8), c = nonZero(-5, 6), d = nonZero(-8, 8), k = nonZero(-5, 5);
    const gk = c * k + d;
    const correct = a * gk + b;
    const o = buildOptions(correct, [c * (a * k + b) + d, a * k + b, gk, correct + 1], (v) => String(v));
    if (!o) return null;
    return {
      text: `Given \\(f(x) = ${linTex(a, b)}\\) and \\(g(x) = ${linTex(c, d)}\\), find \\(f(g(${k}))\\).`,
      ...o,
      explanation: `First find \\(g(${k})\\): \\(g(${k}) = ${c}(${k}) ${d > 0 ? '+' : '-'} ${Math.abs(d)} = ${gk}\\)\n\nThen find \\(f(${gk})\\): \\(f(${gk}) = ${a}(${gk}) ${b > 0 ? '+' : '-'} ${Math.abs(b)} = ${correct}\\)`,
    };
  },
  // find x given f(x) = value
  () => {
    const a = randInt(2, 9), b = nonZero(-12, 12), x = nonZero(-9, 9);
    const val = a * x + b;
    const o = buildOptions(x, [-x, x + 1, val, x - 2], (v) => String(v));
    if (!o) return null;
    return {
      text: `If \\(f(x) = ${linTex(a, b)}\\) and \\(f(x) = ${val}\\), find \\(x\\).`,
      ...o,
      explanation: `\\(${linTex(a, b)} = ${val}\\)\n\n\\(${a}x = ${val - b}\\)\n\n\\(x = \\frac{${val - b}}{${a}} = ${x}\\)`,
    };
  },
  // domain restriction
  () => {
    const b = nonZero(-12, 12);
    const excluded = -b;
    const o = buildOptions(excluded, [b, 0, excluded + 1], (v) => mathOpt(`x = ${v}`));
    if (!o) return null;
    return {
      text: `For what value of \\(x\\) is \\(\\frac{1}{x ${b > 0 ? '+' : '-'} ${Math.abs(b)}}\\) undefined?`,
      ...o,
      explanation: `A fraction is undefined when its denominator is zero.\n\n\\(x ${b > 0 ? '+' : '-'} ${Math.abs(b)} = 0\\)\n\n\\(x = ${excluded}\\)`,
    };
  },
];

// ======================== ALGEBRAIC FRACTIONS ========================
const algFractions = [
  // simplify (x^2 - a^2)/(x + a)
  () => {
    const a = randInt(2, 12);
    const correct = `x - ${a}`;
    const wrongs = [`x + ${a}`, `x^{2} - ${a}`, `\\frac{x - ${a}}{${a}}`];
    const o = textOptions(mathOpt(correct), wrongs.map(mathOpt));
    if (!o) return null;
    return {
      text: `Simplify \\(\\frac{x^{2} - ${a * a}}{x + ${a}}\\).`,
      ...o,
      explanation: `Factorise the numerator as a difference of two squares.\n\n\\(x^{2} - ${a * a} = (x + ${a})(x - ${a})\\)\n\n\\(\\frac{(x + ${a})(x - ${a})}{x + ${a}} = x - ${a}\\)`,
    };
  },
  // add two algebraic fractions with numeric denominators
  () => {
    const d1 = randInt(2, 7), d2 = randInt(2, 7);
    if (d1 === d2) return null;
    const lcd = d1 * d2 / gcd(d1, d2);
    const n = lcd / d1 + lcd / d2;
    const g = gcd(n, lcd);
    const correct = `\\frac{${n / g === 1 ? '' : n / g}x}{${lcd / g}}`;
    const wrongs = [
      `\\frac{2x}{${d1 + d2}}`,
      `\\frac{${n / g}x}{${d1 * d2}}`,
      `\\frac{x}{${lcd / g}}`,
    ];
    const o = textOptions(mathOpt(correct), wrongs.map(mathOpt));
    if (!o) return null;
    return {
      text: `Simplify \\(\\frac{x}{${d1}} + \\frac{x}{${d2}}\\).`,
      ...o,
      explanation: `The LCM of ${d1} and ${d2} is ${lcd}.\n\n\\(\\frac{x}{${d1}} + \\frac{x}{${d2}} = \\frac{${lcd / d1}x + ${lcd / d2}x}{${lcd}} = \\frac{${n}x}{${lcd}}\\)\n\nIn lowest terms this is \\(${correct}\\).`,
    };
  },
  // simplify a common-factor fraction
  () => {
    const k = randInt(2, 9), a = nonZero(-8, 8);
    const correct = `x ${a > 0 ? '+' : '-'} ${Math.abs(a)}`;
    const wrongs = [
      `${k}x ${a > 0 ? '+' : '-'} ${Math.abs(a)}`,
      `x ${a > 0 ? '-' : '+'} ${Math.abs(a)}`,
      `\\frac{x ${a > 0 ? '+' : '-'} ${Math.abs(a)}}{${k}}`,
    ];
    const o = textOptions(mathOpt(correct), wrongs.map(mathOpt));
    if (!o) return null;
    return {
      text: `Simplify \\(\\frac{${k}x ${k * a > 0 ? '+' : '-'} ${Math.abs(k * a)}}{${k}}\\).`,
      ...o,
      explanation: `Factor ${k} out of the numerator.\n\n\\(${k}x ${k * a > 0 ? '+' : '-'} ${Math.abs(k * a)} = ${k}(x ${a > 0 ? '+' : '-'} ${Math.abs(a)})\\)\n\nDividing by ${k} gives \\(${correct}\\).`,
    };
  },
  // solve an equation containing algebraic fractions
  () => {
    const d1 = randInt(2, 5), d2 = randInt(2, 5);
    if (d1 === d2) return null;
    const x = nonZero(-12, 12) * d1 * d2;
    const lhs = x / d1 - x / d2;
    if (!Number.isInteger(lhs)) return null;
    const o = buildOptions(x, [-x, x + d1, lhs, x / 2], (v) => String(v));
    if (!o) return null;
    return {
      text: `Solve the equation \\(\\frac{x}{${d1}} - \\frac{x}{${d2}} = ${lhs}\\).`,
      ...o,
      explanation: `Multiply through by the LCM of ${d1} and ${d2}, which is ${d1 * d2 / gcd(d1, d2)}.\n\nThis gives \\(${d1 * d2 / gcd(d1, d2) / d1}x - ${d1 * d2 / gcd(d1, d2) / d2}x = ${lhs * d1 * d2 / gcd(d1, d2)}\\)\n\nSimplifying and dividing gives \\(x = ${x}\\).`,
    };
  },
];

// ======================== LINEAR INEQUALITIES ========================
const inequalities = [
  // solve ax + b > c with positive a
  () => {
    const a = randInt(2, 12), b = nonZero(-15, 15), x = nonZero(-10, 10);
    const c = a * x + b;
    const sign = pick(['>', '<', '\\geq', '\\leq']);
    const plain = { '>': '>', '<': '<', '\\geq': '\\geq', '\\leq': '\\leq' }[sign];
    const correct = `x ${plain} ${x}`;
    const wrongs = [
      `x ${plain === '>' ? '<' : plain === '<' ? '>' : plain === '\\geq' ? '\\leq' : '\\geq'} ${x}`,
      `x ${plain} ${-x}`,
      `x ${plain} ${x + 1}`,
    ];
    const o = textOptions(mathOpt(correct), wrongs.map(mathOpt));
    if (!o) return null;
    return {
      text: `Solve the inequality \\(${linTex(a, b)} ${sign} ${c}\\).`,
      ...o,
      explanation: `${b > 0 ? 'Subtract' : 'Add'} ${Math.abs(b)} from both sides: \\(${a}x ${sign} ${c - b}\\)\n\nDivide both sides by ${a} (a positive number, so the inequality sign does not change):\n\n\\(${correct}\\)`,
    };
  },
  // negative coefficient -> sign reverses
  () => {
    const a = -randInt(2, 10), b = nonZero(-12, 12), x = nonZero(-9, 9);
    const c = a * x + b;
    const sign = pick(['>', '<']);
    const flipped = sign === '>' ? '<' : '>';
    const correct = `x ${flipped} ${x}`;
    const wrongs = [`x ${sign} ${x}`, `x ${flipped} ${-x}`, `x ${sign} ${-x}`];
    const o = textOptions(mathOpt(correct), wrongs.map(mathOpt));
    if (!o) return null;
    return {
      text: `Solve the inequality \\(${linTex(a, b)} ${sign} ${c}\\).`,
      ...o,
      explanation: `${b > 0 ? 'Subtract' : 'Add'} ${Math.abs(b)}: \\(${a}x ${sign} ${c - b}\\)\n\nDivide both sides by ${a}. Dividing by a negative number reverses the inequality sign.\n\n\\(${correct}\\)`,
    };
  },
  // least/greatest integer satisfying an inequality
  () => {
    const a = randInt(2, 9), b = nonZero(-12, 12);
    const bound = randInt(-8, 12);
    const c = a * bound + b;
    const correct = bound + 1;
    const o = buildOptions(correct, [bound, bound - 1, bound + 2], (v) => String(v));
    if (!o) return null;
    return {
      text: `Find the least integer value of \\(x\\) that satisfies \\(${linTex(a, b)} > ${c}\\).`,
      ...o,
      explanation: `\\(${a}x > ${c - b}\\)\n\n\\(x > ${bound}\\)\n\nThe smallest integer strictly greater than ${bound} is ${correct}.`,
    };
  },
  // compound inequality range
  () => {
    const lo = randInt(-8, 4), hi = lo + randInt(2, 9);
    const a = randInt(2, 6), b = nonZero(-8, 8);
    const cLo = a * lo + b, cHi = a * hi + b;
    const correct = `${lo} < x < ${hi}`;
    const wrongs = [`${hi} < x < ${lo}`, `${lo} \\leq x \\leq ${hi}`, `${lo - 1} < x < ${hi + 1}`];
    const o = textOptions(mathOpt(correct), wrongs.map(mathOpt));
    if (!o) return null;
    return {
      text: `Solve the inequality \\(${cLo} < ${linTex(a, b)} < ${cHi}\\).`,
      ...o,
      explanation: `${b > 0 ? 'Subtract' : 'Add'} ${Math.abs(b)} throughout: \\(${cLo - b} < ${a}x < ${cHi - b}\\)\n\nDivide throughout by ${a}: \\(${correct}\\)`,
    };
  },
];

module.exports = [
  { topicId: 'uBBKbRH9Jug0g36soFBt', unitId: UNIT, topicName: 'Graphs of Linear and Quadratic Functions', generators: graphs },
  { topicId: '4gi1g7JFFg12CaHG11zx', unitId: UNIT, topicName: 'Quadratic Equations', generators: quadratics },
  { topicId: 'NAvybTyFDDuEsNKmjx1P', unitId: UNIT, topicName: 'Change of Subject of Formula', generators: changeSubject },
  { topicId: 'tAoB5vil5sY5TvhyCPW4', unitId: UNIT, topicName: 'Algebraic Expressions', generators: expressions },
  { topicId: '7fFTb5H1r7JPpiYlU8gr', unitId: UNIT, topicName: 'Expansion and Factorisation', generators: expansion },
  { topicId: '4ksQVylUakJCuU3Q8BpI', unitId: UNIT, topicName: 'Linear Equations', generators: linear },
  { topicId: 'GkXSxKZkcZxYXlvbEl3u', unitId: UNIT, topicName: 'Functions and Relations', generators: functions },
  { topicId: 'IFRFuURT9LJFw7ITMu1o', unitId: UNIT, topicName: 'Algebraic Fractions', generators: algFractions },
  { topicId: 'dnPh1mcTNe4ITUFxL6Lw', unitId: UNIT, topicName: 'Linear Inequalities', generators: inequalities },
];
