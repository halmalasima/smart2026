# ai_assistant/urls.py
# مسارات API للمساعد الذكي

from django.urls import path
from django.http import JsonResponse
from .views import (
    AIChatView, AddLegalDocumentsView, DeleteLegalDocumentsView, analyze_case_view
)

def ai_health_check(request):
    return JsonResponse({'status': 'ok', 'service': 'ai'}, status=200)

urlpatterns = [
    path('health/', ai_health_check, name='ai_health'),
    path('health', ai_health_check),
    path('chat/', AIChatView.as_view(), name='ai_chat'),
    path('documents/add/', AddLegalDocumentsView.as_view(), name='add_legal_documents'),
    path('documents/delete/', DeleteLegalDocumentsView.as_view(), name='delete_legal_documents'),
    path('analyze-case/', analyze_case_view, name='analyze_case'),
]
