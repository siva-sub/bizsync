class Employee {
  final String id;
  final String name;
  final String position;
  final String email;
  final String phone;
  final String workPassType;
  final String nric;
  final double basicSalary;
  final double cpfContribution;
  final bool isActive;
  final DateTime joinDate;
  final int leaveBalance;

  const Employee({
    required this.id,
    required this.name,
    required this.position,
    required this.email,
    required this.phone,
    required this.workPassType,
    required this.nric,
    required this.basicSalary,
    required this.cpfContribution,
    this.isActive = true,
    required this.joinDate,
    this.leaveBalance = 14,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'position': position,
      'email': email,
      'phone': phone,
      'work_pass_type': workPassType,
      'nric': nric,
      'basic_salary': basicSalary,
      'cpf_contribution': cpfContribution,
      'is_active': isActive,
      'join_date': joinDate.millisecondsSinceEpoch,
      'leave_balance': leaveBalance,
    };
  }

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'] as String,
      name: json['name'] as String,
      position: json['position'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      workPassType: json['work_pass_type'] as String,
      nric: json['nric'] as String,
      basicSalary: (json['basic_salary'] as num).toDouble(),
      cpfContribution: (json['cpf_contribution'] as num).toDouble(),
      isActive: json['is_active'] as bool? ?? true,
      joinDate: DateTime.fromMillisecondsSinceEpoch(json['join_date'] as int),
      leaveBalance: json['leave_balance'] as int? ?? 14,
    );
  }

  String get workPassDisplayName {
    switch (workPassType.toLowerCase()) {
      case 'citizen':
        return 'Singapore Citizen';
      case 'permanent resident':
        return 'Permanent Resident';
      case 'employment pass':
        return 'Employment Pass';
      case 's pass':
        return 'S Pass';
      case 'work permit':
        return 'Work Permit';
      default:
        return workPassType;
    }
  }

  String get formattedSalary {
    return '\$${basicSalary.toStringAsFixed(0)}';
  }

  String get formattedCpf {
    return '\$${cpfContribution.toStringAsFixed(0)}';
  }

  int get yearsOfService {
    final now = DateTime.now();
    return now.difference(joinDate).inDays ~/ 365;
  }

  @override
  String toString() {
    return 'Employee(id: $id, name: $name, position: $position)';
  }
}
