import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/common.dart';
import '../util/format.dart';
import '../theme/tokens.dart';

/// Circular avatar that falls back to tinted initials.
///
/// Autovella stores avatars as base64 data URIs in some payloads and as URLs
/// in others; both are handled, and a missing avatar degrades to initials
/// rather than a grey blob.
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.initials,
    this.imageUrl,
    this.size = 36,
    this.tint,
    this.maxInitials = 2,
  });

  Avatar.user(
    UserRef user, {
    super.key,
    this.size = 36,
    this.maxInitials = 2,
  })  : initials = user.initials,
        imageUrl = user.avatar,
        tint = user.tint;

  final String initials;
  final String? imageUrl;
  final double size;
  final Color? tint;

  /// Caps how many letters are drawn. Overlapping stacks pass 1: the avatar
  /// to the right covers roughly a third of this one, which clips the second
  /// letter and makes two different people look identical.
  final int maxInitials;

  @override
  Widget build(BuildContext context) {
    final color = tint ?? AppColors.brand600;
    final url = imageUrl;
    final isNetwork = url != null && url.startsWith('http');

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: isNetwork
          ? CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _initials(color),
              placeholder: (_, __) => _initials(color),
            )
          : _initials(color),
    );
  }

  Widget _initials(Color color) {
    final text = initials.length > maxInitials
        ? initials.substring(0, maxInitials)
        : initials;
    return Center(
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: size * (maxInitials == 1 ? 0.44 : 0.36),
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

/// Overlapping avatars with a `+N` overflow counter.
class AvatarStack extends StatelessWidget {
  const AvatarStack({
    super.key,
    required this.users,
    this.max = 3,
    this.size = 26,
  });

  final List<UserRef> users;
  final int max;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) return const SizedBox.shrink();
    final shown = users.take(max).toList();
    final overflow = users.length - shown.length;
    final overlap = size * 0.3;
    final surface = Theme.of(context).colorScheme.surface;

    return SizedBox(
      height: size,
      width: shown.length * (size - overlap) +
          overlap +
          (overflow > 0 ? size - overlap : 0),
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * (size - overlap),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: surface, width: 2),
                ),
                child: Avatar.user(shown[i], size: size, maxInitials: 1),
              ),
            ),
          if (overflow > 0)
            Positioned(
              left: shown.length * (size - overlap),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: AppColors.slate200,
                  shape: BoxShape.circle,
                  border: Border.all(color: surface, width: 2),
                ),
                child: Center(
                  child: Text(
                    '+$overflow',
                    style: TextStyle(
                      fontSize: size * 0.32,
                      fontWeight: FontWeight.w700,
                      color: AppColors.slate600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Coloured pill for a status or priority value.
class ToneChip extends StatelessWidget {
  const ToneChip(this.tone, {super.key, this.dense = false, this.icon});

  ToneChip.status(String? value, {super.key, this.dense = false, this.icon})
      : tone = Tone.status(value);

  ToneChip.priority(String? value, {super.key, this.dense = false, this.icon})
      : tone = Tone.priority(value);

  final Tone tone;
  final bool dense;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Soft pastel backgrounds read as mud on a dark ground, so in dark mode
    // the fill becomes a low-alpha wash of the foreground colour instead.
    final bg = dark ? tone.fg.withValues(alpha: 0.16) : tone.bg;
    final fg = dark ? _lift(tone.fg) : tone.fg;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 6 : 8,
        vertical: dense ? 2 : 4,
      ),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.rSm),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 10 : 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            tone.label,
            style: TextStyle(
              color: fg,
              fontSize: dense ? 10.5 : 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  /// Nudges a colour brighter so it keeps contrast on dark backgrounds.
  static Color _lift(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + 0.22).clamp(0.0, 1.0)).toColor();
  }
}

/// A bordered surface — the base for every list row and panel.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.accentColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  /// Draws a 3px rail down the leading edge — used to carry a project's
  /// colour onto its rows.
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: AppRadius.rLg,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.rLg,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: AppRadius.rLg,
            border: Border.all(color: scheme.outline),
          ),
          child: Stack(
            children: [
              if (accentColor != null)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(AppRadius.lg),
                      ),
                    ),
                  ),
                ),
              Padding(padding: padding, child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// A labelled metric, used across dashboards.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.delta,
    this.deltaPositive,
    this.icon,
    this.accent,
    this.onTap,
  });

  /// A money tile, with the scale unit (L, Cr, K, M) set apart from the
  /// digits so "0M" cannot read as "OM".
  factory StatTile.money(
    num? amount, {
    Key? key,
    required String label,
    String? currency,
    String? delta,
    bool? deltaPositive,
    IconData? icon,
    Color? accent,
    VoidCallback? onTap,
  }) {
    final (symbol, number, unit) =
        Fmt.moneyParts(amount, currency: currency);
    return StatTile(
      key: key,
      label: label,
      value: '$symbol$number',
      unit: unit,
      delta: delta,
      deltaPositive: deltaPositive,
      icon: icon,
      accent: accent,
      onTap: onTap,
    );
  }

  final String label;
  final String value;

  /// Rendered smaller and lighter, immediately after [value].
  final String? unit;
  final String? delta;
  final bool? deltaPositive;
  final IconData? icon;
  final Color? accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = accent ?? theme.colorScheme.primary;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.12),
                    borderRadius: AppRadius.rSm,
                  ),
                  child: Icon(icon, size: 13, color: tint),
                ),
                const SizedBox(width: 7),
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
          const SizedBox(height: AppSpacing.sm),
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
                  maxLines: 1,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    fontSize: 22,
                  ),
                ),
                if (unit != null && unit!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 1.5),
                    child: Text(
                      unit!,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (delta != null) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  deltaPositive == true
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  size: 13,
                  color: deltaPositive == true
                      ? AppColors.success
                      : AppColors.danger,
                ),
                const SizedBox(width: 3),
                Text(
                  delta!,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: deltaPositive == true
                        ? AppColors.success
                        : AppColors.danger,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Slim progress rail used on projects, sprints and budgets.
class ProgressRail extends StatelessWidget {
  const ProgressRail({
    super.key,
    required this.value,
    this.color,
    this.height = 6,
  });

  final double value;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: scheme.surfaceContainerHighest,
        valueColor: AlwaysStoppedAnimation(color ?? scheme.primary),
      ),
    );
  }
}

/// `Label · value` row used throughout detail sheets.
class DetailRow extends StatelessWidget {
  const DetailRow({
    super.key,
    required this.label,
    this.value,
    this.child,
    this.icon,
  });

  final String label;
  final String? value;
  final Widget? child;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: child ??
                Text(
                  value?.isNotEmpty == true ? value! : '—',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

/// Small caps section label.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.action, this.onAction});

  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm, top: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 11,
                letterSpacing: 0.7,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                action!,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
