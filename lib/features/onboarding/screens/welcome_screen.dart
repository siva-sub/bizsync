import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/onboarding_models.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_page_indicator.dart';
import '../../../core/animations/page_transitions.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  final List<WelcomePage> _pages = [
    const WelcomePage(
      title: 'Welcome to BizSync',
      subtitle: 'Your Complete Business Management Solution',
      description: 'Streamline invoicing, manage customers, track finances, and grow your business with our offline-first platform.',
      icon: Icons.business_center,
      color: Color(0xFF1565C0),
    ),
    const WelcomePage(
      title: 'Offline-First Design',
      subtitle: 'Work Anywhere, Anytime',
      description: 'All your data is stored locally and synced when you\'re online. Never lose access to your business information.',
      icon: Icons.offline_bolt,
      color: Color(0xFF7B1FA2),
    ),
    const WelcomePage(
      title: 'Singapore Ready',
      subtitle: 'Built for Local Businesses',
      description: 'GST calculations, IRAS compliance, PayNow QR codes, and Singapore-specific features built right in.',
      icon: Icons.location_city,
      color: Color(0xFF388E3C),
    ),
    const WelcomePage(
      title: 'Secure & Private',
      subtitle: 'Your Data, Your Control',
      description: 'End-to-end encryption, local storage, and P2P sync ensure your business data remains private and secure.',
      icon: Icons.security,
      color: Color(0xFFD32F2F),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));
  }

  void _startAnimations() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _fadeController.forward();
      }
    });
    
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        _slideController.forward();
      }
    });
    
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        _scaleController.forward();
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _currentPage > 0 ? _previousPage : null,
                    icon: const Icon(Icons.arrow_back),
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.surface,
                    ),
                  ),
                  Expanded(
                    child: OnboardingPageIndicator(
                      currentPage: _currentPage,
                      totalPages: _pages.length,
                    ),
                  ),
                  TextButton(
                    onPressed: _skipOnboarding,
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),
            
            // Page content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                  // Restart animations for new page
                  _restartAnimations();
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return AnimatedBuilder(
                    animation: Listenable.merge([
                      _fadeAnimation,
                      _slideAnimation,
                      _scaleAnimation,
                    ]),
                    builder: (context, child) {
                      return FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: ScaleTransition(
                            scale: _scaleAnimation,
                            child: _WelcomePageWidget(
                              page: _pages[index],
                              key: ValueKey(index),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            
            // Navigation buttons
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  if (_currentPage == _pages.length - 1) ...[
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _continueToSetup,
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Get Started'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ] else ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _skipOnboarding,
                        child: const Text('Skip Setup'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton(
                        onPressed: _nextPage,
                        child: const Text('Next'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _restartAnimations() {
    _fadeController.reset();
    _slideController.reset();
    _scaleController.reset();
    
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        _fadeController.forward();
        _slideController.forward();
        _scaleController.forward();
      }
    });
  }

  void _continueToSetup() async {
    final notifier = ref.read(onboardingStateProvider.notifier);
    await notifier.completeStep(OnboardingStep.welcome);
    
    if (mounted) {
      context.go('/onboarding/company-setup');
    }
  }

  void _skipOnboarding() async {
    final shouldSkip = await _showSkipDialog();
    if (shouldSkip == true) {
      final notifier = ref.read(onboardingStateProvider.notifier);
      await notifier.skipOnboarding();
      
      if (mounted) {
        context.go('/');
      }
    }
  }

  Future<bool?> _showSkipDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skip Setup?'),
        content: const Text(
          'You can always complete your business setup later in Settings. '
          'However, some features may be limited until you provide your business information.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continue Setup'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Skip for Now'),
          ),
        ],
      ),
    );
  }
}

class WelcomePage {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color color;

  const WelcomePage({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class _WelcomePageWidget extends StatelessWidget {
  final WelcomePage page;

  const _WelcomePageWidget({
    super.key,
    required this.page,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          
          // Icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: page.color,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: page.color.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              page.icon,
              size: 60,
              color: Colors.white,
            ),
          ),
          
          const SizedBox(height: 40),
          
          // Title
          Text(
            page.title,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 12),
          
          // Subtitle
          Text(
            page.subtitle,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: page.color,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 24),
          
          // Description
          Text(
            page.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          
          const Spacer(),
        ],
      ),
    );
  }
}