// Physics > Waves, Optics
const L = require('./lib');
const { randInt, pick, shuffle, sample, nonZero, frac, fracTex, fracOpt,
        fmtNum, buildOptions, textOptions, round } = L;
const { conceptGens, qaBank } = require('./concept');

const U_WAVES = 'DaLMAx9HzLfppVRlivVr';
const U_OPTICS = '95c1KPMRTwjz5AfA8SdD';

// ===================== WAVE MOTION AND PROPERTIES =====================
const waveMotion = [
  // v = f lambda
  () => {
    const f = randInt(2, 500), lam = pick([0.2, 0.5, 1, 2, 2.5, 4, 5, 10]);
    const v = f * lam;
    const o = buildOptions(round(v, 2), [round(f / lam, 2), round(lam / f, 4), round(v * 2, 2)], (x) => `${fmtNum(x, 2)}m/s`);
    if (!o) return null;
    return {
      text: `A wave of frequency ${f}Hz has a wavelength of ${lam}m. Calculate its speed.`,
      ...o,
      explanation: `\\(v = f\\lambda\\)\n\n\\(= ${f} \\times ${lam} = ${fmtNum(v, 2)}\\)m/s`,
    };
  },
  // find wavelength
  () => {
    const f = randInt(2, 400), lam = pick([0.5, 1, 2, 4, 5]);
    const v = f * lam;
    const o = buildOptions(lam, [round(v * f, 2), round(f / v, 4), round(lam * 2, 2)], (x) => `${fmtNum(x, 3)}m`);
    if (!o) return null;
    return {
      text: `A wave travels at ${fmtNum(v, 2)}m/s with a frequency of ${f}Hz. Calculate its wavelength.`,
      ...o,
      explanation: `\\(\\lambda = \\frac{v}{f}\\)\n\n\\(= \\frac{${fmtNum(v, 2)}}{${f}} = ${lam}\\)m`,
    };
  },
  // period and frequency
  () => {
    const f = pick([2, 4, 5, 8, 10, 20, 25, 50, 100]);
    const T = 1 / f;
    const o = buildOptions(T, [f, round(f / 2, 3), round(T * 2, 4)], (x) => `${fmtNum(x, 4)}s`);
    if (!o) return null;
    return {
      text: `A wave has a frequency of ${f}Hz. Calculate its period.`,
      ...o,
      explanation: `\\(T = \\frac{1}{f}\\)\n\n\\(= \\frac{1}{${f}} = ${fmtNum(T, 4)}\\)s`,
    };
  },
  // frequency from period
  () => {
    const T = pick([0.01, 0.02, 0.04, 0.05, 0.1, 0.2, 0.25, 0.5]);
    const f = 1 / T;
    const o = buildOptions(f, [T, round(T * 2, 3), round(f * 2, 2)], (x) => `${fmtNum(x, 2)}Hz`);
    if (!o) return null;
    return {
      text: `A wave has a period of ${T}s. Calculate its frequency.`,
      ...o,
      explanation: `\\(f = \\frac{1}{T}\\)\n\n\\(= \\frac{1}{${T}} = ${fmtNum(f, 2)}\\)Hz`,
    };
  },
  ...conceptGens('wave motion', [
    'A wave transfers energy from one point to another without transferring matter',
    'The wavelength is the distance between two successive points in phase',
    'The frequency of a wave is the number of complete waves passing a point per second',
    'The amplitude is the maximum displacement from the equilibrium position',
    'The period is the time taken for one complete oscillation',
    'Wave speed is the product of frequency and wavelength',
    'The frequency of a wave does not change when it passes from one medium to another',
  ], [
    'A wave transfers matter from one point to another',
    'Wavelength is the time for one complete oscillation',
    'The amplitude of a wave equals its wavelength',
    'Wave speed is the ratio of frequency to wavelength',
    'The frequency of a wave changes when it moves into a new medium',
    'The period is the number of waves passing a point per second',
  ]),
];

// ============================ TYPES OF WAVES ============================
const TRANSVERSE = ['light waves', 'radio waves', 'water waves', 'X-rays', 'waves on a stretched string'];
const LONGITUDINAL = ['sound waves in air', 'ultrasonic waves in water', 'compression waves in a spring'];
const EM = ['light', 'radio waves', 'X-rays', 'gamma rays', 'microwaves', 'infrared radiation', 'ultraviolet radiation'];
const MECHANICAL = ['sound waves', 'water waves', 'waves on a rope', 'seismic waves'];

const typesOfWaves = [
  // transverse identification
  () => {
    const t = pick(TRANSVERSE);
    const w = sample(LONGITUDINAL, 3);
    if (w.length < 3) return null;
    const cap = (s) => s.charAt(0).toUpperCase() + s.slice(1);
    const o = textOptions(cap(t), w.map(cap));
    if (!o) return null;
    return {
      text: `Which of the following is a transverse wave?`,
      ...o,
      explanation: `In a transverse wave the vibrations are perpendicular to the direction of travel.\n\n${cap(t)} is transverse. The other options are longitudinal waves, in which the vibrations are parallel to the direction of travel.`,
    };
  },
  // longitudinal identification
  () => {
    const t = pick(LONGITUDINAL);
    const w = sample(TRANSVERSE, 3);
    const cap = (s) => s.charAt(0).toUpperCase() + s.slice(1);
    const o = textOptions(cap(t), w.map(cap));
    if (!o) return null;
    return {
      text: `Which of the following is a longitudinal wave?`,
      ...o,
      explanation: `In a longitudinal wave the vibrations are parallel to the direction of travel, producing compressions and rarefactions.\n\n${cap(t)} is longitudinal, while the others listed are transverse waves.`,
    };
  },
  // electromagnetic identification
  () => {
    const t = pick(EM);
    const w = sample(MECHANICAL, 3);
    const cap = (s) => s.charAt(0).toUpperCase() + s.slice(1);
    const o = textOptions(cap(t), w.map(cap));
    if (!o) return null;
    return {
      text: `Which of the following is an electromagnetic wave?`,
      ...o,
      explanation: `Electromagnetic waves can travel through a vacuum and do not need a material medium.\n\n${cap(t)} is electromagnetic. The others are mechanical waves and require a medium.`,
    };
  },
  // mechanical identification
  () => {
    const t = pick(MECHANICAL);
    const w = sample(EM, 3);
    const cap = (s) => s.charAt(0).toUpperCase() + s.slice(1);
    const o = textOptions(cap(t), w.map(cap));
    if (!o) return null;
    return {
      text: `Which of the following is a mechanical wave?`,
      ...o,
      explanation: `Mechanical waves require a material medium to travel through.\n\n${cap(t)} is mechanical. The others are electromagnetic waves, which can travel through a vacuum.`,
    };
  },
  ...conceptGens('types of waves', [
    'Transverse waves have vibrations perpendicular to the direction of propagation',
    'Longitudinal waves have vibrations parallel to the direction of propagation',
    'Electromagnetic waves can travel through a vacuum',
    'Mechanical waves require a material medium',
    'Sound waves are longitudinal waves',
    'Light waves are transverse waves',
    'All electromagnetic waves travel at the same speed in a vacuum',
    'Longitudinal waves consist of compressions and rarefactions',
  ], [
    'Sound waves are transverse waves',
    'Light waves are longitudinal waves',
    'Electromagnetic waves require a material medium to travel',
    'Sound can travel through a vacuum',
    'Transverse waves consist of compressions and rarefactions',
    'All electromagnetic waves travel at different speeds in a vacuum',
  ]),
];

// ============================== SOUND WAVES ==============================
const soundWaves = [
  // echo
  () => {
    const v = 340, t = pick([0.5, 1, 1.5, 2, 2.5, 3, 4]);
    const d = v * t / 2;
    const o = buildOptions(d, [v * t, round(v / t, 2), d * 2], (x) => `${fmtNum(x, 2)}m`);
    if (!o) return null;
    return {
      text: `A man claps his hands and hears the echo after ${t}s. If the speed of sound in air is ${v}m/s, how far away is the reflecting wall?`,
      ...o,
      explanation: `The sound travels to the wall and back, a total distance of \\(2d\\).\n\n\\(2d = vt = ${v} \\times ${t} = ${v * t}\\)m\n\n\\(d = \\frac{${v * t}}{2} = ${d}\\)m`,
    };
  },
  // speed of sound from echo distance
  () => {
    const d = randInt(100, 900), v = 340;
    const t = 2 * d / v;
    const o = buildOptions(round(t, 2), [round(d / v, 2), round(v / d, 3), round(t * 2, 2)], (x) => `${fmtNum(x, 2)}s`);
    if (!o) return null;
    return {
      text: `A wall is ${d}m away from a man who claps his hands. How long after the clap does he hear the echo? [Speed of sound = ${v}m/s]`,
      ...o,
      explanation: `Total distance travelled by the sound \\(= 2 \\times ${d} = ${2 * d}\\)m\n\n\\(t = \\frac{${2 * d}}{${v}} = ${fmtNum(t, 2)}\\)s`,
    };
  },
  // v = f lambda for sound
  () => {
    const f = randInt(100, 2000), v = 340;
    const lam = v / f;
    const o = buildOptions(round(lam, 4), [round(f / v, 4), round(f * v, 2), round(lam * 2, 4)], (x) => `${fmtNum(x, 4)}m`);
    if (!o) return null;
    return {
      text: `Calculate the wavelength of a sound wave of frequency ${f}Hz travelling at ${v}m/s.`,
      ...o,
      explanation: `\\(\\lambda = \\frac{v}{f} = \\frac{${v}}{${f}} = ${fmtNum(lam, 4)}\\)m`,
    };
  },
  ...conceptGens('sound waves', [
    'Sound is a longitudinal wave',
    'Sound requires a material medium to travel and cannot travel through a vacuum',
    'The pitch of a note depends on its frequency',
    'The loudness of a sound depends on its amplitude',
    'Sound travels faster in solids than in gases',
    'The quality or timbre of a note distinguishes two notes of the same pitch and loudness',
    'An echo is produced by the reflection of sound',
    'The audible range for a normal human ear is about 20Hz to 20 000Hz',
  ], [
    'Sound is a transverse wave',
    'Sound can travel through a vacuum',
    'The pitch of a note depends on its amplitude',
    'The loudness of a sound depends on its frequency',
    'Sound travels faster in gases than in solids',
    'Sound travels faster than light',
    'The human audible range is about 2Hz to 200Hz',
  ]),
];

// ================= SUPERPOSITION AND STANDING WAVES =================
const superposition = [
  // beat frequency
  () => {
    const f1 = randInt(200, 500), diff = randInt(2, 15);
    const f2 = f1 + diff;
    const o = buildOptions(diff, [f1 + f2, round((f1 + f2) / 2, 2), diff * 2], (v) => `${fmtNum(v, 2)}Hz`);
    if (!o) return null;
    return {
      text: `Two tuning forks of frequencies ${f1}Hz and ${f2}Hz are sounded together. Calculate the beat frequency.`,
      ...o,
      explanation: `Beat frequency is the difference between the two frequencies.\n\n\\(= ${f2} - ${f1} = ${diff}\\)Hz`,
    };
  },
  // fundamental frequency of a closed pipe
  () => {
    const Lp = pick([0.1, 0.2, 0.25, 0.5, 0.85]);
    const v = 340;
    const f = v / (4 * Lp);
    const o = buildOptions(round(f, 2), [round(v / (2 * Lp), 2), round(v / Lp, 2), round(f * 2, 2)], (x) => `${fmtNum(x, 2)}Hz`);
    if (!o) return null;
    return {
      text: `Calculate the fundamental frequency of a closed pipe of length ${Lp}m. [Speed of sound = ${v}m/s]`,
      ...o,
      explanation: `For a closed pipe the fundamental wavelength is \\(\\lambda = 4L\\).\n\n\\(\\lambda = 4 \\times ${Lp} = ${4 * Lp}\\)m\n\n\\(f = \\frac{v}{\\lambda} = \\frac{${v}}{${4 * Lp}} = ${fmtNum(f, 2)}\\)Hz`,
    };
  },
  // fundamental frequency of an open pipe
  () => {
    const Lp = pick([0.1, 0.2, 0.25, 0.5, 0.85]);
    const v = 340;
    const f = v / (2 * Lp);
    const o = buildOptions(round(f, 2), [round(v / (4 * Lp), 2), round(v / Lp, 2), round(f * 2, 2)], (x) => `${fmtNum(x, 2)}Hz`);
    if (!o) return null;
    return {
      text: `Calculate the fundamental frequency of an open pipe of length ${Lp}m. [Speed of sound = ${v}m/s]`,
      ...o,
      explanation: `For an open pipe the fundamental wavelength is \\(\\lambda = 2L\\).\n\n\\(\\lambda = 2 \\times ${Lp} = ${2 * Lp}\\)m\n\n\\(f = \\frac{v}{\\lambda} = \\frac{${v}}{${2 * Lp}} = ${fmtNum(f, 2)}\\)Hz`,
    };
  },
  ...conceptGens('superposition and standing waves', [
    'A standing wave is formed by the superposition of two identical waves travelling in opposite directions',
    'Nodes are points of zero displacement in a standing wave',
    'Antinodes are points of maximum displacement in a standing wave',
    'The distance between two consecutive nodes is half a wavelength',
    'Beats are produced when two notes of slightly different frequencies are sounded together',
    'Beat frequency equals the difference between the two frequencies',
    'A closed pipe produces only odd harmonics',
    'Constructive interference occurs when two waves arrive in phase',
  ], [
    'Nodes are points of maximum displacement in a standing wave',
    'Antinodes are points of zero displacement',
    'The distance between consecutive nodes equals one full wavelength',
    'Beat frequency equals the sum of the two frequencies',
    'A standing wave transfers energy along its length',
    'Destructive interference occurs when two waves arrive in phase',
    'An open pipe produces only even harmonics',
  ]),
];

// ======================= RESONANCE AND VIBRATION =======================
const resonance = [
  // resonance tube first position
  () => {
    const f = pick([256, 288, 320, 341, 384, 426, 512]);
    const v = 340;
    const Lp = v / (4 * f);
    const o = buildOptions(round(Lp, 4), [round(v / (2 * f), 4), round(v / f, 4), round(Lp * 2, 4)], (x) => `${fmtNum(x, 4)}m`);
    if (!o) return null;
    return {
      text: `A tuning fork of frequency ${f}Hz produces resonance in a closed tube at its shortest length. Calculate this length. [Speed of sound = ${v}m/s, neglect end correction]`,
      ...o,
      explanation: `At the first resonance position in a closed tube, \\(L = \\frac{\\lambda}{4}\\).\n\n\\(\\lambda = \\frac{v}{f} = \\frac{${v}}{${f}} = ${fmtNum(v / f, 4)}\\)m\n\n\\(L = \\frac{${fmtNum(v / f, 4)}}{4} = ${fmtNum(Lp, 4)}\\)m`,
    };
  },
  ...conceptGens('resonance', [
    'Resonance occurs when the frequency of the applied force equals the natural frequency of the body',
    'At resonance the amplitude of vibration is a maximum',
    'A resonance tube can be used to determine the speed of sound in air',
    'Soldiers break step when crossing a bridge to avoid resonance',
    'Every body has a natural frequency of vibration',
    'Resonance is a special case of forced vibration',
  ], [
    'Resonance occurs when the driving frequency is much greater than the natural frequency',
    'At resonance the amplitude of vibration is a minimum',
    'Resonance only occurs in solids',
    'A body has no natural frequency of vibration',
    'Resonance has no practical applications',
    'Resonance occurs only when the driving frequency is zero',
  ], [
    { q: 'Why are soldiers advised to break step when marching across a bridge?', a: 'To avoid setting up resonance in the bridge', w: ['To reduce the total weight on the bridge', 'To move across the bridge faster', 'To reduce friction with the bridge surface'], e: 'If the marching frequency matches the bridge\'s natural frequency, resonance builds a large amplitude of vibration that could damage the structure.' },
    { q: 'A glass shatters when a singer sustains a particular note. What phenomenon is responsible?', a: 'Resonance', w: ['Refraction', 'Diffraction', 'Polarisation'], e: 'When the note matches the natural frequency of the glass, resonance produces vibrations of large amplitude, which can exceed the strength of the glass.' },
  ]),
];

// =========================== REFLECTION OF LIGHT ===========================
const reflection = [
  // angle of reflection
  () => {
    const i = randInt(5, 85);
    const o = buildOptions(i, [90 - i, 2 * i, 180 - i], (v) => `${v}°`);
    if (!o) return null;
    return {
      text: `A ray of light strikes a plane mirror at an angle of incidence of ${i}°. What is the angle of reflection?`,
      ...o,
      explanation: `By the laws of reflection, the angle of incidence equals the angle of reflection.\n\nSo the angle of reflection is ${i}°.`,
    };
  },
  // number of images in two inclined mirrors
  () => {
    const ang = pick([30, 36, 40, 45, 60, 72, 90, 120]);
    const n = 360 / ang - 1;
    if (!Number.isInteger(n)) return null;
    const o = buildOptions(n, [360 / ang, n + 2, round(ang / 360, 3)], (v) => String(v));
    if (!o) return null;
    return {
      text: `Two plane mirrors are inclined at an angle of ${ang}° to each other. How many images of an object placed between them are formed?`,
      ...o,
      explanation: `Number of images \\(= \\frac{360°}{\\theta} - 1\\)\n\n\\(= \\frac{360}{${ang}} - 1 = ${360 / ang} - 1 = ${n}\\)`,
    };
  },
  // rotation of a mirror rotates the ray by twice the angle
  () => {
    const ang = randInt(5, 45);
    const correct = 2 * ang;
    const o = buildOptions(correct, [ang, round(ang / 2, 2), 90 - ang], (v) => `${v}°`);
    if (!o) return null;
    return {
      text: `A plane mirror is rotated through ${ang}° while the incident ray remains fixed. Through what angle does the reflected ray rotate?`,
      ...o,
      explanation: `When a plane mirror rotates through an angle \\(\\theta\\), the reflected ray rotates through \\(2\\theta\\).\n\n\\(2 \\times ${ang}° = ${correct}°\\)`,
    };
  },
  // concave mirror focal length
  () => {
    const r = 2 * randInt(2, 30);
    const f = r / 2;
    const o = buildOptions(f, [r, r * 2, round(r / 4, 2)], (v) => `${fmtNum(v, 2)}cm`);
    if (!o) return null;
    return {
      text: `A concave mirror has a radius of curvature of ${r}cm. Calculate its focal length.`,
      ...o,
      explanation: `\\(f = \\frac{r}{2}\\)\n\n\\(= \\frac{${r}}{2} = ${f}\\)cm`,
    };
  },
  // mirror formula
  () => {
    const f = pick([10, 12, 15, 20]);
    const u = f * pick([2, 3, 4]);
    const v = 1 / (1 / f - 1 / u);
    const o = buildOptions(round(v, 2), [round(u - f, 2), round(u + f, 2), round(v * 2, 2)], (x) => `${fmtNum(x, 2)}cm`);
    if (!o) return null;
    return {
      text: `An object is placed ${u}cm from a concave mirror of focal length ${f}cm. Calculate the image distance.`,
      ...o,
      explanation: `\\(\\frac{1}{f} = \\frac{1}{u} + \\frac{1}{v}\\)\n\n\\(\\frac{1}{v} = \\frac{1}{${f}} - \\frac{1}{${u}}\\)\n\n\\(v = ${fmtNum(v, 2)}\\)cm`,
    };
  },
  ...conceptGens('reflection of light at plane surfaces', [
    'The angle of incidence equals the angle of reflection',
    'The incident ray, the reflected ray and the normal all lie in the same plane',
    'The image formed by a plane mirror is virtual and laterally inverted',
    'The image in a plane mirror is the same size as the object',
    'The image in a plane mirror is as far behind the mirror as the object is in front',
    'A concave mirror can form both real and virtual images',
    'A convex mirror always forms a virtual, diminished and erect image',
  ], [
    'The angle of incidence is twice the angle of reflection',
    'The image formed by a plane mirror is real and inverted',
    'The image in a plane mirror is always magnified',
    'A convex mirror always forms a real image',
    'The image in a plane mirror is closer to the mirror than the object',
    'The incident ray and the reflected ray lie in different planes',
  ]),
];

// =========================== REFRACTION OF LIGHT ===========================
const refraction = [
  // Snell's law
  () => {
    const n = pick([1.33, 1.5, 1.6, 2.42]);
    const i = pick([30, 45, 60]);
    const sinr = Math.sin(i * Math.PI / 180) / n;
    const r = Math.asin(sinr) * 180 / Math.PI;
    const correct = round(r, 2);
    const o = buildOptions(correct, [i, round(i / n, 2), round(r * 2, 2)], (v) => `${fmtNum(v, 2)}°`);
    if (!o) return null;
    return {
      text: `A ray of light passes from air into a medium of refractive index ${n} at an angle of incidence of ${i}°. Calculate the angle of refraction, correct to 2 decimal places.`,
      ...o,
      explanation: `By Snell's law, \\(n = \\frac{\\sin i}{\\sin r}\\).\n\n\\(\\sin r = \\frac{\\sin ${i}°}{${n}} = ${round(sinr, 4)}\\)\n\n\\(r = ${fmtNum(correct, 2)}°\\)`,
    };
  },
  // refractive index from angles
  () => {
    const i = pick([30, 45, 60]);
    const n = pick([1.33, 1.5, 2]);
    const sinr = Math.sin(i * Math.PI / 180) / n;
    const r = round(Math.asin(sinr) * 180 / Math.PI, 1);
    const computed = Math.sin(i * Math.PI / 180) / Math.sin(r * Math.PI / 180);
    const o = buildOptions(round(computed, 2), [round(1 / computed, 2), round(i / r, 2), round(computed * 2, 2)], (v) => fmtNum(v, 2));
    if (!o) return null;
    return {
      text: `Light travelling from air into a transparent medium has an angle of incidence of ${i}° and an angle of refraction of ${r}°. Calculate the refractive index of the medium.`,
      ...o,
      explanation: `\\(n = \\frac{\\sin i}{\\sin r}\\)\n\n\\(= \\frac{\\sin ${i}°}{\\sin ${r}°} = ${fmtNum(round(computed, 2), 2)}\\)`,
    };
  },
  // critical angle
  () => {
    const n = pick([1.33, 1.5, 1.6, 2, 2.42]);
    const C = Math.asin(1 / n) * 180 / Math.PI;
    const correct = round(C, 2);
    const o = buildOptions(correct, [round(90 - C, 2), round(n * 30, 2), round(C * 2, 2)], (v) => `${fmtNum(v, 2)}°`);
    if (!o) return null;
    return {
      text: `Calculate the critical angle for a medium of refractive index ${n}, correct to 2 decimal places.`,
      ...o,
      explanation: `\\(\\sin C = \\frac{1}{n}\\)\n\n\\(\\sin C = \\frac{1}{${n}} = ${round(1 / n, 4)}\\)\n\n\\(C = ${fmtNum(correct, 2)}°\\)`,
    };
  },
  // real and apparent depth
  () => {
    const n = pick([1.33, 1.5, 1.6]);
    const real = randInt(4, 40);
    const app = real / n;
    const o = buildOptions(round(app, 2), [round(real * n, 2), real, round(app * 2, 2)], (v) => `${fmtNum(v, 2)}cm`);
    if (!o) return null;
    return {
      text: `A tank contains a liquid of refractive index ${n} to a depth of ${real}cm. Calculate the apparent depth, correct to 2 decimal places.`,
      ...o,
      explanation: `\\(n = \\frac{\\text{real depth}}{\\text{apparent depth}}\\)\n\n\\(\\text{apparent depth} = \\frac{${real}}{${n}} = ${fmtNum(app, 2)}\\)cm`,
    };
  },
  // speed of light in a medium
  () => {
    const n = pick([1.33, 1.5, 2, 2.42]);
    const c = 3e8;
    const v = c / n;
    const o = buildOptions(round(v, 0), [round(c * n, 0), c, round(v / 2, 0)], (x) => `${Number(x).toExponential(2)} m/s`);
    if (!o) return null;
    return {
      text: `Calculate the speed of light in a medium of refractive index ${n}. [Speed of light in vacuum = \\(3 \\times 10^{8}\\)m/s]`,
      ...o,
      explanation: `\\(n = \\frac{c}{v}\\)\n\n\\(v = \\frac{c}{n} = \\frac{3 \\times 10^{8}}{${n}} = ${v.toExponential(2)}\\) m/s`,
    };
  },
  ...conceptGens('refraction of light', [
    'Refraction is the bending of light as it passes from one medium to another',
    'Refraction occurs because light travels at different speeds in different media',
    'A ray travelling from a less dense to a denser medium bends towards the normal',
    'A ray travelling from a denser to a less dense medium bends away from the normal',
    'Total internal reflection occurs when the angle of incidence exceeds the critical angle',
    'Total internal reflection can only occur when light travels from a denser to a less dense medium',
    'The frequency of light does not change during refraction',
    'Refractive index has no unit',
  ], [
    'Refraction occurs because light changes frequency between media',
    'A ray entering a denser medium bends away from the normal',
    'Total internal reflection occurs when light passes from a less dense to a denser medium',
    'Refractive index is measured in metres',
    'The speed of light is the same in all media',
    'Light does not bend when it enters a new medium at an angle',
  ]),
];

// ================= LENSES AND OPTICAL INSTRUMENTS =================
const lenses = [
  // lens formula
  () => {
    const f = pick([10, 12, 15, 20, 25]);
    const u = f * pick([2, 3, 4, 5]);
    const v = 1 / (1 / f - 1 / u);
    const o = buildOptions(round(v, 2), [round(u - f, 2), round(u + f, 2), round(v * 2, 2)], (x) => `${fmtNum(x, 2)}cm`);
    if (!o) return null;
    return {
      text: `An object is placed ${u}cm from a converging lens of focal length ${f}cm. Calculate the image distance.`,
      ...o,
      explanation: `\\(\\frac{1}{f} = \\frac{1}{u} + \\frac{1}{v}\\)\n\n\\(\\frac{1}{v} = \\frac{1}{${f}} - \\frac{1}{${u}} = ${round(1 / f - 1 / u, 5)}\\)\n\n\\(v = ${fmtNum(v, 2)}\\)cm`,
    };
  },
  // magnification
  () => {
    const u = randInt(10, 60), m = pick([0.5, 2, 3, 4]);
    const v = m * u;
    const o = buildOptions(m, [round(u / v, 3), round(u * v, 2), round(m * 2, 2)], (x) => fmtNum(x, 2));
    if (!o) return null;
    return {
      text: `An object is placed ${u}cm from a lens and its image is formed ${v}cm from the lens. Calculate the magnification.`,
      ...o,
      explanation: `\\(m = \\frac{v}{u}\\)\n\n\\(= \\frac{${v}}{${u}} = ${m}\\)`,
    };
  },
  // power of a lens
  () => {
    const fcm = pick([10, 20, 25, 50, 100, -20, -25]);
    const P = 100 / fcm;
    const o = buildOptions(round(P, 2), [round(fcm / 100, 3), fcm, round(P * 2, 2)], (x) => `${fmtNum(x, 2)}D`);
    if (!o) return null;
    return {
      text: `Calculate the power of a lens of focal length ${fcm}cm.`,
      ...o,
      explanation: `Power \\(= \\frac{1}{f}\\) with \\(f\\) in metres.\n\n\\(f = ${fcm}\\)cm \\(= ${fcm / 100}\\)m\n\n\\(P = \\frac{1}{${fcm / 100}} = ${fmtNum(P, 2)}\\)D`,
    };
  },
  // image height
  () => {
    const ho = randInt(2, 20), m = pick([2, 3, 0.5, 4]);
    const hi = ho * m;
    const o = buildOptions(hi, [round(ho / m, 2), ho, round(hi * 2, 2)], (x) => `${fmtNum(x, 2)}cm`);
    if (!o) return null;
    return {
      text: `An object of height ${ho}cm is placed in front of a lens which produces a magnification of ${m}. Calculate the height of the image.`,
      ...o,
      explanation: `\\(m = \\frac{h_i}{h_o}\\)\n\n\\(h_i = m \\times h_o = ${m} \\times ${ho} = ${hi}\\)cm`,
    };
  },
  ...conceptGens('lenses and optical instruments', [
    'A converging lens is thicker at the centre than at the edges',
    'A diverging lens always forms a virtual, erect and diminished image',
    'The power of a lens is the reciprocal of its focal length in metres',
    'The unit of the power of a lens is the dioptre',
    'A converging lens can form both real and virtual images',
    'A short-sighted person is corrected using a diverging lens',
    'A long-sighted person is corrected using a converging lens',
    'The image formed on the retina of the human eye is real and inverted',
  ], [
    'A converging lens is thinner at the centre than at the edges',
    'A diverging lens always forms a real image',
    'The power of a lens is measured in metres',
    'A short-sighted person is corrected using a converging lens',
    'The image formed on the retina is virtual and erect',
    'A converging lens can only form virtual images',
  ]),
];

// ========= DISPERSION AND ELECTROMAGNETIC SPECTRUM =========
const dispersion = [
  ...conceptGens('dispersion and the electromagnetic spectrum', [
    'Dispersion is the splitting of white light into its component colours',
    'Red light has the longest wavelength in the visible spectrum',
    'Violet light has the shortest wavelength in the visible spectrum',
    'Violet light is deviated most when white light passes through a prism',
    'Red light is deviated least when white light passes through a prism',
    'All electromagnetic waves travel at the same speed in a vacuum',
    'Gamma rays have the shortest wavelength in the electromagnetic spectrum',
    'Radio waves have the longest wavelength in the electromagnetic spectrum',
    'Ultraviolet radiation has a shorter wavelength than visible light',
    'Infrared radiation has a longer wavelength than visible light',
  ], [
    'Red light is deviated most by a prism',
    'Violet light has the longest wavelength in the visible spectrum',
    'Radio waves have the shortest wavelength in the electromagnetic spectrum',
    'Gamma rays have the longest wavelength of all electromagnetic waves',
    'Electromagnetic waves travel at different speeds in a vacuum',
    'Infrared radiation has a shorter wavelength than ultraviolet radiation',
    'Dispersion occurs because all colours travel at the same speed in glass',
  ], [
    { q: 'Which colour of light is deviated most when white light passes through a triangular prism?', a: 'Violet', w: ['Red', 'Green', 'Yellow'], e: 'Violet has the shortest wavelength and the largest refractive index in glass, so it is refracted and deviated the most.' },
    { q: 'Which electromagnetic wave has the longest wavelength?', a: 'Radio waves', w: ['Gamma rays', 'X-rays', 'Ultraviolet radiation'], e: 'The electromagnetic spectrum in order of increasing wavelength runs: gamma rays, X-rays, ultraviolet, visible, infrared, microwaves, radio waves.' },
    { q: 'Which electromagnetic radiation is used in the remote control of a television set?', a: 'Infrared radiation', w: ['Gamma rays', 'X-rays', 'Ultraviolet radiation'], e: 'Television remote controls transmit coded pulses of infrared radiation to the receiver.' },
    { q: 'What is the correct order of colours in the visible spectrum from the longest to the shortest wavelength?', a: 'Red, orange, yellow, green, blue, indigo, violet', w: ['Violet, indigo, blue, green, yellow, orange, red', 'Red, yellow, orange, green, blue, violet, indigo', 'Blue, green, red, yellow, orange, violet, indigo'], e: 'Red has the longest wavelength and violet the shortest, giving the familiar sequence red, orange, yellow, green, blue, indigo, violet.' },
    { q: 'Which radiation is used to detect forged bank notes?', a: 'Ultraviolet radiation', w: ['Infrared radiation', 'Radio waves', 'Microwaves'], e: 'Security marks on genuine notes fluoresce when illuminated with ultraviolet light.' },
  ]),
];

// ====================== FIBRE OPTICS AND LASERS ======================
const fibreOptics = [
  // critical angle in a fibre
  () => {
    const n = pick([1.4, 1.5, 1.6]);
    const C = Math.asin(1 / n) * 180 / Math.PI;
    const correct = round(C, 2);
    const o = buildOptions(correct, [round(90 - C, 2), round(C * 2, 2), round(n * 30, 2)], (v) => `${fmtNum(v, 2)}°`);
    if (!o) return null;
    return {
      text: `An optical fibre core has a refractive index of ${n}. Calculate the critical angle at the core-air boundary, correct to 2 decimal places.`,
      ...o,
      explanation: `\\(\\sin C = \\frac{1}{n} = \\frac{1}{${n}} = ${round(1 / n, 4)}\\)\n\n\\(C = ${fmtNum(correct, 2)}°\\)\n\nLight striking the boundary at an angle greater than this is totally internally reflected and stays in the fibre.`,
    };
  },
  ...conceptGens('fibre optics and lasers', [
    'Optical fibres transmit light by total internal reflection',
    'For total internal reflection the angle of incidence must exceed the critical angle',
    'Optical fibres are used in telecommunications to carry information',
    'Optical fibres are used in endoscopes to view inside the human body',
    'Laser light is monochromatic, meaning it has a single wavelength',
    'Laser light is coherent, meaning the waves are in phase',
    'Laser beams are highly directional and spread out very little',
    'The core of an optical fibre has a higher refractive index than the cladding',
  ], [
    'Optical fibres transmit light by refraction out of the fibre walls',
    'Total internal reflection occurs at all angles of incidence',
    'Laser light contains all the colours of the visible spectrum',
    'Laser light is incoherent and spreads out rapidly',
    'The cladding of an optical fibre has a higher refractive index than the core',
    'Optical fibres can only be used over very short distances of a few centimetres',
  ], [
    { q: 'On which principle does the transmission of light through an optical fibre depend?', a: 'Total internal reflection', w: ['Dispersion', 'Diffraction', 'Polarisation'], e: 'Light entering the fibre strikes the core-cladding boundary at an angle greater than the critical angle and is totally internally reflected repeatedly along the fibre.' },
    { q: 'Which property of laser light makes it suitable for accurate distance measurement?', a: 'It is highly directional and coherent', w: ['It contains many wavelengths', 'It spreads out rapidly with distance', 'It has a very low intensity'], e: 'A coherent, highly directional beam stays narrow over long distances, so the time of flight of the reflected pulse gives an accurate distance.' },
  ]),
];

module.exports = [
  { topicId: 'Fh0pUKzieIW3cFCUSCRO', unitId: U_WAVES, topicName: 'Wave Motion and Properties', generators: waveMotion },
  { topicId: 'FrGVQjZnJTb1JIZYt2ls', unitId: U_WAVES, topicName: 'Sound Waves', generators: soundWaves },
  { topicId: 'JZnYU0ihg2OGvgkrbtvd', unitId: U_WAVES, topicName: 'Superposition and Standing Waves', generators: superposition },
  { topicId: 'se5tHpdNK4b5G8U31tFA', unitId: U_WAVES, topicName: 'Types of Waves', generators: typesOfWaves },
  { topicId: 'YjQx2e9J0nFWVdXROsMu', unitId: U_WAVES, topicName: 'Resonance and Vibration', generators: resonance },
  { topicId: '6QdxBXGAftpjlunpLtyN', unitId: U_OPTICS, topicName: 'Reflection of Light', generators: reflection },
  { topicId: '4zhK3IImPScXkGivIsea', unitId: U_OPTICS, topicName: 'Refraction of Light', generators: refraction },
  { topicId: 'cNc3U2zQYvQxez4H2MQU', unitId: U_OPTICS, topicName: 'Lenses and Optical Instruments', generators: lenses },
  { topicId: 'mzliD6rG5V4hVtti6YI9', unitId: U_OPTICS, topicName: 'Dispersion and Electromagnetic Spectrum', generators: dispersion },
  { topicId: 'Qbu88Spi8J24tW0hHkyq', unitId: U_OPTICS, topicName: 'Fibre Optics and Lasers', generators: fibreOptics },
];
