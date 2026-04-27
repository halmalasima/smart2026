# ai_assistant/services_groq.py
# خدمات المساعد الذكي باستخدام Groq Cloud API (بديل لـ Ollama المحلي)
# AI Assistant services using Groq Cloud API (alternative to local Ollama)

import os
import requests
import json
import logging
from typing import List, Dict, Any, Optional
from django.conf import settings

logger = logging.getLogger(__name__)


class GroqService:
    """خدمة للتواصل مع Groq Cloud API"""

    def __init__(self):
        self.groq_api_key = os.getenv("GROQ_API_KEY")
        self.groq_api_url = "https://api.groq.com/openai/v1/chat/completions"
        # قائمة النماذج المتاحة: llama-3.3-70b-versatile, llama-3-8b-8192, llama-3-70b-8192, mixtral-8x7b-32768, gemma2-9b-it
        # ملاحظة: llama-3.3-70b-versatile تم اختباره ويعمل بشكل صحيح ⭐
        self.model_name = os.getenv("GROQ_MODEL_NAME", "llama-3.3-70b-versatile")  # نموذج افتراضي مختبر
        
        # Log model name for debugging
        logger.info(f"GroqService initialized with model: {self.model_name}")
        logger.info(f"GROQ_MODEL_NAME from env: {os.getenv('GROQ_MODEL_NAME', 'NOT SET')}")
        
        if not self.groq_api_key:
            raise ValueError("GROQ_API_KEY environment variable not set.")

    def _make_request(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        """دالة مساعدة لإجراء طلبات HTTP إلى Groq"""
        try:
            headers = {
                'Content-Type': 'application/json',
                'Authorization': f'Bearer {self.groq_api_key}'
            }
            
            # Log request details (without sensitive data)
            logger.info(f"Making request to Groq API: {self.groq_api_url}")
            logger.info(f"Model: {payload.get('model', 'unknown')}")
            
            response = requests.post(
                self.groq_api_url,
                headers=headers,
                json=payload,
                timeout=120
            )
            
            # Log response status
            logger.info(f"Groq API response status: {response.status_code}")
            
            # If error, log full response for debugging
            if response.status_code != 200:
                error_text = response.text
                logger.error(f"Groq API error {response.status_code}: {error_text}")
                try:
                    error_json = response.json()
                    logger.error(f"Error JSON: {error_json}")
                except:
                    pass
                response.raise_for_status()
            
            return response.json()
        except requests.exceptions.Timeout:
            logger.error("Request to Groq timed out.")
            raise ConnectionError("Groq service timed out.")
        except requests.exceptions.HTTPError as e:
            logger.error(f"HTTP error from Groq: {e}")
            if hasattr(e, 'response') and e.response is not None:
                logger.error(f"Response status: {e.response.status_code}")
                logger.error(f"Response text: {e.response.text}")
            raise ConnectionError(f"Groq service failed: {e}")
        except requests.exceptions.RequestException as e:
            logger.error(f"Request to Groq failed: {e}")
            if hasattr(e, 'response') and e.response is not None:
                logger.error(f"Response status: {e.response.status_code}")
                logger.error(f"Response text: {e.response.text}")
            raise ConnectionError(f"Groq service failed: {e}")

    def generate_response(self, messages: List[Dict[str, str]], stream: bool = False) -> Dict[str, Any]:
        """توليد استجابة من Groq API"""
        payload = {
            "model": self.model_name,
            "messages": messages,
            "temperature": 0.7,
            "max_tokens": 2048,
            "top_p": 0.9,
        }
        
        if stream:
            payload["stream"] = True
        
        logger.info(f"Generating response from Groq model: {self.model_name}")
        return self._make_request(payload)


class HuggingFaceService:
    """خدمة للتواصل مع HuggingFace Inference API (بديل مجاني)"""

    def __init__(self):
        self.hf_api_key = os.getenv("HUGGINGFACE_API_KEY")
        self.model_name = os.getenv("HF_MODEL_NAME", "Qwen/Qwen2.5-7B-Instruct")
        self.api_url = f"https://api-inference.huggingface.co/models/{self.model_name}"
        
        if not self.hf_api_key:
            logger.warning("HUGGINGFACE_API_KEY not set. Some features may not work.")
            # يمكن العمل بدون API key لكن بقيود

    def _make_request(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        """دالة مساعدة لإجراء طلبات HTTP إلى HuggingFace"""
        try:
            headers = {
                'Content-Type': 'application/json',
            }
            if self.hf_api_key:
                headers['Authorization'] = f'Bearer {self.hf_api_key}'
            
            response = requests.post(
                self.api_url,
                headers=headers,
                json=payload,
                timeout=120
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.Timeout:
            logger.error("Request to HuggingFace timed out.")
            raise ConnectionError("HuggingFace service timed out.")
        except requests.exceptions.RequestException as e:
            logger.error(f"Request to HuggingFace failed: {e}")
            raise ConnectionError(f"HuggingFace service failed: {e}")

    def generate_response(self, messages: List[Dict[str, str]]) -> Dict[str, Any]:
        """توليد استجابة من HuggingFace API"""
        # تحويل messages إلى prompt
        prompt = self._format_messages_to_prompt(messages)
        
        payload = {
            "inputs": prompt,
            "parameters": {
                "temperature": 0.7,
                "max_new_tokens": 2048,
                "return_full_text": False,
            }
        }
        
        logger.info(f"Generating response from HuggingFace model: {self.model_name}")
        result = self._make_request(payload)
        
        # تنسيق الاستجابة
        if isinstance(result, list) and len(result) > 0:
            generated_text = result[0].get("generated_text", "")
        else:
            generated_text = str(result)
        
        return {
            "message": {
                "content": generated_text
            }
        }

    def _format_messages_to_prompt(self, messages: List[Dict[str, str]]) -> str:
        """تحويل messages إلى prompt نصي"""
        prompt_parts = []
        for msg in messages:
            role = msg.get("role", "user")
            content = msg.get("content", "")
            
            if role == "system":
                prompt_parts.append(f"System: {content}")
            elif role == "user":
                prompt_parts.append(f"User: {content}")
            elif role == "assistant":
                prompt_parts.append(f"Assistant: {content}")
        
        return "\n\n".join(prompt_parts)


# استخدام RAGService من services package الجديد
from .services.rag_service import RAGService


class AIAssistantServiceGroq:
    """خدمة المساعد الذكي التي تجمع بين RAG و Groq/HuggingFace"""

    def __init__(self, use_groq: bool = True):
        # محاولة تهيئة RAG Service (اختياري)
        self.rag_service = None
        try:
            rag_api_url = os.getenv("RAG_API_URL")
            if rag_api_url and rag_api_url != "https://your-rag-space.hf.space":
                self.rag_service = RAGService()
                logger.info("RAG Service initialized successfully")
            else:
                logger.warning("RAG_API_URL not set or is placeholder, proceeding without RAG")
        except (ValueError, Exception) as e:
            logger.warning(f"RAG Service not available, proceeding without RAG: {e}")
            self.rag_service = None
        
        # اختيار الخدمة حسب الإعدادات
        if use_groq:
            try:
                self.llm_service = GroqService()
                logger.info("Using Groq Cloud API")
            except ValueError:
                logger.warning("Groq API key not set, falling back to HuggingFace")
                self.llm_service = HuggingFaceService()
        else:
            self.llm_service = HuggingFaceService()
            logger.info("Using HuggingFace Inference API")
        
        self.system_prompt = (
            "أنت مساعد قانوني ذكي متخصص في القانون اليمني. مهمتك هي تحليل الاستفسارات القانونية، "
            "وتقديم إجابات دقيقة ومفصلة بناءً على النصوص القانونية اليمنية ذات الصلة. يجب أن تكون "
            "إجاباتك محايدة، موضوعية، ومستندة إلى الحقائق القانونية فقط. عند الإجابة، قم دائمًا "
            "بالإشارة إلى المواد القانونية أو المبادئ القضائية اليمنية التي استندت إليها. إذا تم "
            "توفير سياق من مستندات قانونية، استخدم هذا السياق بشكل أساسي لصياغة إجابتك. في حالة "
            "عدم كفاية المعلومات، اطلب توضيحات إضافية. حافظ على نبرة احترافية وقانونية."
        )

    def _format_rag_context(self, search_results: List[Dict[str, Any]]) -> str:
        """تنسيق السياق المسترجع من RAG"""
        if not search_results:
            return ""
        context = "\n\nوثائق قانونية ذات صلة:\n"
        for i, result in enumerate(search_results):
            content = result.get("page_content", "")
            source = result.get("metadata", {}).get("source", "مصدر غير معروف")
            context += f"---\nالوثيقة {i + 1} (المصدر: {source}):\n{content}\n"
        return context

    def _build_messages(
        self,
        user_query: str,
        rag_context: str,
        conversation_history: List[Dict[str, str]]
    ) -> List[Dict[str, str]]:
        """بناء رسائل المحادثة"""
        messages = []
        messages.append({"role": "system", "content": self.system_prompt})

        # أمثلة قليلة
        messages.append({
            "role": "user",
            "content": "ما هي شروط عقد البيع في القانون اليمني؟"
        })
        messages.append({
            "role": "assistant",
            "content": (
                "وفقًا للقانون المدني اليمني رقم 19 لسنة 1992، المادة 419، يشترط لصحة عقد البيع "
                "أن يكون المبيع معلومًا علمًا نافيًا للجهالة الفاحشة، وأن يكون الثمن معلومًا ومحددًا، "
                "وأن يكون كل من البائع والمشتري أهلاً للتعاقد. كما يجب أن يكون المبيع مملوكًا "
                "للبائع أو مأذونًا له ببيعه."
            )
        })

        # إضافة سجل المحادثة
        messages.extend(conversation_history)

        # إضافة سياق RAG
        if rag_context:
            messages.append({
                "role": "user",
                "content": (
                    f"بناءً على الوثائق القانونية التالية والمحادثة السابقة، أجب على استفسار المستخدم:\n"
                    f"{rag_context}\nاستفسار المستخدم: {user_query}"
                )
            })
        else:
            messages.append({"role": "user", "content": user_query})

        return messages

    def get_ai_response(
        self,
        user_query: str,
        conversation_history: List[Dict[str, str]] = None
    ) -> Dict[str, Any]:
        """الحصول على استجابة من المساعد الذكي"""
        if conversation_history is None:
            conversation_history = []

        rag_context = ""
        search_results = []
        if self.rag_service is not None:
            try:
                search_results = self.rag_service.search(user_query, k=5)
                rag_context = self._format_rag_context(search_results)
                logger.info(f"RAG search successful. Context length: {len(rag_context)} characters.")
            except ConnectionError as e:
                logger.warning(f"RAG service unavailable, proceeding without RAG context: {e}")
            except Exception as e:
                logger.error(f"Unexpected error during RAG search: {e}")
        else:
            logger.info("RAG service not available, proceeding without RAG context")

        messages = self._build_messages(user_query, rag_context, conversation_history)

        try:
            # توليد الاستجابة
            if isinstance(self.llm_service, GroqService):
                response = self.llm_service.generate_response(messages)
                assistant_message = response.get("choices", [{}])[0].get("message", {}).get("content", "")
            else:  # HuggingFace
                response = self.llm_service.generate_response(messages)
                assistant_message = response.get("message", {}).get("content", "")
            
            logger.info("LLM response generated successfully.")
            return {"response": assistant_message, "source_documents": search_results}
        except ConnectionError as e:
            logger.error(f"LLM service unavailable: {e}")
            return {
                "response": "عذرًا، لا يمكنني معالجة طلبك حاليًا بسبب مشكلة في خدمة الذكاء الاصطناعي. يرجى المحاولة لاحقًا.",
                "source_documents": []
            }
        except Exception as e:
            logger.error(f"Unexpected error during LLM response generation: {e}")
            return {
                "response": "حدث خطأ غير متوقع أثناء معالجة طلبك. يرجى المحاولة مرة أخرى.",
                "source_documents": []
            }
