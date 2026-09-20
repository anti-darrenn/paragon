// Physics > Electrostatics, Current Electricity, Magnetism, Atomic and Nuclear
const L = require('./lib');
const { randInt, pick, shuffle, sample, nonZero, gcd, frac, fracTex, fracOpt,
        fmtNum, buildOptions, textOptions, round } = L;
const { conceptGens, qaBank } = require('./concept');

const U_ESTAT = 'zn0zbfhRsA8ciYteI5Pf';
const U_CURR = 'QwVTcH1S7AJ1IdPxOf0H';
const U_MAG = 'DRFFedBq5eTzP49Zpnqx';
const U_ATOM = 'EDW0h2f52hAUrbElsiQj';

const K_E = 9e9;
const E_CHG = 1.6e-19;
const H_PL = 6.63e-34;

// ============================ COULOMB'S LAW ============================
const coulomb = [
  // F = k q1 q2 / r^2
  () => {
    const q1 = randInt(1, 9), q2 = randInt(1, 9), r = randInt(1, 10);
    const Q1 = q1 * 1e-6, Q2 = q2 * 1e-6;
    const F = K_E * Q1 * Q2 / (r * r);
    const o = buildOptions(F, [K_E * Q1 * Q2 / r, K_E * (Q1 + Q2) / (r * r), F * 2],
      (v) => `${Number(v).toExponential(2)} N`);
    if (!o) return null;
    return {
      text: `Two point charges of ${q1}μC and ${q2}μC are placed ${r}m apart in air. Calculate the force between them. [Take \\(k = 9 \\times 10^{9}\\) Nm²/C²]`,
      ...o,
      explanation: `\\(F = \\frac{kq_1q_2}{r^{2}}\\)\n\n\\(= \\frac{9 \\times 10^{9} \\times ${q1} \\times 10^{-6} \\times ${q2} \\times 10^{-6}}{${r}^{2}}\\)\n\n\\(= ${F.toExponential(2)}\\) N`,
    };
  },
  // inverse square reasoning
  () => {
    const factor = randInt(2, 5);
    const correct = frac(1, factor * factor);
    const o = buildOptions(correct, [frac(1, factor), frac(factor * factor, 1), frac(factor, 1)], (f) => fracOpt(f));
    if (!o) return null;
    return {
      text: `If the distance between two point charges is increased ${factor} times, the force between them becomes what fraction of its original value?`,
      ...o,
      explanation: `Coulomb's law is an inverse square law: \\(F \\propto \\frac{1}{r^{2}}\\).\n\nIncreasing \\(r\\) by a factor of ${factor} multiplies \\(r^{2}\\) by ${factor * factor}.\n\nSo the force becomes \\(${fracTex(correct)}\\) of its original value.`,
    };
  },
  // doubling one charge
  () => {
    const factor = randInt(2, 5);
    const o = buildOptions(factor, [factor * factor, round(1 / factor, 3), factor + 1], (v) => `${v} times`);
    if (!o) return null;
    return {
      text: `If one of two point charges is increased ${factor} times while the separation remains constant, what happens to the force between them?`,
      ...o,
      explanation: `\\(F \\propto q_1q_2\\), so the force is directly proportional to each charge.\n\nMultiplying one charge by ${factor} multiplies the force by ${factor}.`,
    };
  },
  ...conceptGens("Coulomb's law", [
    'The force between two point charges is proportional to the product of the charges',
    'The force between two point charges is inversely proportional to the square of their separation',
    'Like charges repel while unlike charges attract',
    'The force acts along the line joining the two charges',
    'Coulomb\'s law applies strictly to point charges',
    'The force between charges depends on the medium between them',
  ], [
    'The force between two point charges is inversely proportional to their separation',
    'Like charges attract while unlike charges repel',
    'Coulomb force is always attractive',
    'The force between charges is independent of the medium separating them',
    'The force is proportional to the square of the separation',
    'Coulomb\'s law applies only to neutral bodies',
  ]),
];

// ====================== ELECTRIC CHARGES AND FIELDS ======================
const chargesFields = [
  // E = F/q
  () => {
    const q = randInt(1, 9), F = randInt(2, 90);
    const Q = q * 1e-6;
    const E = F / Q;
    const o = buildOptions(E, [F * Q, round(Q / F, 10), E * 2], (v) => `${Number(v).toExponential(2)} N/C`);
    if (!o) return null;
    return {
      text: `A charge of ${q}μC experiences a force of ${F}N in an electric field. Calculate the electric field intensity.`,
      ...o,
      explanation: `\\(E = \\frac{F}{q}\\)\n\n\\(= \\frac{${F}}{${q} \\times 10^{-6}} = ${E.toExponential(2)}\\) N/C`,
    };
  },
  // F = qE
  () => {
    const q = randInt(1, 9), E = randInt(1, 9) * 1000;
    const Q = q * 1e-6;
    const F = Q * E;
    const o = buildOptions(F, [round(E / Q, 2), round(Q / E, 12), F * 2], (v) => `${Number(v).toExponential(2)} N`);
    if (!o) return null;
    return {
      text: `Calculate the force on a charge of ${q}μC placed in an electric field of intensity ${E}N/C.`,
      ...o,
      explanation: `\\(F = qE\\)\n\n\\(= ${q} \\times 10^{-6} \\times ${E} = ${F.toExponential(2)}\\) N`,
    };
  },
  // number of electrons in a charge
  () => {
    const q = randInt(1, 9);
    const Q = q * 1e-6;
    const n = Q / E_CHG;
    const o = buildOptions(n, [Q * E_CHG, round(E_CHG / Q, 15), n * 2], (v) => `${Number(v).toExponential(2)}`);
    if (!o) return null;
    return {
      text: `How many electrons make up a charge of ${q}μC? [Charge on an electron = \\(1.6 \\times 10^{-19}\\)C]`,
      ...o,
      explanation: `\\(n = \\frac{Q}{e}\\)\n\n\\(= \\frac{${q} \\times 10^{-6}}{1.6 \\times 10^{-19}} = ${n.toExponential(2)}\\) electrons`,
    };
  },
  ...conceptGens('electric charges and fields', [
    'Like charges repel and unlike charges attract',
    'Electric field intensity is the force per unit positive charge at a point',
    'Electric field lines start on positive charges and end on negative charges',
    'Electric field lines never cross one another',
    'The electric field inside a hollow conductor in equilibrium is zero',
    'Charge is quantised, existing in multiples of the electronic charge',
    'Charge is conserved in any isolated system',
    'Electric field intensity is a vector quantity',
  ], [
    'Electric field lines can cross one another',
    'Electric field lines start on negative charges and end on positive charges',
    'Electric field intensity is a scalar quantity',
    'The electric field inside a hollow charged conductor is very large',
    'Charge can take any continuous value, however small',
    'Like charges attract one another',
  ]),
];

// ============== ELECTRIC POTENTIAL AND CAPACITANCE ==============
const capacitance = [
  // C = Q/V
  () => {
    const C = pick([2, 4, 5, 10, 20, 50]);
    const V = randInt(2, 40);
    const Q = C * 1e-6 * V;
    const o = buildOptions(Q, [C * V, round(C / V, 4), Q * 2], (v) => `${Number(v).toExponential(2)} C`);
    if (!o) return null;
    return {
      text: `Calculate the charge stored on a ${C}μF capacitor connected across a ${V}V supply.`,
      ...o,
      explanation: `\\(Q = CV\\)\n\n\\(= ${C} \\times 10^{-6} \\times ${V} = ${Q.toExponential(2)}\\) C`,
    };
  },
  // energy stored
  () => {
    const C = pick([2, 4, 5, 10, 20]);
    const V = pick([10, 20, 50, 100]);
    const E = 0.5 * C * 1e-6 * V * V;
    const o = buildOptions(E, [C * 1e-6 * V * V, round(0.5 * C * 1e-6 * V, 8), E * 2],
      (v) => `${Number(v).toExponential(2)} J`);
    if (!o) return null;
    return {
      text: `Calculate the energy stored in a ${C}μF capacitor charged to ${V}V.`,
      ...o,
      explanation: `\\(E = \\frac{1}{2}CV^{2}\\)\n\n\\(= \\frac{1}{2} \\times ${C} \\times 10^{-6} \\times ${V}^{2} = ${E.toExponential(2)}\\) J`,
    };
  },
  // capacitors in parallel
  () => {
    const c1 = randInt(1, 20), c2 = randInt(1, 20);
    const total = c1 + c2;
    const series = c1 * c2 / (c1 + c2);
    const o = buildOptions(total, [round(series, 3), c1 * c2, round(total / 2, 2)], (v) => `${fmtNum(v, 2)}μF`);
    if (!o) return null;
    return {
      text: `Two capacitors of ${c1}μF and ${c2}μF are connected in parallel. Calculate their effective capacitance.`,
      ...o,
      explanation: `For capacitors in parallel the capacitances simply add.\n\n\\(C = C_1 + C_2 = ${c1} + ${c2} = ${total}\\)μF`,
    };
  },
  // capacitors in series
  () => {
    const c1 = randInt(1, 20), c2 = randInt(1, 20);
    const series = c1 * c2 / (c1 + c2);
    const o = buildOptions(round(series, 3), [c1 + c2, c1 * c2, round(series * 2, 3)], (v) => `${fmtNum(v, 3)}μF`);
    if (!o) return null;
    return {
      text: `Two capacitors of ${c1}μF and ${c2}μF are connected in series. Calculate their effective capacitance.`,
      ...o,
      explanation: `For capacitors in series, \\(\\frac{1}{C} = \\frac{1}{C_1} + \\frac{1}{C_2}\\).\n\n\\(C = \\frac{C_1C_2}{C_1 + C_2} = \\frac{${c1} \\times ${c2}}{${c1 + c2}} = ${fmtNum(series, 3)}\\)μF`,
    };
  },
  ...conceptGens('capacitance', [
    'Capacitance is the ratio of charge stored to the potential difference across a capacitor',
    'The SI unit of capacitance is the farad',
    'Capacitors in parallel have their capacitances added directly',
    'For capacitors in series the reciprocal of the total capacitance is the sum of the reciprocals',
    'The energy stored in a capacitor is half the product of the capacitance and the square of the voltage',
    'A dielectric between the plates increases the capacitance',
    'Capacitance increases as the plate area increases',
  ], [
    'The SI unit of capacitance is the coulomb',
    'Capacitors in series have their capacitances added directly',
    'Capacitance decreases when the plate area increases',
    'Inserting a dielectric decreases the capacitance',
    'Capacitance is the product of charge and voltage',
    'A capacitor stores current rather than charge',
  ]),
];

// ======================= OHM'S LAW AND RESISTANCE =======================
const ohmsLaw = [
  // V = IR
  () => {
    const I = randInt(1, 20), R = randInt(2, 60);
    const V = I * R;
    const o = buildOptions(V, [round(I / R, 3), I + R, V * 2], (v) => `${fmtNum(v, 2)}V`);
    if (!o) return null;
    return {
      text: `A current of ${I}A flows through a resistor of ${R}Ω. Calculate the potential difference across it.`,
      ...o,
      explanation: `\\(V = IR\\)\n\n\\(= ${I} \\times ${R} = ${V}\\)V`,
    };
  },
  // find current
  () => {
    const R = randInt(2, 50), I = randInt(1, 15);
    const V = I * R;
    const o = buildOptions(I, [V * R, round(R / V, 4), I * 2], (v) => `${fmtNum(v, 2)}A`);
    if (!o) return null;
    return {
      text: `Calculate the current flowing through a ${R}Ω resistor when a potential difference of ${V}V is applied across it.`,
      ...o,
      explanation: `\\(I = \\frac{V}{R}\\)\n\n\\(= \\frac{${V}}{${R}} = ${I}\\)A`,
    };
  },
  // resistors in series
  () => {
    const r1 = randInt(1, 40), r2 = randInt(1, 40), r3 = randInt(1, 40);
    const total = r1 + r2 + r3;
    const o = buildOptions(total, [round(1 / (1 / r1 + 1 / r2 + 1 / r3), 2), r1 * r2 * r3, round(total / 2, 2)], (v) => `${fmtNum(v, 2)}Ω`);
    if (!o) return null;
    return {
      text: `Three resistors of ${r1}Ω, ${r2}Ω and ${r3}Ω are connected in series. Calculate the effective resistance.`,
      ...o,
      explanation: `In series the resistances add.\n\n\\(R = ${r1} + ${r2} + ${r3} = ${total}\\)Ω`,
    };
  },
  // resistors in parallel
  () => {
    const r1 = randInt(1, 30), r2 = randInt(1, 30);
    const par = r1 * r2 / (r1 + r2);
    const o = buildOptions(round(par, 3), [r1 + r2, r1 * r2, round(par * 2, 3)], (v) => `${fmtNum(v, 3)}Ω`);
    if (!o) return null;
    return {
      text: `Two resistors of ${r1}Ω and ${r2}Ω are connected in parallel. Calculate the effective resistance.`,
      ...o,
      explanation: `\\(\\frac{1}{R} = \\frac{1}{R_1} + \\frac{1}{R_2}\\)\n\n\\(R = \\frac{R_1R_2}{R_1 + R_2} = \\frac{${r1} \\times ${r2}}{${r1 + r2}} = ${fmtNum(par, 3)}\\)Ω`,
    };
  },
  ...conceptGens("Ohm's law and resistance", [
    'Ohm\'s law states that current is directly proportional to potential difference at constant temperature',
    'The SI unit of resistance is the ohm',
    'Resistances in series simply add together',
    'The total resistance of resistors in parallel is less than the smallest individual resistance',
    'The resistance of a metallic conductor increases with temperature',
    'A conductor obeying Ohm\'s law gives a straight-line graph of V against I through the origin',
  ], [
    'Ohm\'s law states that current is inversely proportional to potential difference',
    'The SI unit of resistance is the volt',
    'Resistances in parallel simply add together',
    'The total resistance of resistors in parallel is greater than the largest individual resistance',
    'The resistance of a pure metal decreases as temperature rises',
    'Ohm\'s law holds at all temperatures without restriction',
  ]),
];

// =================== ELECTRIC CURRENT AND CIRCUITS ===================
const currentCircuits = [
  // I = Q/t
  () => {
    const I = randInt(1, 20), t = randInt(2, 120);
    const Q = I * t;
    const o = buildOptions(Q, [round(I / t, 4), I + t, Q * 2], (v) => `${fmtNum(v, 2)}C`);
    if (!o) return null;
    return {
      text: `A steady current of ${I}A flows for ${t} seconds. Calculate the quantity of charge that passes.`,
      ...o,
      explanation: `\\(Q = It\\)\n\n\\(= ${I} \\times ${t} = ${Q}\\)C`,
    };
  },
  // find current from charge
  () => {
    const I = randInt(1, 15), t = randInt(2, 100);
    const Q = I * t;
    const o = buildOptions(I, [Q * t, round(t / Q, 4), I * 2], (v) => `${fmtNum(v, 2)}A`);
    if (!o) return null;
    return {
      text: `A charge of ${Q}C flows past a point in a circuit in ${t} seconds. Calculate the current.`,
      ...o,
      explanation: `\\(I = \\frac{Q}{t}\\)\n\n\\(= \\frac{${Q}}{${t}} = ${I}\\)A`,
    };
  },
  // current division in parallel branches
  () => {
    const r1 = randInt(1, 20), r2 = randInt(1, 20);
    const V = randInt(2, 40);
    const i1 = V / r1;
    const o = buildOptions(round(i1, 3), [round(V / r2, 3), round(V / (r1 + r2), 3), round(i1 * 2, 3)], (v) => `${fmtNum(v, 3)}A`);
    if (!o) return null;
    return {
      text: `Two resistors of ${r1}Ω and ${r2}Ω are connected in parallel across a ${V}V supply. Calculate the current through the ${r1}Ω resistor.`,
      ...o,
      explanation: `In a parallel circuit each branch has the full supply voltage across it.\n\n\\(I = \\frac{V}{R} = \\frac{${V}}{${r1}} = ${fmtNum(i1, 3)}\\)A`,
    };
  },
  ...conceptGens('electric current and circuits', [
    'Electric current is the rate of flow of charge',
    'The SI unit of current is the ampere',
    'In a series circuit the current is the same through every component',
    'In a parallel circuit the potential difference across each branch is the same',
    'Conventional current flows from the positive to the negative terminal outside the cell',
    'An ammeter is connected in series in a circuit',
    'A voltmeter is connected in parallel with the component',
    'The sum of the currents entering a junction equals the sum leaving it',
  ], [
    'Electric current is the rate of flow of voltage',
    'In a series circuit the current is different in each component',
    'In a parallel circuit the current is the same in each branch regardless of resistance',
    'An ammeter is connected in parallel with the component',
    'A voltmeter is connected in series in the circuit',
    'Conventional current flows from negative to positive outside the cell',
  ]),
];

// ==================== ELECTRIC ENERGY AND POWER ====================
const electricPower = [
  // P = IV
  () => {
    const I = randInt(1, 20), V = randInt(5, 240);
    const P = I * V;
    const o = buildOptions(P, [round(V / I, 3), I + V, P * 2], (v) => `${fmtNum(v, 2)}W`);
    if (!o) return null;
    return {
      text: `Calculate the power dissipated when a current of ${I}A flows through a device with ${V}V across it.`,
      ...o,
      explanation: `\\(P = IV\\)\n\n\\(= ${I} \\times ${V} = ${P}\\)W`,
    };
  },
  // P = I^2 R
  () => {
    const I = randInt(1, 12), R = randInt(2, 50);
    const P = I * I * R;
    const o = buildOptions(P, [I * R, round(R / (I * I), 3), P * 2], (v) => `${fmtNum(v, 2)}W`);
    if (!o) return null;
    return {
      text: `Calculate the power dissipated in a ${R}Ω resistor carrying a current of ${I}A.`,
      ...o,
      explanation: `\\(P = I^{2}R\\)\n\n\\(= ${I}^{2} \\times ${R} = ${I * I} \\times ${R} = ${P}\\)W`,
    };
  },
  // energy in kWh
  () => {
    const P = pick([100, 200, 500, 750, 1000, 1500, 2000]);
    const t = randInt(1, 12);
    const kWh = P * t / 1000;
    const o = buildOptions(kWh, [P * t, round(P / t / 1000, 4), kWh * 2], (v) => `${fmtNum(v, 3)}kWh`);
    if (!o) return null;
    return {
      text: `An electrical appliance rated ${P}W is used for ${t} hours. Calculate the energy consumed in kilowatt-hours.`,
      ...o,
      explanation: `Energy \\(= P \\times t\\), with power in kilowatts.\n\n\\(= \\frac{${P}}{1000} \\times ${t} = ${kWh}\\)kWh`,
    };
  },
  // cost of electricity
  () => {
    const P = pick([100, 200, 500, 1000, 1500]);
    const t = randInt(2, 10);
    const rate = pick([10, 20, 25, 50]);
    const kWh = P * t / 1000;
    const cost = kWh * rate;
    const o = buildOptions(round(cost, 2), [round(kWh, 3), round(cost * 2, 2), round(P * t * rate, 2)], (v) => `N${fmtNum(v, 2)}`);
    if (!o) return null;
    return {
      text: `A ${P}W bulb is used for ${t} hours. If electrical energy costs N${rate} per kilowatt-hour, calculate the cost of running the bulb.`,
      ...o,
      explanation: `Energy \\(= \\frac{${P}}{1000} \\times ${t} = ${kWh}\\)kWh\n\nCost \\(= ${kWh} \\times ${rate} = ${fmtNum(cost, 2)}\\)\n\nSo the cost is N${fmtNum(cost, 2)}.`,
    };
  },
  // energy in joules
  () => {
    const P = randInt(20, 500), t = randInt(10, 600);
    const E = P * t;
    const o = buildOptions(E, [round(P / t, 3), P + t, E * 2], (v) => `${fmtNum(v, 2)}J`);
    if (!o) return null;
    return {
      text: `Calculate the electrical energy consumed by a ${P}W device operating for ${t} seconds.`,
      ...o,
      explanation: `\\(E = Pt\\)\n\n\\(= ${P} \\times ${t} = ${E}\\)J`,
    };
  },
];

// ============================= CELLS AND EMF =============================
const cellsEmf = [
  // E = I(R + r)
  () => {
    const I = randInt(1, 10), R = randInt(2, 30), r = randInt(1, 5);
    const E = I * (R + r);
    const o = buildOptions(E, [I * R, I * r, E * 2], (v) => `${fmtNum(v, 2)}V`);
    if (!o) return null;
    return {
      text: `A cell of internal resistance ${r}Ω drives a current of ${I}A through an external resistance of ${R}Ω. Calculate the emf of the cell.`,
      ...o,
      explanation: `\\(E = I(R + r)\\)\n\n\\(= ${I}(${R} + ${r}) = ${I} \\times ${R + r} = ${E}\\)V`,
    };
  },
  // terminal pd
  () => {
    const I = randInt(1, 10), R = randInt(2, 30), r = randInt(1, 5);
    const E = I * (R + r);
    const V = I * R;
    const o = buildOptions(V, [E, I * r, V * 2], (x) => `${fmtNum(x, 2)}V`);
    if (!o) return null;
    return {
      text: `A cell of emf ${E}V and internal resistance ${r}Ω is connected to an external resistance of ${R}Ω. Calculate the terminal potential difference.`,
      ...o,
      explanation: `\\(I = \\frac{E}{R + r} = \\frac{${E}}{${R + r}} = ${I}\\)A\n\nTerminal p.d. \\(= IR = ${I} \\times ${R} = ${V}\\)V`,
    };
  },
  // current from emf
  () => {
    const E = randInt(2, 24), R = randInt(2, 30), r = randInt(1, 6);
    const I = E / (R + r);
    const o = buildOptions(round(I, 3), [round(E / R, 3), round(E / r, 3), round(I * 2, 3)], (v) => `${fmtNum(v, 3)}A`);
    if (!o) return null;
    return {
      text: `A cell of emf ${E}V and internal resistance ${r}Ω is connected across a ${R}Ω resistor. Calculate the current in the circuit.`,
      ...o,
      explanation: `\\(I = \\frac{E}{R + r}\\)\n\n\\(= \\frac{${E}}{${R} + ${r}} = \\frac{${E}}{${R + r}} = ${fmtNum(I, 3)}\\)A`,
    };
  },
  // cells in series
  () => {
    const n = randInt(2, 8), e = pick([1.5, 2, 12]);
    const total = n * e;
    const o = buildOptions(round(total, 2), [e, round(e / n, 3), round(total * 2, 2)], (v) => `${fmtNum(v, 2)}V`);
    if (!o) return null;
    return {
      text: `${n} cells each of emf ${e}V are connected in series. Calculate the total emf.`,
      ...o,
      explanation: `In series the emfs add.\n\n\\(= ${n} \\times ${e} = ${fmtNum(total, 2)}\\)V`,
    };
  },
  ...conceptGens('cells and electromotive force', [
    'The emf of a cell is the total energy supplied per unit charge',
    'Terminal potential difference is less than the emf when current flows',
    'Internal resistance causes a loss of voltage inside the cell',
    'Cells connected in series give a larger total emf',
    'Identical cells connected in parallel give the same emf as a single cell',
    'The lost volts in a cell equal the product of the current and the internal resistance',
    'A primary cell cannot be recharged',
  ], [
    'Terminal potential difference is always greater than the emf',
    'Internal resistance has no effect on the terminal voltage',
    'Cells in parallel always give a larger emf than a single cell',
    'The emf of a cell depends on its physical size only',
    'A secondary cell cannot be recharged',
    'Emf is measured in amperes',
  ]),
];

// ======================== SHUNT AND MULTIPLIER ========================
const shuntMultiplier = [
  // ammeter shunt
  () => {
    const Ig = pick([0.01, 0.02, 0.05]);
    const Rg = randInt(5, 100);
    const I = pick([1, 2, 5, 10]);
    const Rs = Ig * Rg / (I - Ig);
    const o = buildOptions(round(Rs, 4), [round(Rg / I, 3), Rg, round(Rs * 2, 4)], (v) => `${fmtNum(v, 4)}Ω`);
    if (!o) return null;
    return {
      text: `A galvanometer of resistance ${Rg}Ω gives full-scale deflection for a current of ${Ig}A. Calculate the resistance of the shunt required to convert it into an ammeter reading up to ${I}A.`,
      ...o,
      explanation: `The shunt carries the excess current \\(I - I_g\\).\n\n\\(I_gR_g = (I - I_g)R_s\\)\n\n\\(R_s = \\frac{${Ig} \\times ${Rg}}{${I} - ${Ig}} = ${fmtNum(Rs, 4)}\\)Ω`,
    };
  },
  // voltmeter multiplier
  () => {
    const Ig = pick([0.001, 0.005, 0.01]);
    const Rg = randInt(5, 100);
    const V = pick([5, 10, 50, 100]);
    const Rm = V / Ig - Rg;
    const o = buildOptions(round(Rm, 2), [round(V / Ig, 2), Rg, round(Rm * 2, 2)], (v) => `${fmtNum(v, 2)}Ω`);
    if (!o) return null;
    return {
      text: `A galvanometer of resistance ${Rg}Ω gives full-scale deflection for ${Ig}A. Calculate the multiplier resistance needed to convert it into a voltmeter reading up to ${V}V.`,
      ...o,
      explanation: `The multiplier is connected in series.\n\n\\(V = I_g(R_g + R_m)\\)\n\n\\(R_m = \\frac{V}{I_g} - R_g = \\frac{${V}}{${Ig}} - ${Rg} = ${fmtNum(Rm, 2)}\\)Ω`,
    };
  },
  ...conceptGens('shunts and multipliers', [
    'A shunt is a low resistance connected in parallel with a galvanometer',
    'A multiplier is a high resistance connected in series with a galvanometer',
    'A shunt converts a galvanometer into an ammeter',
    'A multiplier converts a galvanometer into a voltmeter',
    'An ideal ammeter has zero resistance',
    'An ideal voltmeter has infinite resistance',
    'The shunt carries most of the current in an ammeter',
  ], [
    'A shunt is a high resistance connected in series with a galvanometer',
    'A multiplier is a low resistance connected in parallel',
    'A shunt converts a galvanometer into a voltmeter',
    'An ideal ammeter has infinite resistance',
    'An ideal voltmeter has zero resistance',
    'A multiplier converts a galvanometer into an ammeter',
  ]),
];

// ===================== RESISTIVITY AND CONDUCTIVITY =====================
const resistivity = [
  // R = rho L / A
  () => {
    const rho = pick([1.7e-8, 2.8e-8, 1.1e-6, 4.9e-7]);
    const Lm = randInt(1, 100);
    const A = pick([1e-6, 2e-6, 5e-6, 1e-7]);
    const R = rho * Lm / A;
    const o = buildOptions(R, [rho * Lm * A, round(A / (rho * Lm), 4), R * 2],
      (v) => `${Number(v).toExponential(2)} Ω`);
    if (!o) return null;
    return {
      text: `Calculate the resistance of a wire of length ${Lm}m, cross-sectional area ${A.toExponential(0)}m² and resistivity \\(${rho.toExponential(1)}\\)Ωm.`,
      ...o,
      explanation: `\\(R = \\frac{\\rho L}{A}\\)\n\n\\(= \\frac{${rho.toExponential(1)} \\times ${Lm}}{${A.toExponential(0)}} = ${R.toExponential(2)}\\) Ω`,
    };
  },
  // effect of doubling length
  () => {
    const factor = randInt(2, 5);
    const o = buildOptions(factor, [round(1 / factor, 3), factor * factor, 1], (v) => `${v} times the original`);
    if (!o) return null;
    return {
      text: `If the length of a wire is increased ${factor} times while its cross-sectional area remains unchanged, what happens to its resistance?`,
      ...o,
      explanation: `\\(R = \\frac{\\rho L}{A}\\), so \\(R \\propto L\\) when \\(A\\) and \\(\\rho\\) are constant.\n\nIncreasing the length ${factor} times increases the resistance ${factor} times.`,
    };
  },
  // effect of area
  () => {
    const factor = randInt(2, 5);
    const correct = frac(1, factor);
    const o = buildOptions(correct, [frac(factor, 1), frac(1, factor * factor), frac(factor * factor, 1)], (f) => fracOpt(f));
    if (!o) return null;
    return {
      text: `The cross-sectional area of a wire is increased ${factor} times while its length stays the same. Its resistance becomes what fraction of the original?`,
      ...o,
      explanation: `\\(R = \\frac{\\rho L}{A}\\), so \\(R \\propto \\frac{1}{A}\\).\n\nIncreasing \\(A\\) by a factor of ${factor} reduces the resistance to \\(${fracTex(correct)}\\) of its original value.`,
    };
  },
  ...conceptGens('resistivity and conductivity', [
    'Resistivity is a property of the material and not of its dimensions',
    'The SI unit of resistivity is the ohm-metre',
    'Resistance is directly proportional to the length of a conductor',
    'Resistance is inversely proportional to the cross-sectional area of a conductor',
    'Conductivity is the reciprocal of resistivity',
    'Silver and copper have very low resistivity',
    'The resistivity of a metal increases with temperature',
  ], [
    'Resistivity depends on the length of the wire',
    'The SI unit of resistivity is the ohm',
    'Resistance is inversely proportional to the length of a conductor',
    'Resistance is directly proportional to the cross-sectional area',
    'Conductivity and resistivity are the same quantity',
    'Insulators have very low resistivity',
  ]),
];

// ====================== MAGNETIC FIELDS AND PROPERTIES ======================
const magneticFields = [
  // F = BIL
  () => {
    const B = pick([0.1, 0.2, 0.5, 1, 2]);
    const I = randInt(1, 20), Lm = pick([0.1, 0.2, 0.5, 1, 2]);
    const F = B * I * Lm;
    const o = buildOptions(round(F, 3), [round(B * I, 3), round(I * Lm, 3), round(F * 2, 3)], (v) => `${fmtNum(v, 3)}N`);
    if (!o) return null;
    return {
      text: `A conductor of length ${Lm}m carrying a current of ${I}A is placed at right angles to a magnetic field of flux density ${B}T. Calculate the force on the conductor.`,
      ...o,
      explanation: `\\(F = BIL\\)\n\n\\(= ${B} \\times ${I} \\times ${Lm} = ${fmtNum(F, 3)}\\)N`,
    };
  },
  // F = BQv
  () => {
    const B = pick([0.1, 0.5, 1, 2]);
    const q = randInt(1, 9), v = randInt(1, 9) * 1e6;
    const Q = q * 1e-6;
    const F = B * Q * v;
    const o = buildOptions(F, [B * Q, round(Q * v, 4), F * 2], (x) => `${Number(x).toExponential(2)} N`);
    if (!o) return null;
    return {
      text: `A charge of ${q}μC moves at \\(${(v / 1e6).toFixed(0)} \\times 10^{6}\\)m/s at right angles to a magnetic field of flux density ${B}T. Calculate the force on the charge.`,
      ...o,
      explanation: `\\(F = BQv\\)\n\n\\(= ${B} \\times ${q} \\times 10^{-6} \\times ${v.toExponential(0)} = ${F.toExponential(2)}\\) N`,
    };
  },
  ...conceptGens('magnetism', [
    'Like magnetic poles repel and unlike poles attract',
    'Magnetic field lines run from the north pole to the south pole outside a magnet',
    'Magnetic field lines never cross one another',
    'Iron is a ferromagnetic material',
    'Soft iron is easily magnetised and easily demagnetised',
    'Steel retains its magnetism and is used to make permanent magnets',
    'A freely suspended magnet comes to rest in the north-south direction',
    'The magnetic force on a conductor is greatest when it is perpendicular to the field',
  ], [
    'Like magnetic poles attract one another',
    'Magnetic field lines run from south to north outside a magnet',
    'Magnetic field lines may cross one another',
    'Soft iron is used to make permanent magnets because it retains magnetism',
    'A single magnetic pole can exist on its own',
    'The force on a current-carrying conductor is greatest when it is parallel to the field',
    'Copper is a ferromagnetic material',
  ]),
];

// ====================== ELECTROMAGNETIC INDUCTION ======================
const induction = [
  // induced emf = BLv
  () => {
    const B = pick([0.1, 0.2, 0.5, 1]);
    const Lm = pick([0.2, 0.5, 1, 2]);
    const v = randInt(1, 20);
    const emf = B * Lm * v;
    const o = buildOptions(round(emf, 3), [round(B * Lm, 3), round(Lm * v, 3), round(emf * 2, 3)], (x) => `${fmtNum(x, 3)}V`);
    if (!o) return null;
    return {
      text: `A conductor of length ${Lm}m moves at ${v}m/s at right angles to a magnetic field of flux density ${B}T. Calculate the emf induced.`,
      ...o,
      explanation: `\\(E = BLv\\)\n\n\\(= ${B} \\times ${Lm} \\times ${v} = ${fmtNum(emf, 3)}\\)V`,
    };
  },
  // rate of change of flux
  () => {
    const dphi = pick([0.02, 0.05, 0.1, 0.2, 0.5]);
    const dt = pick([0.1, 0.2, 0.5, 1, 2]);
    const N = randInt(1, 200);
    const emf = N * dphi / dt;
    const o = buildOptions(round(emf, 3), [round(dphi / dt, 3), round(N * dphi * dt, 3), round(emf * 2, 3)], (x) => `${fmtNum(x, 3)}V`);
    if (!o) return null;
    return {
      text: `A coil of ${N} turns experiences a change in magnetic flux of ${dphi}Wb in ${dt}s. Calculate the magnitude of the induced emf.`,
      ...o,
      explanation: `By Faraday's law, \\(E = N\\frac{\\Delta\\Phi}{\\Delta t}\\).\n\n\\(= ${N} \\times \\frac{${dphi}}{${dt}} = ${fmtNum(emf, 3)}\\)V`,
    };
  },
  ...conceptGens('electromagnetic induction', [
    'Faraday\'s law states that the induced emf is proportional to the rate of change of magnetic flux',
    'Lenz\'s law states that the induced current opposes the change producing it',
    'Lenz\'s law is a consequence of the conservation of energy',
    'An emf is induced only when there is a change in magnetic flux linkage',
    'Increasing the number of turns in the coil increases the induced emf',
    'Moving a magnet faster into a coil increases the induced emf',
    'A generator converts mechanical energy into electrical energy',
  ], [
    'An emf is induced even when the magnetic flux is constant',
    'Lenz\'s law states that the induced current aids the change producing it',
    'The induced emf is independent of the number of turns in the coil',
    'Moving the magnet more slowly increases the induced emf',
    'A generator converts electrical energy into mechanical energy',
    'Faraday\'s law relates induced emf to the total flux rather than its rate of change',
  ]),
];

// ============================== AC CIRCUITS ==============================
const acCircuits = [
  // rms from peak
  () => {
    const V0 = pick([10, 20, 50, 100, 141, 200, 311]);
    const Vrms = V0 / Math.sqrt(2);
    const o = buildOptions(round(Vrms, 2), [round(V0 * Math.sqrt(2), 2), V0, round(Vrms / 2, 2)], (v) => `${fmtNum(v, 2)}V`);
    if (!o) return null;
    return {
      text: `An alternating voltage has a peak value of ${V0}V. Calculate its root-mean-square value, correct to 2 decimal places.`,
      ...o,
      explanation: `\\(V_{rms} = \\frac{V_0}{\\sqrt{2}}\\)\n\n\\(= \\frac{${V0}}{1.414} = ${fmtNum(Vrms, 2)}\\)V`,
    };
  },
  // peak from rms
  () => {
    const Vrms = pick([110, 220, 240, 50, 100]);
    const V0 = Vrms * Math.sqrt(2);
    const o = buildOptions(round(V0, 2), [round(Vrms / Math.sqrt(2), 2), Vrms, round(V0 * 2, 2)], (v) => `${fmtNum(v, 2)}V`);
    if (!o) return null;
    return {
      text: `The rms value of an alternating voltage is ${Vrms}V. Calculate its peak value, correct to 2 decimal places.`,
      ...o,
      explanation: `\\(V_0 = V_{rms}\\sqrt{2}\\)\n\n\\(= ${Vrms} \\times 1.414 = ${fmtNum(V0, 2)}\\)V`,
    };
  },
  // frequency and period of ac
  () => {
    const f = pick([50, 60, 100, 200]);
    const T = 1 / f;
    const o = buildOptions(round(T, 5), [f, round(f / 2, 3), round(T * 2, 5)], (v) => `${fmtNum(v, 5)}s`);
    if (!o) return null;
    return {
      text: `An alternating current has a frequency of ${f}Hz. Calculate its period.`,
      ...o,
      explanation: `\\(T = \\frac{1}{f} = \\frac{1}{${f}} = ${fmtNum(T, 5)}\\)s`,
    };
  },
  ...conceptGens('alternating current circuits', [
    'The rms value of an alternating current is the peak value divided by the square root of two',
    'An alternating current reverses its direction periodically',
    'The rms value is also called the effective value',
    'Capacitive reactance decreases as frequency increases',
    'Inductive reactance increases as frequency increases',
    'At resonance in a series LCR circuit the impedance is a minimum',
    'A transformer works only with alternating current',
  ], [
    'The rms value is the peak value multiplied by two',
    'An alternating current flows in only one direction',
    'Capacitive reactance increases as frequency increases',
    'Inductive reactance decreases as frequency increases',
    'A transformer works equally well with direct current',
    'At resonance the impedance of a series LCR circuit is a maximum',
  ]),
];

// =========================== POWER TRANSMISSION ===========================
const transmission = [
  // transformer turns ratio
  () => {
    const Np = pick([100, 200, 500, 1000]);
    const ratio = pick([2, 4, 5, 10]);
    const Ns = Np * ratio;
    const Vp = pick([110, 220, 240]);
    const Vs = Vp * ratio;
    const o = buildOptions(Vs, [round(Vp / ratio, 2), Vp, Vs * 2], (v) => `${fmtNum(v, 2)}V`);
    if (!o) return null;
    return {
      text: `A transformer has ${Np} turns in its primary and ${Ns} turns in its secondary. If the primary voltage is ${Vp}V, calculate the secondary voltage.`,
      ...o,
      explanation: `\\(\\frac{V_s}{V_p} = \\frac{N_s}{N_p}\\)\n\n\\(V_s = \\frac{${Ns}}{${Np}} \\times ${Vp} = ${ratio} \\times ${Vp} = ${Vs}\\)V`,
    };
  },
  // transformer efficiency
  () => {
    const Pin = pick([100, 200, 500, 1000, 2000]);
    const eff = pick([80, 85, 90, 95]);
    const Pout = Pin * eff / 100;
    const o = buildOptions(Pout, [Pin, round(Pin * 100 / eff, 2), round(Pout / 2, 2)], (v) => `${fmtNum(v, 2)}W`);
    if (!o) return null;
    return {
      text: `A transformer with an efficiency of ${eff}% has an input power of ${Pin}W. Calculate its output power.`,
      ...o,
      explanation: `Efficiency \\(= \\frac{P_{out}}{P_{in}} \\times 100\\%\\)\n\n\\(P_{out} = \\frac{${eff}}{100} \\times ${Pin} = ${Pout}\\)W`,
    };
  },
  // power loss in transmission line
  () => {
    const I = randInt(1, 30), R = randInt(1, 20);
    const P = I * I * R;
    const o = buildOptions(P, [I * R, round(R / I, 3), P * 2], (v) => `${fmtNum(v, 2)}W`);
    if (!o) return null;
    return {
      text: `A transmission line of resistance ${R}Ω carries a current of ${I}A. Calculate the power lost as heat in the line.`,
      ...o,
      explanation: `\\(P = I^{2}R\\)\n\n\\(= ${I}^{2} \\times ${R} = ${I * I} \\times ${R} = ${P}\\)W`,
    };
  },
  ...conceptGens('electrical power transmission', [
    'Electrical power is transmitted at high voltage to reduce power loss in the cables',
    'Power loss in a transmission line is proportional to the square of the current',
    'A step-up transformer increases voltage and decreases current',
    'A step-down transformer decreases voltage and increases current',
    'Transformers work on the principle of mutual induction',
    'Transmitting at high voltage means a lower current for the same power',
    'Eddy current losses in a transformer are reduced by using a laminated core',
  ], [
    'Electrical power is transmitted at low voltage to reduce losses',
    'Power loss in a cable is independent of the current',
    'A step-up transformer increases both voltage and current',
    'Transformers work on the principle of electrostatic induction',
    'A solid core reduces eddy current losses better than a laminated core',
    'High voltage transmission increases the current in the line',
  ]),
];

// ======================= SEMICONDUCTORS AND DIODES =======================
const semiconductors = [
  ...conceptGens('semiconductors and diodes', [
    'A semiconductor has a conductivity between that of a conductor and an insulator',
    'Silicon and germanium are common semiconductor materials',
    'An n-type semiconductor is produced by doping with a pentavalent impurity',
    'A p-type semiconductor is produced by doping with a trivalent impurity',
    'In an n-type semiconductor the majority charge carriers are electrons',
    'In a p-type semiconductor the majority charge carriers are holes',
    'A diode conducts easily when forward biased',
    'A diode offers very high resistance when reverse biased',
    'The resistance of a semiconductor decreases as temperature increases',
    'A diode can be used to rectify alternating current',
  ], [
    'A semiconductor is a better conductor than copper',
    'An n-type semiconductor is produced by doping with a trivalent impurity',
    'In a p-type semiconductor the majority carriers are electrons',
    'A diode conducts equally well in both directions',
    'The resistance of a semiconductor increases as temperature increases',
    'A diode cannot be used for rectification',
    'Doping reduces the conductivity of a pure semiconductor',
  ], [
    { q: 'What is the main use of a diode in an electrical circuit?', a: 'Rectification of alternating current', w: ['Amplification of signals', 'Storage of charge', 'Generation of alternating current'], e: 'A diode conducts in one direction only, so it converts alternating current into direct current, a process called rectification.' },
    { q: 'Which impurity is added to silicon to produce an n-type semiconductor?', a: 'A pentavalent impurity such as phosphorus', w: ['A trivalent impurity such as boron', 'A divalent impurity such as magnesium', 'A monovalent impurity such as sodium'], e: 'Pentavalent atoms have five valence electrons. Four form bonds with silicon and the fifth is free to conduct, making electrons the majority carriers.' },
    { q: 'What are the majority charge carriers in a p-type semiconductor?', a: 'Holes', w: ['Electrons', 'Protons', 'Neutrons'], e: 'Trivalent doping leaves vacancies in the bonding structure. These positively charged vacancies, called holes, are the majority carriers.' },
  ]),
];

// ========== PHOTOELECTRIC EFFECT AND THERMIONIC EMISSION ==========
const photoelectric = [
  // E = hf
  () => {
    const f = randInt(1, 9) * 1e14;
    const E = H_PL * f;
    const o = buildOptions(E, [H_PL / f, E * 2, round(f / H_PL, 2)], (v) => `${Number(v).toExponential(2)} J`);
    if (!o) return null;
    return {
      text: `Calculate the energy of a photon of frequency \\(${(f / 1e14).toFixed(0)} \\times 10^{14}\\)Hz. [Take \\(h = 6.63 \\times 10^{-34}\\) Js]`,
      ...o,
      explanation: `\\(E = hf\\)\n\n\\(= 6.63 \\times 10^{-34} \\times ${f.toExponential(1)} = ${E.toExponential(2)}\\) J`,
    };
  },
  // threshold frequency from work function
  () => {
    const W = randInt(2, 9) * 1e-19;
    const f0 = W / H_PL;
    const o = buildOptions(f0, [W * H_PL, round(H_PL / W, 2), f0 * 2], (v) => `${Number(v).toExponential(2)} Hz`);
    if (!o) return null;
    return {
      text: `A metal has a work function of \\(${(W / 1e-19).toFixed(0)} \\times 10^{-19}\\)J. Calculate its threshold frequency. [Take \\(h = 6.63 \\times 10^{-34}\\) Js]`,
      ...o,
      explanation: `At the threshold frequency the photon energy just equals the work function.\n\n\\(W = hf_0 \\Rightarrow f_0 = \\frac{W}{h}\\)\n\n\\(= \\frac{${W.toExponential(1)}}{6.63 \\times 10^{-34}} = ${f0.toExponential(2)}\\) Hz`,
    };
  },
  // maximum kinetic energy
  () => {
    const f = randInt(5, 9) * 1e14;
    const W = randInt(1, 3) * 1e-19;
    const KE = H_PL * f - W;
    if (KE <= 0) return null;
    const o = buildOptions(KE, [H_PL * f + W, H_PL * f, KE * 2], (v) => `${Number(v).toExponential(2)} J`);
    if (!o) return null;
    return {
      text: `Light of frequency \\(${(f / 1e14).toFixed(0)} \\times 10^{14}\\)Hz falls on a metal of work function \\(${(W / 1e-19).toFixed(0)} \\times 10^{-19}\\)J. Calculate the maximum kinetic energy of the emitted electrons. [Take \\(h = 6.63 \\times 10^{-34}\\) Js]`,
      ...o,
      explanation: `By Einstein's photoelectric equation, \\(KE_{max} = hf - W\\).\n\n\\(= (6.63 \\times 10^{-34} \\times ${f.toExponential(1)}) - ${W.toExponential(1)}\\)\n\n\\(= ${KE.toExponential(2)}\\) J`,
    };
  },
  ...conceptGens('the photoelectric effect', [
    'Photoelectrons are emitted only when the frequency of the incident light exceeds the threshold frequency',
    'The maximum kinetic energy of photoelectrons depends on the frequency of the incident light',
    'The number of photoelectrons emitted per second depends on the intensity of the incident light',
    'The work function is the minimum energy needed to remove an electron from a metal surface',
    'Photoelectric emission is instantaneous',
    'The photoelectric effect demonstrates the particle nature of light',
    'Thermionic emission is the emission of electrons from a heated metal surface',
  ], [
    'Photoelectrons are emitted at any frequency provided the light is bright enough',
    'The maximum kinetic energy of photoelectrons depends on the intensity of the light',
    'The number of photoelectrons emitted depends on the frequency of the light',
    'There is a long time delay between illumination and emission',
    'The photoelectric effect demonstrates the wave nature of light',
    'Thermionic emission occurs when a metal is cooled',
  ]),
];

// ============================= RADIOACTIVITY =============================
const radioactivity = [
  // half-life decay
  () => {
    const T = randInt(2, 30);
    const n = randInt(1, 5);
    const t = T * n;
    const N0 = Math.pow(2, n) * randInt(1, 20);
    const N = N0 / Math.pow(2, n);
    const o = buildOptions(N, [N0 / n, N0 / 2, N * 2], (v) => `${fmtNum(v, 2)}g`);
    if (!o) return null;
    return {
      text: `A radioactive substance has a half-life of ${T} days. If ${N0}g of the substance is kept for ${t} days, what mass remains undecayed?`,
      ...o,
      explanation: `Number of half-lives \\(= \\frac{${t}}{${T}} = ${n}\\)\n\n\\(N = N_0\\left(\\frac{1}{2}\\right)^{${n}} = ${N0} \\times \\frac{1}{${Math.pow(2, n)}} = ${N}\\)g`,
    };
  },
  // find the number of half-lives
  () => {
    const n = randInt(1, 6);
    const frac2 = Math.pow(2, n);
    const o = buildOptions(n, [frac2, n + 1, round(n / 2, 2)], (v) => String(v));
    if (!o) return null;
    return {
      text: `After how many half-lives will the activity of a radioactive sample fall to \\(\\frac{1}{${frac2}}\\) of its original value?`,
      ...o,
      explanation: `After \\(n\\) half-lives the fraction remaining is \\(\\left(\\frac{1}{2}\\right)^{n}\\).\n\n\\(\\left(\\frac{1}{2}\\right)^{n} = \\frac{1}{${frac2}}\\)\n\nSince \\(2^{${n}} = ${frac2}\\), \\(n = ${n}\\).`,
    };
  },
  // fraction remaining
  () => {
    const T = randInt(2, 20), n = randInt(1, 5);
    const t = T * n;
    const correct = frac(1, Math.pow(2, n));
    const o = buildOptions(correct, [frac(1, 2 * n), frac(Math.pow(2, n), 1), frac(1, n)], (f) => fracOpt(f));
    if (!o) return null;
    return {
      text: `The half-life of a radioactive element is ${T} years. What fraction of the original sample remains after ${t} years?`,
      ...o,
      explanation: `Number of half-lives \\(= \\frac{${t}}{${T}} = ${n}\\)\n\nFraction remaining \\(= \\left(\\frac{1}{2}\\right)^{${n}} = ${fracTex(correct)}\\)`,
    };
  },
  ...conceptGens('radioactivity', [
    'Alpha particles are helium nuclei carrying a positive charge',
    'Beta particles are fast-moving electrons carrying a negative charge',
    'Gamma rays are electromagnetic waves and carry no charge',
    'Gamma rays have the greatest penetrating power of the three radiations',
    'Alpha particles have the greatest ionising power of the three radiations',
    'Half-life is the time taken for half the nuclei in a sample to decay',
    'Radioactive decay is a spontaneous and random process',
    'The half-life of a radioactive element is unaffected by temperature or pressure',
    'Alpha particles are stopped by a sheet of paper',
  ], [
    'Alpha particles carry a negative charge',
    'Gamma rays carry a positive charge',
    'Alpha particles have the greatest penetrating power',
    'Gamma rays have the greatest ionising power',
    'The half-life of an element can be changed by raising the temperature',
    'Radioactive decay can be predicted exactly for an individual nucleus',
    'Beta particles are helium nuclei',
  ]),
];

// =========================== NUCLEAR REACTIONS ===========================
const nuclear = [
  // mass number / atomic number after alpha decay
  () => {
    const A = randInt(200, 240), Z = randInt(80, 95);
    const o = buildOptions([A - 4, Z - 2], [[A - 4, Z], [A, Z - 2], [A - 2, Z - 4]],
      (p) => `Mass number ${p[0]}, atomic number ${p[1]}`);
    if (!o) return null;
    return {
      text: `A nucleus of mass number ${A} and atomic number ${Z} emits an alpha particle. What are the mass number and atomic number of the daughter nucleus?`,
      ...o,
      explanation: `An alpha particle is a helium nucleus, \\(^{4}_{2}He\\).\n\nMass number: \\(${A} - 4 = ${A - 4}\\)\n\nAtomic number: \\(${Z} - 2 = ${Z - 2}\\)`,
    };
  },
  // beta decay
  () => {
    const A = randInt(10, 240), Z = randInt(5, 92);
    const o = buildOptions([A, Z + 1], [[A, Z - 1], [A - 1, Z], [A - 4, Z - 2]],
      (p) => `Mass number ${p[0]}, atomic number ${p[1]}`);
    if (!o) return null;
    return {
      text: `A nucleus of mass number ${A} and atomic number ${Z} undergoes beta decay. What are the mass number and atomic number of the resulting nucleus?`,
      ...o,
      explanation: `In beta decay a neutron changes into a proton and an electron is emitted.\n\nMass number is unchanged: ${A}\n\nAtomic number increases by 1: \\(${Z} + 1 = ${Z + 1}\\)`,
    };
  },
  // energy from mass defect
  () => {
    const dm = randInt(1, 9) * 1e-28;
    const c = 3e8;
    const E = dm * c * c;
    const o = buildOptions(E, [dm * c, round(dm / (c * c), 40), E * 2], (v) => `${Number(v).toExponential(2)} J`);
    if (!o) return null;
    return {
      text: `Calculate the energy released when a mass defect of \\(${(dm / 1e-28).toFixed(0)} \\times 10^{-28}\\)kg is converted to energy. [Take \\(c = 3 \\times 10^{8}\\)m/s]`,
      ...o,
      explanation: `\\(E = mc^{2}\\)\n\n\\(= ${dm.toExponential(1)} \\times (3 \\times 10^{8})^{2}\\)\n\n\\(= ${dm.toExponential(1)} \\times 9 \\times 10^{16} = ${E.toExponential(2)}\\) J`,
    };
  },
  // number of neutrons
  () => {
    const A = randInt(10, 240), Z = randInt(5, Math.min(92, A - 5));
    const N = A - Z;
    const o = buildOptions(N, [A + Z, Z, A], (v) => String(v));
    if (!o) return null;
    return {
      text: `How many neutrons are present in a nucleus of mass number ${A} and atomic number ${Z}?`,
      ...o,
      explanation: `Number of neutrons \\(= A - Z\\)\n\n\\(= ${A} - ${Z} = ${N}\\)`,
    };
  },
  ...conceptGens('nuclear reactions', [
    'Nuclear fission is the splitting of a heavy nucleus into lighter nuclei',
    'Nuclear fusion is the joining of light nuclei to form a heavier nucleus',
    'The energy released in a nuclear reaction comes from a loss of mass',
    'The Sun obtains its energy mainly from nuclear fusion',
    'Mass and energy are related by the equation E equals mc squared',
    'Isotopes of an element have the same atomic number but different mass numbers',
    'A chain reaction can occur in nuclear fission when released neutrons cause further fissions',
  ], [
    'Nuclear fission is the joining of light nuclei',
    'Nuclear fusion is the splitting of a heavy nucleus',
    'The Sun obtains its energy mainly from nuclear fission',
    'Isotopes have the same mass number but different atomic numbers',
    'Mass is always exactly conserved in a nuclear reaction',
    'Nuclear reactions release far less energy than chemical reactions',
  ]),
];

// ========================== MODELS OF THE ATOM ==========================
const atomModels = [
  ...conceptGens('models of the atom', [
    'Thomson proposed the plum pudding model in which electrons are embedded in a sphere of positive charge',
    'Rutherford\'s alpha scattering experiment showed that the atom has a small dense positive nucleus',
    'Most of an atom is empty space',
    'Bohr proposed that electrons occupy discrete energy levels',
    'An electron emits a photon when it moves from a higher to a lower energy level',
    'In Rutherford\'s experiment most alpha particles passed straight through the gold foil',
    'A few alpha particles were deflected through large angles because they came close to the nucleus',
  ], [
    'Rutherford proposed the plum pudding model',
    'Thomson discovered the atomic nucleus',
    'In Rutherford\'s experiment most alpha particles bounced straight back',
    'Electrons in the Bohr model can occupy any energy whatsoever',
    'An electron absorbs a photon when it falls to a lower energy level',
    'The nucleus occupies almost the entire volume of the atom',
    'The atom is a solid sphere with no internal structure',
  ], [
    { q: 'Whose experiment led to the discovery of the atomic nucleus?', a: 'Rutherford', w: ['Thomson', 'Bohr', 'Chadwick'], e: 'Rutherford\'s alpha particle scattering experiment showed that a small proportion of alpha particles were deflected through large angles, implying a small, dense, positively charged nucleus.' },
    { q: 'Who discovered the electron?', a: 'J. J. Thomson', w: ['Ernest Rutherford', 'Niels Bohr', 'James Chadwick'], e: 'Thomson identified the electron through his experiments on cathode rays and measured its charge-to-mass ratio.' },
    { q: 'Who discovered the neutron?', a: 'James Chadwick', w: ['J. J. Thomson', 'Niels Bohr', 'Ernest Rutherford'], e: 'Chadwick identified the neutron in 1932 as a neutral particle of roughly the same mass as the proton.' },
    { q: 'According to the Bohr model, what happens when an electron jumps from a higher to a lower energy level?', a: 'A photon is emitted', w: ['A photon is absorbed', 'A neutron is emitted', 'The atom becomes ionised'], e: 'The energy difference between the levels is carried away as a photon whose energy equals that difference.' },
  ]),
];

// ======================== WAVE-PARTICLE DUALITY ========================
const duality = [
  // de Broglie wavelength
  () => {
    const m = pick([9.1e-31, 1.67e-27]);
    const v = randInt(1, 9) * 1e6;
    const lam = H_PL / (m * v);
    const o = buildOptions(lam, [H_PL * m * v, round(m * v / H_PL, 2), lam * 2],
      (x) => `${Number(x).toExponential(2)} m`);
    if (!o) return null;
    const name = m === 9.1e-31 ? 'an electron' : 'a proton';
    return {
      text: `Calculate the de Broglie wavelength of ${name} of mass \\(${m.toExponential(2)}\\)kg moving at \\(${(v / 1e6).toFixed(0)} \\times 10^{6}\\)m/s. [Take \\(h = 6.63 \\times 10^{-34}\\) Js]`,
      ...o,
      explanation: `\\(\\lambda = \\frac{h}{mv}\\)\n\n\\(= \\frac{6.63 \\times 10^{-34}}{${m.toExponential(2)} \\times ${v.toExponential(1)}} = ${lam.toExponential(2)}\\) m`,
    };
  },
  ...conceptGens('wave-particle duality', [
    'Light exhibits both wave and particle properties',
    'The photoelectric effect demonstrates the particle nature of light',
    'Interference and diffraction demonstrate the wave nature of light',
    'Electron diffraction demonstrates the wave nature of particles',
    'The de Broglie wavelength is inversely proportional to the momentum of a particle',
    'A photon is a quantum of electromagnetic energy',
    'The energy of a photon is proportional to its frequency',
  ], [
    'Light shows only wave properties and never particle properties',
    'The photoelectric effect demonstrates the wave nature of light',
    'Diffraction demonstrates the particle nature of light',
    'The de Broglie wavelength is directly proportional to momentum',
    'The energy of a photon is independent of its frequency',
    'Only light, and no material particle, can show wave behaviour',
  ]),
];

// ================================ X-RAYS ================================
const xrays = [
  ...conceptGens('X-rays', [
    'X-rays are produced when fast-moving electrons are suddenly stopped by a metal target',
    'X-rays are electromagnetic waves of very short wavelength',
    'X-rays are not deflected by electric or magnetic fields',
    'X-rays can penetrate soft body tissue but are absorbed by bone',
    'Hard X-rays have shorter wavelengths and greater penetrating power than soft X-rays',
    'X-rays cause ionisation of the gases they pass through',
    'Increasing the accelerating voltage in an X-ray tube increases the penetrating power of the X-rays produced',
    'Excessive exposure to X-rays is harmful to living tissue',
  ], [
    'X-rays are streams of negatively charged particles',
    'X-rays are deflected by magnetic fields',
    'Soft X-rays are more penetrating than hard X-rays',
    'X-rays are produced by heating a gas to a very high temperature',
    'X-rays cannot pass through any material',
    'X-rays are completely harmless to living tissue at any dose',
    'X-rays travel more slowly than visible light in a vacuum',
  ], [
    { q: 'How are X-rays produced in an X-ray tube?', a: 'By bombarding a metal target with high-speed electrons', w: ['By heating a metal filament until it glows', 'By passing current through a gas at high pressure', 'By allowing radioactive decay of a heavy nucleus'], e: 'Electrons are accelerated through a large potential difference and strike a metal target. Their sudden deceleration converts their kinetic energy into X-ray photons.' },
    { q: 'What controls the intensity of the X-rays produced in an X-ray tube?', a: 'The filament current, which controls the number of electrons produced', w: ['The accelerating voltage only', 'The atomic number of the target only', 'The length of the tube'], e: 'A larger filament current releases more electrons per second by thermionic emission, so more X-ray photons are produced, increasing intensity.' },
    { q: 'Why is lead used for shielding against X-rays?', a: 'Lead has a high density and absorbs X-rays strongly', w: ['Lead reflects all X-rays', 'Lead is transparent to X-rays', 'Lead converts X-rays into visible light'], e: 'The high density and high atomic number of lead make it a very effective absorber of X-radiation, protecting operators from exposure.' },
  ]),
];

module.exports = [
  { topicId: '5KNcErPBqv76PZk0WnSl', unitId: U_ESTAT, topicName: 'Electric Potential and Capacitance', generators: capacitance },
  { topicId: 'JkLlFBm9Wlxbe6HVwKSK', unitId: U_ESTAT, topicName: 'Electric Charges and Fields', generators: chargesFields },
  { topicId: 'ZE4jKlbT17Afd5scGzIN', unitId: U_ESTAT, topicName: 'Coulombs Law', generators: coulomb },
  { topicId: 'FtC6bH1J36rFX7kJ4zkl', unitId: U_CURR, topicName: 'Ohms Law and Resistance', generators: ohmsLaw },
  { topicId: '55LiUanF7a54dTMD3SMl', unitId: U_CURR, topicName: 'Electric Energy and Power', generators: electricPower },
  { topicId: 'Cysf6XMiWpl92aX0f3zG', unitId: U_CURR, topicName: 'Electric Current and Circuits', generators: currentCircuits },
  { topicId: 'z7E34B4C3X67R2TfA3WX', unitId: U_CURR, topicName: 'Cells and EMF', generators: cellsEmf },
  { topicId: '7V9fcJaVz6sOYeVZpCZO', unitId: U_CURR, topicName: 'Shunt and Multiplier', generators: shuntMultiplier },
  { topicId: 'YBFNHvxsgdyHsxccb2LL', unitId: U_CURR, topicName: 'Resistivity and Conductivity', generators: resistivity },
  { topicId: 'vLIRmdfdG3uUJDF75tdw', unitId: U_MAG, topicName: 'Electromagnetic Induction', generators: induction },
  { topicId: 'uv8GfmTGER7Tho5CZ6ob', unitId: U_MAG, topicName: 'AC Circuits', generators: acCircuits },
  { topicId: 'cCoRjeDu1oodTu1jXIrD', unitId: U_MAG, topicName: 'Magnetic Fields and Properties', generators: magneticFields },
  { topicId: 'X7Bz42r9Mlse2LlluIwe', unitId: U_MAG, topicName: 'Power Transmission', generators: transmission },
  { topicId: 'uoaCt4urf67s9zq7cyRi', unitId: U_MAG, topicName: 'Semiconductors and Diodes', generators: semiconductors },
  { topicId: '7RHOtC0pHEUhHHNCAklS', unitId: U_ATOM, topicName: 'Photoelectric Effect and Thermionic Emission', generators: photoelectric },
  { topicId: 'Nlc4llc4ZYmJ3TMz6Jqk', unitId: U_ATOM, topicName: 'Nuclear Reactions', generators: nuclear },
  { topicId: 'TY6tEwXNWJ8EUHofG1CU', unitId: U_ATOM, topicName: 'Radioactivity', generators: radioactivity },
  { topicId: 'mpmDFCAkGuQoxjsLRGAX', unitId: U_ATOM, topicName: 'Models of the Atom', generators: atomModels },
  { topicId: '0TZ3qtXVLb6ZZZbZOteO', unitId: U_ATOM, topicName: 'Wave-Particle Duality', generators: duality },
  { topicId: 'TZruXH5WnzUTj7MTYx8k', unitId: U_ATOM, topicName: 'X-rays', generators: xrays },
];
