import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Detects if Mesa software rendering is being used on Linux
class MesaRenderingDetector {
  static bool? _isMesaSoftwareRendering;
  static String? _rendererInfo;
  static Map<String, String>? _glInfo;
  
  /// Check if Mesa software rendering is active
  static bool get isMesaSoftwareRendering {
    if (_isMesaSoftwareRendering != null) {
      return _isMesaSoftwareRendering!;
    }
    
    // Only check on Linux
    if (!Platform.isLinux) {
      _isMesaSoftwareRendering = false;
      return false;
    }
    
    try {
      // Check LIBGL_ALWAYS_SOFTWARE environment variable
      final libglSoftware = Platform.environment['LIBGL_ALWAYS_SOFTWARE'];
      if (libglSoftware == '1') {
        _isMesaSoftwareRendering = true;
        _rendererInfo = 'LIBGL_ALWAYS_SOFTWARE=1';
        if (kDebugMode) {
          print('BizSync: Mesa software rendering detected via LIBGL_ALWAYS_SOFTWARE');
        }
        return true;
      }
      
      // Check GL_RENDERER environment variable
      final glRenderer = Platform.environment['GL_RENDERER']?.toLowerCase() ?? '';
      if (glRenderer.contains('llvmpipe') || 
          glRenderer.contains('softpipe') || 
          glRenderer.contains('swrast')) {
        _isMesaSoftwareRendering = true;
        _rendererInfo = glRenderer;
        if (kDebugMode) {
          print('BizSync: Mesa software rendering detected via GL_RENDERER: $glRenderer');
        }
        return true;
      }
      
      // Check additional Mesa-related environment variables
      final mesaGlVersionOverride = Platform.environment['MESA_GL_VERSION_OVERRIDE'];
      final mesaGlslVersionOverride = Platform.environment['MESA_GLSL_VERSION_OVERRIDE'];
      final galiumDriver = Platform.environment['GALLIUM_DRIVER'];
      
      if (mesaGlVersionOverride != null || mesaGlslVersionOverride != null) {
        // Mesa-specific overrides are present
        _isMesaSoftwareRendering = true;
        _rendererInfo = 'Mesa overrides detected';
        if (kDebugMode) {
          print('BizSync: Mesa detected via version overrides');
        }
        return true;
      }
      
      if (galiumDriver != null && 
          (galiumDriver.contains('llvmpipe') || 
           galiumDriver.contains('softpipe') || 
           galiumDriver.contains('swrast'))) {
        _isMesaSoftwareRendering = true;
        _rendererInfo = 'Gallium driver: $galiumDriver';
        if (kDebugMode) {
          print('BizSync: Mesa software rendering detected via GALLIUM_DRIVER: $galiumDriver');
        }
        return true;
      }
      
      // Check for common software rendering indicators
      final glxVendor = Platform.environment['__GLX_VENDOR_LIBRARY_NAME'];
      if (glxVendor == 'mesa') {
        // Additional check needed to determine if it's software rendering
        final vblankMode = Platform.environment['vblank_mode'];
        if (vblankMode == '0') {
          // Vsync disabled is often used with software rendering
          _isMesaSoftwareRendering = true;
          _rendererInfo = 'Mesa with vblank_mode=0';
          if (kDebugMode) {
            print('BizSync: Mesa software rendering suspected (vblank_mode=0)');
          }
          return true;
        }
      }
      
      _isMesaSoftwareRendering = false;
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('BizSync: Error detecting Mesa rendering: $e');
      }
      _isMesaSoftwareRendering = false;
      return false;
    }
  }
  
  /// Get renderer information for debugging
  static String get rendererInfo {
    if (_rendererInfo == null) {
      // Trigger detection to populate info
      isMesaSoftwareRendering;
    }
    return _rendererInfo ?? 'Unknown';
  }
  
  /// Get all GL-related environment variables for debugging
  static Map<String, String> get glEnvironmentInfo {
    if (_glInfo != null) {
      return _glInfo!;
    }
    
    _glInfo = {};
    final envVars = [
      'LIBGL_ALWAYS_SOFTWARE',
      'GL_RENDERER',
      'GL_VERSION',
      'GL_VENDOR',
      'MESA_GL_VERSION_OVERRIDE',
      'MESA_GLSL_VERSION_OVERRIDE',
      'GALLIUM_DRIVER',
      '__GLX_VENDOR_LIBRARY_NAME',
      'vblank_mode',
      'LIBGL_DRI3_DISABLE',
      'CLUTTER_PAINT',
      'GDK_BACKEND',
    ];
    
    for (final varName in envVars) {
      final value = Platform.environment[varName];
      if (value != null) {
        _glInfo![varName] = value;
      }
    }
    
    return _glInfo!;
  }
  
  /// Force detection refresh (useful for testing)
  static void refreshDetection() {
    _isMesaSoftwareRendering = null;
    _rendererInfo = null;
    _glInfo = null;
  }
  
  /// Get adjusted elevation for cards based on rendering mode
  static double getAdjustedElevation(double originalElevation) {
    if (isMesaSoftwareRendering && originalElevation > 0) {
      // Reduce elevation to minimize shadow rendering issues
      return originalElevation * 0.3;
    }
    return originalElevation;
  }
  
  /// Check if shadows should be disabled
  static bool get shouldDisableShadows => isMesaSoftwareRendering;
  
  /// Get shadow color with Mesa workaround
  static Color? getAdjustedShadowColor(Color? originalColor) {
    if (isMesaSoftwareRendering) {
      // Return transparent to effectively disable shadows
      return const Color(0x00000000);
    }
    return originalColor;
  }
  
  /// Print debug information about the rendering environment
  static void printDebugInfo() {
    if (!kDebugMode) return;
    
    print('=== BizSync Mesa Rendering Detection ===');
    print('Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
    print('Mesa Software Rendering: $isMesaSoftwareRendering');
    print('Renderer Info: $rendererInfo');
    print('GL Environment:');
    glEnvironmentInfo.forEach((key, value) {
      print('  $key: $value');
    });
    print('=====================================');
  }
}