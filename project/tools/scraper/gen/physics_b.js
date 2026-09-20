// Physics > Forces and Equilibrium, Gravitation, Work Energy and Power
const L = require('./lib');
const { randInt, pick, shuffle, sample, nonZero, frac, fracTex, fracOpt,
        fmtNum, buildOptions, textOptions, round } = L;
const { conceptGens, qaBank } = require('./concept');

const U_FORCE = 'Esm9MZsMNipuDDjRyb4S';
const U_GRAV = 'FcpqCzyek59Ah33sbXRr';
const U_WEP = 'tBRmodqD7JJn7wmHtFz6';
const G = 10;
const BIG_G = 6.67e-11;

// ============================== FRICTION ==============================
const friction = [
  // F = mu R
  () => {
    const mu = pick([0.1, 0.2, 0.25, 0.3, 0.4, 0.5, 0.6, 0.75, 0.8]);
    const m = randInt(2, 60);
    const R = m * G;
    const F = mu * R;
    const o = buildOptions(round(F, 2), [round(R, 2), round(mu * m, 2), round(F * 2, 2)], (v) => `${fmtNum(v, 2)}N`);
    if (!o) return null;
    return {
      text: `A block of mass ${m}kg rests on a horizontal surface with coefficient of friction ${mu}. Calculate the frictional force. [Take \\(g = 10\\)m/s²]`,
      ...o,
      explanation: `Normal reaction \\(R = mg = ${m} \\times 10 = ${R}\\)N\n\n\\(F = \\mu R = ${mu} \\times ${R} = ${fmtNum(F, 2)}\\)N`,
    };
  },
  // find the coefficient
  () => {
    const mu = pick([0.2, 0.25, 0.4, 0.5, 0.8]);
    const m = randInt(5, 50);
    const R = m * G;
    const F = mu * R;
    const o = buildOptions(mu, [round(F / m, 2), round(R / F, 2), round(mu + 0.1, 2)], (v) => fmtNum(v, 2));
    if (!o) return null;
    return {
      text: `A frictional force of ${fmtNum(F, 2)}N acts on a block of mass ${m}kg resting on a horizontal surface. Calculate the coefficient of friction. [Take \\(g = 10\\)m/s²]`,
      ...o,
      explanation: `\\(R = mg = ${R}\\)N\n\n\\(\\mu = \\frac{F}{R} = \\frac{${fmtNum(F, 2)}}{${R}} = ${mu}\\)`,
    };
  },
  // net force with friction
  () => {
    const m = randInt(2, 30), applied = randInt(40, 200);
    const mu = pick([0.1, 0.2, 0.25, 0.5]);
    const F = mu * m * G;
    const net = applied - F;
    if (net <= 0) return null;
    const a = net / m;
    const o = buildOptions(round(a, 2), [round(applied / m, 2), round(F / m, 2), round(a * 2, 2)], (v) => `${fmtNum(v, 2)}m/s²`);
    if (!o) return null;
    return {
      text: `A horizontal force of ${applied}N is applied to a ${m}kg block on a surface with coefficient of friction ${mu}. Calculate the acceleration of the block. [Take \\(g = 10\\)m/s²]`,
      ...o,
      explanation: `Friction \\(= \\mu mg = ${mu} \\times ${m} \\times 10 = ${fmtNum(F, 2)}\\)N\n\nNet force \\(= ${applied} - ${fmtNum(F, 2)} = ${fmtNum(net, 2)}\\)N\n\n\\(a = \\frac{F_{net}}{m} = \\frac{${fmtNum(net, 2)}}{${m}} = ${fmtNum(a, 2)}\\)m/s²`,
    };
  },
  ...conceptGens('friction', [
    'Friction always opposes relative motion between surfaces in contact',
    'Limiting friction is the maximum value of static friction',
    'The coefficient of friction has no unit',
    'Friction depends on the nature of the surfaces in contact',
    'Lubrication reduces friction between moving parts',
    'Kinetic friction is generally less than limiting static friction',
    'Frictional force is independent of the area of contact for a given normal reaction',
  ], [
    'Friction always acts in the direction of motion',
    'The coefficient of friction is measured in newtons',
    'Friction is always undesirable and serves no useful purpose',
    'Frictional force is directly proportional to the area of contact',
    'Kinetic friction is always greater than limiting static friction',
    'Friction does not depend on the normal reaction',
  ]),
];

// ============= EQUILIBRIUM OF FORCES AND MOMENTS =============
const equilibrium = [
  // moment of a force
  () => {
    const F = randInt(5, 80), d = randInt(2, 15);
    const M = F * d;
    const o = buildOptions(M, [F + d, round(F / d, 2), M * 2], (v) => `${fmtNum(v, 2)}Nm`);
    if (!o) return null;
    return {
      text: `Calculate the moment of a force of ${F}N acting at a perpendicular distance of ${d}m from a pivot.`,
      ...o,
      explanation: `Moment \\(= F \\times d\\)\n\n\\(= ${F} \\times ${d} = ${M}\\)Nm`,
    };
  },
  // principle of moments
  () => {
    const F1 = randInt(2, 40), d1 = randInt(2, 12), d2 = randInt(2, 12);
    const F2 = F1 * d1 / d2;
    if (!Number.isInteger(F2)) return null;
    const o = buildOptions(F2, [F1, round(F1 * d2 / d1, 2), F2 + 5], (v) => `${fmtNum(v, 2)}N`);
    if (!o) return null;
    return {
      text: `A uniform metre rule is pivoted at its centre. A force of ${F1}N acts ${d1}m from the pivot on one side. What force acting ${d2}m from the pivot on the other side will balance it?`,
      ...o,
      explanation: `By the principle of moments, sum of clockwise moments = sum of anticlockwise moments.\n\n\\(${F1} \\times ${d1} = F \\times ${d2}\\)\n\n\\(${F1 * d1} = ${d2}F\\)\n\n\\(F = ${F2}\\)N`,
    };
  },
  // distance for balance
  () => {
    const F1 = randInt(2, 30), d1 = randInt(2, 12), F2 = randInt(2, 30);
    const d2 = F1 * d1 / F2;
    if (!Number.isInteger(d2)) return null;
    const o = buildOptions(d2, [d1, round(F2 * d1 / F1, 2), d2 + 2], (v) => `${fmtNum(v, 2)}m`);
    if (!o) return null;
    return {
      text: `A force of ${F1}N acts at ${d1}m from a pivot. At what distance from the pivot must a force of ${F2}N act on the opposite side to produce equilibrium?`,
      ...o,
      explanation: `\\(F_1 d_1 = F_2 d_2\\)\n\n\\(${F1} \\times ${d1} = ${F2} \\times d_2\\)\n\n\\(d_2 = \\frac{${F1 * d1}}{${F2}} = ${d2}\\)m`,
    };
  },
  ...conceptGens('equilibrium of forces', [
    'For a body in equilibrium the sum of all forces acting on it is zero',
    'For a body in equilibrium the sum of moments about any point is zero',
    'The principle of moments states that clockwise moments equal anticlockwise moments about the same point',
    'Three non-parallel forces in equilibrium must pass through a common point',
    'The moment of a force is the product of the force and the perpendicular distance from the pivot',
  ], [
    'A body in equilibrium must always be at rest',
    'The sum of the moments about a point in equilibrium equals the total force',
    'Moments are measured in newtons',
    'For equilibrium only the vertical forces need to balance',
    'The moment of a force does not depend on the distance from the pivot',
  ]),
];

// ======================= NEWTON'S LAWS OF MOTION =======================
const newtonLaws = [
  // F = ma
  () => {
    const m = randInt(2, 60), a = randInt(1, 15);
    const F = m * a;
    const o = buildOptions(F, [m + a, round(m / a, 2), F * 2], (v) => `${fmtNum(v, 2)}N`);
    if (!o) return null;
    return {
      text: `Calculate the force required to give a body of mass ${m}kg an acceleration of ${a}m/s².`,
      ...o,
      explanation: `By Newton's second law, \\(F = ma\\).\n\n\\(= ${m} \\times ${a} = ${F}\\)N`,
    };
  },
  // find acceleration
  () => {
    const m = randInt(2, 40), a = randInt(1, 12);
    const F = m * a;
    const o = buildOptions(a, [F, round(F * m, 2), a + 2], (v) => `${fmtNum(v, 2)}m/s²`);
    if (!o) return null;
    return {
      text: `A force of ${F}N acts on a body of mass ${m}kg. Calculate the acceleration produced.`,
      ...o,
      explanation: `\\(a = \\frac{F}{m}\\)\n\n\\(= \\frac{${F}}{${m}} = ${a}\\)m/s²`,
    };
  },
  // momentum
  () => {
    const m = randInt(2, 50), v = randInt(2, 30);
    const p = m * v;
    const o = buildOptions(p, [m + v, round(m / v, 2), p / 2], (x) => `${fmtNum(x, 2)}kg m/s`);
    if (!o) return null;
    return {
      text: `Calculate the momentum of a body of mass ${m}kg moving with a velocity of ${v}m/s.`,
      ...o,
      explanation: `Momentum \\(p = mv\\)\n\n\\(= ${m} \\times ${v} = ${p}\\)kg m/s`,
    };
  },
  // impulse / change of momentum
  () => {
    const m = randInt(2, 30), u = randInt(0, 20), v = u + randInt(3, 25);
    const t = randInt(1, 10);
    const F = m * (v - u) / t;
    const o = buildOptions(round(F, 2), [round(m * v / t, 2), m * (v - u), round(F * 2, 2)], (x) => `${fmtNum(x, 2)}N`);
    if (!o) return null;
    return {
      text: `A body of mass ${m}kg changes its velocity from ${u}m/s to ${v}m/s in ${t} seconds. Calculate the force acting on it.`,
      ...o,
      explanation: `\\(F = \\frac{m(v - u)}{t}\\)\n\n\\(= \\frac{${m}(${v} - ${u})}{${t}} = \\frac{${m * (v - u)}}{${t}} = ${fmtNum(F, 2)}\\)N`,
    };
  },
  // conservation of momentum, perfectly inelastic
  () => {
    const m1 = randInt(1, 20), u1 = randInt(2, 25), m2 = randInt(1, 20);
    const v = m1 * u1 / (m1 + m2);
    const o = buildOptions(round(v, 2), [u1, round(m1 * u1, 2), round(v * 2, 2)], (x) => `${fmtNum(x, 2)}m/s`);
    if (!o) return null;
    return {
      text: `A body of mass ${m1}kg moving at ${u1}m/s collides with a stationary body of mass ${m2}kg and they move off together. Calculate their common velocity.`,
      ...o,
      explanation: `By conservation of momentum, total momentum before = total momentum after.\n\n\\(m_1u_1 = (m_1 + m_2)v\\)\n\n\\(${m1} \\times ${u1} = (${m1} + ${m2})v\\)\n\n\\(${m1 * u1} = ${m1 + m2}v\\), so \\(v = ${fmtNum(v, 2)}\\)m/s`,
    };
  },
  ...conceptGens("Newton's laws of motion", [
    'A body remains at rest or in uniform motion unless acted upon by an external force',
    'The rate of change of momentum of a body is proportional to the applied force',
    'Action and reaction are equal in magnitude and opposite in direction',
    'Action and reaction act on two different bodies',
    'The first law of motion is also known as the law of inertia',
    'Momentum is conserved in a closed system with no external forces',
  ], [
    'Action and reaction act on the same body and therefore cancel out',
    'A body in motion must have a force acting on it to keep it moving at constant velocity',
    'The second law states that force equals mass divided by acceleration',
    'Action is always greater than reaction',
    'Newton\'s first law applies only to bodies at rest',
    'Momentum is never conserved during a collision',
  ]),
];

// ================= ELASTIC PROPERTIES AND HOOKE'S LAW =================
const hooke = [
  // F = ke, find k
  () => {
    const k = randInt(5, 200), e = pick([0.02, 0.05, 0.1, 0.2, 0.25, 0.5]);
    const F = k * e;
    const o = buildOptions(k, [round(F * e, 3), round(e / F, 4), k + 10], (v) => `${fmtNum(v, 2)}N/m`);
    if (!o) return null;
    return {
      text: `A force of ${fmtNum(F, 2)}N produces an extension of ${e}m in a spring. Calculate the force constant of the spring.`,
      ...o,
      explanation: `By Hooke's law, \\(F = ke\\).\n\n\\(k = \\frac{F}{e} = \\frac{${fmtNum(F, 2)}}{${e}} = ${k}\\)N/m`,
    };
  },
  // find extension
  () => {
    const k = randInt(10, 200), e = pick([0.02, 0.04, 0.05, 0.1, 0.2]);
    const F = k * e;
    const o = buildOptions(e, [round(F * k, 2), round(F / (k * 2), 4), round(e * 2, 3)], (v) => `${fmtNum(v, 4)}m`);
    if (!o) return null;
    return {
      text: `A spring of force constant ${k}N/m is stretched by a force of ${fmtNum(F, 2)}N. Calculate the extension produced.`,
      ...o,
      explanation: `\\(e = \\frac{F}{k}\\)\n\n\\(= \\frac{${fmtNum(F, 2)}}{${k}} = ${fmtNum(e, 4)}\\)m`,
    };
  },
  // energy stored in a spring
  () => {
    const k = randInt(10, 200), e = pick([0.1, 0.2, 0.4, 0.5]);
    const E = 0.5 * k * e * e;
    const o = buildOptions(round(E, 3), [round(k * e * e, 3), round(0.5 * k * e, 3), round(E * 2, 3)], (v) => `${fmtNum(v, 3)}J`);
    if (!o) return null;
    return {
      text: `Calculate the energy stored in a spring of force constant ${k}N/m when it is stretched by ${e}m.`,
      ...o,
      explanation: `Energy stored \\(= \\frac{1}{2}ke^{2}\\)\n\n\\(= \\frac{1}{2} \\times ${k} \\times ${e}^{2} = ${fmtNum(E, 3)}\\)J`,
    };
  },
  // proportional extension
  () => {
    const e1 = randInt(2, 20), f1 = randInt(2, 30);
    const factor = randInt(2, 5);
    const correct = e1 * factor;
    const o = buildOptions(correct, [e1, e1 + factor, correct * 2], (v) => `${v}cm`);
    if (!o) return null;
    return {
      text: `A load of ${f1}N produces an extension of ${e1}cm in a spring. What extension will a load of ${f1 * factor}N produce, assuming the elastic limit is not exceeded?`,
      ...o,
      explanation: `Within the elastic limit, extension is directly proportional to the load.\n\nThe load has increased by a factor of ${factor}, so the extension also increases by ${factor}.\n\n\\(${e1} \\times ${factor} = ${correct}\\)cm`,
    };
  },
  ...conceptGens("Hooke's law and elasticity", [
    'Within the elastic limit, extension is directly proportional to the applied force',
    'The elastic limit is the maximum force beyond which a material no longer returns to its original shape',
    'The force constant of a spring is measured in newtons per metre',
    'A material that returns to its original shape when the load is removed is said to be elastic',
    'Beyond the elastic limit a material undergoes permanent deformation',
    'The energy stored in a stretched spring is given by half the product of the force constant and the square of the extension',
  ], [
    'Hooke\'s law holds for all values of applied force without limit',
    'The force constant is measured in joules',
    'Extension is inversely proportional to the applied force',
    'A material always returns to its original length no matter how large the load',
    'The elastic limit is the point at which a material breaks completely',
    'Energy stored in a spring is equal to the product of force and extension',
  ]),
];

// ================= CENTRE OF GRAVITY AND STABILITY =================
const centreGravity = [
  ...conceptGens('centre of gravity and stability', [
    'The centre of gravity is the point where the entire weight of a body appears to act',
    'A body is in stable equilibrium if it returns to its original position after a slight displacement',
    'A body is in unstable equilibrium if it moves further away after a slight displacement',
    'Lowering the centre of gravity increases the stability of a body',
    'A wide base increases the stability of a body',
    'For a uniform body the centre of gravity is at its geometric centre',
    'In neutral equilibrium the centre of gravity remains at the same height when the body is displaced',
  ], [
    'The centre of gravity must always lie inside the material of the body',
    'Raising the centre of gravity increases stability',
    'A narrow base makes a body more stable',
    'A body in unstable equilibrium returns to its original position when displaced',
    'The centre of gravity of a body depends on its temperature',
    'Stability is not affected by the position of the centre of gravity',
  ], [
    { q: 'Why are racing cars designed to be low and wide?', a: 'To lower the centre of gravity and widen the base, increasing stability', w: ['To raise the centre of gravity and reduce weight', 'To reduce the mass of the car', 'To increase friction with the air'], e: 'A low centre of gravity and a wide base both increase stability by making it harder for the line of action of the weight to fall outside the base.' },
    { q: 'Where is the centre of gravity of a uniform metre rule?', a: 'At the 50cm mark', w: ['At the 0cm mark', 'At the 100cm mark', 'At the 25cm mark'], e: 'For a uniform body the centre of gravity is at the geometric centre. For a metre rule this is the midpoint, the 50cm mark.' },
    { q: 'A cone resting on its curved side on a horizontal table is in which type of equilibrium?', a: 'Neutral equilibrium', w: ['Stable equilibrium', 'Unstable equilibrium', 'No equilibrium'], e: 'When rolled on its side, the height of the centre of gravity stays the same, which is the defining feature of neutral equilibrium.' },
    { q: 'Which of the following increases the stability of a body?', a: 'Increasing the area of its base', w: ['Raising its centre of gravity', 'Reducing the area of its base', 'Making the body taller'], e: 'A larger base area means the body can be tilted further before the line of action of its weight falls outside the base, so stability increases.' },
  ]),
  // balance point calculation
  () => {
    const m1 = randInt(2, 40), d1 = randInt(10, 45), m2 = randInt(2, 40);
    const d2 = m1 * d1 / m2;
    if (!Number.isInteger(d2) || d2 > 50) return null;
    const o = buildOptions(d2, [d1, round(m2 * d1 / m1, 2), d2 + 5], (v) => `${fmtNum(v, 2)}cm`);
    if (!o) return null;
    return {
      text: `A uniform metre rule is balanced at its centre. A mass of ${m1}g is placed ${d1}cm from the pivot. How far from the pivot on the other side must a mass of ${m2}g be placed to restore balance?`,
      ...o,
      explanation: `Taking moments about the pivot:\n\n\\(${m1} \\times ${d1} = ${m2} \\times d\\)\n\n\\(${m1 * d1} = ${m2}d\\)\n\n\\(d = ${d2}\\)cm`,
    };
  },
];

// ==================== NEWTON'S LAW OF GRAVITATION ====================
const gravitation = [
  // F = G m1 m2 / r^2
  () => {
    const m1 = randInt(1, 9) * 10, m2 = randInt(1, 9) * 10, r = randInt(1, 10);
    const F = BIG_G * m1 * m2 / (r * r);
    const o = buildOptions(F, [BIG_G * m1 * m2 / r, BIG_G * (m1 + m2) / (r * r), F * 2],
      (v) => `${v.toExponential(2)} N`);
    if (!o) return null;
    return {
      text: `Two masses of ${m1}kg and ${m2}kg are ${r}m apart. Calculate the gravitational force between them. [Take \\(G = 6.67 \\times 10^{-11}\\) Nm²/kg²]`,
      ...o,
      explanation: `\\(F = \\frac{Gm_1m_2}{r^{2}}\\)\n\n\\(= \\frac{6.67 \\times 10^{-11} \\times ${m1} \\times ${m2}}{${r}^{2}}\\)\n\n\\(= ${F.toExponential(2)}\\) N`,
    };
  },
  // inverse square reasoning
  () => {
    const factor = randInt(2, 5);
    const correct = frac(1, factor * factor);
    const o = buildOptions(correct, [frac(1, factor), frac(factor * factor, 1), frac(factor, 1)], (f) => fracOpt(f));
    if (!o) return null;
    return {
      text: `If the distance between two masses is increased by a factor of ${factor}, by what factor does the gravitational force between them change?`,
      ...o,
      explanation: `Gravitational force obeys an inverse square law: \\(F \\propto \\frac{1}{r^{2}}\\).\n\nIncreasing \\(r\\) by a factor of ${factor} multiplies \\(r^{2}\\) by \\(${factor}^{2} = ${factor * factor}\\).\n\nSo the force becomes \\(${fracTex(correct)}\\) of its original value.`,
    };
  },
  // weight from g
  () => {
    const m = randInt(2, 90);
    const W = m * G;
    const o = buildOptions(W, [m, round(m / G, 2), W * 2], (v) => `${fmtNum(v, 2)}N`);
    if (!o) return null;
    return {
      text: `Calculate the weight of a body of mass ${m}kg on the Earth's surface. [Take \\(g = 10\\)m/s²]`,
      ...o,
      explanation: `\\(W = mg\\)\n\n\\(= ${m} \\times 10 = ${W}\\)N`,
    };
  },
  ...conceptGens('Newton\'s law of gravitation', [
    'The gravitational force between two masses is proportional to the product of the masses',
    'The gravitational force between two masses is inversely proportional to the square of their separation',
    'Gravitational force is always attractive',
    'The universal gravitational constant has the same value everywhere',
    'The gravitational force acts along the line joining the two masses',
  ], [
    'Gravitational force can be either attractive or repulsive',
    'The gravitational force is inversely proportional to the separation of the masses',
    'The universal gravitational constant varies from place to place on the Earth',
    'Gravitational force depends on the medium between the two masses',
    'The gravitational force is proportional to the square of the separation',
  ]),
];

// ================= GRAVITATIONAL FIELD AND POTENTIAL =================
const gravField = [
  // g = F/m
  () => {
    const g = pick([9.8, 10, 1.6, 3.7, 24.8]);
    const m = randInt(2, 60);
    const F = g * m;
    const o = buildOptions(g, [round(F * m, 2), round(m / F, 3), round(g + 2, 2)], (v) => `${fmtNum(v, 2)}N/kg`);
    if (!o) return null;
    return {
      text: `A body of mass ${m}kg experiences a gravitational force of ${fmtNum(F, 2)}N. Calculate the gravitational field strength at that point.`,
      ...o,
      explanation: `Gravitational field strength \\(g = \\frac{F}{m}\\)\n\n\\(= \\frac{${fmtNum(F, 2)}}{${m}} = ${fmtNum(g, 2)}\\)N/kg`,
    };
  },
  // variation of g with height
  () => {
    const factor = randInt(2, 4);
    const correct = frac(1, factor * factor);
    const o = buildOptions(correct, [frac(1, factor), frac(factor, 1), frac(factor * factor, 1)], (f) => fracOpt(f));
    if (!o) return null;
    return {
      text: `At a distance of ${factor} Earth-radii from the centre of the Earth, the gravitational field strength is what fraction of its value at the Earth's surface?`,
      ...o,
      explanation: `\\(g = \\frac{GM}{r^{2}}\\), so \\(g \\propto \\frac{1}{r^{2}}\\).\n\nAt ${factor} times the radius, \\(g\\) is reduced by a factor of \\(${factor}^{2} = ${factor * factor}\\).\n\nSo it is \\(${fracTex(correct)}\\) of the surface value.`,
    };
  },
  ...conceptGens('gravitational field and potential', [
    'Gravitational field strength is the force per unit mass at a point in the field',
    'Gravitational field strength is measured in newtons per kilogram',
    'Gravitational potential at a point is the work done per unit mass in bringing a mass from infinity to that point',
    'Gravitational potential is always negative',
    'Gravitational field strength decreases with the square of the distance from the centre of a planet',
    'Gravitational field strength is a vector quantity',
  ], [
    'Gravitational field strength is measured in joules per kilogram',
    'Gravitational potential is always positive',
    'Gravitational field strength increases with distance from a planet',
    'Gravitational potential is a vector quantity',
    'Gravitational field strength is the same at all points around a planet regardless of distance',
    'Gravitational potential energy is independent of the mass of the body',
  ]),
];

// ======================= SATELLITES AND ROCKETS =======================
const satellites = [
  // orbital speed
  () => {
    const r = randInt(7, 42) * 1e6;
    const g = pick([8, 9, 10]);
    const v = Math.sqrt(g * r);
    const o = buildOptions(round(v, 0), [round(g * r, 0), round(Math.sqrt(g / r), 4), round(v * 2, 0)],
      (x) => `${Number(x).toExponential(2)} m/s`);
    if (!o) return null;
    return {
      text: `A satellite orbits a planet at a radius of ${(r / 1e6).toFixed(0)} \\(\\times 10^{6}\\)m where the gravitational field strength is ${g}m/s². Calculate its orbital speed.`,
      ...o,
      explanation: `For a circular orbit the gravitational force provides the centripetal force.\n\n\\(\\frac{mv^{2}}{r} = mg \\Rightarrow v = \\sqrt{gr}\\)\n\n\\(v = \\sqrt{${g} \\times ${r.toExponential(1)}} = ${v.toExponential(2)}\\) m/s`,
    };
  },
  ...conceptGens('satellites and rockets', [
    'A geostationary satellite has a period of 24 hours',
    'A geostationary satellite orbits directly above the equator',
    'Escape velocity is the minimum velocity needed to escape a planet\'s gravitational field',
    'For a satellite in orbit, gravitational force provides the centripetal force',
    'A satellite in orbit is in a continuous state of free fall towards the Earth',
    'The escape velocity from the Earth is about 11.2km/s',
    'Rockets work on the principle of conservation of momentum',
  ], [
    'A geostationary satellite has a period of 12 hours',
    'A geostationary satellite can orbit above any latitude',
    'Escape velocity depends on the mass of the escaping body',
    'A satellite in orbit experiences no gravitational force',
    'Rockets need air to push against in order to move forward',
    'The orbital speed of a satellite is independent of the orbital radius',
  ], [
    { q: 'Why does an astronaut in an orbiting spacecraft appear weightless?', a: 'The astronaut and spacecraft are both in free fall with the same acceleration', w: ['There is no gravity in space', 'The spacecraft is beyond the Earth\'s gravitational field', 'The astronaut has no mass in space'], e: 'Gravity still acts on the astronaut. Both the astronaut and the spacecraft accelerate towards the Earth at the same rate, so there is no normal reaction between them, which produces the sensation of weightlessness.' },
    { q: 'On what principle does the motion of a rocket depend?', a: 'Conservation of linear momentum', w: ['Conservation of mass', 'Archimedes\' principle', 'Hooke\'s law'], e: 'Exhaust gases are expelled backwards with momentum, and by conservation of momentum the rocket gains an equal and opposite momentum forwards.' },
  ]),
];

// =========================== WORK AND ENERGY ===========================
const workEnergy = [
  // W = Fd
  () => {
    const F = randInt(5, 200), d = randInt(2, 40);
    const W = F * d;
    const o = buildOptions(W, [F + d, round(F / d, 2), W / 2], (v) => `${fmtNum(v, 2)}J`);
    if (!o) return null;
    return {
      text: `Calculate the work done when a force of ${F}N moves a body through a distance of ${d}m in the direction of the force.`,
      ...o,
      explanation: `Work done \\(= F \\times d\\)\n\n\\(= ${F} \\times ${d} = ${W}\\)J`,
    };
  },
  // W = Fd cos theta
  () => {
    const F = randInt(10, 150), d = randInt(2, 30), ang = pick([0, 30, 60, 90]);
    const W = F * d * Math.cos(ang * Math.PI / 180);
    const o = buildOptions(round(W, 2), [F * d, round(F * d * Math.sin(ang * Math.PI / 180), 2), round(W / 2, 2)],
      (v) => `${fmtNum(v, 2)}J`);
    if (!o) return null;
    return {
      text: `A force of ${F}N acts at ${ang}° to the direction of motion and moves a body ${d}m. Calculate the work done.`,
      ...o,
      explanation: `\\(W = Fd\\cos\\theta\\)\n\n\\(= ${F} \\times ${d} \\times \\cos ${ang}° = ${fmtNum(W, 2)}\\)J`,
    };
  },
  // work done against gravity
  () => {
    const m = randInt(2, 60), h = randInt(2, 30);
    const W = m * G * h;
    const o = buildOptions(W, [m * h, round(m * G, 2), W * 2], (v) => `${fmtNum(v, 2)}J`);
    if (!o) return null;
    return {
      text: `Calculate the work done in lifting a body of mass ${m}kg through a vertical height of ${h}m. [Take \\(g = 10\\)m/s²]`,
      ...o,
      explanation: `Work done against gravity \\(= mgh\\)\n\n\\(= ${m} \\times 10 \\times ${h} = ${W}\\)J`,
    };
  },
  ...conceptGens('work and energy', [
    'Work is done only when a force produces motion in the direction of the force',
    'Work and energy have the same unit, the joule',
    'No work is done when a force acts at right angles to the direction of motion',
    'Work is a scalar quantity',
    'Energy is the capacity to do work',
    'One joule is the work done when a force of one newton moves a body one metre in the direction of the force',
  ], [
    'Work is a vector quantity',
    'Work is done whenever a force is applied, even if the body does not move',
    'The unit of work is the newton',
    'Maximum work is done when the force is perpendicular to the displacement',
    'Energy and power have the same unit',
    'Work done is independent of the distance moved',
  ]),
];

// ==================== KINETIC AND POTENTIAL ENERGY ====================
const kinPot = [
  // KE
  () => {
    const m = randInt(1, 50), v = 2 * randInt(1, 15);
    const KE = 0.5 * m * v * v;
    const o = buildOptions(KE, [m * v * v, 0.5 * m * v, KE * 2], (x) => `${fmtNum(x, 2)}J`);
    if (!o) return null;
    return {
      text: `Calculate the kinetic energy of a body of mass ${m}kg moving with a velocity of ${v}m/s.`,
      ...o,
      explanation: `\\(KE = \\frac{1}{2}mv^{2}\\)\n\n\\(= \\frac{1}{2} \\times ${m} \\times ${v}^{2} = \\frac{1}{2} \\times ${m} \\times ${v * v} = ${KE}\\)J`,
    };
  },
  // PE
  () => {
    const m = randInt(1, 60), h = randInt(2, 40);
    const PE = m * G * h;
    const o = buildOptions(PE, [m * h, m * G, PE / 2], (x) => `${fmtNum(x, 2)}J`);
    if (!o) return null;
    return {
      text: `Calculate the potential energy of a body of mass ${m}kg at a height of ${h}m above the ground. [Take \\(g = 10\\)m/s²]`,
      ...o,
      explanation: `\\(PE = mgh\\)\n\n\\(= ${m} \\times 10 \\times ${h} = ${PE}\\)J`,
    };
  },
  // velocity from KE
  () => {
    const m = randInt(1, 30), v = 2 * randInt(1, 12);
    const KE = 0.5 * m * v * v;
    const o = buildOptions(v, [round(KE / m, 2), round(Math.sqrt(KE / m), 2), v + 3], (x) => `${fmtNum(x, 2)}m/s`);
    if (!o) return null;
    return {
      text: `A body of mass ${m}kg has kinetic energy ${fmtNum(KE, 2)}J. Calculate its velocity.`,
      ...o,
      explanation: `\\(KE = \\frac{1}{2}mv^{2}\\)\n\n\\(${fmtNum(KE, 2)} = \\frac{1}{2} \\times ${m} \\times v^{2}\\)\n\n\\(v^{2} = ${v * v}\\), so \\(v = ${v}\\)m/s`,
    };
  },
  // falling body: speed on landing
  () => {
    const h = 5 * randInt(1, 20);
    const v = Math.sqrt(2 * G * h);
    const correct = round(v, 2);
    const o = buildOptions(correct, [round(2 * G * h, 2), round(G * h, 2), round(v * 2, 2)], (x) => `${fmtNum(x, 2)}m/s`);
    if (!o) return null;
    return {
      text: `A body falls freely from a height of ${h}m. Calculate its velocity just before hitting the ground. [Take \\(g = 10\\)m/s²]`,
      ...o,
      explanation: `Using conservation of energy, \\(mgh = \\frac{1}{2}mv^{2}\\).\n\n\\(v = \\sqrt{2gh} = \\sqrt{2 \\times 10 \\times ${h}} = \\sqrt{${2 * G * h}} = ${fmtNum(correct, 2)}\\)m/s`,
    };
  },
];

// ========================= POWER AND MACHINES =========================
const powerMachines = [
  // P = W/t
  () => {
    const W = randInt(10, 100) * 10, t = randInt(2, 40);
    const P = W / t;
    const o = buildOptions(round(P, 2), [W * t, round(t / W, 4), round(P * 2, 2)], (v) => `${fmtNum(v, 2)}W`);
    if (!o) return null;
    return {
      text: `Calculate the power developed when ${W}J of work is done in ${t} seconds.`,
      ...o,
      explanation: `\\(P = \\frac{W}{t}\\)\n\n\\(= \\frac{${W}}{${t}} = ${fmtNum(P, 2)}\\)W`,
    };
  },
  // power lifting a load
  () => {
    const m = randInt(2, 60), h = randInt(2, 20), t = randInt(2, 15);
    const P = m * G * h / t;
    const o = buildOptions(round(P, 2), [m * G * h, round(m * h / t, 2), round(P * 2, 2)], (v) => `${fmtNum(v, 2)}W`);
    if (!o) return null;
    return {
      text: `A crane lifts a load of mass ${m}kg through a height of ${h}m in ${t} seconds. Calculate the power developed. [Take \\(g = 10\\)m/s²]`,
      ...o,
      explanation: `Work done \\(= mgh = ${m} \\times 10 \\times ${h} = ${m * G * h}\\)J\n\n\\(P = \\frac{W}{t} = \\frac{${m * G * h}}{${t}} = ${fmtNum(P, 2)}\\)W`,
    };
  },
  // mechanical advantage
  () => {
    const effort = randInt(5, 60), ma = randInt(2, 8);
    const load = effort * ma;
    const o = buildOptions(ma, [round(effort / load, 3), load, ma + 2], (v) => fmtNum(v, 2));
    if (!o) return null;
    return {
      text: `A machine lifts a load of ${load}N using an effort of ${effort}N. Calculate its mechanical advantage.`,
      ...o,
      explanation: `\\(MA = \\frac{\\text{load}}{\\text{effort}}\\)\n\n\\(= \\frac{${load}}{${effort}} = ${ma}\\)`,
    };
  },
  // efficiency
  () => {
    const ma = randInt(2, 8), vr = ma + randInt(1, 5);
    const eff = ma / vr * 100;
    const o = buildOptions(round(eff, 2), [round(vr / ma * 100, 2), round(ma * vr, 2), round(eff / 2, 2)], (v) => `${fmtNum(v, 2)}%`);
    if (!o) return null;
    return {
      text: `A machine has a mechanical advantage of ${ma} and a velocity ratio of ${vr}. Calculate its efficiency.`,
      ...o,
      explanation: `Efficiency \\(= \\frac{MA}{VR} \\times 100\\%\\)\n\n\\(= \\frac{${ma}}{${vr}} \\times 100\\% = ${fmtNum(eff, 2)}\\%\\)`,
    };
  },
  // power from force and velocity
  () => {
    const F = randInt(10, 200), v = randInt(2, 30);
    const P = F * v;
    const o = buildOptions(P, [round(F / v, 2), F + v, P / 2], (x) => `${fmtNum(x, 2)}W`);
    if (!o) return null;
    return {
      text: `A car engine exerts a force of ${F}N while moving at a constant velocity of ${v}m/s. Calculate the power developed.`,
      ...o,
      explanation: `\\(P = Fv\\)\n\n\\(= ${F} \\times ${v} = ${P}\\)W`,
    };
  },
  ...conceptGens('machines and efficiency', [
    'The efficiency of a machine is always less than 100 per cent in practice',
    'Mechanical advantage is the ratio of load to effort',
    'Velocity ratio is the ratio of the distance moved by the effort to the distance moved by the load',
    'Friction in a machine reduces its efficiency',
    'Efficiency is the ratio of useful work output to total work input, expressed as a percentage',
    'Power is the rate of doing work',
  ], [
    'A machine can have an efficiency greater than 100 per cent',
    'Mechanical advantage is the ratio of effort to load',
    'Efficiency is measured in watts',
    'A perfect machine can create energy',
    'Power is the total work done regardless of time',
    'Friction increases the efficiency of a machine',
  ]),
];

// ====================== CONSERVATION OF ENERGY ======================
const conservation = [
  // energy at a point during a fall
  () => {
    const m = randInt(1, 20), H = 5 * randInt(2, 12);
    const totalE = m * G * H;
    const o = buildOptions(totalE, [m * H, round(0.5 * m * H, 2), totalE / 2], (v) => `${fmtNum(v, 2)}J`);
    if (!o) return null;
    return {
      text: `A body of mass ${m}kg is released from a height of ${H}m. What is its total mechanical energy just before it hits the ground? [Take \\(g = 10\\)m/s²]`,
      ...o,
      explanation: `Total mechanical energy is conserved during free fall.\n\nAt the top it is all potential: \\(PE = mgh = ${m} \\times 10 \\times ${H} = ${totalE}\\)J\n\nJust before landing this has all become kinetic energy, so the total is still ${totalE}J.`,
    };
  },
  // KE at half the height
  () => {
    const m = randInt(1, 20), H = 10 * randInt(1, 10);
    const ke = m * G * (H / 2);
    const o = buildOptions(ke, [m * G * H, round(ke / 2, 2), ke * 2], (v) => `${fmtNum(v, 2)}J`);
    if (!o) return null;
    return {
      text: `A body of mass ${m}kg falls from rest through a height of ${H}m. Calculate its kinetic energy after falling half the distance. [Take \\(g = 10\\)m/s²]`,
      ...o,
      explanation: `After falling \\(\\frac{${H}}{2} = ${H / 2}\\)m, the loss in potential energy equals the gain in kinetic energy.\n\n\\(KE = mg \\times ${H / 2} = ${m} \\times 10 \\times ${H / 2} = ${ke}\\)J`,
    };
  },
  ...conceptGens('the conservation of energy', [
    'Energy can neither be created nor destroyed, only converted from one form to another',
    'The total energy of an isolated system remains constant',
    'In a freely falling body, potential energy is converted into kinetic energy',
    'In a simple pendulum, energy is continuously converted between kinetic and potential forms',
    'A hydroelectric power station converts potential energy into electrical energy',
    'In the presence of friction, some mechanical energy is converted into heat',
  ], [
    'Energy can be created in a nuclear reactor from nothing',
    'The total energy of an isolated system steadily decreases',
    'A freely falling body loses energy overall',
    'Friction destroys energy completely',
    'Kinetic energy is always conserved in every type of collision',
    'Energy conversion devices can output more energy than they receive',
  ], [
    { q: 'What energy conversion takes place in an electric motor?', a: 'Electrical energy to mechanical energy', w: ['Mechanical energy to electrical energy', 'Chemical energy to electrical energy', 'Heat energy to light energy'], e: 'An electric motor takes in electrical energy and produces rotational mechanical energy.' },
    { q: 'What energy conversion takes place in a battery during discharge?', a: 'Chemical energy to electrical energy', w: ['Electrical energy to chemical energy', 'Mechanical energy to electrical energy', 'Light energy to chemical energy'], e: 'Chemical reactions inside the cell release energy that drives charge round the circuit as electrical energy.' },
    { q: 'What energy conversion takes place in a generator?', a: 'Mechanical energy to electrical energy', w: ['Electrical energy to mechanical energy', 'Chemical energy to heat energy', 'Sound energy to electrical energy'], e: 'A generator is rotated mechanically and induces an emf, converting mechanical energy into electrical energy.' },
    { q: 'What is the main energy conversion in a solar panel?', a: 'Solar (light) energy to electrical energy', w: ['Electrical energy to light energy', 'Heat energy to mechanical energy', 'Chemical energy to light energy'], e: 'Photovoltaic cells convert the energy of incident light directly into electrical energy.' },
  ]),
];

module.exports = [
  { topicId: 'WGxZNRBM3aZ8UOAuUqcA', unitId: U_FORCE, topicName: 'Friction', generators: friction },
  { topicId: 'uqjFLPvSHNyoggvcxbaW', unitId: U_FORCE, topicName: 'Equilibrium of Forces and Moments', generators: equilibrium },
  { topicId: 'LgfLQcqZzq5tYywVaAyM', unitId: U_FORCE, topicName: 'Newtons Laws of Motion', generators: newtonLaws },
  { topicId: 'nauJunIK5dePdLyeA0Rp', unitId: U_FORCE, topicName: 'Elastic Properties and Hookes Law', generators: hooke },
  { topicId: 'TkeMZYVXnvoK3TN4t4GM', unitId: U_FORCE, topicName: 'Centre of Gravity and Stability', generators: centreGravity },
  { topicId: 'D0jUWfRtpZzevzbhNPxo', unitId: U_GRAV, topicName: 'Newtons Law of Gravitation', generators: gravitation },
  { topicId: '8G7G6xd12Ng8cNwRlgRv', unitId: U_GRAV, topicName: 'Gravitational Field and Potential', generators: gravField },
  { topicId: 'Btzo1vUCmvIg6xSMoaix', unitId: U_GRAV, topicName: 'Satellites and Rockets', generators: satellites },
  { topicId: 'F1IMq15bBe8WNHw19m5J', unitId: U_WEP, topicName: 'Work and Energy', generators: workEnergy },
  { topicId: 'bs23sKIqhU1UoGzRcNMj', unitId: U_WEP, topicName: 'Power and Machines', generators: powerMachines },
  { topicId: '5yEJ08gJ3LZ7eVQD4Cm9', unitId: U_WEP, topicName: 'Kinetic and Potential Energy', generators: kinPot },
  { topicId: '0Wu6PzB8Lh9CMN9qtTay', unitId: U_WEP, topicName: 'Conservation of Energy', generators: conservation },
];
