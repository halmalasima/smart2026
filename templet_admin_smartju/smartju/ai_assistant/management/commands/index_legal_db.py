import requests
import logging
from django.core.management.base import BaseCommand
from laws.models import LawArticle, LegalArticleFlat, LegalProcedureNode
from ai_assistant.services.rag_service import RAGService
import os

logger = logging.getLogger(__name__)

class Command(BaseCommand):
    help = 'فهرسة البيانات القانونية من قاعدة البيانات إلى محرك RAG المحلي'

    def handle(self, *args, **options):
        rag_url = os.getenv("RAG_API_URL", "http://localhost:8080")
        self.stdout.write(self.style.SUCCESS(f"البدء في فهرسة البيانات باستخدام RAG API: {rag_url}"))

        # 1. تجهيز البيانات من LawArticle
        self.stdout.write("تجهيز مواد القوانين (LawArticle)...")
        articles = LawArticle.objects.all().select_related('section', 'section__chapter', 'section__chapter__law')
        documents = []
        for art in articles:
            content = f"القانون: {art.section.chapter.law.name}\n" \
                      f"الفصل: {art.section.chapter.title}\n" \
                      f"القسم: {art.section.title}\n" \
                      f"مادة رقم {art.article_number}: {art.article_text}"
            documents.append({
                "page_content": content,
                "metadata": {
                    "source": "database",
                    "type": "law_article",
                    "law_id": art.section.chapter.law.id,
                    "article_id": art.id
                }
            })

        # 2. تجهيز البيانات من LegalArticleFlat
        self.stdout.write("تجهيز المواد المسطحة (LegalArticleFlat)...")
        flat_articles = LegalArticleFlat.objects.all()
        for art in flat_articles:
            content = f"المصدر: {art.source_title}\n" \
                      f"الكتاب: {art.book_title or ''}\n" \
                      f"الفصل: {art.chapter_title or ''}\n" \
                      f"مادة رقم {art.article_number}: {art.article_text}"
            documents.append({
                "page_content": content,
                "metadata": {
                    "source": "database",
                    "type": "flat_article",
                    "article_id": art.id
                }
            })

        # 3. تجهيز البيانات من LegalProcedureNode (دليل الإجراءات)
        self.stdout.write("تجهيز دليل الإجراءات (LegalProcedureNode)...")
        nodes = LegalProcedureNode.objects.all()
        for node in nodes:
            if node.body:
                content = f"دليل الإجراءات - {node.source_title}\n" \
                          f"العنوان: {node.title}\n" \
                          f"المستوى: {node.level}\n" \
                          f"المحتوى: {node.body}"
                documents.append({
                    "page_content": content,
                    "metadata": {
                        "source": "database",
                        "type": "procedure_node",
                        "node_id": node.id
                    }
                })

        if not documents:
            self.stdout.write(self.style.WARNING("لا توجد بيانات للفهرسة."))
            return

        self.stdout.write(f"إجمالي عدد الوثائق المجهزة: {len(documents)}")

        # 4. الإرسال إلى RAG API عبر Batches
        batch_size = 50
        api_endpoint = f"{rag_url}/add_documents_json"
        
        total_docs = len(documents)
        self.stdout.write(f"بدء الإرسال إلى {api_endpoint}...")

        for i in range(0, total_docs, batch_size):
            batch = documents[i:i + batch_size]
            try:
                response = requests.post(api_endpoint, json=batch, timeout=120)
                response.raise_for_status()
                self.stdout.write(f"تمت فهرسة {min(i + batch_size, total_docs)} من {total_docs}")
            except Exception as e:
                self.stdout.write(self.style.ERROR(f"خطأ في الدفعة {i//batch_size + 1}: {str(e)}"))

        self.stdout.write(self.style.SUCCESS("✅ عملية الفهرسة اكتملت بنجاح."))
