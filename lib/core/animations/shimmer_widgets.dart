import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'animation_constants.dart';

/// Shimmer loading skeletons for various UI components
class ShimmerWidgets {
  static const Color _baseColor = Color(0xFFE0E0E0);
  static const Color _highlightColor = Color(0xFFF5F5F5);
  static const Color _darkBaseColor = Color(0xFF303030);
  static const Color _darkHighlightColor = Color(0xFF404040);

  /// Creates a shimmer container with specified dimensions
  static Widget _shimmerContainer({
    required double width,
    required double height,
    BorderRadius? borderRadius,
    required bool isDark,
  }) {
    return TweenAnimationBuilder<double>(
      duration: AnimationConstants.shimmerCycle,
      curve: Curves.easeInOut,
      tween: Tween(begin: -1.0, end: 2.0),
      builder: (context, value, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: borderRadius ?? BorderRadius.circular(4),
            gradient: LinearGradient(
              begin: const Alignment(-1.0, -0.3),
              end: const Alignment(1.0, 0.3),
              colors: isDark
                  ? [_darkBaseColor, _darkHighlightColor, _darkBaseColor]
                  : [_baseColor, _highlightColor, _baseColor],
              stops: [
                (value - 1.0).clamp(0.0, 1.0),
                value.clamp(0.0, 1.0),
                (value + 1.0).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Card skeleton for loading states
  static Widget cardSkeleton({
    double height = 120,
    double width = double.infinity,
    bool isDark = false,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _shimmerContainer(
                  width: 40,
                  height: 40,
                  borderRadius: BorderRadius.circular(20),
                  isDark: isDark,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _shimmerContainer(
                        width: double.infinity,
                        height: 16,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 8),
                      _shimmerContainer(
                        width: 120,
                        height: 12,
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _shimmerContainer(
              width: double.infinity,
              height: 12,
              isDark: isDark,
            ),
            const SizedBox(height: 8),
            _shimmerContainer(
              width: 200,
              height: 12,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  /// List tile skeleton
  static Widget listTileSkeleton({bool isDark = false}) {
    return ListTile(
      leading: _shimmerContainer(
        width: 48,
        height: 48,
        borderRadius: BorderRadius.circular(24),
        isDark: isDark,
      ),
      title: _shimmerContainer(
        width: double.infinity,
        height: 16,
        isDark: isDark,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: _shimmerContainer(
          width: 120,
          height: 12,
          isDark: isDark,
        ),
      ),
      trailing: _shimmerContainer(
        width: 24,
        height: 24,
        borderRadius: BorderRadius.circular(4),
        isDark: isDark,
      ),
    );
  }

  /// Dashboard KPI card skeleton
  static Widget kpiCardSkeleton({bool isDark = false}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _shimmerContainer(
                  width: 80,
                  height: 14,
                  isDark: isDark,
                ),
                _shimmerContainer(
                  width: 24,
                  height: 24,
                  borderRadius: BorderRadius.circular(4),
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _shimmerContainer(
              width: 120,
              height: 32,
              isDark: isDark,
            ),
            const SizedBox(height: 8),
            _shimmerContainer(
              width: 60,
              height: 12,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  /// Chart skeleton
  static Widget chartSkeleton({
    double height = 200,
    bool isDark = false,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _shimmerContainer(
                  width: 120,
                  height: 18,
                  isDark: isDark,
                ),
                _shimmerContainer(
                  width: 80,
                  height: 14,
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: height,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  7,
                  (index) => _shimmerContainer(
                    width: 20,
                    height: 50 + (index * 20).toDouble(),
                    borderRadius: BorderRadius.circular(2),
                    isDark: isDark,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Table skeleton
  static Widget tableSkeleton({
    int rows = 5,
    int columns = 4,
    bool isDark = false,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              children: List.generate(
                columns,
                (index) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _shimmerContainer(
                      width: double.infinity,
                      height: 16,
                      isDark: isDark,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Rows
            ...List.generate(
              rows,
              (rowIndex) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: List.generate(
                    columns,
                    (colIndex) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _shimmerContainer(
                          width: double.infinity,
                          height: 14,
                          isDark: isDark,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Form skeleton
  static Widget formSkeleton({bool isDark = false}) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _shimmerContainer(
            width: 120,
            height: 14,
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          _shimmerContainer(
            width: double.infinity,
            height: 48,
            borderRadius: BorderRadius.circular(8),
            isDark: isDark,
          ),
          const SizedBox(height: 24),
          _shimmerContainer(
            width: 100,
            height: 14,
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          _shimmerContainer(
            width: double.infinity,
            height: 48,
            borderRadius: BorderRadius.circular(8),
            isDark: isDark,
          ),
          const SizedBox(height: 24),
          _shimmerContainer(
            width: 80,
            height: 14,
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          _shimmerContainer(
            width: double.infinity,
            height: 120,
            borderRadius: BorderRadius.circular(8),
            isDark: isDark,
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _shimmerContainer(
                width: 80,
                height: 36,
                borderRadius: BorderRadius.circular(18),
                isDark: isDark,
              ),
              const SizedBox(width: 12),
              _shimmerContainer(
                width: 100,
                height: 36,
                borderRadius: BorderRadius.circular(18),
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Profile skeleton
  static Widget profileSkeleton({bool isDark = false}) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _shimmerContainer(
            width: 80,
            height: 80,
            borderRadius: BorderRadius.circular(40),
            isDark: isDark,
          ),
          const SizedBox(height: 16),
          _shimmerContainer(
            width: 120,
            height: 18,
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          _shimmerContainer(
            width: 180,
            height: 14,
            isDark: isDark,
          ),
          const SizedBox(height: 32),
          ...List.generate(
            4,
            (index) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  _shimmerContainer(
                    width: 24,
                    height: 24,
                    borderRadius: BorderRadius.circular(4),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _shimmerContainer(
                      width: double.infinity,
                      height: 16,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated loading indicator with various styles
class AnimatedLoadingWidget extends StatelessWidget {
  final String? message;
  final LoadingStyle style;
  final Color? color;
  final double size;

  const AnimatedLoadingWidget({
    super.key,
    this.message,
    this.style = LoadingStyle.wanderingCubes,
    this.color,
    this.size = 50.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loadingColor = color ?? theme.colorScheme.primary;

    Widget loadingWidget;
    switch (style) {
      case LoadingStyle.wanderingCubes:
        loadingWidget = SpinKitWanderingCubes(
          color: loadingColor,
          size: size,
        );
        break;
      case LoadingStyle.fadingCircle:
        loadingWidget = SpinKitFadingCircle(
          color: loadingColor,
          size: size,
        );
        break;
      case LoadingStyle.wave:
        loadingWidget = SpinKitWave(
          color: loadingColor,
          size: size,
        );
        break;
      case LoadingStyle.pulse:
        loadingWidget = SpinKitPulse(
          color: loadingColor,
          size: size,
        );
        break;
      case LoadingStyle.threeBounce:
        loadingWidget = SpinKitThreeBounce(
          color: loadingColor,
          size: size * 0.6,
        );
        break;
      case LoadingStyle.rotatingCircle:
        loadingWidget = SpinKitRotatingCircle(
          color: loadingColor,
          size: size,
        );
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          loadingWidget,
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

enum LoadingStyle {
  wanderingCubes,
  fadingCircle,
  wave,
  pulse,
  threeBounce,
  rotatingCircle,
}

/// A more sophisticated loading overlay
class LoadingOverlay extends StatelessWidget {
  final Widget child;
  final bool isLoading;
  final String? message;
  final LoadingStyle style;
  final Color? overlayColor;
  final Color? loadingColor;

  const LoadingOverlay({
    super.key,
    required this.child,
    required this.isLoading,
    this.message,
    this.style = LoadingStyle.wanderingCubes,
    this.overlayColor,
    this.loadingColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: overlayColor ?? Colors.black.withValues(alpha: 0.5),
            child: AnimatedLoadingWidget(
              message: message,
              style: style,
              color: loadingColor,
            ),
          ),
      ],
    );
  }
}