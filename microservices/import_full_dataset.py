import json
import os
import subprocess
import csv
import re
import sys

# Set encoding for Windows console
if sys.platform == "win32":
    import codecs
    sys.stdout = codecs.getwriter("utf-8")(sys.stdout.detach())
    sys.stderr = codecs.getwriter("utf-8")(sys.stderr.detach())

# Configuration
DOCS_DIR = r"d:\smart2026\docs"
COURTS_JSON = os.path.join(DOCS_DIR, "governorates_courts_final.json")
LAWS_SQL = os.path.join(DOCS_DIR, "import_laws.sql")
LAWYERS_CSV = os.path.join(DOCS_DIR, "law.csv")

CONTAINER = "microservices-db-legal-1"
DB = "smartjudi_legal"
DB_USER = "smartjudi"

def run_psql(sql: str) -> bool:
    cmd = ["docker", "exec", "-i", CONTAINER, "psql", "-U", DB_USER, "-d", DB, "-q"]
    try:
        result = subprocess.run(cmd, input=sql, capture_output=True, text=True, encoding="utf-8")
        if result.returncode != 0:
            # print(f"Error: {result.stderr}")
            return False
        return True
    except Exception as e:
        print(f"Exception: {e}")
        return False

def escape_sql(val):
    if val is None: return "NULL"
    return "'" + str(val).replace("'", "''") + "'"

def import_courts():
    print("--- Importing Governorates and Courts ---")
    if not os.path.exists(COURTS_JSON):
        print(f"File not found: {COURTS_JSON}")
        return

    with open(COURTS_JSON, 'r', encoding='utf-8') as f:
        data = json.load(f)

    gov_count = 0
    court_count = 0
    for entry in data:
        gov_name = entry['governorate'].strip()
        courts = entry.get('courts', [])
        
        # Insert Governorate
        sql_gov = f"INSERT INTO courts_governorate (name, created_at, updated_at) VALUES ({escape_sql(gov_name)}, NOW(), NOW()) ON CONFLICT (name) DO NOTHING;"
        run_psql(sql_gov)
        gov_count += 1
        
        for court_name in courts:
            court_name = court_name.strip()
            if not court_name: continue
            
            sql_court = f"""
            INSERT INTO courts_court (name, governorate_id, is_active, created_at, updated_at)
            SELECT {escape_sql(court_name)}, id, true, NOW(), NOW()
            FROM courts_governorate WHERE name = {escape_sql(gov_name)}
            ON CONFLICT DO NOTHING;
            """
            run_psql(sql_court)
            court_count += 1
    
    print(f"Done: Imported {gov_count} Governorates and {court_count} Courts.")

def import_laws():
    print("--- Importing Law Library (PDFs) ---")
    if not os.path.exists(LAWS_SQL):
        print(f"File not found: {LAWS_SQL}")
        return

    with open(LAWS_SQL, 'r', encoding='utf-8') as f:
        sql_content = f.read()

    run_psql(sql_content)
    print("Done: Law Library import completed.")

def import_lawyers():
    print("--- Importing Lawyers from CSV ---")
    if not os.path.exists(LAWYERS_CSV):
        print(f"File not found: {LAWYERS_CSV}")
        return

    with open(LAWYERS_CSV, 'r', encoding='utf-8') as f:
        # Use DictReader to handle Arabic column names
        reader = csv.DictReader(f)
        count = 0
        for row in reader:
            name = row.get('\ufeffالاسم الكامل', row.get('الاسم الكامل', '')).strip()
            reg_num = row.get('رقم القيد', '').strip()
            grade = row.get('الدرجة', '').strip()
            branch = row.get('الفرع', '').strip()
            address = row.get('العنوان', '').strip()
            phone = row.get('موبايل1', '').strip()
            
            if not reg_num or not name: continue
            
            sql = f"""
            INSERT INTO lawyers_lawyer (registration_number, name, grade, branch, address_details, phone, governorate, created_at, updated_at)
            VALUES ({escape_sql(reg_num)}, {escape_sql(name)}, {escape_sql(grade)}, {escape_sql(branch)}, {escape_sql(address)}, {escape_sql(phone)}, {escape_sql(branch)}, NOW(), NOW())
            ON CONFLICT (registration_number) DO UPDATE SET
                name = EXCLUDED.name,
                grade = EXCLUDED.grade,
                branch = EXCLUDED.branch,
                address_details = EXCLUDED.address_details,
                phone = EXCLUDED.phone,
                updated_at = NOW();
            """
            run_psql(sql)
            count += 1
            if count % 100 == 0:
                print(f"  Processed {count} lawyers...", end="\r")
        
        print(f"\nDone: Imported {count} Lawyers.")

if __name__ == "__main__":
    import_courts()
    import_laws()
    import_lawyers()
