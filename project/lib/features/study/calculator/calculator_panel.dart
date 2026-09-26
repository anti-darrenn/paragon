import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import 'calculator_engine.dart';
import 'calculator_provider.dart';
import 'calculator_state.dart';
import '../../../core/theme/app_palette.dart';

enum _Kind { digit, operator, function, action, equals }

class _KeySpec {
  const _KeySpec(this.key, this.label, this.kind, [this.shiftLabel]);
  final CalcKey key;
  final String label;
  final String? shiftLabel;
  final _Kind kind;
}

/// Six to a row: modes, memory and the scientific functions.
const _functionRows = [
  [
    _KeySpec(CalcKey.shift, 'SHIFT', _Kind.function),
    _KeySpec(CalcKey.angle, 'DRG', _Kind.function),
    _KeySpec(CalcKey.fraction, 'S⇔D', _Kind.function),
    _KeySpec(CalcKey.memoryClear, 'MC', _Kind.function),
    _KeySpec(CalcKey.memoryRecall, 'MR', _Kind.function),
    _KeySpec(CalcKey.memoryPlus, 'M+', _Kind.function, 'M−'),
  ],
  [
    _KeySpec(CalcKey.sin, 'sin', _Kind.function, 'sin⁻¹'),
    _KeySpec(CalcKey.cos, 'cos', _Kind.function, 'cos⁻¹'),
    _KeySpec(CalcKey.tan, 'tan', _Kind.function, 'tan⁻¹'),
    _KeySpec(CalcKey.log, 'log', _Kind.function, '10ˣ'),
    _KeySpec(CalcKey.ln, 'ln', _Kind.function, 'eˣ'),
    _KeySpec(CalcKey.sqrt, '√', _Kind.function, '∛'),
  ],
  [
    _KeySpec(CalcKey.square, 'x²', _Kind.function, 'x³'),
    _KeySpec(CalcKey.power, 'xʸ', _Kind.function),
    _KeySpec(CalcKey.inverse, 'x⁻¹', _Kind.function),
    _KeySpec(CalcKey.factorial, 'x!', _Kind.function),
    _KeySpec(CalcKey.nCr, 'nCr', _Kind.function, 'nPr'),
    _KeySpec(CalcKey.percent, '%', _Kind.function),
  ],
  [
    _KeySpec(CalcKey.open, '(', _Kind.function),
    _KeySpec(CalcKey.close, ')', _Kind.function),
    _KeySpec(CalcKey.pi, 'π', _Kind.function, 'e'),
    _KeySpec(CalcKey.ans, 'Ans', _Kind.function),
    _KeySpec(CalcKey.delete, 'DEL', _Kind.action),
    _KeySpec(CalcKey.clear, 'AC', _Kind.action),
  ],
];

/// Four to a row: the number pad.
const _padRows = [
  [
    _KeySpec(CalcKey.d7, '7', _Kind.digit),
    _KeySpec(CalcKey.d8, '8', _Kind.digit),
    _KeySpec(CalcKey.d9, '9', _Kind.digit),
    _KeySpec(CalcKey.divide, '÷', _Kind.operator),
  ],
  [
    _KeySpec(CalcKey.d4, '4', _Kind.digit),
    _KeySpec(CalcKey.d5, '5', _Kind.digit),
    _KeySpec(CalcKey.d6, '6', _Kind.digit),
    _KeySpec(CalcKey.multiply, '×', _Kind.operator),
  ],
  [
    _KeySpec(CalcKey.d1, '1', _Kind.digit),
    _KeySpec(CalcKey.d2, '2', _Kind.digit),
    _KeySpec(CalcKey.d3, '3', _Kind.digit),
    _KeySpec(CalcKey.subtract, '−', _Kind.operator),
  ],
  [
    _KeySpec(CalcKey.d0, '0', _Kind.digit),
    _KeySpec(CalcKey.point, '.', _Kind.digit),
    _KeySpec(CalcKey.equals, '=', _Kind.equals),
    _KeySpec(CalcKey.add, '+', _Kind.operator),
  ],
];

/// Physical keyboard characters (web) and the keys they press.
const Map<String, CalcKey> _typed = {
  '0': CalcKey.d0,
  '1': CalcKey.d1,
  '2': CalcKey.d2,
  '3': CalcKey.d3,
  '4': CalcKey.d4,
  '5': CalcKey.d5,
  '6': CalcKey.d6,
  '7': CalcKey.d7,
  '8': CalcKey.d8,
  '9': CalcKey.d9,
  '.': CalcKey.point,
  '+': CalcKey.add,
  '-': CalcKey.subtract,
  '*': CalcKey.multiply,
  'x': CalcKey.multiply,
  '/': CalcKey.divide,
  '^': CalcKey.power,
  '(': CalcKey.open,
  ')': CalcKey.close,
  '%': CalcKey.percent,
  '!': CalcKey.factorial,
  '=': CalcKey.equals,
};

/// Numpad operators, which do not always report a character.
final Map<LogicalKeyboardKey, CalcKey> _numpad = {
  LogicalKeyboardKey.numpadAdd: CalcKey.add,
  LogicalKeyboardKey.numpadSubtract: CalcKey.subtract,
  LogicalKeyboardKey.numpadMultiply: CalcKey.multiply,
  LogicalKeyboardKey.numpadDivide: CalcKey.divide,
  LogicalKeyboardKey.numpadDecimal: CalcKey.point,
};

/// The calculator panel: display, then the function keys, then the pad.
/// Fits the dock's 360px panel; on a phone's shorter sheet it scrolls.
class CalculatorPanel extends ConsumerWidget {
  const CalculatorPanel({super.key});

  static const double keyHeight = 42;

  KeyEventResult _onKey(WidgetRef ref, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final logical = event.logicalKey;
    CalcKey? key;
    if (logical == LogicalKeyboardKey.enter ||
        logical == LogicalKeyboardKey.numpadEnter) {
      key = CalcKey.equals;
    } else if (logical == LogicalKeyboardKey.backspace) {
      key = CalcKey.delete;
    } else if (logical == LogicalKeyboardKey.escape) {
      key = CalcKey.clear;
    } else {
      key = _numpad[logical];
      final c = event.character;
      if (key == null && c != null) key = _typed[c];
    }
    if (key == null) return KeyEventResult.ignored;
    ref.read(calculatorProvider.notifier).press(key);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calculatorProvider);
    void press(CalcKey k) => ref.read(calculatorProvider.notifier).press(k);

    Widget row(List<_KeySpec> specs) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          for (var i = 0; i < specs.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: _Key(
                spec: specs[i],
                shift: state.shift,
                onTap: () => press(specs[i].key),
              ),
            ),
          ],
        ],
      ),
    );

    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) => _onKey(ref, event),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Display(state: state),
            const SizedBox(height: 10),
            for (final r in _functionRows) row(r),
            const SizedBox(height: 4),
            for (final r in _padRows) row(r),
          ],
        ),
      ),
    );
  }
}

class _Display extends StatelessWidget {
  const _Display({required this.state});
  final CalculatorState state;

  @override
  Widget build(BuildContext context) {
    final indicator = AppTheme.caption.copyWith(
      color: context.palette.textSecondary,
    );
    final isError = state.result is CalcError;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      decoration: BoxDecoration(
        color: context.palette.background,
        border: Border.all(color: context.palette.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (state.shift)
                Text(
                  'S',
                  key: const ValueKey('calc-shift-indicator'),
                  style: indicator.copyWith(color: AppColors.primary),
                ),
              if (state.shift) const SizedBox(width: 8),
              if (state.hasMemory)
                Text(
                  'M',
                  key: const ValueKey('calc-memory-indicator'),
                  style: indicator,
                ),
              const Spacer(),
              Text(
                state.angleMode == AngleMode.deg ? 'DEG' : 'RAD',
                key: const ValueKey('calc-angle'),
                style: indicator,
              ),
            ],
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: 22,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Text(
                state.expression,
                key: const ValueKey('calc-expression'),
                style: AppTheme.bodyMd.copyWith(
                  color: context.palette.textPrimary,
                  height: 1.4,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 34,
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  state.resultText,
                  key: const ValueKey('calc-result'),
                  style: AppTheme.heading2.copyWith(
                    color: isError
                        ? AppColors.wrong
                        : context.palette.textPrimary,
                    fontSize: 24,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.spec, required this.shift, required this.onTap});
  final _KeySpec spec;
  final bool shift;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shifted = shift && spec.shiftLabel != null;
    final label = shifted ? spec.shiftLabel! : spec.label;
    final (Color fill, Color ink) = switch (spec.kind) {
      _Kind.digit => (context.palette.track, context.palette.textPrimary),
      _Kind.operator => (context.palette.track, AppColors.primary),
      _Kind.function => (
        context.palette.background,
        context.palette.textPrimary,
      ),
      _Kind.action => (context.palette.background, AppColors.wrong),
      _Kind.equals => (AppColors.primary, context.palette.background),
    };
    final active = spec.key == CalcKey.shift && shift;
    final big =
        spec.kind == _Kind.digit ||
        spec.kind == _Kind.operator ||
        spec.kind == _Kind.equals;
    return SizedBox(
      height: CalculatorPanel.keyHeight,
      child: Material(
        color: active ? AppColors.primary : fill,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: context.palette.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: InkWell(
          key: ValueKey('calc-key-${spec.key.name}'),
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  label,
                  style: (big ? AppTheme.heading3 : AppTheme.btnLabel).copyWith(
                    color: active
                        ? context.palette.background
                        : shifted
                        ? AppColors.primary
                        : ink,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
