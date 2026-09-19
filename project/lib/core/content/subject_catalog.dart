/// Static outline of every subject Paragon intends to ship.
///
/// This is **not** a replacement for Firestore — `.cursorrules` is explicit
/// that subject/unit/topic data is loaded from Firestore, never hardcoded.
/// The catalog exists for exactly two jobs the live data can't do yet:
///
///  1. **Reach.** Only three subjects are seeded (Mathematics, Physics,
///     Further Mathematics). The other seven have no Firestore documents at
///     all, so there is nothing to navigate to. The catalog gives them a
///     stable route key and a name so their course page is reachable and
///     designed before the content lands.
///  2. **Shape.** A course page with no modules is an empty rectangle. The
///     outlines below are WAEC-syllabus-shaped placeholders so the layout
///     can be reviewed at realistic content density.
///
/// Rules for anything reading this file:
///  - A subject with live Firestore units **always** wins. `courseProvider`
///    falls back to [CatalogSubject.outline] only when Firestore returns no
///    units for that subject. Never merge the two.
///  - Placeholder topics carry no question data and must never be presented
///    as practisable — see `CourseTopic.isPlaceholder` in course_repository.
///  - When a subject is seeded for real, delete its outline here rather than
///    letting the two drift.
library;

/// One unit (module) in a placeholder outline.
class CatalogUnit {
  const CatalogUnit(this.name, this.topics);

  final String name;
  final List<String> topics;
}

/// One subject in the planned catalog.
class CatalogSubject {
  const CatalogSubject({
    required this.slug,
    required this.name,
    required this.blurb,
    this.outline = const [],
  });

  /// Route key for subjects with no Firestore document yet. Live subjects
  /// are normally reached by their Firestore document id, but this slug
  /// resolves them too (see `courseProvider`), so `/subject/physics/course`
  /// works as a readable deep link.
  final String slug;

  final String name;

  /// One line for the catalog card — describes the syllabus area, not
  /// marketing copy.
  final String blurb;

  /// Placeholder unit/topic outline. Empty for subjects whose real
  /// structure already lives in Firestore.
  final List<CatalogUnit> outline;
}

class SubjectCatalog {
  const SubjectCatalog._();

  /// `Further Mathematics` -> `further-mathematics`. Matches the
  /// myschool.ng slugs the scraper already uses (`.cursorrules` §7).
  static String slugify(String name) => name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  static CatalogSubject? bySlug(String slug) {
    for (final subject in all) {
      if (subject.slug == slug) return subject;
    }
    return null;
  }

  static CatalogSubject? byName(String name) => bySlug(slugify(name));

  /// Ordered the way the catalog page lists them: seeded subjects first,
  /// then Phase 2, then low-priority — matching the content priorities in
  /// `.cursorrules` §11.
  static const List<CatalogSubject> all = [
    // ── Seeded: structure comes from Firestore, so no outline here ───────
    CatalogSubject(
      slug: 'mathematics',
      name: 'Mathematics',
      blurb: 'Number, algebra, geometry, trigonometry and calculus.',
    ),
    CatalogSubject(
      slug: 'physics',
      name: 'Physics',
      blurb: 'Motion, energy, waves, electricity and the atom.',
    ),
    CatalogSubject(
      slug: 'further-mathematics',
      name: 'Further Mathematics',
      blurb: 'Pure mathematics, statistics, vectors and mechanics.',
    ),

    // ── Phase 2 and low-priority: placeholder outlines ───────────────────
    CatalogSubject(
      slug: 'chemistry',
      name: 'Chemistry',
      blurb: 'Matter, bonding, reactions and organic chemistry.',
      outline: [
        CatalogUnit('Separation of Mixtures', [
          'Pure and Impure Substances',
          'Filtration and Evaporation',
          'Distillation',
          'Chromatography',
          'Sublimation',
        ]),
        CatalogUnit('Atomic Structure and Bonding', [
          'Atoms, Molecules and Ions',
          'Electron Configuration',
          'The Periodic Table',
          'Types of Chemical Bonding',
          'Shapes of Molecules',
        ]),
        CatalogUnit('States of Matter', [
          'Kinetic Theory',
          'Gas Laws',
          'Vapour Pressure',
          'Crystal Structure',
        ]),
        CatalogUnit('Chemical Reactions', [
          'Writing and Balancing Equations',
          'The Mole Concept',
          'Stoichiometry',
          'Laws of Chemical Combination',
        ]),
        CatalogUnit('Acids, Bases and Salts', [
          'Properties of Acids and Bases',
          'pH and Indicators',
          'Neutralisation and Titration',
          'Preparation of Salts',
          'Hydrolysis of Salts',
        ]),
        CatalogUnit('Energy and Rates', [
          'Enthalpy Changes',
          'Rates of Reaction',
          'Chemical Equilibrium',
          'Catalysis',
        ]),
        CatalogUnit('Electrochemistry', [
          'Oxidation and Reduction',
          'Electrolysis',
          'Electrochemical Cells',
          'Corrosion',
        ]),
        CatalogUnit('Organic Chemistry', [
          'Alkanes',
          'Alkenes and Alkynes',
          'Alkanols',
          'Alkanoic Acids and Esters',
          'Polymers',
          'Petroleum Refining',
        ]),
        CatalogUnit('Metals and Non-Metals', [
          'Extraction of Metals',
          'Properties of Metals',
          'Halogens',
          'Sulphur and its Compounds',
          'Nitrogen and its Compounds',
        ]),
        CatalogUnit('Industrial and Environmental Chemistry', [
          'Water Treatment',
          'Air Pollution',
          'Fertilisers',
          'Industrial Processes',
        ]),
      ],
    ),
    CatalogSubject(
      slug: 'biology',
      name: 'Biology',
      blurb: 'Cells, organisms, genetics, ecology and the environment.',
      outline: [
        CatalogUnit('Concept of Living Things', [
          'Characteristics of Living Things',
          'Cell Structure and Function',
          'Cell Division',
          'Levels of Organisation',
        ]),
        CatalogUnit('Classification', [
          'Kingdoms of Living Things',
          'Viruses and Bacteria',
          'Plant Classification',
          'Animal Classification',
        ]),
        CatalogUnit('Nutrition', [
          'Modes of Nutrition',
          'Photosynthesis',
          'The Digestive System',
          'Food Substances and Tests',
          'Balanced Diet',
        ]),
        CatalogUnit('Transport Systems', [
          'Blood and Circulation',
          'Transport in Plants',
          'The Lymphatic System',
        ]),
        CatalogUnit('Respiration and Excretion', [
          'Respiratory Organs',
          'Aerobic and Anaerobic Respiration',
          'Excretory Organs',
          'Kidneys and Homeostasis',
        ]),
        CatalogUnit('Support and Movement', [
          'The Skeletal System',
          'Muscles and Movement',
          'Support in Plants',
        ]),
        CatalogUnit('Reproduction and Growth', [
          'Asexual Reproduction',
          'Reproduction in Plants',
          'Reproduction in Humans',
          'Growth and Development',
        ]),
        CatalogUnit('Genetics and Evolution', [
          'Mendelian Genetics',
          'Chromosomes and DNA',
          'Variation',
          'Theories of Evolution',
        ]),
        CatalogUnit('Ecology', [
          'Ecosystems',
          'Food Chains and Webs',
          'Population Studies',
          'Nutrient Cycles',
          'Adaptation',
        ]),
        CatalogUnit('Man and His Environment', [
          'Conservation',
          'Pollution',
          'Diseases and Vectors',
          'Food Production',
        ]),
      ],
    ),
    CatalogSubject(
      slug: 'economics',
      name: 'Economics',
      blurb: 'Markets, production, national income and development.',
      outline: [
        CatalogUnit('Basic Economic Concepts', [
          'Scarcity, Choice and Opportunity Cost',
          'Wants and Scale of Preference',
          'Production Possibility Curve',
          'Economic Systems',
        ]),
        CatalogUnit('Demand and Supply', [
          'The Law of Demand',
          'The Law of Supply',
          'Elasticity',
          'Price Determination',
          'Price Control',
        ]),
        CatalogUnit('Theory of Production', [
          'Factors of Production',
          'Division of Labour',
          'Scale of Production',
          'Cost and Revenue',
          'Business Organisations',
        ]),
        CatalogUnit('Market Structures', [
          'Perfect Competition',
          'Monopoly',
          'Oligopoly',
          'Monopolistic Competition',
        ]),
        CatalogUnit('Money and Financial Institutions', [
          'Functions of Money',
          'Commercial Banks',
          'The Central Bank',
          'The Capital Market',
          'Inflation',
        ]),
        CatalogUnit('National Income', [
          'Concepts of National Income',
          'Measuring National Income',
          'The Circular Flow',
          'Standard of Living',
        ]),
        CatalogUnit('Public Finance', [
          'Government Revenue',
          'Government Expenditure',
          'Taxation',
          'Budgets and Fiscal Policy',
          'Public Debt',
        ]),
        CatalogUnit('Agriculture and Industry', [
          'Agricultural Systems',
          'Problems of Agriculture',
          'Industrialisation',
          'Location of Industry',
        ]),
        CatalogUnit('International Trade', [
          'Balance of Payments',
          'Exchange Rates',
          'Trade Restrictions',
          'ECOWAS and Economic Integration',
          'Globalisation',
        ]),
        CatalogUnit('Development Economics', [
          'Growth and Development',
          'Population and Development',
          'Unemployment',
          'Poverty',
          'Development Planning',
        ]),
      ],
    ),
    CatalogSubject(
      slug: 'government',
      name: 'Government',
      blurb: 'Political concepts, institutions and Nigerian government.',
      outline: [
        CatalogUnit('Basic Concepts', [
          'Power, Authority and Legitimacy',
          'Sovereignty',
          'State and Nation',
          'Political Culture',
          'The Rule of Law',
        ]),
        CatalogUnit('Forms of Government', [
          'Democracy',
          'Monarchy',
          'Aristocracy and Oligarchy',
          'Totalitarianism',
          'Federal and Unitary Systems',
        ]),
        CatalogUnit('Organs of Government', [
          'The Legislature',
          'The Executive',
          'The Judiciary',
          'Separation of Powers',
          'Checks and Balances',
        ]),
        CatalogUnit('Constitutions', [
          'Types of Constitution',
          'Features of a Constitution',
          'Constitutional Development',
        ]),
        CatalogUnit('Political Participation', [
          'Political Parties',
          'Pressure Groups',
          'Elections and Electoral Systems',
          'Public Opinion',
          'The Mass Media',
        ]),
        CatalogUnit('Public Administration', [
          'The Civil Service',
          'Public Corporations',
          'Local Government',
          'Bureaucracy',
        ]),
        CatalogUnit('Pre-Colonial Systems', [
          'Hausa-Fulani Political System',
          'Yoruba Political System',
          'Igbo Political System',
        ]),
        CatalogUnit('Colonial Administration', [
          'Indirect Rule',
          'Nigerian Constitutions 1922-1960',
          'Nationalist Movements',
        ]),
        CatalogUnit('Post-Independence Nigeria', [
          'The First Republic',
          'Military Rule',
          'Second and Third Republics',
          'The Fourth Republic',
        ]),
        CatalogUnit('Nigeria and the World', [
          'Foreign Policy',
          'ECOWAS',
          'The African Union',
          'The United Nations',
          'The Commonwealth',
        ]),
      ],
    ),
    CatalogSubject(
      slug: 'english-language',
      name: 'English Language',
      blurb: 'Comprehension, grammar, oral English and essay writing.',
      outline: [
        CatalogUnit('Comprehension', [
          'Reading for Main Ideas',
          'Summary Writing',
          'Inference and Interpretation',
          'Vocabulary in Context',
        ]),
        CatalogUnit('Lexis and Structure', [
          'Synonyms and Antonyms',
          'Word Classes',
          'Sentence Patterns',
          'Concord',
          'Tenses',
        ]),
        CatalogUnit('Grammar', [
          'Parts of Speech',
          'Phrases and Clauses',
          'Punctuation',
          'Active and Passive Voice',
          'Common Errors',
        ]),
        CatalogUnit('Vocabulary Development', [
          'Registers',
          'Idioms and Figurative Expressions',
          'Word Formation',
          'Collocations',
        ]),
        CatalogUnit('Oral English', [
          'Vowel Sounds',
          'Consonant Sounds',
          'Stress and Intonation',
          'Rhymes and Homophones',
          'Emphatic Stress',
        ]),
        CatalogUnit('Essay Writing', [
          'Narrative Essays',
          'Descriptive Essays',
          'Argumentative Essays',
          'Expository Essays',
          'Formal and Informal Letters',
        ]),
        CatalogUnit('Literary Appreciation', [
          'Figures of Speech',
          'Poetic Devices',
          'Drama and Prose Terms',
        ]),
      ],
    ),
    CatalogSubject(
      slug: 'commerce',
      name: 'Commerce',
      blurb: 'Trade, business organisations and the aids to trade.',
      outline: [
        CatalogUnit('Introduction to Commerce', [
          'Occupations',
          'Commercial Activities',
          'Development of Commerce',
          'Home and Foreign Trade',
        ]),
        CatalogUnit('Trade', [
          'Retail Trade',
          'Wholesale Trade',
          'Channels of Distribution',
          'Import and Export Procedures',
        ]),
        CatalogUnit('Business Organisations', [
          'Sole Proprietorship',
          'Partnership',
          'Limited Liability Companies',
          'Cooperative Societies',
          'Public Enterprises',
        ]),
        CatalogUnit('Aids to Trade', [
          'Banking',
          'Insurance',
          'Transportation',
          'Warehousing',
          'Advertising',
          'Communication',
        ]),
        CatalogUnit('Finance and Capital', [
          'Sources of Business Finance',
          'Types of Capital',
          'The Stock Exchange',
          'Payment Systems',
        ]),
        CatalogUnit('Business Documents', [
          'Invoices and Receipts',
          'Orders and Quotations',
          'Statements of Account',
          'Credit and Debit Notes',
        ]),
        CatalogUnit('Trends in Commerce', [
          'E-commerce',
          'Consumer Protection',
          'Business Ethics',
          'Globalisation',
        ]),
      ],
    ),
    CatalogSubject(
      slug: 'music',
      name: 'Music',
      blurb: 'Rudiments, harmony, history and Nigerian music.',
      outline: [
        CatalogUnit('Rudiments of Music', [
          'Staff Notation',
          'Clefs',
          'Note Values and Rests',
          'Time Signatures',
          'Key Signatures',
        ]),
        CatalogUnit('Scales and Intervals', [
          'Major Scales',
          'Minor Scales',
          'The Chromatic Scale',
          'Intervals',
          'Transposition',
        ]),
        CatalogUnit('Harmony', [
          'Triads and Chords',
          'Chord Progressions',
          'Cadences',
          'Four-Part Writing',
        ]),
        CatalogUnit('Melody Writing', [
          'Phrase Structure',
          'Melodic Composition',
          'Modulation',
        ]),
        CatalogUnit('Aural and Sight Reading', [
          'Rhythmic Dictation',
          'Melodic Dictation',
          'Sight Singing',
        ]),
        CatalogUnit('History and Literature', [
          'The Baroque Period',
          'The Classical Period',
          'The Romantic Period',
          'The Twentieth Century',
        ]),
        CatalogUnit('African and Nigerian Music', [
          'Traditional Instruments',
          'Folk Songs',
          'Music and Society',
          'Contemporary Nigerian Music',
        ]),
        CatalogUnit('Performance Studies', [
          'Voice Training',
          'Instrumental Technique',
          'Ensemble Performance',
        ]),
      ],
    ),
  ];
}
