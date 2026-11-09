import 'package:flutter/material.dart';

/// Small visual identity marker derived from `MailAccount.colorValue`.
class AccountColorBadge extends StatelessWidget {
  const AccountColorBadge({
    super.key,
    required this.colorValue,
    this.label,
    this.size = 10,
    this.showLabel = false,
  });

  final int colorValue;
  final String? label;
  final double size;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final color = Color(colorValue);
    final dot = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.25),
            blurRadius: 1.5,
            spreadRadius: 0.5,
          ),
        ],
      ),
    );
    if (!showLabel || label == null || label!.isEmpty) return dot;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          dot,
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
