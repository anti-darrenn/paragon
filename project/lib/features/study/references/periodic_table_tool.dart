import 'package:flutter/material.dart';

import '../../../core/content/subject_tools.dart';
import '../../../core/study/study_tool.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/full_latex_view.dart';
import 'periodic_table_data.dart';

class PeriodicTableTool extends StudyTool {
  const PeriodicTableTool();

  @override
  StudyToolId get id => StudyToolId.periodicTable;
  @override
  String get label => 'Periodic table';
  @override
  IconData get icon => Icons.grid_view_outlined;
  @override
  StudyPanelMode get mode => StudyPanelMode.page;

  @override
  Widget build(BuildContext context, StudyScope scope, VoidCallback close) =>
      const PeriodicTableScreen();
}

/// Category colours. The subject palette is used because it is the only set
/// of ten mutually distinct muted colours in [AppColors]; the pairing
/// carries no meaning.
const Map<String, Color> kCategoryColors = {
  'alkali metal': AppColors.subjectMathematics,
  'alkaline earth metal': AppColors.subjectFurtherMathematics,
  'transition metal': AppColors.subjectEconomics,
  'post-transition metal': AppColors.subjectPhysics,
  'metalloid': AppColors.subjectChemistry,
  'nonmetal': AppColors.subjectBiology,
  'halogen': AppColors.subjectMusic,
  'noble gas': AppColors.subjectEnglishLanguage,
  'lanthanide': AppColors.subjectCommerce,
  'actinide': AppColors.subjectGovernment,
};

Color categoryColor(String category) =>
    kCategoryColors[category] ?? AppColors.textSecondaryDark;

String _capitalise(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

/// Does [e] match the search box? By symbol (exact or prefix) or name
/// (prefix or substring), ignoring case; a number matches Z.
bool elementMatches(ChemicalElement e, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  final z = int.tryParse(q);
  if (z != null) return e.z == z;
  return e.symbol.toLowerCase().startsWith(q) ||
      e.name.toLowerCase().contains(q);
}

class PeriodicTableScreen extends StatefulWidget {
  const PeriodicTableScreen({super.key});

  @override
  State<PeriodicTableScreen> createState() => _PeriodicTableScreenState();
}

class _PeriodicTableScreenState extends State<PeriodicTableScreen> {
  late final Future<List<ChemicalElement>> _load = loadPeriodicTable();
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ChemicalElement>>(
      future: _load,
      initialData: loadedPeriodicTable,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Text(
              'The periodic table could not be loaded.',
              style: AppTheme.bodyMd.copyWith(color: AppColors.wrong),
            ),
          );
        }
        final elements = snap.data;
        if (elements == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return _body(elements);
      },
    );
  }

  Widget _body(List<ChemicalElement> elements) {
    final q = _search.text;
    final matches = [
      for (final e in elements)
        if (elementMatches(e, q)) e,
    ];
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            style: AppTheme.bodyMd.copyWith(color: AppColors.textPrimaryDark),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search by name, symbol or atomic number',
              border: const OutlineInputBorder(),
              suffixIcon: q.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(_search.clear),
                    ),
            ),
          ),
        ),
        if (q.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: matches.isEmpty
                ? Text(
                    'No element matches “${q.trim()}”.',
                    style: AppTheme.caption.copyWith(
                      color: AppColors.textSecondaryDark,
                    ),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final e in matches.take(12))
                        ActionChip(
                          label: Text('${e.symbol} · ${e.name}'),
                          onPressed: () => showElementCard(context, e),
                        ),
                    ],
                  ),
          ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _PeriodicGrid(
            elements: elements,
            isMatch: (e) => elementMatches(e, q),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              for (final entry in kCategoryColors.entries)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: entry.value,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _capitalise(entry.key),
                      style: AppTheme.caption.copyWith(
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Relative atomic masses are the IUPAC abridged standard atomic '
            'weights (CIAAW, 2024). A number in square brackets, such as '
            '[226], means the element has no standard atomic weight: it is '
            'the mass number of its most stable known isotope. Tap an '
            'element for details.',
            style: AppTheme.caption.copyWith(
              color: AppColors.textSecondaryDark,
            ),
          ),
        ),
      ],
    );
  }
}

const double _cell = 52;
const double _gap = 2;

class _PeriodicGrid extends StatelessWidget {
  const _PeriodicGrid({required this.elements, required this.isMatch});
  final List<ChemicalElement> elements;
  final bool Function(ChemicalElement) isMatch;

  @override
  Widget build(BuildContext context) {
    final byPosition = <(int, int), ChemicalElement>{};
    final lanthanides = <ChemicalElement>[];
    final actinides = <ChemicalElement>[];
    for (final e in elements) {
      if (e.series == 'lanthanide') {
        lanthanides.add(e);
      } else if (e.series == 'actinide') {
        actinides.add(e);
      } else if (e.group != null) {
        byPosition[(e.period, e.group!)] = e;
      }
    }

    Widget slot(Widget? child) => Padding(
      padding: const EdgeInsets.all(_gap / 2),
      child: SizedBox(width: _cell, height: _cell + 6, child: child),
    );

    Widget tile(ChemicalElement e) =>
        _ElementTile(element: e, dimmed: !isMatch(e));

    final label = AppTheme.caption.copyWith(
      color: AppColors.textSecondaryDark,
      fontSize: 10,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(width: 20),
            for (var g = 1; g <= 18; g++)
              SizedBox(
                width: _cell + _gap,
                child: Center(child: Text('$g', style: label)),
              ),
          ],
        ),
        for (var p = 1; p <= 7; p++)
          Row(
            children: [
              SizedBox(
                width: 20,
                child: Center(child: Text('$p', style: label)),
              ),
              for (var g = 1; g <= 18; g++)
                if (byPosition[(p, g)] case final e?)
                  slot(tile(e))
                else if (g == 3 && p >= 6)
                  slot(
                    _SeriesMarker(
                      text: p == 6 ? '57–71' : '89–103',
                      color: categoryColor(p == 6 ? 'lanthanide' : 'actinide'),
                    ),
                  )
                else
                  slot(null),
            ],
          ),
        const SizedBox(height: 10),
        for (final (name, row) in [
          ('Lanthanides', lanthanides),
          ('Actinides', actinides),
        ])
          Row(
            children: [
              const SizedBox(width: 20),
              SizedBox(
                width: 2 * (_cell + _gap),
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(name, style: label, textAlign: TextAlign.right),
                ),
              ),
              for (final e in row) slot(tile(e)),
            ],
          ),
      ],
    );
  }
}

class _SeriesMarker extends StatelessWidget {
  const _SeriesMarker({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: color.withAlpha(140)),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Center(
      child: Text(
        text,
        style: AppTheme.caption.copyWith(
          color: AppColors.textSecondaryDark,
          fontSize: 10,
        ),
      ),
    ),
  );
}

class _ElementTile extends StatelessWidget {
  const _ElementTile({required this.element, required this.dimmed});
  final ChemicalElement element;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final e = element;
    final c = categoryColor(e.category);
    return Opacity(
      opacity: dimmed ? 0.25 : 1,
      child: Material(
        color: c.withAlpha(70),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: c),
          borderRadius: BorderRadius.circular(4),
        ),
        child: InkWell(
          key: ValueKey('element-${e.symbol}'),
          borderRadius: BorderRadius.circular(4),
          onTap: () => showElementCard(context, e),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${e.z}',
                  style: AppTheme.caption.copyWith(
                    color: AppColors.textSecondaryDark,
                    fontSize: 9,
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      e.symbol,
                      style: AppTheme.bodyLg.copyWith(
                        color: AppColors.textPrimaryDark,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ),
                ),
                Text(
                  e.weightLabel,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: AppTheme.caption.copyWith(
                    color: AppColors.textPrimaryDark,
                    fontSize: 8.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The detail card for one element.
Future<void> showElementCard(BuildContext context, ChemicalElement e) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surfaceDark,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheet) => SafeArea(child: ElementCard(element: e)),
  );
}

class ElementCard extends StatelessWidget {
  const ElementCard({super.key, required this.element});
  final ChemicalElement element;

  @override
  Widget build(BuildContext context) {
    final e = element;
    final c = categoryColor(e.category);
    final text = AppTheme.bodyMd.copyWith(color: AppColors.textPrimaryDark);
    final muted = AppTheme.caption.copyWith(color: AppColors.textSecondaryDark);

    Widget row(String k, Widget v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 150, child: Text(k, style: muted)),
          Expanded(child: v),
        ],
      ),
    );

    final String weightNote;
    if (e.atomicWeight != null) {
      weightNote = 'IUPAC abridged standard atomic weight (CIAAW 2024)';
    } else {
      final others = e.otherMassNumbers;
      weightNote =
          'No standard atomic weight. [${e.massNumber}] is the mass number of '
          'its most stable known isotope'
          '${others.isEmpty ? '' : ' (CIAAW also lists ${others.join(', ')} as comparably long-lived)'}.';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.withAlpha(70),
                  border: Border.all(color: c),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  e.symbol,
                  style: AppTheme.heading2.copyWith(
                    color: AppColors.textPrimaryDark,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.name,
                      style: AppTheme.heading3.copyWith(
                        color: AppColors.textPrimaryDark,
                      ),
                    ),
                    Text(_capitalise(e.category), style: muted),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          row('Atomic number', Text('${e.z}', style: text)),
          row(
            'Relative atomic mass',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.weightLabel, style: text),
                Text(weightNote, style: muted),
              ],
            ),
          ),
          row(
            'Group',
            Text(
              e.group?.toString() ??
                  '${_capitalise(e.series ?? '')}s (drawn below the table)',
              style: text,
            ),
          ),
          row('Period', Text('${e.period}', style: text)),
          row('Block', Text(e.block, style: text)),
          row(
            'Electron configuration',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FullLatexView(
                  latex: '\\(${configurationLatex(e.electronConfiguration)}\\)',
                  textStyle: text,
                ),
                if (e.configurationPredicted)
                  Text('Predicted, not measured.', style: muted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
