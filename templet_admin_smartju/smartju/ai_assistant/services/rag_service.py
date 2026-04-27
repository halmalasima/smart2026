# smartju/ai_assistant/services/rag_service.py

import os
import httpx
import logging
from typing import List, Dict, Any, Optional

logger = logging.getLogger(__name__)

class RAGService:
    """
    Service to interact with the Hugging Face RAG API.
    خدمة للتفاعل مع واجهة برمجة تطبيقات RAG المستضافة على Hugging Face.
    """
    def __init__(self):
        self.rag_api_url = os.getenv("RAG_API_URL")
        if not self.rag_api_url:
            logger.warning("RAG_API_URL environment variable not set. RAG features will be disabled.")
            self.client = None
        else:
            self.client = httpx.Client(base_url=self.rag_api_url, timeout=30.0)

    def _make_request(self, method: str, endpoint: str, json_data: Optional[Dict] = None) -> Any:
        """
        Helper method to make HTTP requests to the RAG API.
        دالة مساعدة لإجراء طلبات HTTP إلى واجهة برمجة تطبيقات RAG.
        """
        if not self.client:
            raise ConnectionError("RAG client is not initialized (RAG_API_URL missing).")
        try:
            response = self.client.request(method, endpoint, json=json_data, timeout=60.0)
            response.raise_for_status()  # Raise an exception for HTTP errors (4xx or 5xx)
            return response.json()
        except httpx.RequestError as e:
            logger.error(f"RAG API Request failed for {endpoint}: {e}")
            raise ConnectionError(f"Could not connect to RAG API: {e}")
        except httpx.HTTPStatusError as e:
            logger.error(f"RAG API returned HTTP error {e.response.status_code} for {endpoint}: {e.response.text}")
            raise ValueError(f"RAG API error: {e.response.text}")
        except Exception as e:
            logger.error(f"An unexpected error occurred during RAG API call to {endpoint}: {e}")
            raise RuntimeError(f"Unexpected error with RAG API: {e}")

    def health_check(self) -> bool:
        """
        Checks the health of the RAG API.
        يتحقق من حالة عمل واجهة برمجة تطبيقات RAG.
        """
        try:
            response = self._make_request("GET", "/health")
            return response.get("status") == "ok"
        except Exception:
            return False

    def add_documents(self, documents) -> bool:
        """
        Adds documents to the RAG engine.
        يضيف مستندات إلى محرك RAG.
        Accepts either:
          - List of tuples (filename, content_bytes, content_type) for file upload
          - List of dicts [{"page_content": "text", "metadata": {...}}] for JSON
        """
        try:
            if documents and isinstance(documents[0], (tuple, list)):
                # File upload via multipart — use /add_documents
                if not self.client:
                    raise ConnectionError("RAG client is not initialized (RAG_API_URL missing).")
                files = [
                    ("files", (name, content, ctype))
                    for name, content, ctype in documents
                ]
                response = self.client.post("/add_documents", files=files)
                response.raise_for_status()
                result = response.json()
            else:
                # JSON payload — use /add_documents_json (correct endpoint)
                result = self._make_request("POST", "/add_documents_json", json_data=documents)
            logger.info(f"RAG API add_documents response: {result}")
            return result.get("status") == "success"
        except Exception as e:
            logger.error(f"Failed to add documents to RAG: {e}")
            return False

    def search_documents(self, query: str, k: int = 4) -> List[Dict]:
        """
        Searches for relevant documents in the RAG engine.
        يبحث عن المستندات ذات الصلة في محرك RAG.
        """
        try:
            response = self._make_request("POST", "/search", json={"query_text": query, "k": k})
            return response
        except Exception as e:
            logger.error(f"Failed to search documents in RAG: {e}")
            return []

    def delete_documents(self, source: str = None, ids: Optional[List[str]] = None, metadata_filter: Optional[Dict[str, Any]] = None) -> bool:
        """
        Deletes documents from the RAG engine based on source name, IDs, or metadata filter.
        يحذف المستندات من محرك RAG بناءً على اسم المصدر أو المعرفات أو فلتر البيانات الوصفية.
        """
        payload = {}
        if source:
            payload["source"] = source
        if ids:
            payload["ids"] = ids
        if metadata_filter:
            payload["metadata_filter"] = metadata_filter

        if not payload:
            logger.warning("No source, IDs, or metadata filter provided for document deletion.")
            return False

        try:
            response = self._make_request("DELETE", "/delete_documents", json_data=payload)
            logger.info(f"RAG API delete_documents response: {response}")
            return response.get("status") == "success"
        except Exception as e:
            logger.error(f"Failed to delete documents from RAG: {e}")
            return False
