// Mathematics > Mensuration, Plane Geometry, Coordinate Geometry
const L = require('./lib');
const { randInt, pick, shuffle, sample, nonZero, gcd, frac, fracTex, fracOpt,
        fmtNum, buildOptions, textOptions, round } = L;

const U_MENS = 'JaulIQplMk7csfa4It5n';
const U_PLANE = 'e47ZdSNmQrIZGJbaVFL6';
const U_COORD = 'UJZZKq838giR4svymkCQ';

const mathOpt = (s) => `\\(${s}\\)`;
const PI_NOTE = '[Take \\(\\pi = \\frac{22}{7}\\)]';
const PI = 22 / 7;
// integers print plain, otherwise 2 d.p.
const fmtM = (v) => Number.isInteger(round(v, 6)) ? String(round(v, 6)) : round(v, 2).toFixed(2);
const unit = (v, u) => `${fmtM(v)}${u}`;

// ============================== VOLUMES ==============================
const volumes = [
  // cuboid
  () => {
    const l = randInt(3, 25), w = randInt(3, 25), h = randInt(3, 25);
    const V = l * w * h;
    const o = buildOptions(V, [2 * (l * w + l * h + w * h), l + w + h, l * w, V / 2], (v) => unit(v, 'cm³'));
    if (!o) return null;
    return {
      text: `Find the volume of a cuboid of length ${l}cm, width ${w}cm and height ${h}cm.`,
      ...o,
      explanation: `Volume of a cuboid \\(= l \\times w \\times h\\)\n\n\\(= ${l} \\times ${w} \\times ${h}\\)\n\n\\(= ${V}\\) cm³`,
    };
  },
  // cylinder
  () => {
    const r = 7 * randInt(1, 4), h = randInt(3, 25);
    const V = PI * r * r * h;
    const o = buildOptions(V, [2 * PI * r * h, PI * r * h, V / 3, 2 * PI * r * (r + h)], (v) => unit(v, 'cm³'));
    if (!o) return null;
    return {
      text: `Calculate the volume of a cylinder of radius ${r}cm and height ${h}cm. ${PI_NOTE}`,
      ...o,
      explanation: `Volume of a cylinder \\(= \\pi r^{2} h\\)\n\n\\(= \\frac{22}{7} \\times ${r}^{2} \\times ${h}\\)\n\n\\(= \\frac{22}{7} \\times ${r * r} \\times ${h} = ${fmtM(V)}\\) cm³`,
    };
  },
  // cone
  () => {
    const r = 7 * randInt(1, 3), h = 3 * randInt(1, 8);
    const V = PI * r * r * h / 3;
    const o = buildOptions(V, [PI * r * r * h, V / 2, PI * r * h / 3, V * 2], (v) => unit(v, 'cm³'));
    if (!o) return null;
    return {
      text: `Find the volume of a cone of base radius ${r}cm and height ${h}cm. ${PI_NOTE}`,
      ...o,
      explanation: `Volume of a cone \\(= \\frac{1}{3}\\pi r^{2} h\\)\n\n\\(= \\frac{1}{3} \\times \\frac{22}{7} \\times ${r}^{2} \\times ${h}\\)\n\n\\(= \\frac{1}{3} \\times \\frac{22}{7} \\times ${r * r} \\times ${h} = ${fmtM(V)}\\) cm³`,
    };
  },
  // sphere
  () => {
    const r = 7 * randInt(1, 3);
    const V = 4 * PI * r * r * r / 3;
    const o = buildOptions(V, [4 * PI * r * r, PI * r * r * r / 3, V / 2, 4 * PI * r * r * r], (v) => unit(v, 'cm³'));
    if (!o) return null;
    return {
      text: `Calculate the volume of a sphere of radius ${r}cm, correct to 2 decimal places. ${PI_NOTE}`,
      ...o,
      explanation: `Volume of a sphere \\(= \\frac{4}{3}\\pi r^{3}\\)\n\n\\(= \\frac{4}{3} \\times \\frac{22}{7} \\times ${r}^{3}\\)\n\n\\(= \\frac{4}{3} \\times \\frac{22}{7} \\times ${r * r * r} = ${fmtM(V)}\\) cm³`,
    };
  },
  // triangular prism
  () => {
    const b = randInt(4, 20), hT = randInt(3, 18), len = randInt(5, 25);
    const V = 0.5 * b * hT * len;
    const o = buildOptions(V, [b * hT * len, 0.5 * b * hT, V / 3, V * 2], (v) => unit(v, 'cm³'));
    if (!o) return null;
    return {
      text: `A prism has a triangular cross-section of base ${b}cm and height ${hT}cm. If the prism is ${len}cm long, find its volume.`,
      ...o,
      explanation: `Area of the triangular cross-section \\(= \\frac{1}{2} \\times ${b} \\times ${hT} = ${0.5 * b * hT}\\) cm²\n\nVolume \\(= \\text{cross-sectional area} \\times \\text{length}\\)\n\n\\(= ${0.5 * b * hT} \\times ${len} = ${fmtM(V)}\\) cm³`,
    };
  },
  // pyramid
  () => {
    const s = randInt(3, 18), h = 3 * randInt(1, 9);
    const V = s * s * h / 3;
    const o = buildOptions(V, [s * s * h, V / 2, s * h / 3, V * 3], (v) => unit(v, 'cm³'));
    if (!o) return null;
    return {
      text: `Find the volume of a pyramid with a square base of side ${s}cm and height ${h}cm.`,
      ...o,
      explanation: `Volume of a pyramid \\(= \\frac{1}{3} \\times \\text{base area} \\times \\text{height}\\)\n\nBase area \\(= ${s}^{2} = ${s * s}\\) cm²\n\n\\(V = \\frac{1}{3} \\times ${s * s} \\times ${h} = ${fmtM(V)}\\) cm³`,
    };
  },
  // find height given volume of a cylinder
  () => {
    const r = 7 * randInt(1, 3), h = randInt(3, 20);
    const V = PI * r * r * h;
    const o = buildOptions(h, [h * 2, h / 2, h + 3, r], (v) => unit(v, 'cm'));
    if (!o) return null;
    return {
      text: `The volume of a cylinder of radius ${r}cm is ${fmtM(V)}cm³. Find its height. ${PI_NOTE}`,
      ...o,
      explanation: `\\(V = \\pi r^{2} h\\)\n\n\\(${fmtM(V)} = \\frac{22}{7} \\times ${r * r} \\times h\\)\n\n\\(${fmtM(V)} = ${fmtM(PI * r * r)}h\\)\n\n\\(h = ${h}\\) cm`,
    };
  },
];

// =============================== AREAS ===============================
const areas = [
  // rectangle
  () => {
    const l = randInt(4, 40), w = randInt(3, 30);
    if (l === w) return null;
    const A = l * w;
    const o = buildOptions(A, [2 * (l + w), l + w, A / 2, 2 * A], (v) => unit(v, 'cm²'));
    if (!o) return null;
    return {
      text: `Find the area of a rectangle of length ${l}cm and width ${w}cm.`,
      ...o,
      explanation: `Area of a rectangle \\(= l \\times w\\)\n\n\\(= ${l} \\times ${w} = ${A}\\) cm²`,
    };
  },
  // triangle
  () => {
    const b = randInt(4, 40), h = randInt(3, 30);
    const A = 0.5 * b * h;
    const o = buildOptions(A, [b * h, 0.5 * (b + h), A / 2, b + h], (v) => unit(v, 'cm²'));
    if (!o) return null;
    return {
      text: `Calculate the area of a triangle with base ${b}cm and height ${h}cm.`,
      ...o,
      explanation: `Area of a triangle \\(= \\frac{1}{2} \\times \\text{base} \\times \\text{height}\\)\n\n\\(= \\frac{1}{2} \\times ${b} \\times ${h} = ${fmtM(A)}\\) cm²`,
    };
  },
  // circle
  () => {
    const r = 7 * randInt(1, 6);
    const A = PI * r * r;
    const o = buildOptions(A, [2 * PI * r, PI * r, A / 2, 4 * PI * r * r], (v) => unit(v, 'cm²'));
    if (!o) return null;
    return {
      text: `Find the area of a circle of radius ${r}cm. ${PI_NOTE}`,
      ...o,
      explanation: `Area of a circle \\(= \\pi r^{2}\\)\n\n\\(= \\frac{22}{7} \\times ${r}^{2} = \\frac{22}{7} \\times ${r * r}\\)\n\n\\(= ${fmtM(A)}\\) cm²`,
    };
  },
  // trapezium
  () => {
    const a = randInt(4, 25), b = randInt(4, 25), h = randInt(3, 20);
    if (a === b) return null;
    const A = 0.5 * (a + b) * h;
    const o = buildOptions(A, [(a + b) * h, 0.5 * a * b * h, a * b, A / 2], (v) => unit(v, 'cm²'));
    if (!o) return null;
    return {
      text: `Find the area of a trapezium whose parallel sides are ${a}cm and ${b}cm, and whose height is ${h}cm.`,
      ...o,
      explanation: `Area of a trapezium \\(= \\frac{1}{2}(a + b)h\\)\n\n\\(= \\frac{1}{2}(${a} + ${b}) \\times ${h}\\)\n\n\\(= \\frac{1}{2} \\times ${a + b} \\times ${h} = ${fmtM(A)}\\) cm²`,
    };
  },
  // parallelogram
  () => {
    const b = randInt(4, 30), h = randInt(3, 25);
    const A = b * h;
    const o = buildOptions(A, [0.5 * b * h, 2 * (b + h), b + h, 2 * A], (v) => unit(v, 'cm²'));
    if (!o) return null;
    return {
      text: `Calculate the area of a parallelogram with base ${b}cm and perpendicular height ${h}cm.`,
      ...o,
      explanation: `Area of a parallelogram \\(= \\text{base} \\times \\text{height}\\)\n\n\\(= ${b} \\times ${h} = ${A}\\) cm²`,
    };
  },
  // sector
  () => {
    const r = 7 * randInt(1, 4);
    const theta = pick([30, 45, 60, 90, 120, 135, 150, 180, 270]);
    const A = theta / 360 * PI * r * r;
    const o = buildOptions(A, [theta / 360 * 2 * PI * r, PI * r * r, A * 2, A / 2], (v) => unit(v, 'cm²'));
    if (!o) return null;
    return {
      text: `Find the area of a sector of a circle of radius ${r}cm which subtends an angle of ${theta}° at the centre. ${PI_NOTE}`,
      ...o,
      explanation: `Area of a sector \\(= \\frac{\\theta}{360} \\times \\pi r^{2}\\)\n\n\\(= \\frac{${theta}}{360} \\times \\frac{22}{7} \\times ${r * r}\\)\n\n\\(= ${fmtM(A)}\\) cm²`,
    };
  },
  // curved surface area of a cylinder
  () => {
    const r = 7 * randInt(1, 4), h = randInt(4, 25);
    const A = 2 * PI * r * h;
    const o = buildOptions(A, [PI * r * r * h, 2 * PI * r * (r + h), PI * r * h, A / 2], (v) => unit(v, 'cm²'));
    if (!o) return null;
    return {
      text: `Find the curved surface area of a cylinder of radius ${r}cm and height ${h}cm. ${PI_NOTE}`,
      ...o,
      explanation: `Curved surface area \\(= 2\\pi r h\\)\n\n\\(= 2 \\times \\frac{22}{7} \\times ${r} \\times ${h}\\)\n\n\\(= ${fmtM(A)}\\) cm²`,
    };
  },
  // total surface area of a closed cylinder
  () => {
    const r = 7 * randInt(1, 3), h = randInt(4, 22);
    const A = 2 * PI * r * (r + h);
    const o = buildOptions(A, [2 * PI * r * h, PI * r * r * h, A / 2, 2 * PI * r * r], (v) => unit(v, 'cm²'));
    if (!o) return null;
    return {
      text: `Calculate the total surface area of a closed cylinder of radius ${r}cm and height ${h}cm. ${PI_NOTE}`,
      ...o,
      explanation: `Total surface area \\(= 2\\pi r(r + h)\\)\n\n\\(= 2 \\times \\frac{22}{7} \\times ${r}(${r} + ${h})\\)\n\n\\(= 2 \\times \\frac{22}{7} \\times ${r} \\times ${r + h} = ${fmtM(A)}\\) cm²`,
    };
  },
  // surface area of a sphere
  () => {
    const r = 7 * randInt(1, 4);
    const A = 4 * PI * r * r;
    const o = buildOptions(A, [PI * r * r, 4 * PI * r * r * r / 3, 2 * PI * r * r, A / 2], (v) => unit(v, 'cm²'));
    if (!o) return null;
    return {
      text: `Find the surface area of a sphere of radius ${r}cm. ${PI_NOTE}`,
      ...o,
      explanation: `Surface area of a sphere \\(= 4\\pi r^{2}\\)\n\n\\(= 4 \\times \\frac{22}{7} \\times ${r * r}\\)\n\n\\(= ${fmtM(A)}\\) cm²`,
    };
  },
];

// ======================= LENGTHS AND PERIMETERS =======================
const perimeters = [
  // rectangle perimeter
  () => {
    const l = randInt(4, 40), w = randInt(3, 35);
    if (l === w) return null;
    const P = 2 * (l + w);
    const o = buildOptions(P, [l * w, l + w, P / 2, 2 * l * w], (v) => unit(v, 'cm'));
    if (!o) return null;
    return {
      text: `Find the perimeter of a rectangle of length ${l}cm and width ${w}cm.`,
      ...o,
      explanation: `Perimeter \\(= 2(l + w)\\)\n\n\\(= 2(${l} + ${w}) = 2 \\times ${l + w} = ${P}\\) cm`,
    };
  },
  // circumference
  () => {
    const r = 7 * randInt(1, 8);
    const C = 2 * PI * r;
    const o = buildOptions(C, [PI * r * r, PI * r, C / 2, 4 * PI * r], (v) => unit(v, 'cm'));
    if (!o) return null;
    return {
      text: `Find the circumference of a circle of radius ${r}cm. ${PI_NOTE}`,
      ...o,
      explanation: `Circumference \\(= 2\\pi r\\)\n\n\\(= 2 \\times \\frac{22}{7} \\times ${r} = ${fmtM(C)}\\) cm`,
    };
  },
  // arc length
  () => {
    const r = 7 * randInt(1, 5);
    const theta = pick([30, 45, 60, 90, 120, 135, 150, 180, 270]);
    const arc = theta / 360 * 2 * PI * r;
    const o = buildOptions(arc, [theta / 360 * PI * r * r, 2 * PI * r, arc * 2, arc / 2], (v) => unit(v, 'cm'));
    if (!o) return null;
    return {
      text: `Find the length of an arc of a circle of radius ${r}cm which subtends an angle of ${theta}° at the centre. ${PI_NOTE}`,
      ...o,
      explanation: `Arc length \\(= \\frac{\\theta}{360} \\times 2\\pi r\\)\n\n\\(= \\frac{${theta}}{360} \\times 2 \\times \\frac{22}{7} \\times ${r}\\)\n\n\\(= ${fmtM(arc)}\\) cm`,
    };
  },
  // perimeter of a triangle
  () => {
    const a = randInt(4, 30), b = randInt(4, 30), c = randInt(4, 30);
    if (a + b <= c || a + c <= b || b + c <= a) return null;
    const P = a + b + c;
    const o = buildOptions(P, [a * b * c, P / 2, 0.5 * a * b, P + 5], (v) => unit(v, 'cm'));
    if (!o) return null;
    return {
      text: `Find the perimeter of a triangle whose sides are ${a}cm, ${b}cm and ${c}cm.`,
      ...o,
      explanation: `Perimeter is the sum of all three sides.\n\n\\(= ${a} + ${b} + ${c} = ${P}\\) cm`,
    };
  },
  // perimeter of a regular polygon
  () => {
    const n = randInt(3, 12), s = randInt(3, 30);
    const P = n * s;
    const o = buildOptions(P, [n + s, P / 2, s * (n - 2), n * s * 2], (v) => unit(v, 'cm'));
    if (!o) return null;
    return {
      text: `Find the perimeter of a regular polygon with ${n} sides, each of length ${s}cm.`,
      ...o,
      explanation: `All sides of a regular polygon are equal.\n\nPerimeter \\(= ${n} \\times ${s} = ${P}\\) cm`,
    };
  },
  // radius from circumference
  () => {
    const r = 7 * randInt(1, 8);
    const C = 2 * PI * r;
    const o = buildOptions(r, [r * 2, r / 2, C / 2, r + 7], (v) => unit(v, 'cm'));
    if (!o) return null;
    return {
      text: `The circumference of a circle is ${fmtM(C)}cm. Find its radius. ${PI_NOTE}`,
      ...o,
      explanation: `\\(C = 2\\pi r\\)\n\n\\(${fmtM(C)} = 2 \\times \\frac{22}{7} \\times r\\)\n\n\\(${fmtM(C)} = \\frac{44r}{7}\\)\n\n\\(r = ${r}\\) cm`,
    };
  },
  // perimeter of a semicircle
  () => {
    const r = 7 * randInt(1, 5);
    const P = PI * r + 2 * r;
    const o = buildOptions(P, [PI * r, 2 * PI * r, PI * r * r / 2, P * 2], (v) => unit(v, 'cm'));
    if (!o) return null;
    return {
      text: `Find the perimeter of a semicircle of radius ${r}cm. ${PI_NOTE}`,
      ...o,
      explanation: `The perimeter of a semicircle is the curved part plus the diameter.\n\nCurved part \\(= \\pi r = \\frac{22}{7} \\times ${r} = ${fmtM(PI * r)}\\) cm\n\nDiameter \\(= 2 \\times ${r} = ${2 * r}\\) cm\n\nPerimeter \\(= ${fmtM(PI * r)} + ${2 * r} = ${fmtM(P)}\\) cm`,
    };
  },
];

// =============================== ANGLES ===============================
const angles = [
  // complementary
  () => {
    const a = randInt(5, 85);
    const correct = 90 - a;
    const o = buildOptions(correct, [180 - a, 360 - a, a, correct + 10], (v) => `${v}°`);
    if (!o) return null;
    return {
      text: `Find the complement of ${a}°.`,
      ...o,
      explanation: `Complementary angles add up to 90°.\n\n\\(90° - ${a}° = ${correct}°\\)`,
    };
  },
  // supplementary
  () => {
    const a = randInt(5, 175);
    const correct = 180 - a;
    const o = buildOptions(correct, [90 - a, 360 - a, a, correct + 15], (v) => `${v}°`);
    if (!o) return null;
    return {
      text: `Find the supplement of ${a}°.`,
      ...o,
      explanation: `Supplementary angles add up to 180°.\n\n\\(180° - ${a}° = ${correct}°\\)`,
    };
  },
  // angles at a point
  () => {
    const a = randInt(40, 120), b = randInt(40, 120), c = randInt(40, 120);
    const correct = 360 - (a + b + c);
    if (correct <= 0) return null;
    const o = buildOptions(correct, [180 - (a + b + c), a + b + c, correct + 20, 360 - a], (v) => `${v}°`);
    if (!o) return null;
    return {
      text: `Three angles at a point are ${a}°, ${b}° and ${c}°. Find the fourth angle.`,
      ...o,
      explanation: `Angles at a point add up to 360°.\n\n\\(${a}° + ${b}° + ${c}° = ${a + b + c}°\\)\n\nFourth angle \\(= 360° - ${a + b + c}° = ${correct}°\\)`,
    };
  },
  // angles on a straight line
  () => {
    const a = randInt(20, 100), b = randInt(20, 100);
    const correct = 180 - (a + b);
    if (correct <= 0) return null;
    const o = buildOptions(correct, [360 - (a + b), a + b, correct + 10, 90 - a], (v) => `${v}°`);
    if (!o) return null;
    return {
      text: `Two angles on a straight line are ${a}° and ${b}°. Find the third angle on the same straight line.`,
      ...o,
      explanation: `Angles on a straight line add up to 180°.\n\n\\(${a}° + ${b}° = ${a + b}°\\)\n\nThird angle \\(= 180° - ${a + b}° = ${correct}°\\)`,
    };
  },
  // reflex angle
  () => {
    const a = randInt(20, 170);
    const correct = 360 - a;
    const o = buildOptions(correct, [180 - a, 90 - a, a, correct - 20], (v) => `${v}°`);
    if (!o) return null;
    return {
      text: `Find the reflex angle corresponding to ${a}°.`,
      ...o,
      explanation: `A reflex angle and its corresponding angle add up to 360°.\n\n\\(360° - ${a}° = ${correct}°\\)`,
    };
  },
  // ratio of angles on a straight line
  () => {
    const p = randInt(1, 8), q = randInt(1, 8);
    if (gcd(p, q) !== 1 || p === q) return null;
    const unitAng = 180 / (p + q);
    if (!Number.isInteger(unitAng)) return null;
    const correct = p * unitAng;
    const o = buildOptions(correct, [q * unitAng, 180 - correct - 10, correct / 2, correct + 15], (v) => `${v}°`);
    if (!o) return null;
    return {
      text: `Two angles on a straight line are in the ratio ${p}:${q}. Find the smaller of the two angles.`,
      ...o,
      explanation: `The two angles add up to 180°.\n\nTotal parts \\(= ${p} + ${q} = ${p + q}\\)\n\nOne part \\(= \\frac{180°}{${p + q}} = ${unitAng}°\\)\n\nThe angles are \\(${p} \\times ${unitAng}° = ${p * unitAng}°\\) and \\(${q} \\times ${unitAng}° = ${q * unitAng}°\\).\n\nThe smaller angle is ${Math.min(p * unitAng, q * unitAng)}°.`,
      _fixCorrect: Math.min(p * unitAng, q * unitAng),
    };
  },
];
// the ratio template must report the smaller angle - rebuild cleanly
angles[5] = () => {
  const p = randInt(1, 8), q = randInt(1, 8);
  if (gcd(p, q) !== 1 || p === q) return null;
  const unitAng = 180 / (p + q);
  if (!Number.isInteger(unitAng)) return null;
  const angA = p * unitAng, angB = q * unitAng;
  const correct = Math.min(angA, angB);
  const other = Math.max(angA, angB);
  const o = buildOptions(correct, [other, correct / 2, correct + 15, 180 - correct - 5], (v) => `${v}°`);
  if (!o) return null;
  return {
    text: `Two angles on a straight line are in the ratio ${p}:${q}. Find the smaller of the two angles.`,
    ...o,
    explanation: `The two angles add up to 180°.\n\nTotal parts \\(= ${p} + ${q} = ${p + q}\\)\n\nOne part \\(= \\frac{180°}{${p + q}} = ${unitAng}°\\)\n\nThe angles are ${angA}° and ${angB}°.\n\nThe smaller angle is ${correct}°.`,
  };
};

// ======================= ANGLES ON PARALLEL LINES =======================
const parallelLines = [
  // alternate angles
  () => {
    const a = randInt(25, 155);
    const o = buildOptions(a, [180 - a, 90 - a, 360 - a, a + 10], (v) => `${v}°`);
    if (!o) return null;
    return {
      text: `In the figure, two parallel lines are cut by a transversal. If one angle is ${a}°, find the size of its alternate angle.`,
      ...o,
      explanation: `Alternate angles between parallel lines are equal.\n\nSo the alternate angle is also ${a}°.`,
    };
  },
  // corresponding angles
  () => {
    const a = randInt(25, 155);
    const o = buildOptions(a, [180 - a, 90 - a, 360 - a, a + 20], (v) => `${v}°`);
    if (!o) return null;
    return {
      text: `Two parallel lines are cut by a transversal. If one of the angles formed is ${a}°, what is the size of its corresponding angle?`,
      ...o,
      explanation: `Corresponding angles between parallel lines are equal.\n\nSo the corresponding angle is ${a}°.`,
    };
  },
  // co-interior angles
  () => {
    const a = randInt(25, 155);
    const correct = 180 - a;
    const o = buildOptions(correct, [a, 90 - a, 360 - a, correct + 10], (v) => `${v}°`);
    if (!o) return null;
    return {
      text: `Two parallel lines are cut by a transversal. If one co-interior (allied) angle is ${a}°, find the other co-interior angle.`,
      ...o,
      explanation: `Co-interior angles between parallel lines are supplementary, so they add up to 180°.\n\n\\(180° - ${a}° = ${correct}°\\)`,
    };
  },
  // vertically opposite
  () => {
    const a = randInt(20, 160);
    const o = buildOptions(a, [180 - a, 90 - a, 360 - a, a + 15], (v) => `${v}°`);
    if (!o) return null;
    return {
      text: `Two straight lines intersect. If one of the angles formed is ${a}°, find the vertically opposite angle.`,
      ...o,
      explanation: `Vertically opposite angles are equal.\n\nSo the vertically opposite angle is ${a}°.`,
    };
  },
  // transversal: find the other angle on a straight line
  () => {
    const a = randInt(30, 150);
    const correct = 180 - a;
    const o = buildOptions(correct, [a, 90 - a, 360 - a, correct - 10], (v) => `${v}°`);
    if (!o) return null;
    return {
      text: `A transversal cuts two parallel lines. One interior angle on one side of the transversal is ${a}°. Find the adjacent angle on the same straight line.`,
      ...o,
      explanation: `Angles on a straight line add up to 180°.\n\n\\(180° - ${a}° = ${correct}°\\)`,
    };
  },
  // naming the relationship
  () => {
    const rel = pick([
      { q: 'are equal and lie on opposite sides of the transversal, between the parallel lines', a: 'Alternate angles', w: ['Corresponding angles', 'Co-interior angles', 'Vertically opposite angles'] },
      { q: 'are equal and lie on the same side of the transversal, in matching positions', a: 'Corresponding angles', w: ['Alternate angles', 'Co-interior angles', 'Adjacent angles'] },
      { q: 'lie between the parallel lines on the same side of the transversal and add up to 180°', a: 'Co-interior angles', w: ['Alternate angles', 'Corresponding angles', 'Vertically opposite angles'] },
    ]);
    const o = textOptions(rel.a, rel.w);
    if (!o) return null;
    return {
      text: `When a transversal cuts two parallel lines, which pair of angles ${rel.q}?`,
      ...o,
      explanation: `By definition, the angles that ${rel.q} are called ${rel.a.toLowerCase()}.`,
    };
  },
];

// ====================== TRIANGLES AND POLYGONS ======================
const trianglesPolygons = [
  // third angle of a triangle
  () => {
    const a = randInt(20, 110), b = randInt(20, 110);
    const correct = 180 - a - b;
    if (correct <= 0) return null;
    const o = buildOptions(correct, [360 - a - b, a + b, correct + 10, 90 - a], (v) => `${v}°`);
    if (!o) return null;
    return {
      text: `Two angles of a triangle are ${a}° and ${b}°. Find the third angle.`,
      ...o,
      explanation: `The angles of a triangle add up to 180°.\n\n\\(180° - (${a}° + ${b}°) = 180° - ${a + b}° = ${correct}°\\)`,
    };
  },
  // exterior angle of a triangle
  () => {
    const a = randInt(25, 90), b = randInt(25, 90);
    const correct = a + b;
    const o = buildOptions(correct, [180 - a - b, 180 - correct, a, correct + 15], (v) => `${v}°`);
    if (!o) return null;
    return {
      text: `In a triangle, the two interior opposite angles are ${a}° and ${b}°. Find the exterior angle.`,
      ...o,
      explanation: `The exterior angle of a triangle equals the sum of the two interior opposite angles.\n\n\\(${a}° + ${b}° = ${correct}°\\)`,
    };
  },
  // isosceles triangle base angles
  () => {
    const apex = randInt(20, 140);
    if ((180 - apex) % 2 !== 0) return null;
    const correct = (180 - apex) / 2;
    const o = buildOptions(correct, [180 - apex, apex, correct + 10, 90 - apex / 2 + 5], (v) => `${v}°`);
    if (!o) return null;
    return {
      text: `The vertical angle of an isosceles triangle is ${apex}°. Find one of the base angles.`,
      ...o,
      explanation: `The base angles of an isosceles triangle are equal.\n\nSum of base angles \\(= 180° - ${apex}° = ${180 - apex}°\\)\n\nEach base angle \\(= \\frac{${180 - apex}°}{2} = ${correct}°\\)`,
    };
  },
  // sum of interior angles of a polygon
  () => {
    const n = randInt(3, 20);
    const correct = (n - 2) * 180;
    const o = buildOptions(correct, [n * 180, (n - 1) * 180, 360, correct + 180], (v) => `${v}°`);
    if (!o) return null;
    return {
      text: `Find the sum of the interior angles of a polygon with ${n} sides.`,
      ...o,
      explanation: `Sum of interior angles \\(= (n - 2) \\times 180°\\)\n\n\\(= (${n} - 2) \\times 180° = ${n - 2} \\times 180° = ${correct}°\\)`,
    };
  },
  // each interior angle of a regular polygon
  () => {
    const n = pick([3, 4, 5, 6, 8, 9, 10, 12, 15, 18, 20, 24, 30, 36]);
    const correct = (n - 2) * 180 / n;
    if (!Number.isInteger(correct)) return null;
    const o = buildOptions(correct, [360 / n, (n - 2) * 180, 180 - correct, correct + 10], (v) => `${v}°`);
    if (!o) return null;
    return {
      text: `Find the size of each interior angle of a regular polygon with ${n} sides.`,
      ...o,
      explanation: `Each interior angle \\(= \\frac{(n-2) \\times 180°}{n}\\)\n\n\\(= \\frac{${n - 2} \\times 180°}{${n}} = \\frac{${(n - 2) * 180}°}{${n}} = ${correct}°\\)`,
    };
  },
  // number of sides from exterior angle
  () => {
    const n = pick([3, 4, 5, 6, 8, 9, 10, 12, 15, 18, 20, 24, 30, 36]);
    const ext = 360 / n;
    if (!Number.isInteger(ext)) return null;
    const o = buildOptions(n, [n + 2, n - 1, 180 / ext, n * 2], (v) => String(v));
    if (!o) return null;
    return {
      text: `Each exterior angle of a regular polygon is ${ext}°. How many sides has the polygon?`,
      ...o,
      explanation: `The exterior angles of any polygon add up to 360°.\n\nNumber of sides \\(= \\frac{360°}{\\text{exterior angle}} = \\frac{360°}{${ext}°} = ${n}\\)`,
    };
  },
  // number of sides from interior angle
  () => {
    const n = pick([3, 4, 5, 6, 8, 9, 10, 12, 15, 18, 20]);
    const interior = (n - 2) * 180 / n;
    if (!Number.isInteger(interior)) return null;
    const o = buildOptions(n, [n + 1, n - 2, 360 / (180 - interior) + 1, n * 2], (v) => String(v));
    if (!o) return null;
    return {
      text: `Each interior angle of a regular polygon is ${interior}°. Find the number of sides of the polygon.`,
      ...o,
      explanation: `Exterior angle \\(= 180° - ${interior}° = ${180 - interior}°\\)\n\nNumber of sides \\(= \\frac{360°}{${180 - interior}°} = ${n}\\)`,
    };
  },
  // Pythagoras
  () => {
    const triples = [[3, 4, 5], [5, 12, 13], [8, 15, 17], [7, 24, 25], [9, 12, 15], [6, 8, 10], [20, 21, 29], [12, 16, 20], [10, 24, 26], [15, 20, 25], [18, 24, 30], [9, 40, 41]];
    const [a, b, c] = pick(triples);
    const findHyp = Math.random() < 0.5;
    if (findHyp) {
      const o = buildOptions(c, [a + b, Math.abs(b - a), c + 1, Math.round(Math.sqrt(b * b - a * a))], (v) => unit(v, 'cm'));
      if (!o) return null;
      return {
        text: `A right-angled triangle has the two shorter sides ${a}cm and ${b}cm. Find the length of the hypotenuse.`,
        ...o,
        explanation: `By Pythagoras' theorem, \\(c^{2} = a^{2} + b^{2}\\).\n\n\\(c^{2} = ${a}^{2} + ${b}^{2} = ${a * a} + ${b * b} = ${c * c}\\)\n\n\\(c = \\sqrt{${c * c}} = ${c}\\) cm`,
      };
    } else {
      const o = buildOptions(a, [c - b, c + b, a + 2, Math.round(Math.sqrt(c * c + b * b))], (v) => unit(v, 'cm'));
      if (!o) return null;
      return {
        text: `The hypotenuse of a right-angled triangle is ${c}cm and one of the other sides is ${b}cm. Find the length of the third side.`,
        ...o,
        explanation: `By Pythagoras' theorem, \\(a^{2} = c^{2} - b^{2}\\).\n\n\\(a^{2} = ${c}^{2} - ${b}^{2} = ${c * c} - ${b * b} = ${a * a}\\)\n\n\\(a = \\sqrt{${a * a}} = ${a}\\) cm`,
      };
    }
  },
];

// ========================== CIRCLE THEOREMS ==========================
const circleTheorems = [
  // angle at centre = 2 x angle at circumference
  () => {
    const circ = randInt(15, 89);
    const correct = 2 * circ;
    const o = buildOptions(correct, [circ / 2, 180 - circ, circ, 360 - 2 * circ], (v) => `${v}°`);
    if (!o) return null;
    return {
      text: `An arc of a circle subtends an angle of ${circ}° at the circumference. Find the angle it subtends at the centre.`,
      ...o,
      explanation: `The angle subtended at the centre is twice the angle subtended at the circumference by the same arc.\n\n\\(2 \\times ${circ}° = ${correct}°\\)`,
    };
  },
  // reverse: centre given, find circumference angle
  () => {
    const centre = 2 * randInt(15, 89);
    const correct = centre / 2;
    const o = buildOptions(correct, [centre, 180 - centre, 360 - centre, correct + 10], (v) => `${v}°`);
    if (!o) return null;
    return {
      text: `An arc subtends an angle of ${centre}° at the centre of a circle. Find the angle it subtends at the circumference.`,
      ...o,
      explanation: `The angle at the circumference is half the angle at the centre subtended by the same arc.\n\n\\(\\frac{${centre}°}{2} = ${correct}°\\)`,
    };
  },
  // cyclic quadrilateral
  () => {
    const a = randInt(40, 140);
    const correct = 180 - a;
    const o = buildOptions(correct, [a, 360 - a, 90 - a, correct + 20], (v) => `${v}°`);
    if (!o) return null;
    return {
      text: `One angle of a cyclic quadrilateral is ${a}°. Find the angle opposite to it.`,
      ...o,
      explanation: `Opposite angles of a cyclic quadrilateral are supplementary, so they add up to 180°.\n\n\\(180° - ${a}° = ${correct}°\\)`,
    };
  },
  // angle in a semicircle
  () => {
    const other = randInt(20, 70);
    const correct = 90 - other;
    const o = buildOptions(correct, [90, 180 - other, other, correct + 10], (v) => `${v}°`);
    if (!o) return null;
    return {
      text: `In a circle, \\(AB\\) is a diameter and \\(C\\) is a point on the circumference. If \\(\\angle ABC = ${other}°\\), find \\(\\angle BAC\\).`,
      ...o,
      explanation: `The angle in a semicircle is a right angle, so \\(\\angle ACB = 90°\\).\n\nThe angles of triangle \\(ABC\\) add up to 180°.\n\n\\(\\angle BAC = 180° - 90° - ${other}° = ${correct}°\\)`,
    };
  },
  // angles in the same segment
  () => {
    const a = randInt(20, 80);
    const o = buildOptions(a, [180 - a, 2 * a, 90 - a, a + 15], (v) => `${v}°`);
    if (!o) return null;
    return {
      text: `Two angles are subtended by the same chord in the same segment of a circle. If one of them is ${a}°, find the other.`,
      ...o,
      explanation: `Angles in the same segment of a circle are equal.\n\nSo the other angle is also ${a}°.`,
    };
  },
  // tangent and radius
  () => {
    const a = randInt(20, 70);
    const correct = 90 - a;
    const o = buildOptions(correct, [90, 180 - a, a, correct + 10], (v) => `${v}°`);
    if (!o) return null;
    return {
      text: `\\(PT\\) is a tangent to a circle with centre \\(O\\), touching the circle at \\(T\\). If \\(\\angle OPT = ${a}°\\), find \\(\\angle POT\\).`,
      ...o,
      explanation: `A tangent is perpendicular to the radius at the point of contact, so \\(\\angle OTP = 90°\\).\n\nIn triangle \\(OPT\\), the angles add up to 180°.\n\n\\(\\angle POT = 180° - 90° - ${a}° = ${correct}°\\)`,
    };
  },
  // alternate segment theorem
  () => {
    const a = randInt(25, 80);
    const o = buildOptions(a, [180 - a, 90 - a, 2 * a, a + 20], (v) => `${v}°`);
    if (!o) return null;
    return {
      text: `The angle between a tangent and a chord drawn from the point of contact is ${a}°. Find the angle in the alternate segment.`,
      ...o,
      explanation: `By the alternate segment theorem, the angle between a tangent and a chord equals the angle in the alternate segment.\n\nSo the required angle is ${a}°.`,
    };
  },
  // two tangents from an external point
  () => {
    const apex = randInt(20, 100);
    const correct = 180 - apex;
    const o = buildOptions(correct, [apex, 90 - apex / 2, 360 - apex, correct - 20], (v) => `${v}°`);
    if (!o) return null;
    return {
      text: `Two tangents are drawn from an external point \\(P\\) to a circle with centre \\(O\\), touching it at \\(A\\) and \\(B\\). If \\(\\angle APB = ${apex}°\\), find \\(\\angle AOB\\).`,
      ...o,
      explanation: `\\(OAPB\\) is a quadrilateral with \\(\\angle OAP = \\angle OBP = 90°\\) (tangent perpendicular to radius).\n\nThe angles of a quadrilateral add up to 360°.\n\n\\(\\angle AOB = 360° - 90° - 90° - ${apex}° = ${correct}°\\)`,
    };
  },
];

// ============================ CONSTRUCTION ============================
const CONSTRUCTIBLE = [15, 30, 45, 60, 75, 90, 105, 120, 135, 150, 165, 180];
const NOT_CONSTRUCTIBLE = [10, 20, 25, 35, 40, 50, 55, 65, 70, 80, 85, 95, 100, 110, 125, 140, 155, 160, 170];

const ROMAN = ['I', 'II', 'III'];
const construction = [
  // WAEC-style "I. II. III." list: exactly one constructible
  () => {
    const good = pick(CONSTRUCTIBLE);
    const bad = sample(NOT_CONSTRUCTIBLE, 2);
    const items = shuffle([{ v: good, ok: true }, { v: bad[0], ok: false }, { v: bad[1], ok: false }]);
    const idx = items.findIndex(i => i.ok);
    const correct = `${ROMAN[idx]} only`;
    const o = textOptions(correct, ROMAN.filter((_, i) => i !== idx).map(r => `${r} only`).concat(['I and II only']).slice(0, 3));
    if (!o) return null;
    return {
      text: `Which of the following angles can be constructed using a ruler and a pair of compasses only? ${items.map((it, i) => `${ROMAN[i]}. ${it.v}°`).join(' ')}`,
      ...o,
      explanation: `With a ruler and a pair of compasses, 60° and 90° can be constructed directly. Repeated bisection and addition of these produce every multiple of 15°.\n\nOf the angles listed, only ${good}° is a multiple of 15°, so only ${ROMAN[idx]} can be constructed.`,
    };
  },
  // bisect an angle once
  () => {
    const base = 2 * randInt(5, 90);
    const correct = base / 2;
    const o = buildOptions(correct, [base, base * 2, correct + 10, correct - 5], (v) => `${v}°`);
    if (!o) return null;
    return {
      text: `An angle of ${base}° is bisected. Find the size of each of the two angles formed.`,
      ...o,
      explanation: `Bisecting an angle divides it into two equal parts.\n\n\\(\\frac{${base}°}{2} = ${correct}°\\)`,
    };
  },
  // bisect twice
  () => {
    const correct = randInt(3, 44);
    const base = 4 * correct;
    if (base > 180) return null;
    const o = buildOptions(correct, [base / 2, base, correct + 5, correct * 3], (v) => `${v}°`);
    if (!o) return null;
    return {
      text: `An angle of ${base}° is bisected, and one of the resulting angles is bisected again. Find the size of the final angle.`,
      ...o,
      explanation: `First bisection: \\(\\frac{${base}°}{2} = ${base / 2}°\\)\n\nSecond bisection: \\(\\frac{${base / 2}°}{2} = ${correct}°\\)`,
    };
  },
  // difference of two constructed angles
  () => {
    const a = pick([30, 45, 60, 75, 90, 105, 120, 135, 150]);
    const b = pick([15, 30, 45, 60, 75, 90]);
    const correct = a - b;
    if (correct <= 0) return null;
    const o = buildOptions(correct, [a + b, b - a + 180, correct + 15, correct - 15], (v) => `${v}°`);
    if (!o) return null;
    return {
      text: `An angle of ${b}° is constructed inside an angle of ${a}°, sharing the same arm. Find the size of the remaining angle.`,
      ...o,
      explanation: `The remaining angle is the difference between the two angles.\n\n\\(${a}° - ${b}° = ${correct}°\\)`,
    };
  },
  // bisecting to obtain an angle
  () => {
    const base = pick([60, 90, 120, 150, 180, 30]);
    const correct = base / 2;
    const o = buildOptions(correct, [base, base * 2, correct + 15, correct - 15], (v) => `${v}°`);
    if (!o) return null;
    return {
      text: `Which angle must be bisected in order to construct an angle of ${correct}°?`,
      ...o,
      explanation: `Bisecting an angle divides it into two equal halves.\n\nTo obtain ${correct}°, bisect \\(2 \\times ${correct}° = ${base}°\\).`,
      _swap: true,
    };
  },
  // instrument / method facts
  () => {
    const facts = [
      { q: 'What is the first step in constructing a perpendicular bisector of a line segment \\(AB\\)?', a: 'Draw arcs of equal radius (more than half \\(AB\\)) from both \\(A\\) and \\(B\\)', w: ['Measure the angle at \\(A\\) with a protractor', 'Draw a circle with \\(AB\\) as diameter', 'Bisect the angle at \\(A\\)'] },
      { q: 'The locus of points equidistant from the two arms of an angle is', a: 'the bisector of the angle', w: ['the perpendicular bisector of the angle', 'a circle centred at the vertex', 'a line parallel to one arm'] },
      { q: 'Which pair of instruments is sufficient for a standard geometric construction?', a: 'A ruler and a pair of compasses', w: ['A protractor and a set square', 'A ruler and a protractor', 'A pair of compasses and a divider'] },
      { q: 'To construct an angle of 60°, what is constructed first?', a: 'An arc from the vertex cutting the base line, then an equal arc from that point', w: ['A perpendicular to the base line', 'A bisector of a right angle', 'A semicircle on the base line'] },
    ];
    const f = pick(facts);
    const o = textOptions(f.a, f.w);
    if (!o) return null;
    return {
      text: f.q,
      ...o,
      explanation: `The correct procedure is: ${f.a}.`,
    };
  },
  // sum/difference construction
  () => {
    const a = pick([30, 45, 60, 90]), b = pick([15, 30, 45, 60]);
    const correct = a + b;
    if (correct > 180) return null;
    const o = buildOptions(correct, [a - b, a * 2, correct + 15, Math.abs(a - b) + 10], (v) => `${v}°`);
    if (!o) return null;
    return {
      text: `An angle of ${a}° is constructed and an angle of ${b}° is constructed adjacent to it. What is the size of the resulting angle?`,
      ...o,
      explanation: `Adjacent constructed angles add together.\n\n\\(${a}° + ${b}° = ${correct}°\\)`,
    };
  },
];
// fix the bisection template wording so the asked value matches the answer
construction[4] = () => {
  const correct = pick([30, 45, 60, 75, 90, 15]);
  const base = correct * 2;
  if (base > 180) return null;
  const o = buildOptions(base, [correct, correct * 4 > 180 ? correct + 30 : correct * 4, base + 15, base - 15], (v) => `${v}°`);
  if (!o) return null;
  return {
    text: `Which angle must be bisected in order to construct an angle of ${correct}°?`,
    ...o,
    explanation: `Bisecting an angle divides it into two equal parts.\n\nTo obtain ${correct}°, the angle bisected must be \\(2 \\times ${correct}° = ${base}°\\).`,
  };
};

// ================================ LOCI ================================
const POINT_NAMES = [['A', 'B'], ['P', 'Q'], ['X', 'Y'], ['M', 'N'], ['C', 'D'], ['R', 'S'], ['E', 'F'], ['G', 'H']];
const CENTRES = ['O', 'P', 'A', 'C', 'M', 'T'];

const loci = [
  // equidistant from two points (distance varies the wording)
  () => {
    const [a, b] = pick(POINT_NAMES);
    const d = randInt(2, 30);
    const correct = `The perpendicular bisector of \\(${a}${b}\\)`;
    const o = textOptions(correct, [
      `A circle with \\(${a}${b}\\) as diameter`,
      `The bisector of the angle at \\(${a}\\)`,
      `A line parallel to \\(${a}${b}\\)`,
    ]);
    if (!o) return null;
    return {
      text: `Two points \\(${a}\\) and \\(${b}\\) are ${d}cm apart. What is the locus of points equidistant from \\(${a}\\) and \\(${b}\\)?`,
      ...o,
      explanation: `Every point on the perpendicular bisector of a line segment is the same distance from the two endpoints.\n\nSo the locus is the perpendicular bisector of \\(${a}${b}\\), drawn at right angles through the midpoint of \\(${a}${b}\\).`,
    };
  },
  // point equidistant from two points, stated as a moving point
  () => {
    const [a, b] = pick(POINT_NAMES);
    const d = randInt(2, 30);
    const correct = `The perpendicular bisector of \\(${a}${b}\\)`;
    const o = textOptions(correct, [
      `A circle of radius ${d}cm centred at \\(${a}\\)`,
      `The bisector of the angle between \\(${a}${b}\\) and the horizontal`,
      `A line through \\(${a}\\) parallel to \\(${b}\\)`,
    ]);
    if (!o) return null;
    return {
      text: `A point \\(P\\) moves so that it is always the same distance from \\(${a}\\) as it is from \\(${b}\\), where \\(${a}${b} = ${d}\\)cm. Describe the locus of \\(P\\).`,
      ...o,
      explanation: `\\(P\\) satisfies \\(P${a} = P${b}\\) at every position.\n\nThe set of such points is the perpendicular bisector of \\(${a}${b}\\).`,
    };
  },
  // fixed distance from a point -> circle
  () => {
    const c = pick(CENTRES);
    const r = randInt(2, 20);
    const correct = `A circle of radius ${r}cm with centre \\(${c}\\)`;
    const o = textOptions(correct, [
      `A circle of radius ${r * 2}cm with centre \\(${c}\\)`,
      `A straight line ${r}cm from \\(${c}\\)`,
      `The perpendicular bisector of a line ${r}cm long`,
    ]);
    if (!o) return null;
    return {
      text: `A point moves so that it is always ${r}cm from a fixed point \\(${c}\\). What is its locus?`,
      ...o,
      explanation: `The set of all points at a constant distance from a fixed point is a circle.\n\nThe centre is \\(${c}\\) and the radius is ${r}cm.`,
    };
  },
  // fixed distance from a point, stated with a named moving point
  () => {
    const c = pick(CENTRES);
    const r = randInt(2, 25);
    const mover = pick(['P', 'Q', 'R', 'X', 'Z']);
    if (mover === c) return null;
    const correct = `A circle of radius ${r}cm with centre \\(${c}\\)`;
    const o = textOptions(correct, [
      `A circle of radius ${Math.round(r / 2) || 1}cm with centre \\(${c}\\)`,
      `The perpendicular bisector of a line of length ${r}cm`,
      `Two parallel lines ${r}cm from \\(${c}\\)`,
    ]);
    if (!o) return null;
    return {
      text: `A point \\(${mover}\\) moves in a plane so that \\(${mover}${c} = ${r}\\)cm, where \\(${c}\\) is fixed. Describe the locus of \\(${mover}\\).`,
      ...o,
      explanation: `\\(${mover}\\) stays a constant distance of ${r}cm from the fixed point \\(${c}\\).\n\nThe locus is therefore a circle of radius ${r}cm centred at \\(${c}\\).`,
    };
  },
  // equidistant from two intersecting lines
  () => {
    const [a, b] = pick(POINT_NAMES);
    const correct = 'The pair of bisectors of the angles between the lines';
    const o = textOptions(correct, [
      'The perpendicular bisector of the lines',
      'A circle touching both lines',
      'A line parallel to both lines',
    ]);
    if (!o) return null;
    return {
      text: `Two straight lines intersect at a point. What is the locus of points equidistant from both lines?`,
      ...o,
      explanation: `Points equidistant from two intersecting lines lie on the bisectors of the angles formed between them.`,
    };
  },
  // fixed distance from a line
  () => {
    const d = randInt(2, 15);
    const correct = `Two lines parallel to it, each ${d}cm away`;
    const o = textOptions(correct, [
      `One line parallel to it, ${d}cm away`,
      `A circle of radius ${d}cm`,
      `The perpendicular bisector of the line`,
    ]);
    if (!o) return null;
    return {
      text: `A point moves so that it is always ${d}cm from a fixed straight line. What is its locus?`,
      ...o,
      explanation: `The point can lie on either side of the line.\n\nSo the locus is a pair of lines parallel to the given line, each at a perpendicular distance of ${d}cm from it.`,
    };
  },
  // equidistant from a point and within a circle etc.
  () => {
    const c = pick(CENTRES);
    const r = randInt(3, 15);
    const correct = `The interior of a circle of radius ${r}cm centred at \\(${c}\\)`;
    const o = textOptions(correct, [
      `The circumference of a circle of radius ${r}cm centred at \\(${c}\\)`,
      `The exterior of a circle of radius ${r}cm centred at \\(${c}\\)`,
      `A line ${r}cm from \\(${c}\\)`,
    ]);
    if (!o) return null;
    return {
      text: `A point moves so that its distance from a fixed point \\(${c}\\) is always less than ${r}cm. Describe its locus.`,
      ...o,
      explanation: `Points less than ${r}cm from \\(${c}\\) lie inside the circle of radius ${r}cm centred at \\(${c}\\), not on it.`,
    };
  },
  // locus equidistant from three non-collinear points
  () => {
    const correct = 'A single point, the centre of the circle through the three points';
    const o = textOptions(correct, [
      'A circle through the three points',
      'The perpendicular bisector of the longest side',
      'Three separate lines',
    ]);
    if (!o) return null;
    return {
      text: `What is the locus of points equidistant from three non-collinear points?`,
      ...o,
      explanation: `The perpendicular bisectors of the segments joining the points meet at one point, the circumcentre.\n\nThis single point is equidistant from all three.`,
    };
  },
];

// =================== COORDINATE GEOMETRY OF STRAIGHT LINES ===================
const coordinate = [
  // distance between two points
  () => {
    const triples = [[3, 4, 5], [5, 12, 13], [8, 15, 17], [6, 8, 10], [9, 12, 15], [7, 24, 25], [12, 16, 20], [20, 21, 29]];
    const [dx, dy, d] = pick(triples);
    const x1 = randInt(-10, 10), y1 = randInt(-10, 10);
    const sx = pick([1, -1]), sy = pick([1, -1]);
    const x2 = x1 + sx * dx, y2 = y1 + sy * dy;
    const o = buildOptions(d, [dx + dy, Math.abs(dx - dy), d + 1, d * 2], (v) => unit(v, ' units'));
    if (!o) return null;
    return {
      text: `Find the distance between the points \\((${x1}, ${y1})\\) and \\((${x2}, ${y2})\\).`,
      ...o,
      explanation: `Distance \\(= \\sqrt{(x_2 - x_1)^{2} + (y_2 - y_1)^{2}}\\)\n\n\\(= \\sqrt{(${x2} - (${x1}))^{2} + (${y2} - (${y1}))^{2}}\\)\n\n\\(= \\sqrt{(${x2 - x1})^{2} + (${y2 - y1})^{2}} = \\sqrt{${dx * dx} + ${dy * dy}} = \\sqrt{${d * d}} = ${d}\\)`,
    };
  },
  // midpoint
  () => {
    const x1 = randInt(-12, 12), y1 = randInt(-12, 12);
    const x2 = x1 + 2 * nonZero(-8, 8), y2 = y1 + 2 * nonZero(-8, 8);
    const mx = (x1 + x2) / 2, my = (y1 + y2) / 2;
    const o = buildOptions([mx, my], [[x2 - x1, y2 - y1], [my, mx], [mx + 1, my - 1]],
      (p) => mathOpt(`(${p[0]}, ${p[1]})`));
    if (!o) return null;
    return {
      text: `Find the midpoint of the line joining \\((${x1}, ${y1})\\) and \\((${x2}, ${y2})\\).`,
      ...o,
      explanation: `Midpoint \\(= \\left(\\frac{x_1 + x_2}{2}, \\frac{y_1 + y_2}{2}\\right)\\)\n\n\\(= \\left(\\frac{${x1} + ${x2}}{2}, \\frac{${y1} + ${y2}}{2}\\right)\\)\n\n\\(= (${mx}, ${my})\\)`,
    };
  },
  // gradient between two points
  () => {
    const x1 = randInt(-10, 10), y1 = randInt(-10, 10);
    const dx = nonZero(-8, 8), dy = nonZero(-10, 10);
    const x2 = x1 + dx, y2 = y1 + dy;
    const g = frac(dy, dx);
    const o = buildOptions(g, [frac(dx, dy), frac(-dy, dx), frac(dy + 1, dx)], (f) => fracOpt(f));
    if (!o) return null;
    return {
      text: `Find the gradient of the line joining \\((${x1}, ${y1})\\) and \\((${x2}, ${y2})\\).`,
      ...o,
      explanation: `Gradient \\(= \\frac{y_2 - y_1}{x_2 - x_1}\\)\n\n\\(= \\frac{${y2} - (${y1})}{${x2} - (${x1})} = \\frac{${dy}}{${dx}}\\)\n\n\\(= ${fracTex(g)}\\)`,
    };
  },
  // equation of a line through a point with a given gradient
  () => {
    const m = nonZero(-6, 6), x1 = randInt(-8, 8), y1 = randInt(-8, 8);
    const c = y1 - m * x1;
    const lin = (a, b) => {
      let s = a === 1 ? 'x' : a === -1 ? '-x' : `${a}x`;
      if (b !== 0) s += (b > 0 ? ' + ' : ' - ') + Math.abs(b);
      return s;
    };
    const o = buildOptions([m, c], [[m, -c], [-m, c], [c, m]], (p) => mathOpt(`y = ${lin(p[0], p[1])}`));
    if (!o) return null;
    return {
      text: `Find the equation of the straight line with gradient ${m} passing through the point \\((${x1}, ${y1})\\).`,
      ...o,
      explanation: `Use \\(y - y_1 = m(x - x_1)\\).\n\n\\(y - (${y1}) = ${m}(x - (${x1}))\\)\n\n\\(y = ${m}x ${-m * x1 >= 0 ? '+' : '-'} ${Math.abs(m * x1)} ${y1 >= 0 ? '+' : '-'} ${Math.abs(y1)}\\)\n\n\\(y = ${lin(m, c)}\\)`,
    };
  },
  // gradient of a perpendicular line
  () => {
    const a = nonZero(-8, 8), b = randInt(2, 9);
    const m = frac(a, b);
    const perp = frac(-b, a);
    const o = buildOptions(perp, [m, frac(b, a), frac(-a, b)], (f) => fracOpt(f));
    if (!o) return null;
    return {
      text: `A line has gradient \\(${fracTex(m)}\\). Find the gradient of a line perpendicular to it.`,
      ...o,
      explanation: `For perpendicular lines, \\(m_1 \\times m_2 = -1\\).\n\n\\(m_2 = -\\frac{1}{${fracTex(m)}} = ${fracTex(perp)}\\)`,
    };
  },
  // gradient of a parallel line
  () => {
    const m = nonZero(-9, 9), c = randInt(-10, 10);
    const o = buildOptions(m, [-m, frac(1, m).n / frac(1, m).d, m + 1], (v) => fmtNum(v, 3));
    if (!o) return null;
    return {
      text: `Find the gradient of any line parallel to \\(y = ${m === 1 ? 'x' : m === -1 ? '-x' : `${m}x`} ${c >= 0 ? '+' : '-'} ${Math.abs(c)}\\).`,
      ...o,
      explanation: `Parallel lines have equal gradients.\n\nThe given line has gradient ${m}, so any parallel line also has gradient ${m}.`,
    };
  },
  // x-intercept
  () => {
    const m = nonZero(-8, 8);
    const k = nonZero(-8, 8);
    const c = -m * k;                       // so the root is exactly x = k
    const o = buildOptions(k, [-k, c, k + 1], (v) => String(v));
    if (!o) return null;
    return {
      text: `Find the x-intercept of the line \\(y = ${m === 1 ? 'x' : m === -1 ? '-x' : `${m}x`} ${c >= 0 ? '+' : '-'} ${Math.abs(c)}\\).`,
      ...o,
      explanation: `The x-intercept is where \\(y = 0\\).\n\n\\(0 = ${m}x ${c >= 0 ? '+' : '-'} ${Math.abs(c)}\\)\n\n\\(${m}x = ${-c}\\)\n\n\\(x = ${k}\\)`,
    };
  },
];

module.exports = [
  { topicId: '29cNp8gTkGEGe0elHpCY', unitId: U_MENS, topicName: 'Volumes', generators: volumes },
  { topicId: 'bcfw1Su8647dddTevZhy', unitId: U_MENS, topicName: 'Areas', generators: areas },
  { topicId: 'raiMVJtOSRLhrAUkbn0I', unitId: U_MENS, topicName: 'Lengths and Perimeters', generators: perimeters },
  { topicId: 'EcCb8gLBcEYPvMpZpkm9', unitId: U_PLANE, topicName: 'Construction', generators: construction },
  { topicId: 'dSzM8qxvrxvSi7jlI5mG', unitId: U_PLANE, topicName: 'Triangles and Polygons', generators: trianglesPolygons },
  { topicId: 'X5eV19S3P3tREFfiFMut', unitId: U_PLANE, topicName: 'Circle Theorems', generators: circleTheorems },
  { topicId: 'amw6bEfb9gSJ9Ve81VFn', unitId: U_PLANE, topicName: 'Angles on Parallel Lines', generators: parallelLines },
  { topicId: 'xolBMrY0tavoF7Rbae8C', unitId: U_PLANE, topicName: 'Loci', generators: loci },
  { topicId: 'xpYeWCb94pudsKGvY9Do', unitId: U_PLANE, topicName: 'Angles', generators: angles },
  { topicId: 'aUtXJtVUiftSMXvD13Vr', unitId: U_COORD, topicName: 'Coordinate Geometry of Straight Lines', generators: coordinate },
];
