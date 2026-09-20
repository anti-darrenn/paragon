// Physics > Fluids, Heat and Thermodynamics
const L = require('./lib');
const { randInt, pick, shuffle, sample, nonZero, frac, fracTex, fracOpt,
        fmtNum, buildOptions, textOptions, round } = L;
const { conceptGens, qaBank } = require('./concept');

const U_FLUID = 'EukYmz1tLsY5CiBNe70X';
const U_HEAT = '6AcbjWxC7nVuEXmIiLk0';
const G = 10;

// =================== DENSITY AND RELATIVE DENSITY ===================
const density = [
  // rho = m / V
  () => {
    const rho = pick([800, 1000, 1200, 2500, 2700, 7800, 13600]);
    const V = pick([0.001, 0.002, 0.005, 0.01, 0.02]);
    const m = rho * V;
    const o = buildOptions(rho, [round(V / m, 5), round(m * V, 3), rho * 2], (v) => `${fmtNum(v, 2)}kg/m³`);
    if (!o) return null;
    return {
      text: `A body of mass ${fmtNum(m, 2)}kg has a volume of ${V}m³. Calculate its density.`,
      ...o,
      explanation: `\\(\\rho = \\frac{m}{V}\\)\n\n\\(= \\frac{${fmtNum(m, 2)}}{${V}} = ${rho}\\)kg/m³`,
    };
  },
  // mass from density and volume
  () => {
    const rho = pick([800, 1000, 2500, 2700, 7800]);
    const V = pick([0.001, 0.002, 0.004, 0.01]);
    const m = rho * V;
    const o = buildOptions(round(m, 2), [round(rho / V, 2), round(rho * V * 2, 2), round(V / rho, 6)], (v) => `${fmtNum(v, 2)}kg`);
    if (!o) return null;
    return {
      text: `Calculate the mass of a body of volume ${V}m³ and density ${rho}kg/m³.`,
      ...o,
      explanation: `\\(m = \\rho V\\)\n\n\\(= ${rho} \\times ${V} = ${fmtNum(m, 2)}\\)kg`,
    };
  },
  // relative density
  () => {
    const rho = pick([800, 1200, 2500, 2700, 7800, 13600, 920]);
    const rd = rho / 1000;
    const o = buildOptions(rd, [rho, round(1000 / rho, 4), round(rd * 2, 3)], (v) => fmtNum(v, 3));
    if (!o) return null;
    return {
      text: `A substance has a density of ${rho}kg/m³. Calculate its relative density. [Density of water = 1000kg/m³]`,
      ...o,
      explanation: `Relative density \\(= \\frac{\\text{density of substance}}{\\text{density of water}}\\)\n\n\\(= \\frac{${rho}}{1000} = ${rd}\\)\n\nRelative density has no unit.`,
    };
  },
  // density in g/cm3
  () => {
    const m = randInt(10, 500), V = pick([2, 4, 5, 8, 10, 20, 25]);
    const rho = m / V;
    const o = buildOptions(round(rho, 2), [round(V / m, 4), m * V, round(rho * 2, 2)], (v) => `${fmtNum(v, 2)}g/cm³`);
    if (!o) return null;
    return {
      text: `A block of mass ${m}g occupies a volume of ${V}cm³. Calculate its density.`,
      ...o,
      explanation: `\\(\\rho = \\frac{m}{V} = \\frac{${m}}{${V}} = ${fmtNum(rho, 2)}\\)g/cm³`,
    };
  },
  ...conceptGens('density and relative density', [
    'Density is the mass per unit volume of a substance',
    'Relative density has no unit',
    'Relative density is the ratio of the density of a substance to the density of water',
    'The SI unit of density is the kilogram per cubic metre',
    'A substance with relative density less than 1 will float on water',
    'The density of water is approximately 1000kg/m³',
  ], [
    'Density is the volume per unit mass of a substance',
    'Relative density is measured in kg/m³',
    'The SI unit of density is the gram per cubic centimetre',
    'A substance with relative density greater than 1 will float on water',
    'Density does not depend on the volume of the substance sample in any way',
    'Relative density is the product of density and volume',
  ]),
];

// ============================= VISCOSITY =============================
const viscosity = [
  ...conceptGens('viscosity', [
    'Viscosity is the internal friction between layers of a fluid in relative motion',
    'The viscosity of a liquid decreases as its temperature increases',
    'The viscosity of a gas increases as its temperature increases',
    'A body falling through a viscous fluid eventually attains a terminal velocity',
    'At terminal velocity the resultant force on the falling body is zero',
    'Viscous drag opposes the relative motion between a body and a fluid',
    'Thick oils are more viscous than water',
  ], [
    'Viscosity of a liquid increases as temperature increases',
    'Viscous forces act in the direction of motion of a body',
    'A body falling through a viscous fluid accelerates indefinitely',
    'At terminal velocity the body has zero velocity',
    'Viscosity is only a property of solids',
    'Water is more viscous than engine oil',
  ], [
    { q: 'A body falls through a viscous liquid and attains terminal velocity. Which statement about the forces on it is correct?', a: 'The weight is balanced by the upthrust and the viscous drag', w: ['The weight is greater than the sum of the upthrust and the viscous drag', 'Only the viscous drag acts on the body', 'The upthrust alone balances the weight'], e: 'At terminal velocity the acceleration is zero, so the downward weight is exactly balanced by the upward upthrust plus the upward viscous drag.' },
    { q: 'What happens to the viscosity of engine oil as the engine warms up?', a: 'It decreases', w: ['It increases', 'It remains constant', 'It becomes zero'], e: 'For liquids, increasing temperature weakens the intermolecular forces between layers, so viscosity falls. This is why cold engine oil is thicker.' },
    { q: 'Which force is responsible for terminal velocity in a fluid?', a: 'Viscous drag', w: ['Upthrust only', 'Gravitational force only', 'Surface tension'], e: 'Viscous drag increases with speed until it, with the upthrust, balances the weight, at which point acceleration ceases and the velocity becomes constant.' },
  ]),
];

// ========================= PRESSURE IN FLUIDS =========================
const pressure = [
  // P = rho g h
  () => {
    const rho = pick([1000, 1030, 800, 13600]);
    const h = randInt(2, 40);
    const P = rho * G * h;
    const o = buildOptions(P, [rho * h, round(P / G, 2), P * 2], (v) => `${fmtNum(v, 2)}Pa`);
    if (!o) return null;
    return {
      text: `Calculate the pressure at a depth of ${h}m in a liquid of density ${rho}kg/m³. [Take \\(g = 10\\)m/s²]`,
      ...o,
      explanation: `\\(P = \\rho g h\\)\n\n\\(= ${rho} \\times 10 \\times ${h} = ${P}\\)Pa`,
    };
  },
  // P = F/A
  () => {
    const F = randInt(20, 500), A = pick([0.1, 0.2, 0.25, 0.5, 2, 4]);
    const P = F / A;
    const o = buildOptions(round(P, 2), [round(A / F, 4), F * A, round(P * 2, 2)], (v) => `${fmtNum(v, 2)}Pa`);
    if (!o) return null;
    return {
      text: `A force of ${F}N acts normally on a surface of area ${A}m². Calculate the pressure exerted.`,
      ...o,
      explanation: `\\(P = \\frac{F}{A}\\)\n\n\\(= \\frac{${F}}{${A}} = ${fmtNum(P, 2)}\\)Pa`,
    };
  },
  // depth from pressure
  () => {
    const rho = 1000, h = randInt(2, 40);
    const P = rho * G * h;
    const o = buildOptions(h, [round(P / rho, 2), h * 2, h + 5], (v) => `${fmtNum(v, 2)}m`);
    if (!o) return null;
    return {
      text: `At what depth in water is the pressure ${P}Pa? [Density of water = 1000kg/m³, \\(g = 10\\)m/s²]`,
      ...o,
      explanation: `\\(P = \\rho g h\\)\n\n\\(${P} = 1000 \\times 10 \\times h\\)\n\n\\(h = \\frac{${P}}{10000} = ${h}\\)m`,
    };
  },
  // hydraulic press
  () => {
    const a1 = pick([2, 4, 5, 10]), a2 = a1 * randInt(2, 10);
    const f1 = randInt(10, 100);
    const f2 = f1 * a2 / a1;
    const o = buildOptions(f2, [f1, round(f1 * a1 / a2, 2), f2 * 2], (v) => `${fmtNum(v, 2)}N`);
    if (!o) return null;
    return {
      text: `In a hydraulic press, a force of ${f1}N is applied to a piston of area ${a1}cm². Calculate the force produced on a second piston of area ${a2}cm².`,
      ...o,
      explanation: `Pressure is transmitted equally throughout the fluid.\n\n\\(\\frac{F_1}{A_1} = \\frac{F_2}{A_2}\\)\n\n\\(F_2 = \\frac{${f1} \\times ${a2}}{${a1}} = ${f2}\\)N`,
    };
  },
  ...conceptGens('pressure in fluids', [
    'Pressure in a liquid increases with depth',
    'Pressure at a point in a liquid acts equally in all directions',
    'Pressure in a liquid depends on the density of the liquid',
    'Pressure in a liquid is independent of the shape of the containing vessel',
    'The SI unit of pressure is the pascal',
    'Pascal\'s principle states that pressure applied to an enclosed fluid is transmitted equally throughout the fluid',
  ], [
    'Pressure in a liquid decreases with depth',
    'Pressure in a liquid acts only downwards',
    'Pressure in a liquid depends on the shape of the container',
    'The SI unit of pressure is the newton',
    'Pressure in a liquid is independent of the density of the liquid',
    'Liquids cannot transmit pressure',
  ]),
];

// ============= ARCHIMEDES' PRINCIPLE AND FLOTATION =============
const archimedes = [
  // upthrust = weight of displaced liquid
  () => {
    const V = pick([0.001, 0.002, 0.005, 0.01]);
    const rho = pick([1000, 800, 13600]);
    const U = rho * G * V;
    const o = buildOptions(round(U, 2), [round(rho * V, 2), round(U * 2, 2), round(V * G, 4)], (v) => `${fmtNum(v, 2)}N`);
    if (!o) return null;
    return {
      text: `A body of volume ${V}m³ is fully immersed in a liquid of density ${rho}kg/m³. Calculate the upthrust on it. [Take \\(g = 10\\)m/s²]`,
      ...o,
      explanation: `Upthrust equals the weight of the liquid displaced.\n\n\\(U = \\rho V g = ${rho} \\times ${V} \\times 10 = ${fmtNum(U, 2)}\\)N`,
    };
  },
  // apparent weight
  () => {
    const W = randInt(20, 200), U = randInt(2, W - 5);
    const app = W - U;
    const o = buildOptions(app, [W + U, U, round(W / U, 2)], (v) => `${fmtNum(v, 2)}N`);
    if (!o) return null;
    return {
      text: `A body weighs ${W}N in air. When fully immersed in water it experiences an upthrust of ${U}N. What is its apparent weight in water?`,
      ...o,
      explanation: `Apparent weight \\(= \\text{weight in air} - \\text{upthrust}\\)\n\n\\(= ${W} - ${U} = ${app}\\)N`,
    };
  },
  // upthrust from weight loss
  () => {
    const W = randInt(30, 250), app = randInt(5, W - 5);
    const U = W - app;
    const o = buildOptions(U, [W + app, app, round(W / app, 2)], (v) => `${fmtNum(v, 2)}N`);
    if (!o) return null;
    return {
      text: `A metal block weighs ${W}N in air and ${app}N when completely immersed in water. Calculate the upthrust acting on it.`,
      ...o,
      explanation: `Upthrust is the apparent loss in weight.\n\n\\(U = ${W} - ${app} = ${U}\\)N`,
    };
  },
  // relative density by weighings
  () => {
    const W = randInt(40, 200);
    const rd = pick([2, 2.5, 4, 5, 8]);
    const U = W / rd;
    const app = W - U;
    if (!Number.isInteger(app)) return null;
    const o = buildOptions(rd, [round(W / app, 2), round(U / W, 3), rd + 1], (v) => fmtNum(v, 2));
    if (!o) return null;
    return {
      text: `A solid weighs ${W}N in air and ${app}N in water. Calculate its relative density.`,
      ...o,
      explanation: `Upthrust \\(= ${W} - ${app} = ${U}\\)N\n\nRelative density \\(= \\frac{\\text{weight in air}}{\\text{apparent loss in weight}}\\)\n\n\\(= \\frac{${W}}{${U}} = ${rd}\\)`,
    };
  },
  ...conceptGens("Archimedes' principle and flotation", [
    'Archimedes\' principle states that the upthrust equals the weight of fluid displaced',
    'A floating body displaces its own weight of fluid',
    'A body floats if its density is less than that of the fluid',
    'The apparent loss in weight of an immersed body equals the upthrust on it',
    'The law of flotation states that a floating body displaces its own weight of the fluid in which it floats',
    'Upthrust acts vertically upwards through the centre of gravity of the displaced fluid',
  ], [
    'Upthrust equals the weight of the body itself',
    'A body floats if its density is greater than that of the fluid',
    'Upthrust acts vertically downwards',
    'A floating body displaces its own volume of fluid regardless of density',
    'Archimedes\' principle applies only to liquids and never to gases',
    'The apparent weight of an immersed body is greater than its weight in air',
  ]),
];

// ============================ LATENT HEAT ============================
const latentHeat = [
  // Q = mL fusion
  () => {
    const m = pick([0.1, 0.2, 0.5, 1, 2, 2.5, 4, 5]);
    const Lf = 336000;
    const Q = m * Lf;
    const o = buildOptions(Q, [round(Q / 2, 2), round(m * 4200, 2), Q * 2], (v) => `${Number(v).toExponential(2)} J`);
    if (!o) return null;
    return {
      text: `Calculate the quantity of heat required to melt ${m}kg of ice at 0°C. [Specific latent heat of fusion of ice = \\(3.36 \\times 10^{5}\\) J/kg]`,
      ...o,
      explanation: `\\(Q = mL_f\\)\n\n\\(= ${m} \\times 3.36 \\times 10^{5} = ${Q.toExponential(2)}\\) J`,
    };
  },
  // Q = mL vaporisation
  () => {
    const m = pick([0.1, 0.2, 0.5, 1, 2, 3]);
    const Lv = 2260000;
    const Q = m * Lv;
    const o = buildOptions(Q, [round(m * 336000, 2), round(Q / 2, 2), Q * 2], (v) => `${Number(v).toExponential(2)} J`);
    if (!o) return null;
    return {
      text: `Calculate the heat required to convert ${m}kg of water at 100°C into steam at 100°C. [Specific latent heat of vaporisation of water = \\(2.26 \\times 10^{6}\\) J/kg]`,
      ...o,
      explanation: `\\(Q = mL_v\\)\n\n\\(= ${m} \\times 2.26 \\times 10^{6} = ${Q.toExponential(2)}\\) J`,
    };
  },
  // find L
  () => {
    const m = pick([0.5, 1, 2, 4]);
    const Lval = pick([200000, 336000, 450000]);
    const Q = m * Lval;
    const o = buildOptions(Lval, [round(Q * m, 0), round(m / Q, 8), Lval * 2], (v) => `${Number(v).toExponential(2)} J/kg`);
    if (!o) return null;
    return {
      text: `${Q.toExponential(2)} J of heat completely melts ${m}kg of a solid at its melting point. Calculate the specific latent heat of fusion of the solid.`,
      ...o,
      explanation: `\\(Q = mL\\)\n\n\\(L = \\frac{Q}{m} = \\frac{${Q.toExponential(2)}}{${m}} = ${Lval.toExponential(2)}\\) J/kg`,
    };
  },
  ...conceptGens('latent heat', [
    'Latent heat is absorbed or released without any change in temperature',
    'Specific latent heat of fusion is the heat required to change unit mass of a solid to liquid at constant temperature',
    'Specific latent heat of vaporisation is the heat required to change unit mass of a liquid to vapour at constant temperature',
    'The specific latent heat of vaporisation of water is greater than its specific latent heat of fusion',
    'Latent heat is used to overcome intermolecular forces during a change of state',
    'The SI unit of specific latent heat is the joule per kilogram',
  ], [
    'Latent heat always causes a rise in temperature',
    'Latent heat of fusion is greater than latent heat of vaporisation for water',
    'The SI unit of specific latent heat is the joule per kelvin',
    'During melting the temperature of a pure substance rises steadily',
    'Latent heat is released when a solid melts',
    'Specific latent heat depends on the shape of the substance',
  ]),
];

// ============================== GAS LAWS ==============================
const gasLaws = [
  // Boyle's law
  () => {
    const p1 = randInt(1, 10) * 100, v1 = randInt(2, 20);
    const v2 = randInt(2, 20);
    if (v1 === v2) return null;
    const p2 = p1 * v1 / v2;
    if (!Number.isInteger(p2)) return null;
    const o = buildOptions(p2, [round(p1 * v2 / v1, 2), p1, p2 * 2], (v) => `${fmtNum(v, 2)}Pa`);
    if (!o) return null;
    return {
      text: `A gas at a pressure of ${p1}Pa occupies a volume of ${v1}m³. If the volume is changed to ${v2}m³ at constant temperature, calculate the new pressure.`,
      ...o,
      explanation: `By Boyle's law, \\(P_1V_1 = P_2V_2\\) at constant temperature.\n\n\\(${p1} \\times ${v1} = P_2 \\times ${v2}\\)\n\n\\(P_2 = \\frac{${p1 * v1}}{${v2}} = ${p2}\\)Pa`,
    };
  },
  // Charles' law
  () => {
    const t1 = pick([273, 300, 320, 400]), v1 = randInt(2, 20);
    const t2 = pick([273, 300, 320, 400, 500, 600]);
    if (t1 === t2) return null;
    const v2 = v1 * t2 / t1;
    const o = buildOptions(round(v2, 3), [round(v1 * t1 / t2, 3), v1, round(v2 * 2, 3)], (v) => `${fmtNum(v, 3)}m³`);
    if (!o) return null;
    return {
      text: `A gas occupies ${v1}m³ at ${t1}K. What volume will it occupy at ${t2}K if the pressure remains constant?`,
      ...o,
      explanation: `By Charles' law, \\(\\frac{V_1}{T_1} = \\frac{V_2}{T_2}\\) at constant pressure.\n\n\\(V_2 = \\frac{V_1 T_2}{T_1} = \\frac{${v1} \\times ${t2}}{${t1}} = ${fmtNum(v2, 3)}\\)m³`,
    };
  },
  // pressure law
  () => {
    const t1 = pick([273, 300, 350, 400]), p1 = randInt(1, 10) * 100;
    const t2 = pick([273, 300, 350, 400, 500, 600]);
    if (t1 === t2) return null;
    const p2 = p1 * t2 / t1;
    const o = buildOptions(round(p2, 2), [round(p1 * t1 / t2, 2), p1, round(p2 * 2, 2)], (v) => `${fmtNum(v, 2)}Pa`);
    if (!o) return null;
    return {
      text: `The pressure of a fixed mass of gas at ${t1}K is ${p1}Pa. Calculate its pressure at ${t2}K if the volume is kept constant.`,
      ...o,
      explanation: `By the pressure law, \\(\\frac{P_1}{T_1} = \\frac{P_2}{T_2}\\) at constant volume.\n\n\\(P_2 = \\frac{${p1} \\times ${t2}}{${t1}} = ${fmtNum(p2, 2)}\\)Pa`,
    };
  },
  // general gas equation
  () => {
    const p1 = randInt(1, 8) * 100, v1 = randInt(2, 12), t1 = pick([273, 300, 400]);
    const p2 = randInt(1, 8) * 100, t2 = pick([273, 300, 400, 600]);
    const v2 = p1 * v1 * t2 / (t1 * p2);
    const o = buildOptions(round(v2, 3), [round(v1 * p2 / p1, 3), v1, round(v2 * 2, 3)], (v) => `${fmtNum(v, 3)}m³`);
    if (!o) return null;
    return {
      text: `A gas occupies ${v1}m³ at ${p1}Pa and ${t1}K. Calculate its volume at ${p2}Pa and ${t2}K.`,
      ...o,
      explanation: `Using the general gas equation \\(\\frac{P_1V_1}{T_1} = \\frac{P_2V_2}{T_2}\\):\n\n\\(V_2 = \\frac{P_1V_1T_2}{T_1P_2} = \\frac{${p1} \\times ${v1} \\times ${t2}}{${t1} \\times ${p2}} = ${fmtNum(v2, 3)}\\)m³`,
    };
  },
  ...conceptGens('the gas laws', [
    'Boyle\'s law states that the pressure of a fixed mass of gas is inversely proportional to its volume at constant temperature',
    'Charles\' law states that the volume of a fixed mass of gas is directly proportional to its absolute temperature at constant pressure',
    'Absolute zero is 0K, equivalent to -273°C',
    'In gas law calculations temperature must be expressed in kelvin',
    'The pressure law states that pressure is directly proportional to absolute temperature at constant volume',
    'An ideal gas obeys the gas laws at all temperatures and pressures',
  ], [
    'Boyle\'s law states that pressure is directly proportional to volume',
    'Charles\' law applies at constant volume',
    'Absolute zero is 0°C',
    'Temperature may be used in degrees Celsius in gas law calculations',
    'The pressure law states that pressure is inversely proportional to temperature',
    'Gas laws apply only to liquids',
  ]),
];

// =========== HEAT CAPACITY AND SPECIFIC HEAT CAPACITY ===========
const heatCapacity = [
  // Q = m c dtheta
  () => {
    const m = pick([0.5, 1, 2, 2.5, 4, 5]);
    const c = pick([400, 450, 900, 4200, 130]);
    const dt = randInt(5, 80);
    const Q = m * c * dt;
    const o = buildOptions(Q, [round(m * c, 2), round(c * dt, 2), Q * 2], (v) => `${fmtNum(v, 2)}J`);
    if (!o) return null;
    return {
      text: `Calculate the quantity of heat required to raise the temperature of ${m}kg of a substance of specific heat capacity ${c}J/kg·K by ${dt}K.`,
      ...o,
      explanation: `\\(Q = mc\\Delta\\theta\\)\n\n\\(= ${m} \\times ${c} \\times ${dt} = ${Q}\\)J`,
    };
  },
  // find c
  () => {
    const m = pick([0.5, 1, 2, 4]);
    const c = pick([400, 450, 900, 4200]);
    const dt = randInt(5, 50);
    const Q = m * c * dt;
    const o = buildOptions(c, [round(Q / m, 2), round(Q / dt, 2), c * 2], (v) => `${fmtNum(v, 2)}J/kg·K`);
    if (!o) return null;
    return {
      text: `${Q}J of heat raises the temperature of ${m}kg of a substance by ${dt}K. Calculate its specific heat capacity.`,
      ...o,
      explanation: `\\(c = \\frac{Q}{m\\Delta\\theta}\\)\n\n\\(= \\frac{${Q}}{${m} \\times ${dt}} = ${c}\\)J/kg·K`,
    };
  },
  // temperature rise
  () => {
    const m = pick([0.5, 1, 2, 4]);
    const c = pick([400, 900, 4200]);
    const dt = randInt(5, 50);
    const Q = m * c * dt;
    const o = buildOptions(dt, [round(Q / c, 3), round(Q / m, 2), dt * 2], (v) => `${fmtNum(v, 2)}K`);
    if (!o) return null;
    return {
      text: `${Q}J of heat is supplied to ${m}kg of a substance of specific heat capacity ${c}J/kg·K. Calculate the rise in temperature.`,
      ...o,
      explanation: `\\(\\Delta\\theta = \\frac{Q}{mc}\\)\n\n\\(= \\frac{${Q}}{${m} \\times ${c}} = ${dt}\\)K`,
    };
  },
  // heat capacity
  () => {
    const m = pick([0.5, 1, 2, 3, 5]);
    const c = pick([400, 450, 900, 4200]);
    const C = m * c;
    const o = buildOptions(C, [c, round(c / m, 2), C * 2], (v) => `${fmtNum(v, 2)}J/K`);
    if (!o) return null;
    return {
      text: `Calculate the heat capacity of ${m}kg of a substance whose specific heat capacity is ${c}J/kg·K.`,
      ...o,
      explanation: `Heat capacity \\(C = mc\\)\n\n\\(= ${m} \\times ${c} = ${C}\\)J/K`,
    };
  },
  ...conceptGens('heat capacity', [
    'Specific heat capacity is the heat required to raise the temperature of unit mass of a substance by one kelvin',
    'Heat capacity is the product of mass and specific heat capacity',
    'The SI unit of specific heat capacity is the joule per kilogram per kelvin',
    'Water has an unusually high specific heat capacity',
    'The SI unit of heat capacity is the joule per kelvin',
    'A substance with a high specific heat capacity heats up slowly',
  ], [
    'Specific heat capacity is measured in joules per kelvin',
    'Heat capacity is independent of the mass of the body',
    'Water has a very low specific heat capacity',
    'Specific heat capacity is the heat needed to change the state of a substance',
    'A substance with a high specific heat capacity heats up very quickly',
    'Heat capacity and specific heat capacity are the same quantity',
  ]),
];

// =========================== HEAT TRANSFER ===========================
const heatTransfer = [
  ...conceptGens('heat transfer', [
    'Conduction is the transfer of heat through a material without bulk movement of the material',
    'Convection involves the actual movement of the heated fluid',
    'Radiation does not require a material medium',
    'Metals are good conductors of heat because of their free electrons',
    'Heat from the Sun reaches the Earth by radiation',
    'A dull black surface is a better absorber of radiation than a shiny surface',
    'A vacuum flask reduces heat loss by conduction, convection and radiation',
    'Convection currents occur because warm fluid is less dense and rises',
  ], [
    'Conduction requires the bulk movement of the material',
    'Convection can occur in solids',
    'Radiation requires a material medium to travel through',
    'Heat from the Sun reaches the Earth mainly by conduction',
    'A shiny white surface is a better absorber of radiation than a dull black one',
    'Metals are poor conductors of heat',
    'Convection currents occur because warm fluid is denser and sinks',
    'A vacuum can transmit heat by convection',
  ], [
    { q: 'By which process does heat reach the Earth from the Sun?', a: 'Radiation', w: ['Conduction', 'Convection', 'Conduction and convection'], e: 'Space between the Sun and the Earth is essentially a vacuum. Only radiation can transfer heat without a material medium.' },
    { q: 'Why is the inside of a vacuum flask silvered?', a: 'To reduce heat loss by radiation', w: ['To reduce heat loss by conduction', 'To reduce heat loss by convection', 'To increase heat absorption'], e: 'Silvered surfaces are poor emitters and good reflectors of radiation, so silvering the walls minimises radiative heat loss.' },
    { q: 'Why are cooking pots often made of metal but with wooden handles?', a: 'Metal conducts heat well while wood is a poor conductor', w: ['Wood conducts heat better than metal', 'Wood is stronger than metal', 'Metal is a poor conductor of heat'], e: 'The metal body conducts heat efficiently to the food, while the wooden handle, being a poor conductor, stays cool enough to hold.' },
    { q: 'Which method of heat transfer is responsible for land and sea breezes?', a: 'Convection', w: ['Conduction', 'Radiation', 'Evaporation'], e: 'Unequal heating of land and sea sets up density differences in the air, producing convection currents that we feel as breezes.' },
  ]),
];

// ========= EVAPORATION, BOILING AND VAPOUR PRESSURE =========
const evaporation = [
  ...conceptGens('evaporation and boiling', [
    'Evaporation takes place at all temperatures',
    'Boiling occurs at a fixed temperature for a given pressure',
    'Evaporation takes place only at the surface of a liquid',
    'Boiling takes place throughout the liquid',
    'Evaporation causes cooling of the remaining liquid',
    'An increase in external pressure raises the boiling point of a liquid',
    'A liquid boils when its saturated vapour pressure equals the external pressure',
    'Increasing the surface area increases the rate of evaporation',
  ], [
    'Evaporation occurs only at the boiling point',
    'Boiling can occur at any temperature',
    'Evaporation takes place throughout the body of the liquid',
    'Evaporation causes heating of the remaining liquid',
    'An increase in external pressure lowers the boiling point',
    'A liquid boils when its vapour pressure is zero',
    'Reducing surface area increases the rate of evaporation',
    'Boiling takes place only at the surface of a liquid',
  ], [
    { q: 'Why does water boil at a lower temperature on a high mountain?', a: 'Atmospheric pressure is lower at high altitude', w: ['Atmospheric pressure is higher at high altitude', 'Water is purer at high altitude', 'The air is colder at high altitude'], e: 'A liquid boils when its saturated vapour pressure equals the external pressure. Lower atmospheric pressure at altitude means this is reached at a lower temperature.' },
    { q: 'Why does a wet cloth placed on a patient help to reduce fever?', a: 'Evaporation of water from the cloth absorbs heat and produces cooling', w: ['The cloth conducts heat into the body', 'Water has a low specific heat capacity', 'The cloth reflects radiation onto the body'], e: 'The most energetic molecules escape during evaporation, taking latent heat with them, which lowers the temperature of what remains.' },
    { q: 'Which of the following increases the rate of evaporation of a liquid?', a: 'Increasing the temperature of the liquid', w: ['Decreasing the surface area', 'Increasing the humidity of the surrounding air', 'Reducing air movement over the surface'], e: 'Higher temperature gives molecules more kinetic energy, so more of them can escape from the surface per second.' },
    { q: 'What is the effect of adding impurities such as salt to water on its boiling point?', a: 'The boiling point is raised', w: ['The boiling point is lowered', 'The boiling point is unchanged', 'The water no longer boils'], e: 'Dissolved impurities lower the saturated vapour pressure at a given temperature, so a higher temperature is needed for boiling.' },
  ]),
];

// ========================= THERMAL EXPANSION =========================
const expansion = [
  // linear expansion
  () => {
    const l0 = randInt(1, 20);
    const alpha = pick([1.2e-5, 1.9e-5, 2.4e-5, 1.1e-5]);
    const dt = randInt(10, 100);
    const dl = l0 * alpha * dt;
    const o = buildOptions(dl, [round(l0 * alpha, 8), round(dl * 2, 8), round(alpha * dt, 8)],
      (v) => `${Number(v).toExponential(2)} m`);
    if (!o) return null;
    return {
      text: `A metal rod of length ${l0}m and linear expansivity \\(${alpha.toExponential(1)}\\)/K is heated through ${dt}K. Calculate the increase in its length.`,
      ...o,
      explanation: `\\(\\Delta l = l_0 \\alpha \\Delta\\theta\\)\n\n\\(= ${l0} \\times ${alpha.toExponential(1)} \\times ${dt} = ${dl.toExponential(2)}\\) m`,
    };
  },
  // find linear expansivity
  () => {
    const l0 = randInt(1, 10);
    const alpha = pick([1.2e-5, 2.0e-5, 2.5e-5]);
    const dt = randInt(20, 100);
    const dl = l0 * alpha * dt;
    const o = buildOptions(alpha, [round(alpha * 2, 8), round(dl / l0, 8), round(alpha / 2, 8)],
      (v) => `${Number(v).toExponential(1)}/K`);
    if (!o) return null;
    return {
      text: `A rod ${l0}m long expands by ${dl.toExponential(2)}m when heated through ${dt}K. Calculate its linear expansivity.`,
      ...o,
      explanation: `\\(\\alpha = \\frac{\\Delta l}{l_0 \\Delta\\theta}\\)\n\n\\(= \\frac{${dl.toExponential(2)}}{${l0} \\times ${dt}} = ${alpha.toExponential(1)}\\)/K`,
    };
  },
  // relation between expansivities
  () => {
    const alpha = pick([1.2e-5, 1.9e-5, 2.4e-5]);
    const kind = pick([
      { d: 'area (superficial) expansivity', f: 2 },
      { d: 'volume (cubic) expansivity', f: 3 },
    ]);
    const correct = alpha * kind.f;
    const o = buildOptions(correct, [alpha, alpha * (kind.f === 2 ? 3 : 2), alpha / kind.f],
      (v) => `${Number(v).toExponential(1)}/K`);
    if (!o) return null;
    return {
      text: `A material has a linear expansivity of \\(${alpha.toExponential(1)}\\)/K. Calculate its ${kind.d}.`,
      ...o,
      explanation: `${kind.f === 2 ? 'Area expansivity \\(\\beta = 2\\alpha\\)' : 'Volume expansivity \\(\\gamma = 3\\alpha\\)'}\n\n\\(= ${kind.f} \\times ${alpha.toExponential(1)} = ${correct.toExponential(1)}\\)/K`,
    };
  },
  ...conceptGens('thermal expansion', [
    'Most solids expand when heated and contract when cooled',
    'Cubic expansivity is three times the linear expansivity for the same material',
    'Area expansivity is twice the linear expansivity for the same material',
    'Expansion gaps are left in railway lines to allow for thermal expansion',
    'A bimetallic strip bends when heated because the two metals have different expansivities',
    'Water shows anomalous expansion between 0°C and 4°C',
    'Linear expansivity has the unit per kelvin',
  ], [
    'All substances contract when heated',
    'Cubic expansivity is half the linear expansivity',
    'Linear expansivity is measured in metres',
    'A bimetallic strip stays straight when heated',
    'Water contracts continuously as it is cooled from 10°C to 0°C',
    'Expansion gaps in bridges serve no useful purpose',
  ]),
];

// ===================== TEMPERATURE AND THERMOMETERS =====================
const temperature = [
  // Celsius to Kelvin
  () => {
    const c = randInt(-50, 200);
    const k = c + 273;
    const o = buildOptions(k, [c - 273, 273 - c, k + 100], (v) => `${v}K`);
    if (!o) return null;
    return {
      text: `Convert ${c}°C to kelvin.`,
      ...o,
      explanation: `\\(T(K) = \\theta(°C) + 273\\)\n\n\\(= ${c} + 273 = ${k}\\)K`,
    };
  },
  // Kelvin to Celsius
  () => {
    const k = randInt(200, 600);
    const c = k - 273;
    const o = buildOptions(c, [k + 273, 273 - k, c + 50], (v) => `${v}°C`);
    if (!o) return null;
    return {
      text: `Convert ${k}K to degrees Celsius.`,
      ...o,
      explanation: `\\(\\theta(°C) = T(K) - 273\\)\n\n\\(= ${k} - 273 = ${c}\\)°C`,
    };
  },
  // Celsius to Fahrenheit
  () => {
    const c = pick([0, 5, 10, 20, 25, 35, 37, 40, 50, 60, 80, 100]);
    const f = c * 9 / 5 + 32;
    const o = buildOptions(f, [c * 5 / 9 + 32, c + 32, round(f * 2, 2)], (v) => `${fmtNum(v, 2)}°F`);
    if (!o) return null;
    return {
      text: `Convert ${c}°C to degrees Fahrenheit.`,
      ...o,
      explanation: `\\(F = \\frac{9}{5}C + 32\\)\n\n\\(= \\frac{9}{5}(${c}) + 32 = ${c * 9 / 5} + 32 = ${fmtNum(f, 2)}\\)°F`,
    };
  },
  // thermometer scale reading
  () => {
    const l0 = randInt(2, 8), l100 = randInt(20, 30), lt = randInt(l0 + 1, l100 - 1);
    const theta = (lt - l0) / (l100 - l0) * 100;
    const o = buildOptions(round(theta, 2), [round(lt / l100 * 100, 2), lt, round(theta + 10, 2)], (v) => `${fmtNum(v, 2)}°C`);
    if (!o) return null;
    return {
      text: `The mercury column of a thermometer is ${l0}cm at the ice point and ${l100}cm at the steam point. What temperature corresponds to a length of ${lt}cm?`,
      ...o,
      explanation: `\\(\\theta = \\frac{l_\\theta - l_0}{l_{100} - l_0} \\times 100\\)\n\n\\(= \\frac{${lt} - ${l0}}{${l100} - ${l0}} \\times 100 = ${fmtNum(theta, 2)}\\)°C`,
    };
  },
  ...conceptGens('temperature and thermometers', [
    'The ice point and the steam point are the two fixed points of the Celsius scale',
    'Mercury is used in thermometers because it expands uniformly and does not wet glass',
    'A clinical thermometer has a constriction to prevent mercury from flowing back',
    'The kelvin is the SI unit of thermodynamic temperature',
    'A thermocouple thermometer uses the emf generated at a junction of two dissimilar metals',
    'Temperature measures the degree of hotness of a body',
  ], [
    'Temperature and heat are the same physical quantity',
    'Water is the best liquid for thermometers because it wets glass',
    'The SI unit of temperature is the degree Celsius',
    'A clinical thermometer has no constriction',
    'Mercury is used because it contracts when heated',
    'The steam point is at 0°C on the Celsius scale',
  ]),
];

// ======================== THERMAL CONDUCTIVITY ========================
const conductivity = [
  // rate of heat flow
  () => {
    const k = pick([200, 400, 80, 1.0]);
    const A = pick([0.01, 0.02, 0.05, 0.1]);
    const dt = randInt(10, 100);
    const L = pick([0.01, 0.02, 0.05, 0.1]);
    const Q = k * A * dt / L;
    const o = buildOptions(round(Q, 2), [round(k * A * dt * L, 2), round(k * dt / L, 2), round(Q * 2, 2)],
      (v) => `${fmtNum(v, 2)}W`);
    if (!o) return null;
    return {
      text: `Calculate the rate of heat flow through a slab of thermal conductivity ${k}W/m·K, cross-sectional area ${A}m² and thickness ${L}m, when the temperature difference across it is ${dt}K.`,
      ...o,
      explanation: `\\(\\frac{Q}{t} = \\frac{kA\\Delta\\theta}{L}\\)\n\n\\(= \\frac{${k} \\times ${A} \\times ${dt}}{${L}} = ${fmtNum(Q, 2)}\\)W`,
    };
  },
  ...conceptGens('thermal conductivity', [
    'Metals are generally good conductors of heat',
    'Thermal conductivity is measured in watts per metre per kelvin',
    'The rate of heat flow is proportional to the temperature gradient',
    'Good conductors of heat are usually good conductors of electricity',
    'Air is a poor conductor of heat, which is why it is used for insulation',
    'The rate of heat flow through a slab is inversely proportional to its thickness',
    'Wood, plastic and glass are poor conductors of heat',
  ], [
    'Non-metals are generally better conductors of heat than metals',
    'Thermal conductivity has no unit',
    'The rate of heat flow is independent of the temperature difference',
    'Air is an excellent conductor of heat',
    'The rate of heat flow is directly proportional to the thickness of the material',
    'Good conductors of heat are always poor conductors of electricity',
  ]),
];

module.exports = [
  { topicId: 'b9TAmN0G2sIAAtEPACfZ', unitId: U_FLUID, topicName: 'Density and Relative Density', generators: density },
  { topicId: 'yH1qhzlV8NslIQq7rUDg', unitId: U_FLUID, topicName: 'Viscosity', generators: viscosity },
  { topicId: 'N2E6aTipKBIosbsEPc2e', unitId: U_FLUID, topicName: 'Pressure in Fluids', generators: pressure },
  { topicId: '0r29xoxX3rMLnptUTADo', unitId: U_FLUID, topicName: 'Archimedes Principle and Flotation', generators: archimedes },
  { topicId: 'LmcEE2bxbMAeEAdi60gZ', unitId: U_HEAT, topicName: 'Latent Heat', generators: latentHeat },
  { topicId: 'xram2Mm6pcvvV5fg5KYx', unitId: U_HEAT, topicName: 'Gas Laws', generators: gasLaws },
  { topicId: 'RPYiePsAm4yjFGtXMaJs', unitId: U_HEAT, topicName: 'Heat Capacity and Specific Heat Capacity', generators: heatCapacity },
  { topicId: 'nLOqT5rMxf3BCMjSEVB4', unitId: U_HEAT, topicName: 'Heat Transfer', generators: heatTransfer },
  { topicId: '9AqXRCeX7GNApF5KYIZH', unitId: U_HEAT, topicName: 'Evaporation Boiling and Vapour Pressure', generators: evaporation },
  { topicId: '4e9K0pbkSjKkaCbBThYK', unitId: U_HEAT, topicName: 'Thermal Expansion', generators: expansion },
  { topicId: 'aMuKLCSJUpLDzndBQmKM', unitId: U_HEAT, topicName: 'Temperature and Thermometers', generators: temperature },
  { topicId: 'k1G0BGQNWSqVIvw1kXUH', unitId: U_HEAT, topicName: 'Thermal Conductivity', generators: conductivity },
];
