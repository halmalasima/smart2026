import psycopg2

db_configs = [
    {'port': 5433, 'name': 'smartjudi_cases', 'tables': ['lawsuits_lawsuit', 'parties_plaintiff']},
    {'port': 5434, 'name': 'smartjudi_hearings', 'tables': ['hearings_hearing']},
    {'port': 5435, 'name': 'smartjudi_legal', 'tables': ['laws_law', 'courts_court', 'legal_articles']},
    {'port': 5439, 'name': 'smartjudi_auth', 'tables': ['auth_user', 'accounts_userprofile']},
]

user = 'smartjudi'
password = 'smartjudi_secret'

for db in db_configs:
    print(f"\n--- {db['name']} (Port {db['port']}) ---")
    try:
        conn = psycopg2.connect(
            dbname=db['name'],
            user=user,
            password=password,
            host='localhost',
            port=db['port']
        )
        cur = conn.cursor()
        for table in db['tables']:
            cur.execute(f"SELECT count(*) FROM {table};")
            count = cur.fetchone()[0]
            print(f"  {table}: {count}")
        cur.close()
        conn.close()
    except Exception as e:
        print(f"Error: {e}")
