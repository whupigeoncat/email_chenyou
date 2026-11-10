import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/app/theme/mail_theme.dart';
import 'package:local_mail_client/app/widgets/mail_filter_switch.dart';

Widget _host({
  required int selected,
  required ValueChanged<int> onSelected,
  bool disableAnimations = false,
  double textScale = 1,
}) {
  return MaterialApp(
    theme: buildMailTheme(Brightness.light),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations: disableAnimations,
        textScaler: TextScaler.linear(textScale),
      ),
      child: child!,
    ),
    home: Scaffold(
      body: Center(
        child: StatefulBuilder(
          builder: (context, setState) {
            return MailFilterSwitch(
              labels: const ['全部', '未读'],
              selectedIndex: selected,
              segmentKeys: const [
                Key('inbox-filter-all'),
                Key('toggle-unread-filter'),
              ],
              onSelected: (index) {
                onSelected(index);
                setState(() => selected = index);
              },
            );
          },
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('selection pill retargets fast and stops without tickers', (
    tester,
  ) async {
    var selected = 0;
    await tester.pumpWidget(
      _host(selected: selected, onSelected: (value) => selected = value),
    );
    await tester.pump();

    final pill = find.byKey(const Key('mail-filter-pill'));
    final all = find.byKey(const Key('inbox-filter-all'));
    final unread = find.byKey(const Key('toggle-unread-filter'));

    // The label row and pill share the same inset; their centers must align.
    expect(
      (tester.getRect(pill).center.dx - tester.getRect(all).center.dx).abs(),
      lessThan(1.0),
    );

    await tester.tap(unread);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 35));
    await tester.tap(all);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 25));
    await tester.tap(unread);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(selected, 1);
    expect(
      (tester.getRect(pill).center.dx - tester.getRect(unread).center.dx).abs(),
      lessThan(1.0),
    );
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('reduced motion resolves immediately and leaves no ticker', (
    tester,
  ) async {
    var selected = 0;
    await tester.pumpWidget(
      _host(
        selected: selected,
        disableAnimations: true,
        onSelected: (value) => selected = value,
      ),
    );
    await tester.pump();

    final pill = find.byKey(const Key('mail-filter-pill'));
    final unread = find.byKey(const Key('toggle-unread-filter'));
    await tester.tap(unread);
    await tester.pump();

    expect(selected, 1);
    expect(
      (tester.getRect(pill).center.dx - tester.getRect(unread).center.dx).abs(),
      lessThan(1.0),
    );

    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('filter exposes one accessible selected segment', (tester) async {
    final semantics = tester.ensureSemantics();
    var selected = 0;
    await tester.pumpWidget(
      _host(selected: selected, onSelected: (value) => selected = value),
    );
    await tester.pumpAndSettle();

    final all = tester.getSemantics(find.byKey(const Key('inbox-filter-all')));
    final unread = tester.getSemantics(
      find.byKey(const Key('toggle-unread-filter')),
    );
    expect(all.label, '全部');
    expect(all.flagsCollection.isSelected, Tristate.isTrue);
    expect(all.flagsCollection.isButton, isTrue);
    expect(unread.label, '未读');
    expect(unread.flagsCollection.isSelected, Tristate.isFalse);
    expect(unread.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    semantics.dispose();
  });

  testWidgets('large text keeps both labels visible without overflow', (
    tester,
  ) async {
    var selected = 1;
    await tester.pumpWidget(
      _host(
        selected: selected,
        textScale: 2,
        onSelected: (value) => selected = value,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('全部'), findsOneWidget);
    expect(find.text('未读'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
