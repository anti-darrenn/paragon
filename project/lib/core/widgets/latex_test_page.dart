import 'package:flutter/material.dart';
import 'math_text.dart';
import 'full_latex_view.dart';

/// A small manual test page showing a set of sample LaTeX strings
/// Rendered with both the full renderer and lightweight parser.
class LatexTestPage extends StatelessWidget {
  const LatexTestPage({super.key});

  static const samples = <String>[
    'We are asked to simplify:\n\n(11\u2082)^2',
    '\\vspace(0.5cm)',
    '\\textbf{Step 1: Convert the Binary Number to Base Ten}',
    'The binary number 11\u2082 means: (1 x 2^1) + (1 x 2^0)',
    '\\textit{Italic text example}',
    'Inline math: \$x^2 - 5x + 6 = 0\$',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LaTeX Test')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Full renderer (FullLatexView):', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...samples.map((s) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: const Color(0xFF0B2A12)),
                  child: FullLatexView(latex: s, textStyle: const TextStyle(color: Colors.white)),
                )),
            const SizedBox(height: 20),
            const Text('Light renderer (MathText with useLightRenderer=true):', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...samples.map((s) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: const Color(0xFF102233)),
                  child: MathText(text: s, useLightRenderer: true, style: const TextStyle(color: Colors.white)),
                )),
          ],
        ),
      ),
    );
  }
}
