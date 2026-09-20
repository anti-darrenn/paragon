// Further Mathematics > Pure (part B), Statistics & Probability, Vectors & Mechanics
const L = require('./lib');
const { randInt, pick, shuffle, sample, nonZero, gcd, frac, fracTex, fracOpt,
        fmtNum, buildOptions, textOptions, round } = L;

const U_PURE = 'XeO4je16v5S8YFrJeG7y';
const U_STAT = 'MQvfQ7h47QmI6EbqdKTp';
const U_VEC = 'bKjjiw3mUiTDwhwJC5Ys';

const mathOpt = (s) => `\\(${s}\\)`;
const TRIPLES = [[3, 4, 5], [5, 12, 13], [8, 15, 17], [7, 24, 25], [20, 21, 29], [9, 40, 41]];
function nCr(n, r) { if (r < 0 || r > n) return 0; let x = 1; for (let i = 0; i < r; i++) x = x * (n - i) / (i + 1); return Math.round(x); }

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
function dPoly(terms) { return terms.filter(([c, p]) => p !== 0).map(([c, p]) => [c * p, p - 1]); }

// ========================== FM TRIGONOMETRY ==========================
const fmTrig = [
  // compound angle identity
  () => {
    const forms = [
      { q: '\\sin(A + B)', a: '\\sin A \\cos B + \\cos A \\sin B', w: ['\\sin A \\cos B - \\cos A \\sin B', '\\cos A \\cos B + \\sin A \\sin B', '\\sin A \\sin B + \\cos A \\cos B'] },
      { q: '\\sin(A - B)', a: '\\sin A \\cos B - \\cos A \\sin B', w: ['\\sin A \\cos B + \\cos A \\sin B', '\\cos A \\cos B - \\sin A \\sin B', '\\sin A \\sin B - \\cos A \\cos B'] },
      { q: '\\cos(A + B)', a: '\\cos A \\cos B - \\sin A \\sin B', w: ['\\cos A \\cos B + \\sin A \\sin B', '\\sin A \\cos B + \\cos A \\sin B', '\\cos A \\sin B - \\sin A \\cos B'] },
      { q: '\\cos(A - B)', a: '\\cos A \\cos B + \\sin A \\sin B', w: ['\\cos A \\cos B - \\sin A \\sin B', '\\sin A \\cos B - \\cos A \\sin B', '\\sin A \\sin B - \\cos A \\cos B'] },
      { q: '\\sin 2A', a: '2\\sin A \\cos A', w: ['\\sin^{2}A - \\cos^{2}A', '2\\cos^{2}A - 1', '\\cos^{2}A - \\sin^{2}A'] },
      { q: '\\cos 2A', a: '\\cos^{2}A - \\sin^{2}A', w: ['2\\sin A \\cos A', '\\sin^{2}A - \\cos^{2}A', '1 + 2\\sin^{2}A'] },
    ];
    const f = pick(forms);
    const o = textOptions(mathOpt(f.a), f.w.map(mathOpt));
    if (!o) return null;
    return {
      text: `Expand \\(${f.q}\\).`,
      ...o,
      explanation: `By the standard compound-angle formulae, \\(${f.q} = ${f.a}\\).`,
    };
  },
  // sin(A+B) numeric using two triples
  () => {
    const [a1, b1, c1] = pick(TRIPLES);
    const [a2, b2, c2] = pick(TRIPLES);
    const correct = frac(a1 * b2 + b1 * a2, c1 * c2);
    const o = buildOptions(correct, [frac(a1 * b2 - b1 * a2, c1 * c2), frac(b1 * b2 - a1 * a2, c1 * c2), frac(a1 * a2, c1 * c2)], (f) => fracOpt(f));
    if (!o) return null;
    return {
      text: `If \\(\\sin A = ${fracTex(frac(a1, c1))}\\) and \\(\\sin B = ${fracTex(frac(a2, c2))}\\), where \\(A\\) and \\(B\\) are acute, find \\(\\sin(A + B)\\).`,
      ...o,
      explanation: `\\(\\cos A = ${fracTex(frac(b1, c1))}\\) and \\(\\cos B = ${fracTex(frac(b2, c2))}\\) (from \\(\\sin^{2} + \\cos^{2} = 1\\)).\n\n\\(\\sin(A+B) = \\sin A \\cos B + \\cos A \\sin B\\)\n\n\\(= ${fracTex(frac(a1, c1))} \\times ${fracTex(frac(b2, c2))} + ${fracTex(frac(b1, c1))} \\times ${fracTex(frac(a2, c2))}\\)\n\n\\(= ${fracTex(correct)}\\)`,
    };
  },
  // solve a trig equation in a range
  () => {
    const kind = pick([
      { f: 'sin', v: '\\frac{1}{2}', sols: '30° and 150°' },
      { f: 'cos', v: '\\frac{1}{2}', sols: '60° and 300°' },
      { f: 'tan', v: '1', sols: '45° and 225°' },
      { f: 'sin', v: '1', sols: '90° only' },
      { f: 'cos', v: '0', sols: '90° and 270°' },
    ]);
    const o = textOptions(kind.sols, ['0° and 180°', '45° and 135°', '60° and 120°', '30° and 330°'].filter(x => x !== kind.sols).slice(0, 3));
    if (!o) return null;
    return {
      text: `Solve \\(\\${kind.f} \\theta = ${kind.v}\\) for \\(0° \\leq \\theta \\leq 360°\\).`,
      ...o,
      explanation: `The solutions of \\(\\${kind.f} \\theta = ${kind.v}\\) in the interval \\(0° \\leq \\theta \\leq 360°\\) are ${kind.sols}.`,
    };
  },
  // R formula amplitude
  () => {
    const [a, b, c] = pick(TRIPLES);
    const o = buildOptions(c, [a + b, Math.abs(a - b), c + 1], (v) => String(v));
    if (!o) return null;
    return {
      text: `Express \\(${a}\\sin \\theta + ${b}\\cos \\theta\\) in the form \\(R\\sin(\\theta + \\alpha)\\). Find \\(R\\).`,
      ...o,
      explanation: `\\(R = \\sqrt{a^{2} + b^{2}}\\)\n\n\\(= \\sqrt{${a}^{2} + ${b}^{2}} = \\sqrt{${a * a} + ${b * b}} = \\sqrt{${c * c}} = ${c}\\)`,
    };
  },
  // identity simplification
  () => {
    const forms = [
      { q: '\\frac{\\sin \\theta}{\\cos \\theta}', a: '\\tan \\theta', w: ['\\cot \\theta', '\\sec \\theta', '\\csc \\theta'] },
      { q: '1 - \\cos^{2}\\theta', a: '\\sin^{2}\\theta', w: ['\\cos^{2}\\theta', '\\tan^{2}\\theta', '1 + \\sin^{2}\\theta'] },
      { q: '1 + \\tan^{2}\\theta', a: '\\sec^{2}\\theta', w: ['\\csc^{2}\\theta', '\\cot^{2}\\theta', '\\sin^{2}\\theta'] },
      { q: '1 + \\cot^{2}\\theta', a: '\\csc^{2}\\theta', w: ['\\sec^{2}\\theta', '\\tan^{2}\\theta', '\\cos^{2}\\theta'] },
      { q: '\\sin^{2}\\theta + \\cos^{2}\\theta', a: '1', w: ['0', '2', '\\tan^{2}\\theta'] },
      { q: '2\\sin \\theta \\cos \\theta', a: '\\sin 2\\theta', w: ['\\cos 2\\theta', '2\\tan \\theta', '\\sin^{2}\\theta'] },
    ];
    const f = pick(forms);
    const o = textOptions(mathOpt(f.a), f.w.map(mathOpt));
    if (!o) return null;
    return {
      text: `Simplify \\(${f.q}\\).`,
      ...o,
      explanation: `Using the standard trigonometric identities, \\(${f.q} = ${f.a}\\).`,
    };
  },
  // sine / cosine rule numeric
  () => {
    const b = randInt(4, 20), c = randInt(4, 20), A = pick([60, 90, 120]);
    const aSq = b * b + c * c - 2 * b * c * Math.cos(A * Math.PI / 180);
    const correct = round(Math.sqrt(aSq), 2);
    const o = buildOptions(correct, [round(Math.sqrt(b * b + c * c), 2), b + c, round(correct + 1.5, 2)], (v) => `${v.toFixed(2)}`);
    if (!o) return null;
    return {
      text: `In triangle \\(ABC\\), \\(b = ${b}\\), \\(c = ${c}\\) and \\(A = ${A}°\\). Find \\(a\\), correct to 2 decimal places.`,
      ...o,
      explanation: `\\(a^{2} = b^{2} + c^{2} - 2bc\\cos A\\)\n\n\\(= ${b * b} + ${c * c} - 2(${b})(${c})\\cos ${A}°\\)\n\n\\(= ${round(aSq, 3)}\\)\n\n\\(a = ${correct.toFixed(2)}\\)`,
    };
  },
  // area of a triangle using 1/2 ab sin C
  () => {
    const a = randInt(4, 20), b = randInt(4, 20), C = pick([30, 90, 150]);
    const area = 0.5 * a * b * Math.sin(C * Math.PI / 180);
    const correct = round(area, 2);
    const o = buildOptions(correct, [round(a * b, 2), round(0.5 * a * b, 2), round(area * 2, 2)], (v) => `${v.toFixed(2)} square units`);
    if (!o) return null;
    return {
      text: `Find the area of a triangle with sides ${a} and ${b} enclosing an angle of ${C}°, correct to 2 decimal places.`,
      ...o,
      explanation: `Area \\(= \\frac{1}{2}ab\\sin C\\)\n\n\\(= \\frac{1}{2}(${a})(${b})\\sin ${C}°\\)\n\n\\(= ${correct.toFixed(2)}\\) square units`,
    };
  },
];

// ====================== FM COORDINATE GEOMETRY ======================
const fmCoord = [
  // equation of a circle, centre and radius given
  () => {
    const h = nonZero(-8, 8), k = nonZero(-8, 8), r = randInt(2, 10);
    const correct = `(x ${-h >= 0 ? '+' : '-'} ${Math.abs(h)})^{2} + (y ${-k >= 0 ? '+' : '-'} ${Math.abs(k)})^{2} = ${r * r}`;
    const wrongs = [
      `(x ${h >= 0 ? '+' : '-'} ${Math.abs(h)})^{2} + (y ${k >= 0 ? '+' : '-'} ${Math.abs(k)})^{2} = ${r * r}`,
      `(x ${-h >= 0 ? '+' : '-'} ${Math.abs(h)})^{2} + (y ${-k >= 0 ? '+' : '-'} ${Math.abs(k)})^{2} = ${r}`,
      `(x ${-h >= 0 ? '+' : '-'} ${Math.abs(h)})^{2} - (y ${-k >= 0 ? '+' : '-'} ${Math.abs(k)})^{2} = ${r * r}`,
    ];
    const o = textOptions(mathOpt(correct), wrongs.map(mathOpt));
    if (!o) return null;
    return {
      text: `Find the equation of the circle with centre \\((${h}, ${k})\\) and radius ${r}.`,
      ...o,
      explanation: `The equation of a circle with centre \\((a, b)\\) and radius \\(r\\) is \\((x - a)^{2} + (y - b)^{2} = r^{2}\\).\n\nHere \\(a = ${h}\\), \\(b = ${k}\\), \\(r = ${r}\\).\n\nSo the equation is \\(${correct}\\).`,
    };
  },
  // centre of a circle from the general form
  () => {
    const h = nonZero(-7, 7), k = nonZero(-7, 7), r = randInt(2, 9);
    const g = -h, f = -k, c = h * h + k * k - r * r;
    const o = buildOptions([h, k], [[-h, -k], [g, f], [k, h]], (p) => mathOpt(`(${p[0]}, ${p[1]})`));
    if (!o) return null;
    return {
      text: `Find the centre of the circle \\(x^{2} + y^{2} ${2 * g >= 0 ? '+' : '-'} ${Math.abs(2 * g)}x ${2 * f >= 0 ? '+' : '-'} ${Math.abs(2 * f)}y ${c >= 0 ? '+' : '-'} ${Math.abs(c)} = 0\\).`,
      ...o,
      explanation: `For \\(x^{2} + y^{2} + 2gx + 2fy + c = 0\\), the centre is \\((-g, -f)\\).\n\nHere \\(2g = ${2 * g}\\) so \\(g = ${g}\\), and \\(2f = ${2 * f}\\) so \\(f = ${f}\\).\n\nCentre \\(= (${h}, ${k})\\)`,
    };
  },
  // radius from the general form
  () => {
    const h = nonZero(-6, 6), k = nonZero(-6, 6), r = randInt(2, 9);
    const g = -h, f = -k, c = h * h + k * k - r * r;
    const o = buildOptions(r, [r * r, r + 1, Math.abs(c)], (v) => String(v));
    if (!o) return null;
    return {
      text: `Find the radius of the circle \\(x^{2} + y^{2} ${2 * g >= 0 ? '+' : '-'} ${Math.abs(2 * g)}x ${2 * f >= 0 ? '+' : '-'} ${Math.abs(2 * f)}y ${c >= 0 ? '+' : '-'} ${Math.abs(c)} = 0\\).`,
      ...o,
      explanation: `Radius \\(= \\sqrt{g^{2} + f^{2} - c}\\)\n\n\\(= \\sqrt{(${g})^{2} + (${f})^{2} - (${c})}\\)\n\n\\(= \\sqrt{${g * g + f * f - c}} = ${r}\\)`,
    };
  },
  // angle between two lines / perpendicular condition
  () => {
    const a = nonZero(-7, 7), b = randInt(2, 9);
    const m = frac(a, b);
    const perp = frac(-b, a);
    const o = buildOptions(perp, [m, frac(b, a), frac(-a, b)], (f) => fracOpt(f));
    if (!o) return null;
    return {
      text: `A line has gradient \\(${fracTex(m)}\\). Find the gradient of the line perpendicular to it.`,
      ...o,
      explanation: `For perpendicular lines the product of the gradients is \\(-1\\).\n\n\\(m_2 = -\\frac{1}{${fracTex(m)}} = ${fracTex(perp)}\\)`,
    };
  },
  // distance between two points
  () => {
    const [dx, dy, d] = pick(TRIPLES);
    const x1 = randInt(-9, 9), y1 = randInt(-9, 9);
    const x2 = x1 + dx * pick([1, -1]), y2 = y1 + dy * pick([1, -1]);
    const o = buildOptions(d, [dx + dy, Math.abs(dx - dy), d * 2], (v) => String(v));
    if (!o) return null;
    return {
      text: `Find the distance between the points \\((${x1}, ${y1})\\) and \\((${x2}, ${y2})\\).`,
      ...o,
      explanation: `\\(d = \\sqrt{(x_2-x_1)^{2} + (y_2-y_1)^{2}}\\)\n\n\\(= \\sqrt{(${x2 - x1})^{2} + (${y2 - y1})^{2}} = \\sqrt{${dx * dx + dy * dy}} = ${d}\\)`,
    };
  },
  // midpoint / point dividing a line
  () => {
    const x1 = randInt(-10, 10), y1 = randInt(-10, 10);
    const x2 = x1 + 2 * nonZero(-7, 7), y2 = y1 + 2 * nonZero(-7, 7);
    const mx = (x1 + x2) / 2, my = (y1 + y2) / 2;
    const o = buildOptions([mx, my], [[x2 - x1, y2 - y1], [my, mx], [mx + 1, my]], (p) => mathOpt(`(${p[0]}, ${p[1]})`));
    if (!o) return null;
    return {
      text: `Find the midpoint of the line segment joining \\((${x1}, ${y1})\\) and \\((${x2}, ${y2})\\).`,
      ...o,
      explanation: `Midpoint \\(= \\left(\\frac{${x1} + ${x2}}{2}, \\frac{${y1} + ${y2}}{2}\\right) = (${mx}, ${my})\\)`,
    };
  },
];

// ========================= FM DIFFERENTIATION =========================
const fmDiff = [
  // product rule on two linear factors
  () => {
    const a = nonZero(-5, 6), b = nonZero(-8, 8), c = nonZero(-5, 6), d = nonZero(-8, 8);
    // y = (ax+b)(cx+d) -> dy/dx = 2acx + (ad+bc)
    const A = 2 * a * c, B = a * d + b * c;
    const o = buildOptions([A, B], [[a * c, B], [A, a * d - b * c], [A + 1, B]],
      (p) => mathOpt(polyTex([[p[0], 1], [p[1], 0]])));
    if (!o) return null;
    const lin = (p, q) => `${p === 1 ? 'x' : p === -1 ? '-x' : `${p}x`}${q >= 0 ? ' + ' : ' - '}${Math.abs(q)}`;
    return {
      text: `Differentiate \\(y = (${lin(a, b)})(${lin(c, d)})\\) with respect to \\(x\\).`,
      ...o,
      explanation: `Expand first: \\(y = ${polyTex([[a * c, 2], [a * d + b * c, 1], [b * d, 0]])}\\)\n\nDifferentiate term by term:\n\n\\(\\frac{dy}{dx} = ${polyTex([[A, 1], [B, 0]])}\\)`,
    };
  },
  // chain rule on (ax+b)^n
  () => {
    const a = nonZero(-5, 6), b = nonZero(-8, 8), n = randInt(2, 6);
    const coef = n * a;
    const inner = `(${a === 1 ? 'x' : a === -1 ? '-x' : `${a}x`} ${b > 0 ? '+' : '-'} ${Math.abs(b)})`;
    const correct = `${coef}${inner}^{${n - 1}}`;
    const wrongs = [`${n}${inner}^{${n - 1}}`, `${coef}${inner}^{${n}}`, `${a}${inner}^{${n - 1}}`];
    const o = textOptions(mathOpt(correct), wrongs.map(mathOpt));
    if (!o) return null;
    return {
      text: `Find \\(\\frac{dy}{dx}\\) if \\(y = ${inner}^{${n}}\\).`,
      ...o,
      explanation: `By the chain rule, \\(\\frac{dy}{dx} = n(\\text{inner})^{n-1} \\times \\frac{d(\\text{inner})}{dx}\\).\n\n\\(= ${n}${inner}^{${n - 1}} \\times ${a} = ${correct}\\)`,
    };
  },
  // derivative of a trig function
  () => {
    const forms = [
      { q: '\\sin x', a: '\\cos x', w: ['-\\cos x', '-\\sin x', '\\tan x'] },
      { q: '\\cos x', a: '-\\sin x', w: ['\\sin x', '-\\cos x', '\\sec^{2}x'] },
      { q: '\\tan x', a: '\\sec^{2}x', w: ['-\\csc^{2}x', '\\cot x', '\\sec x \\tan x'] },
    ];
    const f = pick(forms);
    const k = randInt(2, 9);
    const correct = `${k}${f.a.startsWith('-') ? f.a : f.a}`;
    const disp = f.a.startsWith('-') ? `-${k}${f.a.slice(1)}` : `${k}${f.a}`;
    const wrongs = f.w.map(w => w.startsWith('-') ? `-${k}${w.slice(1)}` : `${k}${w}`);
    const o = textOptions(mathOpt(disp), wrongs.map(mathOpt));
    if (!o) return null;
    return {
      text: `Differentiate \\(y = ${k}${f.q}\\) with respect to \\(x\\).`,
      ...o,
      explanation: `\\(\\frac{d}{dx}(${f.q}) = ${f.a}\\)\n\nMultiplying by the constant ${k}: \\(\\frac{dy}{dx} = ${disp}\\)`,
    };
  },
  // turning point classification
  () => {
    const a = pick([1, 2, -1, -2]);
    const h = randInt(-5, 5), k = randInt(-10, 10);
    const b = -2 * a * h, c = a * h * h + k;
    const kind = a > 0 ? 'Minimum' : 'Maximum';
    const o = textOptions(kind, [a > 0 ? 'Maximum' : 'Minimum', 'Point of inflexion', 'No turning point']);
    if (!o) return null;
    return {
      text: `Determine the nature of the turning point of \\(y = ${polyTex([[a, 2], [b, 1], [c, 0]])}\\).`,
      ...o,
      explanation: `\\(\\frac{dy}{dx} = ${polyTex([[2 * a, 1], [b, 0]])}\\) and \\(\\frac{d^{2}y}{dx^{2}} = ${2 * a}\\).\n\nSince the second derivative is ${2 * a > 0 ? 'positive' : 'negative'}, the turning point is a ${kind.toLowerCase()}.`,
    };
  },
  // derivative of a polynomial
  () => {
    const a = nonZero(-6, 7), b = nonZero(-8, 8), c = nonZero(-9, 9);
    const terms = [[a, 4], [b, 2], [c, 1]];
    const d = dPoly(terms);
    const o = buildOptions(d, [[[a, 3], [b, 1], [c, 0]], dPoly(d), [[a * 4, 4], [b * 2, 2], [c, 1]]],
      (t) => mathOpt(polyTex(t)));
    if (!o) return null;
    return {
      text: `Differentiate \\(y = ${polyTex(terms)}\\) with respect to \\(x\\).`,
      ...o,
      explanation: `Apply \\(\\frac{d}{dx}(ax^{n}) = nax^{n-1}\\) to each term.\n\n\\(\\frac{dy}{dx} = ${polyTex(d)}\\)`,
    };
  },
  // quotient rule / rate of change
  () => {
    const a = nonZero(-4, 6), b = nonZero(-8, 8), c = nonZero(-9, 9), t = randInt(1, 6);
    const v = 2 * a * t + b;
    const acc = 2 * a;
    const o = buildOptions(acc, [v, a * t * t + b * t + c, acc + b], (x) => `${x}m/s²`);
    if (!o) return null;
    return {
      text: `A particle moves such that its displacement is \\(s = ${polyTex([[a, 2], [b, 1], [c, 0]], 't')}\\). Find its acceleration.`,
      ...o,
      explanation: `Velocity \\(v = \\frac{ds}{dt} = ${polyTex([[2 * a, 1], [b, 0]], 't')}\\)\n\nAcceleration \\(= \\frac{dv}{dt} = ${acc}\\)m/s²\n\nThe acceleration is constant.`,
    };
  },
];

// =========================== FM INTEGRATION ===========================
const fmInt = [
  // definite integral of a quadratic
  () => {
    const a = 3 * nonZero(-2, 3), b = 2 * nonZero(-3, 3), c = nonZero(-6, 6);
    const lo = randInt(0, 2), hi = lo + randInt(1, 4);
    const F = (x) => (a / 3) * x ** 3 + (b / 2) * x ** 2 + c * x;
    const correct = F(hi) - F(lo);
    if (!Number.isInteger(correct)) return null;
    const o = buildOptions(correct, [F(hi) + F(lo), correct * 2, -correct], (v) => String(v));
    if (!o) return null;
    return {
      text: `Evaluate \\(\\int_{${lo}}^{${hi}} (${polyTex([[a, 2], [b, 1], [c, 0]])})\\,dx\\).`,
      ...o,
      explanation: `\\(\\int (${polyTex([[a, 2], [b, 1], [c, 0]])})dx = ${polyTex([[a / 3, 3], [b / 2, 2], [c, 1]])}\\)\n\nAt \\(x = ${hi}\\): \\(${F(hi)}\\)\n\nAt \\(x = ${lo}\\): \\(${F(lo)}\\)\n\nDifference \\(= ${correct}\\)`,
    };
  },
  // integral of a trig function
  () => {
    const forms = [
      { q: '\\sin x', a: '-\\cos x + c', w: ['\\cos x + c', '-\\sin x + c', '\\sec^{2}x + c'] },
      { q: '\\cos x', a: '\\sin x + c', w: ['-\\sin x + c', '\\cos x + c', '-\\cos x + c'] },
      { q: '\\sec^{2}x', a: '\\tan x + c', w: ['\\sec x + c', '-\\cot x + c', '\\tan^{2}x + c'] },
    ];
    const f = pick(forms);
    const o = textOptions(mathOpt(f.a), f.w.map(mathOpt));
    if (!o) return null;
    return {
      text: `Evaluate \\(\\int ${f.q}\\,dx\\).`,
      ...o,
      explanation: `From the standard integrals, \\(\\int ${f.q}\\,dx = ${f.a}\\).`,
    };
  },
  // integral by substitution: (ax+b)^n
  () => {
    const a = randInt(2, 6), b = nonZero(-8, 8), n = randInt(2, 5);
    const denom = a * (n + 1);
    const inner = `(${a}x ${b > 0 ? '+' : '-'} ${Math.abs(b)})`;
    const correct = `\\frac{${inner}^{${n + 1}}}{${denom}} + c`;
    const wrongs = [
      `\\frac{${inner}^{${n + 1}}}{${n + 1}} + c`,
      `${inner}^{${n + 1}} + c`,
      `\\frac{${inner}^{${n}}}{${denom}} + c`,
    ];
    const o = textOptions(mathOpt(correct), wrongs.map(mathOpt));
    if (!o) return null;
    return {
      text: `Evaluate \\(\\int ${inner}^{${n}}\\,dx\\).`,
      ...o,
      explanation: `Let \\(u = ${a}x ${b > 0 ? '+' : '-'} ${Math.abs(b)}\\), so \\(\\frac{du}{dx} = ${a}\\) and \\(dx = \\frac{du}{${a}}\\).\n\n\\(\\int u^{${n}}\\frac{du}{${a}} = \\frac{u^{${n + 1}}}{${a}(${n + 1})} + c\\)\n\n\\(= ${correct}\\)`,
    };
  },
  // area between a curve and the x-axis
  () => {
    const a = 3 * randInt(1, 4), hi = randInt(1, 4);
    const area = (a / 3) * hi ** 3;
    const o = buildOptions(area, [a * hi * hi, area * 2, a * hi], (v) => `${fmtNum(v, 2)} square units`);
    if (!o) return null;
    return {
      text: `Find the area enclosed by the curve \\(y = ${polyTex([[a, 2]])}\\), the x-axis, \\(x = 0\\) and \\(x = ${hi}\\).`,
      ...o,
      explanation: `Area \\(= \\int_{0}^{${hi}} ${polyTex([[a, 2]])}dx = \\left[${polyTex([[a / 3, 3]])}\\right]_{0}^{${hi}}\\)\n\n\\(= ${a / 3}(${hi})^{3} = ${area}\\) square units`,
    };
  },
  // indefinite integral of a polynomial
  () => {
    const a = 2 * nonZero(-4, 5), b = nonZero(-9, 9);
    const correct = `${polyTex([[a / 2, 2], [b, 1]])} + c`;
    const wrongs = [`${polyTex([[a, 2], [b, 1]])} + c`, `${polyTex([[a / 2, 2], [b, 2]])} + c`, `${polyTex([[a, 1], [b, 0]])} + c`];
    const o = textOptions(mathOpt(correct), wrongs.map(mathOpt));
    if (!o) return null;
    return {
      text: `Find \\(\\int (${polyTex([[a, 1], [b, 0]])})\\,dx\\).`,
      ...o,
      explanation: `Integrate term by term using \\(\\int x^{n}dx = \\frac{x^{n+1}}{n+1}\\).\n\n\\(\\int ${polyTex([[a, 1]])}dx = ${polyTex([[a / 2, 2]])}\\)\n\n\\(\\int ${b}dx = ${polyTex([[b, 1]])}\\)\n\nSo the answer is \\(${correct}\\).`,
    };
  },
];

// ====================== FM INDICES AND LOGARITHMS ======================
const fmIndicesLogs = [
  // solve an exponential equation
  () => {
    const b = randInt(2, 9), k = randInt(2, 8);
    const v = Math.pow(b, k);
    const o = buildOptions(k, [v, k + 1, b * k], (x) => String(x));
    if (!o) return null;
    return {
      text: `Solve for \\(x\\): \\(${b}^{x} = ${v}\\).`,
      ...o,
      explanation: `Express both sides with base ${b}.\n\n\\(${v} = ${b}^{${k}}\\)\n\nSo \\(x = ${k}\\).`,
    };
  },
  // solve a log equation
  () => {
    const b = randInt(2, 9), k = randInt(2, 6);
    const v = Math.pow(b, k);
    const o = buildOptions(v, [k, b * k, v / b], (x) => String(x));
    if (!o) return null;
    return {
      text: `Solve for \\(x\\): \\(\\log_{${b}} x = ${k}\\).`,
      ...o,
      explanation: `\\(\\log_{${b}} x = ${k}\\) means \\(x = ${b}^{${k}} = ${v}\\).`,
    };
  },
  // change of base
  () => {
    const forms = [
      { q: '\\log_{a} b', a: '\\frac{\\log b}{\\log a}', w: ['\\frac{\\log a}{\\log b}', '\\log b - \\log a', '\\log(ab)'] },
    ];
    const b1 = randInt(2, 9), b2 = randInt(2, 9);
    if (b1 === b2) return null;
    const correct = `\\frac{\\log ${b2}}{\\log ${b1}}`;
    const wrongs = [`\\frac{\\log ${b1}}{\\log ${b2}}`, `\\log ${b2} - \\log ${b1}`, `\\log(${b1} \\times ${b2})`];
    const o = textOptions(mathOpt(correct), wrongs.map(mathOpt));
    if (!o) return null;
    return {
      text: `Express \\(\\log_{${b1}} ${b2}\\) in terms of common logarithms.`,
      ...o,
      explanation: `By the change of base rule, \\(\\log_{a} b = \\frac{\\log b}{\\log a}\\).\n\nSo \\(\\log_{${b1}} ${b2} = ${correct}\\).`,
    };
  },
  // laws of logarithms combination
  () => {
    const b = randInt(2, 8);
    const k1 = randInt(1, 5), k2 = randInt(1, 5);
    const v1 = Math.pow(b, k1), v2 = Math.pow(b, k2);
    const correct = k1 + k2;
    const o = buildOptions(correct, [k1 * k2, Math.abs(k1 - k2), correct + 1], (x) => String(x));
    if (!o) return null;
    return {
      text: `Evaluate \\(\\log_{${b}} ${v1} + \\log_{${b}} ${v2}\\).`,
      ...o,
      explanation: `\\(\\log_{${b}} ${v1} + \\log_{${b}} ${v2} = \\log_{${b}}(${v1} \\times ${v2}) = \\log_{${b}} ${v1 * v2}\\)\n\nSince \\(${v1 * v2} = ${b}^{${correct}}\\), the value is ${correct}.`,
    };
  },
  // simplify an index expression
  () => {
    const a = randInt(2, 15), b = randInt(2, 15);
    const o = buildOptions(a + b, [a * b, Math.abs(a - b), a + b + 1], (e) => mathOpt(`x^{${e}}`));
    if (!o) return null;
    return {
      text: `Simplify \\(x^{${a}} \\times x^{${b}}\\).`,
      ...o,
      explanation: `Add the indices when multiplying powers of the same base.\n\n\\(x^{${a}} \\times x^{${b}} = x^{${a + b}}\\)`,
    };
  },
  // fractional and negative indices
  () => {
    const b = randInt(2, 7), root = randInt(2, 3), num = randInt(1, 4);
    const base = Math.pow(b, root);
    const correct = frac(1, Math.pow(b, num));
    const o = buildOptions(correct, [frac(Math.pow(b, num), 1), frac(1, b * num), frac(1, Math.pow(b, num + 1))], (f) => fracOpt(f));
    if (!o) return null;
    return {
      text: `Evaluate \\(${base}^{-\\frac{${num}}{${root}}}\\).`,
      ...o,
      explanation: `\\(a^{-\\frac{m}{n}} = \\frac{1}{(\\sqrt[n]{a})^{m}}\\)\n\nThe ${root === 2 ? 'square' : 'cube'} root of ${base} is ${b}.\n\n\\(${base}^{-\\frac{${num}}{${root}}} = \\frac{1}{${b}^{${num}}} = ${fracTex(correct)}\\)`,
    };
  },
];

// ========================== FM STATISTICS ==========================
const fmStats = [
  // mean of a list
  () => {
    const n = randInt(5, 10);
    const vals = Array.from({ length: n }, () => randInt(1, 40));
    const sum = vals.reduce((a, b) => a + b, 0);
    if (sum % n !== 0) return null;
    const correct = sum / n;
    const o = buildOptions(correct, [sum, correct + 1, Math.max(...vals)], (v) => String(v));
    if (!o) return null;
    return {
      text: `Calculate the mean of the following data: ${vals.join(', ')}.`,
      ...o,
      explanation: `Mean \\(= \\frac{\\sum x}{n} = \\frac{${sum}}{${n}} = ${correct}\\)`,
    };
  },
  // variance of a small data set
  () => {
    const m = randInt(3, 12);
    const devs = shuffle([-2, -1, 0, 1, 2]);
    const vals = devs.map(d => m + d);
    const mean = vals.reduce((a, b) => a + b, 0) / vals.length;
    if (!Number.isInteger(mean)) return null;
    const variance = vals.reduce((a, v) => a + (v - mean) ** 2, 0) / vals.length;
    const o = buildOptions(variance, [round(Math.sqrt(variance), 2), variance * 2, mean], (v) => fmtNum(v, 2));
    if (!o) return null;
    return {
      text: `Find the variance of the data: ${vals.join(', ')}.`,
      ...o,
      explanation: `Mean \\(= ${mean}\\)\n\nDeviations from the mean: ${vals.map(v => v - mean).join(', ')}\n\nSquared deviations: ${vals.map(v => (v - mean) ** 2).join(', ')}\n\nVariance \\(= \\frac{${vals.reduce((a, v) => a + (v - mean) ** 2, 0)}}{${vals.length}} = ${variance}\\)`,
    };
  },
  // standard deviation
  () => {
    const m = randInt(4, 15);
    const devs = shuffle([-2, -1, 0, 1, 2]);
    const vals = devs.map(d => m + d);
    const mean = vals.reduce((a, b) => a + b, 0) / vals.length;
    if (!Number.isInteger(mean)) return null;
    const variance = vals.reduce((a, v) => a + (v - mean) ** 2, 0) / vals.length;
    const sd = Math.sqrt(variance);
    const correct = round(sd, 2);
    const o = buildOptions(correct, [variance, round(sd * 2, 2), mean], (v) => fmtNum(v, 2));
    if (!o) return null;
    return {
      text: `Calculate the standard deviation of: ${vals.join(', ')}, correct to 2 decimal places.`,
      ...o,
      explanation: `Mean \\(= ${mean}\\)\n\nVariance \\(= \\frac{\\sum (x - \\bar{x})^{2}}{n} = \\frac{${vals.reduce((a, v) => a + (v - mean) ** 2, 0)}}{${vals.length}} = ${variance}\\)\n\nStandard deviation \\(= \\sqrt{${variance}} = ${correct}\\)`,
    };
  },
  // median of an even-sized set
  () => {
    const vals = Array.from({ length: 6 }, () => randInt(1, 50));
    const sorted = vals.slice().sort((a, b) => a - b);
    const med = (sorted[2] + sorted[3]) / 2;
    const o = buildOptions(med, [sorted[2], sorted[3], round(vals.reduce((a, b) => a + b, 0) / 6, 2)], (v) => fmtNum(v, 2));
    if (!o) return null;
    return {
      text: `Find the median of: ${vals.join(', ')}.`,
      ...o,
      explanation: `Arrange in order: ${sorted.join(', ')}\n\nThere are 6 values, so the median is the mean of the 3rd and 4th values.\n\n\\(\\frac{${sorted[2]} + ${sorted[3]}}{2} = ${med}\\)`,
    };
  },
  // mean from a frequency distribution
  () => {
    const scores = [10, 20, 30, 40, 50];
    const freqs = scores.map(() => randInt(1, 9));
    const total = freqs.reduce((a, b) => a + b, 0);
    const sumfx = scores.reduce((a, s, i) => a + s * freqs[i], 0);
    if (sumfx % total !== 0) return null;
    const correct = sumfx / total;
    const o = buildOptions(correct, [total, sumfx, correct + 10], (v) => fmtNum(v, 2));
    if (!o) return null;
    return {
      text: `The distribution of marks is: ${scores.map((s, i) => `${s} (frequency ${freqs[i]})`).join(', ')}. Calculate the mean mark.`,
      ...o,
      explanation: `\\(\\sum fx = ${scores.map((s, i) => `${s}(${freqs[i]})`).join(' + ')} = ${sumfx}\\)\n\n\\(\\sum f = ${total}\\)\n\nMean \\(= \\frac{${sumfx}}{${total}} = ${correct}\\)`,
    };
  },
];

// ========================== FM PROBABILITY ==========================
const fmProb = [
  // conditional probability
  () => {
    const both = randInt(2, 10), a = both + randInt(2, 12);
    const total = a + randInt(5, 20);
    const correct = frac(both, a);
    const o = buildOptions(correct, [frac(both, total), frac(a, total), frac(a, both)], (f) => fracOpt(f));
    if (!o) return null;
    return {
      text: `In a group of ${total} students, ${a} study Physics and ${both} study both Physics and Chemistry. A student is chosen at random from those who study Physics. What is the probability that the student also studies Chemistry?`,
      ...o,
      explanation: `This is conditional probability: \\(P(C \\mid P) = \\frac{n(P \\cap C)}{n(P)}\\)\n\n\\(= \\frac{${both}}{${a}} = ${fracTex(correct)}\\)`,
    };
  },
  // combinations-based probability
  () => {
    const r1 = randInt(3, 7), r2 = randInt(3, 7);
    const total = r1 + r2;
    const pick2 = 2;
    const correct = frac(nCr(r1, 2), nCr(total, 2));
    const o = buildOptions(correct, [frac(nCr(r2, 2), nCr(total, 2)), frac(r1, total), frac(nCr(r1, 2), total)], (f) => fracOpt(f));
    if (!o) return null;
    return {
      text: `A box contains ${r1} red and ${r2} blue balls. If 2 balls are selected at random without replacement, find the probability that both are red.`,
      ...o,
      explanation: `Number of ways to choose 2 red balls \\(= ^{${r1}}C_{2} = ${nCr(r1, 2)}\\)\n\nTotal ways to choose any 2 balls \\(= ^{${total}}C_{2} = ${nCr(total, 2)}\\)\n\n\\(P = \\frac{${nCr(r1, 2)}}{${nCr(total, 2)}} = ${fracTex(correct)}\\)`,
    };
  },
  // mutually exclusive / addition rule
  () => {
    const d = randInt(6, 20);
    const a = randInt(1, Math.floor(d / 3)), b = randInt(1, Math.floor(d / 3));
    const correct = frac(a + b, d);
    const o = buildOptions(correct, [frac(a * b, d * d), frac(a, d), frac(b, d)], (f) => fracOpt(f));
    if (!o) return null;
    return {
      text: `Two mutually exclusive events \\(A\\) and \\(B\\) have \\(P(A) = ${fracTex(frac(a, d))}\\) and \\(P(B) = ${fracTex(frac(b, d))}\\). Find \\(P(A \\cup B)\\).`,
      ...o,
      explanation: `For mutually exclusive events, \\(P(A \\cup B) = P(A) + P(B)\\).\n\n\\(= ${fracTex(frac(a, d))} + ${fracTex(frac(b, d))} = ${fracTex(correct)}\\)`,
    };
  },
  // independent events, at least one
  () => {
    const a = randInt(1, 4), b = randInt(a + 1, 6);
    const c = randInt(1, 4), d = randInt(c + 1, 6);
    const pA = frac(a, b), pB = frac(c, d);
    const neither = frac((b - a) * (d - c), b * d);
    const correct = frac(b * d - (b - a) * (d - c), b * d);
    const o = buildOptions(correct, [neither, frac(a * c, b * d), frac(a * d + c * b, b * d)], (f) => fracOpt(f));
    if (!o) return null;
    return {
      text: `The probabilities that two independent events \\(A\\) and \\(B\\) occur are \\(${fracTex(pA)}\\) and \\(${fracTex(pB)}\\) respectively. Find the probability that at least one of them occurs.`,
      ...o,
      explanation: `\\(P(\\text{neither}) = \\left(1 - ${fracTex(pA)}\\right)\\left(1 - ${fracTex(pB)}\\right) = ${fracTex(neither)}\\)\n\n\\(P(\\text{at least one}) = 1 - ${fracTex(neither)} = ${fracTex(correct)}\\)`,
    };
  },
  // general addition rule
  () => {
    const d = randInt(8, 24);
    const a = randInt(2, Math.floor(d / 2)), b = randInt(2, Math.floor(d / 2)), both = randInt(1, Math.min(a, b));
    const correct = frac(a + b - both, d);
    const o = buildOptions(correct, [frac(a + b, d), frac(both, d), frac(a * b, d * d)], (f) => fracOpt(f));
    if (!o) return null;
    return {
      text: `Given \\(P(A) = ${fracTex(frac(a, d))}\\), \\(P(B) = ${fracTex(frac(b, d))}\\) and \\(P(A \\cap B) = ${fracTex(frac(both, d))}\\), find \\(P(A \\cup B)\\).`,
      ...o,
      explanation: `\\(P(A \\cup B) = P(A) + P(B) - P(A \\cap B)\\)\n\n\\(= ${fracTex(frac(a, d))} + ${fracTex(frac(b, d))} - ${fracTex(frac(both, d))} = ${fracTex(correct)}\\)`,
    };
  },
];

// ============================ FM VECTORS ============================
const vecTex = (a, b) => `\\begin{pmatrix} ${a} \\\\ ${b} \\end{pmatrix}`;
const vecOpt = (v) => mathOpt(vecTex(v[0], v[1]));

const fmVectors = [
  // dot product
  () => {
    const a = [nonZero(-8, 8), nonZero(-8, 8)], b = [nonZero(-8, 8), nonZero(-8, 8)];
    const dot = a[0] * b[0] + a[1] * b[1];
    const o = buildOptions(dot, [a[0] * b[1] + a[1] * b[0], a[0] * b[0] - a[1] * b[1], dot + 2], (v) => String(v));
    if (!o) return null;
    return {
      text: `Given \\(\\mathbf{a} = ${vecTex(a[0], a[1])}\\) and \\(\\mathbf{b} = ${vecTex(b[0], b[1])}\\), find \\(\\mathbf{a} \\cdot \\mathbf{b}\\).`,
      ...o,
      explanation: `\\(\\mathbf{a} \\cdot \\mathbf{b} = a_1b_1 + a_2b_2\\)\n\n\\(= (${a[0]})(${b[0]}) + (${a[1]})(${b[1]})\\)\n\n\\(= ${a[0] * b[0]} + ${a[1] * b[1]} = ${dot}\\)`,
    };
  },
  // magnitude
  () => {
    const [p, q, r] = pick(TRIPLES);
    const x = p * pick([1, -1]), y = q * pick([1, -1]);
    const o = buildOptions(r, [p + q, Math.abs(p - q), r * 2], (v) => String(v));
    if (!o) return null;
    return {
      text: `Find the magnitude of \\(${vecTex(x, y)}\\).`,
      ...o,
      explanation: `\\(|\\mathbf{v}| = \\sqrt{x^{2} + y^{2}} = \\sqrt{${x * x} + ${y * y}} = \\sqrt{${r * r}} = ${r}\\)`,
    };
  },
  // perpendicular vectors condition
  () => {
    const a1 = nonZero(-8, 8), a2 = nonZero(-8, 8), b1 = nonZero(-8, 8);
    // a.b = 0 -> a1*b1 + a2*b2 = 0 -> b2 = -a1*b1/a2
    const b2 = -a1 * b1 / a2;
    if (!Number.isInteger(b2)) return null;
    const o = buildOptions(b2, [-b2, b1, a2], (v) => String(v));
    if (!o) return null;
    return {
      text: `The vectors \\(${vecTex(a1, a2)}\\) and \\(\\begin{pmatrix} ${b1} \\\\ k \\end{pmatrix}\\) are perpendicular. Find \\(k\\).`,
      ...o,
      explanation: `Perpendicular vectors have a zero dot product.\n\n\\((${a1})(${b1}) + (${a2})k = 0\\)\n\n\\(${a1 * b1} + ${a2}k = 0\\)\n\n\\(k = ${b2}\\)`,
    };
  },
  // angle between two vectors
  () => {
    const kind = pick([
      { a: [1, 0], b: [0, 1], ang: 90 },
      { a: [1, 0], b: [1, 0], ang: 0 },
      { a: [1, 0], b: [-1, 0], ang: 180 },
      { a: [1, 1], b: [1, 0], ang: 45 },
      { a: [0, 1], b: [0, -1], ang: 180 },
    ]);
    const o = buildOptions(kind.ang, [90, 45, 180, 0].filter(x => x !== kind.ang), (v) => `${v}°`);
    if (!o) return null;
    return {
      text: `Find the angle between the vectors \\(${vecTex(kind.a[0], kind.a[1])}\\) and \\(${vecTex(kind.b[0], kind.b[1])}\\).`,
      ...o,
      explanation: `\\(\\cos \\theta = \\frac{\\mathbf{a} \\cdot \\mathbf{b}}{|\\mathbf{a}||\\mathbf{b}|}\\)\n\n\\(\\mathbf{a} \\cdot \\mathbf{b} = ${kind.a[0] * kind.b[0] + kind.a[1] * kind.b[1]}\\)\n\nEvaluating gives \\(\\theta = ${kind.ang}°\\).`,
    };
  },
  // resultant of vectors
  () => {
    const a = [nonZero(-9, 9), nonZero(-9, 9)], b = [nonZero(-9, 9), nonZero(-9, 9)];
    const s = [a[0] + b[0], a[1] + b[1]];
    const o = buildOptions(s, [[a[0] - b[0], a[1] - b[1]], [s[1], s[0]], [a[0] * b[0], a[1] * b[1]]], vecOpt);
    if (!o) return null;
    return {
      text: `Find the resultant of \\(${vecTex(a[0], a[1])}\\) and \\(${vecTex(b[0], b[1])}\\).`,
      ...o,
      explanation: `Add the vectors component by component.\n\n\\(${vecTex(a[0], a[1])} + ${vecTex(b[0], b[1])} = ${vecTex(s[0], s[1])}\\)`,
    };
  },
  // unit vector
  () => {
    const [p, q, r] = pick(TRIPLES);
    const correct = `\\frac{1}{${r}}${vecTex(p, q)}`;
    const wrongs = [`\\frac{1}{${p}}${vecTex(p, q)}`, `${r}${vecTex(p, q)}`, `\\frac{1}{${r * r}}${vecTex(p, q)}`];
    const o = textOptions(mathOpt(correct), wrongs.map(mathOpt));
    if (!o) return null;
    return {
      text: `Find the unit vector in the direction of \\(${vecTex(p, q)}\\).`,
      ...o,
      explanation: `\\(|\\mathbf{v}| = \\sqrt{${p * p} + ${q * q}} = ${r}\\)\n\nThe unit vector is \\(\\frac{\\mathbf{v}}{|\\mathbf{v}|} = ${correct}\\).`,
    };
  },
];

// ============================== STATICS ==============================
const statics = [
  // resultant of two perpendicular forces
  () => {
    const [p, q, r] = pick(TRIPLES);
    const k = randInt(1, 5);
    const o = buildOptions(r * k, [(p + q) * k, Math.abs(p - q) * k, r * k + 2], (v) => `${v}N`);
    if (!o) return null;
    return {
      text: `Two forces of ${p * k}N and ${q * k}N act at right angles to each other. Find the magnitude of their resultant.`,
      ...o,
      explanation: `For perpendicular forces, \\(R = \\sqrt{F_1^{2} + F_2^{2}}\\).\n\n\\(= \\sqrt{${(p * k) ** 2} + ${(q * k) ** 2}} = \\sqrt{${(r * k) ** 2}} = ${r * k}\\)N`,
    };
  },
  // equilibrium: third force
  () => {
    const f1 = randInt(5, 40), f2 = randInt(5, 40);
    const correct = f1 + f2;
    const o = buildOptions(correct, [Math.abs(f1 - f2), f1, correct / 2], (v) => `${v}N`);
    if (!o) return null;
    return {
      text: `Two forces of ${f1}N and ${f2}N act in the same direction on a body. What single force must be applied in the opposite direction to keep the body in equilibrium?`,
      ...o,
      explanation: `The resultant of the two forces is \\(${f1} + ${f2} = ${correct}\\)N.\n\nFor equilibrium the net force must be zero, so a force of ${correct}N is needed in the opposite direction.`,
    };
  },
  // moment of a force
  () => {
    const F = randInt(5, 60), d = randInt(2, 15);
    const correct = F * d;
    const o = buildOptions(correct, [F + d, F / d, correct * 2], (v) => `${v}Nm`);
    if (!o) return null;
    return {
      text: `A force of ${F}N acts at a perpendicular distance of ${d}m from a pivot. Find the moment of the force about the pivot.`,
      ...o,
      explanation: `Moment \\(= \\text{force} \\times \\text{perpendicular distance}\\)\n\n\\(= ${F} \\times ${d} = ${correct}\\)Nm`,
    };
  },
  // principle of moments
  () => {
    const F1 = randInt(2, 30), d1 = randInt(2, 12);
    const d2 = randInt(2, 12);
    const F2 = F1 * d1 / d2;
    if (!Number.isInteger(F2)) return null;
    const o = buildOptions(F2, [F1, F1 * d2 / d1, F2 + 5], (v) => `${v}N`);
    if (!o) return null;
    return {
      text: `A uniform rod is pivoted at its centre. A force of ${F1}N acts at ${d1}m from the pivot on one side. What force acting at ${d2}m on the other side will balance it?`,
      ...o,
      explanation: `By the principle of moments, clockwise moment = anticlockwise moment.\n\n\\(${F1} \\times ${d1} = F \\times ${d2}\\)\n\n\\(${F1 * d1} = ${d2}F\\)\n\n\\(F = ${F2}\\)N`,
    };
  },
  // components of a force
  () => {
    const F = randInt(10, 60);
    const ang = pick([30, 60, 45, 90, 0]);
    const horiz = F * Math.cos(ang * Math.PI / 180);
    const correct = round(horiz, 2);
    const o = buildOptions(correct, [round(F * Math.sin(ang * Math.PI / 180), 2), F, round(correct / 2, 2)], (v) => `${fmtNum(v, 2)}N`);
    if (!o) return null;
    return {
      text: `A force of ${F}N acts at ${ang}° to the horizontal. Find its horizontal component, correct to 2 decimal places.`,
      ...o,
      explanation: `Horizontal component \\(= F\\cos\\theta\\)\n\n\\(= ${F}\\cos ${ang}° = ${fmtNum(correct, 2)}\\)N`,
    };
  },
];

// ==================== DYNAMICS AND PROJECTILES ====================
const dynamics = [
  // v = u + at
  () => {
    const u = randInt(0, 30), a = randInt(1, 10), t = randInt(1, 12);
    const v = u + a * t;
    const o = buildOptions(v, [u * a * t, u + a, v + t], (x) => `${x}m/s`);
    if (!o) return null;
    return {
      text: `A body starts with velocity ${u}m/s and accelerates uniformly at ${a}m/s² for ${t} seconds. Find its final velocity.`,
      ...o,
      explanation: `\\(v = u + at\\)\n\n\\(= ${u} + (${a})(${t}) = ${u} + ${a * t} = ${v}\\)m/s`,
    };
  },
  // s = ut + 1/2 at^2
  () => {
    const u = randInt(0, 25), a = 2 * randInt(1, 6), t = randInt(1, 10);
    const s = u * t + 0.5 * a * t * t;
    const o = buildOptions(s, [u * t, 0.5 * a * t * t, s + t], (x) => `${fmtNum(x, 2)}m`);
    if (!o) return null;
    return {
      text: `A body moving at ${u}m/s accelerates uniformly at ${a}m/s². How far does it travel in ${t} seconds?`,
      ...o,
      explanation: `\\(s = ut + \\frac{1}{2}at^{2}\\)\n\n\\(= (${u})(${t}) + \\frac{1}{2}(${a})(${t})^{2}\\)\n\n\\(= ${u * t} + ${0.5 * a * t * t} = ${s}\\)m`,
    };
  },
  // v^2 = u^2 + 2as
  () => {
    const u = randInt(0, 20), a = randInt(1, 8), s = randInt(5, 60);
    const vSq = u * u + 2 * a * s;
    const v = Math.sqrt(vSq);
    if (!Number.isInteger(v)) return null;
    const o = buildOptions(v, [vSq, u + a * s, v + 2], (x) => `${x}m/s`);
    if (!o) return null;
    return {
      text: `A body starting with velocity ${u}m/s accelerates at ${a}m/s² over a distance of ${s}m. Find its final velocity.`,
      ...o,
      explanation: `\\(v^{2} = u^{2} + 2as\\)\n\n\\(= ${u * u} + 2(${a})(${s}) = ${u * u} + ${2 * a * s} = ${vSq}\\)\n\n\\(v = \\sqrt{${vSq}} = ${v}\\)m/s`,
    };
  },
  // time of flight of a projectile
  () => {
    const u = 10 * randInt(1, 8);
    const ang = pick([30, 90]);
    const g = 10;
    const T = 2 * u * Math.sin(ang * Math.PI / 180) / g;
    const correct = round(T, 2);
    const o = buildOptions(correct, [round(T / 2, 2), round(u / g, 2), round(T * 2, 2)], (v) => `${fmtNum(v, 2)}s`);
    if (!o) return null;
    return {
      text: `A projectile is fired with speed ${u}m/s at ${ang}° to the horizontal. Find its time of flight. [Take \\(g = 10\\)m/s²]`,
      ...o,
      explanation: `Time of flight \\(T = \\frac{2u\\sin\\theta}{g}\\)\n\n\\(= \\frac{2(${u})\\sin ${ang}°}{10} = ${fmtNum(correct, 2)}\\)s`,
    };
  },
  // maximum height
  () => {
    const u = 10 * randInt(1, 8);
    const g = 10;
    const H = u * u / (2 * g);
    const o = buildOptions(H, [u * u / g, u / g, H * 2], (v) => `${fmtNum(v, 2)}m`);
    if (!o) return null;
    return {
      text: `A body is projected vertically upwards with a velocity of ${u}m/s. Find the maximum height reached. [Take \\(g = 10\\)m/s²]`,
      ...o,
      explanation: `At maximum height the velocity is zero, so \\(0 = u^{2} - 2gH\\).\n\n\\(H = \\frac{u^{2}}{2g} = \\frac{${u * u}}{20} = ${H}\\)m`,
    };
  },
  // Newton's second law
  () => {
    const m = randInt(2, 40), a = randInt(1, 12);
    const F = m * a;
    const o = buildOptions(F, [m + a, m / a, F * 2], (v) => `${v}N`);
    if (!o) return null;
    return {
      text: `Find the force required to give a mass of ${m}kg an acceleration of ${a}m/s².`,
      ...o,
      explanation: `By Newton's second law, \\(F = ma\\).\n\n\\(= ${m} \\times ${a} = ${F}\\)N`,
    };
  },
  // momentum
  () => {
    const m = randInt(2, 50), v = randInt(2, 30);
    const p = m * v;
    const o = buildOptions(p, [m + v, m / v, p / 2], (x) => `${x}kg m/s`);
    if (!o) return null;
    return {
      text: `Calculate the momentum of a body of mass ${m}kg moving with a velocity of ${v}m/s.`,
      ...o,
      explanation: `Momentum \\(= mv\\)\n\n\\(= ${m} \\times ${v} = ${p}\\)kg m/s`,
    };
  },
];

module.exports = [
  { topicId: 'AyCNi56Sd89UQ6BdVa5d', unitId: U_PURE, topicName: 'Trigonometry', generators: fmTrig },
  { topicId: 'bNndPgpFfPKSN3DIyent', unitId: U_PURE, topicName: 'Coordinate Geometry', generators: fmCoord },
  { topicId: 'tLPeRzqVzZjOvGNAQu2t', unitId: U_PURE, topicName: 'Differentiation', generators: fmDiff },
  { topicId: '9ns3cy8iHGz5sMcm6w3K', unitId: U_PURE, topicName: 'Integration', generators: fmInt },
  { topicId: 'ahVieCrqSrCwJg4Ru5Lw', unitId: U_PURE, topicName: 'Indices and Logarithms', generators: fmIndicesLogs },
  { topicId: 'gNH8IoIdavYmQa5XiZIH', unitId: U_STAT, topicName: 'Statistics', generators: fmStats },
  { topicId: '4dZX5PU83IJyWdHxjHaE', unitId: U_STAT, topicName: 'Probability', generators: fmProb },
  { topicId: '2IBxfavU2hzVsf5M5mqJ', unitId: U_VEC, topicName: 'Vectors', generators: fmVectors },
  { topicId: 'LDeAtIODsWnN6gGIxwhG', unitId: U_VEC, topicName: 'Statics', generators: statics },
  { topicId: 'WRt0vAni5CosD7tmpAgW', unitId: U_VEC, topicName: 'Dynamics and Projectiles', generators: dynamics },
];
