import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';

part 'onboarding_models.g.dart';

@JsonSerializable()
class OnboardingState {
  final bool isCompleted;
  final OnboardingStep currentStep;
  final CompanyProfile? companyProfile;
  final UserProfile? userProfile;
  final Map<String, bool> permissions;
  final bool hasCompletedTutorial;
  final DateTime? completedAt;

  const OnboardingState({
    this.isCompleted = false,
    this.currentStep = OnboardingStep.welcome,
    this.companyProfile,
    this.userProfile,
    this.permissions = const {},
    this.hasCompletedTutorial = false,
    this.completedAt,
  });

  OnboardingState copyWith({
    bool? isCompleted,
    OnboardingStep? currentStep,
    CompanyProfile? companyProfile,
    UserProfile? userProfile,
    Map<String, bool>? permissions,
    bool? hasCompletedTutorial,
    DateTime? completedAt,
  }) {
    return OnboardingState(
      isCompleted: isCompleted ?? this.isCompleted,
      currentStep: currentStep ?? this.currentStep,
      companyProfile: companyProfile ?? this.companyProfile,
      userProfile: userProfile ?? this.userProfile,
      permissions: permissions ?? this.permissions,
      hasCompletedTutorial: hasCompletedTutorial ?? this.hasCompletedTutorial,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  factory OnboardingState.fromJson(Map<String, dynamic> json) =>
      _$OnboardingStateFromJson(json);

  Map<String, dynamic> toJson() => _$OnboardingStateToJson(this);
}

enum OnboardingStep {
  welcome,
  companySetup,
  userProfile,
  permissions,
  tutorial,
  completed,
}

@JsonSerializable()
class CompanyProfile {
  final String name;
  final String businessType;
  final String industry;
  final String address;
  final String phone;
  final String email;
  final String? website;
  final bool isGstRegistered;
  final String? gstNumber;
  final String? uen;
  final String currency;
  final String timezone;

  const CompanyProfile({
    required this.name,
    required this.businessType,
    required this.industry,
    required this.address,
    required this.phone,
    required this.email,
    this.website,
    this.isGstRegistered = false,
    this.gstNumber,
    this.uen,
    this.currency = 'SGD',
    this.timezone = 'Asia/Singapore',
  });

  CompanyProfile copyWith({
    String? name,
    String? businessType,
    String? industry,
    String? address,
    String? phone,
    String? email,
    String? website,
    bool? isGstRegistered,
    String? gstNumber,
    String? uen,
    String? currency,
    String? timezone,
  }) {
    return CompanyProfile(
      name: name ?? this.name,
      businessType: businessType ?? this.businessType,
      industry: industry ?? this.industry,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      website: website ?? this.website,
      isGstRegistered: isGstRegistered ?? this.isGstRegistered,
      gstNumber: gstNumber ?? this.gstNumber,
      uen: uen ?? this.uen,
      currency: currency ?? this.currency,
      timezone: timezone ?? this.timezone,
    );
  }

  factory CompanyProfile.fromJson(Map<String, dynamic> json) =>
      _$CompanyProfileFromJson(json);

  Map<String, dynamic> toJson() => _$CompanyProfileToJson(this);
}

@JsonSerializable()
class UserProfile {
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String role;
  final String? title;
  final String? department;

  const UserProfile({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.role,
    this.title,
    this.department,
  });

  String get fullName => '$firstName $lastName';
  String get initials =>
      '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}';

  UserProfile copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? role,
    String? title,
    String? department,
  }) {
    return UserProfile(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      title: title ?? this.title,
      department: department ?? this.department,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);

  Map<String, dynamic> toJson() => _$UserProfileToJson(this);
}

class OnboardingData {
  static const List<String> businessTypes = [
    'Private Limited Company',
    'Public Limited Company',
    'Partnership',
    'Sole Proprietorship',
    'Limited Liability Partnership',
    'Branch Office',
    'Representative Office',
    'Other',
  ];

  static const List<String> industries = [
    'Accounting & Finance',
    'Advertising & Marketing',
    'Architecture & Design',
    'Automotive',
    'Construction',
    'Consulting',
    'Education',
    'Engineering',
    'Entertainment & Media',
    'Food & Beverage',
    'Healthcare',
    'Hospitality & Tourism',
    'Information Technology',
    'Legal Services',
    'Manufacturing',
    'Non-Profit',
    'Professional Services',
    'Real Estate',
    'Retail & E-commerce',
    'Transportation & Logistics',
    'Other',
  ];

  static const List<String> roles = [
    'Business Owner',
    'CEO/Managing Director',
    'CFO/Finance Director',
    'Accountant',
    'Bookkeeper',
    'Admin Manager',
    'Operations Manager',
    'Other',
  ];
}

class OnboardingConstants {
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration staggerDelay = Duration(milliseconds: 100);
  static const Duration pageTransitionDuration = Duration(milliseconds: 400);

  static const double cardBorderRadius = 16.0;
  static const double inputBorderRadius = 12.0;
  static const double buttonBorderRadius = 12.0;

  static const EdgeInsets pagePadding = EdgeInsets.all(24.0);
  static const EdgeInsets cardPadding = EdgeInsets.all(20.0);
  static const EdgeInsets inputPadding =
      EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0);
}
