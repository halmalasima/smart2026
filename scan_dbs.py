import psycopg2
from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT

ports = [5433, 5434, 5435, 5436, 5437, 5438, 5439]
user = 'smartjudi'
password = 'smartjudi_secret'

for port in ports:
    print(f"\n--- Checking Port {port} ---")
    try:
        conn = psycopg2.connect(
            dbname='postgres',
            user=user,
            password=password,
            host='localhost',
            port=port
        )
        conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
        cur = conn.cursor()
        
        # List databases
        cur.execute("SELECT datname FROM pg_database WHERE datistemplate = false;")
        dbs = cur.fetchall()
        print(f"Databases: {[db[0] for db in dbs]}")
        
        for db_name in [db[0] for db in dbs]:
            if db_name in ['postgres', 'template1']: continue
            print(f"  Checking DB: {db_name}")
            try:
                db_conn = psycopg2.connect(
                    dbname=db_name,
                    user=user,
                    password=password,
                    host='localhost',
                    port=port
                )
                db_cur = db_conn.cursor()
                db_cur.execute("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';")
                tables = db_cur.fetchall()
                print(f"    Tables: {[t[0] for t in tables]}")
                db_cur.close()
                db_conn.close()
            except Exception as e:
                print(f"    Error checking {db_name}: {e}")
                
        cur.close()
        conn.close()
    except Exception as e:
        print(f"Error connecting to port {port}: {e}")
