class CaseModel {
  final int? id;
  final String caseNumber;
  final String? subject;
  final String? description;

  final DateTime? filingDate;
  final DateTime? gregorianDate;
  final String? hijriDate;
  final int? caseYearHijri;

  final String? caseStatus;
  final String? caseType;
  final String? caseSubtype;
  final String? governorate;
  final int? courtId;
  final String? courtName;

  final int? clientId;
  final String? clientName;

  final List<CasePartyModel>? parties;

  CaseModel({
    this.id,
    required this.caseNumber,
    this.subject,
    this.description,
    this.filingDate,
    this.gregorianDate,
    this.hijriDate,
    this.caseYearHijri,
    this.caseStatus,
    this.caseType,
    this.caseSubtype,
    this.governorate,
    this.courtId,
    this.courtName,
    this.clientId,
    this.clientName,
    this.parties,
  });

  factory CaseModel.fromJson(Map<String, dynamic> json) {
    List<CasePartyModel>? parties;
    if (json['parties'] != null && json['parties'] is List) {
      parties = (json['parties'] as List)
          .map((e) => CasePartyModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return CaseModel(
      id: json['id'],
      caseNumber: json['case_number'] ?? '',
      subject: json['subject'],
      description: json['description'],
      filingDate: json['filing_date'] != null ? DateTime.tryParse(json['filing_date']) : null,
      gregorianDate: json['gregorian_date'] != null ? DateTime.tryParse(json['gregorian_date']) : null,
      hijriDate: json['hijri_date'],
      caseYearHijri: json['case_year_hijri'],
      caseStatus: json['case_status'],
      caseType: json['case_type'],
      caseSubtype: json['case_subtype'],
      governorate: json['governorate'],
      courtId: json['court_fk'] ?? json['court'] ?? json['court_id'],
      courtName: json['court_detail'] != null ? json['court_detail']['court_name'] : json['court_name'],
      clientId: json['client'] ?? json['client_id'],
      clientName: json['client_name'],
      parties: parties,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'case_number': caseNumber,
      'subject': subject,
      'description': description,
      'filing_date': filingDate != null ? filingDate!.toIso8601String().split('T')[0] : null,
      'gregorian_date': gregorianDate != null ? gregorianDate!.toIso8601String().split('T')[0] : null,
      'hijri_date': hijriDate,
      'case_year_hijri': caseYearHijri,
      'case_status': caseStatus,
      'case_type': caseType,
      'case_subtype': caseSubtype,
      'governorate': governorate,
      'court_id': courtId,
      'client': clientId,
    };
  }
}


class CasePartyModel {
  final int? id;
  final int? caseId;
  final String role;
  final String? roleDisplay;
  final String entityType;
  final String? entityTypeDisplay;
  final String name;
  final String? phone;
  final String? idNumber;
  final String? idIssuedFrom;
  final String? idDate;
  final String? address;
  final String? nationality;
  final int? userAccountId;
  final String? generatedPassword;

  CasePartyModel({
    this.id,
    this.caseId,
    required this.role,
    this.roleDisplay,
    this.entityType = 'person',
    this.entityTypeDisplay,
    required this.name,
    this.phone,
    this.idNumber,
    this.idIssuedFrom,
    this.idDate,
    this.address,
    this.nationality,
    this.userAccountId,
    this.generatedPassword,
  });

  factory CasePartyModel.fromJson(Map<String, dynamic> json) {
    return CasePartyModel(
      id: json['id'],
      caseId: json['case'],
      role: json['role'] ?? 'client',
      roleDisplay: json['role_display'],
      entityType: json['entity_type'] ?? 'person',
      entityTypeDisplay: json['entity_type_display'],
      name: json['name'] ?? '',
      phone: json['phone'],
      idNumber: json['id_number'],
      idIssuedFrom: json['id_issued_from'],
      idDate: json['id_date'],
      address: json['address'],
      nationality: json['nationality'],
      userAccountId: json['user_account'],
      generatedPassword: json['generated_password'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'case': caseId,
      'role': role,
      'entity_type': entityType,
      'name': name,
      'phone': phone,
      'id_number': idNumber,
      'id_issued_from': idIssuedFrom,
      'id_date': idDate,
      'address': address,
      'nationality': nationality,
    };
  }
}
