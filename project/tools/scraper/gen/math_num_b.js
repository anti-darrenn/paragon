// Mathematics > Number and Numeration (part B)
const L = require('./lib');
const { randInt, pick, shuffle, sample, nonZero, gcd, frac, fracAdd, fracMul, fracTex, fracOpt,
        fmtNum, fixed, buildOptions, numericDistractors, textOptions, round } = L;

const UNIT = '1tP6EvGOVehoTzIfHSf3';
const mathOpt = (s) => `\\(${s}\\)`;

// ================================ SETS ================================
const SET_SUBJECTS = [
  ['Mathematics', 'English'], ['Physics', 'Chemistry'], ['Biology', 'Geography'],
  ['Economics', 'Government'], ['Literature', 'History'], ['Agric Science', 'Civic Education'],
  ['Further Mathematics', 'Technical Drawing'], ['Commerce', 'Accounting'],
];
const SPORTS = [['football', 'basketball'], ['tennis', 'volleyball'], ['athletics', 'swimming']];

const sets = [
  // n(A u B)
  () => {
    const nA = randInt(10, 45), nB = randInt(10, 45), both = randInt(2, Math.min(nA, nB) - 1);
    const correct = nA + nB - both;
    const o = buildOptions(correct, [nA + nB, nA + nB + both, nA + nB - 2 * both, Math.abs(nA - nB)], (v) => String(v));
    if (!o) return null;
    return {
      text: `If \\(n(A) = ${nA}\\), \\(n(B) = ${nB}\\) and \\(n(A \\cap B) = ${both}\\), find \\(n(A \\cup B)\\).`,
      ...o,
      explanation: `\\(n(A \\cup B) = n(A) + n(B) - n(A \\cap B)\\)\n\n\\(= ${nA} + ${nB} - ${both}\\)\n\n\\(= ${correct}\\)`,
    };
  },
  // Venn: find "neither"
  () => {
    const [s1, s2] = pick(SET_SUBJECTS);
    const both = randInt(4, 15);
    const onlyA = randInt(5, 25), onlyB = randInt(5, 25);
    const neither = randInt(2, 12);
    const total = onlyA + onlyB + both + neither;
    const nA = onlyA + both, nB = onlyB + both;
    const o = buildOptions(neither, [total - nA - nB, neither + both, total - (nA + nB - both) + both, neither + 2], (v) => String(v));
    if (!o) return null;
    return {
      text: `In a class of ${total} students, ${nA} offer ${s1}, ${nB} offer ${s2} and ${both} offer both subjects. How many students offer neither subject?`,
      ...o,
      explanation: `\\(n(${s1[0]} \\cup ${s2[0]}) = ${nA} + ${nB} - ${both} = ${nA + nB - both}\\)\n\nStudents offering neither \\(= ${total} - ${nA + nB - both} = ${neither}\\)`,
    };
  },
  // Venn: find "both"
  () => {
    const [s1, s2] = pick(SET_SUBJECTS);
    const both = randInt(5, 18);
    const onlyA = randInt(6, 22), onlyB = randInt(6, 22);
    const total = onlyA + onlyB + both;
    const nA = onlyA + both, nB = onlyB + both;
    const o = buildOptions(both, [total - nA, total - nB, nA + nB - total + 2, both + 3], (v) => String(v));
    if (!o) return null;
    return {
      text: `In a class of ${total} students, every student offers at least one of ${s1} and ${s2}. If ${nA} offer ${s1} and ${nB} offer ${s2}, how many offer both subjects?`,
      ...o,
      explanation: `Since every student offers at least one subject, \\(n(A \\cup B) = ${total}\\).\n\n\\(n(A \\cap B) = n(A) + n(B) - n(A \\cup B)\\)\n\n\\(= ${nA} + ${nB} - ${total} = ${both}\\)`,
    };
  },
  // number of subsets
  () => {
    const n = randInt(3, 8);
    const correct = Math.pow(2, n);
    const o = buildOptions(correct, [2 * n, Math.pow(2, n) - 1, Math.pow(n, 2), Math.pow(2, n + 1)], (v) => String(v));
    if (!o) return null;
    return {
      text: `How many subsets can be formed from a set containing ${n} elements?`,
      ...o,
      explanation: `A set with \\(n\\) elements has \\(2^{n}\\) subsets.\n\n\\(2^{${n}} = ${correct}\\)`,
    };
  },
  // explicit intersection / union
  () => {
    const pool = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
    const A = sample(pool, randInt(4, 5)).sort((a, b) => a - b);
    const B = sample(pool, randInt(4, 5)).sort((a, b) => a - b);
    const op = pick(['\\cap', '\\cup']);
    const inter = A.filter(x => B.includes(x)).sort((a, b) => a - b);
    const uni = Array.from(new Set([...A, ...B])).sort((a, b) => a - b);
    const correctArr = op === '\\cap' ? inter : uni;
    if (correctArr.length === 0) return null;
    const otherArr = op === '\\cap' ? uni : inter;
    if (otherArr.length === 0) return null;
    const fmtSet = (arr) => mathOpt(`\\{${arr.join(', ')}\\}`);
    const o = buildOptions(correctArr, [otherArr, A, B], (arr) => fmtSet(arr));
    if (!o) return null;
    return {
      text: `If \\(A = \\{${A.join(', ')}\\}\\) and \\(B = \\{${B.join(', ')}\\}\\), find \\(A ${op} B\\).`,
      ...o,
      explanation: op === '\\cap'
        ? `\\(A \\cap B\\) contains the elements common to both sets.\n\nComparing the two sets, the common elements are \\(\\{${inter.join(', ')}\\}\\).`
        : `\\(A \\cup B\\) contains every element that appears in either set, listed once.\n\nThis gives \\(\\{${uni.join(', ')}\\}\\).`,
    };
  },
  // complement
  () => {
    const nU = randInt(40, 90), nA = randInt(10, 35);
    const correct = nU - nA;
    const o = buildOptions(correct, [nU + nA, nA, nU - 2 * nA, correct + 5], (v) => String(v));
    if (!o) return null;
    return {
      text: `Given that \\(n(U) = ${nU}\\) and \\(n(A) = ${nA}\\), find \\(n(A')\\).`,
      ...o,
      explanation: `The complement \\(A'\\) contains everything in the universal set that is not in \\(A\\).\n\n\\(n(A') = n(U) - n(A) = ${nU} - ${nA} = ${correct}\\)`,
    };
  },
  // three-set style: only one subject
  () => {
    const [s1, s2] = pick(SET_SUBJECTS);
    const both = randInt(5, 15), onlyA = randInt(8, 25), onlyB = randInt(8, 25);
    const nA = onlyA + both, nB = onlyB + both;
    const o = buildOptions(onlyA, [nA, nA + both, onlyA + both, Math.abs(nA - nB)], (v) => String(v));
    if (!o) return null;
    return {
      text: `${nA} students offer ${s1} and ${nB} students offer ${s2}. If ${both} students offer both subjects, how many offer ${s1} only?`,
      ...o,
      explanation: `Students offering ${s1} only \\(= n(${s1[0]}) - n(\\text{both})\\)\n\n\\(= ${nA} - ${both} = ${onlyA}\\)`,
    };
  },
];

// ========================== RATIONAL NUMBERS ==========================
const rationals = [
  // recurring decimal (one repeating digit) to fraction
  () => {
    const d = randInt(1, 8);
    const correct = frac(d, 9);
    const o = buildOptions(correct, [frac(d, 10), frac(d, 99), frac(d, 100), frac(9, d)], (f) => fracOpt(f));
    if (!o) return null;
    const s = String(d).repeat(3);
    return {
      text: `Express \\(0.${s}...\\) as a fraction in its lowest terms.`,
      ...o,
      explanation: `Let \\(x = 0.${s}...\\)\n\nThen \\(10x = ${d}.${s}...\\)\n\nSubtracting: \\(10x - x = ${d}\\), so \\(9x = ${d}\\).\n\n\\(x = ${fracTex(correct)}\\)`,
    };
  },
  // recurring decimal (two repeating digits)
  () => {
    const n = randInt(10, 98);
    if (n % 11 === 0) return null;
    const correct = frac(n, 99);
    const o = buildOptions(correct, [frac(n, 100), frac(n, 9), frac(n, 90), frac(99, n)], (f) => fracOpt(f));
    if (!o) return null;
    const s = String(n).repeat(2);
    return {
      text: `Express \\(0.${s}...\\) as a fraction in its lowest terms.`,
      ...o,
      explanation: `Let \\(x = 0.${s}...\\)\n\nThen \\(100x = ${n}.${s}...\\)\n\nSubtracting: \\(100x - x = ${n}\\), so \\(99x = ${n}\\).\n\n\\(x = ${fracTex(correct)}\\)`,
    };
  },
  // which is rational / irrational
  () => {
    const perfect = pick([4, 9, 16, 25, 36, 49, 64, 81, 100, 121, 144]);
    const nonPerfect = sample([2, 3, 5, 6, 7, 8, 10, 11, 12, 13, 15, 17, 18, 20], 3);
    const askRational = Math.random() < 0.5;
    const correct = askRational ? mathOpt(`\\sqrt{${perfect}}`) : mathOpt(`\\sqrt{${nonPerfect[0]}}`);
    const others = askRational
      ? nonPerfect.map(n => mathOpt(`\\sqrt{${n}}`))
      : [mathOpt(`\\sqrt{${perfect}}`), mathOpt(`\\sqrt{${pick([4, 9, 16, 25])}}`), mathOpt(`\\frac{${randInt(1, 9)}}{${randInt(2, 9)}}`)];
    const o = textOptions(correct, others);
    if (!o) return null;
    return {
      text: `Which of the following is ${askRational ? 'a rational' : 'an irrational'} number?`,
      ...o,
      explanation: askRational
        ? `A rational number can be written as a fraction of two integers.\n\n\\(\\sqrt{${perfect}} = ${Math.sqrt(perfect)}\\), which is a whole number and therefore rational. The other square roots do not give exact values.`
        : `An irrational number cannot be written as an exact fraction of two integers.\n\n\\(\\sqrt{${nonPerfect[0]}}\\) is not a perfect square, so its square root is irrational. The others simplify to exact rational values.`,
    };
  },
  // reciprocal
  () => {
    const n = randInt(2, 15), d = randInt(2, 15);
    if (gcd(n, d) !== 1 || n === d) return null;
    const correct = frac(d, n);
    const o = buildOptions(correct, [frac(n, d), frac(-d, n), frac(n + d, n), frac(1, n * d)], (f) => fracOpt(f));
    if (!o) return null;
    return {
      text: `Find the reciprocal of \\(\\frac{${n}}{${d}}\\).`,
      ...o,
      explanation: `The reciprocal of a fraction is obtained by inverting it.\n\nThe reciprocal of \\(\\frac{${n}}{${d}}\\) is \\(${fracTex(correct)}\\).`,
    };
  },
  // ordering rational numbers
  () => {
    const cands = [frac(randInt(1, 7), randInt(8, 12)), frac(randInt(1, 5), randInt(6, 9)), frac(randInt(3, 8), randInt(9, 13)), frac(randInt(1, 4), randInt(5, 7))];
    const vals = cands.map(f => f.n / f.d);
    const maxIdx = vals.indexOf(Math.max(...vals));
    const uniq = new Set(vals.map(v => round(v, 6)));
    if (uniq.size !== 4) return null;
    const correct = cands[maxIdx];
    const o = buildOptions(correct, cands.filter((_, i) => i !== maxIdx), (f) => fracOpt(f));
    if (!o) return null;
    return {
      text: `Which of the following fractions is the largest?`,
      ...o,
      explanation: `Convert each fraction to a decimal:\n\n${cands.map(f => `\\(${fracTex(f)} = ${fmtNum(f.n / f.d, 4)}\\)`).join('\n\n')}\n\nThe largest value is \\(${fracTex(correct)}\\).`,
    };
  },
  // simplify a fraction to lowest terms
  () => {
    const base = frac(randInt(1, 9), randInt(2, 11));
    const k = randInt(2, 9);
    const n = base.n * k, d = base.d * k;
    if (n === d) return null;
    const o = buildOptions(base, [frac(n, d + k), frac(n + 1, d), frac(d, n), frac(n / gcd(n, d) + 1, d / gcd(n, d))], (f) => fracOpt(f));
    if (!o) return null;
    return {
      text: `Reduce \\(\\frac{${n}}{${d}}\\) to its lowest terms.`,
      ...o,
      explanation: `The highest common factor of ${n} and ${d} is ${gcd(n, d)}.\n\n\\(\\frac{${n}}{${d}} = \\frac{${n} \\div ${gcd(n, d)}}{${d} \\div ${gcd(n, d)}} = ${fracTex(base)}\\)`,
    };
  },
];

// ====================== RATIO / PROPORTIONS / RATES ======================
const NAMES = ['Ada', 'Bola', 'Chidi', 'Dele', 'Emeka', 'Funke', 'Gbenga', 'Halima', 'Ifeoma', 'Jide', 'Kemi', 'Musa', 'Ngozi', 'Segun', 'Tunde', 'Uche', 'Yemi', 'Zainab'];

const ratios = [
  // share an amount in ratio a:b
  () => {
    const a = randInt(1, 9), b = randInt(1, 9);
    if (gcd(a, b) !== 1 || a === b) return null;
    const unit = randInt(20, 400);
    const total = (a + b) * unit;
    const [n1, n2] = sample(NAMES, 2);
    const correct = a * unit;
    const o = buildOptions(correct, [b * unit, total / 2, total * a / b, correct + unit], (v) => fmtNum(v, 2));
    if (!o) return null;
    return {
      text: `N${total} is shared between ${n1} and ${n2} in the ratio ${a}:${b}. How much does ${n1} receive?`,
      ...o,
      explanation: `Total number of parts \\(= ${a} + ${b} = ${a + b}\\)\n\nValue of one part \\(= \\frac{${total}}{${a + b}} = ${unit}\\)\n\n${n1}'s share \\(= ${a} \\times ${unit} = ${correct}\\)\n\nSo ${n1} receives N${correct}.`,
    };
  },
  // share in ratio a:b:c
  () => {
    const a = randInt(1, 6), b = randInt(1, 6), c = randInt(1, 6);
    const unit = randInt(15, 250);
    const total = (a + b + c) * unit;
    const [n1, n2, n3] = sample(NAMES, 3);
    const which = pick([0, 1, 2]);
    const parts = [a, b, c], names = [n1, n2, n3];
    const correct = parts[which] * unit;
    const o = buildOptions(correct, [parts[(which + 1) % 3] * unit, parts[(which + 2) % 3] * unit, total / 3, correct + unit], (v) => fmtNum(v, 2));
    if (!o) return null;
    return {
      text: `N${total} is shared among ${n1}, ${n2} and ${n3} in the ratio ${a}:${b}:${c}. Find ${names[which]}'s share.`,
      ...o,
      explanation: `Total parts \\(= ${a} + ${b} + ${c} = ${a + b + c}\\)\n\nOne part \\(= \\frac{${total}}{${a + b + c}} = ${unit}\\)\n\n${names[which]}'s share \\(= ${parts[which]} \\times ${unit} = ${correct}\\)`,
    };
  },
  // simplify a ratio
  () => {
    const g = randInt(2, 12);
    const a = randInt(2, 12), b = randInt(2, 12);
    if (gcd(a, b) !== 1 || a === b) return null;
    const A = a * g, B = b * g;
    const o = buildOptions(`${a}:${b}`, [`${b}:${a}`, `${A}:${B}`, `${a + 1}:${b}`, `${a}:${b + 1}`], (s) => s);
    if (!o) return null;
    return {
      text: `Express the ratio ${A}:${B} in its simplest form.`,
      ...o,
      explanation: `The highest common factor of ${A} and ${B} is ${g}.\n\nDividing both by ${g}: \\(${A} \\div ${g} = ${a}\\) and \\(${B} \\div ${g} = ${b}\\).\n\nSo the ratio is ${a}:${b}.`,
    };
  },
  // speed = distance / time
  () => {
    const speed = randInt(3, 30) * 5;
    const time = randInt(2, 9);
    const distance = speed * time;
    const ask = pick(['speed', 'time', 'distance']);
    if (ask === 'speed') {
      const o = buildOptions(speed, [distance / (time + 1), distance * time, speed + 10, speed / 2], (v) => `${fmtNum(v, 2)} km/h`);
      if (!o) return null;
      return {
        text: `A car travels ${distance}km in ${time} hours. Find its average speed.`,
        ...o,
        explanation: `\\(\\text{Speed} = \\frac{\\text{distance}}{\\text{time}}\\)\n\n\\(= \\frac{${distance}}{${time}} = ${speed}\\) km/h`,
      };
    } else if (ask === 'time') {
      const o = buildOptions(time, [distance / (speed * 2), time + 1, distance * speed, time / 2], (v) => `${fmtNum(v, 2)} hours`);
      if (!o) return null;
      return {
        text: `A car travels ${distance}km at an average speed of ${speed}km/h. How long does the journey take?`,
        ...o,
        explanation: `\\(\\text{Time} = \\frac{\\text{distance}}{\\text{speed}}\\)\n\n\\(= \\frac{${distance}}{${speed}} = ${time}\\) hours`,
      };
    } else {
      const o = buildOptions(distance, [speed / time, speed + time, distance / 2, distance + speed], (v) => `${fmtNum(v, 2)} km`);
      if (!o) return null;
      return {
        text: `A car travels for ${time} hours at an average speed of ${speed}km/h. Find the distance covered.`,
        ...o,
        explanation: `\\(\\text{Distance} = \\text{speed} \\times \\text{time}\\)\n\n\\(= ${speed} \\times ${time} = ${distance}\\) km`,
      };
    }
  },
  // direct proportion cost
  () => {
    const unitCost = randInt(20, 500);
    const q1 = randInt(2, 12), q2 = randInt(3, 20);
    if (q1 === q2) return null;
    const c1 = unitCost * q1, c2 = unitCost * q2;
    const o = buildOptions(c2, [c1 * q2, c1 + q2, c1 / q2, c2 + unitCost], (v) => fmtNum(v, 2));
    if (!o) return null;
    return {
      text: `If ${q1} exercise books cost N${c1}, how much will ${q2} of the same exercise books cost?`,
      ...o,
      explanation: `Cost of 1 book \\(= \\frac{${c1}}{${q1}} = ${unitCost}\\)\n\nCost of ${q2} books \\(= ${unitCost} \\times ${q2} = ${c2}\\)\n\nSo they cost N${c2}.`,
    };
  },
  // work rate (men x days)
  () => {
    const men1 = randInt(2, 12), days1 = randInt(4, 30);
    const work = men1 * days1;
    const men2Options = [];
    for (let m = 2; m <= 40; m++) if (m !== men1 && work % m === 0) men2Options.push(m);
    if (men2Options.length === 0) return null;
    const men2 = pick(men2Options);
    const days2 = work / men2;
    const o = buildOptions(days2, [days1, work / (men2 + 1), days1 * men2 / men1, days2 + 2], (v) => `${fmtNum(v, 2)} days`);
    if (!o) return null;
    return {
      text: `If ${men1} men can complete a job in ${days1} days, how long will it take ${men2} men working at the same rate?`,
      ...o,
      explanation: `This is inverse proportion: more men means fewer days.\n\nTotal work \\(= ${men1} \\times ${days1} = ${work}\\) man-days\n\nTime for ${men2} men \\(= \\frac{${work}}{${men2}} = ${days2}\\) days`,
    };
  },
  // find a missing term in a proportion
  () => {
    const k = randInt(2, 12);
    const a = randInt(2, 12), b = a * k;
    const c = randInt(2, 15), d = c * k;
    const o = buildOptions(d, [c * a, c + k, d + k, c / k], (v) => fmtNum(v, 2));
    if (!o) return null;
    return {
      text: `If \\(${a} : ${b} = ${c} : x\\), find \\(x\\).`,
      ...o,
      explanation: `\\(\\frac{${a}}{${b}} = \\frac{${c}}{x}\\)\n\nCross-multiplying: \\(${a}x = ${b} \\times ${c} = ${b * c}\\)\n\n\\(x = \\frac{${b * c}}{${a}} = ${d}\\)`,
    };
  },
];

// ====================== MATRICES AND DETERMINANTS ======================
const matTex = (m) => `\\begin{pmatrix} ${m[0][0]} & ${m[0][1]} \\\\ ${m[1][0]} & ${m[1][1]} \\end{pmatrix}`;
const matOpt = (m) => mathOpt(matTex(m));
const randMat = (lo = -6, hi = 9) => [[randInt(lo, hi), randInt(lo, hi)], [randInt(lo, hi), randInt(lo, hi)]];

const matrices = [
  // determinant
  () => {
    const M = randMat(-8, 9);
    const [[a, b], [c, d]] = M;
    const correct = a * d - b * c;
    const o = buildOptions(correct, [a * d + b * c, a * b - c * d, a + d - b - c, -(a * d - b * c)], (v) => String(v));
    if (!o) return null;
    return {
      text: `Find the determinant of the matrix \\(${matTex(M)}\\).`,
      ...o,
      explanation: `For \\(\\begin{pmatrix} a & b \\\\ c & d \\end{pmatrix}\\), the determinant is \\(ad - bc\\).\n\n\\(= (${a})(${d}) - (${b})(${c})\\)\n\n\\(= ${a * d} - ${b * c} = ${correct}\\)`,
    };
  },
  // addition
  () => {
    const A = randMat(-7, 9), B = randMat(-7, 9);
    const S = [[A[0][0] + B[0][0], A[0][1] + B[0][1]], [A[1][0] + B[1][0], A[1][1] + B[1][1]]];
    const W1 = [[A[0][0] - B[0][0], A[0][1] - B[0][1]], [A[1][0] - B[1][0], A[1][1] - B[1][1]]];
    const W2 = [[A[0][0] + B[0][0], A[0][1] + B[1][1]], [A[1][0] + B[0][0], A[1][1] + B[1][1]]];
    const W3 = [[S[0][0] + 1, S[0][1]], [S[1][0], S[1][1] - 1]];
    const o = buildOptions(S, [W1, W2, W3], matOpt);
    if (!o) return null;
    return {
      text: `Given \\(A = ${matTex(A)}\\) and \\(B = ${matTex(B)}\\), find \\(A + B\\).`,
      ...o,
      explanation: `Add the matrices element by element.\n\nTop row: \\(${A[0][0]} + (${B[0][0]}) = ${S[0][0]}\\), \\(${A[0][1]} + (${B[0][1]}) = ${S[0][1]}\\)\n\nBottom row: \\(${A[1][0]} + (${B[1][0]}) = ${S[1][0]}\\), \\(${A[1][1]} + (${B[1][1]}) = ${S[1][1]}\\)\n\nSo \\(A + B = ${matTex(S)}\\).`,
    };
  },
  // scalar multiple
  () => {
    const A = randMat(-6, 8);
    const k = nonZero(-5, 6);
    const S = A.map(r => r.map(v => v * k));
    const W1 = A.map(r => r.map(v => v + k));
    const W2 = [[A[0][0] * k, A[0][1]], [A[1][0], A[1][1] * k]];
    const W3 = A.map(r => r.map(v => v * (k + 1)));
    const o = buildOptions(S, [W1, W2, W3], matOpt);
    if (!o) return null;
    return {
      text: `If \\(A = ${matTex(A)}\\), find \\(${k}A\\).`,
      ...o,
      explanation: `Multiply every element of the matrix by ${k}.\n\n\\(${k}A = ${matTex(S)}\\)`,
    };
  },
  // multiplication
  () => {
    const A = randMat(-4, 6), B = randMat(-4, 6);
    const P = [
      [A[0][0] * B[0][0] + A[0][1] * B[1][0], A[0][0] * B[0][1] + A[0][1] * B[1][1]],
      [A[1][0] * B[0][0] + A[1][1] * B[1][0], A[1][0] * B[0][1] + A[1][1] * B[1][1]],
    ];
    const Wrong = [[A[0][0] * B[0][0], A[0][1] * B[0][1]], [A[1][0] * B[1][0], A[1][1] * B[1][1]]];
    const W2 = [[P[0][0] + 1, P[0][1]], [P[1][0], P[1][1] + 1]];
    const W3 = [[P[1][1], P[0][1]], [P[1][0], P[0][0]]];
    const o = buildOptions(P, [Wrong, W2, W3], matOpt);
    if (!o) return null;
    return {
      text: `Given \\(A = ${matTex(A)}\\) and \\(B = ${matTex(B)}\\), find \\(AB\\).`,
      ...o,
      explanation: `Multiply row by column.\n\nTop-left: \\((${A[0][0]})(${B[0][0]}) + (${A[0][1]})(${B[1][0]}) = ${P[0][0]}\\)\n\nTop-right: \\((${A[0][0]})(${B[0][1]}) + (${A[0][1]})(${B[1][1]}) = ${P[0][1]}\\)\n\nBottom-left: \\((${A[1][0]})(${B[0][0]}) + (${A[1][1]})(${B[1][0]}) = ${P[1][0]}\\)\n\nBottom-right: \\((${A[1][0]})(${B[0][1]}) + (${A[1][1]})(${B[1][1]}) = ${P[1][1]}\\)\n\nSo \\(AB = ${matTex(P)}\\).`,
    };
  },
  // singular matrix: find x
  () => {
    const b = randInt(1, 8), c = randInt(1, 8), d = randInt(1, 8);
    const prod = b * c;
    if (prod % d !== 0) return null;
    const x = prod / d;                      // xd - bc = 0
    const o = buildOptions(x, [-x, x + 1, prod, b + c - d], (v) => String(v));
    if (!o) return null;
    return {
      text: `Find the value of \\(x\\) for which the matrix \\(\\begin{pmatrix} x & ${b} \\\\ ${c} & ${d} \\end{pmatrix}\\) has no inverse.`,
      ...o,
      explanation: `A matrix has no inverse when its determinant is zero.\n\n\\(\\det = (x)(${d}) - (${b})(${c}) = ${d}x - ${prod}\\)\n\nSetting \\(${d}x - ${prod} = 0\\): \\(x = \\frac{${prod}}{${d}} = ${x}\\)`,
    };
  },
  // inverse of a 2x2
  () => {
    const [[a, b], [c, d]] = randMat(1, 6);
    const det = a * d - b * c;
    if (det === 0 || Math.abs(det) === 1) return null;
    const adj = [[d, -b], [-c, a]];
    const correct = `\\frac{1}{${det}}${matTex(adj)}`;
    const wrongs = [
      `\\frac{1}{${det}}${matTex([[a, b], [c, d]])}`,
      `\\frac{1}{${-det}}${matTex(adj)}`,
      `\\frac{1}{${det}}${matTex([[d, b], [c, a]])}`,
    ];
    const o = textOptions(mathOpt(correct), wrongs.map(mathOpt));
    if (!o) return null;
    return {
      text: `Find the inverse of the matrix \\(${matTex([[a, b], [c, d]])}\\).`,
      ...o,
      explanation: `For \\(\\begin{pmatrix} a & b \\\\ c & d \\end{pmatrix}\\), the inverse is \\(\\frac{1}{ad-bc}\\begin{pmatrix} d & -b \\\\ -c & a \\end{pmatrix}\\).\n\nDeterminant \\(= (${a})(${d}) - (${b})(${c}) = ${det}\\)\n\nSo the inverse is \\(${correct}\\).`,
    };
  },
];

// ========================== MODULAR ARITHMETIC ==========================
const modular = [
  // (a + b) mod n
  () => {
    const n = randInt(3, 12), a = randInt(5, 60), b = randInt(5, 60);
    const correct = (a + b) % n;
    const o = buildOptions(correct, [(a + b) % (n + 1), (a * b) % n, (correct + 1) % n, a % n], (v) => String(v));
    if (!o) return null;
    return {
      text: `Evaluate \\((${a} + ${b}) \\pmod{${n}}\\).`,
      ...o,
      explanation: `\\(${a} + ${b} = ${a + b}\\)\n\nDividing ${a + b} by ${n} gives a quotient of ${Math.floor((a + b) / n)} and a remainder of ${correct}.\n\nSo \\((${a} + ${b}) \\equiv ${correct} \\pmod{${n}}\\).`,
    };
  },
  // (a x b) mod n
  () => {
    const n = randInt(3, 12), a = randInt(3, 25), b = randInt(3, 25);
    const correct = (a * b) % n;
    const o = buildOptions(correct, [(a + b) % n, (a * b) % (n + 1), (correct + 2) % n, (a % n) * (b % n)], (v) => String(v));
    if (!o) return null;
    return {
      text: `Evaluate \\((${a} \\times ${b}) \\pmod{${n}}\\).`,
      ...o,
      explanation: `\\(${a} \\times ${b} = ${a * b}\\)\n\nDividing ${a * b} by ${n} gives a remainder of ${correct}.\n\nSo \\((${a} \\times ${b}) \\equiv ${correct} \\pmod{${n}}\\).`,
    };
  },
  // reduce a single number
  () => {
    const n = randInt(3, 15), a = randInt(20, 300);
    const correct = a % n;
    const o = buildOptions(correct, [a % (n + 1), n - correct, correct + 1, Math.floor(a / n)], (v) => String(v));
    if (!o) return null;
    return {
      text: `Find the value of ${a} modulo ${n}.`,
      ...o,
      explanation: `Divide ${a} by ${n}: \\(${a} = ${n} \\times ${Math.floor(a / n)} + ${correct}\\)\n\nThe remainder is ${correct}, so \\(${a} \\equiv ${correct} \\pmod{${n}}\\).`,
    };
  },
  // solve a simple congruence
  () => {
    const n = randInt(4, 11);
    const a = randInt(2, n - 1);
    if (gcd(a, n) !== 1) return null;
    let x = null;
    const b = randInt(1, n - 1);
    for (let i = 0; i < n; i++) if ((a * i) % n === b) { x = i; break; }
    if (x === null) return null;
    const o = buildOptions(x, [(x + 1) % n, (x + 2) % n, (b * a) % n, n - x], (v) => String(v));
    if (!o) return null;
    return {
      text: `Find the value of \\(x\\) such that \\(${a}x \\equiv ${b} \\pmod{${n}}\\), where \\(0 \\leq x < ${n}\\).`,
      ...o,
      explanation: `Test the values \\(x = 0, 1, 2, \\dots, ${n - 1}\\).\n\nWhen \\(x = ${x}\\): \\(${a} \\times ${x} = ${a * x}\\), and \\(${a * x} \\div ${n}\\) leaves a remainder of ${b}.\n\nSo \\(x = ${x}\\).`,
    };
  },
  // day of the week / clock arithmetic
  () => {
    const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    const startIdx = randInt(0, 6);
    const ahead = randInt(10, 200);
    const correctIdx = (startIdx + ahead) % 7;
    const o = buildOptions(correctIdx, [(correctIdx + 1) % 7, (correctIdx + 2) % 7, (correctIdx + 6) % 7, (startIdx + ahead) % 6],
      (i) => days[((i % 7) + 7) % 7]);
    if (!o) return null;
    return {
      text: `If today is ${days[startIdx]}, what day of the week will it be in ${ahead} days' time?`,
      ...o,
      explanation: `There are 7 days in a week, so work modulo 7.\n\n\\(${ahead} \\div 7\\) leaves a remainder of ${ahead % 7}.\n\nCounting ${ahead % 7} day${ahead % 7 === 1 ? '' : 's'} on from ${days[startIdx]} gives ${days[correctIdx]}.`,
    };
  },
  // additive inverse in modulo n
  () => {
    const n = randInt(5, 13), a = randInt(1, n - 1);
    const correct = (n - a) % n;
    const o = buildOptions(correct, [a, (correct + 1) % n, n, (n + a) % n], (v) => String(v));
    if (!o) return null;
    return {
      text: `Find the additive inverse of ${a} in modulo ${n} arithmetic.`,
      ...o,
      explanation: `The additive inverse of \\(a\\) is the value \\(b\\) with \\(a + b \\equiv 0 \\pmod{${n}}\\).\n\n\\(${a} + ${correct} = ${a + correct} \\equiv 0 \\pmod{${n}}\\)\n\nSo the additive inverse is ${correct}.`,
    };
  },
];

// =============================== SURDS ===============================
function simplifySurd(N) {
  let c = 1, r = N;
  for (let f = Math.floor(Math.sqrt(N)); f >= 2; f--) {
    if (r % (f * f) === 0) { c = f; r = r / (f * f); break; }
  }
  return { c, r };
}
function surdTex(c, r) {
  if (r === 1) return String(c);
  if (c === 1) return `\\sqrt{${r}}`;
  return `${c}\\sqrt{${r}}`;
}
const surdOpt = (o) => mathOpt(surdTex(o.c, o.r));

const surds = [
  // simplify a single surd
  () => {
    const r = pick([2, 3, 5, 6, 7, 10, 11, 13]);
    const c = randInt(2, 7);
    const N = c * c * r;
    const s = simplifySurd(N);
    if (s.c === 1) return null;
    const o = buildOptions(s, [{ c: s.c + 1, r: s.r }, { c: s.r, r: s.c }, { c: 1, r: N }, { c: s.c, r: s.r + 1 }], surdOpt);
    if (!o) return null;
    return {
      text: `Simplify \\(\\sqrt{${N}}\\).`,
      ...o,
      explanation: `Look for the largest perfect square factor of ${N}.\n\n\\(${N} = ${s.c * s.c} \\times ${s.r}\\)\n\n\\(\\sqrt{${N}} = \\sqrt{${s.c * s.c}} \\times \\sqrt{${s.r}} = ${surdTex(s.c, s.r)}\\)`,
    };
  },
  // add / subtract like surds
  () => {
    const r = pick([2, 3, 5, 6, 7, 11]);
    const a = randInt(2, 12), b = randInt(2, 12);
    const op = pick(['+', '-']);
    const cc = op === '+' ? a + b : a - b;
    if (cc <= 0) return null;
    const correct = { c: cc, r };
    const o = buildOptions(correct, [{ c: op === '+' ? a - b : a + b, r }, { c: a * b, r }, { c: cc, r: r * 2 }, { c: cc + 1, r }], surdOpt);
    if (!o) return null;
    return {
      text: `Simplify \\(${a}\\sqrt{${r}} ${op} ${b}\\sqrt{${r}}\\).`,
      ...o,
      explanation: `These are like surds, so add or subtract the coefficients and keep \\(\\sqrt{${r}}\\).\n\n\\(${a} ${op} ${b} = ${cc}\\)\n\nSo the answer is \\(${surdTex(cc, r)}\\).`,
    };
  },
  // multiply two surds
  () => {
    const p = pick([2, 3, 5, 6, 7, 10]), q = pick([2, 3, 5, 6, 7, 10]);
    const prod = p * q;
    const s = simplifySurd(prod);
    const o = buildOptions(s, [{ c: 1, r: p + q }, { c: p, r: q }, { c: s.c + 1, r: s.r }, { c: 1, r: prod + 1 }], surdOpt);
    if (!o) return null;
    return {
      text: `Simplify \\(\\sqrt{${p}} \\times \\sqrt{${q}}\\).`,
      ...o,
      explanation: `\\(\\sqrt{a} \\times \\sqrt{b} = \\sqrt{ab}\\)\n\n\\(\\sqrt{${p}} \\times \\sqrt{${q}} = \\sqrt{${prod}}\\)\n\n${s.c === 1 ? `This does not simplify further, so the answer is \\(\\sqrt{${prod}}\\).` : `\\(\\sqrt{${prod}} = ${surdTex(s.c, s.r)}\\)`}`,
    };
  },
  // rationalise a/sqrt(b)
  () => {
    const b = pick([2, 3, 5, 6, 7, 11]);
    const a = randInt(2, 12) * b;             // keeps the result tidy
    const c = a / b;
    const correct = { c, r: b };
    const o = buildOptions(correct, [{ c: a, r: b }, { c: c, r: b * b }, { c: c + 1, r: b }, { c: b, r: c }], surdOpt);
    if (!o) return null;
    return {
      text: `Rationalise the denominator of \\(\\frac{${a}}{\\sqrt{${b}}}\\).`,
      ...o,
      explanation: `Multiply the numerator and denominator by \\(\\sqrt{${b}}\\).\n\n\\(\\frac{${a}}{\\sqrt{${b}}} \\times \\frac{\\sqrt{${b}}}{\\sqrt{${b}}} = \\frac{${a}\\sqrt{${b}}}{${b}}\\)\n\n\\(= ${surdTex(c, b)}\\)`,
    };
  },
  // (sqrt a + sqrt b)(sqrt a - sqrt b)
  () => {
    const p = pick([3, 5, 6, 7, 10, 11, 13]), q = pick([2, 3, 5, 7]);
    if (p === q) return null;
    const correct = p - q;
    const o = buildOptions(correct, [p + q, p * q, correct + 1, q - p], (v) => String(v));
    if (!o) return null;
    return {
      text: `Simplify \\((\\sqrt{${p}} + \\sqrt{${q}})(\\sqrt{${p}} - \\sqrt{${q}})\\).`,
      ...o,
      explanation: `This is the difference of two squares: \\((a+b)(a-b) = a^{2} - b^{2}\\).\n\n\\(= (\\sqrt{${p}})^{2} - (\\sqrt{${q}})^{2}\\)\n\n\\(= ${p} - ${q} = ${correct}\\)`,
    };
  },
  // square of a surd expression
  () => {
    const p = pick([2, 3, 5, 7]);
    const a = randInt(1, 5);
    // (a + sqrt p)^2 = a^2 + p + 2a sqrt p
    const rational = a * a + p;
    const coefficient = 2 * a;
    const correct = `${rational} + ${surdTex(coefficient, p)}`;
    const wrongs = [
      `${a * a + p} + ${surdTex(a, p)}`,
      `${a * a - p} + ${surdTex(coefficient, p)}`,
      `${a * a + p * p} + ${surdTex(coefficient, p)}`,
    ];
    const o = textOptions(mathOpt(correct), wrongs.map(mathOpt));
    if (!o) return null;
    return {
      text: `Expand and simplify \\((${a} + \\sqrt{${p}})^{2}\\).`,
      ...o,
      explanation: `\\((a+b)^{2} = a^{2} + 2ab + b^{2}\\)\n\n\\(= ${a}^{2} + 2(${a})(\\sqrt{${p}}) + (\\sqrt{${p}})^{2}\\)\n\n\\(= ${a * a} + ${surdTex(coefficient, p)} + ${p}\\)\n\n\\(= ${correct}\\)`,
    };
  },
  // rationalise with a conjugate
  () => {
    const p = pick([2, 3, 5, 7]);
    const a = randInt(1, 4);
    const den = a * a - p;                    // (a - sqrt p)(a + sqrt p)
    if (den === 0) return null;
    const correct = `\\frac{${a} + \\sqrt{${p}}}{${den}}`;
    const wrongs = [
      `\\frac{${a} - \\sqrt{${p}}}{${den}}`,
      `\\frac{${a} + \\sqrt{${p}}}{${a * a + p}}`,
      `\\frac{${a} + \\sqrt{${p}}}{${-den}}`,
    ];
    const o = textOptions(mathOpt(correct), wrongs.map(mathOpt));
    if (!o) return null;
    return {
      text: `Rationalise the denominator of \\(\\frac{1}{${a} - \\sqrt{${p}}}\\).`,
      ...o,
      explanation: `Multiply the numerator and denominator by the conjugate \\(${a} + \\sqrt{${p}}\\).\n\nDenominator: \\((${a} - \\sqrt{${p}})(${a} + \\sqrt{${p}}) = ${a}^{2} - ${p} = ${den}\\)\n\nSo the expression becomes \\(${correct}\\).`,
    };
  },
];

// ========================== LOGICAL REASONING ==========================
const PAIRS = [
  { p: 'it rains', np: 'it does not rain', q: 'the match is cancelled', nq: 'the match is not cancelled' },
  { p: 'a student works hard', np: 'a student does not work hard', q: 'he passes the examination', nq: 'he does not pass the examination' },
  { p: 'the sun shines', np: 'the sun does not shine', q: 'the clothes dry', nq: 'the clothes do not dry' },
  { p: 'Ada is a doctor', np: 'Ada is not a doctor', q: 'Ada works in a hospital', nq: 'Ada does not work in a hospital' },
  { p: 'the road is wet', np: 'the road is not wet', q: 'driving is dangerous', nq: 'driving is not dangerous' },
  { p: 'a number is even', np: 'a number is not even', q: 'it is divisible by 2', nq: 'it is not divisible by 2' },
  { p: 'the bell rings', np: 'the bell does not ring', q: 'the lesson ends', nq: 'the lesson does not end' },
  { p: 'Musa studies Physics', np: 'Musa does not study Physics', q: 'Musa studies Mathematics', nq: 'Musa does not study Mathematics' },
  { p: 'the price falls', np: 'the price does not fall', q: 'demand increases', nq: 'demand does not increase' },
  { p: 'a triangle is equilateral', np: 'a triangle is not equilateral', q: 'all its sides are equal', nq: 'not all its sides are equal' },
  { p: 'the power supply fails', np: 'the power supply does not fail', q: 'the generator is switched on', nq: 'the generator is not switched on' },
  { p: 'Kemi arrives early', np: 'Kemi does not arrive early', q: 'she gets a seat', nq: 'she does not get a seat' },
  { p: 'the farmer plants in June', np: 'the farmer does not plant in June', q: 'the harvest is good', nq: 'the harvest is not good' },
  { p: 'a shape is a square', np: 'a shape is not a square', q: 'it has four right angles', nq: 'it does not have four right angles' },
  { p: 'the team wins', np: 'the team does not win', q: 'the supporters celebrate', nq: 'the supporters do not celebrate' },
  { p: 'Tunde saves money', np: 'Tunde does not save money', q: 'he buys a bicycle', nq: 'he does not buy a bicycle' },
  { p: 'the water boils', np: 'the water does not boil', q: 'steam is produced', nq: 'steam is not produced' },
  { p: 'a fruit is ripe', np: 'a fruit is not ripe', q: 'it tastes sweet', nq: 'it does not taste sweet' },
  { p: 'the school closes', np: 'the school does not close', q: 'the students go home', nq: 'the students do not go home' },
  { p: 'Ngozi reads the notes', np: 'Ngozi does not read the notes', q: 'she answers the question', nq: 'she does not answer the question' },
  { p: 'the fuel finishes', np: 'the fuel does not finish', q: 'the car stops', nq: 'the car does not stop' },
  { p: 'a number ends in 5', np: 'a number does not end in 5', q: 'it is divisible by 5', nq: 'it is not divisible by 5' },
  { p: 'the market is open', np: 'the market is not open', q: 'traders make sales', nq: 'traders do not make sales' },
  { p: 'Halima trains daily', np: 'Halima does not train daily', q: 'she wins the race', nq: 'she does not win the race' },
  { p: 'the phone is charged', np: 'the phone is not charged', q: 'it switches on', nq: 'it does not switch on' },
  { p: 'the gate is locked', np: 'the gate is not locked', q: 'no one enters', nq: 'someone enters' },
  { p: 'a polygon has three sides', np: 'a polygon does not have three sides', q: 'it is a triangle', nq: 'it is not a triangle' },
  { p: 'Segun pays the fee', np: 'Segun does not pay the fee', q: 'he writes the examination', nq: 'he does not write the examination' },
  { p: 'the rain stops', np: 'the rain does not stop', q: 'the farmers go to the farm', nq: 'the farmers do not go to the farm' },
  { p: 'Uche revises the topic', np: 'Uche does not revise the topic', q: 'he understands it', nq: 'he does not understand it' },
  { p: 'a number is divisible by 9', np: 'a number is not divisible by 9', q: 'it is divisible by 3', nq: 'it is not divisible by 3' },
  { p: 'the tap is open', np: 'the tap is not open', q: 'water flows', nq: 'water does not flow' },
  { p: 'Yemi joins the club', np: 'Yemi does not join the club', q: 'she pays the dues', nq: 'she does not pay the dues' },
  { p: 'the roof leaks', np: 'the roof does not leak', q: 'the room floods', nq: 'the room does not flood' },
  { p: 'a quadrilateral is a rhombus', np: 'a quadrilateral is not a rhombus', q: 'its diagonals bisect at right angles', nq: 'its diagonals do not bisect at right angles' },
  { p: 'the bus is full', np: 'the bus is not full', q: 'the driver departs', nq: 'the driver does not depart' },
  { p: 'Zainab wakes early', np: 'Zainab does not wake early', q: 'she catches the first bus', nq: 'she does not catch the first bus' },
  { p: 'the harvest is poor', np: 'the harvest is not poor', q: 'food prices rise', nq: 'food prices do not rise' },
  { p: 'a metal is heated', np: 'a metal is not heated', q: 'it expands', nq: 'it does not expand' },
  { p: 'the candidate scores above 50', np: 'the candidate does not score above 50', q: 'he is admitted', nq: 'he is not admitted' },
];

const QUANTIFIERS = [
  { s: 'All students are hardworking', neg: 'Some students are not hardworking', w: ['No student is hardworking', 'All students are not hardworking', 'Some students are hardworking'] },
  { s: 'All birds can fly', neg: 'Some birds cannot fly', w: ['No bird can fly', 'All birds cannot fly', 'Some birds can fly'] },
  { s: 'Some men are teachers', neg: 'No man is a teacher', w: ['All men are teachers', 'Some men are not teachers', 'All men are not teachers'] },
  { s: 'Every triangle has three sides', neg: 'Some triangles do not have three sides', w: ['No triangle has three sides', 'All triangles have four sides', 'Some triangles have three sides'] },
  { s: 'All prime numbers are odd', neg: 'Some prime numbers are not odd', w: ['No prime number is odd', 'All prime numbers are even', 'Some prime numbers are odd'] },
  { s: 'Some girls play football', neg: 'No girl plays football', w: ['All girls play football', 'Some girls do not play football', 'All girls do not play football'] },
  { s: 'All mangoes are sweet', neg: 'Some mangoes are not sweet', w: ['No mango is sweet', 'All mangoes are sour', 'Some mangoes are sweet'] },
  { s: 'Every student passed the test', neg: 'Some students did not pass the test', w: ['No student passed the test', 'All students failed the test', 'Some students passed the test'] },
  { s: 'All squares are rectangles', neg: 'Some squares are not rectangles', w: ['No square is a rectangle', 'All rectangles are squares', 'Some squares are rectangles'] },
  { s: 'Some traders are wealthy', neg: 'No trader is wealthy', w: ['All traders are wealthy', 'Some traders are not wealthy', 'All traders are poor'] },
  { s: 'All roads lead to the market', neg: 'Some roads do not lead to the market', w: ['No road leads to the market', 'All roads lead away from the market', 'Some roads lead to the market'] },
  { s: 'Every even number is divisible by 2', neg: 'Some even numbers are not divisible by 2', w: ['No even number is divisible by 2', 'All odd numbers are divisible by 2', 'Some even numbers are divisible by 2'] },
];

const cap = (s) => s.charAt(0).toUpperCase() + s.slice(1);

const logical = [
  // converse
  () => {
    const x = pick(PAIRS);
    const stmt = `If ${x.p}, then ${x.q}.`;
    const correct = `If ${x.q}, then ${x.p}.`;
    const o = textOptions(cap(correct), [cap(`If ${x.np}, then ${x.nq}.`), cap(`If ${x.nq}, then ${x.np}.`), cap(`If ${x.p}, then ${x.nq}.`)]);
    if (!o) return null;
    return {
      text: `What is the converse of the statement: "${cap(stmt)}"?`,
      ...o,
      explanation: `The converse of "If \\(p\\), then \\(q\\)" is "If \\(q\\), then \\(p\\)" — the two parts are interchanged.\n\nHere \\(p\\) is "${x.p}" and \\(q\\) is "${x.q}".\n\nSo the converse is "${cap(correct)}"`,
    };
  },
  // inverse
  () => {
    const x = pick(PAIRS);
    const stmt = `If ${x.p}, then ${x.q}.`;
    const correct = `If ${x.np}, then ${x.nq}.`;
    const o = textOptions(cap(correct), [cap(`If ${x.q}, then ${x.p}.`), cap(`If ${x.nq}, then ${x.np}.`), cap(`If ${x.p}, then ${x.nq}.`)]);
    if (!o) return null;
    return {
      text: `What is the inverse of the statement: "${cap(stmt)}"?`,
      ...o,
      explanation: `The inverse of "If \\(p\\), then \\(q\\)" is "If not \\(p\\), then not \\(q\\)" — both parts are negated but not interchanged.\n\nSo the inverse is "${cap(correct)}"`,
    };
  },
  // contrapositive
  () => {
    const x = pick(PAIRS);
    const stmt = `If ${x.p}, then ${x.q}.`;
    const correct = `If ${x.nq}, then ${x.np}.`;
    const o = textOptions(cap(correct), [cap(`If ${x.q}, then ${x.p}.`), cap(`If ${x.np}, then ${x.nq}.`), cap(`If ${x.nq}, then ${x.p}.`)]);
    if (!o) return null;
    return {
      text: `What is the contrapositive of the statement: "${cap(stmt)}"?`,
      ...o,
      explanation: `The contrapositive of "If \\(p\\), then \\(q\\)" is "If not \\(q\\), then not \\(p\\)" — the parts are both negated and interchanged.\n\nSo the contrapositive is "${cap(correct)}"`,
    };
  },
  // logically equivalent
  () => {
    const x = pick(PAIRS);
    const stmt = `If ${x.p}, then ${x.q}.`;
    const correct = `If ${x.nq}, then ${x.np}.`;
    const o = textOptions(cap(correct), [cap(`If ${x.q}, then ${x.p}.`), cap(`If ${x.np}, then ${x.nq}.`), cap(`If ${x.p}, then ${x.nq}.`)]);
    if (!o) return null;
    return {
      text: `Which of the following is logically equivalent to: "${cap(stmt)}"?`,
      ...o,
      explanation: `A conditional statement is logically equivalent to its contrapositive, "If not \\(q\\), then not \\(p\\)".\n\nThe converse and the inverse are not equivalent to the original statement.\n\nSo the answer is "${cap(correct)}"`,
    };
  },
  // truth value of an implication
  () => {
    const x = pick(PAIRS);
    const pT = Math.random() < 0.5, qT = Math.random() < 0.5;
    // p -> q is false only when p is true and q is false
    const isTrue = !(pT && !qT);
    const o = textOptions(isTrue ? 'True' : 'False', ['Cannot be determined', 'Neither true nor false', isTrue ? 'False' : 'True']);
    if (!o) return null;
    return {
      text: `Given that the statement "${x.p}" is ${pT ? 'true' : 'false'} and the statement "${x.q}" is ${qT ? 'true' : 'false'}, what is the truth value of "If ${x.p}, then ${x.q}"?`,
      ...o,
      explanation: `An implication \\(p \\Rightarrow q\\) is false only when \\(p\\) is true and \\(q\\) is false. In every other case it is true.\n\nHere \\(p\\) is ${pT ? 'true' : 'false'} and \\(q\\) is ${qT ? 'true' : 'false'}, so the implication is ${isTrue ? 'true' : 'false'}.`,
    };
  },
  // negation of a quantified statement
  () => {
    const x = pick(QUANTIFIERS);
    const o = textOptions(x.neg, x.w);
    if (!o) return null;
    return {
      text: `What is the negation of the statement: "${x.s}"?`,
      ...o,
      explanation: `The negation of "all \\(A\\) are \\(B\\)" is "some \\(A\\) are not \\(B\\)", and the negation of "some \\(A\\) are \\(B\\)" is "no \\(A\\) is \\(B\\)".\n\nSo the negation of "${x.s}" is "${x.neg}".`,
    };
  },
  // when is the implication false
  () => {
    const x = pick(PAIRS);
    const correct = `${cap(x.p)} and ${x.nq}`;
    const o = textOptions(correct, [`${cap(x.np)} and ${x.q}`, `${cap(x.np)} and ${x.nq}`, `${cap(x.p)} and ${x.q}`]);
    if (!o) return null;
    return {
      text: `Under which condition is the statement "If ${x.p}, then ${x.q}" false?`,
      ...o,
      explanation: `An implication \\(p \\Rightarrow q\\) is false only when the antecedent \\(p\\) is true while the consequent \\(q\\) is false.\n\nSo the statement is false when ${x.p} and ${x.nq}.`,
    };
  },
  // negation of an implication
  () => {
    const x = pick(PAIRS);
    const correct = `${cap(x.p)} and ${x.nq}.`;
    const o = textOptions(correct, [`If ${x.nq}, then ${x.np}.`, `If ${x.np}, then ${x.nq}.`, `${cap(x.np)} and ${x.q}.`]);
    if (!o) return null;
    return {
      text: `What is the negation of the statement: "If ${x.p}, then ${x.q}"?`,
      ...o,
      explanation: `The negation of \\(p \\Rightarrow q\\) is \\(p \\wedge \\neg q\\): the statement fails exactly when \\(p\\) holds but \\(q\\) does not.\n\nSo the negation is "${correct}"`,
    };
  },
];

module.exports = [
  { topicId: '4Dw7zmuSwhrRQrjoXw4m', unitId: UNIT, topicName: 'Sets', generators: sets },
  { topicId: '4D5iDhokUTc9XTA0OujX', unitId: UNIT, topicName: 'Rational Numbers', generators: rationals },
  { topicId: 'QuvoUbS5KYYV03OHSks4', unitId: UNIT, topicName: 'Ratio Proportions Rates', generators: ratios },
  { topicId: '36UySpvFGm6ZX3SMmSyd', unitId: UNIT, topicName: 'Matrices and Determinants', generators: matrices },
  { topicId: 'C3guPtpBw8L9PbJHGzkx', unitId: UNIT, topicName: 'Modular Arithmetic', generators: modular },
  { topicId: 'YGzoaH6XCy701WdJHE5I', unitId: UNIT, topicName: 'Surds', generators: surds },
  { topicId: 'SBr2G6BCw8KMJf9MtEIA', unitId: UNIT, topicName: 'Logical Reasoning', generators: logical },
];
