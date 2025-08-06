import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/onboarding_models.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_page_indicator.dart';

class CompanySetupScreen extends ConsumerStatefulWidget {
  const CompanySetupScreen({super.key});

  @override
  ConsumerState<CompanySetupScreen> createState() => _CompanySetupScreenState();
}

class _CompanySetupScreenState extends ConsumerState<CompanySetupScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  int _currentPage = 0;
  bool _isLoading = false;

  // Form controllers
  final _companyNameController = TextEditingController();
  final _businessTypeController = TextEditingController();
  final _industryController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _gstNumberController = TextEditingController();
  final _uenController = TextEditingController();

  String _selectedBusinessType = '';
  String _selectedIndustry = '';
  String _selectedCurrency = 'SGD';
  String _selectedTimezone = 'Asia/Singapore';
  bool _isGstRegistered = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadExistingData();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
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

    _fadeController.forward();
  }

  void _loadExistingData() {
    final companyProfile = ref.read(companyProfileProvider);
    if (companyProfile != null) {
      _companyNameController.text = companyProfile.name;
      _businessTypeController.text = companyProfile.businessType;
      _selectedBusinessType = companyProfile.businessType;
      _industryController.text = companyProfile.industry;
      _selectedIndustry = companyProfile.industry;
      _addressController.text = companyProfile.address;
      _phoneController.text = companyProfile.phone;
      _emailController.text = companyProfile.email;
      _websiteController.text = companyProfile.website ?? '';
      _isGstRegistered = companyProfile.isGstRegistered;
      _gstNumberController.text = companyProfile.gstNumber ?? '';
      _uenController.text = companyProfile.uen ?? '';
      _selectedCurrency = companyProfile.currency;
      _selectedTimezone = companyProfile.timezone;
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pageController.dispose();
    _companyNameController.dispose();
    _businessTypeController.dispose();
    _industryController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _gstNumberController.dispose();
    _uenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Company Setup'),
        leading: IconButton(
          onPressed: () => context.go('/onboarding/welcome'),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          TextButton(
            onPressed: _skipToUserProfile,
            child: const Text('Skip'),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Progress indicator
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: OnboardingProgressIndicator(
                progress: (_currentPage + 1) / 3,
                label: 'Company Setup - Step ${_currentPage + 1} of 3',
              ),
            ),

            // Form content
            Expanded(
              child: Form(
                key: _formKey,
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  children: [
                    _buildBasicInfoPage(),
                    _buildContactInfoPage(),
                    _buildCompliancePage(),
                  ],
                ),
              ),
            ),

            // Navigation buttons
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Basic Information',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tell us about your business',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onBackground
                      .withOpacity(0.7),
                ),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _companyNameController,
            decoration: const InputDecoration(
              labelText: 'Company Name *',
              hintText: 'Enter your company name',
              prefixIcon: Icon(Icons.business),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your company name';
              }
              return null;
            },
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedBusinessType.isEmpty ? null : _selectedBusinessType,
            decoration: const InputDecoration(
              labelText: 'Business Type *',
              prefixIcon: Icon(Icons.account_balance),
            ),
            items: OnboardingData.businessTypes.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(type),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedBusinessType = value ?? '';
                _businessTypeController.text = value ?? '';
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select your business type';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedIndustry.isEmpty ? null : _selectedIndustry,
            decoration: const InputDecoration(
              labelText: 'Industry *',
              prefixIcon: Icon(Icons.domain),
            ),
            items: OnboardingData.industries.map((industry) {
              return DropdownMenuItem(
                value: industry,
                child: Text(industry),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedIndustry = value ?? '';
                _industryController.text = value ?? '';
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select your industry';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Business Address *',
              hintText: 'Enter your business address',
              prefixIcon: Icon(Icons.location_on),
            ),
            maxLines: 3,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your business address';
              }
              return null;
            },
            textInputAction: TextInputAction.next,
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contact Information',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'How can customers reach you?',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onBackground
                      .withOpacity(0.7),
                ),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Phone Number *',
              hintText: '+65 1234 5678',
              prefixIcon: Icon(Icons.phone),
            ),
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your phone number';
              }
              return null;
            },
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email Address *',
              hintText: 'contact@yourcompany.com',
              prefixIcon: Icon(Icons.email),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your email address';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                  .hasMatch(value)) {
                return 'Please enter a valid email address';
              }
              return null;
            },
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _websiteController,
            decoration: const InputDecoration(
              labelText: 'Website (Optional)',
              hintText: 'https://www.yourcompany.com',
              prefixIcon: Icon(Icons.web),
            ),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 32),
          Text(
            'Localization',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedCurrency,
            decoration: const InputDecoration(
              labelText: 'Currency',
              prefixIcon: Icon(Icons.attach_money),
            ),
            items: const [
              DropdownMenuItem(
                  value: 'SGD', child: Text('SGD - Singapore Dollar')),
              DropdownMenuItem(value: 'USD', child: Text('USD - US Dollar')),
              DropdownMenuItem(value: 'EUR', child: Text('EUR - Euro')),
              DropdownMenuItem(
                  value: 'GBP', child: Text('GBP - British Pound')),
              DropdownMenuItem(
                  value: 'MYR', child: Text('MYR - Malaysian Ringgit')),
            ],
            onChanged: (value) {
              setState(() {
                _selectedCurrency = value ?? 'SGD';
              });
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedTimezone,
            decoration: const InputDecoration(
              labelText: 'Timezone',
              prefixIcon: Icon(Icons.schedule),
            ),
            items: const [
              DropdownMenuItem(
                  value: 'Asia/Singapore', child: Text('Singapore (GMT+8)')),
              DropdownMenuItem(
                  value: 'Asia/Kuala_Lumpur',
                  child: Text('Kuala Lumpur (GMT+8)')),
              DropdownMenuItem(
                  value: 'Asia/Jakarta', child: Text('Jakarta (GMT+7)')),
              DropdownMenuItem(value: 'UTC', child: Text('UTC (GMT+0)')),
            ],
            onChanged: (value) {
              setState(() {
                _selectedTimezone = value ?? 'Asia/Singapore';
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCompliancePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tax & Compliance',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Singapore tax and regulatory information',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onBackground
                      .withOpacity(0.7),
                ),
          ),
          const SizedBox(height: 32),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    title: const Text('GST Registered'),
                    subtitle:
                        const Text('Is your business registered for GST?'),
                    value: _isGstRegistered,
                    onChanged: (value) {
                      setState(() {
                        _isGstRegistered = value;
                        if (!value) {
                          _gstNumberController.clear();
                        }
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (_isGstRegistered) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _gstNumberController,
                      decoration: const InputDecoration(
                        labelText: 'GST Registration Number *',
                        hintText: '200012345M',
                        prefixIcon: Icon(Icons.receipt_long),
                      ),
                      validator: _isGstRegistered
                          ? (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your GST number';
                              }
                              if (!RegExp(r'^\d{9}[A-Z]$')
                                  .hasMatch(value.trim())) {
                                return 'Please enter a valid GST number (e.g. 200012345M)';
                              }
                              return null;
                            }
                          : null,
                      textInputAction: TextInputAction.next,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _uenController,
            decoration: const InputDecoration(
              labelText: 'UEN (Optional)',
              hintText: '200012345A',
              prefixIcon: Icon(Icons.business_center),
              helperText: 'Unique Entity Number for Singapore businesses',
            ),
            validator: (value) {
              if (value != null && value.isNotEmpty) {
                if (!RegExp(r'^\d{9}[A-Z]$').hasMatch(value.trim())) {
                  return 'Please enter a valid UEN (e.g. 200012345A)';
                }
              }
              return null;
            },
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 24),
          Card(
            color:
                Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Why do we need this?',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This information helps us:\n'
                    '• Calculate GST correctly on invoices\n'
                    '• Generate compliant tax reports\n'
                    '• Ensure IRAS compliance\n'
                    '• Set up proper payment methods',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          if (_currentPage > 0) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: _previousPage,
                child: const Text('Previous'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: FilledButton(
              onPressed: _isLoading ? null : _nextPage,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_currentPage == 2 ? 'Continue' : 'Next'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextPage() async {
    if (_currentPage < 2) {
      if (_validateCurrentPage()) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else {
      await _completeSetup();
    }
  }

  bool _validateCurrentPage() {
    switch (_currentPage) {
      case 0:
        return _companyNameController.text.isNotEmpty &&
            _selectedBusinessType.isNotEmpty &&
            _selectedIndustry.isNotEmpty &&
            _addressController.text.isNotEmpty;
      case 1:
        return _phoneController.text.isNotEmpty &&
            _emailController.text.isNotEmpty &&
            RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                .hasMatch(_emailController.text);
      case 2:
        if (_isGstRegistered && _gstNumberController.text.isEmpty) {
          return false;
        }
        return true;
      default:
        return false;
    }
  }

  Future<void> _completeSetup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final companyProfile = CompanyProfile(
        name: _companyNameController.text.trim(),
        businessType: _selectedBusinessType,
        industry: _selectedIndustry,
        address: _addressController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        website: _websiteController.text.trim().isEmpty
            ? null
            : _websiteController.text.trim(),
        isGstRegistered: _isGstRegistered,
        gstNumber: _isGstRegistered ? _gstNumberController.text.trim() : null,
        uen: _uenController.text.trim().isEmpty
            ? null
            : _uenController.text.trim(),
        currency: _selectedCurrency,
        timezone: _selectedTimezone,
      );

      final notifier = ref.read(onboardingStateProvider.notifier);
      await notifier.completeStep(
        OnboardingStep.companySetup,
        data: companyProfile.toJson(),
      );

      if (mounted) {
        context.go('/onboarding/user-profile');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving company information: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _skipToUserProfile() async {
    final shouldSkip = await _showSkipDialog();
    if (shouldSkip == true && mounted) {
      context.go('/onboarding/user-profile');
    }
  }

  Future<bool?> _showSkipDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skip Company Setup?'),
        content: const Text(
          'You can complete your company information later in Settings. '
          'However, some features like invoicing and tax calculations may be limited.',
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
