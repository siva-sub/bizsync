import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'animation_constants.dart';

/// Custom page transitions for the app
class PageTransitions {
  /// Slide transition from right to left
  static Page<T> slideFromRight<T extends Object?>(
    BuildContext context,
    GoRouterState state,
    Widget child, {
    Duration duration = AnimationConstants.pageTransition,
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: AnimationConstants.fastOutSlowIn,
          )),
          child: child,
        );
      },
    );
  }

  /// Slide transition from left to right
  static Page<T> slideFromLeft<T extends Object?>(
    BuildContext context,
    GoRouterState state,
    Widget child, {
    Duration duration = AnimationConstants.pageTransition,
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: AnimationConstants.fastOutSlowIn,
          )),
          child: child,
        );
      },
    );
  }

  /// Slide transition from bottom to top
  static Page<T> slideFromBottom<T extends Object?>(
    BuildContext context,
    GoRouterState state,
    Widget child, {
    Duration duration = AnimationConstants.pageTransition,
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 1.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: AnimationConstants.fastOutSlowIn,
          )),
          child: child,
        );
      },
    );
  }

  /// Fade transition
  static Page<T> fade<T extends Object?>(
    BuildContext context,
    GoRouterState state,
    Widget child, {
    Duration duration = AnimationConstants.pageTransition,
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: AnimationConstants.easeInOut,
          ),
          child: child,
        );
      },
    );
  }

  /// Scale transition
  static Page<T> scale<T extends Object?>(
    BuildContext context,
    GoRouterState state,
    Widget child, {
    Duration duration = AnimationConstants.pageTransition,
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: AnimationConstants.fastOutSlowIn,
          ),
          child: child,
        );
      },
    );
  }

  /// Slide and fade combined transition
  static Page<T> slideAndFade<T extends Object?>(
    BuildContext context,
    GoRouterState state,
    Widget child, {
    Duration duration = AnimationConstants.pageTransition,
    Offset begin = const Offset(1.0, 0.0),
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final slideAnimation = Tween<Offset>(
          begin: begin,
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: AnimationConstants.fastOutSlowIn,
        ));

        final fadeAnimation = CurvedAnimation(
          parent: animation,
          curve: AnimationConstants.easeInOut,
        );

        return SlideTransition(
          position: slideAnimation,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: child,
          ),
        );
      },
    );
  }

  /// Material design shared axis transition
  static Page<T> sharedAxisHorizontal<T extends Object?>(
    BuildContext context,
    GoRouterState state,
    Widget child, {
    Duration duration = AnimationConstants.pageTransition,
    bool reverse = false,
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final slideInAnimation = Tween<Offset>(
          begin: Offset(reverse ? -0.3 : 0.3, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve:
              const Interval(0.2, 1.0, curve: AnimationConstants.fastOutSlowIn),
        ));

        final slideOutAnimation = Tween<Offset>(
          begin: Offset.zero,
          end: Offset(reverse ? 0.3 : -0.3, 0.0),
        ).animate(CurvedAnimation(
          parent: secondaryAnimation,
          curve:
              const Interval(0.0, 0.8, curve: AnimationConstants.fastOutSlowIn),
        ));

        final fadeInAnimation = CurvedAnimation(
          parent: animation,
          curve: const Interval(0.2, 1.0, curve: Curves.easeIn),
        );

        final fadeOutAnimation = CurvedAnimation(
          parent: secondaryAnimation,
          curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
        );

        return SlideTransition(
          position: slideInAnimation,
          child: FadeTransition(
            opacity: fadeInAnimation,
            child: SlideTransition(
              position: slideOutAnimation,
              child: FadeTransition(
                opacity: ReverseAnimation(fadeOutAnimation),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }

  /// Material design shared axis vertical transition
  static Page<T> sharedAxisVertical<T extends Object?>(
    BuildContext context,
    GoRouterState state,
    Widget child, {
    Duration duration = AnimationConstants.pageTransition,
    bool reverse = false,
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final slideInAnimation = Tween<Offset>(
          begin: Offset(0.0, reverse ? -0.3 : 0.3),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve:
              const Interval(0.2, 1.0, curve: AnimationConstants.fastOutSlowIn),
        ));

        final fadeInAnimation = CurvedAnimation(
          parent: animation,
          curve: const Interval(0.2, 1.0, curve: Curves.easeIn),
        );

        return SlideTransition(
          position: slideInAnimation,
          child: FadeTransition(
            opacity: fadeInAnimation,
            child: child,
          ),
        );
      },
    );
  }

  /// Hero transition for detail screens
  static Page<T> heroTransition<T extends Object?>(
    BuildContext context,
    GoRouterState state,
    Widget child, {
    Duration duration = AnimationConstants.heroTransition,
    String? heroTag,
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: AnimationConstants.easeInOut,
          ),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: AnimationConstants.fastOutSlowIn,
            )),
            child: child,
          ),
        );
      },
    );
  }

  /// Cupertino-style push transition
  static Page<T> cupertinoPageTransition<T extends Object?>(
    BuildContext context,
    GoRouterState state,
    Widget child, {
    Duration duration = AnimationConstants.pageTransition,
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          )),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset.zero,
              end: const Offset(-0.3, 0.0),
            ).animate(CurvedAnimation(
              parent: secondaryAnimation,
              curve: Curves.easeInOut,
            )),
            child: child,
          ),
        );
      },
    );
  }

  /// Custom zoom transition
  static Page<T> zoom<T extends Object?>(
    BuildContext context,
    GoRouterState state,
    Widget child, {
    Duration duration = AnimationConstants.pageTransition,
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: Tween<double>(
            begin: 0.8,
            end: 1.0,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: AnimationConstants.fastOutSlowIn,
          )),
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: AnimationConstants.easeInOut,
            ),
            child: child,
          ),
        );
      },
    );
  }

  /// No transition (instant)
  static Page<T> noTransition<T extends Object?>(
    BuildContext context,
    GoRouterState state,
    Widget child,
  ) {
    return NoTransitionPage<T>(
      key: state.pageKey,
      child: child,
    );
  }
}

/// Custom transition route builder helper
class TransitionBuilder {
  /// Creates a route with custom transition
  static Route<T> createRoute<T extends Object?>({
    required Widget page,
    required RouteTransitionsBuilder transitionsBuilder,
    Duration duration = AnimationConstants.pageTransition,
    RouteSettings? settings,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: transitionsBuilder,
    );
  }

  /// Material design container transform
  static Widget containerTransform({
    required Widget child,
    required Animation<double> animation,
    required Animation<double> secondaryAnimation,
  }) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
      child: ScaleTransition(
        scale: Tween<double>(
          begin: 0.8,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: animation,
          curve:
              const Interval(0.2, 1.0, curve: AnimationConstants.fastOutSlowIn),
        )),
        child: child,
      ),
    );
  }

  /// Morphing circle transition
  static Widget morphingCircle({
    required Widget child,
    required Animation<double> animation,
    required Animation<double> secondaryAnimation,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final radius =
            animation.value * MediaQuery.of(context).size.longestSide;
        return ClipOval(
          clipper: CircleClipper(radius: radius),
          child: child,
        );
      },
      child: child,
    );
  }
}

/// Circle clipper for morphing transitions
class CircleClipper extends CustomClipper<Rect> {
  final double radius;

  CircleClipper({required this.radius});

  @override
  Rect getClip(Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    return Rect.fromCircle(center: center, radius: radius);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Rect> oldClipper) => true;
}

/// No transition page for instant navigation
class NoTransitionPage<T> extends Page<T> {
  final Widget child;

  const NoTransitionPage({
    required this.child,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  });

  @override
  Route<T> createRoute(BuildContext context) {
    return PageRouteBuilder<T>(
      settings: this,
      pageBuilder: (context, animation, _) => child,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }
}
