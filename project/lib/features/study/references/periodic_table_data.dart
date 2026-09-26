import 'dart:convert';

import 'package:flutter/services.dart';

/// The periodic table, loaded from `assets/data/periodic_table.json`.
///
/// Sources (also in the asset's `_source` field — keep the two in step):
/// * Standard atomic weights: IUPAC Commission on Isotopic Abundances and
///   Atomic Weights (CIAAW), *Abridged Standard Atomic Weights 2024*
///   (from "Atomic Weights 2021" with the 2024 Gd, Lu and Zr revisions),
///   https://www.ciaaw.org/abridged-atomic-weights.htm. Kept as the printed
///   strings, so trailing zeros survive (H is 1.0080, Te 127.60).
/// * Elements with no standard atomic weight: mass number of the most
///   stable known isotope from CIAAW "Radioactive elements" (NUBASE2020,
///   Kondev et al., Chinese Physics C 45 (2021) 030001).
/// * Electron configurations: NIST Atomic Spectra Database ground states
///   for Z 1–108; PubChem's predicted configurations for Z 109–118.
/// * Categories: PubChem Periodic Table.
/// * Group, period and block: computed from Z for the IUPAC 18-column
///   layout with 15-element lanthanide and actinide rows.
const String kPeriodicTableAsset = 'assets/data/periodic_table.json';

class ChemicalElement {
  const ChemicalElement({
    required this.z,
    required this.symbol,
    required this.name,
    required this.atomicWeight,
    required this.massNumber,
    required this.otherMassNumbers,
    required this.group,
    required this.period,
    required this.block,
    required this.series,
    required this.category,
    required this.electronConfiguration,
    required this.configurationPredicted,
  });

  final int z;
  final String symbol;
  final String name;

  /// The abridged standard atomic weight as printed (e.g. "1.0080"), or
  /// null for an element with no standard atomic weight.
  final String? atomicWeight;

  /// For an element with no standard atomic weight: the mass number of
  /// its most stable known isotope.
  final int? massNumber;

  /// Isotopes CIAAW lists as comparably long-lived to [massNumber].
  final List<int> otherMassNumbers;

  /// 1–18, or null for the lanthanides and actinides (La–Lu, Ac–Lr),
  /// which are drawn in their own rows.
  final int? group;
  final int period;
  final String block;

  /// 'lanthanide', 'actinide' or null.
  final String? series;
  final String category;

  /// Noble-gas shorthand, subshells separated by spaces: "[Ar] 3d6 4s2".
  final String electronConfiguration;

  /// True for Z ≥ 109, where the configuration is a prediction.
  final bool configurationPredicted;

  double? get atomicWeightValue =>
      atomicWeight == null ? null : double.parse(atomicWeight!);

  /// What the table cell shows: the weight, or [mass number] in brackets.
  String get weightLabel => atomicWeight ?? '[$massNumber]';

  factory ChemicalElement.fromJson(Map<String, dynamic> j) => ChemicalElement(
    z: j['z'] as int,
    symbol: j['symbol'] as String,
    name: j['name'] as String,
    atomicWeight: j['atomicWeight'] as String?,
    massNumber: j['massNumber'] as int?,
    otherMassNumbers: [
      for (final m in (j['otherMassNumbers'] as List? ?? const [])) m as int,
    ],
    group: j['group'] as int?,
    period: j['period'] as int,
    block: j['block'] as String,
    series: j['series'] as String?,
    category: j['category'] as String,
    electronConfiguration: j['electronConfiguration'] as String,
    configurationPredicted: j['configurationPredicted'] as bool? ?? false,
  );
}

/// Parses the asset's JSON text. Throws on malformed data: the file ships
/// with the app and is pinned by tests, so a failure here is a build bug,
/// not a runtime condition to paper over.
List<ChemicalElement> parsePeriodicTable(String json) {
  final doc = jsonDecode(json) as Map<String, dynamic>;
  return [
    for (final e in doc['elements'] as List)
      ChemicalElement.fromJson(e as Map<String, dynamic>),
  ];
}

Future<List<ChemicalElement>>? _cache;
List<ChemicalElement>? _loaded;

/// The table if it has already been loaded this session, so a second
/// opening draws at once instead of flashing a spinner.
List<ChemicalElement>? get loadedPeriodicTable => _loaded;

Future<List<ChemicalElement>> loadPeriodicTable([AssetBundle? bundle]) =>
    _cache ??= (bundle ?? rootBundle)
        .loadString(kPeriodicTableAsset)
        .then(parsePeriodicTable)
        .then((t) => _loaded = t)
        .catchError((Object e) {
          _cache = null; // let the next opening try again
          throw e;
        });

/// "[Ar] 3d6 4s2" → `\mathrm{[Ar]}\,3d^{6}\,4s^{2}`, for FullLatexView.
String configurationLatex(String config) {
  final parts = config.split(' ').map((p) {
    if (p.startsWith('[')) return '\\mathrm{$p}';
    final m = RegExp(r'^(\d)([spdf])(\d+)$').firstMatch(p);
    if (m == null) return p;
    return '${m[1]}${m[2]}^{${m[3]}}';
  });
  return parts.join('\\,');
}
