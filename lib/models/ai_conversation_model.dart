// lib/models/ai_conversation_model.dart

class AIConversationModel {
  final int? id;
  final int? userId;
  final String title;
  final bool isArchived;
  final bool isFavorite;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int messagesCount;

  AIConversationModel({
    this.id,
    this.userId,
    required this.title,
    this.isArchived = false,
    this.isFavorite = false,
    this.createdAt,
    this.updatedAt,
    this.messagesCount = 0,
  });

  factory AIConversationModel.fromJson(Map<String, dynamic> json) {
    return AIConversationModel(
      id: json['id'],
      userId: json['user_id'],
      title: json['title'] ?? 'محادثة جديدة',
      isArchived: json['is_archived'] ?? false,
      isFavorite: json['is_favorite'] ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      messagesCount: json['messages_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      'title': title,
      'is_archived': isArchived,
      'is_favorite': isFavorite,
    };
  }
}

class AIChatMessageModel {
  final int? id;
  final int? conversationId;
  final int? userId;
  final String question;
  final String answer;
  final String? modelVersion;
  final DateTime? createdAt;

  AIChatMessageModel({
    this.id,
    this.conversationId,
    this.userId,
    required this.question,
    required this.answer,
    this.modelVersion,
    this.createdAt,
  });

  factory AIChatMessageModel.fromJson(Map<String, dynamic> json) {
    return AIChatMessageModel(
      id: json['id'],
      conversationId: json['conversation'],
      userId: json['user_id'],
      question: json['question'] ?? '',
      answer: json['answer'] ?? '',
      modelVersion: json['model_version'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation': conversationId,
      if (userId != null) 'user_id': userId,
      'question': question,
      'answer': answer,
      if (modelVersion != null) 'model_version': modelVersion,
    };
  }
}
