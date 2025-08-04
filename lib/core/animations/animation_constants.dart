import 'package:flutter/animation.dart';

/// Animation constants and durations for consistent animations throughout the app
class AnimationConstants {
  // Animation Durations
  static const Duration ultraFast = Duration(milliseconds: 150);
  static const Duration fast = Duration(milliseconds: 250);
  static const Duration medium = Duration(milliseconds: 350);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration ultraSlow = Duration(milliseconds: 750);
  static const Duration snail = Duration(milliseconds: 1000);

  // Page Transition Durations
  static const Duration pageTransition = Duration(milliseconds: 300);
  static const Duration heroTransition = Duration(milliseconds: 400);

  // Micro-interaction Durations
  static const Duration buttonPress = Duration(milliseconds: 100);
  static const Duration cardHover = Duration(milliseconds: 200);
  static const Duration ripple = Duration(milliseconds: 300);

  // Loading Animation Durations
  static const Duration shimmerCycle = Duration(milliseconds: 1500);
  static const Duration spinnerRotation = Duration(milliseconds: 1000);

  // Stagger Delays
  static const Duration staggerDelay = Duration(milliseconds: 100);
  static const Duration listItemStagger = Duration(milliseconds: 50);

  // Chart Animation Durations
  static const Duration chartEntrance = Duration(milliseconds: 800);
  static const Duration numberCounter = Duration(milliseconds: 1200);

  // Toast and Notification Durations
  static const Duration toastSlideIn = Duration(milliseconds: 300);
  static const Duration toastFadeOut = Duration(milliseconds: 200);
  static const Duration notificationExpand = Duration(milliseconds: 250);

  // Animation Curves
  static const easeInOut = Curves.easeInOut;
  static const easeOut = Curves.easeOut;
  static const easeIn = Curves.easeIn;
  static const bounceOut = Curves.bounceOut;
  static const elasticOut = Curves.elasticOut;
  static const fastOutSlowIn = Curves.fastOutSlowIn;
  static const decelerate = Curves.decelerate;

  // Custom curves for specific use cases
  static const materialCurve = Curves.easeInOutCubicEmphasized;
  static const buttonCurve = Curves.easeOutCubic;
  static const cardCurve = Curves.easeInOutQuart;
  static const drawerCurve = Curves.easeInOutCubic;
}

/// Predefined animation configurations for common use cases
class AnimationConfig {
  final Duration duration;
  final Curve curve;
  final Duration? delay;

  const AnimationConfig({
    required this.duration,
    required this.curve,
    this.delay,
  });

  // Common configurations
  static const fadeIn = AnimationConfig(
    duration: AnimationConstants.fast,
    curve: AnimationConstants.easeOut,
  );

  static const slideUp = AnimationConfig(
    duration: AnimationConstants.medium,
    curve: AnimationConstants.fastOutSlowIn,
  );

  static const scaleIn = AnimationConfig(
    duration: AnimationConstants.fast,
    curve: AnimationConstants.bounceOut,
  );

  static const buttonPress = AnimationConfig(
    duration: AnimationConstants.buttonPress,
    curve: AnimationConstants.buttonCurve,
  );

  static const cardHover = AnimationConfig(
    duration: AnimationConstants.cardHover,
    curve: AnimationConstants.cardCurve,
  );

  static const drawerSlide = AnimationConfig(
    duration: AnimationConstants.medium,
    curve: AnimationConstants.drawerCurve,
  );

  static const chartEntrance = AnimationConfig(
    duration: AnimationConstants.chartEntrance,
    curve: AnimationConstants.easeOut,
  );

  static const numberCount = AnimationConfig(
    duration: AnimationConstants.numberCounter,
    curve: AnimationConstants.easeOut,
  );

  static const toastSlide = AnimationConfig(
    duration: AnimationConstants.toastSlideIn,
    curve: AnimationConstants.fastOutSlowIn,
  );
}
