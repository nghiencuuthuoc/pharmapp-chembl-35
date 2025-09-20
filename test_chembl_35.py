import psycopg
conn = psycopg.connect("host=localhost dbname=chembl_35 user=NCT")
with conn.cursor() as cur:
    cur.execute("SELECT chembl_id, pref_name FROM molecule_dictionary LIMIT 5;")
    print(cur.fetchall())
