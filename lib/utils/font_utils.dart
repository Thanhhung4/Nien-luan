import 'package:flutter/material.dart';

/// Helper function to apply Vietnamese font to TextStyle
TextStyle vietnameseTextStyle({
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
  double? letterSpacing,
  double? height,
  TextDecoration? decoration,
  Color? decorationColor,
}) {
  return TextStyle(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
    decoration: decoration,
    decorationColor: decorationColor,
    fontFamily: 'Noto Sans',
  );
}

/// Extension to add Vietnamese font support to TextStyle
extension VietnameseTextStyle on TextStyle {
  TextStyle withVietnameseSupport() {
    return copyWith(fontFamily: 'Noto Sans');
  }
}
