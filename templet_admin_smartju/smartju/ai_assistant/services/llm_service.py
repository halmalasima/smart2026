# smartju/ai_assistant/services/llm_service.py

import os
import httpx
import logging
from typing import List, Dict, Any, Optional

logger = logging.getLogger(__name__)

class LLMService:
    """
    Service to interact with Groq and OpenRouter LLMs, with fallback mechanism.
    خدمة للتفاعل مع نماذج اللغة الكبيرة (LLMs) من Groq و OpenRouter، مع آلية احتياطية.
    """
    def __init__(self):
        self.groq_api_key = os.getenv("GROQ_API_KEY")
        self.openrouter_api_key = os.getenv("OPENROUTER_API_KEY")

        if not self.groq_api_key:
            logger.warning("GROQ_API_KEY environment variable not set. Groq will be unavailable.")
        if not self.openrouter_api_key:
            logger.warning("OPENROUTER_API_KEY environment variable not set. OpenRouter will be unavailable.")

        self.groq_client = httpx.Client(
            base_url="https://api.groq.com/openai/v1",
            headers={"Authorization": f"Bearer {self.groq_api_key}"},
            timeout=60.0
        ) if self.groq_api_key else None
        
        self.openrouter_client = httpx.Client(
            base_url="https://openrouter.ai/api/v1",
            headers={
                "Authorization": f"Bearer {self.openrouter_api_key}",
                "HTTP-Referer": "https://smartjudi2.com",
                "X-Title": "SmartJudi2"
            },
            timeout=60.0
        ) if self.openrouter_api_key else None

        # Ollama support for local operation
        self.ollama_api_url = os.getenv("OLLAMA_API_URL", "http://localhost:11434")
        self.ollama_model_name = os.getenv("OLLAMA_MODEL_NAME", "smartjudi-qwen")
        self.ollama_client = httpx.Client(
            base_url=f"{self.ollama_api_url}/v1",
            timeout=120.0
        ) if self.ollama_api_url else None

        self.system_prompt = """
أنت مساعد قانوني خبير في القانون اليمني. مهمتك هي تقديم استشارات قانونية دقيقة وموثوقة بناءً على القوانين والتشريعات اليمنية. يجب أن تكون إجاباتك واضحة، موجزة، ومستندة إلى النصوص القانونية المتاحة. تجنب التكهنات أو تقديم آراء شخصية. عند الإشارة إلى مواد قانونية، اذكر رقم المادة والقانون الذي تنتمي إليه. حافظ على نبرة احترافية ومحايدة.

في نهاية كل إجابة، يجب عليك دائماً اقتراح 3 أسئلة متابعة ذكية وقصيرة (Follow-up questions) تهم المستخدم وتتعلق بنفس السياق، لمساعدة المستخدم على فهم الموضوع بشكل أشمل. اجعل هذه الأسئلة في سطر جديد تماماً يبدأ بكلمة "SUGGESTED_QUESTIONS:" متبوعة بالأسئلة مفصولة بـ "||".
مثال:
SUGGESTED_QUESTIONS: ما هي الوثائق المطلوبة؟ || كم تستغرق الإجراءات؟ || هل هناك غرامات للتأخير؟

Think step-by-step. First, identify the key legal concepts in the user's query. Second, analyze the provided context for relevant information. Third, formulate an answer based on Yemeni law, citing specific articles if applicable. Finally, present your answer clearly and concisely.

Few-shot Examples:
User: ما هي شروط عقد البيع في القانون اليمني؟
AI: شروط عقد البيع في القانون اليمني، وفقاً لقانون البيع رقم (24) لسنة 2002، هي كالتالي:
1.  الرضا: يجب أن يكون هناك رضا متبادل بين البائع والمشتري.
2.  المحل: يجب أن يكون المبيع موجوداً أو ممكن الوجود، ومعيناً أو قابلاً للتعيين، ومشروعاً التعامل فيه.
3.  الثمن: يجب أن يكون الثمن معلوماً ومقدراً.
(المادة 12 من قانون البيع اليمني رقم 24 لسنة 2002).

User: هل يجوز للمرأة أن تطلب الطلاق في اليمن؟ وما هي الحالات؟
AI: نعم، يجوز للمرأة أن تطلب الطلاق (الخلع) في القانون اليمني، وذلك وفقاً لأحكام قانون الأحوال الشخصية رقم (20) لسنة 1992. من الحالات التي يجوز فيها للمرأة طلب الطلاق:
1.  إذا أضر الزوج بزوجته ضرراً لا يمكن معه دوام العشرة بالمعروف.
2.  إذا غاب الزوج عن زوجته مدة تزيد عن سنة دون عذر مقبول.
3.  إذا امتنع الزوج عن الإنفاق على زوجته.
(المواد 60-65 من قانون الأحوال الشخصية اليمني رقم 20 لسنة 1992).
"""

    def _call_llm(self, client: httpx.Client, model: str, messages: List[Dict], max_tokens: int = 1024, temperature: float = 0.7) -> str:
        """
        Helper method to call a specific LLM API.
        دالة مساعدة لاستدعاء واجهة برمجة تطبيقات نموذج اللغة الكبير (LLM) محددة.
        """
        try:
            payload = {
                "model": model,
                "messages": messages,
                "max_tokens": max_tokens,
                "temperature": temperature,
            }
            response = client.post("/chat/completions", json=payload)
            response.raise_for_status()
            return response.json()["choices"][0]["message"]["content"]
        except httpx.RequestError as e:
            logger.error(f"LLM API Request failed for model {model}: {e}")
            raise ConnectionError(f"Could not connect to LLM API ({model}): {e}")
        except httpx.HTTPStatusError as e:
            logger.error(f"LLM API returned HTTP error {e.response.status_code} for model {model}: {e.response.text}")
            raise ValueError(f"LLM API error ({model}): {e.response.text}")
        except Exception as e:
            logger.error(f"An unexpected error occurred during LLM API call to model {model}: {e}")
            raise RuntimeError(f"Unexpected error with LLM API ({model}): {e}")

    def generate_response(self, user_query: str, rag_context: str, conversation_history: List[Dict], temperature: float = 0.7) -> str:
        """
        Generates a response using Groq as primary and OpenRouter as fallback.
        يولد استجابة باستخدام Groq كنموذج أساسي و OpenRouter كنموذج احتياطي.
        """
        messages = [{"role": "system", "content": self.system_prompt}]
        messages.extend(conversation_history)

        # Integrate RAG context into the user's current query
        # دمج سياق RAG في استعلام المستخدم الحالي
        prompt_template = f"""
Context: {rag_context}
User Query: {user_query}
Based on the provided context and your knowledge of Yemeni law, please answer the user's query.
"""
        messages.append({"role": "user", "content": prompt_template})

        # Try Groq first
        # محاولة Groq أولاً
        if self.groq_client:
            try:
                logger.info("Attempting to generate response with Groq...")
                # Use llama-3.3-70b-versatile if available, otherwise fallback to llama3-8b-8192
                groq_model = os.getenv("GROQ_MODEL_NAME", "llama-3.3-70b-versatile")
                response = self._call_llm(self.groq_client, groq_model, messages, temperature=temperature)
                logger.info("Response generated successfully with Groq.")
                return response
            except Exception as e:
                logger.warning(f"Groq failed, attempting fallback to OpenRouter: {e}")

        # Try OpenRouter
        # الانتقال إلى OpenRouter كخيار احتياطي
        if self.openrouter_client:
            try:
                logger.info("Attempting to generate response with OpenRouter...")
                # Using a common Qwen model name, adjust if a specific one is preferred
                openrouter_model = os.getenv("OPENROUTER_MODEL_NAME", "qwen/qwen-2.5-7b-instruct")
                response = self._call_llm(self.openrouter_client, openrouter_model, messages, temperature=temperature)
                logger.info("Response generated successfully with OpenRouter.")
                return response
            except Exception as e:
                logger.warning(f"OpenRouter failed, attempting fallback to Ollama: {e}")

        # Fallback to Ollama (Local)
        # الانتقال إلى Ollama (محلي) كخيار نهائي
        if self.ollama_client:
            try:
                logger.info("Attempting to generate response with local Ollama...")
                response = self._call_llm(self.ollama_client, self.ollama_model_name, messages, temperature=temperature)
                logger.info("Response generated successfully with Ollama.")
                return response
            except Exception as e:
                logger.error(f"Ollama also failed: {e}")
                raise RuntimeError("All LLM providers (Groq, OpenRouter, and Ollama) failed to generate a response.")
        
        raise RuntimeError("No LLM clients available (Check your API keys or Ollama status).")
    def analyze_case_strategy(self, case_data: Dict[str, Any]) -> str:
        """
        Specialized method for legal strategic analysis.
        دالة متخصصة للتحليل الاستراتيجي القانوني.
        """
        strategy_prompt = f"""
أنت الآن "المحلل الاستراتيجي القانوني" لـ SmartJudi. مهمتك هي تحليل قضية قانونية من منظور محامي محترف في اليمن.
لديك البيانات التالية للقضية:
- موضوع القضية: {case_data.get('subject', 'غير محدد')}
- وقائع القضية: {case_data.get('facts', 'غير محدد')}
- ادعاءات الخصم: {case_data.get('opponent_claims', 'غير محدد')}
- موقف الموكل: {case_data.get('client_position', 'غير محدد')}

قم بتقديم تحليل استراتيجي مفصل مقسم إلى الأجزاء التالية (باللغة العربية الاحترافية):

1. **تحليل نقاط القوة (Strengths):** العناصر التي تدعم موقف موكلنا قانونياً وواقعياً.
2. **تحليل نقاط الضعف (Weaknesses):** الثغرات التي قد يستغلها الخصم.
3. **تحليل ادعاءات الخصم وكيفية الرد:** فند كل ادعاء للخصم وقدم الحجة القانونية المناسبة للرد عليه من القانون اليمني.
4. **توصيات استراتيجية:** خطوات عملية يجب على المحامي اتخاذها (مثلاً: طلب مستند معين، استدعاء شاهد، تغيير الدفع القانوني).
5. **مسودة مقترحة للمذكرة:** نص أولي لمذكرة رد قانونية قوية.

اجعل التحليل عميقاً، واقعياً، ومستنداً لنصوص القانون اليمني قدر الإمكان.
"""
        messages = [
            {"role": "system", "content": "أنت خبير في القانون اليمني والتحليل الاستراتيجي للقضايا."},
            {"role": "user", "content": strategy_prompt}
        ]

        # Use Groq for deep analysis
        if self.groq_client:
            try:
                return self._call_llm(self.groq_client, "llama-3.3-70b-versatile", messages, max_tokens=2048)
            except Exception as e:
                logger.warning(f"Strategy analysis failed with Groq: {e}")

        # Fallback to OpenRouter
        if self.openrouter_client:
            try:
                return self._call_llm(self.openrouter_client, "qwen/qwen-2.5-7b-instruct", messages, max_tokens=2048)
            except Exception as e:
                logger.error(f"Strategy analysis fallback failed: {e}")
        
        raise RuntimeError("Failed to perform strategy analysis.")
