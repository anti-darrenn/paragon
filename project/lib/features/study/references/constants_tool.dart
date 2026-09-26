import 'package:flutter/material.dart';

import '../../../core/content/subject_tools.dart';
import '../../../core/study/study_tool.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/full_latex_view.dart';
import 'constants_data.dart';

class ConstantsTool extends StudyTool {
  const ConstantsTool();

  @override
  StudyToolId get id => StudyToolId.constants;
  @override
  String get label => 'Units & constants';
  @override
  IconData get icon => Icons.straighten_outlined;
  @override
  StudyPanelMode get mode => StudyPanelMode.page;

  @override
  Widget build(BuildContext context, StudyScope scope, VoidCallback close) =>
      const ConstantsScreen();
}

class ConstantsScreen extends StatelessWidget {
  const ConstantsScreen({super.key});

  static const _tabs = ['Constants', 'SI units', 'Prefixes', 'Converter'];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabs.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: AppColors.surfaceDark,
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondaryDark,
              indicatorColor: AppColors.primary,
              tabs: [for (final t in _tabs) Tab(text: t)],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _ConstantsList(),
                _SiUnitsList(),
                _PrefixList(),
                UnitConverter(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

TextStyle get _text =>
    AppTheme.bodyMd.copyWith(color: AppColors.textPrimaryDark);
TextStyle get _muted =>
    AppTheme.caption.copyWith(color: AppColors.textSecondaryDark);
TextStyle get _heading =>
    AppTheme.label.copyWith(color: AppColors.textSecondaryDark);

Widget _tag(String text, Color color) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
  decoration: BoxDecoration(
    border: Border.all(color: color),
    borderRadius: BorderRadius.circular(4),
  ),
  child: Text(text, style: AppTheme.caption.copyWith(color: color)),
);

class _ConstantsList extends StatelessWidget {
  const _ConstantsList();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text(
          'CODATA 2018 recommended values (NIST). “Exact” means exact by '
          'the 2019 SI definitions or by convention; a value ending in … is '
          'exact but cut short. Brackets give the uncertainty in the last '
          'digits: 6.674 30(15) means ±0.000 15.',
          style: _muted,
        ),
        const SizedBox(height: 8),
        for (final c in kPhysicalConstants)
          _ConstantTile(
            name: c.name,
            latex: c.latex,
            exact: c.exact,
            note: c.note,
          ),
        _ConstantTile(
          name: 'Coulomb constant',
          latex: coulombConstantLatex,
          exact: false,
          note:
              'Computed from ε₀ above, to 5 significant figures. WAEC '
              'questions usually take k = 9 × 10⁹ N m² C⁻².',
        ),
      ],
    );
  }
}

class _ConstantTile extends StatelessWidget {
  const _ConstantTile({
    required this.name,
    required this.latex,
    required this.exact,
    this.note,
  });
  final String name;
  final String latex;
  final bool exact;
  final String? note;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.borderDark)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(name, style: _heading)),
            if (exact) _tag('exact', AppColors.correct),
          ],
        ),
        const SizedBox(height: 4),
        FullLatexView(latex: latex, textStyle: _text),
        if (note != null) ...[
          const SizedBox(height: 2),
          Text(note!, style: _muted),
        ],
      ],
    ),
  );
}

class _SiUnitsList extends StatelessWidget {
  const _SiUnitsList();

  @override
  Widget build(BuildContext context) {
    Widget unitRow(SiUnit u, {required bool base}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 48, child: Text(u.symbol, style: _text)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(u.name, style: _text),
                Text(u.quantity, style: _muted),
              ],
            ),
          ),
          SizedBox(
            width: 110,
            child: base
                ? FullLatexView(
                    latex: '\\(\\text{fixes } ${u.definition}\\)',
                    textStyle: _muted,
                  )
                : FullLatexView(
                    latex: '\\(= ${u.definition}\\)',
                    textStyle: _text,
                  ),
          ),
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text('The seven SI base units', style: _heading),
        const SizedBox(height: 2),
        Text(
          'Since 2019 each is defined by fixing the value of a constant '
          '(SI Brochure, 9th edition).',
          style: _muted,
        ),
        for (final u in kSiBaseUnits) unitRow(u, base: true),
        const SizedBox(height: 16),
        Text('Derived units with special names', style: _heading),
        for (final u in kSiDerivedUnits) unitRow(u, base: false),
      ],
    );
  }
}

class _PrefixList extends StatelessWidget {
  const _PrefixList();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text(
          'SI prefixes (SI Brochure, 9th edition; ronna, quetta, ronto and '
          'quecto added in 2022).',
          style: _muted,
        ),
        const SizedBox(height: 8),
        for (final p in kSiPrefixes)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(width: 90, child: Text(p.name, style: _text)),
                SizedBox(width: 48, child: Text(p.symbol, style: _text)),
                Expanded(
                  child: FullLatexView(
                    latex: '\\(10^{${p.power}}\\)',
                    textStyle: _text,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Converts between units in one category. Temperatures are converted as
/// affine maps, so offsets are handled (100 °C = 373.15 K = 212 °F).
class UnitConverter extends StatefulWidget {
  const UnitConverter({super.key});

  @override
  State<UnitConverter> createState() => _UnitConverterState();
}

class _UnitConverterState extends State<UnitConverter> {
  UnitCategory _category = kUnitCategories.first;
  late ConvUnit _from = _category.units[0];
  late ConvUnit _to = _category.units[1];
  final _input = TextEditingController(text: '1');

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _setCategory(UnitCategory c) => setState(() {
    _category = c;
    _from = c.units[0];
    _to = c.units[1];
  });

  Widget _unitPicker(
    ConvUnit value,
    ValueChanged<ConvUnit> onChanged,
    String key,
  ) => DropdownButtonFormField<ConvUnit>(
    key: ValueKey('$key-${_category.name}-${value.symbol}'),
    initialValue: value,
    isExpanded: true,
    dropdownColor: AppColors.surfaceDark,
    style: _text,
    decoration: const InputDecoration(
      isDense: true,
      border: OutlineInputBorder(),
    ),
    items: [
      for (final u in _category.units)
        DropdownMenuItem(value: u, child: Text('${u.name} (${u.symbol})')),
    ],
    onChanged: (u) {
      if (u != null) onChanged(u);
    },
  );

  @override
  Widget build(BuildContext context) {
    final v = double.tryParse(_input.text.trim().replaceAll(',', ''));
    final result = v == null ? null : convert(v, _from, _to);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final c in kUnitCategories)
              ChoiceChip(
                label: Text(c.name),
                selected: c == _category,
                onSelected: (_) => _setCategory(c),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('converter-input'),
          controller: _input,
          onChanged: (_) => setState(() {}),
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          style: _text,
          decoration: const InputDecoration(
            labelText: 'Value',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        _unitPicker(_from, (u) => setState(() => _from = u), 'from'),
        Center(
          child: IconButton(
            tooltip: 'Swap units',
            icon: const Icon(Icons.swap_vert),
            onPressed: () => setState(() {
              final t = _from;
              _from = _to;
              _to = t;
            }),
          ),
        ),
        _unitPicker(_to, (u) => setState(() => _to = u), 'to'),
        const SizedBox(height: 16),
        Text(
          result == null
              ? 'Enter a number.'
              : '${_input.text.trim()} ${_from.symbol} = '
                    '${formatConverted(result)} ${_to.symbol}',
          key: const ValueKey('converter-result'),
          style: AppTheme.heading3.copyWith(color: AppColors.textPrimaryDark),
        ),
        const SizedBox(height: 12),
        Text(
          'Factors are exact by definition (NIST SP 811) except the atomic '
          'mass unit (CODATA 2018). Results are shown to 6 significant '
          'figures.',
          style: _muted,
        ),
      ],
    );
  }
}
