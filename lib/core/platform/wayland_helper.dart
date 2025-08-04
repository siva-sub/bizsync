import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Helper class for Wayland-specific optimizations and platform detection
class WaylandHelper {
  static bool? _isWayland;
  static bool _optimizationsApplied = false;

  /// Check if the current session is running on Wayland
  static bool get isWayland {
    _isWayland ??= _detectWayland();
    return _isWayland!;
  }

  /// Detect if running on Wayland
  static bool _detectWayland() {
    if (!Platform.isLinux) return false;

    final env = Platform.environment;
    return env['XDG_SESSION_TYPE'] == 'wayland' ||
        env['WAYLAND_DISPLAY'] != null ||
        env['WAYLAND_OPTIMIZED'] == '1' ||
        env['GDK_BACKEND'] == 'wayland';
  }

  /// Apply Wayland-specific optimizations
  static Future<void> applyOptimizations() async {
    if (!isWayland || _optimizationsApplied) return;

    try {
      // Configure system chrome for Wayland
      _configureSystemChrome();

      // Set up rendering optimizations
      _configureRendering();

      // Configure window behavior
      _configureWindowBehavior();

      _optimizationsApplied = true;

      if (kDebugMode) {
        debugPrint('✅ Wayland optimizations applied successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️  Warning: Failed to apply Wayland optimizations: $e');
      }
    }
  }

  /// Configure system chrome for Wayland
  static void _configureSystemChrome() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  /// Configure rendering for smooth performance on Wayland
  static void _configureRendering() {
    // Enable high refresh rate rendering
    SchedulerBinding.instance.addPostFrameCallback((_) {
      SchedulerBinding.instance.ensureVisualUpdate();
    });

    // Force frame synchronization
    SchedulerBinding.instance.scheduleFrameCallback((timeStamp) {
      // This helps maintain consistent frame timing on Wayland
      SchedulerBinding.instance.ensureVisualUpdate();
    });
  }

  /// Configure window behavior for Wayland
  static void _configureWindowBehavior() {
    // Set up frame callback for smooth animations
    SchedulerBinding.instance.addPersistentFrameCallback((timeStamp) {
      // Ensure consistent frame delivery for animations
      SchedulerBinding.instance.ensureVisualUpdate();
    });
  }

  /// Get recommended animation duration for the current platform
  static Duration get animationDuration {
    if (isWayland) {
      // Slightly faster animations on Wayland for better perceived performance
      return const Duration(milliseconds: 200);
    }
    return const Duration(milliseconds: 250);
  }

  /// Get recommended animation curve for the current platform
  static Curve get animationCurve {
    if (isWayland) {
      // Use easeOutCubic for smoother animations on Wayland
      return Curves.easeOutCubic;
    }
    return Curves.easeInOut;
  }

  /// Check if hardware acceleration is available
  static bool get hasHardwareAcceleration {
    final env = Platform.environment;
    return env['LIBGL_ALWAYS_SOFTWARE'] != '1' &&
        env['HARDWARE_ACCELERATION_ENABLED'] == '1';
  }

  /// Get platform-specific window hints
  static Map<String, dynamic> get windowHints {
    if (!isWayland) return {};

    return {
      'compositor': 'wayland',
      'decorations': true,
      'resizable': true,
      'vsync': true,
      'hardware_acceleration': hasHardwareAcceleration,
    };
  }

  /// Log platform information for debugging
  static void logPlatformInfo() {
    if (!kDebugMode) return;

    debugPrint('🖥️  Platform Information:');
    debugPrint('   Display Server: ${isWayland ? 'Wayland' : 'X11'}');
    debugPrint(
        '   Hardware Accel: ${hasHardwareAcceleration ? 'Enabled' : 'Disabled'}');
    debugPrint(
        '   Optimizations: ${_optimizationsApplied ? 'Applied' : 'Not Applied'}');

    if (isWayland) {
      final env = Platform.environment;
      debugPrint('   Wayland Display: ${env['WAYLAND_DISPLAY'] ?? 'default'}');
      debugPrint('   Compositor: ${env['XDG_CURRENT_DESKTOP'] ?? 'unknown'}');
    }
  }
}

/// Widget that applies Wayland-specific optimizations to its child
class WaylandOptimizedWidget extends StatefulWidget {
  final Widget child;
  final bool enableAnimationOptimizations;

  const WaylandOptimizedWidget({
    super.key,
    required this.child,
    this.enableAnimationOptimizations = true,
  });

  @override
  State<WaylandOptimizedWidget> createState() => _WaylandOptimizedWidgetState();
}

class _WaylandOptimizedWidgetState extends State<WaylandOptimizedWidget>
    with TickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    _initializeOptimizations();
  }

  void _initializeOptimizations() async {
    await WaylandHelper.applyOptimizations();

    if (widget.enableAnimationOptimizations && WaylandHelper.isWayland) {
      // Optimize animation controllers for Wayland
      SchedulerBinding.instance.addPostFrameCallback((_) {
        setState(() {
          // This rebuilds the widget tree with optimizations applied
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!WaylandHelper.isWayland) {
      return widget.child;
    }

    // Wrap child with Wayland-specific optimizations
    return RepaintBoundary(
      child: AnimatedSwitcher(
        duration: WaylandHelper.animationDuration,
        switchInCurve: WaylandHelper.animationCurve,
        switchOutCurve: WaylandHelper.animationCurve,
        child: widget.child,
      ),
    );
  }
}
