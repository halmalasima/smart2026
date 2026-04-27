# ai_assistant/urls.py
# مسارات API للمساعد الذكي

from django.urls import path
from .views import (
    AIChatView, AddLegalDocumentsView, DeleteLegalDocumentsView, analyze_case_view
)

urlpatterns = [
    path('chat/', AIChatView.as_view(), name='ai_chat'),
    path('documents/add/', AddLegalDocumentsView.as_view(), name='add_legal_documents'),
    path('documents/delete/', DeleteLegalDocumentsView.as_view(), name='delete_legal_documents'),
    path('analyze-case/', analyze_case_view, name='analyze_case'),
]
