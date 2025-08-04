import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/onboarding_models.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_page_indicator.dart';
import '../../../services/profile_picture_service.dart';
import '../../../core/widgets/profile_avatar.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({super.key});

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isLoading = false;
  String? _profilePicturePath;
  Uint8List? _profilePictureBytes;
  final ProfilePictureService _profilePictureService = ProfilePictureService();

  // Form controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _titleController = TextEditingController();
  final _departmentController = TextEditingController();

  String _selectedRole = '';

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadExistingData();
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

  void _loadExistingData() {
    final userProfile = ref.read(userProfileProvider);
    if (userProfile != null) {
      _firstNameController.text = userProfile.firstName;
      _lastNameController.text = userProfile.lastName;
      _emailController.text = userProfile.email;
      _phoneController.text = userProfile.phone;
      _selectedRole = userProfile.role;
      _titleController.text = userProfile.title ?? '';
      _departmentController.text = userProfile.department ?? '';
      _profilePicturePath = userProfile.profilePicturePath;
      
      // Load profile picture if exists
      if (_profilePicturePath != null) {
        _loadProfilePicture();
      }
    } else {
      // Try to load existing profile picture from storage
      _loadExistingProfilePicture();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _titleController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Profile'),
        leading: IconButton(
          onPressed: () => context.go('/onboarding/company-setup'),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          TextButton(
            onPressed: _skipToPermissions,
            child: const Text('Skip'),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Column(
            children: [
              // Progress indicator
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: OnboardingProgressIndicator(
                  progress: 0.75, // 3 out of 4 major steps
                  label: 'Almost there! Let\'s set up your profile',
                ),
              ),

              // Form content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        _buildHeader(),
                        const SizedBox(height: 32),

                        // Profile Avatar Placeholder
                        _buildAvatarSection(),
                        const SizedBox(height: 32),

                        // Personal Information
                        _buildPersonalInfoSection(),
                        const SizedBox(height: 24),

                        // Contact Information
                        _buildContactInfoSection(),
                        const SizedBox(height: 24),

                        // Professional Information
                        _buildProfessionalInfoSection(),
                        const SizedBox(height: 32),

                        // Why we need this info
                        _buildInfoCard(),
                      ],
                    ),
                  ),
                ),
              ),

              // Navigation buttons
              _buildNavigationButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Create Your Profile',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Let\'s personalize your BizSync experience',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color:
                    Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
        ),
      ],
    );
  }

  Widget _buildAvatarSection() {
    final initials = _getInitials();

    return Center(
      child: Column(
        children: [
          ProfileAvatarLarge(
            imagePath: _profilePicturePath,
            imageBytes: _profilePictureBytes,
            initials: initials,
            onTap: _isLoading ? null : _selectProfilePicture,
            showEditIcon: true,
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _isLoading ? null : _selectProfilePicture,
            icon: Icon(_profilePictureBytes == null ? Icons.camera_alt : Icons.edit),
            label: Text(_profilePictureBytes == null ? 'Add Photo' : 'Change Photo'),
          ),
          if (_profilePictureBytes != null)
            TextButton.icon(
              onPressed: _isLoading ? null : _removeProfilePicture,
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label: const Text(
                'Remove Photo',
                style: TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Personal Information',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(
                  labelText: 'First Name *',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your first name';
                  }
                  return null;
                },
                onChanged: (_) => setState(() {}), // Refresh initials
                textInputAction: TextInputAction.next,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Last Name *',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your last name';
                  }
                  return null;
                },
                onChanged: (_) => setState(() {}), // Refresh initials
                textInputAction: TextInputAction.next,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContactInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Contact Information',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _emailController,
          decoration: const InputDecoration(
            labelText: 'Email Address *',
            hintText: 'your.email@company.com',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your email address';
            }
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
              return 'Please enter a valid email address';
            }
            return null;
          },
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _phoneController,
          decoration: const InputDecoration(
            labelText: 'Phone Number *',
            hintText: '+65 1234 5678',
            prefixIcon: Icon(Icons.phone_outlined),
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
      ],
    );
  }

  Widget _buildProfessionalInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Professional Information',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedRole.isEmpty ? null : _selectedRole,
          decoration: const InputDecoration(
            labelText: 'Your Role *',
            prefixIcon: Icon(Icons.work_outline),
          ),
          items: OnboardingData.roles.map((role) {
            return DropdownMenuItem(
              value: role,
              child: Text(role),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedRole = value ?? '';
            });
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select your role';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'Job Title (Optional)',
            hintText: 'e.g., Senior Accountant',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _departmentController,
          decoration: const InputDecoration(
            labelText: 'Department (Optional)',
            hintText: 'e.g., Finance, Operations',
            prefixIcon: Icon(Icons.domain_outlined),
          ),
          textInputAction: TextInputAction.done,
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
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
                  'Your Information is Safe',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Your profile information is stored locally on your device and encrypted. '
              'We use this information to:\n'
              '• Personalize your experience\n'
              '• Generate professional documents\n'
              '• Set up user access controls\n'
              '• Provide better customer support',
            ),
          ],
        ),
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
          Expanded(
            child: OutlinedButton(
              onPressed: _isLoading
                  ? null
                  : () => context.go('/onboarding/company-setup'),
              child: const Text('Previous'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: FilledButton(
              onPressed: _isLoading ? null : _completeProfile,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Continue'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials() {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();

    String initials = '';
    if (firstName.isNotEmpty) {
      initials += firstName[0].toUpperCase();
    }
    if (lastName.isNotEmpty) {
      initials += lastName[0].toUpperCase();
    }

    return initials.isEmpty ? 'U' : initials;
  }

  Future<void> _completeProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userProfile = UserProfile(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        role: _selectedRole,
        title: _titleController.text.trim().isEmpty
            ? null
            : _titleController.text.trim(),
        department: _departmentController.text.trim().isEmpty
            ? null
            : _departmentController.text.trim(),
        profilePicturePath: _profilePicturePath,
      );

      final notifier = ref.read(onboardingStateProvider.notifier);
      await notifier.completeStep(
        OnboardingStep.userProfile,
        data: userProfile.toJson(),
      );

      if (mounted) {
        context.go('/onboarding/permissions');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile information: $e'),
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

  void _skipToPermissions() async {
    final shouldSkip = await _showSkipDialog();
    if (shouldSkip == true && mounted) {
      context.go('/onboarding/permissions');
    }
  }

  Future<bool?> _showSkipDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skip Profile Setup?'),
        content: const Text(
          'You can complete your profile information later in Settings. '
          'However, some features may not be fully personalized for you.',
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

  /// Loads existing profile picture from storage
  Future<void> _loadExistingProfilePicture() async {
    try {
      final picturePath = await _profilePictureService.getProfilePicturePath();
      if (picturePath != null) {
        final pictureBytes = await _profilePictureService.getProfilePictureBytes();
        if (pictureBytes != null && mounted) {
          setState(() {
            _profilePicturePath = picturePath;
            _profilePictureBytes = pictureBytes;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading existing profile picture: $e');
    }
  }

  /// Loads profile picture from the given path
  Future<void> _loadProfilePicture() async {
    if (_profilePicturePath == null) return;

    try {
      final file = File(_profilePicturePath!);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        if (mounted) {
          setState(() {
            _profilePictureBytes = bytes;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading profile picture: $e');
    }
  }

  /// Handles profile picture selection
  Future<void> _selectProfilePicture() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final picturePath = await _profilePictureService.selectAndSaveProfilePicture(context);
      if (picturePath != null) {
        final pictureBytes = await _profilePictureService.getProfilePictureBytes();
        if (pictureBytes != null && mounted) {
          setState(() {
            _profilePicturePath = picturePath;
            _profilePictureBytes = pictureBytes;
          });

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture updated successfully!'),
              behavior: SnackBarBehavior.floating,
            ),
          );

          // Clean up old profile pictures
          _profilePictureService.cleanupOldProfilePictures();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile picture: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Removes the current profile picture
  Future<void> _removeProfilePicture() async {
    final shouldRemove = await _showRemovePhotoDialog();
    if (shouldRemove != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _profilePictureService.deleteProfilePicture();
      if (success && mounted) {
        setState(() {
          _profilePicturePath = null;
          _profilePictureBytes = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture removed successfully!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing profile picture: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Shows confirmation dialog for removing profile picture
  Future<bool?> _showRemovePhotoDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Profile Picture?'),
        content: const Text(
          'Are you sure you want to remove your profile picture? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
