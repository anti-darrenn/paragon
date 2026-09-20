// Chemistry > Separation of Mixtures, Atomic Structure and Bonding, States of Matter
// Topic/unit names must match lib/core/content/subject_catalog.dart exactly.
const L = require('./lib');
const { randInt, pick, shuffle, sample, nonZero, frac, fracTex, fracOpt,
        fmtNum, buildOptions, textOptions, round } = L;
const { conceptGens, qaBank } = require('./concept');

const U_SEP = 'Separation of Mixtures';
const U_ATOM = 'Atomic Structure and Bonding';
const U_STATE = 'States of Matter';
const mathOpt = (s) => `\\(${s}\\)`;

// ===================== PURE AND IMPURE SUBSTANCES =====================
const pureImpure = [
  ...conceptGens('pure and impure substances', [
    'A pure substance has a sharp, fixed melting point',
    'An impure substance melts over a range of temperatures',
    'An impurity lowers the melting point of a solid',
    'An impurity raises the boiling point of a liquid',
    'A mixture can be separated by physical means',
    'A compound can only be separated by chemical means',
    'The components of a mixture retain their individual properties',
    'A pure substance boils at a fixed temperature under a given pressure',
  ], [
    'A pure substance melts over a wide range of temperatures',
    'An impurity raises the melting point of a solid',
    'An impurity lowers the boiling point of a liquid',
    'A compound can be separated by physical means such as filtration',
    'A mixture always has a fixed composition by mass',
    'The components of a mixture lose their individual properties',
    'Impurities have no effect on melting or boiling point',
  ], [
    { q: 'Which of the following is a criterion for the purity of a solid substance?', a: 'A sharp melting point', w: ['A high density', 'A strong smell', 'A bright colour'], e: 'A pure solid melts completely at one fixed temperature. The presence of impurities depresses and broadens the melting point, so a sharp melting point is the standard test of purity.' },
    { q: 'Why is salt spread on icy roads in cold countries?', a: 'It lowers the melting point of ice so the ice melts', w: ['It raises the melting point of ice', 'It increases the density of the ice', 'It reacts chemically with the ice'], e: 'Dissolved salt depresses the freezing point of water, so ice melts at a temperature below 0°C.' },
    { q: 'Which of the following is a pure substance?', a: 'Distilled water', w: ['Sea water', 'Air', 'Brass'], e: 'Distilled water contains only one kind of particle and has a fixed melting and boiling point. Sea water, air and brass are all mixtures.' },
    { q: 'Which of the following is a mixture?', a: 'Air', w: ['Carbon dioxide', 'Sodium chloride', 'Water'], e: 'Air is a mixture of nitrogen, oxygen, argon, carbon dioxide and other gases in variable proportions, none of which are chemically combined.' },
  ]),
  // melting point depression reasoning
  () => {
    const mp = randInt(40, 200);
    const drop = randInt(2, 15);
    const o = buildOptions(mp - drop, [mp + drop, mp, mp - 2 * drop], (v) => `${v}°C`);
    if (!o) return null;
    return {
      text: `A pure solid melts sharply at ${mp}°C. A sample of the same solid containing an impurity was found to melt ${drop}°C lower. At what temperature did the impure sample begin to melt?`,
      ...o,
      explanation: `Impurities depress the melting point of a solid.\n\n\\(${mp}°C - ${drop}°C = ${mp - drop}°C\\)\n\nThe impure sample also melts over a range rather than at a sharp point.`,
    };
  },
];

// ===================== FILTRATION AND EVAPORATION =====================
const filtration = [
  ...conceptGens('filtration and evaporation', [
    'Filtration separates an insoluble solid from a liquid',
    'The solid left on the filter paper is called the residue',
    'The liquid that passes through the filter paper is called the filtrate',
    'Evaporation is used to recover a dissolved solid from its solution',
    'Filtration cannot separate a dissolved solute from its solvent',
    'Sand can be separated from water by filtration',
    'Crystallisation gives a purer solid than simple evaporation to dryness',
  ], [
    'Filtration can separate a dissolved solid from its solution',
    'The residue is the liquid that passes through the filter paper',
    'The filtrate is the solid left on the filter paper',
    'Evaporation is used to separate two miscible liquids',
    'Salt can be separated from water by filtration',
    'Filtration separates liquids of different boiling points',
  ], [
    { q: 'A mixture of sand and common salt is stirred with water and filtered. What is the residue?', a: 'Sand', w: ['Common salt', 'Salt solution', 'Water'], e: 'Salt dissolves and passes through as part of the filtrate. Sand is insoluble and remains on the filter paper as the residue.' },
    { q: 'How would you recover the salt from the filtrate obtained after filtering a salt and sand mixture?', a: 'By evaporating the filtrate to dryness', w: ['By filtering the filtrate again', 'By adding more water', 'By using a magnet'], e: 'The salt is dissolved in the filtrate. Evaporating the water leaves the solid salt behind.' },
    { q: 'Which method would you use to separate a precipitate from the solution in which it was formed?', a: 'Filtration', w: ['Distillation', 'Chromatography', 'Sublimation'], e: 'A precipitate is an insoluble solid suspended in a liquid, which is exactly what filtration separates.' },
  ]),
];

// ============================= DISTILLATION =============================
const distillation = [
  ...conceptGens('distillation', [
    'Simple distillation separates a solvent from a dissolved solid',
    'Fractional distillation separates two or more miscible liquids',
    'Fractional distillation depends on differences in boiling point',
    'In a Liebig condenser, cold water enters at the lower end and leaves at the upper end',
    'The thermometer bulb should be level with the side arm of the distillation flask',
    'The liquid with the lower boiling point distils over first',
    'Fractional distillation of liquid air separates nitrogen from oxygen',
  ], [
    'Simple distillation is used to separate two liquids with very close boiling points',
    'The liquid with the higher boiling point distils over first',
    'In a condenser, cold water enters at the upper end and leaves at the lower end',
    'Distillation separates an insoluble solid from a liquid',
    'Fractional distillation depends on differences in density',
    'The thermometer bulb should be immersed in the boiling liquid',
  ], [
    { q: 'Which method is used to obtain pure water from sea water?', a: 'Simple distillation', w: ['Filtration', 'Chromatography', 'Sublimation'], e: 'The dissolved salts are non-volatile. Boiling the sea water and condensing the steam gives pure water, leaving the salts behind.' },
    { q: 'Which technique separates ethanol from water?', a: 'Fractional distillation', w: ['Simple distillation', 'Filtration', 'Decantation'], e: 'Ethanol and water are miscible with boiling points of 78°C and 100°C. A fractionating column provides repeated vaporisation and condensation to separate them.' },
    { q: 'In the fractional distillation of crude oil, which fraction is collected at the top of the column?', a: 'The fraction with the lowest boiling point', w: ['The fraction with the highest boiling point', 'The densest fraction', 'The bitumen fraction'], e: 'The column is hottest at the base. Only the most volatile, lowest boiling point fractions remain gaseous high up the column, so they are collected at the top.' },
    { q: 'Why is a fractionating column packed with glass beads or rings?', a: 'To increase the surface area for repeated vaporisation and condensation', w: ['To reduce the boiling point of the mixture', 'To filter out impurities', 'To cool the vapour completely'], e: 'The large surface area allows many vaporisation-condensation cycles, which progressively enriches the rising vapour in the more volatile component.' },
  ]),
];

// ============================ CHROMATOGRAPHY ============================
const chromatography = [
  ...conceptGens('chromatography', [
    'Chromatography separates components of a mixture based on differences in solubility and adsorption',
    'The component most soluble in the solvent travels furthest',
    'In paper chromatography the paper is the stationary phase',
    'In paper chromatography the solvent is the mobile phase',
    'Chromatography can be used to separate the pigments in ink',
    'The baseline in paper chromatography must be drawn in pencil',
    'A pure substance produces only one spot on a chromatogram',
  ], [
    'The component least soluble in the solvent travels furthest',
    'In paper chromatography the solvent is the stationary phase',
    'The baseline should be drawn in ink so that it is clearly visible',
    'Chromatography separates substances according to their densities',
    'A pure substance produces several spots on a chromatogram',
    'Chromatography can only be used on coloured substances',
  ], [
    { q: 'Why must the baseline in paper chromatography be drawn in pencil rather than ink?', a: 'Pencil is insoluble in the solvent and will not run', w: ['Pencil is easier to see than ink', 'Ink is too expensive to use', 'Pencil reacts with the solvent to fix the spots'], e: 'Ink would dissolve in the solvent and travel up the paper with the sample, contaminating the chromatogram. Graphite is insoluble and stays in place.' },
    { q: 'Why must the solvent level be below the baseline when the paper is placed in the tank?', a: 'So the samples are not washed directly into the solvent', w: ['So the solvent evaporates faster', 'So the paper does not bend', 'So the spots stay coloured'], e: 'If the solvent level were above the baseline, the spots would simply dissolve into the bulk solvent instead of being carried up the paper.' },
  ]),
  // Rf calculation
  () => {
    const dSolvent = randInt(8, 20);
    const dSpot = randInt(1, dSolvent - 1);
    const rf = dSpot / dSolvent;
    const o = buildOptions(round(rf, 2), [round(dSolvent / dSpot, 2), round(rf * 2, 2), round(dSpot * dSolvent, 2)], (v) => fmtNum(v, 2));
    if (!o) return null;
    return {
      text: `In a paper chromatography experiment, the solvent front travelled ${dSolvent}cm while a spot travelled ${dSpot}cm. Calculate the \\(R_f\\) value of the spot.`,
      ...o,
      explanation: `\\(R_f = \\frac{\\text{distance moved by the spot}}{\\text{distance moved by the solvent front}}\\)\n\n\\(= \\frac{${dSpot}}{${dSolvent}} = ${fmtNum(rf, 2)}\\)\n\n\\(R_f\\) has no unit and is always less than 1.`,
    };
  },
];

// ============================== SUBLIMATION ==============================
const SUBLIMERS = ['iodine', 'ammonium chloride', 'solid carbon dioxide (dry ice)', 'naphthalene', 'camphor'];
const NON_SUBLIMERS = ['sodium chloride', 'copper(II) sulphate', 'calcium carbonate', 'potassium nitrate', 'magnesium oxide'];

const sublimation = [
  // which substance sublimes
  () => {
    const t = pick(SUBLIMERS);
    const w = sample(NON_SUBLIMERS, 3);
    const cap = (s) => s.charAt(0).toUpperCase() + s.slice(1);
    const o = textOptions(cap(t), w.map(cap));
    if (!o) return null;
    return {
      text: `Which of the following substances sublimes on heating?`,
      ...o,
      explanation: `Sublimation is the direct change from solid to vapour without passing through the liquid state.\n\n${cap(t)} sublimes. The other substances listed melt or decompose instead.`,
    };
  },
  // separating a sublimable substance
  () => {
    const s = pick(SUBLIMERS);
    const n = pick(NON_SUBLIMERS);
    const o = textOptions('Sublimation', ['Filtration', 'Fractional distillation', 'Chromatography']);
    if (!o) return null;
    return {
      text: `Which method would you use to separate a mixture of ${s} and ${n}?`,
      ...o,
      explanation: `${s.charAt(0).toUpperCase() + s.slice(1)} sublimes on heating while ${n} does not.\n\nWarming the mixture drives off the ${s} as a vapour, which then re-forms as a solid on a cool surface, leaving the ${n} behind.`,
    };
  },
  ...conceptGens('sublimation', [
    'Sublimation is the direct change of a solid to a vapour without becoming a liquid',
    'Iodine sublimes when gently heated',
    'Ammonium chloride sublimes on heating',
    'Sublimation can be used to separate a sublimable solid from a non-sublimable one',
    'The vapour formed during sublimation re-forms as a solid on a cool surface',
    'Solid carbon dioxide sublimes at atmospheric pressure',
  ], [
    'Sublimation is the change of a solid to a liquid',
    'Sodium chloride sublimes readily on gentle heating',
    'All solids sublime when heated strongly enough at atmospheric pressure',
    'Sublimation involves passing through the liquid state briefly',
    'Sublimation separates two miscible liquids',
    'The vapour formed during sublimation condenses to a liquid first',
  ]),
];

// ======================= ATOMS, MOLECULES AND IONS =======================
const atomsIons = [
  // protons / neutrons / electrons
  () => {
    const Z = randInt(3, 30), A = Z + randInt(Z >= 20 ? Z - 5 : 2, Z + 8);
    const ask = pick(['protons', 'neutrons', 'electrons']);
    const correct = ask === 'neutrons' ? A - Z : Z;
    const o = buildOptions(correct, [A, ask === 'neutrons' ? Z : A - Z, A + Z], (v) => String(v));
    if (!o) return null;
    return {
      text: `An atom has mass number ${A} and atomic number ${Z}. How many ${ask} does it contain?`,
      ...o,
      explanation: `The atomic number gives the number of protons, and in a neutral atom the number of electrons equals the number of protons.\n\nNumber of neutrons = mass number − atomic number = \\(${A} - ${Z} = ${A - Z}\\)\n\nSo the number of ${ask} is ${correct}.`,
    };
  },
  // ion charge and electrons
  () => {
    const Z = randInt(8, 20);
    const charge = pick([1, 2, 3, -1, -2]);
    const electrons = Z - charge;
    const sign = charge > 0 ? `${charge === 1 ? '' : charge}+` : `${Math.abs(charge) === 1 ? '' : Math.abs(charge)}-`;
    const o = buildOptions(electrons, [Z, Z + charge, Z + Math.abs(charge)], (v) => String(v));
    if (!o) return null;
    return {
      text: `An ion of an element with atomic number ${Z} carries a charge of ${sign}. How many electrons does the ion contain?`,
      ...o,
      explanation: `A neutral atom of this element has ${Z} electrons.\n\n${charge > 0 ? `A charge of ${sign} means ${charge} electron${charge === 1 ? ' has' : 's have'} been lost: \\(${Z} - ${charge} = ${electrons}\\)` : `A charge of ${sign} means ${Math.abs(charge)} electron${Math.abs(charge) === 1 ? ' has' : 's have'} been gained: \\(${Z} + ${Math.abs(charge)} = ${electrons}\\)`}`,
    };
  },
  // isotopes
  () => {
    const Z = randInt(5, 25), A1 = Z + randInt(2, 8), A2 = A1 + randInt(1, 4);
    const o = textOptions('They have the same number of protons but different numbers of neutrons', [
      'They have the same number of neutrons but different numbers of protons',
      'They have different numbers of both protons and neutrons',
      'They have the same mass number but different atomic numbers',
    ]);
    if (!o) return null;
    return {
      text: `Two atoms have atomic number ${Z} but mass numbers ${A1} and ${A2} respectively. What is the relationship between them?`,
      ...o,
      explanation: `Both have ${Z} protons, so they are the same element. Their neutron counts differ: \\(${A1} - ${Z} = ${A1 - Z}\\) and \\(${A2} - ${Z} = ${A2 - Z}\\).\n\nAtoms of the same element with different numbers of neutrons are isotopes.`,
    };
  },
  // relative atomic mass from isotopic abundance
  () => {
    const A1 = randInt(10, 40), A2 = A1 + randInt(1, 4);
    const p1 = pick([10, 20, 25, 40, 50, 60, 75, 80, 90]);
    const p2 = 100 - p1;
    const ram = (A1 * p1 + A2 * p2) / 100;
    const o = buildOptions(round(ram, 2), [round((A1 + A2) / 2, 2), A1, A2], (v) => fmtNum(v, 2));
    if (!o) return null;
    return {
      text: `An element has two isotopes of mass numbers ${A1} and ${A2} with relative abundances ${p1}% and ${p2}% respectively. Calculate its relative atomic mass.`,
      ...o,
      explanation: `Relative atomic mass \\(= \\frac{(${A1} \\times ${p1}) + (${A2} \\times ${p2})}{100}\\)\n\n\\(= \\frac{${A1 * p1} + ${A2 * p2}}{100} = \\frac{${A1 * p1 + A2 * p2}}{100} = ${fmtNum(ram, 2)}\\)`,
    };
  },
  ...conceptGens('atoms, molecules and ions', [
    'An atom is the smallest particle of an element that can take part in a chemical reaction',
    'A cation is a positively charged ion formed by the loss of electrons',
    'An anion is a negatively charged ion formed by the gain of electrons',
    'Isotopes are atoms of the same element with different mass numbers',
    'The mass number is the sum of the protons and neutrons in an atom',
    'The atomic number is the number of protons in the nucleus',
    'A neutral atom has equal numbers of protons and electrons',
    'Electrons carry a negative charge and have negligible mass',
  ], [
    'A cation is formed by the gain of electrons',
    'An anion is a positively charged ion',
    'Isotopes have the same mass number but different atomic numbers',
    'The mass number is the number of protons only',
    'Neutrons carry a positive charge',
    'Electrons are found inside the nucleus of an atom',
    'A neutral atom has more protons than electrons',
  ]),
];

// ======================== ELECTRON CONFIGURATION ========================
function econfig(Z) {
  const caps = [2, 8, 8, 18];
  const out = [];
  let left = Z;
  for (const c of caps) {
    if (left <= 0) break;
    const put = Math.min(left, c);
    out.push(put);
    left -= put;
  }
  return out;
}

const electronConfig = [
  // configuration of an element
  () => {
    const Z = randInt(3, 20);
    const cfg = econfig(Z).join(', ');
    const wrongs = [econfig(Z + 1).join(', '), econfig(Z - 1).join(', '), econfig(Z + 2).join(', ')];
    const o = textOptions(cfg, wrongs);
    if (!o) return null;
    return {
      text: `Write the electron configuration of an element with atomic number ${Z}.`,
      ...o,
      explanation: `Electrons fill the shells in order, with a maximum of 2 in the first shell and 8 in the second and third for the first twenty elements.\n\nFor \\(Z = ${Z}\\) this gives ${cfg}.`,
    };
  },
  // valence electrons and group
  () => {
    const Z = pick([3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14, 15, 16, 17, 19, 20]);
    const cfg = econfig(Z);
    const valence = cfg[cfg.length - 1];
    const o = buildOptions(valence, [cfg.length, Z, valence + 1], (v) => String(v));
    if (!o) return null;
    return {
      text: `How many valence electrons does an element with atomic number ${Z} have?`,
      ...o,
      explanation: `The electron configuration is ${cfg.join(', ')}.\n\nThe valence electrons are those in the outermost shell, so there are ${valence}.`,
    };
  },
  // period number
  () => {
    const Z = pick([3, 5, 7, 9, 11, 13, 15, 17, 19, 20, 4, 6, 8, 12, 14, 16]);
    const cfg = econfig(Z);
    const period = cfg.length;
    const o = buildOptions(period, [cfg[cfg.length - 1], Z, period + 1], (v) => String(v));
    if (!o) return null;
    return {
      text: `In which period of the periodic table is the element with atomic number ${Z} found?`,
      ...o,
      explanation: `The configuration is ${cfg.join(', ')}, which uses ${period} shell${period > 1 ? 's' : ''}.\n\nThe period number equals the number of occupied shells, so the element is in period ${period}.`,
    };
  },
  ...conceptGens('electron configuration', [
    'The maximum number of electrons in the first shell is 2',
    'The maximum number of electrons in the second shell is 8',
    'The number of valence electrons determines the chemical properties of an element',
    'Noble gases have completely filled outermost shells',
    'The period number equals the number of occupied electron shells',
    'Elements in the same group have the same number of valence electrons',
  ], [
    'The first shell can hold up to 8 electrons',
    'The number of neutrons determines the chemical properties of an element',
    'Noble gases have incomplete outermost shells',
    'The group number equals the number of occupied shells',
    'Elements in the same period have the same number of valence electrons',
    'Electrons fill the outermost shell before the innermost shell',
  ]),
];

// ========================== THE PERIODIC TABLE ==========================
const periodicTable = [
  ...conceptGens('the periodic table', [
    'The modern periodic table arranges elements in order of increasing atomic number',
    'Elements in the same group have similar chemical properties',
    'Group 1 elements are called the alkali metals',
    'Group 7 elements are called the halogens',
    'Group 8 (or 0) elements are the noble gases and are largely unreactive',
    'Atomic radius decreases across a period from left to right',
    'Ionisation energy increases across a period from left to right',
    'Metallic character increases down a group',
    'Non-metals are found on the right-hand side of the periodic table',
  ], [
    'The modern periodic table arranges elements in order of increasing atomic mass',
    'Elements in the same period have similar chemical properties',
    'Group 1 elements are called the halogens',
    'Group 7 elements are the noble gases',
    'Atomic radius increases across a period from left to right',
    'Ionisation energy decreases across a period from left to right',
    'Metallic character decreases down a group',
    'Metals are found on the right-hand side of the periodic table',
  ], [
    { q: 'What is the basis of the arrangement of elements in the modern periodic table?', a: 'Increasing atomic number', w: ['Increasing atomic mass', 'Increasing density', 'Decreasing reactivity'], e: 'Moseley showed that the properties of the elements are a periodic function of atomic number, which resolved the anomalies in Mendeleev\'s mass-based ordering.' },
    { q: 'Why are noble gases chemically unreactive?', a: 'They have completely filled outermost electron shells', w: ['They have very large atomic radii', 'They exist only as diatomic molecules', 'They readily lose electrons'], e: 'A full outer shell is an energetically stable arrangement, so noble gases have little tendency to gain, lose or share electrons.' },
    { q: 'Elements in the same group of the periodic table have the same', a: 'number of valence electrons', w: ['number of shells', 'atomic mass', 'number of neutrons'], e: 'Group number reflects the outer-shell electron count, and it is those valence electrons that determine chemical behaviour, which is why a group behaves similarly.' },
  ]),
];

// ====================== TYPES OF CHEMICAL BONDING ======================
const bonding = [
  ...conceptGens('chemical bonding', [
    'An ionic bond is formed by the transfer of electrons from a metal to a non-metal',
    'A covalent bond is formed by the sharing of electrons between non-metals',
    'Ionic compounds conduct electricity when molten or in aqueous solution',
    'Ionic compounds generally have high melting and boiling points',
    'A dative or coordinate bond is one in which both shared electrons come from the same atom',
    'Metallic bonding involves a lattice of positive ions in a sea of delocalised electrons',
    'Simple covalent molecular substances generally have low melting points',
    'Hydrogen bonding accounts for the unusually high boiling point of water',
  ], [
    'An ionic bond is formed by sharing electrons between two non-metals',
    'A covalent bond is formed by the complete transfer of electrons',
    'Ionic compounds conduct electricity in the solid state',
    'Ionic compounds generally have very low melting points',
    'In a dative bond each atom contributes one electron',
    'Metallic bonding involves a lattice of negative ions',
    'Simple covalent molecules have very high melting points',
  ], [
    { q: 'Why do ionic compounds conduct electricity when molten but not when solid?', a: 'The ions are free to move when molten but held in fixed positions in the solid', w: ['Electrons are released only on melting', 'The compound decomposes into metals on melting', 'Molten compounds gain extra charge'], e: 'Electrical conduction requires mobile charge carriers. In a solid ionic lattice the ions are locked in place; melting frees them to migrate towards the electrodes.' },
    { q: 'What type of bond exists in sodium chloride?', a: 'Ionic bond', w: ['Covalent bond', 'Metallic bond', 'Hydrogen bond'], e: 'Sodium is a metal that loses an electron and chlorine is a non-metal that gains it, producing oppositely charged ions held by electrostatic attraction.' },
    { q: 'What type of bonding is present in a molecule of methane?', a: 'Covalent bonding', w: ['Ionic bonding', 'Metallic bonding', 'Dative bonding'], e: 'Carbon and hydrogen are both non-metals and share electron pairs to complete their outer shells, which is covalent bonding.' },
    { q: 'Which bond type accounts for the ability of metals to conduct electricity?', a: 'Metallic bonding with delocalised electrons', w: ['Ionic bonding', 'Covalent bonding', 'Hydrogen bonding'], e: 'The delocalised electrons in the metallic lattice are free to drift through the structure when a potential difference is applied.' },
  ]),
];

// ========================= SHAPES OF MOLECULES =========================
const shapes = [
  // shape from a bank
  () => {
    const bank = [
      { m: 'CH_{4}', s: 'Tetrahedral', a: '109.5°' },
      { m: 'H_{2}O', s: 'Bent (V-shaped)', a: '104.5°' },
      { m: 'NH_{3}', s: 'Trigonal pyramidal', a: '107°' },
      { m: 'CO_{2}', s: 'Linear', a: '180°' },
      { m: 'BF_{3}', s: 'Trigonal planar', a: '120°' },
      { m: 'BeCl_{2}', s: 'Linear', a: '180°' },
    ];
    const x = pick(bank);
    const others = bank.filter(b => b.s !== x.s).map(b => b.s);
    const o = textOptions(x.s, sample(Array.from(new Set(others)), 3));
    if (!o) return null;
    return {
      text: `What is the shape of a molecule of \\(${x.m}\\)?`,
      ...o,
      explanation: `The shape is determined by the repulsion between electron pairs around the central atom.\n\n\\(${x.m}\\) is ${x.s.toLowerCase()}, with a bond angle of about ${x.a}.`,
    };
  },
  ...conceptGens('the shapes of molecules', [
    'Methane has a tetrahedral shape with bond angles of about 109.5 degrees',
    'Water is bent because of the two lone pairs on the oxygen atom',
    'Ammonia is trigonal pyramidal because of the lone pair on nitrogen',
    'Carbon dioxide is a linear molecule',
    'Lone pairs repel more strongly than bonding pairs',
    'The shape of a molecule is determined by repulsion between electron pairs',
  ], [
    'Water is a linear molecule',
    'Methane is a flat, square molecule',
    'Ammonia has no lone pair on the nitrogen atom',
    'Carbon dioxide is a bent molecule',
    'Bonding pairs repel more strongly than lone pairs',
    'All molecules with three atoms are bent',
  ]),
];

// ============================ KINETIC THEORY ============================
const kinetic = [
  ...conceptGens('the kinetic theory of matter', [
    'Matter is made up of tiny particles in constant motion',
    'Particles in a solid vibrate about fixed positions',
    'Particles in a gas move randomly at high speed and are far apart',
    'The average kinetic energy of particles increases with temperature',
    'Diffusion occurs because particles are in constant random motion',
    'Gases diffuse faster than liquids because their particles move faster and are further apart',
    'Brownian motion provides evidence for the random motion of particles',
    'Evaporation occurs when the most energetic particles escape from the surface of a liquid',
  ], [
    'Particles in a solid move freely throughout the solid',
    'Particles in a gas are closely packed in fixed positions',
    'The average kinetic energy of particles decreases as temperature rises',
    'Diffusion occurs only in solids',
    'Liquids diffuse faster than gases',
    'Brownian motion shows that particles are stationary',
    'Particles stop moving completely at room temperature',
  ]),
  // Graham's law
  () => {
    const pairs = [
      { a: 'hydrogen', ma: 2, b: 'oxygen', mb: 32 },
      { a: 'helium', ma: 4, b: 'methane', mb: 16 },
      { a: 'methane', ma: 16, b: 'sulphur(IV) oxide', mb: 64 },
      { a: 'hydrogen', ma: 2, b: 'methane', mb: 8 },
    ];
    const p = pick(pairs);
    const ratio = Math.sqrt(p.mb / p.ma);
    const o = buildOptions(round(ratio, 2), [round(p.mb / p.ma, 2), round(Math.sqrt(p.ma / p.mb), 2), round(ratio * 2, 2)], (v) => fmtNum(v, 2));
    if (!o) return null;
    return {
      text: `How many times faster does ${p.a} (relative molecular mass ${p.ma}) diffuse than ${p.b} (relative molecular mass ${p.mb})?`,
      ...o,
      explanation: `By Graham's law, the rate of diffusion is inversely proportional to the square root of the relative molecular mass.\n\n\\(\\frac{r_1}{r_2} = \\sqrt{\\frac{M_2}{M_1}} = \\sqrt{\\frac{${p.mb}}{${p.ma}}} = \\sqrt{${p.mb / p.ma}} = ${fmtNum(ratio, 2)}\\)`,
    };
  },
];

// ====================== GAS LAWS (CHEMISTRY) ======================
const chemGasLaws = [
  // Boyle
  () => {
    const p1 = randInt(1, 10) * 100, v1 = randInt(2, 20), v2 = randInt(2, 20);
    if (v1 === v2) return null;
    const p2 = p1 * v1 / v2;
    if (!Number.isInteger(p2)) return null;
    const o = buildOptions(p2, [round(p1 * v2 / v1, 2), p1, p2 * 2], (v) => `${fmtNum(v, 2)} Pa`);
    if (!o) return null;
    return {
      text: `A gas occupies ${v1}dm³ at a pressure of ${p1}Pa. What pressure is needed to compress it to ${v2}dm³ at constant temperature?`,
      ...o,
      explanation: `Boyle's law: \\(P_1V_1 = P_2V_2\\)\n\n\\(${p1} \\times ${v1} = P_2 \\times ${v2}\\)\n\n\\(P_2 = \\frac{${p1 * v1}}{${v2}} = ${p2}\\) Pa`,
    };
  },
  // Charles
  () => {
    const t1 = pick([273, 300, 350, 400]), v1 = randInt(2, 25);
    const t2 = pick([273, 300, 350, 400, 500, 600]);
    if (t1 === t2) return null;
    const v2 = v1 * t2 / t1;
    const o = buildOptions(round(v2, 2), [round(v1 * t1 / t2, 2), v1, round(v2 * 2, 2)], (v) => `${fmtNum(v, 2)} dm³`);
    if (!o) return null;
    return {
      text: `A gas occupies ${v1}dm³ at ${t1}K. What volume will it occupy at ${t2}K if the pressure is unchanged?`,
      ...o,
      explanation: `Charles' law: \\(\\frac{V_1}{T_1} = \\frac{V_2}{T_2}\\)\n\n\\(V_2 = \\frac{${v1} \\times ${t2}}{${t1}} = ${fmtNum(v2, 2)}\\) dm³`,
    };
  },
  // general gas equation
  () => {
    const p1 = randInt(1, 8) * 100, v1 = randInt(2, 15), t1 = pick([273, 300, 400]);
    const p2 = randInt(1, 8) * 100, t2 = pick([273, 300, 400, 546]);
    const v2 = p1 * v1 * t2 / (t1 * p2);
    const o = buildOptions(round(v2, 2), [round(v1 * p1 / p2, 2), v1, round(v2 * 2, 2)], (v) => `${fmtNum(v, 2)} dm³`);
    if (!o) return null;
    return {
      text: `A gas occupies ${v1}dm³ at ${p1}Pa and ${t1}K. Calculate its volume at ${p2}Pa and ${t2}K.`,
      ...o,
      explanation: `\\(\\frac{P_1V_1}{T_1} = \\frac{P_2V_2}{T_2}\\)\n\n\\(V_2 = \\frac{P_1V_1T_2}{T_1P_2} = \\frac{${p1} \\times ${v1} \\times ${t2}}{${t1} \\times ${p2}} = ${fmtNum(v2, 2)}\\) dm³`,
    };
  },
  // molar volume at s.t.p.
  () => {
    const moles = pick([0.25, 0.5, 1, 2, 2.5, 4]);
    const vol = moles * 22.4;
    const o = buildOptions(round(vol, 2), [round(moles * 24, 2), round(22.4 / moles, 2), round(vol * 2, 2)], (v) => `${fmtNum(v, 2)} dm³`);
    if (!o) return null;
    return {
      text: `What volume would ${moles} mole${moles === 1 ? '' : 's'} of a gas occupy at s.t.p.? [Molar volume at s.t.p. = 22.4dm³]`,
      ...o,
      explanation: `At s.t.p. one mole of any gas occupies 22.4dm³.\n\n\\(${moles} \\times 22.4 = ${fmtNum(vol, 2)}\\) dm³`,
    };
  },
  ...conceptGens('the gas laws', [
    'Boyle\'s law states that the volume of a fixed mass of gas is inversely proportional to its pressure at constant temperature',
    'Charles\' law states that the volume of a fixed mass of gas is directly proportional to its absolute temperature at constant pressure',
    'Standard temperature and pressure are 273K and 101325Pa',
    'One mole of any gas occupies 22.4dm³ at s.t.p.',
    'Temperature must be converted to kelvin in gas law calculations',
    'An ideal gas obeys the gas laws exactly at all temperatures and pressures',
  ], [
    'Boyle\'s law states that volume is directly proportional to pressure',
    'Charles\' law applies at constant volume',
    'Standard temperature is 0K',
    'One mole of any gas occupies 22.4dm³ at all temperatures',
    'Temperature may be used in degrees Celsius in gas law calculations',
    'Real gases obey the gas laws perfectly at very high pressures',
  ]),
];

// ============================ VAPOUR PRESSURE ============================
const vapourPressure = [
  ...conceptGens('vapour pressure', [
    'Saturated vapour pressure is the pressure exerted by a vapour in equilibrium with its liquid',
    'Vapour pressure increases as temperature increases',
    'A liquid boils when its saturated vapour pressure equals the external atmospheric pressure',
    'A liquid with a high vapour pressure at room temperature is described as volatile',
    'Saturated vapour pressure does not depend on the volume of the vapour space',
    'Reducing the external pressure lowers the boiling point of a liquid',
    'Adding a non-volatile solute lowers the vapour pressure of a liquid',
  ], [
    'Vapour pressure decreases as temperature increases',
    'A liquid boils when its vapour pressure is zero',
    'A volatile liquid has a very low vapour pressure',
    'Saturated vapour pressure depends strongly on the volume of the container',
    'Reducing the external pressure raises the boiling point',
    'Adding a non-volatile solute raises the vapour pressure',
  ], [
    { q: 'Why does water boil below 100°C on a high mountain?', a: 'Atmospheric pressure is lower, so the vapour pressure equals it at a lower temperature', w: ['Water is purer at high altitude', 'The air is colder at high altitude', 'Water has a higher vapour pressure at altitude'], e: 'Boiling occurs when saturated vapour pressure equals external pressure. Less atmospheric pressure means that condition is met at a lower temperature.' },
    { q: 'What is meant by a volatile liquid?', a: 'A liquid that evaporates easily and has a high vapour pressure', w: ['A liquid with a very high boiling point', 'A liquid that does not evaporate', 'A liquid that reacts violently with water'], e: 'Volatility describes how readily a liquid vaporises. Weak intermolecular forces give a high saturated vapour pressure and a low boiling point.' },
  ]),
];

// =========================== CRYSTAL STRUCTURE ===========================
const crystals = [
  ...conceptGens('crystal structure', [
    'A crystal has a regular, repeating arrangement of particles',
    'Water of crystallisation is water chemically combined in a crystal in fixed proportions',
    'Efflorescence is the loss of water of crystallisation to the atmosphere',
    'Deliquescence is the absorption of moisture from the air to form a solution',
    'A hygroscopic substance absorbs moisture from the air without dissolving',
    'Copper(II) sulphate crystals turn white when heated because they lose water of crystallisation',
    'Anhydrous copper(II) sulphate turns blue in the presence of water',
  ], [
    'A crystal has a completely random arrangement of particles',
    'Efflorescence is the absorption of water from the atmosphere',
    'Deliquescence is the loss of water of crystallisation',
    'Water of crystallisation is present in variable, non-fixed proportions',
    'Anhydrous copper(II) sulphate turns white in the presence of water',
    'Hygroscopic substances dissolve completely in the water they absorb',
  ], [
    { q: 'What is meant by water of crystallisation?', a: 'Water chemically combined with a salt in a definite proportion in its crystals', w: ['Water used to wash crystals', 'Water trapped mechanically between crystals', 'Water produced when a crystal burns'], e: 'Hydrated salts such as \\(CuSO_4 \\cdot 5H_2O\\) contain a fixed number of water molecules per formula unit, integral to the crystal lattice.' },
    { q: 'Blue copper(II) sulphate crystals turn white on strong heating. What has happened?', a: 'The crystals have lost their water of crystallisation', w: ['The copper has been oxidised', 'The crystals have melted', 'The sulphate has decomposed to sulphur'], e: 'Heating drives off the five water molecules, leaving anhydrous copper(II) sulphate, which is white. Adding water reverses the change.' },
    { q: 'Which term describes a substance that absorbs moisture from the air and dissolves in it?', a: 'Deliquescent', w: ['Efflorescent', 'Hygroscopic', 'Anhydrous'], e: 'A deliquescent solid absorbs so much atmospheric moisture that it eventually forms a solution. Sodium hydroxide behaves this way.' },
  ]),
];

module.exports = [
  { unitName: U_SEP, topicName: 'Pure and Impure Substances', generators: pureImpure },
  { unitName: U_SEP, topicName: 'Filtration and Evaporation', generators: filtration },
  { unitName: U_SEP, topicName: 'Distillation', generators: distillation },
  { unitName: U_SEP, topicName: 'Chromatography', generators: chromatography },
  { unitName: U_SEP, topicName: 'Sublimation', generators: sublimation },
  { unitName: U_ATOM, topicName: 'Atoms, Molecules and Ions', generators: atomsIons },
  { unitName: U_ATOM, topicName: 'Electron Configuration', generators: electronConfig },
  { unitName: U_ATOM, topicName: 'The Periodic Table', generators: periodicTable },
  { unitName: U_ATOM, topicName: 'Types of Chemical Bonding', generators: bonding },
  { unitName: U_ATOM, topicName: 'Shapes of Molecules', generators: shapes },
  { unitName: U_STATE, topicName: 'Kinetic Theory', generators: kinetic },
  { unitName: U_STATE, topicName: 'Gas Laws', generators: chemGasLaws },
  { unitName: U_STATE, topicName: 'Vapour Pressure', generators: vapourPressure },
  { unitName: U_STATE, topicName: 'Crystal Structure', generators: crystals },
];
