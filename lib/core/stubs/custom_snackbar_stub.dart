/// Stub implementation for CustomSnackBar functionality
/// This replaces the external custom_snackbar package with a simple implementation

import 'package:flutter/material.dart';
import '../utils/mesa_rendering_detector.dart';

class CustomSnackBar extends StatelessWidget {
  final String message;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final double? iconPositionTop;
  final double? iconRotationAngle;
  final Duration? animationDuration;
  final Duration? reverseAnimationDuration;
  final VoidCallback? onTap;
  final IconData? icon;
  final TextStyle? textStyle;

  const CustomSnackBar({
    super.key,
    required this.message,
    this.backgroundColor,
    this.borderRadius,
    this.iconPositionTop,
    this.iconRotationAngle,
    this.animationDuration,
    this.reverseAnimationDuration,
    this.onTap,
    this.icon,
    this.textStyle,
  });

  /// Success snackbar constructor
  const CustomSnackBar.success({
    super.key,
    required this.message,
    this.backgroundColor = const Color(0xFF4CAF50),
    this.borderRadius,
    this.iconPositionTop,
    this.iconRotationAngle,
    this.animationDuration,
    this.reverseAnimationDuration,
    this.onTap,
    this.textStyle,
  }) : icon = Icons.check_circle;

  /// Error snackbar constructor
  const CustomSnackBar.error({
    super.key,
    required this.message,
    this.backgroundColor = const Color(0xFFF44336),
    this.borderRadius,
    this.iconPositionTop,
    this.iconRotationAngle,
    this.animationDuration,
    this.reverseAnimationDuration,
    this.onTap,
    this.textStyle,
  }) : icon = Icons.error;

  /// Warning snackbar constructor
  const CustomSnackBar.warning({
    super.key,
    required this.message,
    this.backgroundColor = const Color(0xFFFF9800),
    this.borderRadius,
    this.iconPositionTop,
    this.iconRotationAngle,
    this.animationDuration,
    this.reverseAnimationDuration,
    this.onTap,
    this.textStyle,
  }) : icon = Icons.warning;

  /// Info snackbar constructor
  const CustomSnackBar.info({
    super.key,
    required this.message,
    this.backgroundColor = const Color(0xFF2196F3),
    this.borderRadius,
    this.iconPositionTop,
    this.iconRotationAngle,
    this.animationDuration,
    this.reverseAnimationDuration,
    this.onTap,
    this.textStyle,
  }) : icon = Icons.info;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor ?? Theme.of(context).colorScheme.primary,
        borderRadius: borderRadius ?? BorderRadius.circular(8),
        boxShadow: MesaRenderingDetector.shouldDisableShadows
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                message,
                style: textStyle ??
                    const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show the custom snackbar in the current context
  static void show(BuildContext context, CustomSnackBar snackBar) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: snackBar,
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        duration: snackBar.animationDuration ?? const Duration(seconds: 3),
      ),
    );
  }
}
