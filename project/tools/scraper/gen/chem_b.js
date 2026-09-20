// Chemistry > Chemical Reactions, Acids Bases and Salts, Energy and Rates, Electrochemistry
const L = require('./lib');
const { randInt, pick, shuffle, sample, nonZero, gcd, frac, fracTex, fracOpt,
        fmtNum, buildOptions, textOptions, round } = L;
const { conceptGens, qaBank } = require('./concept');

const U_REACT = 'Chemical Reactions';
const U_ACID = 'Acids, Bases and Salts';
const U_ENERGY = 'Energy and Rates';
const U_ELEC = 'Electrochemistry';
const mathOpt = (s) => `\\(${s}\\)`;

// relative molecular masses used throughout
const RMM = {
  'H_{2}O': 18, 'CO_{2}': 44, 'NaCl': 58.5, 'CaCO_{3}': 100, 'H_{2}SO_{4}': 98,
  'HCl': 36.5, 'NaOH': 40, 'KOH': 56, 'NH_{3}': 17, 'CH_{4}': 16,
  'O_{2}': 32, 'N_{2}': 28, 'H_{2}': 2, 'CuO': 80, 'MgO': 40,
};
const FARADAY = 96500;

// ==================== WRITING AND BALANCING EQUATIONS ====================
const EQUATIONS = [
  { eq: '\\_ H_{2} + O_{2} \\rightarrow \\_ H_{2}O', ans: '2, 1, 2', w: ['1, 1, 1', '2, 2, 2', '1, 2, 1'], e: 'Balancing hydrogen and oxygen gives \\(2H_2 + O_2 \\rightarrow 2H_2O\\).' },
  { eq: '\\_ Na + Cl_{2} \\rightarrow \\_ NaCl', ans: '2, 1, 2', w: ['1, 1, 1', '2, 2, 2', '1, 1, 2'], e: 'Chlorine is diatomic, so \\(2Na + Cl_2 \\rightarrow 2NaCl\\).' },
  { eq: '\\_ CH_{4} + O_{2} \\rightarrow CO_{2} + \\_ H_{2}O', ans: '1, 2, 1, 2', w: ['1, 1, 1, 1', '2, 2, 1, 2', '1, 2, 2, 2'], e: 'One carbon gives one \\(CO_2\\); four hydrogens give two \\(H_2O\\); that needs four oxygen atoms, so two \\(O_2\\).' },
  { eq: '\\_ CaCO_{3} \\rightarrow CaO + CO_{2}', ans: '1, 1, 1', w: ['2, 1, 1', '1, 2, 1', '2, 2, 2'], e: 'The equation is already balanced: \\(CaCO_3 \\rightarrow CaO + CO_2\\).' },
  { eq: '\\_ Fe + \\_ O_{2} \\rightarrow \\_ Fe_{2}O_{3}', ans: '4, 3, 2', w: ['2, 3, 1', '4, 2, 2', '2, 1, 1'], e: 'Four iron atoms and six oxygen atoms balance as \\(4Fe + 3O_2 \\rightarrow 2Fe_2O_3\\).' },
  { eq: '\\_ Mg + \\_ HCl \\rightarrow MgCl_{2} + H_{2}', ans: '1, 2, 1, 1', w: ['1, 1, 1, 1', '2, 2, 1, 1', '1, 2, 2, 1'], e: 'Two chlorides are needed for \\(MgCl_2\\), so \\(Mg + 2HCl \\rightarrow MgCl_2 + H_2\\).' },
  { eq: '\\_ N_{2} + \\_ H_{2} \\rightarrow \\_ NH_{3}', ans: '1, 3, 2', w: ['1, 1, 1', '1, 2, 2', '2, 3, 2'], e: 'The Haber process equation is \\(N_2 + 3H_2 \\rightarrow 2NH_3\\).' },
  { eq: '\\_ KClO_{3} \\rightarrow \\_ KCl + \\_ O_{2}', ans: '2, 2, 3', w: ['1, 1, 1', '2, 1, 3', '1, 1, 3'], e: 'Balancing oxygen gives \\(2KClO_3 \\rightarrow 2KCl + 3O_2\\).' },
];

const equations = [
  () => {
    const x = pick(EQUATIONS);
    const o = textOptions(x.ans, x.w);
    if (!o) return null;
    return {
      text: `Balance the equation \\(${x.eq}\\). What are the coefficients, in order?`,
      ...o,
      explanation: `Balance each element in turn so that the number of atoms of every element is the same on both sides.\n\n${x.e}\n\nThe coefficients are ${x.ans}.`,
    };
  },
  ...conceptGens('chemical equations', [
    'A balanced chemical equation has the same number of atoms of each element on both sides',
    'The law of conservation of mass requires that equations be balanced',
    'State symbols show the physical state of each substance in an equation',
    'The symbol (aq) means dissolved in water',
    'Coefficients in an equation may be changed when balancing, but formulae may not',
    'An ionic equation shows only the species that actually take part in the reaction',
  ], [
    'Subscripts within a formula may be changed in order to balance an equation',
    'A balanced equation may have different numbers of atoms on each side',
    'The symbol (s) means dissolved in water',
    'Coefficients must always be equal to one',
    'Balancing an equation changes the substances that react',
  ]),
];

// ========================== THE MOLE CONCEPT ==========================
const moleConcept = [
  // moles from mass
  () => {
    const f = pick(Object.keys(RMM));
    const m = RMM[f] * pick([0.5, 1, 2, 3, 4, 5]);
    const n = m / RMM[f];
    const o = buildOptions(n, [round(RMM[f] / m, 3), round(m * RMM[f], 1), round(n * 2, 2)], (v) => `${fmtNum(v, 2)} mol`);
    if (!o) return null;
    return {
      text: `How many moles are present in ${fmtNum(m, 1)}g of \\(${f}\\)? [Relative molecular mass of \\(${f}\\) = ${RMM[f]}]`,
      ...o,
      explanation: `\\(\\text{number of moles} = \\frac{\\text{mass}}{\\text{molar mass}}\\)\n\n\\(= \\frac{${fmtNum(m, 1)}}{${RMM[f]}} = ${fmtNum(n, 2)}\\) mol`,
    };
  },
  // mass from moles
  () => {
    const f = pick(Object.keys(RMM));
    const n = pick([0.25, 0.5, 1, 2, 3]);
    const m = n * RMM[f];
    const o = buildOptions(round(m, 2), [round(n / RMM[f], 4), RMM[f], round(m * 2, 2)], (v) => `${fmtNum(v, 2)} g`);
    if (!o) return null;
    return {
      text: `Calculate the mass of ${n} mole${n === 1 ? '' : 's'} of \\(${f}\\). [Relative molecular mass = ${RMM[f]}]`,
      ...o,
      explanation: `\\(\\text{mass} = \\text{moles} \\times \\text{molar mass}\\)\n\n\\(= ${n} \\times ${RMM[f]} = ${fmtNum(m, 2)}\\) g`,
    };
  },
  // number of particles
  () => {
    const n = pick([0.5, 1, 2, 3]);
    const N = n * 6.02e23;
    const o = buildOptions(N, [6.02e23, round(n / 6.02e23, 30), N * 2], (v) => `${Number(v).toExponential(2)}`);
    if (!o) return null;
    return {
      text: `How many molecules are present in ${n} mole${n === 1 ? '' : 's'} of a gas? [Avogadro's number = \\(6.02 \\times 10^{23}\\)]`,
      ...o,
      explanation: `One mole of any substance contains \\(6.02 \\times 10^{23}\\) particles.\n\n\\(${n} \\times 6.02 \\times 10^{23} = ${N.toExponential(2)}\\) molecules`,
    };
  },
  // volume of gas at stp from mass
  () => {
    const f = pick(['O_{2}', 'N_{2}', 'H_{2}', 'CO_{2}', 'CH_{4}']);
    const n = pick([0.5, 1, 2]);
    const m = n * RMM[f];
    const v = n * 22.4;
    const o = buildOptions(round(v, 2), [round(m, 2), round(22.4 / n, 2), round(v * 2, 2)], (x) => `${fmtNum(x, 2)} dm³`);
    if (!o) return null;
    return {
      text: `What volume at s.t.p. is occupied by ${fmtNum(m, 1)}g of \\(${f}\\)? [RMM = ${RMM[f]}, molar volume at s.t.p. = 22.4dm³]`,
      ...o,
      explanation: `Moles \\(= \\frac{${fmtNum(m, 1)}}{${RMM[f]}} = ${n}\\) mol\n\nVolume \\(= ${n} \\times 22.4 = ${fmtNum(v, 2)}\\) dm³`,
    };
  },
  // concentration in mol/dm3
  () => {
    const n = pick([0.1, 0.2, 0.25, 0.5, 1, 2]);
    const v = pick([0.25, 0.5, 1, 2]);
    const c = n / v;
    const o = buildOptions(round(c, 3), [round(v / n, 3), round(n * v, 3), round(c * 2, 3)], (x) => `${fmtNum(x, 3)} mol/dm³`);
    if (!o) return null;
    return {
      text: `Calculate the concentration of a solution containing ${n} mole${n === 1 ? '' : 's'} of solute in ${v}dm³ of solution.`,
      ...o,
      explanation: `\\(\\text{concentration} = \\frac{\\text{moles}}{\\text{volume in dm}^3}\\)\n\n\\(= \\frac{${n}}{${v}} = ${fmtNum(c, 3)}\\) mol/dm³`,
    };
  },
  ...conceptGens('the mole concept', [
    'One mole of a substance contains 6.02 times 10 to the power 23 particles',
    'The molar mass of a substance is its relative molecular mass expressed in grams',
    'One mole of any gas occupies 22.4dm³ at s.t.p.',
    'The number of moles equals the mass divided by the molar mass',
    'Avogadro\'s number is the number of particles in one mole',
    'Equal volumes of all gases at the same temperature and pressure contain the same number of molecules',
  ], [
    'One mole of a substance always weighs exactly one gram',
    'The number of moles equals the molar mass divided by the mass',
    'One mole of a solid occupies 22.4dm³',
    'Avogadro\'s number depends on the substance concerned',
    'Equal masses of all gases contain the same number of molecules',
  ]),
];

// ============================ STOICHIOMETRY ============================
const stoichiometry = [
  // simple mass-mass from a 1:1 equation
  () => {
    const n = pick([0.5, 1, 2, 4]);
    const mCaCO3 = n * 100, mCO2 = n * 44, mCaO = n * 56;
    const o = buildOptions(round(mCO2, 1), [round(mCaO, 1), round(mCaCO3, 1), round(mCO2 * 2, 1)], (v) => `${fmtNum(v, 1)} g`);
    if (!o) return null;
    return {
      text: `Calculate the mass of carbon(IV) oxide produced when ${fmtNum(mCaCO3, 1)}g of calcium trioxocarbonate(IV) decomposes completely: \\(CaCO_{3} \\rightarrow CaO + CO_{2}\\). [Ca=40, C=12, O=16]`,
      ...o,
      explanation: `\\(M_r(CaCO_3) = 100\\), \\(M_r(CO_2) = 44\\)\n\nMoles of \\(CaCO_3 = \\frac{${fmtNum(mCaCO3, 1)}}{100} = ${n}\\) mol\n\nThe equation is 1:1, so ${n} mol of \\(CO_2\\) forms.\n\nMass \\(= ${n} \\times 44 = ${fmtNum(mCO2, 1)}\\) g`,
    };
  },
  // volume of gas from mass of reactant
  () => {
    const n = pick([0.5, 1, 2]);
    const mMg = n * 24;
    const v = n * 22.4;
    const o = buildOptions(round(v, 2), [round(mMg, 1), round(v / 2, 2), round(v * 2, 2)], (x) => `${fmtNum(x, 2)} dm³`);
    if (!o) return null;
    return {
      text: `What volume of hydrogen at s.t.p. is produced when ${fmtNum(mMg, 1)}g of magnesium reacts completely with excess dilute hydrochloric acid? \\(Mg + 2HCl \\rightarrow MgCl_{2} + H_{2}\\) [Mg=24, molar volume=22.4dm³]`,
      ...o,
      explanation: `Moles of \\(Mg = \\frac{${fmtNum(mMg, 1)}}{24} = ${n}\\) mol\n\nThe equation shows 1 mol \\(Mg\\) gives 1 mol \\(H_2\\), so ${n} mol of \\(H_2\\) forms.\n\nVolume \\(= ${n} \\times 22.4 = ${fmtNum(v, 2)}\\) dm³`,
    };
  },
  // percentage composition
  () => {
    const cmp = pick([
      { f: 'H_{2}O', el: 'oxygen', part: 16, whole: 18 },
      { f: 'CaCO_{3}', el: 'calcium', part: 40, whole: 100 },
      { f: 'CO_{2}', el: 'carbon', part: 12, whole: 44 },
      { f: 'NaOH', el: 'sodium', part: 23, whole: 40 },
      { f: 'MgO', el: 'magnesium', part: 24, whole: 40 },
      { f: 'CuO', el: 'copper', part: 64, whole: 80 },
    ]);
    const pct = cmp.part / cmp.whole * 100;
    const o = buildOptions(round(pct, 2), [round(100 - pct, 2), round(cmp.whole / cmp.part * 100, 2), round(pct / 2, 2)], (v) => `${fmtNum(v, 2)}%`);
    if (!o) return null;
    return {
      text: `Calculate the percentage by mass of ${cmp.el} in \\(${cmp.f}\\). [\\(M_r = ${cmp.whole}\\)]`,
      ...o,
      explanation: `\\(\\% = \\frac{\\text{mass of element}}{\\text{molar mass}} \\times 100\\)\n\n\\(= \\frac{${cmp.part}}{${cmp.whole}} \\times 100 = ${fmtNum(pct, 2)}\\%\\)`,
    };
  },
  // empirical formula
  () => {
    const bank = [
      { pc: 'carbon 40%, hydrogen 6.7%, oxygen 53.3%', a: 'CH_{2}O', w: ['C_{2}H_{4}O_{2}', 'CHO', 'C_{2}H_{6}O'] },
      { pc: 'carbon 85.7%, hydrogen 14.3%', a: 'CH_{2}', w: ['CH_{4}', 'C_{2}H_{6}', 'CH_{3}'] },
      { pc: 'sodium 39.3%, chlorine 60.7%', a: 'NaCl', w: ['Na_{2}Cl', 'NaCl_{2}', 'Na_{2}Cl_{3}'] },
      { pc: 'magnesium 60%, oxygen 40%', a: 'MgO', w: ['Mg_{2}O', 'MgO_{2}', 'Mg_{2}O_{3}'] },
    ];
    const x = pick(bank);
    const o = textOptions(mathOpt(x.a), x.w.map(mathOpt));
    if (!o) return null;
    return {
      text: `A compound contains ${x.pc} by mass. Determine its empirical formula.`,
      ...o,
      explanation: `Divide each percentage by the relative atomic mass of the element to get the mole ratio, then divide through by the smallest value and round to the nearest whole numbers.\n\nThis gives the empirical formula \\(${x.a}\\).`,
    };
  },
  ...conceptGens('stoichiometry', [
    'The coefficients in a balanced equation give the mole ratio of the reactants and products',
    'The limiting reactant is the one completely used up first',
    'The empirical formula shows the simplest whole-number ratio of atoms in a compound',
    'The molecular formula is a whole-number multiple of the empirical formula',
    'Mass is conserved in a chemical reaction',
    'A reactant present in excess is not completely used up',
  ], [
    'The coefficients in an equation give the mass ratio of reactants directly',
    'The limiting reactant is the one present in the greatest amount',
    'The empirical formula always equals the molecular formula',
    'Mass is created during an exothermic reaction',
    'The reactant in excess determines how much product forms',
  ]),
];

// ================== LAWS OF CHEMICAL COMBINATION ==================
const combinationLaws = [
  ...conceptGens('the laws of chemical combination', [
    'The law of conservation of mass states that matter is neither created nor destroyed in a chemical reaction',
    'The law of definite proportions states that a pure compound always contains the same elements in the same proportion by mass',
    'The law of multiple proportions applies when two elements form more than one compound',
    'Gay-Lussac\'s law of combining volumes applies to gases measured at the same temperature and pressure',
    'Avogadro\'s law states that equal volumes of gases under the same conditions contain equal numbers of molecules',
    'The total mass of the products equals the total mass of the reactants',
  ], [
    'The law of conservation of mass allows mass to increase during combustion',
    'The law of definite proportions states that compounds have variable composition',
    'Avogadro\'s law states that equal masses of gases contain equal numbers of molecules',
    'Gay-Lussac\'s law applies to solids and liquids only',
    'The law of multiple proportions applies only to a single compound',
  ], [
    { q: 'Which law states that a pure chemical compound always contains the same elements combined in the same proportion by mass?', a: 'The law of definite proportions', w: ['The law of conservation of mass', 'The law of multiple proportions', 'Avogadro\'s law'], e: 'Also called the law of constant composition, it is why pure water is always 2 parts hydrogen to 16 parts oxygen by mass, whatever its source.' },
    { q: 'Which law is the basis of the statement that equal volumes of all gases at the same temperature and pressure contain the same number of molecules?', a: 'Avogadro\'s law', w: ['Boyle\'s law', 'Charles\' law', 'The law of definite proportions'], e: 'Avogadro\'s law links gas volume directly to number of molecules, which is what makes molar volume a single constant for all gases.' },
  ]),
  // conservation of mass calculation
  () => {
    const a = randInt(5, 60), b = randInt(5, 60);
    const total = a + b;
    const prod1 = randInt(2, total - 2);
    const prod2 = total - prod1;
    const o = buildOptions(prod2, [total, prod1, Math.abs(a - b)], (v) => `${v} g`);
    if (!o) return null;
    return {
      text: `${a}g of substance A reacts completely with ${b}g of substance B to form two products. If ${prod1}g of the first product is obtained, what mass of the second product is formed?`,
      ...o,
      explanation: `By the law of conservation of mass, total mass of products = total mass of reactants.\n\n\\(${a} + ${b} = ${total}\\) g\n\nMass of second product \\(= ${total} - ${prod1} = ${prod2}\\) g`,
    };
  },
];

// ==================== PROPERTIES OF ACIDS AND BASES ====================
const acidsBases = [
  ...conceptGens('acids and bases', [
    'An acid is a substance that produces hydrogen ions in aqueous solution',
    'A base is a substance that reacts with an acid to form a salt and water only',
    'An alkali is a soluble base',
    'Acids turn blue litmus paper red',
    'Alkalis turn red litmus paper blue',
    'Acids react with trioxocarbonate(IV) salts to liberate carbon(IV) oxide',
    'Acids react with reactive metals to liberate hydrogen gas',
    'A base accepts a proton according to the Bronsted-Lowry theory',
    'An amphoteric oxide reacts with both acids and alkalis',
  ], [
    'An acid produces hydroxide ions in aqueous solution',
    'Acids turn red litmus paper blue',
    'Alkalis turn blue litmus paper red',
    'All bases are soluble in water',
    'Acids react with metals to liberate oxygen gas',
    'An acid accepts a proton according to the Bronsted-Lowry theory',
    'Amphoteric oxides react with neither acids nor alkalis',
  ], [
    { q: 'Which gas is liberated when a dilute acid reacts with a trioxocarbonate(IV) salt?', a: 'Carbon(IV) oxide', w: ['Hydrogen', 'Oxygen', 'Ammonia'], e: 'Acids displace carbonic acid from carbonates, which immediately decomposes to carbon(IV) oxide and water. The gas turns limewater milky.' },
    { q: 'Which gas is produced when dilute hydrochloric acid reacts with zinc?', a: 'Hydrogen', w: ['Chlorine', 'Oxygen', 'Carbon(IV) oxide'], e: 'Zinc is above hydrogen in the activity series, so it displaces hydrogen from the acid: \\(Zn + 2HCl \\rightarrow ZnCl_2 + H_2\\).' },
    { q: 'What is an amphoteric oxide?', a: 'An oxide that reacts with both acids and alkalis to form salts', w: ['An oxide that reacts with neither acids nor alkalis', 'An oxide that dissolves only in water', 'An oxide that reacts only with acids'], e: 'Aluminium oxide and zinc oxide are amphoteric: they behave as bases towards acids and as acids towards alkalis.' },
    { q: 'Which of the following is an alkali?', a: 'Sodium hydroxide', w: ['Copper(II) oxide', 'Iron(III) oxide', 'Calcium carbonate'], e: 'An alkali is a base that dissolves in water to give hydroxide ions. Sodium hydroxide is highly soluble; the other oxides listed are not.' },
  ]),
];

// ========================== pH AND INDICATORS ==========================
const phIndicators = [
  // pH classification
  () => {
    const ph = randInt(0, 14);
    const correct = ph < 7 ? 'Acidic' : ph === 7 ? 'Neutral' : 'Alkaline';
    const o = textOptions(correct, ['Acidic', 'Neutral', 'Alkaline', 'Amphoteric'].filter(x => x !== correct).slice(0, 3));
    if (!o) return null;
    return {
      text: `A solution has a pH of ${ph}. How would you describe the solution?`,
      ...o,
      explanation: `A pH below 7 is acidic, a pH of exactly 7 is neutral and a pH above 7 is alkaline.\n\nA pH of ${ph} is therefore ${correct.toLowerCase()}.`,
    };
  },
  // pH from hydrogen ion concentration
  () => {
    const p = randInt(1, 12);
    const o = buildOptions(p, [14 - p, p + 1, -p], (v) => String(v));
    if (!o) return null;
    return {
      text: `A solution has a hydrogen ion concentration of \\(1 \\times 10^{-${p}}\\) mol/dm³. Calculate its pH.`,
      ...o,
      explanation: `\\(pH = -\\log_{10}[H^{+}]\\)\n\n\\(= -\\log_{10}(1 \\times 10^{-${p}}) = ${p}\\)`,
    };
  },
  // indicator colours
  () => {
    const bank = [
      { i: 'litmus', med: 'acid', c: 'Red', w: ['Blue', 'Colourless', 'Yellow'] },
      { i: 'litmus', med: 'alkali', c: 'Blue', w: ['Red', 'Colourless', 'Pink'] },
      { i: 'phenolphthalein', med: 'acid', c: 'Colourless', w: ['Pink', 'Blue', 'Yellow'] },
      { i: 'phenolphthalein', med: 'alkali', c: 'Pink', w: ['Colourless', 'Red', 'Blue'] },
      { i: 'methyl orange', med: 'acid', c: 'Red', w: ['Yellow', 'Blue', 'Colourless'] },
      { i: 'methyl orange', med: 'alkali', c: 'Yellow', w: ['Red', 'Blue', 'Colourless'] },
    ];
    const x = pick(bank);
    const o = textOptions(x.c, x.w);
    if (!o) return null;
    return {
      text: `What colour does ${x.i} show in ${x.med === 'acid' ? 'an acidic' : 'an alkaline'} solution?`,
      ...o,
      explanation: `${x.i.charAt(0).toUpperCase() + x.i.slice(1)} is ${x.c.toLowerCase()} in ${x.med === 'acid' ? 'acidic' : 'alkaline'} solution.`,
    };
  },
  ...conceptGens('pH and indicators', [
    'The pH scale runs from 0 to 14',
    'A pH of 7 indicates a neutral solution',
    'The lower the pH, the more acidic the solution',
    'Phenolphthalein is colourless in acid and pink in alkali',
    'Methyl orange is red in acid and yellow in alkali',
    'Universal indicator gives a range of colours showing approximate pH',
    'pH is defined as the negative logarithm to base ten of the hydrogen ion concentration',
  ], [
    'The pH scale runs from 1 to 10',
    'A pH of 0 indicates a neutral solution',
    'The higher the pH, the more acidic the solution',
    'Phenolphthalein is pink in acid and colourless in alkali',
    'Methyl orange is yellow in acid and red in alkali',
    'Universal indicator gives only one colour for all solutions',
  ]),
];

// ==================== NEUTRALISATION AND TITRATION ====================
const titration = [
  // c1v1/n1 = c2v2/n2
  () => {
    const cA = pick([0.05, 0.1, 0.2, 0.5]);
    const vA = pick([20, 25, 50]);
    const vB = pick([20, 25, 50]);
    const cB = cA * vA / vB;
    const o = buildOptions(round(cB, 4), [round(cA * vB / vA, 4), cA, round(cB * 2, 4)], (v) => `${fmtNum(v, 4)} mol/dm³`);
    if (!o) return null;
    return {
      text: `${vA}cm³ of ${cA} mol/dm³ hydrochloric acid exactly neutralises ${vB}cm³ of sodium hydroxide solution. Calculate the concentration of the sodium hydroxide. \\(HCl + NaOH \\rightarrow NaCl + H_{2}O\\)`,
      ...o,
      explanation: `The equation is 1:1, so moles of acid = moles of base.\n\n\\(C_A V_A = C_B V_B\\)\n\n\\(${cA} \\times ${vA} = C_B \\times ${vB}\\)\n\n\\(C_B = \\frac{${round(cA * vA, 4)}}{${vB}} = ${fmtNum(cB, 4)}\\) mol/dm³`,
    };
  },
  // volume needed
  () => {
    const cA = pick([0.1, 0.2, 0.25, 0.5]);
    const cB = pick([0.1, 0.2, 0.25, 0.5]);
    const vB = pick([20, 25, 50]);
    const vA = cB * vB / cA;
    const o = buildOptions(round(vA, 2), [round(cA * vB / cB, 2), vB, round(vA * 2, 2)], (v) => `${fmtNum(v, 2)} cm³`);
    if (!o) return null;
    return {
      text: `What volume of ${cA} mol/dm³ hydrochloric acid is required to neutralise ${vB}cm³ of ${cB} mol/dm³ sodium hydroxide solution?`,
      ...o,
      explanation: `For a 1:1 reaction, \\(C_A V_A = C_B V_B\\).\n\n\\(V_A = \\frac{C_B V_B}{C_A} = \\frac{${cB} \\times ${vB}}{${cA}} = ${fmtNum(vA, 2)}\\) cm³`,
    };
  },
  ...conceptGens('neutralisation and titration', [
    'Neutralisation is the reaction between an acid and a base to form a salt and water',
    'The end point of a titration is shown by a colour change in the indicator',
    'A pipette is used to measure a fixed volume accurately',
    'A burette is used to deliver a variable, measured volume',
    'Phenolphthalein is a suitable indicator for a strong acid and strong alkali titration',
    'The conical flask should be swirled continuously during a titration',
    'Concordant titre values agree to within 0.1cm³ of each other',
  ], [
    'Neutralisation produces a salt and hydrogen gas',
    'A burette is used to measure a fixed volume accurately',
    'A pipette delivers a variable volume of liquid',
    'The end point is reached when the indicator stops changing colour permanently before any acid is added',
    'Titration requires no indicator at all',
    'The conical flask should be kept perfectly still throughout',
  ]),
];

// ========================= PREPARATION OF SALTS =========================
const salts = [
  ...conceptGens('the preparation of salts', [
    'A soluble salt of a reactive metal can be prepared by reacting the metal with a dilute acid',
    'An insoluble salt is usually prepared by precipitation',
    'All trioxonitrate(V) salts are soluble in water',
    'All sodium, potassium and ammonium salts are soluble in water',
    'Silver chloride and lead(II) chloride are insoluble in cold water',
    'Barium tetraoxosulphate(VI) is insoluble in water',
    'A normal salt contains no replaceable hydrogen ions',
    'An acid salt still contains replaceable hydrogen ions',
  ], [
    'All chlorides are insoluble in water',
    'All sodium salts are insoluble in water',
    'Insoluble salts are prepared by titration',
    'All trioxonitrate(V) salts are insoluble',
    'A normal salt contains replaceable hydrogen ions',
    'Barium tetraoxosulphate(VI) is very soluble in water',
  ], [
    { q: 'Which method is most suitable for preparing an insoluble salt such as barium tetraoxosulphate(VI)?', a: 'Precipitation by mixing two soluble salt solutions', w: ['Titration with an indicator', 'Reacting the metal with dilute acid', 'Evaporating a solution of the salt'], e: 'Mixing solutions containing the two required ions precipitates the insoluble salt, which is then filtered, washed and dried.' },
    { q: 'Which method is used to prepare a soluble salt from an insoluble base?', a: 'Adding excess base to warm acid, then filtering and crystallising', w: ['Precipitation', 'Titration with phenolphthalein', 'Direct combination of the elements'], e: 'Excess insoluble base guarantees all the acid reacts; the unreacted solid is filtered off and the filtrate is crystallised.' },
    { q: 'Which of the following salts is insoluble in water?', a: 'Silver chloride', w: ['Sodium chloride', 'Potassium trioxonitrate(V)', 'Ammonium chloride'], e: 'Most chlorides are soluble, but silver, lead(II) and mercury(I) chlorides are the standard exceptions.' },
  ]),
];

// ========================= HYDROLYSIS OF SALTS =========================
const hydrolysis = [
  // salt solution pH
  () => {
    const bank = [
      { s: 'sodium chloride', from: 'a strong acid and a strong base', ph: 'Neutral' },
      { s: 'sodium ethanoate', from: 'a weak acid and a strong base', ph: 'Alkaline' },
      { s: 'ammonium chloride', from: 'a strong acid and a weak base', ph: 'Acidic' },
      { s: 'potassium trioxonitrate(V)', from: 'a strong acid and a strong base', ph: 'Neutral' },
      { s: 'sodium trioxocarbonate(IV)', from: 'a weak acid and a strong base', ph: 'Alkaline' },
      { s: 'ammonium tetraoxosulphate(VI)', from: 'a strong acid and a weak base', ph: 'Acidic' },
    ];
    const x = pick(bank);
    const o = textOptions(x.ph, ['Neutral', 'Acidic', 'Alkaline', 'Amphoteric'].filter(p => p !== x.ph).slice(0, 3));
    if (!o) return null;
    return {
      text: `What is the nature of an aqueous solution of ${x.s}?`,
      ...o,
      explanation: `${x.s.charAt(0).toUpperCase() + x.s.slice(1)} is the salt of ${x.from}.\n\nThe ion derived from the weaker partner hydrolyses in water, so the solution is ${x.ph.toLowerCase()}.`,
    };
  },
  ...conceptGens('the hydrolysis of salts', [
    'Salt hydrolysis is the reaction of the ions of a salt with water to produce an acidic or alkaline solution',
    'A salt of a strong acid and a strong base gives a neutral solution',
    'A salt of a weak acid and a strong base gives an alkaline solution',
    'A salt of a strong acid and a weak base gives an acidic solution',
    'Sodium chloride solution is neutral to litmus',
    'Ammonium chloride solution turns blue litmus red',
  ], [
    'All salt solutions are neutral',
    'A salt of a weak acid and a strong base gives an acidic solution',
    'A salt of a strong acid and a weak base gives an alkaline solution',
    'Sodium chloride solution is strongly alkaline',
    'Hydrolysis of a salt always produces a gas',
  ]),
];

// =========================== ENTHALPY CHANGES ===========================
const enthalpy = [
  // exo / endo classification
  () => {
    const dh = nonZero(-500, 500);
    const correct = dh < 0 ? 'Exothermic' : 'Endothermic';
    const o = textOptions(correct, [dh < 0 ? 'Endothermic' : 'Exothermic', 'Neutral', 'Reversible']);
    if (!o) return null;
    return {
      text: `A reaction has an enthalpy change of \\(\\Delta H = ${dh}\\)kJ/mol. What type of reaction is it?`,
      ...o,
      explanation: `A negative \\(\\Delta H\\) means heat is released to the surroundings (exothermic); a positive \\(\\Delta H\\) means heat is absorbed (endothermic).\n\nHere \\(\\Delta H = ${dh}\\)kJ/mol is ${dh < 0 ? 'negative' : 'positive'}, so the reaction is ${correct.toLowerCase()}.`,
    };
  },
  // Q = mcT
  () => {
    const m = pick([50, 100, 200, 250]);
    const c = 4.2;
    const dt = randInt(2, 40);
    const Q = m * c * dt / 1000;
    const o = buildOptions(round(Q, 2), [round(m * c * dt, 2), round(m * dt / 1000, 3), round(Q * 2, 2)], (v) => `${fmtNum(v, 2)} kJ`);
    if (!o) return null;
    return {
      text: `Calculate the heat evolved when ${m}g of water rises in temperature by ${dt}K. [Specific heat capacity of water = 4.2 J/g·K]`,
      ...o,
      explanation: `\\(Q = mc\\Delta T\\)\n\n\\(= ${m} \\times 4.2 \\times ${dt} = ${fmtNum(m * c * dt, 1)}\\) J\n\n\\(= ${fmtNum(Q, 2)}\\) kJ`,
    };
  },
  ...conceptGens('enthalpy changes', [
    'An exothermic reaction releases heat to the surroundings and has a negative enthalpy change',
    'An endothermic reaction absorbs heat from the surroundings and has a positive enthalpy change',
    'Combustion reactions are exothermic',
    'The dissolution of ammonium trioxonitrate(V) in water is endothermic',
    'Neutralisation of a strong acid by a strong base is exothermic',
    'Enthalpy change is usually measured in kilojoules per mole',
    'Bond breaking absorbs energy while bond forming releases energy',
  ], [
    'An exothermic reaction has a positive enthalpy change',
    'Combustion reactions are endothermic',
    'Bond breaking releases energy while bond forming absorbs energy',
    'Neutralisation reactions absorb heat from the surroundings',
    'Enthalpy change is measured in grams per mole',
    'An endothermic reaction causes the temperature of the surroundings to rise',
  ]),
];

// =========================== RATES OF REACTION ===========================
const rates = [
  ...conceptGens('rates of reaction', [
    'Increasing the temperature increases the rate of a reaction',
    'Increasing the concentration of a reactant increases the rate of reaction',
    'Increasing the surface area of a solid reactant increases the rate of reaction',
    'A catalyst increases the rate of reaction by providing an alternative path of lower activation energy',
    'Activation energy is the minimum energy colliding particles must have to react',
    'Increasing pressure increases the rate of a reaction involving gases',
    'A reaction occurs when particles collide with sufficient energy and correct orientation',
  ], [
    'Increasing temperature decreases the rate of reaction',
    'A catalyst increases the activation energy of a reaction',
    'Powdering a solid reactant decreases the rate of reaction',
    'Increasing concentration has no effect on reaction rate',
    'A catalyst is used up during the reaction it catalyses',
    'All collisions between reactant particles lead to a reaction',
  ], [
    { q: 'Why does powdered calcium trioxocarbonate(IV) react faster with acid than lumps of the same mass?', a: 'The powder has a much larger surface area exposed to the acid', w: ['The powder is more concentrated', 'The powder has a lower activation energy', 'The powder is at a higher temperature'], e: 'Reaction happens at the solid surface. Powdering exposes far more particles to collisions with acid at any instant, so the rate rises.' },
    { q: 'How does a catalyst speed up a chemical reaction?', a: 'By providing an alternative reaction path with a lower activation energy', w: ['By raising the temperature of the reaction mixture', 'By increasing the concentration of the reactants', 'By being consumed to release energy'], e: 'The catalyst is not used up. It lowers the energy barrier so that a greater fraction of collisions are successful at a given temperature.' },
    { q: 'Why does an increase in temperature increase the rate of reaction?', a: 'Particles move faster and a greater proportion of collisions exceed the activation energy', w: ['The activation energy of the reaction falls', 'The concentration of the reactants increases', 'The particles become larger'], e: 'Higher temperature raises average kinetic energy, so collisions are both more frequent and more often energetic enough to react.' },
  ]),
];

// ========================= CHEMICAL EQUILIBRIUM =========================
const equilibrium = [
  // Le Chatelier
  () => {
    const bank = [
      { ch: 'increasing the pressure', rxn: '\\(N_{2}(g) + 3H_{2}(g) \\rightleftharpoons 2NH_{3}(g)\\)', a: 'The equilibrium shifts to the right, producing more ammonia', w: ['The equilibrium shifts to the left', 'There is no change in the position of equilibrium', 'The reaction stops completely'], e: 'There are 4 moles of gas on the left and 2 on the right. Raising the pressure favours the side with fewer gas molecules, so equilibrium shifts right.' },
      { ch: 'increasing the temperature', rxn: 'an exothermic forward reaction', a: 'The equilibrium shifts to the left, favouring the reactants', w: ['The equilibrium shifts to the right', 'There is no change', 'The catalyst is destroyed'], e: 'For an exothermic forward reaction, raising the temperature favours the endothermic reverse direction, shifting equilibrium back towards the reactants.' },
      { ch: 'adding a catalyst', rxn: 'a reversible reaction at equilibrium', a: 'The position of equilibrium is unchanged but it is reached faster', w: ['The equilibrium shifts to the right', 'The equilibrium shifts to the left', 'The reaction becomes irreversible'], e: 'A catalyst speeds the forward and reverse reactions equally, so it changes only the time taken to reach equilibrium, not its position.' },
      { ch: 'removing the product as it forms', rxn: 'a reversible reaction at equilibrium', a: 'The equilibrium shifts to the right to replace the product', w: ['The equilibrium shifts to the left', 'There is no change', 'The reactants are destroyed'], e: 'By Le Chatelier\'s principle the system opposes the change, making more product to replace what was removed.' },
    ];
    const x = pick(bank);
    const o = textOptions(x.a, x.w);
    if (!o) return null;
    return {
      text: `What is the effect of ${x.ch} on ${x.rxn}?`,
      ...o,
      explanation: x.e,
    };
  },
  ...conceptGens('chemical equilibrium', [
    'At equilibrium the rate of the forward reaction equals the rate of the reverse reaction',
    'Chemical equilibrium is dynamic, not static',
    'Le Chatelier\'s principle states that a system at equilibrium opposes any change imposed on it',
    'A catalyst does not change the position of equilibrium',
    'Equilibrium can only be reached in a closed system',
    'The concentrations of reactants and products remain constant at equilibrium',
  ], [
    'At equilibrium the forward reaction stops completely',
    'Chemical equilibrium is static',
    'A catalyst shifts the equilibrium towards the products',
    'At equilibrium the concentrations of reactants and products are always equal',
    'Equilibrium is reached fastest in an open system',
    'Le Chatelier\'s principle states that a system reinforces any change imposed on it',
  ]),
];

// ============================== CATALYSIS ==============================
const catalysis = [
  // catalyst for a process
  () => {
    const bank = [
      { p: 'the Haber process for making ammonia', c: 'Finely divided iron', w: ['Vanadium(V) oxide', 'Platinum', 'Manganese(IV) oxide'] },
      { p: 'the Contact process for making tetraoxosulphate(VI) acid', c: 'Vanadium(V) oxide', w: ['Finely divided iron', 'Nickel', 'Manganese(IV) oxide'] },
      { p: 'the decomposition of hydrogen peroxide', c: 'Manganese(IV) oxide', w: ['Vanadium(V) oxide', 'Finely divided iron', 'Nickel'] },
      { p: 'the hydrogenation of vegetable oils', c: 'Nickel', w: ['Vanadium(V) oxide', 'Manganese(IV) oxide', 'Finely divided iron'] },
    ];
    const x = pick(bank);
    const o = textOptions(x.c, x.w);
    if (!o) return null;
    return {
      text: `Which catalyst is used in ${x.p}?`,
      ...o,
      explanation: `${x.c} is the catalyst used in ${x.p}.`,
    };
  },
  ...conceptGens('catalysis', [
    'A catalyst alters the rate of a reaction without being consumed',
    'A catalyst provides an alternative reaction path of lower activation energy',
    'A catalyst does not change the position of equilibrium',
    'Enzymes are biological catalysts',
    'A negative catalyst or inhibitor slows down a reaction',
    'A catalyst is chemically unchanged at the end of the reaction',
    'A small amount of catalyst can catalyse a large amount of reactant',
  ], [
    'A catalyst is used up during the reaction',
    'A catalyst increases the activation energy',
    'A catalyst shifts the equilibrium position towards the products',
    'Enzymes work equally well at all temperatures and pH values',
    'A catalyst changes the products formed in a reaction',
    'Large amounts of catalyst are always needed',
  ]),
];

// ======================== OXIDATION AND REDUCTION ========================
const redox = [
  // oxidation number
  () => {
    const bank = [
      { sp: 'S in \\(H_{2}SO_{4}\\)', n: 6 }, { sp: 'Mn in \\(KMnO_{4}\\)', n: 7 },
      { sp: 'Cr in \\(K_{2}Cr_{2}O_{7}\\)', n: 6 }, { sp: 'N in \\(HNO_{3}\\)', n: 5 },
      { sp: 'Cl in \\(NaCl\\)', n: -1 }, { sp: 'O in \\(H_{2}O\\)', n: -2 },
      { sp: 'S in \\(H_{2}S\\)', n: -2 }, { sp: 'C in \\(CO_{2}\\)', n: 4 },
      { sp: 'Fe in \\(Fe_{2}O_{3}\\)', n: 3 }, { sp: 'N in \\(NH_{3}\\)', n: -3 },
    ];
    const x = pick(bank);
    const o = buildOptions(x.n, [x.n + 1, x.n - 1, -x.n], (v) => (v > 0 ? `+${v}` : String(v)));
    if (!o) return null;
    return {
      text: `What is the oxidation number of ${x.sp}?`,
      ...o,
      explanation: `Apply the rules: oxygen is normally \\(-2\\), hydrogen \\(+1\\), and the oxidation numbers in a neutral compound sum to zero (or to the charge for an ion).\n\nSolving gives an oxidation number of ${x.n > 0 ? '+' : ''}${x.n}.`,
    };
  },
  ...conceptGens('oxidation and reduction', [
    'Oxidation is the loss of electrons',
    'Reduction is the gain of electrons',
    'An oxidising agent is itself reduced during a reaction',
    'A reducing agent is itself oxidised during a reaction',
    'Oxidation involves an increase in oxidation number',
    'Reduction involves a decrease in oxidation number',
    'Oxidation and reduction always occur together in a redox reaction',
    'Oxidation can also be described as the addition of oxygen or the removal of hydrogen',
  ], [
    'Oxidation is the gain of electrons',
    'Reduction is the loss of electrons',
    'An oxidising agent is itself oxidised during a reaction',
    'Oxidation involves a decrease in oxidation number',
    'Oxidation can occur without any accompanying reduction',
    'Reduction is the addition of oxygen to a substance',
  ]),
];

// ============================= ELECTROLYSIS =============================
const electrolysis = [
  // Faraday: charge
  () => {
    const I = randInt(1, 20), t = randInt(60, 3600);
    const Q = I * t;
    const o = buildOptions(Q, [round(I / t, 4), I + t, Q * 2], (v) => `${fmtNum(v, 2)} C`);
    if (!o) return null;
    return {
      text: `Calculate the quantity of electricity passed when a current of ${I}A flows for ${t} seconds during electrolysis.`,
      ...o,
      explanation: `\\(Q = It\\)\n\n\\(= ${I} \\times ${t} = ${Q}\\) C`,
    };
  },
  // mass deposited
  () => {
    const metal = pick([
      { n: 'copper', ar: 64, z: 2 }, { n: 'silver', ar: 108, z: 1 },
      { n: 'zinc', ar: 65, z: 2 }, { n: 'aluminium', ar: 27, z: 3 },
    ]);
    const I = randInt(1, 10), t = pick([965, 1930, 4825, 9650]);
    const Q = I * t;
    const m = Q * metal.ar / (metal.z * FARADAY);
    const o = buildOptions(round(m, 3), [round(Q * metal.ar / FARADAY, 3), round(m * metal.z, 3), round(m * 2, 3)], (v) => `${fmtNum(v, 3)} g`);
    if (!o) return null;
    return {
      text: `Calculate the mass of ${metal.n} deposited when a current of ${I}A flows for ${t} seconds through a solution of its salt. [${metal.n.charAt(0).toUpperCase() + metal.n.slice(1)} = ${metal.ar}, charge on the ion = ${metal.z}+, F = 96500 C/mol]`,
      ...o,
      explanation: `\\(Q = It = ${I} \\times ${t} = ${Q}\\) C\n\nMoles of electrons \\(= \\frac{${Q}}{96500}\\)\n\nMoles of ${metal.n} \\(= \\frac{${Q}}{${metal.z} \\times 96500}\\)\n\nMass \\(= \\frac{${Q} \\times ${metal.ar}}{${metal.z} \\times 96500} = ${fmtNum(m, 3)}\\) g`,
    };
  },
  ...conceptGens('electrolysis', [
    'Electrolysis is the decomposition of an electrolyte by the passage of an electric current',
    'Cations migrate to the cathode during electrolysis',
    'Anions migrate to the anode during electrolysis',
    'Oxidation occurs at the anode',
    'Reduction occurs at the cathode',
    'One faraday is the quantity of electricity carried by one mole of electrons',
    'One faraday is approximately 96500 coulombs',
    'Electrolysis is used in the purification of copper and the extraction of aluminium',
  ], [
    'Cations migrate to the anode during electrolysis',
    'Oxidation occurs at the cathode',
    'Reduction occurs at the anode',
    'One faraday is approximately 9650 coulombs',
    'Electrolysis can be carried out using an alternating current',
    'Electrolytes conduct electricity by the movement of electrons through the solution',
  ]),
];

// ======================== ELECTROCHEMICAL CELLS ========================
const cells = [
  ...conceptGens('electrochemical cells', [
    'In an electrochemical cell, chemical energy is converted into electrical energy',
    'Oxidation occurs at the anode, which is the negative electrode in a galvanic cell',
    'The electrode with the more negative electrode potential is the anode',
    'A salt bridge completes the circuit and maintains electrical neutrality',
    'The standard hydrogen electrode has an electrode potential of zero volts',
    'The cell e.m.f. is the difference between the electrode potentials of the two half cells',
    'A more reactive metal displaces a less reactive metal from solution',
  ], [
    'In an electrochemical cell, electrical energy is converted into chemical energy',
    'The salt bridge prevents the flow of current',
    'The standard hydrogen electrode has an electrode potential of one volt',
    'Reduction occurs at the anode in a galvanic cell',
    'A less reactive metal displaces a more reactive metal from solution',
    'The cell e.m.f. equals the sum of the two electrode potentials regardless of sign',
  ]),
  // cell emf
  () => {
    const pairs = [
      { a: 'Zn', ea: -0.76, b: 'Cu', eb: 0.34 },
      { a: 'Mg', ea: -2.37, b: 'Cu', eb: 0.34 },
      { a: 'Zn', ea: -0.76, b: 'Ag', eb: 0.80 },
      { a: 'Fe', ea: -0.44, b: 'Cu', eb: 0.34 },
    ];
    const p = pick(pairs);
    const emf = p.eb - p.ea;
    const o = buildOptions(round(emf, 2), [round(p.ea - p.eb, 2), round(p.ea + p.eb, 2), round(emf * 2, 2)], (v) => `${fmtNum(v, 2)} V`);
    if (!o) return null;
    return {
      text: `Calculate the e.m.f. of a cell made from ${p.a} (\\(E° = ${p.ea}\\)V) and ${p.b} (\\(E° = ${p.eb}\\)V).`,
      ...o,
      explanation: `\\(E°_{cell} = E°_{cathode} - E°_{anode}\\)\n\nThe more negative electrode (${p.a}) is the anode.\n\n\\(= ${p.eb} - (${p.ea}) = ${fmtNum(emf, 2)}\\) V`,
    };
  },
];

// ============================== CORROSION ==============================
const corrosion = [
  ...conceptGens('corrosion and its prevention', [
    'Rusting requires both oxygen and water',
    'Rust is hydrated iron(III) oxide',
    'Galvanising protects iron by coating it with zinc',
    'Sacrificial protection uses a more reactive metal to protect iron',
    'Painting protects iron by excluding air and moisture',
    'Salt water speeds up the rusting of iron',
    'Zinc protects iron even when the coating is scratched, because zinc is more reactive',
    'Stainless steel resists corrosion because of its chromium content',
  ], [
    'Rusting requires oxygen but not water',
    'Rust is iron(II) chloride',
    'Galvanising coats iron with copper',
    'Sacrificial protection uses a less reactive metal than iron',
    'Salt water slows down the rusting of iron',
    'A scratched tin coating still protects iron from rusting',
    'Aluminium corrodes rapidly because it forms no protective oxide layer',
  ], [
    { q: 'Why does galvanised iron continue to be protected even when the zinc layer is scratched?', a: 'Zinc is more reactive than iron and corrodes in preference to it', w: ['Zinc seals the scratch physically', 'Zinc is less reactive than iron', 'Zinc reacts with the rust to remove it'], e: 'This is sacrificial protection: the more reactive zinc is oxidised first, so the iron remains protected even where it is exposed.' },
    { q: 'What two substances are essential for the rusting of iron?', a: 'Oxygen and water', w: ['Oxygen and carbon(IV) oxide', 'Water and nitrogen', 'Carbon(IV) oxide and water'], e: 'Rusting is an electrochemical oxidation of iron requiring both air and moisture. Iron does not rust in dry air or in boiled, air-free water.' },
  ]),
];

module.exports = [
  { unitName: U_REACT, topicName: 'Writing and Balancing Equations', generators: equations },
  { unitName: U_REACT, topicName: 'The Mole Concept', generators: moleConcept },
  { unitName: U_REACT, topicName: 'Stoichiometry', generators: stoichiometry },
  { unitName: U_REACT, topicName: 'Laws of Chemical Combination', generators: combinationLaws },
  { unitName: U_ACID, topicName: 'Properties of Acids and Bases', generators: acidsBases },
  { unitName: U_ACID, topicName: 'pH and Indicators', generators: phIndicators },
  { unitName: U_ACID, topicName: 'Neutralisation and Titration', generators: titration },
  { unitName: U_ACID, topicName: 'Preparation of Salts', generators: salts },
  { unitName: U_ACID, topicName: 'Hydrolysis of Salts', generators: hydrolysis },
  { unitName: U_ENERGY, topicName: 'Enthalpy Changes', generators: enthalpy },
  { unitName: U_ENERGY, topicName: 'Rates of Reaction', generators: rates },
  { unitName: U_ENERGY, topicName: 'Chemical Equilibrium', generators: equilibrium },
  { unitName: U_ENERGY, topicName: 'Catalysis', generators: catalysis },
  { unitName: U_ELEC, topicName: 'Oxidation and Reduction', generators: redox },
  { unitName: U_ELEC, topicName: 'Electrolysis', generators: electrolysis },
  { unitName: U_ELEC, topicName: 'Electrochemical Cells', generators: cells },
  { unitName: U_ELEC, topicName: 'Corrosion', generators: corrosion },
];
