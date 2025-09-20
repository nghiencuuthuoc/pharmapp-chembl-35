# PharmApp – ChEMBL 35 on **Windows 11** (Quick Setup)

This README shows a **Windows 11–only** path to get **ChEMBL 35** running on **PostgreSQL**, restore a prebuilt dump, and test connections from both **psql** and **Python** using the Conda env **`pharmapp_3`** created from `pharmapp_3.yml`.

---

## What you’ll set up

- PostgreSQL running locally (ported on **5432**).
- Database **`chembl_35`** restored from the dump **`chembl_35_rdkit_backup.dump`**.
- Python environment **`pharmapp_3`** to run quick queries.

> **Download the dump** from Google Drive:  
> https://drive.google.com/drive/folders/1nqBBNof4q3ywJfrpVUx6PBl0gl3VJfXi?usp=sharing

---

## Paths used in this guide (edit as needed)

- **PGDATA**: `E:\PharmAppDev\pgdata`
- **Dump file**: `E:\DrugDev\NCT-App\CheMBL-35\dump\chembl_35_rdkit_backup.dump`
- **DB name**: `chembl_35`
- **DB owner user**: your Windows account (example: `NCT`)

If your Windows username contains **spaces**, always wrap it in quotes when used in SQL (e.g., `ALTER ROLE "John Doe" ...`).

---

## 0) Pre‑requisites (Windows 11)

- **Conda** (Anaconda / Miniconda) installed.
- **PostgreSQL** installed (includes `psql`, `pg_ctl`, `pg_restore`).  
  Add PostgreSQL’s `bin` folder to **PATH** so you can run those tools from any prompt.

> Tip: Open a new **PowerShell** window after installing PostgreSQL so PATH changes apply.

---

## 1) Create & activate Conda env `pharmapp_3`

From the folder where your `pharmapp_3.yml` file lives:
```bat
conda env create -f pharmapp_3.yml -n pharmapp_3
conda activate pharmapp_3
```

If `psycopg` is missing after activation:
```bat
pip install psycopg
```

---

## 2) Initialize a new PostgreSQL cluster (data directory)

Open **PowerShell** as Administrator (or a user with write access to your target folder):

```bat
# Create the data directory
mkdir E:\PharmAppDev\pgdata

# Initialize the cluster (the Windows user who runs this becomes the DB superuser)
initdb -D "E:\PharmAppDev\pgdata"
```

> If `initdb` is not found, ensure PostgreSQL `bin` is on PATH, or call it with the full path (e.g., `"C:\Program Files\PostgreSQL\17\bin\initdb"`).

---

## 3) Start PostgreSQL

```bat
pg_ctl -D "E:\PharmAppDev\pgdata" -l "E:\PharmAppDev\pgdata\logfile" start

# Optional: confirm it is listening on 5432
netstat -ano | findstr 5432
```

If it’s running, you should see `LISTENING` for `127.0.0.1:5432` and `[::1]:5432`.

---

## 4) Create the database

Connect using your Windows user (it was made superuser at `initdb` time). Replace `NCT` with your account if different:

```bat
psql -h localhost -U NCT -d postgres -c "CREATE DATABASE chembl_35 OWNER \"NCT\";"
```

> If you prefer a separate `postgres` role, you can create it later from `psql`:
> ```sql
> CREATE ROLE postgres WITH LOGIN SUPERUSER PASSWORD 'YourStrong!Pass';
> ```

---

## 5) Restore **ChEMBL 35** from the dump

Make sure the dump file is available locally:
```
E:\DrugDev\NCT-App\CheMBL-35\dump\chembl_35_rdkit_backup.dump
```

Restore with `pg_restore`:
```bat
pg_restore -h localhost -U NCT -d chembl_35 --no-owner --no-privileges "E:\DrugDev\NCT-App\CheMBL-35\dump\chembl_35_rdkit_backup.dump"
```

> *Sanity check:* `pg_restore -l "E:\...\chembl_35_rdkit_backup.dump"` should list archive contents.  
> If it says “not a valid archive”, the file is a plain SQL script → use `psql -f`:
> ```bat
> psql -h localhost -U NCT -d chembl_35 -f "E:\DrugDev\NCT-App\CheMBL-35\dump\chembl_35_rdkit_backup.dump"
> ```

---

## 6) Verify with **psql**

```bat
REM Switch console to UTF-8 to avoid code page warnings
chcp 65001

psql -h localhost -U NCT -d chembl_35 -c "SELECT current_user, current_database();"
psql -h localhost -U NCT -d chembl_35 -c "\dt"
psql -h localhost -U NCT -d chembl_35 -c "SELECT COUNT(*) AS molecules FROM molecule_dictionary;"
psql -h localhost -U NCT -d chembl_35 -c "SELECT COUNT(*) AS assays FROM assays;"
psql -h localhost -U NCT -d chembl_35 -c "SELECT COUNT(*) AS activities FROM activities;"
psql -h localhost -U NCT -d chembl_35 -c "VACUUM ANALYZE;"
```

You should see ~79 tables and non‑zero counts for the main ones.

> If you see a `GSSAPI` warning, append `--no-gssenc` to your `psql` commands:
> ```bat
> psql -h localhost -U NCT -d chembl_35 --no-gssenc -c "SELECT 1;"
> ```

---

## 7) Verify with **Python**

Create a file `test_connection.py` (any folder) with:

```python
import psycopg

conn = psycopg.connect("host=localhost dbname=chembl_35 user=NCT")
with conn.cursor() as cur:
    cur.execute("SELECT chembl_id, pref_name FROM molecule_dictionary ORDER BY chembl_id LIMIT 5;")
    for row in cur.fetchall():
        print(row)
```

Run it:
```bat
python test_connection.py
```

Expected: 5 tuples like `('CHEMBL4760153', None)` or with a name if available.

---

## Troubleshooting (Windows 11)

- **`FATAL: role "postgres" does not exist`**  
  Your cluster was initialized without a `postgres` role (normal on Windows). Either use your Windows user (e.g., `NCT`) as the DB owner (recommended), or create the role from `psql` as a superuser:
  ```sql
  CREATE ROLE postgres WITH LOGIN SUPERUSER PASSWORD 'YourStrong!Pass';
  ```

- **`FATAL: database "<user>" does not exist`**  
  `psql -U <user>` defaults to database `<user>`. Always pass `-d postgres` or `-d chembl_35`.

- **GSSAPI / Code page warnings**  
  Use `--no-gssenc` on `psql` and `chcp 65001` to switch console to UTF‑8.

- **`pg_restore: not a valid archive`**  
  Use `psql -f` for plain SQL dumps.

- **Permission / ownership errors while restoring**  
  Keep `--no-owner --no-privileges` in `pg_restore` and ensure you created `chembl_35` as your superuser.

- **Check server logs**  
  Open `E:\PharmAppDev\pgdata\logfile` for detailed startup/restore messages.

- **Stop the server**  
  ```bat
  pg_ctl -D "E:\PharmAppDev\pgdata" stop
  ```

---

## Optional: one‑shot restore BAT (edit paths/user)

Create `restore_chembl35.bat`:

```bat
@echo off
setlocal

REM === EDIT THESE ===
set PGDATA=E:\PharmAppDev\pgdata
set DUMP=E:\DrugDev\NCT-App\CheMBL-35\dump\chembl_35_rdkit_backup.dump
set PGUSER=NCT
set PGPORT=5432
REM ==================

chcp 65001 >nul

pg_ctl -D "%PGDATA%" -l "%PGDATA%\logfile" start
ping 127.0.0.1 -n 3 >nul

psql -h localhost -p %PGPORT% -U %PGUSER% -d postgres -c "DROP DATABASE IF EXISTS chembl_35;"
psql -h localhost -p %PGPORT% -U %PGUSER% -d postgres -c "CREATE DATABASE chembl_35 OWNER \"%PGUSER%\";"

pg_restore -h localhost -p %PGPORT% -U %PGUSER% -d chembl_35 --no-owner --no-privileges "%DUMP%"

psql -h localhost -p %PGPORT% -U %PGUSER% -d chembl_35 -c "SELECT COUNT(*) AS molecules FROM molecule_dictionary;"
psql -h localhost -p %PGPORT% -U %PGUSER% -d chembl_35 -c "VACUUM ANALYZE;"

echo Done.
endlocal
pause
```

That’s it. You now have ChEMBL 35 live on Windows 11 with a reproducible workflow.
