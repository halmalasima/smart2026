
import os
import django
import sys

# Setup Django environment
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'smartju.settings')
django.setup()

from django.db import connection

def import_sql_file(file_path):
    print(f"Reading SQL file: {file_path}")
    
    with open(file_path, 'r', encoding='utf-8') as f:
        sql_content = f.read()

    # Split statements. This is tricky with simple splitting if content contains semicolons.
    # But looking at the file, it seems standard. We can try executing line by line if they are single line inserts,
    # or use a more robust split.
    # The file has INSERT statements on separate lines.
    
    # Let's try to execute statements one by one.
    # We will ignore empty lines and lines starting with --
    
    with connection.cursor() as cursor:
        print("Starting import...")
        count = 0
        
        # Simple parsing: split by semicolon at end of line
        statements = sql_content.split(';\n')
        
        for statement in statements:
            statement = statement.strip()
            if not statement:
                continue
                
            # Skip CREATE TABLE as we did it via migrations (though IF NOT EXISTS handles it)
            if statement.upper().startswith('CREATE TABLE'):
                print("Skipping CREATE TABLE (handled by Django migrations)")
                continue
                
            try:
                cursor.execute(statement)
                count += 1
                if count % 100 == 0:
                    print(f"Executed {count} statements...")
            except Exception as e:
                print(f"Error executing statement: {statement[:100]}...")
                print(f"Error: {e}")

        print(f"Import finished. {count} statements executed.")

if __name__ == '__main__':
    sql_file_path = r'e:\smartjudi\book_nodes.sql'
    if os.path.exists(sql_file_path):
        import_sql_file(sql_file_path)
    else:
        print(f"File not found: {sql_file_path}")
