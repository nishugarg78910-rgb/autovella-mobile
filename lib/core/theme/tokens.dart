import 'package:flutter/material.dart';

/// Autovella design tokens.
///
/// The brand values here are not invented: they were read off the live web
/// platform at https://autovella.cloud (`:root` custom properties) so the
/// mobile client is the same brand as the web product, pixel for pixel.
///
///   --brand-600 #2563eb   --bg-app      #f8fafc   --text-primary   #0f172a
///   --brand-700 #1d4ed8   --bg-surface  #ffffff   --text-secondary #475569
///   --brand-50  #eff6ff   --bg-muted    #f1f5f9   --text-tertiary  #94a3b8
///   --border    #e5e7eb   --border-strong #d1d5db
///   --radius-sm 6  --radius-md 8  --radius-lg 12
///
/// The web app ships no dark theme. Mobile users expect one, so the dark
/// ramp below is derived from the same slate/blue hues rather than invented,
/// keeping the two surfaces recognisably one product.
class AppColors {
  const AppColors._();

  // ---- Brand ramp (blue) ----------------------------------------------
  static const brand50 = Color(0xFFEFF6FF);
  static const brand100 = Color(0xFFDBEAFE);
  static const brand200 = Color(0xFFBFDBFE);
  static const brand300 = Color(0xFF93C5FD);
  static const brand400 = Color(0xFF60A5FA);
  static const brand500 = Color(0xFF3B82F6);
  static const brand600 = Color(0xFF2563EB); // primary
  static const brand700 = Color(0xFF1D4ED8); // pressed / emphasis
  static const brand800 = Color(0xFF1E40AF);
  static const brand900 = Color(0xFF1E3A8A);

  // ---- Logo accents ----------------------------------------------------
  // Straight off the master artwork. The mark is navy with a violet swoosh
  // and three accent tiles; these are used for brand furniture (the tagline
  // rules, the splash) so the app and the logo agree.
  static const brandNavy = Color(0xFF0C1330);
  static const brandViolet = Color(0xFF5B4BE8);
  static const brandTeal = Color(0xFF0FB894);
  static const brandOrange = Color(0xFFF7860B);

  // ---- Slate ramp (neutrals) ------------------------------------------
  static const slate50 = Color(0xFFF8FAFC);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate400 = Color(0xFF94A3B8);
  static const slate500 = Color(0xFF64748B);
  static const slate600 = Color(0xFF475569);
  static const slate700 = Color(0xFF334155);
  static const slate800 = Color(0xFF1E293B);
  static const slate900 = Color(0xFF0F172A);
  static const slate950 = Color(0xFF020617);

  // ---- Light semantic surfaces ----------------------------------------
  static const bgApp = slate50;
  static const bgSurface = Color(0xFFFFFFFF);
  static const bgMuted = slate100;
  static const border = Color(0xFFE5E7EB);
  static const borderStrong = Color(0xFFD1D5DB);
  static const textPrimary = slate900;
  static const textSecondary = slate600;
  static const textTertiary = slate400;

  // ---- Dark semantic surfaces -----------------------------------------
  static const bgAppDark = slate950;
  static const bgSurfaceDark = Color(0xFF0B1220);
  static const bgMutedDark = slate800;
  static const borderDark = Color(0xFF1E293B);
  static const borderStrongDark = Color(0xFF334155);
  static const textPrimaryDark = Color(0xFFE2E8F0);
  static const textSecondaryDark = slate400;
  static const textTertiaryDark = slate500;

  /// The login hero panel on web is a dark navy gradient.
  static const heroGradientStart = Color(0xFF0C2340);
  static const heroGradientEnd = Color(0xFF17375E);

  // ---- Status palette --------------------------------------------------
  static const success = Color(0xFF16A34A);
  static const successSoft = Color(0xFFDCFCE7);
  static const warning = Color(0xFFD97706);
  static const warningSoft = Color(0xFFFEF3C7);
  static const danger = Color(0xFFDC2626);
  static const dangerSoft = Color(0xFFFEE2E2);
  static const info = brand600;
  static const infoSoft = brand50;
  static const neutral = slate500;
  static const neutralSoft = slate100;
  static const purple = Color(0xFF7C3AED);
  static const purpleSoft = Color(0xFFEDE9FE);
  static const teal = Color(0xFF0D9488);
  static const tealSoft = Color(0xFFCCFBF1);
}

/// Corner radii, mirroring `--radius-sm|md|lg` from the web app.
class AppRadius {
  const AppRadius._();
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 16;
  static const double pill = 999;

  static const rSm = BorderRadius.all(Radius.circular(sm));
  static const rMd = BorderRadius.all(Radius.circular(md));
  static const rLg = BorderRadius.all(Radius.circular(lg));
  static const rXl = BorderRadius.all(Radius.circular(xl));
  static const rPill = BorderRadius.all(Radius.circular(pill));
}

/// 4pt spacing scale.
class AppSpacing {
  const AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// Standard horizontal page gutter on phones.
  static const double gutter = 16;
}

/// Elevation, ported from the web `--shadow-*` values.
class AppShadows {
  const AppShadows._();

  static const xs = [
    BoxShadow(color: Color(0x0A0F172A), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const sm = [
    BoxShadow(color: Color(0x140F172A), blurRadius: 3, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0A0F172A), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const md = [
    BoxShadow(color: Color(0x140F172A), blurRadius: 12, offset: Offset(0, 4)),
  ];
  static const lg = [
    BoxShadow(color: Color(0x1A0F172A), blurRadius: 24, offset: Offset(0, 10)),
  ];
}

/// Motion, mirroring `--transition-fast|base` and `--ease-out`.
class AppMotion {
  const AppMotion._();
  static const easeOut = Cubic(0.16, 1, 0.3, 1);
  static const fast = Duration(milliseconds: 120);
  static const base = Duration(milliseconds: 180);
  static const slow = Duration(milliseconds: 280);
}
