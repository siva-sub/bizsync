import 'package:flutter/material.dart';

/// Custom page transitions for smooth navigation
class PageTransitions {
  
  /// Slide transition from right to left
  static Widget slideFromRight(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      )),
      child: child,
    );
  }
  
  /// Fade transition
  static Widget fade(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: animation,
      child: child,
    );
  }
  
  /// Scale transition
  static Widget scale(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return ScaleTransition(
      scale: Tween<double>(
        begin: 0.8,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
      )),
      child: FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  }
  
  /// Slide up from bottom
  static Widget slideFromBottom(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.0, 1.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      )),
      child: child,
    );
  }
  
  /// Combined slide and fade for onboarding screens
  static Widget onboardingTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.3, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      )),
      child: FadeTransition(
        opacity: Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
        )),
        child: child,
      ),
    );
  }
}

/// Performance-optimized animation controller mixin
mixin OptimizedAnimationMixin<T extends StatefulWidget> on State<T> {
  final List<AnimationController> _controllers = [];
  
  /// Create an optimized animation controller
  AnimationController createAnimationController({
    required Duration duration,
    Duration? reverseDuration,
    String? debugLabel,
    double lowerBound = 0.0,
    double upperBound = 1.0,
    AnimationBehavior animationBehavior = AnimationBehavior.normal,
    required TickerProvider vsync,
  }) {
    final controller = AnimationController(
      duration: duration,
      reverseDuration: reverseDuration,
      debugLabel: debugLabel,
      lowerBound: lowerBound,
      upperBound: upperBound,
      vsync: vsync,
      animationBehavior: animationBehavior,
    );
    
    _controllers.add(controller);
    return controller;
  }
  
  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }
}

/// Widget key generator for preventing unnecessary rebuilds
class WidgetKeys {
  static const String _prefix = 'bizsync_';
  
  /// Generate a value key for lists
  static ValueKey<String> listItem(String id) => ValueKey('${_prefix}list_$id');
  
  /// Generate a value key for cards
  static ValueKey<String> card(String id) => ValueKey('${_prefix}card_$id');
  
  /// Generate a value key for animated widgets
  static ValueKey<String> animated(String id) => ValueKey('${_prefix}anim_$id');
  
  /// Generate a global key for forms
  static GlobalKey<FormState> form(String id) => GlobalKey<FormState>();
  
  /// Generate a page storage key
  static PageStorageKey<String> pageStorage(String id) => PageStorageKey('${_prefix}page_$id');
}

/// Optimized animated list widget that prevents flickering
class OptimizedAnimatedList extends StatelessWidget {
  final List<Widget> children;
  final Duration animationDuration;
  final Curve animationCurve;
  final int? crossAxisCount;
  final double? aspectRatio;
  final EdgeInsets? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const OptimizedAnimatedList({
    super.key,
    required this.children,
    this.animationDuration = const Duration(milliseconds: 300),
    this.animationCurve = Curves.easeOut,
    this.crossAxisCount,
    this.aspectRatio,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    if (crossAxisCount != null) {
      return GridView.count(
        key: const ValueKey('optimized_grid'),
        crossAxisCount: crossAxisCount!,
        childAspectRatio: aspectRatio ?? 1.0,
        padding: padding,
        shrinkWrap: shrinkWrap,
        physics: physics,
        children: children.asMap().entries.map((entry) {
          return AnimatedSwitcher(
            key: ValueKey('grid_item_${entry.key}'),
            duration: animationDuration,
            switchInCurve: animationCurve,
            child: entry.value,
          );
        }).toList(),
      );
    }

    return ListView(
      key: const ValueKey('optimized_list'),
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
      children: children.asMap().entries.map((entry) {
        return AnimatedSwitcher(
          key: ValueKey('list_item_${entry.key}'),
          duration: animationDuration,
          switchInCurve: animationCurve,
          child: entry.value,
        );
      }).toList(),
    );
  }
}