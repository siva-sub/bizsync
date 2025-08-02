import 'package:flutter/material.dart';
import '../animations/index.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

/// Demo screen showcasing all the animation features
class AnimationDemoScreen extends StatefulWidget {
  const AnimationDemoScreen({super.key});

  @override
  State<AnimationDemoScreen> createState() => _AnimationDemoScreenState();
}

class _AnimationDemoScreenState extends State<AnimationDemoScreen> {
  int _counter = 0;
  double _progress = 0.7;
  bool _showShimmer = false;
  OverlayEntry? _loadingOverlay;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BizSync Animation Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with slide animation
            AnimationUtils.slideAndFade(
              child: Text(
                'Animation Showcase',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Animated Cards Section
            _buildAnimatedCardsSection(),
            const SizedBox(height: 24),

            // Animated Buttons Section
            _buildAnimatedButtonsSection(),
            const SizedBox(height: 24),

            // Number Counter Section
            _buildNumberCounterSection(),
            const SizedBox(height: 24),

            // Progress Bar Section  
            _buildProgressBarSection(),
            const SizedBox(height: 24),

            // Staggered List Section
            _buildStaggeredListSection(),
            const SizedBox(height: 24),

            // Shimmer Loading Section
            _buildShimmerSection(),
            const SizedBox(height: 24),

            // Toast Notifications Section
            _buildToastSection(),
            const SizedBox(height: 24),

            // Loading Overlay Section
            _buildLoadingOverlaySection(),
          ],
        ),
      ),
      floatingActionButton: AnimatedFAB(
        onPressed: () {
          setState(() {
            _counter++;
            _progress = (_progress + 0.1).clamp(0.0, 1.0);
          });
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildAnimatedCardsSection() {
    return AnimationUtils.slideAndFade(
      begin: const Offset(0, 30),
      delay: const Duration(milliseconds: 200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Animated Cards',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AnimatedCard(
                  elevation: 2,
                  hoverElevation: 8,
                  onTap: () => context.showSuccessToast('Card 1 tapped!'),
                  child: const Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(Icons.trending_up, size: 32, color: Colors.green),
                        SizedBox(height: 8),
                        Text('Revenue'),
                        Text('\$45,230', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: AnimatedCard(
                  elevation: 2,
                  hoverElevation: 8,
                  onTap: () => context.showInfoToast('Card 2 tapped!'),
                  child: const Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(Icons.people, size: 32, color: Colors.blue),
                        SizedBox(height: 8),
                        Text('Customers'),
                        Text('1,234', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedButtonsSection() {
    return AnimationUtils.slideAndFade(
      begin: const Offset(0, 30),
      delay: const Duration(milliseconds: 400),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Animated Buttons',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              AnimatedButton(
                onPressed: () => context.showSuccessToast('Primary button pressed!'),
                child: const Text('Primary Button'),
              ),
              AnimatedButton(
                onPressed: () => context.showWarningToast('Warning button pressed!'),
                backgroundColor: Colors.orange,
                child: const Text('Warning Button'),
              ),
              AnimatedButton(
                onPressed: () => context.showErrorToast('Danger button pressed!'),
                backgroundColor: Colors.red,
                child: const Text('Danger Button'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNumberCounterSection() {
    return AnimationUtils.slideAndFade(
      begin: const Offset(0, 30),
      delay: const Duration(milliseconds: 600),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Animated Number Counter',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          AnimatedCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      AnimatedNumberCounter(
                        value: _counter * 1000,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text('Total Sales'),
                    ],
                  ),
                  Column(
                    children: [
                      AnimatedNumberCounter(
                        value: _counter * 50,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                        prefix: '\$',
                      ),
                      const Text('Revenue'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBarSection() {
    return AnimationUtils.slideAndFade(
      begin: const Offset(0, 30),
      delay: const Duration(milliseconds: 800),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Animated Progress Bar',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          AnimatedCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Progress: ${(_progress * 100).toInt()}%'),
                  const SizedBox(height: 8),
                  AnimatedProgressBar(
                    progress: _progress,
                    height: 8,
                    progressColor: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaggeredListSection() {
    return AnimationUtils.slideAndFade(
      begin: const Offset(0, 30),
      delay: const Duration(milliseconds: 1000),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Staggered List Animation',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          AnimationLimiter(
            child: Column(
              children: AnimationConfiguration.toStaggeredList(
                duration: AnimationConstants.fast,
                delay: AnimationConstants.listItemStagger,
                childAnimationBuilder: (widget) => SlideAnimation(
                  horizontalOffset: 50.0,
                  child: FadeInAnimation(child: widget),
                ),
                children: List.generate(
                  5,
                  (index) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: AnimatedCard(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text('${index + 1}'),
                        ),
                        title: Text('List Item ${index + 1}'),
                        subtitle: Text('This is a staggered animation demo'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () => context.showInfoToast('List item ${index + 1} tapped!'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerSection() {
    return AnimationUtils.slideAndFade(
      begin: const Offset(0, 30),
      delay: const Duration(milliseconds: 1200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Shimmer Loading States',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Switch(
                value: _showShimmer,
                onChanged: (value) => setState(() => _showShimmer = value),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_showShimmer) ...[
            ShimmerWidgets.cardSkeleton(),
            ShimmerWidgets.kpiCardSkeleton(),
            ShimmerWidgets.listTileSkeleton(),
          ] else ...[
            AnimatedCard(
              child: const Padding(
                padding: EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      child: Icon(Icons.person),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('John Doe', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('Customer since 2023'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildToastSection() {
    return AnimationUtils.slideAndFade(
      begin: const Offset(0, 30),
      delay: const Duration(milliseconds: 1400),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Toast Notifications',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              AnimatedButton(
                onPressed: () => context.showSuccessToast('Success! Operation completed.'),
                backgroundColor: Colors.green,
                child: const Text('Success Toast'),
              ),
              AnimatedButton(
                onPressed: () => context.showErrorToast('Error! Something went wrong.'),
                backgroundColor: Colors.red,
                child: const Text('Error Toast'),
              ),
              AnimatedButton(
                onPressed: () => context.showWarningToast('Warning! Please check your input.'),
                backgroundColor: Colors.orange,
                child: const Text('Warning Toast'),
              ),
              AnimatedButton(
                onPressed: () => context.showInfoToast('Info: Here is some useful information.'),
                backgroundColor: Colors.blue,
                child: const Text('Info Toast'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlaySection() {
    return AnimationUtils.slideAndFade(
      begin: const Offset(0, 30),
      delay: const Duration(milliseconds: 1600),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Loading Overlay',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          AnimatedButton(
            onPressed: () {
              context.showLoadingToast('Processing...');
              Future.delayed(const Duration(seconds: 3), () {
                context.showSuccessToast('Process completed!');
              });
            },
            child: const Text('Show Loading Overlay'),
          ),
        ],
      ),
    );
  }
}