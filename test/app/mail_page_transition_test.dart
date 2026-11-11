import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/app/motion/mail_motion.dart';
import 'package:local_mail_client/app/theme/mail_theme.dart';

Widget _host({
  required GlobalKey<NavigatorState> navigator,
  required MailNavigationObserver observer,
  TargetPlatform platform = TargetPlatform.android,
  bool reduced = false,
  bool guarded = false,
  ValueChanged<Future<String?>>? onPush,
}) => MaterialApp(
  navigatorKey: navigator,
  navigatorObservers: [observer],
  theme: buildMailTheme(Brightness.light).copyWith(platform: platform),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
    child: Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: observer.pointerDown,
      onPointerMove: observer.pointerMove,
      onPointerUp: observer.pointerUp,
      onPointerCancel: observer.pointerCancel,
      child: child!,
    ),
  ),
  home: Builder(
    builder: (context) => Scaffold(
      backgroundColor: Colors.blue,
      appBar: AppBar(
        actions: [
          TextButton(
            key: const Key('open-destination'),
            onPressed: () {
              final result = Navigator.of(context).push<String>(
                MaterialPageRoute(
                  settings: const RouteSettings(arguments: 'original argument'),
                  builder: (_) => _page(guarded: guarded),
                ),
              );
              onPush?.call(result);
            },
            child: const Text('打开'),
          ),
        ],
      ),
      body: const Center(child: Text('source page')),
    ),
  ),
);

Widget _page({bool guarded = false}) => PopScope(
  canPop: !guarded,
  child: const Scaffold(
    backgroundColor: Colors.white,
    body: Center(child: Text('destination', key: Key('destination'))),
  ),
);

ClipPath _reveal(WidgetTester tester) => tester.widget<ClipPath>(
  find.byKey(const ValueKey('mail-liquid-reveal')).last,
);

MailLiquidClipper _clipper(WidgetTester tester) =>
    _reveal(tester).clipper! as MailLiquidClipper;

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  expect(tester.binding.transientCallbackCount, 0);
}

Future<void> _backEvent(
  WidgetTester tester,
  String name, [
  Map<String, dynamic>? arguments,
]) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/backgesture',
    const StandardMethodCodec().encodeMethodCall(MethodCall(name, arguments)),
    (_) {},
  );
  await tester.pump();
}

void main() {
  testWidgets(
    'the previous page remains visible outside the spreading surface',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final observer = MailNavigationObserver();
      final boundary = GlobalKey();
      addTearDown(observer.dispose);
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: _host(navigator: navigator, observer: observer),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-destination')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('source page'), findsOneWidget);
      final color = await tester.runAsync(() async {
        final box =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await box.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final offset = (300 * image.width + 100) * 4;
        final rgba = data!.buffer.asUint8List().sublist(offset, offset + 4);
        image.dispose();
        return rgba;
      });
      expect(color, [33, 150, 243, 255]);
      await _finish(tester);
    },
  );

  test(
    'liquid contour starts empty and covers every corner at the endpoint',
    () {
      for (final size in [const Size(390, 844), const Size(1500, 900)]) {
        for (final origin in [
          Alignment.topRight,
          Alignment.bottomLeft,
          Alignment.center,
        ]) {
          expect(
            MailLiquidClipper(
              progress: 0,
              origin: origin,
            ).getClip(size).getBounds(),
            Rect.zero,
          );
          final middle = MailLiquidClipper(
            progress: .2,
            origin: origin,
          ).getClip(size);
          expect(middle.contains(origin.alongSize(size)), isTrue);
          expect(middle.computeMetrics().single.isClosed, isTrue);
          expect(middle.getBounds().width, lessThan(size.longestSide * 2));
          final full = MailLiquidClipper(
            progress: 1,
            origin: origin,
          ).getClip(size);
          for (final point in [
            const Offset(.1, .1),
            Offset(size.width - .1, .1),
            Offset(.1, size.height - .1),
            Offset(size.width - .1, size.height - .1),
          ]) {
            expect(full.contains(point), isTrue);
          }
        }
      }
    },
  );

  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.macOS,
    TargetPlatform.windows,
  ]) {
    testWidgets(
      '$platform spreads from the tap without translating page text',
      (tester) async {
        final navigator = GlobalKey<NavigatorState>();
        final observer = MailNavigationObserver();
        addTearDown(observer.dispose);
        await tester.pumpWidget(
          _host(navigator: navigator, observer: observer, platform: platform),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('mail-liquid-reveal')), findsNothing);
        final point = tester.getCenter(
          find.byKey(const Key('open-destination')),
        );
        await tester.tapAt(point);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final clipper = _clipper(tester);
        expect(clipper.origin.x, closeTo(point.dx / 800 * 2 - 1, .01));
        expect(clipper.origin.y, closeTo(point.dy / 600 * 2 - 1, .01));
        expect(clipper.progress, allOf(greaterThan(0), lessThan(1)));
        expect(_reveal(tester).clipBehavior, Clip.antiAlias);
        final textPosition = tester.getCenter(
          find.byKey(const Key('destination')),
        );
        expect(textPosition, const Offset(400, 300));
        await tester.pumpAndSettle();
        expect(
          tester.getCenter(find.byKey(const Key('destination'))),
          textPosition,
        );
        expect(_reveal(tester).clipBehavior, Clip.none);
        expect(navigator.currentState!.widget.pages, isEmpty);
        await _finish(tester);
      },
    );
  }

  testWidgets(
    'pop during spread reverses continuously and returns its result',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final observer = MailNavigationObserver();
      addTearDown(observer.dispose);
      Future<String?>? result;
      await tester.pumpWidget(
        _host(
          navigator: navigator,
          observer: observer,
          onPush: (value) => result = value,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-destination')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 140));
      final before = _clipper(tester).progress;
      final origin = _clipper(tester).origin;
      final route = ModalRoute.of(
        tester.element(find.byKey(const Key('destination'))),
      )!;
      expect(route.settings.arguments, 'original argument');
      navigator.currentState!.pop('kept result');
      await tester.pump();
      expect(_clipper(tester).origin, origin);
      expect(_clipper(tester).progress, closeTo(before, .0001));
      await tester.pumpAndSettle();
      expect(await result, 'kept result');
      expect(find.text('source page'), findsOneWidget);
      await _finish(tester);
    },
  );

  testWidgets(
    'programmatic route after a drag or cancel uses a center origin',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final observer = MailNavigationObserver();
      addTearDown(observer.dispose);
      await tester.pumpWidget(_host(navigator: navigator, observer: observer));
      await tester.pumpAndSettle();
      final drag = await tester.startGesture(const Offset(60, 300));
      await drag.moveTo(const Offset(180, 300));
      await drag.up();
      navigator.currentState!.push(MaterialPageRoute(builder: (_) => _page()));
      await tester.pump();
      await tester.pump();
      expect(_clipper(tester).origin, Alignment.center);
      await tester.pumpAndSettle();
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      final cancelled = await tester.startGesture(const Offset(70, 300));
      await cancelled.cancel();
      navigator.currentState!.push(MaterialPageRoute(builder: (_) => _page()));
      await tester.pump();
      await tester.pump();
      expect(_clipper(tester).origin, Alignment.center);
      await _finish(tester);
    },
  );

  testWidgets('an old click is not reused by later programmatic navigation', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    final observer = MailNavigationObserver();
    addTearDown(observer.dispose);
    await tester.pumpWidget(_host(navigator: navigator, observer: observer));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(60, 300));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 750)),
    );
    navigator.currentState!.push(MaterialPageRoute(builder: (_) => _page()));
    await tester.pump();
    await tester.pump();
    expect(_clipper(tester).origin, Alignment.center);
    await _finish(tester);
  });

  testWidgets('reduced motion shows the whole new page on its first frame', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    final observer = MailNavigationObserver();
    addTearDown(observer.dispose);
    await tester.pumpWidget(
      _host(navigator: navigator, observer: observer, reduced: true),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-destination')));
    await tester.pump();
    await tester.pump();
    expect(_reveal(tester).clipBehavior, Clip.none);
    expect(
      tester.getCenter(find.byKey(const Key('destination'))),
      const Offset(400, 300),
    );
    await _finish(tester);
  });

  testWidgets(
    'Cupertino edge gesture can cancel then complete without losing state',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final observer = MailNavigationObserver();
      addTearDown(observer.dispose);
      await tester.pumpWidget(
        _host(
          navigator: navigator,
          observer: observer,
          platform: TargetPlatform.iOS,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-destination')));
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(const Offset(2, 300));
      await gesture.moveTo(const Offset(180, 300));
      await tester.pump(const Duration(milliseconds: 16));
      expect(navigator.currentState!.userGestureInProgress, isTrue);
      expect(_reveal(tester).clipBehavior, Clip.none);
      await gesture.moveTo(const Offset(2, 300));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('destination')), findsOneWidget);
      final commit = await tester.startGesture(const Offset(2, 300));
      await commit.moveTo(const Offset(750, 300));
      await tester.pump(const Duration(milliseconds: 16));
      await commit.up();
      await tester.pumpAndSettle();
      expect(find.text('source page'), findsOneWidget);
      expect(find.byKey(const Key('destination')), findsNothing);
      await _finish(tester);
    },
  );

  testWidgets('a guarded page cannot be discarded by an edge swipe', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    final observer = MailNavigationObserver();
    addTearDown(observer.dispose);
    await tester.pumpWidget(
      _host(
        navigator: navigator,
        observer: observer,
        platform: TargetPlatform.iOS,
        guarded: true,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-destination')));
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(2, 300), const Offset(700, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('destination')), findsOneWidget);
    expect(navigator.currentState!.userGestureInProgress, isFalse);
    await _finish(tester);
  });

  testWidgets('Android predictive back can cancel and commit', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    final observer = MailNavigationObserver();
    addTearDown(observer.dispose);
    await tester.pumpWidget(_host(navigator: navigator, observer: observer));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-destination')));
    await tester.pumpAndSettle();
    const start = <String, dynamic>{
      'touchOffset': <double>[5, 300],
      'progress': 0.0,
      'swipeEdge': 0,
    };
    await _backEvent(tester, 'startBackGesture', start);
    await _backEvent(tester, 'updateBackGestureProgress', {
      'touchOffset': <double>[100, 300],
      'progress': .35,
      'swipeEdge': 0,
    });
    expect(navigator.currentState!.userGestureInProgress, isTrue);
    await _backEvent(tester, 'cancelBackGesture');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('destination')), findsOneWidget);
    await _backEvent(tester, 'startBackGesture', start);
    await _backEvent(tester, 'commitBackGesture');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('destination')), findsNothing);
    await _finish(tester);
  });
}
