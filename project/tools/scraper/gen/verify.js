// Independent verification of generated question files.
// Re-parses the QUESTION TEXT and recomputes the answer with logic written
// separately from the generators, so text/answer divergence is caught.

const fs = require('fs');
const path = require('path');
const DIR = path.join(__dirname, '..', 'data');

const files = fs.readdirSync(DIR).filter(f => f.startsWith('generated_') && f.endsWith('.json'));

let totalQ = 0, structErrors = [], reChecked = 0, reErrors = [];

// ---------- independent maths helpers (re-implemented, not imported) ----------
function decFromBase(str, base) { return str.split('').reduce((n, c) => n * base + Number(c), 0); }
function baseFromDec(n, base) {
  if (n === 0) return '0';
  let s = '';
  while (n > 0) { s = String(n % base) + s; n = Math.floor(n / base); }
  return s;
}
function gcd2(a, b) { a = Math.abs(a); b = Math.abs(b); while (b) { [a, b] = [b, a % b]; } return a; }
// scans upward for the largest square factor - different implementation from the generator
function simplifySurdIndep(N) {
  let best = 1;
  for (let f = 1; f * f <= N; f++) if (N % (f * f) === 0) best = f;
  return { c: best, r: N / (best * best) };
}
function surdStr(c, r) {
  if (r === 1) return String(c);
  if (c === 1) return `\\sqrt{${r}}`;
  return `${c}\\sqrt{${r}}`;
}
function fracStrIndep(n, d) {
  const s = d < 0 ? -1 : 1; n *= s; d *= s;
  const g = gcd2(n, d) || 1;
  n /= g; d /= g;
  if (d === 1) return String(n);
  return n < 0 ? `-\\frac{${-n}}{${d}}` : `\\frac{${n}}{${d}}`;
}
const num = (s) => Number(String(s).replace(/,/g, ''));
// mirrors lib.fmtNum exactly
function fmtNumV(x, dp = 2) {
  if (!isFinite(x)) return 'NaN';
  const m = Math.pow(10, dp);
  const r = Math.round((x + Number.EPSILON) * m) / m;
  if (Number.isInteger(r)) return String(r);
  return String(parseFloat(r.toFixed(dp)));
}

// ---------- text parsers: [regex, handler returning expected correct option string] ----------
const PARSERS = [
  // ---- number bases ----
  [/^Convert \\\((\d+)_\{(\d+)\}\\\) to base ten\.$/, m => String(decFromBase(m[1], +m[2]))],
  [/^Convert (\d+)\\\(_\{10\}\\\) to base (\d+)\.$/, m => `\\(${baseFromDec(+m[1], +m[2])}_{${m[2]}}\\)`],
  [/^Convert \\\((\d+)_\{(\d+)\}\\\) to base (\d+)\.$/, m => `\\(${baseFromDec(decFromBase(m[1], +m[2]), +m[3])}_{${m[3]}}\\)`],
  [/^Evaluate \\\((\d+)_\{(\d+)\}\\\) \+ \\\((\d+)_\{\2\}\\\), giving your answer in base \2\.$/,
    m => `\\(${baseFromDec(decFromBase(m[1], +m[2]) + decFromBase(m[3], +m[2]), +m[2])}_{${m[2]}}\\)`],
  [/^Evaluate \\\((\d+)_\{(\d+)\}\\\) - \\\((\d+)_\{\2\}\\\), giving your answer in base \2\.$/,
    m => `\\(${baseFromDec(decFromBase(m[1], +m[2]) - decFromBase(m[3], +m[2]), +m[2])}_{${m[2]}}\\)`],
  [/^Evaluate \\\((\d+)_\{(\d+)\}\\\) \\\(\\times\\\) \\\((\d+)_\{\2\}\\\), giving your answer in base \2\.$/,
    m => `\\(${baseFromDec(decFromBase(m[1], +m[2]) * decFromBase(m[3], +m[2]), +m[2])}_{${m[2]}}\\)`],
  [/^Evaluate \\\((\d+)_\{(\d+)\}\\\) \+ \\\((\d+)_\{(\d+)\}\\\), leaving your answer in base ten\.$/,
    m => String(decFromBase(m[1], +m[2]) + decFromBase(m[3], +m[4]))],
  [/^Find the value of \\\(y\\\) if \\\((\d)(\d)_\{y\} = (\d+)_\{10\}\\\)\.$/,
    m => String((+m[3] - +m[2]) / +m[1])],

  // ---- indices ----
  [/^Simplify \\\(x\^\{(\d+)\} \\times x\^\{(\d+)\}\\\)\.$/, m => `\\(x^{${+m[1] + +m[2]}}\\)`],
  [/^Simplify \\\(\\frac\{x\^\{(\d+)\}\}\{x\^\{(\d+)\}\}\\\)\.$/, m => {
    const e = +m[1] - +m[2]; return `\\(${e === 1 ? 'x' : e === 0 ? '1' : `x^{${e}}`}\\)`;
  }],
  [/^Simplify \\\(\(x\^\{(\d+)\}\)\^\{(\d+)\}\\\)\.$/, m => `\\(x^{${+m[1] * +m[2]}}\\)`],
  [/^Simplify \\\((\d+)x\^\{(\d+)\} \\times (\d+)x\^\{(\d+)\}\\\)\.$/,
    m => `\\(${+m[1] * +m[3]}x^{${+m[2] + +m[4]}}\\)`],
  [/^Evaluate \\\((\d+)\^\{(\d+)\}\\\)\.$/, m => String(Math.pow(+m[1], +m[2]))],
  [/^Evaluate \\\((\d+)\^\{-(\d+)\}\\\)\.$/, m => `\\(${fracStrIndep(1, Math.pow(+m[1], +m[2]))}\\)`],
  [/^If \\\((\d+)\^\{x\} = (\d+)\\\), find the value of \\\(x\\\)\.$/,
    m => String(Math.round(Math.log(+m[2]) / Math.log(+m[1])))],
  [/^Evaluate \\\((\d+) \\times (\d+)\^\{0\}\\\)\.$/, m => String(+m[1])],

  // ---- logarithms ----
  [/^Evaluate \\\(\\log_\{(\d+)\} (\d+)\\\)\.$/, m => {
    const b = +m[1], v = +m[2];
    const k = Math.log(v) / Math.log(b);
    return String(Math.round(k));
  }],
  [/^If \\\(\\log_\{x\} (\d+) = (\d+)\\\), find \\\(x\\\)\.$/,
    m => String(Math.round(Math.pow(+m[1], 1 / +m[2])))],
  [/^If \\\(\\log_\{(\d+)\} x = (\d+)\\\), find \\\(x\\\)\.$/, m => String(Math.pow(+m[1], +m[2]))],
  [/^Evaluate \\\(\\log_\{(\d+)\} (\d+) \+ \\log_\{(\d+)\} (\d+)\\\)\.$/, m => {
    const k1 = Math.log(+m[2]) / Math.log(+m[1]), k2 = Math.log(+m[4]) / Math.log(+m[3]);
    return String(Math.round(k1) + Math.round(k2));
  }],
  [/^Evaluate \\\(\\log_\{(\d+)\} (\d+) - \\log_\{\1\} (\d+)\\\)\.$/, m => {
    const k1 = Math.log(+m[2]) / Math.log(+m[1]), k2 = Math.log(+m[3]) / Math.log(+m[1]);
    return String(Math.round(k1) - Math.round(k2));
  }],
  [/^Evaluate \\\(\\log_\{(\d+)\} \\frac\{1\}\{(\d+)\}\\\)\.$/, m => {
    const k = Math.log(+m[2]) / Math.log(+m[1]);
    return String(-Math.round(k));
  }],

  // ---- percentages ----
  [/^Find (\d+(?:\.\d+)?)% of (\d+)\.$/, m => {
    const v = +m[2] * +m[1] / 100;
    return Number.isInteger(v) ? String(v) : String(parseFloat(v.toFixed(2)));
  }],
  [/^Express (\d+) as a percentage of (\d+)\.$/, m => {
    const v = +m[1] / +m[2] * 100;
    return `${Number.isInteger(v) ? v : parseFloat(v.toFixed(2))}%`;
  }],

  // ---- sets ----
  [/^If \\\(n\(A\) = (\d+)\\\), \\\(n\(B\) = (\d+)\\\) and \\\(n\(A \\cap B\) = (\d+)\\\), find \\\(n\(A \\cup B\)\\\)\.$/,
    m => String(+m[1] + +m[2] - +m[3])],
  [/^Given that \\\(n\(U\) = (\d+)\\\) and \\\(n\(A\) = (\d+)\\\), find \\\(n\(A'\)\\\)\.$/,
    m => String(+m[1] - +m[2])],
  [/^How many subsets can be formed from a set containing (\d+) elements\?$/,
    m => String(Math.pow(2, +m[1]))],

  // ---- modular arithmetic ----
  [/^Evaluate \\\(\((\d+) \+ (\d+)\) \\pmod\{(\d+)\}\\\)\.$/, m => String((+m[1] + +m[2]) % +m[3])],
  [/^Evaluate \\\(\((\d+) \\times (\d+)\) \\pmod\{(\d+)\}\\\)\.$/, m => String((+m[1] * +m[2]) % +m[3])],
  [/^Find the value of (\d+) modulo (\d+)\.$/, m => String(+m[1] % +m[2])],
  [/^Find the additive inverse of (\d+) in modulo (\d+) arithmetic\.$/,
    m => String((+m[2] - +m[1]) % +m[2])],

  // ---- surds ----
  [/^Simplify \\\(\\sqrt\{(\d+)\}\\\)\.$/, m => {
    const s = simplifySurdIndep(+m[1]); return `\\(${surdStr(s.c, s.r)}\\)`;
  }],
  [/^Simplify \\\((\d+)\\sqrt\{(\d+)\} \+ (\d+)\\sqrt\{\2\}\\\)\.$/,
    m => `\\(${surdStr(+m[1] + +m[3], +m[2])}\\)`],
  [/^Simplify \\\((\d+)\\sqrt\{(\d+)\} - (\d+)\\sqrt\{\2\}\\\)\.$/,
    m => `\\(${surdStr(+m[1] - +m[3], +m[2])}\\)`],
  [/^Simplify \\\(\\sqrt\{(\d+)\} \\times \\sqrt\{(\d+)\}\\\)\.$/, m => {
    const s = simplifySurdIndep(+m[1] * +m[2]); return `\\(${surdStr(s.c, s.r)}\\)`;
  }],
  [/^Simplify \\\(\(\\sqrt\{(\d+)\} \+ \\sqrt\{(\d+)\}\)\(\\sqrt\{\1\} - \\sqrt\{\2\}\)\\\)\.$/,
    m => String(+m[1] - +m[2])],
  [/^Rationalise the denominator of \\\(\\frac\{(\d+)\}\{\\sqrt\{(\d+)\}\}\\\)\.$/,
    m => `\\(${surdStr(+m[1] / +m[2], +m[2])}\\)`],

  // ---- matrices ----
  [/^Find the determinant of the matrix \\\(\\begin\{pmatrix\} (-?\d+) & (-?\d+) \\\\ (-?\d+) & (-?\d+) \\end\{pmatrix\}\\\)\.$/,
    m => String(+m[1] * +m[4] - +m[2] * +m[3])],

  // ---- sequences ----
  [/^The first term of an Arithmetic Progression \(A\.P\.\) is (-?\d+) and the common difference is (-?\d+)\. Find the (\d+)th term\.$/,
    m => String(+m[1] + (+m[3] - 1) * +m[2])],
  [/^Find the sum of the first (\d+) terms of an A\.P\. whose first term is (-?\d+) and common difference is (-?\d+)\.$/,
    m => String(+m[1] * (2 * +m[2] + (+m[1] - 1) * +m[3]) / 2)],
  [/^The first term of a Geometric Progression \(G\.P\.\) is (\d+) and the common ratio is (\d+)\. Find the (\d+)th term\.$/,
    m => String(+m[1] * Math.pow(+m[2], +m[3] - 1))],
  [/^Find the sum of the first (\d+) terms of a G\.P\. with first term (\d+) and common ratio (\d+)\.$/,
    m => String(+m[2] * (Math.pow(+m[3], +m[1]) - 1) / (+m[3] - 1))],

  // ---- financial ----
  [/^Find the simple interest on N(\d+) for (\d+) years at (\d+(?:\.\d+)?)% per annum\.$/, m => {
    const v = +m[1] * +m[3] * +m[2] / 100;
    return Number.isInteger(v) ? String(v) : String(parseFloat(v.toFixed(2)));
  }],

  // ---- ratio ----
  [/^If \\\((\d+) : (\d+) = (\d+) : x\\\), find \\\(x\\\)\.$/, m => {
    const v = +m[2] * +m[3] / +m[1];
    return Number.isInteger(v) ? String(v) : String(parseFloat(v.toFixed(2)));
  }],

  // ---- fractions ----
  [/^Find \\\(\\frac\{(\d+)\}\{(\d+)\}\\\) of (\d+)\.$/, m => {
    const v = +m[3] * +m[1] / +m[2];
    return Number.isInteger(v) ? String(v) : String(parseFloat(v.toFixed(2)));
  }],

  // ---- algebra: quadratics ----
  // Solve x^2 + bx + c = 0  (monic) -> roots ascending "r1 or r2"
  [/^Solve the equation \\\(x\^\{2\} ([+-]) (\d+)x ([+-]) (\d+) = 0\\\)\.$/, m => {
    const b = (m[1] === '+' ? 1 : -1) * +m[2];
    const c = (m[3] === '+' ? 1 : -1) * +m[4];
    const disc = b * b - 4 * c;
    if (disc < 0) return null;
    const s = Math.sqrt(disc);
    if (!Number.isInteger(s)) return null;
    const r1 = (-b - s) / 2, r2 = (-b + s) / 2;
    return `${Math.min(r1, r2)} or ${Math.max(r1, r2)}`;
  }],
  // Expand (x + a)(x + b)
  [/^Expand \\\(\(x ([+-]) (\d+)\)\(x ([+-]) (\d+)\)\\\)\.$/, m => {
    const a = (m[1] === '+' ? 1 : -1) * +m[2];
    const b = (m[3] === '+' ? 1 : -1) * +m[4];
    const B = a + b, C = a * b;
    let s = 'x^{2}';
    if (B !== 0) s += (B > 0 ? ' + ' : ' - ') + (Math.abs(B) === 1 ? 'x' : `${Math.abs(B)}x`);
    if (C !== 0) s += (C > 0 ? ' + ' : ' - ') + Math.abs(C);
    return `\\(${s}\\)`;
  }],
  // Find the y-intercept of y = mx + c
  [/^Find the y-intercept of the line \\\(y = -?\d*x ([+-]) (\d+)\\\)\.$/, m =>
    String((m[1] === '+' ? 1 : -1) * +m[2])],
  // Find the gradient of y = mx + c
  [/^Find the gradient of the line \\\(y = (-?\d*)x [+-] \d+\\\)\.$/, m => {
    const raw = m[1];
    const grad = raw === '' ? 1 : raw === '-' ? -1 : +raw;
    return String(grad);
  }],
  // f(x) = ax + b, find f(k)
  [/^If \\\(f\(x\) = (-?\d*)x ([+-]) (\d+)\\\), find \\\(f\((-?\d+)\)\\\)\.$/, m => {
    const raw = m[1];
    const a = raw === '' ? 1 : raw === '-' ? -1 : +raw;
    const b = (m[2] === '+' ? 1 : -1) * +m[3];
    return String(a * +m[4] + b);
  }],
  // Solve ax + b = c
  [/^Solve the equation \\\((-?\d*)x ([+-]) (\d+) = (-?\d+)\\\)\.$/, m => {
    const raw = m[1];
    const a = raw === '' ? 1 : raw === '-' ? -1 : +raw;
    const b = (m[2] === '+' ? 1 : -1) * +m[3];
    const v = (+m[4] - b) / a;
    return Number.isInteger(v) ? String(v) : String(parseFloat(v.toFixed(2)));
  }],
  // least integer satisfying ax + b > c
  [/^Find the least integer value of \\\(x\\\) that satisfies \\\((\d+)x ([+-]) (\d+) > (-?\d+)\\\)\.$/, m => {
    const a = +m[1], b = (m[2] === '+' ? 1 : -1) * +m[3], c = +m[4];
    return String(Math.floor((c - b) / a) + 1);
  }],
  // sum of three consecutive numbers
  [/^The sum of three consecutive whole numbers is (\d+)\. Find the smallest of the numbers\.$/,
    m => String((+m[1] - 3) / 3)],

  // ================= PHYSICS =================
  // F = ma
  [/^Calculate the force required to give a body of mass (\d+)kg an acceleration of (\d+)m\/s²\.$/,
    m => `${fmtNumV(+m[1] * +m[2])}N`],
  [/^A force of (\d+)N acts on a body of mass (\d+)kg\. Calculate the acceleration produced\.$/,
    m => `${fmtNumV(+m[1] / +m[2])}m/s²`],
  // momentum
  [/^Calculate the momentum of a body of mass (\d+)kg moving with a velocity of (\d+)m\/s\.$/,
    m => `${fmtNumV(+m[1] * +m[2])}kg m/s`],
  // V = IR
  [/^A current of (\d+)A flows through a resistor of (\d+)Ω\. Calculate the potential difference across it\.$/,
    m => `${fmtNumV(+m[1] * +m[2])}V`],
  [/^Calculate the current flowing through a (\d+)Ω resistor when a potential difference of (\d+)V is applied across it\.$/,
    m => `${fmtNumV(+m[2] / +m[1])}A`],
  // P = IV
  [/^Calculate the power dissipated when a current of (\d+)A flows through a device with (\d+)V across it\.$/,
    m => `${fmtNumV(+m[1] * +m[2])}W`],
  // P = I^2 R
  [/^Calculate the power dissipated in a (\d+)Ω resistor carrying a current of (\d+)A\.$/,
    m => `${fmtNumV(+m[2] * +m[2] * +m[1])}W`],
  // E = Pt
  [/^Calculate the electrical energy consumed by a (\d+)W device operating for (\d+) seconds\.$/,
    m => `${fmtNumV(+m[1] * +m[2])}J`],
  // Q = It
  [/^A steady current of (\d+)A flows for (\d+) seconds\. Calculate the quantity of charge that passes\.$/,
    m => `${fmtNumV(+m[1] * +m[2])}C`],
  [/^A charge of (\d+)C flows past a point in a circuit in (\d+) seconds\. Calculate the current\.$/,
    m => `${fmtNumV(+m[1] / +m[2])}A`],
  // resistors in series (3)
  [/^Three resistors of (\d+)Ω, (\d+)Ω and (\d+)Ω are connected in series\. Calculate the effective resistance\.$/,
    m => `${fmtNumV(+m[1] + +m[2] + +m[3])}Ω`],
  // resistors in parallel (2)
  [/^Two resistors of (\d+)Ω and (\d+)Ω are connected in parallel\. Calculate the effective resistance\.$/,
    m => `${fmtNumV(+m[1] * +m[2] / (+m[1] + +m[2]), 3)}Ω`],
  // capacitors in parallel / series
  [/^Two capacitors of (\d+)μF and (\d+)μF are connected in parallel\. Calculate their effective capacitance\.$/,
    m => `${fmtNumV(+m[1] + +m[2])}μF`],
  [/^Two capacitors of (\d+)μF and (\d+)μF are connected in series\. Calculate their effective capacitance\.$/,
    m => `${fmtNumV(+m[1] * +m[2] / (+m[1] + +m[2]), 3)}μF`],
  // temperature conversion
  [/^Convert (-?\d+)°C to kelvin\.$/, m => `${+m[1] + 273}K`],
  [/^Convert (\d+)K to degrees Celsius\.$/, m => `${+m[1] - 273}°C`],
  // moment of a force
  [/^Calculate the moment of a force of (\d+)N acting at a perpendicular distance of (\d+)m from a pivot\.$/,
    m => `${fmtNumV(+m[1] * +m[2])}Nm`],
  // speed = distance / time
  [/^A body covers a distance of (\d+)m in (\d+) seconds\. Calculate its average speed\.$/,
    m => `${fmtNumV(+m[1] / +m[2])}m/s`],
  // v = f lambda
  [/^A wave of frequency (\d+)Hz has a wavelength of ([\d.]+)m\. Calculate its speed\.$/,
    m => `${fmtNumV(+m[1] * +m[2])}m/s`],
  // work done
  [/^Calculate the work done when a force of (\d+)N moves a body through a distance of (\d+)m in the direction of the force\.$/,
    m => `${fmtNumV(+m[1] * +m[2])}J`],
  // kinetic energy
  [/^Calculate the kinetic energy of a body of mass (\d+)kg moving with a velocity of (\d+)m\/s\.$/,
    m => `${fmtNumV(0.5 * +m[1] * +m[2] * +m[2])}J`],
  // potential energy
  [/^Calculate the potential energy of a body of mass (\d+)kg at a height of (\d+)m above the ground\. \[Take \\\(g = 10\\\)m\/s²\]$/,
    m => `${fmtNumV(+m[1] * 10 * +m[2])}J`],
  // weight
  [/^Calculate the weight of a body of mass (\d+)kg on the Earth's surface\. \[Take \\\(g = 10\\\)m\/s²\]$/,
    m => `${fmtNumV(+m[1] * 10)}N`],
  // v = u + at
  [/^A car moving at (\d+)m\/s accelerates uniformly at (\d+)m\/s² for (\d+) seconds\. Find its final velocity\.$/,
    m => `${+m[1] + +m[2] * +m[3]}m/s`],
  // a = (v-u)/t
  [/^A body accelerates uniformly from (\d+)m\/s to (\d+)m\/s in (\d+) seconds\. Calculate its acceleration\.$/,
    m => `${fmtNumV((+m[2] - +m[1]) / +m[3])}m/s²`],
  // neutrons
  [/^How many neutrons are present in a nucleus of mass number (\d+) and atomic number (\d+)\?$/,
    m => String(+m[1] - +m[2])],
  // density
  [/^A block of mass (\d+)g occupies a volume of (\d+)cm³\. Calculate its density\.$/,
    m => `${fmtNumV(+m[1] / +m[2])}g/cm³`],
  // pressure = F/A
  [/^A force of (\d+)N acts normally on a surface of area ([\d.]+)m²\. Calculate the pressure exerted\.$/,
    m => `${fmtNumV(+m[1] / +m[2])}Pa`],
  // P = rho g h
  [/^Calculate the pressure at a depth of (\d+)m in a liquid of density (\d+)kg\/m³\. \[Take \\\(g = 10\\\)m\/s²\]$/,
    m => `${fmtNumV(+m[2] * 10 * +m[1])}Pa`],
  // Q = m c dtheta
  [/^Calculate the quantity of heat required to raise the temperature of ([\d.]+)kg of a substance of specific heat capacity (\d+)J\/kg·K by (\d+)K\.$/,
    m => `${fmtNumV(+m[1] * +m[2] * +m[3])}J`],
  // heat capacity
  [/^Calculate the heat capacity of ([\d.]+)kg of a substance whose specific heat capacity is (\d+)J\/kg·K\.$/,
    m => `${fmtNumV(+m[1] * +m[2])}J\/K`],
  // upthrust from weighings
  [/^A metal block weighs (\d+)N in air and (\d+)N when completely immersed in water\. Calculate the upthrust acting on it\.$/,
    m => `${fmtNumV(+m[1] - +m[2])}N`],
  // apparent weight
  [/^A body weighs (\d+)N in air\. When fully immersed in water it experiences an upthrust of (\d+)N\. What is its apparent weight in water\?$/,
    m => `${fmtNumV(+m[1] - +m[2])}N`],
  // transformer secondary voltage
  [/^A transformer has (\d+) turns in its primary and (\d+) turns in its secondary\. If the primary voltage is (\d+)V, calculate the secondary voltage\.$/,
    m => `${fmtNumV(+m[3] * +m[2] / +m[1])}V`],
  // F = BIL
  [/^A conductor of length ([\d.]+)m carrying a current of (\d+)A is placed at right angles to a magnetic field of flux density ([\d.]+)T\. Calculate the force on the conductor\.$/,
    m => `${fmtNumV(+m[3] * +m[2] * +m[1], 3)}N`],
  // emf = BLv
  [/^A conductor of length ([\d.]+)m moves at (\d+)m\/s at right angles to a magnetic field of flux density ([\d.]+)T\. Calculate the emf induced\.$/,
    m => `${fmtNumV(+m[3] * +m[1] * +m[2], 3)}V`],
  // E = I(R+r)
  [/^A cell of internal resistance (\d+)Ω drives a current of (\d+)A through an external resistance of (\d+)Ω\. Calculate the emf of the cell\.$/,
    m => `${fmtNumV(+m[2] * (+m[3] + +m[1]))}V`],
  // mirror focal length
  [/^A concave mirror has a radius of curvature of (\d+)cm\. Calculate its focal length\.$/,
    m => `${fmtNumV(+m[1] / 2)}cm`],
  // number of images in inclined mirrors
  [/^Two plane mirrors are inclined at an angle of (\d+)° to each other\. How many images of an object placed between them are formed\?$/,
    m => String(360 / +m[1] - 1)],
  // magnification
  [/^An object is placed (\d+)cm from a lens and its image is formed ([\d.]+)cm from the lens\. Calculate the magnification\.$/,
    m => fmtNumV(+m[2] / +m[1])],
  // beat frequency
  [/^Two tuning forks of frequencies (\d+)Hz and (\d+)Hz are sounded together\. Calculate the beat frequency\.$/,
    m => `${fmtNumV(Math.abs(+m[2] - +m[1]))}Hz`],
  // echo distance
  [/^A man claps his hands and hears the echo after ([\d.]+)s\. If the speed of sound in air is (\d+)m\/s, how far away is the reflecting wall\?$/,
    m => `${fmtNumV(+m[2] * +m[1] / 2)}m`],
];

// ---------- run ----------
const perFileRe = {};

for (const f of files) {
  const data = JSON.parse(fs.readFileSync(path.join(DIR, f), 'utf8'));
  const seen = new Set();
  let fileRe = 0, fileReErr = 0;

  data.forEach((q, i) => {
    totalQ++;
    const where = `${f}[${i}]`;

    // ---- structural ----
    if (!q.text || typeof q.text !== 'string') structErrors.push(`${where} missing text`);
    if (!Array.isArray(q.options) || q.options.length !== 4) structErrors.push(`${where} options != 4`);
    else {
      if (new Set(q.options).size !== 4) structErrors.push(`${where} duplicate options`);
      q.options.forEach(o => {
        if (typeof o !== 'string') structErrors.push(`${where} non-string option`);
        else if (/^[A-E][\.\)]\s/.test(o)) structErrors.push(`${where} lettered option: ${o}`);
      });
    }
    if (typeof q.correctIndex !== 'number' || q.correctIndex < 0 || q.correctIndex > 3)
      structErrors.push(`${where} bad correctIndex`);
    if (!q.explanation || q.explanation.length < 10) structErrors.push(`${where} weak explanation`);
    if (q.source !== 'drill') structErrors.push(`${where} bad source`);
    if (q.origin !== 'ai_generated') structErrors.push(`${where} bad origin`);
    if (q.hasAnswer !== true) structErrors.push(`${where} hasAnswer`);
    if (q.year !== null) structErrors.push(`${where} year`);
    if (!q.subjectId || !q.unitId || !q.topicId) structErrors.push(`${where} missing ids`);
    if (seen.has(q.text)) structErrors.push(`${where} duplicate text`);
    seen.add(q.text);

    const blob = [q.text, q.explanation, ...(q.options || [])].join(' ');
    if (/NaN|undefined|Infinity|\[object|\$\{/.test(blob)) structErrors.push(`${where} bad token in content`);
    if (blob.includes('\\(\\(')) structErrors.push(`${where} nested delimiter`);
    if (blob.includes('$')) structErrors.push(`${where} $ delimiter`);
    // delimiter balance
    const opens = (blob.match(/\\\(/g) || []).length, closes = (blob.match(/\\\)/g) || []).length;
    if (opens !== closes) structErrors.push(`${where} unbalanced \\( \\) (${opens}/${closes})`);

    // ---- independent re-derivation ----
    for (const [re, handler] of PARSERS) {
      const m = q.text.match(re);
      if (!m) continue;
      let expected;
      try { expected = handler(m); } catch (e) { break; }
      if (expected == null) break;
      reChecked++; fileRe++;
      const actual = q.options[q.correctIndex];
      if (String(expected) !== String(actual)) {
        fileReErr++;
        reErrors.push(`${where} expected "${expected}" got "${actual}" :: ${q.text}`);
      }
      break;
    }
  });

  perFileRe[f] = { total: data.length, re: fileRe, err: fileReErr };
}

console.log(`Files: ${files.length}`);
console.log(`Total questions: ${totalQ}`);
console.log(`Structural errors: ${structErrors.length}`);
structErrors.slice(0, 25).forEach(e => console.log('  ' + e));
console.log(`\nIndependently re-derived: ${reChecked} (${(reChecked / totalQ * 100).toFixed(1)}% of all questions)`);
console.log(`Re-derivation mismatches: ${reErrors.length}`);
reErrors.slice(0, 25).forEach(e => console.log('  ' + e));

console.log('\nPer-file independent coverage:');
Object.entries(perFileRe).sort().forEach(([f, s]) => {
  console.log(`  ${String(s.re).padStart(4)}/${String(s.total).padStart(4)} checked, ${s.err} bad  ${f}`);
});
