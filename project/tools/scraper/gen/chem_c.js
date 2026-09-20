// Chemistry > Organic Chemistry, Metals and Non-Metals, Industrial and Environmental Chemistry
const L = require('./lib');
const { randInt, pick, shuffle, sample, nonZero, frac, fracTex, fracOpt,
        fmtNum, buildOptions, textOptions, round } = L;
const { conceptGens, qaBank } = require('./concept');

const U_ORG = 'Organic Chemistry';
const U_METAL = 'Metals and Non-Metals';
const U_IND = 'Industrial and Environmental Chemistry';
const mathOpt = (s) => `\\(${s}\\)`;

const ALKANES = [
  { n: 1, name: 'methane', f: 'CH_{4}' }, { n: 2, name: 'ethane', f: 'C_{2}H_{6}' },
  { n: 3, name: 'propane', f: 'C_{3}H_{8}' }, { n: 4, name: 'butane', f: 'C_{4}H_{10}' },
  { n: 5, name: 'pentane', f: 'C_{5}H_{12}' }, { n: 6, name: 'hexane', f: 'C_{6}H_{14}' },
  { n: 7, name: 'heptane', f: 'C_{7}H_{16}' }, { n: 8, name: 'octane', f: 'C_{8}H_{18}' },
];
const ALKENES = [
  { n: 2, name: 'ethene', f: 'C_{2}H_{4}' }, { n: 3, name: 'propene', f: 'C_{3}H_{6}' },
  { n: 4, name: 'butene', f: 'C_{4}H_{8}' }, { n: 5, name: 'pentene', f: 'C_{5}H_{10}' },
  { n: 6, name: 'hexene', f: 'C_{6}H_{12}' },
];

// =============================== ALKANES ===============================
const alkanes = [
  // formula from name
  () => {
    const a = pick(ALKANES);
    const others = ALKANES.filter(x => x.n !== a.n).slice(0, 3).map(x => x.f);
    const o = textOptions(mathOpt(a.f), sample(others, 3).map(mathOpt));
    if (!o) return null;
    return {
      text: `What is the molecular formula of ${a.name}?`,
      ...o,
      explanation: `Alkanes have the general formula \\(C_nH_{2n+2}\\).\n\nFor ${a.name}, \\(n = ${a.n}\\), so the formula is \\(C_{${a.n}}H_{${2 * a.n + 2}}\\), that is \\(${a.f}\\).`,
    };
  },
  // general formula
  () => {
    const o = textOptions(mathOpt('C_nH_{2n+2}'), [mathOpt('C_nH_{2n}'), mathOpt('C_nH_{2n-2}'), mathOpt('C_nH_{n+2}')]);
    if (!o) return null;
    return {
      text: `What is the general formula of the alkanes?`,
      ...o,
      explanation: `Alkanes are saturated hydrocarbons with only single carbon-carbon bonds.\n\nTheir general formula is \\(C_nH_{2n+2}\\).`,
    };
  },
  // number of hydrogens
  () => {
    const n = randInt(1, 12);
    const h = 2 * n + 2;
    const o = buildOptions(h, [2 * n, 2 * n - 2, n + 2], (v) => String(v));
    if (!o) return null;
    return {
      text: `How many hydrogen atoms are present in an alkane containing ${n} carbon atom${n === 1 ? '' : 's'}?`,
      ...o,
      explanation: `Using \\(C_nH_{2n+2}\\) with \\(n = ${n}\\):\n\n\\(2(${n}) + 2 = ${h}\\) hydrogen atoms`,
    };
  },
  ...conceptGens('alkanes', [
    'Alkanes are saturated hydrocarbons containing only single bonds',
    'Alkanes have the general formula CnH2n+2',
    'Alkanes undergo substitution reactions with halogens in the presence of sunlight',
    'Alkanes burn in excess air to give carbon(IV) oxide and water',
    'Alkanes are generally unreactive towards acids and alkalis',
    'Methane is the simplest member of the alkane series',
    'Alkanes do not decolourise bromine water in the dark',
  ], [
    'Alkanes are unsaturated hydrocarbons containing double bonds',
    'Alkanes have the general formula CnH2n',
    'Alkanes undergo addition reactions with hydrogen',
    'Alkanes readily decolourise bromine water in the dark',
    'Alkanes react vigorously with dilute acids',
    'Ethene is the simplest member of the alkane series',
  ]),
];

// ========================= ALKENES AND ALKYNES =========================
const alkenes = [
  // formula
  () => {
    const a = pick(ALKENES);
    const others = ALKENES.filter(x => x.n !== a.n).map(x => x.f);
    const o = textOptions(mathOpt(a.f), sample(others, 3).map(mathOpt));
    if (!o) return null;
    return {
      text: `What is the molecular formula of ${a.name}?`,
      ...o,
      explanation: `Alkenes have the general formula \\(C_nH_{2n}\\).\n\nFor ${a.name}, \\(n = ${a.n}\\), giving \\(${a.f}\\).`,
    };
  },
  // general formulae
  () => {
    const which = pick([
      { s: 'alkenes', f: 'C_nH_{2n}', w: ['C_nH_{2n+2}', 'C_nH_{2n-2}', 'C_nH_{n}'] },
      { s: 'alkynes', f: 'C_nH_{2n-2}', w: ['C_nH_{2n}', 'C_nH_{2n+2}', 'C_nH_{n-2}'] },
    ]);
    const o = textOptions(mathOpt(which.f), which.w.map(mathOpt));
    if (!o) return null;
    return {
      text: `What is the general formula of the ${which.s}?`,
      ...o,
      explanation: `The ${which.s} have the general formula \\(${which.f}\\).`,
    };
  },
  ...conceptGens('alkenes and alkynes', [
    'Alkenes are unsaturated hydrocarbons containing a carbon-carbon double bond',
    'Alkynes contain a carbon-carbon triple bond',
    'Alkenes decolourise bromine water',
    'Alkenes undergo addition reactions',
    'Ethene is used in the manufacture of polythene',
    'Alkenes are more reactive than alkanes',
    'The addition of hydrogen to an alkene is called hydrogenation',
    'Alkenes have the general formula CnH2n',
  ], [
    'Alkenes are saturated hydrocarbons',
    'Alkenes do not decolourise bromine water',
    'Alkenes undergo substitution reactions in preference to addition',
    'Alkanes are more reactive than alkenes',
    'Alkynes contain only single bonds',
    'Alkenes have the general formula CnH2n+2',
  ], [
    { q: 'Which reagent is used to distinguish between ethane and ethene?', a: 'Bromine water', w: ['Limewater', 'Sodium hydroxide solution', 'Silver trioxonitrate(V) solution'], e: 'Ethene is unsaturated and decolourises the orange-brown bromine water by addition across the double bond. Ethane, being saturated, does not.' },
    { q: 'What is the product of the addition of hydrogen to ethene?', a: 'Ethane', w: ['Ethyne', 'Ethanol', 'Ethanoic acid'], e: 'Hydrogenation adds \\(H_2\\) across the double bond, converting the unsaturated ethene into the saturated alkane ethane.' },
  ]),
];

// =============================== ALKANOLS ===============================
const alkanols = [
  ...conceptGens('alkanols (alcohols)', [
    'Alkanols contain the hydroxyl functional group',
    'The general formula of the alkanols is CnH2n+1OH',
    'Ethanol is produced industrially by the fermentation of sugars',
    'Ethanol burns with a clean blue flame',
    'Primary alkanols are oxidised first to alkanals and then to alkanoic acids',
    'Alkanols react with sodium to liberate hydrogen gas',
    'Ethanol is used as a solvent and as a fuel',
    'The oxidation of ethanol gives ethanoic acid',
  ], [
    'Alkanols contain the carboxyl functional group',
    'The general formula of the alkanols is CnH2n',
    'Ethanol does not react with sodium metal',
    'Alkanols are oxidised directly to alkanes',
    'Ethanol is produced by the hydrolysis of soap',
    'Alkanols are completely unreactive',
  ], [
    { q: 'What is the functional group present in alkanols?', a: 'The hydroxyl group, -OH', w: ['The carboxyl group, -COOH', 'The carbonyl group, -CO-', 'The amino group, -NH2'], e: 'Alkanols are characterised by the \\(-OH\\) group attached to a saturated carbon, which gives them their typical reactions with sodium and on oxidation.' },
    { q: 'Which gas is liberated when sodium metal is added to ethanol?', a: 'Hydrogen', w: ['Oxygen', 'Carbon(IV) oxide', 'Ethane'], e: 'Sodium displaces the hydrogen of the hydroxyl group, forming sodium ethoxide and releasing hydrogen gas.' },
    { q: 'What is the product when ethanol is completely oxidised by acidified potassium tetraoxomanganate(VII)?', a: 'Ethanoic acid', w: ['Ethane', 'Ethene', 'Ethyl ethanoate'], e: 'A primary alkanol oxidises first to the alkanal (ethanal) and then, with excess oxidising agent, to the alkanoic acid.' },
    { q: 'By what process is ethanol produced from glucose using yeast?', a: 'Fermentation', w: ['Cracking', 'Polymerisation', 'Esterification'], e: 'Enzymes in yeast convert glucose anaerobically into ethanol and carbon(IV) oxide.' },
  ]),
];

// ==================== ALKANOIC ACIDS AND ESTERS ====================
const acidsEsters = [
  ...conceptGens('alkanoic acids and esters', [
    'Alkanoic acids contain the carboxyl functional group',
    'Ethanoic acid is the acid present in vinegar',
    'Alkanoic acids turn blue litmus paper red',
    'Alkanoic acids react with trioxocarbonate(IV) salts to liberate carbon(IV) oxide',
    'An ester is formed when an alkanoic acid reacts with an alkanol',
    'Esterification is catalysed by concentrated tetraoxosulphate(VI) acid',
    'Esters generally have pleasant fruity smells',
    'The hydrolysis of an ester by an alkali is called saponification',
  ], [
    'Alkanoic acids contain the hydroxyl group as their only functional group',
    'Alkanoic acids turn red litmus paper blue',
    'Esters are formed when two alkanols react together',
    'Esters have unpleasant, pungent smells',
    'Saponification is the formation of an ester from an acid and an alcohol',
    'Alkanoic acids do not react with trioxocarbonate(IV) salts',
  ], [
    { q: 'What is formed when ethanoic acid reacts with ethanol in the presence of concentrated tetraoxosulphate(VI) acid?', a: 'Ethyl ethanoate and water', w: ['Ethane and water', 'Sodium ethanoate and hydrogen', 'Ethene and carbon(IV) oxide'], e: 'This is esterification. The acid and the alkanol condense to form an ester, with water eliminated; the mineral acid is the catalyst.' },
    { q: 'What is the common name for the process of hydrolysing fats and oils with alkali to make soap?', a: 'Saponification', w: ['Esterification', 'Polymerisation', 'Fermentation'], e: 'Saponification is the alkaline hydrolysis of the ester links in fats and oils, producing soap (the salt of a long-chain alkanoic acid) and glycerol.' },
    { q: 'Which functional group is present in alkanoic acids?', a: '-COOH', w: ['-OH', '-CHO', '-COO-'], e: 'The carboxyl group \\(-COOH\\) combines a carbonyl and a hydroxyl on the same carbon, which is what makes these compounds acidic.' },
  ]),
];

// =============================== POLYMERS ===============================
const polymers = [
  // monomer -> polymer
  () => {
    const bank = [
      { m: 'ethene', p: 'polythene', w: ['polystyrene', 'nylon', 'PVC'] },
      { m: 'chloroethene (vinyl chloride)', p: 'PVC', w: ['polythene', 'nylon', 'terylene'] },
      { m: 'phenylethene (styrene)', p: 'polystyrene', w: ['polythene', 'PVC', 'nylon'] },
      { m: 'tetrafluoroethene', p: 'PTFE (Teflon)', w: ['polythene', 'nylon', 'PVC'] },
    ];
    const x = pick(bank);
    const o = textOptions(x.p, x.w);
    if (!o) return null;
    return {
      text: `Which polymer is formed from the monomer ${x.m}?`,
      ...o,
      explanation: `Addition polymerisation of ${x.m} gives ${x.p}, as the double bond opens and the units join in a long chain.`,
    };
  },
  ...conceptGens('polymers', [
    'A polymer is a large molecule built from many repeating monomer units',
    'Addition polymerisation involves monomers containing a carbon-carbon double bond',
    'Condensation polymerisation eliminates a small molecule such as water',
    'Polythene is formed from ethene by addition polymerisation',
    'Nylon and terylene are condensation polymers',
    'Most synthetic polymers are non-biodegradable and cause environmental problems',
    'Starch, cellulose and proteins are natural polymers',
  ], [
    'A polymer is a small molecule made by breaking down a monomer',
    'Addition polymerisation eliminates a molecule of water',
    'Polythene is a condensation polymer',
    'All synthetic polymers are readily biodegradable',
    'Proteins are synthetic addition polymers',
    'Condensation polymerisation requires a carbon-carbon double bond',
  ]),
];

// ========================== PETROLEUM REFINING ==========================
const petroleum = [
  ...conceptGens('petroleum refining', [
    'Petroleum is separated into fractions by fractional distillation',
    'Fractions with lower boiling points are collected higher up the fractionating column',
    'Cracking converts long-chain hydrocarbons into shorter, more useful ones',
    'Cracking produces alkenes as well as shorter alkanes',
    'Petrol, kerosene and diesel are all fractions obtained from crude oil',
    'Bitumen is the residue with the highest boiling point',
    'Reforming improves the octane rating of petrol',
    'Incomplete combustion of petroleum fuels produces poisonous carbon(II) oxide',
  ], [
    'Petroleum is separated by filtration',
    'Fractions with higher boiling points are collected at the top of the column',
    'Cracking joins short hydrocarbons into longer chains',
    'Bitumen has the lowest boiling point of all the fractions',
    'Complete combustion of hydrocarbons produces carbon(II) oxide',
    'Cracking produces only alkanes and no alkenes',
  ], [
    { q: 'What is the purpose of cracking in petroleum refining?', a: 'To convert long-chain hydrocarbons into shorter, more useful molecules', w: ['To join short hydrocarbons into longer chains', 'To remove sulphur from crude oil', 'To separate crude oil into fractions'], e: 'The heavy fractions are in surplus while petrol and alkenes are in demand, so cracking breaks large molecules into smaller, more valuable ones.' },
    { q: 'Which fraction of crude oil is collected at the very top of the fractionating column?', a: 'Refinery gas', w: ['Bitumen', 'Diesel oil', 'Lubricating oil'], e: 'The column is hottest at the base. Only the fractions with the lowest boiling points remain gaseous to the top, and refinery gas is the lightest.' },
    { q: 'Which gas is produced by the incomplete combustion of petroleum fuels?', a: 'Carbon(II) oxide', w: ['Carbon(IV) oxide', 'Oxygen', 'Hydrogen'], e: 'With insufficient oxygen, carbon is only partially oxidised to carbon(II) oxide, a colourless, odourless and highly poisonous gas.' },
  ]),
];

// ========================= EXTRACTION OF METALS =========================
const extraction = [
  // ore of a metal
  () => {
    const bank = [
      { m: 'aluminium', ore: 'Bauxite', w: ['Haematite', 'Galena', 'Limestone'] },
      { m: 'iron', ore: 'Haematite', w: ['Bauxite', 'Galena', 'Cryolite'] },
      { m: 'lead', ore: 'Galena', w: ['Bauxite', 'Haematite', 'Cryolite'] },
      { m: 'zinc', ore: 'Zinc blende', w: ['Bauxite', 'Haematite', 'Galena'] },
    ];
    const x = pick(bank);
    const o = textOptions(x.ore, x.w);
    if (!o) return null;
    return {
      text: `What is the principal ore of ${x.m}?`,
      ...o,
      explanation: `${x.ore} is the chief ore from which ${x.m} is extracted.`,
    };
  },
  ...conceptGens('the extraction of metals', [
    'Highly reactive metals such as aluminium are extracted by electrolysis',
    'Moderately reactive metals such as iron are extracted by reduction with carbon',
    'Aluminium is extracted from purified bauxite dissolved in molten cryolite',
    'Cryolite is added in aluminium extraction to lower the melting point of the alumina',
    'Iron is extracted in the blast furnace using coke, limestone and hot air',
    'Limestone removes acidic impurities as slag in the blast furnace',
    'The method of extraction depends on the reactivity of the metal',
    'Unreactive metals such as gold occur native in the earth',
  ], [
    'Aluminium is extracted by reduction with carbon in a blast furnace',
    'Cryolite raises the melting point of alumina',
    'Iron is extracted by electrolysis of its molten ore',
    'Limestone is added to the blast furnace as a fuel',
    'All metals are extracted by the same method',
    'Gold must be extracted by electrolysis because it is highly reactive',
  ]),
];

// ========================= PROPERTIES OF METALS =========================
const metalProps = [
  // reactivity series ordering
  () => {
    const pairs = [
      { a: 'magnesium', b: 'copper', more: 'magnesium' },
      { a: 'zinc', b: 'silver', more: 'zinc' },
      { a: 'iron', b: 'gold', more: 'iron' },
      { a: 'sodium', b: 'iron', more: 'sodium' },
      { a: 'calcium', b: 'lead', more: 'calcium' },
    ];
    const x = pick(pairs);
    const o = textOptions(x.more.charAt(0).toUpperCase() + x.more.slice(1),
      [(x.more === x.a ? x.b : x.a).charAt(0).toUpperCase() + (x.more === x.a ? x.b : x.a).slice(1),
       'They are equally reactive', 'It cannot be determined']);
    if (!o) return null;
    return {
      text: `Which is the more reactive metal, ${x.a} or ${x.b}?`,
      ...o,
      explanation: `In the activity series, ${x.more} lies above the other metal, so ${x.more} is more reactive and would displace the other from a solution of its salt.`,
    };
  },
  ...conceptGens('the properties of metals', [
    'Metals are good conductors of heat and electricity',
    'Metals are malleable and ductile',
    'Metals generally have high melting and boiling points',
    'Metals form positive ions by losing electrons',
    'Metals form basic oxides',
    'A more reactive metal displaces a less reactive metal from a solution of its salt',
    'Metals are usually shiny when freshly cut',
    'Mercury is the only metal that is liquid at room temperature',
  ], [
    'Metals are poor conductors of electricity',
    'Metals are brittle and break easily when hammered',
    'Metals form negative ions by gaining electrons',
    'Metals form acidic oxides',
    'A less reactive metal displaces a more reactive metal from solution',
    'All metals are solid at room temperature',
  ]),
];

// =============================== HALOGENS ===============================
const halogens = [
  ...conceptGens('the halogens', [
    'The halogens are the elements of group 7 of the periodic table',
    'Halogens exist as diatomic molecules',
    'Reactivity decreases down the halogen group from fluorine to iodine',
    'Chlorine is a greenish-yellow gas with a choking smell',
    'Chlorine displaces bromine from a solution of a bromide',
    'Chlorine is used to sterilise drinking water',
    'Halogens form salts when they react with metals',
    'Iodine is a grey solid that sublimes to a purple vapour',
  ], [
    'The halogens are the elements of group 1',
    'Halogens exist as single, unbonded atoms',
    'Reactivity increases down the halogen group',
    'Chlorine is a colourless, odourless gas',
    'Iodine displaces chlorine from a solution of a chloride',
    'Halogens form only basic oxides with metals',
    'Chlorine is unreactive towards metals',
  ], [
    { q: 'Why does chlorine displace bromine from potassium bromide solution?', a: 'Chlorine is more reactive than bromine', w: ['Bromine is more reactive than chlorine', 'Chlorine is denser than bromine', 'Bromine is a gas at room temperature'], e: 'Reactivity falls down group 7, so the more reactive chlorine takes the electrons and the bromide is oxidised to bromine.' },
    { q: 'What is the main use of chlorine in water treatment?', a: 'To kill bacteria and sterilise the water', w: ['To remove suspended solids', 'To soften hard water', 'To increase the pH of the water'], e: 'Chlorine is a powerful oxidising agent and disinfectant, destroying pathogenic micro-organisms in the supply.' },
  ]),
];

// ===================== SULPHUR AND ITS COMPOUNDS =====================
const sulphur = [
  ...conceptGens('sulphur and its compounds', [
    'Sulphur(IV) oxide is a colourless gas with a choking smell',
    'Sulphur(IV) oxide turns acidified potassium heptaoxodichromate(VI) from orange to green',
    'Concentrated tetraoxosulphate(VI) acid is a powerful dehydrating agent',
    'Tetraoxosulphate(VI) acid is manufactured by the Contact process',
    'Sulphur(IV) oxide is a bleaching agent in the presence of moisture',
    'Sulphur(IV) oxide released from burning fossil fuels causes acid rain',
    'Concentrated tetraoxosulphate(VI) acid chars sugar by removing the elements of water',
  ], [
    'Sulphur(IV) oxide is a bright yellow gas',
    'Concentrated tetraoxosulphate(VI) acid is a strong reducing agent with no dehydrating action',
    'Tetraoxosulphate(VI) acid is manufactured by the Haber process',
    'Sulphur(IV) oxide has no effect on the environment',
    'Sulphur(IV) oxide turns limewater green',
    'Sulphur is a metal',
  ], [
    { q: 'By which industrial process is tetraoxosulphate(VI) acid manufactured?', a: 'The Contact process', w: ['The Haber process', 'The Solvay process', 'The Frasch process'], e: 'The Contact process oxidises sulphur(IV) oxide to sulphur(VI) oxide over a vanadium(V) oxide catalyst, then absorbs it to form the acid.' },
    { q: 'Why is concentrated tetraoxosulphate(VI) acid described as a dehydrating agent?', a: 'It removes the elements of water from compounds such as sugar', w: ['It dissolves readily in water', 'It adds water to compounds', 'It evaporates water on heating'], e: 'It removes hydrogen and oxygen in a 2:1 ratio from a substance, which is why sugar chars to carbon in its presence.' },
  ]),
];

// ==================== NITROGEN AND ITS COMPOUNDS ====================
const nitrogen = [
  ...conceptGens('nitrogen and its compounds', [
    'Nitrogen makes up about 78% of the atmosphere by volume',
    'Nitrogen is a colourless, odourless and relatively unreactive gas',
    'Ammonia is manufactured by the Haber process',
    'Ammonia is the only common alkaline gas',
    'Ammonia turns damp red litmus paper blue',
    'Ammonia gives dense white fumes with hydrogen chloride gas',
    'Trioxonitrate(V) acid is manufactured by the Ostwald process',
    'Nitrogen is used to provide an inert atmosphere in food packaging',
  ], [
    'Nitrogen makes up about 21% of the atmosphere',
    'Ammonia turns damp blue litmus paper red',
    'Ammonia is manufactured by the Contact process',
    'Nitrogen is a highly reactive gas at room temperature',
    'Ammonia is an acidic gas',
    'Trioxonitrate(V) acid is manufactured by the Haber process',
  ], [
    { q: 'By which process is ammonia manufactured industrially?', a: 'The Haber process', w: ['The Contact process', 'The Ostwald process', 'The Solvay process'], e: 'Nitrogen and hydrogen combine over a finely divided iron catalyst at high pressure and moderate temperature to form ammonia.' },
    { q: 'Which gas gives dense white fumes when it comes into contact with hydrogen chloride gas?', a: 'Ammonia', w: ['Sulphur(IV) oxide', 'Carbon(IV) oxide', 'Chlorine'], e: 'Ammonia and hydrogen chloride combine directly to form solid ammonium chloride, seen as a dense white smoke. It is the standard test for ammonia.' },
    { q: 'What percentage of the atmosphere by volume is nitrogen?', a: 'About 78%', w: ['About 21%', 'About 50%', 'About 0.03%'], e: 'Nitrogen is the most abundant atmospheric gas at roughly 78% by volume, with oxygen about 21%.' },
  ]),
];

// ============================ WATER TREATMENT ============================
const water = [
  ...conceptGens('water treatment and hardness', [
    'Temporary hardness in water is caused by dissolved hydrogentrioxocarbonate(IV) salts of calcium and magnesium',
    'Temporary hardness can be removed by boiling',
    'Permanent hardness is caused by dissolved chlorides and tetraoxosulphate(VI) salts of calcium and magnesium',
    'Permanent hardness cannot be removed by boiling',
    'Hard water forms scum with soap rather than a lather',
    'Water is sterilised by chlorination',
    'Sedimentation and filtration remove suspended solids during water treatment',
    'Distillation and ion exchange remove both types of hardness',
  ], [
    'Temporary hardness cannot be removed by boiling',
    'Permanent hardness is removed simply by boiling the water',
    'Hard water lathers more readily with soap than soft water',
    'Chlorination is used to remove hardness from water',
    'Hardness in water is caused by dissolved sodium salts',
    'Boiling removes all forms of hardness from water',
  ], [
    { q: 'What causes temporary hardness in water?', a: 'Dissolved calcium and magnesium hydrogentrioxocarbonate(IV)', w: ['Dissolved calcium tetraoxosulphate(VI)', 'Dissolved sodium chloride', 'Suspended clay particles'], e: 'These hydrogencarbonates decompose on heating to give insoluble carbonates, which is why boiling removes this type of hardness.' },
    { q: 'Which method removes both temporary and permanent hardness from water?', a: 'Ion exchange', w: ['Boiling', 'Filtration', 'Sedimentation'], e: 'An ion-exchange resin swaps the calcium and magnesium ions for sodium ions, so every hardness-causing ion is removed regardless of the anion.' },
    { q: 'Why does hard water form scum with soap?', a: 'Calcium and magnesium ions react with soap to form an insoluble precipitate', w: ['It contains too much sodium', 'It is acidic', 'It contains dissolved chlorine'], e: 'The soap anions form insoluble calcium and magnesium salts, which appear as scum and waste soap before any lather forms.' },
  ]),
];

// ============================= AIR POLLUTION =============================
const pollution = [
  // pollutant source
  () => {
    const bank = [
      { p: 'carbon(II) oxide', s: 'Incomplete combustion of fuels', w: ['Complete combustion of hydrogen', 'Photosynthesis', 'Evaporation of water'] },
      { p: 'sulphur(IV) oxide', s: 'Burning of fossil fuels containing sulphur', w: ['Respiration in animals', 'Photosynthesis', 'Evaporation of sea water'] },
      { p: 'oxides of nitrogen', s: 'High-temperature combustion in vehicle engines', w: ['Photosynthesis in green plants', 'Evaporation of water', 'Fermentation of sugars'] },
      { p: 'lead compounds', s: 'Combustion of leaded petrol', w: ['Photosynthesis', 'Respiration', 'Rainfall'] },
    ];
    const x = pick(bank);
    const o = textOptions(x.s, x.w);
    if (!o) return null;
    return {
      text: `What is the main source of ${x.p} as an air pollutant?`,
      ...o,
      explanation: `${x.s} is the principal source of ${x.p} in the atmosphere.`,
    };
  },
  ...conceptGens('air pollution', [
    'Carbon(II) oxide is poisonous because it combines with haemoglobin in the blood',
    'Sulphur(IV) oxide and oxides of nitrogen are the main causes of acid rain',
    'Carbon(IV) oxide is a greenhouse gas that contributes to global warming',
    'Chlorofluorocarbons damage the ozone layer',
    'Acid rain damages buildings, forests and aquatic life',
    'Catalytic converters reduce harmful emissions from vehicle exhausts',
    'Carbon(II) oxide is a colourless and odourless gas',
  ], [
    'Carbon(II) oxide is harmless to humans',
    'Acid rain is caused mainly by carbon(II) oxide',
    'Chlorofluorocarbons strengthen the ozone layer',
    'Carbon(IV) oxide has no effect on global temperature',
    'Catalytic converters increase the emission of harmful gases',
    'Carbon(II) oxide has a strong, easily detected smell',
  ]),
];

// ============================== FERTILISERS ==============================
const fertilisers = [
  ...conceptGens('fertilisers', [
    'The three main nutrients supplied by fertilisers are nitrogen, phosphorus and potassium',
    'NPK fertilisers supply nitrogen, phosphorus and potassium together',
    'Nitrogenous fertilisers promote the growth of leaves and stems',
    'Ammonium tetraoxosulphate(VI) is a nitrogenous fertiliser',
    'Excessive use of fertilisers causes eutrophication of rivers and lakes',
    'Eutrophication leads to algal blooms and depletion of dissolved oxygen',
    'Fertilisers replace nutrients removed from the soil by crops',
  ], [
    'The main nutrients supplied by fertilisers are carbon, hydrogen and oxygen',
    'Nitrogenous fertilisers mainly promote root growth',
    'Excessive fertiliser use improves the oxygen content of rivers',
    'Fertilisers remove nutrients from the soil',
    'Eutrophication increases the dissolved oxygen in water',
    'NPK fertilisers contain no nitrogen',
  ], [
    { q: 'Which three elements are the principal nutrients supplied by NPK fertilisers?', a: 'Nitrogen, phosphorus and potassium', w: ['Nitrogen, potassium and platinum', 'Nickel, phosphorus and potassium', 'Nitrogen, phosphorus and palladium'], e: 'N, P and K are the macronutrients most often depleted by cropping, which is why compound fertilisers are graded by their NPK content.' },
    { q: 'What environmental problem is caused by the excessive use of fertilisers?', a: 'Eutrophication of water bodies', w: ['Depletion of the ozone layer', 'Acid rain', 'Global warming'], e: 'Nutrient run-off triggers rapid algal growth; when the algae die, decomposition consumes the dissolved oxygen and aquatic life suffocates.' },
  ]),
];

// ========================= INDUSTRIAL PROCESSES =========================
const processes = [
  // process -> product
  () => {
    const bank = [
      { p: 'the Haber process', prod: 'Ammonia', w: ['Tetraoxosulphate(VI) acid', 'Sodium trioxocarbonate(IV)', 'Ethanol'] },
      { p: 'the Contact process', prod: 'Tetraoxosulphate(VI) acid', w: ['Ammonia', 'Sodium hydroxide', 'Nitric acid'] },
      { p: 'the Solvay process', prod: 'Sodium trioxocarbonate(IV)', w: ['Ammonia', 'Tetraoxosulphate(VI) acid', 'Aluminium'] },
      { p: 'the Ostwald process', prod: 'Trioxonitrate(V) acid', w: ['Ammonia', 'Sodium hydroxide', 'Ethanol'] },
    ];
    const x = pick(bank);
    const o = textOptions(x.prod, x.w);
    if (!o) return null;
    return {
      text: `What is the main product of ${x.p}?`,
      ...o,
      explanation: `${x.p.charAt(0).toUpperCase() + x.p.slice(1)} is the industrial manufacture of ${x.prod.toLowerCase()}.`,
    };
  },
  ...conceptGens('industrial chemical processes', [
    'The Haber process manufactures ammonia from nitrogen and hydrogen',
    'The Contact process manufactures tetraoxosulphate(VI) acid',
    'The Solvay process manufactures sodium trioxocarbonate(IV)',
    'Industrial processes are designed to maximise yield while minimising cost',
    'A catalyst is used in the Haber process to speed up the attainment of equilibrium',
    'Vanadium(V) oxide is the catalyst in the Contact process',
    'Industrial siting considers the availability of raw materials, power and transport',
  ], [
    'The Haber process manufactures tetraoxosulphate(VI) acid',
    'The Contact process manufactures ammonia',
    'Catalysts increase the equilibrium yield of ammonia',
    'Industrial processes ignore the cost of raw materials',
    'The Solvay process manufactures aluminium',
    'No catalyst is used in the Contact process',
  ]),
];

module.exports = [
  { unitName: U_ORG, topicName: 'Alkanes', generators: alkanes },
  { unitName: U_ORG, topicName: 'Alkenes and Alkynes', generators: alkenes },
  { unitName: U_ORG, topicName: 'Alkanols', generators: alkanols },
  { unitName: U_ORG, topicName: 'Alkanoic Acids and Esters', generators: acidsEsters },
  { unitName: U_ORG, topicName: 'Polymers', generators: polymers },
  { unitName: U_ORG, topicName: 'Petroleum Refining', generators: petroleum },
  { unitName: U_METAL, topicName: 'Extraction of Metals', generators: extraction },
  { unitName: U_METAL, topicName: 'Properties of Metals', generators: metalProps },
  { unitName: U_METAL, topicName: 'Halogens', generators: halogens },
  { unitName: U_METAL, topicName: 'Sulphur and its Compounds', generators: sulphur },
  { unitName: U_METAL, topicName: 'Nitrogen and its Compounds', generators: nitrogen },
  { unitName: U_IND, topicName: 'Water Treatment', generators: water },
  { unitName: U_IND, topicName: 'Air Pollution', generators: pollution },
  { unitName: U_IND, topicName: 'Fertilisers', generators: fertilisers },
  { unitName: U_IND, topicName: 'Industrial Processes', generators: processes },
];
