import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/onboarding_models.dart';
import '../services/onboarding_service.dart';

/// Provider for the onboarding service singleton
final onboardingServiceProvider = Provider<OnboardingService>((ref) {
  return OnboardingService.instance;
});

/// Provider for the current onboarding state
final onboardingStateProvider = StateNotifierProvider<OnboardingStateNotifier, OnboardingState>((ref) {
  final service = ref.watch(onboardingServiceProvider);
  return OnboardingStateNotifier(service);
});

/// State notifier for managing onboarding state
class OnboardingStateNotifier extends StateNotifier<OnboardingState> {
  final OnboardingService _service;
  
  OnboardingStateNotifier(this._service) : super(_service.currentState) {
    _service.addListener(_updateState);
  }
  
  @override
  void dispose() {
    _service.removeListener(_updateState);
    super.dispose();
  }
  
  void _updateState() {
    state = _service.currentState;
  }
  
  /// Initialize the onboarding service
  Future<void> initialize() async {
    await _service.initialize();
  }
  
  /// Move to the next step
  Future<void> nextStep() async {
    await _service.moveToNextStep();
  }
  
  /// Move to the previous step
  Future<void> previousStep() async {
    await _service.moveToPreviousStep();
  }
  
  /// Complete a specific step with data
  Future<void> completeStep(OnboardingStep step, {Map<String, dynamic>? data}) async {
    await _service.completeStep(step, data: data);
  }
  
  /// Complete the entire onboarding
  Future<void> completeOnboarding() async {
    await _service.completeOnboarding();
  }
  
  /// Skip onboarding
  Future<void> skipOnboarding() async {
    await _service.skipOnboarding();
  }
  
  /// Reset onboarding (for testing)
  Future<void> resetOnboarding() async {
    await _service.resetOnboarding();
  }
  
  /// Update company profile
  Future<void> updateCompanyProfile(CompanyProfile profile) async {
    final updatedState = state.copyWith(companyProfile: profile);
    await _service.updateState(updatedState);
  }
  
  /// Update user profile
  Future<void> updateUserProfile(UserProfile profile) async {
    final updatedState = state.copyWith(userProfile: profile);
    await _service.updateState(updatedState);
  }
  
  /// Update permissions
  Future<void> updatePermissions(Map<String, bool> permissions) async {
    await _service.updatePermissions(permissions);
  }
  
  /// Update single permission
  Future<void> updatePermission(String permission, bool granted) async {
    await _service.updatePermission(permission, granted);
  }
}

/// Provider for checking if onboarding is completed
final isOnboardingCompletedProvider = Provider<bool>((ref) {
  final state = ref.watch(onboardingStateProvider);
  return state.isCompleted;
});

/// Provider for getting current onboarding step
final currentOnboardingStepProvider = Provider<OnboardingStep>((ref) {
  final state = ref.watch(onboardingStateProvider);
  return state.currentStep;
});

/// Provider for getting onboarding progress percentage
final onboardingProgressProvider = Provider<double>((ref) {
  final service = ref.watch(onboardingServiceProvider);
  return service.progressPercentage;
});

/// Provider for getting company profile
final companyProfileProvider = Provider<CompanyProfile?>((ref) {
  final state = ref.watch(onboardingStateProvider);
  return state.companyProfile;
});

/// Provider for getting user profile
final userProfileProvider = Provider<UserProfile?>((ref) {
  final state = ref.watch(onboardingStateProvider);
  return state.userProfile;
});

/// Provider for checking if tutorial is completed
final isTutorialCompletedProvider = Provider<bool>((ref) {
  final state = ref.watch(onboardingStateProvider);
  return state.hasCompletedTutorial;
});

/// Provider for checking specific permissions
final permissionProvider = Provider.family<bool, String>((ref, permission) {
  final state = ref.watch(onboardingStateProvider);
  return state.permissions[permission] ?? false;
});

/// Provider for getting all permissions
final allPermissionsProvider = Provider<Map<String, bool>>((ref) {
  final state = ref.watch(onboardingStateProvider);
  return state.permissions;
});