import json
import re

def get_category(title):
    title = title.lower()
    if "دستور" in title: return "دستوري"
    if any(x in title for x in ["إجراءات جزائية", "عقوبات", "جرائم", "سجون"]): return "جنائي"
    if any(x in title for x in ["مدني", "إثبات", "تحكيم", "مرافعات", "أحوال شخصية", "وقف"]): return "مدني"
    if any(x in title for x in ["تجاري", "شركات", "بنوك", "استثمار"]): return "تجاري"
    if any(x in title for x in ["عمل", "خدمة مدنية", "تقاعد", "إداري"]): return "إداري وعمل"
    if any(x in title for x in ["مالية", "ضرائب", "جمارك", "زكاة"]): return "مالي وضريبي"
    if "لائحة" in title: return "لوائح"
    if "قرار" in title: return "قرارات"
    return "تشريعات عامة"

def generate_tags(title):
    # استخراج كلمات مفتاحية للفهرسة
    words = re.findall(r'\w+', title)
    tags = [w for w in words if len(w) > 3]
    return list(set(tags))

def main():
    try:
        with open("/home/ubuntu/yemen_laws_list.json", "r", encoding="utf-8") as f:
            laws = json.load(f)
    except:
        print("Source file not found.")
        return

    processed_laws = []
    for i, law in enumerate(laws):
        title = law['title'].strip()
        if not title or len(title) < 4: continue
        
        # استنتاج رابط الـ PDF بناءً على النمط المكتشف
        # النمط هو: download.php?path=NAME.pdf&id=ID
        # سنحاول استخراج الـ ID من رابط الصفحة
        law_id_match = re.search(r'id=(\d+)', law['url'])
        pdf_url = None
        if law_id_match:
            law_id = law_id_match.group(1)
            # ملاحظة: اسم الملف البرمجي يختلف، لذا سنضع رابط الصفحة كمرجع
            # ونترك للمستخدم خيار التحميل اليدوي أو استخدام سكريبت التحميل المطور
            pdf_url = f"https://agoye.gov.ye/download.php?id={law_id}"

        processed_laws.append({
            "id": i + 1,
            "title": title,
            "category": get_category(title),
            "tags": generate_tags(title),
            "source_url": law['url'],
            "pdf_link": pdf_url,
            "metadata": {
                "country": "Yemen",
                "language": "Arabic",
                "source": "General Secretariat of the Council of Ministers"
            }
        })

    with open("/home/ubuntu/yemen_laws_indexed.json", "w", encoding="utf-8") as f:
        json.dump(processed_laws, f, ensure_ascii=False, indent=4)
    
    print(f"Successfully indexed {len(processed_laws)} laws.")

if __name__ == "__main__":
    main()
