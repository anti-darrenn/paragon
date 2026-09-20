// Physics > Measurement and Units, Motion
const L = require('./lib');
const { randInt, pick, shuffle, sample, nonZero, frac, fracTex, fracOpt,
        fmtNum, buildOptions, textOptions, round } = L;
const { conceptGens, qaBank } = require('./concept');

const U_MEAS = 'm5gnVhetLYv5NU7KbZ0v';
const U_MOTION = '9wqW7Xs4MAIDqdtbCIme';
const mathOpt = (s) => `\\(${s}\\)`;
const TRIPLES = [[3, 4, 5], [5, 12, 13], [8, 15, 17], [7, 24, 25], [20, 21, 29], [9, 40, 41]];
const G = 10;

// ============= FUNDAMENTAL AND DERIVED QUANTITIES =============
const FUNDAMENTAL = [
  { q: 'mass', u: 'kilogram (kg)' }, { q: 'length', u: 'metre (m)' }, { q: 'time', u: 'second (s)' },
  { q: 'electric current', u: 'ampere (A)' }, { q: 'thermodynamic temperature', u: 'kelvin (K)' },
  { q: 'amount of substance', u: 'mole (mol)' }, { q: 'luminous intensity', u: 'candela (cd)' },
];
const DERIVED = [
  { q: 'force', u: 'newton (N)' }, { q: 'energy', u: 'joule (J)' }, { q: 'power', u: 'watt (W)' },
  { q: 'pressure', u: 'pascal (Pa)' }, { q: 'charge', u: 'coulomb (C)' }, { q: 'frequency', u: 'hertz (Hz)' },
  { q: 'resistance', u: 'ohm (Ω)' }, { q: 'velocity', u: 'metre per second (m/s)' },
  { q: 'acceleration', u: 'metre per second squared (m/s²)' }, { q: 'density', u: 'kilogram per cubic metre (kg/m³)' },
];

const quantities = [
  // which is a fundamental quantity
  () => {
    const t = pick(FUNDAMENTAL);
    const w = sample(DERIVED, 3);
    const o = textOptions(t.q.charAt(0).toUpperCase() + t.q.slice(1), w.map(x => x.q.charAt(0).toUpperCase() + x.q.slice(1)));
    if (!o) return null;
    return {
      text: `Which of the following is a fundamental (base) physical quantity?`,
      ...o,
      explanation: `There are seven fundamental quantities: mass, length, time, electric current, thermodynamic temperature, amount of substance and luminous intensity.\n\n${t.q.charAt(0).toUpperCase() + t.q.slice(1)} is one of them. The others listed are derived quantities, obtained by combining fundamental quantities.`,
    };
  },
  // SI unit of a quantity
  () => {
    const all = [...FUNDAMENTAL, ...DERIVED];
    const t = pick(all);
    const w = sample(all.filter(x => x.u !== t.u), 3);
    const o = textOptions(t.u, w.map(x => x.u));
    if (!o) return null;
    return {
      text: `What is the SI unit of ${t.q}?`,
      ...o,
      explanation: `The SI unit of ${t.q} is the ${t.u}.`,
    };
  },
  // which is a derived quantity
  () => {
    const t = pick(DERIVED);
    const w = sample(FUNDAMENTAL, 3);
    const o = textOptions(t.q.charAt(0).toUpperCase() + t.q.slice(1), w.map(x => x.q.charAt(0).toUpperCase() + x.q.slice(1)));
    if (!o) return null;
    return {
      text: `Which of the following is a derived physical quantity?`,
      ...o,
      explanation: `A derived quantity is obtained by combining fundamental quantities.\n\n${t.q.charAt(0).toUpperCase() + t.q.slice(1)} is derived; its unit, the ${t.u}, is built from base units. The other options are fundamental quantities.`,
    };
  },
  // prefix conversion
  () => {
    const prefixes = [
      { p: 'kilo', f: 1e3 }, { p: 'centi', f: 1e-2 }, { p: 'milli', f: 1e-3 },
      { p: 'micro', f: 1e-6 }, { p: 'mega', f: 1e6 }, { p: 'nano', f: 1e-9 },
    ];
    const pr = pick(prefixes);
    const n = randInt(2, 900);
    const correct = n * pr.f;
    const o = buildOptions(correct, [n / pr.f, n * pr.f * 10, n * pr.f / 10], (v) => `${v.toExponential(2)} m`);
    if (!o) return null;
    return {
      text: `Express ${n} ${pr.p}metres in metres.`,
      ...o,
      explanation: `The prefix "${pr.p}" means a factor of \\(${pr.f.toExponential(0).replace('e', ' \\times 10^{').replace('+', '')}}\\).\n\n\\(${n} \\times ${pr.f.toExponential(0)} = ${correct.toExponential(2)}\\) m`,
    };
  },
];

// ============= DIMENSIONS AND DIMENSIONAL ANALYSIS =============
const DIMS = [
  { q: 'force', d: 'MLT^{-2}' }, { q: 'energy', d: 'ML^{2}T^{-2}' }, { q: 'power', d: 'ML^{2}T^{-3}' },
  { q: 'pressure', d: 'ML^{-1}T^{-2}' }, { q: 'velocity', d: 'LT^{-1}' }, { q: 'acceleration', d: 'LT^{-2}' },
  { q: 'momentum', d: 'MLT^{-1}' }, { q: 'density', d: 'ML^{-3}' }, { q: 'work', d: 'ML^{2}T^{-2}' },
  { q: 'area', d: 'L^{2}' }, { q: 'volume', d: 'L^{3}' }, { q: 'frequency', d: 'T^{-1}' },
];

const dimensions = [
  // dimension of a quantity
  () => {
    const t = pick(DIMS);
    const w = sample(DIMS.filter(x => x.d !== t.d), 3);
    const o = textOptions(mathOpt(t.d), w.map(x => mathOpt(x.d)));
    if (!o) return null;
    return {
      text: `What is the dimension of ${t.q}?`,
      ...o,
      explanation: `The dimension of ${t.q} is \\(${t.d}\\), obtained by expressing it in terms of mass \\(M\\), length \\(L\\) and time \\(T\\).`,
    };
  },
  // which quantity has a given dimension
  () => {
    const t = pick(DIMS);
    const w = sample(DIMS.filter(x => x.d !== t.d), 3);
    const o = textOptions(t.q.charAt(0).toUpperCase() + t.q.slice(1), w.map(x => x.q.charAt(0).toUpperCase() + x.q.slice(1)));
    if (!o) return null;
    return {
      text: `Which physical quantity has the dimension \\(${t.d}\\)?`,
      ...o,
      explanation: `\\(${t.d}\\) is the dimensional formula for ${t.q}.`,
    };
  },
  ...conceptGens('dimensional analysis', [
    'Dimensional analysis can be used to check the homogeneity of an equation',
    'Quantities that are added together must have the same dimensions',
    'Dimensionless constants cannot be determined by dimensional analysis',
    'Both sides of a correct physical equation have the same dimensions',
    'Angle is a dimensionless quantity',
    'Dimensional analysis can be used to derive the form of a relationship between quantities',
  ], [
    'Dimensional analysis can determine the value of numerical constants in an equation',
    'Quantities with different dimensions can be added together',
    'An equation that is dimensionally correct must always be physically correct',
    'All physical constants are dimensionless',
    'Dimensions depend on the system of units used',
    'Two quantities with the same dimensions must be the same quantity',
  ]),
];

// ===================== SCALARS AND VECTORS =====================
const SCALARS = ['mass', 'time', 'temperature', 'speed', 'distance', 'energy', 'work', 'power', 'density', 'volume', 'electric charge'];
const VECTORS = ['force', 'velocity', 'acceleration', 'displacement', 'momentum', 'weight', 'electric field intensity', 'torque'];

const scalarsVectors = [
  // identify a scalar
  () => {
    const t = pick(SCALARS);
    const w = sample(VECTORS, 3);
    const cap = (s) => s.charAt(0).toUpperCase() + s.slice(1);
    const o = textOptions(cap(t), w.map(cap));
    if (!o) return null;
    return {
      text: `Which of the following is a scalar quantity?`,
      ...o,
      explanation: `A scalar quantity has magnitude only, with no direction.\n\n${cap(t)} is a scalar. The other options are vector quantities, which have both magnitude and direction.`,
    };
  },
  // identify a vector
  () => {
    const t = pick(VECTORS);
    const w = sample(SCALARS, 3);
    const cap = (s) => s.charAt(0).toUpperCase() + s.slice(1);
    const o = textOptions(cap(t), w.map(cap));
    if (!o) return null;
    return {
      text: `Which of the following is a vector quantity?`,
      ...o,
      explanation: `A vector quantity has both magnitude and direction.\n\n${cap(t)} is a vector. The other options are scalars, having magnitude only.`,
    };
  },
  // resultant of two perpendicular vectors
  () => {
    const [p, q, r] = pick(TRIPLES);
    const k = randInt(1, 5);
    const o = buildOptions(r * k, [(p + q) * k, Math.abs(p - q) * k, r * k + 3], (v) => `${v}N`);
    if (!o) return null;
    return {
      text: `Two forces of ${p * k}N and ${q * k}N act at right angles to each other. Find the magnitude of the resultant force.`,
      ...o,
      explanation: `For perpendicular vectors, \\(R = \\sqrt{F_1^{2} + F_2^{2}}\\).\n\n\\(= \\sqrt{${(p * k) ** 2} + ${(q * k) ** 2}} = \\sqrt{${(r * k) ** 2}} = ${r * k}\\)N`,
    };
  },
  // parallel and antiparallel resultants
  () => {
    const a = randInt(5, 50), b = randInt(5, 50);
    const same = Math.random() < 0.5;
    const correct = same ? a + b : Math.abs(a - b);
    const o = buildOptions(correct, [same ? Math.abs(a - b) : a + b, a * b, round(Math.sqrt(a * a + b * b), 1)], (v) => `${fmtNum(v, 2)}N`);
    if (!o) return null;
    return {
      text: `Two forces of ${a}N and ${b}N act on a body in ${same ? 'the same direction' : 'opposite directions'}. Find the magnitude of their resultant.`,
      ...o,
      explanation: `${same ? 'Forces in the same direction add together.' : 'Forces in opposite directions subtract.'}\n\n\\(R = ${same ? `${a} + ${b}` : `|${a} - ${b}|`} = ${correct}\\)N`,
    };
  },
  // component of a vector
  () => {
    const F = randInt(10, 80);
    const ang = pick([0, 30, 45, 60, 90]);
    const horiz = F * Math.cos(ang * Math.PI / 180);
    const correct = round(horiz, 2);
    const o = buildOptions(correct, [round(F * Math.sin(ang * Math.PI / 180), 2), F, round(correct / 2, 2)], (v) => `${fmtNum(v, 2)}N`);
    if (!o) return null;
    return {
      text: `A force of ${F}N acts at an angle of ${ang}° to the horizontal. Calculate its horizontal component, correct to 2 decimal places.`,
      ...o,
      explanation: `The horizontal component is \\(F\\cos\\theta\\).\n\n\\(= ${F} \\times \\cos ${ang}° = ${fmtNum(correct, 2)}\\)N`,
    };
  },
];

// ======================== SPEED AND VELOCITY ========================
const speedVelocity = [
  // v = d / t
  () => {
    const v = randInt(2, 40), t = randInt(2, 20);
    const d = v * t;
    const o = buildOptions(v, [d, d + t, round(d / (t + 1), 2)], (x) => `${fmtNum(x, 2)}m/s`);
    if (!o) return null;
    return {
      text: `A body covers a distance of ${d}m in ${t} seconds. Calculate its average speed.`,
      ...o,
      explanation: `\\(\\text{speed} = \\frac{\\text{distance}}{\\text{time}}\\)\n\n\\(= \\frac{${d}}{${t}} = ${v}\\)m/s`,
    };
  },
  // km/h to m/s
  () => {
    const kmh = 18 * randInt(1, 12);
    const ms = kmh * 1000 / 3600;
    const o = buildOptions(ms, [kmh * 3.6, kmh / 3.6 + 5, kmh], (v) => `${fmtNum(v, 2)}m/s`);
    if (!o) return null;
    return {
      text: `Convert ${kmh}km/h to metres per second.`,
      ...o,
      explanation: `\\(1\\)km/h \\(= \\frac{1000}{3600}\\)m/s \\(= \\frac{1}{3.6}\\)m/s\n\n\\(${kmh} \\div 3.6 = ${ms}\\)m/s`,
    };
  },
  // m/s to km/h
  () => {
    const ms = randInt(2, 60);
    const kmh = ms * 3.6;
    const o = buildOptions(kmh, [ms / 3.6, ms * 1000, ms + 3.6], (v) => `${fmtNum(v, 2)}km/h`);
    if (!o) return null;
    return {
      text: `Convert ${ms}m/s to kilometres per hour.`,
      ...o,
      explanation: `Multiply by 3.6 to convert m/s to km/h.\n\n\\(${ms} \\times 3.6 = ${fmtNum(kmh, 2)}\\)km/h`,
    };
  },
  // average speed of a two-stage journey
  () => {
    const d1 = randInt(20, 120), d2 = randInt(20, 120);
    const t1 = randInt(1, 5), t2 = randInt(1, 5);
    const avg = (d1 + d2) / (t1 + t2);
    const o = buildOptions(round(avg, 2), [round((d1 / t1 + d2 / t2) / 2, 2), round(d1 / t1, 2), round(avg + 5, 2)],
      (v) => `${fmtNum(v, 2)}km/h`);
    if (!o) return null;
    return {
      text: `A car travels ${d1}km in ${t1} hour${t1 > 1 ? 's' : ''} and then ${d2}km in ${t2} hour${t2 > 1 ? 's' : ''}. Find its average speed for the whole journey.`,
      ...o,
      explanation: `Average speed \\(= \\frac{\\text{total distance}}{\\text{total time}}\\)\n\n\\(= \\frac{${d1} + ${d2}}{${t1} + ${t2}} = \\frac{${d1 + d2}}{${t1 + t2}} = ${fmtNum(avg, 2)}\\)km/h`,
    };
  },
  // difference between speed and velocity
  () => {
    const bank = [
      { q: 'What is the difference between speed and velocity?', a: 'Speed is a scalar while velocity is a vector', w: ['Speed is a vector while velocity is a scalar', 'They are exactly the same quantity', 'Speed has direction while velocity does not'], e: 'Speed is the rate of change of distance and has magnitude only. Velocity is the rate of change of displacement and has both magnitude and direction.' },
      { q: 'A body moves round a circular track and returns to its starting point. What is its average velocity?', a: 'Zero', w: ['Equal to its average speed', 'Equal to the circumference divided by time', 'Cannot be determined'], e: 'Average velocity is total displacement divided by time. Returning to the starting point gives zero displacement, so the average velocity is zero, even though the average speed is not.' },
      { q: 'Which quantity is defined as the rate of change of displacement?', a: 'Velocity', w: ['Speed', 'Acceleration', 'Distance'], e: 'Velocity is the rate of change of displacement with time. Speed is the rate of change of distance, and acceleration is the rate of change of velocity.' },
    ];
    return qaBank(bank)();
  },
  // uniform velocity time
  () => {
    const v = randInt(5, 40), t = randInt(2, 15);
    const d = v * t;
    const o = buildOptions(t, [d, v, round(d / v + 2, 2)], (x) => `${fmtNum(x, 2)}s`);
    if (!o) return null;
    return {
      text: `How long does it take a body moving with a uniform velocity of ${v}m/s to cover ${d}m?`,
      ...o,
      explanation: `\\(t = \\frac{s}{v} = \\frac{${d}}{${v}} = ${t}\\)s`,
    };
  },
];

// ============ ACCELERATION AND EQUATIONS OF MOTION ============
const equationsOfMotion = [
  // v = u + at
  () => {
    const u = randInt(0, 30), a = randInt(1, 10), t = randInt(1, 12);
    const v = u + a * t;
    const o = buildOptions(v, [u * a * t, u + a, v - u], (x) => `${x}m/s`);
    if (!o) return null;
    return {
      text: `A car moving at ${u}m/s accelerates uniformly at ${a}m/s² for ${t} seconds. Find its final velocity.`,
      ...o,
      explanation: `\\(v = u + at\\)\n\n\\(= ${u} + (${a})(${t}) = ${u} + ${a * t} = ${v}\\)m/s`,
    };
  },
  // a = (v - u)/t
  () => {
    const u = randInt(0, 25), a = randInt(1, 9), t = randInt(2, 12);
    const v = u + a * t;
    const o = buildOptions(a, [v - u, (v + u) / t, a + 2], (x) => `${fmtNum(x, 2)}m/s²`);
    if (!o) return null;
    return {
      text: `A body accelerates uniformly from ${u}m/s to ${v}m/s in ${t} seconds. Calculate its acceleration.`,
      ...o,
      explanation: `\\(a = \\frac{v - u}{t}\\)\n\n\\(= \\frac{${v} - ${u}}{${t}} = \\frac{${v - u}}{${t}} = ${a}\\)m/s²`,
    };
  },
  // s = ut + 1/2 a t^2
  () => {
    const u = randInt(0, 20), a = 2 * randInt(1, 6), t = randInt(2, 10);
    const s = u * t + 0.5 * a * t * t;
    const o = buildOptions(s, [u * t, 0.5 * a * t * t, s + t], (x) => `${fmtNum(x, 2)}m`);
    if (!o) return null;
    return {
      text: `A body starts from a velocity of ${u}m/s and accelerates at ${a}m/s². What distance does it cover in ${t} seconds?`,
      ...o,
      explanation: `\\(s = ut + \\frac{1}{2}at^{2}\\)\n\n\\(= (${u})(${t}) + \\frac{1}{2}(${a})(${t}^{2})\\)\n\n\\(= ${u * t} + ${0.5 * a * t * t} = ${s}\\)m`,
    };
  },
  // v^2 = u^2 + 2as
  () => {
    const u = randInt(0, 20), a = randInt(1, 8), s = randInt(5, 60);
    const vSq = u * u + 2 * a * s;
    const v = Math.sqrt(vSq);
    if (!Number.isInteger(v)) return null;
    const o = buildOptions(v, [vSq, u + a * s, v + 3], (x) => `${x}m/s`);
    if (!o) return null;
    return {
      text: `A body with initial velocity ${u}m/s accelerates uniformly at ${a}m/s² over a distance of ${s}m. Find its final velocity.`,
      ...o,
      explanation: `\\(v^{2} = u^{2} + 2as\\)\n\n\\(= ${u * u} + 2(${a})(${s}) = ${vSq}\\)\n\n\\(v = \\sqrt{${vSq}} = ${v}\\)m/s`,
    };
  },
  // retardation to rest
  () => {
    const u = 2 * randInt(3, 25), t = randInt(2, 12);
    const a = u / t;
    if (!Number.isInteger(a)) return null;
    const o = buildOptions(a, [-a, u * t, u + t], (x) => `${fmtNum(x, 2)}m/s²`);
    if (!o) return null;
    return {
      text: `A car moving at ${u}m/s is brought to rest in ${t} seconds. Calculate the magnitude of its retardation.`,
      ...o,
      explanation: `The final velocity is 0.\n\n\\(a = \\frac{v - u}{t} = \\frac{0 - ${u}}{${t}} = ${-a}\\)m/s²\n\nThe magnitude of the retardation is ${a}m/s².`,
    };
  },
  // free fall
  () => {
    const t = randInt(1, 8);
    const h = 0.5 * G * t * t;
    const o = buildOptions(h, [G * t, G * t * t, h / 2], (x) => `${fmtNum(x, 2)}m`);
    if (!o) return null;
    return {
      text: `A body is released from rest and falls freely for ${t} seconds. How far does it fall? [Take \\(g = 10\\)m/s²]`,
      ...o,
      explanation: `\\(h = ut + \\frac{1}{2}gt^{2}\\), with \\(u = 0\\).\n\n\\(h = \\frac{1}{2}(10)(${t})^{2} = ${h}\\)m`,
    };
  },
  // distance in the nth second
  () => {
    const u = randInt(0, 15), a = 2 * randInt(1, 5), n = randInt(2, 8);
    const sn = u + a * (2 * n - 1) / 2;
    const o = buildOptions(sn, [u + a * n, u * n + 0.5 * a * n * n, sn + a], (x) => `${fmtNum(x, 2)}m`);
    if (!o) return null;
    return {
      text: `A body starting with velocity ${u}m/s accelerates at ${a}m/s². Find the distance it covers during the ${n}th second.`,
      ...o,
      explanation: `\\(s_{n} = u + \\frac{a}{2}(2n - 1)\\)\n\n\\(= ${u} + \\frac{${a}}{2}(2 \\times ${n} - 1)\\)\n\n\\(= ${u} + ${a / 2} \\times ${2 * n - 1} = ${sn}\\)m`,
    };
  },
];

// ============ DISTANCE, DISPLACEMENT AND POSITION ============
const distanceDisplacement = [
  // resultant displacement, perpendicular legs
  () => {
    const [p, q, r] = pick(TRIPLES);
    const k = randInt(1, 5);
    const o = buildOptions(r * k, [(p + q) * k, Math.abs(p - q) * k, r * k + 2], (v) => `${v}m`);
    if (!o) return null;
    return {
      text: `A man walks ${p * k}m due north and then ${q * k}m due east. Calculate the magnitude of his displacement from the starting point.`,
      ...o,
      explanation: `North and east are perpendicular, so use Pythagoras' theorem.\n\n\\(s = \\sqrt{${p * k}^{2} + ${q * k}^{2}} = \\sqrt{${(r * k) ** 2}} = ${r * k}\\)m\n\nNote the total distance walked is ${(p + q) * k}m, but displacement is the straight-line distance.`,
    };
  },
  // distance vs displacement round trip
  () => {
    const d = randInt(10, 200);
    const o = buildOptions(0, [d, 2 * d, d / 2], (v) => `${fmtNum(v, 2)}m`);
    if (!o) return null;
    return {
      text: `A body travels ${d}m due east and then returns ${d}m due west to its starting point. What is its total displacement?`,
      ...o,
      explanation: `Displacement is the straight-line distance from start to finish, with direction.\n\nThe body ends where it started, so the displacement is 0m, even though the total distance travelled is ${2 * d}m.`,
    };
  },
  // total distance of a round trip
  () => {
    const d = randInt(10, 200);
    const o = buildOptions(2 * d, [0, d, 4 * d], (v) => `${fmtNum(v, 2)}m`);
    if (!o) return null;
    return {
      text: `A body travels ${d}m due east and then returns ${d}m due west. What is the total distance travelled?`,
      ...o,
      explanation: `Distance is a scalar and takes no account of direction, so the two legs add.\n\n\\(${d} + ${d} = ${2 * d}\\)m`,
    };
  },
  // displacement along a straight line
  () => {
    const a = randInt(10, 100), b = randInt(10, 100);
    const correct = Math.abs(a - b);
    if (correct === 0) return null;
    const o = buildOptions(correct, [a + b, a, b], (v) => `${v}m`);
    if (!o) return null;
    return {
      text: `A body moves ${a}m to the right and then ${b}m to the left along a straight line. Find the magnitude of its resultant displacement.`,
      ...o,
      explanation: `Taking right as positive: \\(+${a} - ${b} = ${a - b}\\)m\n\nThe magnitude of the displacement is ${correct}m.`,
    };
  },
  ...conceptGens('distance and displacement', [
    'Distance is a scalar quantity while displacement is a vector quantity',
    'Displacement is the shortest straight-line distance between two points',
    'The magnitude of displacement can never exceed the distance travelled',
    'Displacement can be zero even when the distance travelled is not zero',
    'Distance travelled can never be negative',
  ], [
    'Displacement is always equal to the distance travelled',
    'Distance is a vector quantity while displacement is a scalar',
    'Displacement can never be zero for a moving body',
    'The distance travelled can be less than the magnitude of the displacement',
    'Distance has both magnitude and direction',
  ]),
];

// ========================= PROJECTILE MOTION =========================
const projectile = [
  // time of flight
  () => {
    const u = 10 * randInt(1, 8);
    const ang = pick([30, 90]);
    const T = 2 * u * Math.sin(ang * Math.PI / 180) / G;
    const correct = round(T, 2);
    const o = buildOptions(correct, [round(T / 2, 2), round(u / G, 2), round(T * 2, 2)], (v) => `${fmtNum(v, 2)}s`);
    if (!o) return null;
    return {
      text: `A projectile is launched with a speed of ${u}m/s at ${ang}° to the horizontal. Calculate its time of flight. [Take \\(g = 10\\)m/s²]`,
      ...o,
      explanation: `\\(T = \\frac{2u\\sin\\theta}{g}\\)\n\n\\(= \\frac{2(${u})\\sin ${ang}°}{10} = ${fmtNum(correct, 2)}\\)s`,
    };
  },
  // maximum height (vertical projection)
  () => {
    const u = 10 * randInt(1, 9);
    const H = u * u / (2 * G);
    const o = buildOptions(H, [u * u / G, u / G, H * 2], (v) => `${fmtNum(v, 2)}m`);
    if (!o) return null;
    return {
      text: `A ball is thrown vertically upwards with a velocity of ${u}m/s. Find the maximum height it reaches. [Take \\(g = 10\\)m/s²]`,
      ...o,
      explanation: `At the maximum height the velocity is zero.\n\n\\(v^{2} = u^{2} - 2gH \\Rightarrow 0 = ${u * u} - 20H\\)\n\n\\(H = \\frac{${u * u}}{20} = ${H}\\)m`,
    };
  },
  // range
  () => {
    const u = 10 * randInt(1, 8);
    const ang = 45;
    const R = u * u * Math.sin(2 * ang * Math.PI / 180) / G;
    const correct = round(R, 2);
    const o = buildOptions(correct, [round(R / 2, 2), round(u * u / G / 2, 2), round(R * 2, 2)], (v) => `${fmtNum(v, 2)}m`);
    if (!o) return null;
    return {
      text: `A body is projected at ${ang}° to the horizontal with a speed of ${u}m/s. Calculate its horizontal range. [Take \\(g = 10\\)m/s²]`,
      ...o,
      explanation: `\\(R = \\frac{u^{2}\\sin 2\\theta}{g}\\)\n\n\\(= \\frac{${u * u} \\times \\sin 90°}{10} = \\frac{${u * u}}{10} = ${fmtNum(correct, 2)}\\)m`,
    };
  },
  // horizontal projection from a height
  () => {
    const h = 5 * randInt(1, 16);
    const t = Math.sqrt(2 * h / G);
    const correct = round(t, 2);
    const o = buildOptions(correct, [round(h / G, 2), round(2 * h / G, 2), round(t * 2, 2)], (v) => `${fmtNum(v, 2)}s`);
    if (!o) return null;
    return {
      text: `A stone is projected horizontally from the top of a tower of height ${h}m. How long does it take to reach the ground? [Take \\(g = 10\\)m/s²]`,
      ...o,
      explanation: `The vertical motion starts from rest: \\(h = \\frac{1}{2}gt^{2}\\).\n\n\\(${h} = 5t^{2}\\)\n\n\\(t^{2} = ${h / 5}\\), so \\(t = ${fmtNum(correct, 2)}\\)s`,
    };
  },
  // angle for maximum range
  () => {
    const o = buildOptions(45, [30, 60, 90], (v) => `${v}°`);
    if (!o) return null;
    return {
      text: `At what angle to the horizontal should a projectile be launched to achieve the maximum horizontal range?`,
      ...o,
      explanation: `\\(R = \\frac{u^{2}\\sin 2\\theta}{g}\\) is greatest when \\(\\sin 2\\theta = 1\\).\n\nThis requires \\(2\\theta = 90°\\), so \\(\\theta = 45°\\).`,
    };
  },
  ...conceptGens('projectile motion', [
    'The horizontal component of velocity remains constant throughout the flight',
    'The vertical component of velocity is zero at the maximum height',
    'The path of a projectile is a parabola',
    'The acceleration of a projectile is directed vertically downwards throughout',
    'The time to reach maximum height equals half the total time of flight',
  ], [
    'The horizontal component of velocity decreases steadily during flight',
    'The velocity of the projectile is zero at the maximum height',
    'The acceleration of a projectile is zero at the highest point',
    'A projectile follows a circular path',
    'The horizontal range is greatest when the projection angle is 90°',
  ]),
];

// ========================= CIRCULAR MOTION =========================
const circular = [
  // linear from angular velocity
  () => {
    const w = randInt(2, 20), r = randInt(1, 15);
    const v = w * r;
    const o = buildOptions(v, [w / r, w + r, v * 2], (x) => `${fmtNum(x, 2)}m/s`);
    if (!o) return null;
    return {
      text: `A body moves in a circle of radius ${r}m with an angular velocity of ${w}rad/s. Calculate its linear speed.`,
      ...o,
      explanation: `\\(v = \\omega r\\)\n\n\\(= ${w} \\times ${r} = ${v}\\)m/s`,
    };
  },
  // centripetal acceleration
  () => {
    const v = randInt(2, 30), r = randInt(1, 20);
    const a = v * v / r;
    const o = buildOptions(round(a, 2), [round(v / r, 2), round(v * r, 2), round(a * 2, 2)], (x) => `${fmtNum(x, 2)}m/s²`);
    if (!o) return null;
    return {
      text: `A body moves in a circular path of radius ${r}m with a speed of ${v}m/s. Calculate its centripetal acceleration.`,
      ...o,
      explanation: `\\(a = \\frac{v^{2}}{r}\\)\n\n\\(= \\frac{${v * v}}{${r}} = ${fmtNum(a, 2)}\\)m/s²`,
    };
  },
  // centripetal force
  () => {
    const m = randInt(1, 20), v = randInt(2, 20), r = randInt(1, 15);
    const F = m * v * v / r;
    const o = buildOptions(round(F, 2), [round(m * v / r, 2), round(m * v * v, 2), round(F / 2, 2)], (x) => `${fmtNum(x, 2)}N`);
    if (!o) return null;
    return {
      text: `Calculate the centripetal force acting on a body of mass ${m}kg moving at ${v}m/s in a circle of radius ${r}m.`,
      ...o,
      explanation: `\\(F = \\frac{mv^{2}}{r}\\)\n\n\\(= \\frac{${m} \\times ${v * v}}{${r}} = ${fmtNum(F, 2)}\\)N`,
    };
  },
  // period from angular velocity
  () => {
    const f = randInt(1, 20);
    const T = 1 / f;
    const o = buildOptions(round(T, 4), [f, round(2 * Math.PI / f, 3), round(T * 2, 4)], (v) => `${fmtNum(v, 4)}s`);
    if (!o) return null;
    return {
      text: `A body completes ${f} revolutions per second. Find its period.`,
      ...o,
      explanation: `\\(T = \\frac{1}{f}\\)\n\n\\(= \\frac{1}{${f}} = ${fmtNum(T, 4)}\\)s`,
    };
  },
  ...conceptGens('circular motion', [
    'The centripetal force is always directed towards the centre of the circle',
    'In uniform circular motion the speed is constant but the velocity is changing',
    'Centripetal acceleration is directed towards the centre of the circular path',
    'The centripetal force does no work on a body in uniform circular motion',
    'For uniform circular motion, doubling the speed quadruples the centripetal force',
  ], [
    'The centripetal force acts away from the centre of the circle',
    'In uniform circular motion both speed and velocity are constant',
    'Centripetal acceleration is directed along the tangent to the path',
    'No force is needed to keep a body moving in a circle at constant speed',
    'The centripetal force is greatest when the radius is largest',
  ]),
];

// ====================== SIMPLE HARMONIC MOTION ======================
const shm = [
  // period of a simple pendulum
  () => {
    const l = pick([0.1, 0.4, 0.9, 1.6, 2.5]);
    const T = 2 * Math.PI * Math.sqrt(l / G);
    const correct = round(T, 2);
    const o = buildOptions(correct, [round(T / 2, 2), round(2 * Math.PI * l / G, 2), round(T * 2, 2)], (v) => `${fmtNum(v, 2)}s`);
    if (!o) return null;
    return {
      text: `Calculate the period of a simple pendulum of length ${l}m, correct to 2 decimal places. [Take \\(g = 10\\)m/s²]`,
      ...o,
      explanation: `\\(T = 2\\pi\\sqrt{\\frac{l}{g}}\\)\n\n\\(= 2\\pi\\sqrt{\\frac{${l}}{10}} = ${fmtNum(correct, 2)}\\)s`,
    };
  },
  // angular frequency from frequency
  () => {
    const f = randInt(1, 20);
    const w = 2 * Math.PI * f;
    const o = buildOptions(round(w, 2), [round(f / (2 * Math.PI), 3), f, round(w / 2, 2)], (v) => `${fmtNum(v, 2)}rad/s`);
    if (!o) return null;
    return {
      text: `A body performs simple harmonic motion with a frequency of ${f}Hz. Calculate its angular frequency, correct to 2 decimal places.`,
      ...o,
      explanation: `\\(\\omega = 2\\pi f\\)\n\n\\(= 2\\pi \\times ${f} = ${fmtNum(w, 2)}\\)rad/s`,
    };
  },
  // maximum velocity
  () => {
    const w = randInt(2, 15), A = randInt(1, 12);
    const v = w * A;
    const o = buildOptions(v, [w * w * A, w / A, v * 2], (x) => `${fmtNum(x, 2)}m/s`);
    if (!o) return null;
    return {
      text: `A body executes simple harmonic motion with amplitude ${A}m and angular frequency ${w}rad/s. Find its maximum velocity.`,
      ...o,
      explanation: `The maximum velocity occurs at the equilibrium position.\n\n\\(v_{max} = \\omega A = ${w} \\times ${A} = ${v}\\)m/s`,
    };
  },
  // maximum acceleration
  () => {
    const w = randInt(2, 12), A = randInt(1, 10);
    const a = w * w * A;
    const o = buildOptions(a, [w * A, w * w, a / 2], (x) => `${fmtNum(x, 2)}m/s²`);
    if (!o) return null;
    return {
      text: `A body in simple harmonic motion has amplitude ${A}m and angular frequency ${w}rad/s. Calculate its maximum acceleration.`,
      ...o,
      explanation: `The maximum acceleration occurs at the extreme positions.\n\n\\(a_{max} = \\omega^{2}A = ${w * w} \\times ${A} = ${a}\\)m/s²`,
    };
  },
  ...conceptGens('simple harmonic motion', [
    'The acceleration is directly proportional to the displacement from the equilibrium position',
    'The acceleration is always directed towards the equilibrium position',
    'The velocity is maximum at the equilibrium position',
    'The acceleration is zero at the equilibrium position',
    'The period of a simple pendulum is independent of its mass',
    'Kinetic energy is maximum at the centre of the oscillation',
  ], [
    'The acceleration is directed away from the equilibrium position',
    'The velocity is maximum at the extreme positions',
    'The acceleration is maximum at the equilibrium position',
    'The period of a simple pendulum depends on the mass of the bob',
    'The acceleration is inversely proportional to the displacement',
    'Potential energy is maximum at the centre of the oscillation',
  ]),
];

// ========================== RELATIVE MOTION ==========================
const relative = [
  // same direction
  () => {
    const a = randInt(10, 90), b = randInt(5, 80);
    if (a === b) return null;
    const correct = Math.abs(a - b);
    const o = buildOptions(correct, [a + b, a, b], (v) => `${v}m/s`);
    if (!o) return null;
    return {
      text: `Two cars travel in the same direction with speeds ${a}m/s and ${b}m/s. Find the magnitude of the velocity of the first car relative to the second.`,
      ...o,
      explanation: `For motion in the same direction, relative velocity is the difference.\n\n\\(v_{rel} = |${a} - ${b}| = ${correct}\\)m/s`,
    };
  },
  // opposite directions
  () => {
    const a = randInt(10, 90), b = randInt(10, 90);
    const correct = a + b;
    const o = buildOptions(correct, [Math.abs(a - b), a, b], (v) => `${v}m/s`);
    if (!o) return null;
    return {
      text: `Two cars approach each other with speeds ${a}m/s and ${b}m/s. Find the magnitude of their relative velocity.`,
      ...o,
      explanation: `For motion in opposite directions, relative velocity is the sum.\n\n\\(v_{rel} = ${a} + ${b} = ${correct}\\)m/s`,
    };
  },
  // perpendicular relative velocity
  () => {
    const [p, q, r] = pick(TRIPLES);
    const k = randInt(1, 4);
    const o = buildOptions(r * k, [(p + q) * k, Math.abs(p - q) * k, r * k + 2], (v) => `${v}m/s`);
    if (!o) return null;
    return {
      text: `A boat travels at ${p * k}m/s due north while a current flows at ${q * k}m/s due east. Find the magnitude of the resultant velocity of the boat.`,
      ...o,
      explanation: `The two velocities are perpendicular, so combine them using Pythagoras' theorem.\n\n\\(v = \\sqrt{${p * k}^{2} + ${q * k}^{2}} = \\sqrt{${(r * k) ** 2}} = ${r * k}\\)m/s`,
    };
  },
  // overtaking time
  () => {
    const va = randInt(20, 60), vb = randInt(5, 19);
    const gap = (va - vb) * randInt(2, 20);
    const t = gap / (va - vb);
    const o = buildOptions(t, [gap / (va + vb), gap / va, t + 2], (v) => `${fmtNum(v, 2)}s`);
    if (!o) return null;
    return {
      text: `A car travelling at ${va}m/s is ${gap}m behind a lorry travelling at ${vb}m/s in the same direction. How long will it take the car to catch up with the lorry?`,
      ...o,
      explanation: `Relative velocity \\(= ${va} - ${vb} = ${va - vb}\\)m/s\n\n\\(t = \\frac{\\text{gap}}{\\text{relative velocity}} = \\frac{${gap}}{${va - vb}} = ${t}\\)s`,
    };
  },
];

module.exports = [
  { topicId: 'WllsB6UsP7iccQbOKLwl', unitId: U_MEAS, topicName: 'Fundamental and Derived Quantities', generators: quantities },
  { topicId: 'hYs2IvqlNNmCCLB6MJ1w', unitId: U_MEAS, topicName: 'Dimensions and Dimensional Analysis', generators: dimensions },
  { topicId: 'EkFnwvXTZTh8i1NNf6f6', unitId: U_MEAS, topicName: 'Scalars and Vectors', generators: scalarsVectors },
  { topicId: 'UfStgqzSI7XKuEqdFr90', unitId: U_MOTION, topicName: 'Circular Motion', generators: circular },
  { topicId: 'D5a5Hqp1NZWtLJc7poTS', unitId: U_MOTION, topicName: 'Simple Harmonic Motion', generators: shm },
  { topicId: 'V3pwih9gpp1yxTQuvPPU', unitId: U_MOTION, topicName: 'Speed and Velocity', generators: speedVelocity },
  { topicId: 'STUfPoPmprLDYTihlmvF', unitId: U_MOTION, topicName: 'Acceleration and Equations of Motion', generators: equationsOfMotion },
  { topicId: '1DjpLLaDI3NDDdJC7UEO', unitId: U_MOTION, topicName: 'Distance Displacement and Position', generators: distanceDisplacement },
  { topicId: 'HpYHfCQfptvoiy3P2Lfp', unitId: U_MOTION, topicName: 'Projectile Motion', generators: projectile },
  { topicId: 'T4vCcK0Alp6IbKn1pwlX', unitId: U_MOTION, topicName: 'Relative Motion', generators: relative },
];
