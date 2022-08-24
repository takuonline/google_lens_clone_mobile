import 'package:flutter/material.dart';




class SizeConfig {
  static late double screenWidth;
  static late double screenHeight;
  static late double safeBlockHorizontal;
  static late double safeBlockVertical;

  /// Updates the configuration with a fresh BuildContext
  static init(BuildContext context) {
    final MediaQueryData data = MediaQuery.of(context);
    screenWidth = data.size.width;
    screenHeight = data.size.height;
    final double safeAreaHorizontal = data.padding.left + data.padding.right;
    final double safeAreaVertical = data.padding.top + data.padding.bottom;
    safeBlockHorizontal = (screenWidth - safeAreaHorizontal) / 100;
    safeBlockVertical = (screenHeight - safeAreaVertical) / 100;
  }
}
