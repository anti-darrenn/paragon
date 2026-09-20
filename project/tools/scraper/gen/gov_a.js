// Government > Basic Concepts, Forms of Government, Organs of Government,
//              Constitutions, Political Participation
const { conceptGens } = require('./concept');

const U_BASIC = 'Basic Concepts';
const U_FORMS = 'Forms of Government';
const U_ORGANS = 'Organs of Government';
const U_CONST = 'Constitutions';
const U_PART = 'Political Participation';

// ==================== POWER, AUTHORITY AND LEGITIMACY ====================
const power = conceptGens('power, authority and legitimacy', [
  'Power is the ability to influence or control the behaviour of others',
  'Authority is the right to exercise power and is generally accepted as rightful',
  'Legitimacy is the general acceptance by the people that a government has the right to rule',
  'Max Weber identified traditional, charismatic and legal-rational authority',
  'Traditional authority rests on long-established custom and inherited position',
  'Charismatic authority rests on the personal qualities of an individual leader',
  'Legal-rational authority rests on established laws, rules and procedures',
  'A government may hold power without possessing legitimacy',
], [
  'Authority and power mean exactly the same thing',
  'Legitimacy is conferred only by the armed forces',
  'Charismatic authority is inherited from one generation to the next',
  'Legal-rational authority depends on the personal charm of the ruler',
  'A government that seizes power by force automatically acquires legitimacy',
  'Power can only be exercised by the head of state',
  'Traditional authority is based on written constitutional rules',
], [
  { q: 'Which type of authority is based on the exceptional personal qualities of a leader?', a: 'Charismatic authority', w: ['Traditional authority', 'Legal-rational authority', 'Coercive authority'], e: 'Weber described charismatic authority as resting on devotion to the exemplary character of an individual, rather than on custom or on legal rules.' },
  { q: 'What distinguishes authority from mere power?', a: 'Authority carries the recognised right to exercise power', w: ['Authority is always exercised by force', 'Authority is exercised only by the judiciary', 'Authority requires no acceptance by the governed'], e: 'Power is the capacity to compel; authority adds acceptance, so the governed obey because they regard the command as rightful rather than because they are forced.' },
  { q: 'A government that rules without the consent or acceptance of the people lacks', a: 'legitimacy', w: ['sovereignty', 'territory', 'population'], e: 'Legitimacy is the belief among the governed that the government has the right to rule. A government may still hold power, but without that belief it is illegitimate.' },
]);

// ============================== SOVEREIGNTY ==============================
const sovereignty = conceptGens('sovereignty', [
  'Sovereignty is the supreme power of a state to make and enforce laws within its territory',
  'Internal sovereignty is supremacy over all persons and associations within the state',
  'External sovereignty is freedom from control by any other state',
  'Legal sovereignty is vested in the body that makes the law',
  'Political sovereignty ultimately resides with the electorate',
  'Sovereignty is regarded as absolute, indivisible and permanent',
  'Popular sovereignty means that ultimate authority rests with the people',
  'A colony does not possess external sovereignty',
], [
  'Sovereignty can be freely shared with foreign powers without limit',
  'Internal sovereignty means freedom from the control of other states',
  'External sovereignty means supremacy over citizens within the state',
  'Legal sovereignty always resides with the electorate',
  'A colony possesses full external sovereignty',
  'Sovereignty is temporary and expires with each government',
  'Only monarchies can possess sovereignty',
]);

// ============================= STATE AND NATION =============================
const stateNation = conceptGens('the state and the nation', [
  'A state must possess population, territory, government and sovereignty',
  'A nation is a group of people bound by common language, culture, history or descent',
  'A nation-state exists where the boundaries of the state coincide with those of a single nation',
  'Nigeria is a multi-national state containing many ethnic nations',
  'A state is a legal and political entity while a nation is largely a cultural one',
  'Sovereignty is the attribute that distinguishes a state from other associations',
  'A nation may exist without having its own state',
], [
  'A state can exist without any defined territory',
  'A nation and a state always mean exactly the same thing',
  'Nigeria is a single-nation state with one ethnic group',
  'Sovereignty is not required for statehood',
  'A nation cannot exist unless it controls a state',
  'Population is not an essential attribute of a state',
], [
  { q: 'Which of the following is NOT an essential attribute of a state?', a: 'A common language spoken by everyone', w: ['Population', 'Defined territory', 'Sovereignty'], e: 'The four essentials are population, territory, government and sovereignty. Many states, Nigeria among them, contain numerous language groups.' },
  { q: 'What primarily distinguishes a nation from a state?', a: 'A nation is bound by shared culture and identity, a state by legal sovereignty', w: ['A nation always has a larger population', 'A state has no defined territory', 'A nation must possess an army'], e: 'Nationhood is a matter of shared identity; statehood is a matter of sovereign legal authority over a territory. The two need not coincide.' },
]);

// ============================ POLITICAL CULTURE ============================
const politicalCulture = conceptGens('political culture', [
  'Political culture is the pattern of attitudes, beliefs and values a people hold towards politics',
  'Political socialisation is the process by which political values are transmitted',
  'The family, school, mass media and peer groups are agents of political socialisation',
  'A parochial political culture shows little awareness of or interest in the political system',
  'A subject political culture shows awareness of government but little participation',
  'A participant political culture shows both awareness of and active involvement in politics',
  'Political apathy is a lack of interest in political affairs',
], [
  'Political culture is fixed at birth and never changes',
  'A participant political culture shows no interest in political affairs',
  'A parochial political culture involves very high levels of political participation',
  'The family plays no role in political socialisation',
  'Political apathy means very enthusiastic political involvement',
  'Political socialisation occurs only in adulthood',
]);

// ============================= THE RULE OF LAW =============================
const ruleOfLaw = conceptGens('the rule of law', [
  'The rule of law means that everyone is subject to the law, including those who govern',
  'A. V. Dicey is associated with the classic exposition of the rule of law',
  'Equality before the law is a central principle of the rule of law',
  'No person should be punished except for a breach of an established law',
  'The rule of law requires an independent and impartial judiciary',
  'Fundamental human rights should be protected by the courts',
  'An accused person is presumed innocent until proven guilty',
  'Arbitrary arrest and detention violate the rule of law',
], [
  'The rule of law places the head of state above the law',
  'Under the rule of law, people may be punished without trial',
  'The rule of law requires the judiciary to take orders from the executive',
  'Only ordinary citizens are bound by the law',
  'An accused person is presumed guilty until proven innocent',
  'The rule of law permits arbitrary detention in all circumstances',
], [
  { q: 'Which principle holds that no one is above the law, including government officials?', a: 'The rule of law', w: ['Separation of powers', 'Federalism', 'Collective responsibility'], e: 'The rule of law subjects every person and institution, including the government itself, to the same body of law administered by the ordinary courts.' },
  { q: 'Which of the following most undermines the rule of law?', a: 'Detention of citizens without trial', w: ['An independent judiciary', 'Equality before the law', 'Publicly known laws'], e: 'Detention without trial denies the accused the protection of established legal process, which is the core guarantee the rule of law provides.' },
]);

// ============================== DEMOCRACY ==============================
const democracy = conceptGens('democracy', [
  'Democracy is government of the people, by the people and for the people',
  'Abraham Lincoln gave the classic definition of democracy',
  'In a direct democracy citizens participate in decision-making themselves',
  'In a representative democracy citizens elect others to govern on their behalf',
  'Regular free and fair elections are essential to democracy',
  'Democracy requires respect for fundamental human rights',
  'Freedom of the press is an important feature of democracy',
  'The existence of an organised opposition is a feature of democracy',
  'Universal adult suffrage means all qualified adults may vote',
], [
  'Democracy requires that only landowners may vote',
  'In a representative democracy citizens make every decision directly',
  'Democracy is incompatible with the holding of elections',
  'A one-party state with no opposition is the purest form of democracy',
  'Democracy requires the suppression of the press',
  'Universal adult suffrage restricts voting to members of one party',
], [
  { q: 'Who defined democracy as "government of the people, by the people and for the people"?', a: 'Abraham Lincoln', w: ['Karl Marx', 'John Locke', 'Thomas Hobbes'], e: 'The phrase comes from Lincoln\'s Gettysburg Address of 1863 and remains the most widely quoted definition of democracy.' },
  { q: 'Which type of democracy involves citizens taking part in decision-making in person?', a: 'Direct democracy', w: ['Representative democracy', 'Parliamentary democracy', 'Liberal democracy'], e: 'Direct democracy, as practised in ancient Athens and in modern referenda, has citizens decide issues themselves rather than through elected delegates.' },
  { q: 'Which of the following is essential to a democratic system?', a: 'Periodic free and fair elections', w: ['A single permanent ruling party', 'Rule by decree', 'Censorship of the press'], e: 'Elections are the mechanism by which the governed grant and withdraw consent; without them government cannot be said to rest on popular will.' },
]);

// =============================== MONARCHY ===============================
const monarchy = conceptGens('monarchy', [
  'A monarchy is a system in which a king or queen is head of state',
  'In an absolute monarchy the monarch holds unlimited power',
  'In a constitutional monarchy the monarch\'s powers are limited by a constitution',
  'The position of monarch is normally hereditary',
  'Britain is an example of a constitutional monarchy',
  'In a constitutional monarchy the monarch reigns but does not rule',
  'A constitutional monarch usually performs mainly ceremonial functions',
], [
  'In a constitutional monarchy the monarch holds unlimited power',
  'Monarchy is always an elective office contested at each election',
  'In an absolute monarchy the monarch is bound by a written constitution',
  'Britain is an example of an absolute monarchy',
  'A monarch can never be a head of state',
  'Constitutional monarchs exercise full executive control over the legislature',
]);

// ====================== ARISTOCRACY AND OLIGARCHY ======================
const aristocracy = conceptGens('aristocracy and oligarchy', [
  'Aristocracy is government by a privileged class regarded as the best qualified',
  'Oligarchy is government by a small group of people',
  'Plutocracy is government by the wealthy',
  'Gerontocracy is government by the elders',
  'Theocracy is government by religious leaders in the name of a deity',
  'An oligarchy concentrates political power in few hands',
  'Aristocratic rule is usually based on noble birth',
], [
  'Oligarchy is government by the whole population',
  'Aristocracy means government by the poorest class',
  'Plutocracy is government by religious leaders',
  'Theocracy is government by the military',
  'Gerontocracy is government by the youngest members of society',
  'An oligarchy distributes power equally among all citizens',
]);

// ============================ TOTALITARIANISM ============================
const totalitarianism = conceptGens('totalitarianism and dictatorship', [
  'A totalitarian state seeks to control every aspect of public and private life',
  'Totalitarian regimes typically permit only one political party',
  'Totalitarian governments suppress opposition and censor the press',
  'A dictatorship concentrates power in a single ruler or small group',
  'Military rule is usually imposed following a coup d\'etat',
  'Under military rule the constitution is often suspended and rule is by decree',
  'Fundamental human rights are typically curtailed under totalitarian rule',
], [
  'Totalitarian states guarantee complete freedom of the press',
  'Totalitarian regimes encourage strong opposition parties',
  'A dictatorship distributes power widely among elected bodies',
  'Military governments usually strengthen the existing constitution',
  'Totalitarian states hold regular free and fair multi-party elections',
  'Rule by decree is a feature of liberal democracy',
]);

// ==================== FEDERAL AND UNITARY SYSTEMS ====================
const federalUnitary = conceptGens('federal and unitary systems', [
  'In a federal system powers are shared between a central government and component units',
  'In a unitary system all power is concentrated in one central government',
  'A federal constitution is usually written and rigid',
  'Nigeria operates a federal system of government',
  'A confederation is a loose union of states which retain their sovereignty',
  'In a federation the component units have powers guaranteed by the constitution',
  'A supreme court is needed in a federation to settle disputes between levels of government',
  'Ghana under a unitary arrangement concentrates authority in the central government',
], [
  'In a unitary system power is shared between central and regional governments',
  'In a federation the central government may abolish the component units at will',
  'Nigeria operates a unitary system of government',
  'A confederation has a very strong central government',
  'Federal constitutions are usually unwritten and flexible',
  'A federation has no need for a supreme court',
], [
  { q: 'Which system of government shares powers between a central authority and component units under a written constitution?', a: 'Federalism', w: ['Unitarism', 'Confederalism', 'Absolutism'], e: 'Federalism divides powers constitutionally, so neither the centre nor the units can unilaterally abolish the other\'s sphere of authority.' },
  { q: 'Which of the following is a feature of a unitary system of government?', a: 'Concentration of power in a single central government', w: ['A rigid written constitution dividing powers', 'Component units with guaranteed powers', 'A supreme court to arbitrate between tiers'], e: 'In a unitary state any regional bodies exercise only powers delegated by the centre, which may alter or withdraw them.' },
]);

// ============================= THE LEGISLATURE =============================
const legislature = conceptGens('the legislature', [
  'The primary function of the legislature is to make laws',
  'A bicameral legislature has two chambers',
  'A unicameral legislature has only one chamber',
  'The Nigerian National Assembly consists of the Senate and the House of Representatives',
  'The legislature exercises oversight over the activities of the executive',
  'The legislature controls public funds through the approval of the budget',
  'A bill becomes law after passing through the legislature and receiving assent',
  'Federal states commonly adopt bicameral legislatures to represent the component units',
], [
  'The primary function of the legislature is to interpret the law',
  'A bicameral legislature has only one chamber',
  'The Nigerian National Assembly is unicameral',
  'The legislature has no control over public expenditure',
  'The legislature is responsible for prosecuting criminal offences',
  'Bills become law without any legislative debate',
], [
  { q: 'What is the primary function of the legislature?', a: 'Law-making', w: ['Interpretation of laws', 'Implementation of laws', 'Prosecution of offenders'], e: 'The legislature enacts law; the executive implements it and the judiciary interprets it. That division is the basis of the separation of powers.' },
  { q: 'Of which two chambers does the Nigerian National Assembly consist?', a: 'The Senate and the House of Representatives', w: ['The Senate and the House of Chiefs', 'The House of Representatives and the Council of State', 'The Senate and the Federal Executive Council'], e: 'Nigeria\'s bicameral National Assembly pairs the Senate, representing the states equally, with the House of Representatives, representing population.' },
  { q: 'Why do federal states usually adopt a bicameral legislature?', a: 'So that one chamber can represent the component units equally', w: ['To make law-making faster', 'To reduce the cost of governance', 'To remove the need for elections'], e: 'A second chamber gives the federating units a guaranteed voice regardless of population, protecting smaller units from domination.' },
]);

// ============================== THE EXECUTIVE ==============================
const executive = conceptGens('the executive', [
  'The executive is the organ of government that implements and enforces laws',
  'In a presidential system the president is both head of state and head of government',
  'In a parliamentary system the head of state and head of government are separate offices',
  'The executive formulates and executes government policy',
  'The executive conducts the foreign relations of the state',
  'The president exercises the prerogative of mercy',
  'Nigeria operates a presidential system of government',
  'In a parliamentary system the executive is drawn from and answerable to the legislature',
], [
  'The executive is the organ that interprets the law',
  'In a presidential system the president is answerable to no one and cannot be removed',
  'In a parliamentary system the prime minister is also the head of state',
  'Nigeria operates a parliamentary system of government',
  'The executive has no role in the formulation of policy',
  'The executive is responsible for adjudicating disputes between citizens',
], [
  { q: 'In a presidential system of government, the president is', a: 'both head of state and head of government', w: ['head of state only', 'head of government only', 'a ceremonial figure with no real power'], e: 'Fusing the two roles in one directly elected office is the defining feature of presidentialism, as in Nigeria and the United States.' },
  { q: 'Which organ of government is responsible for implementing laws?', a: 'The executive', w: ['The legislature', 'The judiciary', 'The electorate'], e: 'The executive carries laws into effect through ministries, departments and agencies of state.' },
]);

// ============================== THE JUDICIARY ==============================
const judiciary = conceptGens('the judiciary', [
  'The judiciary interprets the law and settles disputes',
  'Judicial independence means judges can decide cases free from external interference',
  'Security of tenure helps to guarantee the independence of the judiciary',
  'The judiciary protects the fundamental human rights of citizens',
  'Judicial review allows the courts to examine the constitutionality of laws and actions',
  'The Supreme Court is the highest court in Nigeria',
  'Judges should be appointed on merit and not on partisan political grounds',
  'The judiciary acts as a check on both the legislature and the executive',
], [
  'The judiciary makes the laws of the state',
  'Judges should take instructions from the executive when deciding cases',
  'Judicial review means the executive may overturn court judgments',
  'The judiciary has no role in protecting human rights',
  'The Supreme Court is subordinate to the Court of Appeal',
  'Security of tenure weakens judicial independence',
], [
  { q: 'What is the main function of the judiciary?', a: 'Interpretation of the law and settlement of disputes', w: ['Making the law', 'Implementing government policy', 'Conducting elections'], e: 'Courts apply and interpret the law to concrete disputes, and in doing so protect rights and check the other arms of government.' },
  { q: 'Which of the following best guarantees the independence of the judiciary?', a: 'Security of tenure for judges', w: ['Appointment of judges by the ruling party alone', 'Frequent transfer of judges by the executive', 'Payment of judges from party funds'], e: 'If judges cannot be removed at the pleasure of politicians, they can decide against the government without fearing for their positions.' },
  { q: 'The power of the courts to declare an act of the legislature unconstitutional is called', a: 'judicial review', w: ['judicial precedent', 'delegated legislation', 'collective responsibility'], e: 'Judicial review lets the courts measure legislation and executive action against the constitution and strike down whatever conflicts with it.' },
]);

// =========================== SEPARATION OF POWERS ===========================
const separation = conceptGens('the separation of powers', [
  'The separation of powers divides government into legislative, executive and judicial branches',
  'Baron de Montesquieu is associated with the doctrine of the separation of powers',
  'The doctrine aims to prevent the concentration of power in one person or body',
  'Separation of powers helps to prevent tyranny and abuse of office',
  'The doctrine is applied most fully in a presidential system',
  'In a parliamentary system there is considerable overlap between executive and legislature',
  'Each arm of government should perform its own distinct functions',
], [
  'The separation of powers concentrates all authority in the executive',
  'John Locke alone formulated the threefold separation of powers as it is known today',
  'The doctrine requires the judiciary to be appointed by and answerable to the legislature',
  'Separation of powers is applied most completely in a parliamentary system',
  'The doctrine encourages one person to head all three arms of government',
  'Separation of powers makes tyranny more likely',
], [
  { q: 'Which political thinker is most associated with the doctrine of the separation of powers?', a: 'Baron de Montesquieu', w: ['Karl Marx', 'Thomas Hobbes', 'Jean-Jacques Rousseau'], e: 'Montesquieu argued in The Spirit of the Laws that liberty requires legislative, executive and judicial power to be held by different bodies.' },
  { q: 'What is the main purpose of the separation of powers?', a: 'To prevent the concentration and abuse of power', w: ['To make government cheaper to run', 'To speed up the passage of laws', 'To give the president absolute authority'], e: 'Dividing functions among separate bodies means each can restrain the others, which guards against tyranny.' },
]);

// ============================ CHECKS AND BALANCES ============================
const checks = conceptGens('checks and balances', [
  'Checks and balances allow each arm of government to limit the powers of the others',
  'The legislature checks the executive through its power to approve the budget',
  'The legislature can remove a president through impeachment',
  'The president may check the legislature by withholding assent to a bill',
  'The judiciary checks both the legislature and the executive through judicial review',
  'Legislative confirmation of executive appointments is a form of check',
  'The legislature may override a presidential veto by a special majority',
], [
  'Checks and balances mean each arm of government is completely powerless',
  'The judiciary cannot review the actions of the executive',
  'The legislature has no power to remove a president under any circumstances',
  'A president may dissolve the Supreme Court at will',
  'Checks and balances require all three arms to be headed by one person',
  'Budget approval is the exclusive preserve of the judiciary',
], [
  { q: 'By what process may the legislature remove a president from office for gross misconduct?', a: 'Impeachment', w: ['Vote of no confidence', 'Judicial review', 'Referendum'], e: 'Impeachment is the constitutional procedure by which the legislature investigates and removes a chief executive, a central check on the presidency.' },
  { q: 'Legislative confirmation of ministerial appointments is an example of', a: 'checks and balances', w: ['delegated legislation', 'collective responsibility', 'judicial precedent'], e: 'Requiring the legislature to approve the executive\'s nominees prevents the president from filling offices entirely unchecked.' },
]);

// ========================= TYPES OF CONSTITUTION =========================
const constTypes = conceptGens('types of constitution', [
  'A written constitution is contained in a single formal document',
  'An unwritten constitution is drawn from conventions, statutes and judicial decisions',
  'A rigid constitution is difficult to amend and requires a special procedure',
  'A flexible constitution can be amended by the ordinary law-making process',
  'Britain is usually cited as having an unwritten constitution',
  'Nigeria operates a written and rigid constitution',
  'Federal constitutions are normally written and rigid',
], [
  'An unwritten constitution is contained in one single document',
  'A rigid constitution can be amended by a simple majority like any other law',
  'Britain has a written and rigid constitution',
  'Nigeria operates an unwritten and flexible constitution',
  'A flexible constitution requires a referendum for every amendment',
  'Federal constitutions are typically unwritten',
]);

// ======================= FEATURES OF A CONSTITUTION =======================
const constFeatures = conceptGens('the features and functions of a constitution', [
  'A constitution is the body of fundamental rules by which a state is governed',
  'A constitution defines the powers and limits of the organs of government',
  'A constitution usually guarantees the fundamental rights of citizens',
  'A constitution provides for the procedure by which it may be amended',
  'A constitution establishes the relationship between the government and the governed',
  'The constitution is the supreme law of the land in Nigeria',
  'Any law inconsistent with the constitution is void to the extent of the inconsistency',
], [
  'A constitution is subordinate to ordinary Acts of the legislature',
  'A constitution deals only with foreign policy',
  'A constitution cannot be amended under any circumstances',
  'A constitution has no bearing on the rights of citizens',
  'A constitution is binding only on ordinary citizens and not on government',
  'Laws inconsistent with the constitution automatically override it',
]);

// ====================== CONSTITUTIONAL DEVELOPMENT ======================
const constDev = conceptGens('constitutional development in Nigeria', [
  'The Clifford Constitution of 1922 introduced the elective principle to Nigeria',
  'The Richards Constitution of 1946 introduced regionalism into Nigeria',
  'The Macpherson Constitution of 1951 was drafted after wide consultation',
  'The Lyttleton Constitution of 1954 established a federal structure for Nigeria',
  'The Independence Constitution came into force in 1960',
  'The Republican Constitution of 1963 removed the British monarch as head of state',
  'The 1979 Constitution introduced a presidential system to Nigeria',
  'The 1999 Constitution governs the Fourth Republic',
], [
  'The Clifford Constitution of 1922 established a republic in Nigeria',
  'The Richards Constitution of 1946 abolished regionalism',
  'The Lyttleton Constitution of 1954 created a unitary state',
  'The Republican Constitution came into force in 1960',
  'The 1979 Constitution introduced a parliamentary system',
  'The Fourth Republic operates under the 1963 Constitution',
], [
  { q: 'Which Nigerian constitution first introduced the elective principle?', a: 'The Clifford Constitution of 1922', w: ['The Richards Constitution of 1946', 'The Macpherson Constitution of 1951', 'The Lyttleton Constitution of 1954'], e: 'Clifford\'s constitution allowed a limited number of Nigerians to elect members to the Legislative Council, the first elections of their kind in British West Africa.' },
  { q: 'Which constitution introduced a federal structure to Nigeria?', a: 'The Lyttleton Constitution of 1954', w: ['The Clifford Constitution of 1922', 'The Richards Constitution of 1946', 'The Independence Constitution of 1960'], e: 'The Lyttleton Constitution converted the regions into genuine federating units with their own governments and defined legislative powers.' },
  { q: 'In which year did Nigeria become a republic?', a: '1963', w: ['1960', '1954', '1979'], e: 'Nigeria gained independence on 1 October 1960 but retained the British monarch as head of state until the Republican Constitution of 1 October 1963.' },
]);

// ============================ POLITICAL PARTIES ============================
const parties = conceptGens('political parties', [
  'A political party is an organised group seeking to win political power and form a government',
  'Political parties aggregate and articulate the interests of their members',
  'Political parties serve as a link between the government and the governed',
  'In a two-party system two major parties dominate the contest for power',
  'In a multi-party system several parties compete for political power',
  'A one-party system permits only one legal political party',
  'Opposition parties provide an alternative government and scrutinise those in power',
  'Political parties present manifestos setting out their programmes',
], [
  'A political party exists mainly to enforce court judgments',
  'Political parties play no role in mobilising voters',
  'A one-party system allows several parties to contest elections freely',
  'Opposition parties are unnecessary in a democracy',
  'Political parties are forbidden from presenting manifestos',
  'A two-party system means only two people may contest an election',
]);

// ============================= PRESSURE GROUPS =============================
const pressureGroups = conceptGens('pressure groups', [
  'A pressure group seeks to influence government policy without seeking to form a government',
  'Trade unions and professional associations are examples of pressure groups',
  'Pressure groups may use lobbying, petitions, strikes and the media to press their case',
  'Unlike political parties, pressure groups do not contest elections to form a government',
  'Promotional pressure groups campaign for a cause rather than a sectional interest',
  'Interest or sectional groups defend the interests of their own members',
  'Pressure groups contribute to political participation between elections',
], [
  'A pressure group aims primarily to capture political power and form a government',
  'Pressure groups always contest general elections',
  'Trade unions cannot function as pressure groups',
  'Pressure groups are prohibited from lobbying legislators',
  'Pressure groups and political parties are identical in aim and method',
  'Pressure groups reduce citizen participation in politics',
], [
  { q: 'What is the main difference between a political party and a pressure group?', a: 'A political party seeks to form a government while a pressure group seeks only to influence policy', w: ['A pressure group contests more elections than a party', 'A political party never has members', 'A pressure group is always illegal'], e: 'Both try to shape public decisions, but only the party puts up candidates with the aim of taking over the machinery of government.' },
  { q: 'Which of the following is an example of a pressure group in Nigeria?', a: 'The Nigeria Labour Congress', w: ['The Senate', 'The Supreme Court', 'The Independent National Electoral Commission'], e: 'The NLC is an umbrella body of trade unions that lobbies and campaigns to influence policy, without seeking to form a government itself.' },
]);

// =================== ELECTIONS AND ELECTORAL SYSTEMS ===================
const elections = conceptGens('elections and electoral systems', [
  'An election is the process by which citizens choose their representatives',
  'Universal adult suffrage gives every qualified adult the right to vote',
  'In the simple majority or first-past-the-post system the candidate with the most votes wins',
  'Proportional representation allocates seats in proportion to votes received',
  'A by-election is held to fill a vacancy arising between general elections',
  'A referendum allows the electorate to vote directly on a specific issue',
  'The secret ballot protects voters from intimidation',
  'An independent electoral commission helps to ensure free and fair elections',
  'Rigging, thuggery and vote buying are electoral malpractices',
], [
  'Universal adult suffrage restricts the vote to property owners',
  'In first-past-the-post the candidate with the fewest votes wins',
  'Proportional representation gives all seats to the largest party',
  'A by-election is held to choose an entire new parliament',
  'The open ballot best protects voters from intimidation',
  'Electoral commissions should be controlled by the ruling party',
], [
  { q: 'Which body is responsible for conducting federal elections in Nigeria?', a: 'The Independent National Electoral Commission', w: ['The National Assembly', 'The Supreme Court', 'The Federal Executive Council'], e: 'INEC organises and supervises federal and state elections, registers voters and political parties, and announces results.' },
  { q: 'An election held to fill a vacancy caused by the death or resignation of a member is called', a: 'a by-election', w: ['a general election', 'a referendum', 'a primary election'], e: 'A by-election fills a single vacant seat between general elections and does not affect the rest of the legislature.' },
  { q: 'Which electoral system allocates seats to parties in proportion to the votes they receive?', a: 'Proportional representation', w: ['First-past-the-post', 'Simple majority system', 'Electoral college system'], e: 'Proportional representation aims to match each party\'s share of seats to its share of the national vote, reducing wasted votes.' },
]);

// ============================= PUBLIC OPINION =============================
const publicOpinion = conceptGens('public opinion', [
  'Public opinion is the collective view of a significant proportion of the population on an issue',
  'Public opinion can be measured through opinion polls and surveys',
  'The mass media help to shape and reflect public opinion',
  'Governments in a democracy are expected to be responsive to public opinion',
  'Public opinion may change over time as circumstances change',
  'Pressure groups and political parties both try to influence public opinion',
], [
  'Public opinion is the private view of a single individual',
  'Public opinion is permanently fixed and cannot change',
  'Democratic governments are expected to ignore public opinion entirely',
  'Opinion polls cannot be used to gauge public opinion',
  'The mass media have no influence on public opinion',
]);

// ============================= THE MASS MEDIA =============================
const media = conceptGens('the mass media', [
  'The mass media inform, educate and entertain the public',
  'The mass media act as a watchdog over government',
  'A free press is essential to the working of a democracy',
  'The media help to shape public opinion on political issues',
  'The media provide a platform for the expression of diverse views',
  'Censorship restricts the freedom of the press',
  'The media are sometimes described as the fourth estate of the realm',
], [
  'The mass media exist solely to praise the government of the day',
  'A free press is incompatible with democracy',
  'Censorship strengthens press freedom',
  'The media have no role in holding government accountable',
  'The media are formally the fourth arm of government in Nigeria',
  'Broadcasting cannot influence political attitudes',
]);

module.exports = [
  { unitName: U_BASIC, topicName: 'Power, Authority and Legitimacy', generators: power },
  { unitName: U_BASIC, topicName: 'Sovereignty', generators: sovereignty },
  { unitName: U_BASIC, topicName: 'State and Nation', generators: stateNation },
  { unitName: U_BASIC, topicName: 'Political Culture', generators: politicalCulture },
  { unitName: U_BASIC, topicName: 'The Rule of Law', generators: ruleOfLaw },
  { unitName: U_FORMS, topicName: 'Democracy', generators: democracy },
  { unitName: U_FORMS, topicName: 'Monarchy', generators: monarchy },
  { unitName: U_FORMS, topicName: 'Aristocracy and Oligarchy', generators: aristocracy },
  { unitName: U_FORMS, topicName: 'Totalitarianism', generators: totalitarianism },
  { unitName: U_FORMS, topicName: 'Federal and Unitary Systems', generators: federalUnitary },
  { unitName: U_ORGANS, topicName: 'The Legislature', generators: legislature },
  { unitName: U_ORGANS, topicName: 'The Executive', generators: executive },
  { unitName: U_ORGANS, topicName: 'The Judiciary', generators: judiciary },
  { unitName: U_ORGANS, topicName: 'Separation of Powers', generators: separation },
  { unitName: U_ORGANS, topicName: 'Checks and Balances', generators: checks },
  { unitName: U_CONST, topicName: 'Types of Constitution', generators: constTypes },
  { unitName: U_CONST, topicName: 'Features of a Constitution', generators: constFeatures },
  { unitName: U_CONST, topicName: 'Constitutional Development', generators: constDev },
  { unitName: U_PART, topicName: 'Political Parties', generators: parties },
  { unitName: U_PART, topicName: 'Pressure Groups', generators: pressureGroups },
  { unitName: U_PART, topicName: 'Elections and Electoral Systems', generators: elections },
  { unitName: U_PART, topicName: 'Public Opinion', generators: publicOpinion },
  { unitName: U_PART, topicName: 'The Mass Media', generators: media },
];
