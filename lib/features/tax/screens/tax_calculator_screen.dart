import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/rates/tax_rate_model.dart';
import '../models/company/company_tax_profile.dart';
import '../models/fx/fx_rate_model.dart';
import '../services/calculation/tax_calculation_service.dart';

enum CalculatorType {
  gst,
  corporateTax,
  withholdingTax,
  stampDuty,
  importDuty,
}

class TaxCalculatorScreen extends ConsumerStatefulWidget {
  final CalculatorType calculatorType;

  const TaxCalculatorScreen({
    super.key,
    required this.calculatorType,
  });

  @override
  ConsumerState<TaxCalculatorScreen> createState() =>
      _TaxCalculatorScreenState();
}

class _TaxCalculatorScreenState extends ConsumerState<TaxCalculatorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  // Form fields
  DateTime _calculationDate = DateTime.now();
  CompanyType _companyType = CompanyType.privateLimited;
  Currency _currency = Currency.sgd;
  bool _isGstRegistered = true;
  String _recipientCountry = 'SG';
  String _incomeType = 'dividends';
  String _instrumentType = 'shares';

  TaxCalculationResult? _result;
  bool _isCalculating = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getCalculatorTitle()),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => _showCalculationHistory(),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _result != null ? () => _shareResult() : null,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildCalculatorForm(),
                    if (_result != null) ...[
                      const SizedBox(height: 24),
                      _buildResultCard(),
                    ],
                  ],
                ),
              ),
            ),
            _buildActionBar(),
          ],
        ),
      ),
    );
  }

  String _getCalculatorTitle() {
    switch (widget.calculatorType) {
      case CalculatorType.gst:
        return 'GST Calculator';
      case CalculatorType.corporateTax:
        return 'Corporate Tax Calculator';
      case CalculatorType.withholdingTax:
        return 'Withholding Tax Calculator';
      case CalculatorType.stampDuty:
        return 'Stamp Duty Calculator';
      case CalculatorType.importDuty:
        return 'Import Duty Calculator';
    }
  }

  Widget _buildCalculatorForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Calculation Parameters',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            // Amount field
            TextFormField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: _getCurrencySymbol(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _amountController.clear(),
                ),
                border: const OutlineInputBorder(),
                helperText: _getAmountHelperText(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an amount';
                }
                final amount = double.tryParse(value);
                if (amount == null || amount <= 0) {
                  return 'Please enter a valid positive amount';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Date field
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: const Text('Calculation Date'),
              subtitle: Text(_calculationDate.toString().split(' ')[0]),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _selectDate,
            ),

            const Divider(),

            // Calculator-specific fields
            ..._buildSpecificFields(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSpecificFields() {
    switch (widget.calculatorType) {
      case CalculatorType.gst:
        return _buildGstFields();
      case CalculatorType.corporateTax:
        return _buildCorporateTaxFields();
      case CalculatorType.withholdingTax:
        return _buildWithholdingTaxFields();
      case CalculatorType.stampDuty:
        return _buildStampDutyFields();
      case CalculatorType.importDuty:
        return _buildImportDutyFields();
    }
  }

  List<Widget> _buildGstFields() {
    return [
      SwitchListTile(
        title: const Text('GST Registered'),
        subtitle: const Text('Is the business GST registered?'),
        value: _isGstRegistered,
        onChanged: (value) => setState(() => _isGstRegistered = value),
      ),
      const SizedBox(height: 8),
      DropdownButtonFormField<Currency>(
        value: _currency,
        decoration: const InputDecoration(
          labelText: 'Currency',
          border: OutlineInputBorder(),
        ),
        items: Currency.values.map((currency) {
          return DropdownMenuItem(
            value: currency,
            child: Text(
                '${currency.name.toUpperCase()} - ${_getCurrencyName(currency)}'),
          );
        }).toList(),
        onChanged: (value) => setState(() => _currency = value!),
      ),
    ];
  }

  List<Widget> _buildCorporateTaxFields() {
    return [
      DropdownButtonFormField<CompanyType>(
        value: _companyType,
        decoration: const InputDecoration(
          labelText: 'Company Type',
          border: OutlineInputBorder(),
        ),
        items: CompanyType.values.map((type) {
          return DropdownMenuItem(
            value: type,
            child: Text(_getCompanyTypeName(type)),
          );
        }).toList(),
        onChanged: (value) => setState(() => _companyType = value!),
      ),
      const SizedBox(height: 16),
      Text(
        'Tax Reliefs & Exemptions',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      if (_companyType == CompanyType.startup)
        const ListTile(
          leading: Icon(Icons.stars, color: Colors.orange),
          title: Text('Startup Tax Exemption'),
          subtitle: Text('First S\$100,000 exempt, next S\$200,000 at 8.5%'),
        ),
      if (_companyType == CompanyType.charity)
        const ListTile(
          leading: Icon(Icons.favorite, color: Colors.red),
          title: Text('Charity Tax Exemption'),
          subtitle: Text('Full exemption from corporate tax'),
        ),
      if ([CompanyType.privateLimited, CompanyType.publicLimited]
          .contains(_companyType))
        const ListTile(
          leading: Icon(Icons.discount, color: Colors.blue),
          title: Text('Partial Tax Exemption'),
          subtitle: Text('First S\$10,000 at 0%, next S\$190,000 at 8.5%'),
        ),
    ];
  }

  List<Widget> _buildWithholdingTaxFields() {
    return [
      DropdownButtonFormField<String>(
        value: _incomeType,
        decoration: const InputDecoration(
          labelText: 'Income Type',
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(value: 'dividends', child: Text('Dividends')),
          DropdownMenuItem(value: 'interest', child: Text('Interest')),
          DropdownMenuItem(value: 'royalties', child: Text('Royalties')),
          DropdownMenuItem(
              value: 'management_fees', child: Text('Management Fees')),
          DropdownMenuItem(
              value: 'technical_fees', child: Text('Technical Fees')),
        ],
        onChanged: (value) => setState(() => _incomeType = value!),
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        value: _recipientCountry,
        decoration: const InputDecoration(
          labelText: 'Recipient Country',
          border: OutlineInputBorder(),
          helperText: 'Country of tax residence of recipient',
        ),
        items: const [
          DropdownMenuItem(value: 'SG', child: Text('Singapore')),
          DropdownMenuItem(value: 'US', child: Text('United States')),
          DropdownMenuItem(value: 'UK', child: Text('United Kingdom')),
          DropdownMenuItem(value: 'CN', child: Text('China')),
          DropdownMenuItem(value: 'IN', child: Text('India')),
          DropdownMenuItem(value: 'MY', child: Text('Malaysia')),
          DropdownMenuItem(value: 'OTHER', child: Text('Other Country')),
        ],
        onChanged: (value) => setState(() => _recipientCountry = value!),
      ),
      if (_recipientCountry != 'SG') ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.info, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tax treaty may apply. Ensure Certificate of Residence is obtained.',
                  style: TextStyle(color: Colors.blue[700]),
                ),
              ),
            ],
          ),
        ),
      ],
    ];
  }

  List<Widget> _buildStampDutyFields() {
    return [
      DropdownButtonFormField<String>(
        value: _instrumentType,
        decoration: const InputDecoration(
          labelText: 'Instrument Type',
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(value: 'shares', child: Text('Shares Transfer')),
          DropdownMenuItem(value: 'property', child: Text('Property Purchase')),
          DropdownMenuItem(value: 'mortgage', child: Text('Mortgage')),
          DropdownMenuItem(value: 'lease', child: Text('Lease Agreement')),
        ],
        onChanged: (value) => setState(() => _instrumentType = value!),
      ),
      if (_instrumentType == 'property') ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning, color: Colors.orange),
                  const SizedBox(width: 8),
                  const Text('Property Stamp Duty Rates',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              const Text('• Citizens (first property): 1-4% progressive rates'),
              const Text('• Additional Buyer\'s Stamp Duty may apply'),
              const Text(
                  '• Rates vary based on property value and buyer status'),
            ],
          ),
        ),
      ],
    ];
  }

  List<Widget> _buildImportDutyFields() {
    return [
      TextFormField(
        decoration: const InputDecoration(
          labelText: 'HS Code',
          border: OutlineInputBorder(),
          helperText: 'Harmonized System classification code',
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter HS code';
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        value: 'SG',
        decoration: const InputDecoration(
          labelText: 'Country of Origin',
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(value: 'ASEAN', child: Text('ASEAN Country')),
          DropdownMenuItem(value: 'CN', child: Text('China')),
          DropdownMenuItem(value: 'US', child: Text('United States')),
          DropdownMenuItem(value: 'EU', child: Text('European Union')),
          DropdownMenuItem(value: 'OTHER', child: Text('Other Country')),
        ],
        onChanged: (value) {},
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_offer, color: Colors.green),
                const SizedBox(width: 8),
                const Text('Preferential Trade Agreements',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            const Text('• ASEAN Free Trade Area - 0% duty on most goods'),
            const Text('• CPTPP, EUSFTA - Reduced or eliminated tariffs'),
            const Text('• Certificate of Origin may be required'),
          ],
        ),
      ),
    ];
  }

  Widget _buildResultCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calculate,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Calculation Result',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildResultSummary(),
            const SizedBox(height: 16),
            if (_result!.breakdown.isNotEmpty) ...[
              Text(
                'Breakdown',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ..._result!.breakdown.map(_buildBreakdownItem),
            ],
            if (_result!.appliedReliefs.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Applied Tax Reliefs',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ..._result!.appliedReliefs.map(_buildReliefItem),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildSummaryRow('Gross Amount', _result!.grossAmount),
          if (_result!.taxableAmount != _result!.grossAmount)
            _buildSummaryRow('Taxable Amount', _result!.taxableAmount),
          _buildSummaryRow(
              'Tax Rate', '${(_result!.taxRate * 100).toStringAsFixed(2)}%',
              isRate: true),
          _buildSummaryRow('Tax Amount', _result!.taxAmount,
              isHighlighted: true),
          const Divider(),
          _buildSummaryRow('Net Amount', _result!.netAmount, isTotal: true),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, dynamic value,
      {bool isRate = false, bool isHighlighted = false, bool isTotal = false}) {
    final textStyle = isTotal
        ? Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold)
        : isHighlighted
            ? Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: Theme.of(context).primaryColor)
            : Theme.of(context).textTheme.bodyLarge;

    final displayValue = isRate
        ? value.toString()
        : '${_getCurrencySymbol()}${(value as double).toStringAsFixed(2)}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: textStyle),
          Text(displayValue, style: textStyle),
        ],
      ),
    );
  }

  Widget _buildBreakdownItem(TaxCalculationBreakdown breakdown) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(breakdown.description),
        subtitle: breakdown.legislation != null
            ? Text('Legislation: ${breakdown.legislation}')
            : null,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${(breakdown.rate * 100).toStringAsFixed(2)}%'),
            Text(
              '${_getCurrencySymbol()}${breakdown.taxAmount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReliefItem(relief) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.green.withOpacity(0.1),
      child: ListTile(
        leading: const Icon(Icons.savings, color: Colors.green),
        title: Text(relief.name),
        subtitle: Text(relief.description),
        trailing: const Icon(Icons.check_circle, color: Colors.green),
      ),
    );
  }

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _clearForm,
              child: const Text('Clear'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isCalculating ? null : _calculate,
              child: _isCalculating
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Calculate'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _calculationDate,
      firstDate: DateTime(1990),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _calculationDate = date);
    }
  }

  void _clearForm() {
    setState(() {
      _amountController.clear();
      _calculationDate = DateTime.now();
      _companyType = CompanyType.privateLimited;
      _currency = Currency.sgd;
      _isGstRegistered = true;
      _recipientCountry = 'SG';
      _incomeType = 'dividends';
      _instrumentType = 'shares';
      _result = null;
    });
  }

  Future<void> _calculate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isCalculating = true);

    try {
      final amount = double.parse(_amountController.text);

      // Create dummy profile for calculation
      final profile = CompanyTaxProfile(
        companyId: 'temp',
        companyName: 'Test Company',
        registrationNumber: '000000A',
        companyType: _companyType,
        status: CompanyStatus.active,
        residencyStatus: ResidencyStatus.resident,
        industryClassification: IndustryClassification.services,
        incorporationDate: DateTime.now().subtract(const Duration(days: 365)),
        financialYearEnd: DateTime(DateTime.now().year, 12, 31),
        isGstRegistered: _isGstRegistered,
        lastUpdated: DateTime.now(),
      );

      final context = TaxCalculationContext(
        companyProfile: profile,
        calculationDate: _calculationDate,
        currency: _currency,
        transactionDetails: {
          'incomeType': _incomeType,
          'recipientCountry': _recipientCountry,
          'instrumentType': _instrumentType,
        },
        availableReliefs: [],
      );

      final taxType = _getTaxTypeFromCalculator();

      // Simulate calculation (in real app, would use actual service)
      await Future.delayed(const Duration(milliseconds: 500));

      final result = await _performCalculation(amount, taxType, context);

      setState(() => _result = result);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Calculation error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isCalculating = false);
    }
  }

  TaxType _getTaxTypeFromCalculator() {
    switch (widget.calculatorType) {
      case CalculatorType.gst:
        return TaxType.gst;
      case CalculatorType.corporateTax:
        return TaxType.corporateTax;
      case CalculatorType.withholdingTax:
        return TaxType.withholdingTax;
      case CalculatorType.stampDuty:
        return TaxType.stampDuty;
      case CalculatorType.importDuty:
        return TaxType.importDuty;
    }
  }

  Future<TaxCalculationResult> _performCalculation(
    double amount,
    TaxType taxType,
    TaxCalculationContext context,
  ) async {
    // Simplified calculation logic - in real app would use TaxCalculationService
    double taxRate = 0;
    String description = '';
    List<TaxCalculationBreakdown> breakdown = [];

    switch (taxType) {
      case TaxType.gst:
        if (_isGstRegistered) {
          taxRate = 0.09; // 9% current GST rate
          description = 'GST 9%';
        }
        break;
      case TaxType.corporateTax:
        taxRate = 0.17; // Standard corporate tax rate
        description = 'Corporate Tax 17%';

        // Apply exemptions for startups
        if (_companyType == CompanyType.startup) {
          if (amount <= 100000) {
            taxRate = 0; // First S$100k exempt
            description = 'Startup Exemption - First S\$100,000';
          } else if (amount <= 300000) {
            // Mixed calculation needed
            final exemptPortion = 100000;
            final partialPortion = amount - 100000;
            final partialTax = partialPortion * 0.085;

            return TaxCalculationResult(
              grossAmount: amount,
              taxableAmount: amount,
              taxRate: partialTax / amount,
              taxAmount: partialTax,
              netAmount: amount - partialTax,
              breakdown: [
                TaxCalculationBreakdown(
                  description: 'Startup Exemption - First S\$100,000',
                  amount: exemptPortion.toDouble(),
                  rate: 0,
                  taxAmount: 0,
                  taxType: TaxType.corporateTax,
                  legislation: 'Income Tax Act Section 43A',
                ),
                TaxCalculationBreakdown(
                  description:
                      'Startup Partial Exemption - Next S\$200,000 at 8.5%',
                  amount: partialPortion,
                  rate: 0.085,
                  taxAmount: partialTax,
                  taxType: TaxType.corporateTax,
                  legislation: 'Income Tax Act Section 43A',
                ),
              ],
              appliedReliefs: [],
              metadata: {},
            );
          }
        }
        break;
      case TaxType.withholdingTax:
        switch (_incomeType) {
          case 'dividends':
            taxRate = 0; // One-tier system
            description = 'Withholding Tax on Dividends (One-tier system)';
            break;
          case 'interest':
            taxRate = _recipientCountry == 'SG' ? 0 : 0.15;
            description = 'Withholding Tax on Interest';
            break;
          case 'royalties':
            taxRate = _recipientCountry == 'SG' ? 0 : 0.10;
            description = 'Withholding Tax on Royalties';
            break;
          default:
            taxRate = _recipientCountry == 'SG' ? 0 : 0.17;
            description = 'Withholding Tax (Standard rate)';
        }
        break;
      case TaxType.stampDuty:
        switch (_instrumentType) {
          case 'shares':
            taxRate = 0.002; // 0.2%
            description = 'Stamp Duty on Shares 0.2%';
            break;
          case 'property':
            taxRate = 0.04; // Simplified 4%
            description = 'Property Stamp Duty';
            break;
          default:
            taxRate = 0.001;
            description = 'General Stamp Duty';
        }
        break;
      case TaxType.importDuty:
        taxRate = 0.07; // Simplified 7% (includes GST)
        description = 'Import Duty + GST';
        break;
      default:
        break;
    }

    final taxAmount = amount * taxRate;
    final netAmount = taxType == TaxType.gst
        ? amount + taxAmount // GST is added
        : amount - taxAmount; // Other taxes are deducted

    breakdown.add(TaxCalculationBreakdown(
      description: description,
      amount: amount,
      rate: taxRate,
      taxAmount: taxAmount,
      taxType: taxType,
      legislation: _getLegislation(taxType),
    ));

    return TaxCalculationResult(
      grossAmount: amount,
      taxableAmount: amount,
      taxRate: taxRate,
      taxAmount: taxAmount,
      netAmount: netAmount,
      breakdown: breakdown,
      appliedReliefs: [],
      metadata: {
        'calculationDate': _calculationDate.toIso8601String(),
        'currency': _currency.name,
      },
    );
  }

  String? _getLegislation(TaxType taxType) {
    switch (taxType) {
      case TaxType.gst:
        return 'Goods and Services Tax Act';
      case TaxType.corporateTax:
        return 'Income Tax Act';
      case TaxType.withholdingTax:
        return 'Income Tax Act Section 45';
      case TaxType.stampDuty:
        return 'Stamp Duties Act';
      case TaxType.importDuty:
        return 'Customs Act';
      default:
        return null;
    }
  }

  void _showCalculationHistory() {
    // TODO: Show calculation history
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Calculation history feature coming soon')),
    );
  }

  void _shareResult() {
    if (_result == null) return;

    // TODO: Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share functionality coming soon')),
    );
  }

  String _getCurrencySymbol() {
    switch (_currency) {
      case Currency.sgd:
        return 'S\$ ';
      case Currency.usd:
        return 'US\$ ';
      case Currency.eur:
        return '€ ';
      case Currency.gbp:
        return '£ ';
      default:
        return '${_currency.name.toUpperCase()} ';
    }
  }

  String _getCurrencyName(Currency currency) {
    switch (currency) {
      case Currency.sgd:
        return 'Singapore Dollar';
      case Currency.usd:
        return 'US Dollar';
      case Currency.eur:
        return 'Euro';
      case Currency.gbp:
        return 'British Pound';
      default:
        return currency.name.toUpperCase();
    }
  }

  String _getCompanyTypeName(CompanyType type) {
    switch (type) {
      case CompanyType.privateLimited:
        return 'Private Limited Company';
      case CompanyType.publicLimited:
        return 'Public Limited Company';
      case CompanyType.charity:
        return 'Charity/Non-Profit';
      case CompanyType.startup:
        return 'Startup (Qualifying)';
      case CompanyType.branch:
        return 'Branch Office';
      default:
        return type.name;
    }
  }

  String _getAmountHelperText() {
    switch (widget.calculatorType) {
      case CalculatorType.gst:
        return 'Enter the net amount (excluding GST)';
      case CalculatorType.corporateTax:
        return 'Enter the chargeable income';
      case CalculatorType.withholdingTax:
        return 'Enter the gross payment amount';
      case CalculatorType.stampDuty:
        return 'Enter the value of instrument/transaction';
      case CalculatorType.importDuty:
        return 'Enter the CIF value of goods';
    }
  }
}
