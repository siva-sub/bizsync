import 'package:flutter/material.dart';
import '../stubs/custom_snackbar_stub.dart';

// Re-export the stub implementation
export '../stubs/custom_snackbar_stub.dart';

// Stub functions to replace missing top_snackbar_flutter functionality
void showTopSnackBar(OverlayState overlayState, Widget snackBar,
    {Duration? displayDuration}) {
  ScaffoldMessenger.of(overlayState.context).showSnackBar(
    SnackBar(
        content: snackBar,
        duration: displayDuration ?? const Duration(seconds: 3)),
  );
}

/// Animation utilities for toast notifications
class AnimatedToast {
  static const Duration defaultDuration = Duration(milliseconds: 300);
  static const Duration defaultDisplayDuration = Duration(seconds: 3);

  /// Show success toast
  static void showSuccess(BuildContext context, String message) {
    CustomSnackBar.show(
      context,
      CustomSnackBar.success(message: message),
    );
  }

  /// Show error toast
  static void showError(BuildContext context, String message) {
    CustomSnackBar.show(
      context,
      CustomSnackBar.error(message: message),
    );
  }

  /// Show warning toast
  static void showWarning(BuildContext context, String message) {
    CustomSnackBar.show(
      context,
      CustomSnackBar.warning(message: message),
    );
  }

  /// Show info toast
  static void showInfo(BuildContext context, String message) {
    CustomSnackBar.show(
      context,
      CustomSnackBar.info(message: message),
    );
  }
}

/// Extension methods for BuildContext to show toast messages
extension ToastExtension on BuildContext {
  void showSuccessToast(String message) {
    AnimatedToast.showSuccess(this, message);
  }

  void showErrorToast(String message) {
    AnimatedToast.showError(this, message);
  }

  void showWarningToast(String message) {
    AnimatedToast.showWarning(this, message);
  }

  void showInfoToast(String message) {
    AnimatedToast.showInfo(this, message);
  }

  void showLoadingToast(String message) {
    AnimatedToast.showInfo(this, message); // Use info style for loading
  }
}

/// Legacy support for old toast animations
class ToastAnimation {
  static void slideFromTop(BuildContext context, Widget child) {
    showTopSnackBar(Overlay.of(context), child);
  }

  static void slideFromBottom(BuildContext context, Widget child) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: child,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static void fadeIn(BuildContext context, Widget child) {
    showTopSnackBar(Overlay.of(context), child);
  }
}
