import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// One restrained motion family: a spring for state selection, an opaque liquid
/// route reveal, and short curves for press and expansion changes. Nothing
/// here starts on its own; controllers live only while an interaction runs.
abstract final class MailMotion {
  static const Duration quick = Duration(milliseconds: 140);
  static const Duration standard = Duration(milliseconds: 220);
  static const Duration route = Duration(milliseconds: 420);
  static const Duration routeExit = Duration(milliseconds: 280);

  static const Curve standardCurve = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve exitCurve = Cubic(0.4, 0.0, 1.0, 1.0);

  /// Physically continuous selection; mild bounce, settles quickly.
  static final SpringDescription selectionSpring =
      SpringDescription.withDurationAndBounce(
        duration: const Duration(milliseconds: 420),
        bounce: 0.12,
      );

  static bool reduceMotion(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  static Duration duration(BuildContext context, Duration duration) =>
      reduceMotion(context) ? Duration.zero : duration;
}

final _routeOrigins = Expando<Alignment>('mail route origins');

/// A route keeps its opening point for the return journey. Weak keys let
/// disposed routes go away without retaining their pages or contexts.
class MailNavigationObserver extends NavigatorObserver {
  final Stopwatch _clock = Stopwatch()..start();
  Offset? _position;
  Duration? _pressedAt;
  int? _pointer;

  void pointerDown(PointerDownEvent event) {
    if (event.buttons != kPrimaryButton || _pointer != null) {
      clearPointer();
      return;
    }
    _pointer = event.pointer;
    _position = event.position;
    _pressedAt = _clock.elapsed;
  }

  void pointerMove(PointerMoveEvent event) {
    if (event.pointer == _pointer &&
        _position != null &&
        (event.position - _position!).distance > kTouchSlop) {
      clearPointer();
    }
  }

  void pointerUp(PointerUpEvent event) {
    if (event.pointer == _pointer) {
      _pointer = null;
      _pressedAt = _clock.elapsed;
    }
  }

  void pointerCancel(PointerCancelEvent event) {
    if (event.pointer == _pointer) clearPointer();
  }

  void clearPointer() {
    _position = null;
    _pressedAt = null;
    _pointer = null;
  }

  Alignment _consumeOrigin() {
    final point = _position;
    final at = _pressedAt;
    final recent =
        at != null &&
        (_pointer != null ||
            _clock.elapsed - at < const Duration(milliseconds: 700));
    clearPointer();
    final box = navigator?.context.findRenderObject();
    if (!recent ||
        point == null ||
        box is! RenderBox ||
        !box.hasSize ||
        box.size.isEmpty) {
      return Alignment.center;
    }
    final local = box.globalToLocal(point);
    return Alignment(
      (local.dx / box.size.width * 2 - 1).clamp(-1.0, 1.0),
      (local.dy / box.size.height * 2 - 1).clamp(-1.0, 1.0),
    );
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute && previousRoute != null) {
      _routeOrigins[route] = _consumeOrigin();
    }
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute is PageRoute) _routeOrigins[newRoute] = _consumeOrigin();
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  void dispose() {
    clearPointer();
    _clock.stop();
  }
}

/// Reveals the new, stationary page as an opaque spreading surface. Native
/// builders remain mounted to own interactive-back detection, but their normal
/// slide/fade animations are held at the completed state.
class MailPageTransitionsBuilder extends PageTransitionsBuilder {
  const MailPageTransitionsBuilder();

  @override
  Duration get transitionDuration => MailMotion.route;

  @override
  Duration get reverseTransitionDuration => MailMotion.routeExit;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (route.isFirst) return child;
    final platform = Theme.of(context).platform;
    final reduceMotion = MailMotion.reduceMotion(context);
    final gestureState = route.navigator!.userGestureInProgressNotifier;
    return AnimatedBuilder(
      animation: Listenable.merge([animation, gestureState]),
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: child,
      ),
      builder: (context, page) {
        final gesture = route.popGestureInProgress;
        // One reversible function avoids an edge jump when a push is popped
        // before it finishes. The page's typography never moves or scales.
        final progress = Curves.easeInOutCubic.transform(
          animation.value.clamp(0.0, 1.0),
        );
        final reveal = ClipPath(
          key: const ValueKey('mail-liquid-reveal'),
          clipper: MailLiquidClipper(
            progress: progress,
            origin: _routeOrigins[route] ?? Alignment.center,
          ),
          clipBehavior: reduceMotion || gesture || progress >= 1
              ? Clip.none
              : Clip.antiAlias,
          child: page,
        );
        // AlwaysStoppedAnimation reports "forward" even at zero, which makes
        // Android paint a full-page fallback background outside the reveal.
        final primary = gesture ? animation : kAlwaysCompleteAnimation;
        const secondary = kAlwaysDismissedAnimation;
        return switch (platform) {
          TargetPlatform.android =>
            const PredictiveBackPageTransitionsBuilder().buildTransitions(
              route,
              context,
              primary,
              secondary,
              reveal,
            ),
          TargetPlatform.iOS || TargetPlatform.macOS =>
            const CupertinoPageTransitionsBuilder().buildTransitions(
              route,
              context,
              primary,
              secondary,
              reveal,
            ),
          _ => reveal,
        };
      },
    );
  }
}

/// A smooth, gently changing contour; no shader, blur, alpha layer or timer.
class MailLiquidClipper extends CustomClipper<Path> {
  const MailLiquidClipper({required this.progress, required this.origin});

  final double progress;
  final Alignment origin;

  @override
  Path getClip(Size size) {
    if (progress <= 0 || size.isEmpty) return Path();
    if (progress >= 1) return Path()..addRect(Offset.zero & size);
    final center = origin.alongSize(size);
    final farthest = <Offset>[
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ].map((corner) => (corner - center).distance).reduce(math.max);
    final radius = 8 + (farthest * 1.025 - 8) * progress;
    final ripple = 0.045 * math.pow(1 - progress, 2);
    const count = 16;
    final points = List<Offset>.generate(count, (index) {
      final angle = index * math.pi * 2 / count;
      final wave =
          math.sin(angle * 3 + progress * math.pi * 0.7) +
          0.5 * math.sin(angle * 5 - progress * math.pi * 0.5);
      final r = radius * (1 + ripple * wave);
      return center + Offset(math.cos(angle) * r, math.sin(angle) * r);
    });
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < count; i++) {
      final previous = points[(i + count - 1) % count];
      final current = points[i];
      final next = points[(i + 1) % count];
      final following = points[(i + 2) % count];
      final firstControl = current + (next - previous) / 6;
      final secondControl = next - (following - current) / 6;
      path.cubicTo(
        firstControl.dx,
        firstControl.dy,
        secondControl.dx,
        secondControl.dy,
        next.dx,
        next.dy,
      );
    }
    return path..close();
  }

  @override
  bool shouldReclip(MailLiquidClipper oldClipper) =>
      progress != oldClipper.progress || origin != oldClipper.origin;
}
