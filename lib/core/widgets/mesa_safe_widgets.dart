import 'dart:ui';
import 'package:flutter/material.dart';
import '../utils/mesa_rendering_config.dart';

/// A Card widget that automatically adjusts its rendering based on Mesa detection
class MesaSafeCard extends StatelessWidget {
  final Widget? child;
  final Color? color;
  final Color? shadowColor;
  final Color? surfaceTintColor;
  final double? elevation;
  final ShapeBorder? shape;
  final bool borderOnForeground;
  final EdgeInsetsGeometry? margin;
  final Clip? clipBehavior;
  final bool semanticContainer;
  
  const MesaSafeCard({
    Key? key,
    this.color,
    this.shadowColor,
    this.surfaceTintColor,
    this.elevation,
    this.shape,
    this.borderOnForeground = true,
    this.margin,
    this.clipBehavior,
    this.child,
    this.semanticContainer = true,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final config = MesaRenderingConfig();
    
    return Card(
      color: color,
      shadowColor: config.isMesaActive ? Colors.transparent : shadowColor,
      surfaceTintColor: surfaceTintColor,
      elevation: config.getSafeElevation(elevation ?? 1.0),
      shape: shape,
      borderOnForeground: borderOnForeground,
      margin: margin,
      clipBehavior: clipBehavior,
      semanticContainer: semanticContainer,
      child: child,
    );
  }
}

/// A Container widget that automatically adjusts its decoration based on Mesa detection
class MesaSafeContainer extends StatelessWidget {
  final Widget? child;
  final AlignmentGeometry? alignment;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Decoration? decoration;
  final Decoration? foregroundDecoration;
  final double? width;
  final double? height;
  final BoxConstraints? constraints;
  final EdgeInsetsGeometry? margin;
  final Matrix4? transform;
  final AlignmentGeometry? transformAlignment;
  final Clip clipBehavior;
  
  const MesaSafeContainer({
    Key? key,
    this.alignment,
    this.padding,
    this.color,
    this.decoration,
    this.foregroundDecoration,
    this.width,
    this.height,
    this.constraints,
    this.margin,
    this.transform,
    this.transformAlignment,
    this.child,
    this.clipBehavior = Clip.none,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final config = MesaRenderingConfig();
    
    Decoration? safeDecoration = decoration;
    if (decoration is BoxDecoration) {
      safeDecoration = config.getSafeBoxDecoration(decoration as BoxDecoration);
    }
    
    Decoration? safeForegroundDecoration = foregroundDecoration;
    if (foregroundDecoration is BoxDecoration) {
      safeForegroundDecoration = config.getSafeBoxDecoration(foregroundDecoration as BoxDecoration);
    }
    
    return Container(
      alignment: alignment,
      padding: padding,
      color: color,
      decoration: safeDecoration,
      foregroundDecoration: safeForegroundDecoration,
      width: width,
      height: height,
      constraints: constraints,
      margin: margin,
      transform: transform,
      transformAlignment: transformAlignment,
      clipBehavior: clipBehavior,
      child: child,
    );
  }
}

/// A Material widget that automatically adjusts its elevation based on Mesa detection
class MesaSafeMaterial extends StatelessWidget {
  final Widget? child;
  final MaterialType type;
  final double elevation;
  final Color? color;
  final Color? shadowColor;
  final Color? surfaceTintColor;
  final TextStyle? textStyle;
  final ShapeBorder? shape;
  final bool borderOnForeground;
  final Clip clipBehavior;
  final Duration animationDuration;
  final BorderRadiusGeometry? borderRadius;
  
  const MesaSafeMaterial({
    Key? key,
    this.type = MaterialType.canvas,
    this.elevation = 0.0,
    this.color,
    this.shadowColor,
    this.surfaceTintColor,
    this.textStyle,
    this.shape,
    this.borderOnForeground = true,
    this.clipBehavior = Clip.none,
    this.animationDuration = kThemeChangeDuration,
    this.borderRadius,
    this.child,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final config = MesaRenderingConfig();
    
    return Material(
      type: type,
      elevation: config.getSafeElevation(elevation),
      color: color,
      shadowColor: config.isMesaActive ? Colors.transparent : shadowColor,
      surfaceTintColor: surfaceTintColor,
      textStyle: textStyle,
      shape: shape,
      borderOnForeground: borderOnForeground,
      clipBehavior: clipBehavior,
      animationDuration: config.getSafeAnimationDuration(animationDuration),
      borderRadius: borderRadius,
      child: child,
    );
  }
}

/// A BackdropFilter widget that automatically disables blur based on Mesa detection
class MesaSafeBackdropFilter extends StatelessWidget {
  final ImageFilter? filter;
  final Widget? child;
  final BlendMode blendMode;
  
  const MesaSafeBackdropFilter({
    Key? key,
    required this.filter,
    this.child,
    this.blendMode = BlendMode.srcOver,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final config = MesaRenderingConfig();
    
    // If Mesa is active and blur should be disabled, just return the child
    if (config.isMesaActive) {
      return child ?? const SizedBox.shrink();
    }
    
    return BackdropFilter(
      filter: filter ?? ImageFilter.blur(sigmaX: 0, sigmaY: 0),
      blendMode: blendMode,
      child: child,
    );
  }
}

/// A convenient blur widget that automatically adjusts based on Mesa detection
class MesaSafeBlur extends StatelessWidget {
  final Widget child;
  final double sigmaX;
  final double sigmaY;
  final BlendMode blendMode;
  
  const MesaSafeBlur({
    Key? key,
    required this.child,
    this.sigmaX = 10.0,
    this.sigmaY = 10.0,
    this.blendMode = BlendMode.srcOver,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final config = MesaRenderingConfig();
    
    // If Mesa is active, just return the child without blur
    if (config.isMesaActive) {
      return child;
    }
    
    return BackdropFilter(
      filter: ImageFilter.blur(
        sigmaX: config.getSafeBlurSigma(sigmaX),
        sigmaY: config.getSafeBlurSigma(sigmaY),
      ),
      blendMode: blendMode,
      child: child,
    );
  }
}

/// Helper function to create safe box shadows
List<BoxShadow>? createMesaSafeBoxShadow({
  Color color = const Color(0x33000000),
  Offset offset = const Offset(0, 2),
  double blurRadius = 4.0,
  double spreadRadius = 0.0,
}) {
  final config = MesaRenderingConfig();
  
  if (config.isMesaActive) {
    return null;
  }
  
  return [
    BoxShadow(
      color: config.getSafeShadowColor(color),
      offset: offset,
      blurRadius: blurRadius,
      spreadRadius: spreadRadius,
    ),
  ];
}

/// Helper function to create safe elevation
double getMesaSafeElevation(double elevation) {
  return MesaRenderingConfig().getSafeElevation(elevation);
}