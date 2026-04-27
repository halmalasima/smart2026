import json
import re
from django.core.management.base import BaseCommand
from django.utils.text import slugify
from laws.models import Law, LegalCategory, Tag
from django.db import transaction

class Command(BaseCommand):
    help = 'Import laws from JSON file into the structured database'

    def add_arguments(self, parser):
        parser.add_argument('json_file', type=str, help='The path to the JSON file to import')

    def arabic_slugify(self, text):
        # Basic Arabic slugify
        text = text.replace(' ', '-')
        text = re.sub(r'[^\w\-]', '', text)
        return text

    def handle(self, *args, **options):
        json_file = options['json_file']

        try:
            with open(json_file, 'r', encoding='utf-8') as f:
                laws_data = json.load(f)
        except Exception as e:
            self.stderr.write(self.style.ERROR(f"Error reading JSON file: {e}"))
            return

        added_count = 0
        updated_count = 0

        with transaction.atomic():
            for item in laws_data:
                title = item.get('title', '').strip()
                if not title:
                    continue
                
                # Clean title by removing trailing symbols or extra spaces if needed
                title = re.sub(r'[\*\•]+', '', title).strip()

                category_name = item.get('category', 'تشريعات عامة').strip()
                source_url = item.get('source_url', '')
                pdf_link = item.get('pdf_link', '')
                tags_list = item.get('tags', [])

                # 1. Handle Category
                category_slug = self.arabic_slugify(category_name)
                if not category_slug:
                    category_slug = f"cat-{abs(hash(category_name))}"
                
                category, _ = LegalCategory.objects.get_or_create(
                    name=category_name,
                    defaults={'slug': category_slug}
                )

                # 2. Handle Law
                law_slug = self.arabic_slugify(title)
                if not law_slug:
                    law_slug = f"law-{abs(hash(title))}"
                
                # Ensure unique slug
                original_slug = law_slug
                counter = 1
                while Law.objects.filter(slug=law_slug).exists() and not Law.objects.filter(name=title).exists():
                    law_slug = f"{original_slug}-{counter}"
                    counter += 1

                # Use update_or_create to avoid duplicates by name
                law, created = Law.objects.update_or_create(
                    name=title,
                    defaults={
                        'category': category,
                        'slug': law_slug,
                        'source_url': source_url,
                        'pdf_link': pdf_link
                    }
                )

                if created:
                    added_count += 1
                else:
                    updated_count += 1

                # 3. Handle Tags
                law.tags.clear() # Clear existing tags for fresh import
                for tag_name in tags_list:
                    tag_name = tag_name.strip()
                    if not tag_name:
                        continue
                    
                    tag_slug = self.arabic_slugify(tag_name)
                    if not tag_slug:
                        tag_slug = f"tag-{abs(hash(tag_name))}"
                    
                    tag, _ = Tag.objects.get_or_create(
                        name=tag_name,
                        defaults={'slug': tag_slug}
                    )
                    law.tags.add(tag)

        self.stdout.write(self.style.SUCCESS(f'Successfully imported laws: {added_count} added, {updated_count} updated.'))
