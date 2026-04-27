import psycopg2
import os

try:
    conn = psycopg2.connect(
        dbname='postgres',
        user='smartjudi',
        password='smartjudi_secret',
        host='localhost',
        port='5435'
    )
    cur = conn.cursor()
    cur.execute("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';")
    tables = cur.fetchall()
    print(f"Tables in db-legal: {[t[0] for t in tables]}")
    cur.close()
    conn.close()
except Exception as e:
    print(f"Error connecting to db-legal: {e}")
