/// Attachment Model
class AttachmentModel {
  final int? id;
  final int lawsuitId;
  final String documentType;
  final DateTime gregorianDate;
  final String hijriDate;
  final int pageCount;
  final String content;
  final String evidenceBasis;
  final String? fileUrl;
  final String? originalFilename;
  final int? fileSize;
  final String? localPath;
  final bool isSynced;
  final DateTime? createdAt;

  AttachmentModel({
    this.id,
    required this.lawsuitId,
    required this.documentType,
    required this.gregorianDate,
    required this.hijriDate,
    required this.pageCount,
    required this.content,
    required this.evidenceBasis,
    this.fileUrl,
    this.originalFilename,
    this.fileSize,
    this.localPath,
    this.isSynced = true,
    this.createdAt,
  });

  factory AttachmentModel.fromJson(Map<String, dynamic> json) {
    return AttachmentModel(
      id: json['id'],
      lawsuitId: json['lawsuit'] is int 
          ? json['lawsuit'] as int
          : (json['lawsuit'] is Map ? (json['lawsuit'] as Map)['id'] : null) ?? json['lawsuit_id'] ?? 0,
      documentType: json['document_type'] ?? 'other',
      gregorianDate: json['gregorian_date'] != null 
          ? DateTime.parse(json['gregorian_date']) 
          : DateTime.now(),
      hijriDate: json['hijri_date'] ?? '',
      pageCount: json['page_count'] ?? 1,
      content: json['content'] ?? '',
      evidenceBasis: json['evidence_basis'] ?? '',
      fileUrl: json['file_url'] ?? json['file'],
      originalFilename: json['original_filename'],
      fileSize: json['file_size'],
      localPath: json['local_path'],
      isSynced: json['is_synced'] is int 
          ? (json['is_synced'] == 1) 
          : (json['is_synced'] ?? true),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'lawsuit_id': lawsuitId,
      'document_type': documentType,
      'gregorian_date': gregorianDate.toIso8601String().split('T')[0],
      'hijri_date': hijriDate,
      'page_count': pageCount,
      'content': content,
      'evidence_basis': evidenceBasis,
      if (fileUrl != null) 'file': fileUrl,
      if (originalFilename != null) 'original_filename': originalFilename,
      if (fileSize != null) 'file_size': fileSize,
      if (localPath != null) 'local_path': localPath,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  String get typeDisplay {
    switch (documentType) {
      case 'identity':
        return 'هوية/جواز سفر';
      case 'contract':
        return 'عقد';
      case 'certificate':
        return 'شهادة';
      case 'evidence':
        return 'دليل';
      case 'statement':
        return 'بيان';
      case 'receipt':
        return 'إيصال';
      case 'other':
      default:
        return 'أخرى';
    }
  }

  String get fileSizeDisplay {
    if (fileSize == null) return '-';
    
    double size = fileSize!.toDouble();
    const units = ['B', 'KB', 'MB', 'GB'];
    int unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    return '${size.toStringAsFixed(1)} ${units[unitIndex]}';
  }
}
