# ai_assistant/services.py
# خدمات المساعد الذكي - التواصل مع RAG و Ollama

import os
import requests
import json
import logging
from typing import List, Dict, Any, Optional
from django.conf import settings

logger = logging.getLogger(__name__)


class RAGService:
    """خدمة للتواصل مع محرك RAG على Hugging Face Spaces"""

    def __init__(self):
        self.rag_api_url = os.getenv("RAG_API_URL")
        if not self.rag_api_url:
            raise ValueError("RAG_API_URL environment variable not set.")
        self.search_endpoint = f"{self.rag_api_url}/search"
        self.add_documents_endpoint = f"{self.rag_api_url}/add_documents"
        self.delete_documents_endpoint = f"{self.rag_api_url}/delete_documents"
        self.health_endpoint = f"{self.rag_api_url}/health"

    def _make_request(self, method: str, url: str, **kwargs) -> Dict[str, Any]:
        """دالة مساعدة لإجراء طلبات HTTP"""
        try:
            response = requests.request(method, url, timeout=30, **kwargs)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.Timeout:
            logger.error(f"Request to {url} timed out.")
            raise ConnectionError(f"RAG service at {url} timed out.")
        except requests.exceptions.RequestException as e:
            logger.error(f"Request to {url} failed: {e}")
            raise ConnectionError(f"RAG service at {url} failed: {e}")

    def health_check(self) -> Dict[str, Any]:
        """التحقق من صحة خدمة RAG"""
        logger.info(f"Checking RAG service health at {self.health_endpoint}")
        return self._make_request("GET", self.health_endpoint)

    def search(self, query: str, k: int = 4) -> List[Dict[str, Any]]:
        """البحث عن المستندات ذات الصلة في محرك RAG"""
        payload = {"query": query, "k": k}
        logger.info(f"Searching RAG for query: '{query}' with k={k}")
        response = self._make_request("POST", self.search_endpoint, json=payload)
        return response.get("results", [])

    def add_documents(self, files: List[tuple]) -> Dict[str, Any]:
        """إضافة مستندات جديدة إلى محرك RAG
        files should be a list of (filename, file_content_bytes, content_type)
        """
        multipart_files = []
        for filename, content, content_type in files:
            multipart_files.append(("files", (filename, content, content_type)))

        logger.info(f"Adding {len(files)} documents to RAG.")
        response = self._make_request("POST", self.add_documents_endpoint, files=multipart_files)
        return response

    def delete_documents(self, source: str) -> Dict[str, Any]:
        """حذف المستندات من محرك RAG بناءً على المصدر"""
        payload = {"source": source}
        logger.info(f"Deleting documents with source: {source} from RAG.")
        response = self._make_request("DELETE", self.delete_documents_endpoint, data=payload)
        return response


class OllamaService:
    """خدمة للتواصل مع Ollama LLM المحلي"""

    def __init__(self):
        self.ollama_api_url = os.getenv("OLLAMA_API_URL")
        if not self.ollama_api_url:
            raise ValueError("OLLAMA_API_URL environment variable not set.")
        self.generate_endpoint = f"{self.ollama_api_url}/api/chat"
        self.model_name = os.getenv("OLLAMA_MODEL_NAME", "smartjudi-qwen")

    def _make_request(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        """دالة مساعدة لإجراء طلبات HTTP إلى Ollama"""
        try:
            headers = {'Content-Type': 'application/json'}
            response = requests.post(
                self.generate_endpoint,
                headers=headers,
                json=payload,
                timeout=120
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.Timeout:
            logger.error("Request to Ollama timed out.")
            raise ConnectionError("Ollama service timed out.")
        except requests.exceptions.RequestException as e:
            logger.error(f"Request to Ollama failed: {e}")
            raise ConnectionError(f"Ollama service failed: {e}")

    def generate_response(self, messages: List[Dict[str, str]], stream: bool = False) -> Dict[str, Any]:
        """توليد استجابة من Ollama LLM"""
        payload = {
            "model": self.model_name,
            "messages": messages,
            "stream": stream,
            "options": {
                "temperature": 0.7,
                "top_k": 40,
                "top_p": 0.9,
            }
        }
        logger.info(f"Generating response from Ollama model: {self.model_name}")
        return self._make_request(payload)


class AIAssistantService:
    """خدمة المساعد الذكي التي تجمع بين RAG و Ollama"""

    def __init__(self):
        self.rag_service = RAGService()
        self.ollama_service = OllamaService()
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

    def _build_ollama_messages(
        self,
        user_query: str,
        rag_context: str,
        conversation_history: List[Dict[str, str]]
    ) -> List[Dict[str, str]]:
        """بناء رسائل المحادثة لـ Ollama"""
        messages = []
        messages.append({"role": "system", "content": self.system_prompt})

        # أمثلة قليلة للمساعدة في التوجيه (Few-shot examples)
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

        messages.append({
            "role": "user",
            "content": (
                "شخص قام بالاستيلاء على أرض مملوكة للدولة وقام بالبناء عليها. "
                "ما هو التكييف القانوني لهذا الفعل وما هي الإجراءات المتخذة؟"
            )
        })
        messages.append({
            "role": "assistant",
            "content": (
                "هذا الفعل يندرج تحت جريمة الاعتداء على الأملاك العامة، والتي يعاقب عليها قانون "
                "الجرائم والعقوبات اليمني. وفقًا للمادة 261 من قانون الجرائم والعقوبات، يعاقب بالحبس "
                "كل من اعتدى على ملك عام أو خاص بقصد الاستيلاء عليه. الإجراءات المتخذة تشمل تحرير "
                "محضر بالواقعة، التحقيق، وإحالة القضية إلى النيابة العامة ثم المحكمة المختصة لإصدار "
                "الحكم المناسب، مع الأمر بإزالة التعدي."
            )
        })

        # إضافة سجل المحادثة
        messages.extend(conversation_history)

        # إضافة سياق RAG إذا كان متاحًا
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
        try:
            # سلسلة التفكير: أولاً، البحث عن المستندات ذات الصلة
            search_results = self.rag_service.search(user_query, k=5)
            rag_context = self._format_rag_context(search_results)
            logger.info(f"RAG search successful. Context length: {len(rag_context)} characters.")
        except ConnectionError as e:
            logger.warning(f"RAG service unavailable, proceeding without RAG context: {e}")
            # خطة بديلة: المتابعة بدون سياق RAG إذا فشلت خدمة RAG
        except Exception as e:
            logger.error(f"Unexpected error during RAG search: {e}")

        messages = self._build_ollama_messages(user_query, rag_context, conversation_history)

        try:
            # توليد الاستجابة من Ollama
            ollama_response = self.ollama_service.generate_response(messages)
            assistant_message = ollama_response.get("message", {}).get("content", "")
            logger.info("Ollama response generated successfully.")
            return {"response": assistant_message, "source_documents": search_results}
        except ConnectionError as e:
            logger.error(f"Ollama service unavailable: {e}")
            return {
                "response": "عذرًا، لا يمكنني معالجة طلبك حاليًا بسبب مشكلة في خدمة الذكاء الاصطناعي. يرجى المحاولة لاحقًا.",
                "source_documents": []
            }
        except Exception as e:
            logger.error(f"Unexpected error during Ollama response generation: {e}")
            return {
                "response": "حدث خطأ غير متوقع أثناء معالجة طلبك. يرجى المحاولة مرة أخرى.",
                "source_documents": []
            }
