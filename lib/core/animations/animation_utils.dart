import 'package:flutter/material.dart';
import 'animation_constants.dart';

/// Utility class for creating common animations
class AnimationUtils {
  /// Creates a fade in animation
  static Widget fadeIn({
    required Widget child,
    Duration duration = AnimationConstants.fast,
    Curve curve = AnimationConstants.easeOut,
    Duration delay = Duration.zero,
  }) {
    return TweenAnimationBuilder<double>(
      duration: duration,
      curve: curve,
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: child,
        );
      },
      child: child,
    );
  }

  /// Creates a slide in animation from bottom
  static Widget slideInFromBottom({
    required Widget child,
    Duration duration = AnimationConstants.medium,
    Curve curve = AnimationConstants.fastOutSlowIn,
    double offset = 50.0,
  }) {
    return TweenAnimationBuilder<double>(
      duration: duration,
      curve: curve,
      tween: Tween(begin: offset, end: 0.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, value),
          child: child,
        );
      },
      child: child,
    );
  }

  /// Creates a scale in animation
  static Widget scaleIn({
    required Widget child,
    Duration duration = AnimationConstants.fast,
    Curve curve = AnimationConstants.bounceOut,
    double initialScale = 0.0,
  }) {
    return TweenAnimationBuilder<double>(
      duration: duration,
      curve: curve,
      tween: Tween(begin: initialScale, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: child,
    );
  }

  /// Creates a slide and fade combination
  static Widget slideAndFade({
    required Widget child,
    Duration duration = AnimationConstants.medium,
    Curve curve = AnimationConstants.fastOutSlowIn,
    Offset begin = const Offset(0, 30),
    Offset end = Offset.zero,
    Duration delay = Duration.zero,
  }) {
    if (delay == Duration.zero) {
      return TweenAnimationBuilder<double>(
        duration: duration,
        curve: curve,
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset.lerp(begin, end, value)!,
              child: child,
            ),
          );
        },
        child: child,
      );
    }
    
    return FutureBuilder(
      future: Future.delayed(delay),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        return TweenAnimationBuilder<double>(
          duration: duration,
          curve: curve,
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset.lerp(begin, end, value)!,
                child: child,
              ),
            );
          },
          child: child,
        );
      },
    );
  }

  /// Creates a rotation animation
  static Widget rotate({
    required Widget child,
    Duration duration = AnimationConstants.slow,
    Curve curve = AnimationConstants.easeInOut,
    double turns = 1.0,
  }) {
    return TweenAnimationBuilder<double>(
      duration: duration,
      curve: curve,
      tween: Tween(begin: 0.0, end: turns),
      builder: (context, value, child) {
        return Transform.rotate(
          angle: value * 2 * 3.14159, // Convert to radians
          child: child,
        );
      },
      child: child,
    );
  }

  /// Creates a pulse animation (scale up and down)
  static Widget pulse({
    required Widget child,
    Duration duration = AnimationConstants.slow,
    double minScale = 0.95,
    double maxScale = 1.05,
  }) {
    return TweenAnimationBuilder<double>(
      duration: duration,
      curve: Curves.easeInOut,
      tween: Tween(begin: minScale, end: maxScale),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: child,
      onEnd: () {
        // This would need a StatefulWidget to properly loop
        // For now, this is a one-time animation
      },
    );
  }

  /// Creates a shimmer effect
  static Widget shimmer({
    required Widget child,
    Color baseColor = const Color(0xFFE0E0E0),
    Color highlightColor = const Color(0xFFF5F5F5),
    Duration duration = AnimationConstants.shimmerCycle,
  }) {
    return TweenAnimationBuilder<double>(
      duration: duration,
      curve: Curves.easeInOut,
      tween: Tween(begin: -1.0, end: 2.0),
      builder: (context, value, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1.0, -0.3),
              end: Alignment(1.0, 0.3),
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: [
                (value - 1.0).clamp(0.0, 1.0),
                value.clamp(0.0, 1.0),
                (value + 1.0).clamp(0.0, 1.0),
              ],
            ),
          ),
          child: child,
        );
      },
      child: child,
    );
  }

  /// Creates a bouncy button press animation
  static Widget bouncyButton({
    required Widget child,
    required VoidCallback onPressed,
    Duration duration = AnimationConstants.buttonPress,
    double pressScale = 0.95,
  }) {
    return TweenAnimationBuilder<double>(
      duration: duration,
      curve: AnimationConstants.buttonCurve,
      tween: Tween(begin: 1.0, end: 1.0),
      builder: (context, value, child) {
        return GestureDetector(
          onTapDown: (_) {
            // Scale down animation would be handled by AnimatedScale in a StatefulWidget
          },
          onTapUp: (_) {
            onPressed();
          },
          onTapCancel: () {
            // Scale back up animation
          },
          child: Transform.scale(
            scale: value,
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  /// Creates a hover effect for cards
  static Widget hoverCard({
    required Widget child,
    double elevation = 4.0,
    double hoverElevation = 8.0,
    Duration duration = AnimationConstants.cardHover,
  }) {
    return TweenAnimationBuilder<double>(
      duration: duration,
      curve: AnimationConstants.cardCurve,
      tween: Tween(begin: elevation, end: elevation),
      builder: (context, value, child) {
        return Card(
          elevation: value,
          child: child,
        );
      },
      child: child,
    );
  }

  /// Creates a number counter animation
  static Widget animatedCounter({
    required int value,
    Duration duration = AnimationConstants.numberCounter,
    TextStyle? style,
    String prefix = '',
    String suffix = '',
  }) {
    return TweenAnimationBuilder<int>(
      duration: duration,
      curve: AnimationConstants.easeOut,
      tween: IntTween(begin: 0, end: value),
      builder: (context, animatedValue, child) {
        return Text(
          '$prefix${animatedValue.toString()}$suffix',
          style: style,
        );
      },
    );
  }

  /// Creates a progress bar animation
  static Widget animatedProgressBar({
    required double progress,
    Duration duration = AnimationConstants.medium,
    Color? backgroundColor,
    Color? progressColor,
    double height = 4.0,
  }) {
    return TweenAnimationBuilder<double>(
      duration: duration,
      curve: AnimationConstants.easeOut,
      tween: Tween(begin: 0.0, end: progress),
      builder: (context, value, child) {
        return LinearProgressIndicator(
          value: value,
          backgroundColor: backgroundColor,
          valueColor: AlwaysStoppedAnimation(progressColor),
          minHeight: height,
        );
      },
    );
  }

  /// Creates a typing animation effect
  static Widget typeWriter({
    required String text,
    Duration duration = const Duration(milliseconds: 100),
    TextStyle? style,
  }) {
    return TweenAnimationBuilder<int>(
      duration: Duration(milliseconds: duration.inMilliseconds * text.length),
      curve: Curves.easeInOut,
      tween: IntTween(begin: 0, end: text.length),
      builder: (context, value, child) {
        return Text(
          text.substring(0, value),
          style: style,
        );
      },
    );
  }
}

/// Widget that provides animated transitions between different states
class CustomAnimatedSwitcher extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final AnimatedSwitcherTransitionBuilder? transitionBuilder;

  const CustomAnimatedSwitcher({
    super.key,
    required this.child,
    this.duration = AnimationConstants.fast,
    this.curve = AnimationConstants.easeInOut,
    this.transitionBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      transitionBuilder: transitionBuilder ?? _defaultTransitionBuilder,
      child: child,
    );
  }

  Widget _defaultTransitionBuilder(Widget child, Animation<double> animation) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.0, 0.1),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }
}