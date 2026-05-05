import os
import logging
import asyncio
import tempfile

from fastapi import FastAPI, HTTPException, UploadFile, File
from fastapi.responses import JSONResponse, Response
from pydantic import BaseModel
from typing import List, Dict, Any, Optional
from contextlib import asynccontextmanager

from dotenv import load_dotenv

from langchain_community.vectorstores import Chroma
from langchain_community.embeddings import HuggingFaceEmbeddings
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_core.documents import Document

from pdf2image import convert_from_path
import pytesseract

# ---------------------------------------------------
# Environment
# ---------------------------------------------------

load_dotenv()

EMBEDDING_MODEL_NAME = os.getenv(
    "EMBEDDING_MODEL_NAME",
    "intfloat/multilingual-e5-small"
)

CHROMA_DB_DIR = os.getenv("CHROMA_DB_DIR", "./chroma_db")

# ---------------------------------------------------
# Logging
# ---------------------------------------------------

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s"
)

logger = logging.getLogger(__name__)

# ---------------------------------------------------
# Global objects
# ---------------------------------------------------

embeddings = None
vectorstore = None

model_loading = False
model_loaded = False

# ---------------------------------------------------
# Text Splitter
# ---------------------------------------------------

text_splitter = RecursiveCharacterTextSplitter(
    chunk_size=1000,
    chunk_overlap=200
)

# ---------------------------------------------------
# Model Loader
# ---------------------------------------------------

def load_embedding_model():
    global embeddings

    logger.info("Loading embedding model...")

    # Get Hugging Face token if available
    hf_token = os.getenv("HUGGINGFACE_API_KEY") or os.getenv("HF_TOKEN")
    
    model_kwargs = {}
    if hf_token:
        model_kwargs["token"] = hf_token
        logger.info("Using Hugging Face token for model access")

    embeddings = HuggingFaceEmbeddings(
        model_name=EMBEDDING_MODEL_NAME,
        model_kwargs=model_kwargs
    )

    logger.info("Embedding model loaded")

def init_vectorstore():
    global vectorstore

    os.makedirs(CHROMA_DB_DIR, exist_ok=True)

    vectorstore = Chroma(
        persist_directory=CHROMA_DB_DIR,
        embedding_function=embeddings
    )

    logger.info("ChromaDB initialized")

# ---------------------------------------------------
# Background Loader
# ---------------------------------------------------

async def load_model_background():
    global model_loading, model_loaded

    model_loading = True

    loop = asyncio.get_event_loop()

    try:

        await loop.run_in_executor(None, load_embedding_model)
        await loop.run_in_executor(None, init_vectorstore)

        model_loaded = True
        model_loading = False

        logger.info("RAG engine ready")

    except Exception as e:

        model_loading = False
        model_loaded = False

        logger.error(f"Model loading failed: {e}")

# ---------------------------------------------------
# Lifespan
# ---------------------------------------------------

@asynccontextmanager
async def lifespan(app: FastAPI):

    asyncio.create_task(load_model_background())

    logger.info("Startup complete")

    yield

    if vectorstore:
        try:
            vectorstore.persist()
            logger.info("Chroma persisted")
        except Exception as e:
            logger.error(f"Persist failed: {e}")

# ---------------------------------------------------
# FastAPI
# ---------------------------------------------------

app = FastAPI(
    title="SmartJudi RAG Engine",
    version="1.0",
    lifespan=lifespan
)

# ---------------------------------------------------
# Health Endpoints
# ---------------------------------------------------

@app.get("/")
async def root():
    return JSONResponse(
        {"status": "ok"}
    )

@app.get("/health")
@app.get("/health/")
async def health():
    """Health check with model status"""
    global model_loading, model_loaded
    
    status = {
        "status": "ok",
        "model_loading": model_loading,
        "model_loaded": model_loaded,
        "ready": model_loaded and not model_loading
    }
    
    if model_loading:
        status["message"] = "Model is loading in background..."
    elif model_loaded:
        status["message"] = "RAG engine is fully operational"
    else:
        status["message"] = "RAG engine initializing"
    
    return status

@app.get("/healthz")
@app.get("/healthz/")
async def healthz():
    return Response("OK")

# ---------------------------------------------------
# Models
# ---------------------------------------------------

class DocumentSchema(BaseModel):
    page_content: str
    metadata: Dict[str, Any] = {}

class SearchQuery(BaseModel):
    query_text: str
    k: int = 4

class DeleteRequest(BaseModel):
    source: Optional[str] = None
    ids: Optional[List[str]] = None
    metadata_filter: Optional[Dict[str, Any]] = None

# ---------------------------------------------------
# OCR
# ---------------------------------------------------

def extract_text_from_pdf(pdf_path):

    images = convert_from_path(pdf_path)

    text = ""

    for img in images:

        page_text = pytesseract.image_to_string(
            img,
            lang="ara+eng"
        )

        text += page_text

    return text

# ---------------------------------------------------
# Document Processing
# ---------------------------------------------------

def process_document(content: bytes, filename: str):

    text = ""

    if filename.endswith(".pdf"):

        with tempfile.NamedTemporaryFile(delete=False) as tmp:

            tmp.write(content)
            path = tmp.name

        text = extract_text_from_pdf(path)

        os.remove(path)

    else:

        text = content.decode("utf-8", errors="ignore")

    chunks = text_splitter.split_text(text)

    docs = [
        Document(
            page_content=chunk,
            metadata={"source": filename}
        )
        for chunk in chunks
    ]

    return docs

# ---------------------------------------------------
# Add Documents
# ---------------------------------------------------

@app.post("/add_documents")
async def add_documents(
    files: List[UploadFile] = File(...)
):

    if not model_loaded:

        raise HTTPException(
            503,
            "Model still loading"
        )

    docs = []

    for file in files:

        content = await file.read()

        processed = process_document(
            content,
            file.filename
        )

        docs.extend(processed)

    vectorstore.add_documents(docs)

    return {
        "status": "success",
        "documents_added": len(docs)
    }

# ---------------------------------------------------
# Add Documents JSON (Directly from code/DB)
# ---------------------------------------------------

@app.post("/add_documents_json")
async def add_documents_json(
    documents: List[DocumentSchema]
):
    if not model_loaded:
        raise HTTPException(
            503,
            "Model still loading"
        )

    docs = []
    for doc_schema in documents:
        # Split text into chunks if needed
        chunks = text_splitter.split_text(doc_schema.page_content)
        for chunk in chunks:
            docs.append(
                Document(
                    page_content=chunk,
                    metadata=doc_schema.metadata
                )
            )

    if docs:
        vectorstore.add_documents(docs)

    return {
        "status": "success",
        "documents_added": len(docs),
        "total_chunks": len(docs)
    }

# ---------------------------------------------------
# Search
# ---------------------------------------------------

@app.post("/search")
async def search(query: SearchQuery):

    if not model_loaded:

        raise HTTPException(
            503,
            "Model still loading"
        )

    results = vectorstore.similarity_search_with_score(
        query.query_text,
        k=query.k
    )

    response = []

    for doc, score in results:

        response.append({
            "content": doc.page_content,
            "metadata": doc.metadata,
            "score": float(score)
        })

    return response

# ---------------------------------------------------
# Delete Documents
# ---------------------------------------------------

@app.delete("/delete_documents")
async def delete_documents(req: DeleteRequest):

    if not model_loaded:
        raise HTTPException(503, "Model still loading")

    if not req.source and not req.ids and not req.metadata_filter:
        raise HTTPException(400, "Provide 'source', 'ids', or 'metadata_filter'")

    try:
        where_filter = None
        if req.source:
            where_filter = {"source": req.source}
        elif req.metadata_filter:
            where_filter = req.metadata_filter

        collection = vectorstore._collection

        if req.ids:
            collection.delete(ids=req.ids)
            deleted_count = len(req.ids)
        elif where_filter:
            results = collection.get(where=where_filter)
            if results and results["ids"]:
                collection.delete(ids=results["ids"])
                deleted_count = len(results["ids"])
            else:
                deleted_count = 0
        else:
            deleted_count = 0

        return {
            "status": "success",
            "deleted_count": deleted_count
        }
    except Exception as e:
        logger.error(f"Delete documents failed: {e}")
        raise HTTPException(500, f"Delete failed: {str(e)}")