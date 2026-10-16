import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/providers/auth_provider.dart';
import 'package:paragon/features/rooms/join_room_screen.dart';

/// Plan v2 7.5: `/join?code=…` from a host's link fills the box.
void main() {
  Future<String> codeIn(WidgetTester tester, String? initial) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [isGuestProvider.overrideWithValue(true)],
        child: MaterialApp(home: JoinRoomScreen(initialCode: initial)),
      ),
    );
    await tester.pump();
    return tester
        .widget<TextField>(find.byType(TextField).first)
        .controller!
        .text;
  }

  testWidgets('a shared code is filled in, tidied', (tester) async {
    expect(await codeIn(tester, 'abc234'), 'ABC234');
  });

  testWidgets('CONTROL: no code, or a bad one, leaves the box empty', (
    tester,
  ) async {
    expect(await codeIn(tester, null), '');
    expect(await codeIn(tester, 'nope'), '');
  });
}
