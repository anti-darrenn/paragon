/// Physical constants, SI units and unit conversion.
///
/// **Sources.**
/// * Constants: CODATA 2018 recommended values, NIST, "Fundamental Physical
///   Constants — Complete Listing, 2018 CODATA adjustment"
///   (https://physics.nist.gov/cuu/Constants/ArchiveASCII/allascii_2018.txt).
///   Constants marked exact are exact by the 2019 SI definitions (SI
///   Brochure, 9th edition, BIPM 2019): c, h, e, k_B, N_A, and those derived
///   from them alone (R, F, σ, the molar volume, the electronvolt). g_n and
///   the standard atmosphere are exact by convention (3rd CGPM 1901; 10th
///   CGPM 1954). Since 2019, ε₀ and μ₀ are *measured*, not exact.
/// * SI base units, derived units and prefixes: SI Brochure, 9th edition
///   (2019); ronna, quetta, ronto and quecto added by the 27th CGPM (2022).
/// * Conversion factors: NIST Special Publication 811 (2008), Appendix B —
///   the inch (0.0254 m), pound (0.453 592 37 kg), thermochemical calorie
///   (4.184 J) and conventional millimetre of mercury (13.5951 g/cm³ × 1 mm
///   × g_n) are exact by definition; composite factors are computed below
///   from those rather than written out.
library;

import 'dart:math' as math;

class PhysicalConstant {
  const PhysicalConstant({
    required this.name,
    required this.symbol,
    required this.mantissa,
    required this.exponent,
    required this.unit,
    this.exact = false,
    this.truncated = false,
    this.uncertainty,
    this.note,
  });

  final String name;

  /// LaTeX, e.g. `k_{\mathrm{B}}`.
  final String symbol;

  /// The value's significand as published, digits only, e.g. "6.62607015".
  final String mantissa;
  final int exponent;

  /// LaTeX unit, e.g. `\mathrm{J\,s}`.
  final String unit;

  /// Exact by definition.
  final bool exact;

  /// Exact but with an unending decimal expansion; shown cut short.
  final bool truncated;

  /// CODATA standard uncertainty in the last digits, e.g. "(15)".
  final String? uncertainty;
  final String? note;

  double get value => double.parse('${mantissa}e$exponent');

  /// The value as LaTeX, digits grouped in threes after the point.
  String get valueLatex {
    final parts = mantissa.split('.');
    final frac = parts.length > 1 ? parts[1] : '';
    final grouped = StringBuffer(_groupInt(parts[0]));
    if (frac.isNotEmpty) {
      grouped.write('.');
      for (var i = 0; i < frac.length; i += 3) {
        if (i > 0) grouped.write(r'\,');
        grouped.write(frac.substring(i, math.min(i + 3, frac.length)));
      }
    }
    if (truncated) grouped.write(r'\ldots');
    if (uncertainty != null) grouped.write(uncertainty);
    final power = exponent == 0
        ? ''
        : r' \times 10^{'
              '$exponent'
              '}';
    return '$grouped$power';
  }

  /// The whole line as FullLatexView source.
  String get latex => '\\($symbol = $valueLatex\\ $unit\\)';
}

String _groupInt(String s) {
  if (s.length <= 4) return s;
  final out = StringBuffer();
  final lead = s.length % 3;
  if (lead > 0) out.write(s.substring(0, lead));
  for (var i = lead; i < s.length; i += 3) {
    if (out.isNotEmpty) out.write(r'\,');
    out.write(s.substring(i, i + 3));
  }
  return out.toString();
}

/// CODATA 2018. Value strings copied from the NIST listing cited above.
const List<PhysicalConstant> kPhysicalConstants = [
  PhysicalConstant(
    name: 'Standard acceleration of gravity',
    symbol: r'g_{\mathrm{n}}',
    mantissa: '9.80665',
    exponent: 0,
    unit: r'\mathrm{m\,s^{-2}}',
    exact: true,
    note:
        'Exact by convention. WAEC questions often use g = 10 m s⁻² or '
        '9.8 m s⁻²; use the value the question gives.',
  ),
  PhysicalConstant(
    name: 'Speed of light in vacuum',
    symbol: 'c',
    mantissa: '299792458',
    exponent: 0,
    unit: r'\mathrm{m\,s^{-1}}',
    exact: true,
  ),
  PhysicalConstant(
    name: 'Planck constant',
    symbol: 'h',
    mantissa: '6.62607015',
    exponent: -34,
    unit: r'\mathrm{J\,s}',
    exact: true,
  ),
  PhysicalConstant(
    name: 'Elementary charge',
    symbol: 'e',
    mantissa: '1.602176634',
    exponent: -19,
    unit: r'\mathrm{C}',
    exact: true,
  ),
  PhysicalConstant(
    name: 'Avogadro constant',
    symbol: r'N_{\mathrm{A}}',
    mantissa: '6.02214076',
    exponent: 23,
    unit: r'\mathrm{mol^{-1}}',
    exact: true,
  ),
  PhysicalConstant(
    name: 'Boltzmann constant',
    symbol: r'k_{\mathrm{B}}',
    mantissa: '1.380649',
    exponent: -23,
    unit: r'\mathrm{J\,K^{-1}}',
    exact: true,
  ),
  PhysicalConstant(
    name: 'Molar gas constant',
    symbol: 'R',
    mantissa: '8.314462618',
    exponent: 0,
    unit: r'\mathrm{J\,mol^{-1}\,K^{-1}}',
    exact: true,
    truncated: true,
    note: 'R = N_A k_B.',
  ),
  PhysicalConstant(
    name: 'Faraday constant',
    symbol: 'F',
    mantissa: '96485.33212',
    exponent: 0,
    unit: r'\mathrm{C\,mol^{-1}}',
    exact: true,
    truncated: true,
    note: 'F = N_A e.',
  ),
  PhysicalConstant(
    name: 'Molar volume of an ideal gas at s.t.p. (273.15 K, 101.325 kPa)',
    symbol: r'V_{\mathrm{m}}',
    mantissa: '22.41396954',
    exponent: 0,
    unit: r'\mathrm{dm^{3}\,mol^{-1}}',
    exact: true,
    truncated: true,
    note: 'CODATA lists 22.413 969 54… × 10⁻³ m³ mol⁻¹; 10⁻³ m³ = 1 dm³.',
  ),
  PhysicalConstant(
    name: 'Newtonian constant of gravitation',
    symbol: 'G',
    mantissa: '6.67430',
    exponent: -11,
    unit: r'\mathrm{m^{3}\,kg^{-1}\,s^{-2}}',
    uncertainty: '(15)',
  ),
  PhysicalConstant(
    name: 'Vacuum electric permittivity',
    symbol: r'\varepsilon_0',
    mantissa: '8.8541878128',
    exponent: -12,
    unit: r'\mathrm{F\,m^{-1}}',
    uncertainty: '(13)',
    note: 'Measured since the 2019 SI; no longer exact.',
  ),
  PhysicalConstant(
    name: 'Vacuum magnetic permeability',
    symbol: r'\mu_0',
    mantissa: '1.25663706212',
    exponent: -6,
    unit: r'\mathrm{N\,A^{-2}}',
    uncertainty: '(19)',
    note: 'Measured since the 2019 SI; 4π × 10⁻⁷ is now an approximation.',
  ),
  PhysicalConstant(
    name: 'Electron mass',
    symbol: r'm_{\mathrm{e}}',
    mantissa: '9.1093837015',
    exponent: -31,
    unit: r'\mathrm{kg}',
    uncertainty: '(28)',
  ),
  PhysicalConstant(
    name: 'Proton mass',
    symbol: r'm_{\mathrm{p}}',
    mantissa: '1.67262192369',
    exponent: -27,
    unit: r'\mathrm{kg}',
    uncertainty: '(51)',
  ),
  PhysicalConstant(
    name: 'Neutron mass',
    symbol: r'm_{\mathrm{n}}',
    mantissa: '1.67492749804',
    exponent: -27,
    unit: r'\mathrm{kg}',
    uncertainty: '(95)',
  ),
  PhysicalConstant(
    name: 'Atomic mass constant (unified atomic mass unit)',
    symbol: r'm_{\mathrm{u}} = 1\,\mathrm{u}',
    mantissa: '1.66053906660',
    exponent: -27,
    unit: r'\mathrm{kg}',
    uncertainty: '(50)',
  ),
  PhysicalConstant(
    name: 'Electronvolt',
    symbol: r'1\,\mathrm{eV}',
    mantissa: '1.602176634',
    exponent: -19,
    unit: r'\mathrm{J}',
    exact: true,
  ),
  PhysicalConstant(
    name: 'Stefan–Boltzmann constant',
    symbol: r'\sigma',
    mantissa: '5.670374419',
    exponent: -8,
    unit: r'\mathrm{W\,m^{-2}\,K^{-4}}',
    exact: true,
    truncated: true,
  ),
  PhysicalConstant(
    name: 'Wien wavelength displacement constant',
    symbol: 'b',
    mantissa: '2.897771955',
    exponent: -3,
    unit: r'\mathrm{m\,K}',
    exact: true,
    truncated: true,
  ),
  PhysicalConstant(
    name: 'Rydberg constant',
    symbol: r'R_\infty',
    mantissa: '10973731.568160',
    exponent: 0,
    unit: r'\mathrm{m^{-1}}',
    uncertainty: '(21)',
  ),
  PhysicalConstant(
    name: 'Standard atmosphere',
    symbol: r'1\,\mathrm{atm}',
    mantissa: '101325',
    exponent: 0,
    unit: r'\mathrm{Pa}',
    exact: true,
  ),
];

PhysicalConstant constantNamed(String name) =>
    kPhysicalConstants.firstWhere((c) => c.name == name);

/// Coulomb's constant 1/(4πε₀), computed from CODATA 2018 ε₀.
double get coulombConstant =>
    1 / (4 * math.pi * constantNamed('Vacuum electric permittivity').value);

/// [coulombConstant] to 5 significant figures, as FullLatexView source.
String get coulombConstantLatex {
  final k = coulombConstant.toStringAsExponential(4).split('e');
  return '\\(k = \\dfrac{1}{4\\pi\\varepsilon_0} = ${k[0]} \\times '
      '10^{${int.parse(k[1])}}\\ \\mathrm{N\\,m^{2}\\,C^{-2}}\\)';
}

// ── SI units ─────────────────────────────────────────────────────────────

class SiUnit {
  const SiUnit(this.quantity, this.name, this.symbol, this.definition);
  final String quantity;
  final String name;
  final String symbol;

  /// For a base unit, the defining constant; for a derived unit, its
  /// expression in other units (LaTeX).
  final String definition;
}

/// SI Brochure (9th ed.), Table 2.
const List<SiUnit> kSiBaseUnits = [
  SiUnit('time', 'second', 's', r'\Delta\nu_{\mathrm{Cs}}'),
  SiUnit('length', 'metre', 'm', 'c'),
  SiUnit('mass', 'kilogram', 'kg', 'h'),
  SiUnit('electric current', 'ampere', 'A', 'e'),
  SiUnit('thermodynamic temperature', 'kelvin', 'K', r'k_{\mathrm{B}}'),
  SiUnit('amount of substance', 'mole', 'mol', r'N_{\mathrm{A}}'),
  SiUnit('luminous intensity', 'candela', 'cd', r'K_{\mathrm{cd}}'),
];

/// SI Brochure (9th ed.), Table 4: the 22 derived units with special names.
const List<SiUnit> kSiDerivedUnits = [
  SiUnit('plane angle', 'radian', 'rad', r'\mathrm{m/m}'),
  SiUnit('solid angle', 'steradian', 'sr', r'\mathrm{m^{2}/m^{2}}'),
  SiUnit('frequency', 'hertz', 'Hz', r'\mathrm{s^{-1}}'),
  SiUnit('force', 'newton', 'N', r'\mathrm{kg\,m\,s^{-2}}'),
  SiUnit('pressure, stress', 'pascal', 'Pa', r'\mathrm{N/m^{2}}'),
  SiUnit('energy, work, heat', 'joule', 'J', r'\mathrm{N\,m}'),
  SiUnit('power', 'watt', 'W', r'\mathrm{J/s}'),
  SiUnit('electric charge', 'coulomb', 'C', r'\mathrm{A\,s}'),
  SiUnit('potential difference', 'volt', 'V', r'\mathrm{W/A}'),
  SiUnit('capacitance', 'farad', 'F', r'\mathrm{C/V}'),
  SiUnit('electric resistance', 'ohm', 'Ω', r'\mathrm{V/A}'),
  SiUnit('electric conductance', 'siemens', 'S', r'\mathrm{A/V}'),
  SiUnit('magnetic flux', 'weber', 'Wb', r'\mathrm{V\,s}'),
  SiUnit('magnetic flux density', 'tesla', 'T', r'\mathrm{Wb/m^{2}}'),
  SiUnit('inductance', 'henry', 'H', r'\mathrm{Wb/A}'),
  SiUnit('Celsius temperature', 'degree Celsius', '°C', r'\mathrm{K}'),
  SiUnit('luminous flux', 'lumen', 'lm', r'\mathrm{cd\,sr}'),
  SiUnit('illuminance', 'lux', 'lx', r'\mathrm{lm/m^{2}}'),
  SiUnit('activity', 'becquerel', 'Bq', r'\mathrm{s^{-1}}'),
  SiUnit('absorbed dose', 'gray', 'Gy', r'\mathrm{J/kg}'),
  SiUnit('dose equivalent', 'sievert', 'Sv', r'\mathrm{J/kg}'),
  SiUnit('catalytic activity', 'katal', 'kat', r'\mathrm{mol\,s^{-1}}'),
];

class SiPrefix {
  const SiPrefix(this.name, this.symbol, this.power);
  final String name;
  final String symbol;
  final int power;
}

/// SI Brochure (9th ed.), Table 7, with the 2022 additions.
const List<SiPrefix> kSiPrefixes = [
  SiPrefix('quetta', 'Q', 30),
  SiPrefix('ronna', 'R', 27),
  SiPrefix('yotta', 'Y', 24),
  SiPrefix('zetta', 'Z', 21),
  SiPrefix('exa', 'E', 18),
  SiPrefix('peta', 'P', 15),
  SiPrefix('tera', 'T', 12),
  SiPrefix('giga', 'G', 9),
  SiPrefix('mega', 'M', 6),
  SiPrefix('kilo', 'k', 3),
  SiPrefix('hecto', 'h', 2),
  SiPrefix('deca', 'da', 1),
  SiPrefix('deci', 'd', -1),
  SiPrefix('centi', 'c', -2),
  SiPrefix('milli', 'm', -3),
  SiPrefix('micro', 'μ', -6),
  SiPrefix('nano', 'n', -9),
  SiPrefix('pico', 'p', -12),
  SiPrefix('femto', 'f', -15),
  SiPrefix('atto', 'a', -18),
  SiPrefix('zepto', 'z', -21),
  SiPrefix('yocto', 'y', -24),
  SiPrefix('ronto', 'r', -27),
  SiPrefix('quecto', 'q', -30),
];

// ── Unit converter ──────────────────────────────────────────────────────

/// A unit as an affine map to the category's SI unit:
/// `si = value × factor + offset`. Only temperature has an offset.
class ConvUnit {
  const ConvUnit(this.name, this.symbol, this.factor, [this.offset = 0]);
  final String name;
  final String symbol;
  final double factor;
  final double offset;

  double toSi(double v) => v * factor + offset;
  double fromSi(double si) => (si - offset) / factor;
}

class UnitCategory {
  const UnitCategory(this.name, this.units);
  final String name;
  final List<ConvUnit> units;

  ConvUnit unit(String symbol) => units.firstWhere((u) => u.symbol == symbol);
}

// Exact definitions (NIST SP 811, Appendix B).
const double _inch = 0.0254;
const double _foot = 0.3048;
const double _yard = 0.9144;
const double _mile = 1609.344;
const double _nauticalMile = 1852;
const double _pound = 0.45359237;
const double _calorieTh = 4.184;
const double _mercuryDensity = 13595.1; // kg/m³, conventional
const double _gn = 9.80665;
const double _atm = 101325;
const double _eV = 1.602176634e-19;

double convert(double value, ConvUnit from, ConvUnit to) =>
    to.fromSi(from.toSi(value));

final List<UnitCategory> kUnitCategories = [
  const UnitCategory('Length', [
    ConvUnit('metre', 'm', 1),
    ConvUnit('kilometre', 'km', 1e3),
    ConvUnit('centimetre', 'cm', 1e-2),
    ConvUnit('millimetre', 'mm', 1e-3),
    ConvUnit('micrometre', 'μm', 1e-6),
    ConvUnit('nanometre', 'nm', 1e-9),
    ConvUnit('ångström', 'Å', 1e-10),
    ConvUnit('inch', 'in', _inch),
    ConvUnit('foot', 'ft', _foot),
    ConvUnit('yard', 'yd', _yard),
    ConvUnit('mile', 'mi', _mile),
    ConvUnit('nautical mile', 'nmi', _nauticalMile),
  ]),
  const UnitCategory('Mass', [
    ConvUnit('kilogram', 'kg', 1),
    ConvUnit('gram', 'g', 1e-3),
    ConvUnit('milligram', 'mg', 1e-6),
    ConvUnit('tonne', 't', 1e3),
    ConvUnit('pound', 'lb', _pound),
    ConvUnit('ounce', 'oz', _pound / 16),
    ConvUnit('unified atomic mass unit', 'u', 1.66053906660e-27),
  ]),
  const UnitCategory('Time', [
    ConvUnit('second', 's', 1),
    ConvUnit('millisecond', 'ms', 1e-3),
    ConvUnit('minute', 'min', 60),
    ConvUnit('hour', 'h', 3600),
    ConvUnit('day', 'd', 86400),
    ConvUnit('week', 'wk', 604800),
    ConvUnit('year (365.25 d)', 'yr', 365.25 * 86400),
  ]),
  const UnitCategory('Area', [
    ConvUnit('square metre', 'm²', 1),
    ConvUnit('square kilometre', 'km²', 1e6),
    ConvUnit('square centimetre', 'cm²', 1e-4),
    ConvUnit('square millimetre', 'mm²', 1e-6),
    ConvUnit('hectare', 'ha', 1e4),
    ConvUnit('square foot', 'ft²', _foot * _foot),
    ConvUnit('acre (43 560 ft²)', 'acre', 43560 * _foot * _foot),
  ]),
  const UnitCategory('Volume', [
    ConvUnit('cubic metre', 'm³', 1),
    ConvUnit('cubic decimetre', 'dm³', 1e-3),
    ConvUnit('litre', 'L', 1e-3),
    ConvUnit('millilitre', 'mL', 1e-6),
    ConvUnit('cubic centimetre', 'cm³', 1e-6),
    ConvUnit('UK gallon', 'gal (UK)', 4.54609e-3),
  ]),
  const UnitCategory('Speed', [
    ConvUnit('metre per second', 'm/s', 1),
    ConvUnit('kilometre per hour', 'km/h', 1000 / 3600),
    ConvUnit('centimetre per second', 'cm/s', 1e-2),
    ConvUnit('mile per hour', 'mph', _mile / 3600),
    ConvUnit('knot', 'kn', _nauticalMile / 3600),
  ]),
  const UnitCategory('Energy', [
    ConvUnit('joule', 'J', 1),
    ConvUnit('kilojoule', 'kJ', 1e3),
    ConvUnit('calorie (thermochemical)', 'cal', _calorieTh),
    ConvUnit('kilocalorie', 'kcal', _calorieTh * 1000),
    ConvUnit('electronvolt', 'eV', _eV),
    ConvUnit('kilowatt-hour', 'kWh', 3.6e6),
    ConvUnit('erg', 'erg', 1e-7),
  ]),
  const UnitCategory('Pressure', [
    ConvUnit('pascal', 'Pa', 1),
    ConvUnit('kilopascal', 'kPa', 1e3),
    ConvUnit('standard atmosphere', 'atm', _atm),
    ConvUnit('millimetre of mercury', 'mmHg', _mercuryDensity * _gn * 1e-3),
    ConvUnit('torr', 'Torr', _atm / 760),
    ConvUnit('bar', 'bar', 1e5),
    ConvUnit('newton per square metre', 'N/m²', 1),
  ]),
  const UnitCategory('Temperature', [
    ConvUnit('kelvin', 'K', 1),
    ConvUnit('degree Celsius', '°C', 1, 273.15),
    // °F → K: (F − 32) × 5/9 + 273.15 = F × 5/9 + 255.372…
    ConvUnit('degree Fahrenheit', '°F', 5 / 9, 273.15 - 32 * 5 / 9),
  ]),
];

UnitCategory unitCategory(String name) =>
    kUnitCategories.firstWhere((c) => c.name == name);

/// A converted value for display: up to 6 significant figures, plain for
/// moderate magnitudes and in scientific notation otherwise, with no
/// trailing zeros.
String formatConverted(double v) {
  if (v.isNaN || v.isInfinite) return '—';
  if (v == 0) return '0';
  final a = v.abs();
  if (a >= 1e-4 && a < 1e9) {
    var s = v.toStringAsPrecision(6);
    if (s.contains('e')) return s;
    if (s.contains('.')) {
      s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }
    return s;
  }
  final e = v.toStringAsExponential(5);
  final parts = e.split('e');
  var m = parts[0];
  if (m.contains('.')) {
    m = m.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  final exp = int.parse(parts[1]);
  return '$m × 10${_superscript(exp)}';
}

String _superscript(int n) {
  const digits = '⁰¹²³⁴⁵⁶⁷⁸⁹';
  final s = n.abs().toString().split('').map((d) => digits[int.parse(d)]);
  return '${n < 0 ? '⁻' : ''}${s.join()}';
}
