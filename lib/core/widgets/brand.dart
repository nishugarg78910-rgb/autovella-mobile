import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The Autovella mark, picking the artwork that suits the background.
///
/// Two assets ship: the navy mark for light surfaces and the white mark for
/// dark ones. Using the wrong one produces navy-on-navy, which is how the
/// logo disappeared in the first build.
class AutovellaMark extends StatelessWidget {
  const AutovellaMark({super.key, this.height = 40, this.onDark});

  final double height;

  /// Forces a variant. When null it follows the ambient theme brightness.
  final bool? onDark;

  @override
  Widget build(BuildContext context) {
    final dark = onDark ?? Theme.of(context).brightness == Brightness.dark;
    return Image.asset(
      dark ? 'assets/images/logo_on_dark.png' : 'assets/images/logo_on_light.png',
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      // If the asset is ever missing, fall back to something shaped like the
      // mark rather than showing a broken-image glyph.
      errorBuilder: (context, _, __) => Icon(
        Icons.change_history_rounded,
        size: height,
        color: dark ? Colors.white : AppColors.slate900,
      ),
    );
  }
}

/// Mark + wordmark + tagline, stacked and centred — the full brand lockup
/// used on the login screen and splash.
class AutovellaLockup extends StatelessWidget {
  const AutovellaLockup({
    super.key,
    this.height = 64,
    this.showTagline = true,
    this.onDark,
  });

  final double height;
  final bool showTagline;
  final bool? onDark;

  @override
  Widget build(BuildContext context) {
    final dark = onDark ?? Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? Colors.white : AppColors.slate900;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AutovellaMark(height: height, onDark: dark),
        const SizedBox(height: AppSpacing.md),
        Text(
          'AUTOVELLA',
          style: TextStyle(
            color: ink,
            fontSize: height * 0.36,
            fontWeight: FontWeight.w600,
            letterSpacing: height * 0.11,
          ),
        ),
        if (showTagline) ...[
          const SizedBox(height: AppSpacing.sm),
          _Tagline(onDark: dark),
        ],
      ],
    );
  }
}

/// "One System . Every Workflow . Always Ahead", flanked by the brand's
/// violet and teal rules as in the master artwork.
class _Tagline extends StatelessWidget {
  const _Tagline({required this.onDark});

  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final ink = onDark ? Colors.white70 : AppColors.slate700;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 22, height: 1.4, color: AppColors.brandViolet),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            'One System  ·  Every Workflow  ·  Always Ahead',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ink,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Container(width: 22, height: 1.4, color: AppColors.brandTeal),
      ],
    );
  }
}
