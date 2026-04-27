import psycopg2

# Connect to postgres database
conn = psycopg2.connect(
    dbname='postgres',
    user='jood',
    password='123456',
    host='localhost'
)
conn.autocommit = True
cur = conn.cursor()

# Terminate all connections to smartjudi
cur.execute("""
    SELECT pg_terminate_backend(pid)
    FROM pg_stat_activity
    WHERE datname = 'smartjudi' AND pid <> pg_backend_pid()
""")

# Drop and recreate database
cur.execute('DROP DATABASE IF EXISTS smartjudi')
cur.execute('CREATE DATABASE smartjudi')

print('✓ Database recreated successfully')

cur.close()
conn.close()
