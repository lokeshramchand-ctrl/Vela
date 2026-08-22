import 'dart:math' as math;
import 'dart:ui';

/// Builds a [Color] from an OKLCH triple, matching the CSS `oklch()` values
/// used verbatim in the Vela design tokens (see design/tokens.md).
///
/// [lightness] is 0-1 (design tokens are given as a %, e.g. `14.5%` -> 0.145).
/// [chroma] is unitless (e.g. `0.008`). [hue] is in degrees.
Color oklch(double lightness, double chroma, double hue, [double alpha = 1]) {
  final hueRad = hue * math.pi / 180;
  final a = chroma * math.cos(hueRad);
  final b = chroma * math.sin(hueRad);

  final lPrime = lightness + 0.3963377774 * a + 0.2158037573 * b;
  final mPrime = lightness - 0.1055613458 * a - 0.0638541728 * b;
  final sPrime = lightness - 0.0894841775 * a - 1.2914855480 * b;

  final l = lPrime * lPrime * lPrime;
  final m = mPrime * mPrime * mPrime;
  final s = sPrime * sPrime * sPrime;

  final rLinear = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s;
  final gLinear = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s;
  final bLinear = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s;

  return Color.fromARGB(
    (alpha.clamp(0, 1) * 255).round(),
    _toSrgbByte(rLinear),
    _toSrgbByte(gLinear),
    _toSrgbByte(bLinear),
  );
}

int _toSrgbByte(double linear) {
  final c = linear.clamp(0.0, 1.0);
  final srgb = c <= 0.0031308 ? 12.92 * c : 1.055 * math.pow(c, 1 / 2.4) - 0.055;
  return (srgb.clamp(0.0, 1.0) * 255).round();
}
