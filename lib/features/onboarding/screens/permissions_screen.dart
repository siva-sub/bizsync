import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/onboarding_models.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_page_indicator.dart';

class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  bool _isLoading = false;
  
  final Map<String, bool> _permissions = {
    'notifications': false,
    'camera': false,
    'storage': false,
    'location': false,
  };
  
  final Map<String, PermissionStatus> _permissionStatuses = {};

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkExistingPermissions();
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

  Future<void> _checkExistingPermissions() async {
    try {
      final notificationStatus = await Permission.notification.status;
      final cameraStatus = await Permission.camera.status;
      final storageStatus = await Permission.storage.status;
      final locationStatus = await Permission.location.status;
      
      setState(() {
        _permissionStatuses['notifications'] = notificationStatus;
        _permissionStatuses['camera'] = cameraStatus;
        _permissionStatuses['storage'] = storageStatus;
        _permissionStatuses['location'] = locationStatus;
        
        _permissions['notifications'] = notificationStatus.isGranted;
        _permissions['camera'] = cameraStatus.isGranted;
        _permissions['storage'] = storageStatus.isGranted;
        _permissions['location'] = locationStatus.isGranted;
      });
    } catch (e) {
      // Handle permission check errors
      debugPrint('Error checking permissions: $e');
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Permissions'),
        leading: IconButton(
          onPressed: () => context.go('/onboarding/user-profile'),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          TextButton(
            onPressed: _skipToTutorial,
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
                  progress: 0.9, // Almost complete
                  label: 'Final step! Let\'s set up permissions',
                ),
              ),
              
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      _buildHeader(),
                      const SizedBox(height: 32),
                      
                      // Permission cards
                      _buildPermissionCard(
                        'notifications',
                        'Notifications',
                        'Stay updated with invoice payments, reminders, and important business alerts',
                        Icons.notifications_outlined,
                        Colors.blue,
                        required: true,
                      ),
                      const SizedBox(height: 16),
                      
                      _buildPermissionCard(
                        'camera',
                        'Camera',
                        'Scan QR codes for payments and capture documents for your records',
                        Icons.camera_alt_outlined,
                        Colors.green,
                        required: false,
                      ),
                      const SizedBox(height: 16),
                      
                      _buildPermissionCard(
                        'storage',
                        'Storage',
                        'Save invoices, reports, and backups to your device storage',
                        Icons.folder_outlined,
                        Colors.orange,
                        required: false,
                      ),
                      const SizedBox(height: 16),
                      
                      _buildPermissionCard(
                        'location',
                        'Location',
                        'Auto-fill addresses and provide location-based business insights',
                        Icons.location_on_outlined,
                        Colors.purple,
                        required: false,
                      ),
                      const SizedBox(height: 32),
                      
                      // Privacy info
                      _buildPrivacyCard(),
                    ],
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
          'App Permissions',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Grant permissions to unlock BizSync\'s full potential. You can change these anytime in Settings.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionCard(
    String key,
    String title,
    String description,
    IconData icon,
    Color color,
    { required bool required }
  ) {
    final isGranted = _permissions[key] ?? false;
    final status = _permissionStatuses[key];
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (required) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Required',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isGranted,
                  onChanged: (value) => _handlePermissionToggle(key, value),
                  activeColor: color,
                ),
              ],
            ),
            if (status != null && status.isPermanentlyDenied) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_outlined,
                      color: Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Permission permanently denied. Please enable in Settings.',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => openAppSettings(),
                      child: const Text('Settings'),
                      style: TextButton.styleFrom(
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyCard() {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.privacy_tip_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Privacy & Security',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'BizSync respects your privacy:\n'
              '• All data is stored locally on your device\n'
              '• No personal information is sent to external servers\n'
              '• You control what permissions to grant\n'
              '• Permissions can be changed anytime in Settings',
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
              onPressed: _isLoading ? null : () => context.go('/onboarding/user-profile'),
              child: const Text('Previous'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: FilledButton(
              onPressed: _isLoading ? null : _completePermissions,
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

  Future<void> _handlePermissionToggle(String key, bool value) async {
    if (value) {
      // Request permission
      Permission permission;
      switch (key) {
        case 'notifications':
          permission = Permission.notification;
          break;
        case 'camera':
          permission = Permission.camera;
          break;
        case 'storage':
          permission = Permission.storage;
          break;
        case 'location':
          permission = Permission.location;
          break;
        default:
          return;
      }
      
      final status = await permission.request();
      setState(() {
        _permissionStatuses[key] = status;
        _permissions[key] = status.isGranted;
      });
      
      if (status.isPermanentlyDenied) {
        _showPermissionDeniedDialog(key);
      }
    } else {
      // Can't revoke permissions from the app, just update UI
      setState(() {
        _permissions[key] = false;
      });
    }
  }

  void _showPermissionDeniedDialog(String permissionKey) {
    String permissionName = permissionKey;
    switch (permissionKey) {
      case 'notifications':
        permissionName = 'Notifications';
        break;
      case 'camera':
        permissionName = 'Camera';
        break;
      case 'storage':
        permissionName = 'Storage';
        break;
      case 'location':
        permissionName = 'Location';
        break;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$permissionName Permission Denied'),
        content: Text(
          'To enable $permissionName access, please go to Settings > Apps > BizSync > Permissions and turn on $permissionName.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _completePermissions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final notifier = ref.read(onboardingStateProvider.notifier);
      await notifier.completeStep(
        OnboardingStep.permissions,
        data: _permissions,
      );

      if (mounted) {
        context.go('/onboarding/tutorial');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving permissions: $e'),
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

  void _skipToTutorial() async {
    final shouldSkip = await _showSkipDialog();
    if (shouldSkip == true && mounted) {
      context.go('/onboarding/tutorial');
    }
  }

  Future<bool?> _showSkipDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skip Permissions?'),
        content: const Text(
          'You can grant permissions later in Settings. However, some features may be limited without proper permissions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Grant Permissions'),
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