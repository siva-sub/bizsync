import '../models/company/company_tax_profile.dart';
import '../models/rates/tax_rate_model.dart';
import '../../customers/models/customer.dart';
import '../../../core/database/crdt_database_service.dart';

/// Service to manage tax settings and company/customer GST registration status
class TaxSettingsService {
  static final TaxSettingsService _instance = TaxSettingsService._internal();
  factory TaxSettingsService() => _instance;
  TaxSettingsService._internal();

  CompanyTaxProfile? _cachedCompanyProfile;
  final CRDTDatabaseService _databaseService = CRDTDatabaseService();

  /// Get the company's GST registration status
  Future<bool> getCompanyGstRegistrationStatus() async {
    final profile = await getCompanyTaxProfile();
    return profile?.isGstRegistered ?? false;
  }

  /// Get customer's GST registration status
  Future<bool> getCustomerGstRegistrationStatus(String? customerId) async {
    if (customerId == null || customerId.isEmpty) {
      return false;
    }

    try {
      final db = await _databaseService.database;
      final result = await db.query(
        'customers',
        columns: ['gst_registered'],
        where: 'id = ?',
        whereArgs: [customerId],
        limit: 1,
      );

      if (result.isNotEmpty) {
        return (result.first['gst_registered'] as int? ?? 0) == 1;
      }
    } catch (e) {
      print('Error getting customer GST status: $e');
    }

    return false;
  }

  /// Get the company tax profile
  Future<CompanyTaxProfile?> getCompanyTaxProfile() async {
    if (_cachedCompanyProfile != null) {
      return _cachedCompanyProfile;
    }

    try {
      final db = await _databaseService.database;
      final result = await db.query(
        'company_tax_profile',
        limit: 1,
      );

      if (result.isNotEmpty) {
        _cachedCompanyProfile = _parseCompanyTaxProfile(result.first);
        return _cachedCompanyProfile;
      }
    } catch (e) {
      print('Error getting company tax profile: $e');
    }

    // Return default profile if none exists
    return _getDefaultCompanyProfile();
  }

  /// Update company GST registration status
  Future<void> updateCompanyGstRegistrationStatus(bool isRegistered, {
    String? gstNumber,
    DateTime? registrationDate,
  }) async {
    try {
      final db = await _databaseService.database;
      
      // Check if profile exists
      final existingProfile = await db.query('company_tax_profile', limit: 1);
      
      final data = {
        'is_gst_registered': isRegistered ? 1 : 0,
        'gst_number': gstNumber,
        'gst_registration_date': registrationDate?.millisecondsSinceEpoch,
        'last_updated': DateTime.now().millisecondsSinceEpoch,
      };

      if (existingProfile.isNotEmpty) {
        await db.update(
          'company_tax_profile',
          data,
          where: 'company_id = ?',
          whereArgs: [existingProfile.first['company_id']],
        );
      } else {
        // Create new profile
        data.addAll({
          'company_id': 'default_company',
          'company_name': 'My Company',
          'registration_number': 'REG001',
          'company_type': 'private_limited',
          'status': 'active',
          'residency_status': 'resident',
          'industry_classification': 'services',
          'incorporation_date': DateTime.now().millisecondsSinceEpoch,
          'financial_year_end': DateTime(DateTime.now().year, 12, 31).millisecondsSinceEpoch,
        });
        
        await db.insert('company_tax_profile', data);
      }

      // Clear cache to force reload
      _cachedCompanyProfile = null;
    } catch (e) {
      print('Error updating company GST registration: $e');
      rethrow;
    }
  }

  /// Get current GST rate based on date
  double getCurrentGstRate([DateTime? date]) {
    date ??= DateTime.now();
    
    // Singapore GST rates based on effective dates
    if (date.year >= 2024) {
      return 0.09; // 9% from Jan 2024
    } else if (date.year >= 2023) {
      return 0.08; // 8% from 2023
    } else {
      return 0.07; // 7% before 2023
    }
  }

  /// Check if GST is applicable for a transaction
  Future<bool> isGstApplicable(GstTransactionContext context) async {
    final companyGstRegistered = await getCompanyGstRegistrationStatus();
    
    // Company must be GST registered to charge GST
    if (!companyGstRegistered) {
      return false;
    }

    final customerGstRegistered = await getCustomerGstRegistrationStatus(context.customerId);
    
    // Apply business logic for GST applicability
    switch (context.transactionType) {
      case GstTransactionType.localSupply:
        return true; // GST applies to local supplies
      case GstTransactionType.export:
        return false; // Zero-rated for exports
      case GstTransactionType.import:
        return customerGstRegistered; // GST on imports if customer is registered
      case GstTransactionType.digitalService:
        return context.customerCountryCode == 'SG'; // GST on digital services to SG customers
    }
  }

  /// Get GST exemption status for specific categories
  bool isGstExempt(String itemCategory) {
    final exemptCategories = {
      'financial_services',
      'residential_property_sale',
      'residential_property_rent',
      'precious_metals_investment',
      'medical_services',
      'education_services',
    };
    
    return exemptCategories.contains(itemCategory.toLowerCase());
  }

  CompanyTaxProfile _parseCompanyTaxProfile(Map<String, dynamic> data) {
    return CompanyTaxProfile(
      companyId: data['company_id'] as String,
      companyName: data['company_name'] as String,
      registrationNumber: data['registration_number'] as String,
      companyType: _parseCompanyType(data['company_type'] as String),
      status: _parseCompanyStatus(data['status'] as String),
      residencyStatus: _parseResidencyStatus(data['residency_status'] as String),
      industryClassification: _parseIndustryClassification(data['industry_classification'] as String),
      incorporationDate: DateTime.fromMillisecondsSinceEpoch(data['incorporation_date'] as int),
      financialYearEnd: DateTime.fromMillisecondsSinceEpoch(data['financial_year_end'] as int),
      isGstRegistered: (data['is_gst_registered'] as int? ?? 0) == 1,
      gstNumber: data['gst_number'] as String?,
      gstRegistrationDate: data['gst_registration_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['gst_registration_date'] as int)
          : null,
      gstTurnoverThreshold: (data['gst_turnover_threshold'] as num?)?.toDouble(),
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(data['last_updated'] as int),
    );
  }

  CompanyTaxProfile _getDefaultCompanyProfile() {
    return CompanyTaxProfile(
      companyId: 'default_company',
      companyName: 'My Company',
      registrationNumber: 'REG001',
      companyType: CompanyType.privateLimited,
      status: CompanyStatus.active,
      residencyStatus: ResidencyStatus.resident,
      industryClassification: IndustryClassification.services,
      incorporationDate: DateTime.now(),
      financialYearEnd: DateTime(DateTime.now().year, 12, 31),
      isGstRegistered: false, // Default to not registered
      lastUpdated: DateTime.now(),
    );
  }

  CompanyType _parseCompanyType(String type) {
    switch (type.toLowerCase()) {
      case 'private_limited': return CompanyType.privateLimited;
      case 'public_limited': return CompanyType.publicLimited;
      case 'charity': return CompanyType.charity;
      case 'startup': return CompanyType.startup;
      case 'branch': return CompanyType.branch;
      case 'representative_office': return CompanyType.representativeOffice;
      default: return CompanyType.privateLimited;
    }
  }

  CompanyStatus _parseCompanyStatus(String status) {
    switch (status.toLowerCase()) {
      case 'active': return CompanyStatus.active;
      case 'dormant': return CompanyStatus.dormant;
      case 'striking': return CompanyStatus.striking;
      case 'wound': return CompanyStatus.wound;
      case 'dissolved': return CompanyStatus.dissolved;
      default: return CompanyStatus.active;
    }
  }

  ResidencyStatus _parseResidencyStatus(String status) {
    switch (status.toLowerCase()) {
      case 'resident': return ResidencyStatus.resident;
      case 'non_resident': return ResidencyStatus.nonResident;
      case 'deemed_resident': return ResidencyStatus.deemedResident;
      default: return ResidencyStatus.resident;
    }
  }

  IndustryClassification _parseIndustryClassification(String classification) {
    switch (classification.toLowerCase()) {
      case 'manufacturing': return IndustryClassification.manufacturing;
      case 'trading': return IndustryClassification.trading;
      case 'services': return IndustryClassification.services;
      case 'financial': return IndustryClassification.financial;
      case 'real_estate': return IndustryClassification.real_estate;
      case 'construction': return IndustryClassification.construction;
      case 'technology': return IndustryClassification.technology;
      case 'healthcare': return IndustryClassification.healthcare;
      case 'education': return IndustryClassification.education;
      case 'transport': return IndustryClassification.transport;
      case 'hospitality': return IndustryClassification.hospitality;
      case 'retail': return IndustryClassification.retail;
      case 'agriculture': return IndustryClassification.agriculture;
      case 'mining': return IndustryClassification.mining;
      case 'utilities': return IndustryClassification.utilities;
      case 'telecommunications': return IndustryClassification.telecommunications;
      case 'media': return IndustryClassification.media;
      case 'professional_services': return IndustryClassification.professional_services;
      case 'consulting': return IndustryClassification.consulting;
      case 'research_development': return IndustryClassification.research_development;
      default: return IndustryClassification.services;
    }
  }
}

/// Context for GST calculation decisions
class GstTransactionContext {
  final String? customerId;
  final String? customerCountryCode;
  final GstTransactionType transactionType;
  final String itemCategory;

  const GstTransactionContext({
    this.customerId,
    this.customerCountryCode,
    this.transactionType = GstTransactionType.localSupply,
    this.itemCategory = 'general',
  });
}

enum GstTransactionType {
  localSupply,
  export,
  import,
  digitalService,
}

