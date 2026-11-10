import 'package:flutter/material.dart';

/// One restrained motion family: a single spring for state selection, and
/// short decelerating curves for route, press and expansion changes. Nothing
/// here starts on its own; controllers live only while an interaction runs.
abstract final class MailMotion {
  static const Duration quick = Duration(milliseconds: 140);
  static const Duration standard = Duration(milliseconds: 220);
  static const Duration route = Duration(milliseconds: 280);

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

/// A small, interruption-safe state transition for pushed pages. Native
/// platform navigation (including iOS edge-swipe back and Android predictive
/// back) stays in charge of the route itself; this only shapes the surface.
class MailPageTransitionsBuilder extends PageTransitionsBuilder {
  const MailPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (route.isFirst || MailMotion.reduceMotion(context)) return child;
    // Drive the route animation directly instead of keeping a CurvedAnimation
    // and its listeners alive for the lifetime of the route.
    final curved = animation.drive(CurveTween(curve: MailMotion.standardCurve));
    final offset = Tween<Offset>(
      begin: const Offset(0.0, 0.012),
      end: Offset.zero,
    ).animate(curved);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(position: offset, child: child),
    );
  }
}
