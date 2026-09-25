require("dotenv").config();
const fs = require("fs");
const path = require("path");
const Groq = require("groq-sdk");

const SUBJECT = 'physics';
const FILE = path.join(__dirname, "data", `classified_${SUBJECT}.json`);
const PROGRESS_FILE = path.join(__dirname, "data", `fix_progress_${SUBJECT}.json`);
const groq = new Groq({ apiKey: process.env.GROQ_API_KEY });

// Topics to re-classify — all confirmed mostly or entirely wrong
const SUSPECT_TOPICS = [
  "Fundamental and Derived Quantities",
];

const TOPIC_MAP = {
  "Pure Mathematics": [
    "Sets and Venn Diagrams",
    "Surds",
    "Binary Operations",
    "Logical Reasoning",
    "Functions",
    "Polynomial Functions",
    "Rational Functions and Partial Fractions",
    "Indices and Logarithms",
    "Permutations and Combinations",
    "Binomial Theorem",
    "Sequences and Series",
    "Matrices and Linear Transformation",
    "Trigonometry",
    "Coordinate Geometry",
    "Differentiation",
    "Integration",
  ],
  "Statistics and Probability": [
    "Statistics",
    "Probability",
  ],
  "Vectors and Mechanics": [
    "Vectors",
    "Statics",
    "Dynamics and Projectiles",
  ],
};

const FLAT_TOPICS = [];
let idx = 0;
for (const [unit, topics] of Object.entries(TOPIC_MAP)) {
  for (const topic of topics) {
    FLAT_TOPICS.push({ index: idx++, unit, topic });
  }
}

const TOPIC_LIST_TEXT = FLAT_TOPICS.map(t => `${t.index}: ${t.unit} > ${t.topic}`).join("\n");

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

function parseResponse(text) {
  const cleaned = text.replace(/```json|```/g, "").trim();
  try { return JSON.parse(cleaned); } catch (_) {}
  const match = cleaned.match(/\[[\d,\s]+\]/);
  if (match) return JSON.parse(match[0]);
  const nums = cleaned.match(/\d+/g);
  if (nums && nums.length > 0) return nums.map(Number);
  throw new Error("Could not parse: " + cleaned.slice(0, 200));
}

function buildPrompt(questions) {
  const qList = questions
    .map(({ q }, j) => `Q${j}: ${q.text.slice(0, 400)}`)
    .join("\n");

  return `You are classifying Nigerian WAEC Physics exam questions into the SINGLE best matching topic.

TOPIC LIST (index: Unit > Topic):
${TOPIC_LIST_TEXT}

- "Fundamental and Derived Quantities": ONLY for questions explicitly about SI units, base quantities (mass, length, time, current), or unit conversion. Questions about motion, forces, energy, waves, or any other physics concept are NOT this topic.

IMPORTANT:
- Choose the topic based on the MAIN physics concept being tested.
- Ignore distracting numbers, diagrams, or wording.
- Use the MOST SPECIFIC topic possible.
- Do NOT classify based on surface keywords alone.
- Every question must map to exactly ONE topic.

CLASSIFICATION RULES — read carefully:

MEASUREMENT AND UNITS
- "Fundamental and Derived Quantities":
  SI units, dimensions of quantities, base quantities, derived quantities.
- "Dimensions and Dimensional Analysis":
  dimensional equations, checking formula consistency, deriving units.
- "Scalars and Vectors":
  vector addition/subtraction, resultant vectors, vector components, scalar vs vector quantities.

MOTION
- "Distance, Displacement and Position":
  path length, position, displacement, coordinate motion.
- "Speed and Velocity":
  average speed, instantaneous speed, velocity-time interpretation.
- "Acceleration and Equations of Motion":
  SUVAT equations, uniformly accelerated motion, free fall.
- "Projectile Motion":
  objects projected at angles, horizontal range, time of flight.
- "Circular Motion":
  centripetal force, angular speed, satellites moving in circles.
- "Simple Harmonic Motion":
  oscillation, pendulums, springs, periodic motion.
- "Relative Motion":
  motion observed from moving frames, boats, trains, relative velocity.

FORCES AND EQUILIBRIUM
- "Newton's Laws of Motion":
  F = ma, inertia, momentum change, action-reaction.
- "Friction":
  frictional force, limiting friction, lubrication.
- "Equilibrium of Forces and Moments":
  balancing forces, torque, moments, lever systems.
- "Centre of Gravity and Stability":
  stability, toppling, center of mass/gravity.
- "Elastic Properties and Hooke's Law":
  springs, elastic deformation, stress, strain.

GRAVITATION
- "Newton's Law of Gravitation":
  gravitational attraction between masses.
- "Gravitational Field and Potential":
  field strength, escape velocity, potential energy.
- "Satellites and Rockets":
  orbital motion, rocket propulsion, artificial satellites.

WORK, ENERGY AND POWER
- "Work and Energy":
  work done by forces, transfer of energy.
- "Kinetic and Potential Energy":
  KE = 1/2mv², GPE, elastic potential energy.
- "Power and Machines":
  power, efficiency, machine advantage.
- "Conservation of Energy":
  energy transformations and conservation principles.

FLUIDS
- "Density and Relative Density":
  density calculations, floating/sinking comparisons.
- "Pressure in Fluids":
  pressure, hydraulic systems, atmospheric pressure.
- "Archimedes' Principle and Flotation":
  upthrust, buoyancy, floating bodies.
- "Viscosity":
  fluid resistance and flow behavior.

HEAT AND THERMODYNAMICS
- "Temperature and Thermometers":
  temperature scales, thermometer calibration.
- "Thermal Expansion":
  expansion of solids, liquids, gases due to heat.
- "Gas Laws":
  Boyle's law, Charles's law, pressure-volume relationships.
- "Heat Capacity and Specific Heat Capacity":
  heating calculations involving mcΔθ.
- "Latent Heat":
  melting, boiling, phase changes without temperature change.
- "Evaporation, Boiling and Vapour Pressure":
  evaporation factors, vapour pressure concepts.
- "Heat Transfer":
  conduction, convection, radiation.
- "Thermal Conductivity":
  good/bad conductors of heat, insulation.

WAVES
- "Wave Motion and Properties":
  wavelength, frequency, amplitude, wave speed.
- "Types of Waves":
  transverse vs longitudinal waves.
- "Superposition and Standing Waves":
  interference, stationary waves, harmonics.
- "Sound Waves":
  sound properties, echo, Doppler effect.
- "Resonance and Vibration":
  forced vibration, resonance conditions.

OPTICS
- "Reflection of Light":
  mirrors, laws of reflection, images in mirrors.
- "Refraction of Light":
  refractive index, Snell's law, critical angle.
- "Lenses and Optical Instruments":
  convex/concave lenses, microscopes, telescopes.
- "Dispersion and Electromagnetic Spectrum":
  prisms, spectrum, EM wave properties.
- "Fibre Optics and Lasers":
  optical fibres, laser applications.

ELECTROSTATICS
- "Electric Charges and Fields":
  electric field lines, charging methods.
- "Coulomb's Law":
  electrostatic force between charges.
- "Electric Potential and Capacitance":
  capacitors, potential difference in electrostatics.

CURRENT ELECTRICITY
- "Electric Current and Circuits":
  circuit analysis, current flow, Kirchhoff-type ideas.
- "Ohm's Law and Resistance":
  V = IR, resistance calculations.
- "Resistivity and Conductivity":
  material properties affecting current flow.
- "Electric Energy and Power":
  electrical power, heating effect, energy consumption.
- "Cells and EMF":
  batteries, internal resistance, electromotive force.
- "Shunt and Multiplier":
  galvanometer conversion, ammeter/voltmeter extension.

MAGNETISM AND ELECTROMAGNETISM
- "Magnetic Fields and Properties":
  magnets, magnetic field patterns.
- "Electromagnetic Induction":
  generators, induced EMF, Faraday's law.
- "AC Circuits":
  alternating current behavior and calculations.
- "Power Transmission":
  transformers and national grid transmission.
- "Semiconductors and Diodes":
  p-n junctions, rectifiers, transistor basics.

ATOMIC AND NUCLEAR PHYSICS
- "Models of the Atom":
  atomic structure and atomic models.
- "Photoelectric Effect and Thermionic Emission":
  electron emission due to light or heat.
- "X-rays":
  production and properties of X-rays.
- "Radioactivity":
  alpha, beta, gamma decay, half-life.
- "Nuclear Reactions":
  fission, fusion, nuclear equations.
- "Wave-Particle Duality":
  de Broglie wavelength, dual nature of matter/light.

QUESTIONS TO CLASSIFY:
${qList}

Return ONLY a JSON array of integers.
One topic index per question, in order.
No explanation.
No markdown.
No extra text.`;
}

async function main() {
  if (!process.env.GROQ_API_KEY) {
    console.error("ERROR: GROQ_API_KEY not set in .env");
    process.exit(1);
  }

  const data = JSON.parse(fs.readFileSync(FILE, "utf8"));

  // Find all questions from suspect topics with their original indices
  const targets = data
    .map((q, i) => ({ q, i }))
    .filter(({ q }) => SUSPECT_TOPICS.includes(q.topicName));

  console.log(`Found ${targets.length} questions to re-classify across ${SUSPECT_TOPICS.length} suspect topics`);

  // Resume support
  let startBatch = 0;
  const fixes = {}; // originalIndex -> {unitName, topicName}

  if (fs.existsSync(PROGRESS_FILE)) {
    const prog = JSON.parse(fs.readFileSync(PROGRESS_FILE, "utf8"));
    startBatch = prog.startBatch;
    Object.assign(fixes, prog.fixes);
    console.log(`Resuming from batch ${startBatch} (${Object.keys(fixes).length} already fixed)`);
  }

  const BATCH = 5;
  const totalBatches = Math.ceil(targets.length / BATCH);

  for (let b = startBatch; b < totalBatches; b++) {
    const batch = targets.slice(b * BATCH, (b + 1) * BATCH);

    process.stdout.write(`Batch ${b + 1}/${totalBatches}... `);

    try {
      const prompt = buildPrompt(batch);
      const completion = await groq.chat.completions.create({
        model: "llama-3.1-8b-instant",
        messages: [{ role: "user", content: prompt }],
        temperature: 0,
      });
      let indices = parseResponse(completion.choices[0].message.content);
      indices = indices.slice(0, batch.length);
      while (indices.length < batch.length) indices.push(0);

      for (let j = 0; j < batch.length; j++) {
        const topicEntry = FLAT_TOPICS[indices[j]] || FLAT_TOPICS[0];
        fixes[batch[j].i] = { unitName: topicEntry.unit, topicName: topicEntry.topic };
      }

      console.log(`done`);
    } catch (err) {
      console.error(`ERROR: ${err.message}`);
      console.log("Saving progress. Re-run to resume.");
      fs.writeFileSync(PROGRESS_FILE, JSON.stringify({ startBatch: b, fixes }, null, 2));
      process.exit(1);
    }

    fs.writeFileSync(PROGRESS_FILE, JSON.stringify({ startBatch: b + 1, fixes }, null, 2));

    if (b + 1 < totalBatches) await sleep(2500);
  }

  // Apply all fixes
  let changed = 0;
  for (const [idxStr, { unitName, topicName }] of Object.entries(fixes)) {
    const i = Number(idxStr);
    if (data[i].topicName !== topicName) changed++;
    data[i].unitName = unitName;
    data[i].topicName = topicName;
  }

  fs.writeFileSync(FILE, JSON.stringify(data, null, 2));
  console.log(`\nApplied ${changed} topic changes. classified.json updated.`);

  if (fs.existsSync(PROGRESS_FILE)) fs.unlinkSync(PROGRESS_FILE);

  // Print new distribution
  console.log("\n=== Updated distribution ===");
  const topics = {};
  data.forEach(q => {
    const key = q.unitName + " > " + q.topicName;
    topics[key] = (topics[key] || 0) + 1;
  });
  Object.entries(topics).sort((a, b) => b[1] - a[1])
    .forEach(([k, v]) => console.log(v, k));
}

main();