# BizSync Animation System

A comprehensive animation system designed for production-ready Flutter applications, providing smooth 60fps animations with professional polish.

## Features

### 🎯 Core Animation Utilities
- **AnimationConstants**: Predefined durations, curves, and configurations
- **AnimationUtils**: Helper functions for common animations
- **AnimatedWidgets**: Ready-to-use animated components

### 🌟 Page Transitions
- Slide transitions (left, right, bottom, top)
- Fade and scale transitions
- Shared axis transitions (Material Design)
- Hero transitions for detail screens
- Custom zoom and morphing effects

### 🔄 Loading States
- **Shimmer Effects**: Professional loading skeletons
- **Spinner Variations**: Multiple loading spinner styles
- **Progressive Loading**: Skeleton → Content transitions
- **Loading Overlays**: Full-screen and inline loading states

### 🎨 Micro-Interactions
- **Button Press Feedback**: Scale and ripple effects
- **Card Hover Effects**: Elevation and shadow animations
- **Navigation Animations**: Smooth drawer and menu transitions
- **Staggered Lists**: Progressive item appearance

### 📊 Dashboard Animations
- **Animated Counters**: Smooth number counting
- **Chart Entrances**: Progressive data visualization
- **Progress Bars**: Animated progress indicators
- **KPI Cards**: Hover and data update animations

### 🔔 Notification System
- **Toast Animations**: Slide-in notifications with various styles
- **Success/Error States**: Animated feedback with icons
- **Progress Toasts**: Loading states with progress bars
- **Dismissible Overlays**: Smooth overlay management

## Quick Start

### 1. Import the Animation System

```dart
import 'package:bizsync/core/animations/index.dart';
```

### 2. Basic Animations

```dart
// Slide and fade animation
AnimationUtils.slideAndFade(
  child: Text('Animated Text'),
  begin: Offset(0, 30),
  duration: AnimationConstants.medium,
)

// Scale in animation
AnimationUtils.scaleIn(
  child: Icon(Icons.star),
  curve: AnimationConstants.bounceOut,
)
```

### 3. Animated Widgets

```dart
// Animated button with press feedback
AnimatedButton(
  onPressed: () => print('Pressed!'),
  child: Text('Click Me'),
)

// Animated card with hover effects
AnimatedCard(
  onTap: () => navigator.push(...),
  child: Padding(
    padding: EdgeInsets.all(16),
    child: Text('Card Content'),
  ),
)

// Animated number counter
AnimatedNumberCounter(
  value: 1234,
  prefix: '\$',
  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
)
```

### 4. Loading States

```dart
// Shimmer loading
ShimmerWidgets.cardSkeleton()
ShimmerWidgets.listTileSkeleton()
ShimmerWidgets.kpiCardSkeleton()

// Animated loading with style variations
AnimatedLoadingWidget(
  message: 'Loading data...',
  style: LoadingStyle.wanderingCubes,
)
```

### 5. Toast Notifications

```dart
// Using extension methods
context.showSuccessToast('Operation successful!');
context.showErrorToast('Something went wrong');
context.showWarningToast('Please check input');
context.showInfoToast('Helpful information');

// Custom toast
AnimatedToast.showCustom(
  context,
  message: 'Custom notification',
  backgroundColor: Colors.purple,
  icon: Icons.star,
)
```

### 6. Staggered Animations

```dart
// Staggered list
AnimationLimiter(
  child: Column(
    children: AnimationConfiguration.toStaggeredList(
      duration: AnimationConstants.fast,
      delay: AnimationConstants.listItemStagger,
      childAnimationBuilder: (widget) => SlideAnimation(
        horizontalOffset: 30.0,
        child: FadeInAnimation(child: widget),
      ),
      children: listItems,
    ),
  ),
)

// Staggered grid
StaggeredGridView(
  crossAxisCount: 2,
  children: gridItems,
)
```

### 7. Page Transitions

```dart
// In your router configuration
Page<T> myPage<T>(BuildContext context, GoRouterState state, Widget child) {
  return PageTransitions.slideFromRight(context, state, child);
  // or
  return PageTransitions.fade(context, state, child);
  // or  
  return PageTransitions.sharedAxisHorizontal(context, state, child);
}
```

## Animation Guidelines

### Performance Best Practices

1. **60fps Target**: All animations are optimized for 60fps performance
2. **GPU Acceleration**: Use transforms instead of layout changes
3. **Animation Limits**: Limit concurrent animations to prevent jank
4. **Memory Management**: Properly dispose animation controllers

### Design Principles

1. **Consistent Timing**: Use predefined duration constants
2. **Material Motion**: Follow Material Design motion guidelines
3. **Purposeful Animation**: Every animation should have a clear purpose
4. **Accessibility**: Respect user's motion preferences

### Duration Guidelines

```dart
// Ultra fast interactions (button press)
AnimationConstants.ultraFast  // 150ms

// Fast transitions (hover, focus)
AnimationConstants.fast       // 250ms

// Medium transitions (page changes)
AnimationConstants.medium     // 350ms

// Slow transitions (complex layouts)
AnimationConstants.slow       // 500ms

// Chart and data animations
AnimationConstants.chartEntrance    // 800ms
AnimationConstants.numberCounter    // 1200ms
```

### Curve Usage

```dart
// Button interactions
AnimationConstants.buttonCurve      // easeOutCubic

// Card animations
AnimationConstants.cardCurve        // easeInOutQuart

// Page transitions
AnimationConstants.fastOutSlowIn    // Material standard

// Drawer/menu animations
AnimationConstants.drawerCurve      // easeInOutCubic

// Bouncy effects
AnimationConstants.bounceOut        // For emphasis
```

## Advanced Usage

### Custom Animation Configurations

```dart
// Create custom animation config
const customConfig = AnimationConfig(
  duration: Duration(milliseconds: 600),
  curve: Curves.elasticOut,
  delay: Duration(milliseconds: 100),
);

// Use with animation utilities
AnimationUtils.slideAndFade(
  child: widget,
  duration: customConfig.duration,
  curve: customConfig.curve,
)
```

### Hero Animations

```dart
// Wrap widgets with hero tags for seamless transitions
HeroAnimationWrapper(
  tag: 'customer-${customer.id}',
  child: CustomerCard(customer: customer),
)
```

### Custom Loading States

```dart
// Loading overlay with custom styling
LoadingOverlay(
  isLoading: isProcessing,
  message: 'Processing payment...',
  style: LoadingStyle.pulse,
  child: PaymentForm(),
)
```

## Integration Examples

### Dashboard KPIs with Animations

```dart
// Animated KPI card
AnimatedCard(
  child: Padding(
    padding: EdgeInsets.all(16),
    child: Column(
      children: [
        AnimationUtils.scaleIn(
          delay: Duration(milliseconds: 200),
          child: Icon(Icons.trending_up),
        ),
        SizedBox(height: 8),
        AnimatedNumberCounter(
          value: revenue,
          prefix: '\$',
          duration: AnimationConstants.numberCounter,
        ),
        AnimationUtils.slideAndFade(
          begin: Offset(0, 10),
          delay: Duration(milliseconds: 400),
          child: Text('Revenue'),
        ),
      ],
    ),
  ),
)
```

### Enhanced Navigation Drawer

```dart
// Animated navigation items
AnimationLimiter(
  child: Column(
    children: AnimationConfiguration.toStaggeredList(
      duration: AnimationConstants.fast,
      delay: AnimationConstants.listItemStagger,
      childAnimationBuilder: (widget) => SlideAnimation(
        horizontalOffset: 20.0,
        child: FadeInAnimation(child: widget),
      ),
      children: navigationItems,
    ),
  ),
)
```

## Testing and Debugging

### Animation Testing

```dart
// Disable animations for tests
AnimationConstants.ultraFast = Duration.zero;

// Or use Flutter's animation testing utilities
testWidgets('should animate correctly', (tester) async {
  await tester.pumpWidget(AnimatedWidget());
  await tester.pump(Duration(milliseconds: 100));
  // Test animation states
});
```

### Performance Monitoring

```dart
// Monitor animation performance
import 'package:flutter/scheduler.dart';

SchedulerBinding.instance.addTimingsCallback((timings) {
  for (final timing in timings) {
    if (timing.totalSpan > Duration(milliseconds: 16)) {
      print('Frame took ${timing.totalSpan.inMilliseconds}ms');
    }
  }
});
```

## Demo Screen

Run the animation demo to see all features in action:

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => AnimationDemoScreen(),
  ),
);
```

The demo showcases:
- All animation types and transitions
- Interactive examples
- Performance characteristics
- Best practice implementations

## Contributing

When adding new animations:

1. Follow existing naming conventions
2. Use predefined constants and curves
3. Test on various devices and screen sizes
4. Ensure 60fps performance
5. Add documentation and examples
6. Update the demo screen

## License

Part of the BizSync application suite. See main application license.