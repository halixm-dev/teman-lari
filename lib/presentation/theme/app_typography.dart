import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  AppTypography._();

  static TextStyle get figtree => GoogleFonts.figtree();
  static TextStyle get figtreeBold =>
      GoogleFonts.figtree(fontWeight: FontWeight.w700);
  static TextStyle get figtreeExtraBold =>
      GoogleFonts.figtree(fontWeight: FontWeight.w800);

  static TextStyle get jetbrainsMono => GoogleFonts.jetBrainsMono();
  static String? get monoFamily => GoogleFonts.jetBrainsMono().fontFamily;

  static TextStyle get displayXl =>
      figtreeExtraBold.copyWith(fontSize: 48, height: 1.1);

  static TextStyle get displayLg =>
      figtreeBold.copyWith(fontSize: 36, height: 1.15);

  static TextStyle get displayMd =>
      figtreeBold.copyWith(fontSize: 28, height: 1.2);

  static TextStyle get headingLg =>
      figtree.copyWith(fontSize: 22, fontWeight: FontWeight.w600, height: 1.3);

  static TextStyle get headingMd =>
      figtree.copyWith(fontSize: 18, fontWeight: FontWeight.w600, height: 1.35);

  static TextStyle get headingSm =>
      figtree.copyWith(fontSize: 15, fontWeight: FontWeight.w600, height: 1.4);

  static TextStyle get bodyLg => figtree.copyWith(fontSize: 16, height: 1.6);

  static TextStyle get bodyMd => figtree.copyWith(fontSize: 14, height: 1.55);

  static TextStyle get bodySm => figtree.copyWith(fontSize: 13, height: 1.5);

  static TextStyle get caption =>
      figtree.copyWith(fontSize: 11, fontWeight: FontWeight.w500, height: 1.4);

  static TextStyle get statHero => jetbrainsMono.copyWith(
    fontSize: 42,
    fontWeight: FontWeight.w800,
    height: 1.0,
  );

  static TextStyle get statUnit =>
      figtree.copyWith(fontSize: 16, fontWeight: FontWeight.w500, height: 1.0);

  static TextStyle get statValue =>
      jetbrainsMono.copyWith(fontSize: 24, fontWeight: FontWeight.w700);

  static TextStyle get statLabel => caption.copyWith(letterSpacing: 0.05);
}

/// Alias for [AppTypography] per design system naming convention.
typedef AppTextStyles = AppTypography;
