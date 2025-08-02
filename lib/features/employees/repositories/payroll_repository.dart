import 'dart:async';
import '../../../core/database/crdt_database_service.dart';
import '../../../core/crdt/hybrid_logical_clock.dart';
import '../models/index.dart';

/// Repository for Payroll data operations with CRDT support
class PayrollRepository {
  final CRDTDatabaseService _database;
  
  PayrollRepository(this._database);
  
  // ============================================================================
  // PAYROLL RECORD OPERATIONS
  // ============================================================================
  
  /// Save payroll record to database
  Future<void> savePayrollRecord(CRDTPayrollRecord payrollRecord) async {
    await _database.insert(
      table: 'payroll_records',
      data: payrollRecord.toCRDTJson(),
      id: payrollRecord.id,
    );
  }
  
  /// Get payroll record by ID
  Future<CRDTPayrollRecord?> getPayrollRecord(String payrollRecordId) async {
    final data = await _database.get('payroll_records', payrollRecordId);
    if (data == null) return null;
    
    return CRDTPayrollRecord.fromCRDTJson(data);
  }
  
  /// Get payroll records for an employee
  Future<List<CRDTPayrollRecord>> getPayrollRecordsForEmployee(
    String employeeId, {
    DateTime? fromDate,
    DateTime? toDate,
    String? status,
    int? limit,
    int? offset,
  }) async {
    final conditions = <String>[];
    final args = <dynamic>[];
    
    conditions.add('JSON_EXTRACT(data, "\$.employee_id.value") = ?');
    args.add(employeeId);
    
    conditions.add('JSON_EXTRACT(data, "\$.is_deleted") = ?');
    args.add(false);
    
    if (fromDate != null) {
      conditions.add('datetime(JSON_EXTRACT(data, "\$.pay_period_start.value") / 1000, \'unixepoch\') >= datetime(?)');
      args.add(fromDate.toIso8601String());
    }
    
    if (toDate != null) {
      conditions.add('datetime(JSON_EXTRACT(data, "\$.pay_period_end.value") / 1000, \'unixepoch\') <= datetime(?)');
      args.add(toDate.toIso8601String());
    }
    
    if (status != null) {
      conditions.add('JSON_EXTRACT(data, "\$.status.value") = ?');
      args.add(status);
    }
    
    final results = await _database.query(
      table: 'payroll_records',
      where: conditions.join(' AND '),
      whereArgs: args,
      orderBy: 'JSON_EXTRACT(data, "\$.pay_period_start.value") DESC',
      limit: limit,
      offset: offset,
    );
    
    return results.map((data) => CRDTPayrollRecord.fromCRDTJson(data)).toList();
  }
  
  /// Get payroll records for a pay period
  Future<List<CRDTPayrollRecord>> getPayrollRecordsForPeriod(
    DateTime periodStart,
    DateTime periodEnd, {
    String? department,
    String? status,
  }) async {
    final conditions = <String>[];
    final args = <dynamic>[];
    
    conditions.add('JSON_EXTRACT(data, "\$.is_deleted") = ?');
    args.add(false);
    
    conditions.add('''
      datetime(JSON_EXTRACT(data, "\$.pay_period_start.value") / 1000, 'unixepoch') >= datetime(?) AND
      datetime(JSON_EXTRACT(data, "\$.pay_period_end.value") / 1000, 'unixepoch') <= datetime(?)
    ''');
    args.add(periodStart.toIso8601String());
    args.add(periodEnd.toIso8601String());
    
    if (status != null) {
      conditions.add('JSON_EXTRACT(data, "\$.status.value") = ?');
      args.add(status);
    }
    
    final results = await _database.query(
      table: 'payroll_records',
      where: conditions.join(' AND '),
      whereArgs: args,
      orderBy: 'JSON_EXTRACT(data, "\$.employee_id.value")',
    );
    
    return results.map((data) => CRDTPayrollRecord.fromCRDTJson(data)).toList();
  }
  
  /// Update payroll record
  Future<void> updatePayrollRecord(CRDTPayrollRecord payrollRecord) async {
    await _database.update(
      table: 'payroll_records',
      id: payrollRecord.id,
      data: payrollRecord.toCRDTJson(),
    );
  }
  
  /// Delete payroll record (soft delete)
  Future<void> deletePayrollRecord(String payrollRecordId) async {
    final payroll = await getPayrollRecord(payrollRecordId);
    if (payroll == null) return;
    
    payroll.isDeleted = true;
    payroll.updatedAt = HLCTimestamp.now(_database.nodeId);
    
    await updatePayrollRecord(payroll);
  }
  
  /// Get payroll statistics for a period
  Future<Map<String, dynamic>> getPayrollStatistics({
    required DateTime startDate,
    required DateTime endDate,
    String? department,
  }) async {
    final conditions = <String>[];
    final args = <dynamic>[];
    
    conditions.add('JSON_EXTRACT(data, "\$.is_deleted") = ?');
    args.add(false);
    
    conditions.add('''
      datetime(JSON_EXTRACT(data, "\$.pay_period_start.value") / 1000, 'unixepoch') >= datetime(?) AND
      datetime(JSON_EXTRACT(data, "\$.pay_period_end.value") / 1000, 'unixepoch') <= datetime(?)
    ''');
    args.add(startDate.toIso8601String());
    args.add(endDate.toIso8601String());
    
    final whereClause = conditions.join(' AND ');
    
    // Get aggregated statistics
    final statsResult = await _database.rawQuery('''
      SELECT 
        COUNT(*) as total_records,
        SUM(CAST(JSON_EXTRACT(data, "\$.basic_salary_cents.value") AS REAL) / 100.0) as total_basic_salary,
        SUM(CAST(JSON_EXTRACT(data, "\$.allowances_cents.value") AS REAL) / 100.0) as total_allowances,
        SUM(CAST(JSON_EXTRACT(data, "\$.overtime_cents.value") AS REAL) / 100.0) as total_overtime,
        SUM(CAST(JSON_EXTRACT(data, "\$.bonus_cents.value") AS REAL) / 100.0) as total_bonus,
        SUM(CAST(JSON_EXTRACT(data, "\$.cpf_employee_cents.value") AS REAL) / 100.0) as total_cpf_employee,
        SUM(CAST(JSON_EXTRACT(data, "\$.cpf_employer_cents.value") AS REAL) / 100.0) as total_cpf_employer,
        SUM(CAST(JSON_EXTRACT(data, "\$.sdl_cents.value") AS REAL) / 100.0) as total_sdl,
        SUM(CAST(JSON_EXTRACT(data, "\$.fwl_cents.value") AS REAL) / 100.0) as total_fwl,
        AVG(CAST(JSON_EXTRACT(data, "\$.basic_salary_cents.value") AS REAL) / 100.0) as avg_basic_salary
      FROM payroll_records 
      WHERE $whereClause
    ''', args);
    
    final stats = statsResult.first;
    
    // Convert null values to 0
    final result = <String, dynamic>{};
    stats.forEach((key, value) {
      result[key] = value ?? 0.0;
    });
    
    // Calculate gross and net totals
    final totalGross = (result['total_basic_salary'] as double) +
                      (result['total_allowances'] as double) +
                      (result['total_overtime'] as double) +
                      (result['total_bonus'] as double);
    
    final totalNet = totalGross - (result['total_cpf_employee'] as double);
    
    result['total_gross_pay'] = totalGross;
    result['total_net_pay'] = totalNet;
    result['total_employer_costs'] = totalGross + 
                                    (result['total_cpf_employer'] as double) +
                                    (result['total_sdl'] as double) +
                                    (result['total_fwl'] as double);
    
    return result;
  }
  
  // ============================================================================
  // CPF CALCULATION OPERATIONS
  // ============================================================================
  
  /// Save CPF calculation
  Future<void> saveCpfCalculation(CRDTSingaporeCpfCalculation cpfCalculation) async {
    await _database.insert(
      table: 'cpf_calculations',
      data: cpfCalculation.toCRDTJson(),
      id: cpfCalculation.id,
    );
  }
  
  /// Get CPF calculation by ID
  Future<CRDTSingaporeCpfCalculation?> getCpfCalculation(String calculationId) async {
    final data = await _database.get('cpf_calculations', calculationId);
    if (data == null) return null;
    
    return CRDTSingaporeCpfCalculation.fromCRDTJson(data);
  }
  
  /// Get CPF calculations for an employee
  Future<List<CRDTSingaporeCpfCalculation>> getCpfCalculationsForEmployee(
    String employeeId, {
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final conditions = <String>[];
    final args = <dynamic>[];
    
    conditions.add('JSON_EXTRACT(data, "\$.employee_id.value") = ?');
    args.add(employeeId);
    
    conditions.add('JSON_EXTRACT(data, "\$.is_deleted") = ?');
    args.add(false);
    
    if (fromDate != null) {
      conditions.add('datetime(JSON_EXTRACT(data, "\$.calculation_date.value") / 1000, \'unixepoch\') >= datetime(?)');
      args.add(fromDate.toIso8601String());
    }
    
    if (toDate != null) {
      conditions.add('datetime(JSON_EXTRACT(data, "\$.calculation_date.value") / 1000, \'unixepoch\') <= datetime(?)');
      args.add(toDate.toIso8601String());
    }
    
    final results = await _database.query(
      table: 'cpf_calculations',
      where: conditions.join(' AND '),
      whereArgs: args,
      orderBy: 'JSON_EXTRACT(data, "\$.calculation_date.value") DESC',
    );
    
    return results.map((data) => CRDTSingaporeCpfCalculation.fromCRDTJson(data)).toList();
  }
  
  /// Update CPF calculation
  Future<void> updateCpfCalculation(CRDTSingaporeCpfCalculation cpfCalculation) async {
    await _database.update(
      table: 'cpf_calculations',
      id: cpfCalculation.id,
      data: cpfCalculation.toCRDTJson(),
    );
  }
  
  // ============================================================================
  // IR8A TAX FORM OPERATIONS
  // ============================================================================
  
  /// Save IR8A tax form
  Future<void> saveIR8ATaxForm(CRDTIR8ATaxForm taxForm) async {
    await _database.insert(
      table: 'ir8a_tax_forms',
      data: taxForm.toCRDTJson(),
      id: taxForm.id,
    );
  }
  
  /// Get IR8A tax form by ID
  Future<CRDTIR8ATaxForm?> getIR8ATaxForm(String taxFormId) async {
    final data = await _database.get('ir8a_tax_forms', taxFormId);
    if (data == null) return null;
    
    return CRDTIR8ATaxForm.fromCRDTJson(data);
  }
  
  /// Get IR8A tax forms for an employee
  Future<List<CRDTIR8ATaxForm>> getIR8ATaxFormsForEmployee(
    String employeeId, {
    int? taxYear,
  }) async {
    final conditions = <String>[];
    final args = <dynamic>[];
    
    conditions.add('JSON_EXTRACT(data, "\$.employee_id.value") = ?');
    args.add(employeeId);
    
    conditions.add('JSON_EXTRACT(data, "\$.is_deleted") = ?');
    args.add(false);
    
    if (taxYear != null) {
      conditions.add('JSON_EXTRACT(data, "\$.tax_year.value") = ?');
      args.add(taxYear);
    }
    
    final results = await _database.query(
      table: 'ir8a_tax_forms',
      where: conditions.join(' AND '),
      whereArgs: args,
      orderBy: 'JSON_EXTRACT(data, "\$.tax_year.value") DESC',
    );
    
    return results.map((data) => CRDTIR8ATaxForm.fromCRDTJson(data)).toList();
  }
  
  /// Get IR8A tax forms for a tax year
  Future<List<CRDTIR8ATaxForm>> getIR8ATaxFormsForYear(int taxYear) async {
    final results = await _database.query(
      table: 'ir8a_tax_forms',
      where: 'JSON_EXTRACT(data, "\$.tax_year.value") = ? AND JSON_EXTRACT(data, "\$.is_deleted") = ?',
      whereArgs: [taxYear, false],
      orderBy: 'JSON_EXTRACT(data, "\$.employee_name.value")',
    );
    
    return results.map((data) => CRDTIR8ATaxForm.fromCRDTJson(data)).toList();
  }
  
  /// Update IR8A tax form
  Future<void> updateIR8ATaxForm(CRDTIR8ATaxForm taxForm) async {
    await _database.update(
      table: 'ir8a_tax_forms',
      id: taxForm.id,
      data: taxForm.toCRDTJson(),
    );
  }
  
  // ============================================================================
  // PAY COMPONENT OPERATIONS
  // ============================================================================
  
  /// Save pay component
  Future<void> savePayComponent(CRDTPayComponent payComponent) async {
    await _database.insert(
      table: 'pay_components',
      data: payComponent.toCRDTJson(),
      id: payComponent.id,
    );
  }
  
  /// Get pay components for a payroll record
  Future<List<CRDTPayComponent>> getPayComponentsForPayroll(String payrollRecordId) async {
    final results = await _database.query(
      table: 'pay_components',
      where: 'JSON_EXTRACT(data, "\$.payroll_record_id.value") = ? AND JSON_EXTRACT(data, "\$.is_deleted") = ?',
      whereArgs: [payrollRecordId, false],
      orderBy: 'JSON_EXTRACT(data, "\$.component_type.value")',
    );
    
    return results.map((data) => CRDTPayComponent.fromCRDTJson(data)).toList();
  }
  
  /// Update pay component
  Future<void> updatePayComponent(CRDTPayComponent payComponent) async {
    await _database.update(
      table: 'pay_components',
      id: payComponent.id,
      data: payComponent.toCRDTJson(),
    );
  }
  
  // ============================================================================
  // BATCH OPERATIONS
  // ============================================================================
  
  /// Batch insert payroll records
  Future<void> batchInsertPayrollRecords(List<CRDTPayrollRecord> payrollRecords) async {
    await _database.batchInsert(
      table: 'payroll_records',
      records: payrollRecords.map((record) => {
        'id': record.id,
        'data': record.toCRDTJson(),
      }).toList(),
    );
  }
  
  /// Get pending payroll records
  Future<List<CRDTPayrollRecord>> getPendingPayrollRecords() async {
    final results = await _database.query(
      table: 'payroll_records',
      where: 'JSON_EXTRACT(data, "\$.status.value") = ? AND JSON_EXTRACT(data, "\$.is_deleted") = ?',
      whereArgs: ['draft', false],
      orderBy: 'JSON_EXTRACT(data, "\$.pay_date.value")',
    );
    
    return results.map((data) => CRDTPayrollRecord.fromCRDTJson(data)).toList();
  }
  
  /// Get approved payroll records for payment processing
  Future<List<CRDTPayrollRecord>> getApprovedPayrollRecords({
    DateTime? payDate,
  }) async {
    final conditions = <String>[];
    final args = <dynamic>[];
    
    conditions.add('JSON_EXTRACT(data, "\$.status.value") = ?');
    args.add('approved');
    
    conditions.add('JSON_EXTRACT(data, "\$.is_deleted") = ?');
    args.add(false);
    
    if (payDate != null) {
      conditions.add('date(JSON_EXTRACT(data, "\$.pay_date.value") / 1000, \'unixepoch\') = date(?)');
      args.add(payDate.toIso8601String());
    }
    
    final results = await _database.query(
      table: 'payroll_records',
      where: conditions.join(' AND '),
      whereArgs: args,
      orderBy: 'JSON_EXTRACT(data, "\$.employee_id.value")',
    );
    
    return results.map((data) => CRDTPayrollRecord.fromCRDTJson(data)).toList();
  }
}