# ai_assistant/views.py
# واجهات API للمساعد الذكي

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.decorators import api_view, permission_classes
# Import from old services.py for backward compatibility
try:
    from . import services as old_services_module
    OldAIAssistantService = getattr(old_services_module, 'AIAssistantService', None)
    OldRAGService = getattr(old_services_module, 'RAGService', None)
except (ImportError, AttributeError):
    OldAIAssistantService = None
    OldRAGService = None

# Import from new services package (explicit import from services directory)
from .services.ai_assistant_service import AIAssistantService
from .services.rag_service import RAGService
from .serializers import ChatRequestSerializer, ChatResponseSerializer
import logging
import os
from drf_yasg.utils import swagger_auto_schema
from drf_yasg import openapi

logger = logging.getLogger(__name__)


class AIChatView(APIView):
    """نقطة نهاية للدردشة مع المساعد الذكي"""
    permission_classes = [IsAuthenticated]

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        try:
            # محاولة استخدام Groq إذا كان متاحاً (أسهل وأسرع)
            groq_api_key = os.getenv("GROQ_API_KEY")
            if groq_api_key:
                try:
                    from .services_groq import AIAssistantServiceGroq
                    self.ai_assistant_service = AIAssistantServiceGroq(use_groq=True)
                    logger.info("Using Groq Cloud API for AI Assistant")
                except Exception as e:
                    logger.warning(f"Failed to initialize Groq service: {e}, falling back to Ollama")
                    self.ai_assistant_service = AIAssistantService()
            else:
                # استخدام Ollama المحلي (افتراضي)
                self.ai_assistant_service = AIAssistantService()
                logger.info("Using local Ollama for AI Assistant")
        except ValueError as e:
            logger.warning(f"AIAssistantService not initialized: {e}")
            self.ai_assistant_service = None

    @swagger_auto_schema(
        request_body=ChatRequestSerializer,
        responses={
            200: ChatResponseSerializer,
            400: "Bad Request",
            500: "Internal Server Error",
            503: "Service Unavailable"
        },
        operation_description="إرسال استفسار للمساعد القانوني الذكي والحصول على استجابة"
    )
    def post(self, request, *args, **kwargs):
        serializer = ChatRequestSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        user_query = serializer.validated_data.get('user_query') or serializer.validated_data.get('query')
        conversation_history = serializer.validated_data.get('conversation_history', [])

        if self.ai_assistant_service is None:
            offline_msg = (
                "المساعد الذكي غير مُفعّل على هذا الخادم. للتشغيل المحلي: عيّن المتغير "
                "GROQ_API_KEY في البيئة، أو شغّل Ollama واضبط عنوانه في إعدادات المشروع."
            )
            response_data = {
                "ai_response": offline_msg,
                "conversation_history": conversation_history
                + [
                    {"role": "user", "content": user_query},
                    {"role": "assistant", "content": offline_msg},
                ],
                "source_documents": [],
            }
            return Response(response_data, status=status.HTTP_200_OK)

        logger.info(f"Received chat query: {user_query}")
        # Debug: Log API key status (without showing the actual key)
        groq_key = os.getenv("GROQ_API_KEY")
        logger.info(f"GROQ_API_KEY present: {bool(groq_key)}")
        logger.info(f"GROQ_API_KEY length: {len(groq_key) if groq_key else 0}")
        try:
            # Try new service first, fallback to old service
            try:
                new_service = AIAssistantService()
                ai_response_content = new_service.get_ai_response(user_query, conversation_history)
                
                # استخراج الاقتراحات من النص إذا وجدت
                suggested_questions = []
                clean_response = ai_response_content
                if "SUGGESTED_QUESTIONS:" in ai_response_content:
                    parts = ai_response_content.split("SUGGESTED_QUESTIONS:")
                    clean_response = parts[0].strip()
                    if len(parts) > 1:
                        suggestions_part = parts[1].strip()
                        suggested_questions = [q.strip() for q in suggestions_part.split("||") if q.strip()]

                response_data = {
                    "ai_response": clean_response,
                    "suggested_questions": suggested_questions,
                    "conversation_history": conversation_history + [
                        {"role": "user", "content": user_query},
                        {"role": "assistant", "content": clean_response}
                    ]
                }
            except Exception as e:
                logger.warning(f"New service failed, using legacy service: {e}")
                # Fallback to legacy service
                response_data = self.ai_assistant_service.get_ai_response(
                    user_query, conversation_history
                )
                # Convert legacy format to new format
                if isinstance(response_data, dict) and "response" in response_data:
                    response_data = {
                        "ai_response": response_data["response"],
                        "conversation_history": conversation_history + [
                            {"role": "user", "content": user_query},
                            {"role": "assistant", "content": response_data["response"]}
                        ],
                        "source_documents": response_data.get("source_documents", [])
                    }

            response_serializer = ChatResponseSerializer(data=response_data)
            response_serializer.is_valid(raise_exception=True)
            return Response(response_serializer.data, status=status.HTTP_200_OK)
        except Exception as e:
            logger.exception(f"Error in AI chat view: {e}")
            # Provide more user-friendly error messages
            error_message = str(e)
            if "GROQ_API_KEY" in error_message or "API key" in error_message.lower() or "credentials" in error_message.lower() or "دخول" in error_message:
                error_message = "عذراً، يرجى التحقق من إعدادات API Key. تأكد من إضافة GROQ_API_KEY أو HUGGINGFACE_API_KEY إلى ملف .env"
            return Response(
                {"detail": error_message},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class AddLegalDocumentsView(APIView):
    """نقطة نهاية لإضافة مستندات قانونية إلى محرك RAG"""
    permission_classes = [IsAuthenticated]

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        try:
            self.rag_service = RAGService()
        except ValueError as e:
            logger.warning(f"RAGService not initialized: {e}")
            self.rag_service = None

    @swagger_auto_schema(
        request_body=openapi.Schema(
            type=openapi.TYPE_OBJECT,
            properties={
                'files': openapi.Schema(
                    type=openapi.TYPE_ARRAY,
                    items=openapi.Schema(type=openapi.TYPE_FILE),
                    description='قائمة ملفات PDF أو Word أو نصية لرفعها'
                )
            },
            required=['files']
        ),
        responses={200: "Success", 400: "Bad Request", 500: "Internal Server Error"},
        operation_description="رفع مستندات قانونية (PDF, Word, Text) إلى محرك RAG للفهرسة"
    )
    def post(self, request, *args, **kwargs):
        if self.rag_service is None:
            return Response(
                {"detail": "خدمة RAG غير متاحة حالياً. يرجى التحقق من إعدادات الخادم."},
                status=status.HTTP_503_SERVICE_UNAVAILABLE
            )

        if 'files' not in request.FILES:
            return Response(
                {"detail": "لم يتم تقديم ملفات."},
                status=status.HTTP_400_BAD_REQUEST
            )

        uploaded_files = request.FILES.getlist('files')
        files_for_rag = []
        for uploaded_file in uploaded_files:
            files_for_rag.append(
                (uploaded_file.name, uploaded_file.read(), uploaded_file.content_type)
            )

        try:
            response = self.rag_service.add_documents(files_for_rag)
            return Response(response, status=status.HTTP_200_OK)
        except Exception as e:
            logger.exception(f"Error adding legal documents: {e}")
            return Response(
                {"detail": str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class DeleteLegalDocumentsView(APIView):
    """نقطة نهاية لحذف مستندات قانونية من محرك RAG"""
    permission_classes = [IsAuthenticated]

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        try:
            self.rag_service = RAGService()
        except ValueError as e:
            logger.warning(f"RAGService not initialized: {e}")
            self.rag_service = None

    @swagger_auto_schema(
        request_body=openapi.Schema(
            type=openapi.TYPE_OBJECT,
            properties={
                'source': openapi.Schema(
                    type=openapi.TYPE_STRING,
                    description='اسم الملف المصدر للحذف'
                )
            },
            required=['source']
        ),
        responses={200: "Success", 400: "Bad Request", 500: "Internal Server Error"},
        operation_description="حذف مستندات قانونية من محرك RAG حسب اسم الملف المصدر"
    )
    def delete(self, request, *args, **kwargs):
        if self.rag_service is None:
            return Response(
                {"detail": "خدمة RAG غير متاحة حالياً. يرجى التحقق من إعدادات الخادم."},
                status=status.HTTP_503_SERVICE_UNAVAILABLE
            )

        source = request.data.get('source')
        if not source:
            return Response(
                {"detail": "معامل 'source' مطلوب."},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            response = self.rag_service.delete_documents(source)
            return Response(response, status=status.HTTP_200_OK)
        except Exception as e:
            logger.exception(f"Error deleting legal documents: {e}")
            return Response(
                {"detail": str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def analyze_case_view(request):
    """
    Endpoint for AI Strategic Case Analysis.
    نقطة اتصال للتحليل الاستراتيجي للقضية بالذكاء الاصطناعي.
    """
    case_data = {
        'subject': request.data.get('subject', ''),
        'facts': request.data.get('facts', ''),
        'opponent_claims': request.data.get('opponent_claims', ''),
        'client_position': request.data.get('client_position', ''),
    }
    
    if not case_data['facts'] or not case_data['opponent_claims']:
        return Response(
            {'error': 'يجب توفير وقائع القضية وادعاءات الخصم للتحليل'}, 
            status=status.HTTP_400_BAD_REQUEST
        )
    
    try:
        from .services.llm_service import LLMService
        llm = LLMService()
        analysis = llm.analyze_case_strategy(case_data)
        return Response({'analysis': analysis})
    except Exception as e:
        logger.error(f"Error in analyze_case_view: {e}")
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
