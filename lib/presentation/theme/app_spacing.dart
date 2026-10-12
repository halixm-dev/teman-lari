import 'package:flutter/material.dart';

class AppSpacing {
  AppSpacing._();

  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space8 = 32;
  static const double space10 = 40;
  static const double space12 = 48;
  static const double space16 = 64;

  // Design system aliases (docs/design.md)
  static const double s4 = space1;
  static const double s8 = space2;
  static const double s12 = space3;
  static const double s16 = space4;
  static const double s20 = space5;
  static const double s24 = space6;
  static const double s32 = space8;
  static const double s40 = space10;
  static const double s48 = space12;
  static const double s64 = space16;

  // Edge insets
  static const EdgeInsets cardPadding = EdgeInsets.all(space4);
  static const EdgeInsets pagePadding = EdgeInsets.all(space4);
  static const EdgeInsets pagePaddingWide = EdgeInsets.symmetric(
    horizontal: space6,
    vertical: space4,
  );

  // Radius
  static const double radiusSm = 4;
  static const double radiusMd = 8;
  static const double radiusLg = 12;
  static const double radiusXl = 16;
  static const double radius2xl = 24;
  static const double radiusFull = 9999;
}

/// Border radius tokens per docs/design.md
class AppRadius {
  AppRadius._();

  static const double sm = 4;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 16;
  static const double xxl = 24;
  static const double full = 9999;
}
