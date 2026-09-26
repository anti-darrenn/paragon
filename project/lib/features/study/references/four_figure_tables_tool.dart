import 'package:flutter/material.dart';

import '../../../core/content/subject_tools.dart';
import '../../../core/study/study_tool.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/full_latex_view.dart';
import 'four_figure_math.dart';
import 'four_figure_tables.dart';
import '../../../core/theme/app_palette.dart';

/// The four-figure tables supplied in the WAEC hall: logarithms,
/// antilogarithms, natural sines, cosines and tangents. Every entry is
/// computed — see `four_figure_math.dart`.
class FourFigureTablesTool extends StudyTool {
  const FourFigureTablesTool();

  @override
  StudyToolId get id => StudyToolId.fourFigureTables;
  @override
  String get label => 'Four-figure tables';
  @override
  IconData get icon => Icons.table_chart_outlined;
  @override
  StudyPanelMode get mode => StudyPanelMode.page;

  @override
  Widget build(BuildContext context, StudyScope scope, VoidCallback close) =>
      const FourFigureTablesScreen();
}

class FourFigureTablesScreen extends StatefulWidget {
  const FourFigureTablesScreen({super.key});

  @override
  State<FourFigureTablesScreen> createState() => _FourFigureTablesScreenState();
}

class _FourFigureTablesScreenState extends State<FourFigureTablesScreen> {
  // ~450 short strings each; built once per opening, not per frame.
  late final List<FigureTable> _tables = buildFourFigureTables();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tables.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: context.palette.surface,
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.primary,
              unselectedLabelColor: context.palette.textSecondary,
              indicatorColor: AppColors.primary,
              tabs: [for (final t in _tables) Tab(text: t.title)],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [for (final t in _tables) FigureTableView(table: t)],
            ),
          ),
        ],
      ),
    );
  }
}

const double _rowHeaderWidth = 46;
const double _cellWidth = 54;
const double _mdWidth = 30;
const double _headerHeight = 30;
const double _rowHeight = 30;
const double _tallRowHeight = 44;

/// One table with sticky row and column headers and a look-up box.
class FigureTableView extends StatefulWidget {
  const FigureTableView({super.key, required this.table});
  final FigureTable table;

  @override
  State<FigureTableView> createState() => _FigureTableViewState();
}

class _FigureTableViewState extends State<FigureTableView> {
  final _input = TextEditingController();
  final _vBody = ScrollController();
  final _vHeader = ScrollController();
  final _hBody = ScrollController();
  final _hHeader = ScrollController();
  TableLookup? _hit;
  String? _error;

  late final List<double> _heights = [
    for (final md in widget.table.meanDifferences)
      md.any((s) => s.contains('\n')) ? _tallRowHeight : _rowHeight,
  ];
  late final List<double> _offsets = () {
    final out = <double>[];
    var y = 0.0;
    for (final h in _heights) {
      out.add(y);
      y += h;
    }
    return out;
  }();

  double get _bodyWidth =>
      widget.table.columnLabels.length * _cellWidth +
      widget.table.meanDifferenceLabels.length * _mdWidth +
      8;

  @override
  void initState() {
    super.initState();
    _vBody.addListener(() {
      if (_vHeader.hasClients) _vHeader.jumpTo(_vBody.offset);
    });
    _hBody.addListener(() {
      if (_hHeader.hasClients) _hHeader.jumpTo(_hBody.offset);
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _vBody.dispose();
    _vHeader.dispose();
    _hBody.dispose();
    _hHeader.dispose();
    super.dispose();
  }

  void _lookUp() {
    final hit = widget.table.lookup(_input.text);
    setState(() {
      _hit = hit;
      _error = hit == null
          ? 'Enter ${widget.table.lookupHint.toLowerCase()}.'
          : null;
    });
    if (hit == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_vBody.hasClients) {
        final target = (_offsets[hit.row] - _rowHeight * 2).clamp(
          0.0,
          _vBody.position.maxScrollExtent,
        );
        _vBody.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
      if (_hBody.hasClients) {
        final target = (hit.column * _cellWidth - _cellWidth).clamp(
          0.0,
          _hBody.position.maxScrollExtent,
        );
        _hBody.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  TextStyle get _cellStyle => AppTheme.caption.copyWith(
    color: context.palette.textPrimary,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  TextStyle get _headStyle => AppTheme.caption.copyWith(
    color: context.palette.textSecondary,
    fontWeight: FontWeight.w600,
  );

  @override
  Widget build(BuildContext context) {
    final t = widget.table;
    final hit = _hit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  onSubmitted: (_) => _lookUp(),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  style: AppTheme.bodyMd.copyWith(
                    color: context.palette.textPrimary,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: t.lookupHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _lookUp, child: const Text('Look up')),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: hit != null
              ? _LookupSummary(hit: hit, table: t)
              : Text(
                  _error ?? t.note,
                  style: AppTheme.caption.copyWith(
                    color: _error != null
                        ? AppColors.wrong
                        : context.palette.textSecondary,
                  ),
                ),
        ),
        Divider(height: 1, color: context.palette.border),
        Expanded(child: _grid(t, hit)),
      ],
    );
  }

  Widget _grid(FigureTable t, TableLookup? hit) {
    return Column(
      children: [
        SizedBox(
          height: _headerHeight,
          child: Row(
            children: [
              _box(
                width: _rowHeaderWidth,
                height: _headerHeight,
                color: context.palette.surface,
                child: const SizedBox.shrink(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _hHeader,
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  child: SizedBox(
                    width: _bodyWidth,
                    child: Row(
                      children: [
                        for (var c = 0; c < t.columnLabels.length; c++)
                          _box(
                            width: _cellWidth,
                            height: _headerHeight,
                            color: hit?.column == c
                                ? AppColors.primary.withAlpha(50)
                                : context.palette.surface,
                            child: Text(t.columnLabels[c], style: _headStyle),
                          ),
                        const SizedBox(width: 8),
                        for (var k = 1; k <= t.meanDifferenceLabels.length; k++)
                          _box(
                            width: _mdWidth,
                            height: _headerHeight,
                            color: hit != null && hit.meanDifferenceColumn == k
                                ? AppColors.primary.withAlpha(50)
                                : context.palette.track,
                            child: Text(
                              t.meanDifferenceLabels[k - 1],
                              style: _headStyle,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: _rowHeaderWidth,
                child: ListView.builder(
                  controller: _vHeader,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: t.rowLabels.length,
                  itemBuilder: (context, r) => _box(
                    width: _rowHeaderWidth,
                    height: _heights[r],
                    color: hit?.row == r
                        ? AppColors.primary.withAlpha(50)
                        : context.palette.surface,
                    child: Text(t.rowLabels[r], style: _headStyle),
                  ),
                ),
              ),
              Expanded(
                child: Scrollbar(
                  controller: _hBody,
                  child: SingleChildScrollView(
                    controller: _hBody,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: _bodyWidth,
                      child: ListView.builder(
                        controller: _vBody,
                        itemCount: t.rowLabels.length,
                        itemBuilder: (context, r) => _row(t, r, hit),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(FigureTable t, int r, TableLookup? hit) {
    final onRow = hit?.row == r;
    return Row(
      children: [
        for (var c = 0; c < t.columnLabels.length; c++)
          _box(
            key: onRow && hit!.column == c
                ? const ValueKey('ff-hit-cell')
                : null,
            width: _cellWidth,
            height: _heights[r],
            color: onRow && hit!.column == c
                ? AppColors.primary.withAlpha(110)
                : (onRow || hit?.column == c)
                ? AppColors.primary.withAlpha(28)
                : null,
            child: Text(t.cells[r][c], style: _cellStyle),
          ),
        const SizedBox(width: 8),
        for (var k = 1; k <= t.meanDifferenceLabels.length; k++)
          _box(
            key: onRow && hit!.meanDifferenceColumn == k
                ? const ValueKey('ff-hit-md')
                : null,
            width: _mdWidth,
            height: _heights[r],
            color: onRow && hit!.meanDifferenceColumn == k
                ? AppColors.primary.withAlpha(110)
                : onRow
                ? AppColors.primary.withAlpha(28)
                : context.palette.track.withAlpha(120),
            child: Text(
              t.meanDifferences[r][k - 1],
              textAlign: TextAlign.center,
              style: _cellStyle.copyWith(color: context.palette.textSecondary),
            ),
          ),
      ],
    );
  }

  Widget _box({
    Key? key,
    required double width,
    required double height,
    required Widget child,
    Color? color,
  }) => Container(
    key: key,
    width: width,
    height: height,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color,
      border: Border(
        bottom: BorderSide(color: context.palette.border, width: 0.5),
        right: BorderSide(color: context.palette.border, width: 0.5),
      ),
    ),
    child: child,
  );
}

class _LookupSummary extends StatelessWidget {
  const _LookupSummary({required this.hit, required this.table});
  final TableLookup hit;
  final FigureTable table;

  @override
  Widget build(BuildContext context) {
    final where = StringBuffer(
      'Row ${table.rowLabels[hit.row]}, column ${table.columnLabels[hit.column]}',
    );
    if (hit.meanDifferenceColumn > 0) {
      where.write(
        ', mean difference ${table.meanDifferenceLabels[hit.meanDifferenceColumn - 1]}',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FullLatexView(
          latex: hit.latex,
          textStyle: AppTheme.bodyLg.copyWith(
            color: context.palette.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          where.toString(),
          style: AppTheme.caption.copyWith(
            color: context.palette.textSecondary,
          ),
        ),
      ],
    );
  }
}
