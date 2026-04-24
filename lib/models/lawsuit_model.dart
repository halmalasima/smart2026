/// Lawsuit Model - with archive lifecycle support
class LawsuitModel {
  final int? id;
  final String caseNumber;
  final String caseType;
  final int? caseYearHijri;
  final String? caseSubtype;
  final String status;
  final String? caseStatus;
  final String? subject;
  final String? description;
  final String? facts;
  final String? legalBasis;
  final String? legalReasons;
  final String? requests;
  final String? governorate;
  final String? notes;
  final DateTime? filingDate;
  final DateTime? gregorianDate;
  final String? hijriDate;
  final int? courtId;
  final String? courtName;
  final int? judgeId;
  final String? judgeName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Archive lifecycle fields
  final String archiveStatus;
  final DateTime? archiveDate;
  final String? archiveReason;
  final bool isDeleted;
  final DateTime? deletedAt;
  final int? parentLawsuitId;
  final int? caseId;
  final int? clientId;
  final String? clientName;
  final int? createdById;
  final String? createdByName;

  // Counts
  final int childLawsuitsCount;
  final int plaintiffsCount;
  final int defendantsCount;
  final int attachmentsCount;
  final int hearingsCount;
  final bool isSynced;

  LawsuitModel({
    this.id,
    required this.caseNumber,
    required this.caseType,
    this.caseYearHijri,
    this.caseSubtype,
    this.status = 'pending',
    this.caseStatus,
    this.subject,
    this.description,
    this.facts,
    this.legalBasis,
    this.legalReasons,
    this.requests,
    this.governorate,
    this.notes,
    this.filingDate,
    this.gregorianDate,
    this.hijriDate,
    this.courtId,
    this.courtName,
    this.judgeId,
    this.judgeName,
    this.createdAt,
    this.updatedAt,
    this.archiveStatus = 'active',
    this.archiveDate,
    this.archiveReason,
    this.isDeleted = false,
    this.deletedAt,
    this.parentLawsuitId,
    this.caseId,
    this.clientId,
    this.clientName,
    this.createdById,
    this.createdByName,
    this.childLawsuitsCount = 0,
    this.plaintiffsCount = 0,
    this.defendantsCount = 0,
    this.attachmentsCount = 0,
    this.hearingsCount = 0,
    this.isSynced = true,
  });

  factory LawsuitModel.fromJson(Map<String, dynamic> json) {
    return LawsuitModel(
      id: json['id'],
      caseNumber: json['case_number'] ?? '',
      caseType: json['case_type'] ?? '',
      caseYearHijri: json['case_year_hijri'],
      caseSubtype: json['case_subtype'],
      status: json['status'] ?? 'pending',
      caseStatus: json['case_status'],
      subject: json['subject'],
      description: json['description'],
      facts: json['facts'],
      legalBasis: json['legal_basis'],
      legalReasons: json['legal_reasons'],
      requests: json['requests'],
      governorate: json['governorate'],
      notes: json['notes'],
      filingDate: json['filing_date'] != null 
          ? DateTime.parse(json['filing_date']) 
          : null,
      gregorianDate: json['gregorian_date'] != null 
          ? DateTime.parse(json['gregorian_date']) 
          : null,
      hijriDate: json['hijri_date'],
      courtId: json['court_fk'] ?? json['court'] ?? json['court_id'],
      courtName: json['court_detail'] != null 
          ? json['court_detail']['court_name'] 
          : json['court_name'],
      judgeId: json['judge'] ?? json['judge_id'],
      judgeName: json['judge_name'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      // Archive fields
      archiveStatus: json['archive_status'] ?? 'active',
      archiveDate: json['archive_date'] != null ? DateTime.parse(json['archive_date']) : null,
      archiveReason: json['archive_reason'],
      isDeleted: _parseBool(json['is_deleted']),
      deletedAt: json['deleted_at'] != null ? DateTime.parse(json['deleted_at']) : null,
      parentLawsuitId: json['parent_lawsuit'] ?? json['parent_lawsuit_id'],
      caseId: json['case'] ?? json['case_id'],
      clientId: json['client'] ?? json['client_id'],
      clientName: json['client_name'],
      createdById: json['created_by_detail'] != null ? json['created_by_detail']['id'] : (json['created_by_id'] ?? json['created_by']),
      createdByName: json['created_by_detail'] != null ? 
        '${json['created_by_detail']['first_name'] ?? ''} ${json['created_by_detail']['last_name'] ?? ''}'.trim() : 
        (json['created_by_name'] ?? json['created_by_username']),
      childLawsuitsCount: json['child_lawsuits_count'] ?? 0,
      plaintiffsCount: json['plaintiffs_count'] ?? 0,
      defendantsCount: json['defendants_count'] ?? 0,
      attachmentsCount: json['attachments_count'] ?? 0,
      hearingsCount: json['hearings_count'] ?? 0,
      isSynced: _parseBool(json['is_synced'], defaultValue: true),
    );
  }

  static bool _parseBool(dynamic value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) {
      final s = value.toLowerCase();
      return s == '1' || s == 'true';
    }
    return defaultValue;
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'case_number': caseNumber,
      'case_type': caseType,
      'case_year_hijri': caseYearHijri,
      'case_subtype': caseSubtype,
      'case_status': caseStatus ?? (status == 'pending' ? 'جديد' : status),
      'subject': subject,
      'status': status,
      'description': description,
      'facts': facts,
      'legal_basis': legalBasis,
      'legal_reasons': legalReasons,
      'requests': requests,
      'governorate': governorate,
      'notes': notes,
      if (filingDate != null) 'filing_date': filingDate!.toIso8601String().split('T')[0],
      if (gregorianDate != null) 'gregorian_date': gregorianDate!.toIso8601String().split('T')[0],
      'hijri_date': hijriDate,
      'court_id': courtId,
      'judge': judgeId,
      if (parentLawsuitId != null) 'parent_lawsuit': parentLawsuitId,
      if (caseId != null) 'case': caseId,
      if (clientId != null) 'client': clientId,
    };
  }

  // Helper for internal DB storage
  Map<String, dynamic> toLocalJson() {
    return {
      if (id != null) 'id': id,
      'case_number': caseNumber,
      'case_type': caseType,
      'case_year_hijri': caseYearHijri,
      'case_subtype': caseSubtype,
      'status': status,
      'case_status': caseStatus,
      'subject': subject,
      'description': description,
      'facts': facts,
      'legal_basis': legalBasis,
      'legal_reasons': legalReasons,
      'requests': requests,
      'governorate': governorate,
      'notes': notes,
      if (filingDate != null) 'filing_date': filingDate!.toIso8601String(),
      if (gregorianDate != null) 'gregorian_date': gregorianDate!.toIso8601String(),
      'hijri_date': hijriDate,
      'court_fk': courtId,
      'court_name': courtName,
      'judge': judgeId,
      'judge_name': judgeName,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'archive_status': archiveStatus,
      'archive_date': archiveDate?.toIso8601String(),
      'archive_reason': archiveReason,
      'is_deleted': isDeleted ? 1 : 0,
      'deleted_at': deletedAt?.toIso8601String(),
      'parent_lawsuit_id': parentLawsuitId,
      'client_id': clientId,
      'client_name': clientName,
      'created_by_id': createdById,
      'created_by_name': createdByName,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  String get statusDisplay {
    switch (status) {
      case 'pending':
        return 'قيد الانتظار';
      case 'in_progress':
        return 'قيد المعالجة';
      case 'completed':
        return 'مكتملة';
      case 'appealed':
        return 'مستأنفة';
      case 'closed':
        return 'مغلقة';
      default:
        return status;
    }
  }

  String get caseTypeDisplay {
    switch (caseType) {
      case 'امر_اداء':
        return 'أمر أداء';
      case 'دعوى':
        return 'دعوى';
      case 'رد_على_دعوى':
        return 'رد على دعوى';
      case 'استئناف':
        return 'استئناف';
      case 'طعن':
        return 'طعن';
      case 'civil':
        return 'مدنية';
      case 'criminal':
        return 'جنائية';
      case 'commercial':
        return 'تجارية';
      case 'administrative':
        return 'إدارية';
      case 'family':
        return 'أحوال شخصية';
      default:
        return caseType;
    }
  }

  String get archiveStatusDisplay {
    switch (archiveStatus) {
      case 'active':
        return 'نشط';
      case 'semi_active':
        return 'شبه نشط';
      case 'archived':
        return 'محفوظ';
      default:
        return archiveStatus;
    }
  }

  String get caseStatusDisplay {
    final s = caseStatus ?? '';
    switch (s) {
      case 'جديد':
        return 'جديد';
      case 'قيد_النظر':
        return 'قيد النظر';
      case 'مكتمل':
        return 'مكتمل';
      case 'مغلق':
        return 'مغلق';
      default:
        return s.isNotEmpty ? s : statusDisplay;
    }
  }
}
