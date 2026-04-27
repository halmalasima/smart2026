import csv
import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'smartju.settings')
django.setup()

from lawyers.models import Lawyer


def import_lawyers_from_csv(csv_file_path):
    """
    Import lawyers from CSV file to database
    CSV columns: القيد,الاسم,الدرجة,الفرع,,المحافظة,المديرية,الحي,تفاصيل العنوان,نوع المكتب,ملاحظة
    """
    with open(csv_file_path, 'r', encoding='utf-8-sig') as csvfile:
        reader = csv.DictReader(csvfile)
        
        count = 0
        for row in reader:
            try:
                Lawyer.objects.create(
                    registration_number=row.get('القيد', '').strip(),
                    name=row.get('الاسم', '').strip(),
                    grade=row.get('الدرجة', '').strip(),
                    branch=row.get('الفرع', '').strip() or None,
                    phone=row.get('', '').strip() or None,  # Phone is in empty column
                    governorate=row.get('المحافظة', '').strip() or None,
                    directorate=row.get('المديرية', '').strip() or None,
                    neighborhood=row.get('الحي', '').strip() or None,
                    address_details=row.get('تفاصيل العنوان', '').strip() or None,
                    office_type=row.get('نوع المكتب', '').strip() or None,
                    notes=row.get('ملاحظة', '').strip() or None,
                )
                count += 1
                print(f"Imported: {row.get('الاسم', '')}")
            except Exception as e:
                print(f"Error importing {row.get('الاسم', '')}: {e}")
        
        print(f"\nTotal imported: {count} lawyers")


if __name__ == '__main__':
    csv_path = '../المحاميين1.csv'
    if os.path.exists(csv_path):
        import_lawyers_from_csv(csv_path)
    else:
        print(f"CSV file not found: {csv_path}")
        print(f"Current directory: {os.getcwd()}")
