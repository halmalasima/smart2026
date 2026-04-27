"""AI Service — FastAPI app proxying Groq and external RAG API."""
import os
import logging
import httpx
from fastapi import FastAPI, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
from typing import List, Dict, Any, Optional
import jwt

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="SmartJudi AI Service", version="1.0.0")
security = HTTPBearer(auto_error=False)

GROQ_API_KEY = os.getenv("GROQ_API_KEY", "")
GROQ_API_URL = "https://api.groq.com/openai/v1/chat/completions"
GROQ_MODEL = os.getenv("GROQ_MODEL_NAME", "llama-3.3-70b-versatile")
RAG_API_URL = os.getenv("RAG_API_URL", "").rstrip("/")
JWT_SECRET = os.getenv("JWT_SECRET_KEY", os.getenv("JWT_SECRET", ""))


def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    if not credentials:
        raise HTTPException(status_code=401, detail="Missing token")
    try:
        jwt.decode(credentials.credentials, JWT_SECRET, algorithms=["HS256"])
    except jwt.PyJWTError as e:
        raise HTTPException(status_code=401, detail=f"Invalid token: {e}")


SYSTEM_PROMPT = (
    "أنت مساعد قانوني ذكي متخصص في القانون اليمني. "
    "أجب بدقة واحترافية مستنداً إلى القوانين والأنظمة المعمول بها. "
    "إذا لم تعلم الإجابة، قل ذلك صراحةً."
)


class ChatRequest(BaseModel):
    query: Optional[str] = None
    user_query: Optional[str] = None
    conversation_history: List[Dict[str, Any]] = []


class ChatResponse(BaseModel):
    ai_response: str
    conversation_history: List[Dict[str, Any]]


class DocumentAddRequest(BaseModel):
    content: str
    doc_id: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None


class DocumentDeleteRequest(BaseModel):
    doc_id: str


@app.get("/api/ai/health/")
async def health():
    return {"status": "ok", "service": "ai"}


@app.post("/api/ai/chat/", response_model=ChatResponse)
async def chat(request: ChatRequest, _=Depends(verify_token)):
    user_input = request.user_query or request.query
    if not user_input:
        raise HTTPException(status_code=400, detail="query or user_query is required")

    if not GROQ_API_KEY:
        raise HTTPException(status_code=503, detail="GROQ_API_KEY not configured")

    messages = [{"role": "system", "content": SYSTEM_PROMPT}]
    for h in request.conversation_history:
        if h.get("role") in ("user", "assistant") and h.get("content"):
            messages.append({"role": h["role"], "content": h["content"]})
    messages.append({"role": "user", "content": user_input})

    payload = {"model": GROQ_MODEL, "messages": messages, "max_tokens": 1024, "temperature": 0.7}

    async with httpx.AsyncClient(timeout=120) as client:
        try:
            resp = await client.post(
                GROQ_API_URL,
                json=payload,
                headers={"Authorization": f"Bearer {GROQ_API_KEY}", "Content-Type": "application/json"},
            )
            resp.raise_for_status()
        except httpx.HTTPStatusError as e:
            logger.error(f"Groq error {e.response.status_code}: {e.response.text}")
            raise HTTPException(status_code=502, detail="Groq API error")
        except httpx.RequestError as e:
            logger.error(f"Groq request failed: {e}")
            raise HTTPException(status_code=502, detail="Cannot reach Groq API")

    ai_text = resp.json()["choices"][0]["message"]["content"]
    updated_history = list(request.conversation_history) + [
        {"role": "user", "content": user_input},
        {"role": "assistant", "content": ai_text},
    ]
    return ChatResponse(ai_response=ai_text, conversation_history=updated_history)


@app.post("/api/ai/documents/add/")
async def documents_add(request: DocumentAddRequest, _=Depends(verify_token)):
    if not RAG_API_URL:
        raise HTTPException(status_code=503, detail="RAG_API_URL not configured")
    async with httpx.AsyncClient(timeout=60) as client:
        try:
            resp = await client.post(f"{RAG_API_URL}/add_document/", json=request.dict())
            resp.raise_for_status()
            return resp.json()
        except httpx.RequestError as e:
            raise HTTPException(status_code=502, detail=f"RAG service error: {e}")


@app.post("/api/ai/documents/delete/")
async def documents_delete(request: DocumentDeleteRequest, _=Depends(verify_token)):
    if not RAG_API_URL:
        raise HTTPException(status_code=503, detail="RAG_API_URL not configured")
    async with httpx.AsyncClient(timeout=60) as client:
        try:
            resp = await client.post(f"{RAG_API_URL}/delete_document/", json=request.dict())
            resp.raise_for_status()
            return resp.json()
        except httpx.RequestError as e:
            raise HTTPException(status_code=502, detail=f"RAG service error: {e}")
