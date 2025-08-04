import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/onboarding_models.dart';

class OnboardingService {
  static const String _onboardingKey = 'onboarding_state';
  static const String _tutorialKey = 'tutorial_completed';
  static const String _appVersionKey = 'app_version';

  static OnboardingService? _instance;
  static OnboardingService get instance => _instance ??= OnboardingService._();
  OnboardingService._();

  OnboardingState _currentState = const OnboardingState();

  OnboardingState get currentState => _currentState;

  final List<VoidCallback> _listeners = [];

  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  /// Initialize the onboarding service and load saved state
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedState = prefs.getString(_onboardingKey);

      if (savedState != null) {
        final json = jsonDecode(savedState) as Map<String, dynamic>;
        _currentState = OnboardingState.fromJson(json);
      }

      // Check if this is a new version that requires re-onboarding
      await _checkAppVersion();

      _notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing onboarding service: $e');
      }
      // Continue with default state
    }
  }

  /// Check if app version requires re-onboarding for new features
  Future<void> _checkAppVersion() async {
    const currentVersion = '1.0.0'; // This should come from package_info

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedVersion = prefs.getString(_appVersionKey);

      if (savedVersion != currentVersion) {
        // New version detected - might need to show what's new
        await prefs.setString(_appVersionKey, currentVersion);

        // For now, we don't force re-onboarding for version updates
        // But we could add a "What's New" tutorial here
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error checking app version: $e');
      }
    }
  }

  /// Update the current onboarding state
  Future<void> updateState(OnboardingState newState) async {
    _currentState = newState;
    await _saveState();
    _notifyListeners();
  }

  /// Move to the next step in onboarding
  Future<void> moveToNextStep() async {
    final nextStep = _getNextStep(_currentState.currentStep);
    await updateState(_currentState.copyWith(currentStep: nextStep));
  }

  /// Move to the previous step in onboarding
  Future<void> moveToPreviousStep() async {
    final previousStep = _getPreviousStep(_currentState.currentStep);
    await updateState(_currentState.copyWith(currentStep: previousStep));
  }

  /// Complete a specific onboarding step
  Future<void> completeStep(OnboardingStep step,
      {Map<String, dynamic>? data}) async {
    OnboardingState newState = _currentState;

    switch (step) {
      case OnboardingStep.welcome:
        newState = newState.copyWith(currentStep: OnboardingStep.companySetup);
        break;

      case OnboardingStep.companySetup:
        if (data != null) {
          final companyProfile = CompanyProfile.fromJson(data);
          newState = newState.copyWith(
            companyProfile: companyProfile,
            currentStep: OnboardingStep.userProfile,
          );
        }
        break;

      case OnboardingStep.userProfile:
        if (data != null) {
          final userProfile = UserProfile.fromJson(data);
          newState = newState.copyWith(
            userProfile: userProfile,
            currentStep: OnboardingStep.permissions,
          );
        }
        break;

      case OnboardingStep.permissions:
        if (data != null) {
          final permissions = Map<String, bool>.from(data);
          newState = newState.copyWith(
            permissions: permissions,
            currentStep: OnboardingStep.tutorial,
          );
        }
        break;

      case OnboardingStep.tutorial:
        newState = newState.copyWith(
          hasCompletedTutorial: true,
          currentStep: OnboardingStep.completed,
        );
        break;

      case OnboardingStep.completed:
        newState = newState.copyWith(
          isCompleted: true,
          completedAt: DateTime.now(),
        );
        break;
    }

    await updateState(newState);
  }

  /// Complete the entire onboarding process
  Future<void> completeOnboarding() async {
    final newState = _currentState.copyWith(
      isCompleted: true,
      currentStep: OnboardingStep.completed,
      completedAt: DateTime.now(),
    );

    await updateState(newState);
  }

  /// Skip onboarding (for testing or returning users)
  Future<void> skipOnboarding() async {
    await completeOnboarding();
  }

  /// Reset onboarding state (for testing)
  Future<void> resetOnboarding() async {
    _currentState = const OnboardingState();
    await _saveState();
    _notifyListeners();
  }

  /// Check if onboarding is completed
  bool get isOnboardingCompleted => _currentState.isCompleted;

  /// Check if a specific step is completed
  bool isStepCompleted(OnboardingStep step) {
    final currentStepIndex =
        OnboardingStep.values.indexOf(_currentState.currentStep);
    final checkStepIndex = OnboardingStep.values.indexOf(step);
    return _currentState.isCompleted || currentStepIndex > checkStepIndex;
  }

  /// Get the next step
  OnboardingStep _getNextStep(OnboardingStep currentStep) {
    final currentIndex = OnboardingStep.values.indexOf(currentStep);
    if (currentIndex < OnboardingStep.values.length - 1) {
      return OnboardingStep.values[currentIndex + 1];
    }
    return OnboardingStep.completed;
  }

  /// Get the previous step
  OnboardingStep _getPreviousStep(OnboardingStep currentStep) {
    final currentIndex = OnboardingStep.values.indexOf(currentStep);
    if (currentIndex > 0) {
      return OnboardingStep.values[currentIndex - 1];
    }
    return OnboardingStep.welcome;
  }

  /// Save the current state to persistent storage
  Future<void> _saveState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_currentState.toJson());
      await prefs.setString(_onboardingKey, json);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving onboarding state: $e');
      }
    }
  }

  /// Get progress percentage for current onboarding step
  double get progressPercentage {
    if (_currentState.isCompleted) return 1.0;

    final currentIndex =
        OnboardingStep.values.indexOf(_currentState.currentStep);
    final totalSteps =
        OnboardingStep.values.length - 1; // Exclude completed step

    return currentIndex / totalSteps;
  }

  /// Get remaining steps count
  int get remainingSteps {
    if (_currentState.isCompleted) return 0;

    final currentIndex =
        OnboardingStep.values.indexOf(_currentState.currentStep);
    return OnboardingStep.values.length - 1 - currentIndex;
  }

  /// Check if user has required permissions
  bool hasPermission(String permission) {
    return _currentState.permissions[permission] ?? false;
  }

  /// Update a specific permission
  Future<void> updatePermission(String permission, bool granted) async {
    final updatedPermissions =
        Map<String, bool>.from(_currentState.permissions);
    updatedPermissions[permission] = granted;

    await updateState(_currentState.copyWith(permissions: updatedPermissions));
  }

  /// Request and update multiple permissions
  Future<void> updatePermissions(Map<String, bool> permissions) async {
    final updatedPermissions =
        Map<String, bool>.from(_currentState.permissions);
    updatedPermissions.addAll(permissions);

    await updateState(_currentState.copyWith(permissions: updatedPermissions));
  }
}
