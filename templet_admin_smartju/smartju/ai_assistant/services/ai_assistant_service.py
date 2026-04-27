# smartju/ai_assistant/services/ai_assistant_service.py

import logging
from typing import List, Dict, Any

from .rag_service import RAGService
from .llm_service import LLMService

logger = logging.getLogger(__name__)

class AIAssistantService:
    """
    Orchestrates RAG and LLM services to provide AI assistant functionality.
    تنسيق خدمات RAG و LLM لتوفير وظائف المساعد الذكي.
    """
    def __init__(self):
        self.rag_service = RAGService()
        self.llm_service = LLMService()

    def get_ai_response(self, user_query: str, conversation_history: List[Dict]) -> str:
        """
        Retrieves relevant documents using RAG and generates an AI response.
        يسترجع المستندات ذات الصلة باستخدام RAG ويولد استجابة من الذكاء الاصطناعي.
        """
        logger.info(f"Received user query: {user_query}")

        # 1. Retrieve relevant documents from RAG
        # 1. استرجاع المستندات ذات الصلة من RAG
        retrieved_docs = self.rag_service.search_documents(user_query, k=5)
        rag_context = "\n\n".join([doc["page_content"] for doc in retrieved_docs])
        
        if not rag_context:
            logger.warning("No relevant documents found for the query. Proceeding with LLM only.")
            rag_context = "No specific legal context found."

        logger.debug(f"RAG Context: {rag_context[:200]}...") # Log first 200 chars of context

        # 2. Generate response using LLM with RAG context and conversation history
        # 2. توليد استجابة باستخدام LLM مع سياق RAG وتاريخ المحادثة
        try:
            ai_response = self.llm_service.generate_response(
                user_query=user_query,
                rag_context=rag_context,
                conversation_history=conversation_history
            )
            logger.info("AI response generated successfully.")
            return ai_response
        except Exception as e:
            logger.error(f"Failed to generate AI response: {e}")
            return "عذرًا، حدث خطأ أثناء معالجة طلبك. يرجى المحاولة مرة أخرى لاحقًا." # Arabic error message
