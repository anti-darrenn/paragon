import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/config/support_config.dart';
import 'package:paragon/features/support/donate_card.dart';

const _links = DonateLinks(
  oneTime: [
    (amount: 1000, url: 'https://pay.test/one-1000'),
    (amount: 2500, url: 'https://pay.test/one-2500'),
    (amount: 5000, url: null), // no page yet: hidden
  ],
  oneTimeOther: 'https://pay.test/other',
  monthly: [(amount: 2500, url: 'https://pay.test/month-2500')],
);

Future<List<Uri>> _pump(WidgetTester tester, DonateLinks links) async {
  final opened = <Uri>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DonateCard(links: links, open: opened.add),
        ),
      ),
    ),
  );
  return opened;
}

void main() {
  test('formatNaira groups thousands', () {
    expect(formatNaira(500), '₦500');
    expect(formatNaira(2500), '₦2,500');
    expect(formatNaira(1000000), '₦1,000,000');
  });

  testWidgets('control: what ships draws nothing', (tester) async {
    expect(kDonateLinks.isEmpty, isTrue);
    await _pump(tester, kDonateLinks);
    expect(find.text('Make a donation'), findsNothing);
  });

  testWidgets('one-time: the middle amount is chosen, and opens its page', (
    tester,
  ) async {
    final opened = await _pump(tester, _links);
    expect(find.text('₦5,000'), findsNothing);
    await tester.tap(find.text('Donate ₦2,500'));
    expect(opened.single.toString(), 'https://pay.test/one-2500');

    await tester.tap(find.text('Other'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Donate'));
    expect(opened.last.toString(), 'https://pay.test/other');
  });

  testWidgets('monthly opens the monthly page and hides Other', (tester) async {
    final opened = await _pump(tester, _links);
    await tester.tap(find.text('Monthly'));
    await tester.pump();
    expect(find.text('Other'), findsNothing);
    await tester.tap(find.text('Donate ₦2,500 a month'));
    expect(opened.single.toString(), 'https://pay.test/month-2500');
  });

  testWidgets('with only one-time pages there is no toggle', (tester) async {
    await _pump(
      tester,
      const DonateLinks(
        oneTime: [(amount: 1000, url: 'https://pay.test/a')],
        oneTimeOther: null,
        monthly: [],
      ),
    );
    expect(find.text('Monthly'), findsNothing);
    expect(find.text('Donate ₦1,000'), findsOneWidget);
  });
}
