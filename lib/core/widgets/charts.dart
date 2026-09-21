import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../util/format.dart';

/// A progress ring with the value in the middle.
///
/// Used for one number that is a share of a whole — completion, utilisation,
/// budget burn. A ring earns its place over a bar only when it is the hero of
/// a card; for comparing several values, bars win every time.
class MetricRing extends StatelessWidget {
  const MetricRing({
    super.key,
    required this.value,
    required this.label,
    this.caption,
    this.size = 108,
    this.color,
    this.trackColor,
  });

  /// 0–1.
  final double value;
  final String label;
  final String? caption;
  final double size;
  final Color? color;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = color ?? theme.colorScheme.primary;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _RingPainter(
              value: value.clamp(0, 1),
              color: tint,
              track: trackColor ?? theme.colorScheme.surfaceContainerHighest,
              stroke: size * 0.10,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                  fontSize: size * 0.24,
                  height: 1.1,
                ),
              ),
              if (caption != null)
                Text(
                  caption!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: size * 0.10,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.color,
    required this.track,
    required this.stroke,
  });

  final double value;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);

    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, trackPaint);

    if (value <= 0) return;
    final valuePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      valuePaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.track != track;
}

/// A single row in a labelled bar list.
class BarDatum {
  const BarDatum({
    required this.label,
    required this.value,
    this.caption,
    this.color,
  });

  final String label;
  final double value;

  /// Shown on the right instead of the raw number.
  final String? caption;

  /// Overrides the single hue. Use only where the colour carries meaning that
  /// the label already states — a status the row is named after, for example.
  final Color? color;
}

/// Horizontal bars: one hue, direct labels, recessive track.
///
/// Built from plain widgets rather than a charting package so the mark specs
/// hold exactly — 4px rounded data-ends, 8px bars, no gridlines competing
/// with the data.
class BarList extends StatelessWidget {
  const BarList({
    super.key,
    required this.rows,
    this.maxOverride,
    this.valueFormatter,
    this.dense = false,
  });

  final List<BarDatum> rows;
  final double? maxOverride;
  final String Function(double)? valueFormatter;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (rows.isEmpty) return const SizedBox.shrink();

    final max = maxOverride ??
        rows.fold<double>(0, (m, r) => r.value > m ? r.value : m);
    final safeMax = max <= 0 ? 1.0 : max;
    final gap = dense ? AppSpacing.sm : AppSpacing.md;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          Row(
            children: [
              Expanded(
                child: Text(
                  rows[i].label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                rows[i].caption ??
                    valueFormatter?.call(rows[i].value) ??
                    Fmt.number(rows[i].value),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          LayoutBuilder(
            builder: (context, constraints) {
              final fraction = (rows[i].value / safeMax).clamp(0.0, 1.0);
              return Stack(
                children: [
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  AnimatedContainer(
                    duration: AppMotion.slow,
                    curve: AppMotion.easeOut,
                    height: 8,
                    width: (constraints.maxWidth * fraction)
                        .clamp(fraction > 0 ? 4.0 : 0.0, constraints.maxWidth),
                    decoration: BoxDecoration(
                      color: rows[i].color ?? theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}

/// A compact stacked bar showing parts of a whole on one line, with a legend
/// underneath. Each segment is separated by a 2px surface gap so adjacent
/// fills never read as one.
class StackedBar extends StatelessWidget {
  const StackedBar({super.key, required this.segments, this.height = 10});

  final List<BarDatum> segments;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = segments.fold<double>(0, (s, e) => s + e.value);
    if (total <= 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: SizedBox(
            height: height,
            // Explicit width: this sits in a Column aligned to `start`, so
            // without it the box shrink-wraps a Row whose children are all
            // Expanded — intrinsic width zero, and the bar vanishes.
            width: double.infinity,
            child: Row(
              // Stretch: a childless ColoredBox has no intrinsic height, so
              // under the default centre alignment every segment collapses to
              // a zero-height sliver and the bar disappears entirely.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < segments.length; i++) ...[
                  if (i > 0)
                    SizedBox(
                      width: 2,
                      child: ColoredBox(color: theme.colorScheme.surface),
                    ),
                  Expanded(
                    flex: (segments[i].value * 1000).round().clamp(1, 1000000),
                    child: ColoredBox(
                      color: segments[i].color ?? theme.colorScheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: 6,
          children: [
            for (final s in segments)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: s.color ?? theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${s.label} ${s.caption ?? Fmt.number(s.value)}',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

/// A headline number with an optional ring or bar beneath — the hero of a
/// metric card.
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.caption,
    this.icon,
    this.accent,
    this.progress,
    this.onTap,
  });

  final String label;
  final String value;
  final String? unit;
  final String? caption;
  final IconData? icon;
  final Color? accent;

  /// 0–1; draws a slim bar under the number when supplied.
  final double? progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = accent ?? theme.colorScheme.primary;

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: AppRadius.rLg,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.rLg,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: AppRadius.rLg,
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (icon != null) ...[
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: tint.withValues(alpha: 0.12),
                          borderRadius: AppRadius.rSm,
                        ),
                        child: Icon(icon, size: 14, color: tint),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        value,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.8,
                          fontSize: 26,
                          height: 1,
                        ),
                      ),
                      if (unit != null && unit!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: Text(
                            unit!,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (progress != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress!.clamp(0, 1),
                      minHeight: 5,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(tint),
                    ),
                  ),
                ],
                if (caption != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    caption!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
