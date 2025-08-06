import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/onboarding_models.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_page_indicator.dart';

class TutorialScreen extends ConsumerStatefulWidget {
  const TutorialScreen({super.key});

  @override
  ConsumerState<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends ConsumerState<TutorialScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isCompleting = false;

  final List<TutorialPage> _pages = [
    const TutorialPage(
      title: 'Create Professional Invoices',
      description:
          'Generate GST-compliant invoices with your company branding. Track payment status and send reminders automatically.',
      imagePath: 'assets/tutorial/invoices.png', // We'll use icons for now
      icon: Icons.receipt_long,
      color: Color(0xFF1565C0),
      tips: [
        'Tap the + button to create a new invoice',
        'Use templates to speed up invoice creation',
        'Track payment status in real-time',
      ],
    ),
    const TutorialPage(
      title: 'Manage Customers & Contacts',
      description:
          'Keep all your customer information organized. Track purchase history and manage relationships effectively.',
      imagePath: 'assets/tutorial/customers.png',
      icon: Icons.people,
      color: Color(0xFF7B1FA2),
      tips: [
        'Import contacts from your phone',
        'Add GST numbers for business customers',
        'View customer purchase history',
      ],
    ),
    const TutorialPage(
      title: 'Singapore Tax Compliance',
      description:
          'Automatic GST calculations, IRAS-compliant reports, and built-in tax calendar to never miss deadlines.',
      imagePath: 'assets/tutorial/tax.png',
      icon: Icons.account_balance,
      color: Color(0xFF388E3C),
      tips: [
        'Automatic 9% GST calculation',
        'Generate F5 and F7 reports',
        'Set GST filing reminders',
      ],
    ),
    const TutorialPage(
      title: 'PayNow QR Payments',
      description:
          'Generate instant PayNow QR codes for fast payments. Accept payments on-the-go without card terminals.',
      imagePath: 'assets/tutorial/payments.png',
      icon: Icons.qr_code,
      color: Color(0xFFD32F2F),
      tips: [
        'Generate QR codes instantly',
        'Share payment links via WhatsApp',
        'Track payment confirmations',
      ],
    ),
    const TutorialPage(
      title: 'Offline-First & Sync',
      description:
          'Work anywhere, even without internet. Your data syncs automatically when you\'re back online.',
      imagePath: 'assets/tutorial/sync.png',
      icon: Icons.sync,
      color: Color(0xFFFF6F00),
      tips: [
        'All data stored locally',
        'P2P sync between devices',
        'Encrypted cloud backups',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
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

    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _slideController.forward();
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              children: [
                // Header with skip button
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _currentPage > 0 ? _previousPage : null,
                        icon: const Icon(Icons.arrow_back),
                        style: IconButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.surface,
                        ),
                      ),
                      Expanded(
                        child: OnboardingPageIndicator(
                          currentPage: _currentPage,
                          totalPages: _pages.length,
                        ),
                      ),
                      TextButton(
                        onPressed: _skipTutorial,
                        child: const Text('Skip'),
                      ),
                    ],
                  ),
                ),

                // Tutorial content
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      return _TutorialPageWidget(
                        page: _pages[index],
                        key: ValueKey(index),
                      );
                    },
                  ),
                ),

                // Navigation buttons
                _buildNavigationButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          if (_currentPage == _pages.length - 1) ...[
            Expanded(
              child: FilledButton.icon(
                onPressed: _isCompleting ? null : _completeTutorial,
                icon: _isCompleting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: const Text('Get Started'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ] else ...[
            Expanded(
              child: OutlinedButton(
                onPressed: _skipTutorial,
                child: const Text('Skip Tutorial'),
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

  Future<void> _completeTutorial() async {
    setState(() {
      _isCompleting = true;
    });

    try {
      final notifier = ref.read(onboardingStateProvider.notifier);
      await notifier.completeStep(OnboardingStep.tutorial);
      await notifier.completeOnboarding();

      if (mounted) {
        // Show completion animation before navigating
        await _showCompletionAnimation();
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error completing tutorial: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() {
        _isCompleting = false;
      });
    }
  }

  Future<void> _skipTutorial() async {
    final shouldSkip = await _showSkipDialog();
    if (shouldSkip == true) {
      final notifier = ref.read(onboardingStateProvider.notifier);
      await notifier.completeOnboarding();

      if (mounted) {
        context.go('/');
      }
    }
  }

  Future<void> _showCompletionAnimation() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _CompletionDialog(),
    );
  }

  Future<bool?> _showSkipDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skip Tutorial?'),
        content: const Text(
          'The tutorial helps you get the most out of BizSync. You can always access it later from Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continue Tutorial'),
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

class TutorialPage {
  final String title;
  final String description;
  final String imagePath;
  final IconData icon;
  final Color color;
  final List<String> tips;

  const TutorialPage({
    required this.title,
    required this.description,
    required this.imagePath,
    required this.icon,
    required this.color,
    required this.tips,
  });
}

class _TutorialPageWidget extends StatelessWidget {
  final TutorialPage page;

  const _TutorialPageWidget({
    super.key,
    required this.page,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const Spacer(),

          // Feature illustration
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: page.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              page.icon,
              size: 80,
              color: page.color,
            ),
          ),

          const SizedBox(height: 40),

          // Title
          Text(
            page.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: page.color,
                ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // Description
          Text(
            page.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onBackground
                      .withValues(alpha: 0.7),
                  height: 1.6,
                ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),

          // Tips
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Tips:',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  ...page.tips.map((tip) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 16,
                              color: page.color,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                tip,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ),

          const Spacer(),
        ],
      ),
    );
  }
}

class _CompletionDialog extends StatefulWidget {
  const _CompletionDialog();

  @override
  State<_CompletionDialog> createState() => _CompletionDialogState();
}

class _CompletionDialogState extends State<_CompletionDialog>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _scaleController.forward();
    _fadeController.forward();

    // Auto close after animation
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            padding: const EdgeInsets.all(32.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Setup Complete!',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Welcome to BizSync!\nYour business management journey begins now.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
