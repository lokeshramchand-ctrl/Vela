import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';

/// Text styles matching the design's three-font system:
/// Space Grotesk (amounts/headlines), Instrument Sans (body), IBM Plex Mono
/// (micro labels / meta / tabular data). Colors are applied at the call site
/// (AppColors.onDark / AppColors.onLight / semantic colors) since the same
/// role is reused on both dark and light surfaces.
/// Global `font-variant-numeric: tabular-nums` (per the design tokens) so
/// digits stay fixed-width - required for amounts to align in lists/columns.
TextStyle _t(TextStyle style) =>
    style.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

abstract final class AppTypography {
  // Space Grotesk - hero amounts & headlines
  static final TextStyle heroAmount44 = _t(
    GoogleFonts.spaceGrotesk(
      fontSize: 44,
      fontWeight: FontWeight.w700,
      height: 1,
      letterSpacing: -0.03 * 44,
    ),
  );
  static final TextStyle heroAmount40 = _t(
    GoogleFonts.spaceGrotesk(
      fontSize: 40,
      fontWeight: FontWeight.w700,
      height: 1,
      letterSpacing: -0.03 * 40,
    ),
  );
  static final TextStyle heroAmount36 = _t(
    GoogleFonts.spaceGrotesk(
      fontSize: 36,
      fontWeight: FontWeight.w700,
      height: 1,
      letterSpacing: -0.02 * 36,
    ),
  );
  static final TextStyle heroAmount34 = _t(
    GoogleFonts.spaceGrotesk(
      fontSize: 34,
      fontWeight: FontWeight.w700,
      height: 1,
      letterSpacing: -0.02 * 34,
    ),
  );
  static final TextStyle screenTitle24 = _t(
    GoogleFonts.spaceGrotesk(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.02 * 24,
    ),
  );
  static final TextStyle navTitle15 = _t(
    GoogleFonts.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.w600),
  );
  static final TextStyle bigHeadline32 = _t(
    GoogleFonts.spaceGrotesk(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      height: 1.2,
      letterSpacing: -0.03 * 32,
    ),
  );
  static final TextStyle bigHeadline26 = _t(
    GoogleFonts.spaceGrotesk(
      fontSize: 26,
      fontWeight: FontWeight.w700,
      height: 1.25,
      letterSpacing: -0.02 * 26,
    ),
  );
  static final TextStyle bigHeadline22 = _t(
    GoogleFonts.spaceGrotesk(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      height: 1.3,
      letterSpacing: -0.02 * 22,
    ),
  );
  static final TextStyle amountMedium20 = _t(
    GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.w600),
  );
  static final TextStyle amountMedium19 = _t(
    GoogleFonts.spaceGrotesk(fontSize: 19, fontWeight: FontWeight.w700),
  );
  static final TextStyle amountMedium17 = _t(
    GoogleFonts.spaceGrotesk(fontSize: 17, fontWeight: FontWeight.w600),
  );
  static final TextStyle amountMedium16 = _t(
    GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w600),
  );
  static final TextStyle amountMedium15 = _t(
    GoogleFonts.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.w600),
  );
  static final TextStyle amountMedium14 = _t(
    GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w600),
  );
  static final TextStyle amountSmall22 = _t(
    GoogleFonts.spaceGrotesk(fontSize: 22, fontWeight: FontWeight.w700),
  );
  static final TextStyle wordmark14 = _t(
    GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w600),
  );

  // Instrument Sans - body copy
  static final TextStyle signalBody17 = _t(
    GoogleFonts.instrumentSans(
      fontSize: 17,
      fontWeight: FontWeight.w500,
      height: 1.45,
    ),
  );
  static final TextStyle cardBody15 = _t(
    GoogleFonts.instrumentSans(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      height: 1.45,
    ),
  );
  static final TextStyle cardBody135 = _t(
    GoogleFonts.instrumentSans(
      fontSize: 13.5,
      fontWeight: FontWeight.w500,
      height: 1.5,
    ),
  );
  static final TextStyle body14 = _t(
    GoogleFonts.instrumentSans(fontSize: 14, fontWeight: FontWeight.w500),
  );
  static final TextStyle body13 = _t(
    GoogleFonts.instrumentSans(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      height: 1.5,
    ),
  );
  static final TextStyle rowLabel145 = _t(
    GoogleFonts.instrumentSans(fontSize: 14.5, fontWeight: FontWeight.w600),
  );
  static final TextStyle rowLabel14 = _t(
    GoogleFonts.instrumentSans(fontSize: 14, fontWeight: FontWeight.w600),
  );
  static final TextStyle buttonLabel15 = _t(
    GoogleFonts.instrumentSans(fontSize: 15, fontWeight: FontWeight.w600),
  );
  static final TextStyle buttonLabel14 = _t(
    GoogleFonts.instrumentSans(fontSize: 14, fontWeight: FontWeight.w600),
  );
  static final TextStyle buttonLabel12 = _t(
    GoogleFonts.instrumentSans(fontSize: 12, fontWeight: FontWeight.w600),
  );
  static final TextStyle buttonLabel13 = _t(
    GoogleFonts.instrumentSans(fontSize: 13, fontWeight: FontWeight.w600),
  );
  static final TextStyle footnote1155 = _t(
    GoogleFonts.instrumentSans(
      fontSize: 11.5,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),
  );
  static final TextStyle footnote12 = _t(
    GoogleFonts.instrumentSans(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.45,
    ),
  );
  static final TextStyle footnote15 = _t(
    GoogleFonts.instrumentSans(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      height: 1.55,
    ),
  );

  // IBM Plex Mono - micro labels / meta / tabular data
  static final TextStyle microLabel11 = _t(
    GoogleFonts.instrumentSans(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1 * 11,
    ),
  );
  static final TextStyle microLabelTracked105 = _t(
    GoogleFonts.instrumentSans(
      fontSize: 10.5,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1 * 10.5,
    ),
  );
  static final TextStyle microLabelTracked11 = _t(
    GoogleFonts.instrumentSans(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.12 * 11,
    ),
  );
  static final TextStyle meta115 = _t(
    GoogleFonts.instrumentSans(fontSize: 11.5, fontWeight: FontWeight.w500),
  );
  static final TextStyle meta12 = _t(
    GoogleFonts.instrumentSans(fontSize: 12, fontWeight: FontWeight.w500),
  );
  static final TextStyle metaBold12 = _t(
    GoogleFonts.instrumentSans(fontSize: 12, fontWeight: FontWeight.w600),
  );
  static final TextStyle badge95 = _t(
    GoogleFonts.instrumentSans(fontSize: 9.5, fontWeight: FontWeight.w600),
  );
  static final TextStyle badge10 = _t(
    GoogleFonts.instrumentSans(fontSize: 10, fontWeight: FontWeight.w600),
  );
}
