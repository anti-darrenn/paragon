import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'calculator_state.dart';

/// Holds the calculator between openings. The dock rebuilds a panel each
/// time it is opened, so the expression, Ans, memory and DEG/RAD live
/// here rather than in the widget. Not auto-disposed on purpose; nothing
/// is stored beyond the app session.
class CalculatorController extends Notifier<CalculatorState> {
  @override
  CalculatorState build() => const CalculatorState();

  void press(CalcKey key) => state = state.press(key);
}

final calculatorProvider =
    NotifierProvider<CalculatorController, CalculatorState>(
      CalculatorController.new,
    );
