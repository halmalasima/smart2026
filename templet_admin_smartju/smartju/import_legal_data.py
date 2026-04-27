#!/usr/bin/env python
"""
سكريبت لاستيراد بيانات المواد القانونية من ملف SQL إلى قاعدة بيانات Django
"""
import os
import sys
import re

# إعداد Django
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'smartju.settings')

import django
django.setup()

from laws.models import LegalArticleFlat

def parse_sql_file(file_path):
    """تحليل ملف SQL واستخراج البيانات"""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # البحث عن جميع القيم في INSERT statements
    # النمط: ('value1','value2',...)
    pattern = r"\('([^']*(?:''[^']*)*)','([^']*(?:''[^']*)*)','([^']*(?:''[^']*)*)','([^']*(?:''[^']*)*)','([^']*(?:''[^']*)*)','([^']*(?:''[^']*)*)','([^']*(?:''[^']*)*)'\)"
    
    matches = re.findall(pattern, content)
    
    records = []
    for match in matches:
        record = {
            'source_title': match[0].replace("''", "'"),
            'book_title': match[1].replace("''", "'") if match[1] else None,
            'section_title': match[2].replace("''", "'") if match[2] else None,
            'chapter_title': match[3].replace("''", "'") if match[3] else None,
            'branch_title': match[4].replace("''", "'") if match[4] else None,
            'article_number': match[5].replace("''", "'"),
            'article_text': match[6].replace("''", "'"),
        }
        records.append(record)
    
    return records

def import_data(records):
    """استيراد البيانات إلى قاعدة البيانات"""
    created_count = 0
    
    for record in records:
        obj, created = LegalArticleFlat.objects.get_or_create(
            source_title=record['source_title'],
            article_number=record['article_number'],
            defaults={
                'book_title': record['book_title'],
                'section_title': record['section_title'],
                'chapter_title': record['chapter_title'],
                'branch_title': record['branch_title'],
                'article_text': record['article_text'],
            }
        )
        if created:
            created_count += 1
    
    return created_count

if __name__ == '__main__':
    # مسار ملف SQL
    sql_file = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'yemen_legal_dataset.sql')
    
    print(f"📂 جاري قراءة الملف: {sql_file}")
    
    if not os.path.exists(sql_file):
        print(f"❌ الملف غير موجود: {sql_file}")
        sys.exit(1)
    
    records = parse_sql_file(sql_file)
    print(f"📊 تم العثور على {len(records)} سجل")
    
    if records:
        print("⏳ جاري استيراد البيانات...")
        created = import_data(records)
        print(f"✅ تم استيراد {created} سجل جديد بنجاح!")
        print(f"📈 إجمالي السجلات في قاعدة البيانات: {LegalArticleFlat.objects.count()}")
    else:
        print("⚠️ لم يتم العثور على بيانات للاستيراد")
