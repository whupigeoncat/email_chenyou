import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../motion/mail_motion.dart';
import '../theme/mail_theme.dart';

/// The signature blue-flow control: one physically continuous selection pill.
///
/// The controller is created only for this widget, retargets from its current
/// velocity and stops as soon as the spring settles. Reduced motion resolves
/// to the target immediately without leaving a ticker or timer behind.
class MailFilterSwitch extends StatefulWidget {
  const MailFilterSwitch({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.semanticLabel = '邮件筛选',
    this.segmentKeys = const <Key?>[],
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final String semanticLabel;
  final List<Key?> segmentKeys;

  @override
  State<MailFilterSwitch> createState() => _MailFilterSwitchState();
}

class _MailFilterSwitchState extends State<MailFilterSwitch>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late double _target;
  bool _reduceMotion = false;

  int get _lastIndex => math.max(0, widget.labels.length - 1);

  double _fractionFor(int index) {
    if (_lastIndex == 0) return 0;
    return (index / _lastIndex).clamp(0.0, 1.0).toDouble();
  }

  @override
  void initState() {
    super.initState();
    _target = _fractionFor(widget.selectedIndex);
    _controller = AnimationController.unbounded(vsync: this, value: _target);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MailMotion.reduceMotion(context);
    if (reduce != _reduceMotion) {
      _reduceMotion = reduce;
      if (reduce) {
        _controller.stop();
        _controller.value = _target;
      }
    }
  }

  @override
  void didUpdateWidget(covariant MailFilterSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = _fractionFor(widget.selectedIndex);
    if (target != _target) {
      _target = target;
      _animateToTarget();
    }
  }

  void _animateToTarget() {
    if (_reduceMotion) {
      _controller.stop();
      _controller.value = _target;
      return;
    }
    _controller.animateWith(
      SpringSimulation(
        MailMotion.selectionSpring,
        _controller.value,
        _target,
        _controller.velocity,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    assert(widget.labels.isNotEmpty);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textScaler = MediaQuery.textScalerOf(context);
    final baseStyle =
        theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600) ??
        const TextStyle(fontWeight: FontWeight.w600);
    final textDirection = Directionality.of(context);

    var widestLabel = 0.0;
    var tallestLabel = 0.0;
    for (final label in widget.labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: baseStyle),
        textDirection: textDirection,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      widestLabel = math.max(widestLabel, painter.width);
      tallestLabel = math.max(tallestLabel, painter.height);
      painter.dispose();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 320.0;
        final count = widget.labels.length;
        var horizontalPadding = 20.0;
        final naturalWidth = count * (widestLabel + horizontalPadding * 2) + 8;
        if (naturalWidth > available) {
          horizontalPadding =
              ((available - 8 - count * widestLabel) / (count * 2)).clamp(
                8.0,
                20.0,
              );
        }
        final segmentWidth = widestLabel + horizontalPadding * 2;
        final trackWidth = segmentWidth * count + 8;
        final segmentHeight = math.max(48.0, tallestLabel + 18);
        final trackHeight = segmentHeight + 8;
        final radius = BorderRadius.circular(999);

        return Semantics(
          container: true,
          label: widget.semanticLabel,
          child: SizedBox(
            width: trackWidth,
            height: trackHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: MailColors.track(context),
                borderRadius: radius,
              ),
              child: Stack(
                children: [
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final fraction = _controller.value.clamp(
                        0.0,
                        _lastIndex.toDouble(),
                      );
                      return Positioned(
                        left: 4 + fraction * (count - 1) * segmentWidth,
                        top: 4,
                        width: segmentWidth,
                        height: segmentHeight,
                        child: DecoratedBox(
                          key: const Key('mail-filter-pill'),
                          decoration: BoxDecoration(
                            color: MailColors.brandBlue,
                            borderRadius: radius,
                          ),
                        ),
                      );
                    },
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        children: [
                          for (var index = 0; index < count; index++)
                            SizedBox(
                              width: segmentWidth,
                              height: trackHeight,
                              child: Semantics(
                                button: true,
                                selected: widget.selectedIndex == index,
                                label: widget.labels[index],
                                excludeSemantics: true,
                                onTap: widget.selectedIndex == index
                                    ? null
                                    : () => widget.onSelected(index),
                                child: Material(
                                  type: MaterialType.transparency,
                                  child: InkWell(
                                    key: index < widget.segmentKeys.length
                                        ? widget.segmentKeys[index]
                                        : null,
                                    customBorder: const StadiumBorder(),
                                    canRequestFocus: true,
                                    onTap: widget.selectedIndex == index
                                        ? null
                                        : () => widget.onSelected(index),
                                    child: Center(
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: math.max(
                                            4,
                                            horizontalPadding - 8,
                                          ),
                                        ),
                                        child: AnimatedDefaultTextStyle(
                                          duration: MailMotion.duration(
                                            context,
                                            MailMotion.quick,
                                          ),
                                          curve: MailMotion.standardCurve,
                                          style: baseStyle.copyWith(
                                            color: widget.selectedIndex == index
                                                ? MailColors.white
                                                : scheme.onSurfaceVariant,
                                          ),
                                          child: Text(
                                            widget.labels[index],
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
