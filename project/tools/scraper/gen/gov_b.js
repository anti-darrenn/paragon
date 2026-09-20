// Government > Public Administration, Pre-Colonial Systems, Colonial Administration,
//              Post-Independence Nigeria, Nigeria and the World
const { conceptGens } = require('./concept');

const U_ADMIN = 'Public Administration';
const U_PRE = 'Pre-Colonial Systems';
const U_COL = 'Colonial Administration';
const U_POST = 'Post-Independence Nigeria';
const U_WORLD = 'Nigeria and the World';

// ============================= THE CIVIL SERVICE =============================
const civilService = conceptGens('the civil service', [
  'The civil service is the body of permanent officials who implement government policy',
  'Civil servants are politically neutral and serve whichever government is in power',
  'Permanence and continuity are key features of the civil service',
  'Anonymity means civil servants act in the name of their minister rather than their own',
  'Civil servants are recruited on merit through competitive examination',
  'The civil service is organised hierarchically into ministries and departments',
  'The permanent secretary is the administrative head of a ministry',
  'A minister bears political responsibility for the actions of the ministry',
], [
  'Civil servants are appointed and dismissed with every change of government',
  'Civil servants should openly campaign for the ruling party',
  'The minister is the administrative head of a ministry',
  'Civil servants are recruited solely on the basis of party membership',
  'Anonymity means civil servants take public credit for all policy decisions',
  'The civil service is responsible for making the laws of the state',
], [
  { q: 'Who is the administrative head of a ministry in Nigeria?', a: 'The permanent secretary', w: ['The minister', 'The president', 'The speaker'], e: 'The minister provides political direction while the permanent secretary, a career civil servant, runs the ministry administratively and is its accounting officer.' },
  { q: 'Which of the following is a feature of the civil service?', a: 'Political neutrality', w: ['Partisanship', 'Temporary tenure tied to elections', 'Recruitment by party nomination'], e: 'Neutrality lets the same permanent officials serve successive governments faithfully, which is what gives administration its continuity.' },
]);

// ============================ PUBLIC CORPORATIONS ============================
const corporations = conceptGens('public corporations', [
  'A public corporation is a state-owned enterprise established by an Act of parliament',
  'Public corporations provide essential services that may be unprofitable for private firms',
  'A public corporation has a legal personality separate from the government',
  'Public corporations are managed by a board of directors',
  'Public corporations are often established to prevent private monopoly of essential services',
  'Privatisation is the transfer of a public enterprise to private ownership',
  'Commercialisation requires a public enterprise to operate on profit-making lines',
  'Public corporations are frequently criticised for inefficiency and bureaucratic delay',
], [
  'A public corporation is owned entirely by private shareholders',
  'Public corporations are established by executive order of a permanent secretary',
  'Public corporations have no legal personality of their own',
  'Privatisation means transferring a private company to government ownership',
  'Public corporations are always more efficient than private firms',
  'Commercialisation means providing services entirely free of charge',
]);

// ============================= LOCAL GOVERNMENT =============================
const localGovt = conceptGens('local government', [
  'Local government is the third tier of government in Nigeria',
  'Local government brings governance closer to the grassroots',
  'Local government councils are headed by an elected chairman',
  'Local governments receive statutory allocations from the Federation Account',
  'Local government encourages popular participation in governance',
  'Local governments provide services such as primary healthcare, markets and refuse disposal',
  'The 1976 local government reform standardised the system across Nigeria',
  'Internally generated revenue supplements the statutory allocation of local councils',
], [
  'Local government is the first tier of government in Nigeria',
  'Local government councils are headed by the state governor',
  'Local governments receive no allocation from the Federation Account',
  'Local government removes citizens from participation in governance',
  'Local governments are responsible for national defence',
  'Local government councils make laws for the whole federation',
], [
  { q: 'Which tier of government is closest to the people in Nigeria?', a: 'Local government', w: ['Federal government', 'State government', 'The judiciary'], e: 'Local government administers the smallest units and delivers grassroots services, which is the main argument for its existence as a separate tier.' },
  { q: 'Which reform standardised the structure of local government throughout Nigeria?', a: 'The 1976 local government reform', w: ['The 1914 amalgamation', 'The 1960 independence settlement', 'The 1999 constitution'], e: 'The 1976 reform introduced a uniform single-tier council system nationwide and recognised local government as a distinct tier with statutory funding.' },
]);

// ================================ BUREAUCRACY ================================
const bureaucracy = conceptGens('bureaucracy', [
  'Bureaucracy is administration through a hierarchy of officials following fixed rules',
  'Max Weber developed the classical theory of bureaucracy',
  'A bureaucracy features a clear hierarchy of authority',
  'Bureaucracy relies on written rules, records and official procedures',
  'Specialisation and division of labour are features of bureaucracy',
  'Impersonality means bureaucratic decisions are made without favouritism',
  'Red tape and delay are common criticisms of bureaucracy',
  'Officials in a bureaucracy are appointed on the basis of technical qualification',
], [
  'Bureaucracy has no hierarchy and all officials rank equally',
  'Bureaucratic decisions are properly based on personal friendship',
  'Karl Marx developed the classical theory of bureaucracy',
  'Bureaucracies keep no written records of their decisions',
  'Officials in a bureaucracy are chosen by lottery',
  'Bureaucracy is universally praised for its speed and flexibility',
]);

// ==================== HAUSA-FULANI POLITICAL SYSTEM ====================
const hausaFulani = conceptGens('the pre-colonial Hausa-Fulani political system', [
  'The Hausa-Fulani system was a highly centralised political system',
  'The Emir was the political and religious head of the emirate',
  'The system was based on Islamic law, the Sharia',
  'The Sokoto Caliphate was established after the Jihad of Usman dan Fodio',
  'The Waziri served as the chief adviser to the Emir',
  'The Alkali presided over the Sharia courts',
  'The centralised structure made indirect rule relatively easy to apply in the north',
  'Emirates were subordinate to the Sultan of Sokoto',
], [
  'The Hausa-Fulani system was highly decentralised with no central authority',
  'The Emir had purely ceremonial functions with no real power',
  'The Hausa-Fulani system was based on a written republican constitution',
  'Indirect rule was very difficult to apply in the north because there were no chiefs',
  'The Alkali commanded the emirate army',
  'The Sokoto Caliphate was established by the British',
], [
  { q: 'Who led the Jihad that established the Sokoto Caliphate?', a: 'Usman dan Fodio', w: ['Lord Lugard', 'Oba Ovonramwen', 'Samori Toure'], e: 'Usman dan Fodio\'s Jihad of 1804 overthrew the Hausa kings and created the Sokoto Caliphate, a centralised Islamic state.' },
  { q: 'Why was indirect rule most successful in Northern Nigeria?', a: 'There was an existing centralised authority structure under the Emirs', w: ['The people spoke English fluently', 'There were no traditional rulers at all', 'The region had a republican system'], e: 'Indirect rule needed recognised chiefs through whom to govern. The emirate hierarchy supplied exactly that, so the British simply layered themselves on top.' },
]);

// ======================= YORUBA POLITICAL SYSTEM =======================
const yoruba = conceptGens('the pre-colonial Yoruba political system', [
  'The Yoruba system was a monarchy with checks on the power of the Oba',
  'The Oba was the political and spiritual head of the kingdom',
  'The Oyo Mesi was the council of kingmakers in the Oyo Empire',
  'The Bashorun was the head of the Oyo Mesi',
  'The Ogboni cult acted as a check on both the Oba and the Oyo Mesi',
  'The Oyo Mesi could reject an Alaafin and require him to commit suicide',
  'The Yoruba system combined centralisation with significant constitutional checks',
  'The Aremo was the eldest son of the Alaafin',
], [
  'The Oba of the Yoruba was an absolute ruler subject to no checks whatsoever',
  'The Oyo Mesi was the army of the Oyo Empire',
  'The Ogboni cult had no political influence',
  'The Yoruba system was completely acephalous with no central ruler',
  'The Bashorun was a British colonial officer',
  'The Alaafin could never be removed from office under any circumstances',
], [
  { q: 'Which body served as the council of kingmakers in the old Oyo Empire?', a: 'The Oyo Mesi', w: ['The Ogboni', 'The Alkali court', 'The Council of Elders of Nri'], e: 'The Oyo Mesi, headed by the Bashorun, selected the Alaafin and could also reject him, making it a real constitutional check on the monarchy.' },
  { q: 'Which group acted as a check on the powers of both the Alaafin and the Oyo Mesi?', a: 'The Ogboni cult', w: ['The Emirs', 'The Aro Confederacy', 'The Warrant Chiefs'], e: 'The Ogboni was a powerful religious and judicial society whose approval was needed for major decisions, balancing the other two centres of power.' },
]);

// ========================= IGBO POLITICAL SYSTEM =========================
const igbo = conceptGens('the pre-colonial Igbo political system', [
  'The Igbo political system was largely decentralised and segmentary',
  'The Igbo system is often described as acephalous, meaning without a central head',
  'Decisions were taken in village assemblies in which adult males could speak',
  'The Ofo title holders exercised authority within the lineage',
  'The Age Grade system performed executive and public works functions',
  'Direct democracy was practised at village assembly level',
  'The absence of powerful chiefs made indirect rule difficult in Igboland',
  'The British imposed Warrant Chiefs on Igbo communities',
], [
  'The Igbo political system was highly centralised under a single king',
  'Indirect rule worked very smoothly in Igboland because of its powerful emirs',
  'Village assemblies played no role in Igbo decision-making',
  'The Warrant Chiefs were traditional Igbo rulers of long standing',
  'The Igbo system was based on Sharia law',
  'The Age Grade system had no public functions',
], [
  { q: 'Why did indirect rule largely fail in Igboland?', a: 'There was no pre-existing centralised chieftaincy through which to rule', w: ['The Igbo had too many emirs', 'The British did not try to apply it there', 'The Igbo spoke only English'], e: 'Igbo society was acephalous and decisions were collective, so the British invented Warrant Chiefs with no traditional legitimacy, and they were widely resented.' },
  { q: 'What term describes a political system without a central governing authority?', a: 'Acephalous', w: ['Centralised', 'Theocratic', 'Unitary'], e: 'Acephalous literally means headless. Authority in such systems is dispersed among lineages, age grades and assemblies rather than concentrated in a monarch.' },
]);

// ============================== INDIRECT RULE ==============================
const indirectRule = conceptGens('indirect rule', [
  'Indirect rule was a system of governing colonies through existing traditional rulers',
  'Lord Frederick Lugard introduced indirect rule in Nigeria',
  'Indirect rule was cheap because it required few British personnel',
  'Indirect rule was most successful in Northern Nigeria',
  'Indirect rule largely failed in the Eastern provinces',
  'Warrant Chiefs were appointed where no suitable traditional ruler existed',
  'The amalgamation of Northern and Southern Nigeria took place in 1914',
  'Indirect rule preserved many traditional institutions under British supervision',
], [
  'Indirect rule meant governing colonies directly with British officials only',
  'Indirect rule was introduced by Governor Clifford',
  'Indirect rule was most successful in Eastern Nigeria',
  'Indirect rule required a very large number of British administrators',
  'The amalgamation of Nigeria took place in 1960',
  'Warrant Chiefs were long-established traditional rulers everywhere they were used',
], [
  { q: 'Who is regarded as the architect of indirect rule in Nigeria?', a: 'Lord Frederick Lugard', w: ['Sir Hugh Clifford', 'Sir Arthur Richards', 'Sir John Macpherson'], e: 'Lugard developed the system in Northern Nigeria and extended it after the 1914 amalgamation, setting out the theory in The Dual Mandate.' },
  { q: 'In which year were Northern and Southern Nigeria amalgamated?', a: '1914', w: ['1900', '1922', '1960'], e: 'Lugard amalgamated the Northern and Southern Protectorates in 1914, creating the single colonial entity that became modern Nigeria.' },
  { q: 'What was the main advantage of indirect rule to the British?', a: 'It was cheap and required few British officials', w: ['It rapidly educated the local population', 'It gave Nigerians full self-government', 'It abolished all traditional institutions'], e: 'Ruling through existing chiefs kept costs and staffing low, which was the central attraction for an administration with limited resources.' },
]);

// ================= NIGERIAN CONSTITUTIONS 1922-1960 =================
const colonialConst = conceptGens('Nigerian constitutions between 1922 and 1960', [
  'The Clifford Constitution of 1922 introduced the elective principle',
  'The Clifford Constitution allowed limited franchise in Lagos and Calabar',
  'The Richards Constitution of 1946 introduced regionalism',
  'The Richards Constitution was criticised for lack of consultation with Nigerians',
  'The Macpherson Constitution of 1951 followed extensive consultation',
  'The Lyttleton Constitution of 1954 established a genuine federal structure',
  'Regional self-government was attained by the East and West in 1957',
  'Nigeria attained independence on 1 October 1960',
], [
  'The Clifford Constitution granted independence to Nigeria',
  'The Richards Constitution was widely praised for extensive consultation',
  'The Lyttleton Constitution created a unitary system',
  'Nigeria attained independence in 1963',
  'The Macpherson Constitution was drawn up without consulting any Nigerians',
  'The elective principle was first introduced in 1954',
], [
  { q: 'On what date did Nigeria attain independence?', a: '1 October 1960', w: ['1 October 1963', '15 January 1966', '29 May 1999'], e: 'Nigeria became independent within the Commonwealth on 1 October 1960, and became a republic exactly three years later.' },
  { q: 'Which constitution is credited with introducing regionalism into Nigeria?', a: 'The Richards Constitution of 1946', w: ['The Clifford Constitution of 1922', 'The Macpherson Constitution of 1951', 'The Lyttleton Constitution of 1954'], e: 'Richards divided Nigeria into Northern, Western and Eastern regions with regional councils, laying the groundwork for later federalism.' },
]);

// =========================== NATIONALIST MOVEMENTS ===========================
const nationalism = conceptGens('nationalist movements in Nigeria', [
  'Nationalism is the desire of a people for self-government and independence',
  'Herbert Macaulay is regarded as the father of Nigerian nationalism',
  'The Nigerian National Democratic Party was founded in 1923',
  'The National Council of Nigeria and the Cameroons was formed in 1944',
  'Nnamdi Azikiwe and Herbert Macaulay were prominent in the NCNC',
  'Obafemi Awolowo led the Action Group',
  'Ahmadu Bello led the Northern Peoples Congress',
  'The Second World War and the growth of the press stimulated Nigerian nationalism',
  'Nigerian ex-servicemen returning from the Second World War contributed to nationalist agitation',
], [
  'Nationalism is the desire to remain permanently under colonial rule',
  'Lord Lugard is regarded as the father of Nigerian nationalism',
  'The NCNC was formed in 1960 after independence',
  'Obafemi Awolowo led the Northern Peoples Congress',
  'Ahmadu Bello led the Action Group',
  'The Second World War discouraged nationalist sentiment in Nigeria',
], [
  { q: 'Who is regarded as the father of Nigerian nationalism?', a: 'Herbert Macaulay', w: ['Nnamdi Azikiwe', 'Obafemi Awolowo', 'Ahmadu Bello'], e: 'Macaulay founded the NNDP in 1923 and pioneered organised political agitation against colonial rule, inspiring the generation that followed.' },
  { q: 'Which party was led by Chief Obafemi Awolowo?', a: 'The Action Group', w: ['The NCNC', 'The Northern Peoples Congress', 'The NNDP'], e: 'Awolowo founded and led the Action Group, which controlled the Western Region in the years before and after independence.' },
  { q: 'Which factor contributed significantly to the growth of nationalism in Nigeria?', a: 'The experience of ex-servicemen in the Second World War', w: ['The success of indirect rule', 'The absence of a local press', 'The lack of educated Nigerians'], e: 'Nigerians who fought abroad saw colonial powers defeated and self-determination proclaimed, and returned unwilling to accept subject status.' },
]);

// ============================ THE FIRST REPUBLIC ============================
const firstRepublic = conceptGens('the First Republic', [
  'The First Republic began on 1 October 1963',
  'Nigeria adopted a parliamentary system in the First Republic',
  'Sir Abubakar Tafawa Balewa was the Prime Minister and head of government',
  'Dr Nnamdi Azikiwe was the ceremonial President and head of state',
  'The First Republic was ended by a military coup on 15 January 1966',
  'The 1962-63 census controversy contributed to political crisis',
  'The Western Region crisis of 1962 destabilised the First Republic',
  'Regionalism and ethnic rivalry weakened the First Republic',
], [
  'The First Republic operated a presidential system of government',
  'Tafawa Balewa was the ceremonial head of state',
  'Nnamdi Azikiwe was the Prime Minister of the First Republic',
  'The First Republic began in 1960',
  'The First Republic ended peacefully through a general election',
  'The First Republic was free of ethnic and regional tension',
], [
  { q: 'Who was the Prime Minister of Nigeria during the First Republic?', a: 'Sir Abubakar Tafawa Balewa', w: ['Dr Nnamdi Azikiwe', 'Chief Obafemi Awolowo', 'General Yakubu Gowon'], e: 'Under the parliamentary system Balewa was head of government as Prime Minister, while Azikiwe held the ceremonial presidency.' },
  { q: 'What event brought the First Republic to an end?', a: 'The military coup of 15 January 1966', w: ['The general election of 1964', 'The declaration of a republic in 1963', 'Independence in 1960'], e: 'A group of young army officers overthrew the civilian government in January 1966, beginning Nigeria\'s long experience of military rule.' },
]);

// =============================== MILITARY RULE ===============================
const militaryRule = conceptGens('military rule in Nigeria', [
  'A coup d\'etat is the sudden unconstitutional seizure of power, usually by the military',
  'Military governments usually suspend part or all of the constitution',
  'Military regimes rule by decree rather than by Act of parliament',
  'Under military rule the legislature is normally dissolved',
  'The Supreme Military Council was the highest decision-making body under military rule',
  'The Nigerian Civil War was fought between 1967 and 1970',
  'Military rule concentrates executive and legislative power in the same hands',
  'Fundamental human rights are often curtailed under military rule',
], [
  'Military governments always strengthen and expand the constitution',
  'Military regimes govern through elected parliaments',
  'The Nigerian Civil War was fought between 1979 and 1983',
  'Under military rule the judiciary always retains complete independence',
  'A coup d\'etat is a constitutional transfer of power through elections',
  'Military rule strictly observes the separation of powers',
], [
  { q: 'By what instrument do military governments normally make law?', a: 'Decrees', w: ['Acts of parliament', 'Bye-laws', 'Judicial precedents'], e: 'With the legislature dissolved, the ruling council issues decrees, which typically also oust the jurisdiction of the courts to review them.' },
  { q: 'Between which years was the Nigerian Civil War fought?', a: '1967 to 1970', w: ['1960 to 1963', '1979 to 1983', '1993 to 1999'], e: 'The war followed the attempted secession of the Eastern Region as Biafra and ended in January 1970 with the reunification of the country.' },
]);

// ==================== SECOND AND THIRD REPUBLICS ====================
const secondThird = conceptGens('the Second and Third Republics', [
  'The Second Republic began on 1 October 1979',
  'Alhaji Shehu Shagari was the executive President of the Second Republic',
  'The Second Republic adopted an American-style presidential system',
  'The 1979 Constitution replaced the parliamentary system with a presidential one',
  'The Second Republic was terminated by a military coup on 31 December 1983',
  'The Third Republic was aborted when the June 12 1993 presidential election was annulled',
  'Chief M. K. O. Abiola was widely believed to have won the annulled 1993 election',
  'The Second Republic was troubled by allegations of corruption and electoral malpractice',
], [
  'The Second Republic operated a parliamentary system',
  'Shehu Shagari was a ceremonial president with no executive powers',
  'The Second Republic began in 1963',
  'The Third Republic completed a full term of civilian government',
  'The June 12 1993 election was allowed to stand and its winner took office',
  'The Second Republic ended through a peaceful handover to another civilian government',
], [
  { q: 'Who was the President of Nigeria during the Second Republic?', a: 'Alhaji Shehu Shagari', w: ['Dr Nnamdi Azikiwe', 'General Olusegun Obasanjo', 'Chief M. K. O. Abiola'], e: 'Shagari of the NPN was elected in 1979 as Nigeria\'s first executive President and was overthrown by the military on 31 December 1983.' },
  { q: 'What brought the Third Republic to an end before it properly began?', a: 'The annulment of the June 12 1993 presidential election', w: ['The civil war', 'The 1979 constitution', 'The amalgamation of 1914'], e: 'The military annulled the presidential election widely believed won by M. K. O. Abiola, aborting the transition to civilian rule.' },
]);

// ============================ THE FOURTH REPUBLIC ============================
const fourthRepublic = conceptGens('the Fourth Republic', [
  'The Fourth Republic began on 29 May 1999',
  'Chief Olusegun Obasanjo was the first President of the Fourth Republic',
  'The Fourth Republic operates under the 1999 Constitution',
  'The Fourth Republic uses a presidential system of government',
  'The National Assembly of the Fourth Republic is bicameral',
  'Nigeria currently has 36 states and a Federal Capital Territory',
  'Democracy Day was formerly marked on 29 May and is now marked on 12 June',
  'The Fourth Republic has seen several peaceful transfers of power between civilian governments',
], [
  'The Fourth Republic began in 1993',
  'The Fourth Republic operates a parliamentary system',
  'The Fourth Republic operates under the 1963 Constitution',
  'Nigeria currently has 19 states',
  'The National Assembly of the Fourth Republic is unicameral',
  'Chief M. K. O. Abiola was the first President of the Fourth Republic',
], [
  { q: 'In which year did the Fourth Republic begin?', a: '1999', w: ['1979', '1993', '1960'], e: 'Military rule ended on 29 May 1999 when Olusegun Obasanjo was sworn in under the 1999 Constitution.' },
  { q: 'How many states does Nigeria currently have?', a: '36', w: ['30', '19', '12'], e: 'Nigeria has 36 states plus the Federal Capital Territory, Abuja, a structure reached in 1996.' },
]);

// =============================== FOREIGN POLICY ===============================
const foreignPolicy = conceptGens('Nigerian foreign policy', [
  'Foreign policy is the set of principles guiding a state\'s relations with other states',
  'Africa has traditionally been described as the centrepiece of Nigerian foreign policy',
  'Non-alignment has been a guiding principle of Nigerian foreign policy',
  'Nigeria has consistently opposed colonialism and apartheid in Africa',
  'Nigeria played a leading role in the formation of ECOWAS',
  'Nigeria contributed troops to ECOMOG peacekeeping operations in Liberia and Sierra Leone',
  'Respect for the sovereign equality of states is a principle of Nigerian foreign policy',
  'Good neighbourliness guides Nigeria\'s relations with its immediate neighbours',
], [
  'Nigerian foreign policy has always been aligned to one superpower bloc',
  'Europe has traditionally been the centrepiece of Nigerian foreign policy',
  'Nigeria actively supported apartheid in South Africa',
  'Nigeria opposed the formation of ECOWAS',
  'Nigeria has never participated in any peacekeeping operation',
  'Nigerian foreign policy rejects the sovereign equality of states',
], [
  { q: 'What has traditionally been described as the centrepiece of Nigerian foreign policy?', a: 'Africa', w: ['Europe', 'The Commonwealth', 'The Middle East'], e: 'Successive Nigerian governments have given priority to African liberation, unity and regional stability, a stance summarised as Afrocentrism.' },
  { q: 'Nigeria\'s policy of refusing to align with either superpower bloc during the Cold War is called', a: 'non-alignment', w: ['isolationism', 'colonialism', 'protectionism'], e: 'Non-alignment allowed Nigeria to maintain relations with both East and West while retaining independence of judgement in world affairs.' },
]);

// =================================== ECOWAS ===================================
const ecowas = conceptGens('ECOWAS', [
  'ECOWAS stands for the Economic Community of West African States',
  'ECOWAS was established in 1975 by the Treaty of Lagos',
  'Nigeria and Togo took the lead in establishing ECOWAS',
  'A major aim of ECOWAS is the promotion of trade and economic integration in West Africa',
  'ECOWAS provides for the free movement of persons and goods among member states',
  'ECOMOG was the ECOWAS monitoring group used for peacekeeping',
  'The ECOWAS secretariat is located in Abuja',
  'ECOWAS intervened militarily in the Liberian civil war',
], [
  'ECOWAS was established in 1963',
  'ECOWAS is a military alliance with no economic objectives',
  'ECOWAS restricts the movement of persons between member states',
  'ECOWAS was formed by the Treaty of Rome',
  'The ECOWAS secretariat is located in Addis Ababa',
  'ECOWAS has never engaged in peacekeeping',
], [
  { q: 'In which year was ECOWAS established?', a: '1975', w: ['1963', '1960', '2002'], e: 'ECOWAS was created by the Treaty of Lagos in May 1975, with Nigeria and Togo leading the initiative.' },
  { q: 'What does the acronym ECOWAS stand for?', a: 'Economic Community of West African States', w: ['East African Community of West African States', 'Economic Council of West African Somalia', 'European Community of West African States'], e: 'ECOWAS is the regional bloc of fifteen West African states formed to promote economic integration.' },
]);

// ============================= THE AFRICAN UNION =============================
const au = conceptGens('the African Union', [
  'The African Union replaced the Organisation of African Unity in 2002',
  'The Organisation of African Unity was founded in 1963 in Addis Ababa',
  'The headquarters of the African Union is in Addis Ababa, Ethiopia',
  'A major aim of the AU is to promote unity and solidarity among African states',
  'The AU seeks to defend the sovereignty and territorial integrity of member states',
  'The OAU played a leading role in the struggle against colonialism and apartheid',
  'Nigeria was a founding member of the Organisation of African Unity',
  'The AU promotes peace, security and stability on the African continent',
], [
  'The African Union replaced the OAU in 1963',
  'The headquarters of the African Union is in Abuja',
  'The OAU supported the continuation of colonial rule in Africa',
  'The African Union is open only to North African states',
  'Nigeria refused to join the Organisation of African Unity',
  'The OAU was founded in 2002',
], [
  { q: 'Which organisation did the African Union replace, and in what year?', a: 'The Organisation of African Unity, in 2002', w: ['ECOWAS, in 1975', 'The Commonwealth, in 1960', 'The United Nations, in 1945'], e: 'The OAU, founded in 1963, was formally succeeded by the African Union in 2002 with a broader mandate covering economic integration and security.' },
  { q: 'Where are the headquarters of the African Union located?', a: 'Addis Ababa, Ethiopia', w: ['Abuja, Nigeria', 'Accra, Ghana', 'Nairobi, Kenya'], e: 'The AU inherited the OAU\'s headquarters in Addis Ababa, where the founding charter was signed in 1963.' },
]);

// =========================== THE UNITED NATIONS ===========================
const un = conceptGens('the United Nations', [
  'The United Nations was founded in 1945 after the Second World War',
  'The headquarters of the United Nations is in New York',
  'Nigeria joined the United Nations in 1960 on attaining independence',
  'The principal organs include the General Assembly and the Security Council',
  'The Security Council has five permanent members with the power of veto',
  'The International Court of Justice sits at The Hague',
  'The Secretary-General is the chief administrative officer of the United Nations',
  'A major purpose of the United Nations is the maintenance of international peace and security',
  'Every member state has one vote in the General Assembly',
], [
  'The United Nations was founded in 1919',
  'The headquarters of the United Nations is in Geneva',
  'Nigeria joined the United Nations in 1945',
  'The Security Council has fifteen permanent members with veto power',
  'The International Court of Justice sits in New York',
  'Larger states have more votes than smaller states in the General Assembly',
], [
  { q: 'In which year did Nigeria join the United Nations?', a: '1960', w: ['1945', '1963', '1975'], e: 'Nigeria was admitted as a member on gaining independence in October 1960.' },
  { q: 'How many permanent members does the United Nations Security Council have?', a: 'Five', w: ['Ten', 'Fifteen', 'Three'], e: 'China, France, Russia, the United Kingdom and the United States are permanent members, each holding a veto over substantive resolutions.' },
  { q: 'Which organ of the United Nations bears primary responsibility for international peace and security?', a: 'The Security Council', w: ['The General Assembly', 'The Secretariat', 'The Trusteeship Council'], e: 'The Security Council can authorise sanctions and the use of force, and its decisions bind all member states.' },
]);

// ============================= THE COMMONWEALTH =============================
const commonwealth = conceptGens('the Commonwealth', [
  'The Commonwealth is a voluntary association of states mostly formerly ruled by Britain',
  'Nigeria joined the Commonwealth on attaining independence in 1960',
  'Membership of the Commonwealth is voluntary and a state may withdraw',
  'The Commonwealth promotes democracy, good governance and human rights among members',
  'The Commonwealth Games are held every four years',
  'Nigeria was suspended from the Commonwealth in 1995 and readmitted in 1999',
  'The Commonwealth provides technical assistance and scholarships to member states',
  'Commonwealth Heads of Government Meetings are held periodically',
], [
  'Membership of the Commonwealth is compulsory for all African states',
  'Nigeria has never been suspended from the Commonwealth',
  'The Commonwealth is a military alliance with a joint army',
  'The Commonwealth Games are held every year',
  'A state may not withdraw from the Commonwealth once admitted',
  'Nigeria joined the Commonwealth in 1914',
], [
  { q: 'Why was Nigeria suspended from the Commonwealth in 1995?', a: 'Over human rights abuses under military rule', w: ['For refusing to pay its subscription', 'For leaving ECOWAS', 'For adopting a presidential system'], e: 'Nigeria was suspended following the execution of Ken Saro-Wiwa and other activists, and was readmitted in 1999 after the return to civilian rule.' },
  { q: 'Which of the following best describes the Commonwealth?', a: 'A voluntary association of mainly former British territories', w: ['A compulsory military alliance', 'A West African economic bloc', 'An organ of the United Nations'], e: 'Members join and remain by choice, cooperating on development, democracy and culture rather than under any binding obligation.' },
]);

module.exports = [
  { unitName: U_ADMIN, topicName: 'The Civil Service', generators: civilService },
  { unitName: U_ADMIN, topicName: 'Public Corporations', generators: corporations },
  { unitName: U_ADMIN, topicName: 'Local Government', generators: localGovt },
  { unitName: U_ADMIN, topicName: 'Bureaucracy', generators: bureaucracy },
  { unitName: U_PRE, topicName: 'Hausa-Fulani Political System', generators: hausaFulani },
  { unitName: U_PRE, topicName: 'Yoruba Political System', generators: yoruba },
  { unitName: U_PRE, topicName: 'Igbo Political System', generators: igbo },
  { unitName: U_COL, topicName: 'Indirect Rule', generators: indirectRule },
  { unitName: U_COL, topicName: 'Nigerian Constitutions 1922-1960', generators: colonialConst },
  { unitName: U_COL, topicName: 'Nationalist Movements', generators: nationalism },
  { unitName: U_POST, topicName: 'The First Republic', generators: firstRepublic },
  { unitName: U_POST, topicName: 'Military Rule', generators: militaryRule },
  { unitName: U_POST, topicName: 'Second and Third Republics', generators: secondThird },
  { unitName: U_POST, topicName: 'The Fourth Republic', generators: fourthRepublic },
  { unitName: U_WORLD, topicName: 'Foreign Policy', generators: foreignPolicy },
  { unitName: U_WORLD, topicName: 'ECOWAS', generators: ecowas },
  { unitName: U_WORLD, topicName: 'The African Union', generators: au },
  { unitName: U_WORLD, topicName: 'The United Nations', generators: un },
  { unitName: U_WORLD, topicName: 'The Commonwealth', generators: commonwealth },
];
