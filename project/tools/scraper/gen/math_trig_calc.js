// Mathematics > Trigonometry, Calculus, Statistics & Probability, Vectors & Transformation
const L = require('./lib');
const { randInt, pick, shuffle, sample, nonZero, gcd, frac, fracTex, fracOpt,
        fmtNum, buildOptions, textOptions, round } = L;

const U_TRIG = 'dRthLAyJ0sSMpeWjmKkF';
const U_CALC = 'YMreOBeGL2LBU067S9UB';
const U_STAT = 'Vj9qLjpEoV21IuiGTiUQ';
const U_VEC = 'W2vfBXlR6xWOk2lOkodK';

const mathOpt = (s) => `\\(${s}\\)`;
const TRIPLES = [[3, 4, 5], [5, 12, 13], [8, 15, 17], [7, 24, 25], [20, 21, 29], [9, 40, 41]];

// ============================ TRIGONOMETRY ============================
const EXACT = {
  'sin|0': '0', 'sin|30': '\\frac{1}{2}', 'sin|45': '\\frac{\\sqrt{2}}{2}', 'sin|60': '\\frac{\\sqrt{3}}{2}', 'sin|90': '1',
  'cos|0': '1', 'cos|30': '\\frac{\\sqrt{3}}{2}', 'cos|45': '\\frac{\\sqrt{2}}{2}', 'cos|60': '\\frac{1}{2}', 'cos|90': '0',
  'tan|0': '0', 'tan|30': '\\frac{\\sqrt{3}}{3}', 'tan|45': '1', 'tan|60': '\\sqrt{3}',
};
const EXACT_VALS = Array.from(new Set(Object.values(EXACT)));

const trigRatios = [
  // exact value of a special angle
  () => {
    const key = pick(Object.keys(EXACT));
    const [f, a] = key.split('|');
    const correct = EXACT[key];
    const wrongs = sample(EXACT_VALS.filter(v => v !== correct), 3);
    const o = textOptions(mathOpt(correct), wrongs.map(mathOpt));
    if (!o) return null;
    return {
      text: `Evaluate \\(\\${f} ${a}°\\).`,
      ...o,
      explanation: `From the standard trigonometric ratios of special angles, \\(\\${f} ${a}° = ${correct}\\).`,
    };
  },
  // ratio from a right-angled triangle
  () => {
    const [a, b, c] = pick(TRIPLES);
    const k = randInt(1, 5);
    const [A, B, C] = [a * k, b * k, c * k];
    const which = pick(['sin', 'cos', 'tan']);
    const correct = which === 'sin' ? frac(A, C) : which === 'cos' ? frac(B, C) : frac(A, B);
    const o = buildOptions(correct, [frac(B, C), frac(A, C), frac(A, B), frac(B, A)], (f) => fracOpt(f));
    if (!o) return null;
    const defn = which === 'sin' ? '\\frac{\\text{opposite}}{\\text{hypotenuse}}' : which === 'cos' ? '\\frac{\\text{adjacent}}{\\text{hypotenuse}}' : '\\frac{\\text{opposite}}{\\text{adjacent}}';
    return {
      text: `In a right-angled triangle, the side opposite angle \\(\\theta\\) is ${A}cm, the adjacent side is ${B}cm and the hypotenuse is ${C}cm. Find \\(\\${which} \\theta\\).`,
      ...o,
      explanation: `\\(\\${which} \\theta = ${defn}\\)\n\n\\(= \\frac{${which === 'tan' ? A : which === 'sin' ? A : B}}{${which === 'tan' ? B : C}} = ${fracTex(correct)}\\)`,
    };
  },
  // Pythagorean identity
  () => {
    const [a, b, c] = pick(TRIPLES);
    const given = pick(['sin', 'cos']);
    const gv = given === 'sin' ? frac(a, c) : frac(b, c);
    const correct = given === 'sin' ? frac(b, c) : frac(a, c);
    const other = given === 'sin' ? 'cos' : 'sin';
    const o = buildOptions(correct, [gv, frac(a, b), frac(b, a)], (f) => fracOpt(f));
    if (!o) return null;
    return {
      text: `If \\(\\${given} \\theta = ${fracTex(gv)}\\) and \\(\\theta\\) is acute, find \\(\\${other} \\theta\\).`,
      ...o,
      explanation: `Use \\(\\sin^{2}\\theta + \\cos^{2}\\theta = 1\\).\n\n\\(\\${other}^{2}\\theta = 1 - \\left(${fracTex(gv)}\\right)^{2} = 1 - \\frac{${given === 'sin' ? a * a : b * b}}{${c * c}} = \\frac{${c * c - (given === 'sin' ? a * a : b * b)}}{${c * c}}\\)\n\n\\(\\${other}\\theta = ${fracTex(correct)}\\)`,
    };
  },
  // tan from sin and cos
  () => {
    const [a, b, c] = pick(TRIPLES);
    const correct = frac(a, b);
    const o = buildOptions(correct, [frac(b, a), frac(a, c), frac(c, a)], (f) => fracOpt(f));
    if (!o) return null;
    return {
      text: `Given that \\(\\sin \\theta = ${fracTex(frac(a, c))}\\) and \\(\\cos \\theta = ${fracTex(frac(b, c))}\\), find \\(\\tan \\theta\\).`,
      ...o,
      explanation: `\\(\\tan \\theta = \\frac{\\sin \\theta}{\\cos \\theta}\\)\n\n\\(= ${fracTex(frac(a, c))} \\div ${fracTex(frac(b, c))} = \\frac{${a}}{${c}} \\times \\frac{${c}}{${b}} = ${fracTex(correct)}\\)`,
    };
  },
  // sine rule
  () => {
    const A = pick([30, 45, 60]), B = pick([30, 45, 60, 90]);
    if (A === B) return null;
    const a = randInt(5, 40);
    const rad = (d) => d * Math.PI / 180;
    const b = a * Math.sin(rad(B)) / Math.sin(rad(A));
    const correct = round(b, 1);
    const o = buildOptions(correct, [round(a * Math.sin(rad(A)) / Math.sin(rad(B)), 1), round(b + 2, 1), round(b / 2, 1), round(a + B - A, 1)],
      (v) => `${v.toFixed(1)}cm`);
    if (!o) return null;
    return {
      text: `In triangle \\(PQR\\), \\(\\angle P = ${A}°\\), \\(\\angle Q = ${B}°\\) and \\(p = ${a}\\)cm. Find \\(q\\), correct to 1 decimal place.`,
      ...o,
      explanation: `By the sine rule, \\(\\frac{p}{\\sin P} = \\frac{q}{\\sin Q}\\).\n\n\\(q = \\frac{p \\sin Q}{\\sin P} = \\frac{${a} \\times \\sin ${B}°}{\\sin ${A}°}\\)\n\n\\(= ${correct.toFixed(1)}\\)cm`,
    };
  },
  // cosine rule
  () => {
    const b = randInt(4, 20), c = randInt(4, 20), A = pick([60, 90, 120]);
    const rad = A * Math.PI / 180;
    const aSq = b * b + c * c - 2 * b * c * Math.cos(rad);
    const a = Math.sqrt(aSq);
    const correct = round(a, 1);
    const o = buildOptions(correct, [round(Math.sqrt(b * b + c * c), 1), round(b + c, 1), round(a + 1.5, 1), round(Math.abs(b - c), 1)],
      (v) => `${v.toFixed(1)}cm`);
    if (!o) return null;
    return {
      text: `In triangle \\(ABC\\), \\(b = ${b}\\)cm, \\(c = ${c}\\)cm and \\(\\angle A = ${A}°\\). Find \\(a\\), correct to 1 decimal place.`,
      ...o,
      explanation: `By the cosine rule, \\(a^{2} = b^{2} + c^{2} - 2bc\\cos A\\).\n\n\\(a^{2} = ${b}^{2} + ${c}^{2} - 2(${b})(${c})\\cos ${A}°\\)\n\n\\(a^{2} = ${round(aSq, 2)}\\)\n\n\\(a = ${correct.toFixed(1)}\\)cm`,
    };
  },
  // evaluate a combination of special angles
  () => {
    const pairs = [
      { e: '\\sin 30° + \\cos 60°', v: 1, s: '\\frac{1}{2} + \\frac{1}{2} = 1' },
      { e: '\\sin 90° - \\cos 0°', v: 0, s: '1 - 1 = 0' },
      { e: '\\tan 45° + \\sin 90°', v: 2, s: '1 + 1 = 2' },
      { e: '\\cos 90° + \\sin 0°', v: 0, s: '0 + 0 = 0' },
      { e: '2\\sin 30°', v: 1, s: '2 \\times \\frac{1}{2} = 1' },
      { e: '\\tan 45° \\times \\cos 0°', v: 1, s: '1 \\times 1 = 1' },
      { e: '4\\cos 60°', v: 2, s: '4 \\times \\frac{1}{2} = 2' },
      { e: '\\sin 30° \\times \\tan 45°', v: 0.5, s: '\\frac{1}{2} \\times 1 = \\frac{1}{2}' },
      { e: '6\\sin 30° - \\tan 45°', v: 2, s: '6 \\times \\frac{1}{2} - 1 = 2' },
      { e: '\\cos 0° + \\tan 0°', v: 1, s: '1 + 0 = 1' },
    ];
    const p = pick(pairs);
    const o = buildOptions(p.v, [p.v + 1, p.v - 1, p.v * 2, p.v + 0.5], (v) => fmtNum(v, 2));
    if (!o) return null;
    return {
      text: `Evaluate \\(${p.e}\\).`,
      ...o,
      explanation: `Substitute the exact values of the special angles.\n\n\\(${p.e} = ${p.s}\\)`,
    };
  },
  // find the angle from a ratio
  () => {
    const key = pick(['sin|30', 'sin|60', 'cos|60', 'cos|30', 'tan|45', 'tan|60', 'sin|45', 'cos|45']);
    const [f, a] = key.split('|');
    const val = EXACT[key];
    const o = buildOptions(Number(a), [Number(a) + 15, Number(a) - 15, 90 - Number(a)], (v) => `${v}°`);
    if (!o) return null;
    return {
      text: `If \\(\\${f} \\theta = ${val}\\) and \\(0° \\leq \\theta \\leq 90°\\), find \\(\\theta\\).`,
      ...o,
      explanation: `From the table of special angles, \\(\\${f} ${a}° = ${val}\\).\n\nSo \\(\\theta = ${a}°\\).`,
    };
  },
];

// ================= ANGLES OF ELEVATION AND DEPRESSION =================
const elevation = [
  // 45 degrees: exact
  () => {
    const d = randInt(5, 80);
    const o = buildOptions(d, [d * 2, d / 2, d + 5, round(d * Math.sqrt(2), 1)], (v) => `${fmtNum(v, 2)}m`);
    if (!o) return null;
    return {
      text: `The angle of elevation of the top of a tower from a point ${d}m away on level ground is 45°. Find the height of the tower.`,
      ...o,
      explanation: `\\(\\tan 45° = \\frac{\\text{height}}{\\text{distance}}\\)\n\n\\(1 = \\frac{h}{${d}}\\)\n\n\\(h = ${d}\\)m`,
    };
  },
  // ladder against a wall with cos 60
  () => {
    const foot = randInt(2, 30);
    const len = 2 * foot;                       // cos 60 = 1/2
    const o = buildOptions(len, [foot / 2, foot + 2, round(foot * Math.sqrt(3), 1), foot * 3], (v) => `${fmtNum(v, 2)}m`);
    if (!o) return null;
    return {
      text: `A ladder leans against a vertical wall making an angle of 60° with the horizontal ground. If the foot of the ladder is ${foot}m from the wall, find the length of the ladder.`,
      ...o,
      explanation: `\\(\\cos 60° = \\frac{\\text{distance from wall}}{\\text{length of ladder}}\\)\n\n\\(\\frac{1}{2} = \\frac{${foot}}{L}\\)\n\n\\(L = 2 \\times ${foot} = ${len}\\)m`,
    };
  },
  // elevation with 30 or 60, rounded
  () => {
    const d = randInt(10, 90);
    const ang = pick([30, 60]);
    const h = d * Math.tan(ang * Math.PI / 180);
    const correct = round(h, 2);
    const o = buildOptions(correct, [round(d / Math.tan(ang * Math.PI / 180), 2), round(h * 2, 2), round(h / 2, 2), d],
      (v) => `${v.toFixed(2)}m`);
    if (!o) return null;
    return {
      text: `From a point ${d}m from the foot of a vertical pole on level ground, the angle of elevation of the top of the pole is ${ang}°. Find the height of the pole, correct to 2 decimal places.`,
      ...o,
      explanation: `\\(\\tan ${ang}° = \\frac{h}{${d}}\\)\n\n\\(h = ${d} \\times \\tan ${ang}°\\)\n\n\\(= ${d} \\times ${round(Math.tan(ang * Math.PI / 180), 4)} = ${correct.toFixed(2)}\\)m`,
    };
  },
  // angle of depression equals angle of elevation
  () => {
    const a = randInt(15, 75);
    const o = buildOptions(a, [90 - a, 180 - a, a + 10], (v) => `${v}°`);
    if (!o) return null;
    return {
      text: `From the top of a cliff, the angle of depression of a boat at sea is ${a}°. What is the angle of elevation of the top of the cliff from the boat?`,
      ...o,
      explanation: `The angle of depression from the top and the angle of elevation from the boat are alternate angles between two horizontal parallel lines.\n\nSo the angle of elevation is also ${a}°.`,
    };
  },
  // find the distance given height and 45
  () => {
    const h = randInt(5, 70);
    const o = buildOptions(h, [h * 2, h / 2, round(h * Math.sqrt(2), 1)], (v) => `${fmtNum(v, 2)}m`);
    if (!o) return null;
    return {
      text: `A vertical pole is ${h}m high. If the angle of elevation of its top from a point on the ground is 45°, how far is the point from the foot of the pole?`,
      ...o,
      explanation: `\\(\\tan 45° = \\frac{${h}}{d}\\)\n\n\\(1 = \\frac{${h}}{d}\\)\n\n\\(d = ${h}\\)m`,
    };
  },
  // using a Pythagorean triple: find the angle's sine
  () => {
    const [a, b, c] = pick(TRIPLES);
    const k = randInt(1, 4);
    const correct = frac(a, c);
    const o = buildOptions(correct, [frac(b, c), frac(a, b), frac(c, a)], (f) => fracOpt(f));
    if (!o) return null;
    return {
      text: `A man stands ${b * k}m from the foot of a vertical tower of height ${a * k}m. If the distance from the man to the top of the tower is ${c * k}m, find the sine of the angle of elevation of the top of the tower.`,
      ...o,
      explanation: `The angle of elevation \\(\\theta\\) has the tower height as the opposite side and the line of sight as the hypotenuse.\n\n\\(\\sin \\theta = \\frac{\\text{opposite}}{\\text{hypotenuse}} = \\frac{${a * k}}{${c * k}} = ${fracTex(correct)}\\)`,
    };
  },
];

// ============================== BEARINGS ==============================
const bearings = [
  // back bearing
  () => {
    const b = randInt(1, 359);
    const correct = b < 180 ? b + 180 : b - 180;
    const o = buildOptions(correct, [360 - b, b, (b + 90) % 360], (v) => `${String(v).padStart(3, '0')}°`);
    if (!o) return null;
    return {
      text: `The bearing of \\(Q\\) from \\(P\\) is ${String(b).padStart(3, '0')}°. Find the bearing of \\(P\\) from \\(Q\\).`,
      ...o,
      explanation: `The back bearing differs from the forward bearing by 180°.\n\n${b < 180 ? `Since ${b}° is less than 180°, add 180°: \\(${b}° + 180° = ${correct}°\\)` : `Since ${b}° is 180° or more, subtract 180°: \\(${b}° - 180° = ${correct}°\\)`}`,
    };
  },
  // compass direction to bearing
  () => {
    const dirs = [
      { d: 'due North', b: 0 }, { d: 'due East', b: 90 }, { d: 'due South', b: 180 }, { d: 'due West', b: 270 },
      { d: 'North-East', b: 45 }, { d: 'South-East', b: 135 }, { d: 'South-West', b: 225 }, { d: 'North-West', b: 315 },
    ];
    const x = pick(dirs);
    const o = buildOptions(x.b, dirs.filter(d => d.b !== x.b).map(d => d.b), (v) => `${String(v).padStart(3, '0')}°`);
    if (!o) return null;
    return {
      text: `What is the bearing of a point lying ${x.d} of an observer?`,
      ...o,
      explanation: `Bearings are measured clockwise from the North direction.\n\n${x.d} corresponds to a bearing of ${String(x.b).padStart(3, '0')}°.`,
    };
  },
  // distance after walking north then east
  () => {
    const [a, b, c] = pick(TRIPLES);
    const k = randInt(1, 4);
    const o = buildOptions(c * k, [(a + b) * k, Math.abs(b - a) * k, c * k + 2], (v) => `${v}km`);
    if (!o) return null;
    return {
      text: `A man walks ${a * k}km due North and then ${b * k}km due East. How far is he from his starting point?`,
      ...o,
      explanation: `North and East are perpendicular, so use Pythagoras' theorem.\n\n\\(d^{2} = ${a * k}^{2} + ${b * k}^{2} = ${(a * k) ** 2} + ${(b * k) ** 2} = ${(c * k) ** 2}\\)\n\n\\(d = ${c * k}\\)km`,
    };
  },
  // angle between two bearings
  () => {
    const b1 = randInt(10, 170), b2 = randInt(180, 350);
    const diff = b2 - b1;
    const correct = diff > 180 ? 360 - diff : diff;
    const o = buildOptions(correct, [diff, 360 - correct, correct + 20], (v) => `${v}°`);
    if (!o) return null;
    return {
      text: `From a point \\(O\\), the bearing of \\(A\\) is ${String(b1).padStart(3, '0')}° and the bearing of \\(B\\) is ${String(b2).padStart(3, '0')}°. Find the angle \\(AOB\\).`,
      ...o,
      explanation: `The angle between the two directions is the difference between the bearings.\n\n\\(${b2}° - ${b1}° = ${diff}°\\)\n\n${diff > 180 ? `Since this exceeds 180°, the required angle is \\(360° - ${diff}° = ${correct}°\\).` : `So \\(\\angle AOB = ${correct}°\\).`}`,
    };
  },
  // bearing expressed in N..E form
  () => {
    const a = randInt(10, 80);
    const correct = a;
    const o = buildOptions(correct, [180 - a, 360 - a, 90 + a], (v) => `${String(v).padStart(3, '0')}°`);
    if (!o) return null;
    return {
      text: `Express the direction N${a}°E as a three-figure bearing.`,
      ...o,
      explanation: `N${a}°E means ${a}° measured from North towards the East.\n\nAs a three-figure bearing this is ${String(correct).padStart(3, '0')}°.`,
    };
  },
  // bearing S..W form
  () => {
    const a = randInt(10, 80);
    const correct = 180 + a;
    const o = buildOptions(correct, [180 - a, 360 - a, a], (v) => `${String(v).padStart(3, '0')}°`);
    if (!o) return null;
    return {
      text: `Express the direction S${a}°W as a three-figure bearing.`,
      ...o,
      explanation: `Measuring clockwise from North: South is 180°, and S${a}°W is a further ${a}° towards the West.\n\n\\(180° + ${a}° = ${correct}°\\)`,
    };
  },
];

// =========================== DIFFERENTIATION ===========================
function dPoly(terms) { return terms.filter(([c, p]) => p !== 0).map(([c, p]) => [c * p, p - 1]); }
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

const differentiation = [
  // derivative of a polynomial
  () => {
    const a = nonZero(-6, 8), b = nonZero(-8, 8), c = nonZero(-10, 10);
    const terms = [[a, 3], [b, 2], [c, 1]];
    const d = dPoly(terms);
    const wrong1 = [[a, 2], [b, 1], [c, 0]];
    const wrong2 = dPoly([[a, 3], [b, 2], [c, 1]]).map(([x, p]) => [x, p + 1]);
    const wrong3 = [[a * 3, 2], [b * 2, 1], [0, 0]];
    const o = buildOptions(d, [wrong1, wrong2, wrong3], (t) => mathOpt(polyTex(t)));
    if (!o) return null;
    return {
      text: `Differentiate \\(y = ${polyTex(terms)}\\) with respect to \\(x\\).`,
      ...o,
      explanation: `Differentiate each term using \\(\\frac{d}{dx}(ax^{n}) = nax^{n-1}\\).\n\n\\(\\frac{d}{dx}(${polyTex([[a, 3]])}) = ${polyTex([[3 * a, 2]])}\\)\n\n\\(\\frac{d}{dx}(${polyTex([[b, 2]])}) = ${polyTex([[2 * b, 1]])}\\)\n\n\\(\\frac{d}{dx}(${polyTex([[c, 1]])}) = ${c}\\)\n\nSo \\(\\frac{dy}{dx} = ${polyTex(d)}\\).`,
    };
  },
  // gradient at a point
  () => {
    const a = nonZero(-5, 6), b = nonZero(-8, 8), c = nonZero(-9, 9), k = nonZero(-4, 4);
    const grad = 2 * a * k + b;
    const o = buildOptions(grad, [a * k * k + b * k + c, 2 * a * k, grad + a, -grad], (v) => String(v));
    if (!o) return null;
    return {
      text: `Find the gradient of the curve \\(y = ${polyTex([[a, 2], [b, 1], [c, 0]])}\\) at the point where \\(x = ${k}\\).`,
      ...o,
      explanation: `\\(\\frac{dy}{dx} = ${polyTex([[2 * a, 1], [b, 0]])}\\)\n\nAt \\(x = ${k}\\): \\(\\frac{dy}{dx} = ${2 * a}(${k}) ${b > 0 ? '+' : '-'} ${Math.abs(b)}\\)\n\n\\(= ${2 * a * k} ${b > 0 ? '+' : '-'} ${Math.abs(b)} = ${grad}\\)`,
    };
  },
  // turning point x value
  () => {
    const a = nonZero(-5, 5), b = 2 * a * nonZero(-5, 5), c = nonZero(-9, 9);
    const x = -b / (2 * a);
    if (!Number.isInteger(x)) return null;
    const o = buildOptions(x, [-x, x + 1, b / (2 * a)], (v) => mathOpt(`x = ${v}`));
    if (!o) return null;
    return {
      text: `Find the value of \\(x\\) at the turning point of the curve \\(y = ${polyTex([[a, 2], [b, 1], [c, 0]])}\\).`,
      ...o,
      explanation: `At a turning point, \\(\\frac{dy}{dx} = 0\\).\n\n\\(\\frac{dy}{dx} = ${polyTex([[2 * a, 1], [b, 0]])} = 0\\)\n\n\\(${2 * a}x = ${-b}\\)\n\n\\(x = ${x}\\)`,
    };
  },
  // derivative of a single power term
  () => {
    const a = nonZero(-9, 9), n = randInt(2, 8);
    const o = buildOptions([a * n, n - 1], [[a, n - 1], [a * n, n], [a * (n + 1), n]], (t) => mathOpt(polyTex([t])));
    if (!o) return null;
    return {
      text: `Find \\(\\frac{dy}{dx}\\) if \\(y = ${polyTex([[a, n]])}\\).`,
      ...o,
      explanation: `Use \\(\\frac{d}{dx}(ax^{n}) = nax^{n-1}\\).\n\n\\(\\frac{dy}{dx} = ${n} \\times ${a}x^{${n}-1} = ${polyTex([[a * n, n - 1]])}\\)`,
    };
  },
  // second derivative
  () => {
    const a = nonZero(-5, 6), b = nonZero(-7, 7);
    const first = dPoly([[a, 3], [b, 2]]);
    const second = dPoly(first);
    const o = buildOptions(second, [first, dPoly(second), [[a * 6, 2]]], (t) => mathOpt(polyTex(t)));
    if (!o) return null;
    return {
      text: `Find \\(\\frac{d^{2}y}{dx^{2}}\\) if \\(y = ${polyTex([[a, 3], [b, 2]])}\\).`,
      ...o,
      explanation: `First derivative: \\(\\frac{dy}{dx} = ${polyTex(first)}\\)\n\nDifferentiate again: \\(\\frac{d^{2}y}{dx^{2}} = ${polyTex(second)}\\)`,
    };
  },
  // rate of change / velocity from displacement
  () => {
    const a = nonZero(-4, 6), b = nonZero(-8, 8), c = randInt(-9, 9), t = randInt(1, 6);
    const v = 2 * a * t + b;
    const o = buildOptions(v, [a * t * t + b * t + c, 2 * a * t, v + b, -v], (x) => `${x}m/s`);
    if (!o) return null;
    return {
      text: `The displacement of a particle is given by \\(s = ${polyTex([[a, 2], [b, 1], [c, 0]], 't')}\\). Find its velocity when \\(t = ${t}\\).`,
      ...o,
      explanation: `Velocity is the rate of change of displacement: \\(v = \\frac{ds}{dt}\\).\n\n\\(v = ${polyTex([[2 * a, 1], [b, 0]], 't')}\\)\n\nAt \\(t = ${t}\\): \\(v = ${2 * a}(${t}) ${b > 0 ? '+' : '-'} ${Math.abs(b)} = ${v}\\)m/s`,
    };
  },
];

// ============================= INTEGRATION =============================
const integration = [
  // indefinite integral of a power
  () => {
    const a = nonZero(-9, 9), n = randInt(1, 7);
    const newC = a / (n + 1);
    if (!Number.isInteger(newC)) return null;
    const correct = `${polyTex([[newC, n + 1]])} + c`;
    const wrongs = [
      `${polyTex([[a, n + 1]])} + c`,
      `${polyTex([[a * n, n - 1]])} + c`,
      `${polyTex([[newC, n]])} + c`,
    ];
    const o = textOptions(mathOpt(correct), wrongs.map(mathOpt));
    if (!o) return null;
    return {
      text: `Evaluate \\(\\int ${polyTex([[a, n]])}\\,dx\\).`,
      ...o,
      explanation: `Use \\(\\int ax^{n}dx = \\frac{ax^{n+1}}{n+1} + c\\).\n\n\\(= \\frac{${a}x^{${n + 1}}}{${n + 1}} + c = ${polyTex([[newC, n + 1]])} + c\\)`,
    };
  },
  // indefinite integral of a two-term polynomial
  () => {
    const a = nonZero(-4, 5) * 2, b = nonZero(-9, 9);
    const t1 = a / 2;
    if (!Number.isInteger(t1)) return null;
    const correct = `${polyTex([[t1, 2], [b, 1]])} + c`;
    const wrongs = [
      `${polyTex([[a, 2], [b, 1]])} + c`,
      `${polyTex([[a, 1], [0, 0]])} + c`,
      `${polyTex([[t1, 2], [b, 2]])} + c`,
    ];
    const o = textOptions(mathOpt(correct), wrongs.map(mathOpt));
    if (!o) return null;
    return {
      text: `Find \\(\\int (${polyTex([[a, 1], [b, 0]])})\\,dx\\).`,
      ...o,
      explanation: `Integrate term by term.\n\n\\(\\int ${polyTex([[a, 1]])}dx = ${polyTex([[t1, 2]])}\\)\n\n\\(\\int ${b}\\,dx = ${polyTex([[b, 1]])}\\)\n\nSo the integral is \\(${correct}\\).`,
    };
  },
  // definite integral of a linear function
  () => {
    const a = nonZero(-4, 5) * 2, b = nonZero(-8, 8);
    const lo = randInt(0, 3), hi = lo + randInt(1, 5);
    const F = (x) => (a / 2) * x * x + b * x;
    const correct = F(hi) - F(lo);
    const o = buildOptions(correct, [F(hi) + F(lo), F(lo) - F(hi), correct + a, correct / 2], (v) => String(v));
    if (!o) return null;
    return {
      text: `Evaluate \\(\\int_{${lo}}^{${hi}} (${polyTex([[a, 1], [b, 0]])})\\,dx\\).`,
      ...o,
      explanation: `\\(\\int (${polyTex([[a, 1], [b, 0]])})dx = ${polyTex([[a / 2, 2], [b, 1]])}\\)\n\nAt \\(x = ${hi}\\): \\(${F(hi)}\\)\n\nAt \\(x = ${lo}\\): \\(${F(lo)}\\)\n\nDifference \\(= ${F(hi)} - (${F(lo)}) = ${correct}\\)`,
    };
  },
  // definite integral of a quadratic
  () => {
    const a = 3 * nonZero(-2, 3), b = 2 * nonZero(-3, 3);
    const lo = randInt(0, 2), hi = lo + randInt(1, 4);
    const F = (x) => (a / 3) * x * x * x + (b / 2) * x * x;
    const correct = F(hi) - F(lo);
    if (!Number.isInteger(correct)) return null;
    const o = buildOptions(correct, [F(hi) + F(lo), correct * 2, correct + a, -correct], (v) => String(v));
    if (!o) return null;
    return {
      text: `Evaluate \\(\\int_{${lo}}^{${hi}} (${polyTex([[a, 2], [b, 1]])})\\,dx\\).`,
      ...o,
      explanation: `\\(\\int (${polyTex([[a, 2], [b, 1]])})dx = ${polyTex([[a / 3, 3], [b / 2, 2]])}\\)\n\nAt \\(x = ${hi}\\): \\(${F(hi)}\\)\n\nAt \\(x = ${lo}\\): \\(${F(lo)}\\)\n\nSo the integral \\(= ${F(hi)} - (${F(lo)}) = ${correct}\\)`,
    };
  },
  // integral of a constant
  () => {
    const k = nonZero(-12, 12);
    const correct = `${polyTex([[k, 1]])} + c`;
    const wrongs = [`${polyTex([[k, 2]])} + c`, `${k} + c`, `${polyTex([[k / 2, 2]])} + c`];
    const o = textOptions(mathOpt(correct), wrongs.map(mathOpt));
    if (!o) return null;
    return {
      text: `Evaluate \\(\\int ${k}\\,dx\\).`,
      ...o,
      explanation: `The integral of a constant \\(k\\) with respect to \\(x\\) is \\(kx + c\\).\n\n\\(\\int ${k}\\,dx = ${polyTex([[k, 1]])} + c\\)`,
    };
  },
  // area under a curve
  () => {
    const a = 3 * randInt(1, 4);
    const hi = randInt(1, 4);
    const area = (a / 3) * hi * hi * hi;
    const o = buildOptions(area, [a * hi * hi, area * 2, area / 2, a * hi], (v) => `${fmtNum(v, 2)} square units`);
    if (!o) return null;
    return {
      text: `Find the area bounded by the curve \\(y = ${polyTex([[a, 2]])}\\), the x-axis, and the lines \\(x = 0\\) and \\(x = ${hi}\\).`,
      ...o,
      explanation: `Area \\(= \\int_{0}^{${hi}} ${polyTex([[a, 2]])}\\,dx\\)\n\n\\(= \\left[${polyTex([[a / 3, 3]])}\\right]_{0}^{${hi}}\\)\n\n\\(= ${a / 3}(${hi})^{3} - 0 = ${area}\\) square units`,
    };
  },
];

// ============================= STATISTICS =============================
const statistics = [
  // mean of a list
  () => {
    const n = randInt(5, 9);
    const vals = Array.from({ length: n }, () => randInt(1, 30));
    const sum = vals.reduce((a, b) => a + b, 0);
    if (sum % n !== 0) return null;
    const correct = sum / n;
    const o = buildOptions(correct, [sum, correct + 1, correct - 1, Math.max(...vals)], (v) => fmtNum(v, 2));
    if (!o) return null;
    return {
      text: `Find the mean of the following numbers: ${vals.join(', ')}.`,
      ...o,
      explanation: `Mean \\(= \\frac{\\sum x}{n}\\)\n\nSum \\(= ${vals.join(' + ')} = ${sum}\\)\n\nMean \\(= \\frac{${sum}}{${n}} = ${correct}\\)`,
    };
  },
  // median
  () => {
    const n = pick([5, 7, 9]);
    const vals = Array.from({ length: n }, () => randInt(1, 40));
    const sorted = vals.slice().sort((a, b) => a - b);
    const correct = sorted[(n - 1) / 2];
    const o = buildOptions(correct, [sorted[0], sorted[n - 1], round(vals.reduce((a, b) => a + b, 0) / n, 1)], (v) => String(v));
    if (!o) return null;
    return {
      text: `Find the median of the following set of numbers: ${vals.join(', ')}.`,
      ...o,
      explanation: `Arrange the numbers in ascending order: ${sorted.join(', ')}\n\nThere are ${n} values, so the median is the ${(n + 1) / 2}th value.\n\nMedian \\(= ${correct}\\)`,
    };
  },
  // mode
  () => {
    const modeVal = randInt(1, 15);
    const others = sample([16, 17, 18, 19, 20, 21, 22, 23, 24, 25], 3);
    const vals = shuffle([modeVal, modeVal, modeVal, ...others]);
    const o = buildOptions(modeVal, others, (v) => String(v));
    if (!o) return null;
    return {
      text: `Find the mode of the following set of numbers: ${vals.join(', ')}.`,
      ...o,
      explanation: `The mode is the value that occurs most frequently.\n\n${modeVal} appears 3 times, more than any other value.\n\nMode \\(= ${modeVal}\\)`,
    };
  },
  // range
  () => {
    const vals = Array.from({ length: randInt(5, 8) }, () => randInt(1, 60));
    const hi = Math.max(...vals), lo = Math.min(...vals);
    const correct = hi - lo;
    if (correct === 0) return null;
    const o = buildOptions(correct, [hi, lo, hi + lo], (v) => String(v));
    if (!o) return null;
    return {
      text: `Find the range of the following set of numbers: ${vals.join(', ')}.`,
      ...o,
      explanation: `Range \\(= \\text{highest value} - \\text{lowest value}\\)\n\n\\(= ${hi} - ${lo} = ${correct}\\)`,
    };
  },
  // missing value given the mean
  () => {
    const n = randInt(4, 6);
    const vals = Array.from({ length: n }, () => randInt(1, 20));
    const mean = randInt(5, 20);
    const x = mean * (n + 1) - vals.reduce((a, b) => a + b, 0);
    if (x <= 0 || x > 60) return null;
    const o = buildOptions(x, [mean, x + 2, x - 2, vals.reduce((a, b) => a + b, 0)], (v) => String(v));
    if (!o) return null;
    return {
      text: `The mean of ${vals.join(', ')} and \\(x\\) is ${mean}. Find the value of \\(x\\).`,
      ...o,
      explanation: `There are ${n + 1} values in total.\n\n\\(\\frac{${vals.join(' + ')} + x}{${n + 1}} = ${mean}\\)\n\n\\(${vals.reduce((a, b) => a + b, 0)} + x = ${mean * (n + 1)}\\)\n\n\\(x = ${x}\\)`,
    };
  },
  // mean from a small frequency distribution
  () => {
    const scores = [1, 2, 3, 4, 5];
    const freqs = scores.map(() => randInt(1, 8));
    const total = freqs.reduce((a, b) => a + b, 0);
    const sumfx = scores.reduce((acc, s, i) => acc + s * freqs[i], 0);
    if (sumfx % total !== 0) return null;
    const correct = sumfx / total;
    const o = buildOptions(correct, [total, sumfx, correct + 1], (v) => fmtNum(v, 2));
    if (!o) return null;
    return {
      text: `The scores of some students are: ${scores.map((s, i) => `${s} (${freqs[i]} students)`).join(', ')}. Find the mean score.`,
      ...o,
      explanation: `Mean \\(= \\frac{\\sum fx}{\\sum f}\\)\n\n\\(\\sum fx = ${scores.map((s, i) => `${s} \\times ${freqs[i]}`).join(' + ')} = ${sumfx}\\)\n\n\\(\\sum f = ${total}\\)\n\nMean \\(= \\frac{${sumfx}}{${total}} = ${correct}\\)`,
    };
  },
  // mean after removing a value
  () => {
    const n = randInt(8, 25);
    const mean = randInt(3, 15);
    const total = n * mean;
    const removed = randInt(mean + 1, mean + 30);
    const newMean = (total - removed) / (n - 1);
    if (!Number.isInteger(newMean) || newMean <= 0) return null;
    const o = buildOptions(newMean, [mean, newMean + 1, round(total / (n - 1), 2)], (v) => fmtNum(v, 2));
    if (!o) return null;
    return {
      text: `The mean of ${n} numbers is ${mean}. If one of the numbers, ${removed}, is removed, find the mean of the remaining numbers.`,
      ...o,
      explanation: `Total of all ${n} numbers \\(= ${n} \\times ${mean} = ${total}\\)\n\nTotal after removing ${removed} \\(= ${total} - ${removed} = ${total - removed}\\)\n\nNew mean \\(= \\frac{${total - removed}}{${n - 1}} = ${newMean}\\)`,
    };
  },
];

// ============================= PROBABILITY =============================
const COLOURS = [['red', 'blue'], ['green', 'yellow'], ['black', 'white'], ['red', 'green'], ['blue', 'white']];

const probability = [
  // single draw
  () => {
    const [c1, c2] = pick(COLOURS);
    const n1 = randInt(2, 12), n2 = randInt(2, 12);
    const total = n1 + n2;
    const correct = frac(n1, total);
    const o = buildOptions(correct, [frac(n2, total), frac(n1, n2), frac(total, n1)], (f) => fracOpt(f));
    if (!o) return null;
    return {
      text: `A bag contains ${n1} ${c1} balls and ${n2} ${c2} balls. If one ball is picked at random, what is the probability that it is ${c1}?`,
      ...o,
      explanation: `Total number of balls \\(= ${n1} + ${n2} = ${total}\\)\n\n\\(P(\\text{${c1}}) = \\frac{\\text{number of ${c1} balls}}{\\text{total}} = \\frac{${n1}}{${total}}\\)${fracTex(correct) === `\\frac{${n1}}{${total}}` ? '' : `\n\nIn lowest terms this is \\(${fracTex(correct)}\\).`}`,
    };
  },
  // two draws with replacement
  () => {
    const [c1, c2] = pick(COLOURS);
    const n1 = randInt(2, 9), n2 = randInt(2, 9);
    const total = n1 + n2;
    const correct = frac(n1 * n1, total * total);
    const o = buildOptions(correct, [frac(n1, total), frac(n1 * (n1 - 1), total * (total - 1)), frac(n2 * n2, total * total)], (f) => fracOpt(f));
    if (!o) return null;
    return {
      text: `A box contains ${n1} ${c1} balls and ${n2} ${c2} balls. Two balls are drawn at random one after the other with replacement. Find the probability that both are ${c1}.`,
      ...o,
      explanation: `With replacement, the total stays at ${total} for both draws.\n\n\\(P(${c1}) = \\frac{${n1}}{${total}}\\) each time.\n\n\\(P(\\text{both } ${c1}) = \\frac{${n1}}{${total}} \\times \\frac{${n1}}{${total}} = ${fracTex(correct)}\\)`,
    };
  },
  // two draws without replacement
  () => {
    const [c1, c2] = pick(COLOURS);
    const n1 = randInt(3, 9), n2 = randInt(2, 9);
    const total = n1 + n2;
    const correct = frac(n1 * (n1 - 1), total * (total - 1));
    const o = buildOptions(correct, [frac(n1 * n1, total * total), frac(n1, total), frac(n2 * (n2 - 1), total * (total - 1))], (f) => fracOpt(f));
    if (!o) return null;
    return {
      text: `A bag contains ${n1} ${c1} balls and ${n2} ${c2} balls. Two balls are picked at random without replacement. Find the probability that both are ${c1}.`,
      ...o,
      explanation: `First draw: \\(P = \\frac{${n1}}{${total}}\\)\n\nAfter removing one ${c1} ball, ${n1 - 1} ${c1} balls remain out of ${total - 1}.\n\nSecond draw: \\(P = \\frac{${n1 - 1}}{${total - 1}}\\)\n\n\\(P(\\text{both}) = \\frac{${n1}}{${total}} \\times \\frac{${n1 - 1}}{${total - 1}} = ${fracTex(correct)}\\)`,
    };
  },
  // complementary event
  () => {
    const d = randInt(3, 20);
    const n = randInt(1, d - 1);
    const p = frac(n, d);
    const correct = frac(d - n, d);
    const o = buildOptions(correct, [p, frac(n, d - n), frac(d, n)], (f) => fracOpt(f));
    if (!o) return null;
    return {
      text: `The probability that a student passes an examination is \\(${fracTex(p)}\\). What is the probability that the student fails?`,
      ...o,
      explanation: `\\(P(\\text{fail}) = 1 - P(\\text{pass})\\)\n\n\\(= 1 - ${fracTex(p)} = ${fracTex(correct)}\\)`,
    };
  },
  // single die
  () => {
    const events = [
      { d: 'an even number', n: 3 }, { d: 'an odd number', n: 3 }, { d: 'a prime number', n: 3 },
      { d: 'a number greater than 4', n: 2 }, { d: 'a number less than 3', n: 2 }, { d: 'a multiple of 3', n: 2 },
      { d: 'a 6', n: 1 }, { d: 'a number greater than 2', n: 4 },
    ];
    const e = pick(events);
    const correct = frac(e.n, 6);
    const o = buildOptions(correct, [frac(6 - e.n, 6), frac(e.n, 12), frac(1, 6)], (f) => fracOpt(f));
    if (!o) return null;
    return {
      text: `A fair die is thrown once. What is the probability of obtaining ${e.d}?`,
      ...o,
      explanation: `A die has 6 equally likely outcomes.\n\nThe number of outcomes giving ${e.d} is ${e.n}.\n\n\\(P = \\frac{${e.n}}{6} = ${fracTex(correct)}\\)`,
    };
  },
  // either/or (mutually exclusive)
  () => {
    const [c1, c2] = pick(COLOURS);
    const n1 = randInt(2, 10), n2 = randInt(2, 10), n3 = randInt(2, 10);
    const total = n1 + n2 + n3;
    const correct = frac(n1 + n2, total);
    const o = buildOptions(correct, [frac(n1 * n2, total * total), frac(n3, total), frac(n1, total)], (f) => fracOpt(f));
    if (!o) return null;
    return {
      text: `A bag contains ${n1} ${c1} balls, ${n2} ${c2} balls and ${n3} orange balls. One ball is picked at random. Find the probability that it is either ${c1} or ${c2}.`,
      ...o,
      explanation: `Total \\(= ${n1} + ${n2} + ${n3} = ${total}\\)\n\nThese events are mutually exclusive, so add the probabilities.\n\n\\(P(${c1} \\text{ or } ${c2}) = \\frac{${n1}}{${total}} + \\frac{${n2}}{${total}} = \\frac{${n1 + n2}}{${total}} = ${fracTex(correct)}\\)`,
    };
  },
  // two coins
  () => {
    const events = [
      { d: 'two heads', n: 1 }, { d: 'two tails', n: 1 }, { d: 'exactly one head', n: 2 },
      { d: 'at least one head', n: 3 }, { d: 'at least one tail', n: 3 },
    ];
    const e = pick(events);
    const correct = frac(e.n, 4);
    const o = buildOptions(correct, [frac(4 - e.n, 4), frac(1, 2), frac(e.n, 8)], (f) => fracOpt(f));
    if (!o) return null;
    return {
      text: `Two fair coins are tossed together. Find the probability of obtaining ${e.d}.`,
      ...o,
      explanation: `The possible outcomes are HH, HT, TH, TT — 4 equally likely outcomes.\n\nThe number of outcomes giving ${e.d} is ${e.n}.\n\n\\(P = \\frac{${e.n}}{4} = ${fracTex(correct)}\\)`,
    };
  },
  // independent events
  () => {
    const a = randInt(1, 5), b = randInt(2, 9);
    const c = randInt(1, 5), d = randInt(2, 9);
    if (a >= b || c >= d) return null;
    const p1 = frac(a, b), p2 = frac(c, d);
    const correct = frac(a * c, b * d);
    const o = buildOptions(correct, [frac(a * d + c * b, b * d), p1, p2], (f) => fracOpt(f));
    if (!o) return null;
    return {
      text: `The probability that Ada passes Mathematics is \\(${fracTex(p1)}\\) and the probability that she passes English is \\(${fracTex(p2)}\\). If the two events are independent, find the probability that she passes both subjects.`,
      ...o,
      explanation: `For independent events, \\(P(A \\text{ and } B) = P(A) \\times P(B)\\).\n\n\\(= ${fracTex(p1)} \\times ${fracTex(p2)} = ${fracTex(correct)}\\)`,
    };
  },
];

// ========================= VECTORS IN A PLANE =========================
const vecTex = (a, b) => `\\begin{pmatrix} ${a} \\\\ ${b} \\end{pmatrix}`;
const vecOpt = (v) => mathOpt(vecTex(v[0], v[1]));

const vectors = [
  // magnitude
  () => {
    const [a, b, c] = pick(TRIPLES);
    const sx = pick([1, -1]), sy = pick([1, -1]);
    const x = a * sx, y = b * sy;
    const o = buildOptions(c, [a + b, Math.abs(a - b), c + 1], (v) => String(v));
    if (!o) return null;
    return {
      text: `Find the magnitude of the vector \\(${vecTex(x, y)}\\).`,
      ...o,
      explanation: `\\(|\\mathbf{v}| = \\sqrt{x^{2} + y^{2}}\\)\n\n\\(= \\sqrt{(${x})^{2} + (${y})^{2}} = \\sqrt{${x * x} + ${y * y}} = \\sqrt{${c * c}} = ${c}\\)`,
    };
  },
  // addition
  () => {
    const a = [nonZero(-9, 9), nonZero(-9, 9)], b = [nonZero(-9, 9), nonZero(-9, 9)];
    const s = [a[0] + b[0], a[1] + b[1]];
    const o = buildOptions(s, [[a[0] - b[0], a[1] - b[1]], [a[0] * b[0], a[1] * b[1]], [s[1], s[0]]], vecOpt);
    if (!o) return null;
    return {
      text: `Given \\(\\mathbf{a} = ${vecTex(a[0], a[1])}\\) and \\(\\mathbf{b} = ${vecTex(b[0], b[1])}\\), find \\(\\mathbf{a} + \\mathbf{b}\\).`,
      ...o,
      explanation: `Add corresponding components.\n\n\\(${a[0]} + (${b[0]}) = ${s[0]}\\)\n\n\\(${a[1]} + (${b[1]}) = ${s[1]}\\)\n\nSo \\(\\mathbf{a} + \\mathbf{b} = ${vecTex(s[0], s[1])}\\).`,
    };
  },
  // subtraction
  () => {
    const a = [nonZero(-9, 9), nonZero(-9, 9)], b = [nonZero(-9, 9), nonZero(-9, 9)];
    const s = [a[0] - b[0], a[1] - b[1]];
    const o = buildOptions(s, [[a[0] + b[0], a[1] + b[1]], [b[0] - a[0], b[1] - a[1]], [s[1], s[0]]], vecOpt);
    if (!o) return null;
    return {
      text: `Given \\(\\mathbf{a} = ${vecTex(a[0], a[1])}\\) and \\(\\mathbf{b} = ${vecTex(b[0], b[1])}\\), find \\(\\mathbf{a} - \\mathbf{b}\\).`,
      ...o,
      explanation: `Subtract corresponding components.\n\n\\(${a[0]} - (${b[0]}) = ${s[0]}\\)\n\n\\(${a[1]} - (${b[1]}) = ${s[1]}\\)\n\nSo \\(\\mathbf{a} - \\mathbf{b} = ${vecTex(s[0], s[1])}\\).`,
    };
  },
  // scalar multiple
  () => {
    const a = [nonZero(-8, 8), nonZero(-8, 8)];
    const k = nonZero(-5, 6);
    const s = [a[0] * k, a[1] * k];
    const o = buildOptions(s, [[a[0] + k, a[1] + k], [a[0] * k, a[1]], [s[1], s[0]]], vecOpt);
    if (!o) return null;
    return {
      text: `If \\(\\mathbf{a} = ${vecTex(a[0], a[1])}\\), find \\(${k}\\mathbf{a}\\).`,
      ...o,
      explanation: `Multiply each component by ${k}.\n\n\\(${k} \\times ${a[0]} = ${s[0]}\\)\n\n\\(${k} \\times ${a[1]} = ${s[1]}\\)\n\nSo \\(${k}\\mathbf{a} = ${vecTex(s[0], s[1])}\\).`,
    };
  },
  // combination 2a + 3b
  () => {
    const a = [nonZero(-6, 6), nonZero(-6, 6)], b = [nonZero(-6, 6), nonZero(-6, 6)];
    const m = randInt(2, 4), n = randInt(2, 4);
    const s = [m * a[0] + n * b[0], m * a[1] + n * b[1]];
    const o = buildOptions(s, [[m * a[0] - n * b[0], m * a[1] - n * b[1]], [a[0] + b[0], a[1] + b[1]], [s[1], s[0]]], vecOpt);
    if (!o) return null;
    return {
      text: `Given \\(\\mathbf{a} = ${vecTex(a[0], a[1])}\\) and \\(\\mathbf{b} = ${vecTex(b[0], b[1])}\\), find \\(${m}\\mathbf{a} + ${n}\\mathbf{b}\\).`,
      ...o,
      explanation: `\\(${m}\\mathbf{a} = ${vecTex(m * a[0], m * a[1])}\\)\n\n\\(${n}\\mathbf{b} = ${vecTex(n * b[0], n * b[1])}\\)\n\nAdding the components gives \\(${vecTex(s[0], s[1])}\\).`,
    };
  },
  // vector from point A to B
  () => {
    const A = [randInt(-9, 9), randInt(-9, 9)], B = [randInt(-9, 9), randInt(-9, 9)];
    const s = [B[0] - A[0], B[1] - A[1]];
    if (s[0] === 0 && s[1] === 0) return null;
    const o = buildOptions(s, [[A[0] - B[0], A[1] - B[1]], [A[0] + B[0], A[1] + B[1]], [s[1], s[0]]], vecOpt);
    if (!o) return null;
    return {
      text: `If \\(A(${A[0]}, ${A[1]})\\) and \\(B(${B[0]}, ${B[1]})\\), find \\(\\overrightarrow{AB}\\).`,
      ...o,
      explanation: `\\(\\overrightarrow{AB} = \\mathbf{b} - \\mathbf{a}\\)\n\n\\(= ${vecTex(B[0], B[1])} - ${vecTex(A[0], A[1])} = ${vecTex(s[0], s[1])}\\)`,
    };
  },
];

// =========================== TRANSFORMATION ===========================
const transformation = [
  // reflection in an axis
  () => {
    const x = nonZero(-9, 9), y = nonZero(-9, 9);
    const kind = pick([
      { d: 'the x-axis', f: (p) => [p[0], -p[1]], e: 'Reflection in the x-axis keeps \\(x\\) and changes the sign of \\(y\\).' },
      { d: 'the y-axis', f: (p) => [-p[0], p[1]], e: 'Reflection in the y-axis changes the sign of \\(x\\) and keeps \\(y\\).' },
      { d: 'the line \\(y = x\\)', f: (p) => [p[1], p[0]], e: 'Reflection in the line \\(y = x\\) interchanges the coordinates.' },
      { d: 'the origin', f: (p) => [-p[0], -p[1]], e: 'Reflection in the origin changes the sign of both coordinates.' },
    ]);
    const img = kind.f([x, y]);
    const o = buildOptions(img, [[x, y], [-img[0], img[1]], [img[1], img[0]]], (p) => mathOpt(`(${p[0]}, ${p[1]})`));
    if (!o) return null;
    return {
      text: `Find the image of the point \\((${x}, ${y})\\) under a reflection in ${kind.d}.`,
      ...o,
      explanation: `${kind.e}\n\nSo \\((${x}, ${y}) \\rightarrow (${img[0]}, ${img[1]})\\).`,
    };
  },
  // translation
  () => {
    const x = randInt(-9, 9), y = randInt(-9, 9);
    const a = nonZero(-8, 8), b = nonZero(-8, 8);
    const img = [x + a, y + b];
    const o = buildOptions(img, [[x - a, y - b], [a, b], [img[1], img[0]]], (p) => mathOpt(`(${p[0]}, ${p[1]})`));
    if (!o) return null;
    return {
      text: `Find the image of the point \\((${x}, ${y})\\) under the translation \\(\\begin{pmatrix} ${a} \\\\ ${b} \\end{pmatrix}\\).`,
      ...o,
      explanation: `Add the translation vector to the position vector of the point.\n\n\\(x: ${x} + (${a}) = ${img[0]}\\)\n\n\\(y: ${y} + (${b}) = ${img[1]}\\)\n\nSo the image is \\((${img[0]}, ${img[1]})\\).`,
    };
  },
  // rotation about the origin
  () => {
    const x = nonZero(-9, 9), y = nonZero(-9, 9);
    const kind = pick([
      { d: '90° anticlockwise', f: (p) => [-p[1], p[0]] },
      { d: '90° clockwise', f: (p) => [p[1], -p[0]] },
      { d: '180°', f: (p) => [-p[0], -p[1]] },
    ]);
    const img = kind.f([x, y]);
    const o = buildOptions(img, [[x, y], [img[1], img[0]], [-img[0], -img[1]]], (p) => mathOpt(`(${p[0]}, ${p[1]})`));
    if (!o) return null;
    return {
      text: `Find the image of the point \\((${x}, ${y})\\) under a rotation of ${kind.d} about the origin.`,
      ...o,
      explanation: `Under a rotation of ${kind.d} about the origin, \\((x, y) \\rightarrow (${kind.d === '90° anticlockwise' ? '-y, x' : kind.d === '90° clockwise' ? 'y, -x' : '-x, -y'})\\).\n\nSo \\((${x}, ${y}) \\rightarrow (${img[0]}, ${img[1]})\\).`,
    };
  },
  // enlargement
  () => {
    const x = nonZero(-8, 8), y = nonZero(-8, 8), k = nonZero(-4, 5);
    if (k === 1) return null;
    const img = [x * k, y * k];
    const o = buildOptions(img, [[x + k, y + k], [x, y], [img[1], img[0]]], (p) => mathOpt(`(${p[0]}, ${p[1]})`));
    if (!o) return null;
    return {
      text: `Find the image of the point \\((${x}, ${y})\\) under an enlargement with centre the origin and scale factor ${k}.`,
      ...o,
      explanation: `Multiply both coordinates by the scale factor ${k}.\n\n\\(${k} \\times ${x} = ${img[0]}\\)\n\n\\(${k} \\times ${y} = ${img[1]}\\)\n\nSo the image is \\((${img[0]}, ${img[1]})\\).`,
    };
  },
  // find the translation vector from object and image
  () => {
    const x = randInt(-8, 8), y = randInt(-8, 8);
    const a = nonZero(-8, 8), b = nonZero(-8, 8);
    const img = [x + a, y + b];
    const o = buildOptions([a, b], [[-a, -b], [img[0], img[1]], [b, a]], (p) => mathOpt(`\\begin{pmatrix} ${p[0]} \\\\ ${p[1]} \\end{pmatrix}`));
    if (!o) return null;
    return {
      text: `A translation maps the point \\((${x}, ${y})\\) onto \\((${img[0]}, ${img[1]})\\). Find the translation vector.`,
      ...o,
      explanation: `The translation vector is the image minus the object.\n\n\\(x: ${img[0]} - (${x}) = ${a}\\)\n\n\\(y: ${img[1]} - (${y}) = ${b}\\)\n\nSo the vector is \\(\\begin{pmatrix} ${a} \\\\ ${b} \\end{pmatrix}\\).`,
    };
  },
];

module.exports = [
  { topicId: 'XtziwsDi9PQfI58tqnmQ', unitId: U_TRIG, topicName: 'Angles of Elevation and Depression', generators: elevation },
  { topicId: 'bz56Yuz1DWjCCsEWC8iA', unitId: U_TRIG, topicName: 'Sine Cosine Tangent', generators: trigRatios },
  { topicId: 's326YQ1xJSFIiwkTJ0JZ', unitId: U_TRIG, topicName: 'Bearings', generators: bearings },
  { topicId: 'xT9o6hvoZcKZ9nXfr6Nn', unitId: U_CALC, topicName: 'Differentiation', generators: differentiation },
  { topicId: 'y9tBzH3xCxsQaN00Yq0L', unitId: U_CALC, topicName: 'Integration', generators: integration },
  { topicId: 'TzNBHiEyjggS80ZwGfU3', unitId: U_STAT, topicName: 'Statistics', generators: statistics },
  { topicId: 'NurtzfptDkKsMSxLme7Z', unitId: U_STAT, topicName: 'Probability', generators: probability },
  { topicId: 'gxZo4Ja9gio4IbXe3Yjn', unitId: U_VEC, topicName: 'Vectors in a Plane', generators: vectors },
  { topicId: '31ljkVXvTXWV6XSjbC8G', unitId: U_VEC, topicName: 'Transformation', generators: transformation },
];
