# ai_assistant/serializers.py
# سيريالايزر للمساعد الذكي

from rest_framework import serializers


class ChatRequestSerializer(serializers.Serializer):
    """سيريالايزر لطلب الدردشة"""
    user_query = serializers.CharField(max_length=2000)
    query = serializers.CharField(max_length=2000, required=False)  # Legacy support
    conversation_history = serializers.ListField(
        child=serializers.DictField(child=serializers.CharField()),
        required=False,
        default=[]
    )
    
    def validate(self, data):
        # Support both user_query (new) and query (legacy)
        if not data.get('user_query') and not data.get('query'):
            raise serializers.ValidationError("Either 'user_query' or 'query' must be provided.")
        # Normalize to user_query
        if data.get('query') and not data.get('user_query'):
            data['user_query'] = data['query']
        return data


class SourceDocumentSerializer(serializers.Serializer):
    """سيريالايزر لوثيقة المصدر"""
    page_content = serializers.CharField()
    metadata = serializers.DictField()


class ChatResponseSerializer(serializers.Serializer):
    """سيريالايزر لاستجابة الدردشة"""
    ai_response = serializers.CharField()
    response = serializers.CharField(required=False)  # Legacy support
    conversation_history = serializers.ListField(
        child=serializers.DictField(child=serializers.CharField()),
        required=False
    )
    source_documents = serializers.ListField(
        child=SourceDocumentSerializer(),
        required=False,
        default=[]
    )
    suggested_questions = serializers.ListField(
        child=serializers.CharField(),
        required=False,
        default=[]
    )


class AddDocumentsSerializer(serializers.Serializer):
    """سيريالايزر لإضافة المستندات - يستخدم للتوثيق فقط، الملفات تُعالج مباشرة"""
    files = serializers.ListField(
        child=serializers.FileField(),
        help_text="List of PDF, Word, or Text files to upload."
    )
