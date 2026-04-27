import json
import re
from django.core.management.base import BaseCommand
from laws.models import Law, LegalArticleFlat
from django.db import transaction

class Command(BaseCommand):
    help = 'Import legal articles from JSON archive into LegalArticleFlat model'

    def add_arguments(self, parser):
        parser.add_argument('json_file', type=str, help='The path to the JSON file to import')

    def handle(self, *args, **options):
        json_file = options['json_file']

        try:
            with open(json_file, 'r', encoding='utf-8') as f:
                archive_data = json.load(f)
        except Exception as e:
            self.stderr.write(self.style.ERROR(f"Error reading JSON file: {e}"))
            return

        added_count = 0

        with transaction.atomic():
            # Clear existing articles to avoid duplicates and ensure a fresh state for this tab
            LegalArticleFlat.objects.all().delete()
            self.stdout.write("Cleared existing LegalArticleFlat records.")

            for book_item in archive_data:
                book_title = book_item.get('title', '').strip()
                if not book_title:
                    continue

                # Clean title
                book_title = re.sub(r'[\*\•]+', '', book_title).strip()

                # Find the matching law from the previously imported 408 laws
                # We try exact match first, then case-insensitive partial
                law = Law.objects.filter(name=book_title).first()
                if not law:
                    law = Law.objects.filter(name__icontains=book_title).first()

                source_title = law.name if law else book_title
                articles = book_item.get('articles', [])
                
                for art in articles:
                    article_id_str = art.get('article_id', '').strip()
                    content = art.get('content', '').strip()
                    
                    if not content:
                        continue

                    # Extract the article number from strings like "مادة (1)"
                    article_num = article_id_str
                    match = re.search(r'(\d+)', article_id_str)
                    if match:
                        article_num = match.group(1)

                    LegalArticleFlat.objects.create(
                        source_title=source_title,
                        book_title=book_title,
                        article_number=article_num,
                        article_text=content
                    )
                    added_count += 1

        self.stdout.write(self.style.SUCCESS(f'Successfully imported {added_count} articles into LegalArticleFlat.'))
