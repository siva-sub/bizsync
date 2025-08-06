import 'dart:ui';
import 'package:flutter/material.dart';
import 'mesa_rendering_detector.dart';

/// Global configuration for Mesa-safe rendering
/// This class provides centralized control over rendering features
/// that may cause issues with Mesa software rendering on Linux
class MesaRenderingConfig {
  static final MesaRenderingConfig _instance = MesaRenderingConfig._internal();

  factory MesaRenderingConfig() => _instance;

  MesaRenderingConfig._internal();

  /// Whether Mesa software rendering is detected
  bool get isMesaActive => MesaRenderingDetector.isMesaSoftwareRendering;

  /// Configuration flags
  bool _disableShadows = false;
  bool _disableElevation = false;
  bool _disableBlur = false;
  bool _reduceAnimations = false;

  /// Initialize the configuration based on Mesa detection
  void initialize() {
    if (isMesaActive) {
      _disableShadows = true;
      _disableElevation = true;
      _disableBlur = true;
      _reduceAnimations = true;
      debugPrint(
          'MesaRenderingConfig: Initialized with Mesa workarounds enabled');
    }
  }

  /// Get safe box shadow (returns null if shadows are disabled)
  List<BoxShadow>? getSafeBoxShadow(List<BoxShadow>? shadows) {
    if (_disableShadows || shadows == null) {
      return null;
    }
    return shadows;
  }

  /// Get safe elevation value
  double getSafeElevation(double elevation) {
    if (_disableElevation) {
      return 0.0;
    }
    // Reduce elevation slightly even when not fully disabled
    if (isMesaActive && elevation > 0) {
      return elevation * 0.3;
    }
    return elevation;
  }

  /// Get safe shadow color
  Color getSafeShadowColor(Color color) {
    if (_disableShadows) {
      return Colors.transparent;
    }
    // Reduce opacity for Mesa
    if (isMesaActive) {
      return color.withOpacity(0.3);
    }
    return color;
  }

  /// Get safe blur sigma values
  double getSafeBlurSigma(double sigma) {
    if (_disableBlur) {
      return 0.0;
    }
    // Reduce blur intensity for Mesa
    if (isMesaActive && sigma > 0) {
      return sigma * 0.5;
    }
    return sigma;
  }

  /// Get safe image filter for blur effects
  ImageFilter? getSafeImageFilter(double sigmaX, double sigmaY) {
    if (_disableBlur) {
      return null;
    }
    return ImageFilter.blur(
      sigmaX: getSafeBlurSigma(sigmaX),
      sigmaY: getSafeBlurSigma(sigmaY),
    );
  }

  /// Get safe animation duration
  Duration getSafeAnimationDuration(Duration duration) {
    if (_reduceAnimations) {
      // Reduce animation duration by 50% for smoother performance
      return Duration(milliseconds: duration.inMilliseconds ~/ 2);
    }
    return duration;
  }

  /// Get safe box decoration with Mesa workarounds
  BoxDecoration? getSafeBoxDecoration(BoxDecoration? decoration) {
    if (decoration == null || !isMesaActive) {
      return decoration;
    }

    return BoxDecoration(
      color: decoration.color,
      image: decoration.image,
      border: decoration.border,
      borderRadius: decoration.borderRadius,
      boxShadow: getSafeBoxShadow(decoration.boxShadow),
      gradient: decoration.gradient,
      backgroundBlendMode: decoration.backgroundBlendMode,
      shape: decoration.shape,
    );
  }

  /// Create a safe theme data with Mesa workarounds
  ThemeData applySafeTheme(ThemeData theme) {
    if (!isMesaActive) {
      return theme;
    }

    return theme.copyWith(
      // Disable all shadows in the theme
      shadowColor: _disableShadows ? Colors.transparent : theme.shadowColor,

      // Adjust card theme
      cardTheme: theme.cardTheme.copyWith(
        elevation: getSafeElevation(theme.cardTheme.elevation ?? 1.0),
        shadowColor:
            _disableShadows ? Colors.transparent : theme.cardTheme.shadowColor,
      ),

      // Adjust app bar theme
      appBarTheme: theme.appBarTheme.copyWith(
        elevation: getSafeElevation(theme.appBarTheme.elevation ?? 4.0),
        shadowColor: _disableShadows
            ? Colors.transparent
            : theme.appBarTheme.shadowColor,
      ),

      // Adjust elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: theme.elevatedButtonTheme.style?.copyWith(
          elevation: MaterialStateProperty.all(
            getSafeElevation(2.0),
          ),
          shadowColor: MaterialStateProperty.all(
            _disableShadows ? Colors.transparent : null,
          ),
        ),
      ),

      // Adjust floating action button theme
      floatingActionButtonTheme: theme.floatingActionButtonTheme.copyWith(
        elevation:
            getSafeElevation(theme.floatingActionButtonTheme.elevation ?? 6.0),
        disabledElevation: getSafeElevation(
            theme.floatingActionButtonTheme.disabledElevation ?? 0.0),
        highlightElevation: getSafeElevation(
            theme.floatingActionButtonTheme.highlightElevation ?? 12.0),
      ),

      // Adjust dialog theme
      dialogTheme: theme.dialogTheme.copyWith(
        elevation: getSafeElevation(theme.dialogTheme.elevation ?? 24.0),
      ),

      // Adjust bottom sheet theme
      bottomSheetTheme: theme.bottomSheetTheme.copyWith(
        elevation: getSafeElevation(theme.bottomSheetTheme.elevation ?? 0.0),
        modalElevation:
            getSafeElevation(theme.bottomSheetTheme.modalElevation ?? 1.0),
      ),

      // Adjust navigation bar theme
      navigationBarTheme: theme.navigationBarTheme.copyWith(
        elevation: getSafeElevation(theme.navigationBarTheme.elevation ?? 0.0),
      ),

      // Adjust drawer theme
      drawerTheme: theme.drawerTheme.copyWith(
        elevation: getSafeElevation(theme.drawerTheme.elevation ?? 16.0),
      ),
    );
  }
}
